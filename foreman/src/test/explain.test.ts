// `foreman explain <job>`: per-round cost, why each round ran (from rounds.ts), and the one next command. Offline:
// the fixture job with the fake adapter, and hand-written logs. explain reads job.jsonl and writes nothing.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { main } from "../cli.js";
import { explain, explainText, type Explanation } from "../explain.js";
import { JobLog, changeReason, readLog, rebuildState, weightedTokens, type NewEvent } from "../joblog.js";
import { runProcess } from "../proc.js";
import { cleanup, tempJob } from "./helpers.js";
import { PKG_ROOT } from "../paths.js";

after(cleanup);

const CLI = path.join(PKG_ROOT, "dist", "cli.js");
const run = async (argv: string[]): Promise<{ code: number; text: string }> => {
  const lines: string[] = [];
  const code = await main(argv, (s) => lines.push(s));
  return { code, text: lines.join("\n") };
};

/** A copy of the fixture (4 events, up to plan_set) with `events` appended through the real writer (lock released after). */
function logged(label: string, events: NewEvent[]): string {
  const job = tempJob(label);
  const log = JobLog.open(job.jobDir);
  try {
    for (const e of events) log.append(e);
  } finally {
    log.close();
  }
  fs.rmSync(path.join(job.jobDir, "state.json"), { force: true });
  return job.jobDir;
}

const bw = (pkg: string, round: number, tokensIn: number, tokensOut: number, extra: Record<string, unknown> = {}): NewEvent =>
  ({ type: "builder_run", package: pkg, round, adapter: "fake", mode: "edit", model: "fake", outcome: "ok", durationMs: 100 * round, tokensIn, tokensOut, ...extra }) as NewEvent;
const ps = (pkg: string, state: string, round: number, extra: Record<string, unknown> = {}): NewEvent => ({ type: "package_state", package: pkg, state, round, ...extra }) as NewEvent;
const vf = (pkg: string, round: number, verb: string, level: string, ok: boolean, report: string): NewEvent => ({ type: "verify", package: pkg, round, level, verb, ok, report, exitCode: ok ? 0 : 1 }) as NewEvent;

/** Every file under a directory with its bytes and mtime: what a read-only command must leave as it was. */
function snapshot(dir: string): string {
  const out: string[] = [];
  const walk = (d: string): void => {
    for (const n of fs.readdirSync(d).sort()) {
      const f = path.join(d, n);
      const st = fs.statSync(f);
      if (st.isDirectory()) walk(f);
      else out.push(`${path.relative(dir, f)} ${st.size} ${st.mtimeMs} ${fs.readFileSync(f).toString("base64").slice(0, 64)}`);
    }
  };
  walk(dir);
  return out.join("\n");
}

// The `foreman status` text of the fixture run to done, taken from the base (30d0526) before the display code moved.
// H1e (25 Nov): events 57, was 56: the first promotion takes one picture (the window check).
const STATUS_DONE = `job      paddle-court-20261110-1  "Paddle Court"  pack game.paddle_court
state    done  (pack verified V0 to V4 and promoted under the job directory (promoted/game.paddle_court))   events 57
brief    approved by auto   plan 3 packages (revision 1)
card     no card (the Planner named none)
billing  fake none: fake adapter: no model is called and nothing is billed
tokens   in 20400  out 2660
promoted game.paddle_court 0.1.0 -> promoted/game.paddle_court
milestone blockout: 2 capture(s) (captures/blockout-hero-f120.png, captures/blockout-hero-f480.png)
milestone greybox: 2 capture(s) (captures/greybox-hero-f150.png, captures/greybox-hero-f450.png)

package    state     round  milestone  runs  cause  last verify  detail
---------  --------  -----  ---------  ----  -----  -----------  ------
core       promoted  1      blockout   1            smoke ok r1
court      promoted  1      blockout   1            smoke ok r1
paddle_ai  promoted  2      greybox    2            bot ok r2`;

