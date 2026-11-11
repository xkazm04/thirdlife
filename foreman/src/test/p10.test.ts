// P10 (brief briefs/BRIEF-P10-FOREMAN.md), against the fake adapter and the fake runner. No model is called.
//   1 the pack's tests at the merge gate (the replay of the real hockey job's first change request)
//   2 a failed final verification goes back to a package; a change that cannot be made ends `done`, not `failed`
//   3 a change request carries the present values      4 the inbox (one process, then two)
//   (5 the engine's `starved` verdict and 6 the player's check in the plan are in p10b.test.ts)
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

// ---------------------------------------------------------------- 1. the pack's tests at the merge gate

test("1 replay of the real hockey job's first change request: the dependant's rebuild is checked against BOTH bots, the failure is found at its merge and goes back to it; the job ends done, never failed", async () => {
  const { job, before, seq } = await hockeyAfterFirstDone("replay");
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", script: hockeyScript() });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > before);
  // As in the real log: the Planner names the owner, the owner merges, the AI's own bot fails on the merged pack.
  const re = ofType(later, "reopened");
  assert.deepEqual(re.map((e) => e.package), ["hockey_core", "hockey_ai"]);
  assert.match(re[0]?.reason ?? "", new RegExp(`^change request \\(event ${seq}\\); the Planner names the package`));
  assert.match(re[1]?.reason ?? "", /^its dependency hockey_core was changed and merged again, and bot \(V4\) now fails on the merged pack/);
  // The real job needed one AI round and failed in the final verification; here the same round is refused at the gate.
  assert.deepEqual(ofType(later, "builder_run").filter((e) => e.mode === "edit").map((e) => `${e.package}/${e.round}`), ["hockey_core/2", "hockey_ai/2", "hockey_ai/3"]);
  const verifies = ofType(later, "verify");
  const stem = (re2: RegExp): Extract<JobEvent, { type: "verify" }>[] => verifies.filter((e) => re2.test(e.report));
  // Round 2 of the AI: its own acceptance passes (both seeds of ITS bot), then the owner's bot on the candidate fails.
  assert.deepEqual(verifies.filter((e) => e.package === "hockey_ai" && e.round === 2 && !/-reverify-/.test(e.report)).map((e) => `${e.verb}:${e.ok}`), ["lint:true", "smoke:true", "bot:true", "bot:true", "invariants:true"]);
  const failed = stem(/hockey_ai-r2-pack-bot-bot_hockey-s\d+/);
  assert.deepEqual(failed.map((e) => [e.ok, e.after, e.package]), [[false, "hockey_ai", undefined]]);
  // The control: the same test on pack/ without the AI's new files passes, so those files are the cause.
  const control = stem(/hockey_ai-r2-control-bot-bot_hockey-s\d+/);
  assert.deepEqual(control.map((e) => e.ok), [true]);
  assert.ok((control[0]?.seq ?? 0) > (failed[0]?.seq ?? 0));
  // The failure names the package whose test failed and the package that was merging.
  const note = ofType(later, "note").find((n) => n.text.startsWith(`${FOREMAN_NOTE}${PACK_TEST_FAILED}`));
  assert.equal(note?.package, "hockey_ai");
  assert.equal(note?.round, 2);
  assert.match(note?.text ?? "", /tests\/bot_hockey\.gd, a test of package hockey_core, fails on the whole pack with the round-2 files of hockey_ai merged in[^]*passes on the same pack without them[^]*NOT merged/);
  // Nothing of round 2 reached pack/: the AI merged once, after round 3, where BOTH bots ran on the candidate.
  const merges = ofType(later, "merge").filter((e) => e.package === "hockey_ai");
  assert.equal(merges.length, 1);
  const both = stem(/hockey_ai-r3-pack-bot-/);
  assert.deepEqual(both.map((e) => `${/pack-bot-(\w+?)-s\d+/.exec(e.report)?.[1]}:${e.ok}`), ["bot_hockey:true", "bot_hockey_ai:true"]);
  assert.ok(both.every((e) => e.seq < (merges[0]?.seq ?? 0)), "the tests of the pack gate the merge");
  assert.deepEqual(states(later, "hockey_ai"), ["queued2", "running2", "verifying2", "running3", "verifying3", "promoted3"]);
  // One step earlier: the failure is in the log before any final check ran, and the final verification then passes.
  const firstFinal = verifies.find((e) => /reports\/final-/.test(e.report));
  assert.ok(firstFinal && (failed[0]?.seq ?? 0) < firstFinal.seq);
  assert.ok(stem(/reports\/final-/).every((e) => e.ok));
  assert.deepEqual(ofType(later, "job_state").map((e) => e.state), ["running", "done"]);
  assert.deepEqual(ofType(later, "promoted").map((e) => e.version), ["0.1.1"]);
  // What the AI's builder was told in round 3.
  const p3 = promptsOf(builder, "hockey_ai")[1] ?? "";
  assert.match(p3, /PACK TEST FAILED after the merge of hockey_ai was tried: tests\/bot_hockey\.gd, a test of package hockey_core/);
  assert.match(p3, /Every test of the pack must pass with your files in, not only your own acceptance/);
  assert.match(p3, /The Verifier did not pass round 2: bot \(V4\) on the whole pack with your files merged in/);
  // The owner's merge: both bots of the pack are answered for by packages that depend on it (hockey_fx runs
  // bot_hockey, hockey_ai owns bot_hockey_ai), so they run right AFTER the merge, in those packages' acceptance.
  assert.equal(stem(/hockey_core-r2-pack-bot-/).length, 0);
  assert.deepEqual(stem(/-reverify-bot-/).map((e) => `${e.package}:${e.ok}`), ["hockey_ai:false", "hockey_fx:true"]);
  // The pack that was promoted holds the fix; the first promotion is untouched.
  assert.match(fs.readFileSync(path.join(job.jobDir, "promoted", "game.ice_hockey_three_against@0.1.1", "data", "ai.json"), "utf8"), /"red_skill": 0\.6/);
  assert.match(fs.readFileSync(path.join(job.jobDir, "promoted", "game.ice_hockey_three_against", "data", "tuning.json"), "utf8"), /"radius": 0\.15/);
});

