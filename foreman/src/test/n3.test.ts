// N3 (brief briefs/BRIEF-N3-FOREMAN.md), against the fake adapter and the fake runner. No model is called.
//   1 change request (change_requested / reopened, `foreman change`, answer --change, dependants verified again)
//   2 the critic names the package        3 kit use cannot fall silently (kit_regression)
//   4 runner options from the engine's verbs.json      5 `foreman follow`
//   6 params in the builder prompt; the manifest carries params, footprint, on_leave, subject, moments
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempDir, tempJob, foremanFor, readEvents, scriptWith, fixturePlan, VERBS, type TempJob } from "./helpers.js";
import { FakeBuilder, type FakeStep } from "../builder/fake.js";
import type { Builder } from "../builder/types.js";
import { planCheck, renderPlannerPrompt } from "../designer.js";
import type { JobEvent, PackageSpec } from "../events.js";
import { JobLog, rebuildState, type JobState } from "../joblog.js";
import { Foreman, CHANGE_ROUND, CRITIC_ROUND, DEP_CHANGED, FOREMAN_NOTE, KIT_REGRESSION, countKitUse, statesKitReason } from "../foreman.js";
import { followLog, main } from "../cli.js";
import { acceptedCarriedFields, mergeCarried } from "../manifest.js";
import { Verifier } from "../verifier.js";
import { FAKE_VERBS_FILE, VerbsError, acceptanceOptions, loadVerbs, readVerbsFile, verbsFor } from "../verbs.js";
import { runProcess } from "../proc.js";
import { PKG_ROOT, REPO_ROOT } from "../paths.js";

after(cleanup);

const ofType = <T extends JobEvent["type"]>(evs: JobEvent[], type: T): Extract<JobEvent, { type: T }>[] => evs.filter((e) => e.type === type) as Extract<JobEvent, { type: T }>[];
const states = (evs: JobEvent[], pkg: string): string[] => ofType(evs, "package_state").filter((e) => e.package === pkg).map((e) => `${e.state}${e.round}`);
const CLI = path.join(PKG_ROOT, "dist", "cli.js");
const cli = (args: string[], env: NodeJS.ProcessEnv = {}): ReturnType<typeof runProcess> => runProcess({ exe: process.execPath, args: [CLI, ...args], env: { ...process.env, ...env }, timeoutMs: 90_000 });
const promptsOf = (b: FakeBuilder, pkg: string): string[] => b.calls.filter((c) => c.req.meta?.role === "builder" && c.req.meta?.package === pkg).map((c) => c.req.prompt);
const SNAPSHOT3 = path.join(REPO_ROOT, "site", "_engine_snapshot3");
const MARBLE_JOB = path.join(REPO_ROOT, "site", "marble-run-three-marbles-20261110-2");

const MAIN_V2 = 'extends Node\n\nvar _ctx\nvar _score := {"left": 0, "right": 0}\nvar _rally := 0\n\nfunc _pack_setup(ctx) -> void:\n\t_ctx = ctx\n\nfunc _pack_start() -> void:\n\t_rally = 0\n\nfunc _pack_tick(frame: int) -> void:\n\t_rally = frame * 2\n\nfunc _pack_state() -> Dictionary:\n\treturn {"score": _score, "rally": _rally, "big_ball": true}\n';
const COURT_GD = "extends RefCounted\n\nstatic func build(ctx, layout: Dictionary) -> void:\n\tfor wall in layout.get(\"walls\", []):\n\t\tpass\n";
const AI_GD = "extends RefCounted\n\nfunc decide(ball_y: float, paddle_y: float, tuning: Dictionary) -> float:\n\treturn signf(ball_y - paddle_y)\n";
const AI_JSON = '{\n "reaction_frames": 8,\n "max_speed_mps": 6,\n "error_m": 0.3\n}\n';
const coreRound2 = (body = MAIN_V2): FakeStep => ({ match: { role: "builder", package: "core", round: 2 }, write: { "scripts/main.gd": body }, text: "Changed scripts/main.gd.\nDEVIATIONS: _pack_state() now also returns big_ball." });
const criticStep = (attempt: number, ok: boolean, note: string, pkg?: string): FakeStep => ({
  match: { role: "critic", attempt },
  json: { ok, scores: { silhouette: 0.8, readability: ok ? 0.8 : 0.4, style_consistency: 0.7, shows_play: 0.7 }, notes: [note], ...(pkg !== undefined ? { package: pkg } : {}) },
});

function request(jobDir: string, text: string, pkg?: string): number {
  const log = JobLog.open(jobDir);
  try {
    return log.append({ type: "change_requested", text, ...(pkg !== undefined ? { package: pkg } : {}) }).seq;
  } finally {
    log.close();
  }
}

