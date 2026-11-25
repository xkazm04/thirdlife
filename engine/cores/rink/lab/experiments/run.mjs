#!/usr/bin/env node
// Third Life rink core, LAB (lane K8 "balance"): the experiment runner. One change at a time, measured before and after by both kinds of hand.
//
//   node engine/cores/rink/lab/experiments/run.mjs run <id> [--seeds 1-60] [--jobs 8] [--cells screen|ladder|matrix]
//   node engine/cores/rink/lab/experiments/run.mjs apply <id>     a kept experiment's change is folded into hockey.thirdlife's two files
//   node engine/cores/rink/lab/experiments/run.mjs ledger         LEDGER.md from every <id>.json (the ledger is a view of the files, never typed)
//   node engine/cores/rink/lab/experiments/run.mjs arm <name> [--cells ...] [--seeds ...]   measure one cartridge as it is on disk (hockey.regular | hockey.thirdlife)
//
// An experiment is experiments/<id>.json: { id, title, hypothesis, targets, tempo, ablate: [verbs], change: { rules, game, levels }, verdict, why, owner_line }.
//   change.rules   switches of native/patches-thirdlife (the cartridge's rules sidecar: lab_rules.h)
//   change.game    a JSON merge into the cartridge's `game` object (thirdjam's own cartridge numbers)
//   change.levels  { rookie | pro | all_star: "k=v;k=v" } thirdjam's difficulty tune keys, appended to the level's line in the sidecar
// "before" is hockey.thirdlife as it is on disk (every kept change so far); "after" is that plus the change. Both arms run on rinklab-thirdlife.exe (whose
// parity with thirdjam is rink.sh balance-thirdlife --parity), the same seeds, so every difference is paired match for match.
// An arm's raw output is kept under .tl/k8/arms/<hash of its two files and the runner> and reused: the next experiment's "before" is the last one's "after".
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { cfg, runAll, readCell, summarize, paired } from "../cells.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..", "..", "..", "..");
const exe = path.join(here, "..", "bin", "rinklab-thirdlife.exe");
const contentSrc = path.join(root, "engine", "cores", "rink", "native", "content");
const CART = "hockey.thirdlife";
const argv = process.argv.slice(2);
const opt = (k, d) => { const i = argv.indexOf(`--${k}`); return i >= 0 ? argv[i + 1] : d; };
const SEEDS = opt("seeds", "1-60");
const JOBS = Number(opt("jobs", 8));

const cellOf = (id) => {
  // "pro.plan-regular.x-shoot" | "rookie.regular.x-idle" | "pro.good.only-none"
  const [level0, hand, ...rest] = id.split(".");
  const level = level0;
  const c = { level, player: "regular", plan: "", remove: "", only: "", signal: "", id };
  if (hand.startsWith("plan-")) c.plan = hand.slice(5); else c.player = hand;
  for (const r of rest) { if (r.startsWith("x-")) c.remove = r.slice(2).replace(/\+/g, ","); else if (r.startsWith("only-")) c.only = r.slice(5).replace(/\+/g, ",");
    else if (r.startsWith("k-")) { c.remove = r.slice(2).replace(/\+/g, ","); c.extra = ["-plankeep"]; } }
  return c;
};
const SETS = {
  // the screen of every experiment: both kinds of hand where the game can show (pro), the two ends of the ladder, the idle hand at rookie
  screen: ["rookie.regular.x-idle", "rookie.plan-novice", "pro.novice", "pro.regular", "pro.good", "pro.plan-novice", "pro.plan-regular", "pro.plan-good",
    "all_star.regular", "all_star.plan-regular"],
  // the whole ladder, both kinds of hand
  ladder: ["rookie", "pro", "all_star"].flatMap((l) => [`${l}.regular.x-idle`, `${l}.novice`, `${l}.regular`, `${l}.good`, `${l}.plan-novice`, `${l}.plan-regular`, `${l}.plan-good`]),
};
export const MATRIX_VERBS = ["sprint", "stop", "shield", "pass", "onetimer", "tap", "charge", "shoot", "deke", "spin", "poke", "lift", "check", "brace"];
// the planning hand's own ablation at pro (its validation on hockey.regular, and the dead-verb verdict on hockey.thirdlife)
SETS.pablate = ["pro.plan-regular", ...MATRIX_VERBS.map((v) => `pro.plan-regular.x-${v}`), "pro.plan-regular.x-draw", "pro.plan-regular.only-none"];
// the planning hand's calibration cells (on hockey.regular: the one number it is fitted to, and the ladder's corners)
SETS.pcal = ["pro.plan-novice", "pro.plan-regular", "pro.plan-good", "all_star.plan-regular", "rookie.plan-novice"];
// the mid-round matrix: the ladder by the planning hand, the screen's scripted cells, and the planning hand without each verb at pro
SETS.mid = [...new Set([...SETS.screen, "rookie.plan-regular", "rookie.plan-good", "all_star.plan-novice", "all_star.plan-good", ...SETS.pablate, "pro.regular.x-pass", "pro.regular.x-check", "pro.regular.x-brace"])];
// an experiment that names all its own cells (exp.cells)
SETS.none = [];
// the final matrix (round 3, 200 seeds): the ladder by both kinds of hand, the idle hand at every level, and the planning hand at pro without each
// verb twice over: "x-" = out of its menu and its keys (it re-plans: leans toward "costs nothing"), "k-" = still in its menu and pressed, the game never
// hears it (K4's ablation on this hand: leans toward "vital"). The truth of a verb lies between the two.
export const FINAL_VERBS = ["sprint", "stop", "shield", "pass", "onetimer", "tap", "charge", "deke", "spin", "poke", "lift", "check", "brace"];
SETS.final = [...SETS.ladder, "pro.plan-regular.x-shoot", ...FINAL_VERBS.map((v) => `pro.plan-regular.x-${v}`), ...FINAL_VERBS.map((v) => `pro.plan-regular.k-${v}`),
  "pro.regular.x-pass", "pro.regular.x-shoot"];
