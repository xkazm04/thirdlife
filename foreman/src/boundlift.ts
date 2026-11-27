// H1h item 6 (lane G5, bumper karts; d25-kart job events 14, 214-216): the plan's tofu bound on possession (240 to 600
// frames, from the hockey card) was applied to a ball the person had chosen on a card to be "Never Held" ("never carry
// it"). The builder asked whether to keep the bound; the person answered "C. Keep the ball fully loose ... Drop the
// 4-second possession target". The builder did, and the Foreman threw the round away for that same bound. Three critic
// revises of the bump (core r8 to r10) were lost the same way. A person's card choice or direct answer lifts a plan
// bound: the row is not judged (acceptance, milestone look), and the Foreman says so in a note, once per round.
import type { JobEvent } from "./events.js";
import type { JobState } from "./joblog.js";
import { readTofuMetrics, type TofuMetric } from "./tofu.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";
import { ruleLinesSince } from "./rulelines.js";

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
    // H1i (the Director): the card names the bounds its choice lifts (`lifts`, written by the Designer); the words below
    // are the fallback for a card that names none
    if (alt?.lifts !== undefined) {
      for (const row of rows) if (!out.has(row.id) && alt.lifts.includes(row.id)) out.set(row.id, `your card "${alt.title}" (it lifts ${row.id})`);
      continue;
    }
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

// ---------- N27 (night of 27 Nov, lane T): a person's change is built as asked; the balance it moves is a note ----------
// On 25 Nov the tofu bounds bent four games away from what the person asked: critic revises that did what was asked were
// thrown away over a bound (G11 r5 and r9, G5 r8-r10), a builder added a hidden comeback multiplier to pass close_rounds
// (G19), and a camera-only change failed on balance (G19 core r11). From now on, in a change since the last promotion:
//   - a PLAY change (an ability, a rule, a speed, anything but the view, the screen or the look) moves the balance rows
//     (who wins and how close) as the person asked: they are not judged, and when one leaves its bound the person gets a
//     plain-words note (BALANCE_MOVED: "the crew side now wins 3 of 3 test rounds; say 'make it fairer' to tune it");
//   - a VIEW change (camera, HUD, score plate, buttons, hints, with sky and colours beside them) skips the balance rows;
//   - a LOOK change (colours, costumes, scenery, with no play or view words) and a FAIR change ("make it fairer") keep
//     the balance rows as a guard;
//   - every other row (feedback within 3 f, tells, idle rivals, the verbs pressed, contacts, spacing) still guards,
//     unless the person's words name what it measures (a launch or a knockdown for idle rivals, a faster move for tells);
//   - a guarding row that was already outside its bound before the change is not this change's regression: not judged.
// The tofu gate (tofugate.ts), the milestone look (quality.ts) and the card's hand checks (handcheck.ts) read this.

/** The start of the Foreman's note to the person when their change moved a balance figure (Create shows its first line). */
export const BALANCE_MOVED = `${FOREMAN_NOTE}balance moved by your change`;
/** The start of the Foreman's note when a change to the view or the screen only was not judged on balance. */
export const BALANCE_SKIPPED = `${FOREMAN_NOTE}balance not judged`;

/** The rows that say who wins and how close: a person's play change may move them. */
export const BALANCE_ROWS = new Set(["skill_spread", "skill_variants", "lead_change_share", "close_rounds", "pressure_waves", "possession_median_f"]);

/** Rows outside the balance family that a person's words touch when they name what the row measures. */
const TOUCH: { ids: RegExp; words: RegExp }[] = [
  { ids: /^idle_max_f$/, words: /\b(launch\w*|tumbl\w*|knock\w*|flatten\w*|floor(s|ed|ing)?|stun\w*|freez\w*|frozen|ragdoll\w*|fl(y|ies|ying|ung|ew)|fall\w*|fell|topple\w*|dizzy|daze\w*|flip\w*|bowl\w* over)\b/i },
  // T2 (J2's copy, core r16: "hold F to raise it, release to swing" refused on tells 2 < 3): a new attack move with its
  // own wind-up is one the frozen tofu bot does not count among its tells, so the count moves with the person's words
  { ids: /^tell(s|_min_f)$/, words: /\b(fast\w*|quick\w*|instant\w*|sudden\w*|surprise|no warning|snap\w*|dash\w*|lunge\w*|rush\w*|charg\w*|swing\w*|wind[- ]?up\w*|rais\w*|slam\w*|smash\w*|hammer\w*|leap\w*|dunk\w*|pounc\w*)\b/i },
  { ids: /^(scrum|overlap)_share$/, words: /\b(crowd\w*|pile\w*|clump\w*|swarm\w*|gang\w*|all at once|huge|giant|bigger|pull\w*|magnet\w*|tackl\w*|body ?check\w*)\b/i },
];

