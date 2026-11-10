import { test, after } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { cleanup, tempDir, tempJob, foremanFor, readEvents, packFiles, Kill } from "./helpers.js";
import { ledgerSpawn, reapOrphans } from "../orphans.js";
import { killTree, runProcess } from "../proc.js";
import { rebuildState } from "../joblog.js";
import { eventSchemas } from "../events.js";
import { ClaudeCliBuilder } from "../builder/claude-cli.js";
import { schemaErrors } from "../builder/json.js";
import { PKG_ROOT } from "../paths.js";
import type { JobEvent } from "../events.js";

after(cleanup);

const alive = (pid: number): boolean => {
  try {
    process.kill(pid, 0);
    return true;
  } catch (e) {
    return (e as NodeJS.ErrnoException).code === "EPERM";
  }
};
const wait = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

test("orphans: a hard-killed parent takes its children with it (Windows); the reaper kills a live ledger entry and never a process that is not provably ours", { skip: process.platform !== "win32" }, async () => {
  const dir = tempDir("orphan");
  const ledger = path.join(dir, "children.jsonl");
  const parentScript = path.join(dir, "parent.mjs");
  fs.writeFileSync(
    parentScript,
    `import { ledgerSpawn } from ${JSON.stringify(pathToFileURL(path.join(PKG_ROOT, "dist", "orphans.js")).href)};\n` +
      `ledgerSpawn(process.argv[2])({ exe: process.execPath, args: ["-e", "setInterval(() => {}, 1000)"], timeoutMs: 600000 });\n` +
      `setInterval(() => {}, 1000);\n`,
  );
  const parent = spawn(process.execPath, [parentScript, ledger], { stdio: "ignore", windowsHide: true });
  let childPid: number | undefined;
  try {
    for (let i = 0; i < 200 && childPid === undefined; i++) {
      await wait(25);
      if (fs.existsSync(ledger)) {
        const first = fs.readFileSync(ledger, "utf8").split("\n")[0];
        if (first) childPid = (JSON.parse(first) as { pid: number }).pid;
      }
    }
    assert.ok(childPid !== undefined, "the child never appeared in the ledger");
    // Kill the parent only (no tree), as a crash or a closed window would. Observed on Windows with Node 24: the
    // child dies with it, because Node starts non-detached children inside a kill-on-close job object. This test
    // pins that behaviour down, since resume relies on a dead Foreman not leaving a builder editing a workspace.
    assert.equal(alive(childPid), true);
    const gone = new Promise<void>((res) => parent.on("close", () => res()));
    parent.kill();
    await gone;
    for (let i = 0; i < 60 && alive(childPid); i++) await wait(50);
    assert.equal(alive(childPid), false, "a child survived the hard kill of its parent: the reaper is now load-bearing");
    // The ledger still names it; reaping finds nothing to kill and clears the file.
    const r = reapOrphans(ledger);
    assert.deepEqual(r, { killed: [], skipped: [{ pid: childPid, why: "no longer running" }] });
    assert.equal(fs.readFileSync(ledger, "utf8"), "", "the ledger is cleared after reaping");
  } finally {
    if (childPid !== undefined && alive(childPid)) killTree(childPid);
    if (parent.pid !== undefined && alive(parent.pid)) killTree(parent.pid);
  }

  // The reaper itself: a ledger entry whose process is still alive and matches in name and start time is killed.
  const pending = ledgerSpawn(ledger, runProcess)({ exe: process.execPath, args: ["-e", "setInterval(() => {}, 1000)"], timeoutMs: 60_000 });
  let livePid: number | undefined;
  for (let i = 0; i < 200 && livePid === undefined; i++) {
    await wait(25);
    const first = fs.readFileSync(ledger, "utf8").split("\n")[0];
    if (first) livePid = (JSON.parse(first) as { pid: number }).pid;
  }
  assert.ok(livePid !== undefined);
  const reaped = reapOrphans(ledger);
  assert.deepEqual(reaped.killed, [livePid]);
  const ended = await pending;
  assert.equal(ended.exitCode !== 0 || ended.signal !== undefined, true, "the reaped child did not end by being killed");
  assert.equal(alive(livePid), false);

  // A pid that now belongs to something else, or to a later process of the same name, is never touched.
  // (If this logic were wrong, this very test process would be killed.)
  const self = process.pid;
  fs.writeFileSync(
    ledger,
    [
      { pid: self, exe: "godot.exe", startedAt: Date.now() },
      { pid: 999_999_998, exe: "node.exe", startedAt: Date.now() },
      { pid: 12, exe: "node.exe", startedAt: Date.now() },
      { pid: 12, exited: true },
    ]
      .map((l) => JSON.stringify(l))
      .join("\n") + "\n",
  );
  const r1 = reapOrphans(ledger);
  assert.deepEqual(r1.killed, []);
  assert.deepEqual(r1.skipped.map((s) => s.pid).sort(), [999_999_998, self].sort());
  assert.match(r1.skipped.find((s) => s.pid === self)?.why ?? "", /pid now belongs to node\.exe/);
  fs.writeFileSync(ledger, JSON.stringify({ pid: self, exe: "node.exe", startedAt: Date.now() - 3_600_000 }) + "\n");
  const r2 = reapOrphans(ledger);
  assert.deepEqual(r2.killed, []);
  assert.match(r2.skipped[0]?.why ?? "", /reused/);
  assert.deepEqual(reapOrphans(path.join(dir, "no-ledger.jsonl")), { killed: [], skipped: [] });
});

