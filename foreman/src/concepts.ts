// L1b of 21 Nov: crazy must not collapse onto the idea standard already took. Last night's proof showed both modes
// choosing the same family ("slam rivals into stone that collapses"). A crazy concept step therefore reads the
// standard concepts made for the same sentence in the same site (other job directories), and is told to leave their
// idea family; without one, the crazy prompt forbids the most typical crazy move. Reads job logs; writes nothing.
import fs from "node:fs";
import path from "node:path";
import type { Concept } from "./events.js";
import { readLog } from "./joblog.js";
import type { Creativity } from "./v2.js";

const norm = (s: string): string => s.trim().toLowerCase().replace(/\s+/g, " ").replace(/[.!?]+$/, "");

/**
 * The concepts of STANDARD jobs in `siteDir` whose sentence is this one (case and spacing ignored), newest last.
 * `except`: a job directory to leave out (the job being designed). A log that cannot be read is skipped.
 */
export function standardConcepts(siteDir: string, sentence: string, except?: string, mode: "standard" | "crazy" = "standard"): Concept[] {
  if (!fs.existsSync(siteDir)) return [];
  const out: { mtime: number; concept: Concept }[] = [];
  for (const d of fs.readdirSync(siteDir, { withFileTypes: true })) {
    const dir = path.join(siteDir, d.name);
    if (!d.isDirectory() || (except !== undefined && path.resolve(dir) === path.resolve(except)) || !fs.existsSync(path.join(dir, "job.jsonl"))) continue;
    try {
      const { events } = readLog(dir);
      const created = events.find((e) => e.type === "job_created");
      if (created?.type !== "job_created" || (mode === "crazy" ? created.creativity !== "crazy" : created.creativity !== undefined) || norm(created.sentence) !== norm(sentence)) continue;
      const brief = [...events].reverse().find((e) => e.type === "brief_set");
      if (brief?.type === "brief_set" && brief.brief.concept) out.push({ mtime: fs.statSync(path.join(dir, "job.jsonl")).mtimeMs, concept: brief.brief.concept });
    } catch {
      /* a broken or foreign log says nothing about this sentence */
    }
  }
  return out.sort((a, b) => a.mtime - b.mtime).map((x) => x.concept);
}

/** How many earlier designs of the same sentence and mode the concept step is shown (the newest). */
export const EARLIER_MAX = 4;

/**
 * What a concept step is given: for a crazy job the standard concepts of the same sentence (`taken`); for both modes
 * the earlier concepts of the same sentence in the same mode (`earlier`, N4 loop round 5: three crazy colosseum runs in
 * a row chose "a parry swaps your soul into the rival's body"; four standard ones broke the stone walls).
 */
export function takenFor(siteDir: string, sentence: string, creativity: Creativity | undefined, except?: string): { taken?: Concept[]; earlier?: Concept[] } {
  const earlier = standardConcepts(siteDir, sentence, except, creativity === "crazy" ? "crazy" : "standard").slice(-EARLIER_MAX);
  const taken = creativity === "crazy" ? standardConcepts(siteDir, sentence, except) : [];
  return { ...(taken.length > 0 ? { taken } : {}), ...(earlier.length > 0 ? { earlier } : {}) };
}

/** The concept prompt's block about earlier designs of the same sentence in the same mode ("" without any). */
export function earlierText(earlier: Concept[] | undefined): string {
  if (earlier === undefined || earlier.length === 0) return "";
  return [
    "",
    "# Earlier designs of this same sentence in this mode (other jobs on this site)",
    ...earlier.map((c, i) => `- earlier design ${i + 1}: "${c.anchor} where ${c.hook}" (it chose "${c.candidates[c.chosen]?.pitch ?? "?"}")`),
    "The core loop stays the proven template (the same template is right). The HOOK must come from another idea family than every one above: not the same twist on another object, not the same twist bigger or later. A player who asks for this game again must meet a hook they have not seen. `why` names the earlier family you left.",
    "",
  ].join("\n");
}

