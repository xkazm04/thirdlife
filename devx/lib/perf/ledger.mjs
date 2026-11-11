// The perf ledger (perf/ledger.jsonl, schema tl.perf/1): one line per `tl perf run`, plus the pure functions that read,
// compare and trend it. No process state: files are passed in, so tests need no Godot.
import fs from "node:fs";
import path from "node:path";

export const SCHEMA = "tl.perf/1";

/** Every metric a scenario may report. All are "lower is better" except bodies_awake, which is information. */
export const METRICS = ["sim_tick_ms_p50", "sim_tick_ms_p99", "worst_tick_ms", "frame_ms_p50", "frame_ms_p99", "worst_frame_ms",
  "gpu_ms", "render_cpu_ms", "draw_calls", "primitives", "load_ms", "first_frame_ms", "six_built_ms", "bodies_awake"];

/**
 * The tolerance of the gate: a metric regresses when it is above baseline * (1 + rel) + abs. Chosen from the spread of
 * repeated quiet runs (docs/PERF.md "Tolerances"): medians of a deterministic scripted run move a few percent, tails and
 * worst cases move a lot, counts of draw calls and primitives do not move at all.
 */
export const TOLERANCE = {
  sim_tick_ms_p50: { rel: 0.20, abs: 0.05 },
  // 0.30 at first. Two quiet runs of tour6 on the merged round 1 gave 11.8 and 17.0 ms: the 99th percentile there is a
  // handful of ticks in which a pack is built (worst tick 762 to 838 ms). Until the loading package removes those
  // ticks this metric is noise above its median; tighten it again when worst_tick_ms is under a frame.
  sim_tick_ms_p99: { rel: 0.60, abs: 0.30 },
  worst_tick_ms: { rel: 0.60, abs: 2.0 },
  frame_ms_p50: { rel: 0.20, abs: 0.10 },
  frame_ms_p99: { rel: 0.30, abs: 0.50 },
  worst_frame_ms: { rel: 0.60, abs: 3.0 },
  gpu_ms: { rel: 0.20, abs: 0.20 },
  render_cpu_ms: { rel: 0.20, abs: 0.20 },
  draw_calls: { rel: 0.02, abs: 2 },
  primitives: { rel: 0.02, abs: 100 },
  load_ms: { rel: 0.30, abs: 150 },
  first_frame_ms: { rel: 0.30, abs: 300 },   // P5: the world's start to the first drawn frame (the landscape is in it, the engine's start is not)
  six_built_ms: { rel: 0.50, abs: 500 },     // P5: world start until the sixth pack is attached (a worker thread: moves with the machine)
};

export function readLedger(file) {
  if (!fs.existsSync(file)) return [];
  const rows = [];
  for (const l of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
    if (!l.trim()) continue;
    try { const r = JSON.parse(l); if (r.schema === SCHEMA) rows.push(r); } catch { /* a torn line is skipped, never fatal */ }
  }
  return rows;
}

export function appendLine(file, row) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.appendFileSync(file, JSON.stringify(row) + "\n");
}

/** The last quiet run on this machine that has the scenario (a busy run is never a baseline). */
export function lastQuiet(rows, scenario, machine) {
  for (let i = rows.length - 1; i >= 0; i--) {
    const r = rows[i];
    if (r.quiet === true && (!machine || r.machine === machine) && r.scenarios?.[scenario]) return r;
  }
  return null;
}

/** Compares two scenario records -> [{metric, base, now, delta, pct, limit, verdict}]; verdict: ok | REGRESSED | better | info. */
export function compareScenario(base, now) {
  const out = [];
  for (const m of METRICS) {
    const b = base?.[m], n = now?.[m];
    if (b === undefined && n === undefined) continue;
    if (b === undefined || n === undefined) { out.push({ metric: m, base: b, now: n, verdict: "info" }); continue; }
    const tol = TOLERANCE[m];
    const limit = tol ? b * (1 + tol.rel) + tol.abs : null;
    const pct = b !== 0 ? ((n - b) / b) * 100 : null;
    let verdict = "info";
    if (tol) verdict = n > limit ? "REGRESSED" : n < b * (1 - tol.rel) - tol.abs ? "better" : "ok";
    out.push({ metric: m, base: b, now: n, delta: n - b, pct, limit, verdict });
  }
  return out;
}

/** Compares two ledger rows over the scenarios both have. -> {rows: [{scenario, ...cell}], regressions: n} */
export function compareRows(a, b) {
  const rows = [];
  let regressions = 0;
  for (const id of Object.keys(b.scenarios ?? {})) {
    if (!a.scenarios?.[id]) continue;
    for (const c of compareScenario(a.scenarios[id], b.scenarios[id])) { rows.push({ scenario: id, ...c }); if (c.verdict === "REGRESSED") regressions++; }
  }
  return { rows, regressions };
}

const fmt = (v) => (v === undefined ? "-" : Math.abs(v) >= 100 ? String(Math.round(v)) : v.toFixed(3));

/** The table a person reads. */
export function formatCompare(a, b, cmp = compareRows(a, b)) {
  const head = `perf compare: A ${a.ts} ${a.commit} ${a.quiet ? "quiet" : "BUSY"}   B ${b.ts} ${b.commit} ${b.quiet ? "quiet" : "BUSY"}`;
  const lines = [head, `${"scenario".padEnd(9)} ${"metric".padEnd(16)} ${"A".padStart(10)} ${"B".padStart(10)} ${"change".padStart(9)}  verdict`];
  for (const r of cmp.rows) {
    const pct = r.pct === null || r.pct === undefined ? "" : `${r.pct >= 0 ? "+" : ""}${r.pct.toFixed(1)}%`;
    lines.push(`${r.scenario.padEnd(9)} ${r.metric.padEnd(16)} ${fmt(r.base).padStart(10)} ${fmt(r.now).padStart(10)} ${pct.padStart(9)}  ${r.verdict}`);
  }
  if (!cmp.rows.length) lines.push("(no scenario in common)");
  if (!a.quiet || !b.quiet) lines.push("note: a BUSY run was taken while the machine was loaded; its figures are recorded but never used as a baseline");
  return lines.join("\n");
}

/** Per scenario and metric: every run in time order. */
export function trend(rows) {
  const out = {};
  for (const r of rows) {
    for (const [id, sc] of Object.entries(r.scenarios ?? {})) {
      for (const m of METRICS) {
        if (sc[m] === undefined) continue;
        (out[`${id}/${m}`] ??= []).push({ ts: r.ts, commit: r.commit, quiet: r.quiet, v: sc[m] });
      }
    }
  }
  return out;
}

export function formatTrend(rows, last = 8) {
  const t = trend(rows);
  const keys = Object.keys(t).sort();
  if (!keys.length) return "no perf runs in the ledger yet (tl perf run)";
  const lines = [`${"scenario/metric".padEnd(28)} runs  quiet   ${"first".padStart(9)} ${"last".padStart(9)} ${"best".padStart(9)}  last ${last} (quiet marked *)`];
  for (const k of keys) {
    const pts = t[k], vals = pts.filter((p) => p.quiet).map((p) => p.v);
    const best = vals.length ? Math.min(...vals) : undefined;
    lines.push(`${k.padEnd(28)} ${String(pts.length).padStart(4)} ${String(vals.length).padStart(6)}   ${fmt(vals[0]).padStart(9)} ${fmt(vals.at(-1)).padStart(9)} ${fmt(best).padStart(9)}  ${pts.slice(-last).map((p) => fmt(p.v) + (p.quiet ? "*" : "")).join(" ")}`);
  }
  return lines.join("\n");
}
