// JOB.md "Added 2026-11-20" in the derived state: creativity, run_through, the reactions on the latest brief and the
// phases of the latest plan. The reducer of these events lives here and is called from joblog.ts applyEvent (kept
// below its 600-line rule). Pure: it reads and writes the state it is given; a broken rule is reported through `fail`.
import type { JobEvent, PhaseVerdict } from "./events.js";
import type { JobState } from "./joblog.js";
import { choiceProblem } from "./v2.js";
import { QUALITY_ANSWER_RE, QUALITY_ROUNDS, lookOk } from "./quality_state.js";

/** The fixed start of the `reason` of a `reopened` event that answers a phase `hold` (its seq is the phase_reviewed). */
export const PHASE_HOLD_RE = /^phase hold \(event (\d+)\)/;
export const holdReason = (seq: number): string => `phase hold (event ${seq})`;

/** One reaction of the player to an aspect of the latest brief (the latest per aspect counts). */
export interface ReactionView {
  choice: string;
  note?: string;
  seq: number;
}

/**
 * One phase of the plan and where it stands. `open`: being built; `done`: phase_done written, the job waits for the
 * player's verdict; `held`: the player said hold, a change round runs on its packages; `passed`.
 */
export interface PhaseView {
  id: string;
  title: string;
  try: string;
  packages: string[];
  state: "open" | "done" | "held" | "passed";
  /** How many `phase_done` events this phase has (a hold sends it round again). */
  doneCount: number;
  /** Every verdict on it, oldest first. */
  reviews: { verdict: PhaseVerdict; by: "player" | "auto"; note?: string; seq: number }[];
  /** The hold being worked on: its seq, the note, and whether its change round was opened (`reopened`). */
  hold?: { seq: number; note: string; applied: boolean };
}

/** The phase being built or waiting now: the first that is not passed. Undefined without phases or when all passed. */
export function currentPhase(s: Pick<JobState, "phases">): PhaseView | undefined {
  return s.phases.find((ph) => ph.state !== "passed");
}

/** The phase whose `phase_done` waits for a verdict (`foreman phase <job> pass|hold`), if any. */
export function waitingPhase(s: Pick<JobState, "phases">): PhaseView | undefined {
  return s.phases.find((ph) => ph.state === "done");
}

/** The index of the phase a package is in; -1 when the plan has no phases or the package is in none. */
export function phaseIndexOf(s: Pick<JobState, "phases">, pkg: string): number {
  return s.phases.findIndex((ph) => ph.packages.includes(pkg));
}

/**
 * The designer v2 part of the reducer, called for every event BEFORE joblog.ts handles it the usual way. `fail`
 * throws the reader's error for this line (an aspect the brief does not have, a verdict on a phase that is not done).
 */
export function applyDesignEvent(s: JobState, ev: JobEvent, fail: (message: string) => never): void {
  const needPhase = (id: string): PhaseView => s.phases.find((x) => x.id === id) ?? fail(`${ev.type} names phase "${id}" that the latest plan_set does not have (${s.phases.map((x) => x.id).join(", ") || "no phases"})`);
  switch (ev.type) {
    case "job_created":
      if (ev.creativity !== undefined) s.creativity = ev.creativity;
      if (ev.run_through === true) s.runThrough = true;
      break;
    case "brief_set":
      s.briefs += 1;
      s.reactions = {}; // reactions to the old brief no longer count
      s.reviews = s.pendingReviews; // JOB.md 2026-11-21: the reviews written before a brief judged it
      s.pendingReviews = [];
      break;
    case "design_reviewed":
      s.pendingReviews.push({ round: ev.round, verdict: ev.verdict, scores: ev.scores, notes: ev.notes });
      break;
    case "aspect_reacted": {
      if (s.briefApprovedBy !== undefined) fail(`aspect_reacted after brief_approved: the brief is approved, reactions come before`);
      const aspect = (s.brief?.aspects ?? []).find((a) => a.id === ev.aspect) ?? fail(`aspect_reacted names aspect "${ev.aspect}", which the latest brief_set does not have (${(s.brief?.aspects ?? []).map((a) => a.id).join(", ") || "no aspects"})`);
      const bad = choiceProblem(aspect, ev.choice);
      if (bad !== undefined) fail(`aspect_reacted: ${bad}`);
      s.reactions[ev.aspect] = { choice: ev.choice, ...(ev.note !== undefined ? { note: ev.note } : {}), seq: ev.seq };
      break;
    }
    case "plan_set": {
      // A re-plan keeps what the log says about a phase it keeps (same id): its state, its verdicts, its hold.
      const before = new Map(s.phases.map((ph) => [ph.id, ph]));
      s.phases = (ev.phases ?? []).map((ph) => {
        const old = before.get(ph.id);
        return old ? { ...old, title: ph.title, try: ph.try, packages: [...ph.packages] } : { id: ph.id, title: ph.title, try: ph.try, packages: [...ph.packages], state: "open", doneCount: 0, reviews: [] };
      });
      break;
    }
    case "phase_done": {
      const ph = needPhase(ev.phase);
      ph.state = "done";
      ph.doneCount += 1;
      delete ph.hold;
      break;
    }
    case "phase_reviewed": {
      const ph = needPhase(ev.phase);
      if (ph.state !== "done") fail(`phase_reviewed: phase "${ev.phase}" is ${ph.state}, not done (a verdict follows its phase_done)`);
      ph.reviews.push({ verdict: ev.verdict, by: ev.by, ...(ev.note !== undefined ? { note: ev.note } : {}), seq: ev.seq });
      if (ev.verdict === "pass") ph.state = "passed";
      else {
        ph.state = "held";
        ph.hold = { seq: ev.seq, note: ev.note ?? "", applied: false };
      }
      break;
    }
    case "reopened": {
      // A phase hold's change round: the player's note joins the package's change requests (part of its brief).
      const h = PHASE_HOLD_RE.exec(ev.reason);
      const ph = h ? s.phases.find((x) => x.hold?.seq === Number(h[1])) : undefined;
      const p = s.packages[ev.package];
      if (ph?.hold && p) {
        if (!ph.hold.applied) p.changes = [...(p.changes ?? []), ph.hold.note];
        ph.hold.applied = true;
      }
      break;
    }
    case "milestone": {
      // JOB.md 2026-11-21: a look still NOT ok after the last revise round holds the job for the owner.
      const held = ev.round !== undefined && ev.round >= QUALITY_ROUNDS && !lookOk(ev.summary);
      if (held) s.qualityHeld = { milestone: ev.milestone, round: ev.round as number, seq: ev.seq };
      else if (s.qualityHeld?.milestone === ev.milestone) delete s.qualityHeld;
      break;
    }
    case "comment":
      if (s.qualityHeld?.milestone === ev.milestone && QUALITY_ANSWER_RE.test(ev.text)) delete s.qualityHeld;
      break;
    default:
      break;
  }
}