/** Runs the fixture job to `done` (promotion under the job directory) and returns the number of events it took. */
async function runToDone(job: TempJob, first: FakeStep[] = [], opts: Parameters<typeof foremanFor>[1] = {}): Promise<number> {
  const s = await foremanFor(job, { promoteTo: "job", script: scriptWith(first), ...opts }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  return s.lastSeq;
}

// ---------------------------------------------------------------- 1. change request

test("1 change: a request on a DONE job re-opens the named package, runs one round of it, verifies its dependants again without rebuilding them, and promotes a second pack beside the first", async () => {
  const job = tempJob("change-done");
  const before = await runToDone(job);
  const firstPack = path.join(job.jobDir, "promoted", "game.paddle_court");
  assert.equal(JSON.parse(fs.readFileSync(path.join(firstPack, "pack.json"), "utf8")).version, "0.1.0");
  const text = "Make the ball twice as big and count the rally twice as fast.";
  const seq = request(job.jobDir, text, "core");
  assert.equal(seq, before + 1);

  const { foreman, builder } = foremanFor(job, { promoteTo: "job", script: scriptWith([coreRound2()]) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  const later = evs.filter((e) => e.seq > before);
  assert.deepEqual(later.slice(0, 4).map((e) => e.type), ["change_requested", "job_state", "reopened", "package_state"]);
  assert.match((later[1] as Extract<JobEvent, { type: "job_state" }>).reason ?? "", /reopened by a change request \(was done\)/);
  const re = ofType(later, "reopened");
  assert.equal(re.length, 1);
  assert.equal(re[0]?.package, "core");
  assert.match(re[0]?.reason ?? "", new RegExp(`^change request \\(event ${seq}\\); the request names the package: Make the ball twice as big`));
  const queued = later[3] as Extract<JobEvent, { type: "package_state" }>;
  assert.deepEqual([queued.package, queued.state, queued.round], ["core", "queued", 2]);
  assert.ok((queued.detail ?? "").startsWith(`${CHANGE_ROUND}: ${text}`));
  // A round of the owner, and only of the owner.
  assert.deepEqual(states(later, "core"), ["queued2", "running2", "verifying2", "promoted2"]);
  assert.deepEqual(ofType(later, "builder_run").map((e) => `${e.package}/${e.round}`), ["core/2"]);
  assert.deepEqual(states(later, "court"), []);
  assert.deepEqual(states(later, "paddle_ai"), []);
  // The dependants are verified again, on the merged pack, after the owner's merge.
  const mergeAt = ofType(later, "merge").find((e) => e.package === "core")?.seq ?? 0;
  assert.ok(mergeAt > 0);
  const again = ofType(later, "verify").filter((e) => e.package !== undefined && e.package !== "core");
  assert.deepEqual(again.map((e) => `${e.package}:${e.verb}:${e.ok}`), ["court:lint:true", "court:smoke:true", "paddle_ai:lint:true", "paddle_ai:smoke:true", "paddle_ai:bot:true"]);
  assert.ok(again.every((e) => e.seq > mergeAt && /-reverify-/.test(e.report)));
  // The brief of the re-opened package carries the request.
  const prompt = promptsOf(builder, "core")[0] ?? "";
  assert.match(prompt, /## Change requests from the player[^]*1\. Make the ball twice as big/);
  assert.match(prompt, /This package was finished and merged\. The player now asks for a change[^]*CHANGE REQUEST: Make the ball twice as big/);
  assert.match(prompt, /# Round 2 of 5/, "the round limit counts from the re-opening (4 rounds from round 2)");
  // The pack that is promoted again is photographed first (the fixture declares the camera `hero`): no critic call.
  const shots = ofType(later, "note").find((n) => n.text.startsWith(`${FOREMAN_NOTE}pictures of the pack as it is promoted the 2nd time`));
  assert.match(shots?.text ?? "", /captures\/promotion2-hero-f\d+\.png, captures\/promotion2-hero-f\d+\.png$/);
  for (const f of (shots?.text ?? "").split(": ").at(-1)?.split(", ") ?? []) assert.ok(fs.existsSync(path.join(job.jobDir, f)), f);
  assert.equal(ofType(later, "builder_run").filter((e) => e.package === undefined).length, 0);
  // A second promotion, beside the first.
  const promos = ofType(evs, "promoted");
  assert.deepEqual(promos.map((p) => `${p.version} ${p.dest}`), ["0.1.0 promoted/game.paddle_court", "0.1.1 promoted/game.paddle_court@0.1.1"]);
  const secondPack = path.join(job.jobDir, "promoted", "game.paddle_court@0.1.1");
  assert.equal(JSON.parse(fs.readFileSync(path.join(secondPack, "pack.json"), "utf8")).version, "0.1.1");
  assert.equal(fs.readFileSync(path.join(secondPack, "scripts", "main.gd"), "utf8"), MAIN_V2);
  assert.equal(JSON.parse(fs.readFileSync(path.join(firstPack, "pack.json"), "utf8")).version, "0.1.0", "the earlier promotion is untouched");
  assert.notEqual(fs.readFileSync(path.join(firstPack, "scripts", "main.gd"), "utf8"), MAIN_V2);
  assert.match(later[later.length - 1]?.type === "job_state" ? ((later[later.length - 1] as Extract<JobEvent, { type: "job_state" }>).reason ?? "") : "", /promotion 2 of this job; the earlier one is kept/);
  // Derived state agrees, and a further run changes nothing.
  const st = rebuildState(job.jobDir, { write: false });
  assert.deepEqual(st.changes, [{ seq, text, package: "core", owner: "core", state: "reopened" }]);
  assert.equal(st.promotions.length, 2);
  assert.equal(st.packages["core"]?.roundBase, 2);
  assert.deepEqual(st.packages["core"]?.changes, [text]);
  const n = evs.length;
  await foremanFor(job, { promoteTo: "job" }).foreman.run();
  assert.equal(readEvents(job.jobDir).length, n);
});

test("1 change: without --package the Planner is asked which package owns the problem (one short generate call); no usable answer falls back to the root and says so", async () => {
  const job = tempJob("change-owner");
  const before = await runToDone(job);
  const seq = request(job.jobDir, "The walls are too low: the ball flies over them.");
  const owner: FakeStep = { match: { role: "planner", promptIncludes: "The player's change request" }, json: { package: "court", reason: "the walls are built by the court package" } };
  const courtRound2: FakeStep = { match: { role: "builder", package: "court", round: 2 }, write: { "data/court.json": '{\n "width_m": 16,\n "depth_m": 9,\n "wall_height_m": 2.4,\n "walls": ["north", "south"],\n "goals": ["west", "east"]\n}\n', "scripts/court.gd": COURT_GD }, text: "Raised the walls.\nDEVIATIONS: wall_height_m is 2.4, not 1.2." };
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", script: scriptWith([owner, courtRound2]) });
  assert.equal((await foreman.run()).jobState?.state, "done");
  const later = readEvents(job.jobDir).filter((e) => e.seq > before);
  const ask = builder.calls.filter((c) => c.req.meta?.role === "planner");
  assert.equal(ask.length, 1);
  assert.equal(ask[0]?.req.mode, "generate");
  assert.match(ask[0]?.req.prompt ?? "", /- core \(blockout, the root\): [^\n]*Files: scripts\/main\.gd, tests\/bot_rally\.gd\n- court \(blockout, depends on core\): [^\n]*Files: data\/court\.json, scripts\/court\.gd/);
  assert.equal(ofType(later, "builder_run").filter((e) => e.package === undefined && e.mode === "generate").length, 1, "the owner question is a job-level builder_run in the log");
  const re = ofType(later, "reopened");
  assert.deepEqual(re.map((e) => e.package), ["court"]);
  assert.match(re[0]?.reason ?? "", new RegExp(`^change request \\(event ${seq}\\); the Planner names the package: the walls are built by the court package`));
  assert.deepEqual(states(later, "court"), ["queued2", "running2", "verifying2", "promoted2"]);
  assert.equal(ofType(later, "verify").filter((e) => /-reverify-/.test(e.report)).length, 0, "court has no dependants");
  assert.equal(ofType(later, "promoted")[0]?.dest, "promoted/game.paddle_court@0.1.1");

  // No usable answer (a package that does not exist, twice): the root takes it, and the reason says so.
  const job2 = tempJob("change-owner-none");
  const before2 = await runToDone(job2);
  request(job2.jobDir, "Something is off.");
  const lost: FakeStep = { match: { role: "planner", promptIncludes: "The player's change request" }, json: { package: "ghost", reason: "?" } };
  assert.equal((await foremanFor(job2, { promoteTo: "job", script: scriptWith([lost, coreRound2()]) }).foreman.run()).jobState?.state, "done");
  const later2 = readEvents(job2.jobDir).filter((e) => e.seq > before2);
  assert.equal(ofType(later2, "builder_run").filter((e) => e.package === undefined).length, 2, "asked twice, both in the log");
  assert.equal(ofType(later2, "reopened")[0]?.package, "core");
  assert.match(ofType(later2, "reopened")[0]?.reason ?? "", /the Planner gave no usable answer[^]*so the root package takes it/);
});

test("1 change: a dependant whose verification now fails is re-opened and rebuilt; one that still passes is left alone", async () => {
  const job = tempJob("change-dep");
  const before = await runToDone(job);
  request(job.jobDir, "The player serves the ball now.", "core");
  const breaksBot = coreRound2(`${MAIN_V2}# FAKE_BOT_NEEDS(serve)\n`);
  const adapts: FakeStep = { match: { role: "builder", package: "paddle_ai", round: 3 }, write: { "data/ai.json": AI_JSON, "scripts/paddle_ai.gd": `${AI_GD}# FAKE_HAS(serve)\n` }, text: "The paddle waits for the serve.\nDEVIATIONS: none" };
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", script: scriptWith([breaksBot, adapts]) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > before);
  const re = ofType(later, "reopened");
  assert.deepEqual(re.map((e) => e.package), ["core", "paddle_ai"]);
  assert.match(re[1]?.reason ?? "", /^its dependency core was changed and merged again, and bot \(V4\) now fails on the merged pack/);
  assert.deepEqual(ofType(later, "builder_run").map((e) => `${e.package}/${e.round}`), ["core/2", "paddle_ai/3"], "court still passes and is not rebuilt");
  assert.deepEqual(states(later, "paddle_ai"), ["queued3", "running3", "verifying3", "promoted3"]);
  const p = promptsOf(builder, "paddle_ai")[0] ?? "";
  assert.ok(p.includes(`${DEP_CHANGED}: package core, which yours depends on, was changed and merged again`));
  assert.match(p, /The Verifier did not pass round 2: bot \(V4\) on your workspace/);
  assert.match(p, /# Round 3 of 6/);
  // The dependant's workspace was brought up to the changed dependency before its builder ran.
  assert.ok(fs.readFileSync(path.join(job.jobDir, "ws", "paddle_ai", "scripts", "main.gd"), "utf8").includes("FAKE_BOT_NEEDS(serve)"));
  assert.equal(ofType(later, "promoted")[0]?.version, "0.1.1");
});

test("1 change: a re-opened package that passes no round keeps its earlier files; the job ends done and says the change was not made", async () => {
  const job = tempJob("change-fails");
  const before = await runToDone(job);
  request(job.jobDir, "Break everything.", "core");
  const bad = (round: number): FakeStep => ({ match: { role: "builder", package: "core", round }, write: { "scripts/main.gd": "extends Node\nfunc _pack_tick(f):\n\tFAKE_SCRIPT_ERROR()\n" }, text: "Done." });
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", roundLimit: 2, script: scriptWith([bad(2), bad(3)]) });
  const s = await foreman.run();
  // The request stays in the package's brief in every later round, not only in the first one's feedback.
  assert.match(promptsOf(builder, "core")[1] ?? "", /# Round 3 of 3/);
  assert.match(promptsOf(builder, "core")[1] ?? "", /## Change requests from the player[^]*1\. Break everything\./);
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  assert.match(s.jobState?.reason ?? "", /no merge since the last promotion/);
  const later = readEvents(job.jobDir).filter((e) => e.seq > before);
  assert.deepEqual(states(later, "core"), ["queued2", "running2", "verifying2", "running3", "verifying3", "promoted3"]);
  assert.match(ofType(later, "package_state").at(-1)?.detail ?? "", /re-opened, but no round passed[^]*the change was NOT made/);
  assert.equal(ofType(later, "merge").length, 0);
  assert.equal(ofType(later, "promoted").length, 0);
  assert.ok(!fs.readFileSync(path.join(job.jobDir, "pack", "scripts", "main.gd"), "utf8").includes("FAKE_SCRIPT_ERROR"));
});

test("1 change: a kill between `reopened` and its `queued` is repaired on resume", async () => {
  const job = tempJob("change-kill");
  const before = await runToDone(job);
  request(job.jobDir, "Bigger ball.", "core");
  class Stop extends Error {}
  await assert.rejects(foremanFor(job, { promoteTo: "job", script: scriptWith([coreRound2()]), afterAppend: (ev) => { if (ev.type === "reopened") throw new Stop("kill"); } }).foreman.run(), Stop);
  assert.equal(readEvents(job.jobDir).at(-1)?.type, "reopened");
  const s = await foremanFor(job, { promoteTo: "job", script: scriptWith([coreRound2()]) }).foreman.run();
  assert.equal(s.jobState?.state, "done");
  const later = readEvents(job.jobDir).filter((e) => e.seq > before);
  assert.equal(ofType(later, "reopened").length, 1, "not re-opened twice");
  assert.deepEqual(states(later, "core"), ["queued2", "running2", "verifying2", "promoted2"]);
  assert.ok((ofType(later, "package_state")[0]?.detail ?? "").startsWith(`${CHANGE_ROUND}: Bigger ball.`));
});

test("1 change: `foreman answer --change=<package>` answers the question AND re-opens that package; the asking package continues after it", async () => {
  const job = tempJob("answer-change");
  const asks: FakeStep[] = [
    { match: { role: "builder", package: "paddle_ai", round: 2, promptIncludes: "Answer to your question" }, write: { "data/ai.json": AI_JSON, "scripts/paddle_ai.gd": AI_GD }, text: "Done.\nDEVIATIONS: none" },
    { match: { role: "builder", package: "paddle_ai", round: 2 }, text: "I cannot do this from my files.\nQUESTION: May core be changed so that the ball is bigger?" },
    coreRound2(),
  ];
  const first = await foremanFor(job, { promoteTo: "job", script: scriptWith(asks) }).foreman.run();
  assert.equal(first.jobState?.state, "paused");
  const out: string[] = [];
  assert.equal(await main(["answer", job.jobDir, "paddle_ai", "Yes. core makes the ball bigger.", "--change", "core"], (l) => out.push(l)), 0);
  assert.match(out.join("\n"), /change request for core recorded as event \d+/);
  const mid = readEvents(job.jobDir);
  assert.deepEqual(mid.slice(-2).map((e) => e.type), ["answer", "change_requested"]);
  assert.equal((mid.at(-1) as Extract<JobEvent, { type: "change_requested" }>).package, "core");
  await assert.rejects(main(["answer", job.jobDir, "paddle_ai", "again", "--change", "core"], () => {}), /no open question/);

  const { foreman, builder } = foremanFor(job, { promoteTo: "job", script: scriptWith(asks) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > first.lastSeq);
  assert.deepEqual(ofType(later, "reopened").map((e) => e.package), ["core"]);
  const runs = ofType(later, "builder_run").map((e) => `${e.package}/${e.round}`);
  assert.deepEqual(runs, ["core/2", "paddle_ai/2"], "the asking package waits for the package it depends on");
  assert.match(promptsOf(builder, "core")[0] ?? "", /CHANGE REQUEST: Yes\. core makes the ball bigger\./);
  assert.match(promptsOf(builder, "paddle_ai")[0] ?? "", /Answer to your question: Yes\. core makes the ball bigger\./);
  assert.ok(fs.readFileSync(path.join(job.jobDir, "ws", "paddle_ai", "scripts", "main.gd"), "utf8").includes("big_ball"), "the asker builds against the changed files");
  assert.equal(s.promotions.length, 1);
});

test("1 change: `foreman change` by command line on a finished fixture job, twice; `status --json` agrees with the log", async () => {
  const job = tempJob("change-cli");
  const scriptFile = path.join(job.jobDir, "fake-builder.json");
  const script = JSON.parse(fs.readFileSync(scriptFile, "utf8")) as { steps: FakeStep[] };
  const owner: FakeStep = { match: { role: "planner", promptIncludes: "The player's change request" }, json: { package: "court", reason: "the court package owns the walls" } };
  const courtRound2: FakeStep = { match: { role: "builder", package: "court", round: 2 }, write: { "scripts/court.gd": `${COURT_GD}# higher walls\n` }, text: "Done.\nDEVIATIONS: none" };
  script.steps = [owner, coreRound2(), courtRound2, ...script.steps].map((s) => ({ ...s, delayMs: 0 }));
  fs.writeFileSync(scriptFile, JSON.stringify(script));
  const early = await cli(["change", job.jobDir, "too early", "--adapter", "fake"]);
  assert.equal(early.exitCode, 2);
  assert.match(early.stderr, /no merged package yet/);
  assert.equal((await cli(["run", job.jobDir, "--adapter", "fake", "--quiet"])).exitCode, 0);
  const unknown = await cli(["change", job.jobDir, "x", "--package", "ghost", "--adapter", "fake"]);
  assert.equal(unknown.exitCode, 2);
  assert.match(unknown.stderr, /unknown package ghost \(the plan has: core, court, paddle_ai\)/);

  const one = await cli(["change", job.jobDir, "Make the ball bigger.", "--package", "core", "--adapter", "fake"]);
  assert.equal(one.exitCode, 0, one.stderr + one.stdout);
  assert.match(one.stdout, /change request recorded as event \d+ for package core/);
  assert.match(one.stdout, /reopened\s+core: change request \(event \d+\); the request names the package/);
  assert.match(one.stdout, /paddle_ai bot V4 ok[^\n]*reverify-bot/);
  assert.match(one.stdout, /promoted\s+game\.paddle_court 0\.1\.1 -> promoted\/game\.paddle_court@0\.1\.1/);
  const two = await cli(["change", job.jobDir, "The walls are too low.", "--adapter", "fake", "--quiet"]);
  assert.equal(two.exitCode, 0, two.stderr + two.stdout);

  const evs = readEvents(job.jobDir);
  assert.deepEqual(ofType(evs, "change_requested").map((e) => e.package ?? "-"), ["core", "-"]);
  assert.deepEqual(ofType(evs, "reopened").map((e) => e.package), ["core", "court"]);
  assert.deepEqual(ofType(evs, "promoted").map((e) => e.dest), ["promoted/game.paddle_court", "promoted/game.paddle_court@0.1.1", "promoted/game.paddle_court@0.1.2"]);
  for (const d of ofType(evs, "promoted").map((e) => e.dest)) assert.ok(fs.existsSync(path.join(job.jobDir, d, "pack.json")), d);
  const status = await cli(["status", job.jobDir, "--json"]);
  const st = JSON.parse(status.stdout) as JobState;
  assert.equal(st.jobState?.state, "done");
  assert.deepEqual(st.changes.map((c) => `${c.state}:${c.owner}`), ["reopened:core", "reopened:court"]);
  assert.equal(st.promotions.length, 3);
  assert.equal(st.promoted?.dest, "promoted/game.paddle_court@0.1.2");
  assert.deepEqual([st.packages["core"]?.round, st.packages["court"]?.round, st.packages["paddle_ai"]?.round], [2, 2, 2]);
  const table = await cli(["status", job.jobDir]);
  assert.match(table.stdout, /change\s+#\d+ reopened -> core: Make the ball bigger\./);
  assert.match(table.stdout, /promotion 3; earlier: 0\.1\.0 promoted\/game\.paddle_court, 0\.1\.1 promoted\/game\.paddle_court@0\.1\.1/);
  // --no-run only records.
  const rec = await cli(["change", job.jobDir, "later", "--package", "core", "--no-run"]);
  assert.equal(rec.exitCode, 0);
  assert.equal(readEvents(job.jobDir).at(-1)?.type, "change_requested");
  assert.equal(rebuildState(job.jobDir, { write: false }).changes.at(-1)?.state, "pending");
});

// ---------------------------------------------------------------- 2. the critic names the package

/** The fixture job with paddle_ai as an art package (milestone art_pass). */
function artJob(label: string): TempJob {
  const job = tempJob(label);
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  const plan = JSON.parse(lines[3] as string) as { packages: PackageSpec[] };
  for (const p of plan.packages) if (p.id === "paddle_ai") p.milestone = "art_pass";
  lines[3] = JSON.stringify(plan);
  fs.writeFileSync(file, lines.map((l) => l + "\n").join(""));
  return job;
}

test("2 critic: it names the ROOT package while an art package has just merged: the extra round runs on the root, the art package is only verified again, and the milestone is written after the second look", async () => {
  const job = artJob("critic-names");
  const steps = [criticStep(1, true, "a clear court"), criticStep(2, false, "the ball is a dot: the court is far too wide for it", "core"), criticStep(3, true, "the ball reads now"), coreRound2()];
  const { foreman, builder } = foremanFor(job, { critic: true, promoteTo: "job", script: scriptWith(steps) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  const re = ofType(evs, "reopened");
  assert.equal(re.length, 1);
  assert.equal(re[0]?.package, "core");
  assert.ok((re[0]?.reason ?? "").startsWith(`${CRITIC_ROUND} (milestone art_pass): the critic names this package`), re[0]?.reason);
  assert.match(re[0]?.reason ?? "", /the milestone's own package\(s\): paddle_ai/);
  // The round runs on the root; the art package that had just merged gets no round.
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "promoted1", "queued2", "running2", "verifying2", "promoted2"]);
  assert.equal(states(evs, "paddle_ai").at(-1), "promoted2");
  assert.ok(!states(evs, "paddle_ai").includes("queued3"));
  const sentBack = ofType(evs, "package_state").find((e) => e.package === "core" && e.state === "queued" && e.round === 2);
  assert.ok((sentBack?.detail ?? "").startsWith(CRITIC_ROUND));
  assert.match(promptsOf(builder, "core")[1] ?? "", /sent back: critic \(V5\) NOT ok, one extra round: [^\n]*the ball is a dot: the court is far too wide for it/);
  // The critic was given the package list with the files each owns.
  const criticPrompts = builder.calls.filter((c) => c.req.meta?.role === "critic").map((c) => c.req.prompt);
  assert.equal(criticPrompts.length, 3);
  assert.match(criticPrompts[1] ?? "", /# The packages this pack is built from[^]*- core \(blockout, the root\): [^\n]*Files: scripts\/main\.gd, tests\/bot_rally\.gd[^]*- paddle_ai \(art_pass, depends on core\): [^\n]*Files: data\/ai\.json, scripts\/paddle_ai\.gd/);
  const critique = fs.readdirSync(path.join(job.jobDir, "reports")).filter((f) => /^critic-art_pass-s\d+\.json$/.test(f)).sort();
  assert.equal(JSON.parse(fs.readFileSync(path.join(job.jobDir, "reports", critique[0] as string), "utf8")).package, "core");
  // After the root's second merge its dependants are verified again; then the milestone is written, once.
  const mergeAt = ofType(evs, "merge").filter((e) => e.package === "core")[1]?.seq ?? 0;
  assert.ok(ofType(evs, "verify").some((e) => e.package === "paddle_ai" && e.seq > mergeAt && /-reverify-bot/.test(e.report) && e.ok));
  const ms = ofType(evs, "milestone");
  assert.deepEqual(ms.map((m) => m.milestone), ["blockout", "art_pass"]);
  assert.ok((ms[1]?.seq ?? 0) > mergeAt, "the art_pass milestone waits for the round on the root");
  assert.match(ms[1]?.summary ?? "", /critic \(V5\) ok: [^\n]*the ball reads now[^\n]*\(the verdict after the one extra round/);
});

test("2 critic: an unknown or missing package falls back to the milestone's own packages and is logged as a note", async () => {
  for (const [named, why] of [["ghost", /the critic named "ghost", which is not a package of this plan/], [undefined, /the critic named no package/]] as const) {
    const job = artJob(`critic-fallback-${named ?? "none"}`);
    const visible: FakeStep = { match: { role: "builder", package: "paddle_ai", round: 3 }, write: { "data/ai.json": AI_JSON, "scripts/paddle_ai.gd": `${AI_GD}# brighter\n` }, text: "Done." };
    const steps = [criticStep(1, true, "fine"), criticStep(2, false, "too dark", named), criticStep(3, true, "better"), visible];
    const s = await foremanFor(job, { critic: true, promoteTo: "job", script: scriptWith(steps) }).foreman.run();
    assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
    const evs = readEvents(job.jobDir);
    assert.equal(ofType(evs, "reopened").length, 0);
    const note = ofType(evs, "note").find((n) => why.test(n.text));
    assert.ok(note, JSON.stringify(ofType(evs, "note")));
    assert.match(note?.text ?? "", /^\[foreman\] [^]*the critic's extra round goes to the package\(s\) of the art_pass milestone: paddle_ai/);
    assert.deepEqual(states(evs, "paddle_ai").slice(-4), ["queued3", "running3", "verifying3", "promoted3"]);
    assert.ok(!states(evs, "core").includes("queued2"));
  }
});

// ---------------------------------------------------------------- 3. kit use cannot fall silently

const venue = (kinds: string[]): string => JSON.stringify({ width_m: 16, depth_m: 9, wall_height_m: 1.2, props: kinds.map((kind, i) => ({ id: `p${i}`, kind })) }, null, 1) + "\n";
const courtRound = (round: number, kinds: string[], text: string, gd = COURT_GD): FakeStep => ({ match: { role: "builder", package: "court", round }, write: { "data/court.json": venue(kinds), "scripts/court.gd": gd }, text });

test("3 kit: a round that lowers kit use fails with cause kit_regression, is not merged, and the next round gets the figures; the same round with a stated reason passes and the reason is a note", async () => {
  const drop = "Removed the lumber and the crates so the ball reads larger.";
  // Without a reason.
  const job = tempJob("kit-fall");
  const before = await runToDone(job, [courtRound(1, ["barrier_wall", "lumber", "crate"], "Done.\nDEVIATIONS: none")]);
  assert.equal(countKitUse(path.join(job.jobDir, "pack")), 3);
  request(job.jobDir, "Make the ball read larger.", "court");
  const steps = [courtRound(2, ["barrier_wall"], `${drop}\nDEVIATIONS: none`), courtRound(3, ["barrier_wall", "lumber", "crate", "sign"], "Kept the kit parts, moved the camera instead.\nDEVIATIONS: none")];
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", script: scriptWith(steps) });
  assert.equal((await foreman.run()).jobState?.state, "done");
  const later = readEvents(job.jobDir).filter((e) => e.seq > before);
  assert.deepEqual(states(later, "court"), ["queued2", "running2", "verifying2", "failed2", "queued3", "running3", "verifying3", "promoted3"]);
  const failed = ofType(later, "package_state").find((e) => e.package === "court" && e.state === "failed");
  assert.equal(failed?.cause, "kit_regression");
  assert.match(failed?.detail ?? "", /^KIT REGRESSION: kit parts used fell from 3 to 1/);
  assert.equal(ofType(later, "merge").filter((e) => e.package === "court").length, 1, "the regressing round was not merged");
  assert.match(promptsOf(builder, "court")[1] ?? "", /Round 2 passed its checks but was not merged:\nKIT REGRESSION: kit parts used fell from 3 to 1[^]*state it under DEVIATIONS in a line that starts with "KIT:"/);
  assert.equal(countKitUse(path.join(job.jobDir, "pack")), 4);

  // The same round, with the reason stated: it passes, and the reason is recorded.
  const job2 = tempJob("kit-stated");
  const before2 = await runToDone(job2, [courtRound(1, ["barrier_wall", "lumber", "crate"], "Done.\nDEVIATIONS: none")]);
  request(job2.jobDir, "Make the ball read larger.", "court");
  const stated = courtRound(2, ["barrier_wall"], `${drop}\nDEVIATIONS:\n- KIT: lumber and crate props removed, they stood between the camera and the ball.`);
  assert.equal((await foremanFor(job2, { promoteTo: "job", script: scriptWith([stated]) }).foreman.run()).jobState?.state, "done");
  const later2 = readEvents(job2.jobDir).filter((e) => e.seq > before2);
  assert.deepEqual(states(later2, "court"), ["queued2", "running2", "verifying2", "promoted2"]);
  const note = ofType(later2, "note").find((n) => n.text.startsWith(`${FOREMAN_NOTE}kit figures got worse`));
  assert.match(note?.text ?? "", /the builder states why, so the round passes: kit parts used fell from 3 to 1[^]*Stated: - KIT: lumber and crate props removed/);
  assert.equal(countKitUse(path.join(job2.jobDir, "pack")), 1);
});

test("3 kit: a round that raises the lint report's bypass count fails with kit_regression too (also a package's first round); at the round limit a first-time package stays failed with that cause", async () => {
  const byHand = `${COURT_GD}\nfunc _wall() -> void:\n\tvar b = RigidBody3D.new() # FAKE_BYPASS\n`;
  const job = tempJob("kit-bypass");
  const { foreman } = foremanFor(job, { promoteTo: "job", script: scriptWith([courtRound(1, [], "Done.\nDEVIATIONS: none", byHand)]) });
  assert.equal((await foreman.run()).jobState?.state, "done");
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "court").slice(0, 6), ["queued1", "running1", "verifying1", "failed1", "queued2", "running2"]);
  const failed = ofType(evs, "package_state").find((e) => e.package === "court" && e.state === "failed");
  assert.equal(failed?.cause, "kit_regression");
  assert.match(failed?.detail ?? "", /bypasses rose from 0 to 1 \(the pack's lint report, composability\.bypasses; the newest: scripts\/court\.gd:\d+ RigidBody3D\.new\(\)/);
  // Round limit 1: failed for good, cause kit_regression, the job fails (no re-plan allowed here).
  const job2 = tempJob("kit-bypass-limit");
  const s2 = await foremanFor(job2, { promoteTo: "job", roundLimit: 1, script: scriptWith([courtRound(1, [], "Done.\nDEVIATIONS: none", byHand)]) }).foreman.run();
  assert.equal(s2.jobState?.state, "failed");
  assert.equal(s2.packages["court"]?.cause, "kit_regression");
  assert.ok(!fs.existsSync(path.join(job2.jobDir, "pack", "scripts", "court.gd")));
  // What counts as a stated reason.
  assert.equal(statesKitReason("- KIT: built the net by hand, the kit has none"), true);
  assert.equal(statesKitReason("The net is a RigidBody3D.new() because no primitive fits", ["RigidBody3D.new()"]), true);
  assert.equal(statesKitReason("wall_height_m is 2.4, not 1.2"), false);
  assert.equal(statesKitReason(undefined), false);
});

test("3 kit: a kit regression in the critic's extra round gets exactly one more round; if that fails too, the earlier files stay and the job goes on; --no-kit-gate (kitGate: false) switches the comparison off", async () => {
  const withKit = (n: number, extra = ""): string => `${MAIN_V2}${Array.from({ length: n }, (_, i) => `# part ${i}\nvar p${i} = TLKit.build("lumber", {})\n`).join("")}${extra}`;
  const core = (round: number, body: string, text = "Done.\nDEVIATIONS: none"): FakeStep => ({ match: { role: "builder", package: "core", round }, write: { "scripts/main.gd": body }, text });
  const critics = [criticStep(1, true, "fine"), criticStep(2, false, "the ball is a dot", "core"), criticStep(3, false, "still a dot")];
  const job = artJob("kit-critic");
  // Round 1 uses three kit parts; the critic's round (2) drops them all; the one more round (3) breaks smoke.
  const fixtureCore = scriptWith().steps.find((x) => x.match?.package === "core")?.write ?? {};
  const first: FakeStep = { ...core(1, withKit(3)), write: { ...fixtureCore, "scripts/main.gd": withKit(3) } };
  const steps = [...critics, first, core(2, withKit(0)), core(3, withKit(3, "func _x():\n\tFAKE_SCRIPT_ERROR()\n")), core(4, withKit(3))];
  const s = await foremanFor(job, { critic: true, promoteTo: "job", script: scriptWith(steps) }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "core").slice(4), ["queued2", "running2", "verifying2", "failed2", "queued3", "running3", "verifying3", "promoted3"]);
  const kept = ofType(evs, "package_state").filter((e) => e.package === "core").at(-1);
  assert.match(kept?.detail ?? "", /re-opened, but no round passed \(smoke \(V2\)[^]*the files merged before it stay in pack\/ and the change was NOT made/);
  assert.equal(countKitUse(path.join(job.jobDir, "pack")), 3, "the pack still uses the three kit parts of round 1");
  assert.equal(ofType(evs, "merge").filter((e) => e.package === "core").length, 1);
  assert.deepEqual(ofType(evs, "milestone").map((m) => m.milestone), ["blockout", "art_pass"]);
  // The same job with the comparison switched off: the critic's round merges although kit use fell.
  const job2 = artJob("kit-off");
  const s2 = await foremanFor(job2, { critic: true, promoteTo: "job", kitGate: false, script: scriptWith(steps) }).foreman.run();
  assert.equal(s2.jobState?.state, "done");
  assert.ok(!ofType(readEvents(job2.jobDir), "package_state").some((e) => e.cause === "kit_regression"));
  assert.equal(countKitUse(path.join(job2.jobDir, "pack")), 0);
});

test("3 kit: the figures of the real marble pack can be counted (the lint report has `composability`, not `metrics`)", { skip: !fs.existsSync(path.join(MARBLE_JOB, "pack")) ? "the second real job's directory is not in site/" : false }, () => {
  assert.ok(countKitUse(path.join(MARBLE_JOB, "pack")) >= 8, "8 `kind` entries in data/ plus the TLKit calls");
  const lint = JSON.parse(fs.readFileSync(path.join(MARBLE_JOB, "reports", "final-lint-s121.json"), "utf8")) as { metrics?: unknown; composability?: { bypasses?: unknown[]; kit_parts_added?: number } };
  assert.equal(lint.metrics, undefined);
  assert.ok(Array.isArray(lint.composability?.bypasses));
});

// ---------------------------------------------------------------- 4. runner options from the engine

test("4 verbs: the option list is read from kernel/runner/verbs.json; `--bot-frames` with `invariants` passes the plan check, an option of another verb does not", () => {
  const plan = fixturePlan();
  const withBotFrames = plan.map((p) => (p.id === "core" ? { ...p, acceptance: [...p.acceptance, { level: "V3" as const, verb: "invariants" as const, args: ["--seed=1", "--bot-frames=4000"] }] } : p));
  assert.deepEqual(planCheck(withBotFrames, { verbs: VERBS }), []);
  assert.deepEqual(acceptanceOptions(VERBS, "invariants"), ["seed", "frames", "bot-frames"]);
  assert.equal(acceptanceOptions(VERBS, "capture"), undefined);
  const wrong = plan.map((p) => (p.id === "core" ? { ...p, acceptance: [{ level: "V2" as const, verb: "smoke" as const, args: ["--bot-frames=4000"] }] } : p));
  assert.match(planCheck(wrong, { verbs: VERBS }).join("\n"), /smoke does not take --bot-frames \(allowed: --seed, --frames; from [^)]*verbs\.json\)/);
  // A list with a new option is obeyed without a code change.
  const more = structuredClone(VERBS);
  (more.verbs["smoke"] as { options: Record<string, { type: string }> }).options["wind"] = { type: "int" };
  const windy = plan.map((p) => (p.id === "core" ? { ...p, acceptance: [{ level: "V2" as const, verb: "smoke" as const, args: ["--wind=3"] }] } : p));
  assert.deepEqual(planCheck(windy, { verbs: more }), []);
  assert.notDeepEqual(planCheck(windy, { verbs: VERBS }), []);
  // The Planner prompt prints the list from the file.
  const text = renderPlannerPrompt({ sentence: "s", packId: "game.x", title: "X", brief: { rules: "r", arena: "a", ai: "i", controls: "c", mood: "m" }, packContract: "(c)" }, { verbs: VERBS });
  assert.match(text, /- `invariants` \(V3\): `--seed=<int>` \(default 1\), `--frames=<int>` \(default 3600\), `--bot-frames=<int>` \(default 36000\)/);
  assert.match(text, /- `bot` \(V4\): [^\n]*`--test=<string>` \(required: `--test=tests\/<file>\.gd`\)/);
  // No copy of the list is left in the sources.
  for (const f of ["designer.ts", "foreman.ts", "cli.ts", path.join("testing", "fake-runner-core.ts")]) {
    const src = fs.readFileSync(path.join(PKG_ROOT, "src", f), "utf8");
    assert.ok(!/ACCEPTANCE_OPTIONS|\["pack", "report", "seed", "frames"/.test(src), f);
  }
});

test("4 verbs: the second real job's FIRST Planner output (it used --bot-frames=4000 and was refused) is accepted now", { skip: !fs.existsSync(path.join(MARBLE_JOB, "reports", "planner-a1-s6.json")) || !fs.existsSync(SNAPSHOT3) ? "site/marble-run-three-marbles-20261110-2 or site/_engine_snapshot3 is not there" : false }, () => {
  const t = JSON.parse(fs.readFileSync(path.join(MARBLE_JOB, "reports", "planner-a1-s6.json"), "utf8")) as { problems: string[]; result: { json: { packages: PackageSpec[] } } };
  assert.ok(t.problems.every((p) => /--bot-frames=4000" is not a plain --key=value/.test(p)) && t.problems.length === 3, "this is the answer the Foreman refused on 2026-11-10");
  const packages = t.result.json.packages;
  assert.ok(packages.some((p) => p.acceptance.some((a) => a.verb === "invariants" && a.args.includes("--bot-frames=4000"))));
  assert.deepEqual(planCheck(packages, { maxPackages: 3, verbs: loadVerbs(SNAPSHOT3) }), []);
  assert.deepEqual(planCheck(packages, { maxPackages: 3, verbs: VERBS }), []);
  // The fake runner's verbs file is the engine's file, word for word.
  assert.deepEqual(readVerbsFile(FAKE_VERBS_FILE).verbs, loadVerbs(SNAPSHOT3).verbs);
});

test("4 verbs: a missing or unreadable verbs.json is a clear error at start (run, plan), not a fallback; the fake runner takes --bot-frames from the same list", async () => {
  const empty = tempDir("engine-empty");
  assert.throws(() => loadVerbs(empty), (e: unknown) => e instanceof VerbsError && /the runner's option list cannot be read: [^\n]*kernel\/runner\/verbs\.json \(ENOENT\)[^]*TL_ENGINE_DIR/.test(e.message));
  fs.mkdirSync(path.join(empty, "kernel", "runner"), { recursive: true });
  fs.writeFileSync(path.join(empty, "kernel", "runner", "verbs.json"), "{ not json");
  assert.throws(() => loadVerbs(empty), /is not JSON/);
  fs.writeFileSync(path.join(empty, "kernel", "runner", "verbs.json"), JSON.stringify({ schema: "tl.verbs/2", verbs: {} }));
  assert.throws(() => loadVerbs(empty), /is not a tl\.verbs\/1 file/);

  // A real (non-fake) runner with an engine that has no list: the run stops before a single event is written.
  const job = tempJob("verbs-missing");
  const real = new Verifier({ godot: path.join(job.root, "no-such-godot.exe"), engineDir: job.engineDir });
  assert.throws(() => verbsFor(real.location), VerbsError);
  const n = readEvents(job.jobDir).length;
  await assert.rejects(new Foreman({ jobDir: job.jobDir, builder: new FakeBuilder(scriptWith()), verifier: real, packContract: "(c)" }).run(), VerbsError);
  assert.equal(readEvents(job.jobDir).length, n);
  fs.rmSync(path.join(job.jobDir, "foreman.config.json"));
  const planFile = path.join(job.root, "plan.json");
  fs.writeFileSync(planFile, JSON.stringify({ packages: fixturePlan() }));
  const env = { TL_GODOT: path.join(job.root, "no-such-godot.exe"), TL_ENGINE_DIR: job.engineDir };
  for (const args of [["plan", job.jobDir, "--from", planFile, "--no-reference"], ["run", job.jobDir, "--adapter", "fake"]]) {
    const r = await cli(args, env);
    assert.equal(r.exitCode, 2, args.join(" "));
    assert.match(r.stderr, /^VerbsError: the runner's option list cannot be read: [^\n]*verbs\.json/);
  }

  // The fake runner obeys the same file: a job whose plan uses invariants --bot-frames runs to done.
  const job2 = tempJob("verbs-botframes");
  const file = path.join(job2.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  const plan = JSON.parse(lines[3] as string) as { packages: PackageSpec[] };
  (plan.packages[0] as PackageSpec).acceptance.push({ level: "V3", verb: "invariants", args: ["--seed=1", "--bot-frames=4000"] });
  lines[3] = JSON.stringify(plan);
  fs.writeFileSync(file, lines.map((l) => l + "\n").join(""));
  const s = await foremanFor(job2, { promoteTo: "job" }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  assert.ok(readEvents(job2.jobDir).some((e) => e.type === "verify" && e.package === "core" && e.verb === "invariants" && e.ok));
});

// ---------------------------------------------------------------- 5. follow

test("5 follow: on a job that another process is writing, every event is printed exactly once, as one JSON line, and follow exits 0 at the terminal state", async () => {
  const job = tempJob("follow-live");
  const following = cli(["follow", job.jobDir, "--poll-ms", "15"]);
  await new Promise((r) => setTimeout(r, 300));
  const run = await cli(["run", job.jobDir, "--adapter", "fake", "--quiet"]);
  assert.equal(run.exitCode, 0, run.stderr + run.stdout);
  const f = await following;
  assert.equal(f.exitCode, 0, f.stderr);
  const printed = f.stdout.split(/\r?\n/).filter(Boolean);
  const inFile = fs.readFileSync(path.join(job.jobDir, "job.jsonl"), "utf8").split("\n").filter(Boolean);
  assert.deepEqual(printed, inFile, "the same lines, in order, once each");
  assert.ok(printed.length > 40);
  assert.ok(!fs.existsSync(path.join(job.jobDir, "foreman.lock")), "follow holds no lock (and the run released its own)");
  // --from: only what comes after, and a job that is already finished ends at once.
  const tail = await cli(["follow", job.jobDir, "--from", String(inFile.length - 3)]);
  assert.equal(tail.exitCode, 0);
  assert.deepEqual(tail.stdout.split(/\r?\n/).filter(Boolean), inFile.slice(-3));
  // --from the last event of a finished job: it waits for what a change request will append (here: gives up idle).
  const idle = await cli(["follow", job.jobDir, "--from", String(inFile.length), "--idle-ms", "400", "--poll-ms", "20"]);
  assert.equal(idle.exitCode, 4);
  assert.equal(idle.stdout.trim(), "");
});

test("5 follow: a torn last line is waited for and never printed; when the writer cuts it off and writes on, nothing is lost or repeated", async () => {
  const dir = tempDir("follow-torn");
  const file = path.join(dir, "job.jsonl");
  const ev = (seq: number, body: object): string => JSON.stringify({ v: 1, seq, ts: "2026-11-11T00:00:00.000Z", job: "j-20261111-1", ...body }) + "\n";
  const head = ev(1, { type: "job_created", sentence: "s", packId: "game.x", title: "X" }) + ev(2, { type: "job_state", state: "running", reason: "started" });
  fs.writeFileSync(file, head + '{"v":1,"seq":3,"ts":"2026-11-11T00:00:0');
  const out: string[] = [];
  const done = followLog(file, { pollMs: 10, out: (l) => out.push(l) });
  await new Promise((r) => setTimeout(r, 120));
  assert.equal(out.length, 2, "the torn third line is not printed");
  // The writer opens the log: the torn tail is cut off, and the events are written again, whole.
  fs.truncateSync(file, Buffer.byteLength(head));
  fs.appendFileSync(file, ev(3, { type: "job_state", state: "paused", reason: "waiting" }));
  await new Promise((r) => setTimeout(r, 80));
  assert.equal(out.length, 3, "paused is not a terminal state: follow goes on");
  fs.appendFileSync(file, ev(4, { type: "job_state", state: "running", reason: "resumed" }) + ev(5, { type: "job_state", state: "failed", reason: "x" }));
  assert.equal(await done, 0);
  assert.deepEqual(out.map((l) => (JSON.parse(l) as { seq: number }).seq), [1, 2, 3, 4, 5]);
});

// ---------------------------------------------------------------- 6. params and the other optional manifest fields

test("6 params: the builder prompt tells builders to declare tunable values in pack.json `params` and to keep them in data/; the kit rule and the KIT: line are there too", () => {
  const job = tempJob("prompt-n3");
  const { foreman } = foremanFor(job, {});
  const prompts = foreman.previewBuilderPrompts();
  assert.equal(prompts.length, 3);
  for (const p of prompts) {
    assert.match(p.prompt, /`params`: \*\*declare what a player may tune\.\*\*[^]*JSON file of yours under `data\/`[^]*do NOT write such values as constants in a script[^]*\{"name", "file", "path", "min", "max", "step", "label"\}/);
    assert.match(p.prompt, /5 optional fields of `pack\.json` are yours to write \(`footprint`, `params`, `on_leave`, `subject`, `moments`\)/);
    assert.ok(!p.prompt.includes("{{"), "no placeholder is left in the prompt");
    assert.match(p.prompt, /\*\*Kit use is measured every round\.\*\*[^]*starts with `KIT:`/);
  }
});

test("6 manifest: params, subject, moments, footprint and on_leave written by a builder are carried through merges, other packages' workspaces and the promotion; any other edit of pack.json is still undone", async () => {
  const job = tempJob("carried");
  const inner = new FakeBuilder(scriptWith());
  const add = (cwd: string, change: (m: Record<string, unknown>) => void): void => {
    const file = path.join(cwd, "pack.json");
    const m = JSON.parse(fs.readFileSync(file, "utf8")) as Record<string, unknown>;
    change(m);
    fs.writeFileSync(file, JSON.stringify(m, null, 1));
  };
  const wall = { name: "wall_height", file: "data/court.json", path: "wall_height_m", min: 0.5, max: 3, step: 0.1, label: "Wall height" };
  const speed = { name: "ai_speed", file: "data/ai.json", path: "max_speed_mps", min: 1, max: 12, step: 0.5, label: "Opponent speed" };
  const seen: Record<string, unknown> = {};
  const builder: Builder = {
    name: "fake",
    probe: () => inner.probe(),
    run: async (req) => {
      const pkg = req.meta?.package;
      if (req.mode === "edit" && pkg === "paddle_ai") seen["paddle_ai"] = (JSON.parse(fs.readFileSync(path.join(req.cwd, "pack.json"), "utf8")) as Record<string, unknown>)["params"];
      const res = await inner.run(req);
      if (req.mode === "edit" && pkg === "court") {
        add(req.cwd, (m) => {
          m["params"] = [wall];
          m["subject"] = "Ball";
          m["moments"] = [{ name: "first_goal", event: "goal" }];
          m["footprint"] = { size_m: [16, 9], height_m: 4 };
          m["on_leave"] = "bot";
        });
      }
      if (req.mode === "edit" && pkg === "paddle_ai" && req.meta?.round === 2) {
        add(req.cwd, (m) => {
          m["params"] = [...((m["params"] as unknown[] | undefined) ?? []), speed];
          m["title"] = "My Own Title";
        });
      }
      return res;
    },
  };
  const s = await foremanFor(job, { promoteTo: "job", builder: builder as unknown as FakeBuilder }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const want = { params: [wall, speed], subject: "Ball", moments: [{ name: "first_goal", event: "goal" }], footprint: { size_m: [16, 9], height_m: 4 }, on_leave: "bot" };
  for (const dir of ["pack", path.join("promoted", "game.paddle_court")]) {
    const m = JSON.parse(fs.readFileSync(path.join(job.jobDir, dir, "pack.json"), "utf8")) as Record<string, unknown>;
    for (const [k, v] of Object.entries(want)) assert.deepEqual(m[k], v, `${dir}: ${k}`);
    assert.equal(m["title"], "Paddle Court", "a key the builder does not own is put back");
    assert.deepEqual(m["tests"], ["tests/bot_rally.gd"]);
  }
  assert.deepEqual(seen["paddle_ai"], [wall], "a later package finds the earlier package's params in its workspace manifest");
  const evs = readEvents(job.jobDir);
  const verifying = (pkg: string, round: number): string => ofType(evs, "package_state").find((e) => e.package === pkg && e.state === "verifying" && e.round === round)?.detail ?? "";
  assert.ok(!verifying("court", 1).includes("pack.json"), "writing only the five fields is not a scope violation");
  assert.match(verifying("paddle_ai", 2), /pack\.json \(edited by the builder; the Foreman's composed manifest was put back\)/);
  assert.match(verifying("core", 1), /pack\.json \(edited by the builder/);
});

test("6 manifest: the three-way merge keeps another package's entries when a stale workspace adds its own", () => {
  const a = { name: "a", v: 1 };
  const b = { name: "b", v: 1 };
  const c = { name: "c", v: 1 };
  assert.deepEqual(mergeCarried({ params: [a] }, { params: [a, b] }, { params: [a, c] }), { params: [a, c, b] });
  assert.deepEqual(mergeCarried({ params: [a] }, { params: [a] }, { params: [a, c], subject: "Puck" }), { params: [a, c], subject: "Puck" });
  assert.deepEqual(mergeCarried({ params: [a, b] }, { params: [b] }, { params: [a, b, c] }), { params: [b, c] });
  assert.deepEqual(mergeCarried({ params: [a] }, { params: [{ name: "a", v: 2 }] }, { params: [a, c] }), { params: [{ name: "a", v: 2 }, c] });
  assert.deepEqual(mergeCarried({}, { on_leave: "pause" }, { on_leave: "bot" }), { on_leave: "pause" });
  assert.deepEqual(mergeCarried({ subject: "Ball" }, {}, { subject: "Ball" }), {});
});

// ---------------------------------------------------------------- the reducer

test("events: change_requested and reopened are strict events; kit_regression is a cause; state.json carries changes, promotions and the re-open round", () => {
  const dir = tempDir("n3-events");
  const log = JobLog.open(dir);
  try {
    log.append({ type: "job_created", sentence: "s", packId: "game.x", title: "X" });
    log.append({ type: "plan_set", packages: fixturePlan() });
    assert.throws(() => log.append({ type: "change_requested", text: "" }), /text/);
    assert.throws(() => log.append({ type: "change_requested", text: "t", package: "ghost" }), /names package "ghost"/);
    assert.throws(() => log.append({ type: "reopened", package: "core" } as never), /missing key "reason"/);
    log.append({ type: "package_state", package: "core", state: "promoted", round: 2 });
    const c = log.append({ type: "change_requested", text: "bigger" });
    assert.equal(log.state.changes[0]?.state, "pending");
    log.append({ type: "reopened", package: "core", reason: `change request (event ${c.seq}); the request names the package: bigger` });
    assert.deepEqual(log.state.changes, [{ seq: c.seq, text: "bigger", owner: "core", state: "reopened" }]);
    assert.equal(log.state.packages["core"]?.roundBase, 3);
    log.append({ type: "reopened", package: "court", reason: "its dependency core was changed" });
    assert.equal(log.state.packages["court"]?.changes, undefined);
    log.append({ type: "package_state", package: "court", state: "failed", round: 1, cause: "kit_regression", detail: "KIT REGRESSION: x" });
    assert.equal(log.state.packages["court"]?.cause, "kit_regression");
    assert.equal(KIT_REGRESSION, "KIT REGRESSION");
  } finally {
    log.close();
  }
});

test("6 manifest: an engine whose manifest check does not know the optional fields (today's engine) is never sent them: the prompt does not ask for them, and a builder's `params` is removed and recorded", async () => {
  // What the engine accepts is read from its kernel/runner/manifest.gd.
  const engine = tempDir("engine-manifest");
  assert.deepEqual(acceptedCarriedFields(engine), [], "no checker source: nothing is accepted");
  fs.mkdirSync(path.join(engine, "kernel", "runner"), { recursive: true });
  fs.writeFileSync(path.join(engine, "kernel", "runner", "manifest.gd"), 'const KEYS: Dictionary = {\n\t"id": {"type": "string"},\n\t"cameras": {"type": "array"},\n}\n');
  assert.deepEqual(acceptedCarriedFields(engine), []);
  fs.appendFileSync(path.join(engine, "kernel", "runner", "manifest.gd"), 'const OPTIONAL: Dictionary = {"params": {"type": "array"}, "moments": {"type": "array"}}\n');
  assert.deepEqual(acceptedCarriedFields(engine), ["params", "moments"]);

  const job = tempJob("carried-none");
  const inner = new FakeBuilder(scriptWith());
  const builder: Builder = {
    name: "fake",
    probe: () => inner.probe(),
    run: async (req) => {
      const res = await inner.run(req);
      if (req.mode === "edit" && req.meta?.package === "court") {
        const file = path.join(req.cwd, "pack.json");
        const m = JSON.parse(fs.readFileSync(file, "utf8")) as Record<string, unknown>;
        m["params"] = [{ name: "wall_height", file: "data/court.json", path: "wall_height_m", min: 0.5, max: 3, step: 0.1, label: "Wall height" }];
        fs.writeFileSync(file, JSON.stringify(m, null, 1));
      }
      return res;
    },
  };
  const { foreman } = foremanFor(job, { promoteTo: "job", carriedFields: [], builder: builder as unknown as FakeBuilder });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const prompt = inner.calls.find((c) => c.req.meta?.package === "court")?.req.prompt ?? "";
  assert.match(prompt, /\*\*Values a player may tune\.\*\* Keep every value[^]*JSON file of yours under `data\/`[^]*does not accept the optional manifest fields[^]*do NOT add them to `pack\.json`[^]*TUNABLE: <data file> <dotted path> <min> <max> <step> <label>/);
  assert.ok(!/yours to write/.test(prompt));
  for (const dir of ["pack", path.join("promoted", "game.paddle_court")]) {
    assert.equal((JSON.parse(fs.readFileSync(path.join(job.jobDir, dir, "pack.json"), "utf8")) as Record<string, unknown>)["params"], undefined, dir);
  }
  const verifying = ofType(readEvents(job.jobDir), "package_state").find((e) => e.package === "court" && e.state === "verifying");
  assert.match(verifying?.detail ?? "", /pack\.json \(the builder wrote params; this engine's manifest check does not accept that field yet, so it was removed\)/);
});
