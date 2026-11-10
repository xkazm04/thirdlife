// The gate engine: select steps (tier, --only, --changed), run them in order, retry a clock-only failure once, build the verdict.
// Pure of process state: steps, git and the history file are injected (that is the test seam).
import { step as mkStep } from "../ctx.mjs";
import { changedPaths, mapChanged } from "./changed.mjs";
import { appendHistory, loadFigure } from "./history.mjs";

export const FLAKY_LABEL = "flaky-retry-passed";

/** Which steps run. -> {selected, error?, note?}. `error` means "could not run" (exit 2). */
export function select(all, { tier = "full", only = null, changed = false, base = "HEAD", git = null } = {}) {
  let pool = all;
  let note = "";
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
    if (!paths.length) { note = `no changes against ${base}`; pool = []; }
    else if (m.all) note = `all steps: ${m.unmatched.length} changed path(s) match no step (${m.unmatched.slice(0, 3).join(", ")}${m.unmatched.length > 3 ? ", ..." : ""})`;
    else { pool = pool.filter((s) => m.ids.has(s.id)); note = `${paths.length} changed path(s) -> ${pool.map((s) => s.id).join(", ") || "no step"}`; }
  }
  return { selected: pool, note };
}

async function runOnce(s, ctx) {
  const t0 = Date.now();
  try {
    const r = await s.run(ctx);
    if (!r || typeof r !== "object" || typeof r.ok !== "boolean") return { ok: false, detail: `step '${s.id}' (${s.file ?? "?"}) returned a malformed result (need {ok:boolean, detail?:string})`, ms: Date.now() - t0 };
    return { ok: r.ok, detail: String(r.detail ?? ""), clockOnly: !!r.clockOnly, ms: Date.now() - t0 };
  } catch (e) {
    return { ok: false, detail: `step '${s.id}' (${s.file ?? "?"}) threw: ${String(e?.message ?? e).split("\n")[0]}`, ms: Date.now() - t0 };
  }
}

/** Runs one step; a failure marked clockOnly is retried ONCE, alone. Returns a verdict step. */
export async function runStep(s, ctx) {
  const first = await runOnce(s, ctx);
  if (first.ok) return { ...mkStep(s.id, true, first.ms, first.detail), retried: false };
  if (!first.clockOnly) return { ...mkStep(s.id, false, first.ms, first.detail), retried: false };
  const second = await runOnce(s, { ...ctx, retry: true });
  const ms = first.ms + second.ms;
  if (second.ok) return { ...mkStep(s.id, true, ms, `${FLAKY_LABEL}: ${first.detail}`.trim()), retried: true, flaky: true };
  return { ...mkStep(s.id, false, ms, `failed again after clock-only retry: ${second.detail}`), retried: true };
}

export async function runGate(opts) {
  const { steps: all, broken = [], ctx, historyFile = null, log = () => {} } = opts;
  const sel = select(all, opts);
  if (sel.error) return { exit: 2, error: sel.error, results: [], extra: {} };
  const t0 = Date.now();
  const results = [];
  for (const b of broken) results.push({ ...mkStep(`gate:${b.file}`, false, 0, `${b.file}: ${b.message}`), retried: false });
  for (const s of sel.selected) { log(`... ${s.id}`); results.push(await runStep(s, ctx)); }
  const load = await loadFigure();
  const flakyRetries = results.filter((r) => r.flaky).length;
  const extra = { tier: opts.tier ?? "full", ms: Date.now() - t0, load, flaky_retries: flakyRetries, note: sel.note || undefined };
  if (historyFile) appendHistory(historyFile, { ts: new Date().toISOString(), tier: extra.tier, load, steps: results.map((r) => ({ id: r.id, ms: r.ms, ok: r.ok, retried: !!r.retried })) });
  return { exit: results.every((r) => r.ok) ? 0 : 1, results, extra, note: sel.note };
}
