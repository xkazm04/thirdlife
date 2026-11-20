// JOB.md "Added 2026-11-20": the build runs in phases the player tries and passes. The replayed fixture job
// (fixtures/job-phases: a crazy brief with a crazy aspect, three phases, the fake adapter and the fake runner) goes
// through every stop: a pause after phase 1, a hold with a note (a change round on that phase's packages), a pass, the
// next phases, promotion; and the same job with run_through, which never stops.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { main, copyFixture } from "../cli.js";
import { rebuildState } from "../joblog.js";
import { cleanup, tempDir, readEvents } from "./helpers.js";
import type { JobEvent } from "../events.js";

after(cleanup);

const run = async (argv: string[]): Promise<{ code: number; text: string }> => {
  const lines: string[] = [];
  const code = await main(argv, (s) => lines.push(s));
  return { code, text: lines.join("\n") };
};
const status = async (jobDir: string): Promise<string> => (await run(["status", jobDir])).text;
const types = (evs: JobEvent[]): string[] => evs.map((e) => (e.type === "job_state" ? `job_state:${e.state}:${e.reason ?? ""}` : e.type === "phase_done" ? `phase_done:${e.phase}` : e.type === "phase_reviewed" ? `phase_reviewed:${e.phase}:${e.verdict}:${e.by}` : e.type));
const FLAGS = ["--adapter", "fake", "--quiet", "--parallel", "1"];

function phasesJob(label: string): string {
  const jobDir = path.join(tempDir(label), "site", "paddle-court-crazy-20261121-1");
  copyFixture(jobDir, true);
  return jobDir;
}

test("phases fixture: the brief is crazy with one crazy aspect, the player's reactions stand on it, the plan has three phases", () => {
  const s = rebuildState(phasesJob("phases-shape"), { write: false });
  assert.equal(s.creativity, "crazy");
  assert.deepEqual(s.brief?.aspects?.filter((a) => a.crazy === true).map((a) => a.id), ["magnet_ball"]);
  assert.deepEqual(Object.keys(s.reactions), ["court", "magnet_ball"]);
  assert.equal(s.briefApprovedBy, "player");
  assert.deepEqual(s.phases.map((p) => [p.id, p.packages]), [["court_plays", ["core", "court"]], ["rival", ["paddle_ai"]], ["magnet", ["fx"]]]);
});

