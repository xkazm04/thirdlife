// Reads a tl.verify/1 report (contracts/RUNNER.md) and turns a failure into a few readable lines.

/** The report is the last JSON line of stdout. Returns the parsed object or null. */
export function parseReport(stdout) {
  const lines = String(stdout ?? "").split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  for (let i = lines.length - 1; i >= 0; i--) {
    if (!lines[i].startsWith("{")) continue;
    try { const o = JSON.parse(lines[i]); if (o && o.schema === "tl.verify/1") return o; } catch { /* keep looking upward */ }
  }
  return null;
}

/**
 * First `limit` findings of a failed report as {kind, where, message}. errors[] first (they carry file:line);
 * failed checks follow when errors[] is empty; a bot summary closes the list.
 */
export function findings(report, limit = 5) {
  if (!report) return [];
  const out = [];
  for (const e of report.errors ?? []) {
    out.push({ kind: e.kind ?? "error", where: e.file ? `${e.file}${e.line != null ? ":" + e.line : ""}` : "", message: String(e.message ?? "") });
  }
  if (!out.length) {
    for (const c of report.checks ?? []) if (c.ok === false) out.push({ kind: c.id, where: "", message: String(c.detail ?? "") });
  }
  const r = report.bot?.result;
  if (!out.length && r && r.ok === false) out.push({ kind: "bot", where: report.bot.test ?? "", message: String(r.summary ?? "bot reported not ok") });
  return out.slice(0, limit);
}

export const formatFinding = (f) => `${f.kind}${f.where ? "  " + f.where : ""}  ${f.message}`;
