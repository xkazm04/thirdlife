// Two selftests that existed and were not gate steps (P1): the shareable items (`item.sh selftest`) and the designer panel's model
// (`ui.sh selftest`). Both are headless; a failure that only the clock explains is marked so the gate runs it once more, alone.
// Counted against each script's own trailer line (docs/GATE-HONESTY.md).
import fs from "node:fs";
import path from "node:path";
import { CLOCK_MARKERS } from "../flaky.mjs";
import { judgeScript, NO_GODOT } from "../godot-step.mjs";

// Both selftests read the real marble job of the first night (site/marble-run-three-marbles-20261110-2), which is gitignored job output
// and exists only in the main checkout. In a worktree it is not there: item.sh then fails card.from_job and ui.sh selftest has been seen to
// hang (10 minutes, no output) when foreman/dist exists. A step that cannot have its input COULD NOT RUN (exit 2): it is not a verdict on
// the code, and it is not a pass either (it used to pass as "SKIPPED").
const MARBLE = "marble-run-three-marbles-20261110-2";
function marbleJob(ctx) {
  return [path.join(ctx.REPO, "site", MARBLE), path.join(ctx.REPO, "engine", "..", "site", MARBLE), path.resolve(ctx.ENGINE, "..", "..", "..", MARBLE)].find((d) => fs.existsSync(d)) ?? null;
}
const TIMEOUT_MS = 10 * 60 * 1000;

function script(label, file, trailer) {
  return async function run(ctx) {
    if (!ctx.resolveGodot()) return { ok: false, notRun: true, detail: NO_GODOT };
    if (!marbleJob(ctx)) return { ok: false, notRun: true, detail: `needs site/${MARBLE} (the real marble job, main checkout only); run this step there` };
    const r = ctx.bash(path.join(ctx.ENGINE, "tools", file), ["selftest"], { cwd: ctx.REPO, timeout: TIMEOUT_MS });
    const v = judgeScript(r, { label, trailer, timeoutMs: TIMEOUT_MS });
    if (v.ok || v.notRun) return v;
    const failLines = r.stdout.split(/\r?\n/).filter((l) => l.startsWith("FAIL"));
    const finished = trailer.test(r.stdout) && !r.timedOut;
    const clockOnly = finished && failLines.length > 0 && failLines.every((l) => CLOCK_MARKERS.some((m) => m.test(l)) || /tick_timeout|frame_budget|starved/.test(l));
    return { ...v, clockOnly };
  };
}

export const steps = [
  { id: "item.selftest", tiers: ["full"], paths: ["engine/kernel/share/**", "engine/tools/item.sh", "engine/kernel/**", "docs/SHARING.md", "engine/project.godot"],
    run: script("item.sh selftest", "item.sh", /^item selftest: (\d+) passed, (\d+) failed/m) },
  { id: "ui.selftest", tiers: ["full"], paths: ["engine/ui/**", "engine/tools/ui.sh", "engine/project.godot"],
    run: script("ui.sh selftest", "ui.sh", /^\[selftest\] (\d+) passed, (\d+) failed/m) },
];
