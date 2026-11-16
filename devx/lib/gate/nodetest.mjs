// Shared by the node --test steps (devx.test, foreman.test): judge a run by its counts, keep its whole output.
import fs from "node:fs";
import path from "node:path";
import { cutShort, failingTests, nodeTestCounts } from "./counts.mjs";

/** The whole output of a run, kept where the verdict line says (.tl/last/<step>.log; .tl/ is gitignored). */
export function keepLog(repo, stepId, r) {
  const file = path.join(repo, ".tl", "last", `${stepId}.log`);
  try { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, `exit ${r.code}${r.timedOut ? " (timed out)" : ""}${r.signal ? " signal " + r.signal : ""}
--- stdout
${r.stdout}
--- stderr
${r.stderr}
`); return true; } catch { return false; }
}

/** Shared by devx.test and foreman.test: r = ctx.run result of a node --test run. */
export function judgeNodeTest(r, { files, timeoutMs, log = null, label = "" }) {
  const c = nodeTestCounts(r.stdout);
  const cut = cutShort(r, timeoutMs);
  const where = files ? ` across ${files} files` : "";
  const sum = c.summary ? `${c.pass} pass, ${c.fail} fail${c.cancelled ? `, ${c.cancelled} cancelled` : ""}${c.skipped ? `, ${c.skipped} skipped` : ""}${where}` : `no summary line${where}`;
  const keep = log ? ` (full output: ${log})` : "";
  if (r.signal && !r.timedOut) return { ok: false, notRun: true, found: c.found, completed: c.completed, detail: `${label}${cut}: ${sum}${keep}` };
  if (r.code === 0 && c.summary && !cut && c.fail === 0 && c.cancelled === 0) return { ok: true, found: c.found, completed: c.completed, detail: sum };
  const names = failingTests(r.stdout).slice(0, 5).join(" | ").slice(0, 400);
  const why = cut || (!c.summary ? "the run stopped before its summary" : "");
  const rest = names || (r.stderr || r.stdout).trim().split(/\r?\n/).filter((l) => l.trim()).slice(-2).join(" | ").slice(0, 240);
  return { ok: false, found: c.summary ? c.found : Math.max(c.found, 1), completed: c.completed, detail: `${label}${why ? why + "; " : ""}${sum}; ${rest}${keep}` };
}
