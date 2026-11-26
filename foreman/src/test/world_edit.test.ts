// M4 (spark world-sandbox): `foreman world-edit` with the fake adapter: the answer file, the checks fed back, the
// expansion of boxes into the contract's ops, and the refusals (contracts/BUILD.md "The LLM command bar").
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { PKG_ROOT } from "../paths.js";
import { cleanup, tempDir } from "./helpers.js";
import { expand } from "../world_edit_check.js";
import { facts } from "../world_edit.js";
after(cleanup);

const rows = Array.from({ length: 4 }, () => [10, 10, 10, 10]);
const ask = {
  schema: "tl.world-edit-ask/1", sentence: "a little stone tower here", cursor: [100, 10, 50], facing: 0,
  region: { min: [99, 9, 49], max: [102, 20, 52] }, ops: ["place", "remove"],
  blocks: [[100, 10, 50, 1, 3, 0, 0]],
  ground: { min: [99, 49], rows },
  refused: [{ reason: "game lot", runs: [[52, 99, 102]] }],
  shapes: [{ id: 1, name: "cube", note: "a full block" }, { id: 7, name: "roof", note: "a 45-degree roof" }],
  mats: [{ id: 1, name: "stone", note: "grey stone" }, { id: 3, name: "plank", note: "pale planks" }],
  caps: { ops: 4000, blocks_left: 1000 },
};
type Reply = unknown;
function worldEdit(input: unknown, replies: Reply[], promptText = "a little stone tower here", extra: Record<string, unknown>[] = []) {
  const root = tempDir("world-edit"), file = path.join(root, "ask.json"), out = path.join(root, "answer.json");
  fs.writeFileSync(file, JSON.stringify(input));
  const script = path.join(root, "fake.json");
  fs.writeFileSync(script, JSON.stringify({ model: "builder-opus", steps: replies.map((json, i) => ({
    match: { role: "world_edit", attempt: i + 1, promptIncludes: i ? "Your previous answer was rejected" : promptText },
    json, tokensIn: 100, tokensOut: 40, ...(extra[i] ?? {}),
  })) }));
  const run = spawnSync(process.execPath, [path.join(PKG_ROOT, "dist/cli.js"), "world-edit", "--in", file, "--out", out,
    "--adapter", "fake", "--fake-script", script], { encoding: "utf8" });
  return { code: run.status, error: run.stderr, result: fs.existsSync(out) ? JSON.parse(fs.readFileSync(out, "utf8")) : undefined };
}
const good = { note: "A small stone tower on the plank block.", ops: [
  { op: "fill", from: [101, 10, 49], to: [101, 12, 49], shape: 1, mat: 1, rot: 0 },
  { op: "place", at: [101, 13, 49], shape: 7, mat: 1, rot: 2 },
  { op: "remove", at: [100, 10, 50] },
] };

test("world-edit writes the expanded ops, the note and the call's usage", () => {
  const r = worldEdit(ask, [good], "100,10,50 cube(1) plank(3) rot 0");
  assert.equal(r.code, 0, r.error);
  assert.deepEqual(Object.keys(r.result), ["schema", "ops", "note", "model", "durationMs", "tokensIn", "tokensOut"]);
  assert.equal(r.result.schema, "tl.world-edit/1");
  assert.deepEqual(r.result.ops, [
    { op: "place", at: [101, 10, 49], shape: 1, mat: 1, rot: 0 }, { op: "place", at: [101, 11, 49], shape: 1, mat: 1, rot: 0 },
    { op: "place", at: [101, 12, 49], shape: 1, mat: 1, rot: 0 }, { op: "place", at: [101, 13, 49], shape: 7, mat: 1, rot: 2 },
    { op: "remove", at: [100, 10, 50], shape: 1, mat: 3, rot: 0 }]);
  assert.deepEqual([r.result.note, r.result.model, r.result.tokensIn, r.result.tokensOut], [good.note, "builder-opus", 100, 40]);
  assert.ok(r.result.durationMs >= 0);
});

test("world-edit feeds an op outside the region back and takes the fixed answer on attempt 2", () => {
  const outside = { ...good, ops: [{ op: "place", at: [140, 10, 49], shape: 1, mat: 1, rot: 0 }, ...good.ops] };
  const r = worldEdit(ask, [outside, good]);
  assert.equal(r.code, 0, r.error);
  assert.equal(r.result.ops.length, 5);
  assert.equal(r.result.tokensIn, 200);
});

