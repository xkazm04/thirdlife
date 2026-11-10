import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempJob, foremanFor, readEvents, scriptWith, packFiles, fastVerifier, Kill, fixtureScript } from "./helpers.js";
import { FakeBuilder, type FakeStep } from "../builder/fake.js";
import { MessagesApiBuilder } from "../builder/messages-api.js";
import { rebuildState, JobLog } from "../joblog.js";
import type { JobEvent } from "../events.js";

after(cleanup);

const ofType = <T extends JobEvent["type"]>(evs: JobEvent[], type: T): Extract<JobEvent, { type: T }>[] => evs.filter((e) => e.type === type) as Extract<JobEvent, { type: T }>[];
const states = (evs: JobEvent[], pkg: string): string[] => ofType(evs, "package_state").filter((e) => e.package === pkg).map((e) => `${e.state}${e.round}`);
const builderRuns = (evs: JobEvent[], pkg: string): number => ofType(evs, "builder_run").filter((e) => e.package === pkg).length;

test("three-package fixture builds to promoted; the pack lands in <engine>/packs/<id>/", async () => {
  const job = tempJob("happy");
  const { foreman } = foremanFor(job);
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done");
  assert.deepEqual(s.order.map((id) => s.packages[id]?.state), ["promoted", "promoted", "promoted"]);
  assert.deepEqual(s.promoted, { packId: "game.paddle_court", version: "0.1.0", dest: "packs/game.paddle_court" });
  const promoted = packFiles(path.join(job.engineDir, "packs", "game.paddle_court"));
  assert.deepEqual(Object.keys(promoted).sort(), ["data/ai.json", "data/court.json", "pack.json", "scripts/court.gd", "scripts/main.gd", "scripts/paddle_ai.gd", "tests/bot_rally.gd"]);
  assert.deepEqual(promoted, packFiles(path.join(job.jobDir, "pack")));
  const evs = readEvents(job.jobDir);
  // billing is in the log before the first builder_run
  const billingAt = evs.findIndex((e) => e.type === "billing");
  const firstRun = evs.findIndex((e) => e.type === "builder_run");
  assert.ok(billingAt !== -1 && billingAt < firstRun);
  // dependency order: core is promoted before court or paddle_ai start running
  const corePromoted = evs.findIndex((e) => e.type === "package_state" && e.package === "core" && e.state === "promoted");
  const othersRunning = evs.findIndex((e) => e.type === "package_state" && e.package !== "core" && e.state === "running");
  assert.ok(corePromoted < othersRunning);
  // every file the events point at exists
  for (const e of evs) {
    if (e.type === "verify") assert.ok(fs.existsSync(path.join(job.jobDir, e.report)), e.report);
    if (e.type === "builder_run" && e.transcript) assert.ok(fs.existsSync(path.join(job.jobDir, e.transcript)), e.transcript);
  }
  // the final gate went through V4
  assert.deepEqual(ofType(evs, "verify").filter((e) => e.report.startsWith("reports/final-")).map((e) => `${e.verb}:${e.ok}`), ["lint:true", "smoke:true", "invariants:true", "bot:true"]);
  assert.deepEqual(ofType(evs, "milestone").map((e) => e.milestone), ["blockout", "greybox"]);
  // running it again changes nothing
  const before = readEvents(job.jobDir).length;
  await foremanFor(job).foreman.run();
  assert.equal(readEvents(job.jobDir).length, before);
});

