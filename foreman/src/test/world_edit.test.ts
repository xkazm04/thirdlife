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
