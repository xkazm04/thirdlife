// H1h item 6 (lane G5, bumper karts; d25-kart job events 14, 214-216): the plan's tofu bound on possession (240 to 600
// frames, from the hockey card) was applied to a ball the person had chosen on a card to be "Never Held" ("never carry
// it"). The builder asked whether to keep the bound; the person answered "C. Keep the ball fully loose ... Drop the
// 4-second possession target". The builder did, and the Foreman threw the round away for that same bound. Three critic
// revises of the bump (core r8 to r10) were lost the same way. A person's card choice or direct answer lifts a plan
// bound: the row is not judged (acceptance, milestone look), and the Foreman says so in a note, once per round.
import type { JobEvent } from "./events.js";
import type { JobState } from "./joblog.js";
import type { TofuMetric } from "./tofu.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";

/** The start of the Foreman's note when a person lifted a plan bound. */
export const LIFTED = `${FOREMAN_NOTE}plan bound lifted`;
/** Words that drop a target or bound. */
const DROP = /\b(drop\w*|lift\w*|remov\w*|ignor\w*|without)\b[^.?]{0,60}\b(target|bound|check|limit|figure)s?\b|\b(target|bound|check|limit)s?\b[^.?]{0,40}\b(dropped|lifted|removed|ignored|does not matter|doesn'?t matter)\b/i;
/** Words of a metric's id that say nothing about what it measures. */
const GENERIC = new Set(["median", "share", "max", "min", "mean", "rate", "count", "frames", "per", "the"]);
/** A card choice that makes a ball nobody holds lifts the possession rows. */
const CARD_LIFTS: { re: RegExp; ids: RegExp; what: string }[] = [
  { re: /\bnever (held|hold|carr\w*)\b|\brolls? free\b|\bnobody holds\b|\bno one holds\b|\bloose ball\b/i, ids: /possession|carry|carried|hold/, what: "a ball nobody holds" },
];

/** The words of a metric that name what it measures (possession_median_f -> possession). */
export const metricWords = (id: string): string[] => id.toLowerCase().split(/[^a-z]+/).filter((w) => w.length > 2 && !GENERIC.has(w));

/** The option a letter answer picks ("C." -> the question's "(C) ..." words), or "". */
function optionOf(question: string, answer: string): string {
  const letter = /^\s*\(?([A-Fa-f])\b[).:]?/.exec(answer)?.[1]?.toUpperCase();
  if (letter === undefined) return "";
  return new RegExp(`\\(${letter}\\)\\s*([^?]*?)(?=,?\\s*(?:or\\s*)?\\([A-F]\\)|\\?|$)`).exec(question)?.[1] ?? "";
}

/** The plan rows a person lifted, with the words why (metric id -> why). */
export function liftedBounds(s: Pick<JobState, "brief" | "reactions">, events: readonly JobEvent[], rows: readonly TofuMetric[]): Map<string, string> {
  const out = new Map<string, string>();
  const questions = new Map<string, string>();
  for (const e of events ?? []) {
    if (e.type === "question") questions.set(e.package, e.text);
    if (e.type !== "answer") continue;
    const q = questions.get(e.package) ?? "";
    const said = `${optionOf(q, e.text)} ${e.text}`;
    if (!DROP.test(said)) continue;
    for (const r of rows) if (!out.has(r.id) && metricWords(r.id).some((w) => said.toLowerCase().includes(w))) out.set(r.id, `your answer to ${e.package}'s question (event ${e.seq}): "${clip(e.text, 200)}"`);
  }
  for (const a of s.brief?.aspects ?? []) {
    const r = s.reactions?.[a.id];
    if (r === undefined || r.choice === "drop") continue;
    const alt = a.alternatives.find((x) => x.id === r.choice);
    const words = `${alt !== undefined ? `${alt.title} ${alt.line}` : ""} ${r.note ?? ""}`;
    for (const l of CARD_LIFTS) {
      if (!l.re.test(words)) continue;
      for (const row of rows) if (!out.has(row.id) && l.ids.test(row.id)) out.set(row.id, `your card "${alt?.title ?? a.title}" (${l.what}${r.note !== undefined ? `: "${clip(r.note, 160)}"` : ""})`);
    }
  }
  return out;
}

/** The rows still judged, and the lifted ones with why. */
export function withLifts(s: Pick<JobState, "brief" | "reactions">, events: readonly JobEvent[], rows: TofuMetric[]): { rows: TofuMetric[]; lifted: Map<string, string> } {
  const lifted = liftedBounds(s, events, rows);
  return { rows: rows.filter((r) => !lifted.has(r.id)), lifted };
}

/** The Foreman's note for lifted rows ("" when none): which bound, on whose word. */
export function liftedNote(lifted: Map<string, string>, rows: readonly TofuMetric[]): string {
  if (lifted.size === 0) return "";
  const parts = [...lifted].map(([id, why]) => {
    const r = rows.find((x) => x.id === id);
    const bound = r === undefined ? "" : ` (the plan's bound: ${r.min !== undefined ? `>= ${r.min}` : ""}${r.min !== undefined && r.max !== undefined ? " and " : ""}${r.max !== undefined ? `<= ${r.max}` : ""})`;
    return `${id}${bound}, on ${why}`;
  });
  return `${LIFTED}, not judged: ${parts.join("; ")}`;
}
