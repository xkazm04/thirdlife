import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { matchGlob } from "../lib/gate/glob.mjs";
import { discoverSteps } from "../lib/gate/discover.mjs";
import { changedPaths, mapChanged } from "../lib/gate/changed.mjs";
import { classify } from "../lib/gate/flaky.mjs";
import { median, trend } from "../lib/gate/history.mjs";
import { execute } from "../lib/commands/check.mjs";
import { hookAction, HOOK_SCRIPT } from "../lib/commands/hook.mjs";
import * as ctx from "../lib/ctx.mjs";

const fake = (id, run, extra = {}) => ({ id, tiers: ["fast", "full"], paths: [`${id}/**`], run, ...extra });
async function gate(args, steps, deps = {}) {
  const lines = [];
  const orig = console.log; console.log = (...a) => lines.push(a.join(" "));
  const origErr = console.error; console.error = () => {};
  let exit; try { exit = await execute(args, { steps, historyFile: null, ctx, ...deps }); } finally { console.log = orig; console.error = origErr; }
  let json = null; try { json = JSON.parse(lines.at(-1) ?? "null"); } catch { /* --trend prints a table */ }
  return { exit, lines, json };
}

test("glob matcher", () => {
  assert.ok(matchGlob("engine/kernel/**", "engine/kernel/runner/worker.gd"));
  assert.ok(matchGlob("engine/kernel/**", "engine/kernel/a.gd"));
  assert.ok(!matchGlob("engine/kernel/**", "engine/kits/a.gd"));
  assert.ok(matchGlob("**/*.md", "a/b/c.md") && matchGlob("**/*.md", "c.md"));
  assert.ok(matchGlob("foreman/*.json", "foreman/package.json") && !matchGlob("foreman/*.json", "foreman/src/x.json"));
  assert.ok(matchGlob("a/?.txt", "a/b.txt") && !matchGlob("a/?.txt", "a/bc.txt"));
  assert.ok(matchGlob("devx/**", "devx\\lib\\x.mjs"));
  assert.ok(matchGlob("a.b", "a.b") && !matchGlob("a.b", "axb"));
});

test("a failing fake step: exit 1 and the step is named; JSON is the last line", async () => {
  const { exit, lines, json } = await gate([], [fake("good", async () => ({ ok: true })), fake("bad.step", async () => ({ ok: false, detail: "boom" }))]);
  assert.equal(exit, 1);
  assert.ok(lines.some((l) => l.startsWith("FAIL") && l.includes("bad.step") && l.includes("boom")));
  assert.ok(lines.some((l) => l.startsWith("PASS") && l.includes("good")));
  assert.equal(json.schema, "tl.devx/1"); assert.equal(json.ok, false);
});

test("all green -> exit 0", async () => {
  const { exit, json } = await gate([], [fake("a", async () => ({ ok: true }))]);
  assert.equal(exit, 0); assert.equal(json.ok, true);
});

test("a step that throws, and a malformed result, are FAILs naming the step", async () => {
  const { exit, lines } = await gate([], [fake("thrower", async () => { throw new Error("kaput"); }), fake("sloppy", async () => "yes")]);
  assert.equal(exit, 1);
  assert.ok(lines.some((l) => l.startsWith("FAIL") && l.includes("thrower") && l.includes("kaput")));
  assert.ok(lines.some((l) => l.startsWith("FAIL") && l.includes("sloppy") && l.includes("malformed")));
});

test("flaky: clock-only failure retried once alone, passes, is labelled and counted", async () => {
  let calls = 0; const seen = [];
  const s = fake("clocky", async (c) => { calls++; seen.push(!!c.retry); return calls === 1 ? { ok: false, clockOnly: true, detail: "tick_timeout" } : { ok: true, detail: "fine" }; });
  const { exit, lines, json } = await gate([], [s]);
  assert.equal(exit, 0); assert.equal(calls, 2); assert.deepEqual(seen, [false, true]);
  assert.ok(lines.some((l) => l.startsWith("PASS") && l.includes("flaky-retry-passed")));
  assert.equal(json.flaky_retries, 1); assert.equal(json.steps[0].retried, true);
});

test("flaky: a second failure is a real FAIL; a non-clock failure is never retried", async () => {
  let n = 0;
  const twice = fake("twice", async () => { n++; return { ok: false, clockOnly: true, detail: "slow" }; });
  let m = 0;
  const real = fake("real", async () => { m++; return { ok: false, detail: "wrong hash" }; });
  const { exit, json } = await gate([], [twice, real]);
  assert.equal(exit, 1); assert.equal(n, 2); assert.equal(m, 1);
  assert.equal(json.steps.find((s) => s.id === "twice").ok, false);
  assert.equal(json.flaky_retries, 0);
});

