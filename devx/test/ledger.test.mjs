// Ledger tests: synthetic job logs with known figures, a torn/odd log, and the real marble jobs when the site exists.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { findSiteRoot, readJob, readLedger } from "../lib/commands/ledger.mjs";

function job(events) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tl-ledger-"));
  const d = path.join(dir, "job-a");
  fs.mkdirSync(d);
  const base = "2026-01-01T10:";
  const lines = events.map((e, i) => JSON.stringify({ v: 1, seq: i + 1, ts: `${base}${e.ts ?? "00:00"}.000Z`, job: "job-a", ...e, ts: `${base}${e.ts ?? "00:00"}.000Z` }));
  fs.writeFileSync(path.join(d, "job.jsonl"), lines.join("\n") + "\n");
  return { dir, file: path.join(d, "job.jsonl") };
}

test("figures are summed and derived from events only", () => {
  const { file } = job([
    { type: "job_created", ts: "00:00" },
    { type: "job_state", state: "running", ts: "01:00" },
    { type: "package_state", package: "a", state: "queued", round: 1 },
    { type: "builder_run", mode: "edit", tokensIn: 1000, tokensOut: 100, tokensCacheRead: 800 },
    { type: "package_state", package: "a", state: "queued", round: 2, detail: "critic (V5) NOT ok, one extra round: x" },
    { type: "package_state", package: "b", state: "queued", round: 1 },
    { type: "builder_run", mode: "generate", tokensIn: 500, tokensOut: 50, tokensCacheRead: 0 },
    { type: "replan", reason: "r", added: [], removed: [], changed: [] },
    { type: "job_state", state: "done", ts: "10:30" },
  ]);
  const j = readJob(file);
  assert.equal(j.outcome, "done");
  assert.equal(j.wallMs, 10.5 * 60000);
  assert.equal(j.runMs, 9.5 * 60000);
  assert.equal(j.packages, 2);
  assert.equal(j.rounds, 3);
  assert.equal(j.editRuns, 1);
  assert.equal(j.tokensIn, 1500);
  assert.equal(j.tokensOut, 150);
  assert.equal(j.tokensCacheRead, 800);
  assert.equal(j.weighted, Math.round(1500 - 800 + 80 + 150));
  assert.equal(j.replans, 1);
  assert.equal(j.critic, 1);
});

test("a field the log does not carry is null, never guessed", () => {
  const { file } = job([
    { type: "job_created" },
    { type: "builder_run", mode: "edit", tokensIn: 100, tokensOut: 10 },
    { type: "job_state", state: "failed", ts: "01:00" },
  ]);
  const j = readJob(file);
  assert.equal(j.tokensCacheRead, null);
  assert.equal(j.weighted, null, "weighted needs the cache figure");
  assert.equal(j.tokensIn, 100);
  assert.equal(j.packages, null);
  const noRuns = readJob(job([{ type: "job_created" }]).file);
  assert.equal(noRuns.tokensIn, null);
  assert.equal(noRuns.outcome, null);
  assert.equal(noRuns.runMs, null);
});

test("a torn final line is tolerated, a broken middle line is reported", () => {
  const { file } = job([{ type: "job_created" }, { type: "job_state", state: "running" }]);
  fs.appendFileSync(file, '{"v":1,"seq":3,"ty');
  assert.equal(readJob(file).problem, undefined);
  const text = fs.readFileSync(file, "utf8").split("\n");
  fs.writeFileSync(file, [text[0], "garbage", text[1], ""].join("\n"));
  assert.match(readJob(file).problem, /line 2/);
});

test("readLedger skips underscore dirs and dirs without a log, and totals only known figures", () => {
  const a = job([{ type: "job_created" }, { type: "builder_run", mode: "edit", tokensIn: 10, tokensOut: 1, tokensCacheRead: 5 }, { type: "job_state", state: "done", ts: "01:00" }]);
  const root = path.dirname(a.dir + "/x");
  fs.mkdirSync(path.join(a.dir, "_engine_snapshot"));
  fs.mkdirSync(path.join(a.dir, "empty"));
  const b = path.join(a.dir, "job-b");
  fs.mkdirSync(b);
  fs.writeFileSync(path.join(b, "job.jsonl"), JSON.stringify({ v: 1, seq: 1, ts: "2026-01-01T10:00:00.000Z", job: "job-b", type: "job_created" }) + "\n");
  const led = readLedger(a.dir);
  assert.deepEqual(led.jobs.map((j) => j.id), ["job-a", "job-b"]);
  assert.equal(led.totals.tokensIn, 10);
  assert.equal(led.totals.tokensIn_jobs, 1);
  assert.ok(root);
});

test("findSiteRoot honours TL_SITE_DIR first", () => {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), "tl-site-"));
  assert.equal(findSiteRoot({ TL_SITE_DIR: d }, d), path.resolve(d));
});

// The real record: docs/reports/JOB2-MARBLE.md, "The two jobs side by side".
const site = findSiteRoot();
const real = site && fs.existsSync(path.join(site, "marble-run-three-marbles-20261110-2", "job.jsonl"));
test("real marble job 2 matches JOB2-MARBLE.md", { skip: !real && "no site/ with the marble jobs" }, () => {
  const j = readJob(path.join(site, "marble-run-three-marbles-20261110-2", "job.jsonl"));
  assert.equal(j.outcome, "done");
  assert.equal(Math.round(j.wallMs / 1000), 14 * 60 + 45);
  assert.equal(j.packages, 3);
  assert.equal(j.editRuns, 7);
  assert.equal(j.tokensIn, 2009179);
  assert.equal(j.tokensCacheRead, 1689227);
  assert.equal(j.tokensOut, 85150);
  assert.ok(Math.abs(j.weighted - 574000) < 100, `weighted ${j.weighted} should be about 574,000`);
  assert.equal(j.critic, 3);
  assert.equal(j.replans, 0);
});
test("real marble job 1 matches JOB2-MARBLE.md where its log carries the figure", { skip: !real && "no site/ with the marble jobs" }, () => {
  const j = readJob(path.join(site, "marble-run-three-marbles-20261110-1", "job.jsonl"));
  assert.equal(Math.round(j.runMs / 1000) - (14 * 60 + 22) <= 1, true, "started to done is 14 min 22 s in the report");
  assert.equal(j.editRuns, 3);
  assert.equal(j.tokensIn, 2682580);
  assert.equal(j.tokensOut, 98790);
  assert.equal(j.tokensCacheRead, null, "job 1 predates tokensCacheRead: the log cannot give the report's 2,457,191");
});
