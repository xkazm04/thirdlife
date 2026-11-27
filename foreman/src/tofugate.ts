// H1e of 25 Nov (lane G4's half court, events 76 and 81-86): a builder's own tofu bot answered `ok: true` while its
// metrics were outside the plan's bounds (pressure_waves 0 against >= 2, scrum_share 0.453 against <= 0.3; its note:
// "bot_tofu's ok only requires one match and 3 verbs used; it does not enforce the metric bounds"), and the round merged
// and was promoted. The bounds are the Foreman's to enforce, against the plan's rows (tofu.ts), at every acceptance run
// of the plan's tofu bot (G4's court_exchange, the tofu package): a bot that passes with a metric out of bounds fails the
// round, with the rows in words, and nothing is merged. Two such rounds at most (the look's revise budget, QUALITY_ROUNDS);
// after them the round merges and the milestone look judges the same bounds and holds the job for the person, as before,
// so a bound the game cannot meet still reaches the person instead of spending builder rounds to the cap.
// N27 (night of 27 Nov, lane T): in a person's change since the last promotion, the rows the change moves are a note to
// the person and never a refusal; the rows it did not touch still guard, as a regression (boundlift.ts splitByChange).
import fs from "node:fs";
import path from "node:path";
import type { Acceptance } from "./events.js";
import type { GateHost } from "./p10gate.js";
import type { VerifyResult } from "./verifier.js";
import { courtOf, judgeTofu, readTofuMetrics, tofuMetricsFor, tofuOf } from "./tofu.js";
import { QUALITY_ROUNDS } from "./quality_state.js";
import { BALANCE_MOVED, BALANCE_SKIPPED, LIFTED, alreadyOutNote, askedChange, balanceMovedNote, balanceSkippedNote, liftedNote, splitByChange, withLifts } from "./boundlift.js";
import { FOREMAN_NOTE } from "./conduct.js";
import { LONGER_BEFORE, judgedLongerLine, longerBefore, longerBeforeNote, priorLonger, reportReader, roundTold, type LongerRun } from "./longernote.js"; // D27 T3 items 43, 35

/** The words a round gets when the plan's tofu bot passed with metrics out of the plan's bounds; undefined otherwise. */
export function tofuGate(h: Pick<GateHost, "s" | "pkg" | "dir" | "rel" | "append" | "events">, id: string, a: Pick<Acceptance, "verb" | "args">, vr: VerifyResult): VerifyResult | undefined {
  const t = tofuOf(h.s.plan);
  if (t === undefined || a.verb !== "bot" || !vr.ok || !a.args.includes(`--test=${t.test}`)) return undefined;
  const p = h.pkg(id);
  if (p.round - (p.roundBase ?? 1) >= QUALITY_ROUNDS) return undefined; // the look judges it from here on
  const result = (vr.report as { bot?: { result?: { metrics?: unknown; hand?: unknown } } } | undefined)?.bot?.result;
  const m = result?.metrics;
  const metrics = m !== null && typeof m === "object" && !Array.isArray(m) ? (m as Record<string, unknown>) : undefined;
  // H1h: a bound the person lifted (a card choice, an answer) is not judged; said once a round when it would have failed
  const all = tofuMetricsFor(h.s.brief?.concept?.template, h.s.brief?.design?.verbs.length, courtOf(h.s.brief));
  const { rows, lifted } = withLifts(h.s, h.events, all);
  // N27 (lane T): in a person's change the rows it moves are a note to the person, not a refusal (boundlift.ts)
  const asked = askedChange(h.events);
  let judgedRows = rows;
  if (asked !== undefined) {
    const before = readTofuMetrics(h.dir(), (h.events ?? []).filter((e) => e.seq < asked.seq), t.test).metrics;
    const split = splitByChange(asked, rows, metrics, before);
    judgedRows = split.judged;
    const once = (start: string, text: string): void => {
      if (!(h.events ?? []).some((e) => e.type === "note" && e.package === id && e.round === p.round && e.text.startsWith(start))) h.append({ type: "note", package: id, round: p.round, text });
    };
    if (split.moved.length > 0) once(BALANCE_MOVED, balanceMovedNote(split.moved, metrics, before, t.test));
    if (split.skipped.length > 0) once(BALANCE_SKIPPED, balanceSkippedNote(split.skipped, metrics, t.test));
    if (split.before.length > 0) once(`${FOREMAN_NOTE}already outside`, alreadyOutNote(split.before, before));
  }
  const judged = judgeTofu(metrics, judgedRows, t.test);
  const wouldFail = [...lifted.keys()].filter((id) => judgeTofu(metrics, all.filter((r) => r.id === id), t.test).rows.some((r) => !r.ok));
  if (wouldFail.length > 0 && !(h.events ?? []).some((e) => e.type === "note" && e.package === id && e.round === p.round && e.text.startsWith(LIFTED))) h.append({ type: "note", package: id, round: p.round, text: liftedNote(new Map([...lifted].filter(([k]) => wouldFail.includes(k))), all) });
  if (judged.ok) return undefined;
  const out = judged.rows.filter((r) => !r.ok).map((r) => `${r.id} ${r.value ?? "absent"} (the plan's bound: ${r.want})`);
  const summary = `${t.test} answered ok, but the Foreman judges its metrics against the plan's tofu bounds and ${out.length} ${out.length === 1 ? "is" : "are"} outside them: ${out.join("; ")}. A bot's own ok is not the check: change the game until the figures it counts are inside the bounds (never the bot's ok, never the counting).${asked !== undefined ? ` These rows were inside their bounds before the person's change and the change did not ask to move them: keep what the person asked and put these back; never add a rule nobody asked for (a probability, a multiplier, a comeback) to pass them.` : ""}`;
  // The judgement is a failed check of its own (the next round's feedback reads the round's failed verify event).
  const file = h.dir("reports", `${id}-r${p.round}-tofu-bounds-s${h.s.lastSeq + 1}.json`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify({ schema: "tl.foreman.tofu-bounds/1", verb: "bot", level: "V4", ok: false, outcome: "failed", by: `the Foreman (tofugate.ts) on ${h.rel(vr.reportFile)}`, test: t.test, checks: judged.rows.map((r) => ({ id: `tofu.${r.id}`, ok: r.ok, detail: `${r.value ?? "absent"} (the plan's bound: ${r.want})` })), errors: [{ kind: "bounds", message: summary }] }, null, 1) + "\n");
  h.append({ type: "verify", package: id, round: p.round, level: "V4", verb: "bot", ok: false, report: h.rel(file) });
  return { ...vr, ok: false, summary, reportFile: file, verdictFile: file };
}

