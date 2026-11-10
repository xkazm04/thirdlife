// `tl check`: one command, one verdict. See devx/lib/gate/ for the engine and steps/ for the steps.
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as realCtx from "../ctx.mjs";
import { discoverSteps } from "../gate/discover.mjs";
import { runGate } from "../gate/engine.mjs";
import { readHistory, trend } from "../gate/history.mjs";

export const summary = "the gate: run the checks (--tier fast|full, --only a,b, --changed [--base ref], --trend)";

const STEPS_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "gate", "steps");
const USAGE = "usage: tl check [--tier fast|full] [--only <step>[,..]] [--changed [--base <ref>]] [--trend]";

export function parseArgs(args) {
  const o = { tier: "full", only: null, changed: false, base: "HEAD", trend: false };
  for (let i = 0; i < args.length; i++) {
    const a = args[i], val = () => { const v = args[++i]; if (v === undefined) throw new Error(`${a} needs a value`); return v; };
    if (a === "--tier") o.tier = val();
    else if (a.startsWith("--tier=")) o.tier = a.slice(7);
    else if (a === "--only") o.only = val().split(",").filter(Boolean);
    else if (a.startsWith("--only=")) o.only = a.slice(7).split(",").filter(Boolean);
    else if (a === "--changed") o.changed = true;
    else if (a === "--base") o.base = val();
    else if (a.startsWith("--base=")) o.base = a.slice(7);
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
  try { o = parseArgs(args); } catch (e) { console.error(`tl check: ${e.message}\n${USAGE}`); return 2; }
  if (o.trend) {
    const rows = trend(readHistory(historyFile ?? ""));
    if (!rows.length) { console.log("no gate history yet (.tl/gate-history.jsonl)"); return 0; }
    console.log("step                          runs  median ms   last ms");
    for (const r of rows) console.log(`${r.id.padEnd(28)} ${String(r.n).padStart(5)} ${String(r.median).padStart(10)} ${String(r.last).padStart(9)}${r.slow ? "  SLOWER than usual" : ""}`);
    return 0;
  }
  let found = deps.steps ? { steps: deps.steps, broken: deps.broken ?? [] } : await discoverSteps(STEPS_DIR);
  const git = deps.git ?? ((a) => { const r = ctx.run("git", a, { cwd: ctx.REPO }); if (r.code !== 0) throw new Error(r.stderr.trim() || `git ${a.join(" ")} exited ${r.code}`); return r.stdout; });
  const res = await runGate({ ...o, steps: found.steps, broken: found.broken, git, ctx, historyFile, log: (m) => console.error(m) });
  if (res.error) { console.error(`tl check: ${res.error}`); return 2; }
  if (res.note) console.log(`# ${res.note}`);
  const lines = res.results.map((r) => ({ ...r, detail: r.detail.split("\n")[0].slice(0, 300) }));
  ctx.printVerdict("check", lines, res.extra);
  return res.exit;
}

export async function run(args, ctx) { return execute(args, { ctx }); }
