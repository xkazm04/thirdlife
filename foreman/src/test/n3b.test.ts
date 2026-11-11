// N3b: the two defects the real hockey job found (2026-11-11). Fake adapter and fake runner; no model, no git.
//   1 a re-opened package is verified with the registrations of everything its workspace holds
//   2 a clock-based failure that repeats is checked against the machine (the engine's reference pack) before a builder hears of it
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempJob, foremanFor, readEvents, scriptWith, fastVerifier, type TempJob } from "./helpers.js";
import { FakeBuilder, type FakeStep } from "../builder/fake.js";
import type { JobEvent, PackageSpec } from "../events.js";
import { JobLog } from "../joblog.js";
import { FOREMAN_NOTE, MACHINE_BUSY, NOT_LOAD, medianOverHalfBudget } from "../foreman.js";
import type { VerifyResult } from "../verifier.js";

after(cleanup);

const ofType = <T extends JobEvent["type"]>(evs: JobEvent[], type: T): Extract<JobEvent, { type: T }>[] => evs.filter((e) => e.type === type) as Extract<JobEvent, { type: T }>[];
const states = (evs: JobEvent[], pkg: string): string[] => ofType(evs, "package_state").filter((e) => e.package === pkg).map((e) => `${e.state}${e.round}`);
const promptsOf = (b: FakeBuilder, pkg: string): string[] => b.calls.filter((c) => c.req.meta?.role === "builder" && c.req.meta?.package === pkg).map((c) => c.req.prompt);
const AI_JSON = '{\n "reaction_frames": 8,\n "max_speed_mps": 6,\n "error_m": 0.3\n}\n';
const AI_GD = "extends RefCounted\n\nfunc decide(ball_y: float, paddle_y: float, tuning: Dictionary) -> float:\n\treturn signf(ball_y - paddle_y)\n";

/** The engine's known-good reference pack, as the fake runner needs it: kernel/examples/pack_min. */
function withReferencePack(job: TempJob): void {
  const dir = path.join(job.engineDir, "kernel", "examples", "pack_min");
  fs.mkdirSync(path.join(dir, "scripts"), { recursive: true });
  fs.mkdirSync(path.join(dir, "tests"), { recursive: true });
  fs.writeFileSync(path.join(dir, "pack.json"), JSON.stringify({ id: "example.pack_min", version: "0.1.0", kernelApi: "0.1", title: "Minimal pack", capabilities: ["physics"], entry: "scripts/main.gd", assets: [], tests: ["tests/bot_roll.gd"] }));
  fs.writeFileSync(path.join(dir, "scripts", "main.gd"), "extends Node\n");
  fs.writeFileSync(path.join(dir, "tests", "bot_roll.gd"), "extends Node\n");
}

// ---------------------------------------------------------------- 1. the manifest of a re-opened package

