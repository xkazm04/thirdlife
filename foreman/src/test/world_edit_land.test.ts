// M6 round 3, lane A6 round 4 (27 Nov 2026, Q-A7): the ask's `land_refused` (the ground ops' refused columns, apart
// from the blocks' `refused`): read in the shape of `refused`, said in one prompt line, and a ground op that meets it
// (path, land, paint, plant, flood, pour) fed back, while a block there still passes.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { PKG_ROOT } from "../paths.js";
import { cleanup, tempDir } from "./helpers.js";
import { expand } from "../world_edit_check.js";
import { facts, readAsk } from "../world_edit.js";
after(cleanup);

const rows = Array.from({ length: 41 }, () => Array(41).fill(10));
// the village band: columns x 90..101, z 40..47 (3 m cells i 30..33, j 13..15 partly)
const band = Array.from({ length: 8 }, (_, k) => [40 + k, 90, 101] as [number, number, number]);
const ask = {
  schema: "tl.world-edit-ask/1", sentence: "a little wooden house with a stone path to it", cursor: [110, 10, 60], facing: 0,
  region: { min: [90, 9, 40], max: [130, 40, 80] }, ops: ["place", "remove", "assemble", "land", "paint", "pour", "path", "plant"],
  blocks: [], ground: { min: [90, 40], rows },
  land_refused: [{ reason: "village", runs: band }],
  shapes: [{ id: 1, name: "cube", note: "a full block" }], mats: [{ id: 1, name: "stone", note: "grey stone" }],
  paints: ["grass", "dirt", "stone", "valley"],
  caps: { ops: 4000, blocks_left: 100000 },
};

function worldEdit(input: unknown, replies: unknown[], promptText: string) {
  const root = tempDir("world-edit-land"), file = path.join(root, "ask.json"), out = path.join(root, "answer.json");
  fs.writeFileSync(file, JSON.stringify(input));
  const script = path.join(root, "fake.json");
  fs.writeFileSync(script, JSON.stringify({ model: "builder-opus", steps: replies.map((json, i) => ({
    match: { role: "world_edit", attempt: i + 1, promptIncludes: i ? "Your previous answer was rejected" : promptText }, json, tokensIn: 100, tokensOut: 40,
  })) }));
  const run = spawnSync(process.execPath, [path.join(PKG_ROOT, "dist/cli.js"), "world-edit", "--in", file, "--out", out,
    "--adapter", "fake", "--fake-script", script], { encoding: "utf8" });
  return { code: run.status, error: run.stderr, result: fs.existsSync(out) ? JSON.parse(fs.readFileSync(out, "utf8")) : undefined };
}

test("land_refused: read in refused's shape, said in one prompt line after the blocks' refused columns, absent = no line", () => {
  const root = tempDir("world-edit-land-read"), file = path.join(root, "ask.json");
  fs.writeFileSync(file, JSON.stringify(ask));
  const a = readAsk(file);
  const f = facts(a);
  assert.equal(f.land_refused, "Paths, land, paint, plants and water are refused on these columns (blocks may still go there): village: x 90..101, z 40..47");
  const { land_refused: _, ...without } = ask;
  assert.equal(facts(without as never).land_refused, "");
  const tpl = fs.readFileSync(path.join(PKG_ROOT, "prompts", "world_edit.md"), "utf8");
  assert.ok(tpl.indexOf("{{land_refused}}") > tpl.indexOf("{{refused}}") && tpl.indexOf("{{land_refused}}") < tpl.indexOf("# Blocks already"));
  fs.writeFileSync(file, JSON.stringify({ ...ask, land_refused: [] }));
  assert.throws(() => readAsk(file), /land_refused/, "an empty list is an absent key: omitted, never []");
  fs.writeFileSync(file, JSON.stringify({ ...ask, land_refused: [{ reason: "village", runs: [[40, 90]] }] }));
  assert.throws(() => readAsk(file), /land_refused/);
});

test("land_refused: every ground op that meets it is fed back with the reason and columns; off it, and a block on it, pass", () => {
  const bad: [Record<string, unknown>, RegExp][] = [
    [{ op: "path", id: 1, pts: [[11050, 6050], [9550, 4550]], width_cm: 200, paint: "stone" }, /the path's line at \(9\d, 4\d\) meets ground the Home refuses .*\(village, x 90..101, z 4\d\)/],
    [{ op: "paint", cells: [[31, 14, "valley", "dirt"]] }, /paint \[31, 14\] meets ground/],
    [{ op: "plant", cells: [[33, 15, "valley", "flowers"]] }, /plant \[33, 15\] meets ground/],
    [{ op: "land", verts: [[34, 16, 1100]] }, /land \[34, 16\] meets ground/],
    [{ op: "pour", at: [95, 10, 45] }, /the pour at \[95,10,45\] meets ground/],
  ];
  for (const [o, want] of bad) {
    const r = expand(ask as never, [o as never]);
    assert.equal(r.problems.length, 1, JSON.stringify(o) + JSON.stringify(r.problems));
    assert.match(r.problems[0] as string, want);
  }
  const good = [
    { op: "path", id: 1, pts: [[11050, 6050], [11050, 5050]], width_cm: 200, paint: "stone" },
    { op: "paint", cells: [[35, 17, "valley", "dirt"]] },
    { op: "land", verts: [[36, 18, 1100]] },
    { op: "place", at: [95, 10, 45], shape: 1, mat: 1, rot: 0 },
  ];
  assert.deepEqual(expand(ask as never, good as never).problems, []);
});

test("world-edit: a path through land_refused ground is fed back and the moved path is taken on attempt 2", () => {
  const house = { op: "assemble", kind: "house", at: [112, 10, 62], size: [7, 3, 5], rot: 2, mat: 1, trim: 1 };
  const through = { note: "A house with a stone path.", ops: [house, { op: "path", id: 1, pts: [[10950, 6350], [9500, 4500]], width_cm: 150, paint: "stone" }] };
  const moved = { note: "A house with a stone path.", ops: [house, { op: "path", id: 1, pts: [[10950, 6350], [10950, 5500]], width_cm: 150, paint: "stone" }] };
  const r = worldEdit(ask, [through, moved], "Paths, land, paint, plants and water are refused on these columns");
  assert.equal(r.code, 0, r.error);
  assert.deepEqual(r.result.ops, moved.ops);
  assert.equal(r.result.tokensIn, 200, "two attempts");
});