// ---------- N27 T2 (night of 27 Nov, lane J2's robots): a match the person's change made longer gets the frames it needs ----------
// J2 asked for a hammer that launches robots; matches went from about 2.8 to about 4.5 minutes, and core's tofu bot
// (three matches) was no longer done within the runner's 36,000 frames (RUNNER.md `bot --frames`, default 36000). Nothing
// was wrong with the game, the bot could not be edited (the measure is the Foreman's), and the job ended "the change was
// NOT made" after four rounds sent to the wrong package. In a person's PLAY change (boundlift.ts askedChange), a bot run
// that failed ONLY because it ran out of frames is run once more with three times the frames (at most 108,000: half an
// hour of play); when it passes, the person gets a plain-words note (BALANCE_MOVED, as the balance figures) and the run
// counts. A run that is still not done with three times the frames (a match that never ends) stays a failure.

/** The runner's default bot budget (RUNNER.md) and the most a person's longer matches are given. */
export const DEFAULT_BOT_FRAMES = 36000;
export const LONGER_MAX_FRAMES = 108000;

/** A bot run that failed only because it was not done within its frames (bot.ok of a cut run fails with it). */
export function onlyOutOfFrames(vr: Pick<VerifyResult, "ok" | "verb" | "report">): boolean {
  const r = vr.report as { checks?: { id: string; ok: boolean }[]; bot?: { done?: unknown } } | undefined;
  if (vr.ok || vr.verb !== "bot" || r?.bot?.done !== false) return false;
  const failed = (r.checks ?? []).filter((c) => !c.ok).map((c) => c.id);
  return failed.includes("bot.completed") && failed.every((id) => id === "bot.completed" || id === "bot.ok");
}

