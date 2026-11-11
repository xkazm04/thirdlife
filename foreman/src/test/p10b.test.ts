// P10, second file (items 5 and 6; items 1 to 4 are in p10.test.ts). Fake adapter and fake runner; no model is called.
//   1 the pack's tests at the merge gate (the replay of the real hockey job's first change request)
//   2 a failed final verification goes back to a package; a change that cannot be made ends `done`, not `failed`
//   3 a change request carries the present values      4 the inbox (one process, then two)
//   5 the engine's `starved` verdict and `metrics.starved_stalls`      6 the player's check in the plan
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempDir, tempJob, foremanFor, readEvents, scriptWith, fixturePlan, fastVerifier, VERBS, type TempJob } from "./helpers.js";
import { FakeBuilder, type FakeScript, type FakeStep } from "../builder/fake.js";
import type { Builder } from "../builder/types.js";
import { planCheck, playerCheckProblems, playerChecks, renderPlannerPrompt } from "../designer.js";
import type { JobEvent, PackageSpec } from "../events.js";
import { JobLog, rebuildState } from "../joblog.js";
import { FINAL_FAILED, FOREMAN_NOTE, MACHINE_BUSY, PACK_TEST_FAILED, STARVED, isStarved, presentValuesText, restsOnAClock, starvedStalls } from "../foreman.js";
import { INBOX_FILE, INBOX_REJECTED_FILE, drainInbox, readInbox, writeInbox } from "../inbox.js";
import { Verifier } from "../verifier.js";
import { inProcessFakeRunner } from "../testing/fake-runner-core.js";
import { runProcess } from "../proc.js";
import { FAKE_RUNNER, PKG_ROOT, REPO_ROOT } from "../paths.js";

after(cleanup);

const ofType = <T extends JobEvent["type"]>(evs: JobEvent[], type: T): Extract<JobEvent, { type: T }>[] => evs.filter((e) => e.type === type) as Extract<JobEvent, { type: T }>[];
const states = (evs: JobEvent[], pkg: string): string[] => ofType(evs, "package_state").filter((e) => e.package === pkg).map((e) => `${e.state}${e.round}`);
const promptsOf = (b: FakeBuilder, pkg: string): string[] => b.calls.filter((c) => c.req.meta?.role === "builder" && c.req.meta?.package === pkg).map((c) => c.req.prompt);
const CLI = path.join(PKG_ROOT, "dist", "cli.js");
const cli = (args: string[], env: NodeJS.ProcessEnv = {}): ReturnType<typeof runProcess> => runProcess({ exe: process.execPath, args: [CLI, ...args], env: { ...process.env, ...env }, timeoutMs: 120_000 });
const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

const HOCKEY = path.join(PKG_ROOT, "fixtures", "job-hockey-change");
/**
 * The real hockey job (read only, never run). `site/` is not versioned: in a git worktree under
 * <main>/.claude/worktrees/<name> it is found in the main checkout.
 */
const REAL_JOB = [path.join(REPO_ROOT, "site"), path.resolve(REPO_ROOT, "..", "..", "..", "site")].map((d) => path.join(d, "ice-hockey-three-against-20261111-1")).find((d) => fs.existsSync(path.join(d, "job.jsonl"))) ?? path.join(REPO_ROOT, "site", "ice-hockey-three-against-20261111-1");
/** The words of the real job's first change request (event 232 of its log). */
const REAL_REQUEST = "I can hardly see the puck. Make it bigger and much darker so it stands out on the ice, and move the camera so both goals and the whole rink stay in view.";

