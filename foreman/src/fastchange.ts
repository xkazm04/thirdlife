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
import { FOREMAN_NOTE, clip } from "./conduct.js";
import { CARTRIDGE_DIFF, FIGURE_MISSED } from "./coregate.js";
import { REMOVED, entriesText, type Removal } from "./removal.js";
import { NOT_DONE, noteLines, notMadeSince } from "./halfmade.js";
import { BALANCE_MOVED } from "./boundlift.js";
import { botsCardLines } from "./botsdefault.js"; // S1-bots A

/** N27 (lane T): the start of a what-changed line naming a rule the builder added that the person did not ask for. */
export const UNASKED_RULE = "unasked rule";
/**
 * N27: a builder's line that adds a rule nobody asked for: its own `RULE:` line (builder.md), or the words the 25 Nov
 * builders used for the hidden ones (G19: "with probability 0.8", "do 2.0 times damage", "new comeback rule not in the
 * contract", "nothing on screen announces it").
 */
export const HIDDEN_RULE = /^RULE:|\bprobabilit\w*\b|\b\d+\s*(%|percent) chance\b|\bmultipl(ied|ier|iers)\b|\bcomeback\b|\brubber[- ]?band\w*|\bcatch[- ]?up\b|\bhandicap\w*|\bnot in the contract\b|\b(nobody|no one) asked\b|\bnothing (new )?on screen (announces|explains|shows)\b|\bhidden (rule|bonus|boost)\b|\b\d+(\.\d+)?\s*(x|times)\s+(the\s+)?(damage|harder|faster|speed|stronger)\b/i;

/** The builders' lines since the last promotion that add a rule nobody asked for (merged packages only). */
export function unaskedRules(since: readonly JobEvent[]): string[] {
  const merged = new Set(since.flatMap((e) => (e.type === "merge" ? [e.package] : [])));
  return [...new Set(since.flatMap((e) => (e.type === "note" && merged.has(e.package) && !e.text.startsWith(FOREMAN_NOTE) ? noteLines(e.text).filter((l) => HIDDEN_RULE.test(l) && !NOT_DONE.test(l)) : [])))];
}

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
  return [...spec.acceptance.filter((a) => a.verb !== "bot"), ...(keep.length > 0 ? keep : bots.slice(-1)), ...toyBots(s, spec.id, round)];
}

/** E3e: the keys a toy bot (lane E1b's base: tests/bot_toys.gd, every zone and obstacle drawn) speaks for. */
export const TOY_KEYS = /\bgame\.rink\.(?:zones|obstacles)\b/;

/**
 * E3e: a diff round that changed the rink's zones or obstacles also runs the base's toy bot (a registered test named
 * bot_toys.gd), so a new bumper or slow patch is proven drawn; a diff of speeds, rules or colours does not run it.
 */