// the same hand's ladder on hockey.regular, for the column beside it
SETS.pladder = ["rookie", "pro", "all_star"].flatMap((l) => [`${l}.regular.x-idle`, `${l}.plan-novice`, `${l}.plan-regular`, `${l}.plan-good`]);
SETS.matrix = [...SETS.ladder, ...MATRIX_VERBS.flatMap((v) => [`pro.plan-regular.x-${v}`, `pro.regular.x-${v}`]), "pro.plan-regular.only-none", "pro.regular.only-none"];

const readJson = (f) => JSON.parse(fs.readFileSync(f, "utf8"));
const merge = (a, b) => {
  if (b === null || typeof b !== "object" || Array.isArray(b)) return b;
  const o = a && typeof a === "object" && !Array.isArray(a) ? { ...a } : {};
  for (const [k, v] of Object.entries(b)) o[k] = merge(o[k], v);
  return o;
};
function armFiles(name, change) {
  const cart = readJson(path.join(contentSrc, "Cartridges", `${name}.cartridge.json`));
  const rf = path.join(contentSrc, "Cartridges", `${name}.rules.json`);
  let rules = fs.existsSync(rf) ? readJson(rf) : { schema: "tl.rink.rules/1", rules: {}, levels: {} };
  if (change) {
    if (change.game) cart.game = merge(cart.game, change.game);
    if (change.rules) rules = { ...rules, rules: { ...(rules.rules || {}), ...change.rules } };
    if (change.levels) { const lv = { ...(rules.levels || {}) }; for (const [l, t] of Object.entries(change.levels)) lv[l] = [lv[l], t].filter(Boolean).join(";"); rules = { ...rules, levels: lv }; }
  }
  return { cart, rules };
}
// An arm is named by what it plays (the cartridge's game, its rule switches, its level tunes) and by EPOCH, which this lane bumps whenever the planning
// hand or the code behind an existing switch changes (a new patch with its switch off changes no arm: rink.sh balance-thirdlife --parity proves that for
// the switch-less game). Each arm keeps the hash of the runner that measured it; a different runner on a kept arm is said aloud.
const EPOCH = "k8-4";   // k8-1: the first form of patch 0002 (E01); k8-2: patch 0002 rewritten (E01b .. E05); k8-3: the planning hand presses its poke, lift and check at once and lets go of a spent brace (round 2, after E05); k8-4: that hand with its limits fitted again (reaction 28 / 22 / 14 frames)
function armDir(files) {
  const exeSha = crypto.createHash("sha1").update(fs.readFileSync(exe)).digest("hex").slice(0, 12);
  const key = crypto.createHash("sha1").update(JSON.stringify(files.cart.game) + "|" + JSON.stringify(files.rules.rules || {}) + "|" + JSON.stringify(files.rules.levels || {}) + "|" + EPOCH).digest("hex").slice(0, 12);
  const dir = path.join(root, ".tl", "k8", "arms", key);
  const metaFile = path.join(dir, "runner.json");
  if (fs.existsSync(metaFile)) { const m = JSON.parse(fs.readFileSync(metaFile, "utf8")); if (m.exe !== exeSha) console.log(`note  arm ${key} was measured on runner ${m.exe}; the runner is now ${exeSha} (same EPOCH ${EPOCH}: its cells are reused)`); }
  else { fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(metaFile, JSON.stringify({ exe: exeSha, epoch: EPOCH })); }
  const cdir = path.join(dir, "content", "Cartridges");
  if (!fs.existsSync(path.join(cdir, `${CART}.cartridge.json`))) {
    fs.mkdirSync(cdir, { recursive: true });
    fs.cpSync(path.join(contentSrc, "Designer"), path.join(dir, "content", "Designer"), { recursive: true });
    fs.writeFileSync(path.join(cdir, `${CART}.cartridge.json`), JSON.stringify(files.cart, null, 2) + "\n");
    fs.writeFileSync(path.join(cdir, `${CART}.rules.json`), JSON.stringify(files.rules, null, 2) + "\n");
  }
  return { key, dir, content: path.join(dir, "content"), raw: path.join(dir, "raw") };
}
const nSeeds = (s) => { const [a, b] = s.split("-").map(Number); return (b ?? a) - a + 1; };
async function runArm(arm, ids) {
  cfg.exe = exe; cfg.content = arm.content; cfg.cartridge = CART; cfg.extra = [];
  const want = nSeeds(SEEDS);
  const todo = ids.map(cellOf).filter((c) => readCell(path.join(arm.raw, `${c.id}.${SEEDS}.jsonl`)).size < want || [...readCell(path.join(arm.raw, `${c.id}.${SEEDS}.jsonl`)).values()].some((x) => !x.lab));
  if (todo.length) {
    const log = console.log; console.log = () => {};
    const res = await runAll(todo, SEEDS, arm.raw, JOBS);
    console.log = log;
    const bad = res.filter((r) => r.code !== 0);
    if (bad.length) { console.log(`FAIL  experiment: ${bad.length} cells exited non-zero (${bad.map((b) => b.cell.id).join(", ")}): a stopped run is never a pass`); process.exit(1); }
  }
  const out = {};
  for (const id of ids) {
    const rows = readCell(path.join(arm.raw, `${id}.${SEEDS}.jsonl`));
    const s = summarize(rows);
    if (s.n !== want) { console.log(`FAIL  experiment: cell ${id} has ${s.n} of ${want} matches: a stopped run is never a pass`); process.exit(1); }
    out[id] = { rows, s };
  }
  return out;
}
const FIGS = ["win_pct", "gd", "gf_min", "ga_min", "human_goals_match", "human_walk_goals_match", "shots_min", "opp_shots_min", "passes_min", "passes_completed_pct", "passes_received_match",
  "one_timers_match", "carry_s", "carries_min", "poss_pct", "changes_min", "loose_pct", "takes_key_min", "takes_nokey_min", "human_knockdowns_match", "human_down_s_match",
  "hits_landed_min", "pokes_clean_min", "presses_total_min", "sprint_share_pct", "human_mean_mps", "match_s", "first_goal_for_s"];
