import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { validateEvent, EventError, EVENT_TYPES } from "../events.js";
import { JobLog, LogError, readLog, readLogText, rebuildState, foldEvents, LOG_FILE, STATE_FILE } from "../joblog.js";
import { cleanup, tempDir, tempJob, foremanFor, readEvents, FIXTURE } from "./helpers.js";

after(cleanup);

const base = { v: 1, seq: 1, ts: "2026-11-10T17:00:00.000Z", job: "j-20261110-1" };
const created = { ...base, type: "job_created", sentence: "a game", packId: "game.x", title: "X" };
const line = (o: object): string => JSON.stringify(o) + "\n";

test("events: every type in JOB.md is known, nothing else", () => {
  assert.deepEqual([...EVENT_TYPES].sort(), [
    "answer", "billing", "brief_approved", "brief_set", "budget", "builder_run", "comment", "job_created", "job_state",
    "merge", "milestone", "note", "package_state", "plan_set", "promoted", "question", "replan", "verify",
  ]);
});

test("strict reader: unknown type is an error", () => {
  assert.throws(() => validateEvent({ ...base, type: "job_exploded" }), (e: unknown) => e instanceof EventError && /unknown event type "job_exploded"/.test(e.message));
  assert.throws(() => readLogText(line(created) + line({ ...base, seq: 2, type: "nope" })), (e: unknown) => e instanceof LogError && /line 2: unknown event type/.test(e.message));
});

test("strict reader: unknown key is an error, at the top level and nested", () => {
  assert.throws(() => validateEvent({ ...created, extra: 1 }), /unknown key "extra"/);
  assert.throws(
    () => validateEvent({ ...base, type: "brief_set", brief: { rules: "r", arena: "a", ai: "i", controls: "c", mood: "m", vibe: "v" }, estimate: { packages: 1, wallMinutes: 1, tokens: 1 } }),
    /unknown key "vibe"/,
  );
  assert.throws(() => validateEvent({ ...base, type: "budget", policy: { kind: "overnight", limt: 3 }, state: "paused", reason: "x" }), /unknown key "limt"/);
});

test("strict reader: missing key, wrong value, null, bad version", () => {
  assert.throws(() => validateEvent({ ...base, type: "job_created", sentence: "s", title: "t" }), /missing key "packId"/);
  assert.throws(() => validateEvent({ ...created, v: 2 }), /\/v/);
  assert.throws(() => validateEvent({ ...base, type: "job_state", state: "sleeping" }), /state/);
  assert.throws(() => validateEvent({ ...base, type: "job_state", state: "done", reason: null }), EventError);
  assert.throws(() => validateEvent({ ...created, ts: "yesterday" }), /\/ts/);
  assert.throws(() => validateEvent("x"), /not a JSON object/);
});

test("strict reader: cause is required with failed and blocked, forbidden otherwise", () => {
  const ps = { ...base, type: "package_state", package: "core", round: 1 };
  assert.throws(() => validateEvent({ ...ps, state: "failed" }), /missing key "cause"/);
  assert.throws(() => validateEvent({ ...ps, state: "blocked" }), /missing key "cause"/);
  assert.throws(() => validateEvent({ ...ps, state: "running", cause: "budget" }), /only allowed/);
  assert.throws(() => validateEvent({ ...ps, state: "failed", cause: "bad_luck" }), /cause/);
  assert.equal(validateEvent({ ...ps, state: "failed", cause: "verify_failed", detail: "d" }).type, "package_state");
});

test("strict reader: seq must be the line number and job must not change", () => {
  assert.throws(() => readLogText(line(created) + line({ ...base, seq: 3, type: "brief_approved", by: "auto" })), /seq is 3, expected 2/);
  assert.throws(() => readLogText(line(created) + line({ ...base, job: "other", seq: 2, type: "brief_approved", by: "auto" })), /job is "other"/);
  assert.throws(() => readLogText(line(created) + "not json\n" + line({ ...base, seq: 3, type: "brief_approved", by: "auto" })), /line 2: not valid JSON/);
});

test("strict reader: plan_set with duplicate ids, unknown deps or a cycle is an error", () => {
  const pkg = (id: string, deps: string[]): object => ({ id, title: id, milestone: "blockout", deps, scope: [`scripts/${id}.gd`], contract: "c", acceptance: [] });
  const plan = (packages: object[]): object => ({ ...base, type: "plan_set", packages });
  assert.throws(() => validateEvent(plan([pkg("a", []), pkg("a", [])])), /duplicate package id "a"/);
  assert.throws(() => validateEvent(plan([pkg("a", ["zz"])])), /depends on unknown "zz"/);
  assert.throws(() => validateEvent(plan([pkg("a", ["b"]), pkg("b", ["a"])])), /dependency cycle/);
  assert.throws(() => validateEvent(plan([{ ...pkg("a", []), scope: ["../x"] }])), /scope/);
  assert.throws(() => validateEvent(plan([{ ...pkg("a", []), id: "Bad-Id" }])), /id/);
});

