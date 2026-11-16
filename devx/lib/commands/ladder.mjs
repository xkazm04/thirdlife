// `tl ladder`: a pack's ladder (H5/H6): every bot_ladder_<level>_<hand>.gd test the pack names, over N seeds, as one table.
// A cell is one test; each seed is one run. A run is completed when the bot finished (tl.verify/1 line, bot.completed true).
// Cells found / completed are reported (docs/GATE-HONESTY.md): the command fails when a cell did not complete every seed.
// The manifest has no `ladder` key (contracts/pack.schema.json forbids unknown keys): cells are found by file name.
export const summary = "a pack's difficulty ladder: `tl ladder --pack <dir> [--seeds N] [--cells a,b] [--par N]` (bot_ladder_* tests over N seeds; wins with a 95 % interval)";
import fs from "node:fs";
import path from "node:path";
import { spawn } from "node:child_process";
import * as realCtx from "../ctx.mjs";
import { usage, couldNotRun } from "../verdict.mjs";

const USAGE = "usage: tl ladder --pack <dir> [--seeds N] [--cells <level_hand>[,..]] [--par N]";

export function parseArgs(args) {
  const o = { pack: null, seeds: 20, cells: null, par: 6 };
  for (let i = 0; i < args.length; i++) {
    const a = args[i], val = () => { const v = args[++i]; if (v === undefined) throw new Error(`${a} needs a value`); return v; };
    const [k, inline] = a.includes("=") ? [a.slice(0, a.indexOf("=")), a.slice(a.indexOf("=") + 1)] : [a, undefined];
    const v = () => (inline !== undefined ? inline : val());
    if (k === "--pack") o.pack = v();
    else if (k === "--seeds") o.seeds = Number(v());
    else if (k === "--cells") o.cells = v().split(",").filter(Boolean);
    else if (k === "--par") o.par = Number(v());
    else throw new Error(`unknown option ${a}`);
  }
  if (!o.pack) throw new Error("--pack is required");
  if (!(o.seeds >= 1)) throw new Error("--seeds must be at least 1");
  if (!(o.par >= 1)) throw new Error("--par must be at least 1");
  return o;
}

/** The ladder cells a pack names: tests/bot_ladder_<level>_<hand>.gd. -> [{cell, test, level, hand}] */
export function findCells(packDir, only = null) {
  const man = JSON.parse(fs.readFileSync(path.join(packDir, "pack.json"), "utf8"));
  return (man.tests ?? []).map((t) => path.basename(t, ".gd")).filter((b) => b.startsWith("bot_ladder_")).map((b) => {
    const cell = b.slice("bot_ladder_".length), cut = cell.lastIndexOf("_");
    return { cell, test: `tests/${b}.gd`, level: cut > 0 ? cell.slice(0, cut) : cell, hand: cut > 0 ? cell.slice(cut + 1) : "?" };
  }).filter((c) => !only || only.includes(c.cell));
}

/** One run's report -> {done, won, gf, ga, frames, period, passes, reached, down, hash} or null when there is no verify line. */
export function readRun(stdout) {
  const line = String(stdout).split(/\r?\n/).filter((l) => l.startsWith("{")).reverse().find((l) => { try { return JSON.parse(l).schema === "tl.verify/1"; } catch { return false; } });
  if (!line) return null;
  const v = JSON.parse(line), b = v.bot?.result ?? {};
  const done = (v.checks ?? []).some((c) => c.id === "bot.completed" && c.ok === true);
  return { done, won: b.won === true, gf: Number(b.goals) || 0, ga: Number(b.against) || 0, frames: Number(b.frames) || 0, period: Number(b.period_reached) || 0,
    passes: Number(b.passes) || 0, reached: Number(b.passes_reached) || 0, down: Number(b.down_frames) || 0, taps: Number(b.taps_lost) || 0, shots: Number(b.shots) || 0, hash: v.metrics?.state_hash?.slice(0, 16) };
}

/** Wins of n with a 95 % interval (normal approximation), in whole percent. */
export function interval(w, n) {
  const p = n ? w / n : 0, h = n ? 1.96 * Math.sqrt(p * (1 - p) / n) : 0;
  return { pct: Math.round(p * 100), lo: Math.round(Math.max(0, p - h) * 100), hi: Math.round(Math.min(1, p + h) * 100) };
}