const VIEW_WORDS = /\b(camera|cam|view|zoom\w*|angle|screen|hud|score ?plate|scoreboard|plate|buttons?|keys?|hints?|labels?|captions?|text|font|minimap|icons?|bars?|meters?|title|menu|overlay|ui|on screen)\b/i;
const LOOK_WORDS = /\b(colou?r\w*|paint\w*|sky|sunset|sunrise|noon|night|dusk|dawn|lighting|glow\w*|shin\w*|gold\w*|blue|red|green|teal|white|black|yellow|orange|purple|pink|grey|gray|costume\w*|caps?|hats?|jackets?|cloth\w*|skins?|textures?|looks?|style|banners?|flags?|decor\w*|scenery|sea|harbour|harbor|trees?|buildings?|sounds?|music|sparks?|dust|particles?|trail\w*)\b/i;
const PLAY_WORDS = /\b(abilit\w*|power\w*|jump\w*|dunk\w*|hammer\w*|swing\w*|charg\w*|dash\w*|shoot\w*|shots?|slam\w*|hit\w*|bash\w*|launch\w*|knock\w*|tackl\w*|block\w*|attack\w*|damage\w*|strong\w*|weak\w*|fast\w*|slow\w*|speed\w*|heav\w*|harder|easier|rivals?|bots?|ai|opponents?|enem\w*|rules?|scor\w*|goals?|points?|win\w*|los\w*|rounds?|health|stamina|cooldown\w*|mov\w*|run\w*|boost\w*|sprint\w*|pass\w*|kick\w*|throw\w*|catch\w*|parr\w*|dodg\w*|roll\w*|flip\w*|loop\w*|fire\w*|bomb\w*|tumbl\w*|push\w*|shov\w*|steal\w*|grab\w*|hold\w*|press\w*|releas\w*|smaller|size|longer|shorter|clock|timer|lives|crazy|stun\w*|spin\w*|aerial\w*|double)\b/i;
/** Words that change what a body does even inside a clause about the view ("a camera kick when the hammer launches a robot"). */
const STRONG_PLAY = /\b(abilit\w*|power\w*|jump\w*|dunk\w*|hammer\w*|swing\w*|charg\w*|dash\w*|launch\w*|knock\w*|tackl\w*|damage\w*|strong\w*|weak\w*|faster|slower|speed\w*|harder|easier|tumbl\w*|shov\w*|push\w*|steal\w*|throw\w*|slam\w*|flip\w*|boost\w*|sprint\w*|cooldown\w*|rules?|aerial\w*|stun\w*)\b/i;
// "unfair on purpose" asks for a one-sided game: a play change, not a fairness ask (the second real job of lane T)
// D27 item 10 (S35's kart copy s35-3A, events 1295-1442: "Take out two things the old balance check added ..." read as a
// fairness ask, the tofu gate refused the clean-up three times, and teams changed the bots' shooting unasked; 125 min,
// 5.89M tokens): "balance" counts only as an ask (balance it, rebalance the teams, more balanced), never as the name of a
// check, a gate or a figure.
const FAIR_WORDS = /\b(fair(er|ness)?|(re)?balance (it|them|this|that|things|out|the (game|teams?|sides?|match(es)?|rounds?|bots?|rivals?|players?))|(more|better) balanced|balanced (game|match|teams|sides)|more even|even(ly)? matched|closer (game|match|rounds?)|too (hard|easy|strong|weak)|overpowered|nerf\w*)\b/i;

export type ChangeKind = "play" | "view" | "look" | "fair";

/** What a person's change words ask for, clause by clause (sentences and semicolons). */
export function changeKind(text: string): ChangeKind {
  if (FAIR_WORDS.test(text)) return "fair";
  const clauses = text.split(/[.;!?\n]+/).map((c) => c.trim()).filter(Boolean);
  const kinds = clauses.map((c) => (VIEW_WORDS.test(c) ? (STRONG_PLAY.test(c) ? "play" : "view") : PLAY_WORDS.test(c) ? "play" : LOOK_WORDS.test(c) ? "look" : "neutral"));
  if (kinds.includes("play")) return "play";
  if (kinds.includes("view")) return "view";
  if (kinds.includes("look")) return "look";
  return "play"; // words the Foreman cannot place ("make it more fun") are a play change: built as asked, with the note
}

