// E3f of 25 Nov (lane E5's real proof, job 2): on a game on a core, who takes a change. "make the goals bigger" on a
// pirate game (teal v gold, first to 1, 70 x 35) was given to the base package by the Planner ("goal size is part of the
// play space, which the root builds"); the base's change round copies the engine's base again, so the game came back
// as plain HOKEJ. On a core the base is the engine's copy: no round of it changes anything a person asked for. A change
// goes to the package that owns the game's cartridge (goal size, rink size, speeds, rules, teams, the bots), or to the
// skin's owner when the words are only words and colours. The Planner is not offered the base (its question lists the
// job's own packages), and whatever answers "base" anyway (a fallback to the root, a phase hold's first package) is
// moved here. Pure: the plan, the words and the core route in, a package out.
import type { PackageSpec } from "./events.js";
import type { PackageLine } from "./designer.js";
import { isBase, type CoreRoute } from "./coreroute.js";
import { matchesAny } from "./scope.js";

/** Words that name the skin only (what a person reads and the colours), not how the game plays. */
export const SKIN_ONLY_WORDS = /\b(colou?rs?|red|blue|green|teal|gold|orange|purple|pink|yellow|black|white|names?|named|rename|title|words?|commentary|barks?|banner|says?|call|called|font|logo|jersey|jerseys|look|looks)\b/i;
/** Words that name the cartridge (the play): sizes, speeds, rules, teams, the bots. These win over skin words. */
export const CARTRIDGE_WORDS = /\b(goals?|nets?|rink|ice|pond|arena|bigger|smaller|wider|narrower|longer|shorter|larger|faster|slower|speed|quick|quicker|rules?|first to|score|scoring|minutes?|time|timer|teams?|players?|skaters?|a side|strong|stronger|weak|weaker|hard|harder|easy|easier|difficult|bots?|puck|shots?|pass|passes|check|checks|friction|slippery|bounce)\b/i;

/** The package of a core plan that owns the game's cartridge: the one that also owns data/match.json first, else any. */
export function cartridgeOwner(plan: readonly PackageSpec[]): PackageSpec | undefined {
  const owns = (p: PackageSpec): boolean => !isBase(p) && p.scope.some((g) => /\.cartridge\.json$|cartridge/.test(g));
  return plan.find((p) => owns(p) && matchesAny(p.scope, "data/match.json")) ?? plan.find(owns);
}

/** The package of a core plan that owns the skin (data/skin.json), not the base. */
export const skinOwner = (plan: readonly PackageSpec[]): PackageSpec | undefined => plan.find((p) => !isBase(p) && matchesAny(p.scope, "data/skin.json"));

/**
 * The owner a change really goes to. Off a core, or an owner that is not the base: `owner` as given. On a core, the base:
 * the skin's owner when the words name only the skin, else the cartridge's owner, else the skin's; the base only when
 * the plan has nothing else. `why` says it in words for the `reopened` reason.
 */
export function coreChangeOwner(plan: readonly PackageSpec[], core: CoreRoute | undefined, owner: string, text: string): { owner: string; why?: string } {
  const spec = plan.find((p) => p.id === owner);
  if (core === undefined || spec === undefined) return { owner };
  if (!isBase(spec)) return playOwner(plan, core, spec, text);
  const cart = cartridgeOwner(plan);
  const skin = skinOwner(plan);
  const skinOnly = SKIN_ONLY_WORDS.test(text) && !CARTRIDGE_WORDS.test(text);
  const to = (skinOnly ? (skin ?? cart) : (cart ?? skin));
  if (to === undefined) return { owner };
  const what = to === cart ? `the game's cartridge (sizes, speeds, rules, teams, the bots: ${to.scope.join(", ")})` : `the game's skin (${to.scope.join(", ")})`;
  return { owner: to.id, why: `on a game on the ${core.core} core the base "${owner}" is the engine's copy of engine/templates/${core.base}/ (a round of it copies the same files and undoes the game's own data), so the change goes to "${to.id}", which owns ${what}` };
}

/**
 * The packages the Planner may name for a change on a core game: the job's own packages, not the base (when there is
 * any other). Off a core, every line as given.
 */
export function changeCandidates(lines: PackageLine[], plan: readonly PackageSpec[], core: CoreRoute | undefined): PackageLine[] {
  if (core === undefined) return lines;
  const base = new Set(plan.filter(isBase).map((p) => p.id));
  const own = lines.filter((l) => !base.has(l.id));
  return own.length > 0 ? own : lines;
}

