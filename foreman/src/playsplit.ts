// D27 lane T3, item 37 (lane J2b's Arsenal copy, events 1255-1290 and 1325-1347): on the rink core the Planner gave a
// person's play rules to the drawing package twice. "Any skater ... who lands a body check goes MEGA for five seconds ...
// twice as heavy and a bit faster, every bump knocks a man flat ... he turns wide" went to harbour, which drew MEGA and
// wrote the stats as a NOT DONE; "they should land their body checks on me and my mates more often" went to harbour "in
// scripts/main.gd". Both reached the cartridge only through the hand-off, after a drawing round that guessed at play it
// cannot change (coreowner.ts keeps the Planner's owner when the words also name a picture). On a core how a game plays
// is the cartridge's, so a person's change whose words ask for play goes to the cartridge's owner FIRST; the package the
// Planner named gets the same change as the Foreman's request for the drawing, and it runs after the cartridge's merge
// when it depends on it (the scheduler waits for a package's dependencies), so it draws what the cartridge made (an
// effect's id, the events it starts) instead of a copy of the rule. Pure.
import type { JobEvent, PackageSpec } from "./events.js";
import { isBase, type CoreRoute } from "./coreroute.js";
import { DRAW_WORDS, cartridgeOwner } from "./coreowner.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";

/**
 * Words that ask for how the game PLAYS (a rule, a stat, how often, what a hit does), not for what it shows. Nouns of the
 * place alone ("the ice", "the puck", "on screen") are not an ask: "YOU ARE MEGA! stays on screen while I lie on the ice"
 * is a picture. A strong ask is play wherever it stands; a weak one (a comparative, a knockdown) only in a sentence that
 * names nothing to see ("pulsing faster as he gets closer" is the arrow's; "when a rival knocks me down, YOU ARE MEGA!
 * stays on screen" is the words').
 */
export const PLAY_ASK = /\b(more often|less often|as often|twice as (?:heavy|fast|strong|often|many|much)|half as (?:heavy|fast|strong|often|many|much)|(?:one|two|three|four|five|six|ten|twenty|\d+) times (?:as|more) (?:often|heavy|fast|strong)|turns? wide|earns?|earned|lands? (?:\w+ ){0,2}(?:body )?checks?|first to|cooldown|recharg\w*|heavier|lighter|mass|friction)\b/i;
export const PLAY_WEAK = /\b(faster|slower|quicker|stronger|weaker|harder|easier|knocks? (?:\w+ ){0,3}(?:flat|down|over)|knocked (?:flat|down|over)|bounc\w*)\b/i;

/** The sentences of `text` that ask for play, in order; "" when none does. Quoted words are text to show, never an ask. */
export function playSentences(text: string): string {
  return text
    .replace(/"[^"]*"|“[^”]*”/g, "\"...\"")
    .split(/(?<=[.!?])\s+(?=["“A-Z])/)
    .map((s) => s.trim())
    .filter((s) => s !== "" && (PLAY_ASK.test(s) || (PLAY_WEAK.test(s) && !DRAW_WORDS.test(s))))
    .join(" ");
}

/** The start of the Foreman's request for the drawing of a change whose play went to the cartridge first. */
export const drawPartHead = (seq: number): string => `${FOREMAN_NOTE}the drawing part of change request ${seq}, `;

/**
 * On a game on a core, a person's change the Planner gave to `owner` (not the cartridge's owner, not the base) whose
 * words ask for play: the change goes to the cartridge's owner first (`owner`), and `owner` gets the Foreman's request for
 * the drawing (`draw`). Undefined off a core, for a Foreman request, when the owner already is the cartridge's, or when
 * no sentence asks for play.
 */
export function playSplit(plan: readonly PackageSpec[], core: CoreRoute | undefined, owner: string, seq: number, text: string): { owner: string; why: string; draw?: { package: string; text: string } } | undefined {
  if (core === undefined || text.startsWith(FOREMAN_NOTE)) return undefined;
  const cart = cartridgeOwner(plan);
  const spec = plan.find((p) => p.id === owner);
  if (cart === undefined || spec === undefined || isBase(spec) || cart.id === owner) return undefined;
  const play = playSentences(text);
  if (play === "") return undefined;
  const after = (spec.deps ?? []).includes(cart.id) ? `, and your package runs after its merge` : "";
  const why = `on a game on the ${core.core} core how the game plays is the cartridge's, and the words "${clip(play, 300)}" ask for play, so the change goes to "${cart.id}" first (it owns ${cart.scope.join(", ")}); "${owner}", which the Planner named, draws it${after ? " after that merge" : ""}`;
  const body = `${drawPartHead(seq)}for what your files show and play out (${spec.scope.slice(0, 6).join(", ")}${spec.scope.length > 6 ? ", ..." : ""}): "${cart.id}" makes how it plays first, in the game's cartridge (the rules, stats, effects and bots these words ask for: "${clip(play, 600)}")${after}. Draw what the merged cartridge makes (read its effect ids and the events the core sends for them: never a copy of the rule of your own) and make everything of the change that is seen or heard; a play rule the cartridge has made is not yours to write again or to mark NOT DONE. The whole change: "${text}"`;
  // words with nothing to draw are the cartridge's alone (coreowner.ts moves those there already)
  return { owner: cart.id, why, ...(DRAW_WORDS.test(text) ? { draw: { package: owner, text: clip(body, 3000) } } : {}) };
}

/**
 * The live D27 T3 copy (event 1262): the quick cartridge diff made exactly the play (`mega`: trigger check_landed, mass
 * x2, speed x1.1, turn rate x0.6) and said "No key can say the white flash, the boing, ... the camera shake or the
 * trembling ice, so a builder has to add those", and item 29's check sent the whole change to the cartridge's builder for
 * what harbour draws. When the drawing of the change in flight went to another package, the sentences of the diff's
 * words that name only something to see or hear are that package's, not a part the diff left unmade.
 */
export function drawnElsewhere(events: readonly JobEvent[] | undefined, owner: string): boolean {
  let last = -1;
  for (const e of events ?? []) if (e.type === "promoted") last = e.seq;
  return (events ?? []).some((e) => e.type === "change_requested" && e.seq > last && e.package !== undefined && e.package !== owner && e.text.startsWith(`${FOREMAN_NOTE}the drawing part of change request `));
}

/** The diff's words without the sentences that name only a picture or a sound (what the drawing package makes). */
export function playWhy(why: string): string {
  return why
    .split(/(?<=[.!?])\s+/)
    .filter((s) => !(DRAW_WORDS.test(s) && !PLAY_ASK.test(s)))
    .join(" ");
}
