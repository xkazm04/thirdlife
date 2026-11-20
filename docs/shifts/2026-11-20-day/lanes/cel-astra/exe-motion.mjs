import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { withWindowLock } from "../../../../../devx/lib/perf/scenarios.mjs";

// node <lane>/exe-motion.mjs <ThirdLife.exe> <new evidence directory> [--board|--walk|--pan] [profiles...]
// --board captures the west-facing visitor-road view through the normal playable boot.
const [binary, directory, ...options] = process.argv.slice(2);
if (!binary || !directory) throw new Error("Expected an exported binary and an evidence directory");
const absolute = value => path.resolve(value).replaceAll("\\", "/");
const exe = absolute(binary);
if (!fs.existsSync(exe)) throw new Error("Missing exported binary: " + exe);
const output = absolute(directory);
const profiles = {
  crisp: "", old: "msaa=2,taa=1", "old-smaa": "msaa=2,ss=smaa,taa=1",
  smaa: "msaa=4,ss=smaa,taa=0", fxaa: "msaa=4,ss=fxaa,taa=0",
  eight: "msaa=8,ss=smaa,taa=0", "eight-fxaa": "msaa=8,ss=fxaa,taa=0",
  "taa-only": "msaa=4,ss=off,taa=1",
};
const routeOptions = options.filter(option => option.startsWith("--"));
const route = routeOptions[0]?.slice(2);
if (routeOptions.length > 1 || (route && !["walk", "pan", "board"].includes(route))) throw new Error("Select one route");
const selected = options.filter(option => !option.startsWith("--"));
const board = route === "board";
const first = board ? 1170 : 100;
const last = board ? 1180 : 160;
// One pan input turns 0.015 degrees, about a quarter pixel at the centre.
const pan = Array.from({length: 120}, (_, i) => (60 + i) + ":~0.1,0").join(";");
const keysByRoute = {walk: "30:+W;180:-W", pan, board: "25:~1196.944,0;60:+W;1060:-W;1120:~-4.611,0"};
const routes = route ? [route] : ["walk", "pan"];

fs.mkdirSync(output, {recursive: true});
for (const profile of selected.length ? selected : ["old", "crisp"]) {
  if (!Object.hasOwn(profiles, profile)) throw new Error("Unknown profile: " + profile);
  for (const route of routes) {
    const keys = keysByRoute[route];
    const dir = output + "/" + profile + "-" + route;
    fs.mkdirSync(dir); // Never mix raw frames from two captures.
    const env = {
      ...process.env,
      TL_STYLE: "crisp", TL_EXE_KEYS: keys, TL_EXE_FRAMES: dir, TL_EXE_FRAMES_FULL: "1",
      TL_EXE_FRAMES_RANGE: first + ":" + last, TL_EXE_QUIT_AT: String(board ? 1260 : 300),
      TL_EXE_CAPTURE: dir + "/still.png", TL_EXE_CAPTURE_AT: String(last - 2),
      TL_EXE_TRACE: dir + "/trace.jsonl", TL_CACHE_DIR: absolute(".tl/cache"),
      TL_EXE_WINDOW_POS: process.env.TL_WINDOW_POS || "0,1440",
    };
    if (profiles[profile]) env.TL_EXE_AA = profiles[profile];
    else delete env.TL_EXE_AA;
    const args = ["--windowed", "--resolution", "1920x1080", "--rendering-driver", "d3d12",
      "--fixed-fps", "60", "--audio-driver", "Dummy", "--log-file", dir + "/run.log"];
    const timeout = board ? 600000 : 180000;
    const run = withWindowLock(() => spawnSync(exe, args, {cwd: path.dirname(exe), env, timeout}),
      {waitMs: 45 * 60 * 1000});
    if (run.error || run.status !== 0) throw new Error(dir + ": " + (run.error || run.status));
    fs.writeFileSync(dir + "/console.log", Buffer.concat([run.stdout, run.stderr]));
    const records = fs.readFileSync(dir + "/frames.jsonl", "utf8").trim().split(/\r?\n/).filter(Boolean).map(JSON.parse);
    const invalid = records.some((r, i) => r.frame !== first + i || r.n !== i ||
      r.size[0] !== 1920 || r.size[1] !== 1080);
    if (records.length !== last - first + 1 || invalid) throw new Error("Incomplete native sequence in " + dir);
    const log = fs.readFileSync(dir + "/run.log", "utf8");
    if (/^(?:SCRIPT ERROR|SHADER ERROR|ERROR):/m.test(log)) throw new Error("Render or script error in " + dir + "/run.log");
    const events = log.split(/\r?\n/)
      .filter(line => line.startsWith('{"schema":"thirdlife.exe/1"')).map(JSON.parse);
    const aa = events.find(event => event.kind === "aa");
    const still = events.find(event => event.kind === "capture" && event.saved && event.frame === last);
    if (!aa || !still || still.width !== 1920 || still.height !== 1080) throw new Error("Missing viewport or still in " + dir);
    const observed = {msaa: [0, 2, 4, 8][aa.msaa_3d], ss: ["off", "fxaa", "smaa"][aa.screen_space_aa],
      taa: Number(aa.taa)};
    const spec = profiles[profile];
    for (const field of spec ? spec.split(",") : []) {
      const [key, value] = field.split("=");
      if (String(observed[key]) !== value) throw new Error("Viewport did not apply " + field + " in " + dir);
    }
    console.log(profile, route, records.length, "frames", JSON.stringify(aa),
      JSON.stringify(records[0]), JSON.stringify(records.at(-1)));
  }
}