let doneJob: Promise<string> | undefined;
/** The fixture job run to done with the fake adapter (tokens scripted in fake-builder.json); built once. */
function fixtureDone(): Promise<string> {
  doneJob ??= (async () => {
    const job = tempJob("explain-done");
    const r = await run(["run", job.jobDir, "--adapter", "fake", "--quiet"]);
    assert.equal(r.code, 0, r.text);
    return job.jobDir;
  })();
  return doneJob;
}

test("explain: the fixture run to done -> one block per package, one line per round with why, outcome, duration, tokens; sums are the job total", async () => {
  const jobDir = await fixtureDone();
  const before = snapshot(jobDir);
  const r = await run(["explain", jobDir]);
  assert.equal(r.code, 0, r.text);
  assert.equal(snapshot(jobDir), before, "explain writes nothing (not even state.json)");
  const lines = r.text.split("\n");
  for (const id of ["core", "court", "paddle_ai"]) assert.ok(lines.some((l) => l.startsWith(`${id} `)), `a block for ${id}:\n${r.text}`);
  const roundLine = (re: RegExp): string => lines.find((l) => re.test(l)) ?? assert.fail(`no line ${re}:\n${r.text}`);
  const core1 = roundLine(/^\s+r1\s.*first build/);
  assert.match(core1, /\bok\b/);
  assert.match(core1, /\d+ms/);
  assert.match(core1, /in 5200 out 900 w 6100/);
  const ai2 = roundLine(/^\s+r2\s/);
  assert.match(ai2, /retry after smoke V2 FAILED/);
  assert.match(ai2, /in 5000 out 300 w 5300/);

  const j = JSON.parse((await run(["explain", jobDir, "--json"])).text) as Explanation;
  const s = rebuildState(jobDir, { write: false });
  const ledger = s.tokenLedger.reduce((a, t) => a + t.tokens, 0);
  const pkgSum = j.packages.reduce((a, p) => a + p.rounds.reduce((b, x) => b + x.weighted, 0), 0);
  assert.equal(pkgSum + (j.jobRuns?.weighted ?? 0), ledger, "per-round weighted sums plus the job-level runs are the state's total");
  assert.equal(j.weighted, ledger);
  for (const p of j.packages) assert.equal(p.weighted, p.rounds.reduce((b, x) => b + x.weighted, 0));
  const core = j.packages.find((p) => p.id === "core");
  assert.equal(core?.weighted, weightedTokens(s.packages["core"]?.tokensIn ?? 0, s.packages["core"]?.tokensOut ?? 0));
  assert.deepEqual(j.packages.find((p) => p.id === "paddle_ai")?.rounds.map((x) => [x.round, x.kind, x.why]), [
    [1, "first", "first build"],
    [2, "verify_retry", "retry after smoke V2 FAILED"],
  ]);
  assert.equal(lines.at(-1), "next: nothing; promoted game.paddle_court 0.1.0 -> promoted/game.paddle_court");
});