test("clock classification reads the case reports; unknown means real", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tlt_"));
  fs.writeFileSync(path.join(dir, "a.json"), '{"watchdog":{"reason":"tick_timeout"}}');
  fs.writeFileSync(path.join(dir, "b.json"), '{"checks":[{"id":"invariants.frame_budget","ok":false}]}');
  fs.writeFileSync(path.join(dir, "c.json"), '{"checks":[{"id":"smoke.no_script_errors","ok":false}]}');
  assert.equal(classify("PASS x\nFAIL a: exit code 3, expected 0\nFAIL b: x\n", dir).clockOnly, true);
  assert.equal(classify("FAIL a: x\nFAIL c: y\n", dir).clockOnly, false);
  assert.equal(classify("FAIL nope.hash: x\n", dir).clockOnly, false);
  assert.equal(classify("PASS all\n", dir).clockOnly, false);
  fs.rmSync(dir, { recursive: true });
});

test("tiers: fast skips full-only steps; --only picks; unknown --only and bad --tier are exit 2", async () => {
  const ran = [];
  const mk = (id, tiers) => fake(id, async () => { ran.push(id); return { ok: true }; }, { tiers });
  const steps = [mk("s.fast", ["fast", "full"]), mk("s.full", ["full"])];
  await gate(["--tier", "fast"], steps); assert.deepEqual(ran.splice(0), ["s.fast"]);
  await gate([], steps); assert.deepEqual(ran.splice(0), ["s.fast", "s.full"]);
  await gate(["--only", "s.full"], steps); assert.deepEqual(ran.splice(0), ["s.full"]);
  assert.equal((await gate(["--only", "nope"], steps)).exit, 2);
  assert.equal((await gate(["--tier", "x"], steps)).exit, 2);
  assert.deepEqual(ran, []);
});

test("--changed maps injected git output to steps; an unmatched path runs everything", async () => {
  const ran = [];
  const mk = (id, paths) => ({ id, tiers: ["fast", "full"], paths, run: async () => { ran.push(id); return { ok: true }; } });
  const steps = [mk("kernel.selftest", ["engine/kernel/**"]), mk("seeds", ["engine/kernel/**", "engine/seeds/**"]), mk("foreman.test", ["foreman/**"])];
  const gitFor = (diff, untracked = "") => (a) => (a[0] === "diff" ? (assert.deepEqual(a, ["diff", "--name-only", "HEAD"]), diff) : untracked);
  await gate(["--changed"], steps, { git: gitFor("engine/kernel/runner/worker.gd\n") });
  assert.deepEqual(ran.splice(0), ["kernel.selftest", "seeds"]);
  await gate(["--changed"], steps, { git: gitFor("", "foreman/src/new.ts\n") });
  assert.deepEqual(ran.splice(0), ["foreman.test"]);
  await gate(["--changed"], steps, { git: gitFor("foreman/a.ts\nREADME.md\n") });
  assert.deepEqual(ran.splice(0), ["kernel.selftest", "seeds", "foreman.test"]);
  const r = await gate(["--changed"], steps, { git: gitFor("") });
  assert.deepEqual(ran, []); assert.equal(r.exit, 0);
  const base = []; await gate(["--changed", "--base", "origin/main"], steps, { git: (a) => { base.push(a.join(" ")); return ""; } });
  assert.equal(base[0], "diff --name-only origin/main");
  assert.deepEqual(changedPaths(() => "a\nb\n"), ["a", "b"]);
  assert.equal(mapChanged(["x/y"], steps).all, true);
});