test("world-edit feeds back unknown keys, unknown ids, a place on a held cell and glass, and fails after 2 attempts", () => {
  const bad = { note: "x", ops: [{ op: "place", at: [101, 10, 49], shape: 1, mat: 1, rot: 0, colour: "red" }] };
  const ids = { note: "x", ops: [{ op: "place", at: [101, 10, 49], shape: 9, mat: 1, rot: 0 }, { op: "place", at: [100, 10, 50], shape: 1, mat: 1, rot: 0 },
    { op: "place", at: [101, 11, 49], shape: 6, mat: 10, rot: 0 }] };
  const r = worldEdit(ask, [bad, ids]);
  assert.equal(r.code, 1);
  assert.deepEqual(Object.keys(r.result), ["schema", "error"]);
  assert.match(r.result.error, /after 2 attempts/);
  assert.match(r.result.error, /unknown shape 9/);
  assert.match(r.result.error, /already holds a block/);
  assert.match(r.result.error, /glass/);
});

test("world-edit refuses an ask with an unknown key before any call", () => {
  const r = worldEdit({ ...ask, mystery: 1 }, []);
  assert.equal(r.code, 2);
  assert.match(r.error, /--in.*mystery/);
  assert.equal(r.result, undefined);
});

test("world-edit refuses an answer that expands past 4000 ops", () => {
  const big = { ...ask, region: { min: [0, 0, 0], max: [40, 30, 40] }, ground: { min: [0, 0], rows: Array.from({ length: 41 }, () => Array(41).fill(1)) }, blocks: [] };
  const many = { note: "a big block", ops: [{ op: "fill", from: [0, 0, 0], to: [20, 20, 20], shape: 1, mat: 1, rot: 0 }] };
  const r = worldEdit(big, [many, many]);
  assert.equal(r.code, 1);
  assert.match(r.result.error, /expands to 9261 operations; at most 4000/);
});

test("world-edit writes the model's error as the answer", () => {
  const r = worldEdit(ask, [{}], undefined, [{ outcome: "error", error: { kind: "exit", message: "the model is not reachable" } }]);
  assert.equal(r.code, 1);
  assert.deepEqual(Object.keys(r.result), ["schema", "error"]);
  assert.match(r.result.error, /not reachable/);
});

test("expand: fill replaces another block and keeps the same one, walls fill the ring, clear removes what is there", () => {
  const a = { ...ask, blocks: [[100, 10, 50, 1, 3, 0, 0], [101, 10, 50, 1, 1, 0, 0]] } as never;
  const r = expand(a, [{ op: "fill", from: [100, 10, 50], to: [101, 10, 50], shape: 1, mat: 1, rot: 0 }]);
  assert.deepEqual(r.problems, []);
  assert.deepEqual(r.ops.map((o) => o.op), ["remove", "place"]);
  const w = expand(a, [{ op: "fill", from: [99, 11, 49], to: [101, 11, 51], shape: 1, mat: 1, rot: 0, walls: true }, { op: "clear", from: [99, 10, 49], to: [102, 10, 52] }]);
  assert.deepEqual([w.placed, w.removed], [8, 2]);
  assert.match(expand(a, [{ op: "remove", at: [99, 10, 49] }]).problems[0] as string, /empty/);
  assert.match(expand(a, [{ op: "put", at: [100, 10, 50], part: "crate", rot: 0 }]).problems[0] as string, /does not take "put" yet/);
});

test("expand: the M5 ops pass through with shape checks once the ask offers them (pour only with at)", () => {
  const m5 = { ...ask, ops: ["place", "remove", "pour", "drain", "path", "unpath", "plant"],
    water: [{ y: 9, runs: [[50, 99, 101]] }] } as never;
  const good = [
    { op: "pour", at: [100, 10, 50] },
    { op: "drain", cells: [[33, 17, 950]] },
    { op: "path", id: 3, pts: [[9950, 4950], [10150, 5050]], width_cm: 300, paint: "dirt" },
    { op: "plant", cells: [[33, 17, "valley", "meadow"]] }];
  const r = expand(m5, good);
  assert.deepEqual(r.problems, []);
  assert.deepEqual(r.ops, good);
  const bad = expand(m5, [
    { op: "pour", at: [100, 10, 50], cells: [[33, 17, 950]] },
    { op: "drain", cells: [[33, 17, "high"]] },
    { op: "path", id: 0, pts: [[9950, 4950], [10150, 5050]], width_cm: 300, paint: "dirt" },
    { op: "unpath", id: 3, pts: [[9950, 4950], [20000, 5050]], width_cm: 300, paint: "dirt" },
    { op: "plant", cells: [[33, 17, "meadow"]] },
    { op: "flood", cells: [[33, 17, 950]] }]);
  assert.deepEqual(bad.problems.map((p) => p.replace(/^ops\[\d+\] \((\w+)\): /, "$1: ")), [
    'pour: pour takes no "cells"', "drain: a drain cell is [i, j, level_cm] of integers", "path: id must be a positive integer",
    "unpath: the point [20000, 5050] (world 200, 50.5) is outside the region", 'plant: a plant cell is [i, j, "<from>", "<to>"]',
    'flood: the Home does not take "flood" yet: use only place, remove, pour, drain, path, unpath, plant, fill, clear']);
});