/** The concept prompt's block about what is taken; the crazy fallback when nothing is. "" for a standard job. */
export function takenText(creativity: Creativity | undefined, taken: Concept[] | undefined): string {
  if (creativity !== "crazy") return "";
  if (taken === undefined || taken.length === 0) {
    return [
      "",
      "# Escape the obvious crazy move",
      "Before you write, name to yourself the most typical crazy twist for this sentence: the one any designer reaches for first (for a fight in an arena that is the arena breaking apart, stone or hazards falling on the fighters, or animals let loose). That move and every variation of it are FORBIDDEN as the crazy mechanic: a bigger version, the same hazard on another object, the same destruction later in the round.",
      "Each candidate bends a rule the player takes for granted instead: what scores, who or what the player controls, what a hit leaves behind, who the audience is, how time works. The five candidates come from at least four different idea families; `why` names the typical move you left out.",
      "The core loop stays the proven template's (a fight is still the duel template, copied): crazy bends what sits on top of it, never the template's verbs, frames or contact results.",
      "",
    ].join("\n");
  }
  const lines = taken.map((c, i) => {
    const pick = c.candidates[c.chosen];
    return `- standard design ${i + 1}: it chose "${pick?.pitch ?? "?"}" (${c.anchor} where ${c.hook}); its other candidates: ${c.candidates.filter((_, k) => k !== c.chosen).map((x) => `"${x.pitch}"`).join("; ")}`;
  });
  return [
    "",
    "# Already designed: the STANDARD version of this same sentence",
    ...lines,
    "Your crazy concept must come from a DIFFERENT idea family than every concept above: not the chosen one, not a variation of it (the same verb on another object, the same hazard bigger or later, the same destruction), and not one of its other candidates. A player who has played the standard version must meet a game whose core twist they have not seen. Bend a rule the player takes for granted: what scores, who or what they control, what a hit leaves behind, who the audience is, how time works. The five candidates come from at least four different idea families; `why` names which standard family you left and why yours is not a variation of it.",
    "The core loop stays the proven template's, the same one the standard design copies (a fight is still the duel template): the idea family is the hook on top of it, not a new combat system.",
    "",
  ].join("\n");
}

const STOP = new Set(["the", "and", "with", "your", "their", "them", "they", "into", "onto", "from", "that", "this", "where", "until", "then", "each", "every", "rival", "rivals", "fight", "fighter", "fighters", "arena", "colosseum", "game", "player", "players"]);
const words = (s: string): Set<string> => new Set(s.toLowerCase().replace(/[^a-z\s]/g, " ").split(/\s+/).filter((w) => w.length >= 4 && !STOP.has(w)).map((w) => w.replace(/(ing|ed|es|s)$/, "")));

/**
 * A crude guard against the collapse: the chosen crazy pitch and hook share most of their content words with a taken
 * concept's chosen pitch and hook (Jaccard over content words above `max`). Words of the sentence itself do not count.
 */
/**
 * N4 loop round 5: the chosen HOOK against the hooks of earlier designs of the same sentence and mode (content words of
 * the hooks alone, Jaccard above `max`): the hook is the family; pitches dilute it. Real 22 Nov hooks: "parrying a heavy
 * swaps your soul into your rival's body" and "a perfect parry swaps your soul into the rival's body" share 4 of 6.
 */
export function earlierProblems(concept: Concept, earlier: Concept[] | undefined, sentence: string, max = 0.4): string[] {
  if (!earlier?.length) return [];
  const own = words(sentence);
  const bag = (h: string): Set<string> => new Set([...words(h)].filter((w) => !own.has(w)));
  const mine = bag(concept.hook);
  const out: string[] = [];
  for (const e of earlier) {
    const theirs = bag(e.hook);
    const inter = [...mine].filter((w) => theirs.has(w));
    if (inter.length / Math.max(1, new Set([...mine, ...theirs]).size) > max) out.push(`the chosen hook is too close to an earlier design of this sentence ("${e.hook}"): they share ${inter.join(", ")}. Choose a hook from another idea family (see "Earlier designs of this same sentence"); the core template stays`);
  }
  return out;
}

