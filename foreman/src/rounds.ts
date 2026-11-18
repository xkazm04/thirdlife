// Why a package round runs, derived from the job log in ONE place. JOB.md has no round-kind field: the kind is read
// from the fixed starts of the `detail` of a `queued` package_state and of the `reason` of a `reopened`, which the
// Foreman writes from the constants below. reopen() clips those texts, so every constant sits at the very start.
// Pure: no file, no process; foreman.ts, p10gate.ts (and `foreman explain`) read these functions, never the prefixes.
import type { JobEvent } from "./events.js";
import { CHANGE_REASON_RE, type JobState, type PackageView } from "./joblog.js";
import { FINAL_FAILED } from "./p10.js";
export { FINAL_FAILED };

/** Fixed starts of the `detail` of a package sent back after its merge; the feedback and the resume read them. */
export const NO_VISIBLE_CHANGE = "NO VISIBLE CHANGE";
export const CRITIC_ROUND = "critic (V5) NOT ok, one extra round";
/** N3: fixed starts of the `detail` of a package that goes back to work after it was finished. */
export const CHANGE_ROUND = "CHANGE REQUEST";
export const DEP_CHANGED = "DEPENDENCY CHANGED";
export const KIT_REGRESSION = "KIT REGRESSION";
/** Lane C3: the start of the `reopened` reason and `queued` detail of a round sent back by a failed hand check. It is a
 *  final-verification round (one round, then the final verification and the hand checks again): kind final_failed. */
export const HAND_CHECK = "hand check failed";

/**
 * Why a round runs. `first`: round 1 (a first build, a retry requested, a replan). `verify_retry`: any later round
 * whose detail starts with no constant (the Verifier's failure is the feedback). `critic_kit_retry`: a kit
 * regression in the round right after the critic's extra round (JOB.md: one more, then the job goes on).
 */
export type RoundKind = "first" | "verify_retry" | "critic" | "critic_kit_retry" | "kit_regression" | "no_visible_change" | "change" | "dep_changed" | "final_failed";
/** The kinds a `reopened` reason can have: a change request, the critic naming the package, a changed dependency, a failed final verification. */
export type ReopenKind = Extract<RoundKind, "change" | "critic" | "dep_changed" | "final_failed">;

const DETAIL_KINDS: ReadonlyArray<readonly [string, RoundKind]> = [
  [CRITIC_ROUND, "critic"],
  [KIT_REGRESSION, "kit_regression"],
  [NO_VISIBLE_CHANGE, "no_visible_change"],
  [CHANGE_ROUND, "change"],
  [DEP_CHANGED, "dep_changed"],
  [FINAL_FAILED, "final_failed"],
  [HAND_CHECK, "final_failed"],
];

/** The kind a `detail` (or a `reason`) names by its fixed start; undefined for free text. The one prefix test. */
export function detailKind(detail: string | undefined): RoundKind | undefined {
  const d = detail ?? "";
  for (const [pre, kind] of DETAIL_KINDS) if (d.startsWith(pre)) return kind;
  return undefined;
}

/** Why a finished package was re-opened, from the `reopened` reason the Foreman wrote. */
export function reopenKind(reason: string): ReopenKind {
  if (CHANGE_REASON_RE.test(reason)) return "change";
  const k = detailKind(reason);
  return k === "critic" || k === "final_failed" ? k : "dep_changed";
}

/** The start of the `reopened` reason of the critic's extra round for milestone `m`. */
export const criticReopenFor = (m: string): string => `${CRITIC_ROUND} (milestone ${m})`;
/** True for the `reopened` reason of the critic's extra round for milestone `m`. */
export const isCriticReopenFor = (reason: string, m: string): boolean => reason.startsWith(criticReopenFor(m));

export interface RoundFold {
  /** package -> round -> kind. A round queued more than once keeps the first kind a constant named (an `any` rule). */
  rounds: Map<string, Map<number, RoundKind>>;
  /** package -> the kind of its last `reopened`. */
  lastReopen: Map<string, ReopenKind>;
}