test("N3b 1: a root that is re-opened after a dependant with an EXTRA capability has merged is verified with that dependant's registrations (its files are in the root's workspace)", async () => {
  const job = tempJob("reopen-manifest");
  // paddle_ai registers the capability `audio`, which the root does not, and its script uses it.
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  const plan = JSON.parse(lines[3] as string) as { packages: PackageSpec[] };
  for (const p of plan.packages) if (p.id === "paddle_ai") p.registers = { capabilities: ["audio"] };
  lines[3] = JSON.stringify(plan);
  fs.writeFileSync(file, lines.map((l) => l + "\n").join(""));
  const usesAudio: FakeStep = { match: { role: "builder", package: "paddle_ai" }, write: { "data/ai.json": AI_JSON, "scripts/paddle_ai.gd": `${AI_GD}# FAKE_USES(audio)\n` }, text: "Done.\nDEVIATIONS: none" };
  const first = await foremanFor(job, { promoteTo: "job", script: scriptWith([usesAudio]) }).foreman.run();
  assert.equal(first.jobState?.state, "done", JSON.stringify(first.jobState));
  assert.ok((JSON.parse(fs.readFileSync(path.join(job.jobDir, "pack", "pack.json"), "utf8")) as { capabilities: string[] }).capabilities.includes("audio"));

  // The root is re-opened (a change request; the critic naming it takes the same path).
  const log = JobLog.open(job.jobDir);
  try {
    log.append({ type: "change_requested", text: "Make the ball bigger.", package: "core" });
  } finally {
    log.close();
  }
  const core2: FakeStep = { match: { role: "builder", package: "core", round: 2 }, write: { "scripts/main.gd": "extends Node\n# bigger ball\nfunc _pack_setup(ctx) -> void:\n\tpass\n" }, text: "Done.\nDEVIATIONS: none" };
  const second = await foremanFor(job, { promoteTo: "job", roundLimit: 1, script: scriptWith([core2, usesAudio]) }).foreman.run();
  assert.equal(second.jobState?.state, "done", JSON.stringify(second.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > first.lastSeq);
  // The workspace holds paddle_ai's script, and the manifest it is verified with declares paddle_ai's capability.
  const ws = path.join(job.jobDir, "ws", "core");
  assert.ok(fs.readFileSync(path.join(ws, "scripts", "paddle_ai.gd"), "utf8").includes("FAKE_USES(audio)"));
  assert.ok((JSON.parse(fs.readFileSync(path.join(ws, "pack.json"), "utf8")) as { capabilities: string[] }).capabilities.includes("audio"), "the workspace manifest lacks the capability of a package whose files it holds");
  assert.deepEqual((JSON.parse(fs.readFileSync(path.join(job.jobDir, "ws", "core.members.json"), "utf8")) as string[]).sort(), ["court", "paddle_ai"]);
  const lint = ofType(later, "verify").find((e) => e.package === "core" && e.verb === "lint");
  assert.deepEqual([lint?.round, lint?.ok], [2, true], "lint of the re-opened root fails on lint.capabilities when the manifest is composed from its dependencies alone");
  assert.deepEqual(states(later, "core"), ["queued2", "running2", "verifying2", "promoted2"]);
  assert.equal(ofType(later, "merge").filter((e) => e.package === "core").length, 1, "the change was merged");
  assert.equal(ofType(later, "promoted")[0]?.version, "0.1.1");
});

// ---------------------------------------------------------------- 2. clock-based failures and the machine

test("N3b 2: a clock failure that repeats while the reference pack trips its clock too is 'inconclusive: machine busy': the Foreman waits and tries again, and when it clears no round is spent and the builder hears nothing", async () => {
  const job = tempJob("clock-clears");
  withReferencePack(job);
  const slept: number[] = [];
  // The first three runs of pack code trip: core's smoke, its second run, and the reference pack.
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", verifier: fastVerifier(job.engineDir, { FAKE_RUNNER_LOAD_TRIPS: "3" }), sleep: async (ms) => void slept.push(ms) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "promoted1"]);
  const smoke = ofType(evs, "verify").filter((e) => e.package === "core" && e.verb === "smoke");
  assert.deepEqual(smoke.map((e) => [e.ok, /-again-s\d+/.test(e.report), /-retry1-s\d+/.test(e.report)]), [[false, false, false], [false, true, false], [true, false, true]]);
  assert.deepEqual(slept, [20_000], "the default first pause");
  const note = ofType(evs, "note").find((n) => n.text.startsWith(`${FOREMAN_NOTE}${MACHINE_BUSY}`));
  assert.match(note?.text ?? "", /smoke on the workspace of core failed on a clock \(tick_timeout[^]*and so did the engine's reference pack \([^]*reports\/reference-smoke-for-smoke-s\d+\.json\)\. Waiting 20 s, then try 1 of 3\./);
  assert.equal(ofType(evs, "verify").filter((e) => /reference-/.test(e.report)).length, 0, "the reference run is not a verify event of this job's pack");
  assert.equal(promptsOf(builder, "core").length, 1);
  for (const p of builder.calls.map((c) => c.req.prompt)) assert.ok(!/tick_timeout: _pack_tick did not return/.test(p), "a busy-machine failure is never feedback");
  // The builder prompt says what a frame-time failure can be.
  assert.match(promptsOf(builder, "core")[0] ?? "", /\*\*A time limit can fail because the machine is busy\.\*\*[^]*Do NOT ask a `QUESTION:` about it/);
});

test("N3b 2: a clock failure that persists while the reference pack keeps failing too ends the round as inconclusive: package blocked (machine_busy), job paused, builder not run again; resume verifies the same files", async () => {
  const job = tempJob("clock-busy");
  withReferencePack(job);
  const slept: number[] = [];
  const opts = { promoteTo: "job" as const, clockRetries: 2, clockPausesMs: [5, 9], sleep: async (ms: number) => void slept.push(ms) };
  const busy = foremanFor(job, { ...opts, verifier: fastVerifier(job.engineDir, { FAKE_RUNNER_LOAD_TRIPS: "99" }) });
  const s = await busy.foreman.run();
  assert.equal(s.jobState?.state, "paused", JSON.stringify(s.jobState));
  assert.match(s.jobState?.reason ?? "", /^machine busy: the verification of core was inconclusive/);
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "blocked1"]);
  const blocked = ofType(evs, "package_state").find((e) => e.package === "core" && e.state === "blocked");
  assert.equal(blocked?.cause, "machine_busy");
  assert.ok((blocked?.detail ?? "").startsWith(MACHINE_BUSY), blocked?.detail);
  assert.match(blocked?.detail ?? "", /Tried 2 more time\(s\)[^]*NOT a verdict about the pack: nothing was sent to the builder/);
  assert.deepEqual(slept, [5, 9], "the options: two tries, pauses 5 and 9 ms");
  assert.deepEqual(ofType(evs, "verify").filter((e) => e.package === "core" && e.verb === "smoke").map((e) => e.ok), [false, false, false, false], "two runs, then one per try");
  assert.equal(promptsOf(busy.builder, "core").length, 1, "no second round");
  assert.equal(s.packages["court"]?.state, "queued", "dependants wait; they are not blocked as if the root had failed");

  // The machine is free again: resume verifies the files that are there, without the builder.
  const calm = foremanFor(job, { ...opts, verifier: fastVerifier(job.engineDir) });
  const s2 = await calm.foreman.run();
  assert.equal(s2.jobState?.state, "done", JSON.stringify(s2.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > s.lastSeq);
  assert.deepEqual(states(later, "core"), ["verifying1", "promoted1"]);
  assert.match(ofType(later, "package_state")[0]?.detail ?? "", /resumed/);
  assert.equal(promptsOf(calm.builder, "core").length, 0, "the builder of the busy round is not paid twice");
  for (const p of calm.builder.calls.map((c) => c.req.prompt)) assert.ok(!/tick_timeout: _pack_tick did not return|machine busy: /.test(p), "neither the clock failure nor the Foreman's own notes reach a builder");
});

test("N3b 2: a clock failure that persists while the reference pack PASSES is the pack's own: no waiting, the round fails and the builder is told the machine was measured", async () => {
  const job = tempJob("clock-real");
  withReferencePack(job);
  const slept: number[] = [];
  const runaway: FakeStep = { match: { role: "builder", package: "core", round: 1 }, write: { "scripts/main.gd": "extends Node\n# FAKE_WATCHDOG\n", "tests/bot_rally.gd": "extends Node\n" }, text: "Done." };
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", script: scriptWith([runaway]), sleep: async (ms) => void slept.push(ms) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "running2", "verifying2", "promoted2"]);
  assert.deepEqual(slept, []);
  assert.equal(ofType(evs, "package_state").filter((e) => e.cause === "machine_busy").length, 0);
  const note = ofType(evs, "note").find((n) => n.text.startsWith(`${FOREMAN_NOTE}${NOT_LOAD}`));
  assert.match(note?.text ?? "", /smoke failed on a clock \(tick_timeout[^]*the engine's reference pack, run right after it on the same machine, did not \(passed, frame p99 0\.4 ms; reports\/reference-smoke-for-smoke-s\d+\.json\)/);
  const p2 = promptsOf(builder, "core")[1] ?? "";
  assert.match(p2, /The Foreman measured the machine before reporting this: machine not shown busy: smoke failed on a clock[^]*evidence about the moment AFTER the failure, not proof/);
  assert.match(p2, /The Verifier did not pass round 1: smoke \(V2\) on your workspace/);
  // One interrupted tick of the reference pack is the sensitive sign of a busy machine (the fake reports 0.03 ms).
  const job3 = tempJob("clock-tick-reference");
  withReferencePack(job3);
  const s4 = await foremanFor(job3, { promoteTo: "job", clockRetries: 0, referenceBusyTickMs: 0.02, script: scriptWith([runaway]), sleep: async () => {} }).foreman.run();
  assert.equal(s4.jobState?.state, "paused");
  assert.match(s4.packages["core"]?.detail ?? "", /it passed, but one of its ticks took 0\.03 ms/);
  // A reference pack that itself only "passes slowly" (frame p99 at or over the limit) also counts as a busy machine.
  const job2 = tempJob("clock-slow-reference");
  withReferencePack(job2);
  const s3 = await foremanFor(job2, { promoteTo: "job", clockRetries: 0, referenceBusyP99Ms: 0.3, script: scriptWith([runaway]), sleep: async () => {} }).foreman.run();
  assert.equal(s3.jobState?.state, "paused");
  assert.match(s3.packages["core"]?.detail ?? "", /and so did the engine's reference pack \(it passed, but its frame p99 was 0\.4 ms/);
});

test("N3b 2: a frame-budget failure whose MEDIAN frame is already over half the budget is slow code, not load: it is not measured against the machine", () => {
  const report = (p50: number, p99: number, outcome: "failed" | "watchdog" = "failed"): VerifyResult =>
    ({ verb: "invariants", level: "V3", ok: false, flags: [], summary: "invariants failed", durationMs: 1, reportFile: "r.json", verdictFile: "v.json", report: { schema: "tl.verify/1", verb: "invariants", level: "V3", ok: false, outcome, errors: [], metrics: { frame_ms_p50: p50, frame_ms_p99: p99 }, checks: [{ id: "smoke.loads", ok: true }, { id: "invariants.frame_budget", ok: false, detail: `frame p99 ${p99} ms (budget 8 ms; scripts + physics step, headless, better of two runs)` }] } }) as VerifyResult;
  // The real hockey figures: p50 0.96 ms, p99 15.83 ms: the typical frame is fine, so the machine is measured.
  assert.equal(medianOverHalfBudget(report(0.96, 15.83)), undefined);
  assert.match(medianOverHalfBudget(report(5.2, 9.1)) ?? "", /The median frame alone is 5\.2 ms, over half of the 8 ms budget/);
  assert.equal(medianOverHalfBudget(report(5.2, 9.1, "watchdog")), undefined);
});
