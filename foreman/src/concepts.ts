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
export function standardConcepts(siteDir: string, sentence: string, except?: string): Concept[] {
  if (!fs.existsSync(siteDir)) return [];
  const out: { mtime: number; concept: Concept }[] = [];
  for (const d of fs.readdirSync(siteDir, { withFileTypes: true })) {
    const dir = path.join(siteDir, d.name);
    if (!d.isDirectory() || (except !== undefined && path.resolve(dir) === path.resolve(except)) || !fs.existsSync(path.join(dir, "job.jsonl"))) continue;
    try {
      const { events } = readLog(dir);
      const created = events.find((e) => e.type === "job_created");
      if (created?.type !== "job_created" || created.creativity !== undefined || norm(created.sentence) !== norm(sentence)) continue;
      const brief = [...events].reverse().find((e) => e.type === "brief_set");
      if (brief?.type === "brief_set" && brief.brief.concept) out.push({ mtime: fs.statSync(path.join(dir, "job.jsonl")).mtimeMs, concept: brief.brief.concept });
    } catch {
      /* a broken or foreign log says nothing about this sentence */
    }
  }
  return out.sort((a, b) => a.mtime - b.mtime).map((x) => x.concept);
}

/** What a crazy concept step is given: the standard concepts of the same sentence (none for a standard job). */
export function takenFor(siteDir: string, sentence: string, creativity: Creativity | undefined, except?: string): { taken?: Concept[] } {
  if (creativity !== "crazy") return {};
  const taken = standardConcepts(siteDir, sentence, except);
  return taken.length > 0 ? { taken } : {};
}

/** The concept prompt's block about what is taken; the crazy fallback when nothing is. "" for a standard job. */
export function takenText(creativity: Creativity | undefined, taken: Concept[] | undefined): string {
  if (creativity !== "crazy") return "";
  if (taken === undefined || taken.length === 0) {
    return [
      "",
      "# Escape the obvious crazy move",
      "Before you write, name to yourself the most typical crazy twist for this sentence: the one any designer reaches for first (for a fight in an arena that is the arena breaking apart, stone or hazards falling on the fighters, or animals let loose). That move and every variation of it are FORBIDDEN as the crazy mechanic: a bigger version, the same hazard on another object, the same destruction later in the round.",
      "Each candidate bends a rule the player takes for granted instead: what scores, who or what the player controls, what a hit does, who the audience is, how time works. The five candidates come from at least four different idea families; `why` names the typical move you left out.",
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
    "Your crazy concept must come from a DIFFERENT idea family than every concept above: not the chosen one, not a variation of it (the same verb on another object, the same hazard bigger or later, the same destruction), and not one of its other candidates. A player who has played the standard version must meet a game whose core twist they have not seen. Bend a rule the player takes for granted: what scores, who or what they control, what a hit does, who the audience is, how time works. The five candidates come from at least four different idea families; `why` names which standard family you left and why yours is not a variation of it.",
    "",
  ].join("\n");
}

const STOP = new Set(["the", "and", "with", "your", "their", "them", "they", "into", "onto", "from", "that", "this", "where", "until", "then", "each", "every", "rival", "rivals", "fight", "fighter", "fighters", "arena", "colosseum", "game", "player", "players"]);
const words = (s: string): Set<string> => new Set(s.toLowerCase().replace(/[^a-z\s]/g, " ").split(/\s+/).filter((w) => w.length >= 4 && !STOP.has(w)).map((w) => w.replace(/(ing|ed|es|s)$/, "")));

/**
 * A crude guard against the collapse: the chosen crazy pitch and hook share most of their content words with a taken
 * concept's chosen pitch and hook (Jaccard over content words above `max`). Words of the sentence itself do not count.
 */
export function takenProblems(concept: Concept, taken: Concept[] | undefined, sentence: string, max = 0.4): string[] {
  if (!taken?.length) return [];
  const own = words(sentence);
  const bag = (c: Concept): Set<string> => new Set([...words(`${c.candidates[c.chosen]?.pitch ?? ""} ${c.hook}`)].filter((w) => !own.has(w)));
  const mine = bag(concept);
  const out: string[] = [];
  for (const t of taken) {
    const theirs = bag(t);
    const inter = [...mine].filter((w) => theirs.has(w));
    const j = inter.length / Math.max(1, new Set([...mine, ...theirs]).size);
    if (j > max) out.push(`the chosen crazy concept is too close to the standard design ("${t.hook}"): they share ${inter.join(", ")}. Choose a concept from another idea family (see "Already designed")`);
  }
  return out;
}