export function toyBots(s: JobState, id: string, round: number): Acceptance[] {
  const diff = s.notes.find((n) => n.package === id && n.round === round && n.text.startsWith(`${FOREMAN_NOTE}${CARTRIDGE_DIFF}: `));
  if (diff === undefined || !TOY_KEYS.test(diff.text.split(" (")[0] ?? "")) return [];
  const toy = s.plan.flatMap((p) => p.registers?.tests ?? []).find((t) => /(^|\/)bot_toys\.gd$/.test(t));
  return toy !== undefined ? [{ level: "V4", verb: "bot", args: [`--test=${toy}`] }] : [];
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

/** E3f: the start of the Foreman's one-line "what changed" note (after FOREMAN_NOTE), written before a 2nd or later promotion. */
export const WHAT_CHANGED = "what changed";

/**
 * E3f (E5b: after job 2's change a person got "version 2" and nothing said what changed): one line for the version about to
 * be promoted, from the log since the last promotion: the person's words, the cartridge diff's keys (before -> after),
 * and the files merged. Nothing merged is said too: the change was not made.
 */
export function whatChangedNote(events: readonly JobEvent[], version: string, found: readonly Removal[] = []): string {
  let last = -1;
  let was = "";
  for (const e of events) if (e.type === "promoted") [last, was] = [e.seq, e.version];
  const since = events.filter((e) => e.seq > last);
  const asked = since.flatMap((e) => (e.type === "change_requested" && !e.text.startsWith(FOREMAN_NOTE) ? [`"${e.text}"`] : []));
  const keys = since.flatMap((e) => (e.type === "note" && e.text.startsWith(`${FOREMAN_NOTE}${CARTRIDGE_DIFF}: `) ? [e.text.slice(`${FOREMAN_NOTE}${CARTRIDGE_DIFF}: `.length).split(" (")[0] ?? ""] : [])).filter(Boolean);
  const files = [...new Set(since.flatMap((e) => (e.type === "merge" ? e.files : [])))].sort();
  // H1f (G2: "files: data/tuning.json, scripts/sim/sim.gd, ..." named files, not what the person will see; the builder's
  // own note said it in words): after the person's words, what the merged rounds' builders say they changed, then the files.
  const merged = new Set(since.flatMap((e) => (e.type === "merge" ? [e.package] : [])));
  const said = files.length === 0 ? [] : since.flatMap((e) => (e.type === "note" && merged.has(e.package) && !e.text.startsWith(FOREMAN_NOTE) ? noteLines(e.text).filter((l) => !NOT_DONE.test(l)) : [])); // H1g: what was NOT made is not "what you will see"
  const seen = said.length === 0 ? "" : `what you will see, in the builder's words: ${said.slice(0, 3).map((l) => clip(l, 220)).join(" / ")}${said.length > 3 ? ` (and ${said.length - 3} more in its note)` : ""}; `;
  const made = files.length === 0 ? "nothing was merged: the change was NOT made" : `${seen}${keys.length > 0 ? `${keys.join("; ")}; ` : ""}files: ${files.join(", ")}`;
  // H1 (E5e defect 3): each removal on its own line, "removed: ...; why: ...": the diff's REMOVED notes, then what the
  // promoted cartridge lost that no note names (a builder's round), with why unknown.
  const named = files.length === 0 ? [] : since.flatMap((e) => (e.type === "note" && e.text.startsWith(`${FOREMAN_NOTE}${REMOVED}: `) ? [e.text.slice(FOREMAN_NOTE.length)] : []));
  const unnamed = found.filter((r) => !named.some((n) => n.startsWith(`${REMOVED}: ${entriesText([r])};`))).map((r) => `${REMOVED}: ${entriesText([r])}; why: not said (a builder's round; its DEVIATIONS may say)`);
  // H1d: a figure the person named that the change missed, on its own line too
  const missed = files.length === 0 ? [] : since.flatMap((e) => (e.type === "note" && e.text.startsWith(`${FOREMAN_NOTE}${FIGURE_MISSED}: `) ? [e.text.slice(FOREMAN_NOTE.length)] : []));
  // H1g: what the builders say they did not make, on its own line (and where it went), so "asked" never reads as all made
  const notMade = files.length === 0 ? [] : notMadeSince(since);
  // N27: the balance the person's change moved (the newest note's first line) and every rule they did not ask for, each on its own line
  const moved = files.length === 0 ? [] : since.flatMap((e) => (e.type === "note" && e.text.startsWith(BALANCE_MOVED) ? [(e.text.split("\n")[0] ?? "").slice(FOREMAN_NOTE.length)] : [])).slice(-1);
  const rules = files.length === 0 ? [] : unaskedRules(since).map((l) => `${UNASKED_RULE} (the builder's words; you did not ask for it): ${clip(l.replace(/^RULE:\s*/, ""), 300)}`);
  const bots = files.length === 0 ? [] : botsCardLines(since); // S1-bots A: what the Foreman told the bots by default
  const lines = [...new Set([...notMade, ...named, ...unnamed, ...missed, ...moved, ...rules, ...bots])].map((l) => `\n${l}`).join("");
  return `${`${FOREMAN_NOTE}${WHAT_CHANGED} in v${version}${was !== "" ? ` (since v${was})` : ""}: ${asked.length > 0 ? `asked ${asked.join(", ")}; ` : ""}${made}`.slice(0, 1500)}${lines}`;
}
