#!/usr/bin/env node
// Third Life rink core, LAB (lane K4 "reference"): runs and tabulates cells of thirdjam playtester matches through rinklab.exe.
// Measurement only. A cell = cartridge x difficulty x hand x what the hand lost (rinklab -remove / -only) x seeds.
//
//   node engine/cores/rink/lab/cells.mjs run <plan> [--seeds 1-200] [--jobs 6] [--out .tl/k4/raw]
//   node engine/cores/rink/lab/cells.mjs table <plan> [--seeds 1-200] [--out .tl/k4/raw] [--json file]
// Plans: ladder (idle / novice / regular / good x rookie / pro / all_star), ablate (regular and good x the three levels x each verb
// removed), only (regular and good x the three levels x skating plus one verb), signal (the team signal held), balance (the harness's subset).
// Every hand presses sprint (-playersprint: the game the owner played has it; the novice's profile never sprints anyway).
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..", "..", "..");
const exe = path.join(here, "bin", "rinklab.exe");
const content = path.join(root, "engine", "cores", "rink", "native", "content");

const LEVELS = ["rookie", "pro", "all_star"];
export const VERBS = ["sprint", "brake", "stop", "deke", "spin", "shield", "stick", "pass", "saucer", "onetimer", "tap", "charge", "shoot",
  "poke", "lift", "check", "brace", "ability", "draw"];
export const ONLY = ["none", "shoot", "pass", "pass,shoot", "check", "lift", "poke", "lift,check,poke,brace"];

export function plan(name) {
  const cells = [];
  const add = (level, player, remove, only, signal) => cells.push({ level, player, remove: remove || "", only: only || "", signal: signal || "",
    id: `${level}.${player}${remove ? ".x-" + remove.replace(/,/g, "+") : ""}${only ? ".only-" + only.replace(/,/g, "+") : ""}${signal ? ".sig-" + signal : ""}` });
  if (name === "ladder") {
    for (const l of LEVELS) { add(l, "regular", "idle"); for (const p of ["novice", "regular", "good"]) add(l, p); }
  } else if (name === "ablate") {
    for (const l of LEVELS) for (const p of ["regular", "good"]) for (const v of VERBS) add(l, p, v);
  } else if (name === "only") {
    // pro and all_star: at rookie both full hands win every match and the idle hand wins 60 % (no room to show a verb).
    for (const l of ["pro", "all_star"]) for (const p of ["regular", "good"]) for (const o of ONLY) add(l, p, "", o);
  } else if (name === "signal") {
    // The team signal the playtester never gives (thirdjam's HUD verb), held all match: pass at every level for both hands, the other three at pro.
    for (const l of LEVELS) for (const p of ["regular", "good"]) add(l, p, "", "", "pass");
    for (const k of ["defend", "space", "praise"]) add("pro", "regular", "", "", k);
  } else if (name === "diag") {
    // the draw: the full hands and the hands that never take it, re-run for the draw counters (same matches, hash for hash)
    for (const l of ["pro", "all_star"]) for (const p of ["regular", "good"]) { add(l, p); add(l, p, "draw"); }
  } else if (name === "balance") {
    // The harness: the ladder's three hands at pro and all_star, idle at pro, and the five most telling ablations (regular, pro).
    for (const l of ["pro", "all_star"]) for (const p of ["novice", "regular", "good"]) add(l, p);
    add("pro", "regular", "idle");
    // the stick's aim (the largest loss), the stop and the sprint (the feet), the pass (its loss is a gain) and the shot (its loss costs little)
    for (const v of ["stick", "stop", "sprint", "pass", "shoot"]) add("pro", "regular", v);
  } else throw new Error(`unknown plan ${name}`);
  return cells;
}

function args(argv) {
  const a = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith("--")) { a[argv[i].slice(2)] = argv[i + 1]; i++; } else a._.push(argv[i]);
  }
  return a;
}

