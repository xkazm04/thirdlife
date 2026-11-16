// Count drops (docs/GATE-HONESTY.md): a step that FOUND fewer units than its last green run of the same tier is a FAIL, unless
// the run declared it (`tl check --expect-drop <step>`). Pure: the history rows (.tl/gate-history.jsonl) are passed in.
//   * The baseline is the found count of the latest history row of the same tier in which that step was ok, not not_run, and
//     counted. A failed or not-run row never sets it; a row that does not hold the step (an --only or --changed run) is skipped.
//   * A step that is not ok, could not run, or has no count is never compared. Old rows without a key read as before.

const hasCount = (s) => Number.isInteger(s?.found);
const green = (s) => s && s.ok === true && !s.not_run && hasCount(s);

/** -> the found count of the step's last green run of `tier`, or undefined. */
export function baseline(history, stepId, tier) {
  for (let i = history.length - 1; i >= 0; i--) {
    const e = history[i];
    if (e?.tier !== tier) continue;
    const s = (e.steps ?? []).find((x) => x.id === stepId);
    if (green(s)) return s.found;
  }
  return undefined;
}

const signed = (d) => (d >= 0 ? `+${d}` : String(d));
const withNote = (detail, note) => `${detail ?? ""} (${note})`.trim();

/** results = the engine's verdict steps. -> {results, drops:[{id, was, now}]}: every ok, counted step gets its delta in the
 *  detail; an undeclared drop turns the step FAIL, reason first. */
export function judge(results, history, { tier, expected = [] } = {}) {
  const drops = [];
  const out = results.map((r) => {
    if (!r.ok || r.not_run || !hasCount(r)) return r;
    const was = baseline(history, r.id, tier);
    if (was === undefined) return { ...r, detail: withNote(r.detail, "no earlier count") };
    const d = r.found - was;
    if (d >= 0) return { ...r, detail: withNote(r.detail, `${signed(d)} vs last green`) };
    if (expected.includes(r.id)) return { ...r, detail: withNote(r.detail, `${d} vs last green, expected`) };
    drops.push({ id: r.id, was, now: r.found });
    return { ...r, ok: false, detail: `found ${r.found}, last green run found ${was} (${d}): fewer units than before; a real removal is declared with --expect-drop ${r.id}; ${r.detail ?? ""}`.replace(/; $/, "") };
  });
  return { results: out, drops };
}

/** --trend columns: per step id -> {last_found?, green_found?, drop?}. last = the step's latest counted run that was not not_run;
 *  green = the last green run of the same tier before it. drop only when last < green and the last row did not declare it. */
export function countTrend(history) {
  const per = new Map();
  for (let i = 0; i < history.length; i++) for (const s of history[i]?.steps ?? []) if (hasCount(s) && !s.not_run) per.set(s.id, i);
  const out = new Map();
  for (const [id, i] of per) {
    const e = history[i], last = e.steps.find((s) => s.id === id).found;
    const g = baseline(history.slice(0, i), id, e.tier);
    const declared = (e.expected_drop ?? []).includes(id);
    out.set(id, { last_found: last, ...(g !== undefined ? { green_found: g } : {}), ...(g !== undefined && last < g && !declared ? { drop: true } : {}) });
  }
  return out;
}