test("orphans: a child that ends normally is closed in the ledger", async () => {
  const dir = tempDir("ledger");
  const ledger = path.join(dir, "children.jsonl");
  const r = await ledgerSpawn(ledger, runProcess)({ exe: process.execPath, args: ["-e", "console.log(1)"], timeoutMs: 10_000 });
  assert.equal(r.exitCode, 0);
  const lines = fs.readFileSync(ledger, "utf8").trim().split("\n").map((l) => JSON.parse(l) as { pid: number; exited?: boolean; exe?: string });
  assert.equal(lines.length, 2);
  assert.equal(lines[0]?.pid, lines[1]?.pid);
  assert.equal(lines[1]?.exited, true);
  assert.deepEqual(reapOrphans(ledger), { killed: [], skipped: [] });
});

test("parallel build, kill at every event, resume: same pack, nothing promoted is rebuilt", async () => {
  const ref = tempJob("pref");
  await foremanFor(ref, { parallel: 2 }).foreman.run();
  const refPack = packFiles(path.join(ref.jobDir, "pack"));
  const total = readEvents(ref.jobDir).length;
  let kills = 0;
  for (let killAt = 5; killAt < total + 4; killAt++) {
    const job = tempJob(`pkill${killAt}`);
    let killed = false;
    try {
      await foremanFor(job, {
        parallel: 2,
        afterAppend: (ev) => {
          if (ev.seq === killAt) throw new Kill(killAt);
        },
      }).foreman.run();
    } catch (e) {
      assert.ok(e instanceof Kill, String(e));
      killed = true;
    }
    if (!killed) continue;
    kills += 1;
    const atKill = rebuildState(job.jobDir, { write: false });
    const before = readEvents(job.jobDir);
    const promotedAtKill = Object.values(atKill.packages).filter((p) => p.state === "promoted").map((p) => p.id);
    const runs = (evs: JobEvent[], id: string): number => evs.filter((e) => e.type === "builder_run" && e.package === id).length;
    const s = await foremanFor(job, { parallel: 2 }).foreman.run();
    const evs = readEvents(job.jobDir);
    assert.equal(s.jobState?.state, "done", `kill at ${killAt}`);
    assert.deepEqual(s.order.map((id) => s.packages[id]?.state), ["promoted", "promoted", "promoted"], `kill at ${killAt}`);
    assert.deepEqual(packFiles(path.join(job.jobDir, "pack")), refPack, `kill at ${killAt}: pack differs`);
    for (const id of promotedAtKill) assert.equal(runs(evs, id), runs(before, id), `kill at ${killAt}: ${id} was rebuilt`);
    // every merge names the files the package contributed, also when the merge was redone after the kill
    for (const id of s.order) assert.ok((s.packages[id]?.mergedFiles ?? []).length >= 2, `kill at ${killAt}: ${id} has no merged files on record`);
  }
  assert.ok(kills > 40, `only ${kills} kill points were exercised`);
});

