// D27 lane T3, item 34 (lane J2b's robots copy, events 1653-1706): "And my own bot teammates should use the magnet too."
// went to core (the Planner) and, as the rivals' part, to brain. core r23 made it ("the magnet bot logic now runs for
// team 0 mates (ids 1 and 2) as well as rivals"), merged, and brain r4 then ran anyway, found "the mates' and rivals'
// magnet decisions ... stay in core's scripts/sim/magnet.gd ... No values in data/ai.json or scripts under scripts/ai/
// were changed", and added a figure to its test: about 0.6M tokens and 6 minutes for nothing. A rivals' part is a guess
// that the other package's files decide for those bots; once the owner has merged and says, in its own words, that its
// code now makes the bots the person named do it, the guess is answered: the package that waits for it is not opened.
// The owner must name the same bots the person named (mates, rivals, the bots) with a word that includes them ("as well
// as", "also", "too", "for all"), the thing they use or do (a word of the person's sentence), and no NOT DONE. Pure.
import type { JobEvent } from "./events.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";
import { rivalPartHead, rivalSentences } from "./rivals.js";

/** The bots a person's words name, each with the words an owner may use for them. */
const GROUPS: [RegExp, RegExp][] = [
  [/\b(team-?mates?|(?:my|our) (?:own )?(?:bot |robot )?(?:mates|team-?mates))\b/i, /\b(mates?|team-?mates?|team 0|my side|your side|own side)\b/i],
  [/\b(rivals?|opponents?|enem(?:y|ies)|foes?|the other (?:side|team|crew|squad))\b/i, /\b(rivals?|opponents?|enem(?:y|ies)|foes?|the other (?:side|team)|team 1)\b/i],
  [/\b(bots?|robots?|computer players?|AI|CPU)\b/i, /\b(bots?|robots?|every (?:bot|robot|player)|all (?:the )?(?:bots|robots|players))\b/i],
];
const INCLUDES = /\b(as well as|also|too|both|for (?:all|every|both)|now (?:runs|works|decides) for|for (?:the )?(?:mates|rivals|bots|robots) as well)\b/i;
const STOP = new Set(["should", "would", "could", "their", "there", "these", "those", "with", "from", "that", "this", "they", "them", "when", "what", "will", "your", "mine", "make", "made", "like", "same", "more", "less", "also", "only", "just", "own"]);

/** The content words (4 letters or more) of a sentence, without the bots' own words. */
const content = (s: string): Set<string> => new Set(s.toLowerCase().split(/[^a-z]+/).filter((w) => w.length >= 4 && !STOP.has(w) && !GROUPS.some(([p, o]) => p.test(w) || o.test(w))).map((w) => w.replace(/(es|s)$/, "")));

/** The owner's sentence that says its code makes the bots the person named do it; undefined when none does. */
export function ownerMadeBots(rivalWords: string, ownerNote: string): string | undefined {
  if (rivalWords === "" || /\bNOT (?:DONE|MADE|BUILT)\b/.test(ownerNote)) return undefined;
  const group = GROUPS.find(([p]) => p.test(rivalWords));
  if (group === undefined) return undefined;
  const words = content(rivalWords);
  for (const s of ownerNote.split(/(?<=[.!?])\s+|\n/).map((x) => x.replace(/^\s*[-*]\s*/, "").trim())) {
    if (!group[1].test(s) || !INCLUDES.test(s)) continue;
    if ([...content(s)].some((w) => words.has(w))) return s;
  }
  return undefined;
}

/**
 * After `owner`'s merge: each package that waits, queued and not yet built, only for the rivals' part of the owner's
 * change, when the owner's notes since its re-opening say its code made those bots do it: a note (the owner's words) and
 * the package back to promoted, with no round. [] otherwise.
 */
export function botsDone(events: readonly JobEvent[], owner: string, round: number): Record<string, unknown>[] {
  const reopenedAt = [...events].reverse().find((e) => e.type === "reopened" && e.package === owner)?.seq;
  if (reopenedAt === undefined) return [];
  const note = events.filter((e) => e.type === "note" && e.package === owner && e.seq > reopenedAt && !e.text.startsWith(FOREMAN_NOTE)).map((e) => (e.type === "note" ? e.text : "")).join("\n");
  const out: Record<string, unknown>[] = [];
  for (const req of events.filter((e): e is Extract<JobEvent, { type: "change_requested" }> => e.type === "change_requested" && e.package !== undefined && e.package !== owner && e.text.startsWith(FOREMAN_NOTE) && e.text.includes(`"${owner}" builds the rest of the change`))) {
    const p = req.package as string;
    const m = /^\[foreman\] the rivals' part of change request (\d+), /.exec(req.text);
    if (m === null || !req.text.startsWith(rivalPartHead(Number(m[1])))) continue;
    // the package waits for this request alone: its last re-opening is this one, it is queued, and no builder ran since
    const reopen = [...events].reverse().find((e) => e.type === "reopened" && e.package === p);
    if (reopen?.type !== "reopened" || reopen.seq < req.seq || !reopen.reason.includes(`event ${req.seq})`)) continue;
    const state = [...events].reverse().find((e) => e.type === "package_state" && e.package === p);
    if (state?.type !== "package_state" || state.state !== "queued" || events.some((e) => e.type === "builder_run" && e.package === p && e.seq > reopen.seq)) continue;
    if (events.some((e) => e.type === "change_requested" && e.package === p && e.seq > req.seq)) continue; // more work came for it
    const person = events.find((e) => e.seq === Number(m[1]));
    const said = ownerMadeBots(rivalSentences(person?.type === "change_requested" ? person.text : ""), note);
    if (said === undefined) continue;
    out.push({ type: "note", package: p, round: state.round, text: `${FOREMAN_NOTE}the rivals' part of change request ${m[1]} needs no round of ${p}: ${owner} made those bots do it in its own files, in its words: "${clip(said, 300)}"` });
    out.push({ type: "package_state", package: p, state: "promoted", round: state.round, detail: clip(`not opened: the rivals' part of change request ${m[1]} was made by ${owner} (round ${round})`, 300) });
  }
  return out;
}
