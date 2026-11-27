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

test("expand: the M6 ops pass through with shape checks once the ask offers them; the ask takes zones, rules and rules_room", () => {
  const m6 = { ...ask, ops: ["place", "remove", "zone", "unzone", "rule", "unrule"],
    zones: [{ id: 1, box: [[100, 10, 50], [101, 10, 51]], look: "pad" }], rules: [],
    rules_room: { zones_left: 511, rules_left: 512, counters: [] } } as never;
  const good = [
    { op: "zone", id: 1, box: [[100, 10, 50], [102, 12, 51]], look: "coin", name: "Coin" },      // M6 lane C: z 52 is the fixture's game lot
    { op: "rule", id: 1, when: { on: "enter", zone: 1 }, do: [{ do: "take", zone: 1 }, { do: "add", counter: "coins", by: 1 }] }];
  const r = expand(m6, good);
  assert.deepEqual(r.problems, []);
  assert.deepEqual(r.ops, good);
  const bad = expand(m6, [
    { op: "zone", id: 0, box: [[100, 10, 50], [102, 12, 52]], look: "pad" },
    { op: "zone", id: 2, box: [[100, 10, 50]], look: "pad" },
    { op: "rule", id: 2, when: { on: "enter", zone: 1 }, do: [] },
    { op: "rule", id: 3, do: [{ do: "finish" }] }]);
  assert.deepEqual(bad.problems.map((p) => p.replace(/^ops\[\d+\] \((\w+)\): /, "$1: ")), [
    "zone: id must be a positive integer", "zone: box must be [[x0, y0, z0], [x1, y1, z1]] of integers",
    "rule: do must be a non-empty list of effects", 'rule: when must be one trigger {"on": ...}']);
  const ok = worldEdit(m6 as never, [{ note: "A coin.", ops: good }]);
  assert.equal(ok.code, 0, ok.error);
});

// M6 (lane C): zones and rules taught in the prompt, checked with every limit and refusal of the contract, fed back.
const m6ask = { ...m5ask, ops: ["place", "remove", "zone", "unzone", "rule", "unrule"],
  zones: [{ id: 3, box: [[110, 10, 60], [111, 11, 61]], look: "none", name: "Gate" }, { id: 4, box: [[112, 10, 60], [113, 10, 61]], look: "pad" }],
  rules: [{ id: 7, when: { on: "use", zone: 4 }, do: [{ do: "toggle", zone: 3 }] }],
  rules_room: { zones_left: 510, rules_left: 511, counters: [] } };
const course = { note: "A stone step course, the run Hop.", ops: [
  { op: "fill", from: [100, 10, 49], to: [101, 10, 49], shape: 1, mat: 1, rot: 0 },
  { op: "zone", id: 1, box: [[100, 10, 50], [101, 10, 51]], look: "pad", name: "Start" },
  { op: "zone", id: 2, box: [[101, 11, 49], [101, 12, 49]], look: "coin" },
  { op: "zone", id: 3, box: [[100, 11, 49], [100, 11, 49]], look: "flag", name: "Finish" },
  { op: "rule", id: 1, when: { on: "enter", zone: 1 }, do: [{ do: "start", run: "Hop" }, { do: "say", text: "Go!", frames: 60 }] },
  { op: "rule", id: 2, when: { on: "enter", zone: 2 }, if: [{ running: true }], do: [{ do: "take", zone: 2 }, { do: "add", counter: "coins", by: 1 }] },
  { op: "rule", id: 3, when: { on: "enter", zone: 3 }, if: [{ running: true }, { counter: "coins", min: 1 }], do: [{ do: "finish" }] },
  { op: "rule", id: 4, when: { on: "use", zone: 4 }, do: [{ do: "say", text: "The gate", frames: 90 }] }] };
const m6problems = (a: unknown, ops: unknown[]) => expand(a as never, ops as never).problems.map((p) => p.replace(/^ops\[\d+\] \((\w+)\): /, "$1: "));

test("world-edit M6: the prompt teaches zones and rules with the measured zones, rules and room; a course answer passes whole", () => {
  const f = facts(m6ask as never);
  for (const k of ['{"op":"zone"', '{"op":"rule"', "A door that opens and closes on E", "A short run", '"look":"pad"', "Name the run in the note",
    'Zones in the region now: \n{"id":3,"box":[[110,10,60],[111,11,61]],"look":"none","name":"Gate"}', '{"id":7,"when":{"on":"use","zone":4}',
    "510 more zones, 511 more rules; counters in use: none"]) assert.ok((f.rules as string).includes(k), k);
  assert.equal(facts(m5ask as never).rules, "", "no zone op offered: no rules section");
  const grown = (facts({ ...m6ask, zones: [], rules: [] } as never).rules as string).length;
  assert.ok(grown <= 4096 - 64, `the rules section is ${grown} bytes on a Home with no zones (the prompt grows at most 4 KB in all)`);
  const r = worldEditSteps(m6ask, [{ includes: "# Zones and rules", json: course }]);
  assert.equal(r.code, 0, r.error);
  assert.deepEqual(r.result.ops.slice(2), course.ops.slice(1));
  assert.deepEqual(r.result.ops.slice(0, 2).map((o: { op: string }) => o.op), ["place", "place"]);
});

