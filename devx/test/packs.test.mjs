import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { findPacks, unitsOf, verifyLine, gatePacks, run } from "../lib/gate/steps/packs.mjs";

function root(packs) {
  const r = fs.mkdtempSync(path.join(os.tmpdir(), "tl_packs_test_"));
  for (const [name, manifest] of Object.entries(packs)) {
    fs.mkdirSync(path.join(r, name), { recursive: true });
    if (manifest !== undefined) fs.writeFileSync(path.join(r, name, "pack.json"), typeof manifest === "string" ? manifest : JSON.stringify(manifest));
  }
  return r;
}
const line = (ok, extra = {}) => JSON.stringify({ schema: "tl.verify/1", ok, outcome: ok ? "passed" : "failed", frames: 100, metrics: { state_hash: "ab".repeat(32) }, checks: [], ...extra });
const pass = () => ({ code: 0, stdout: "Godot\n" + line(true), stderr: "" });

test("findPacks: every folder with a pack.json, sorted; a folder without one is not a pack", () => {
  const r = root({ b: { tests: [] }, a: { tests: [] }, notes: undefined });
  assert.deepEqual(findPacks([r]).map((p) => path.basename(p)), ["a", "b"]);
  assert.deepEqual(findPacks([path.join(r, "missing")]), []);
});

test("unitsOf: lint, smoke, one bot per test, invariants", () => {
  const r = root({ g: { tests: ["tests/bot_a.gd", "tests/bot_b.gd"] } });
  assert.deepEqual(unitsOf(path.join(r, "g")).map((u) => u.verb), ["lint", "smoke", "bot:bot_a", "bot:bot_b", "invariants"]);
  assert.deepEqual(unitsOf(path.join(r, "g"))[2].args, ["--test=tests/bot_a.gd"]);
});

test("verifyLine: the last tl.verify/1 line wins; none -> null", () => {
  assert.equal(verifyLine(`x\n${line(false)}\n${line(true)}\n`).ok, true);
  assert.equal(verifyLine("no json here\n{broken"), null);
});

test("all verbs pass: found = completed, ok, every bot's hash in the summary, every run kept", () => {
  const r = root({ g: { tests: ["tests/bot_a.gd"] }, h: { tests: [] } });
  const kept = [];
  const res = gatePacks(findPacks([r]), pass, (n) => kept.push(n));
  assert.equal(res.ok, true); assert.equal(res.found, 2); assert.equal(res.completed, 2); assert.equal(res.units, 7); assert.equal(res.done, 7);
  assert.ok(kept.includes("g.bot_bot_a.log") && kept.includes("h.invariants.log"));
  assert.equal(res.summary.find((s) => s.verb === "bot:bot_a").hash, "abababababababab");
});

test("a failing verb fails the step and names the pack and the verb", () => {
  const r = root({ g: { tests: ["tests/bot_a.gd"] } });
  const res = gatePacks(findPacks([r]), (dir, verb) => (verb === "smoke"
    ? { code: 1, stdout: line(false, { checks: [{ id: "smoke.no_script_errors", ok: false, detail: "1 error" }] }), stderr: "" } : pass()));
  assert.equal(res.ok, false); assert.equal(res.found, 1); assert.equal(res.completed, 0);
  assert.deepEqual(res.failures.map((f) => [f.pack, f.verb]), [["g", "smoke"]]);
  assert.match(res.failures[0].why, /smoke.no_script_errors/);
});

test("a stopped run (exit 0 but no verify line, or ok false with exit 0) is never a pass", () => {
  const r = root({ g: { tests: ["tests/bot_a.gd"] } });
  const res = gatePacks(findPacks([r]), (dir, verb, args) => (args[0] === "--test=tests/bot_a.gd" ? { code: 0, stdout: "killed\n", stderr: "" }
    : verb === "lint" ? { code: 0, stdout: line(false), stderr: "" } : pass()));
  assert.equal(res.ok, false); assert.equal(res.done, 2); assert.equal(res.units, 4);
  assert.deepEqual(res.failures.map((f) => f.verb), ["lint", "bot:bot_a"]);
});

test("a manifest that does not parse is a failed unit, not a skipped pack", () => {
  const r = root({ g: "{ not json" });
  const res = gatePacks(findPacks([r]), pass);
  assert.equal(res.ok, false); assert.equal(res.found, 1); assert.equal(res.completed, 0);
  assert.equal(res.failures[0].verb, "manifest");
});

test("the step: zero house games found is a FAIL, not a pass", async () => {
  const r = root({});
  const old = process.env.TL_GATE_PACKS_DIR; process.env.TL_GATE_PACKS_DIR = r;
  try {
    const res = await run({ ENGINE: r, REPO: r, resolveGodot: () => "godot", bash: () => { throw new Error("must not run"); } });
    assert.equal(res.ok, false); assert.match(res.detail, /found 0/);
  } finally { if (old === undefined) delete process.env.TL_GATE_PACKS_DIR; else process.env.TL_GATE_PACKS_DIR = old; }
});

test("the step through a fake ctx: counts and the failing pack and verb in the detail, output kept under .tl/gate-packs", async () => {
  const r = root({ good: { tests: [] }, bad: { tests: ["tests/bot_x.gd"] } });
  const old = process.env.TL_GATE_PACKS_DIR; process.env.TL_GATE_PACKS_DIR = r;
  try {
    const bash = (script, args) => (args[1].endsWith("bad") && args[0] === "bot" ? { code: 1, stdout: line(false, { checks: [{ id: "bot.completed", ok: false, detail: "not done" }] }), stderr: "" } : pass());
    const res = await run({ ENGINE: r, REPO: r, resolveGodot: () => "godot", bash });
    assert.equal(res.ok, false);
    assert.match(res.detail, /found 2, completed 1; verb runs 6 of 7/);
    assert.match(res.detail, /FAILED bad: bot:bot_x;/);
    assert.match(res.detail, /first: bad bot:bot_x: bot.completed: not done/);
    assert.ok(res.detail.indexOf("FAILED") < 300, "the names fit in the 300 characters check.mjs prints");
    assert.ok(fs.existsSync(path.join(r, ".tl", "gate-packs", "bad.bot_bot_x.log")));
  } finally { if (old === undefined) delete process.env.TL_GATE_PACKS_DIR; else process.env.TL_GATE_PACKS_DIR = old; }
});