function hockeyJob(label: string): TempJob {
  const root = tempDir(label);
  const jobDir = path.join(root, "site", "ice-hockey-change-replay-1");
  fs.mkdirSync(jobDir, { recursive: true });
  for (const f of ["job.jsonl", "fake-builder.json", "foreman.config.json"]) fs.copyFileSync(path.join(HOCKEY, f), path.join(jobDir, f));
  const engineDir = path.join(root, "engine");
  fs.mkdirSync(engineDir, { recursive: true });
  return { root, jobDir, engineDir };
}
function hockeyScript(first: FakeStep[] = []): FakeScript {
  const base = JSON.parse(fs.readFileSync(path.join(HOCKEY, "fake-builder.json"), "utf8")) as FakeScript;
  return { ...base, steps: [...first, ...base.steps] };
}
function request(jobDir: string, text: string, pkg?: string): number {
  const log = JobLog.open(jobDir);
  try {
    return log.append({ type: "change_requested", text, ...(pkg !== undefined ? { package: pkg } : {}) }).seq;
  } finally {
    log.close();
  }
}
/** The hockey fixture built to its first `done` (promotion 0.1.0), then the real job's first change request recorded. */
async function hockeyAfterFirstDone(label: string, opts: Parameters<typeof foremanFor>[1] = {}): Promise<{ job: TempJob; before: number; seq: number }> {
  const job = hockeyJob(label);
  const s = await foremanFor(job, { promoteTo: "job", script: hockeyScript(), ...opts }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  assert.equal(s.promotions.length, 1);
  const before = s.lastSeq;
  return { job, before, seq: request(job.jobDir, REAL_REQUEST) };
}
const reportOf = (e: JobEvent): string => (e.type === "verify" ? e.report : "");

// ---------------------------------------------------------------- 5. the engine's verdicts

test("5 starved: a runner that reports `starved` (exit 2, engine error `starved:`) is the machine: nothing goes to a builder, the round is not spent, the job pauses; a resume verifies the same files", async () => {
  const job = tempJob("starved");
  const sleeps: number[] = [];
  const starving = new Verifier({ godot: FAKE_RUNNER, engineDir: job.engineDir, spawn: inProcessFakeRunner({ FAKE_RUNNER_STARVED: "99" }), timeoutMs: 300 });
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", verifier: starving, clockRetries: 2, clockPausesMs: [10, 20], sleep: async (ms) => void sleeps.push(ms) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "paused", JSON.stringify(s.jobState));
  assert.match(s.jobState?.reason ?? "", /machine busy/);
  const evs = readEvents(job.jobDir);
  // The runner's own words reach the log; the Foreman's reference gauge is not asked (the engine has said it).
  const smoke = ofType(evs, "verify").filter((e) => e.verb === "smoke");
  assert.deepEqual(smoke.map((e) => [e.ok, e.exitCode, e.package]), [[false, 2, "core"], [false, 2, "core"], [false, 2, "core"]]);
  assert.ok(!fs.readdirSync(path.join(job.jobDir, "reports")).some((f) => f.startsWith("reference-")), "no reference run");
  assert.deepEqual(sleeps, [10, 20]);
  const notes = ofType(evs, "note").filter((n) => n.text.startsWith(`${FOREMAN_NOTE}${MACHINE_BUSY}`));
  assert.equal(notes.length, 3);
  assert.match(notes[0]?.text ?? "", new RegExp(`${STARVED}: smoke on the workspace of core ended exit 2, not_run, and the engine says why: "starved: _pack_tick ran 90 s of wall time`));
  assert.match(notes[2]?.text ?? "", /This is NOT a verdict about the pack: nothing was sent to the builder and no round was spent/);
  // Nothing sent to a builder, the round not spent.
  assert.equal(builder.calls.length, 1, "one builder run: the one before the check");
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "blocked1"]);
  const core = rebuildState(job.jobDir, { write: false }).packages["core"];
  assert.deepEqual([core?.state, core?.cause, core?.round], ["blocked", "machine_busy", 1]);
  assert.ok(!ofType(evs, "package_state").some((e) => e.state === "failed"));
  // The machine is free again: the same files are verified, the builder is not run again for them.
  const r = foremanFor(job, { promoteTo: "job" });
  const done = await r.foreman.run();
  assert.equal(done.jobState?.state, "done", JSON.stringify(done.jobState));
  assert.equal(r.builder.calls.filter((c) => c.req.meta?.package === "core").length, 0);
  assert.equal(done.packages["core"]?.round, 1);
});

