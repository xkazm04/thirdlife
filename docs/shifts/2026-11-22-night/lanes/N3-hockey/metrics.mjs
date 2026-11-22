// N3 (22 Nov): the five hockey bot metrics (docs/research/HOCKEY-ARCADE.md 5.5) over N seeds per cell.
// usage: node metrics.mjs --tree <worktree> [--seeds 20] [--par 6] [--cells pro_regular,ai_pro,..] [--out file.json]
// A cell is a test: <level>_<hand> -> tests/bot_ladder_<level>_<hand>.gd; ai_<level> -> tests/bot_metrics_ai.gd with
// the level tapped by the test itself (only pro is written; other ai levels are not cells). Each seed is one headless
// bot run; a run counts only when its verify line says bot.completed (a stopped run is never a sample).
import fs from "node:fs";
import path from "node:path";
import { spawn } from "node:child_process";

const a = process.argv.slice(2);
const opt = (k, d) => { const i = a.indexOf(k); return i >= 0 ? a[i + 1] : d; };
const tree = opt("--tree", process.cwd());
const seeds = Number(opt("--seeds", 20));
const par = Number(opt("--par", 6));
const cells = opt("--cells", "rookie_newcomer,pro_regular,allstar_sharp,pro_perfect,ai_pro").split(",");
const out = opt("--out", "");
const first = Number(opt("--first", 1));

function testOf(cell) {
  if (cell.startsWith("ai_")) return "tests/bot_metrics_ai.gd";
  return `tests/bot_ladder_${cell}.gd`;
}

function run(cell, seed) {
  return new Promise((res) => {
    const p = spawn("bash", [path.join(tree, "engine/tools/tl.sh"), "bot", `--pack=${path.join(tree, "engine/packs/hockey")}`, `--test=${testOf(cell)}`, `--seed=${seed}`],
      { env: { ...process.env, TL_QUIET: "1" } });
    let so = "";
    p.stdout.on("data", (d) => (so += d));
    p.stderr.on("data", () => {});
    p.on("close", (code) => {
      const line = so.split(/\r?\n/).filter((l) => l.startsWith("{")).reverse().find((l) => { try { return JSON.parse(l).schema === "tl.verify/1"; } catch { return false; } });
      if (!line) return res({ cell, seed, done: false, code });
      const v = JSON.parse(line);
      const done = (v.checks ?? []).some((c) => c.id === "bot.completed" && c.ok === true);
      const bad = (v.checks ?? []).filter((c) => c.ok !== true && c.id !== "bot.ok").map((c) => c.id);
      res({ cell, seed, done: done && bad.length === 0, bad, code, r: v.bot?.result ?? {}, hash: v.metrics?.state_hash });
    });
  });
}

const median = (xs) => { if (!xs.length) return NaN; const s = [...xs].sort((x, y) => x - y); const m = s.length >> 1; return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };
const f1 = (x) => (Number.isFinite(x) ? x.toFixed(1) : "-");
const pc = (x) => (Number.isFinite(x) ? Math.round(x * 100) + "%" : "-");