/** The person's note when their change made the bot's matches outrun its frames (first line for Create). */
export function longerNote(test: string, had: number, used: number | undefined, given: number, short = false, prior?: LongerRun): string {
  if (short) return `${BALANCE_MOVED}: built as you asked; matches now run longer (the Foreman's test fit fewer matches than it plays into its ${had} frames). Say "make matches shorter" to tune it.
figures (${test}): done in ${had} frames with too few matches for its own check; passed when run again with ${given} frames (${used ?? "?"} used; not judged in this change)`;
  const times = used !== undefined ? Math.round((used / had) * 10) / 10 : undefined;
  return `${BALANCE_MOVED}: built as you asked; matches now run longer${times !== undefined ? ` (the Foreman's test needed about ${times} times the frames it planned${prior !== undefined ? `; ${prior.frames} before your change` : ""})` : ""}. Say "make matches shorter" to tune it.\nfigures (${test}): not done within ${had} frames; done in ${used ?? "?"} of ${given} when run again with more (not judged in this change)`;
}

/**
 * The run again with more frames, in a person's play change, when `vr` failed only for frames; undefined otherwise (the
 * caller keeps `vr`). `rerun` runs the same verb with the given args (logged as a verify event by the caller).
 */
export async function longerMatch(h: Pick<GateHost, "events" | "append" | "s"> & Partial<Pick<GateHost, "dir">>, a: Pick<Acceptance, "verb" | "args">, vr: VerifyResult, where: { package?: string; round: number; after?: string }, rerun: (args: string[]) => Promise<VerifyResult>): Promise<VerifyResult | undefined> {
  const asked = askedChange(h.events);
  const short = tofuTooShort(h.s.plan, a, vr); // D27 (b): the tofu bot completed but its own ok wanted more matches
  if (asked === undefined || asked.kind !== "play" || !(onlyOutOfFrames(vr) || short)) return undefined;
  const set = a.args.find((x) => x.startsWith("--frames="));
  const had = set !== undefined ? Number(set.slice("--frames=".length)) : DEFAULT_BOT_FRAMES;
  if (!(had > 0 && had < LONGER_MAX_FRAMES)) return undefined;
  const given = Math.min(LONGER_MAX_FRAMES, had * 3);
  const again = await rerun([...a.args.filter((x) => !x.startsWith("--frames=")), `--frames=${given}`]);
  const test = a.args.find((x) => x.startsWith("--test="))?.slice("--test=".length) ?? "the bot";
  if (!again.ok) return onlyOutOfFrames(again) ? { ...again, summary: `${again.summary}. It was not done with ${given} frames either (three times the ${had} it plans): a match that does not end` } : again;
  const used = (again.report as { bot?: { frames?: unknown } } | undefined)?.bot?.frames;
  const owner = where.package ?? where.after ?? h.s.plan.find((p) => (p.registers?.tests ?? []).includes(test))?.id ?? h.s.plan[0]?.id;
  const said = (h.events ?? []).some((e) => e.type === "note" && e.seq > asked.seq && ((e.text.startsWith(BALANCE_MOVED) && e.text.includes("matches now run longer") && e.text.includes(`figures (${test}):`)) || (e.text.startsWith(`${FOREMAN_NOTE}${LONGER_BEFORE}`) && e.text.includes(test))));
  const n = typeof used === "number" ? used : undefined;
  const round = where.package !== undefined ? where.round : h.s.packages[owner ?? ""]?.round ?? where.round;
  // D27 T3 item 43: matches that ran as long before the change (the newest longer run of the test before it) are not the change's
  const prior = h.dir !== undefined ? priorLonger(h.events, test, asked.seq, reportReader(h.dir)) : undefined;
  const before = longerBefore(prior, n);
  const hash = (again.report as { metrics?: { state_hash?: unknown } } | undefined)?.metrics?.state_hash;
  if (owner !== undefined && !said) h.append({ type: "note", package: owner, round, text: before && prior !== undefined && n !== undefined ? longerBeforeNote(test, had, prior, n, typeof hash === "string" ? hash : undefined) : longerNote(test, had, n, given, short, prior) });
  // D27 T3 item 35: every round the longer run decided says so, not only the first of the change
  else if (owner !== undefined && !roundTold(h.events, owner, round, test)) h.append({ type: "note", package: owner, round, text: judgedLongerLine(test, had, given, n) });
  return { ...again, summary: `${again.summary} (run again with ${given} frames: ${before ? "its matches ran this long before the person's change too" : "the person's change made its matches longer"})` };
}

/**
 * D27 round 4 (b) (J2nd's kart copy, events 1503-1514: core r31 wired the item shells; the merge gate's pack test of the
 * plan's tofu bot completed at its budget and failed on the bot's own ok, "2 matches", wanting 3 in 36,000 frames, because
 * shells and golden goals made matches longer; longerMatch did not rerun it, since the run had completed): the plan's
 * tofu bot that completed, with no script or engine error, and failed only on its own ok, is a run too short for the
 * person's longer matches. In a person's play change it gets the same one rerun with three times the frames.
 */
export function tofuTooShort(plan: Parameters<typeof tofuOf>[0], a: Pick<Acceptance, "verb" | "args">, vr: Pick<VerifyResult, "ok" | "verb" | "report">): boolean {
  const t = tofuOf(plan);
  if (vr.ok || vr.verb !== "bot" || t === undefined || !a.args.includes(`--test=${t.test}`)) return false;
  const r = vr.report as { checks?: { id: string; ok: boolean }[]; bot?: { done?: unknown }; errors?: { kind?: string }[] } | undefined;
  if (r?.bot?.done !== true) return false;
  const failed = (r.checks ?? []).filter((c) => !c.ok).map((c) => c.id);
  return failed.length === 1 && failed[0] === "bot.ok" && !(r.errors ?? []).some((e) => e.kind !== undefined && e.kind !== "bot");
}
