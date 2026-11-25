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
  // H1g: the body rows (stand, brace, stability, stumble, ...) are the game's only when it has bodies that take a hit
  return new Set([...names.flatMap(wordsOf), ...(hasBodies(brief) ? BODY : [])]);
}

/**
 * H1g (lane G5, bumper karts, event 69: the builder was sent 49 house contact rows to add, hits.body_window,
 * stand_brace, sprint_stability, stumble_ratio ...): the words of rows about a body taking a hit (standing, bracing,
 * stumbling, falling). They are generic for a game of people, robots or creatures, and foreign to a game of vehicles.
 */
export const BODY = ["body", "stability", "stand", "brace", "stumble", "downed", "lying", "down", "loose", "unseen"];

/** Body reactions in a design's words: a game whose bodies stumble, tumble, fall or get up. */
const REACTS = /\b(stumbl\w*|tumbl\w*|stagger\w*|fall(s|ing|en)?|knock\w* (down|over)|get\w* (back )?up|clamber\w*|ragdoll\w*|flinch\w*|trip(s|ped)?|on foot)\b/i;
/** Vehicles in a design's words. */
const VEHICLES = /\b(karts?|cars?|vehicles?|trucks?|buggy|buggies|boats?|ships?|tanks?|planes?|hovercrafts?|motorbikes?|bikes?)\b/i;

/**
 * Has this game bodies that take a hit? Yes when its design says a body stumbles, tumbles, falls or gets up; no when it
 * is a game of vehicles that says none of that (a kart spins out, it does not stumble); yes otherwise (as before H1g).
 */
export function hasBodies(brief: Brief | undefined): boolean {
  const text = JSON.stringify(brief ?? {});
  return REACTS.test(text) || !VEHICLES.test(text);
}

/** Words of a row's or a verb's name that say nothing about which game it is. */
const GENERIC = new Set([
  "hits", "fun", "gap", "cone", "deg", "cooldown", "frames", "frame", "window", "min", "max", "speed", "ratio", "share",
  "radius", "length", "bonus", "range", "kept", "live", "recent", "clip", "dot", "arc", "match", "base", "bot", "mult",
  "scale", "time", "delay", "thrust", "side", "behind", "full",
  "grace", "give", "restitution", "scatter", "back", "strip", "hold", "turn", "exposed", "margin", "push", "pull", "windup",
  "stop", "closing", "hard", "shake", "replay", "slow", "card", "tail", "end", "before", "sprint", "charge", "hit", "contact",
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