test("resume refuses to continue when pack/ lost files the log says were merged", async () => {
  const job = tempJob("lost");
  await assert.rejects(
    foremanFor(job, {
      afterAppend: (ev) => {
        if (ev.type === "package_state" && ev.package === "core" && ev.state === "promoted") throw new Kill(ev.seq);
      },
    }).foreman.run(),
    Kill,
  );
  fs.rmSync(path.join(job.jobDir, "pack", "scripts", "main.gd"));
  const s = await foremanFor(job).foreman.run();
  assert.equal(s.jobState?.state, "failed");
  assert.match(s.jobState?.reason ?? "", /pack\/ no longer holds files the log says were merged \(core: scripts\/main\.gd\)/);
  assert.equal(readEvents(job.jobDir).filter((e) => e.type === "builder_run").length, 1, "nothing was built on top of a broken pack");
});

test("the budget policy lives in the log: a resume without the flag still enforces it, and a pause cut by a kill is closed", async () => {
  const job = tempJob("budget-resume");
  let clock = Date.parse("2026-11-10T20:00:00.000Z");
  const now = (): Date => new Date((clock += 1));
  const sleep = async (ms: number): Promise<void> => void (clock += ms);
  await assert.rejects(
    foremanFor(job, {
      budget: { kind: "tokens_per_hour", limit: 8000 },
      now,
      sleep,
      afterAppend: (ev) => {
        if (ev.type === "budget" && ev.state === "paused") throw new Kill(ev.seq);
      },
    }).foreman.run(),
    Kill,
  );
  const atKill = rebuildState(job.jobDir, { write: false });
  assert.deepEqual(atKill.budget?.policy, { kind: "tokens_per_hour", limit: 8000 });
  assert.equal(atKill.budget?.state, "paused");
  const killedAt = atKill.lastSeq;
  // Resume with NO policy given: the logged one holds. The clock has not moved, so the pause is still due.
  const s = await foremanFor(job, { now, sleep }).foreman.run();
  assert.equal(s.jobState?.state, "done");
  const later = readEvents(job.jobDir).filter((e) => e.seq > killedAt && e.type === "budget");
  assert.ok(later.length >= 2);
  assert.equal(later[0]?.type === "budget" ? later[0].state : "", "paused");
  assert.deepEqual(later[0]?.type === "budget" ? later[0].policy : {}, { kind: "tokens_per_hour", limit: 8000 });
  // WP3c item 7: the job has ended, so the derived state is closed; the last budget EVENT still says running.
  assert.equal(s.budget?.state, "closed");
  assert.equal(s.budget?.open?.state, "running");

  // Second case: the reason for the pause is gone by the time of the restart.
  const job2 = tempJob("budget-resume2");
  let clock2 = Date.parse("2026-11-10T20:00:00.000Z");
  const now2 = (): Date => new Date((clock2 += 1));
  await assert.rejects(
    foremanFor(job2, {
      budget: { kind: "tokens_per_hour", limit: 8000 },
      now: now2,
      afterAppend: (ev) => {
        if (ev.type === "budget" && ev.state === "paused") throw new Kill(ev.seq);
      },
    }).foreman.run(),
    Kill,
  );
  const k2 = rebuildState(job2.jobDir, { write: false }).lastSeq;
  clock2 += 2 * 3_600_000;
  const s2 = await foremanFor(job2, { now: now2 }).foreman.run();
  assert.equal(s2.jobState?.state, "done");
  const first = readEvents(job2.jobDir).find((e) => e.seq > k2 && e.type === "budget");
  assert.ok(first?.type === "budget" && first.state === "running" && /allowed again after a restart/.test(first.reason));
});

