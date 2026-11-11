// N3c: watchdog stalls at different frames are the machine; at the same frame, the pack (real hockey job, 2026-11-11).
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempJob, foremanFor, readEvents, scriptWith, fastVerifier, type TempJob } from "./helpers.js";
import { FakeBuilder, type FakeStep } from "../builder/fake.js";
import type { JobEvent } from "../events.js";
import { JobLog } from "../joblog.js";
import { FOREMAN_NOTE, MACHINE_BUSY, PACK_STALL, classifyStalls, restsOnAClock, stallOf } from "../foreman.js";
import type { VerifyReport, VerifyResult } from "../verifier.js";
import { PKG_ROOT } from "../paths.js";

after(cleanup);

const ofType = <T extends JobEvent["type"]>(evs: JobEvent[], type: T): Extract<JobEvent, { type: T }>[] => evs.filter((e) => e.type === type) as Extract<JobEvent, { type: T }>[];
const states = (evs: JobEvent[], pkg: string): string[] => ofType(evs, "package_state").filter((e) => e.package === pkg).map((e) => `${e.state}${e.round}`);
const promptsOf = (b: FakeBuilder, pkg: string): string[] => b.calls.filter((c) => c.req.meta?.role === "builder" && c.req.meta?.package === pkg).map((c) => c.req.prompt);
const referenceReports = (job: TempJob): string[] => fs.readdirSync(path.join(job.jobDir, "reports")).filter((f) => f.startsWith("reference-"));

/** The engine's reference pack: it PASSES here whenever it is asked (unless the load trips reach it). */
function withReferencePack(job: TempJob): void {
  const dir = path.join(job.engineDir, "kernel", "examples", "pack_min");
  fs.mkdirSync(path.join(dir, "scripts"), { recursive: true });
  fs.mkdirSync(path.join(dir, "tests"), { recursive: true });
  fs.writeFileSync(path.join(dir, "pack.json"), JSON.stringify({ id: "example.pack_min", version: "0.1.0", kernelApi: "0.1", title: "Minimal pack", capabilities: ["physics"], entry: "scripts/main.gd", assets: [], tests: ["tests/bot_roll.gd"] }));
  fs.writeFileSync(path.join(dir, "scripts", "main.gd"), "extends Node\n");
  fs.writeFileSync(path.join(dir, "tests", "bot_roll.gd"), "extends Node\n");
}

test("N3c: two stalls at DIFFERENT frames are the machine although the reference pack would pass: note, wait, retry; the builder hears nothing and no round is spent", async () => {
  const job = tempJob("stall-different");
  withReferencePack(job);
  const slept: number[] = [];
  // Exactly two load trips, each at another frame: core's smoke and its second run. Anything after that passes,
  // so the reference pack WOULD pass if it were asked; it is not asked.
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", verifier: fastVerifier(job.engineDir, { FAKE_RUNNER_LOAD_TRIPS: "2", FAKE_RUNNER_LOAD_FRAMES: "1" }), sleep: async (ms) => void slept.push(ms) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "promoted1"]);
  assert.deepEqual(ofType(evs, "verify").filter((e) => e.package === "core" && e.verb === "smoke").map((e) => [e.ok, /-retry1-s\d+/.test(e.report)]), [[false, false], [false, false], [true, true]]);
  assert.deepEqual(slept, [20_000]);
  const note = ofType(evs, "note").find((n) => n.text.startsWith(`${FOREMAN_NOTE}${MACHINE_BUSY}`));
  assert.match(note?.text ?? "", /smoke on the workspace of core: the watchdog stopped 2 runs of the same check on the same files at 2 DIFFERENT places \(frame 1307 in _pack_tick \(scripts\/main\.gd\); frame 3078 in _pack_tick \(scripts\/main\.gd\)\)[^]*whatever a reference run says afterwards[^]*Waiting 20 s, then try 1 of 3\./);
  assert.deepEqual(referenceReports(job), [], "the frames decide; the gauge is not run");
  assert.equal(promptsOf(builder, "core").length, 1);
  for (const p of builder.calls.map((c) => c.req.prompt)) assert.ok(!/tick_timeout: _pack_tick did not return|DIFFERENT places/.test(p));

  // Stalls that keep coming, each at another frame: inconclusive, the job pauses, the builder is not run again.
  const job2 = tempJob("stall-different-stays");
  withReferencePack(job2);
  const busy = foremanFor(job2, { promoteTo: "job", clockRetries: 2, clockPausesMs: [3], verifier: fastVerifier(job2.engineDir, { FAKE_RUNNER_LOAD_TRIPS: "99", FAKE_RUNNER_LOAD_FRAMES: "1" }), sleep: async () => {} });
  const s2 = await busy.foreman.run();
  assert.equal(s2.jobState?.state, "paused");
  assert.equal(s2.packages["core"]?.cause, "machine_busy");
  assert.match(s2.packages["core"]?.detail ?? "", /^inconclusive: machine busy\. smoke on the workspace of core: the watchdog stopped 4 runs of the same check on the same files at 4 DIFFERENT places/);
  assert.deepEqual(referenceReports(job2), []);
  assert.equal(promptsOf(busy.builder, "core").length, 1);
});