test("a torn final line is tolerated, reported, and cut off by the writer; a complete bad line never is", () => {
  const dir = tempDir("torn");
  const file = path.join(dir, LOG_FILE);
  fs.writeFileSync(file, line(created) + '{"v":1,"seq":2,"ts":"2026-11-10T17:00:01.000Z","job":"j-2026');
  const r = readLog(dir);
  assert.equal(r.events.length, 1);
  assert.equal(r.tornTail, true);
  assert.throws(() => readLog(dir, { tolerateTornTail: false }), /torn final line/);
  assert.equal(rebuildState(dir).tornTail, true);
  const log = JobLog.open(dir);
  assert.equal(log.repairedTornTail, true);
  log.append({ type: "brief_approved", by: "auto" });
  log.close();
  const again = readLog(dir, { tolerateTornTail: false });
  assert.deepEqual(again.events.map((e) => e.seq), [1, 2]);
  assert.equal(again.tornTail, false);
});

test("writer: one line per event, validated before it is written, state.json follows the log", () => {
  const dir = tempDir("writer");
  const log = JobLog.open(dir);
  log.append({ type: "job_created", sentence: "s", packId: "game.x", title: "T" });
  assert.throws(() => log.append({ type: "job_state", state: "sleeping" } as never), EventError);
  // An event that names a package no plan declares is refused and leaves no line behind.
  assert.throws(() => log.append({ type: "package_state", package: "ghost", state: "queued", round: 1 }), /no plan_set/);
  log.append({ type: "job_state", state: "running" });
  log.close();
  const text = fs.readFileSync(path.join(dir, LOG_FILE), "utf8");
  assert.equal(text.split("\n").length, 3);
  assert.ok(text.endsWith("\n"));
  const onDisk = JSON.parse(fs.readFileSync(path.join(dir, STATE_FILE), "utf8")) as object;
  assert.deepEqual(onDisk, JSON.parse(JSON.stringify(rebuildState(dir, { write: false }))));
  // state.json is derived: delete it and it comes back identical.
  fs.rmSync(path.join(dir, STATE_FILE));
  rebuildState(dir);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(dir, STATE_FILE), "utf8")), onDisk);
});

test("writer: a second Foreman on the same job is refused while the first is alive", () => {
  const dir = tempDir("lock");
  const log = JobLog.open(dir);
  fs.writeFileSync(path.join(dir, "foreman.lock"), String(process.ppid));
  assert.throws(() => JobLog.open(dir), /another Foreman/);
  // A lock left by a dead process (pid that cannot exist) is taken over.
  fs.writeFileSync(path.join(dir, "foreman.lock"), "999999999");
  JobLog.open(dir).close();
  log.close();
});

test("the first event must be job_created", () => {
  assert.throws(() => foldEvents("j", [validateEvent({ ...base, type: "brief_approved", by: "auto" })]), /first event must be job_created/);
});

test("rebuildState succeeds on every prefix of a finished log and agrees with the full run", async () => {
  const job = tempJob("prefix");
  const { foreman } = foremanFor(job);
  const final = await foreman.run();
  assert.equal(final.jobState?.state, "done");
  const lines = fs.readFileSync(path.join(job.jobDir, LOG_FILE), "utf8").split("\n").filter((l) => l.length > 0);
  assert.ok(lines.length > 40, `expected a long log, got ${lines.length}`);
  const dir = tempDir("prefix-replay");
  let promotedSoFar = 0;
  for (let k = 0; k <= lines.length; k++) {
    fs.writeFileSync(path.join(dir, LOG_FILE), lines.slice(0, k).map((l) => l + "\n").join(""));
    const s = rebuildState(dir);
    assert.equal(s.lastSeq, k);
    // Package outcomes only ever move forward along the log: a promoted package stays promoted.
    const promoted = Object.values(s.packages).filter((p) => p.state === "promoted").length;
    assert.ok(promoted >= promotedSoFar, `prefix ${k}: promoted count went down`);
    promotedSoFar = promoted;
    // A prefix cut in the middle of the last line is the same state as the prefix before it.
    if (k < lines.length) {
      fs.appendFileSync(path.join(dir, LOG_FILE), (lines[k] as string).slice(0, 25));
      const torn = rebuildState(dir);
      assert.equal(torn.lastSeq, k);
      assert.equal(torn.tornTail, true);
    }
  }
  assert.deepEqual(JSON.parse(JSON.stringify(rebuildState(dir, { write: false }))), JSON.parse(JSON.stringify(final)));
});

test("the fixture log itself reads strictly", () => {
  // Only the first four lines are the fixture; if someone ran the job in place, later lines are that run's.
  const r = readLog(FIXTURE, { tolerateTornTail: false });
  assert.deepEqual(r.events.slice(0, 4).map((e) => e.type), ["job_created", "brief_set", "brief_approved", "plan_set"]);
  assert.ok(readEvents(FIXTURE).length >= 4);
});
