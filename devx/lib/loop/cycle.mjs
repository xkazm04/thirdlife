// One watch cycle: the engine verbs in order, stopping at the first failure. The runner is injected for tests.
import { parseReport, findings } from "./findings.mjs";

export const VERB_ORDER = ["lint", "smoke", "bot"];

/** Keeps the cheap-to-expensive order whatever order the user typed. */
export function orderVerbs(list) {
  const want = new Set(list);
  const unknown = [...want].filter((v) => !VERB_ORDER.includes(v));
  if (unknown.length) throw new Error(`unknown verb '${unknown[0]}' (watch runs: ${VERB_ORDER.join(", ")})`);
  return VERB_ORDER.filter((v) => want.has(v));
}

/**
 * runVerb(verb) -> Promise<{code, stdout, stderr, ms}>.
 * Returns {results:[{verb, ok, ms, code, findings[]}], ok, aborted}. `isCancelled()` is polled between verbs.
 */
export async function runCycle(verbs, runVerb, isCancelled = () => false) {
  const results = [];
  for (const verb of verbs) {
    if (isCancelled()) return { results, ok: false, aborted: true };
    const r = await runVerb(verb);
    const report = parseReport(r.stdout);
    const ok = r.code === 0 && (report ? report.ok !== false : true);
    const res = { verb, ok, ms: r.ms, code: r.code, findings: ok ? [] : findings(report) };
    if (!ok && !res.findings.length) {
      const tail = (r.stderr || r.stdout || "").trim().split(/\r?\n/).slice(-3).join(" | ");
      res.findings = [{ kind: r.code === 2 ? "not_run" : "engine", where: "", message: `exit ${r.code}${report ? "" : ", no tl.verify/1 report"}${tail ? ": " + tail : ""}` }];
    }
    results.push(res);
    if (!ok) break;
  }
  return { results, ok: results.length > 0 && results.every((x) => x.ok), aborted: false };
}
