#!/usr/bin/env node
// Third Life rink core, LAB (lane K4 "reference"): the balance harness. `bash engine/tools/rink.sh balance` runs it.
//
// Re-runs a small fixed subset of the reference measurements on the native core and prints every figure with the recorded
// baseline beside it (engine/cores/rink/lab/balance.baseline.json), so a change to a cartridge or to the core shows what it moved:
//   - the tempo probes (rinklab gym: speeds, stops, chases, passes, shots, when a hit must be pressed), exact;
//   - the skill ladder at pro and all_star (novice / regular / good) and the idle hand at pro;
//   - five ablations of the regular hand at pro (the verbs whose loss moved the game most in docs/research/hockey-teardown/PLAY.md).
// Seeds 1-50 a cell (the full tables use 200: this is a detector, not the measurement). Every match's final state hash is kept: equal
// hashes = the same game, frame for frame. PASS = every hash and every gym line equal to the baseline; FAIL = something moved (the
// lines say what, by how much); exit 2 = could not run (no rinklab.exe and no compiler).
//   node engine/cores/rink/lab/balance.mjs [--update] [--jobs 6] [--cartridge hockey.regular]
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { plan, runAll, readCell, summarize, cfg } from "./cells.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..", "..", "..");
const content = path.join(root, "engine", "cores", "rink", "native", "content");
// lane K8: --exe, --cartridge and --baseline play the same harness on the thirdlife runner (rink.sh balance-thirdlife): with hockey.regular against the
// reference baseline it is the parity proof of the patched tree; with hockey.thirdlife against its own baseline it is that cartridge's change detector.
const argOf = (k, d) => { const i = process.argv.indexOf(k); return i >= 0 ? process.argv[i + 1] : d; };
const exe = path.resolve(root, argOf("--exe", path.join(here, "bin", "rinklab.exe")));
const cartridge = argOf("--cartridge", "hockey.regular");
const baseFile = path.resolve(root, argOf("--baseline", path.join(here, "balance.baseline.json")));
cfg.exe = exe; cfg.cartridge = cartridge;
const SEEDS = "1-50";
const FIGS = ["win_pct", "gd", "gf_min", "ga_min", "first_goal_for_s", "poss_pct", "shots_min", "opp_shots_min", "carries_min", "carry_s", "carries_lost_min",
  "passes_completed_pct", "changes_min", "human_knockdowns_match", "hits_landed_min", "pile_pct", "dead_puck_pct", "match_s"];

const argv = process.argv.slice(2);
const update = argv.includes("--update");
const jobs = Number(argv[argv.indexOf("--jobs") + 1]) || 6;

if (!fs.existsSync(exe)) { console.log("NOT RUN  balance: rinklab.exe is not built (engine/tools/rink.sh lab-build)"); process.exit(2); }
const outDir = path.join(root, ".tl", "rink-balance" + (cartridge === "hockey.regular" && !process.argv.includes("--exe") ? "" : "-" + path.basename(exe, ".exe") + "-" + cartridge));
fs.rmSync(outDir, { recursive: true, force: true });
fs.mkdirSync(outDir, { recursive: true });
const t0 = Date.now();

// 1. the gym
const gym = spawnSync(exe, ["gym", content, `-cartridge=${cartridge}`], { encoding: "utf8" });
if (gym.status !== 0) { console.log(`NOT RUN  balance: rinklab gym exited ${gym.status}`); process.exit(2); }
const gymLines = gym.stdout.split("\n").map((l) => l.trim()).filter((l) => l.startsWith("{\"tool\":\"rinklab.gym/1\""));

// 2. the cells (quiet: the per-cell lines of runAll go to a log)
const cells = plan("balance");
const log = console.log; console.log = () => {};
const res = await runAll(cells, SEEDS, outDir, jobs);
console.log = log;
const failed = res.filter((r) => r.code !== 0);
const now = { tool: "rinklab.balance/1", seeds: SEEDS, cartridge, gym: gymLines, cells: {} };
let found = 0;
for (const c of cells) {
  const rows = readCell(path.join(outDir, `${c.id}.${SEEDS}.jsonl`));
  const s = summarize(rows);
  found += s.n;
  const digest = crypto.createHash("sha256").update(s.hashes.join(",")).digest("hex").slice(0, 16);
  now.cells[c.id] = { n: s.n, hashes: digest, ...Object.fromEntries(FIGS.map((k) => [k, s[k]])) };
}
const expected = cells.length * 50;
if (failed.length || found !== expected) {
  console.log(`FAIL  balance: ${found} of ${expected} matches completed (${failed.length} cells exited non-zero): a stopped run is never a pass`);
  process.exit(1);
}
if (update) {
  fs.writeFileSync(baseFile, JSON.stringify(now, null, 1) + "\n");
  console.log(`PASS  balance baseline written: ${Object.keys(now.cells).length} cells x 50 seeds, ${gymLines.length} gym probes (${((Date.now() - t0) / 1000).toFixed(0)} s)`);
  process.exit(0);
}
if (!fs.existsSync(baseFile)) { console.log("NOT RUN  balance: no baseline (run with --update once)"); process.exit(2); }
const base = JSON.parse(fs.readFileSync(baseFile, "utf8"));

// 3. the table: every figure, now and baseline
const pad = (s, n) => String(s).padEnd(n);
const wid = (k) => Math.max(10, k.length + 2);
let moved = 0;
console.log(pad("cell", 30) + FIGS.map((k) => pad(k, wid(k))).join(""));
for (const id of Object.keys(now.cells)) {
  const a = now.cells[id], b = base.cells[id];
  const same = b && a.hashes === b.hashes;
  if (!same) moved++;
  console.log(pad(id, 30) + FIGS.map((k) => pad(a[k], wid(k))).join("") + (same ? "  = baseline (hashes equal)" : "  MOVED"));
  if (!same && b) console.log(pad("  baseline", 30) + FIGS.map((k) => pad(b[k], wid(k))).join(""));
}
let gymMoved = 0;
const baseGym = new Map((base.gym || []).map((l) => { const j = JSON.parse(l); return [`${j.probe}/${j.variant || j.verb || ""}/${j.geometry || ""}/${j.gap_m ?? j.dist_m ?? ""}/${j.hold_frames ?? ""}/${j.chaser_sprint ?? ""}${j.carrier_sprint ?? ""}`, l]; }));
for (const l of gymLines) {
  const j = JSON.parse(l);
  const key = `${j.probe}/${j.variant || j.verb || ""}/${j.geometry || ""}/${j.gap_m ?? j.dist_m ?? ""}/${j.hold_frames ?? ""}/${j.chaser_sprint ?? ""}${j.carrier_sprint ?? ""}`;
  if (baseGym.get(key) !== l) { gymMoved++; console.log(`gym MOVED ${key}\n   now      ${l.slice(0, 300)}\n   baseline ${(baseGym.get(key) || "(absent)").slice(0, 300)}`); }
}
const secs = ((Date.now() - t0) / 1000).toFixed(0);
if (moved || gymMoved || gymLines.length !== (base.gym || []).length) {
  console.log(`FAIL  balance: ${moved} of ${Object.keys(now.cells).length} cells and ${gymMoved} of ${gymLines.length} gym probes moved from the baseline (${found} matches, ${secs} s)`);
  process.exit(1);
}
console.log(`PASS  balance: ${Object.keys(now.cells).length} cells (${found} of ${expected} matches) and ${gymLines.length} gym probes equal the baseline, hash for hash (${secs} s)`);
fs.rmSync(outDir, { recursive: true, force: true });
