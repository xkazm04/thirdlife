// E4b (night of 24-25 Nov 2026): a change on a game on a core that changes DATA only (the cartridge, its rules sidecar,
// the skin: coreroute.ts CORE_DATA_RE) is playable in minutes. E5 measured 14.5 min for "make it faster": the cartridge
// diff and its measured check took 50 s; the rest was work that re-proves files the change did not touch: every pack
// test on the merge candidate, the dependants' acceptance again, the whole final verification (the same bots on the same
// files), the card's hand checks, and four promotion captures (about 4.5 min).
// For such a round the Foreman keeps:
//   - the measured check (coregate.ts cartridgeChange: the core plays the cartridge before and after),
//   - the round's own acceptance (lint and the player check: for a diff round the first-match bot is the measured check's),
//   - the merge gate (lint, smoke on exactly the candidate that becomes pack/),
//   - ONE look (one promotion capture: the first camera at the first frame; E5: 40 s, the later frame took 110-120 s).
// and skips: the pack tests, the dependants' re-verification (their files did not change), the milestone's re-look, the
// final verification's repeats and the hand checks. Each skip is said in a Foreman note. A change that touches any
// other file (a script, a test, the base) goes the whole way as before.
import type { Acceptance, JobEvent, PackageSpec } from "./events.js";
import type { JobState } from "./joblog.js";
import { CORE_DATA_RE } from "./coreroute.js";
import { coreRouteOf } from "./templates.js";
import { playerChecks } from "./playercheck.js";
import { FOREMAN_NOTE } from "./conduct.js";
import { CARTRIDGE_DIFF } from "./coregate.js";

/** The start of the Foreman's notes about what a data-only change skipped (after FOREMAN_NOTE). */
export const DATA_ONLY = "data-only change";

/** Is the job a game on a core, with at least one promotion (a change, not the first build)? */
const coreChange = (s: JobState): boolean => coreRouteOf(s.brief?.concept?.template) !== undefined && s.promotions.length > 0;

/** Files that are a core game's data: the cartridge, a rules sidecar, the skin. */
export const dataOnly = (files: readonly string[]): boolean => files.length > 0 && files.every((f) => CORE_DATA_RE.test(f));

/** A merge of these files on this job is a data-only change (fast path). */
export function fastMerge(s: JobState, files: readonly string[]): boolean {
  return coreChange(s) && dataOnly(files);
}

/** Every merge since the last promotion touched data only, and there was at least one: the promotion is fast. */
export function fastPromotion(s: JobState, events: readonly JobEvent[]): boolean {
  if (!coreChange(s)) return false;
  let last = -1;
  for (const e of events) if (e.type === "promoted") last = e.seq;
  const merges = events.filter((e) => e.type === "merge" && e.seq > last);
  return merges.length > 0 && merges.every((e) => e.type === "merge" && dataOnly([...e.files, ...(e.removed ?? [])]));
}

/** Is this round of the package a cartridge diff round (the Foreman's diff, no builder)? */
export function isDiffRound(s: JobState, id: string, round: number): boolean {
  return s.notes.some((n) => n.package === id && n.round === round && n.text.startsWith(`${FOREMAN_NOTE}${CARTRIDGE_DIFF}: `));
}

/**
 * The acceptance a round runs. A diff round keeps the non-bot checks and the player check's bot (the measured check
 * has just played the changed cartridge at every level, as the first-match bot would); any other round, all of it.
 */
export function roundAcceptance(s: JobState, spec: PackageSpec, round: number): Acceptance[] {
  if (!coreChange(s) || !isDiffRound(s, spec.id, round)) return spec.acceptance;
  const player = new Set(playerChecks(s.plan).map((p) => p.test));
  const bots = spec.acceptance.filter((a) => a.verb === "bot");
  const keep = bots.filter((a) => a.args.some((x) => player.has(x.replace(/^--test=/, ""))));
  return [...spec.acceptance.filter((a) => a.verb !== "bot"), ...(keep.length > 0 ? keep : bots.slice(-1))];
}

/** The note that says what a data-only merge skipped. */
export function mergeNote(files: readonly string[], dependants: readonly string[]): string {
  return `${FOREMAN_NOTE}${DATA_ONLY} (${files.join(", ")}): the pack tests, the re-verification of ${dependants.length > 0 ? dependants.join(", ") : "no dependant"} and the milestone's re-look are skipped (their files did not change; the measured check and this round's acceptance played the new data)`;
}

/** The final verification of a fast promotion: the merge gate already ran on exactly this pack; lint and smoke once more. */
export function fastFinal(final: Acceptance[]): Acceptance[] {
  return final.filter((a) => a.verb === "lint" || a.verb === "smoke");
}

export const FINAL_NOTE = `${FOREMAN_NOTE}${DATA_ONLY}: the final verification is lint and smoke (the bots ran on these files at the merge), no hand checks (the measured check stands for them), and ONE promotion picture`;
