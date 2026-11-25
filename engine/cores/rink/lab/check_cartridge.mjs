#!/usr/bin/env node
// Third Life rink core, LAB (lane E2 "cartridge"): a measured check of a cartridge before a person plays it.
//   node engine/cores/rink/lab/check_cartridge.mjs <file.cartridge.json> [--rules <file.rules.json>] [--seeds N] [--plan-seeds M] [--json-only]
// 1. thirdjam's validator (engine/cores/rink/schema/validate.mjs): a refused cartridge stops here (exit 1), with its errors.
// 2. the lab (rinklab.exe; rinklab-thirdlife.exe when a rules file is given) plays it headless in a scratch content dir:
//    - thirdjam's REGULAR PLAYTESTER with sprint (the tournament's -player=regular -playersprint) on the human's seat (a scripted hand, AI/JamPlaytester.cpp) against thirdjam's bots,
//      N seeds (default 10) at rookie, pro and all_star;
//    - K8's PLANNING HAND (lab_plan.cpp, a human-limited hand that re-plans) M seeds (default 2) at each level.
// 3. prints what a person will meet, in plain words, and one JSON line {"tool":"tl.rink.check/1", ...} last for the Foreman.
// Figures are per match unless said; every figure names the hand it was read through (CLAUDE.md: a bot's hand measures the game).
// exit 0 = measured (warnings are words, not a failure); 1 = the cartridge is refused or a match did not end; 2 = could not run.
// H1 of 25 Nov (E3g item 5: a job's first lint waited 2.6-3.4 min for two of these checks, each mostly the 16 skate_only
// matches played in a row by one process):
//   - the defect cells' seeds are split into --defect-groups G contiguous ranges (default 4, at most 4), one lab process
//     each, and every run goes through a pool of at most --jobs J lab processes (default 4: one lab process is one core, so 4
//     of a 16-thread machine is 25 %; before the split the check ran 8 at once),
//     so the check never loads the machine more than it did. Each match is played by its own seed, so the per-match lines
//     and the JSON line are the same byte for byte as one process playing all the seeds (only `seconds` differs);
//   - the lab's raw lines are cached in .tl/check-cartridge-cache/ (TL_RINK_CHECK_CACHE overrides; --no-cache skips it),
//     keyed by the cartridge's bytes, the rules file's bytes, the lab exe's bytes, the content dir's bytes and every run's
//     arguments: the house check and an untouched base cartridge are the same in every job. Only a check whose every run
//     completed is kept. A hit says so in words and in the JSON line (`cached`: true).
// TL_RINKLAB_EXE: a stand-in lab (a .mjs file is run with node), for the Foreman's tests.
import { spawn } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const CONTENT = path.join(ROOT, "engine", "cores", "rink", "native", "content");
const LEVELS = ["rookie", "pro", "all_star"];

function arg(name, def) {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : def;
}

function notRun(why) {
  console.log(`NOT RUN  rink check-cartridge: ${why}`);
  console.log(JSON.stringify({ tool: "tl.rink.check/1", ok: false, ran: false, why }));
  process.exit(2);
}