export function runCell(cell, seeds, outDir) {
  return new Promise((resolve) => {
    const file = path.join(outDir, `${cell.id}.${seeds}.jsonl`);
    const a = ["match", content, "-cartridge=hockey.regular", `-seeds=${seeds}`, `-difficulty=${cell.level}`, `-player=${cell.player}`, "-playersprint"];
    if (cell.remove) a.push(`-remove=${cell.remove}`);
    if (cell.only) a.push(`-only=${cell.only === "none" ? "none" : cell.only}`);
    if (cell.signal) a.push(`-signal=${cell.signal}`);
    const out = fs.createWriteStream(file);
    const p = spawn(exe, a, { stdio: ["ignore", "pipe", "pipe"] });
    let buf = "";
    p.stdout.on("data", (d) => { buf += d.toString(); let i; while ((i = buf.indexOf("\n")) >= 0) { const l = buf.slice(0, i).trim(); buf = buf.slice(i + 1); if (l.startsWith("{")) out.write(l + "\n"); } });
    p.on("close", (code) => { out.end(() => resolve({ cell, file, code })); });
  });
}

export async function runAll(cells, seeds, outDir, jobs) {
  fs.mkdirSync(outDir, { recursive: true });
  const queue = cells.slice();
  const results = [];
  const worker = async () => { while (queue.length) { const c = queue.shift(); const t0 = Date.now(); const r = await runCell(c, seeds, outDir); results.push(r);
    console.log(`${r.code === 0 ? "done" : "FAIL"}  ${c.id}  ${((Date.now() - t0) / 1000).toFixed(0)} s`); } };
  await Promise.all(Array.from({ length: Math.max(1, jobs) }, worker));
  return results;
}

const mean = (xs) => (xs.length ? xs.reduce((s, x) => s + x, 0) / xs.length : NaN);
const sd = (xs) => { const m = mean(xs); return xs.length > 1 ? Math.sqrt(xs.reduce((s, x) => s + (x - m) ** 2, 0) / (xs.length - 1)) : 0; };
const median = (xs) => { if (!xs.length) return NaN; const s = xs.slice().sort((a, b) => a - b); return s[Math.floor(s.length / 2)]; };
const r = (x, d = 2) => (Number.isFinite(x) ? Number(x.toFixed(d)) : null);

// Reads a cell's raw lines: pairs of thirdjam.playtest/1 and rinklab.cell/1, by seed.
export function readCell(file) {
  const rows = new Map();
  if (!fs.existsSync(file)) return rows;
  for (const l of fs.readFileSync(file, "utf8").split("\n")) {
    if (!l.trim()) continue;
    const j = JSON.parse(l);
    if (j.tool === "thirdjam.playtest/1") rows.set(j.seed, { pt: j });
    else if (j.tool === "rinklab.cell/1" && rows.has(j.seed)) rows.get(j.seed).lab = j.stats;
  }
  return rows;
}

