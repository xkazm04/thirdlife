// Shared context for every `tl` command: repo paths, tool resolution, process spawning, verdict printing.
// Zero dependencies (Node >= 24). A command never hardcodes a machine path: it asks ctx.
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

export const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
export const posix = (p) => p.split(path.sep).join("/");
export const rel = (p) => posix(path.relative(REPO, p));

/** Optional per-machine overrides, gitignored: <repo>/.tl/local.json, e.g. {"godot": "C:/.../Godot_console.exe"}. */
export function localConfig() {
  try { return JSON.parse(fs.readFileSync(path.join(REPO, ".tl", "local.json"), "utf8")); } catch { return {}; }
}

const GODOT_FALLBACKS = ["C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"];

/** Resolution order: TL_GODOT env, .tl/local.json "godot", PATH (godot4/godot), known fallbacks. null when none. */
export function resolveGodot() {
  const cands = [process.env.TL_GODOT, localConfig().godot, ...GODOT_FALLBACKS].filter(Boolean);
  for (const c of cands) if (fs.existsSync(c)) return c;
  for (const name of ["godot4", "godot"]) {
    const r = spawnSync(process.platform === "win32" ? "where" : "which", [name], { encoding: "utf8" });
    if (r.status === 0) return r.stdout.split(/\r?\n/)[0].trim();
  }
  return null;
}

export const ENGINE = path.join(REPO, "engine");
export const FOREMAN = path.join(REPO, "foreman");

/** Runs a command, returns {code, stdout, stderr, ms}. Never throws. */
export function run(cmd, args, opts = {}) {
  const t0 = Date.now();
  const r = spawnSync(cmd, args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024, shell: false, ...opts,
    env: { ...process.env, ...(opts.env ?? {}) } });
  return { code: r.status ?? (r.error ? 2 : 1), stdout: r.stdout ?? "", stderr: (r.stderr ?? "") + (r.error ? String(r.error) : ""), ms: Date.now() - t0 };
}

/** Runs a bash script from engine/tools with TL_GODOT set. Finds Git Bash on Windows. */
export function bash(script, args = [], opts = {}) {
  const godot = resolveGodot();
  const sh = process.platform === "win32" ? (fs.existsSync("C:/Program Files/Git/bin/bash.exe") ? "C:/Program Files/Git/bin/bash.exe" : "bash") : "bash";
  return run(sh, [script, ...args], { ...opts, env: { TL_QUIET: "1", ...(godot ? { TL_GODOT: godot } : {}), ...(opts.env ?? {}) } });
}

/** A step result: {id, ok, ms, detail}. `verdict` prints one line per step and the JSON as the last line. */
export function step(id, ok, ms, detail = "") { return { id, ok, ms, detail }; }
export function printVerdict(name, steps, extra = {}) {
  for (const s of steps) console.log(`${s.ok ? "PASS" : "FAIL"}  ${s.id.padEnd(28)} ${String(s.ms).padStart(7)} ms  ${s.detail}`.trimEnd());
  const ok = steps.every((s) => s.ok);
  console.log(JSON.stringify({ schema: "tl.devx/1", cmd: name, ok, steps, ...extra }));
  return ok ? 0 : 1;
}