test("explain: the last verify of core r2 is smoke FAILED -> the r2 line names 'smoke V2 FAILED' and its report; a change request round says its number", () => {
  const jobDir = logged("explain-verify", [
    { type: "job_state", state: "running", reason: "started" },
    ps("core", "queued", 1),
    ps("core", "running", 1),
    bw("core", 1, 1000, 100),
    vf("core", 1, "lint", "V1", false, "reports/core-r1-lint.json"),
    ps("core", "running", 2),
    bw("core", 2, 2000, 200, { tokensCacheRead: 1000 }),
    vf("core", 2, "lint", "V1", true, "reports/core-r2-lint.json"),
    vf("core", 2, "smoke", "V2", false, "reports/core-r2-smoke.json"),
    ps("core", "failed", 2, { cause: "verify_failed", detail: "smoke (V2) did not pass after 2 rounds" }),
    ps("court", "queued", 1),
    ps("court", "running", 1),
    bw("court", 1, 400, 40),
    ps("court", "promoted", 1),
    { type: "change_requested", text: "make the walls taller", package: "court" },
    { type: "reopened", package: "court", reason: changeReason(19) },
    ps("court", "queued", 2, { detail: "CHANGE REQUEST: make the walls taller" }),
    { type: "job_state", state: "failed", reason: "core failed" },
  ]);
  const { events } = readLog(jobDir);
  const s = rebuildState(jobDir, { write: false });
  const ex = explain(s, events, { alive: false });
  const core = ex.packages.find((p) => p.id === "core");
  assert.deepEqual(core?.rounds.map((r) => r.why), ["first build", "retry after lint V1 FAILED"]);
  assert.deepEqual(core?.rounds[1]?.verify, { verb: "smoke", level: "V2", ok: false, report: "reports/core-r2-smoke.json" });
  assert.equal(core?.rounds[1]?.weighted, weightedTokens(2000, 200, 1000));
  const court = ex.packages.find((p) => p.id === "court");
  assert.deepEqual(court?.rounds.map((r) => [r.kind, r.why]), [["first", "first build"], ["change", "change request #19"]]);
  assert.equal(ex.costByWhy["change"], undefined, "a round that spent nothing adds no key");
  const text = explainText(ex).split("\n");
  const r2 = text.find((l) => /^\s+r2\s/.test(l) && l.includes("lint V1 FAILED")) ?? assert.fail(explainText(ex));
  assert.match(r2, /smoke V2 FAILED reports\/core-r2-smoke\.json/);
  assert.match(text.at(-1) ?? "", /^next: foreman resume paddle-court-20261110-1 --retry-failed .*core failed: verify_failed.*reports\/core-r2-smoke\.json/);
});

test("explain: an open question -> 'next: foreman answer <job> <package> \"...\"' quoting the question", async () => {
  const jobDir = logged("explain-question", [
    { type: "job_state", state: "running", reason: "started" },
    ps("paddle_ai", "queued", 1),
    ps("paddle_ai", "running", 1),
    bw("paddle_ai", 1, 300, 30),
    { type: "question", package: "paddle_ai", text: "May the AI read the ball's velocity?" },
    ps("paddle_ai", "blocked", 1, { cause: "question" }),
    { type: "job_state", state: "paused", reason: "a builder asked a question" },
  ]);
  const r = await run(["explain", jobDir]);
  assert.equal(r.code, 0, r.text);
  assert.equal(r.text.split("\n").at(-1), `next: foreman answer paddle-court-20261110-1 paddle_ai "<your answer>"   (paddle_ai asks: "May the AI read the ball's velocity?")`);
});

test("explain: running and no live lock -> resume; budget paused -> waiting on budget; a live Foreman -> nothing to type", () => {
  const jobDir = logged("explain-killed", [
    { type: "job_state", state: "running", reason: "started" },
    ps("core", "queued", 1),
    ps("core", "running", 1),
  ]);
  const { events } = readLog(jobDir);
  const s = rebuildState(jobDir, { write: false });
  assert.equal(explain(s, events, { alive: false }).next, `foreman resume paddle-court-20261110-1 (the Foreman is not running; log stops at event 7)`);
  assert.equal(explain(s, events, { pid: 4242, alive: false }).next, `foreman resume paddle-court-20261110-1 (the Foreman is not running: pid 4242 is gone; log stops at event 7)`);
  assert.equal(explain(s, events, { pid: 4242, alive: true }).next, "nothing to type; the Foreman is running (pid 4242)");

  const paused = logged("explain-budget", [
    { type: "job_state", state: "running", reason: "started" },
    { type: "budget", policy: { kind: "tokens_per_hour", limit: 1000 }, state: "paused", reason: "1200 of 1000 tokens in the last hour" },
    ps("core", "blocked", 1, { cause: "budget", detail: "1200 of 1000 tokens in the last hour" }),
  ]);
  const p = readLog(paused);
  const ps2 = rebuildState(paused, { write: false });
  assert.equal(explain(ps2, p.events, { pid: 7, alive: true }).next, "waiting on budget: 1200 of 1000 tokens in the last hour");
});

