// `tl perf run | compare | trend`: the performance ledger (perf/ledger.jsonl, schema tl.perf/1). docs/PERF.md has the whole story.
import os from "node:os";
import path from "node:path";
import { appendLine, compareRows, formatCompare, formatTrend, readLedger, SCHEMA } from "../perf/ledger.mjs";
import { judge, sample } from "../perf/quiet.mjs";
import { SCENARIOS, bestOf } from "../perf/scenarios.mjs";

export const summary = "performance ledger: run [--scenario id[,id]] [--quiet-only] [--repeat N] | compare <a> <b> | trend";

const USAGE = `usage: tl perf run [--scenario <id>[,<id>]] [--quiet-only [--wait <s>]] [--repeat N] [--no-record]
       tl perf compare <a> <b>     (a ledger line number, -1 = the last line, "last", "base" = the last quiet line)
       tl perf trend
scenarios: ${Object.keys(SCENARIOS).join(", ")}`;

export function ledgerFile(ctx) { return path.join(ctx.REPO, "perf", "ledger.jsonl"); }

export function machineId() {
  const c = os.cpus();
  return `${(c[0]?.model ?? "cpu").replace(/\s+/g, " ").trim()}/${c.length}t/${os.platform()}`;
}

function commitId(ctx) {
  const h = ctx.run("git", ["rev-parse", "--short", "HEAD"], { cwd: ctx.REPO, env: { GIT_DIR: undefined } });
  if (h.code !== 0) return "unknown";
  const d = ctx.run("git", ["status", "--porcelain", "--untracked-files=no"], { cwd: ctx.REPO });
  return h.stdout.trim() + (d.code === 0 && d.stdout.trim() ? "+dirty" : "");
}

export function parseRunArgs(args) {
  const o = { scenarios: null, quietOnly: false, wait: 120, repeat: 1, record: true };
  for (let i = 0; i < args.length; i++) {
    const a = args[i], val = () => { const v = args[++i]; if (v === undefined) throw new Error(`${a} needs a value`); return v; };
    if (a === "--scenario") o.scenarios = val().split(",").filter(Boolean);
    else if (a.startsWith("--scenario=")) o.scenarios = a.slice(11).split(",").filter(Boolean);
    else if (a === "--quiet-only") o.quietOnly = true;
    else if (a === "--wait") o.wait = Number(val());
    else if (a === "--repeat") o.repeat = Math.max(1, Number(val()));
    else if (a === "--no-record") o.record = false;
    else throw new Error(`unknown option ${a}`);
  }
  if (o.scenarios) for (const s of o.scenarios) if (!SCENARIOS[s]) throw new Error(`unknown scenario '${s}' (have: ${Object.keys(SCENARIOS).join(", ")})`);
  return o;
}

/** Looks one ledger line up: 1-based number, negative from the end, "last", "prev", or "base" (the last quiet line). */
export function pick(rows, ref) {
  if (!rows.length) return null;
  if (ref === "last") return rows.at(-1);
  if (ref === "prev") return rows.at(-2) ?? null;
  if (ref === "base") return [...rows].reverse().find((r) => r.quiet) ?? null;
  const n = Number(ref);
  if (!Number.isInteger(n) || n === 0) return null;
  return n > 0 ? rows[n - 1] ?? null : rows[rows.length + n] ?? null;
}

async function waitQuiet(o, log) {
  const t0 = Date.now();
  for (;;) {
    const s = await sample(1500);
    if (judge([s]).quiet) return s;
    if ((Date.now() - t0) / 1000 >= o.wait) return null;
    log(`... machine busy (use ${(s.util * 100).toFixed(0)}%, probe ${s.probe}); waiting`);
  }
}

async function run(args, ctx) {
  let o;
  try { o = parseRunArgs(args); } catch (e) { console.error(`tl perf: ${e.message}\n${USAGE}`); return 2; }
  if (!ctx.resolveGodot()) { console.error("tl perf: no Godot found: set TL_GODOT or .tl/local.json (tl doctor)"); return 2; }
  const ids = o.scenarios ?? Object.keys(SCENARIOS);
  const log = (m) => console.error(m);
  let pre;
  if (o.quietOnly) {
    pre = await waitQuiet(o, log);
    if (!pre) { console.log(`FAIL  perf.run  the machine was not quiet within ${o.wait} s; nothing was run or recorded`); console.log(JSON.stringify({ schema: "tl.devx/1", cmd: "perf run", ok: false, steps: [] })); return 2; }
  } else pre = await sample(1500);
  const steps = [], scenarios = {};
  for (const id of ids) {
    log(`... ${id}`);
    const t0 = Date.now();
    try {
      const runs = [];
      for (let i = 0; i < o.repeat; i++) runs.push(SCENARIOS[id].run(ctx));
      scenarios[id] = bestOf(runs);
      steps.push({ id: `perf.${id}`, ok: true, ms: Date.now() - t0, detail: Object.entries(scenarios[id]).map(([k, v]) => `${k} ${v}`).join(", ") });
    } catch (e) {
      steps.push({ id: `perf.${id}`, ok: false, ms: Date.now() - t0, detail: String(e?.message ?? e).split("\n")[0].slice(0, 300) });
    }
  }
  const post = await sample(1500);
  const verdict = judge([pre, post]);
  const row = { schema: SCHEMA, ts: new Date().toISOString().replace(/\.\d+Z$/, "Z"), commit: commitId(ctx), machine: machineId(), quiet: verdict.quiet,
    load: { util: verdict.util, probe: verdict.probe }, scenarios };
  let note = `machine ${verdict.quiet ? "quiet" : "BUSY"} (use ${(verdict.util * 100).toFixed(0)}%, probe ${verdict.probe})`;
  if (o.quietOnly && !verdict.quiet) note += "; it became busy during the run: NOT recorded";
  else if (o.record && Object.keys(scenarios).length) { appendLine(ledgerFile(ctx), row); note += `; recorded in perf/ledger.jsonl (line ${readLedger(ledgerFile(ctx)).length})`; }
  else note += "; not recorded";
  console.log(`# ${note}`);
  return ctx.printVerdict("perf run", steps, { quiet: verdict.quiet, row });
}

async function compare(args, ctx) {
  const rows = readLedger(ledgerFile(ctx));
  if (args.length !== 2) { console.error(USAGE); return 2; }
  const a = pick(rows, args[0]), b = pick(rows, args[1]);
  if (!a || !b) { console.error(`tl perf compare: no such ledger line (${rows.length} line(s) in perf/ledger.jsonl)`); return 2; }
  const cmp = compareRows(a, b);
  console.log(formatCompare(a, b, cmp));
  console.log(JSON.stringify({ schema: "tl.devx/1", cmd: "perf compare", ok: cmp.regressions === 0, regressions: cmp.regressions }));
  return cmp.regressions === 0 ? 0 : 1;
}

async function trendCmd(args, ctx) {
  console.log(formatTrend(readLedger(ledgerFile(ctx))));
  return 0;
}

export async function runCommand(args, ctx) {
  const [sub, ...rest] = args;
  if (sub === "run") return run(rest, ctx);
  if (sub === "compare") return compare(rest, ctx);
  if (sub === "trend") return trendCmd(rest, ctx);
  console.error(USAGE);
  return 2;
}
export { runCommand as run };
