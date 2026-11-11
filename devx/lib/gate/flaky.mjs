// Clock-only failure detection for the Godot-backed steps (kernel selftest, seeds).
// Evidence (contracts/RUNNER.md "Wall-clock exceptions"): only a tick over 250 ms (`watchdog.reason == "tick_timeout"`), a setup call
// over 10 s (same watchdog, phase _pack_setup) and the physics p99 budget (check `invariants.frame_budget`) read a clock.
// The shell scripts print `FAIL <case>: <why>` and keep each case's report in $TL_SELFTEST_DIR/<case>.json, so we read those.
import fs from "node:fs";
import path from "node:path";

// P1: a tick_timeout now means processor time (a runaway script); a run the machine starved is an engine error "starved: ..."
// (outcome not_run). Both stay listed: a gate retry of either costs little and the report says which it was.
export const CLOCK_MARKERS = [/"reason":"tick_timeout"/, /"id":"invariants\.frame_budget","ok":false/, /"message":"starved: /];

export function failedCases(stdout) {
  return [...String(stdout).matchAll(/^FAIL ([^\s:]+)/gm)].map((m) => m[1]);
}

/** -> {failed:[names], clockOnly:boolean}. clockOnly needs >=1 failed case and EVERY failed case's report to carry a clock marker.
 *  A failure we cannot read (no report, no FAIL line) is never clock-only: unknown means real. */
export function classify(stdout, reportDir, markers = CLOCK_MARKERS) {
  const failed = failedCases(stdout);
  if (!failed.length) return { failed, clockOnly: false };
  const clock = (name) => {
    try { const txt = fs.readFileSync(path.join(reportDir, name + ".json"), "utf8"); return markers.some((m) => m.test(txt)); } catch { return false; }
  };
  return { failed, clockOnly: failed.every(clock) };
}