function aggregate(runs) {
  const ok = runs.filter((r) => r.done && r.r.metrics);
  const L = [], PP = [];
  let live = 0, passes = 0, comp = 0, shots = 0, slot = 0, ot = 0, after = 0, ozB = 0, ozR = 0, ent = 0, entOk = 0, goals = 0, wins = 0;
  const tov = {};
  const hits = { bump: 0, stumble: 0, knockdown: 0, cross: 0 };
  let crowd = 0, crowd4 = 0; const croles = {};
  const side = { blue: { shots: 0, passes: 0, comp: 0, tov: 0 }, red: { shots: 0, passes: 0, comp: 0, tov: 0 } };
  for (const r of ok) {
    const m = r.r.metrics;
    L.push(...m.lengths); PP.push(...m.poss_passes);
    live += m.live; after += m.after_shot;
    for (const s of ["blue", "red"]) {
      passes += m.passes[s]; comp += m.complete[s]; shots += m.shots[s]; slot += m.slot_shots[s]; ot += m.one_timers[s];
      ent += m.entries[s]; entOk += m.entries_ok[s];
      side[s].shots += m.shots[s]; side[s].passes += m.passes[s]; side[s].comp += m.complete[s];
    }
    ozB += m.oz.blue; ozR += m.oz.red;
    for (const [k, n] of Object.entries(m.turnovers)) tov[k] = (tov[k] ?? 0) + n;
    crowd += m.crowd_sum ?? 0; crowd4 += m.crowd4 ?? 0; for (const [k, n] of Object.entries(m.crowd_roles ?? {})) croles[k] = (croles[k] ?? 0) + n;
    for (const sd of Object.values(m.given ?? {})) for (const k of Object.keys(hits)) hits[k] += Number(sd[k] ?? 0);
    goals += (r.r.goals ?? 0) + (r.r.against ?? 0);
    if (r.r.won) wins++;
  }
  const mins = live / 3600;
  const tovN = Object.values(tov).reduce((x, y) => x + y, 0);
  const share = Object.fromEntries(Object.entries(tov).map(([k, n]) => [k, n / tovN]));
  return {
    runs: runs.length, completed: ok.length, wins,
    poss_median_s: median(L) / 60, poss_n: L.length,
    passes_per_poss: PP.length ? PP.reduce((x, y) => x + y, 0) / PP.length : NaN,
    completion: passes ? comp / passes : NaN,
    shots_per_min_team: mins ? shots / mins / 2 : NaN,
    shots_blue_per_min: mins ? side.blue.shots / mins : NaN, shots_red_per_min: mins ? side.red.shots / mins : NaN,
    slot_or_ot_share: shots ? Math.min(1, (slot + ot) / shots) : NaN, slot_share: shots ? slot / shots : NaN, ot_share: shots ? ot / shots : NaN,
    turnovers_per_min: mins ? tovN / mins : NaN, turnover_share: share, after_shot: after,
    oz_blue: live ? ozB / live : NaN, oz_red: live ? ozR / live : NaN,
    entry_success: ent ? entOk / ent : NaN, entries: ent,
    checks_per_min: mins ? (hits.stumble + hits.knockdown) / mins : NaN, bumps_per_min: mins ? hits.bump / mins : NaN, knockdowns_per_min: mins ? hits.knockdown / mins : NaN,
    crowd_mean: live ? crowd / live : NaN, scrum_share: live ? crowd4 / live : NaN, scrum_roles: croles,
    goals_how: ok.flatMap((r) => (r.r.metrics.goals_how ?? []).map((g) => `${r.seed}:${g.join("/")}`)),
    goals_per_game: ok.length ? goals / ok.length : NaN,
    hashes: ok.map((r) => `${r.seed}:${(r.hash ?? "").slice(0, 12)}`),
  };
}

function line(cell, g) {
  const sh = Object.entries(g.turnover_share).sort((x, y) => y[1] - x[1]).map(([k, v]) => `${k} ${pc(v)}`).join(", ");
  return `| ${cell} | ${g.completed}/${g.runs} | ${g.wins} | ${f1(g.poss_median_s)} s | ${f1(g.passes_per_poss)} / ${pc(g.completion)} | ${f1(g.shots_per_min_team)} (b ${f1(g.shots_blue_per_min)}, r ${f1(g.shots_red_per_min)}) / ${pc(g.slot_or_ot_share)} (ot ${pc(g.ot_share)}) | ${f1(g.turnovers_per_min)}/min: ${sh} | ${pc(g.oz_blue / (g.oz_blue + g.oz_red))} / ${pc(g.oz_red / (g.oz_blue + g.oz_red))} (raw ${pc(g.oz_blue)} / ${pc(g.oz_red)}), entry ${pc(g.entry_success)} | ${f1(g.goals_per_game)} | ${f1(g.checks_per_min)} (down ${f1(g.knockdowns_per_min)}, bump ${f1(g.bumps_per_min)}) | ${f1(g.crowd_mean)} / ${pc(g.scrum_share)} |`;
}

const jobs = [];
for (const c of cells) for (let s = first; s < first + seeds; s++) jobs.push([c, s]);
const results = [];
let next = 0;
async function worker() { while (next < jobs.length) { const [c, s] = jobs[next++]; results.push(await run(c, s)); } }
const t0 = Date.now();
await Promise.all(Array.from({ length: par }, worker));
const table = {};
console.log("| cell | completed | blue wins | possession median (4-10 s) | passes per poss (1.5-3) / completion (70-85%) | shots/min/team (1.5-3) / slot+OT (>=40%) | turnovers by cause (none >45%, self <15%, bobble <15%) | OZ share blue / red = OZ / (OZ + DZ) (35-55%), entry (50-70%) | goals/game (3-7) | checks/min: stumble+down (down, bump) | near the puck (5 m) / scrum share (>=4) |");
console.log("|---|---|---|---|---|---|---|---|---|---|---|");
for (const c of cells) {
  const g = aggregate(results.filter((r) => r.cell === c));
  table[c] = g;
  console.log(line(c, g));
  const bad = results.filter((r) => r.cell === c && !r.done);
  if (bad.length) console.log(`  ${c}: NOT COMPLETED seeds ${bad.map((r) => `${r.seed}(${r.code};${(r.bad ?? []).join("/")})`).join(" ")}`);
}
console.log(`elapsed ${Math.round((Date.now() - t0) / 1000)} s, ${results.length} runs`);
if (out) fs.writeFileSync(out, JSON.stringify({ seeds, first, cells, table, runs: results.map((r) => ({ cell: r.cell, seed: r.seed, done: r.done, hash: r.hash, won: r.r?.won, goals: r.r?.goals, against: r.r?.against, metrics: r.r?.metrics })) }, null, 1));
