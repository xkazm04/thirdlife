// perf ledger, compare, trend, quiet and scenario parsers: no Godot, no machine load needed.
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { TOLERANCE, appendLine, compareRows, compareScenario, formatCompare, formatTrend, lastQuiet, readLedger, SCHEMA } from "../lib/perf/ledger.mjs";
import { judge } from "../lib/perf/quiet.mjs";
import { bestOf, parseStats, parseTour, parseWorld } from "../lib/perf/scenarios.mjs";
import { parseRunArgs, pick } from "../lib/commands/perf.mjs";

const row = (ts, quiet, sc, extra = {}) => ({ schema: SCHEMA, ts, commit: "abc", machine: "m", quiet, scenarios: sc, ...extra });

test("compareScenario: within tolerance is ok, beyond is REGRESSED, far under is better", () => {
  const base = { sim_tick_ms_p50: 1.0, draw_calls: 100 };
  const lim = 1.0 * (1 + TOLERANCE.sim_tick_ms_p50.rel) + TOLERANCE.sim_tick_ms_p50.abs;
  const at = (v) => compareScenario(base, { sim_tick_ms_p50: v, draw_calls: 100 }).find((c) => c.metric === "sim_tick_ms_p50").verdict;
  assert.equal(at(lim - 0.001), "ok");
  assert.equal(at(lim + 0.001), "REGRESSED");
  assert.equal(at(0.5), "better");
  // a count that does not move at all stays ok, beyond the allowance regresses
  assert.equal(compareScenario(base, { sim_tick_ms_p50: 1.0, draw_calls: 105 }).find((c) => c.metric === "draw_calls").verdict, "REGRESSED");
});

test("compareScenario: a metric only one side measured is information, bodies_awake never regresses", () => {
  const r = compareScenario({ sim_tick_ms_p50: 1, bodies_awake: 500 }, { sim_tick_ms_p50: 1, bodies_awake: 900, load_ms: 5 });
  assert.equal(r.find((c) => c.metric === "load_ms").verdict, "info");
  assert.equal(r.find((c) => c.metric === "bodies_awake").verdict, "info");
});

test("lastQuiet never returns a busy run and honours the machine", () => {
  const rows = [row("t1", true, { a: { load_ms: 1 } }), row("t2", false, { a: { load_ms: 2 } }), row("t3", true, { b: { load_ms: 3 } })];
  assert.equal(lastQuiet(rows, "a", "m").ts, "t1");
  assert.equal(lastQuiet(rows, "b", "m").ts, "t3");
  assert.equal(lastQuiet(rows, "a", "other"), null);
  assert.equal(lastQuiet([row("t", false, { a: {} })], "a", "m"), null);
});

