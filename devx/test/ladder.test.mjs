import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execute, findCells, readRun, interval, parseArgs } from "../lib/commands/ladder.mjs";

function fakePack(tests) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tl_ladder_test_"));
  fs.writeFileSync(path.join(dir, "pack.json"), JSON.stringify({ tests }));
  return dir;
}
const report = (done, b) => JSON.stringify({ schema: "tl.verify/1", ok: done, metrics: { state_hash: "ab".repeat(32) },
  checks: [{ id: "bot.completed", ok: done }], bot: { result: b } });
const fakeCtx = (dir) => ({ REPO: dir, ENGINE: dir, resolveGodot: () => "godot",
  printVerdict: (name, steps, extra) => { const ok = steps.every((s) => s.ok); fakeCtx.last = { name, steps, extra, ok }; return ok ? 0 : 1; } });
async function quiet(fn) { const o = console.log, e = console.error; console.log = () => {}; console.error = () => {}; try { return await fn(); } finally { console.log = o; console.error = e; } }

test("parseArgs: --pack required, numbers checked, inline and spaced forms", () => {
  assert.throws(() => parseArgs([]), /--pack/);
  assert.deepEqual(parseArgs(["--pack", "p", "--seeds=5", "--cells", "a_b,c_d"]), { pack: "p", seeds: 5, cells: ["a_b", "c_d"], par: 6 });
  assert.throws(() => parseArgs(["--pack", "p", "--seeds", "0"]), /seeds/);
});

test("findCells: the bot_ladder_<level>_<hand> tests the manifest names, by file name", () => {
  const dir = fakePack(["tests/bot_hockey.gd", "tests/bot_ladder_pro_regular.gd", "tests/bot_ladder_all_star_sharp.gd"]);
  assert.deepEqual(findCells(dir).map((c) => [c.cell, c.level, c.hand]), [["pro_regular", "pro", "regular"], ["all_star_sharp", "all_star", "sharp"]]);
  assert.deepEqual(findCells(dir, ["pro_regular"]).map((c) => c.cell), ["pro_regular"]);
});

test("readRun and interval", () => {
  assert.equal(readRun("noise\n"), null);
  const r = readRun("x\n" + report(true, { won: true, goals: 3, against: 1, frames: 900, period_reached: 2, passes: 2, passes_reached: 1, down_frames: 9 }));
  assert.equal(r.done, true); assert.equal(r.won, true); assert.equal(r.gf, 3); assert.equal(r.period, 2);
  assert.deepEqual(interval(10, 20), { pct: 50, lo: 28, hi: 72 });
});

test("all cells complete every seed: exit 0, found = completed, wins and interval in the JSON", async () => {
  const dir = fakePack(["tests/bot_ladder_rookie_newcomer.gd", "tests/bot_ladder_pro_regular.gd"]);
  const runBot = async (c, seed) => report(true, { won: c.cell === "rookie_newcomer" || seed === 1, goals: 2, against: 1, frames: 1000 });
  const code = await quiet(() => execute(["--pack", dir, "--seeds", "4"], { ctx: fakeCtx(dir), runBot }));
  assert.equal(code, 0);
  const x = fakeCtx.last.extra;
  assert.equal(x.cells_found, 2); assert.equal(x.cells_completed, 2);
  assert.equal(x.cells.find((c) => c.cell === "rookie_newcomer").wins, 4);
  assert.equal(x.cells.find((c) => c.cell === "pro_regular").wins, 1);
  assert.ok(fakeCtx.last.steps.every((s) => s.found === 4 && s.completed === 4));
});

test("a run that did not finish (or printed no report) is not completed: the cell and the command fail", async () => {
  const dir = fakePack(["tests/bot_ladder_pro_regular.gd"]);
  const runBot = async (c, seed) => (seed === 2 ? "killed\n" : seed === 3 ? report(false, {}) : report(true, { won: false }));
  const code = await quiet(() => execute(["--pack", dir, "--seeds", "3"], { ctx: fakeCtx(dir), runBot }));
  assert.equal(code, 1);
  const st = fakeCtx.last.steps[0];
  assert.equal(st.found, 3); assert.equal(st.completed, 1); assert.match(st.detail, /seeds not completed: 2,3/);
});

test("a pack without ladder tests: found 0 cells is a FAIL", async () => {
  const dir = fakePack(["tests/bot_hockey.gd"]);
  const code = await quiet(() => execute(["--pack", dir], { ctx: fakeCtx(dir), runBot: async () => "" }));
  assert.equal(code, 1);
  assert.match(fakeCtx.last.steps[0].detail, /found 0 cells/);
});