/** H1d: words that name the game's toys and how they play (the cartridge's abilities, pickups, zones and effects). */
export const TOY_PLAY_WORDS = /\b(bubbles?|shields?|abilit(?:y|ies)|pickups?|power-?ups?|spots?|tricks?|boosts?|zones?|pads?|cannon|hip[- ]check|cooldowns?|charges?|comes? back|win|wins|winning|matches)\b/i;
/** H1d: words that name a picture (what a drawing package changes), which keep the Planner's owner. */
export const DRAW_WORDS = /\b(draw\w*|look\w*|see|seen|visible|show\w*|glow\w*|bright\w*|colou?r\w*|flash\w*|sounds?|icons?|signs?|labels?|hints?|hud|camera|animat\w*|pictures?|clutter|boxes|beads?)\b/i;

/**
 * H1d (lane G1's change 3: "let my bubble come back by itself ... make the green spots hand out a cannon shot or a hip
 * check" went to `harbour`, the drawing package, and cost 33.5 min and 3.98 M tokens without being made): on a core, words
 * about play (sizes, speeds, rules, the bots, the toys) with no word about a picture go to the cartridge's owner when the
 * Planner named a package that does not own the game's cartridge. The skin's words stay the skin's; a picture stays the
 * Planner's choice.
 */
function playOwner(plan: readonly PackageSpec[], core: CoreRoute, spec: PackageSpec, text: string): { owner: string; why?: string } {
  const cart = cartridgeOwner(plan);
  if (cart === undefined || cart.id === spec.id) return { owner: spec.id };
  const play = CARTRIDGE_WORDS.test(text) || TOY_PLAY_WORDS.test(text);
  const skinOnly = SKIN_ONLY_WORDS.test(text) && !play;
  const namedSkin = skinOwner(plan)?.id === spec.id && SKIN_ONLY_WORDS.test(text); // "rename the teams" stays the skin's
  if (!play || skinOnly || namedSkin || DRAW_WORDS.test(text)) return { owner: spec.id };
  return { owner: cart.id, why: `on a game on the ${core.core} core how the game plays (its sizes, speeds, rules, bots and toys) is the cartridge's, and these words ask for play, not a picture: the change goes to "${cart.id}", which owns the game's cartridge (${cart.scope.join(", ")}); "${spec.id}" owns ${spec.scope.join(", ")}` };
}

/** H1h: words that name the game's text, which lives in the skin (data/skin.json and its text files). */
export const SKIN_TEXT = /\b(title|tagline|subtitle|slogan|commentary|announcer|team names?|names? of the teams|rename\w*)\b/i;

/**
 * H1h (lane G1's v0.1.11, event 584: "Change the line under the title to: Grab a trick at the green spots. F uses it." went
 * with two drawing asks to `harbour`, which cannot edit the skin; it overrode the line from its own tuning file while the
 * skin still said the old line): the sentences of a change that name the game's text go to the skin's owner. A sentence
 * that sets a text after a colon takes the sentences after it (the new line's own full stops). `rest` is "" when every
 * sentence was the skin's (then the whole change goes there). Undefined when nothing moves: no skin owner, the change is
 * already the skin's, or no sentence names the text.
 */
export function skinSplit(plan: readonly PackageSpec[], owner: string, text: string): { to: string; skinText: string; rest: string; why: string } | undefined {
  const skin = skinOwner(plan);
  if (skin === undefined || skin.id === owner) return undefined;
  const sentences = (text.match(/[^.!?]+(?:[.!?]+|$)/g) ?? []).map((s) => s.trim()).filter((s) => s !== "");
  const first = sentences.findIndex((s) => SKIN_TEXT.test(s));
  if (first < 0) return undefined;
  const mine = sentences.map((s, i) => (i === first || (i > first && sentences[first]?.includes(":") === true) ? true : i > first && SKIN_TEXT.test(s)));
  const skinText = sentences.filter((_, i) => mine[i]).join(" ");
  const rest = sentences.filter((_, i) => !mine[i]).join(" ");
  return { to: skin.id, skinText, rest, why: `the words "${skinText}" set the game's text (title, tagline, names, commentary), which lives in the skin, so ${rest === "" ? "the change goes" : "that part goes"} to "${skin.id}", which owns ${skin.scope.join(", ")}` };
}
