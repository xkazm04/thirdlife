// K7: the gate step "world" (a house game in a world plays as it does alone), with a fake runner: the verdict over the
// output of `world.sh alone` for the three paths (all same; one different; fewer rows than games) and the honesty edges.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { parseAlone, judgeWorld, readGames, run, paths, tiers } from "../lib/gate/steps/world.mjs";

const HEAD = "pack | mode | own ticks | hash in the world | runner alone (tl.sh bot), same ticks | verdict";
const row = (pack, ticks, w, a, verdict = w === a ? "same" : "DIFFERENT") => `${pack} | bot | ${ticks} | ${w} | ${a} (${ticks} frames) | ${verdict}`;
const out = (rows, trailer) => [HEAD, ...rows, trailer].filter(Boolean).join("\n");
const three = [row("seed.drive", 3517, "b912bc471e4967a9", "b912bc471e4967a9"), row("seed.wall", 1221, "cb75fb26a1e80254", "cb75fb26a1e80254"),
  row("game.ice_hockey_three_against", 1591, "7773cb3fece6b9f8", "7773cb3fece6b9f8")];

test("all same: found = completed = games, PASS, the hashes named", () => {
  const v = judgeWorld({ code: 0, stdout: out(three, "PASS world.alone: every pack hashes in the world as the runner hashes it alone"), stderr: "" }, 3);
  assert.equal(v.ok, true); assert.equal(v.found, 3); assert.equal(v.completed, 3);
  assert.match(v.detail, /game\.ice_hockey_three_against 7773cb3fece6b9f8@1591/);
});

test("one game differs: FAIL, the game named with both hashes", () => {
  const rows = [three[0], three[1], row("game.ice_hockey_three_against", 6722, "d46dac9e05aeca95", "7773cb3fece6b9f8")];
  const v = judgeWorld({ code: 1, stdout: out(rows, "FAIL world.alone"), stderr: "" }, 3);
  assert.equal(v.ok, false); assert.equal(v.found, 3); assert.equal(v.completed, 2);
  assert.match(v.detail, /game\.ice_hockey_three_against differs: 6722 own ticks, world d46dac9e05aeca95, alone 7773cb3fece6b9f8/);
});

test("fewer rows than games: FAIL, never a pass, even with the tool's own PASS line and exit 0", () => {
  const v = judgeWorld({ code: 0, stdout: out(three.slice(0, 2), "PASS world.alone: every pack hashes in the world as the runner hashes it alone"), stderr: "" }, 3);
  assert.equal(v.ok, false); assert.equal(v.found, 3); assert.equal(v.completed, 2);
  assert.match(v.detail, /printed 2 rows for 3 games/);
});

test("a run without its trailer line (stopped) is a FAIL; our timeout is a FAIL; a kill from outside is could not run", () => {
  const cut = judgeWorld({ code: 1, stdout: out(three, ""), stderr: "" }, 3);
  assert.equal(cut.ok, false); assert.match(cut.detail, /stopped before its trailer line/);
  const late = judgeWorld({ code: 1, stdout: out(three.slice(0, 1), ""), stderr: "", timedOut: true, signal: "SIGTERM" }, 3);
  assert.equal(late.ok, false); assert.notEqual(late.notRun, true); assert.match(late.detail, /timed out/);
  const killed = judgeWorld({ code: 1, stdout: out(three.slice(0, 1), ""), stderr: "", signal: "SIGKILL" }, 3);
  assert.equal(killed.ok, false); assert.equal(killed.notRun, true);
});

test("parseAlone reads the table and the trailer; a row without the runner's hash still counts as a row (not same)", () => {
  const p = parseAlone(out([row("x.y", 10, "aa", "")], "FAIL world.alone"));
  assert.equal(p.rows.length, 1); assert.equal(p.rows[0].verdict, "DIFFERENT"); assert.equal(p.trailer, "FAIL");
});

test("readGames: the exe's games; a missing game that is not optional is an error; the step is full tier and claims the engine", () => {
  const r = fs.mkdtempSync(path.join(os.tmpdir(), "tl_world_test_"));
  fs.mkdirSync(path.join(r, "engine", "boot"), { recursive: true });
  fs.mkdirSync(path.join(r, "g1"), { recursive: true });
  fs.writeFileSync(path.join(r, "g1", "pack.json"), "{}");
  const write = (games) => fs.writeFileSync(path.join(r, "engine", "boot", "games.json"), JSON.stringify({ games }));
  write([{ name: "a", from: "g1" }, { name: "b", from: "gone", optional: true }]);
  assert.deepEqual(readGames(r).games.map((g) => g.name), ["a"]);
  write([{ name: "a", from: "g1" }, { name: "c", from: "gone" }]);
  assert.match(readGames(r).error, /c \(gone\)/);
  assert.deepEqual(tiers, ["full"]);
  for (const p of ["engine/kernel/**", "engine/packs/**", "engine/seeds/**", "engine/kits/**", "engine/rigs/**"]) assert.ok(paths.includes(p), p);
});

test("run: no Godot is could not run; no games is a FAIL (found 0)", async () => {
  const r = fs.mkdtempSync(path.join(os.tmpdir(), "tl_world_test_"));
  fs.mkdirSync(path.join(r, "engine", "boot"), { recursive: true });
  fs.mkdirSync(path.join(r, "g1"), { recursive: true });
  fs.writeFileSync(path.join(r, "g1", "pack.json"), "{}");
  fs.writeFileSync(path.join(r, "engine", "boot", "games.json"), JSON.stringify({ games: [{ name: "a", from: "g1" }] }));
  const ng = await run({ REPO: r, ENGINE: path.join(r, "engine"), resolveGodot: () => null });
  assert.equal(ng.ok, false); assert.equal(ng.notRun, true);
  fs.writeFileSync(path.join(r, "engine", "boot", "games.json"), JSON.stringify({ games: [] }));
  const none = await run({ REPO: r, ENGINE: path.join(r, "engine"), resolveGodot: () => "godot" });
  assert.equal(none.ok, false); assert.equal(none.found, 0);
});
