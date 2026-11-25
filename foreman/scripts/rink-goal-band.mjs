#!/usr/bin/env node
// E3d of 25 Nov: the goals-a-match band a rink game's measured check holds a cartridge to, derived from thirdjam's own cartridges
// (the regular cut, the Third Life cut and the twelve modes of engine/cores/rink/native/content/Cartridges/modes/MODES.md),
// E3f of 25 Nov: with each level's match length (minutes) and goals a minute, so a match that is over before a person plays
// (E5b: job 1 first to 5 in 1.2 min) is held to what thirdjam's modes play, sudden death included (its 1 goal in 0.4 to 0.6 min),
// each played by lane E2's check (`check_cartridge.mjs`, thirdjam's regular playtester with sprint, 5 seeds a level, no
// planning hand). Writes foreman/data/rink-goal-band.json: every cartridge's goals a match per level, and the band.
//   node foreman/scripts/rink-goal-band.mjs
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..");
const C = path.join(ROOT, "engine", "cores", "rink", "native", "content", "Cartridges");
const files = [path.join(C, "hockey.regular.cartridge.json"), path.join(C, "hockey.thirdlife.cartridge.json"), ...fs.readdirSync(path.join(C, "modes")).filter((n) => n.endsWith(".cartridge.json")).sort().map((n) => path.join(C, "modes", n))];
const from = {};
const minutesFrom = {};
let min = Infinity, max = -Infinity;
const rate = { min: Infinity, max: -Infinity }, minutes = { min: Infinity, max: -Infinity };
const r2 = (x) => Math.round(x * 100) / 100;
for (const f of files) {
  const rules = f.replace(/\.cartridge\.json$/, ".rules.json");
  let out = "";
  try { out = execFileSync(process.execPath, [path.join(ROOT, "engine", "cores", "rink", "lab", "check_cartridge.mjs"), f, ...(fs.existsSync(rules) ? ["--rules", rules] : []), "--seeds", "5", "--plan-seeds", "0", "--json-only"], { encoding: "utf8" }); } catch (e) { out = e.stdout ?? ""; }
  const j = JSON.parse(out.trim().split(/\r?\n/).pop());
  if (!j.ran || !j.levels) { console.log(`skip ${path.basename(f)}: ${JSON.stringify(j.problems ?? j.refused ?? j.why)}`); continue; }
  const g = {};
  const m = {};
  for (const [lv, l] of Object.entries(j.levels)) {
    const x = Math.round((l.playtester.goals_for + l.playtester.goals_against) * 10) / 10;
    g[lv] = x; min = Math.min(min, x); max = Math.max(max, x);
    const t = l.playtester.minutes;
    m[lv] = t; minutes.min = Math.min(minutes.min, t); minutes.max = Math.max(minutes.max, t);
    if (t > 0) { rate.min = Math.min(rate.min, r2(x / t)); rate.max = Math.max(rate.max, r2(x / t)); }
  }
  from[path.basename(f)] = g;
  minutesFrom[path.basename(f)] = m;
  console.log(`${path.basename(f)}: goals ${JSON.stringify(g)}, minutes ${JSON.stringify(m)}`);
}
const doc = { tool: "tl.foreman.rink-goal-band/1", hand: "thirdjam regular playtester with sprint, 5 seeds a level (lane E2's check_cartridge.mjs)", made: new Date().toISOString().slice(0, 10), band: { min, max }, from, rate, minutes, minutes_from: minutesFrom };
fs.writeFileSync(path.join(ROOT, "foreman", "data", "rink-goal-band.json"), JSON.stringify(doc, null, 1) + "\n");
console.log(`PASS  rink goal band: ${min} to ${max} goals a match, ${rate.min} to ${rate.max} goals a minute, ${minutes.min} to ${minutes.max} min a match over ${Object.keys(from).length} cartridges -> foreman/data/rink-goal-band.json`);