// One cell's figures. Minutes are minutes of live play (play_frames / 3600).
export function summarize(rows) {
  const v = [...rows.values()].filter((x) => x.pt && x.lab);
  const n = v.length;
  const wins = v.filter((x) => x.pt.result === "win").length, losses = v.filter((x) => x.pt.result === "loss").length;
  const gd = v.map((x) => x.pt.goals[0] - x.pt.goals[1]);
  const mins = v.map((x) => x.pt.play_frames / 3600);
  const totMin = mins.reduce((s, x) => s + x, 0);
  const sum = (f) => v.reduce((s, x) => s + f(x), 0);
  const ffg = v.map((x) => x.pt.first_goal_for).filter((x) => x >= 0);
  const fga = v.map((x) => x.pt.first_goal_against).filter((x) => x >= 0);
  const poss = v.map((x) => { const t = x.lab.team_frames; return t[0] + t[1] > 0 ? t[0] / (t[0] + t[1]) : 0.5; });
  const press = {};
  for (const k of Object.keys(v[0]?.lab.press || {})) press[k] = r(sum((x) => x.lab.press[k]) / totMin, 2);
  return {
    n, win_pct: r((100 * wins) / n, 1), loss_pct: r((100 * losses) / n, 1), win_se: r(100 * Math.sqrt((wins / n) * (1 - wins / n) / n), 1),
    gd: r(mean(gd), 3), gd_sd: r(sd(gd), 3),
    gf_min: r(sum((x) => x.pt.goals[0]) / totMin, 3), ga_min: r(sum((x) => x.pt.goals[1]) / totMin, 3),
    human_goals_match: r(sum((x) => x.pt.goals_by_human) / n, 3),
    match_s: r(mean(v.map((x) => x.pt.frames / 60)), 1), play_s: r(mean(v.map((x) => x.pt.play_frames / 60)), 1),
    first_goal_for_s: r(median(ffg) / 60, 1), first_goal_for_share: r((100 * ffg.length) / n, 1), first_goal_against_s: r(median(fga) / 60, 1),
    poss_pct: r(100 * mean(poss), 1),
    hold_pct: r(100 * sum((x) => x.pt.hold_frames[0]) / sum((x) => x.pt.hold_frames[0] + x.pt.hold_frames[1] + x.pt.hold_frames[2]), 1),
    shots_min: r(sum((x) => x.pt.shots) / totMin, 2), shots_on_target_pct: r((100 * sum((x) => x.pt.shots_on_target)) / Math.max(1, sum((x) => x.pt.shots)), 1),
    team_shots_min: r(sum((x) => x.lab.shots[0]) / totMin, 2), opp_shots_min: r(sum((x) => x.lab.shots[1]) / totMin, 2),
    touches_min: r(sum((x) => x.pt.touches) / totMin, 2),
    carries_min: r(sum((x) => x.lab.carries) / totMin, 2), carry_s: r(sum((x) => x.lab.carry_frames) / Math.max(1, sum((x) => x.lab.carries)) / 60, 2),
    carries_lost_min: r(sum((x) => x.lab.carry_end.lost) / totMin, 2),
    carry_end: Object.fromEntries(["shot", "pass", "lost", "kept", "goal"].map((k) => [k, r(sum((x) => x.lab.carry_end[k]) / Math.max(1, sum((x) => x.lab.carries)) * 100, 1)])),
    passes_min: r(sum((x) => x.pt.passes) / totMin, 2), passes_completed_pct: r((100 * sum((x) => x.lab.passes_completed)) / Math.max(1, sum((x) => x.lab.passes_completed + x.lab.passes_intercepted)), 1),
    spell_s: r(sum((x) => x.lab.spell_frames[0] + x.lab.spell_frames[1]) / Math.max(1, sum((x) => x.lab.spells[0] + x.lab.spells[1])) / 60, 2),
    changes_min: r(sum((x) => x.lab.changes) / totMin, 2),
    event_gap_s: r(mean(v.map((x) => x.lab.gap_mean)) / 60, 2), long_gaps_match: r(sum((x) => x.lab.long_gaps) / n, 2),
    hits_landed_min: r(sum((x) => x.lab.hits_landed) / totMin, 2),
    human_hits_min: r(sum((x) => x.pt.cross_landed + x.pt.checks_landed) / totMin, 2),
    human_knockdowns_match: r(sum((x) => x.pt.knockdowns) / n, 2),
    pokes_clean_min: r(sum((x) => x.pt.pokes_clean) / totMin, 2), lifts_min: r(sum((x) => x.pt.lifts) / totMin, 2),
    dekes_min: r(sum((x) => x.pt.dekes) / totMin, 2), spins_min: r(sum((x) => x.pt.acts?.spin ?? 0) / totMin, 2), one_timers_match: r(sum((x) => x.pt.one_timers) / n, 2),
    sprint_share_pct: r((100 * sum((x) => x.pt.sprint_frames)) / sum((x) => x.pt.play_frames), 1),
    human_max_mps: r(Math.max(...v.map((x) => x.lab.human_max)), 2), human_mean_mps: r(mean(v.map((x) => x.lab.human_mean)), 2),
    bot_max_mps: [r(Math.max(...v.map((x) => x.lab.bot_max[0])), 2), r(Math.max(...v.map((x) => x.lab.bot_max[1])), 2)],
    bot_mean_mps: [r(mean(v.map((x) => x.lab.bot_mean[0])), 2), r(mean(v.map((x) => x.lab.bot_mean[1])), 2)],
    bot_fast_pct: [r(100 * mean(v.map((x) => x.lab.bot_fast_share[0])), 1), r(100 * mean(v.map((x) => x.lab.bot_fast_share[1])), 1)],
    human_fast_pct: r((100 * sum((x) => x.lab.human_fast)) / sum((x) => x.lab.play_frames), 1),
    presses_min: press, presses_total_min: r(Object.values(press).reduce((s, x) => s + (x || 0), 0) - (press.stop || 0), 1),
    removed_match: r(sum((x) => x.lab.removed) / n, 1),
    pile_pct: r((100 * sum((x) => x.lab.pile_frames ?? NaN)) / sum((x) => x.lab.play_frames), 1),
    scrum_pct: r((100 * sum((x) => x.lab.scrum_frames ?? NaN)) / sum((x) => x.lab.play_frames), 1),
    dead_puck_pct: r((100 * sum((x) => x.lab.dead_puck_frames ?? NaN)) / sum((x) => x.lab.play_frames), 1),
    dead_spells_min: r(sum((x) => x.lab.dead_spells ?? NaN) / totMin, 2),
    board_puck_pct: r((100 * sum((x) => x.lab.board_puck_frames ?? NaN)) / sum((x) => x.lab.play_frames), 1),
    loose_pct: r((100 * sum((x) => x.lab.loose_frames ?? NaN)) / sum((x) => x.lab.play_frames), 1),
    idle_spells_match: r(sum((x) => x.pt.idle_spells) / n, 2), max_no_touch_s: r(mean(v.map((x) => x.pt.max_no_touch)) / 60, 1),
    hashes: v.map((x) => x.pt.hash),
  };
}

