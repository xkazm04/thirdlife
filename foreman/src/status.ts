// The text of `foreman status` and of the event lines `run` prints: moved verbatim out of cli.ts (re-exported there).
import type { JobEvent } from "./events.js";
import { currentPhase, waitingPhase, type JobState } from "./joblog.js";
import { qualityLines } from "./cli_quality.js";
import { lookOk } from "./quality_state.js";

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
    case "aspect_reacted":
      return `${head} ${ev.aspect} -> ${ev.choice}${ev.note !== undefined ? `: ${ev.note.replace(/\s+/g, " ").slice(0, 200)}` : ""}`;
    case "phase_done":
      return `${head} ${ev.phase}`;
    case "phase_reviewed":
      return `${head} ${ev.phase} ${ev.verdict} by ${ev.by}${ev.note !== undefined ? `: ${ev.note.replace(/\s+/g, " ").slice(0, 200)}` : ""}`;
    default:
      return head;
  }
}

/**
 * JOB.md 2026-11-20: the designer v2 part of `foreman status`: creativity, the pitch, the aspect cards with the
 * player's reactions, the phase strip, and, when the job waits, which phase and the command that answers it.
 */
export function designLines(s: JobState): string[] {
  const out: string[] = [];
  const mode = [s.creativity === "crazy" ? "crazy" : "standard", s.runThrough ? "run-through" : "", s.briefs > 1 ? `design ${s.briefs}` : ""].filter(Boolean).join(", ");
  const c = s.brief?.concept; // JOB.md 2026-11-21: the design room
  if (c) out.push(`concept  ${c.anchor} where ${c.hook} (candidate ${c.chosen + 1} of ${c.candidates.length}, likelihood ${c.candidates[c.chosen]?.likelihood ?? "?"})`);
  for (const r of s.reviews) out.push(`review   round ${r.round} ${r.verdict}: ${Object.entries(r.scores).map(([k, v]) => `${k} ${v}`).join(", ")}; ${r.notes.replace(/\s+/g, " ").slice(0, 160)}`);
  if (s.brief?.pitch !== undefined || s.creativity !== undefined || s.runThrough) out.push(`design   ${mode}${s.brief?.pitch !== undefined ? `: ${s.brief.pitch}` : ""}`);
  for (const a of s.brief?.aspects ?? []) {
    const r = s.reactions[a.id];
    const react = r === undefined ? "" : `  -> ${r.choice}${r.note !== undefined ? ` ("${r.note.replace(/\s+/g, " ").slice(0, 60)}")` : ""}`;
    out.push(`aspect   ${a.id.padEnd(14)} [${a.icon}]${a.crazy === true ? " CRAZY" : ""} ${a.title}: ${a.line}${react}`);
  }
  if (s.brief?.aspects?.length && !s.briefApprovedBy) out.push(`next     foreman react ${s.job} <aspect> keep|drop|<alternative> [--note "..."]  |  foreman redesign ${s.job}  |  foreman approve ${s.job}`);
  const cur = currentPhase(s);
  s.phases.forEach((ph, i) => {
    const mark = ph === cur ? (ph.state === "done" ? "WAITING" : ph.state === "held" ? "HELD" : s.jobState ? "BUILDING" : "first") : ph.state === "passed" ? "passed" : "later";
    out.push(`phase    ${i + 1}/${s.phases.length} ${ph.id.padEnd(14)} ${mark.padEnd(8)} ${ph.packages.join(", ")}; try: ${ph.try}`);
  });
  const wait = waitingPhase(s);
  if (wait) {
    out.push(
      s.runThrough
        ? `waiting  phase ${wait.id} is done; run-through passes it when the Foreman runs: foreman resume ${s.job}`
        : `waiting  phase ${wait.id} is done: try it ("${wait.try}"), then: foreman phase ${s.job} pass   or   foreman phase ${s.job} hold --note "<what to change>"`,
    );
  } else if (cur?.state === "held" && cur.hold !== undefined) {
    out.push(`held     phase ${cur.id}: ${cur.hold.applied ? "its change round runs" : "its change round starts when the Foreman runs"} for: ${cur.hold.note.replace(/\s+/g, " ").slice(0, 120)}`);
  }
  return out;
}

/** `card`: the lines of handview.ts cardLines (the recipe card and its hand checks), printed under the plan line. */
export function statusTable(s: JobState, card: string[] = []): string {
  const lines: string[] = [];
  lines.push(`job      ${s.job}${s.title ? `  "${s.title}"` : ""}${s.packId ? `  pack ${s.packId}` : ""}`);
  lines.push(`state    ${s.jobState?.state ?? "created"}${s.jobState?.reason ? `  (${s.jobState.reason})` : ""}   events ${s.lastSeq}${s.tornTail ? "   TORN LAST LINE" : ""}`);
  lines.push(`brief    ${s.brief ? (s.briefApprovedBy ? `approved by ${s.briefApprovedBy}` : "set, not approved") : "none"}   plan ${s.plan.length > 0 ? `${s.plan.length} packages (revision ${s.planRevision})` : "none"}`);
  lines.push(...designLines(s));
  lines.push(...card);
  if (s.billing) lines.push(`billing  ${s.billing.adapter} ${s.billing.mode}: ${s.billing.evidence}`);
  if (s.budget) lines.push(`budget   ${s.budget.policy.kind}${s.budget.policy.limit !== undefined ? ` ${s.budget.policy.limit}` : ""} ${s.budget.state}: ${s.budget.reason}`);
  lines.push(`tokens   in ${s.tokens.in}  out ${s.tokens.out}${s.tokens.unreportedRuns > 0 ? `  (${s.tokens.unreportedRuns} runs reported none)` : ""}`);
  if (s.promoted) lines.push(`promoted ${s.promoted.packId} ${s.promoted.version} -> ${s.promoted.dest}${s.promotions.length > 1 ? `  (promotion ${s.promotions.length}; earlier: ${s.promotions.slice(0, -1).map((p) => `${p.version} ${p.dest}`).join(", ")})` : ""}`);
  for (const c of s.changes) lines.push(`change   #${c.seq} ${c.state}${c.owner ? ` -> ${c.owner}` : c.package ? ` (for ${c.package})` : ""}: ${c.text.replace(/\s+/g, " ").slice(0, 100)}`);
  if (s.replans > 0) lines.push(`replans  ${s.replans}${s.pendingReplan ? " (the last one has no plan_set yet)" : ""}`);
  for (const m of s.milestones) lines.push(`milestone ${m.milestone}${m.round !== undefined ? ` round ${m.round} kept ${m.kept ?? "?"}` : ""}: ${lookOk(m.summary) ? "" : "NOT ok, "}${m.captures.length} capture(s)${m.strips?.length ? `, ${m.strips.length} strip(s)` : ""}${m.captures.length > 0 ? ` (${m.captures.join(", ")})` : ""}`);
  lines.push(...qualityLines(s));
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