test("explain --json: one object that parses; costByWhy values sum to the weighted total", async () => {
  const jobDir = await fixtureDone();
  const r = await run(["explain", jobDir, "--json"]);
  assert.equal(r.code, 0);
  const j = JSON.parse(r.text) as Explanation;
  assert.equal(j.job, "paddle-court-20261110-1");
  assert.deepEqual(j.packages.map((p) => p.id), ["core", "court", "paddle_ai"]);
  for (const p of j.packages) for (const x of p.rounds) for (const k of ["round", "kind", "why", "outcome", "durationMs", "tokensIn", "tokensOut", "weighted"]) assert.ok(k in x, `${p.id} r${x.round} has ${k}`);
  const sum = Object.values(j.costByWhy).reduce((a, b) => a + b, 0);
  assert.equal(sum, j.weighted);
  assert.deepEqual(Object.keys(j.costByWhy).sort(), ["first", "job", "verify_retry"]);
  assert.equal(j.next, "nothing; promoted game.paddle_court 0.1.0 -> promoted/game.paddle_court");
  assert.equal("text" in j, false);
  // --package keeps one block.
  const one = JSON.parse((await run(["explain", jobDir, "--json", "--package", "paddle_ai"])).text) as Explanation;
  assert.deepEqual(one.packages.map((p) => p.id), ["paddle_ai"]);
});

test("explain --package nope -> UsageError naming the job's packages, exit 2", async () => {
  const jobDir = logged("explain-nope", [{ type: "job_state", state: "running", reason: "started" }]);
  const r = await runProcess({ exe: process.execPath, args: [CLI, "explain", jobDir, "--package", "nope"], timeoutMs: 30_000 });
  assert.equal(r.exitCode, 2, r.stdout + r.stderr);
  assert.equal(r.stderr.trim(), `no package "nope" in paddle-court-20261110-1 (core, court, paddle_ai)`);
});

test("status is unchanged byte for byte after the move (guard), and cli.ts stays within its 906-line ratchet", async () => {
  const jobDir = await fixtureDone();
  const r = await run(["status", jobDir]);
  assert.equal(r.code, 0);
  assert.equal(r.text, STATUS_DONE);
  const killed = logged("explain-status-killed", [{ type: "job_state", state: "running", reason: "started" }]);
  const k = await run(["status", killed]);
  assert.equal(k.text.split("\n").at(-1), "foreman  NOT running; the log stops at event 5. Continue with: foreman resume paddle-court-20261110-1");
  const cliLines = fs.readFileSync(path.join(PKG_ROOT, "src", "cli.ts"), "utf8").split("\n").length - 1;
  const baseline = (JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "..", "devx", "arch.baseline.json"), "utf8")) as { sizes: Record<string, number> }).sizes["foreman/src/cli.ts"];
  assert.ok(cliLines <= 906, `cli.ts has ${cliLines} lines`);
  if (baseline !== undefined) assert.ok(cliLines <= baseline, `cli.ts ${cliLines} > baseline ${baseline}`);
});

test("explain.ts reads why a round ran from rounds.ts only: no prefix test of its own (source scan)", () => {
  const src = fs.readFileSync(path.join(PKG_ROOT, "src", "explain.ts"), "utf8");
  assert.match(src, /from "\.\/rounds\.js"/);
  assert.match(src, /\broundKinds\(/);
  assert.doesNotMatch(src, /startsWith\(|\.test\(|\bmatch\(|indexOf\(/, "no prefix matching in explain.ts");
  for (const c of ["CRITIC_ROUND", "CHANGE_ROUND", "DEP_CHANGED", "KIT_REGRESSION", "NO_VISIBLE_CHANGE", "FINAL_FAILED"]) assert.ok(!src.includes(c), `explain.ts does not use ${c}`);
  assert.ok(!/writeFileSync|appendFileSync|JobLog\.open|rebuildState\(/.test(src), "explain.ts writes nothing");
});
