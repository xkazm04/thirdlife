// `k.sh selftest` is headless: every kit part, rig and clip, twice with equal hashes, plus budgets (no wall-clock cases: no retry).
// Counted against the selftest's own trailer "[selftest] N passed, M failed: RESULT ..." (docs/GATE-HONESTY.md).
import path from "node:path";
import { judgeScript, NO_GODOT } from "../godot-step.mjs";
export const id = "kit.selftest";
export const tiers = ["full"];
export const paths = ["engine/kits/**", "engine/rigs/**", "engine/style/**", "engine/kits_lab/**", "engine/tools/k.sh", "engine/project.godot"];
export const TRAILER = /^\[selftest\] (\d+) passed, (\d+) failed/m;
const TIMEOUT_MS = 10 * 60 * 1000;
export async function run(ctx) {
  if (!ctx.resolveGodot()) return { ok: false, notRun: true, detail: NO_GODOT };
  const r = ctx.bash(path.join(ctx.ENGINE, "tools", "k.sh"), ["selftest"], { cwd: ctx.REPO, timeout: TIMEOUT_MS });
  const v = judgeScript(r, { label: "k.sh selftest", trailer: TRAILER, timeoutMs: TIMEOUT_MS });
  return { ...v, clockOnly: false };
}
