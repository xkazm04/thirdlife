// Two selftests that existed and were not gate steps (P1): the shareable items (`item.sh selftest`) and the designer panel's model
// (`ui.sh selftest`). Both are headless; a failure that only the clock explains is marked so the gate runs it once more, alone.
import fs from "node:fs";
import path from "node:path";
import { CLOCK_MARKERS } from "../flaky.mjs";

// Both selftests read the real marble job of the first night (site/marble-run-three-marbles-20261110-2), which is gitignored job output
// and exists only in the main checkout. In a worktree it is not there: item.sh then fails card.from_job and ui.sh selftest has been seen to
// hang (10 minutes, no output) when foreman/dist exists. A step that cannot have its input says so and passes: it is NOT a verdict on the code.
const MARBLE = "marble-run-three-marbles-20261110-2";
function marbleJob(ctx) {
  return [path.join(ctx.REPO, "site", MARBLE), path.join(ctx.REPO, "engine", "..", "site", MARBLE), path.resolve(ctx.ENGINE, "..", "..", "..", MARBLE)].find((d) => fs.existsSync(d)) ?? null;
}

function script(label, file, countRe) {
  return async function run(ctx) {
    if (!ctx.resolveGodot()) return { ok: false, detail: "no Godot found: set TL_GODOT or .tl/local.json (tl doctor)" };
    if (!marbleJob(ctx)) return { ok: true, detail: `SKIPPED, not judged: needs site/${MARBLE} (the real marble job, main checkout only); run this step there` };
    const r = ctx.bash(path.join(ctx.ENGINE, "tools", file), ["selftest"], { cwd: ctx.REPO, timeout: 10 * 60 * 1000 });
    const pass = (r.stdout.match(/^PASS /gm) ?? []).length;
    const count = (r.stdout.match(countRe) ?? [])[0] ?? `${pass} PASS lines`;
    if (r.code === 0 && pass > 0) return { ok: true, detail: count };
    const fails = r.stdout.split(/\r?\n/).filter((l) => l.startsWith("FAIL")).slice(0, 3).map((l) => l.slice(0, 160)).join(" | ");
    const clockOnly = !!fails && r.stdout.split(/\r?\n/).filter((l) => l.startsWith("FAIL")).every((l) => CLOCK_MARKERS.some((m) => m.test(l)) || /tick_timeout|frame_budget|starved/.test(l));
    return { ok: false, clockOnly, detail: `${label}: exit ${r.code}, ${pass} PASS; ${fails || r.stderr.trim().slice(0, 200) || "no PASS lines (did the selftest run?)"}` };
  };
}

export const steps = [
  { id: "item.selftest", tiers: ["full"], paths: ["engine/kernel/share/**", "engine/tools/item.sh", "engine/kernel/**", "docs/SHARING.md", "engine/project.godot"],
    run: script("item.sh selftest", "item.sh", /item selftest: \d+ passed, \d+ failed/) },
  { id: "ui.selftest", tiers: ["full"], paths: ["engine/ui/**", "engine/tools/ui.sh", "engine/project.godot"],
    run: script("ui.sh selftest", "ui.sh", /\[selftest\] \d+ passed, \d+ failed/) },
];
