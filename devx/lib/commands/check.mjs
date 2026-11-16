// `tl check`: one command, one verdict. See devx/lib/gate/ for the engine and steps/ for the steps.
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as realCtx from "../ctx.mjs";
import { discoverSteps } from "../gate/discover.mjs";
import { runGate } from "../gate/engine.mjs";
import { readHistory, trend } from "../gate/history.mjs";
import { diskReport } from "../disk.mjs";
import { usage, couldNotRun, done } from "../verdict.mjs";

export const summary = "the gate: run the checks (--tier fast|full, --only a,b, --changed [--base ref], --expect-drop a,b, --trend)";

const STEPS_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "gate", "steps");
const USAGE = "usage: tl check [--tier fast|full] [--only <step>[,..]] [--changed [--base <ref>]] [--expect-drop <step>[,..]] [--trend]";

export function parseArgs(args) {
  const o = { tier: "full", only: null, changed: false, base: "HEAD", trend: false, expectDrop: [] };
  for (let i = 0; i < args.length; i++) {
    const a = args[i], val = () => { const v = args[++i]; if (v === undefined) throw new Error(`${a} needs a value`); return v; };
    if (a === "--tier") o.tier = val();
    else if (a.startsWith("--tier=")) o.tier = a.slice(7);
    else if (a === "--only") o.only = val().split(",").filter(Boolean);
    else if (a.startsWith("--only=")) o.only = a.slice(7).split(",").filter(Boolean);
    else if (a === "--changed") o.changed = true;
    else if (a === "--base") o.base = val();
    else if (a.startsWith("--base=")) o.base = a.slice(7);
    else if (a === "--expect-drop") o.expectDrop.push(...val().split(",").filter(Boolean));
    else if (a.startsWith("--expect-drop=")) o.expectDrop.push(...a.slice(14).split(",").filter(Boolean));
    else if (a === "--trend") o.trend = true;
    else throw new Error(`unknown option ${a}`);
  }
  if (o.tier !== "fast" && o.tier !== "full") throw new Error(`--tier must be fast or full, not '${o.tier}'`);
  return o;
}

/** The testable core. deps = {steps, broken, git, ctx, historyFile}: omitted -> the real ones. Returns the exit code. */
export async function execute(args, deps = {}) {
  const ctx = deps.ctx ?? realCtx;
  const historyFile = deps.historyFile === undefined ? path.join(ctx.REPO, ".tl", "gate-history.jsonl") : deps.historyFile;
  let o;
  try { o = parseArgs(args); } catch (e) { return usage("check", `tl check: ${e.message}\n${USAGE}`); }
  if (o.trend) return trendReport(historyFile);
  // The disk floor says, it never stops anything (devx/lib/disk.mjs).
  const disk = (deps.disk ?? diskReport)(ctx.REPO);
  console.log(`# ${disk.line}`);
  let found = deps.steps ? { steps: deps.steps, broken: deps.broken ?? [] } : await discoverSteps(STEPS_DIR);
  const git = deps.git ?? ((a) => { const r = ctx.run("git", a, { cwd: ctx.REPO }); if (r.code !== 0) throw new Error(r.stderr.trim() || `git ${a.join(" ")} exited ${r.code}`); return r.stdout; });
  const res = await runGate({ ...o, steps: found.steps, broken: found.broken, git, ctx, historyFile, log: (m) => console.error(m) });
  if (res.error) return res.usage ? usage("check", `tl check: ${res.error}
${USAGE}`) : couldNotRun("check", `tl check: ${res.error}`);
  if (res.note) console.log(`# ${res.note}`);
  const lines = res.results.map((r) => ({ ...r, detail: r.detail.split("\n")[0].slice(0, 300) }));
  const diskExtra = disk.error ? {} : { disk_free_gb: disk.free_gb, disk_floor_gb: disk.floor_gb, ...(disk.low ? { disk_low: true } : {}) };
  ctx.printVerdict("check", lines, { ...res.extra, ...diskExtra, exit: res.exit });   // the engine's tri-state is the line's exit
  return res.exit;
}

/** --trend: per step, runs / median / last ms, and the last found count against the last green one (DROP when fewer, not
 *  declared) from the gate history; the rows ride in the JSON line as `trend`. */
function trendReport(historyFile) {
  const rows = trend(readHistory(historyFile ?? ""));
  if (!rows.length) console.log("no gate history yet (.tl/gate-history.jsonl)");
  else {
    const n = (v) => String(v ?? "-");
    console.log("step                          runs  median ms   last ms  last found  green found");
    for (const r of rows) console.log(`${r.id.padEnd(28)} ${String(r.n).padStart(5)} ${String(r.median).padStart(10)} ${String(r.last).padStart(9)} ${n(r.last_found).padStart(11)} ${n(r.green_found).padStart(12)}${r.drop ? "  DROP" : ""}${r.slow ? "  SLOWER than usual" : ""}`);
  }
  return done("check", { mode: "trend", trend: rows });
}

export async function run(args, ctx) { return execute(args, { ctx }); }