/** The person's change in flight: every change request since the last promotion, in their words (undefined before a first version). */
export function askedChange(events: readonly JobEvent[] | undefined): { seq: number; text: string; kind: ChangeKind } | undefined {
  let last = -1;
  for (const e of events ?? []) if (e.type === "promoted") last = e.seq;
  if (last < 0) return undefined; // the first build: the tofu stage judges as before
  const asks = (events ?? []).flatMap((e) => (e.type === "change_requested" && e.seq > last && !e.text.startsWith(FOREMAN_NOTE) ? [{ seq: e.seq, text: e.text }] : []));
  const first = asks[0];
  if (first === undefined) return undefined;
  const text = asks.map((e) => e.text).join(" / ");
  const kind = changeKind(text);
  // D27b item 31 (J2nd's biplane copy, events 994-1000): a builder's RULE: line makes a view change a play change
  return { seq: first.seq, text, kind: kind === "view" && ruleLinesSince(events, first.seq).length > 0 ? "play" : kind };
}

/** Is `v` inside the row's bound (absent is never inside)? */
export const insideBound = (r: Pick<TofuMetric, "min" | "max">, v: unknown): boolean => typeof v === "number" && Number.isFinite(v) && (r.min === undefined || v >= r.min) && (r.max === undefined || v <= r.max);

/** How a row is treated in a person's change. */
export type RowCall = "judged" | "moved" | "skipped" | "before";

/** One row's treatment in a change of `kind` (words: the person's), from whether it was outside its bound before the change. */
export function rowCall(kind: ChangeKind, id: string, words: string, failedBefore: boolean): RowCall {
  // T2 (J2's copy, event 1146: "close test rounds: now 0, was 0"): a row already outside before the change was not moved
  // by it; no note says the person's change did it
  if (failedBefore) return "before";
  if (BALANCE_ROWS.has(id)) {
    if (kind === "play") return "moved";
    if (kind === "view") return "skipped";
  } else if (kind !== "fair" && TOUCH.some((t) => t.ids.test(id) && t.words.test(words))) return "moved";
  return "judged";
}

/** The rows of a person's change: those still judged, and the moved, skipped and already-failing ones outside their bounds now. */
export function splitByChange(asked: { text: string; kind: ChangeKind }, rows: TofuMetric[], now: Record<string, unknown> | undefined, before: Record<string, unknown> | undefined): { judged: TofuMetric[]; moved: TofuMetric[]; skipped: TofuMetric[]; before: TofuMetric[] } {
  const out = { judged: [] as TofuMetric[], moved: [] as TofuMetric[], skipped: [] as TofuMetric[], before: [] as TofuMetric[] };
  for (const r of rows) {
    const call = rowCall(asked.kind, r.id, asked.text, before !== undefined && !insideBound(r, before[r.id]));
    if (call === "judged") out.judged.push(r);
    else if (!insideBound(r, now?.[r.id])) out[call].push(r);
  }
  return out;
}

const PLAIN: Record<string, string> = {
  skill_spread: "how much the timing of the core move matters",
  skill_variants: "ways of the core move that work",
  lead_change_share: "the share of test rounds where the lead changes hands",
  close_rounds: "close test rounds",
  pressure_waves: "waves of rival pressure",
  possession_median_f: "frames a side keeps the ball",
  idle_max_f: "the longest a rival stands doing nothing, in frames",
  tell_min_f: "the shortest warning before a rival's attack, in frames",
  tells: "warned rival attacks",
  scrum_share: "the share of time in a crowd round the ball",
  overlap_share: "the share of time bodies overlap",
};
const fig = (v: unknown): string => (typeof v === "number" && Number.isFinite(v) ? String(Math.round(v * 100) / 100) : "not measured");
const want = (r: Pick<TofuMetric, "min" | "max">): string => (r.min !== undefined && r.max !== undefined ? `${r.min} to ${r.max}` : r.min !== undefined ? `${r.min} or more` : `${r.max} or less`);