/** Pure core: cells x seeds through runBot(cell, seed) -> Promise<stdout>. -> rows */
export async function ladder(cells, seeds, par, runBot) {
  const jobs = [];
  for (const c of cells) for (let s = 1; s <= seeds; s++) jobs.push({ c, s });
  const got = new Map(cells.map((c) => [c.cell, []]));
  let i = 0;
  await Promise.all(Array.from({ length: Math.min(par, jobs.length) }, async () => {
    while (i < jobs.length) { const j = jobs[i++]; got.get(j.c.cell).push({ seed: j.s, r: readRun(await runBot(j.c, j.s)) }); }
  }));
  return cells.map((c) => {
    const runs = got.get(c.cell).sort((a, b) => a.seed - b.seed), ok = runs.filter((x) => x.r && x.r.done).map((x) => x.r);
    const n = ok.length, sum = (k) => ok.reduce((a, r) => a + r[k], 0), w = ok.filter((r) => r.won).length;
    return { ...c, found: seeds, completed: n, wins: w, ...interval(w, n), gf: n ? +(sum("gf") / n).toFixed(2) : 0, ga: n ? +(sum("ga") / n).toFixed(2) : 0,
      frames: n ? Math.round(sum("frames") / n) : 0, draws: ok.filter((r) => r.gf === r.ga).length, taps_lost: sum("taps"), shots: sum("shots"), period2: ok.filter((r) => r.period >= 2).length, passes: sum("passes"), reached: sum("reached"),
      down_pct: +(100 * sum("down") / Math.max(1, sum("frames"))).toFixed(2), missing: runs.filter((x) => !x.r || !x.r.done).map((x) => x.seed) };
  });
}

function realRunBot(ctx, packDir) {
  const sh = process.platform === "win32" && fs.existsSync("C:/Program Files/Git/bin/bash.exe") ? "C:/Program Files/Git/bin/bash.exe" : "bash";
  const godot = ctx.resolveGodot();
  return (c, seed) => new Promise((res) => {
    const p = spawn(sh, [path.join(ctx.ENGINE, "tools", "tl.sh"), "bot", `--pack=${packDir}`, `--test=${c.test}`, `--seed=${seed}`],
      { cwd: ctx.REPO, env: { ...process.env, TL_QUIET: "1", ...(godot ? { TL_GODOT: godot } : {}) } });
    let out = "";
    p.stdout.on("data", (d) => (out += d));
    p.stderr.on("data", () => {});
    p.on("error", () => res(""));
    p.on("close", () => res(out));
  });
}

/** deps = {ctx, runBot}: the test seam. Returns the exit code. */
export async function execute(args, deps = {}) {
  const ctx = deps.ctx ?? realCtx;
  let o;
  try { o = parseArgs(args); } catch (e) { return usage("ladder", `tl ladder: ${e.message}\n${USAGE}`); }
  const packDir = path.resolve(ctx.REPO, o.pack);
  if (!fs.existsSync(path.join(packDir, "pack.json"))) return couldNotRun("ladder", `tl ladder: no pack.json in ${packDir}`);
  const cells = findCells(packDir, o.cells);
  if (!deps.runBot && !ctx.resolveGodot()) return couldNotRun("ladder", "tl ladder: Godot not found (tl doctor)");
  const t0 = Date.now();
  const rows = cells.length ? await ladder(cells, o.seeds, o.par, deps.runBot ?? realRunBot(ctx, packDir)) : [];
  console.log(`level      hand      wins          win % (95 %)   goals for:against  frames  period 2  passes reached  down %  draws  taps lost  his shots`);
  for (const r of rows) console.log(`${r.level.padEnd(10)} ${r.hand.padEnd(9)} ${String(r.wins).padStart(3)} of ${String(r.completed).padEnd(4)}  ${String(r.pct).padStart(3)} (${r.lo}..${r.hi})`.padEnd(54) +
    `${r.gf.toFixed(2)} : ${r.ga.toFixed(2)}`.padEnd(19) + `${String(r.frames).padStart(6)}  ${String(r.period2).padStart(3)}/${r.completed}   ${r.reached}/${r.passes}`.padEnd(30) + `${String(r.down_pct).padEnd(7)}${String(r.draws).padEnd(7)}${String(r.taps_lost).padEnd(11)}${r.shots}`);
  const steps = rows.map((r) => ({ id: `ladder:${r.cell}`, ok: r.completed === r.found, ms: 0, found: r.found, completed: r.completed,
    detail: `${r.wins} of ${r.completed} won (${r.pct} %, ${r.lo}..${r.hi}) through the ${r.hand} hand${r.missing.length ? `; seeds not completed: ${r.missing.join(",")}` : ""}` }));
  if (!steps.length) steps.push({ id: "ladder", ok: false, ms: 0, found: 0, completed: 0, detail: `no bot_ladder_* test in ${path.join(o.pack, "pack.json")}: found 0 cells` });
  const cellsDone = rows.filter((r) => r.completed === r.found).length;
  return ctx.printVerdict("ladder", steps, { pack: o.pack, seeds: o.seeds, cells_found: rows.length, cells_completed: cellsDone, ms: Date.now() - t0,
    cells: rows.map(({ missing, test, ...r }) => r) });
}

export async function run(args, ctx) { return execute(args, { ctx }); }
