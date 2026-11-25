// The generate-mode call with its checks and retries (moved out of designer.ts by E3g of 25 Nov 2026; designer.ts
// re-exports everything here). E3g, after lane E5's real job 3 (PROOF-E5c.md): its first two starts failed after three
// Designer attempts each, a different small check each time (a playstyle line of 14 words, "75 widths", SKIN keys),
// because each retry heard only the last attempt's problems and an answer that fixed one check broke another. Now:
//   - every failing check of an attempt is found (the content checks run even when the schema check failed);
//   - the exact fixes are made without the model (a word overflow of at most TRIM_MAX words trimmed, then the role's
//     own `exactFix`, e.g. designfix.ts: "75 widths" -> "75 body widths", a SKIN field's known spelling);
//   - a retry hears every problem of the attempt AND every problem an earlier attempt was refused for.
import type { Builder, RunResult } from "./builder/types.js";
import { schemaErrors } from "./builder/json.js";
import { lengthViolations, repairLengths, setAt, trimWords, TRIM_MAX, type LengthRule } from "./repair.js";
import { words } from "./v2.js";

export const render = (template: string, vars: Record<string, string>): string => template.replace(/\{\{(\w+)\}\}/g, (_m, k: string) => vars[k] ?? "");

export type GenerateRole = "designer" | "concept" | "design_review" | "planner" | "critic" | "placer" | "critic_compare" | "cartridge";
export interface GenerateCall {
  role: GenerateRole | `${GenerateRole}_repair`;
  attempt: number;
  prompt: string;
  result: RunResult;
  /** Validation problems found by us after the adapter said ok. */
  problems: string[];
}

export type Generated<T> = { ok: true; value: T; calls: GenerateCall[] } | { ok: false; reason: string; calls: GenerateCall[] };

/** E3g: an exact, mechanical fix of an answer (`fixed`: what was changed, one line each); undefined when nothing applies. */
export type ExactFix = (value: unknown) => { value: unknown; fixed: string[] } | undefined;

export interface GenerateOptions {
  model?: string;
  timeoutMs?: number;
  /** Total attempts when the answer does not validate. Default 2. */
  attempts?: number;
  /** L1b: word limits of the answer; an answer whose only problems are these gets ONE repair call (repair.ts). */
  limits?: LengthRule[];
  /** E3g: the role's own exact fixes, made without the model before any repair call or retry. */
  exactFix?: ExactFix;
}

/** E3g: every problem of an answer: the schema's and the content checks' (a check that cannot read the answer adds none). */
function allProblems(jsonSchema: object, check: (value: unknown) => string[], value: unknown): string[] {
  let content: string[] = [];
  try {
    content = check(value);
  } catch {
    /* an answer the schema refused may not have the shape the checks read */
  }
  return [...new Set([...schemaErrors(jsonSchema, value), ...content])];
}

/** E3g: the answer with its exact fixes made (small word overflows trimmed, then the role's own), or undefined. */
export function exactFixed(answer: unknown, opts: Pick<GenerateOptions, "limits" | "exactFix">): { value: unknown; fixed: string[] } | undefined {
  let value = structuredClone(answer);
  const fixed: string[] = [];
  for (const v of opts.limits !== undefined ? lengthViolations(value, opts.limits) : []) {
    if (v.words - v.max > TRIM_MAX) continue;
    const t = trimWords(v.text, v.max);
    setAt(value, v.path, t);
    fixed.push(`${v.path} trimmed from ${v.words} to ${words(t)} words (limit ${v.max}): "${t}"`);
  }
  const own = opts.exactFix?.(value);
  if (own !== undefined) {
    value = own.value;
    fixed.push(...own.fixed);
  }
  return fixed.length > 0 ? { value, fixed } : undefined;
}

