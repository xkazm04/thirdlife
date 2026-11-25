#!/usr/bin/env node
// Third Life rink core, LAB (lane K4): the tables of docs/research/hockey-teardown/PLAY.md from the raw cells (.tl/k4/raw).
//   node engine/cores/rink/lab/tables.mjs [--raw .tl/k4/raw] [--media docs/research/hockey-teardown/media]
// Writes media/play_ladder.json, play_ablate.json, play_only.json, play_signal.json (every cell's figures) and prints the markdown tables.
// Differences are paired by seed against the full hand of the same level (the same 200 seeds): d = mean of (variant - full) per match,
// se = its standard error; "*" marks |d| >= 2 se.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { plan, readCell, summarize, paired, VERBS, ONLY } from "./cells.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..", "..", "..");
const argv = process.argv.slice(2);
const opt = (k, d) => { const i = argv.indexOf(`--${k}`); return i >= 0 ? argv[i + 1] : d; };
const raw = path.resolve(root, opt("raw", ".tl/k4/raw"));
const media = path.resolve(root, opt("media", "docs/research/hockey-teardown/media"));
const SEEDS = "1-200";
const LV = ["rookie", "pro", "all_star"], LS = { rookie: "R", pro: "P", all_star: "A" };
const load = (id) => readCell(path.join(raw, `${id}.${SEEDS}.jsonl`));
const win = (x) => (x.pt.result === "win" ? 1 : 0);
const gd = (x) => x.pt.goals[0] - x.pt.goals[1];
const perMin = (f) => (x) => f(x) / (x.pt.play_frames / 3600);
const fmt = (p, scale = 1, dig = 0) => (p.n ? `${(p.d * scale).toFixed(dig)}${Math.abs(p.d) >= 2 * p.se && p.se > 0 ? "*" : ""}` : "-");
const dump = (name, obj) => { fs.mkdirSync(media, { recursive: true }); fs.writeFileSync(path.join(media, name), JSON.stringify(obj, null, 1) + "\n"); };
const strip = (s) => { const o = { ...s }; delete o.hashes; return o; };

// ---- the ladder
const ladder = {};
for (const c of plan("ladder")) ladder[c.id] = { ...c, ...strip(summarize(load(c.id))) };
dump("play_ladder.json", ladder);
console.log("\n### ladder\n");
console.log("| hand | level | wins % | loss % | goal diff | goals for / against a min | first goal for (median s; share of matches) | first goal against (s) | possession % | the hand's shots / min | opp shots / min | match (s) |");
console.log("|---|---|---|---|---|---|---|---|---|---|---|---|");
for (const p of ["regular.x-idle", "novice", "regular", "good"]) for (const l of LV) {
  const s = ladder[`${l}.${p}`];
  console.log(`| ${p === "regular.x-idle" ? "idle" : p} | ${l} | ${s.win_pct} ±${s.win_se} | ${s.loss_pct} | ${s.gd.toFixed(2)} | ${s.gf_min} / ${s.ga_min} | ${s.first_goal_for_s} (${s.first_goal_for_share} %) | ${s.first_goal_against_s} | ${s.poss_pct} | ${s.shots_min} | ${s.opp_shots_min} | ${s.match_s} |`);
}