test("a builder that claims success while the verifier fails is not promoted: the round increments and the report goes back", async () => {
  const job = tempJob("claim");
  const { foreman, builder } = foremanFor(job);
  await foreman.run();
  const evs = readEvents(job.jobDir);
  // Round 1 of paddle_ai: builder outcome ok, text "everything works perfectly", smoke fails.
  const run1 = ofType(evs, "builder_run").find((e) => e.package === "paddle_ai" && e.round === 1);
  assert.equal(run1?.outcome, "ok");
  assert.deepEqual(states(evs, "paddle_ai"), ["queued1", "running1", "verifying1", "running2", "verifying2", "promoted2"]);
  const failed = ofType(evs, "verify").find((e) => e.package === "paddle_ai" && !e.ok);
  assert.deepEqual([failed?.round, failed?.verb, failed?.exitCode], [1, "smoke", 1]);
  // Nothing of paddle_ai was merged in round 1.
  const merges = ofType(evs, "merge").filter((e) => e.package === "paddle_ai");
  assert.equal(merges.length, 1);
  assert.ok(evs.indexOf(merges[0] as JobEvent) > evs.findIndex((e) => e.type === "package_state" && e.package === "paddle_ai" && e.state === "verifying" && e.round === 2));
  // Round 2's prompt carries the tl.verify/1 report of round 1.
  const round2 = builder.calls.find((c) => c.req.meta?.package === "paddle_ai" && c.req.meta.round === 2);
  assert.match(round2?.req.prompt ?? "", /The Verifier did not pass round 1: smoke \(V2\) on your workspace/);
  assert.match(round2?.req.prompt ?? "", /"schema":"tl\.verify\/1"/);
  assert.match(round2?.req.prompt ?? "", /script_error/);
  assert.match(round2?.req.prompt ?? "", /Round 2 of 4/);
});

test("after the round limit the package is `failed` with cause verify_failed; dependants are blocked, the job fails, nothing is promoted", async () => {
  const job = tempJob("limit");
  const liar: FakeStep = { match: { role: "builder", package: "core" }, write: { ...(fixtureScript().steps[0]?.write ?? {}), "scripts/main.gd": "extends Node\nfunc _pack_tick(frame):\n\tFAKE_SCRIPT_ERROR()\n" }, text: "Done, all tests pass." };
  const { foreman, builder } = foremanFor(job, { script: scriptWith([liar]) });
  const s = await foreman.run();
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "running2", "verifying2", "running3", "verifying3", "running4", "verifying4", "failed4"]);
  assert.equal(builder.calls.length, 4, "four rounds, four builder runs, no more");
  assert.deepEqual([s.packages["core"]?.state, s.packages["core"]?.cause, s.packages["core"]?.round], ["failed", "verify_failed", 4]);
  assert.deepEqual([s.packages["court"]?.state, s.packages["court"]?.cause], ["blocked", "dependency"]);
  assert.deepEqual([s.packages["paddle_ai"]?.state, s.packages["paddle_ai"]?.cause], ["blocked", "dependency"]);
  assert.equal(s.jobState?.state, "failed");
  assert.equal(ofType(evs, "merge").length, 0);
  assert.equal(ofType(evs, "promoted").length, 0);
  assert.deepEqual(packFiles(path.join(job.jobDir, "pack")), {});
  assert.ok(!fs.existsSync(path.join(job.engineDir, "packs")));
});

