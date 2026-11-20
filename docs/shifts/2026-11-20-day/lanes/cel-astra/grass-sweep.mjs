// node grass-sweep.mjs <engine dir> <evidence dir> <profile name|--reference> [--skyline]
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { resolveGodot } from "../../../../../devx/lib/ctx.mjs";
import { withWindowLock } from "../../../../../devx/lib/perf/scenarios.mjs";

const [engine, output, profile, skyline] = process.argv.slice(2);
if (!engine || !output || !profile || !/^(--reference|[\w][\w-]*)$/.test(profile) || (skyline && skyline !== "--skyline"))
  throw new Error("Expected engine directory, evidence directory, profile name or --reference, and optional --skyline");
const destination = path.resolve(output);
const reference = profile === "--reference";
const script = fileURLToPath(new URL("./grass-sweep.gd", import.meta.url));
const godot = resolveGodot();
if (!godot) throw new Error("Set TL_GODOT or configure Godot in .tl/local.json");
fs.mkdirSync(destination, { recursive: true });
const args = ["--path", path.resolve(engine), "--windowed", "--resolution", "1920x1080",
  "--position", process.env.TL_WINDOW_POS || "0,1440", "--rendering-driver", "d3d12",
  "--fixed-fps", "60", "--audio-driver", "Dummy", "--script", script];
const env = { ...process.env, TL_STYLE: "crisp", TL_EXE_AA: "", TL_EXE_KEYS: "",
  TL_CACHE_DIR: path.resolve(".tl/cache"), TL_CEL_EVIDENCE: destination, TL_GRASS_PROFILE: profile,
  TL_GRASS_REFERENCE: reference ? "1" : "", TL_GRASS_SKYLINE: skyline ? "1" : "" };
const result = withWindowLock(() => spawnSync(godot, args, { env, timeout: 300000, encoding: "utf8" }),
  { waitMs: 45 * 60 * 1000 });
const log = (result.stdout || "") + (result.stderr || "");
const logPath = path.join(destination, (reference ? "reference" : profile) + ".log");
fs.writeFileSync(logPath, log);
if (result.error || result.status !== 0 || !/^GRASS_SWEEP_OK\r?$/m.test(log) || /^(?:SCRIPT ERROR|SHADER ERROR|ERROR):/m.test(log))
  throw new Error("Incomplete sweep. " + (result.error?.message || logPath));
console.log((reference ? "54" : "27") + " grass plates saved in " + destination);

