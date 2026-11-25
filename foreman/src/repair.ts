// L1b of 21 Nov (PRIORITY 0 from the Director): a word limit must never kill a good design. The real crazy proof job
// fight-colosseum-20261121-2 failed after 3 attempts on "design playstyle 'murmillo' line has 17 words; at most 12":
// a rich answer sent back whole keeps overshooting somewhere. When the ONLY problems of an answer are length limits,
// one short repair call lists each offending field with its text, its count and its limit, asks for those fields
// alone, and the Foreman merges them back; everything else stays verbatim. A field still over after the repair is cut
// at its limit (said in the call's problems). Content errors still go through the usual attempts.
import type { Builder, RunResult } from "./builder/types.js";
import { schemaErrors } from "./builder/json.js";
import { LIMITS, words } from "./v2.js";
import { ROOM_LIMITS } from "./room_wire.js";

/** A length rule: a path pattern over the answer (`[*]` for any index) and the most words its string may have. */
export interface LengthRule {
  path: string;
  max: number;
}

const T = ROOM_LIMITS.text;
/** The Designer's answer (design step): the v2 brief fields and the design doc. */
export const BRIEF_LIMITS: LengthRule[] = [
  { path: "brief.pitch", max: LIMITS.pitch },
  { path: "brief.aspects[*].title", max: LIMITS.title },
  { path: "brief.aspects[*].line", max: LIMITS.line },
  { path: "brief.aspects[*].detail", max: LIMITS.detail },
  { path: "brief.aspects[*].alternatives[*].title", max: LIMITS.title },
  { path: "brief.aspects[*].alternatives[*].line", max: LIMITS.line },
  ...["pillars[*].line", "pillars[*].rules_out", "verbs[*].input", "verbs[*].cancel", "loops.s3", "loops.s30", "loops.m3", "context[*]", "skill.floor", "skill.ceiling[*]", "feel.knockback", "feel.reaction", "feel.whiff", "feel.shake", "feel.camera", "clips[*].moment", "first_minute", "fail_state", "out_of_scope[*]"].map((p) => ({ path: `brief.design.${p}`, max: T })),
  { path: "brief.design.playstyles[*].title", max: ROOM_LIMITS.playstyleTitle },
  { path: "brief.design.playstyles[*].line", max: ROOM_LIMITS.playstyleLine },
];
/** The concept step's answer. */
export const CONCEPT_LIMITS: LengthRule[] = [
  { path: "concept.candidates[*].pitch", max: ROOM_LIMITS.pitch },
  { path: "concept.why", max: ROOM_LIMITS.why },
  { path: "concept.hook", max: ROOM_LIMITS.hook },
  { path: "concept.anchor", max: ROOM_LIMITS.anchor },
  { path: "concept.references[*].borrow", max: ROOM_LIMITS.borrow },
  { path: "concept.template.reference", max: ROOM_LIMITS.reference },
  { path: "concept.template.copies[*]", max: ROOM_LIMITS.copy },
];
/** The review step's answer. */
export const REVIEW_LIMITS: LengthRule[] = [{ path: "notes", max: ROOM_LIMITS.notes }];

export interface Violation {
  path: string;
  text: string;
  words: number;
  max: number;
}

/** Every string leaf of `value` with its concrete path ("a.b[2].c"). */
function leaves(value: unknown, at = ""): { path: string; text: string }[] {
  if (typeof value === "string") return [{ path: at, text: value }];
  if (Array.isArray(value)) return value.flatMap((v, i) => leaves(v, `${at}[${i}]`));
  if (value !== null && typeof value === "object") return Object.entries(value).flatMap(([k, v]) => leaves(v, at === "" ? k : `${at}.${k}`));
  return [];
}

/** The strings of `value` over their rule's limit. */
export function lengthViolations(value: unknown, rules: LengthRule[]): Violation[] {
  const out: Violation[] = [];
  for (const l of leaves(value)) {
    const pattern = l.path.replace(/\[\d+\]/g, "[*]");
    const rule = rules.find((r) => r.path === pattern);
    if (rule && words(l.text) > rule.max) out.push({ path: l.path, text: l.text, words: words(l.text), max: rule.max });
  }
  return out;
}

/** Sets the string at a concrete path (the path came from `leaves`, so every step exists). */
export function setAt(value: unknown, at: string, text: string): void {
  const steps = at.match(/[^.[\]]+/g) ?? [];
  let cur = value as Record<string, unknown>;
  for (const s of steps.slice(0, -1)) cur = cur[s] as Record<string, unknown>;
  cur[steps[steps.length - 1] as string] = text;
}

/** The first `max` words of a text, as a person counts them. */
export const cut = (text: string, max: number): string => text.trim().split(/\s+/).slice(0, max).join(" ").replace(/[,;:]$/, "");