/** E3g: the retry's feedback: every problem of the last attempt, and the earlier attempts' problems to keep fixed. */
export function retryFeedback(problems: string[], earlier: string[]): string {
  const old = earlier.filter((p) => !problems.includes(p));
  return [
    "",
    "# Your previous answer was rejected",
    ...problems.map((p) => `- ${p}`),
    ...(old.length > 0 ? ["# Earlier answers were refused for these too: your answer must pass them as well", ...old.map((p) => `- ${p}`)] : []),
    "Fix EVERY problem above in this one answer: each is its own check, and an answer that fixes one and breaks another is refused again.",
    "Answer again with one valid JSON object.",
  ].join("\n");
}

export async function generate<T>(
  builder: Builder,
  role: GenerateRole,
  template: string,
  vars: Record<string, string>,
  jsonSchema: object,
  check: (value: unknown) => string[],
  opts: GenerateOptions,
  mode: "generate" | "readonly-scan" = "generate",
  cwd = "",
  images: string[] = [],
): Promise<Generated<T>> {
  const calls: GenerateCall[] = [];
  let feedback = "";
  const refused: string[] = [];
  let refusedLast: string[] = [];
  const attempts = opts.attempts ?? 2;
  for (let attempt = 1; attempt <= attempts; attempt++) {
    const text = render(template, { ...vars, schema: JSON.stringify(jsonSchema, null, 1), feedback });
    const result = await builder.run({
      prompt: text,
      mode,
      cwd,
      schema: jsonSchema,
      timeoutMs: opts.timeoutMs ?? 10 * 60_000,
      ...(opts.model ? { model: opts.model } : {}),
      ...(images.length > 0 ? { images } : {}),
      meta: { role },
    });
    let problems: string[] = [];
    if (result.outcome === "ok") {
      // The adapter validated against the schema; we do it again here because acceptance is ours to decide.
      problems = allProblems(jsonSchema, check, result.json);
      if (problems.length === 0) {
        calls.push({ role, attempt, prompt: text, result, problems });
        return { ok: true, value: result.json as T, calls };
      }
      let answer: unknown = result.json;
      const fx = exactFixed(answer, opts);
      if (fx !== undefined) {
        const left = allProblems(jsonSchema, check, fx.value);
        calls.push({ role, attempt, prompt: text, result, problems: [...problems, ...fx.fixed.map((f) => `[foreman] exact fix: ${f}`)] });
        if (left.length === 0) return { ok: true, value: fx.value as T, calls };
        answer = fx.value;
        problems = left;
      } else calls.push({ role, attempt, prompt: text, result, problems });
      if (opts.limits && !calls.some((c) => c.role === `${role}_repair`)) {
        const r = await repairLengths<T>(builder, role, answer, opts.limits, jsonSchema, check, { ...(opts.model ? { model: opts.model } : {}), timeoutMs: opts.timeoutMs ?? 10 * 60_000 });
        if (r.result) calls.push({ role: `${role}_repair`, attempt, prompt: r.prompt ?? "", result: r.result, problems: r.problems });
        if (r.value !== undefined) return { ok: true, value: r.value, calls };
      }
    } else {
      calls.push({ role, attempt, prompt: text, result, problems });
      // Only an answer that came back but did not validate is worth asking again; a timeout or refusal is not.
      if (!(result.outcome === "error" && (result.error?.kind === "schema" || result.error?.kind === "parse"))) {
        return { ok: false, reason: `${role}: builder ${result.outcome}: ${result.error?.message ?? "no detail"}`, calls };
      }
      // E3g: an answer the adapter refused for its schema is still read by the content checks: all its problems at once
      problems = result.error.kind === "schema" && result.json !== undefined ? allProblems(jsonSchema, check, result.json) : [result.error.message];
    }
    feedback = retryFeedback(problems, refused);
    for (const p of problems) if (!refused.includes(p)) refused.push(p);
    refusedLast = problems;
  }
  // the last call's problems (a repair call's own), else what the last attempt still failed after its exact fixes
  const last = calls[calls.length - 1];
  const lastProblems = last?.role === role ? refusedLast : (last?.problems ?? []);
  return { ok: false, reason: `${role}: answer still invalid after ${attempts} attempts: ${(lastProblems.length ? lastProblems : [last?.result.error?.message ?? "invalid"]).join("; ")}`, calls };
}
