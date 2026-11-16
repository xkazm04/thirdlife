// A step that FOUND fewer units than its last green run of the same tier fails unless the drop is declared (docs/GATE-HONESTY.md).
// Offline: fake steps and a temp history file; the real .tl/gate-history.jsonl is never read or written here.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execute } from "../lib/commands/check.mjs";
import { HOOK_SCRIPT } from "../lib/commands/hook.mjs";
import * as ctx from "../lib/ctx.mjs";

const fake = (id, run) => ({ id, tiers: ["fast", "full"], paths: [`${id}/**`], run });
const counted = (id, n) => fake(id, async () => ({ ok: true, found: n, completed: n, detail: `${n} pass` }));
const row = (steps, tier = "fast") => ({ ts: "2026-11-16T00:00:00.000Z", tier, load: 0, steps: steps.map((s) => ({ ms: 1, retried: false, ...s })) });

function tmpHistory(rows) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tl-drop-"));
  const file = path.join(dir, "gate-history.jsonl");
  if (rows) fs.writeFileSync(file, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
  return file;
}
const readRows = (file) => fs.readFileSync(file, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));

async function gate(args, steps, historyFile) {
  const lines = [];
  const o = console.log, e = console.error; console.log = (...a) => lines.push(a.join(" ")); console.error = () => {};
  let exit; try { exit = await execute(args, { steps, historyFile, ctx, disk: () => ({ line: "disk: test", free_gb: 100, floor_gb: 20, low: false }) }); } finally { console.log = o; console.error = e; }
  let json = null; try { json = JSON.parse(lines.at(-1) ?? "null"); } catch { /* none */ }
  return { exit, lines, json };
}
const lineOf = (lines, id) => lines.find((l) => /^(PASS|FAIL|NOT RUN) /.test(l) && l.split(/\s+/).includes(id)) ?? "";
const green169 = row([{ id: "devx.test", ok: true, found: 169, completed: 169 }]);

test("a drop against the last green run is a FAIL with the figures, and count_drops in the JSON", async () => {
  const file = tmpHistory([green169]);
  const { exit, lines, json } = await gate(["--tier", "fast"], [counted("devx.test", 165)], file);
  assert.equal(exit, 1);
  const l = lineOf(lines, "devx.test");
  assert.ok(l.startsWith("FAIL"), l);
  assert.ok(l.includes("[165/165] found 165, last green run found 169 (-4)"), l);
  assert.deepEqual(json.count_drops, [{ id: "devx.test", was: 169, now: 165 }]);
  assert.equal(json.ok, false);
  assert.equal(readRows(file).at(-1).steps[0].ok, false, "the failed drop is recorded as a failed step, so it never becomes the baseline");
});

test("--expect-drop <step> declares the removal: PASS, the line says expected, the history row records it", async () => {
  const file = tmpHistory([green169]);
  const { exit, lines, json } = await gate(["--tier", "fast", "--expect-drop", "devx.test"], [counted("devx.test", 165)], file);
  assert.equal(exit, 0);
  const l = lineOf(lines, "devx.test");
  assert.ok(l.startsWith("PASS") && l.includes("(-4 vs last green, expected)"), l);
  assert.equal(json.count_drops, undefined);
  const last = readRows(file).at(-1);
  assert.deepEqual(last.expected_drop, ["devx.test"]);
  // the declared count is the next run's baseline
  const again = await gate(["--tier", "fast"], [counted("devx.test", 165)], file);
  assert.equal(again.exit, 0); assert.ok(lineOf(again.lines, "devx.test").includes("(+0 vs last green)"));
});

test("a rise is a PASS showing the delta; no count_drops key", async () => {
  const file = tmpHistory([green169]);
  const { exit, lines, json } = await gate(["--tier", "fast"], [counted("devx.test", 173)], file);
  assert.equal(exit, 0);
  assert.ok(lineOf(lines, "devx.test").includes("(+4 vs last green)"));
  assert.ok(!("count_drops" in json));
  assert.ok(!("expected_drop" in readRows(file).at(-1)), "absent = omitted");
});

test("no history file: PASS on the engine's own law, the line says no earlier count", async () => {
  const file = tmpHistory(null);
  const { exit, lines, json } = await gate(["--tier", "fast"], [counted("devx.test", 169)], file);
  assert.equal(exit, 0);
  assert.ok(lineOf(lines, "devx.test").includes("no earlier count"));
  assert.ok(!("count_drops" in json));
});

test("the baseline is the last GREEN run of the step in the same tier: never a failed, not-run or other-tier row; old rows still read", async () => {
  const file = tmpHistory([
    { ts: "x", steps: [{ id: "devx.test", ms: 1, ok: true }] },                 // an old row: no tier, no counts
    green169,
    row([{ id: "devx.test", ok: false, found: 150, completed: 150 }]),
    row([{ id: "devx.test", ok: false, not_run: true, found: 120, completed: 0 }]),
    row([{ id: "devx.test", ok: true, found: 100, completed: 100 }], "full"),
    row([{ id: "other", ok: true, found: 5, completed: 5 }]),                   // a --only run without the step: not a drop
  ]);
  const { exit, lines } = await gate(["--tier", "fast"], [counted("devx.test", 169)], file);
  assert.equal(exit, 0);
  assert.ok(lineOf(lines, "devx.test").includes("(+0 vs last green)"), lineOf(lines, "devx.test"));
  // a step that could not run is never compared
  const nr = await gate(["--tier", "fast"], [fake("devx.test", async () => ({ ok: false, notRun: true, found: 3, completed: 0, detail: "no deps" }))], file);
  assert.equal(nr.exit, 2);
  assert.ok(!("count_drops" in nr.json));
});

test("--expect-drop naming a step not selected: exit 2, the error names the selected steps, nothing runs", async () => {
  const file = tmpHistory([green169]);
  let ran = 0;
  const s = fake("devx.test", async () => { ran++; return { ok: true, found: 1, completed: 1 }; });
  const { exit, json } = await gate(["--tier", "fast", "--expect-drop", "nosuch"], [s], file);
  assert.equal(exit, 2);
  assert.equal(ran, 0);
  assert.match(json.error, /nosuch/); assert.match(json.error, /devx\.test/);
  assert.equal(readRows(file).length, 1, "nothing appended");
});

test("--trend gains last found and green found columns and marks DROP", async () => {
  const file = tmpHistory([
    green169,
    row([{ id: "devx.test", ok: false, found: 165, completed: 165 }, { id: "arch", ok: true, found: 9, completed: 9 }]),
  ]);
  const { exit, lines, json } = await gate(["--trend"], [], file);
  assert.equal(exit, 0);
  assert.ok(lines.some((l) => l.includes("last found") && l.includes("green found")));
  const l = lines.find((x) => x.startsWith("devx.test"));
  assert.ok(l && l.includes("DROP"), l);
  assert.ok(!lines.find((x) => x.startsWith("arch")).includes("DROP"));
  const r = json.trend.find((x) => x.id === "devx.test");
  assert.equal(r.last_found, 165); assert.equal(r.green_found, 169); assert.equal(r.drop, true);
  assert.ok(!("drop" in json.trend.find((x) => x.id === "arch")));
});

test("the pre-push hook's FAIL message names --expect-drop as the way to declare a real removal", () => {
  assert.match(HOOK_SCRIPT, /--expect-drop <step>/);
});
