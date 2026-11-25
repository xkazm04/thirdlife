#!/usr/bin/env node
// Third Life rink core, LAB (lane E2): the range thirdjam's own cartridges span, per figure of check_cartridge.mjs, for its
// "above / below anything thirdjam ships" words. Runs check_cartridge.mjs (--seeds 5, no planning hand) on every shipped cartridge.
//   node engine/cores/rink/lab/check_cartridge_bands.mjs      writes engine/cores/rink/lab/check_cartridge.bands.json
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const C = path.join(ROOT, "engine", "cores", "rink", "native", "content", "Cartridges");
const files = [];
for (const d of [C, path.join(C, "modes"), path.join(C, "modes", "parked")]) for (const f of fs.readdirSync(d).filter((n) => n.endsWith(".cartridge.json") && !n.includes(".test."))) files.push(path.join(d, f));
const keys = ["speed_mean", "speed_max", "minutes", "carry_s", "changes_min", "shots", "knockdowns", "loose_share"];
const bands = {};
const from = [];
for (const f of files) {
  let out = "";
  try { out = execFileSync(process.execPath, [path.join(HERE, "check_cartridge.mjs"), f, "--seeds", "5", "--plan-seeds", "0", "--json-only", "--make-bands"], { encoding: "utf8" }); } catch (e) { out = e.stdout ?? ""; }
  const j = JSON.parse(out.trim().split(/\r?\n/).pop());
  if (!j.ok) { console.log(`skip ${path.basename(f)}: ${JSON.stringify(j.problems ?? j.refused)}`); continue; }
  from.push(path.basename(f));
  for (const lv of Object.values(j.levels)) for (const k of keys) {
    const x = lv.playtester[k];
    bands[k] = bands[k] ? { min: Math.min(bands[k].min, x), max: Math.max(bands[k].max, x) } : { min: x, max: x };
  }
}
fs.writeFileSync(path.join(HERE, "check_cartridge.bands.json"), JSON.stringify({ tool: "tl.rink.check.bands/1", hand: "thirdjam regular playtester with sprint, 5 seeds a level", from, bands }, null, 1) + "\n");
console.log(`PASS  rink check-cartridge bands: ${from.length} cartridges -> lab/check_cartridge.bands.json`);