// Paired by seed against a reference cell: the mean difference and its standard error (same seeds both sides).
export function paired(rowsA, rowsB, f) {
  const d = [];
  for (const [s, a] of rowsA) { const b = rowsB.get(s); if (a.pt && a.lab && b?.pt && b?.lab) d.push(f(a) - f(b)); }
  return { n: d.length, d: r(mean(d), 3), se: r(sd(d) / Math.sqrt(Math.max(1, d.length)), 3) };
}

async function main() {
  const a = args(process.argv.slice(2));
  const [cmd, name] = a._;
  const seeds = a.seeds || "1-200";
  const outDir = path.resolve(root, a.out || ".tl/k4/raw");
  if (!fs.existsSync(exe)) { console.log("NOT RUN  rinklab.exe is not built (engine/tools/rink.sh lab-build)"); process.exit(2); }
  const cells = plan(name);
  if (cmd === "run") {
    const res = await runAll(cells, seeds, outDir, Number(a.jobs || 6));
    const bad = res.filter((x) => x.code !== 0);
    console.log(`${bad.length ? "FAIL" : "PASS"}  cells ${name}: ${res.length - bad.length} of ${res.length} ran`);
    process.exit(bad.length ? 1 : 0);
  } else if (cmd === "table") {
    const out = {};
    for (const c of cells) {
      const rows = readCell(path.join(outDir, `${c.id}.${seeds}.jsonl`));
      const s = summarize(rows);
      delete s.hashes;
      out[c.id] = { ...c, ...s };
    }
    const txt = JSON.stringify(out, null, 1);
    if (a.json) fs.writeFileSync(path.resolve(root, a.json), txt + "\n");
    else console.log(txt);
  } else { console.log("usage: cells.mjs run|table <plan> [--seeds a-b] [--jobs n]"); process.exit(2); }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