/** One pass over the log: the kind of every queued round of every package, and of every package's last re-opening. */
export function roundKinds(events: readonly JobEvent[]): RoundFold {
  const rounds = new Map<string, Map<number, RoundKind>>();
  const lastReopen = new Map<string, ReopenKind>();
  for (const e of events) {
    if (e.type === "reopened") {
      lastReopen.set(e.package, reopenKind(e.reason));
      continue;
    }
    if (e.type !== "package_state" || e.state !== "queued") continue;
    let byRound = rounds.get(e.package);
    if (!byRound) rounds.set(e.package, (byRound = new Map()));
    const named = detailKind(e.detail);
    const had = byRound.get(e.round);
    if (named === undefined) {
      if (had === undefined) byRound.set(e.round, e.round <= 1 ? "first" : "verify_retry");
      continue;
    }
    if (had !== undefined && had !== "first" && had !== "verify_retry") continue;
    byRound.set(e.round, named === "kit_regression" && byRound.get(e.round - 1) === "critic" ? "critic_kit_retry" : named);
  }
  return { rounds, lastReopen };
}

export function roundKindOf(events: readonly JobEvent[] | RoundFold, id: string, round: number): RoundKind | undefined {
  const fold = Array.isArray(events) ? roundKinds(events as readonly JobEvent[]) : (events as RoundFold);
  return fold.rounds.get(id)?.get(round);
}

/** True when any round of the package was the critic's extra round (or the kit retry that followed it). */
export function hadCriticRound(fold: RoundFold, id: string): boolean {
  for (const k of fold.rounds.get(id)?.values() ?? []) if (k === "critic" || k === "critic_kit_retry") return true;
  return false;
}

/**
 * The last round a package may use: the round limit counts from its last re-opening (N3). A package re-opened by
 * a failed final verification (P10 item 2) gets ONE round per re-opening.
 */
export function roundCap(view: Pick<PackageView, "id" | "roundBase">, fold: RoundFold, roundLimit: number): number {
  if (view.roundBase !== undefined && fold.lastReopen.get(view.id) === "final_failed") return view.roundBase;
  return (view.roundBase ?? 1) + roundLimit - 1;
}

/** The `detail` of the last `queued` of (package, round) whose fixed start names one of `kinds`. */
export function queuedDetail(events: readonly JobEvent[], id: string, round: number, kinds: readonly RoundKind[]): string | undefined {
  for (let i = events.length - 1; i >= 0; i--) {
    const e = events[i] as JobEvent;
    if (e.type !== "package_state" || e.package !== id || e.round !== round || e.state !== "queued") continue;
    const k = detailKind(e.detail);
    if (k !== undefined && kinds.includes(k)) return e.detail ?? "";
  }
  return undefined;
}

/** A `reopened` whose `queued` is missing (a kill between the two): the `detail` that `queued` would have had. */
export function requeueDetail(events: readonly JobEvent[], state: Pick<JobState, "changes">, id: string): string {
  let reason = "";
  for (let i = events.length - 1; i >= 0; i--) {
    const e = events[i] as JobEvent;
    if (e.type === "reopened" && e.package === id) {
      reason = e.reason;
      break;
    }
  }
  const kind = reopenKind(reason);
  if (kind === "change") {
    const m = CHANGE_REASON_RE.exec(reason);
    const change = m ? state.changes.find((c) => c.seq === Number(m[1])) : undefined;
    if (change) return `${CHANGE_ROUND}: ${change.text}`;
  }
  return kind === "critic" || kind === "final_failed" ? reason : `${DEP_CHANGED}: ${reason}`;
}

/** How often the final verification sent a failure back since the last promotion or change request. */
export function finalSentSince(events: readonly JobEvent[]): number {
  let since = 0;
  for (let i = events.length - 1; i >= 0; i--) {
    const e = events[i] as JobEvent;
    if (e.type === "promoted" || e.type === "change_requested") {
      since = e.seq;
      break;
    }
  }
  return events.filter((e) => e.type === "reopened" && e.seq > since && reopenKind(e.reason) === "final_failed").length;
}