const pick = (s) => ({ n: s.n, ...Object.fromEntries(FIGS.map((k) => [k, s[k]])), carry_lost_pct: s.carry_end.lost, carry_goal_pct: s.carry_end.goal, goals_walk_pct: s.goals_walk_pct, ride_takes_min: s.ride_takes_min, pass_then: s.pass_then,
  bot_mean_mps: s.bot_mean_mps, presses_min: s.presses_min, plan_chosen: s.plan_chosen });
const win = (x) => (x.pt.result === "win" ? 100 : 0);
const gd = (x) => x.pt.goals[0] - x.pt.goals[1];
const star = (p) => (p.se > 0 && Math.abs(p.d) >= 2 * p.se ? "*" : "");

function table(ids, before, after) {
  const cols = [["win %", "win_pct"], ["goal diff", "gd"], ["gf/min", "gf_min"], ["ga/min", "ga_min"], ["walk-in goals / match", "human_walk_goals_match"], ["shots/min", "shots_min"],
    ["pass compl %", "passes_completed_pct"], ["passes/min", "passes_min"], ["one-timers / match", "one_timers_match"], ["carry s", "carry_s"], ["carries lost %", "carry_lost_pct"],
    ["takes key / no key per min", null], ["knockdowns", "human_knockdowns_match"], ["down s", "human_down_s_match"], ["changes/min", "changes_min"], ["match s", "match_s"]];
  const lines = [];
  lines.push("| cell | " + cols.map((c) => c[0]).join(" | ") + " | paired: wins pp, goal diff |");
  lines.push("|---|" + cols.map(() => "---").join("|") + "|---|");
  for (const id of ids) {
    const b = before?.[id]?.s, a = after[id].s;
    const cell = (k) => {
      const f = (s) => (k === null ? `${s.takes_key_min} / ${s.takes_nokey_min}` : k === "carry_lost_pct" ? s.carry_end.lost : s[k]);
      return b ? `${f(b)} -> ${f(a)}` : `${f(a)}`;
    };
    let pd = "";
    if (b) { const pw = paired(after[id].rows, before[id].rows, win), pg = paired(after[id].rows, before[id].rows, gd); pd = `${pw.d.toFixed(1)}${star(pw)} (±${pw.se}), ${pg.d.toFixed(2)}${star(pg)} (±${pg.se})`; }
    lines.push(`| ${id} | ` + cols.map((c) => cell(c[1])).join(" | ") + ` | ${pd} |`);
  }
  return lines.join("\n");
}

