// From the worktree root: node <lane>/exe-aa.mjs <ThirdLife.exe> <evidence directory>
// Uses the boot scene, the machine-wide test-window lock, and native release captures.
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { withWindowLock } from "../../../../../devx/lib/perf/scenarios.mjs";

const [binary, output] = process.argv.slice(2);
if (!binary || !output || !fs.existsSync(binary)) {
  throw new Error("Expected an exported ThirdLife.exe and an output directory.");
}
const exe = path.resolve(binary);
const dir = path.resolve(output);
const forward = file => file.replaceAll("\\", "/");
fs.mkdirSync(dir, { recursive: true });
const oldAA = "msaa=2,taa=1";
const walk = "30:+W;180:-W";
const cases = [
  ["old-aa", "crisp", oldAA, ""],
  ["crisp", "crisp", "", ""],
  ["old-aa-walk", "crisp", oldAA, walk],
  ["crisp-walk", "crisp", "", walk],
  ["classic", "classic", "", ""],
  ["classic-override", "classic", oldAA, ""],
];

for (const [name, style, aa, keys] of cases) {
  const capture = path.join(dir, name + ".png");
  const log = path.join(dir, name + ".log");
  const env = {
    ...process.env,
    TL_STYLE: style,
    TL_EXE_KEYS: keys,
    TL_EXE_CAPTURE: forward(capture),
    TL_EXE_CAPTURE_AT: "160",
    TL_EXE_QUIT_AT: "300",
    TL_EXE_WINDOW_POS: process.env.TL_WINDOW_POS || "0,1440",
    TL_CACHE_DIR: process.env.TL_CACHE_DIR || forward(path.join(dir, "cache")),
  };
  if (aa) env.TL_EXE_AA = aa;
  else delete env.TL_EXE_AA;
  const run = withWindowLock(() => spawnSync(exe, [
    "--windowed", "--resolution", "1920x1080", "--rendering-driver", "d3d12",
    "--fixed-fps", "60", "--audio-driver", "Dummy", "--log-file", forward(log),
  ], { cwd: path.dirname(exe), env, timeout: 180000 }));
  if (run.error || run.status !== 0) throw new Error(name + " failed: " + (run.error || run.status));
  const records = fs.readFileSync(log, "utf8").split(/\r?\n/)
    .filter(line => line.startsWith('{"schema":"thirdlife.exe/1"')).map(line => JSON.parse(line));
  const frame = records.find(r => r.kind === "capture" && r.saved && r.width === 1920 && r.height === 1080);
  const settings = records.find(r => r.kind === "aa");
  if (!frame || !settings || !fs.existsSync(capture)) throw new Error(name + " lacks native capture or viewport settings: " + log);
  console.log(name, JSON.stringify(settings), JSON.stringify(frame));
}