test("N3c: two stalls at the SAME frame are the pack's own: no waiting, the round fails and the builder gets the frame number", async () => {
  const job = tempJob("stall-same");
  withReferencePack(job);
  const slept: number[] = [];
  const stalls: FakeStep = { match: { role: "builder", package: "core", round: 1 }, write: { "scripts/main.gd": "extends Node\n# FAKE_STALL_AT(4885)\n", "tests/bot_rally.gd": "extends Node\n" }, text: "Done." };
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", script: scriptWith([stalls]), sleep: async (ms) => void slept.push(ms) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "running2", "verifying2", "promoted2"]);
  assert.deepEqual(slept, []);
  assert.deepEqual(referenceReports(job), [], "the same frame twice needs no gauge either");
  const note = ofType(evs, "note").find((n) => n.text.startsWith(`${FOREMAN_NOTE}${PACK_STALL}`));
  assert.match(note?.text ?? "", /smoke on the workspace of core: the watchdog stopped 2 runs of the same check on the same files at the SAME place, frame 4885 in _pack_tick \(scripts\/main\.gd\)/);
  const p2 = promptsOf(builder, "core")[1] ?? "";
  assert.match(p2, /The Foreman compared the two runs before reporting this: the same stall twice: [^]*at the SAME place, frame 4885 in _pack_tick[^]*look at what _pack_tick does at frame 4885/);
  assert.match(p2, /The Verifier did not pass round 1: smoke \(V2\) on your workspace/);
});

