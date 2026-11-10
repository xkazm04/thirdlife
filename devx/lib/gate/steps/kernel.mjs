import path from "node:path";
import { runScriptStep } from "../godot-step.mjs";
export const id = "kernel.selftest";
export const tiers = ["full"];
export const paths = ["engine/kernel/**", "engine/tools/selftest.sh", "engine/tools/tl.sh", "engine/project.godot", "contracts/RUNNER.md"];
export async function run(ctx) { return runScriptStep(ctx, path.join(ctx.ENGINE, "tools", "selftest.sh"), "selftest"); }
