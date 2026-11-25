#!/usr/bin/env node
// E3d of 25 Nov: the goals-a-match band a rink game's measured check holds a cartridge to, derived from thirdjam's own cartridges
// (the regular cut, the Third Life cut and the twelve modes of engine/cores/rink/native/content/Cartridges/modes/MODES.md),
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
let min = Infinity, max = -Infinity;
for (const f of files) {
  const rules = f.replace(/\.cartridge\.json$/, ".rules.json");
  let out = "";
  try { out = execFileSync(process.execPath, [path.join(ROOT, "engine", "cores", "rink", "lab", "check_cartridge.mjs"), f, ...(fs.existsSync(rules) ? ["--rules", rules] : []), "--seeds", "5", "--plan-seeds", "0", "--json-only"], { encoding: "utf8" }); } catch (e) { out = e.stdout ?? ""; }
  const j = JSON.parse(out.trim().split(/\r?\n/).pop());
  if (!j.ran || !j.levels) { console.log(`skip ${path.basename(f)}: ${JSON.stringify(j.problems ?? j.refused ?? j.why)}`); continue; }
  const g = {};
  for (const [lv, l] of Object.entries(j.levels)) {
    const x = Math.round((l.playtester.goals_for + l.playtester.goals_against) * 10) / 10;
    g[lv] = x; min = Math.min(min, x); max = Math.max(max, x);
  }
  from[path.basename(f)] = g;
  console.log(`${path.basename(f)}: ${JSON.stringify(g)}`);
}
const doc = { tool: "tl.foreman.rink-goal-band/1", hand: "thirdjam regular playtester with sprint, 5 seeds a level (lane E2's check_cartridge.mjs)", made: new Date().toISOString().slice(0, 10), band: { min, max }, from };
fs.writeFileSync(path.join(ROOT, "foreman", "data", "rink-goal-band.json"), JSON.stringify(doc, null, 1) + "\n");
console.log(`PASS  rink goal band: ${min} to ${max} goals a match over ${Object.keys(from).length} cartridges -> foreman/data/rink-goal-band.json`);
