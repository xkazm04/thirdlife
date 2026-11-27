// Lane DN (27 Nov 2026): the day-and-night captures and frame times, from the game as a person starts it (engine/boot,
// a window, the Home loaded from TL_HOME_BUILD_DIR with its settings.json naming the time and "hold").
//   node docs/shifts/2026-11-27-day/lanes/DN-night/shots.mjs <build dir> <out dir> [shots|times|all]
// <build dir> holds build.json from engine/kernel/world/home/day_shots.gd (the lamp street). Each run takes the one test
// window lock (devx/lib/perf/scenarios.mjs). Raw PNGs and frame logs go to <out dir>; JPGs (< 400 KB) beside this file.
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { withWindowLock } from "../../../../../devx/lib/perf/scenarios.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "../../../../..");
const G = process.env.TL_GODOT || "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe";
const [build0, out0, what = "all"] = process.argv.slice(2);
const build = build0 && path.resolve(build0), out = out0 && path.resolve(out0);
if (!build || !out) { console.error("usage: shots.mjs <build dir> <out dir> [shots|times|all]"); process.exit(2); }
fs.mkdirSync(out, { recursive: true });
const TIMES = { dawn: 21600, noon: 43200, dusk: 64800, night: 0 };
const SPAWN = "";                       // where boot puts the visitor by itself (no TL_EXE_START)
const STREET = "-178,3,-80,2";          // the west end of the lamp street (day_shots.gd --street=-84,2,-164,2 --spacing=5: 23 lamps, 2 houses, 2 masts, 31 lights), facing it

function run(name, start, time, extra) {
  const dir = path.join(out, name);
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  for (const f of ["build.json", "edits.jsonl"]) if (fs.existsSync(path.join(build, f))) fs.copyFileSync(path.join(build, f), path.join(dir, f));
  fs.writeFileSync(path.join(dir, "settings.json"), JSON.stringify({ schema: "tl.home-settings/1", day: { frame: TIMES[time], cycle: "hold" } }) + "\n");
  const env = { ...process.env, TL_STYLE: "crisp", TL_HOME: "", TL_HOME_BUILD_DIR: dir, ...(start ? { TL_EXE_START: start } : {}), TL_EXE_WINDOW_POS: process.env.TL_WINDOW_POS || "0,1440", MSYS_NO_PATHCONV: "1", ...extra };
  const t0 = Date.now();
  const r = withWindowLock(() => spawnSync(G, ["--resolution", "1600x900", "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", path.join(ROOT, "engine"), "res://boot/boot.tscn"],
    { env, encoding: "utf8", timeout: 240000, maxBuffer: 64 << 20 }));
  fs.writeFileSync(path.join(dir, "window.log"), (r.stdout || "") + (r.stderr || ""));
  const errs = ((r.stdout || "") + (r.stderr || "")).split(/\r?\n/).filter((l) => /^SCRIPT ERROR|^ERROR:/.test(l));
  console.log(`${name}: exit ${r.status} in ${Math.round((Date.now() - t0) / 1000)} s, ${errs.length} error lines${errs.length ? ": " + errs[0] : ""}`);
  return { dir, r };
}

function shot(name, start, time) {
  const png = path.join(out, `${name}.png`);
  const { r } = run(name, start, time, { TL_EXE_CAPTURE: png, TL_EXE_CAPTURE_AT: "420", TL_EXE_QUIT_AT: "440" });
  if (!fs.existsSync(png)) { console.log(`${name}: NO PICTURE`); return; }
  const jpg = path.join(HERE, `${name}.jpg`);
  for (const q of [3, 4, 5, 6, 8]) {
    spawnSync("ffmpeg", ["-y", "-loglevel", "error", "-i", png, "-q:v", String(q), jpg]);
    if (fs.statSync(jpg).size < 400 * 1024) break;
  }
  console.log(`${name}: ${jpg} ${Math.round(fs.statSync(jpg).size / 1024)} KB`);
}

function times(name, start, time) {
  const fdir = path.join(out, `${name}-frames`);
  run(name, start, time, { TL_EXE_FRAMES: fdir, TL_EXE_FRAMES_TIMES: "1", TL_EXE_FRAMES_RANGE: "600:2400", TL_EXE_QUIT_AT: "2420" });
  const lines = fs.existsSync(path.join(fdir, "frames.jsonl")) ? fs.readFileSync(path.join(fdir, "frames.jsonl"), "utf8").trim().split("\n").map((l) => JSON.parse(l)) : [];
  const d = [];
  for (let i = 1; i < lines.length; i++) d.push((lines[i].usec - lines[i - 1].usec) / 1000);
  d.sort((a, b) => a - b);
  const q = (p) => d.length ? d[Math.min(d.length - 1, Math.floor(p * d.length))].toFixed(2) : "-";
  const line = `${name}: ${d.length} drawn frames (physics 600..2400, vsync off), p50 ${q(0.5)} ms, p99 ${q(0.99)} ms, max ${d.length ? d[d.length - 1].toFixed(1) : "-"} ms`;
  console.log(line);
  fs.appendFileSync(path.join(out, "times.txt"), line + "\n");
}

if (what === "shots" || what === "all") {
  for (const t of ["dawn", "noon", "dusk", "night"]) shot(`dn-${t}`, SPAWN, t);
  shot("dn-lamps-night", STREET, "night");
  shot("dn-lamps-noon", STREET, "noon");
  shot("dn-lamps-dusk", STREET, "dusk");
}
if (what === "times" || what === "all") {
  times("t-street-noon", STREET, "noon");
  times("t-street-night", STREET, "night");
}
if (what.startsWith("one:")) {          // one:<name>:spawn|street:<dawn|noon|dusk|night>
  const [, name, where, t] = what.split(":");
  shot(name, where === "street" ? STREET : SPAWN, t);
}