test("5 starved: one starved run followed by a real verdict does not pause anything; `metrics.starved_stalls` is shown in the round's detail when it is not zero; unit cases", async () => {
  const job = tempJob("starved-once");
  const once = new Verifier({ godot: FAKE_RUNNER, engineDir: job.engineDir, spawn: inProcessFakeRunner({ FAKE_RUNNER_STARVED: "1" }), timeoutMs: 300 });
  const s = await foremanFor(job, { promoteTo: "job", verifier: once, clockPausesMs: [1], sleep: async () => {} }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  assert.ok(!ofType(evs, "job_state").some((e) => e.state === "paused"));
  assert.deepEqual(ofType(evs, "verify").filter((e) => e.package === "core").map((e) => `${e.verb}:${e.ok}`), ["lint:true", "smoke:false", "smoke:true"]);
  assert.equal(ofType(evs, "builder_run").filter((e) => e.package === "core").length, 1);

  const job2 = tempJob("starved-stalls");
  const stalls = fastVerifier(job2.engineDir, { FAKE_RUNNER_STARVED_STALLS: "2" });
  assert.equal((await foremanFor(job2, { promoteTo: "job", verifier: stalls }).foreman.run()).jobState?.state, "done");
  const promoted = ofType(readEvents(job2.jobDir), "package_state").filter((e) => e.state === "promoted");
  assert.equal(promoted.length, 3);
  for (const p of promoted) assert.match(p.detail ?? "", /^starved_stalls \d+ \(\d+ ms\) in \d+ check run\(s\) of this round: the machine held the processor back; the engine's limits count processor time, so nothing failed for it$/);
  assert.match(promoted[0]?.detail ?? "", /^starved_stalls 4 \(1242 ms\) in 2 check run\(s\)/, "core: smoke on the workspace and smoke on the whole pack, 2 stalls each");
  // Without stalls the detail is absent, as before.
  assert.ok(ofType(evs, "package_state").filter((e) => e.state === "promoted").every((e) => e.detail === undefined));

  const report = (outcome: "not_run" | "watchdog", errors: { kind: string; message: string }[], metrics?: Record<string, unknown>): Parameters<typeof isStarved>[0] => ({
    verb: "smoke", level: "V2", ok: false, exitCode: 2, reportFile: "r.json", verdictFile: "r.verdict.json", flags: [], summary: "", durationMs: 1,
    report: { schema: "tl.verify/1", verb: "smoke", level: "V2", ok: false, outcome, checks: [], errors, ...(metrics ? { metrics } : {}) },
  });
  const starved = report("not_run", [{ kind: "engine", message: "starved: _pack_tick ran 90 s of wall time (started again 2 time(s); no verdict on the pack)" }]);
  assert.equal(isStarved(starved), true);
  assert.equal(restsOnAClock(starved), false, "the Foreman's own clock rule does not claim it: the engine's verdict is read directly");
  assert.equal(isStarved(report("not_run", [{ kind: "engine", message: "unknown option --x for 'smoke'" }])), false);
  assert.equal(isStarved(report("not_run", [{ kind: "load", message: "starved: not an engine error" }])), false);
  assert.equal(isStarved(report("watchdog", [{ kind: "watchdog", message: "tick_timeout: _pack_tick did not return within 250 ms" }])), false);
  assert.deepEqual(starvedStalls(report("not_run", [], { starved_stalls: 3, starved_ms: 901.5 })), { stalls: 3, ms: 901.5 });
  assert.deepEqual(starvedStalls(starved), { stalls: 0, ms: 0 });
});

// ---------------------------------------------------------------- 6. the player's part

const withoutCheck = (plan: PackageSpec[]): PackageSpec[] => plan.map((p) => ({ ...p, contract: p.contract.replace(/\n?^.*PLAYER CHECK:.*$/m, "") }));

test("6 player check: a plan with player input must name, in a contract, a bot that fails when the human-controlled side has nothing to do; the plan check refuses a plan that does not", () => {
  const plan = fixturePlan();
  assert.deepEqual(planCheck(plan, { verbs: VERBS }), [], "the fixture plan names its player check");
  assert.deepEqual(playerChecks(plan).map((c) => `${c.package}:${c.test}`), ["core:tests/bot_rally.gd"]);
  const bare = withoutCheck(plan);
  assert.equal(playerChecks(bare).length, 0);
  const problems = planCheck(bare, { verbs: VERBS });
  assert.equal(problems.length, 1);
  assert.match(problems[0] ?? "", /^the game has player input \(package "core" registers the capability "input"\) but no contract names a player check\. Add ONE line[^]*"PLAYER CHECK: tests\/<bot>\.gd fails when <what the human-controlled side can no longer do>"/);
  // The real hockey plan as it was (no such line: it was written before this rule) is refused; with the line it passes.
  const hockey = (readEvents(HOCKEY).find((e) => e.type === "plan_set") as Extract<JobEvent, { type: "plan_set" }>).packages;
  assert.deepEqual(planCheck(hockey, { verbs: VERBS }), []);
  assert.equal(planCheck(withoutCheck(hockey), { verbs: VERBS }).length, 1);
  // The line must name a registered bot that some acceptance runs, and say what it fails on.
  const named = (line: string): string[] => playerCheckProblems(bare.map((p) => (p.id === "core" ? { ...p, contract: `${p.contract}\n${line}` } : p)));
  assert.deepEqual(named("PLAYER CHECK: tests/bot_rally.gd fails when the player's paddle never returned the ball"), []);
  assert.deepEqual(named("- **PLAYER CHECK:** `tests/bot_rally.gd` fails when the result is the same without the player's inputs").length, 1, "the form is fixed: one plain line");
  assert.match(named("PLAYER CHECK: tests/bot_ghost.gd fails when the player's paddle never returned the ball")[0] ?? "", /names tests\/bot_ghost\.gd, which no package registers in registers\.tests/);
  assert.match(named("PLAYER CHECK: tests/bot_rally.gd ok")[0] ?? "", /must say what the bot fails on/);
  // Which acceptance runs the bot is the plan's business: the final verification runs every registered bot anyway.
  assert.deepEqual(playerCheckProblems(bare.map((p) => ({ ...p, acceptance: p.acceptance.filter((a) => a.verb !== "bot"), ...(p.id === "core" ? { contract: `${p.contract}\nPLAYER CHECK: tests/bot_rally.gd fails when the player's paddle never returned the ball` } : {}) }))), []);
  // A game nobody plays (no package registers `input`) needs none.
  const watching = bare.map((p) => ({ ...p, ...(p.registers ? { registers: { ...p.registers, capabilities: (p.registers.capabilities ?? []).filter((c) => c !== "input") } } : {}) }));
  assert.deepEqual(playerCheckProblems(watching), []);
});

test("6 player check: the Planner prompt asks for it, with the form of the line and the reason; the dry prompt for the racing sentence carries the text", () => {
  const prompt = renderPlannerPrompt(
    { sentence: "A night street race: three laps against two rivals, nitro on a pad, the walls break", packId: "game.night_street_race", title: "Night street race", brief: { rules: "r", arena: "a", ai: "i", controls: "c", mood: "m" }, packContract: "(omitted)" },
    { verbs: VERBS },
  );
  assert.match(prompt, /\*\*The player's part is tested\.\*\*[^]*ONE bot of the plan must FAIL when the human-controlled side has nothing\s+to do/);
  assert.match(prompt, /the\s+result with the player's inputs differs from the result without them/);
  assert.match(prompt, /`PLAYER CHECK: tests\/<bot>\.gd fails when <what the human-controlled side can no longer do>`/);
  assert.match(prompt, /Every later package that\s+moves, steers or scores for anyone[^]*also runs it in its own\s+acceptance/);
  assert.ok(!prompt.includes("{{"));
  const dry = path.join(PKG_ROOT, "dry", "p10-prompts-racing.txt");
  assert.ok(fs.existsSync(dry), "foreman/dry/p10-prompts-racing.txt is part of the package");
  const text = fs.readFileSync(dry, "utf8");
  assert.match(text, /A night street race: three laps against two rivals, nitro on a pad, the walls break/);
  assert.match(text, /PLAYER CHECK: tests\/<bot>\.gd fails when/);
});
