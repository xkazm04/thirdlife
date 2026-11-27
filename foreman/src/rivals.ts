// D27 item 1 (lane J19 of 27 Nov, events 593-619): "The rivals charge an open line, raise shields when charged, slam a
// crowd and run out of the ring" went with the whole change to ONE package, core. In the 3 v 3 game four of the five
// bots think in the crew package's scripts/crew/mind.gd, so only Bram (core's brain.gd) learned the moves: the bots
// rushed 0 a minute. A change names one owner (the Planner's answer); the sentences of it that tell the rivals what to
// do also go, as a change request of the Foreman's, to every OTHER package whose files drive a bot (a mind, a brain,
// an ai file). Nothing is sent when no sentence names the rivals: the Foreman never adds a bot line nobody asked for.
import type { PackageSpec } from "./events.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";

/** Words that name players the bots play: the person's rivals, the computer's players, and in a team game the bots'
 * own roles (defenders, mates, keepers). */
export const RIVAL_WORDS = /\b(rivals?|bots?|opponents?|enem(?:y|ies)|foes?|the other (?:side|team|crew|squad)|computer players?|defenders?|attackers?|teammates?|team-mates?|(?:my|our|his|their) mates|keepers?|goalies?)\b|\b(?:AI|CPU)\b/i;
/** What a bot does: a verb after the rivals' word asks the bots for behaviour ("The rivals charge an open line"). */
const DOING = /\b(charg\w*|slam\w*|attack\w*|block\w*|dodg\w*|run\w*|chas\w*|press\w*|shoot\w*|pass\w*|dunk\w*|div\w*|jump\w*|us(?:e|es|ing)|try|tries|raise\w*|flee\w*|guard\w*|defend\w*|double\w*|swarm\w*|hit\w*|strik\w*|throw\w*|dash\w*|rush\w*|answer\w*|react\w*|counter\w*|retreat\w*|flank\w*|mark\w*|tackl\w*|steal\w*|aim\w*|fir(?:e|es|ing)|slow\w*|fast\w*|aggress\w*|smart\w*|clever\w*|team up|gang up|cover\w*|contest\w*|go(?:es)? for|come(?:s)? at|punish\w*|wait\w*|reject\w*|swat\w*|crowd\w*|surround\w*|focus\w*)\b/i;
/** A file whose name says it decides for a bot (outside tests/). */
export const MIND_FILE = /(?:^|\/)(?:brains?|minds?|ai|bots?|rivals?|opponents?|enem(?:y|ies)|foes?|tactics|coach|squad_ai|ai_[a-z0-9_]+|[a-z0-9_]+_ai)(?:\.[a-z]+$|\/)/i;

/**
 * The person's sentences that tell the rivals (the bots) what to do: a rivals' word with a verb of doing after it. A
 * sentence about what happens TO them ("it knocks down every skater, rivals and mates alike") or about their look
 * ("the rivals wear gold") is not a bot's. "" when none does.
 */
export function rivalSentences(text: string): string {
  // D27 round 4, item 19 (JB-back's shield copy, event 869: "... I never see BRACED!: a rival who sees ..." lost its start,
  // because "!" inside a sentence ended it): a sentence ends at . ! ? followed by a space or the end, never inside a word
  const sentences = text.split(/(?<=[.!?])\s+/).map((s) => s.trim()).filter((s) => s !== "");
  return sentences
    .filter((s) => {
      const m = RIVAL_WORDS.exec(s);
      // the verb follows within five words ("the other side scores: the ball trails flames ... their jumps" is not one)
      return m !== null && DOING.test(s.slice(m.index + m[0].length).split(/[:;]/)[0]?.trim().split(/\s+/).slice(0, 5).join(" ") ?? "");
    })
    .join(" ");
}

/** The files of a package that decide for a bot: its merged files, or its plan scope's plain paths before a merge. */
export function mindFiles(spec: Pick<PackageSpec, "scope">, merged: readonly string[] | undefined): string[] {
  const files = merged !== undefined && merged.length > 0 ? merged : spec.scope.filter((f) => !f.includes("*"));
  return files.filter((f) => !f.startsWith("tests/") && MIND_FILE.test(f));
}

/** Does package `id` depend on `on`, directly or through its dependencies? */
function dependsOn(plan: readonly PackageSpec[], id: string, on: string, seen = new Set<string>()): boolean {
  const deps = plan.find((p) => p.id === id)?.deps ?? [];
  return deps.some((d) => d === on || (!seen.has(d) && (seen.add(d), dependsOn(plan, d, on, seen))));
}

/** The start of the Foreman's change request for the rivals' part of change request `seq`. */
export const rivalPartHead = (seq: number): string => `${FOREMAN_NOTE}the rivals' part of change request ${seq}, `;

/**
 * The change requests for the rivals' part of a person's change: one for every package other than `owner` whose files
 * drive a bot (never a base package: on a core the bots are the core's). Empty when no sentence names the rivals or no
 * other package drives a bot.
 */
export function rivalSplit(plan: readonly PackageSpec[], merged: (id: string) => readonly string[] | undefined, owner: string, seq: number, text: string): { package: string; text: string; why: string }[] {
  const words = rivalSentences(text);
  if (words === "") return [];
  return plan.flatMap((p) => {
    if (p.id === owner || p.kind === "base") return [];
    const minds = mindFiles(p, merged(p.id));
    if (minds.length === 0) return [];
    const why = `the words "${clip(words, 300)}" tell the rivals what to do, and "${p.id}" drives bots too (${minds.join(", ")}), so they go to it as well`;
    const after = dependsOn(plan, p.id, owner) ? "and your package runs after its merge: make the bots you drive do what these words say with what it merged" : "make the bots you drive do what these words say";
    const body = `${rivalPartHead(seq)}for the bots your files drive (${minds.join(", ")}): "${words}". "${owner}" builds the rest of the change (the moves and rules it names) in the same change, ${after}. The whole change, for what the words refer to: "${text}"`;
    return [{ package: p.id, text: clip(body, 2000), why }];
  });
}
