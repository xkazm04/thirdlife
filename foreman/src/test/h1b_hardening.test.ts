// H1b of the day run of 25 Nov 2026 (editor hardening, round 2). Each test failed on main 98b1f52 and passes now.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempJob, foremanFor, readEvents, scriptWith, fastVerifier, type TempJob } from "./helpers.js";
import type { FakeBuilder, FakeStep } from "../builder/fake.js";
import type { JobEvent, PackageSpec } from "../events.js";
import { FOREMAN_NOTE, MACHINE_BUSY, NOT_LOAD, restsOnAClock } from "../foreman.js";
import { waitForQuiet } from "../machine.js";
import type { VerifyResult } from "../verifier.js";

after(cleanup);

const ofType = <T extends JobEvent["type"]>(evs: JobEvent[], type: T): Extract<JobEvent, { type: T }>[] => evs.filter((e) => e.type === type) as Extract<JobEvent, { type: T }>[];
const states = (evs: JobEvent[], pkg: string): string[] => ofType(evs, "package_state").filter((e) => e.package === pkg).map((e) => `${e.state}${e.round}`);
const promptsOf = (b: FakeBuilder, pkg: string): string[] => b.calls.filter((c) => c.req.meta?.role === "builder" && c.req.meta?.package === pkg).map((c) => c.req.prompt);

// ---------------------------------------------------------------- 1. a clock-only failure is not a builder round

/** The fixture job with `invariants` in core's acceptance, as the game lanes' cores had it (G4 court_core, G2 core). */
function invariantsJob(label: string, reference = false): TempJob {
  const job = tempJob(label);
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  const plan = JSON.parse(lines[3] as string) as { packages: PackageSpec[] };
  for (const p of plan.packages) if (p.id === "core") p.acceptance = [...p.acceptance, { level: "V3", verb: "invariants", args: [] }];
  lines[3] = JSON.stringify(plan);
  fs.writeFileSync(file, lines.map((l) => l + "\n").join(""));
  if (reference) {
    const dir = path.join(job.engineDir, "kernel", "examples", "pack_min");
    fs.mkdirSync(path.join(dir, "scripts"), { recursive: true });
    fs.mkdirSync(path.join(dir, "tests"), { recursive: true });
    fs.writeFileSync(path.join(dir, "pack.json"), JSON.stringify({ id: "example.pack_min", version: "0.1.0", kernelApi: "0.1", title: "Minimal pack", capabilities: ["physics"], entry: "scripts/main.gd", assets: [], tests: ["tests/bot_roll.gd"] }));
    fs.writeFileSync(path.join(dir, "scripts", "main.gd"), "extends Node\n");
    fs.writeFileSync(path.join(dir, "tests", "bot_roll.gd"), "extends Node\n");
  }
  return job;
}

const loads = (...xs: number[]): (() => Promise<number | undefined>) => {
  let i = 0;
  return async () => xs[Math.min(i++, xs.length - 1)];
};
const invariantsRuns = (evs: JobEvent[]): boolean[] => ofType(evs, "verify").filter((e) => e.package === "core" && e.verb === "invariants").map((e) => e.ok);

test("H1b 1 (G4's court_core r1: many_budget p50 1.048 ms against 1.0 on a loaded machine went to the builder at once): many_budget rests on a clock, so it is run again and the second run decides; no builder round", async () => {
  const job = invariantsJob("h1b-many-once");
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", verifier: fastVerifier(job.engineDir, { FAKE_RUNNER_MANY_SLOW: "1" }), machineLoad: loads(30), sleep: async () => {} });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "promoted1"], "no round 2");
  assert.deepEqual(invariantsRuns(evs), [false, true], "the first run missed the budget, the second decided");
  assert.equal(promptsOf(builder, "core").length, 1);
  for (const p of builder.calls.map((c) => c.req.prompt)) assert.ok(!/many_budget|frame p50 1\.048/.test(p), "a clock failure is never feedback");
});