// ---- the ablations
const abl = {};
const full = {};
for (const l of LV) for (const p of ["regular", "good"]) full[`${l}.${p}`] = load(`${l}.${p}`);
console.log("\n### ablate: wins (percentage points) and goal difference, paired against the full hand\n");
console.log("| verb removed | regular R / P / A: wins pp | regular: goal diff | good R / P / A: wins pp | good: goal diff | presses it lost a match (regular, pro) |");
console.log("|---|---|---|---|---|---|");
for (const v of VERBS) {
  const cells = {};
  const w = { regular: [], good: [] }, g = { regular: [], good: [] };
  let removed = "";
  for (const p of ["regular", "good"]) for (const l of LV) {
    const id = `${l}.${p}.x-${v}`;
    const rows = load(id);
    const s = strip(summarize(rows));
    const f = full[`${l}.${p}`];
    const pw = paired(rows, f, win), pg = paired(rows, f, gd);
    const extra = {
      d_poss: paired(rows, f, (x) => { const t = x.lab.team_frames; return t[0] + t[1] ? (100 * t[0]) / (t[0] + t[1]) : 50; }),
      d_ga_min: paired(rows, f, perMin((x) => x.pt.goals[1])), d_gf_min: paired(rows, f, perMin((x) => x.pt.goals[0])),
      d_lost_min: paired(rows, f, perMin((x) => x.lab.carry_end.lost)), d_shots_min: paired(rows, f, perMin((x) => x.pt.shots)),
      d_kd_match: paired(rows, f, (x) => x.pt.knockdowns),
    };
    let ident = 0; for (const [sd, a] of rows) if (f.get(sd)?.pt.hash === a.pt.hash) ident++;
    cells[id] = { ...s, d_win: pw, d_gd: pg, ...extra, identical_matches: ident };
    w[p].push(fmt(pw, 100)); g[p].push(fmt(pg, 1, 2));
    if (p === "regular" && l === "pro") removed = s.n ? `${s.removed_match}${ident === s.n ? ` (all ${s.n} matches identical)` : ident ? ` (${ident} of ${s.n} identical)` : ""}` : "-";
  }
  abl[v] = cells;
  console.log(`| ${v} | ${w.regular.join(" / ")} | ${g.regular.join(" / ")} | ${w.good.join(" / ")} | ${g.good.join(" / ")} | ${removed} |`);
}
dump("play_ablate.json", abl);
console.log("\n### ablate: what moved (regular hand, pro; per minute of play unless said)\n");
console.log("| verb removed | possession pp | goals for / min | goals against / min | the hand's shots / min | carries lost / min | knockdowns taken a match |");
console.log("|---|---|---|---|---|---|---|");
for (const v of VERBS) {
  const c = abl[v][`pro.regular.x-${v}`];
  console.log(`| ${v} | ${fmt(c.d_poss, 1, 1)} | ${fmt(c.d_gf_min, 1, 2)} | ${fmt(c.d_ga_min, 1, 2)} | ${fmt(c.d_shots_min, 1, 2)} | ${fmt(c.d_lost_min, 1, 2)} | ${fmt(c.d_kd_match, 1, 2)} |`);
}

// ---- skating plus one verb
const only = {};
console.log("\n### only: skating and the stick's aim plus the named verbs (wins %, pro / all_star)\n");
console.log("| hand keeps | regular P / A | good P / A |");
console.log("|---|---|---|");
const LV2 = ["pro", "all_star"];
const idleRow = LV2.map((l) => ladder[`${l}.regular.x-idle`].win_pct).join(" / ");
console.log(`| nothing (idle) | ${idleRow} | ${idleRow} |`);
for (const o of ONLY) {
  const row = {};
  for (const p of ["regular", "good"]) row[p] = LV2.map((l) => { const id = `${l}.${p}.only-${o.replace(/,/g, "+")}`; const s = strip(summarize(load(id))); only[id] = s; return s.n ? s.win_pct : "-"; }).join(" / ");
  console.log(`| ${o === "none" ? "skating only" : o.replace(/,/g, " + ")} | ${row.regular} | ${row.good} |`);
}
console.log(`| everything (full hand) | ${LV2.map((l) => ladder[`${l}.regular`].win_pct).join(" / ")} | ${LV2.map((l) => ladder[`${l}.good`].win_pct).join(" / ")} |`);
dump("play_only.json", only);

// ---- the signal
const sig = {};
const sigCells = plan("signal");
if (sigCells.some((c) => fs.existsSync(path.join(raw, `${c.id}.${SEEDS}.jsonl`)))) {
  console.log("\n### signal held all match (paired against the full hand)\n");
  console.log("| signal | hand | level | wins pp | goal diff | passes received a match |");
  console.log("|---|---|---|---|---|---|");
  for (const c of sigCells) {
    const rows = load(c.id);
    const f = full[`${c.level}.${c.player}`];
    const s = strip(summarize(rows));
    const pw = paired(rows, f, win), pg = paired(rows, f, gd), pr = paired(rows, f, (x) => x.pt.passes_received);
    sig[c.id] = { ...s, d_win: pw, d_gd: pg, d_received: pr };
    console.log(`| ${c.signal} | ${c.player} | ${c.level} | ${fmt(pw, 100)} | ${fmt(pg, 1, 2)} | ${fmt(pr, 1, 2)} |`);
  }
  dump("play_signal.json", sig);
}