test("world-edit M6: each op's bad form is fed back and the fixed answer taken on attempt 2 (zone, unzone, rule, unrule)", () => {
  const gate = { op: "unrule", id: 7, when: { on: "use", zone: 4 }, do: [{ do: "toggle", zone: 3 }] };
  const cases: [unknown[], unknown[], string][] = [
    [[{ op: "zone", id: 1, box: [[100, 10, 50], [100, 10, 90]], look: "pad" }], [{ op: "zone", id: 1, box: [[100, 10, 50], [100, 10, 51]], look: "pad" }], "leaves the region"],
    [[gate, { op: "unzone", id: 3, box: [[110, 10, 60], [111, 11, 61]], look: "none" }], [gate, { op: "unzone", ...m6ask.zones[0] }], "unzone carries the whole zone as listed"],
    [[{ op: "unzone", ...m6ask.zones[1] }], [gate, { op: "unzone", ...m6ask.zones[1] }], "is named by rule 7: remove (unrule) that rule first"],
    [[{ op: "rule", id: 1, when: { on: "enter", zone: 9 }, do: [{ do: "finish" }] }], [{ op: "rule", id: 1, when: { on: "enter", zone: 4 }, do: [{ do: "finish" }] }], "zone 9 is neither made by this answer nor listed"],
    [[{ ...gate, do: [{ do: "open", zone: 3 }] }], [gate], "unrule carries the whole rule as listed"],
  ];
  for (const [bad, fixed, why] of cases) {
    const r = worldEditSteps(m6ask, [{ includes: "# Zones and rules", json: { note: "x", ops: bad } }, { includes: why, json: { note: "Fixed.", ops: fixed } }]);
    assert.equal(r.code, 0, `${why}: ${r.error} ${JSON.stringify(r.result)}`);
    assert.deepEqual(r.result.ops, fixed);
  }
});

