// The quality loop (JOB.md "Added 2026-11-21") read from the log: where one milestone stands. Pure: events in, a
// decision out; quality.ts acts on it. The loop:
//   look 0 (the first captures and critic): ok -> `milestone` (no round), done; NOT ok -> snapshot, revise round 1.
//   look k >= 1: the critic compares with the previous look and keeps the better (`kept`); `milestone {round: k}`.
//     The kept version is ok -> done; NOT ok and k < 2 -> snapshot, revise round k + 1; NOT ok at k >= 2 -> the job
//     holds (`job_state paused` reason "quality") until `foreman quality <job> accept|retry` (a `comment`).
//   accept -> done; retry -> one more revise round with the owner's note, then a look again (and a hold again).
import type { JobEvent } from "./events.js";
import { criticRoundOf } from "./rounds.js";

/** Revise rounds before the job holds for the owner. */
export const QUALITY_ROUNDS = 2;
/** The pause reason of a quality hold. */
export const QUALITY_PAUSE = "quality";
/** The `comment` text `foreman quality` writes: "quality accept", "quality retry", each optionally ": <note>". */
export const QUALITY_ANSWER_RE = /^quality (accept|retry)(?:: ([\s\S]+))?$/;
export const qualityAnswerText = (answer: "accept" | "retry", note?: string): string => `quality ${answer}${note !== undefined ? `: ${note}` : ""}`;

/** A look whose summary carries the critic's NOT ok is not ok; ok, no verdict and no critic are (they do not gate). */
export const lookOk = (summary: string): boolean => !/critic \(V5\) NOT ok/.test(summary);

export interface Look {
  seq: number;
  /** 0 for a `milestone` without `round`. */
  round: number;
  ok: boolean;
  captures: string[];
  strips: { capture: string; label: string }[];
  summary: string;
}

/** What to do next for a milestone whose packages are all merged. */
export type QualityNext =
  | { next: "closed" }
  | { next: "held"; round: number }
  /** Film and judge; `round` is the look's round (0 = the first look). `previous` is the look before (round >= 1). */
  | { next: "look"; round: number; previous?: Look }
  /** A revise round is due and was not sent yet (a kill in between, or `foreman quality retry`). */
  | { next: "send"; round: number; look: Look; note?: string };

export function looksOf(events: readonly JobEvent[], m: string): Look[] {
  const out: Look[] = [];
  for (const e of events) {
    if (e.type !== "milestone" || e.milestone !== m) continue;
    out.push({ seq: e.seq, round: e.round ?? 0, ok: lookOk(e.summary), captures: e.captures, strips: e.strips ?? [], summary: e.summary });
  }
  return out;
}

/** The revise rounds sent for milestone `m`: [{round, seq}] from `reopened` reasons and `queued` details. */
export function roundsSent(events: readonly JobEvent[], m: string, members: string[]): { round: number; seq: number }[] {
  const out: { round: number; seq: number }[] = [];
  for (const e of events) {
    let r: number | undefined;
    if (e.type === "reopened") r = criticRoundOf(e.reason, m);
    else if (e.type === "package_state" && e.state === "queued") {
      r = criticRoundOf(e.detail, m);
      // A log from before 2026-11-21: the members' "one extra round" queued detail does not name the milestone.
      if (r === undefined && members.includes(e.package) && (e.detail ?? "").startsWith("critic (V5) NOT ok, one extra round:")) r = 1;
    }
    if (r !== undefined && !out.some((x) => x.round === r)) out.push({ round: r, seq: e.seq });
  }
  return out;
}

/** The owner's answers to a quality hold of milestone `m`, in order. */
export function answersOf(events: readonly JobEvent[], m: string): { seq: number; answer: "accept" | "retry"; note?: string }[] {
  const out: { seq: number; answer: "accept" | "retry"; note?: string }[] = [];
  for (const e of events) {
    if (e.type !== "comment" || e.milestone !== m) continue;
    const a = QUALITY_ANSWER_RE.exec(e.text);
    if (a) out.push({ seq: e.seq, answer: a[1] as "accept" | "retry", ...(a[2] !== undefined ? { note: a[2] } : {}) });
  }
  return out;
}

export function qualityNext(events: readonly JobEvent[], m: string, members: string[]): QualityNext {
  const looks = looksOf(events, m);
  const sent = roundsSent(events, m, members);
  const maxSent = sent.reduce((a, x) => Math.max(a, x.round), 0);
  const last = looks.at(-1);
  if (last === undefined) return { next: "look", round: maxSent };
  if (last.round === 0 || last.ok) return { next: "closed" };
  const answer = answersOf(events, m).filter((a) => a.seq > last.seq).at(-1);
  if (answer?.answer === "accept") return { next: "closed" };
  const due = last.round + 1;
  const wanted = answer?.answer === "retry" || last.round < QUALITY_ROUNDS;
  if (!wanted) return { next: "held", round: last.round };
  if (sent.some((x) => x.round === due && x.seq > last.seq)) return { next: "look", round: due, previous: last };
  return { next: "send", round: due, look: last, ...(answer?.note !== undefined ? { note: answer.note } : {}) };
}