test("claude-cli: envelopes recorded from the real CLI (2.1.322) normalize to the right results", () => {
  const b = new ClaudeCliBuilder({ bin: process.execPath, env: {} });
  const load = (name: string): string => fs.readFileSync(path.join(PKG_ROOT, "fixtures", "envelopes", `claude-cli-2.1.322-${name}.ndjson`), "utf8");
  const proc = (stdout: string, extra: object = {}): Parameters<ClaudeCliBuilder["normalize"]>[0] => ({ exitCode: 0, stdout, stderr: "", timedOut: false, outputCapped: false, durationMs: 1, ...extra });
  const capital = { type: "object", additionalProperties: false, required: ["capital"], properties: { capital: { type: "string" } } };

  const gen = b.normalize(proc(load("generate")), [], "", { prompt: "p", mode: "generate", cwd: "", schema: capital, timeoutMs: 1000 }, 1000);
  assert.deepEqual([gen.ok, gen.outcome, gen.json, gen.tokensIn, gen.tokensOut], [true, "ok", { capital: "Paris" }, 2715, 54]);
  assert.deepEqual(gen.observed, { tools: ["StructuredOutput"], permissionMode: "default", apiKeySource: "none", billingMode: "subscription" });
  assert.equal(gen.model, "claude-sonnet-5-5");

  const edit = b.normalize(proc(load("edit")), [], "", { prompt: "p", mode: "edit", cwd: "", timeoutMs: 1000 }, 1000);
  assert.deepEqual([edit.ok, edit.outcome, edit.text, edit.tokensIn, edit.tokensOut], [true, "ok", "NO_SHELL", 11240, 206]);
  assert.deepEqual(edit.observed?.tools, ["Edit", "Glob", "Grep", "Read", "Write"]);
  assert.equal(edit.observed?.permissionMode, "acceptEdits");

  // What the 1 s run looked like: only the init event, then our kill.
  const cut = b.normalize(proc(load("edit-timeout"), { timedOut: true, exitCode: undefined }), [], "", { prompt: "p", mode: "edit", cwd: "", timeoutMs: 1000 }, 1000);
  assert.deepEqual([cut.ok, cut.outcome, cut.tokensIn, cut.text], [false, "timeout", undefined, undefined]);

  const briefSchema = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "prompts", "brief.schema.json"), "utf8")) as object;
  const designer = b.normalize(proc(load("designer")), [], "", { prompt: "p", mode: "generate", cwd: "", schema: briefSchema, timeoutMs: 1000 }, 1000);
  assert.deepEqual([designer.ok, designer.outcome, designer.tokensIn, designer.tokensOut], [true, "ok", 3893, 987]);
  assert.deepEqual(schemaErrors(briefSchema, designer.json), []);
  // The same real stream cut before its result event is `truncated`, not `error` and not `ok`.
  const lines = load("designer").trim().split("\n");
  const noResult = b.normalize(proc(lines.slice(0, 3).join("\n") + "\n"), [], "", { prompt: "p", mode: "generate", cwd: "", schema: briefSchema, timeoutMs: 1000 }, 1000);
  assert.deepEqual([noResult.ok, noResult.outcome], [false, "truncated"]);
});

test("data/job-events.schema.json is the event vocabulary the reader enforces", () => {
  const onDisk = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "data", "job-events.schema.json"), "utf8")) as { events: object };
  assert.deepEqual(onDisk.events, JSON.parse(JSON.stringify(eventSchemas())));
});
