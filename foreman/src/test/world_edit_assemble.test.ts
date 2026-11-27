// M6 round 3, lane A6 (27 Nov 2026): `foreman world-edit` and the input op `assemble` (contracts/BUILD.md
// "Assemblies (M6, round 3)"): the ask may offer it, the prompt teaches it (at most 2 KB, one worked example), its shape
// is checked word for word as the exe's assembly.gd `malformed` plus the ask's material table and region, a bad one is
// fed back and the fixed answer taken, and a good one reaches the answer file as written (the exe expands it).
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { PKG_ROOT } from "../paths.js";
import { cleanup, tempDir } from "./helpers.js";
import { expand } from "../world_edit_check.js";
import { facts, ASSEMBLE_TEXT } from "../world_edit.js";
import { footprint } from "../world_edit_assemble.js";
after(cleanup);

const rows = Array.from({ length: 41 }, () => Array(41).fill(10));
const ask = {
  schema: "tl.world-edit-ask/1", sentence: "a small stone tower with stairs", cursor: [110, 10, 60], facing: 0,
  region: { min: [90, 9, 40], max: [130, 40, 80] }, ops: ["place", "remove", "assemble"],
  blocks: [], ground: { min: [90, 40], rows },
  shapes: [{ id: 1, name: "cube", note: "a full block" }, { id: 3, name: "stair", note: "four steps" }],
  mats: [{ id: 1, name: "stone", note: "grey stone" }, { id: 2, name: "stone_dark", note: "dark stone" }, { id: 3, name: "plank", note: "pale planks" }],
  caps: { ops: 4000, blocks_left: 100000 },
};
const tower = { op: "assemble", kind: "tower", at: [100, 10, 50], size: [7, 12, 1], rot: 0, mat: 1, trim: 2, opts: { stairs: "outside", crenels: true } };

function worldEdit(input: unknown, replies: unknown[], promptText: string) {
  const root = tempDir("world-edit-assemble"), file = path.join(root, "ask.json"), out = path.join(root, "answer.json");
  fs.writeFileSync(file, JSON.stringify(input));
  const script = path.join(root, "fake.json");
  fs.writeFileSync(script, JSON.stringify({ model: "builder-opus", steps: replies.map((json, i) => ({
    match: { role: "world_edit", attempt: i + 1, promptIncludes: i ? "Your previous answer was rejected" : promptText }, json, tokensIn: 100, tokensOut: 40,
  })) }));
  const run = spawnSync(process.execPath, [path.join(PKG_ROOT, "dist/cli.js"), "world-edit", "--in", file, "--out", out,
    "--adapter", "fake", "--fake-script", script], { encoding: "utf8" });
  return { code: run.status, error: run.stderr, result: fs.existsSync(out) ? JSON.parse(fs.readFileSync(out, "utf8")) : undefined };
}

test("assemble: the prompt teaches it only when the ask offers it, at most 2 KB, with the preference and one example", () => {
  const f = facts(ask as never);
  assert.ok((f.more_ops as string).includes(ASSEMBLE_TEXT));
  assert.ok(Buffer.byteLength(ASSEMBLE_TEXT) <= 2048, `${Buffer.byteLength(ASSEMBLE_TEXT)} bytes`);
  for (const k of ["PREFER ASSEMBLIES for walls, towers, houses, stairs, bridges and platforms", "single blocks only for",
    '"kind":"tower"', "wall [length, height, 1]", "bridge [width, 1, length]", "platform [width, 1, depth]", "stair [width, steps, 1]"])
    assert.ok(ASSEMBLE_TEXT.includes(k), k);
  assert.equal(facts({ ...ask, ops: ["place", "remove"] } as never).more_ops, "", "an ask without assemble teaches none");
  assert.match(f.ops as string, /assemble/);
});