test("N3c: the four real reports of the hockey job (two rounds, two runs each, stalls at frames 4885/6483 and 3522/1307) are classified as machine load", () => {
  const dir = path.join(PKG_ROOT, "fixtures", "hockey-stalls");
  const load = (name: string): VerifyResult => {
    const report = JSON.parse(fs.readFileSync(path.join(dir, name), "utf8")) as VerifyReport;
    return { verb: report.verb as VerifyResult["verb"], level: report.level as VerifyResult["level"], ok: false, exitCode: 3, report, reportFile: name, verdictFile: name, flags: [], summary: `${report.verb} watchdog`, durationMs: 0 };
  };
  const r2 = [load("hockey_ai-r2-bot-s142.json"), load("hockey_ai-r2-bot-again-s143.json")];
  const r3 = [load("hockey_ai-r3-invariants-s153.json"), load("hockey_ai-r3-invariants-again-s154.json")];
  for (const vr of [...r2, ...r3]) assert.equal(restsOnAClock(vr), true, vr.reportFile);
  assert.deepEqual(r2.map((vr) => [stallOf(vr)?.frame, stallOf(vr)?.callback, stallOf(vr)?.file]), [[4885, "_bot_tick", "tests/bot_hockey_ai.gd"], [6483, "_pack_tick", "scripts/main.gd"]]);
  assert.deepEqual(r3.map((vr) => [stallOf(vr)?.frame, stallOf(vr)?.callback]), [[3522, "_pack_tick"], [1307, "_bot_tick"]]);
  const c2 = classifyStalls(r2);
  assert.equal(c2.verdict, "machine_load");
  assert.match(c2.text, /at 2 DIFFERENT places \(frame 4885 in _bot_tick \(tests\/bot_hockey_ai\.gd\); frame 6483 in _pack_tick \(scripts\/main\.gd\)\)/);
  const c3 = classifyStalls(r3);
  assert.equal(c3.verdict, "machine_load");
  assert.match(c3.text, /frame 3522 in _pack_tick[^]*frame 1307 in _bot_tick/);
  // The figures a reader needs to check the verdict: the one run that reported frame times had ordinary frames.
  assert.match(c3.text, /median 0\.715 ms, p99 1\.278 ms, so single ticks blew the watchdog's limit while the frames around them stayed far under the 8 ms budget/);
  // The same report twice would be the pack's own stall; a report without a frame decides nothing.
  assert.equal(classifyStalls([r2[0] as VerifyResult, r2[0] as VerifyResult]).verdict, "pack");
  const noFrame = structuredClone(r2[1] as VerifyResult);
  (noFrame.report as VerifyReport).errors = [{ kind: "watchdog", message: "tick_timeout: _pack_tick did not return within 250 ms (runaway script); the process was stopped" }];
  assert.equal(classifyStalls([r2[0] as VerifyResult, noFrame]).verdict, "undecided");
});

test("N3c: a log written BEFORE this rule (two failed runs with stalls at different frames, then the next round) no longer hands those reports to the builder as its pack's failure", () => {
  const job = tempJob("stall-old-log");
  const src = path.join(PKG_ROOT, "fixtures", "hockey-stalls");
  fs.mkdirSync(path.join(job.jobDir, "reports"), { recursive: true });
  fs.copyFileSync(path.join(src, "hockey_ai-r2-bot-s142.json"), path.join(job.jobDir, "reports", "core-r1-bot-s8.json"));
  fs.copyFileSync(path.join(src, "hockey_ai-r2-bot-again-s143.json"), path.join(job.jobDir, "reports", "core-r1-bot-again-s9.json"));
  const log = JobLog.open(job.jobDir);
  try {
    log.append({ type: "package_state", package: "core", state: "running", round: 1 });
    log.append({ type: "builder_run", package: "core", round: 1, adapter: "fake", mode: "edit", model: "fake", outcome: "ok", durationMs: 1 });
    log.append({ type: "package_state", package: "core", state: "verifying", round: 1 });
    log.append({ type: "verify", package: "core", round: 1, level: "V4", verb: "bot", ok: false, report: "reports/core-r1-bot-s8.json", exitCode: 3 });
    log.append({ type: "verify", package: "core", round: 1, level: "V4", verb: "bot", ok: false, report: "reports/core-r1-bot-again-s9.json", exitCode: 3 });
    log.append({ type: "note", package: "core", round: 1, text: "[foreman] not machine load: bot failed on a clock (...) The time is this pack's own." });
    log.append({ type: "package_state", package: "core", state: "running", round: 2 });
  } finally {
    log.close();
  }
  const prompt = foremanFor(job, {}).foreman.previewBuilderPrompts("core")[0]?.prompt ?? "";
  assert.match(prompt, /Round 1 did not pass bot \(V4\), but NOT because of your pack: the watchdog stopped 2 runs of the same check on the same files at 2 DIFFERENT places \(frame 4885 in _bot_tick[^]*frame 6483 in _pack_tick[^]*If an earlier message of the Foreman called this the pack's own time, that was wrong/);
  assert.ok(!/The Verifier did not pass round 1|The time is this pack's own/.test(prompt));
});
