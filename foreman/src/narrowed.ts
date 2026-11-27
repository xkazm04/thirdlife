// D27 lane T3, item 44 (lane N-newcomer's shield copy, events 1506-1513): the person asked "Keep my Q press: if I press Q
// while I am down, stunned or mid-move, ... blow the horn the moment I am free again". rally kept it only while busy:
// "The kept press is dropped if the bar is no longer full, the captain falls, or a call is already running", and a press
// while down only says "CALL: STAND UP FIRST". Its builder said so among its notes, and its summary even said "pressing Q
// while your captain is down ... now keeps the press"; the card and Create said nothing was left unmade. A builder that
// makes an ask for fewer cases than the person named has left part of it unmade: when a builder's line drops, ignores or
// refuses the input in a state the person's own condition names (down, stunned, mid-move, in the air), the person reads
// it as "part of your change was NOT made", in the builder's words. Pure.
import type { JobEvent } from "./events.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";
import { askedChange } from "./boundlift.js";

/** The start of the note (Create shows a note that starts so as "Not made: ..."). */
export const NARROWED = "part of your change was NOT made: ";

/** A builder's words that drop, ignore or refuse something in a case. */
export const DROPS = /\b(?:is|are|gets?|will be|was)\s+(?:dropped|ignored|discarded|cancel+ed|lost|refused|not kept|not queued|skipped)\b|\b(?:not kept|never kept|isn't kept|aren't kept)\b|\bonly (?:while|when|if)\b|\bexcept (?:while|when|if)\b/i;
/**
 * A person's sentence that asks to take something away in that state ("YOU ARE MEGA! stays on screen while I lie on the
 * ice: take it away the moment I fall", this lane's live copy, event 1371): a builder that removes it then has made the
 * ask, not narrowed it.
 */
const TAKE_AWAY = /\b(take (?:it|them|that) away|take away|remove\w*|hide\w*|clear\w*|drop (?:it|them)|stop (?:it|them|showing)|go(?:es)? away|disappear\w*)\b/i;

/** The states a game's body can be in, each with the words for it (a person's and a builder's). */
const STATES: [string, RegExp][] = [
  ["down", /\b(down|falls?|fallen|falling|fell|knocked|knockdown|floored|get ?up|getting up|lying|prone|wallsplat|on the ground)\b/i],
  ["stunned", /\b(stun\w*|stagger\w*|hitstop|blockstun|dazed|reeling)\b/i],
  ["mid-move", /\b(mid-?move|busy|wind-?up|winding up|attacking|swinging|recover\w*|mid-?swing)\b/i],
  ["in the air", /\b(in the air|airborne|jumping|mid-?air|leaping)\b/i],
];

/** The conditions of the person's words: the clauses after if, while, when, whenever, even when (up to a full stop). */
export function personConditions(text: string): string[] {
  return [...text.matchAll(/\b(?:if|while|when|whenever|even (?:if|when))\b([^.;:!?]{3,300})/gi)]
    .filter((m) => !TAKE_AWAY.test(text.slice(m.index ?? 0).split(/[.?](?:\s|$)/)[0] ?? ""))
    .map((m) => (m[0] ?? "").trim());
}

/** The states a piece of words names. */
const statesIn = (s: string): string[] => STATES.filter(([, re]) => re.test(s)).map(([k]) => k);

/**
 * The narrowings in a builder's note: each sentence that drops, ignores or refuses something in a state one of the
 * person's conditions names, with the condition it narrows. [] when none.
 */
export function narrowings(person: string, note: string): { asked: string; said: string; state: string }[] {
  const conds = personConditions(person).map((c) => ({ c, states: statesIn(c) })).filter((x) => x.states.length > 0);
  if (conds.length === 0) return [];
  const out: { asked: string; said: string; state: string }[] = [];
  for (const s of note.split(/(?<=[.!?])\s+(?=[A-Z`"])|\n/).map((x) => x.replace(/^\s*[-*]\s*/, "").trim())) {
    if (s === "" || s.startsWith(FOREMAN_NOTE) || !DROPS.test(s)) continue;
    const here = statesIn(s);
    const c = conds.find((x) => x.states.some((k) => here.includes(k)));
    if (c !== undefined && !out.some((o) => o.said === s)) out.push({ asked: c.c, said: s, state: c.states.find((k) => here.includes(k)) as string });
  }
  return out;
}

/**
 * At a package's merge in a person's change: one note per narrowing in its builder's notes since it was re-opened
 * (Create and the what-changed card show them as "part of your change was NOT made"). [] otherwise.
 */
export function narrowedNotes(events: readonly JobEvent[], id: string, round: number): { type: "note"; package: string; round: number; text: string }[] {
  const asked = askedChange(events);
  if (asked === undefined) return [];
  const since = [...events].reverse().find((e) => e.type === "reopened" && e.package === id)?.seq ?? asked.seq;
  const note = events.filter((e) => e.type === "note" && e.package === id && e.seq > since && !e.text.startsWith(FOREMAN_NOTE)).map((e) => (e.type === "note" ? e.text : "")).join("\n");
  return narrowings(asked.text, note)
    .map((n) => `${FOREMAN_NOTE}${NARROWED}${id} made it for fewer cases than you asked: you asked "${clip(n.asked, 240)}", and ${id} says (${n.state}): "${clip(n.said, 300)}"`)
    .filter((text) => !events.some((e) => e.type === "note" && e.package === id && e.text === text))
    .map((text) => ({ type: "note" as const, package: id, round, text }));
}