test("discovery: missing dir ok; a throwing file and a malformed step become FAILs naming the file", async () => {
  assert.deepEqual(await discoverSteps(path.join(os.tmpdir(), "tl_no_such_dir_xyz")), { steps: [], broken: [] });
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tld_"));
  fs.writeFileSync(path.join(dir, "ok.mjs"), 'export const id="ok"; export const tiers=["fast"]; export const paths=["a/**"]; export async function run(){return {ok:true}}');
  fs.writeFileSync(path.join(dir, "throws.mjs"), 'throw new Error("load boom");');
  fs.writeFileSync(path.join(dir, "bad.mjs"), 'export const id="bad"; export const tiers="fast";');
  fs.writeFileSync(path.join(dir, "multi.mjs"), 'export const steps=[{id:"m1",tiers:["full"],paths:[],run:async()=>({ok:true})},{id:"m2",tiers:["full"],paths:[],run:async()=>({ok:true})}];');
  const { steps, broken } = await discoverSteps(dir);
  assert.deepEqual(steps.map((s) => s.id).sort(), ["m1", "m2", "ok"]);
  assert.deepEqual(broken.map((b) => b.file).sort(), ["bad.mjs", "throws.mjs"]);
  const { exit, lines } = await gate([], steps, { broken });
  assert.equal(exit, 1);
  assert.ok(lines.some((l) => l.startsWith("FAIL") && l.includes("throws.mjs") && l.includes("load boom")));
  assert.ok(lines.some((l) => l.startsWith("FAIL") && l.includes("bad.mjs")));
  fs.rmSync(dir, { recursive: true });
});

test("history is appended and --trend prints medians", async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tlh_")); const file = path.join(dir, ".tl", "gate-history.jsonl");
  for (let i = 0; i < 3; i++) await gate([], [fake("h", async () => ({ ok: true }))], { historyFile: file });
  const rows = fs.readFileSync(file, "utf8").trim().split("\n").map((l) => JSON.parse(l));
  assert.equal(rows.length, 3); assert.equal(rows[0].steps[0].id, "h"); assert.equal(typeof rows[0].load, "number"); assert.equal(rows[0].tier, "full");
  const t = await gate(["--trend"], [], { historyFile: file });
  assert.equal(t.exit, 0); assert.ok(t.lines.some((l) => l.startsWith("h ") && /\b3\b/.test(l)));
  assert.equal(median([5, 1, 3]), 3); assert.equal(trend([{ steps: [{ id: "q", ms: 100 }] }])[0].median, 100);
  fs.rmSync(dir, { recursive: true });
});

test("hook: install/remove round-trip in a temp repo, refuses a foreign hook", () => {
  const repo = fs.mkdtempSync(path.join(os.tmpdir(), "tlk_"));
  spawnSync("git", ["init", "-q"], { cwd: repo });
  const hook = path.join(repo, ".git", "hooks", "pre-push");
  assert.match(hookAction("status", repo).message, /not installed/);
  assert.ok(hookAction("install", repo).ok);
  assert.equal(fs.readFileSync(hook, "utf8"), HOOK_SCRIPT);
  assert.ok(hookAction("install", repo).ok, "reinstall of our own hook is fine");
  assert.match(hookAction("status", repo).message, /^installed/);
  assert.ok(hookAction("remove", repo).ok); assert.ok(!fs.existsSync(hook));
  fs.writeFileSync(hook, "#!/bin/sh\necho mine\n");
  const i = hookAction("install", repo); assert.equal(i.ok, false); assert.match(i.message, /refusing/);
  const r = hookAction("remove", repo); assert.equal(r.ok, false);
  assert.equal(fs.readFileSync(hook, "utf8"), "#!/bin/sh\necho mine\n");
  assert.match(hookAction("status", repo).message, /foreign/);
  fs.rmSync(repo, { recursive: true, force: true });
});

test("hook script blocks a push on a failing gate (run under sh with a stub tl)", () => {
  const repo = fs.mkdtempSync(path.join(os.tmpdir(), "tlp_"));
  spawnSync("git", ["init", "-q"], { cwd: repo });
  fs.mkdirSync(path.join(repo, "devx", "bin"), { recursive: true });
  const hook = path.join(repo, ".git", "hooks", "pre-push");
  hookAction("install", repo);
  fs.writeFileSync(path.join(repo, "devx", "bin", "tl.mjs"), "console.log(process.argv.slice(2).join(' ')); process.exit(Number(process.env.STUB_EXIT ?? 0));");
  const sh = fs.existsSync("C:/Program Files/Git/bin/sh.exe") ? "C:/Program Files/Git/bin/sh.exe" : "sh";
  const go = (env) => spawnSync(sh, [hook], { cwd: repo, encoding: "utf8", env: { ...process.env, ...env } });
  const ok = go({ STUB_EXIT: "0" }); assert.equal(ok.status, 0); assert.match(ok.stdout, /check --tier fast/);
  assert.equal(go({ STUB_EXIT: "1" }).status, 1);
  assert.match(go({ STUB_EXIT: "0", TL_PUSH_TIER: "full" }).stdout, /check --tier full/);
  fs.rmSync(repo, { recursive: true, force: true });
});