test("H1b 1b (G2's core r1, p50 1.334 ms with the processor at 85-100 %): twice over the budget while room.sh's measure says busy is no verdict: the Foreman waits, tries again, then pauses the job (machine_busy); no builder round; resume on a quiet machine verifies the same files", async () => {
  const job = invariantsJob("h1b-many-busy");
  const slept: number[] = [];
  const opts = { promoteTo: "job" as const, clockRetries: 2, clockPausesMs: [5, 9], quietWaitMs: 0, sleep: async (ms: number) => void slept.push(ms) };
  const busy = foremanFor(job, { ...opts, verifier: fastVerifier(job.engineDir, { FAKE_RUNNER_MANY_SLOW: "99" }), machineLoad: loads(93) });
  const s = await busy.foreman.run();
  assert.equal(s.jobState?.state, "paused", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "blocked1"]);
  assert.equal(ofType(evs, "package_state").find((e) => e.package === "core" && e.state === "blocked")?.cause, "machine_busy");
  const note = ofType(evs, "note").find((n) => n.text.startsWith(`${FOREMAN_NOTE}${MACHINE_BUSY}`));
  assert.match(note?.text ?? "", /invariants on the workspace of core failed on a clock \(frame p50 1\.048 ms \(budget 1\.0 ms for one of many[^]*the machine's processor was at 93 % \(the room\.sh measure; busy above 70 %\)/);
  assert.deepEqual(invariantsRuns(evs), [false, false, false, false], "two runs, then one per try");
  assert.equal(promptsOf(busy.builder, "core").length, 1, "no second round");
  const calm = foremanFor(job, { ...opts, verifier: fastVerifier(job.engineDir), machineLoad: loads(30) });
  const s2 = await calm.foreman.run();
  assert.equal(s2.jobState?.state, "done", JSON.stringify(s2.jobState));
  assert.deepEqual(states(readEvents(job.jobDir).filter((e) => e.seq > s.lastSeq), "core"), ["verifying1", "promoted1"]);
  assert.equal(promptsOf(calm.builder, "core").length, 0, "the builder is not paid twice");
});

test("H1b 1c: the try again waits for a quieter machine (room.sh's measure at or under 70 %), not only a fixed pause; then the run decides", async () => {
  const job = invariantsJob("h1b-many-quiet");
  const slept: number[] = [];
  // 93 % when measured, still 88 % after the first pause, 40 % at the next poll: the try runs then and passes.
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", verifier: fastVerifier(job.engineDir, { FAKE_RUNNER_MANY_SLOW: "2" }), machineLoad: loads(93, 88, 40), sleep: async (ms) => void slept.push(ms) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  assert.deepEqual(slept, [20_000, 15_000], "the first pause, then one poll until the load came down");
  assert.deepEqual(invariantsRuns(readEvents(job.jobDir)), [false, false, true]);
  assert.equal(promptsOf(builder, "core").length, 1);
  // the pure wait: gives up after maxMs, returns the last load
  const polls: number[] = [];
  assert.deepEqual(await waitForQuiet(loads(95), async (ms) => void polls.push(ms), 70, 30_000, 15_000), { load: 95, waitedMs: 30_000 });
  assert.deepEqual(polls, [15_000, 15_000]);
  assert.deepEqual(await waitForQuiet(async () => undefined, async () => {}, 70, 30_000), { waitedMs: 0 }, "unmeasurable: no wait");
});

test("H1b 1d: slow code on a quiet machine still goes to the builder: twice over the budget, the processor at 20 % and the reference pack calm: round 2 with the figures", async () => {
  const job = invariantsJob("h1b-many-slow-code", true);
  const slow: FakeStep = { match: { role: "builder", package: "core", round: 1 }, write: { "scripts/main.gd": "extends Node\n# FAKE_MANY_SLOW\n", "tests/bot_rally.gd": "extends Node\n" }, text: "Done." };
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", script: scriptWith([slow]), machineLoad: loads(20), sleep: async () => {} });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  assert.deepEqual(states(evs, "core"), ["queued1", "running1", "verifying1", "running2", "verifying2", "promoted2"]);
  assert.ok(ofType(evs, "note").some((n) => n.text.startsWith(`${FOREMAN_NOTE}${NOT_LOAD}`)));
  assert.match(promptsOf(builder, "core")[1] ?? "", /many_budget|frame p50 1\.048/);
  const r = (ids: string[]): VerifyResult => ({ verb: "invariants", level: "V3", ok: false, flags: [], summary: "", durationMs: 1, reportFile: "r", verdictFile: "v", report: { schema: "tl.verify/1", verb: "invariants", level: "V3", ok: false, outcome: "failed", errors: [], checks: ids.map((id) => ({ id, ok: false })) } }) as VerifyResult;
  assert.equal(restsOnAClock(r(["invariants.many_budget"])), true);
  assert.equal(restsOnAClock(r(["invariants.many_budget", "invariants.frame_budget"])), true);
  assert.equal(restsOnAClock(r(["invariants.many_budget", "invariants.determinism"])), false, "a real failure beside it is the pack's");
});