test("1 pack tests: a test that fails with AND without the round's files is not that merge's doing (a note, the merge goes on); `packTests: never` runs none; a first build runs none by default and all with `always`", async () => {
  // The sibling hockey_fx is re-opened by a change request while the AI's own bot is already failing on pack/.
  const { job, before } = await hockeyAfterFirstDone("not-mine", { packTests: "never" });
  // Without the gate (never) and without final rounds, the owner's change leaves hockey_ai kept-earlier and the job as it was before P10.
  const fxAgain: FakeStep = { match: { role: "builder", package: "hockey_fx", round: 2 }, write: { "data/fx.json": '{\n "horn_volume_db": -3,\n "burst_size_m": 2.5\n}\n' }, text: "Louder horn.\nDEVIATIONS: none" };
  // The owner's round breaks the AI's bot; the AI is never able to adapt (every round of it fails its own bot).
  const aiStuck: FakeStep = { match: { role: "builder", package: "hockey_ai" }, text: "I could not adapt.\nDEVIATIONS: none" };
  const first = await foremanFor(job, { promoteTo: "job", roundLimit: 1, finalRounds: 0, packTests: "never", script: hockeyScript([aiStuck]) }).foreman.run();
  assert.equal(first.jobState?.state, "failed", "before P10 (no final rounds): the final verification ends the job");
  assert.equal(readEvents(job.jobDir).filter((e) => e.seq > before && e.type === "verify" && /-pack-bot-|-control-bot-/.test(reportOf(e))).length, 0, "packTests never: no pack test ran");
  const mid = readEvents(job.jobDir).length;
  request(job.jobDir, "Make the goal horn louder.", "hockey_fx");
  const s = await foremanFor(job, { promoteTo: "job", roundLimit: 1, finalRounds: 0, script: hockeyScript([fxAgain, aiStuck]) }).foreman.run();
  const later = readEvents(job.jobDir).filter((e) => e.seq > mid);
  const verifies = ofType(later, "verify");
  // hockey_fx merges again: bot_hockey passes on its candidate; bot_hockey_ai fails there and on pack/ (the control).
  assert.deepEqual(verifies.filter((e) => /hockey_fx-r2-(pack|control)-bot-/.test(e.report)).map((e) => `${/-(pack|control)-bot-(\w+?)-s\d+/.exec(e.report)?.slice(1).join(":")}:${e.ok}`), ["pack:bot_hockey:true", "pack:bot_hockey_ai:false", "control:bot_hockey_ai:false"]);
  const note = ofType(later, "note").find((n) => n.text.includes("pack test fails without this merge too"));
  assert.match(note?.text ?? "", /tests\/bot_hockey_ai\.gd, a test of package hockey_ai, fails[^]*fails without them as well[^]*Not caused by this merge, which goes on; hockey_ai is the package to look at/);
  assert.equal(ofType(later, "merge").filter((e) => e.package === "hockey_fx").length, 1, "the sibling's merge is not held up");
  assert.equal(s.jobState?.state, "failed", "finalRounds 0 keeps the old ending; the next test shows the new one");

  // A first build: no pack tests by default (the acceptance of the plan decides), every test with `always`.
  const job2 = hockeyJob("always");
  assert.equal((await foremanFor(job2, { promoteTo: "job", packTests: "always", script: hockeyScript() }).foreman.run()).jobState?.state, "done");
  const evs2 = ofType(readEvents(job2.jobDir), "verify").filter((e) => /-pack-bot-/.test(e.report));
  assert.deepEqual(evs2.map((e) => `${e.after}:${/pack-bot-(\w+?)-s\d+/.exec(e.report)?.[1]}`), ["hockey_ai:bot_hockey", "hockey_ai:bot_hockey_ai", "hockey_look:bot_hockey", "hockey_look:bot_hockey_ai", "hockey_fx:bot_hockey", "hockey_fx:bot_hockey_ai"], "the root's bots are answered for by its dependants; every later merge runs both");
  const job3 = hockeyJob("default-first");
  assert.equal((await foremanFor(job3, { promoteTo: "job", script: hockeyScript() }).foreman.run()).jobState?.state, "done");
  assert.equal(ofType(readEvents(job3.jobDir), "verify").filter((e) => /-pack-bot-/.test(e.report)).length, 0);
});