test("assemble: a good one of every kind passes as written; the footprint turns as the exe's", () => {
  const good = [tower,
    { op: "assemble", kind: "wall", at: [95, 10, 55], size: [9, 4, 1], rot: 1, mat: 3, opts: { door: 4, windows: 3, crenels: true } },
    { op: "assemble", kind: "house", at: [110, 10, 60], size: [7, 4, 5], rot: 2, mat: 3, trim: 2 },
    { op: "assemble", kind: "stair", at: [120, 10, 45], size: [2, 6, 1], rot: 3, mat: 1 },
    { op: "assemble", kind: "bridge", at: [100, 12, 70], size: [3, 1, 9], rot: 0, mat: 1, trim: 3 },
    { op: "assemble", kind: "platform", at: [115, 14, 70], size: [5, 1, 4], rot: 0, mat: 3, trim: 2 }];
  const r = expand(ask as never, good as never);
  assert.deepEqual(r.problems, []);
  assert.deepEqual(r.ops, good);
  assert.deepEqual(footprint(good[1] as never), [95, 47, 95, 55], "rot 1: local +x to world -z");
  assert.deepEqual(footprint({ kind: "stair", at: [0, 0, 0], size: [2, 13, 1], rot: 0 }), [0, 0, 1, 14], "13 steps and 2 landings");
  assert.deepEqual(footprint({ kind: "house", at: [0, 0, 0], size: [7, 4, 5], rot: 3 }), [-4, 0, 0, 6]);
});

test("assemble: every bad form is refused with the exe's words, and the ask's table and region are held", () => {
  const rows: [Record<string, unknown>, RegExp][] = [
    [{ kind: "castle" }, /unknown kind 'castle': one of wall, tower, house, stair, bridge, platform/],
    [{ size: [7, 0, 7] }, /size must be \[w, h, d\] of whole cells, each 1-48 \(tower: \[side, height, unused\]\)/],
    [{ size: [49, 10, 1] }, /size must be/], [{ size: [7, 10] }, /size must be/], [{ rot: 4 }, /rot must be 0..3/],
    [{ mat: 10 }, /mat 10 \(glass\) is only a window's pane/], [{ trim: 9 }, /trim 9 is not in the material table/],
    [{ opts: {} }, /opts is written only when it holds an option/], [{ opts: { crenels: false } }, /opts.crenels is written only when true/],
    [{ opts: { stairs: "spiral" } }, /opts.stairs is "inside" or "outside"/], [{ opts: { roof: true } }, /a tower takes no opt 'roof' \(only door, windows, crenels, stairs\)/],
    [{ opts: { door: 0 } }, /opts.door is the door's cell along the tower's front, 1..5/], [{ opts: { windows: 1 } }, /opts.windows is a window every N cells, N 2..16/],
    [{ size: [3, 10, 1], opts: { stairs: "inside" } }, /at least 5 wide/], [{ size: [7, 3, 1] }, /at least 4 high/],
    [{ kind: "house", opts: { door: 2 } }, /a house takes no opts/], [{ kind: "house", size: [2, 4, 5], opts: undefined }, /at least 3 x 3/],
    [{ kind: "wall", size: [6, 2, 1], opts: { door: 2 } }, /a wall with a door is at least 3 high/],
    [{ colour: "red" }, /assemble takes no "colour"/], [{ at: [100, 10] }, /at must be \[x, y, z\]/],
    [{ at: [140, 10, 50] }, /outside the region/], [{ at: [126, 10, 50] }, /footprint x 126..132, z 50..56 \(turned by rot 0\) leaves the region/],
  ];
  for (const [change, want] of rows) {
    const o: Record<string, unknown> = { ...tower, ...change };
    for (const k of Object.keys(change)) if (change[k] === undefined) delete o[k];
    const r = expand(ask as never, [o as never]);
    assert.equal(r.problems.length, 1, JSON.stringify(change) + " " + JSON.stringify(r.problems));
    assert.match(r.problems[0] as string, want, JSON.stringify(change));
  }
  const old = expand({ ...ask, ops: ["place", "remove"] } as never, [tower as never]);
  assert.match(old.problems[0] as string, /the Home does not take "assemble" yet/);
});

test("world-edit: a bad assemble is fed back and the fixed answer is taken on attempt 2; the answer keeps the assemble", () => {
  const bad = { note: "A tower.", ops: [{ ...tower, kind: "keep" }] };
  const good = { note: "A stone tower with stairs round it.", ops: [tower, { op: "place", at: [96, 10, 50], shape: 1, mat: 1, rot: 0 }] };
  const r = worldEdit(ask, [bad, good], "PREFER ASSEMBLIES");
  assert.equal(r.code, 0, r.error);
  assert.deepEqual(r.result.ops, good.ops);
  assert.equal(r.result.tokensIn, 200, "two attempts");
  const r2 = worldEdit(ask, [bad, bad], "PREFER ASSEMBLIES");
  assert.equal(r2.code, 1);
  assert.match(r2.result.error, /unknown kind 'keep'/);
});
