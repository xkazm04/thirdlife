// Gate step: recipe cards name only what exists and what their seed shows. Static, no Godot.
import { REPO } from "../../ctx.mjs";
import { checkCards } from "../../cards/check.mjs";

export const id = "cards";
export const tiers = ["fast", "full"];
export const paths = ["engine/cards/**", "engine/seeds/**", "engine/kits/**", "engine/kernel/api/**", "engine/rigs/**", "assets/manifest.json", "contracts/CARDS.md", "contracts/pack.schema.json"];

export async function run(ctx) {
  const { steps } = checkCards({ root: ctx?.REPO ?? REPO });
  const failed = steps.filter((s) => !s.ok);
  return { ok: failed.length === 0, detail: failed.length ? failed.map((s) => `${s.id}: ${s.detail}`).join(" | ") : steps[0].detail };
}