function run(exe, args) {
  return new Promise((resolve) => {
    const p = exe.endsWith(".mjs") ? spawn(process.execPath, [exe, ...args], { stdio: ["ignore", "pipe", "pipe"] }) : spawn(exe, args, { stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    p.stdout.on("data", (d) => { out += d; });
    p.stderr.on("data", () => {});
    p.on("close", (code) => resolve({ code, lines: out.split(/\r?\n/).filter((l) => l.startsWith("{")).map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean) }));
    p.on("error", () => resolve({ code: -1, lines: [] }));
  });
}

const file = process.argv[2];
if (!file || file.startsWith("--")) notRun("usage: check_cartridge.mjs <file.cartridge.json> [--rules <file>] [--seeds N] [--plan-seeds M]");
if (!fs.existsSync(file)) notRun(`${file} not found`);
const rulesFile = arg("--rules", "");
if (rulesFile && !fs.existsSync(rulesFile)) notRun(`${rulesFile} not found`);
const seeds = Math.max(1, Number(arg("--seeds", "10")));
const planSeeds = Math.max(0, Number(arg("--plan-seeds", "2")));
const jsonOnly = process.argv.includes("--json-only");
// E3d of 25 Nov (lane E3, from lane K8's CHECK-CARTRIDGE-NOTE.md): --defects also plays K8's two coarse cells at pro, 16 seeds
// (--defect-seeds N): the hand that never moves (-player=regular -remove=idle) and the planning hand skating only
// (-plan=regular -only=none -plancheck, its copies of the sim checked: clone_mismatch above 0 = the hand is NOT VALID here).
// Their figures go in the tl.rink.check/1 line under `defects`; the Foreman decides what fails.
const defects = process.argv.includes("--defects");
const defectSeeds = Math.max(1, Number(arg("--defect-seeds", "16")));
const say = (s) => { if (!jsonOnly) console.log(s); };

// 1. the validator
const text = fs.readFileSync(file, "utf8");
const { validateCartridgeText } = await import(pathToFileURL(path.join(ROOT, "engine", "cores", "rink", "schema", "validate.mjs")).href);
const v = validateCartridgeText(text);
if (!v.ok) {
  say(`FAIL  rink check-cartridge: ${path.basename(file)} is refused by thirdjam's validator (${v.errors.length} error(s)):`);
  for (const e of v.errors.slice(0, 12)) say(`  - ${e}`);
  console.log(JSON.stringify({ tool: "tl.rink.check/1", ok: false, ran: false, file: path.basename(file), refused: v.errors }));
  process.exit(1);
}

// 2. the lab, in a scratch content dir holding the cartridge as Cartridges/tlcheck.cartridge.json
const exe = process.env.TL_RINKLAB_EXE || path.join(HERE, "bin", rulesFile ? "rinklab-thirdlife.exe" : "rinklab.exe");
if (!fs.existsSync(exe)) notRun(`${path.relative(ROOT, exe)} is not built (bash engine/tools/rink.sh ${rulesFile ? "lab-build-thirdlife" : "lab-build"})`);
const defectGroups = Math.min(4, Math.max(1, Number(arg("--defect-groups", "4"))));
const maxJobs = Math.max(1, Number(arg("--jobs", "4")));
// The runs, in the order their results are read (the JSON line's key order follows it). `pri` 0 runs first: the long cells.
const C = "<content>";
const runs = [];
for (const lv of LEVELS) {
  runs.push({ hand: "playtester", lv, pri: 1, args: ["match", C, "-cartridge=tlcheck", `-seeds=1-${seeds}`, `-difficulty=${lv}`, "-player=regular", "-playersprint"] });
  if (planSeeds > 0) runs.push({ hand: "plan", lv, pri: 1, args: ["match", C, "-cartridge=tlcheck", `-seeds=1-${planSeeds}`, `-difficulty=${lv}`, "-plan=regular"] });
}
/** `n` seeds from 1 in `g` contiguous ranges, as even as they go: 16 in 4 -> 1-4, 5-8, 9-12, 13-16. */
const ranges = (n, g) => { const out = []; let from = 1; for (let i = 0; i < Math.min(g, n); i++) { const k = Math.floor(n / Math.min(g, n)) + (i < n % Math.min(g, n) ? 1 : 0); out.push(`${from}-${from + k - 1}`); from += k; } return out; };
if (defects) {
  for (const s of ranges(defectSeeds, defectGroups)) runs.push({ hand: "idle", lv: "pro", pri: 1, args: ["match", C, "-cartridge=tlcheck", `-seeds=${s}`, "-difficulty=pro", "-player=regular", "-playersprint", "-remove=idle"] });
  for (const s of ranges(defectSeeds, defectGroups)) runs.push({ hand: "skate_only", lv: "pro", pri: 0, args: ["match", C, "-cartridge=tlcheck", `-seeds=${s}`, "-difficulty=pro", "-plan=regular", "-playersprint", "-only=none", "-plancheck"] });
}
// The cache key: what the lab reads (the cartridge, the rules, the content dir, the exe) and how it is asked.
const sha = (...parts) => { const h = crypto.createHash("sha256"); for (const p of parts) h.update(p); return h.digest("hex"); };
const contentHash = () => { const h = crypto.createHash("sha256"); const walk = (d, rel) => { for (const n of fs.readdirSync(d).sort()) { const a = path.join(d, n), r = rel ? `${rel}/${n}` : n; if (fs.statSync(a).isDirectory()) walk(a, r); else h.update(`${r}\0`).update(fs.readFileSync(a)).update("\0"); } }; walk(CONTENT, ""); return h.digest("hex"); };
const useCache = !process.argv.includes("--no-cache") && !process.argv.includes("--make-bands");
const cacheDir = process.env.TL_RINK_CHECK_CACHE || path.join(ROOT, ".tl", "check-cartridge-cache");
const key = useCache ? sha(JSON.stringify({ v: 1, runs: runs.map((r) => [r.hand, r.lv, r.args]) }), "\0", text, "\0", rulesFile ? fs.readFileSync(rulesFile) : "", "\0", fs.readFileSync(exe), "\0", contentHash()) : "";
const cacheFile = useCache ? path.join(cacheDir, `${key}.json`) : "";
const t0 = Date.now();
let done;
let cached = false;
try {
  if (useCache) {
    const c = JSON.parse(fs.readFileSync(cacheFile, "utf8"));
    if (c.tool === "tl.rink.check.cache/1" && Array.isArray(c.done) && c.done.length === new Set(runs.map((r) => `${r.hand} ${r.lv}`)).size) { done = c.done; cached = true; }
  }
} catch { /* not cached */ }
if (!cached) {
  const scratch = path.join(ROOT, ".tl", "check-cartridge", String(process.pid));
  fs.rmSync(scratch, { recursive: true, force: true });
  fs.cpSync(CONTENT, scratch, { recursive: true });
  fs.writeFileSync(path.join(scratch, "Cartridges", "tlcheck.cartridge.json"), text);
  if (rulesFile) fs.copyFileSync(rulesFile, path.join(scratch, "Cartridges", "tlcheck.rules.json"));
  const content = scratch.replace(/\\/g, "/");
  // A pool of at most maxJobs lab processes: the long cells first, every result kept at its run's place.
  const out = new Array(runs.length);
  const order = runs.map((r, i) => i).sort((a, b) => runs[a].pri - runs[b].pri || a - b);
  const worker = async () => { while (order.length) { const i = order.shift(); const r = runs[i]; out[i] = { hand: r.hand, lv: r.lv, r: await run(exe, r.args.map((a) => (a === C ? content : a))) }; } };
  await Promise.all(Array.from({ length: Math.min(maxJobs, runs.length) }, worker));
  fs.rmSync(scratch, { recursive: true, force: true });
  // The groups of a cell, joined in seed order: one result per cell, as one process playing every seed gives.
  done = [];
  for (const x of out) {
    const same = done.find((d) => d.hand === x.hand && d.lv === x.lv);
    if (same === undefined) done.push({ hand: x.hand, lv: x.lv, r: { code: x.r.code, lines: [...x.r.lines] } });
    else { same.r.code = same.r.code !== 0 ? same.r.code : x.r.code; same.r.lines.push(...x.r.lines); }
  }
  if (useCache && done.every((d) => d.r.code === 0)) {
    try {
      fs.mkdirSync(cacheDir, { recursive: true });
      const tmp = `${cacheFile}.${process.pid}.tmp`;
      fs.writeFileSync(tmp, JSON.stringify({ tool: "tl.rink.check.cache/1", file: path.basename(file), runs: runs.length, done }) + "\n");
      fs.renameSync(tmp, cacheFile);
    } catch { /* a cache that cannot be written is only slower */ }
  }
}
const seconds = (Date.now() - t0) / 1000;

// 3. what a person meets
const mean = (a) => (a.length ? a.reduce((x, y) => x + y, 0) / a.length : 0);
const r1 = (x) => Math.round(x * 10) / 10;
const r2 = (x) => Math.round(x * 100) / 100;
const levels = {};
const problems = [];
const defectCells = {};
for (const { hand, lv, r } of done) {
  if (hand === "idle" || hand === "skate_only") {
    const play = r.lines.filter((l) => l.tool === "thirdjam.playtest/1");
    const plan = r.lines.filter((l) => l.tool === "rinklab.cell/1").map((l) => l.planstats).filter(Boolean);
    if (r.code !== 0 || play.length !== defectSeeds) { problems.push(`${hand} at ${lv}: ${play.length} of ${defectSeeds} matches reported (exit ${r.code})`); continue; }
    defectCells[hand] = { matches: play.length, wins: play.filter((p) => p.result === "win").length, not_over: play.filter((p) => !p.over).length,
      ...(hand === "skate_only" ? { clone_checked: plan.reduce((s, x) => s + (x.clone_checked ?? 0), 0), clone_mismatch: plan.reduce((s, x) => s + (x.clone_mismatch ?? 0), 0) } : {}) };
    continue;
  }
  const play = r.lines.filter((l) => l.tool === "thirdjam.playtest/1");
  const cell = r.lines.filter((l) => l.tool === "rinklab.cell/1").map((l) => l.stats);
  const want = hand === "plan" ? planSeeds : seeds;
  if (r.code !== 0 || play.length !== want || cell.length !== want) {
    problems.push(`${hand} at ${lv}: ${play.length} of ${want} matches reported (exit ${r.code})`);
    continue;
  }
  const notOver = play.filter((p) => !p.over).length;
  const m = {
    matches: play.length,
    wins: play.filter((p) => p.result === "win").length,
    not_over: notOver,
    goals_for: r1(mean(play.map((p) => p.goals[0]))),
    goals_against: r1(mean(play.map((p) => p.goals[1]))),
    minutes: r1(mean(play.map((p) => p.frames / 3600))),
    shots: r1(mean(cell.map((c) => c.shots[0] + c.shots[1]))),
    carry_s: r1(mean(cell.map((c) => (c.carries ? c.carry_frames / c.carries / 60 : 0)))),
    loose_share: r2(mean(cell.map((c) => (c.play_frames ? c.loose_frames / c.play_frames : 0)))),
    knockdowns: r1(mean(play.map((p) => p.knockdowns_all ?? 0))),
    passes_completed: r1(mean(cell.map((c) => c.passes_completed))),
    human_touches_min: r1(mean(play.map((p) => p.touches_per_min ?? 0))),
    max_no_touch_s: r1(Math.max(...play.map((p) => (p.max_no_touch ?? 0) / 60))),
    speed_mean: r1(mean(cell.map((c) => c.human_mean))),
    speed_max: r1(Math.max(...cell.map((c) => c.human_max))),
    changes_min: r1(mean(cell.map((c) => (c.play_frames ? c.changes / (c.play_frames / 3600) : 0)))),
    walked_goals: cell.reduce((s, c) => s + (c.goals_walk ? c.goals_walk[0] + c.goals_walk[1] : 0), 0),
  };
  (levels[lv] ??= {})[hand] = m;
  if (notOver) problems.push(`${hand} at ${lv}: ${notOver} match(es) did not end`);
}
const warnings = [];
const pt = (lv) => levels[lv]?.playtester;
if (pt("rookie") && pt("rookie").wins === 0) warnings.push("unwinnable at rookie: thirdjam's regular playtester won none of its matches");
if (pt("all_star") && pt("all_star").wins === pt("all_star").matches) warnings.push("trivial at all_star: thirdjam's regular playtester won every match");
for (const lv of LEVELS) {
  const m = pt(lv);
  if (!m) continue;
  if (m.goals_for + m.goals_against < 1) warnings.push(`almost no goals at ${lv} (${r1(m.goals_for + m.goals_against)} a match)`);
  if (m.goals_for + m.goals_against > 15) warnings.push(`a goal flood at ${lv} (${r1(m.goals_for + m.goals_against)} a match)`);
  if (m.minutes > 10) warnings.push(`long matches at ${lv} (${m.minutes} min)`);
  if (m.minutes < 1) warnings.push(`very short matches at ${lv} (${m.minutes} min)`);
  if (m.loose_share > 0.6) warnings.push(`the puck is loose most of the time at ${lv} (${Math.round(m.loose_share * 100)} %)`);
  if (m.carry_s > 6) warnings.push(`long carries at ${lv} (${m.carry_s} s each): the puck rarely changes hands`);
  if (m.knockdowns > 40) warnings.push(`a knockdown fest at ${lv} (${m.knockdowns} a match)`);
  if (m.human_touches_min < 3) warnings.push(`the person rarely touches the puck at ${lv} (${m.human_touches_min} a minute for the scripted hand)`);
}
// Outside thirdjam's own range: lab/check_cartridge.bands.json holds, per figure, the lowest and highest value over every cartridge
// thirdjam ships (made by --make-bands); a figure beyond a quarter past that span is told in words (not a failure).
const BANDS = path.join(HERE, "check_cartridge.bands.json");
const WORDS = {
  speed_mean: "the skaters' mean speed (m/s)", speed_max: "the top speed (m/s)", minutes: "a match's length (min)", carry_s: "a carry's length (s)",
  changes_min: "possession changes a minute", shots: "shots a match", knockdowns: "knockdowns a match", loose_share: "the share of play the puck is loose",
};
if (fs.existsSync(BANDS) && !process.argv.includes("--make-bands")) {
  const bands = JSON.parse(fs.readFileSync(BANDS, "utf8")).bands;
  for (const [k, w] of Object.entries(WORDS)) {
    const b = bands[k];
    if (!b) continue;
    const span = Math.max(b.max - b.min, 1e-9);
    for (const lv of LEVELS) {
      const x = pt(lv)?.[k];
      if (x === undefined) continue;
      if (x > b.max + span * 0.25) warnings.push(`${w} at ${lv} is ${x}, above anything thirdjam ships (${b.min}..${b.max})`);
      else if (x < b.min - span * 0.25) warnings.push(`${w} at ${lv} is ${x}, below anything thirdjam ships (${b.min}..${b.max})`);
    }
  }
}
const ok = problems.length === 0;
say(`rink check-cartridge: ${path.basename(file)}${rulesFile ? " + " + path.basename(rulesFile) : ""} (validator: accepted; ${done.length} runs in ${r1(seconds)} s${cached ? ", read from the cache: this cartridge, rules, lab and content were measured before" : ""})`);
for (const lv of LEVELS) {
  const m = pt(lv), p = levels[lv]?.plan;
  if (!m) continue;
  say(`  ${lv.padEnd(8)} thirdjam's regular playtester wins ${m.wins} of ${m.matches}${p ? `, the planning hand ${p.wins} of ${p.matches}` : ""}; ` +
    `${r1(m.goals_for + m.goals_against)} goals a match (${m.goals_for}:${m.goals_against}), ${m.minutes} min; a carry lasts ${m.carry_s} s, ` +
    `the puck is loose ${Math.round(m.loose_share * 100)} % of play; ${m.knockdowns} knockdowns, ${m.shots} shots, ${m.passes_completed} completed passes; ` +
    `skaters average ${m.speed_mean} m/s (top ${m.speed_max}), the puck changes hands ${m.changes_min} times a minute; ` +
    `the hand touches the puck ${m.human_touches_min} times a minute${m.walked_goals ? `; ${m.walked_goals} goals walked in` : ""}`);
}
for (const w of warnings) say(`  WARN ${w}`);
for (const p of problems) say(`  FAIL ${p}`);
say(ok ? `PASS  rink check-cartridge: measured${warnings.length ? ` (${warnings.length} warning(s))` : ""}` : `FAIL  rink check-cartridge: ${problems.length} run(s) did not complete`);
console.log(JSON.stringify({ tool: "tl.rink.check/1", ok, ran: true, file: path.basename(file), rules: rulesFile ? path.basename(rulesFile) : undefined,
  hands: { playtester: `thirdjam regular playtester with sprint, ${seeds} seeds a level`, plan: planSeeds ? `planning hand (lab_plan regular), ${planSeeds} seeds a level` : undefined },
  levels, ...(defects ? { defects: defectCells, defect_hands: { idle: `thirdjam regular playtester with every input removed, ${defectSeeds} seeds at pro`, skate_only: `planning hand (lab_plan regular) skating only, ${defectSeeds} seeds at pro, its sim copies checked` } } : {}), warnings, problems, seconds: r1(seconds), ...(cached ? { cached: true } : {}) }));
process.exit(ok ? 0 : 1);
