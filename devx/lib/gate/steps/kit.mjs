// `k.sh selftest` is headless: every kit part, rig and clip, twice with equal hashes, plus budgets (no wall-clock cases: no retry).
import path from "node:path";
export const id = "kit.selftest";
export const tiers = ["full"];
export const paths = ["engine/kits/**", "engine/rigs/**", "engine/style/**", "engine/kits_lab/**", "engine/tools/k.sh", "engine/project.godot"];
export async function run(ctx) {
  if (!ctx.resolveGodot()) return { ok: false, detail: "no Godot found: set TL_GODOT or .tl/local.json (tl doctor)" };
  const r = ctx.bash(path.join(ctx.ENGINE, "tools", "k.sh"), ["selftest"], { cwd: ctx.REPO, timeout: 10 * 60 * 1000 });
  const pass = (r.stdout.match(/\bPASS\b/g) ?? []).length;
  if (r.code === 0 && pass > 0) return { ok: true, detail: `${pass} PASS lines` };
  const fails = r.stdout.split(/\r?\n/).filter((l) => /FAIL|ERROR/.test(l)).slice(0, 3).map((l) => l.slice(0, 160)).join(" | ");
  return { ok: false, detail: `exit ${r.code}, ${pass} PASS; ${fails || r.stderr.trim().slice(0, 200) || "no PASS lines (did the selftest run?)"}` };
}