/** E3g: the most words over its limit that a text is trimmed by without the model (generate.ts exactFixed). */
export const TRIM_MAX = 3;
const FILLER = new Set(["the", "a", "an"]);
const LOOSE_END = new Set(["the", "a", "an", "and", "or", "but", "to", "of", "into", "onto", "in", "on", "at", "for", "with", "your", "their", "its", "then"]);

/**
 * E3g: a text trimmed to `max` words without the model: articles go first (from the end), then the tail is cut, and a
 * cut never ends on a joining word ("into", "and"). The final full stop is kept.
 */
export function trimWords(text: string, max: number): string {
  const stop = /[.!?]$/.exec(text.trim())?.[0] ?? "";
  let w = text.trim().split(/\s+/);
  for (let i = w.length - 1; i > 0 && w.length > max; i--) if (FILLER.has((w[i] as string).toLowerCase())) w.splice(i, 1);
  if (w.length > max) {
    w = w.slice(0, max);
    while (w.length > 1 && LOOSE_END.has((w[w.length - 1] as string).toLowerCase().replace(/[^a-z]/g, ""))) w.pop();
  }
  const out = w.join(" ").replace(/[,;:]$/, "");
  return /[.!?]$/.test(out) ? out : `${out}${stop}`;
}

export interface Repaired<T> {
  /** The answer with the offending fields replaced (only set when it now passes every check). */
  value?: T;
  /** The repair call, when one was made (it goes into the log like any generate call). */
  result?: RunResult;
  prompt?: string;
  /** What was cut mechanically after the repair, and what still fails (content problems). */
  problems: string[];
}

/**
 * When every problem of `answer` is a length limit (proved by cutting each offending field to its limit: then the
 * checks pass), ONE repair call shortens exactly those fields; anything still over is cut. Returns `value` only when
 * the merged answer passes the schema and `check`. With content problems it returns no value and makes no call.
 */
export async function repairLengths<T>(
  builder: Builder,
  role: string,
  answer: unknown,
  rules: LengthRule[],
  schema: object,
  check: (value: unknown) => string[],
  run: { model?: string; timeoutMs: number },
): Promise<Repaired<T>> {
  const bad = lengthViolations(answer, rules);
  if (bad.length === 0) return { problems: [] };
  const trimmed = structuredClone(answer);
  for (const v of bad) setAt(trimmed, v.path, cut(v.text, v.max));
  if (schemaErrors(schema, trimmed).length > 0 || check(trimmed).length > 0) return { problems: [] }; // content errors too: the usual attempts
  const prompt = [
    "Some text fields of your answer are over their word limit. Everything else in it is accepted and kept as it is.",
    "Rewrite ONLY these fields, each to at most its limit (aim two words under it), keeping its meaning, its numbers and its names. A word is whatever stands between two spaces.",
    ...bad.map((v) => `- ${v.path} (${v.words} words, limit ${v.max}): ${JSON.stringify(v.text)}`),
    "Answer with ONE JSON object and nothing else: {\"fixes\": [{\"path\": \"<the path above>\", \"text\": \"<the shorter text>\"}]}, one entry per field above.",
  ].join("\n");
  const fixSchema = {
    type: "object",
    additionalProperties: false,
    required: ["fixes"],
    properties: { fixes: { type: "array", items: { type: "object", additionalProperties: false, required: ["path", "text"], properties: { path: { enum: bad.map((v) => v.path) }, text: { type: "string", minLength: 1 } } } } },
  };
  const result = await builder.run({ prompt, mode: "generate", cwd: "", schema: fixSchema, timeoutMs: Math.min(run.timeoutMs, 5 * 60_000), ...(run.model ? { model: run.model } : {}), meta: { role: `${role}_repair` } });
  const fixes = new Map<string, string>();
  if (result.outcome === "ok" && schemaErrors(fixSchema, result.json).length === 0) for (const f of (result.json as { fixes: { path: string; text: string }[] }).fixes) fixes.set(f.path, f.text);
  const merged = structuredClone(answer);
  const problems: string[] = [];
  for (const v of bad) {
    const fixed = fixes.get(v.path);
    if (fixed !== undefined && words(fixed) <= v.max) setAt(merged, v.path, fixed);
    else {
      setAt(merged, v.path, cut(fixed ?? v.text, v.max));
      problems.push(`[foreman] ${v.path} was still ${words(fixed ?? v.text)} words after the repair: cut to its first ${v.max}`);
    }
  }
  const left = [...schemaErrors(schema, merged), ...check(merged)];
  return left.length === 0 ? { value: merged as T, result, prompt, problems } : { result, prompt, problems: [...problems, ...left] };
}