export function takenProblems(concept: Concept, taken: Concept[] | undefined, sentence: string, max = 0.4, what = "the standard design"): string[] {
  if (!taken?.length) return [];
  const own = words(sentence);
  const bag = (c: Concept): Set<string> => new Set([...words(`${c.candidates[c.chosen]?.pitch ?? ""} ${c.hook}`)].filter((w) => !own.has(w)));
  const mine = bag(concept);
  const out: string[] = [];
  for (const t of taken) {
    const theirs = bag(t);
    const inter = [...mine].filter((w) => theirs.has(w));
    const j = inter.length / Math.max(1, new Set([...mine, ...theirs]).size);
    if (j > max) out.push(what === "the standard design" ? `the chosen crazy concept is too close to the standard design ("${t.hook}"): they share ${inter.join(", ")}. Choose a concept from another idea family (see "Already designed")` : `the chosen hook is too close to ${what} ("${t.hook}"): they share ${inter.join(", ")}. Choose a hook from another idea family (see "Earlier designs of this same sentence")`);
  }
  return out;
}

// ---------- E3c of 25 Nov: a plain sentence is taken at its word ----------
// Lane E5's real proof: for "3 against 3 hockey on a small pond rink" the concept step chose candidate 4 of 5 ("each goal
// drafts you to the team you beat", likelihood 0.08), and the person had to drop four aspects by hand. A standard job
// whose words name a known game (a genre template other than `own`) and ask for no twist chooses the FAITHFUL reading,
// candidate 1 (index 0): the game the words name, done well. The other four stay as alternatives a person can pick.

/** Words that ask for a twist on top of the named game (a plain sentence has none of them). */
export const TWIST_WORDS = /\b(twist|twisted|crazy|weird|wild|strange|surprise|but|except|instead|unless|whenever|every time|each time|where (?:the|you|your|every|each|a|an)|while|reversed|upside[- ]down|zombies?|lava|rockets?|magic|power[- ]?ups?|gravity|portals?)\b/i;

/** True when a sentence asks for something on top of the game it names. */
export const asksForTwist = (sentence: string): boolean => TWIST_WORDS.test(sentence);

/**
 * Problems of a concept that should have taken the sentence at its word: on a standard job whose sentence names a known
 * game (`named`: the template the words call for, else undefined) and asks for no twist, `chosen` is 0 and candidate 0
 * is the faithful (most likely) reading. [] otherwise.
 */
export function faithfulProblems(c: Concept, sentence: string, creativity: Creativity | undefined, named: string | undefined): string[] {
  if (creativity === "crazy" || named === undefined || asksForTwist(sentence)) return [];
  const out: string[] = [];
  const top = Math.max(...c.candidates.map((x) => x.likelihood));
  if ((c.candidates[0]?.likelihood ?? 0) < top) out.push(`candidate 1 (index 0) is the faithful reading of the player's words "${sentence}": the game they name, done well, with no twist they did not ask for; give it the highest likelihood (it has ${c.candidates[0]?.likelihood ?? "?"}, another has ${top})`);
  if (c.chosen !== 0) out.push(`the player's words name a known game (${named}) and ask for no twist: choose the faithful reading, "chosen": 0, not candidate ${c.chosen + 1} ("${c.candidates[c.chosen]?.pitch ?? "?"}", likelihood ${c.candidates[c.chosen]?.likelihood ?? "?"}). Keep the bolder ideas as the other candidates: the person can pick one; a twist they did not ask for is one they must remove by hand`);
  return out;
}
