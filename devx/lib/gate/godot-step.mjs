// Shared runner for the shell-script steps (kernel selftest, seeds, kit, item, ui): run with reports kept in a temp dir, count the
// PASS/FAIL case lines against the script's own trailer ("selftest: N passed, M failed"), classify a failure as clock-only from the
// reports (see flaky.mjs). A script without its trailer was stopped before its end: never a pass (docs/GATE-HONESTY.md).
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { cutShort, scriptCounts } from "./counts.mjs";
import { classify } from "./flaky.mjs";

// P7: 30 minutes (it was 15). This is a wall-clock limit on a script that grows with every package: with four other
// builders on the machine kernel.selftest (now 20 cases longer) ran past 15 minutes without a single failing case.
const TIMEOUT_MS = 30 * 60 * 1000;
export const NO_GODOT = "no Godot found: set TL_GODOT or .tl/local.json {\"godot\": ...} (tl doctor)";

/** The verdict over one finished script run. r = ctx.run result. -> step result with found/completed. */
export function judgeScript(r, { label, trailer, timeoutMs, reportDir = null }) {
  const c = scriptCounts(r.stdout, trailer);
  const cut = cutShort(r, timeoutMs);
  const counts = { found: c.found, completed: c.completed };
  if (r.signal && !r.timedOut) return { ok: false, notRun: true, ...counts, detail: `${label}: ${cut} after ${c.completed} cases` };
  if (r.code === 0 && c.trailer && !cut && c.failed === 0) return { ok: true, ...counts, detail: `${c.passed} cases passed` };
  const { failed, clockOnly } = reportDir ? classify(r.stdout, reportDir) : { failed: [], clockOnly: false };
  const fails = r.stdout.split(/\r?\n/).filter((l) => l.startsWith("FAIL")).slice(0, 3).map((l) => l.slice(0, 160)).join(" | ");
  const stop = cut || (!c.trailer ? `stopped before its trailer line (${c.completed} cases seen, exit ${r.code})` : "");
  const why = fails || `exit ${r.code}: ${(r.stderr || r.stdout).trim().split(/\r?\n/).slice(-2).join(" | ").slice(0, 240)}`;
  // A clock-only verdict needs the script to have finished: a cut-short run is not a slow case.
  const clock = clockOnly && c.trailer && !cut;
  return { ok: false, clockOnly: clock, ...counts, detail: `${label}: ${c.failed || failed.length} failed, ${c.passed} passed; ${stop ? stop + "; " : ""}${clock ? "clock-only: " : ""}${why}` };
}

export function runScriptStep(ctx, script, label, trailer = new RegExp(`^${label}: (\\d+) passed, (\\d+) failed`, "m")) {
  if (!ctx.resolveGodot()) return { ok: false, notRun: true, detail: NO_GODOT };
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tl_gate_"));
  try {
    const r = ctx.bash(script, [], { cwd: ctx.REPO, timeout: TIMEOUT_MS, env: { TL_SELFTEST_DIR: dir } });
    return judgeScript(r, { label, trailer, timeoutMs: TIMEOUT_MS, reportDir: dir });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