// ---------------------------------------------------------------- 2. a failed final verification goes back to a package

test("2 final verification: with the merge gate off, the real job's failure (final bot fails after the AI's rebuild) re-opens the package that merged last since the test last passed, for ONE round; the job ends done", async () => {
  const { job, before } = await hockeyAfterFirstDone("final-back");
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", packTests: "never", script: hockeyScript() });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > before);
  // Exactly the real job's sequence up to the failed final check (events 232 to 278 of its log) ...
  const finalFail = ofType(later, "verify").find((e) => /reports\/final-bot-bot_hockey-s\d+/.test(e.report) && !e.ok);
  assert.ok(finalFail, "the final verification fails at the owner's bot, as in the real job");
  assert.equal(ofType(later, "merge").filter((e) => e.package === "hockey_ai" && e.seq < (finalFail?.seq ?? 0)).length, 1, "the AI's rebuild was merged first");
  // ... and then not `failed`: the failure goes back to a package.
  assert.deepEqual(ofType(later, "job_state").map((e) => e.state), ["running", "done"]);
  const back = ofType(later, "reopened").filter((e) => e.reason.startsWith(FINAL_FAILED));
  assert.equal(back.length, 1);
  assert.equal(back[0]?.package, "hockey_ai");
  assert.equal(back[0]?.seq, (finalFail?.seq ?? 0) + 1);
  assert.match(back[0]?.reason ?? "", /^FINAL VERIFICATION FAILED \(1 of 4\) at bot \(V4\) --test=tests\/bot_hockey\.gd \[report: reports\/final-bot-bot_hockey-s\d+\.json\]\. Sent back to hockey_ai: tests\/bot_hockey\.gd \(a test of package hockey_core\) last passed at event \d+ \([^)]*\); since the state that run saw, hockey_ai merged last \(event \d+\) and nothing else changed/);
  // One round, with the failed report in the prompt.
  assert.deepEqual(ofType(later, "builder_run").filter((e) => e.mode === "edit").map((e) => `${e.package}/${e.round}`), ["hockey_core/2", "hockey_ai/2", "hockey_ai/3"]);
  const p3 = promptsOf(builder, "hockey_ai")[1] ?? "";
  assert.match(p3, /# Round 3 of 3/, "one round per final re-opening");
  assert.match(p3, /the WHOLE pack then failed its final verification, so nothing was promoted:\nFINAL VERIFICATION FAILED \(1 of 4\)/);
  assert.match(p3, /Report of the failed check \(tl\.verify\/1\):\n\{[^]*"bot\.ok"/);
  assert.deepEqual(ofType(later, "promoted").map((e) => e.version), ["0.1.1"]);
  assert.equal(rebuildState(job.jobDir, { write: false }).packages["hockey_ai"]?.round, 3);
});

test("2 final verification: when the rounds are spent the change ends as NOT made: the job is `done` on the earlier promotion and the event says so; a further run changes nothing; a first build still ends `failed`", async () => {
  const { job, before } = await hockeyAfterFirstDone("final-spent");
  // The AI can adapt to the big puck only by taking the game from the player, in every round.
  const base = hockeyScript();
  const breaking = base.steps.find((x) => x.match?.package === "hockey_ai" && x.match.round === 2) as FakeStep;
  const always: FakeStep = { ...breaking, match: { role: "builder", package: "hockey_ai", promptIncludes: "FINAL VERIFICATION FAILED" } };
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", packTests: "never", finalRounds: 2, script: hockeyScript([always]) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  assert.match(s.jobState?.reason ?? "", /^the change was NOT made: the final verification still fails at bot \(V4\) after 2 round\(s\) that it sent back to a package \(limit 2\); the job ends on the earlier promotion game\.ice_hockey_three_against 0\.1\.0 \(promoted\/game\.ice_hockey_three_against\), which is untouched/);
  const later = readEvents(job.jobDir).filter((e) => e.seq > before);
  assert.deepEqual(ofType(later, "job_state").map((e) => e.state), ["running", "done"]);
  assert.deepEqual(ofType(later, "reopened").filter((e) => e.reason.startsWith(FINAL_FAILED)).map((e) => `${e.package}:${/\((\d of \d)\)/.exec(e.reason)?.[1]}`), ["hockey_ai:1 of 2", "hockey_ai:2 of 2"]);
  assert.equal(promptsOf(builder, "hockey_ai").length, 3, "the rebuild and two rounds sent back: the cost is bounded");
  assert.equal(ofType(later, "promoted").length, 0);
  assert.equal(s.promotions.length, 1);
  assert.match(fs.readFileSync(path.join(job.jobDir, "promoted", "game.ice_hockey_three_against", "data", "tuning.json"), "utf8"), /"radius": 0\.15/);
  const n = readEvents(job.jobDir).length;
  assert.equal((await foremanFor(job, { promoteTo: "job", script: hockeyScript() }).foreman.run()).jobState?.state, "done");
  assert.equal(readEvents(job.jobDir).length, n, "a finished job stays finished");
  // A new request starts a new count.
  request(job.jobDir, "The puck is far too big: radius about 0.12 m.", "hockey_core");
  const again = await foremanFor(job, { promoteTo: "job", packTests: "never", finalRounds: 1, script: hockeyScript() }).foreman.run();
  assert.equal(again.jobState?.state, "done", JSON.stringify(again.jobState));
  assert.match(ofType(readEvents(job.jobDir).filter((e) => e.seq > n), "reopened").find((e) => e.reason.startsWith(FINAL_FAILED))?.reason ?? "", /\(1 of 1\)/);

  // A first build (no earlier promotion to fall back on) fails as before.
  const fresh = tempJob("final-first");
  const f = await foremanFor(fresh, { promoteTo: "job", script: scriptWith([{ match: { role: "builder", package: "court" }, write: { "data/court.json": "{}\n", "scripts/court.gd": "extends RefCounted\n# FAKE_NONDETERMINISTIC\n" }, text: "Done." }]) }).foreman.run();
  assert.equal(f.jobState?.state, "failed");
  assert.match(f.jobState?.reason ?? "", /^final verification failed at invariants/);
});

// ---------------------------------------------------------------- 3. the present values

/** The fixture's builder, plus `params` in the root's pack.json as a real builder writes them (a fake step cannot read the file). */
function withParams(inner: FakeBuilder): Builder {
  return {
    name: "fake",
    probe: () => inner.probe(),
    run: async (req) => {
      const res = await inner.run(req);
      if (req.mode === "edit" && req.meta?.package === "hockey_core" && req.meta.round === 1) {
        const file = path.join(req.cwd, "pack.json");
        const m = JSON.parse(fs.readFileSync(file, "utf8")) as Record<string, unknown>;
        m["params"] = [
          { name: "puck_radius", file: "data/tuning.json", path: "puck.radius", min: 0.04, max: 0.3, step: 0.01, label: "Puck size" },
          { name: "score_to_win", file: "data/tuning.json", path: "rules.score_to_win", min: 1, max: 9, step: 1, label: "Goals to win" },
        ];
        fs.writeFileSync(file, JSON.stringify(m, null, 1));
      }
      return res;
    },
  };
}

test("3 present values: a change request on a pack with `params` shows the owner each declared value as it is NOW, then the small values of the data files; a package without change requests gets no table", async () => {
  const job = hockeyJob("values");
  const inner = new FakeBuilder(hockeyScript());
  const s = await foremanFor(job, { promoteTo: "job", builder: withParams(inner) as unknown as FakeBuilder }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  assert.ok(promptsOf(inner, "hockey_core").every((p) => !p.includes("The values as they are now")), "no table without a change request");
  request(job.jobDir, REAL_REQUEST);
  const inner2 = new FakeBuilder(hockeyScript());
  assert.equal((await foremanFor(job, { promoteTo: "job", builder: withParams(inner2) as unknown as FakeBuilder }).foreman.run()).jobState?.state, "done");
  const p = promptsOf(inner2, "hockey_core")[0] ?? "";
  assert.match(p, /## Change requests from the player[^]*1\. I can hardly see the puck\. Make it bigger[^]*### The values as they are now/);
  assert.match(p, /A request such as "bigger", "faster" or "darker" is measured from these figures/);
  assert.match(p, /Declared tunable values \(`params` of pack\.json\) and what each is NOW:\n- Puck size \(`puck_radius`\): `data\/tuning\.json` `puck\.radius` = 0\.15 \(min 0\.04, max 0\.3, step 0\.01\)\n- Goals to win \(`score_to_win`\): `data\/tuning\.json` `rules\.score_to_win` = 3 \(min 1, max 9, step 1\)/);
  // The other small values: the owner's files are marked, another package's are read only; declared ones are not repeated.
  const line = (file: string): string => p.split("\n").find((l) => l.startsWith(`- \`${file}\``)) ?? "";
  assert.match(line("data/tuning.json"), /\(yours\): skater\.skate_speed = 7\.5; skater\.radius = 0\.45; shoot\.speed = 18; puck\.height = 0\.05; puck\.color = \[0\.25,0\.25,0\.28\]; camera\.pos = \[0,38,22\]; camera\.fov = 50/);
  assert.ok(!line("data/tuning.json").includes("puck.radius"), "a declared value is listed once, with its range");
  assert.match(line("data/ai.json"), /\(another package's: read only\): red_skill = 0\.9/);
  // The dependant re-opened for the changed dependency has no change request of its own: no table.
  assert.ok(promptsOf(inner2, "hockey_ai").every((x) => !x.includes("The values as they are now")));
  // The table stays in the owner's later rounds (it is part of the brief, not of one round's feedback) and follows the files.
  request(job.jobDir, "The puck is now far too big. About a third of that size.", "hockey_core");
  const inner3 = new FakeBuilder(hockeyScript());
  await foremanFor(job, { promoteTo: "job", builder: withParams(inner3) as unknown as FakeBuilder }).foreman.run();
  assert.match(promptsOf(inner3, "hockey_core")[0] ?? "", /`puck\.radius` = 0\.35 \(min 0\.04, max 0\.3, step 0\.01\)/, "the present value is the one the first change left");
});

test("3 present values: a figure that is in no data file is found in the owner's scripts (the real pack's puck was a literal in scripts/main.gd)", { skip: !fs.existsSync(path.join(REAL_JOB, "promoted", "game.ice_hockey_three_against", "pack.json")) ? "the real hockey job is not in site/ of this checkout (it lives in the main checkout only)" : false }, () => {
  const pack = path.join(REAL_JOB, "promoted", "game.ice_hockey_three_against");
  const text = presentValuesText(pack, ["scripts/main.gd", "scripts/rink_api.gd", "data/venue.json", "data/tuning.json", "tests/bot_hockey.gd"]);
  // What the brief's two sources give for the pack the first request was made on: no puck size at all.
  assert.match(text, /- Goals to win \(`score_to_win`\): `data\/tuning\.json` `rules\.score_to_win` = 3 \(min 1, max 9, step 1\)/);
  const data = text.split("\n").filter((l) => l.startsWith("- `data/"));
  assert.ok(!data.some((l) => /radius/.test(l) && /puck/.test(l)), "neither params nor data/*.json of the 0.1.0 pack held the puck's size");
  // The third source does.
  assert.match(text, /Figures written in your own scripts[^]*- `scripts\/main\.gd:\d+`: puck = TLBall\.create\(\{"part": TLKit\.build\("puck", \{"radius": 0\.15, "height": 0\.08\}\)/);
});

test("3 present values: unit cases (no params, a long list, a broken file, nothing to show)", () => {
  const dir = tempDir("values-unit");
  fs.mkdirSync(path.join(dir, "data"), { recursive: true });
  fs.mkdirSync(path.join(dir, "scripts"), { recursive: true });
  assert.equal(presentValuesText(dir), "", "an empty pack has no table");
  fs.writeFileSync(path.join(dir, "pack.json"), JSON.stringify({ id: "game.x", params: [{ name: "gone", file: "data/a.json", path: "no.such", label: "Gone" }] }));
  fs.writeFileSync(path.join(dir, "data", "a.json"), JSON.stringify({ speed: 4, name: "x", deep: { on: true, list: [1, 2, 3, 4, 5, 6], rows: [{ w: 1 }, { w: 2 }, { w: 3 }, { w: 4 }] }, long: "x".repeat(60) }));
  fs.writeFileSync(path.join(dir, "data", "broken.json"), "{ not json");
  fs.writeFileSync(path.join(dir, "scripts", "main.gd"), 'extends Node\nconst BALL_SIZE := 0.4\n# "radius": 9 in a comment does not count\nvar x = make({"radius": 0.2})\n');
  const text = presentValuesText(dir);
  assert.match(text, /- Gone \(`gone`\): `data\/a\.json` `no\.such` = \(not found in the file\)/);
  assert.match(text, /- `data\/a\.json`: speed = 4; name = "x"; deep\.on = true; deep\.rows\.0\.w = 1; deep\.rows\.1\.w = 2; deep\.rows\.2\.w = 3$/m, "a long list is content: three entries, no long string, no 6-number list");
  assert.ok(!text.includes("broken.json"));
  assert.match(text, /- `scripts\/main\.gd:2`: const BALL_SIZE := 0\.4\n- `scripts\/main\.gd:4`: var x = make\(\{"radius": 0\.2\}\)/);
  assert.ok(!text.includes('"radius": 9'));
});

// ---------------------------------------------------------------- 4. the inbox

test("4 inbox: entries are strict lines appended whole; a drain writes each as the event it would have been, once, in file order; a refused entry is listed and never tried again", async () => {
  const job = tempJob("inbox-unit");
  const s0 = await foremanFor(job, { promoteTo: "job", script: scriptWith([{ match: { role: "builder", package: "paddle_ai", round: 2 }, text: "QUESTION: May the paddle be wider?" }]) }).foreman.run();
  assert.equal(s0.jobState?.state, "paused");
  const a = writeInbox(job.jobDir, { kind: "answer", package: "paddle_ai", text: "Yes, wider.", by: "player", change: "core" });
  const b = writeInbox(job.jobDir, { kind: "change", text: "Bigger ball.", package: "core" });
  const c = writeInbox(job.jobDir, { kind: "answer", package: "court", text: "nobody asked", by: "player" });
  const d = writeInbox(job.jobDir, { kind: "change", text: "x", package: "ghost" });
  // A line another process is still writing (no newline yet) and a line that is not an entry.
  fs.appendFileSync(path.join(job.jobDir, INBOX_FILE), '{"kind":"change","text":"an unknown key","id":"z","ts":"t","extra":1}\n{"id":"torn","kind":"cha');
  const read = readInbox(job.jobDir);
  assert.deepEqual(read.entries.map((e) => e.id), [a.id, b.id, c.id, d.id]);
  assert.deepEqual(read.bad.map((x) => x.problem), ['unknown key "extra"']);
  const log = JobLog.open(job.jobDir);
  try {
    const before = log.events.length;
    const r = drainInbox(job.jobDir, () => log.events, () => log.state, (body) => log.append(body));
    assert.deepEqual(r.appended.map((e) => `${e.type}:${e.type === "answer" || e.type === "change_requested" ? e.inbox : ""}`), [`answer:${a.id}`, `change_requested:${a.id}`, `change_requested:${b.id}`]);
    assert.deepEqual(r.rejected.map((x) => x.reason), ["package court has no open question", "unknown package ghost (the plan has: core, court, paddle_ai)"]);
    assert.equal(log.state.packages["paddle_ai"]?.lastAnswer, "Yes, wider.");
    assert.deepEqual(log.state.changes.map((x) => `${x.package}:${x.state}`), ["core:pending", "core:pending"]);
    // Again: nothing new, nothing twice, the refused ones are not looked at again.
    const again = drainInbox(job.jobDir, () => log.events, () => log.state, (body) => log.append(body));
    assert.deepEqual([again.appended.length, again.rejected.length, log.events.length], [0, 0, before + 3]);
    assert.equal(fs.readFileSync(path.join(job.jobDir, INBOX_REJECTED_FILE), "utf8").trim().split("\n").length, 2);
  } finally {
    log.close();
  }
  // A kill between the two events of one entry (answer --change): the second half is written by the next drain, the first is not repeated.
  const job2 = tempJob("inbox-half");
  await foremanFor(job2, { promoteTo: "job", script: scriptWith([{ match: { role: "builder", package: "paddle_ai", round: 2 }, text: "QUESTION: May the paddle be wider?" }]) }).foreman.run();
  const e = writeInbox(job2.jobDir, { kind: "answer", package: "paddle_ai", text: "Yes.", by: "player", change: "core" });
  const half = JobLog.open(job2.jobDir);
  half.append({ type: "answer", package: "paddle_ai", text: "Yes.", by: "player", inbox: e.id });
  half.close();
  const log2 = JobLog.open(job2.jobDir);
  try {
    const r = drainInbox(job2.jobDir, () => log2.events, () => log2.state, (body) => log2.append(body));
    assert.deepEqual(r.appended.map((x) => x.type), ["change_requested"]);
    assert.equal(ofType(log2.events as JobEvent[], "answer").length, 1);
  } finally {
    log2.close();
  }
});

test("4 inbox: a running Foreman takes an answer while another package is still building, starts the asking package again at once, and re-opens a finished package for a change request without a pause", async () => {
  const job = tempJob("inbox-run");
  const asks: FakeStep = { match: { role: "builder", package: "paddle_ai", round: 1, attempt: 1 }, text: "QUESTION: May the paddle be wider than the contract says?" };
  const answered: FakeStep = { match: { role: "builder", package: "paddle_ai", promptIncludes: "Answer to your question: Yes, up to 2 m." }, write: { "data/ai.json": '{\n "reaction_frames": 8,\n "max_speed_mps": 6,\n "error_m": 0.3\n}\n', "scripts/paddle_ai.gd": "extends RefCounted\n\nfunc decide(ball_y: float, paddle_y: float, tuning: Dictionary) -> float:\n\treturn signf(ball_y - paddle_y)\n" }, text: "Done.\nDEVIATIONS: none" };
  const slowCourt: FakeStep = { ...(scriptWith().steps.find((x) => x.match?.package === "court") as FakeStep), delayMs: 1500 };
  const core2: FakeStep = { match: { role: "builder", package: "core", round: 2 }, write: { "scripts/main.gd": 'extends Node\n\nfunc _pack_tick(frame: int) -> void:\n\tpass\n\nfunc _pack_state() -> Dictionary:\n\treturn {"big_ball": true}\n' }, text: "Bigger ball.\nDEVIATIONS: none" };
  const script = scriptWith([asks, answered, core2]);
  script.steps = script.steps.map((x) => (x.match?.package === "court" ? slowCourt : x));
  let wrote = false;
  const { foreman } = foremanFor(job, {
    promoteTo: "job",
    parallel: 2,
    inboxPollMs: 25,
    script,
    // What `foreman answer` and `foreman change` do in a second process while this one holds the lock.
    onEvent: (ev) => {
      if (ev.type !== "question" || wrote) return;
      wrote = true;
      writeInbox(job.jobDir, { kind: "answer", package: "paddle_ai", text: "Yes, up to 2 m.", by: "player" });
      writeInbox(job.jobDir, { kind: "change", text: "Make the ball bigger.", package: "core" });
    },
  });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  const answer = ofType(evs, "answer");
  const change = ofType(evs, "change_requested");
  assert.deepEqual([answer.length, change.length], [1, 1], "each exactly once");
  assert.ok(answer[0]?.inbox !== undefined && change[0]?.inbox !== undefined && answer[0].inbox !== change[0].inbox);
  assert.ok((answer[0]?.seq ?? 0) < (change[0]?.seq ?? 0), "in the order they were written");
  // The other package was still building: court's builder had not answered yet when the answer was logged.
  const courtBuilt = ofType(evs, "builder_run").find((e) => e.package === "court")?.seq ?? 0;
  assert.ok((answer[0]?.seq ?? 0) < courtBuilt, "the answer was taken while court was still being built");
  const askerAgain = ofType(evs, "package_state").find((e) => e.package === "paddle_ai" && e.state === "running" && e.seq > (answer[0]?.seq ?? 0))?.seq ?? Infinity;
  assert.ok(askerAgain < courtBuilt, "the asking package went on while court was still being built");
  // The change request re-opened the finished core at once; the job never paused.
  const reopened = ofType(evs, "reopened");
  assert.deepEqual(reopened.map((e) => e.package), ["core"]);
  assert.ok((reopened[0]?.seq ?? Infinity) < courtBuilt);
  assert.ok(!ofType(evs, "job_state").some((e) => e.state === "paused"));
  assert.deepEqual(ofType(evs, "job_state").map((e) => e.state), ["running", "done"]);
  assert.match(fs.readFileSync(path.join(job.jobDir, "pack", "scripts", "main.gd"), "utf8"), /big_ball/);
  assert.equal(rebuildState(job.jobDir, { write: false }).changes[0]?.state, "reopened");
});

test("4 inbox: a change request for a package that is being built waits in the log as pending and is applied when that package is finished; one left in the inbox by a Foreman that ended is taken by the next command", async () => {
  const job = tempJob("inbox-busy");
  const slowAi: FakeStep = { match: { role: "builder", package: "paddle_ai", round: 1 }, delayMs: 700, write: { "data/ai.json": '{\n "reaction_frames": 8,\n "max_speed_mps": 6,\n "error_m": 0.3\n}\n', "scripts/paddle_ai.gd": "extends RefCounted\n\nfunc decide(ball_y: float, paddle_y: float, tuning: Dictionary) -> float:\n\treturn signf(ball_y - paddle_y)\n" }, text: "Done.\nDEVIATIONS: none" };
  const ai2: FakeStep = { match: { role: "builder", package: "paddle_ai", round: 2 }, write: { "scripts/paddle_ai.gd": "extends RefCounted\n\nfunc decide(ball_y: float, paddle_y: float, tuning: Dictionary) -> float:\n\treturn 0.5 * signf(ball_y - paddle_y)\n" }, text: "Slower.\nDEVIATIONS: none" };
  let wrote = false;
  const { foreman } = foremanFor(job, {
    promoteTo: "job",
    parallel: 2,
    inboxPollMs: 25,
    script: scriptWith([slowAi, ai2], true),
    onEvent: (ev) => {
      // While paddle_ai is in its first round (running, not finished): a change request FOR paddle_ai.
      if (ev.type !== "package_state" || ev.package !== "paddle_ai" || ev.state !== "running" || wrote) return;
      wrote = true;
      writeInbox(job.jobDir, { kind: "change", text: "Make the opponent slower.", package: "paddle_ai" });
    },
  });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  const change = ofType(evs, "change_requested")[0];
  const firstMerge = ofType(evs, "merge").find((e) => e.package === "paddle_ai");
  const reopened = ofType(evs, "reopened")[0];
  assert.ok(change && firstMerge && reopened);
  assert.ok(change.seq < firstMerge.seq, "logged while the package was being built");
  assert.ok(reopened.seq > firstMerge.seq, "applied only after that package's merge");
  assert.equal(reopened.package, "paddle_ai");
  assert.deepEqual(states(evs, "paddle_ai").slice(-4), ["queued2", "running2", "verifying2", "promoted2"]);

  // Left over: written when no Foreman was looking any more. `foreman answer|change|run|resume` takes it first.
  const left = writeInbox(job.jobDir, { kind: "change", text: "Higher walls.", package: "court" });
  const out = await cli(["change", job.jobDir, "And a wider court.", "--package", "court", "--no-run"]);
  assert.equal(out.exitCode, 0, out.stderr);
  const tail = ofType(readEvents(job.jobDir), "change_requested").slice(-2);
  assert.deepEqual(tail.map((e) => [e.text, e.inbox]), [["Higher walls.", left.id], ["And a wider court.", undefined]]);
});

test("4 inbox: when no builder is in flight a change request is applied whatever state its package is in, as before P10 (a job that failed on a package is asked to try that package again)", async () => {
  const job = tempJob("change-failed");
  // The fixture's paddle_ai fails its first round; with one round per package the job fails on it.
  const s = await foremanFor(job, { promoteTo: "job", roundLimit: 1 }).foreman.run();
  assert.equal(s.jobState?.state, "failed", JSON.stringify(s.jobState));
  assert.equal(s.packages["paddle_ai"]?.state, "failed");
  const before = s.lastSeq;
  request(job.jobDir, "Keep the opponent simple: follow the ball.", "paddle_ai");
  const again = await foremanFor(job, { promoteTo: "job" }).foreman.run();
  assert.equal(again.jobState?.state, "done", JSON.stringify(again.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > before);
  assert.deepEqual(ofType(later, "reopened").map((e) => e.package), ["paddle_ai"]);
  assert.deepEqual(states(later, "paddle_ai"), ["queued2", "running2", "verifying2", "promoted2"]);
  assert.equal(rebuildState(job.jobDir, { write: false }).changes[0]?.state, "reopened");
});

test("4 inbox, two processes on one job: a running fake-adapter job receives an answer and a change request from `foreman answer` and `foreman change`; the log shows both exactly once and in order; no lock error", async () => {
  const job = tempJob("inbox-2proc");
  const base = scriptWith([], true);
  const asks: FakeStep = { match: { role: "builder", package: "paddle_ai", round: 1, attempt: 1 }, text: "QUESTION: May the paddle be wider than the contract says?" };
  const answered: FakeStep = { match: { role: "builder", package: "paddle_ai", promptIncludes: "Answer to your question:" }, write: { "data/ai.json": '{\n "reaction_frames": 8,\n "max_speed_mps": 6,\n "error_m": 0.3\n}\n', "scripts/paddle_ai.gd": "extends RefCounted\n\nfunc decide(ball_y: float, paddle_y: float, tuning: Dictionary) -> float:\n\treturn signf(ball_y - paddle_y)\n" }, text: "Done.\nDEVIATIONS: none" };
  const core2: FakeStep = { match: { role: "builder", package: "core", round: 2 }, write: { "scripts/main.gd": 'extends Node\n\nfunc _pack_tick(frame: int) -> void:\n\tpass\n\nfunc _pack_state() -> Dictionary:\n\treturn {"big_ball": true}\n' }, text: "Bigger ball.\nDEVIATIONS: none" };
  // court takes 12 s: long enough for two more node processes to start on a busy machine.
  const steps = [asks, answered, core2, ...base.steps.map((x) => (x.match?.package === "court" ? { ...x, delayMs: 12_000 } : x))];
  fs.writeFileSync(path.join(job.jobDir, "fake-builder.json"), JSON.stringify({ ...base, steps }, null, 1));
  const running = cli(["run", job.jobDir, "--adapter", "fake", "--parallel", "2", "--no-critic", "--inbox-poll-ms", "100", "--quiet"]);
  // Process 2 waits for the question (it reads the log as `follow` does, without a lock).
  const logFile = path.join(job.jobDir, "job.jsonl");
  const deadline = Date.now() + 60_000;
  while (Date.now() < deadline && !(fs.existsSync(logFile) && fs.readFileSync(logFile, "utf8").includes('"type":"question"'))) await sleep(50);
  assert.ok(fs.readFileSync(logFile, "utf8").includes('"type":"question"'), "the running job asked its question");
  const ans = await cli(["answer", job.jobDir, "paddle_ai", "Yes, up to 2 m."]);
  const chg = await cli(["change", job.jobDir, "Make the ball bigger.", "--package", "core", "--adapter", "fake"]);
  const run = await running;
  for (const r of [ans, chg, run]) assert.ok(!/another Foreman|holds .*foreman\.lock/.test(r.stdout + r.stderr), `no lock error: ${r.stdout}${r.stderr}`);
  assert.equal(ans.exitCode, 0, ans.stderr);
  assert.equal(chg.exitCode, 0, chg.stderr);
  assert.equal(run.exitCode, 0, run.stdout + run.stderr);
  assert.match(ans.stdout, /^answer handed to the running Foreman \(pid \d+\) through inbox\.jsonl as entry [0-9a-f-]{36}; it continues without a resume/);
  assert.match(chg.stdout, /^change request handed to the running Foreman \(pid \d+\) through inbox\.jsonl as entry [0-9a-f-]{36} for package core/);
  const evs = readEvents(job.jobDir);
  const answer = ofType(evs, "answer");
  const change = ofType(evs, "change_requested");
  assert.deepEqual([answer.length, change.length], [1, 1], "both exactly once");
  assert.deepEqual([answer[0]?.text, change[0]?.text, change[0]?.package], ["Yes, up to 2 m.", "Make the ball bigger.", "core"]);
  const ids = readInbox(job.jobDir).entries.map((e) => e.id);
  assert.deepEqual([answer[0]?.inbox, change[0]?.inbox], ids, "the events carry the ids of the two inbox lines, in the order of the file");
  assert.ok((answer[0]?.seq ?? 0) < (change[0]?.seq ?? 0), "in order");
  // Both were acted on by the process that held the lock, while court was still being built, and the job ended done.
  const courtBuilt = ofType(evs, "builder_run").find((e) => e.package === "court")?.seq ?? 0;
  assert.ok((answer[0]?.seq ?? 0) < courtBuilt && (change[0]?.seq ?? 0) < courtBuilt, "taken while court was still being built");
  assert.deepEqual(ofType(evs, "reopened").map((e) => e.package), ["core"]);
  assert.deepEqual(ofType(evs, "job_state").map((e) => e.state), ["running", "done"]);
  assert.ok(!fs.existsSync(path.join(job.jobDir, "foreman.lock")));
  // seq is the line number throughout: one writer wrote every line.
  assert.deepEqual(evs.map((e) => e.seq), evs.map((_e, i) => i + 1));
});

