// The gate engine: select steps (tier, --only, --changed), run them in order, retry a clock-only failure once, build the verdict.
// Pure of process state: steps, git and the history file are injected (that is the test seam).
//
// The step contract (docs/GATE-HONESTY.md): run(ctx) -> {ok:boolean, detail?:string, clockOnly?:boolean,
//   found?:int, completed?:int, notRun?:boolean}
//   * found/completed: the units (tests, cases, rules) the underlying run found and the ones it carried to a verdict. When given,
//     the engine FAILS the step on found == 0 or completed != found, whatever `ok` says.
//   * notRun: the step could not run here (no Godot, no foreman/node_modules, no input, the machine too busy to judge, killed from
//     outside). It is never a pass: the gate exits 2 ("could not run") when nothing failed and something could not run.
import { step as mkStep } from "../ctx.mjs";
import { changedPaths, mapChanged } from "./changed.mjs";
import { countProblem } from "./counts.mjs";
import { appendHistory, loadFigure } from "./history.mjs";

export const FLAKY_LABEL = "flaky-retry-passed";
export const NOT_RUN = "could not run";

/** Which steps run. -> {selected, error?, note?, nothingChanged?}. `error` means "could not run" (exit 2). */
export function select(all, { tier = "full", only = null, changed = false, base = "HEAD", git = null } = {}) {
  let pool = all;
  let note = "";
  let nothingChanged = false;
  if (only) {
    const missing = only.filter((id) => !all.some((s) => s.id === id));
    if (missing.length) return { selected: [], error: `unknown step: ${missing.join(", ")} (have: ${all.map((s) => s.id).join(", ") || "none"})` };
    pool = all.filter((s) => only.includes(s.id));
  } else {
    pool = tier === "fast" ? all.filter((s) => s.tiers.includes("fast")) : all;
  }
  if (changed) {
    let paths;
    try { paths = changedPaths(git, base); } catch (e) { return { selected: [], error: `--changed: git failed: ${e.message}` }; }
    const m = mapChanged(paths, all);
    if (!paths.length) { note = `no changes against ${base}`; pool = []; nothingChanged = true; }
    else if (m.all) note = `all steps: ${m.unmatched.length} changed path(s) match no step (${m.unmatched.slice(0, 3).join(", ")}${m.unmatched.length > 3 ? ", ..." : ""})`;
    else { pool = pool.filter((s) => m.ids.has(s.id)); note = `${paths.length} changed path(s) -> ${pool.map((s) => s.id).join(", ") || "no step"}`; nothingChanged = !pool.length; }
  }
  return { selected: pool, note, nothingChanged };
}

const isCount = (v) => v !== undefined;

async function runOnce(s, ctx) {
  const t0 = Date.now();
  try {
    const r = await s.run(ctx);
    if (!r || typeof r !== "object" || typeof r.ok !== "boolean") return { ok: false, detail: `step '${s.id}' (${s.file ?? "?"}) returned a malformed result (need {ok:boolean, detail?:string})`, ms: Date.now() - t0 };
    const counts = { ...(isCount(r.found) ? { found: r.found } : {}), ...(isCount(r.completed) ? { completed: r.completed } : {}) };
    const detail = String(r.detail ?? "");
    if (r.notRun) return { ok: false, notRun: true, detail: detail.startsWith(NOT_RUN) ? detail : `${NOT_RUN}: ${detail}`, ms: Date.now() - t0, ...counts };
    const bad = countProblem(r);
    if (bad) return { ok: false, detail: `${bad}${r.ok ? " (the step itself said ok)" : ""}; ${detail}`, ms: Date.now() - t0, ...counts };
    return { ok: r.ok, detail, clockOnly: !!r.clockOnly, ms: Date.now() - t0, ...counts };
  } catch (e) {
    return { ok: false, detail: `step '${s.id}' (${s.file ?? "?"}) threw: ${String(e?.message ?? e).split("\n")[0]}`, ms: Date.now() - t0 };
  }
}

const tail = (r) => ({ ...(isCount(r.found) ? { found: r.found } : {}), ...(isCount(r.completed) ? { completed: r.completed } : {}), ...(r.notRun ? { not_run: true } : {}) });

/** Runs one step; a failure marked clockOnly is retried ONCE, alone. Returns a verdict step. */
export async function runStep(s, ctx) {
  const first = await runOnce(s, ctx);
  if (first.ok) return { ...mkStep(s.id, true, first.ms, first.detail), ...tail(first), retried: false };
  if (!first.clockOnly) return { ...mkStep(s.id, false, first.ms, first.detail), ...tail(first), retried: false };
  const second = await runOnce(s, { ...ctx, retry: true });
  const ms = first.ms + second.ms;
  if (second.ok) return { ...mkStep(s.id, true, ms, `${FLAKY_LABEL}: ${first.detail}`.trim()), ...tail(second), retried: true, flaky: true };
  return { ...mkStep(s.id, false, ms, `failed again after clock-only retry: ${second.detail}`), ...tail(second), retried: true };
}

/** exit: 1 when anything failed; else 2 when anything could not run; else 0. Zero steps selected is a FAIL ("found 0"), except
 *  under --changed when nothing changed (or nothing changed that any step claims): then there was nothing to check, and the note says so. */
export async function runGate(opts) {
  const { steps: all, broken = [], ctx, historyFile = null, log = () => {} } = opts;
  const sel = select(all, opts);
  if (sel.error) return { exit: 2, error: sel.error, results: [], extra: {} };
  const t0 = Date.now();
  const results = [];
  for (const b of broken) results.push({ ...mkStep(`gate:${b.file}`, false, 0, `${b.file}: ${b.message}`), retried: false });
  if (!sel.selected.length && !broken.length && !sel.nothingChanged) results.push({ ...mkStep("gate", false, 0, "found 0 steps to run: nothing was checked"), retried: false });
  for (const s of sel.selected) { log(`... ${s.id}`); results.push(await runStep(s, ctx)); }
  const load = await loadFigure();
  const flakyRetries = results.filter((r) => r.flaky).length;
  const notRun = results.filter((r) => r.not_run).map((r) => r.id);
  const counted = results.filter((r) => isCount(r.found));
  const extra = { tier: opts.tier ?? "full", ms: Date.now() - t0, load, flaky_retries: flakyRetries, note: sel.note || undefined,
    steps_found: sel.selected.length, steps_completed: sel.selected.filter((s) => results.some((r) => r.id === s.id)).length,
    units_found: counted.reduce((a, r) => a + r.found, 0), units_completed: counted.reduce((a, r) => a + (r.completed ?? 0), 0),
    ...(notRun.length ? { not_run: notRun } : {}) };
  if (historyFile) appendHistory(historyFile, { ts: new Date().toISOString(), tier: extra.tier, load, steps: results.map((r) => ({ id: r.id, ms: r.ms, ok: r.ok, retried: !!r.retried, ...tail(r) })) });
  const failed = results.some((r) => !r.ok && !r.not_run);
  return { exit: failed ? 1 : notRun.length ? 2 : 0, results, extra, note: sel.note };
}