test("out-of-scope files are dropped before verification, recorded in the log, and never reach pack/", async () => {
  const job = tempJob("scope");
  const sneaky: FakeStep = {
    match: { role: "builder", package: "court" },
    write: { ...(fixtureScript().steps[1]?.write ?? {}), "scripts/main.gd": "extends Node\n# court's builder rewrote core's file\n", "tests/extra_bot.gd": "extends Node\n", "docs/readme.md": "hi\n" },
  };
  const { foreman } = foremanFor(job, { script: scriptWith([sneaky]) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done");
  const evs = readEvents(job.jobDir);
  const verifying = ofType(evs, "package_state").find((e) => e.package === "court" && e.state === "verifying");
  assert.equal(verifying?.detail, "dropped out-of-scope files: docs/readme.md, scripts/main.gd, tests/extra_bot.gd");
  const coreVerifying = ofType(evs, "package_state").find((e) => e.package === "core" && e.state === "verifying");
  assert.equal(coreVerifying?.detail, "dropped out-of-scope files: NOTES.txt, pack.json (edited by the builder; the Foreman's composed manifest was put back)");
  assert.deepEqual(ofType(evs, "merge").find((e) => e.package === "court")?.files, ["data/court.json", "scripts/court.gd"]);
  const pack = packFiles(path.join(job.jobDir, "pack"));
  assert.ok(!("docs/readme.md" in pack) && !("tests/extra_bot.gd" in pack) && !("NOTES.txt" in pack));
  assert.ok(!(pack["scripts/main.gd"] ?? "").includes("rewrote"), "core's file must be what core's builder wrote");
});

test("builder timeout and truncation are typed outcomes in the log; the package retries and, at the limit, fails with the right cause", async () => {
  const job = tempJob("typed");
  const steps: FakeStep[] = [
    { match: { role: "builder", package: "core", round: 1 }, hang: true },
    { match: { role: "builder", package: "core", round: 2 }, outcome: "truncated", text: "I wrote pack.json and then" },
    { match: { role: "builder", package: "court" }, outcome: "truncated", text: "cut" },
    { match: { role: "builder", package: "paddle_ai" }, hang: true },
  ];
  const { foreman, builder } = foremanFor(job, { script: scriptWith(steps), builderTimeoutMs: 40, roundLimit: 3 });
  const s = await foreman.run();
  const evs = readEvents(job.jobDir);
  assert.deepEqual(ofType(evs, "builder_run").filter((e) => e.package === "core").map((e) => e.outcome), ["timeout", "truncated", "ok"]);
  assert.equal(s.packages["core"]?.state, "promoted");
  assert.equal(s.packages["core"]?.round, 3);
  // a non-ok builder run never moves a package to verifying
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "running2", "running3", "verifying3", "promoted3"]);
  assert.match(builder.calls.find((c) => c.req.meta?.package === "core" && c.req.meta.round === 2)?.req.prompt ?? "", /ended with outcome "timeout"/);
  assert.match(builder.calls.find((c) => c.req.meta?.package === "core" && c.req.meta.round === 3)?.req.prompt ?? "", /the answer was cut off/);
  assert.deepEqual([s.packages["court"]?.state, s.packages["court"]?.cause], ["failed", "builder_truncated"]);
  assert.deepEqual([s.packages["paddle_ai"]?.state, s.packages["paddle_ai"]?.cause], ["failed", "builder_timeout"]);
  assert.equal(s.jobState?.state, "failed");
});

test("exit code and outcome disagreement from the runner fails the round and is visible in the verdict file", async () => {
  const job = tempJob("disagree");
  const { foreman } = foremanFor(job, { verifier: fastVerifier(job.engineDir, { FAKE_RUNNER_MODE: "disagree" }), roundLimit: 1 });
  const s = await foreman.run();
  assert.deepEqual([s.packages["core"]?.state, s.packages["core"]?.cause], ["failed", "verify_failed"]);
  const v = ofType(readEvents(job.jobDir), "verify")[0];
  assert.deepEqual([v?.ok, v?.exitCode], [false, 1]);
  const verdict = JSON.parse(fs.readFileSync(path.join(job.jobDir, (v?.report ?? "").replace(/\.json$/, ".verdict.json")), "utf8")) as { flags: string[] };
  assert.deepEqual(verdict.flags, ["exit_outcome_disagree"]);
  assert.match(s.packages["core"]?.detail ?? "", /exit code 1 means failed, the report says passed/);
});

test("a whole-pack failure after a clean workspace run does not merge: pack/ only ever holds verified files", async () => {
  // court passes in its own workspace only because the file that breaks the pack is out of its scope there.
  const job = tempJob("gate");
  let calls = 0;
  const inner = fastVerifier(job.engineDir);
  const flaky = Object.create(inner) as typeof inner;
  // Fail exactly one whole-pack smoke (the candidate of court, round 1).
  flaky.run = async (req) => {
    const r = await inner.run(req);
    if (req.verb === "smoke" && req.packDir.includes("_candidate_court") && calls++ === 0) return { ...r, ok: false, summary: "forced whole-pack failure" };
    return r;
  };
  const { foreman } = foremanFor(job, { verifier: flaky });
  const s = await foreman.run();
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "court"), ["queued1", "running1", "verifying1", "running2", "verifying2", "promoted2"]);
  const packLevelFail = ofType(evs, "verify").find((e) => e.package === undefined && !e.ok);
  assert.ok(packLevelFail?.report.startsWith("reports/court-r1-pack-smoke"));
  assert.equal(ofType(evs, "merge").filter((e) => e.package === "court").length, 1);
  assert.equal(s.jobState?.state, "done");
});

