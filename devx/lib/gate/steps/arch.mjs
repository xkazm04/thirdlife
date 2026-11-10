// Gate step: static architecture rules (devx/arch.rules.json). No Godot; well under a second on the real tree.
import { REPO } from "../../ctx.mjs";
import { runRules } from "../../arch/core.mjs";

export const id = "arch";
export const tiers = ["fast", "full"];
export const paths = ["engine/**", "contracts/**", "devx/**", "docs/generated/**"];

export async function run(ctx = {}) {
  const { results } = runRules({ root: ctx.repo ?? REPO });
  const bad = results.filter((r) => !r.ok);
  if (!bad.length) return { ok: true, detail: `${results.length} rules` };
  const first = bad[0].findings[0];
  return { ok: false, detail: `${bad.map((r) => r.rule.id).join(", ")}: ${first.file}${first.line ? ":" + first.line : ""} ${first.message}`.slice(0, 300) };
}