async function main() {
  const cmd = argv[0];
  if (!fs.existsSync(exe)) { console.log("NOT RUN  experiment: rinklab-thirdlife.exe is not built (engine/tools/rink.sh lab-build-thirdlife)"); process.exit(2); }
  if (cmd === "run") {
    const id = argv[1];
    const file = path.join(here, `${id}.json`);
    const exp = readJson(file);
    const ids = [...SETS[opt("cells", "screen")], ...(exp.ablate || []).flatMap((v) => [`pro.plan-regular.x-${v}`, `pro.regular.x-${v}`]), ...(exp.cells || [])];
    const t0 = Date.now();
    const armB = armDir(armFiles(CART, null)), armA = armDir(armFiles(CART, exp.change));
    const before = await runArm(armB, ids), after = await runArm(armA, ids);
    exp.result = { seeds: SEEDS, arms: { before: armB.key, after: armA.key }, cells: {} };
    for (const c of ids) {
      const pw = paired(after[c].rows, before[c].rows, win), pg = paired(after[c].rows, before[c].rows, gd);
      exp.result.cells[c] = { before: pick(before[c].s), after: pick(after[c].s), paired: { wins_pp: pw.d, wins_se: pw.se, gd: pg.d, gd_se: pg.se } };
    }
    exp.result.table = table(ids, before, after).split("\n");
    fs.writeFileSync(file, JSON.stringify(exp, null, 1) + "\n");
    console.log(exp.result.table.join("\n"));
    console.log(`PASS  experiment ${id}: ${ids.length} cells x ${nSeeds(SEEDS)} seeds, before ${armB.key} and after ${armA.key} (${((Date.now() - t0) / 1000).toFixed(0)} s)`);
  } else if (cmd === "arm") {
    const ids = SETS[opt("cells", "screen")];
    const name = argv[1] || CART;
    const arm = armDir(armFiles(name, null));
    const res = await runArm(arm, ids);
    const out = {}; for (const c of ids) out[c] = pick(res[c].s);
    // --vs <cell>: every cell paired, match for match, against one cell of the same arm (an ablation against the full hand)
    const vs = opt("vs", "");
    if (vs && res[vs]) for (const c of ids) { if (c === vs) continue; const pw = paired(res[c].rows, res[vs].rows, win), pg = paired(res[c].rows, res[vs].rows, gd);
      out[c].vs = { cell: vs, wins_pp: pw.d, wins_se: pw.se, gd: pg.d, gd_se: pg.se };
      console.log(`${c.padEnd(34)} vs ${vs}: wins ${pw.d.toFixed(1)}${star(pw)} pp (±${pw.se}), goal diff ${pg.d.toFixed(2)}${star(pg)} (±${pg.se})`); }
    if (opt("json", "")) fs.writeFileSync(path.resolve(root, opt("json", "")), JSON.stringify({ cartridge: name, seeds: SEEDS, arm: arm.key, cells: out }, null, 1) + "\n");
    console.log(table(ids, null, res));
    console.log(`PASS  arm ${name}: ${ids.length} cells x ${nSeeds(SEEDS)} seeds (${arm.key})`);
  } else if (cmd === "pair") {
    // two cartridges on disk, cell for cell (hockey.regular -> hockey.thirdlife): the page for the owner
    const ids = SETS[opt("cells", "screen")];
    const a = await runArm(armDir(armFiles(argv[1], null)), ids), b = await runArm(armDir(armFiles(argv[2], null)), ids);
    const out = {}; for (const c of ids) out[c] = { [argv[1]]: pick(a[c].s), [argv[2]]: pick(b[c].s) };
    if (opt("json", "")) fs.writeFileSync(path.resolve(root, opt("json", "")), JSON.stringify({ seeds: SEEDS, cells: out }, null, 1) + "\n");
    console.log(table(ids, a, b));
    console.log(`PASS  pair ${argv[1]} -> ${argv[2]}: ${ids.length} cells x ${nSeeds(SEEDS)} seeds`);
  } else if (cmd === "apply") {
    const exp = readJson(path.join(here, `${argv[1]}.json`));
    if (exp.verdict !== "kept") { console.log(`FAIL  apply: ${argv[1]} is "${exp.verdict}", not kept`); process.exit(1); }
    const f = armFiles(CART, exp.change);
    fs.writeFileSync(path.join(contentSrc, "Cartridges", `${CART}.cartridge.json`), JSON.stringify(f.cart, null, 2) + "\n");
    fs.writeFileSync(path.join(contentSrc, "Cartridges", `${CART}.rules.json`), JSON.stringify(f.rules, null, 2) + "\n");
    console.log(`PASS  apply ${argv[1]}: ${CART}.cartridge.json and ${CART}.rules.json now carry it`);
  } else if (cmd === "ledger") {
    const files = fs.readdirSync(here).filter((f) => /^E\d+.*\.json$/.test(f)).sort();
    const L = ["# The experiment ledger of hockey.thirdlife (lane K8)", "",
      "Generated by `node engine/cores/rink/lab/experiments/run.mjs ledger` from the `E*.json` files beside it: never typed. One change at a time; \"before\" is the",
      "cartridge with every change kept so far, \"after\" is that plus the change; both on the same seeds, so the last column is paired match for match",
      "(`*` = at least two standard errors from zero). Hands: `regular`, `novice`, `good` are thirdjam's own scripted playtester; `plan-*` is the planning hand",
      "(`lab_plan.h`); `x-<verb>` = the hand without that verb; `x-idle` = no input at all. Targets (T1..T10) and pillars: `docs/design/HOCKEY-BALANCE.md`.", ""];
    L.push("| id | change | targets | verdict | what the owner feels |", "|---|---|---|---|---|");
    for (const f of files) { const e = readJson(path.join(here, f)); L.push(`| ${e.id} | ${e.title} | ${(e.targets || []).join(", ")} | **${e.verdict || "open"}** | ${e.owner_line || ""} |`); }
    for (const f of files) {
      const e = readJson(path.join(here, f));
      L.push("", `## ${e.id}: ${e.title}`, "", `- **Verdict: ${e.verdict || "open"}.** ${e.why || ""}`, `- Hypothesis: ${e.hypothesis}`, `- Change: \`${JSON.stringify(e.change)}\`${e.patch ? ` (patch \`${e.patch}\`)` : ""}`,
        `- Tempo: ${e.tempo || "no row of the tempo map moves"}`, ...(e.owner_line ? [`- The owner, first minute: ${e.owner_line}`] : []), ...(e.notes ? [`- Notes: ${e.notes}`] : []));
      if (e.result) L.push("", `Seeds ${e.result.seeds}; arms ${e.result.arms.before} -> ${e.result.arms.after}.`, "", ...e.result.table);
    }
    fs.writeFileSync(path.join(here, "LEDGER.md"), L.join("\n") + "\n");
    console.log(`PASS  ledger: ${files.length} experiments`);
  } else { console.log("usage: run.mjs run <id> | arm <cartridge> | pair <a> <b> | apply <id> | ledger   [--seeds 1-60] [--jobs 8] [--cells screen|ladder|matrix]"); process.exit(2); }
}
main();
