export const summary = "check the machine: node, git, Godot, ffmpeg, foreman deps, free disk; print what is missing";
import { run, resolveGodot, FOREMAN, REPO, printVerdict, step } from "../ctx.mjs";
import { diskReport } from "../disk.mjs";
import fs from "node:fs";
import path from "node:path";
export { doctor as run };
async function doctor() {
  const steps = [];
  const t = (id, ok, detail) => steps.push(step(id, ok, 0, detail));
  t("node>=24", Number(process.versions.node.split(".")[0]) >= 24, process.versions.node);
  t("git", run("git", ["--version"]).code === 0, "");
  const g = resolveGodot(); t("godot", !!g, g ?? "set TL_GODOT or .tl/local.json {\"godot\": ...}");
  const deps = fs.existsSync(path.join(FOREMAN, "node_modules")); t("foreman deps", deps, deps ? "present" : "run `npm ci` in foreman/");
  t("ffmpeg (optional)", true, run("ffmpeg", ["-version"]).code === 0 ? "present" : "absent: only `tl.sh seeds sheet` needs it");
  // The disk floor warns and never fails or stops anything (devx/lib/disk.mjs; TL_DISK_FLOOR_GB, default 20).
  const d = diskReport(REPO); t("disk free", true, d.line.replace(/^disk: /, ""));
  return printVerdict("doctor", steps, d.error ? {} : { disk_free_gb: d.free_gb, disk_floor_gb: d.floor_gb, ...(d.low ? { disk_low: true } : {}) });
}