test("kill at every event of the run, then resume: same outcome, same pack, and no promoted package is rebuilt", async () => {
  const ref = tempJob("ref");
  await foremanFor(ref).foreman.run();
  const refEvents = readEvents(ref.jobDir);
  const refPack = packFiles(path.join(ref.jobDir, "pack"));
  const total = refEvents.length;
  assert.ok(total > 40);
  let resumedSeen = 0;
  for (let killAt = 5; killAt < total; killAt++) {
    const job = tempJob(`kill${killAt}`);
    const { foreman } = foremanFor(job, {
      afterAppend: (ev) => {
        if (ev.seq === killAt) throw new Kill(killAt);
      },
    });
    await assert.rejects(foreman.run(), (e: unknown) => e instanceof Kill);
    const atKill = rebuildState(job.jobDir, { write: false });
    assert.equal(atKill.lastSeq, killAt);
    const promotedAtKill = Object.values(atKill.packages).filter((p) => p.state === "promoted").map((p) => p.id);
    const runsAtKill = new Map(promotedAtKill.map((id) => [id, builderRuns(readEvents(job.jobDir), id)]));
    const midFlight = Object.values(atKill.packages).filter((p) => p.state === "running" || p.state === "verifying");

    const s = await foremanFor(job).foreman.run();
    const evs = readEvents(job.jobDir);
    assert.equal(s.jobState?.state, "done", `kill at ${killAt}: job did not finish`);
    assert.deepEqual(s.order.map((id) => [id, s.packages[id]?.state, s.packages[id]?.round]), [["core", "promoted", 1], ["court", "promoted", 1], ["paddle_ai", "promoted", 2]], `kill at ${killAt}`);
    assert.deepEqual(packFiles(path.join(job.jobDir, "pack")), refPack, `kill at ${killAt}: pack differs`);
    assert.deepEqual(packFiles(path.join(job.engineDir, "packs", "game.paddle_court")), refPack, `kill at ${killAt}: promoted pack differs`);
    for (const [id, n] of runsAtKill) assert.equal(builderRuns(evs, id), n, `kill at ${killAt}: promoted package ${id} was rebuilt`);
    // A package caught mid-flight restarts the same round, and the log says "resumed".
    for (const p of midFlight) {
      const after = ofType(evs, "package_state").find((e) => e.seq > killAt && e.package === p.id);
      assert.equal(after?.round, p.round, `kill at ${killAt}: ${p.id} did not restart the same round`);
      assert.match(after?.detail ?? "", /resumed/, `kill at ${killAt}: ${p.id} restart is not marked resumed`);
      resumedSeen += 1;
    }
    assert.equal(ofType(evs, "promoted").length, 1);
    // work already paid for is not paid twice: an ok builder run for a round is never repeated
    const okRuns = ofType(evs, "builder_run").filter((e) => e.outcome === "ok").map((e) => `${e.package}:${e.round}`);
    assert.equal(new Set(okRuns).size, okRuns.length, `kill at ${killAt}: an ok builder round ran twice (${okRuns.join(",")})`);
  }
  assert.ok(resumedSeen > 10);
});

