// Async engine verb runner with a killable child (ctx.run is synchronous and cannot be interrupted).
import { spawn, spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { REPO, resolveGodot } from "../ctx.mjs";

export const bashExe = () => (process.platform === "win32" && fs.existsSync("C:/Program Files/Git/bin/bash.exe") ? "C:/Program Files/Git/bin/bash.exe" : "bash");

/** Kills the child and its descendants (on Windows child.kill() would leave Godot running). */
export function killTree(child) {
  if (!child || child.exitCode !== null || child.pid == null) return;
  if (process.platform === "win32") spawnSync("taskkill", ["/PID", String(child.pid), "/T", "/F"], { stdio: "ignore" });
  else { try { child.kill("SIGKILL"); } catch { /* gone */ } }
}

/** Starts `bash engine/tools/tl.sh <verb> --pack=<pack> ...extra`. Returns {child, done: Promise<{code, stdout, stderr, ms}>}. */
export function startVerb(verb, pack, extra = []) {
  const godot = resolveGodot();
  const t0 = Date.now();
  const child = spawn(bashExe(), [path.join(REPO, "engine", "tools", "tl.sh"), verb, `--pack=${pack}`, ...extra], {
    cwd: REPO, env: { ...process.env, TL_QUIET: "1", ...(godot ? { TL_GODOT: godot } : {}) }, stdio: ["ignore", "pipe", "pipe"],
  });
  let stdout = "", stderr = "";
  child.stdout.on("data", (d) => { stdout += d; });
  child.stderr.on("data", (d) => { stderr += d; });
  const done = new Promise((resolve) => {
    child.on("error", (e) => resolve({ code: 2, stdout, stderr: stderr + String(e), ms: Date.now() - t0 }));
    child.on("close", (code) => resolve({ code: code ?? 2, stdout, stderr, ms: Date.now() - t0 }));
  });
  return { child, done };
}
