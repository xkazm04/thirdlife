// The one boundary of "the change in flight" (the Director's ruling of 27 Nov, after D27 items 33/40 and D27b items
// 41/42): a change begins after the last promotion, or after the last job ending since it (a job done, failed or cancelled
// without a promotion: that change ended NOT made). boundlift.ts askedChange (what is asked now), fastchange.ts
// whatChangedNote (what this version made) and unmade.ts earlierUnmade (each earlier change that ended unmade) read it.
// A leaf module: only types are imported, so any module may use it.
import type { JobEvent } from "./events.js";

/** The seq of the last `promoted` event (-1 before a first version). */
export function lastPromotion(events: readonly JobEvent[] | undefined): number {
  let last = -1;
  for (const e of events ?? []) if (e.type === "promoted") last = e.seq;
  return last;
}

/** A job ending: the job done, failed or cancelled. */
export const isJobEnd = (e: JobEvent): boolean => e.type === "job_state" && (e.state === "done" || e.state === "failed" || e.state === "cancelled");

/** The job endings since the last promotion (the promotion's own ending among them), in log order. */
export function endsSincePromotion(events: readonly JobEvent[] | undefined): JobEvent[] {
  const last = lastPromotion(events);
  return last < 0 ? [] : (events ?? []).filter((e) => e.seq > last && isJobEnd(e));
}

/** The seq after which the change in flight began: the last job ending since the last promotion, else that promotion; -1 before a first version. */
export function changeBoundary(events: readonly JobEvent[] | undefined): number {
  return Math.max(lastPromotion(events), ...endsSincePromotion(events).map((e) => e.seq));
}