test("world-edit reads an ask with the water key and the M5 op names, and refuses a malformed water key", () => {
  const m5 = { ...ask, ops: ["place", "remove", "flood", "pour", "drain", "path", "unpath", "plant"], water: [{ y: 9, runs: [[50, 99, 101]] }] };
  const ok = worldEdit(m5, [{ note: "A pond.", ops: [{ op: "pour", at: [100, 10, 50] }] }]);
  assert.equal(ok.code, 0, ok.error);
  assert.deepEqual(ok.result.ops, [{ op: "pour", at: [100, 10, 50] }]);
  const bad = worldEdit({ ...m5, water: [{ y: 9, runs: [[50, 99]] }] }, []);
  assert.equal(bad.code, 2);
  assert.match(bad.error, /--in.*water/);
});

// M5 (lane C): the water fact, the M5 ops taught and checked, the ask's unlocked tables held, each fed back and fixed.
function worldEditSteps(input: unknown, steps: { json: unknown; includes: string }[]) {
  const root = tempDir("world-edit-m5"), file = path.join(root, "ask.json"), out = path.join(root, "answer.json");
  fs.writeFileSync(file, JSON.stringify(input));
  const script = path.join(root, "fake.json");
  fs.writeFileSync(script, JSON.stringify({ model: "builder-opus", steps: steps.map((s, i) => ({
    match: { role: "world_edit", attempt: i + 1, promptIncludes: s.includes }, json: s.json, tokensIn: 100, tokensOut: 40 })) }));
  const run = spawnSync(process.execPath, [path.join(PKG_ROOT, "dist/cli.js"), "world-edit", "--in", file, "--out", out,
    "--adapter", "fake", "--fake-script", script], { encoding: "utf8" });
  return { code: run.status, error: run.stderr, result: fs.existsSync(out) ? JSON.parse(fs.readFileSync(out, "utf8")) : undefined };
}
const m5ask = { ...ask, region: { min: [96, 6, 46], max: [127, 29, 77] },
  ground: { min: [96, 46], rows: Array.from({ length: 32 }, () => Array(32).fill(10)) },
  ops: ["place", "remove", "land", "paint", "put", "lift", "pour", "drain", "path", "unpath", "plant"],
  mats: [{ id: 1, name: "stone", note: "grey stone" }, { id: 9, name: "white", note: "white trim" }],
  paints: ["grass", "dirt", "valley"], parts: [{ kind: "tree", note: "a tree" }, { kind: "bench", note: "a bench" }],
  water: [{ y: 9, runs: [[50, 103, 107], [51, 103, 107], [52, 104, 108]] }, { y: 12, runs: [[60, 120, 121]] }] };

test("world-edit M5: the prompt carries the measured water and teaches pour, drain, path, unpath and plant with a pond, a path and a bridge", () => {
  const f = facts(m5ask as never);
  assert.equal(f.water, "surface in cell y 9 (a block at y 9 or lower in these columns stands in the water): x 103..107, z 50..51; x 104..108, z 52\n" +
    "surface in cell y 12 (a block at y 12 or lower in these columns stands in the water): x 120..121, z 60");
  for (const k of ['{"op":"pour"', '{"op":"drain"', '{"op":"path"', '{"op":"unpath"', '{"op":"plant"', "A pond", "A dirt path"]) assert.ok(f.more_ops?.includes(k), k);
  assert.equal(facts(ask as never).water, "none in the region");
  assert.ok(!(facts(ask as never).more_ops ?? "").includes("pour"));
  const r = worldEditSteps(m5ask, [{ includes: "x 103..107, z 50..51", json: { note: "A pond.", ops: [{ op: "pour", at: [100, 10, 50] }] } }]);
  assert.equal(r.code, 0, r.error);
  const prompt = fs.readFileSync(path.join(PKG_ROOT, "prompts", "world_edit.md"), "utf8");
  for (const k of ["# Water (measured)", "1 cell above the higher bank's ground y", "A stone bridge with railings", "White (9) is a trim", "open"]) assert.ok(prompt.includes(k), k);
});