test("parallel build: two packages are in flight at once and the result equals the serial one", async () => {
  const serial = tempJob("serial");
  await foremanFor(serial).foreman.run();
  const job = tempJob("parallel");
  const { foreman } = foremanFor(job, { parallel: 3, script: scriptWith([], true) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done");
  const evs = readEvents(job.jobDir);
  const live = new Set<string>();
  let peak = 0;
  for (const e of ofType(evs, "package_state")) {
    if (e.state === "running" || e.state === "verifying") live.add(e.package);
    else live.delete(e.package);
    peak = Math.max(peak, live.size);
  }
  assert.equal(peak, 2, "court and paddle_ai depend only on core and run together");
  assert.deepEqual(packFiles(path.join(job.jobDir, "pack")), packFiles(path.join(serial.jobDir, "pack")));
});

test("budget tokens_per_hour: the job pauses when the hour's tokens are spent and resumes when the window moves (budget events)", async () => {
  const job = tempJob("budget");
  let clock = Date.parse("2026-11-10T20:00:00.000Z");
  const sleeps: number[] = [];
  const { foreman } = foremanFor(job, {
    budget: { kind: "tokens_per_hour", limit: 8000 },
    now: () => new Date((clock += 1)),
    // Ten minutes pass after core's builder run, so court's tokens are still inside the hour when core's leave it.
    onEvent: (ev) => {
      if (ev.type === "builder_run" && ev.package === "core") clock += 600_000;
    },
    sleep: async (ms) => {
      sleeps.push(ms);
      clock += ms;
    },
  });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done");
  const evs = readEvents(job.jobDir);
  const budget = ofType(evs, "budget");
  // core costs 6100 tokens (< 8000: court may start), court brings it to 10800: paddle_ai must wait.
  // The policy itself is the first budget event: it is in the log before anything is spent.
  assert.deepEqual(budget.map((e) => e.state), ["running", "paused", "running", "paused", "running"]);
  assert.equal(budget[0]?.reason, "policy set");
  assert.ok((budget[0]?.seq ?? 0) < (evs.find((e) => e.type === "builder_run")?.seq ?? 0));
  assert.match(budget[1]?.reason ?? "", /tokens_per_hour: 10800 tokens used in the last hour, limit 8000/);
  assert.deepEqual(budget[1]?.policy, { kind: "tokens_per_hour", limit: 8000 });
  assert.ok(sleeps.length >= 2 && sleeps.every((ms) => ms > 0 && ms <= 3_600_000));
  const blocked = ofType(evs, "package_state").filter((e) => e.state === "blocked");
  assert.deepEqual(blocked.map((e) => [e.package, e.cause]), [["paddle_ai", "budget"], ["paddle_ai", "budget"]]);
  // no builder run starts while the budget is paused
  let paused = false;
  for (const e of evs) {
    if (e.type === "budget") paused = e.state === "paused";
    if (e.type === "builder_run") assert.equal(paused, false, `builder_run at seq ${e.seq} during a pause`);
  }
  // WP3c item 7: the job has ended, so the derived state is closed; the last budget EVENT still says running.
  assert.equal(s.budget?.state, "closed");
  assert.equal(s.budget?.open?.state, "running");
});

test("simulated rate limit: the builder's rate-limit error pauses the job, the same round is retried, no round is spent", async () => {
  const job = tempJob("ratelimit");
  const slept: number[] = [];
  const limit: FakeStep = { match: { role: "builder", package: "court", attempt: 1 }, outcome: "error", error: { kind: "rate_limit", message: "Claude usage limit reached", retryAfterMs: 90_000 } };
  const { foreman } = foremanFor(job, { script: scriptWith([limit]), sleep: async (ms) => void slept.push(ms) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done");
  const evs = readEvents(job.jobDir);
  assert.deepEqual(ofType(evs, "builder_run").filter((e) => e.package === "court").map((e) => [e.round, e.outcome]), [[1, "error"], [1, "ok"]]);
  assert.deepEqual(states(evs, "court"), ["queued1", "running1", "blocked1", "running1", "verifying1", "promoted1"]);
  assert.deepEqual(ofType(evs, "budget").map((e) => [e.state, e.policy.kind]), [["paused", "tokens_per_hour"], ["running", "tokens_per_hour"]]);
  assert.match(ofType(evs, "budget")[0]?.reason ?? "", /^rate_limit: Claude usage limit reached/);
  assert.deepEqual(slept, [90_000]);
  assert.equal(s.packages["court"]?.round, 1);
});

test("budget only_while_playing and overnight decide from the injected signal and clock", async () => {
  const { budgetVerdict } = await import("../budget.js");
  const { emptyState } = await import("../joblog.js");
  const st = emptyState("j");
  assert.deepEqual(budgetVerdict({ kind: "only_while_playing" }, st, { now: () => new Date(), isPlaying: () => true }), { allowed: true });
  assert.equal(budgetVerdict({ kind: "only_while_playing" }, st, { now: () => new Date(), isPlaying: () => false }).allowed, false);
  const at = (h: number, m = 0): (() => Date) => () => new Date(2026, 10, 10, h, m, 0);
  assert.equal(budgetVerdict({ kind: "overnight", limit: "22:00-07:00" }, st, { now: at(23) }).allowed, true);
  assert.equal(budgetVerdict({ kind: "overnight", limit: "22:00-07:00" }, st, { now: at(3) }).allowed, true);
  const day = budgetVerdict({ kind: "overnight", limit: "22:00-07:00" }, st, { now: at(15, 30) });
  assert.deepEqual(day.allowed ? 0 : day.waitMs, 6.5 * 3_600_000);
  assert.equal(budgetVerdict({ kind: "overnight", limit: "nonsense" }, st, { now: at(23) }).allowed, false);
  assert.deepEqual(budgetVerdict(undefined, st, { now: at(1) }), { allowed: true });

  const job = tempJob("playing");
  let playing = false;
  const { foreman } = foremanFor(job, { budget: { kind: "only_while_playing" }, isPlaying: () => playing, sleep: async () => void (playing = true) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done");
  assert.deepEqual(ofType(readEvents(job.jobDir), "budget").map((e) => e.state), ["running", "paused", "running"]);
});

test("an adapter that cannot run fails the job before any package starts, with billing already logged", async () => {
  const job = tempJob("refused");
  const { foreman } = foremanFor(job, { builder: new MessagesApiBuilder({ env: {} }) as never });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "failed");
  assert.match(s.jobState?.reason ?? "", /messages-api is not available/);
  const evs = readEvents(job.jobDir);
  assert.deepEqual(ofType(evs, "billing").map((e) => [e.adapter, e.mode]), [["messages-api", "api_key"]]);
  assert.equal(ofType(evs, "builder_run").length, 0);
});

test("a builder's question blocks its package and pauses the job; the answer goes into the next prompt", async () => {
  const job = tempJob("question");
  const ask: FakeStep = { match: { role: "builder", package: "court", attempt: 1 }, text: "I need one thing.\nQUESTION: how thick are the walls?" };
  const builder = new FakeBuilder(scriptWith([ask]));
  const s1 = await foremanFor(job, { builder }).foreman.run();
  assert.equal(s1.jobState?.state, "paused");
  assert.deepEqual([s1.packages["court"]?.state, s1.packages["court"]?.cause, s1.packages["court"]?.openQuestion], ["blocked", "question", "how thick are the walls?"]);
  assert.equal(s1.packages["paddle_ai"]?.state, "promoted", "an unrelated package is not held up");
  const log = JobLog.open(job.jobDir);
  log.append({ type: "answer", package: "court", text: "0.3 m", by: "player" });
  log.close();
  const s2 = await foremanFor(job, { builder }).foreman.run();
  assert.equal(s2.jobState?.state, "done");
  assert.match(builder.calls[builder.calls.length - 1]?.req.prompt ?? "", /Answer to your question: 0\.3 m/);

  // A kill between the builder's answer and the `question` event must not lose the question.
  const job2 = tempJob("question-kill");
  const builder2 = new FakeBuilder(scriptWith([ask]));
  await assert.rejects(
    foremanFor(job2, {
      builder: builder2,
      afterAppend: (ev) => {
        if (ev.type === "builder_run" && ev.package === "court") throw new Kill(ev.seq);
      },
    }).foreman.run(),
    Kill,
  );
  const s3 = await foremanFor(job2, { builder: builder2 }).foreman.run();
  assert.deepEqual([s3.jobState?.state, s3.packages["court"]?.state, s3.packages["court"]?.cause, s3.packages["court"]?.openQuestion], ["paused", "blocked", "question", "how thick are the walls?"]);
  assert.equal(readEvents(job2.jobDir).filter((e) => e.type === "builder_run" && e.package === "court").length, 1, "the question is recovered from the transcript, not bought again");
});

test("--retry-failed puts failed packages back in the queue; without it a failed package stays failed", async () => {
  const job = tempJob("retry");
  const bad: FakeStep = { match: { role: "builder", package: "core" }, outcome: "refused", error: { kind: "refusal", message: "no" } };
  const s1 = await foremanFor(job, { script: scriptWith([bad]) }).foreman.run();
  assert.deepEqual([s1.jobState?.state, s1.packages["core"]?.state, s1.packages["core"]?.cause], ["failed", "failed", "builder_error"]);
  const s2 = await foremanFor(job).foreman.run();
  assert.equal(s2.packages["core"]?.state, "failed");
  const s3 = await foremanFor(job, { retryFailed: true }).foreman.run();
  assert.equal(s3.jobState?.state, "done");
});
