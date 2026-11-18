// Lane C4 (18 Nov): what `foreman status` and `foreman explain` say about the job's recipe card and its hand checks.
// Read only: the card from ref/cards/ (the copy the job was built with), the hand checks from the reports each check
// left (reports/hand-checks-s<seq>.json, handcheck.ts), the rounds they cost from the log (`reopened`, "hand check failed").
import fs from "node:fs";
import path from "node:path";
import type { JobEvent } from "./events.js";
import type { JobState } from "./joblog.js";
import { cardOf } from "./cards.js";
import { HAND_SUMMARY, handsOf, type HandSummary } from "./handcheck.js";
import { HAND_CHECK } from "./rounds.js";

export interface CardView {
  /** Absent: the plan names no card. */
  card?: { id: string; version: string; title: string; checks: number };
  /** One entry per hand check that ran, oldest first. */
  checks: { seq: number; summary: HandSummary }[];
  /** Packages sent back for a round by a failed hand check, with the event that sent them. */
  sentBack: { package: string; seq: number }[];
}

export function cardView(jobDir: string, state: JobState, events: readonly JobEvent[]): CardView {
  const c = state.card !== undefined ? cardOf(path.join(jobDir, "ref"), state.card) : undefined;
  const card = state.card === undefined ? undefined : { id: state.card, version: c?.version ?? "?", title: c?.title ?? "(not in ref/cards/)", checks: handsOf(c)?.checks.length ?? 0 };
  const dir = path.join(jobDir, "reports");
  const checks: CardView["checks"] = [];
  for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) {
    const m = /^hand-checks-s(\d+)\.json$/.exec(f);
    if (!m) continue;
    try {
      const summary = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")) as HandSummary;
      if (summary.schema === HAND_SUMMARY) checks.push({ seq: Number(m[1]), summary });
    } catch {
      /* a torn report is skipped: the verify events stay the record */
    }
  }
  checks.sort((a, b) => a.seq - b.seq);
  const sentBack = events.filter((e): e is Extract<JobEvent, { type: "reopened" }> => e.type === "reopened" && e.reason.startsWith(HAND_CHECK)).map((e) => ({ package: e.package, seq: e.seq }));
  return { ...(card ? { card } : {}), checks, sentBack };
}

const bound = (r: { wins_min?: number; wins_max?: number }): string =>
  [r.wins_min !== undefined ? `at least ${r.wins_min}` : "", r.wins_max !== undefined ? `at most ${r.wins_max}` : ""].filter(Boolean).join(", ");

/** The lines status and explain print: the card, then one line per hand of every check that ran. */
export function cardLines(v: CardView): string[] {
  if (!v.card) return ["card     no card (the Planner named none)"];
  const lines = [`card     ${v.card.id} v${v.card.version}  "${v.card.title}"  ${v.card.checks > 0 ? `${v.card.checks} hand check(s)` : "no hand checks in this card"}`];
  if (v.card.checks > 0 && v.checks.length === 0) lines.push("hands    not run yet (they run at the final verification)");
  v.checks.forEach((c, i) => {
    const next = v.checks[i + 1]?.seq ?? Infinity;
    const back = v.sentBack.filter((b) => b.seq > c.seq && b.seq < next).map((b) => b.package);
    for (const r of c.summary.rows) {
      lines.push(`hands    ${v.checks.length > 1 ? `#${i + 1} ` : ""}${r.hand.padEnd(9)} ${String(r.wins).padStart(2)} of ${String(r.completed).padEnd(3)} ${bound(r).padEnd(14)} ${r.ok ? "holds" : "MISSED"}${r.completed < r.seeds ? `  (${r.completed} of ${r.seeds} runs finished)` : ""}`);
    }
    if (back.length > 0) lines.push(`hands    #${i + 1} missed: one round was sent back to ${back.join(", ")}`);
  });
  return lines;
}