test("world-edit M5: each new op's bad form is fed back and the fixed answer taken on attempt 2", () => {
  const cases: [Record<string, unknown>, Record<string, unknown>, string][] = [
    [{ op: "pour", at: [200, 10, 50] }, { op: "pour", at: [105, 8, 51] }, "is outside the region"],
    [{ op: "drain", cells: [[34, 17]] }, { op: "drain", cells: [[34, 17, 950]] }, "a drain cell is [i, j, level_cm]"],
    [{ op: "path", id: 2, pts: [[9800, 5000], [9850, 5000]], width_cm: 250, paint: "dirt" }, { op: "path", id: 2, pts: [[9800, 5000], [11000, 5000]], width_cm: 250, paint: "dirt" }, "50 cm apart"],
    [{ op: "path", id: 2, pts: [[9800, 5000], [11000, 5000]], width_cm: 100, paint: "dirt" }, { op: "path", id: 2, pts: [[9800, 5000], [11000, 5000]], width_cm: 150, paint: "dirt" }, "width_cm 100 is outside 150-800"],
    [{ op: "path", id: 2, pts: [[9800, 5000], [11000, 5000]], width_cm: 300, paint: "lava" }, { op: "path", id: 2, pts: [[9800, 5000], [11000, 5000]], width_cm: 300, paint: "plank" }, "paint must be a path paint"],
    [{ op: "unpath", id: 2, pts: [[9800, 5000]], width_cm: 300, paint: "dirt" }, { op: "unpath", id: 2, pts: [[9800, 5000], [11000, 5000]], width_cm: 300, paint: "dirt" }, "pts must hold 2 to 64 points"],
    [{ op: "plant", cells: [[34, 17, "valley", "roses"]] }, { op: "plant", cells: [[34, 17, "valley", "flowers"]] }, "a plant cell's growths are meadow, flowers, tall_grass, valley"],
    [{ op: "paint", cells: [[34, 17, "valley", "sand"]] }, { op: "paint", cells: [[34, 17, "valley", "dirt"]] }, "with paints from the table (grass, dirt, valley)"],
  ];
  for (const [bad, fixed, why] of cases) {
    const r = worldEditSteps(m5ask, [{ includes: "Water (measured)", json: { note: "x", ops: [bad] } }, { includes: why, json: { note: "Fixed.", ops: [fixed] } }]);
    assert.equal(r.code, 0, `${bad.op}: ${r.error} ${JSON.stringify(r.result)}`);
    assert.deepEqual(r.result.ops, [fixed]);
    assert.equal(r.result.tokensIn, 200);
  }
});

test("world-edit M5: a mat or part not in the ask's tables (locked) is refused, and the answer fixed on attempt 2 is taken", () => {
  const brick = { note: "A brick wall.", ops: [{ op: "fill", from: [100, 10, 50], to: [103, 11, 50], shape: 1, mat: 11, rot: 0 }] };
  const stone = { note: "A stone wall.", ops: [{ op: "fill", from: [100, 10, 50], to: [103, 11, 50], shape: 1, mat: 1, rot: 0 }] };
  const r = worldEditSteps(m5ask, [{ includes: "9 white: white trim", json: brick }, { includes: "mat 11 is not in the material table (unknown, or not unlocked yet): use one of 1, 9", json: stone }]);
  assert.equal(r.code, 0, r.error);
  assert.deepEqual(r.result.ops.map((o: { op: string; mat: number }) => `${o.op} ${o.mat}`), ["remove 3", ...Array(8).fill("place 1")]);
  const house = { note: "A house.", ops: [{ op: "put", at: [110, 10, 60], part: "house", rot: 0 }] };
  const tree = { note: "A tree.", ops: [{ op: "put", at: [110, 10, 60], part: "tree", rot: 0 }] };
  const p = worldEditSteps(m5ask, [{ includes: "bench: a bench", json: house }, { includes: 'the part "house" is not in the parts table', json: tree }]);
  assert.equal(p.code, 0, p.error);
  assert.deepEqual(p.result.ops, tree.ops);
  const twice = worldEditSteps(m5ask, [{ includes: "Kit parts", json: house }, { includes: "not unlocked yet", json: house }]);
  assert.equal(twice.code, 1);
  assert.match(twice.result.error, /after 2 attempts.*"house" is not in the parts table/);
});
