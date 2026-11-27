// D27 lane T3, items 43 and 35: what the Foreman tells about a run that passed only with more frames (tofugate.ts
// longerMatch).
//
// 43 (lane N-newcomer's robots copy, event 1828): a change that only draws (a Q on the meter, a hint line; the pack's own
// newcomer hand plays v0.1.11 and v0.1.12 to the same hash) was told "balance moved by your change: matches now run
// longer". The frozen tofu bot had outrun its 36000 frames since v0.1.10: the last change's final run needed 41149
// frames (event 1733), and this one needed 41149 again, with the same state hash. A longer run is the person's change
// only when the matches got longer than they were before it: the newest passing longer run of the same test before the
// change is the measure. The same frames (within 5 %) are "already outside before your change", never the change's.
//
// 35 (lane J2b's robots copy, events 1700-1733): brain r4's and show r8's pack checks, and the final, each ran the frozen
// tofu bot, which each time was not done within 36000 frames and passed with more. The rule was the same for all three
// (verifyLogged -> longerMatch), but only the first got a line: the note is written once a change, so show r8's round
// read as "bot (V4) failed" and then a pass, with no word why. Every round whose check the longer run decided now says
// so in a line of its own; the person's note stays once a change.
import fs from "node:fs";
import type { JobEvent } from "./events.js";
import { FOREMAN_NOTE } from "./conduct.js";

/** The start of the line a round gets when the longer run decided its check after the person was told (after FOREMAN_NOTE). */
export const JUDGED_LONGER = "judged on a longer run";
/** The start of the note when the matches outran the test's frames before the change too (after FOREMAN_NOTE). */
export const LONGER_BEFORE = "already outside before your change, not judged as its regression: matches ran longer";

export interface LongerRun {
  seq: number;
  report: string;
  frames: number;
  hash?: string;
}

/** A passing run of `test` with more frames (a `-longer` report) logged before `beforeSeq`: the newest, or undefined. */
export function priorLonger(events: readonly JobEvent[] | undefined, test: string, beforeSeq: number, readReport: (rel: string) => unknown): LongerRun | undefined {
  const runs = (events ?? []).filter((e): e is Extract<JobEvent, { type: "verify" }> => e.type === "verify" && e.ok && e.seq < beforeSeq && e.verb === "bot" && /-longer-s\d+\.json$/.test(e.report));
  for (const e of [...runs].reverse()) {
    const r = readReport(e.report) as { bot?: { test?: unknown; frames?: unknown }; metrics?: { state_hash?: unknown } } | undefined;
    if (r?.bot?.test !== test || typeof r.bot.frames !== "number") continue;
    return { seq: e.seq, report: e.report, frames: r.bot.frames, ...(typeof r.metrics?.state_hash === "string" ? { hash: r.metrics.state_hash } : {}) };
  }
  return undefined;
}

/** A report read from the job directory (undefined when it cannot be read). */
export const reportReader = (dir: (...p: string[]) => string) => (rel: string): unknown => {
  try {
    return JSON.parse(fs.readFileSync(dir(...rel.split("/")), "utf8"));
  } catch {
    return undefined;
  }
};

/** Did the matches outrun the test's frames before the change by as much as now (within 5 %)? */
export const longerBefore = (prior: LongerRun | undefined, used: number | undefined): boolean => prior !== undefined && used !== undefined && used <= prior.frames * 1.05;

/** The note when the matches ran as long before the person's change (item 43). */
export function longerBeforeNote(test: string, had: number, prior: LongerRun, used: number, hash: string | undefined): string {
  const same = hash !== undefined && prior.hash !== undefined && hash === prior.hash ? ", the same play to the frame (the same state hash)" : "";
  return `${FOREMAN_NOTE}${LONGER_BEFORE} than ${test} plans (${had} frames) before your change too: it needed ${prior.frames} frames then (${prior.report}) and ${used} now${same}. Your change did not make them longer.`;
}

/** The line of a round whose check the longer run decided, once the change's note is written (item 35). */
export function judgedLongerLine(test: string, had: number, given: number, used: number | undefined): string {
  return `${FOREMAN_NOTE}${JUDGED_LONGER}: ${test} was not done within ${had} frames, so it ran again with ${given} and passed (${used ?? "?"} used), as told for this change; this is not a failed check of this round`;
}

/** Has this package's round a judged-longer line (or the change's note) already? */
export function roundTold(events: readonly JobEvent[] | undefined, pkg: string, round: number, test: string): boolean {
  return (events ?? []).some((e) => e.type === "note" && e.package === pkg && e.round === round && e.text.includes(test) && (e.text.includes(JUDGED_LONGER) || e.text.includes("matches now run longer") || e.text.includes(LONGER_BEFORE)));
}