test("phases: pause after each phase, a hold with a note runs a change round on that phase's packages, pass goes on, the last pass promotes; foreman status names the phase and the command at every stop", async () => {
  const jobDir = phasesJob("phases-walk");
  const job = path.basename(jobDir);

  // 1. Phase 1 is built; the job stops for the player.
  const r1 = await run(["run", jobDir, ...FLAGS]);
  assert.equal(r1.code, 3, r1.text);
  let evs = readEvents(jobDir);
  const t1 = types(evs);
  assert.deepEqual(t1.slice(-2), ["phase_done:court_plays", "job_state:paused:phase"]);
  assert.ok(!evs.some((e) => e.type === "package_state" && (e.package === "paddle_ai" || e.package === "fx") && e.state !== "queued"), "nothing of a later phase started");
  let st = await status(jobDir);
  assert.match(st, /state    paused  \(phase\)/);
  assert.match(st, /phase    1\/3 court_plays\s+WAITING\s+core, court; try: Rally the ball off the walls with your paddle/);
  assert.match(st, /phase    2\/3 rival\s+later/);
  assert.match(st, new RegExp(`waiting  phase court_plays is done: try it \\("Rally the ball off the walls with your paddle"\\), then: foreman phase ${job} pass   or   foreman phase ${job} hold --note`));
  assert.match((await run(["explain", jobDir])).text, new RegExp(`next: foreman phase ${job} pass`));
  assert.match(st, /design   crazy: Slap a speeding ball/);
  assert.match(st, /aspect   magnet_ball\s+\[twist\] CRAZY Magnet ball/);

  // resume does not move a job that waits for a verdict, and writes nothing.
  const n = readEvents(jobDir).length;
  assert.equal((await run(["resume", jobDir, ...FLAGS])).code, 3);
  assert.equal(readEvents(jobDir).length, n);

  // 2. Hold with a note: the Planner names the court among the phase's packages; court round 2 makes the change.
  await assert.rejects(run(["phase", jobDir, "hold", ...FLAGS]), /hold needs --note/);
  const r2 = await run(["phase", jobDir, "hold", "--note", "The rallies are too slow: make the court smaller", ...FLAGS]);
  assert.equal(r2.code, 3, r2.text);
  evs = readEvents(jobDir);
  const hold = evs.find((e) => e.type === "phase_reviewed");
  assert.ok(hold?.type === "phase_reviewed" && hold.verdict === "hold" && hold.by === "player" && hold.note === "The rallies are too slow: make the court smaller");
  const reopened = evs.find((e) => e.type === "reopened");
  assert.ok(reopened?.type === "reopened" && reopened.package === "court");
  assert.match(reopened.type === "reopened" ? reopened.reason : "", new RegExp(`^phase hold \\(event ${hold.seq}\\) on phase court_plays; the Planner names the package among the phase's core, court`));
  const queued = evs.find((e) => e.type === "package_state" && e.package === "court" && e.state === "queued" && e.round === 2);
  assert.match(queued?.type === "package_state" ? queued.detail ?? "" : "", /^CHANGE REQUEST: The rallies are too slow/);
  const transcript = evs.filter((e) => e.type === "builder_run" && e.package === "court" && e.round === 2).at(-1);
  const prompt = (JSON.parse(fs.readFileSync(path.join(jobDir, transcript?.type === "builder_run" ? transcript.transcript ?? "" : ""), "utf8")) as { prompt: string }).prompt;
  assert.match(prompt, /Change requests from the player[^\n]*\n1\. The rallies are too slow: make the court smaller/);
  assert.match(prompt, /phase 1 of 3, "The court plays"/);
  assert.equal((JSON.parse(fs.readFileSync(path.join(jobDir, "pack", "data", "court.json"), "utf8")) as { width_m: number }).width_m, 12);
  assert.deepEqual(types(evs).slice(-2), ["phase_done:court_plays", "job_state:paused:phase"]);
  assert.equal(rebuildState(jobDir, { write: false }).phases[0]?.doneCount, 2);
  st = await status(jobDir);
  assert.match(st, /phase    1\/3 court_plays\s+WAITING/);

  // 3. Pass: phase 2 (paddle_ai: round 1 fails its bot, round 2 passes), then the job stops again.
  const r3 = await run(["phase", jobDir, "pass", ...FLAGS]);
  assert.equal(r3.code, 3, r3.text);
  evs = readEvents(jobDir);
  assert.deepEqual(types(evs).slice(-2), ["phase_done:rival", "job_state:paused:phase"]);
  assert.ok(!evs.some((e) => e.type === "package_state" && e.package === "fx" && e.state !== "queued"));
  st = await status(jobDir);
  assert.match(st, /phase    1\/3 court_plays\s+passed/);
  assert.match(st, /phase    2\/3 rival\s+WAITING/);

  // 4. Pass: phase 3 (the crazy aspect's package), then the job stops once more before final verification.
  assert.equal((await run(["phase", jobDir, "pass", ...FLAGS])).code, 3);
  assert.deepEqual(types(readEvents(jobDir)).slice(-2), ["phase_done:magnet", "job_state:paused:phase"]);
  assert.equal(rebuildState(jobDir, { write: false }).promoted, undefined, "nothing is promoted before the last pass");

  // 5. The last pass: final verification and promotion.
  const r5 = await run(["phase", jobDir, "pass", ...FLAGS]);
  assert.equal(r5.code, 0, r5.text);
  const s = rebuildState(jobDir, { write: false });
  assert.equal(s.jobState?.state, "done");
  assert.equal(s.promoted?.packId, "game.paddle_court_crazy");
  assert.deepEqual(s.phases.map((p) => p.state), ["passed", "passed", "passed"]);
  const reviews = readEvents(jobDir).filter((e) => e.type === "phase_reviewed").map((e) => (e.type === "phase_reviewed" ? `${e.phase}:${e.verdict}:${e.by}` : ""));
  assert.deepEqual(reviews, ["court_plays:hold:player", "court_plays:pass:player", "rival:pass:player", "magnet:pass:player"]);
  // The critic scored the fun_promise item against the phase's try line.
  const critique = fs.readdirSync(path.join(jobDir, "reports")).filter((f) => f.startsWith("critic-")).map((f) => JSON.parse(fs.readFileSync(path.join(jobDir, "reports", f), "utf8")) as { schema: string; rubric: { id: string; text: string }[]; scores?: Record<string, number> }).filter((c) => c.schema === "tl.foreman.critique/1");
  assert.ok(critique.length > 0);
  assert.ok(critique.every((c) => c.rubric.some((r) => r.id === "fun_promise") && typeof c.scores?.["fun_promise"] === "number"));
  await assert.rejects(run(["phase", jobDir, "pass", ...FLAGS]), /no phase waits for a verdict|every phase has passed/);
});

test("phases with run_through: the Foreman passes each phase itself (by auto) right after phase_done and never pauses", async () => {
  const jobDir = phasesJob("phases-through");
  const file = path.join(jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n");
  const first = JSON.parse(lines[0] as string) as Record<string, unknown>;
  lines[0] = JSON.stringify({ ...first, run_through: true });
  fs.writeFileSync(file, lines.join("\n"));
  const r = await run(["run", jobDir, ...FLAGS]);
  assert.equal(r.code, 0, r.text);
  const t = types(readEvents(jobDir));
  const phaseEvents = t.filter((x) => x.startsWith("phase_"));
  assert.deepEqual(phaseEvents, ["phase_done:court_plays", "phase_reviewed:court_plays:pass:auto", "phase_done:rival", "phase_reviewed:rival:pass:auto", "phase_done:magnet", "phase_reviewed:magnet:pass:auto"]);
  assert.ok(!t.some((x) => x.startsWith("job_state:paused")));
  assert.equal(rebuildState(jobDir, { write: false }).jobState?.state, "done");
});

test("a failing phase fails loudly and names the phase", async () => {
  const jobDir = phasesJob("phases-fail");
  const script = JSON.parse(fs.readFileSync(path.join(jobDir, "fake-builder.json"), "utf8")) as { steps: { match?: Record<string, unknown>; write?: Record<string, string> }[] };
  // The court never loads: every round writes a script with a runtime error.
  script.steps.unshift({ match: { role: "builder", package: "court" }, write: { "data/court.json": "{}\n", "scripts/court.gd": "extends RefCounted\nstatic func build(ctx, layout):\n\tFAKE_SCRIPT_ERROR()\n" } });
  fs.writeFileSync(path.join(jobDir, "fake-builder.json"), JSON.stringify(script));
  const r = await run(["run", jobDir, ...FLAGS, "--round-limit", "1", "--max-replans", "0"]);
  assert.equal(r.code, 1, r.text);
  const s = rebuildState(jobDir, { write: false });
  assert.equal(s.jobState?.state, "failed");
  assert.match(s.jobState?.reason ?? "", /^phase court_plays \("The court plays"\) did not complete: court failed/);
});
