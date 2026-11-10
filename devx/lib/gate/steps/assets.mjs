// Gate step: the asset manifest, budgets and hygiene, static (no Godot). Convention in the devx common brief.
import { REPO } from "../../ctx.mjs";
import { checkAssets } from "../../assets/check.mjs";

export const id = "assets";
export const tiers = ["fast", "full"];
export const paths = ["assets/**", "engine/kits/**", "contracts/ASSETS.md"];

export async function run(ctx) {
  const { steps } = checkAssets({ root: ctx?.REPO ?? REPO });
  const failed = steps.filter((s) => !s.ok);
  return { ok: failed.length === 0, detail: failed.length ? failed.map((s) => `${s.id}: ${s.detail}`).join(" | ") : `${steps.length} checks passed` };
}