test("ledger: append, read back, a torn line is skipped", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tl_perf_test_"));
  try {
    const f = path.join(dir, "perf", "ledger.jsonl");
    appendLine(f, row("t1", true, { a: { load_ms: 1 } }));
    fs.appendFileSync(f, "{not json\n");
    appendLine(f, row("t2", false, { a: { load_ms: 2 } }));
    const rows = readLedger(f);
    assert.deepEqual(rows.map((r) => r.ts), ["t1", "t2"]);
    assert.equal(readLedger(path.join(dir, "none.jsonl")).length, 0);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test("formatCompare prints a table a person can read, and flags a busy run", () => {
  const a = row("2026-11-11T10:00:00Z", true, { mix30: { sim_tick_ms_p50: 2.0, load_ms: 1000 } });
  const b = row("2026-11-11T11:00:00Z", false, { mix30: { sim_tick_ms_p50: 3.5, load_ms: 1010 } });
  const cmp = compareRows(a, b);
  assert.equal(cmp.regressions, 1);
  const text = formatCompare(a, b, cmp);
  assert.match(text, /mix30\s+sim_tick_ms_p50\s+2\.000\s+3\.500\s+\+75\.0%\s+REGRESSED/);
  assert.match(text, /BUSY/);
});

test("formatTrend lists quiet runs and counts busy ones", () => {
  const rows = [row("t1", true, { a: { load_ms: 100 } }), row("t2", false, { a: { load_ms: 900 } }), row("t3", true, { a: { load_ms: 110 } })];
  const text = formatTrend(rows);
  assert.match(text, /a\/load_ms\s+3\s+2\s+100\.?0?0?0?\s+110/);
  assert.match(formatTrend([]), /no perf runs/);
});

test("pick: line numbers, negative from the end, last, prev, base", () => {
  const rows = [row("t1", true, {}), row("t2", false, {}), row("t3", false, {})];
  assert.equal(pick(rows, "1").ts, "t1");
  assert.equal(pick(rows, "-1").ts, "t3");
  assert.equal(pick(rows, "last").ts, "t3");
  assert.equal(pick(rows, "prev").ts, "t2");
  assert.equal(pick(rows, "base").ts, "t1");
  assert.equal(pick(rows, "9"), null);
  assert.equal(pick(rows, "0"), null);
});

test("parseRunArgs", () => {
  assert.deepEqual(parseRunArgs(["--scenario", "mix30,pile600", "--quiet-only", "--repeat", "2"]), { scenarios: ["mix30", "pile600"], quietOnly: true, wait: 120, repeat: 2, record: true });
  assert.throws(() => parseRunArgs(["--scenario", "nope"]), /unknown scenario/);
  assert.throws(() => parseRunArgs(["--wat"]), /unknown option/);
});

test("judge: busy when the machine is used or the probe is starved", () => {
  assert.equal(judge([{ util: 0.1, probe: 0.99 }, { util: 0.2, probe: 0.97 }]).quiet, true);
  assert.equal(judge([{ util: 0.1, probe: 0.99 }, { util: 0.6, probe: 0.99 }]).quiet, false);
  assert.equal(judge([{ util: 0.1, probe: 0.5 }]).quiet, false);
});

test("parseWorld takes the world line and the awake bodies; a world with errors throws", () => {
  const out = [
    "noise", JSON.stringify({ schema: "tl.world/1", kind: "pack", awake_bodies_at_end: 554 }),
    JSON.stringify({ schema: "tl.world/1", kind: "world", load_ms: 2200, iter_ms_p50: 7.4, iter_ms_p99: 8.1, iter_ms_max: 9.9, errors: [], script_errors: 0, engine_errors: 0 }),
  ].join("\n");
  assert.deepEqual(parseWorld(out), { sim_tick_ms_p50: 7.4, sim_tick_ms_p99: 8.1, worst_tick_ms: 9.9, load_ms: 2200, bodies_awake: 554 });
  assert.throws(() => parseWorld(JSON.stringify({ kind: "world", errors: ["pack 0 did not load"] })), /errors/);
  assert.throws(() => parseWorld("nothing"), /no tl.world/);
});

test("parseTour takes frame, render and the largest draw count over the pictures", () => {
  const out = [
    JSON.stringify({ kind: "world", load_ms: 3000, iter_ms_p50: 1, iter_ms_p99: 2, iter_ms_max: 3 }),
    JSON.stringify({ kind: "picture", draw_calls: 400, primitives: 90000 }), JSON.stringify({ kind: "picture", draw_calls: 520, primitives: 80000 }),
    JSON.stringify({ kind: "tour", frame_ms_p50_all: 4.2, render_cpu_ms_p50: 1.5, render_gpu_ms_p50: 3.1, landscape: { build_ms: 800 } }),
  ].join("\n");
  const m = parseTour(out);
  assert.equal(m.frame_ms_p50, 4.2); assert.equal(m.gpu_ms, 3.1); assert.equal(m.render_cpu_ms, 1.5);
  assert.equal(m.draw_calls, 520); assert.equal(m.primitives, 90000);
  assert.throws(() => parseTour(JSON.stringify({ kind: "world" })), /did not report/);
});

test("parseStats and bestOf", () => {
  assert.deepEqual(parseStats('{"layout":"main","triangles":120000,"draw_calls":310}'), { draw_calls: 310, primitives: 120000 });
  assert.deepEqual(parseStats('WARNING: x' + String.fromCharCode(10) + '{"draw_calls":239,"layout":"main","objects":256,"primitives_in_frame":1667300,"triangles_built":488092,"viewport":[2560,1440]}'), { draw_calls: 239, primitives: 1667300 });
  assert.deepEqual(bestOf([{ a: 5, b: 1, bodies_awake: 10 }, { a: 3, b: 2, bodies_awake: 10 }]), { a: 3, b: 1, bodies_awake: 10 });
});
