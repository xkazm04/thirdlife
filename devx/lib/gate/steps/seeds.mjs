import path from "node:path";
import { runScriptStep } from "../godot-step.mjs";
export const id = "seeds";
export const tiers = ["full"];
export const paths = ["engine/kernel/**", "engine/seeds/**", "engine/kits/**", "engine/style/**", "engine/tools/seeds.sh", "engine/tools/tl.sh", "engine/project.godot"];
export async function run(ctx) { return runScriptStep(ctx, path.join(ctx.ENGINE, "tools", "seeds.sh"), "seeds"); }
