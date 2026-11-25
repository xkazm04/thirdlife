// H1e of 25 Nov (lanes G2 and G4: robot football and a half-court basketball game built on the arcade_sport template,
// whose house game is the hockey): a game is judged by what its own rules have. The critic was given 70 hockey contact
// rows (hits.board_bonus, hits.check_cone_deg, ...) as "missing" from a basketball pack, and the builders were told to
// "make the house game's kind happen" (a one_timer). A house game's contact row or verb that this game's design does not
// have is not required and never "missing": it is said once, as not judged.
// The game's own words are its design: the verbs (ids and the template moves they copy), the clip moments and the aspect
// cards' ids. Words that say nothing about which game it is (units, limits, body physics, juice) transfer to any game
// with bodies: a row made only of them is required everywhere.
import type { Brief } from "./events.js";

/** The game's own words (lower case), or undefined for a brief without a design (then nothing is filtered). */
export function gameWords(brief: Brief | undefined): Set<string> | undefined {
  const d = brief?.design;
  if (d === undefined) return undefined;
  const names = [...d.verbs.flatMap((v) => [v.id, v.move ?? ""]), ...d.clips.map((c) => c.id), ...(brief?.aspects ?? []).map((a) => a.id)];
  return new Set(names.flatMap(wordsOf));
}

/** Words of a row's or a verb's name that say nothing about which game it is. */
const GENERIC = new Set([
  "hits", "fun", "gap", "cone", "deg", "cooldown", "frames", "frame", "window", "min", "max", "speed", "ratio", "share",
  "radius", "length", "bonus", "range", "kept", "live", "recent", "clip", "dot", "arc", "match", "base", "bot", "mult",
  "scale", "time", "delay", "thrust", "stability", "stand", "brace", "side", "behind", "full", "down", "downed", "lying",
  "grace", "give", "restitution", "scatter", "back", "strip", "hold", "turn", "exposed", "margin", "push", "pull", "windup",
  "stop", "closing", "hard", "shake", "replay", "slow", "card", "tail", "end", "before", "body", "unseen", "sprint", "charge",
  "stumble", "loose", "hit", "contact",
]);

/** The words of a dotted, snake_case name (hits.board_bonus -> board, bonus); numbers and one- or two-letter units go. */
export const wordsOf = (name: string): string[] => name.toLowerCase().split(/[^a-z0-9]+/).filter((w) => w.length > 2 && !/^\d+$/.test(w));

/** One word of the game's: the same, or one the start of the other (shot / shoot are not; check / checks are). */
function own(words: Set<string>, w: string): boolean {
  for (const g of words) if (g === w || (Math.min(g.length, w.length) >= 4 && (g.startsWith(w) || w.startsWith(g)))) return true;
  return false;
}

/** The words of a row that name a game (not generic), and of those the ones this game does not have. */
const foreignOf = (words: Set<string>, name: string): string[] => wordsOf(name).filter((w) => !GENERIC.has(w) && !own(words, w));

/** Does the game have this contact row? A row of generic words only: yes; else every word that names a game must be the game's. */
export function gameHasRow(words: Set<string> | undefined, row: string): boolean {
  return words === undefined || foreignOf(words, row).length === 0;
}

/** Does the game have this verb or contact kind (one_timer, wall_splat, screen_spring)? Every word of it is the game's. */
export function gameHasVerb(words: Set<string> | undefined, verb: string): boolean {
  return words === undefined || wordsOf(verb).every((w) => GENERIC.has(w) || own(words, w));
}

/** The house words the game does not have, over some rows, for the one line that says those rows were not judged. */
export function foreignWords(words: Set<string> | undefined, rows: string[]): string[] {
  if (words === undefined) return [];
  return [...new Set(rows.flatMap((r) => foreignOf(words, r)))];
}
