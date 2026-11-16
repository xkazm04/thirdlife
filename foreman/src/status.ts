// The text of `foreman status` and of the event lines `run` prints: moved verbatim out of cli.ts (re-exported there).
import type { JobEvent } from "./events.js";
import type { JobState } from "./joblog.js";

export function eventLine(ev: JobEvent): string {
  const head = `${String(ev.seq).padStart(4)} ${ev.ts.slice(11, 19)} ${ev.type.padEnd(13)}`;
  switch (ev.type) {
    case "package_state":
      return `${head} ${ev.package} ${ev.state} r${ev.round}${ev.cause ? ` cause=${ev.cause}` : ""}${ev.detail ? ` (${ev.detail})` : ""}`;
    case "builder_run":
      return `${head} ${ev.package ?? "(job)"} ${ev.adapter}/${ev.mode} ${ev.outcome} ${ev.durationMs}ms${ev.tokensIn !== undefined ? ` in=${ev.tokensIn} out=${ev.tokensOut ?? 0}` : ""}${ev.tokensCacheRead !== undefined ? ` cacheRead=${ev.tokensCacheRead}` : ""}`;
    case "verify":
      return `${head} ${ev.package ?? "(pack)"} ${ev.verb} ${ev.level} ${ev.ok ? "ok" : "FAILED"}${ev.exitCode !== undefined ? ` exit=${ev.exitCode}` : ""} ${ev.report}`;
    case "merge":
      return `${head} ${ev.package} ${ev.files.length} files`;
    case "billing":
      return `${head} ${ev.adapter} ${ev.mode}: ${ev.evidence}`;
    case "budget":
      return `${head} ${ev.state}: ${ev.reason}`;
    case "job_state":
      return `${head} ${ev.state}${ev.reason ? `: ${ev.reason}` : ""}`;
    case "promoted":
      return `${head} ${ev.packId} ${ev.version} -> ${ev.dest}`;
    case "milestone":
      return `${head} ${ev.milestone}: ${ev.summary}`;
    case "question":
      return `${head} ${ev.package}: ${ev.text}`;
    case "note":
      return `${head} ${ev.package} r${ev.round} ${ev.text.startsWith("[foreman] ") ? "" : "deviations: "}${ev.text.replace(/\s+/g, " ").slice(0, 300)}`;
    case "change_requested":
      return `${head} ${ev.package ?? "(owner to be named)"}: ${ev.text.replace(/\s+/g, " ").slice(0, 300)}`;
    case "reopened":
      return `${head} ${ev.package}: ${ev.reason.replace(/\s+/g, " ").slice(0, 300)}`;
    default:
      return head;
  }
}

export function statusTable(s: JobState): string {
  const lines: string[] = [];
  lines.push(`job      ${s.job}${s.title ? `  "${s.title}"` : ""}${s.packId ? `  pack ${s.packId}` : ""}`);
  lines.push(`state    ${s.jobState?.state ?? "created"}${s.jobState?.reason ? `  (${s.jobState.reason})` : ""}   events ${s.lastSeq}${s.tornTail ? "   TORN LAST LINE" : ""}`);
  lines.push(`brief    ${s.brief ? (s.briefApprovedBy ? `approved by ${s.briefApprovedBy}` : "set, not approved") : "none"}   plan ${s.plan.length > 0 ? `${s.plan.length} packages (revision ${s.planRevision})` : "none"}`);
  if (s.billing) lines.push(`billing  ${s.billing.adapter} ${s.billing.mode}: ${s.billing.evidence}`);
  if (s.budget) lines.push(`budget   ${s.budget.policy.kind}${s.budget.policy.limit !== undefined ? ` ${s.budget.policy.limit}` : ""} ${s.budget.state}: ${s.budget.reason}`);
  lines.push(`tokens   in ${s.tokens.in}  out ${s.tokens.out}${s.tokens.unreportedRuns > 0 ? `  (${s.tokens.unreportedRuns} runs reported none)` : ""}`);
  if (s.promoted) lines.push(`promoted ${s.promoted.packId} ${s.promoted.version} -> ${s.promoted.dest}${s.promotions.length > 1 ? `  (promotion ${s.promotions.length}; earlier: ${s.promotions.slice(0, -1).map((p) => `${p.version} ${p.dest}`).join(", ")})` : ""}`);
  for (const c of s.changes) lines.push(`change   #${c.seq} ${c.state}${c.owner ? ` -> ${c.owner}` : c.package ? ` (for ${c.package})` : ""}: ${c.text.replace(/\s+/g, " ").slice(0, 100)}`);
  if (s.replans > 0) lines.push(`replans  ${s.replans}${s.pendingReplan ? " (the last one has no plan_set yet)" : ""}`);
  for (const m of s.milestones) lines.push(`milestone ${m.milestone}: ${m.captures.length} capture(s)${m.captures.length > 0 ? ` (${m.captures.join(", ")})` : ""}`);
  const rows = s.order.map((id) => {
    const p = s.packages[id];
    if (!p) return [id, "?", "", "", "", "", ""];
    const last = p.lastVerify ? `${p.lastVerify.verb} ${p.lastVerify.ok ? "ok" : "FAILED"} r${p.lastVerify.round}` : "";
    return [p.id, p.state, String(p.round), p.milestone, String(p.builderRuns), p.cause ?? "", last, p.detail ?? ""];
  });
  const head = ["package", "state", "round", "milestone", "runs", "cause", "last verify", "detail"];
  const widths = head.map((h, i) => Math.min(i === 7 ? 60 : 24, Math.max(h.length, ...rows.map((r) => (r[i] ?? "").length))));
  const fmt = (r: string[]): string => r.map((c, i) => (c.length > (widths[i] ?? 0) ? c.slice(0, (widths[i] ?? 1) - 1) + "~" : c).padEnd(widths[i] ?? 0)).join("  ").trimEnd();
  lines.push("");
  lines.push(fmt(head));
  lines.push(widths.map((w) => "-".repeat(w)).join("  "));
  for (const r of rows) lines.push(fmt(r));
  return lines.join("\n");
}
