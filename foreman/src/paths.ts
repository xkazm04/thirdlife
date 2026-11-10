import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

function findPackageRoot(): string {
  let dir = path.dirname(fileURLToPath(import.meta.url));
  for (let i = 0; i < 6; i++) {
    if (fs.existsSync(path.join(dir, "package.json"))) return dir;
    dir = path.dirname(dir);
  }
  throw new Error("foreman package root not found");
}

/** The foreman/ directory (where package.json, data/ and prompts/ live). */
export const PKG_ROOT = findPackageRoot();
/** The repository root: foreman/ sits directly under it. */
export const REPO_ROOT = path.dirname(PKG_ROOT);
export const DEFAULT_GODOT = "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe";
export const FAKE_RUNNER = path.join(PKG_ROOT, "dist", "testing", "fake-runner.js");

export function toPosix(p: string): string {
  return p.replace(/\\/g, "/");
}
