// The game-design method (docs/design/METHOD.md) in the editor. The design room's prompts carry the method's sections
// by number, as they carry the handbook's (roomtext.ts qualityText). The stages the brief has no key for yet (the
// fantasy, the reference-game teardown, the 30-second test, the kill criteria) are labelled lines at the head of
// `brief.rules`, a free string of the contract (JOB.md: brief_set.brief.rules), so nothing new is written to the log:
//   FANTASY: ...        one line, who the player is and what it feels like
//   TEARDOWN: ...       one to three lines, a reference game's moment: what you do, what you see, the numbers
//   30 SECONDS: ...     one line, the first 30 seconds as a newcomer meets them, in beats
//   KILL IF: ...        two to four lines, what a person playing the tofu phase would see that stops the game
// The Foreman reads them back for the review, the Planner, the critic and the person's playtest card at a phase pause.
import type { Brief } from "./events.js";
import { METHOD_DOC, methodText } from "./roomtext.js";

export { METHOD_DOC, methodText };

export const METHOD_LABELS = ["FANTASY", "TEARDOWN", "30 SECONDS", "KILL IF"] as const;
export type MethodLabel = (typeof METHOD_LABELS)[number];

export interface MethodLines {
  fantasy: string[];
  teardown: string[];
  thirty: string[];
  kill: string[];
}

const KEY: Record<MethodLabel, keyof MethodLines> = { FANTASY: "fantasy", TEARDOWN: "teardown", "30 SECONDS": "thirty", "KILL IF": "kill" };

/** The method lines of a `brief.rules` text, in order per label (empty lists when it has none: a brief made before the method). */
export function methodLines(rules: string | undefined): MethodLines {
  const out: MethodLines = { fantasy: [], teardown: [], thirty: [], kill: [] };
  for (const raw of (rules ?? "").split(/\r?\n/)) {
    const m = /^\s*(?:[-*]\s*)?(FANTASY|TEARDOWN|30 SECONDS|KILL IF)\s*:\s*(.+?)\s*$/.exec(raw);
    if (m) out[KEY[m[1] as MethodLabel]].push(m[2] as string);
  }
  return out;
}

/** True when the brief carries the method lines (a brief made before the method has none, and reads as before). */
export const hasMethod = (brief: Pick<Brief, "rules"> | undefined): boolean => {
  const l = methodLines(brief?.rules);
  return l.fantasy.length + l.teardown.length + l.thirty.length + l.kill.length > 0;
};

const words = (s: string): number => s.split(/\s+/).filter(Boolean).length;

/** The limits of the method lines (words per line, lines per label). */
export const METHOD_LIMITS = { fantasy: 25, teardown: 45, thirty: 70, kill: 30, teardownLines: [1, 3], killLines: [2, 4] } as const;

/** The design step's checks of the method lines (designer.ts sends an answer back on any). */
export function methodProblems(brief: Pick<Brief, "rules">): string[] {
  const l = methodLines(brief.rules);
  const out: string[] = [];
  const need = "brief.rules starts with the method lines (docs/design/METHOD.md section 3), each on its own line";
  if (l.fantasy.length !== 1) out.push(`${need}: exactly one "FANTASY: <who the player is and what it feels like>" line (found ${l.fantasy.length})`);
  if (l.teardown.length < METHOD_LIMITS.teardownLines[0] || l.teardown.length > METHOD_LIMITS.teardownLines[1]) out.push(`${need}: 1 to 3 "TEARDOWN: <reference game>: <its moment: what you do, what you see, the numbers>" lines (found ${l.teardown.length})`);
  if (l.thirty.length !== 1) out.push(`${need}: exactly one "30 SECONDS: <0-5 s ...; 5-15 s ...; 15-30 s ...>" line (found ${l.thirty.length})`);
  if (l.kill.length < METHOD_LIMITS.killLines[0] || l.kill.length > METHOD_LIMITS.killLines[1]) out.push(`${need}: 2 to 4 "KILL IF: <what a person playing the first phase would see that stops this game>" lines (found ${l.kill.length})`);
  const over = (label: string, lines: string[], max: number): void => lines.forEach((x) => { if (words(x) > max) out.push(`brief.rules ${label} line (${words(x)} words, limit ${max}): "${x.slice(0, 80)}"`); });
  over("FANTASY", l.fantasy, METHOD_LIMITS.fantasy);
  over("TEARDOWN", l.teardown, METHOD_LIMITS.teardown);
  over("30 SECONDS", l.thirty, METHOD_LIMITS.thirty);
  over("KILL IF", l.kill, METHOD_LIMITS.kill);
  return out;
}

/** The method lines as the review, the Planner and the critic read them ("" for a brief without them). */
export function methodBlock(brief: Pick<Brief, "rules"> | undefined): string {
  if (!hasMethod(brief)) return "";
  const l = methodLines(brief?.rules);
  return [
    ...l.fantasy.map((x) => `- the fantasy: ${x}`),
    ...l.teardown.map((x) => `- teardown of a reference game: ${x}`),
    ...l.thirty.map((x) => `- the 30-second test: ${x}`),
    ...l.kill.map((x) => `- kill if: ${x}`),
  ].join("\n");
}

/**
 * The person's playtest card (METHOD.md section 12) for a job waiting at a phase: what to play, what to watch for, how
 * to answer. Empty for a brief without the method lines.
 */
export function playtestCard(brief: Pick<Brief, "rules"> | undefined, job: string, phase: { id: string; try: string }, first: boolean): string[] {
  if (!hasMethod(brief)) return [];
  const l = methodLines(brief?.rules);
  const out = [`playtest phase ${phase.id}: play it yourself (or hand it to a newcomer and watch without helping) for 5 minutes; a bot figure is not this answer`];
  for (const f of l.fantasy) out.push(`playtest the fantasy: ${f}`);
  if (first) for (const t of l.thirty) out.push(`playtest first 30 s: ${t}`);
  out.push(`playtest promise: ${phase.try}`);
  for (const k of l.kill) out.push(`playtest kill if: ${k}`);
  out.push(`playtest then: did you want one more go? yes: foreman phase ${job} pass   no or a kill line seen: foreman phase ${job} hold --note "<the worst three things you felt, worst first; where it stopped being fun>"`);
  return out;
}

/** The critic's `kill_criteria` rubric item for a brief with KILL IF lines (undefined without them). */
export function killItem(brief: Pick<Brief, "rules"> | undefined): { id: string; text: string } | undefined {
  const kill = methodLines(brief?.rules).kill;
  if (kill.length === 0) return undefined;
  return {
    id: "kill_criteria",
    text: `The design's kill criteria, written before the build (docs/design/METHOD.md section 11): ${kill.map((k, i) => `(${i + 1}) ${k}`).join(" ")}. 1.0 when the frames show none of them happening; 0.0 when any is plainly seen (name its number and the image in \`notes\`). A line only a person playing can judge (a feeling, a wish to play again) is not scored here: say "kill line <n>: a person must judge it".`,
  };
}