/** "the crew side now wins 3 of 3 of the Foreman's test rounds (was 2 of 3)" from a tofu bot's `rounds` [{winner}], or "". */
export function winsLine(now: Record<string, unknown> | undefined, before: Record<string, unknown> | undefined): string {
  const tally = (m: Record<string, unknown> | undefined): { top: string; n: number; of: number; by: Map<string, number> } | undefined => {
    const raw = m?.["raw"] !== null && typeof m?.["raw"] === "object" ? (m?.["raw"] as Record<string, unknown>) : undefined;
    const list = Array.isArray(m?.["rounds"]) ? m?.["rounds"] : raw?.["rounds"]; // G19's bot keeps them under metrics.raw
    const rs = Array.isArray(list) ? (list as unknown[]) : [];
    const by = new Map<string, number>();
    for (const r of rs) {
      const w = r !== null && typeof r === "object" ? (r as Record<string, unknown>)["winner"] : undefined;
      if (typeof w === "string" && w !== "") by.set(w, (by.get(w) ?? 0) + 1);
    }
    const best = [...by].sort((a, b) => b[1] - a[1])[0];
    return best === undefined ? undefined : { top: best[0], n: best[1], of: rs.length, by };
  };
  const a = tally(now);
  if (a === undefined) return "";
  const b = tally(before);
  return `the ${a.top} side now wins ${a.n} of ${a.of} of the Foreman's test rounds${b === undefined ? "" : ` (was ${b.by.get(a.top) ?? 0} of ${b.of})`}`;
}

/** The person's note for rows a play change moved out of their bounds: a first line for Create, then the figures. */
export function balanceMovedNote(moved: TofuMetric[], now: Record<string, unknown> | undefined, before: Record<string, unknown> | undefined, test: string): string {
  const wins = winsLine(now, before);
  const first = moved[0];
  const lead = wins !== "" || first === undefined ? wins : `${PLAIN[first.id] ?? first.id}: now ${fig(now?.[first.id])}${before !== undefined ? `, was ${fig(before[first.id])}` : ""}`;
  const figures = moved.map((r) => `${r.id} ${fig(now?.[r.id])}${before !== undefined ? ` (was ${fig(before[r.id])})` : ""}, the Foreman's bound ${want(r)}`).join("; ");
  return `${BALANCE_MOVED}: built as you asked; ${lead}. Say "make it fairer" to tune it.\nfigures (${test}, not judged in this change): ${figures}`;
}

/** The note for balance rows a view-only change was not judged on. */
export function balanceSkippedNote(skipped: TofuMetric[], now: Record<string, unknown> | undefined, test: string): string {
  return `${BALANCE_SKIPPED}: a change to the view or the screen only; ${test} figures outside their bounds, not judged: ${skipped.map((r) => `${r.id} ${fig(now?.[r.id])} (bound ${want(r)})`).join("; ")}`;
}

/** The note for guarding rows that were outside their bounds before this change too. */
export function alreadyOutNote(rows: TofuMetric[], before: Record<string, unknown> | undefined): string {
  return `${FOREMAN_NOTE}already outside before your change, not judged as its regression: ${rows.map((r) => `${r.id} (was ${fig(before?.[r.id])}, bound ${want(r)})`).join("; ")}`;
}

/** The person's note for a hand check a play change moved out of the card's bound. */
export function handMovedNote(hand: string, wins: number, seeds: number, before: { wins: number; seeds: number } | undefined, bound: string): string {
  return `${BALANCE_MOVED}: built as you asked; a ${hand} player now wins ${wins} of ${seeds}${before !== undefined ? ` (was ${before.wins} of ${before.seeds})` : ""}. Say "make it fairer" to tune it.\nfigures (the card's ${hand} hand check, not judged in this change): ${wins} of ${seeds} wins, the card's bound ${bound}`;
}

/** The rows a look judges in a person's change (all of them before a first version): the rows the change moved or skipped are not judged. */
export function rowsForChange(jobDir: string, events: readonly JobEvent[], rows: TofuMetric[], now: Record<string, unknown> | undefined, test: string): TofuMetric[] {
  const asked = askedChange(events);
  if (asked === undefined) return rows;
  const before = readTofuMetrics(jobDir, events.filter((e) => e.seq < asked.seq), test).metrics;
  return splitByChange(asked, rows, now, before).judged;
}

/**
 * D27 item 6: the balance lines of a change, one per thing they are about (who wins the test rounds, a hand check's wins,
 * how long matches run): the newest line of each, in the order the things were first told. Before, only the newest line
 * of all was shown, so "matches now run longer" was lost behind a later hand-check line (lane T2's robot job).
 */
export function balanceLines(lines: readonly string[]): string[] {
  const newest = new Map<string, string>();
  for (const l of lines) {
    const key = l.split(" now ")[0] as string;
    newest.delete(key);
    newest.set(key, l);
  }
  const order = [...new Set(lines.map((l) => l.split(" now ")[0] as string))];
  return order.map((k) => newest.get(k) as string);
}