test("expand M6: every limit of a zone and a rule is held, with the contract's words", () => {
  const z = (o: Record<string, unknown>) => ({ op: "zone", id: 1, box: [[100, 10, 50], [101, 10, 51]], look: "pad", ...o });
  const rule = (o: Record<string, unknown>) => ({ op: "rule", id: 1, when: { on: "enter", zone: 3 }, do: [{ do: "finish" }], ...o });
  const big = { ...m6ask, region: { min: [0, 0, 0], max: [99, 40, 99] }, ground: { min: [0, 0], rows: Array.from({ length: 100 }, () => Array(100).fill(10)) }, blocks: [] };
  const tight = { ...m6ask, rules_room: { zones_left: 1, rules_left: 0, counters: [] } };
  const rows: [unknown, unknown[], string][] = [
    [m6ask, [z({ box: [[101, 10, 50], [100, 10, 51]] })], "zone: box: the low corner comes first (x0 <= x1, y0 <= y1, z0 <= z1)"],
    [big, [z({ box: [[0, 10, 0], [64, 10, 1]] })], "zone: box: at most 64 cells a side (65 x 1 x 2)"],
    [m6ask, [z({ look: "spring" })], "zone: look must be one of none, pad, coin, flag"],
    [m6ask, [z({ name: "x".repeat(25) })], "zone: name must be 1-24 printable characters"],
    [m6ask, [z({ name: "a\u0007b" })], "zone: name must be 1-24 printable characters"],
    [m6ask, [z({}), z({})], "zone: the answer makes zone 1 twice: give each new zone its own id"],
    [tight, [z({}), z({ id: 2 })], "zone: the Home has room for 1 more zones"],
    [tight, [rule({})], "rule: the Home has room for 0 more rules"],
    [m6ask, [rule({ when: { on: "enter", zone: 1 } }), z({})], "rule: when: zone 1 is made later in this answer: put the zone op before the rules that name it"],
    [m6ask, [z({ look: "spring" }), rule({ when: { on: "enter", zone: 1 } })], "zone: look must be one of none, pad, coin, flag"],
    [m6ask, [rule({ when: { on: "jump", zone: 3 } })], "rule: when: on must be one of enter, leave, use, every, count, start, finish"],
    [m6ask, [rule({ when: { on: "enter" } })], 'rule: when: "enter" needs zone'],
    [m6ask, [rule({ when: { on: "start", zone: 3 } })], 'rule: when: "start" takes no "zone" (it takes nothing else)'],
    [m6ask, [rule({ when: { on: "every", frames: 30 } })], "rule: when: every's frames must be an integer 60..36000 (60 frames are 1 s)"],
    [m6ask, [rule({ when: { on: "count", counter: "coins", at: 0 } })], "rule: when: at must be an integer 1..999"],
    [m6ask, [rule({ when: { on: "count", counter: "Coins", at: 3 } })], "rule: when: counter must be 1-16 of a-z and _"],
    [m6ask, [rule({ if: [] })], "rule: if must be a non-empty list (leave it out when there are no conditions)"],
    [m6ask, [rule({ if: [{ running: true, counter: "a" }] })], 'rule: if: {"running": true|false} stands alone'],
    [m6ask, [rule({ if: [{ counter: "coins" }] })], "rule: if: counter coins needs min or max"],
    [m6ask, [rule({ if: [{ counter: "coins", min: 5, max: 2 }] })], "rule: if: min is above max (it never holds)"],
    [m6ask, [rule({ if: Array(9).fill({ running: true }) })], "rule: if: at most 8 conditions"],
    [m6ask, [rule({ do: Array(9).fill({ do: "finish" }) })], "rule: do must be 1-8 effects"],
    [m6ask, [rule({ do: [{ do: "explode" }] })], 'rule: do[0]: "explode" is not an effect (start, checkpoint, finish, respawn, add, take, open, close, toggle, launch, teleport, say)'],
    [m6ask, [rule({ do: [{ do: "launch", up_cm: 4000, fwd_cm: 0 }] })], "rule: do[0] launch: up_cm must be an integer 0..3000 (cm per second)"],
    [m6ask, [rule({ do: [{ do: "say", text: "hi", frames: 10 }] })], "rule: do[0] say: frames must be an integer 30..600 (60 frames are 1 s)"],
    [m6ask, [rule({ do: [{ do: "say", text: "x".repeat(61), frames: 60 }] })], "rule: do[0] say: text must be 1-60 printable characters"],
    [m6ask, [rule({ do: [{ do: "add", counter: "coins", by: 0 }] })], "rule: do[0] add: by must be an integer -99..99, not 0"],
    [m6ask, [rule({ do: [{ do: "start", run: "" }] })], "rule: do[0] start: run must be 1-24 printable characters"],
    [m6ask, [rule({ do: [{ do: "teleport", zone: 8 }] })], "rule: do[0] teleport: zone 8 is neither made by this answer nor listed in the region's zones"],
    [m6ask, [rule({ do: [{ do: "finish", zone: 3 }] })], 'rule: do[0] finish: takes no "zone" (it takes nothing else)'],
    [m6ask, [rule({}), rule({})], "rule: the answer makes rule 1 twice: give each new rule its own id"],
    [{ ...m6ask, rules_room: { zones_left: 9, rules_left: 9, counters: ["a", "b", "c", "d", "e", "f", "g"] } },
      [rule({ do: [{ do: "add", counter: "h", by: 1 }, { do: "add", counter: "i", by: 1 }] })], "rule: the Home would use 9 counters (a, b, c, d, e, f, g, h, i); at most 8"],
    [m6ask, [{ op: "unzone", id: 5, box: [[110, 10, 60], [111, 11, 61]], look: "none" }], "unzone: no zone 5 is listed in the region's zones (unzone names one that is there)"],
    [m6ask, [{ op: "unrule", id: 8, when: { on: "start" }, do: [{ do: "finish" }] }], "unrule: no rule 8 is listed in the region's rules (unrule names one that is there)"],
    [m6ask, [z({ box: [[100, 10, 51], [101, 10, 52]] })], "zone: the box covers columns the Home refuses (game lot, x 99..102, z 52): zones are refused there"],
    [m6ask, [z({ colour: "red" })], 'zone: zone takes no "colour"'],
  ];
  for (const [a, ops, want] of rows) assert.deepEqual(m6problems(a, ops).slice(0, 1), [want], want);
  // the rule naming a refused zone hears why too
  assert.equal(m6problems(m6ask, [z({ look: "spring" }), rule({ when: { on: "enter", zone: 1 } })])[1], "rule: when: zone 1 was refused above (fix it, and this holds)");
  // a new zone that reuses a listed zone's id is the answer's own: the rule names it, the listed one stays (renumber)
  assert.deepEqual(m6problems(m6ask, [z({ id: 3 }), rule({ when: { on: "enter", zone: 3 } })]), []);
  // unrule, then unzone, then a new zone and rule in its place: one batch the Home applies in order
  assert.deepEqual(m6problems(m6ask, [{ op: "unrule", ...m6ask.rules[0] }, { op: "unzone", ...m6ask.zones[1] }, z({}),
    rule({ when: { on: "use", zone: 1 }, do: [{ do: "open", zone: 3 }] })]), []);
});

test("world-edit M6: an ask's zones and rules are read in the file's shapes; a malformed one is refused before any call", () => {
  const bad = worldEdit({ ...m6ask, zones: [{ id: 3, box: [[110, 10, 60]], look: "none" }] }, []);
  assert.equal(bad.code, 2);
  assert.match(bad.error, /--in.*zones/);
  const odd = worldEdit({ ...m6ask, rules: [{ id: 7, when: { on: "use", zone: 4 }, do: [], extra: 1 }] }, []);
  assert.equal(odd.code, 2);
});
