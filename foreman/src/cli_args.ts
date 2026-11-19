import { ADAPTERS, editorFieldProblem, type EditorFields } from "./events.js";

export class UsageError extends Error {}

export interface Args {
  cmd: string;
  pos: string[];
  flags: Record<string, string | true>;
}

const BOOLEAN_FLAGS = new Set(["auto-approve", "allow-edit", "no-promote", "retry-failed", "quiet", "json", "force-subscription", "help", "no-critic", "no-reference", "planner-only", "builder-only", "no-run", "no-kit-gate"]);

export function parseArgs(argv: string[]): Args {
  const pos: string[] = [];
  const flags: Record<string, string | true> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i] as string;
    if (a.startsWith("--")) {
      const eq = a.indexOf("=");
      const name = eq === -1 ? a.slice(2) : a.slice(2, eq);
      if (eq !== -1) flags[name] = a.slice(eq + 1);
      else if (BOOLEAN_FLAGS.has(name)) flags[name] = true;
      else {
        const v = argv[i + 1];
        if (v === undefined) throw new UsageError(`--${name} needs a value`);
        flags[name] = v;
        i += 1;
      }
    } else pos.push(a);
  }
  return { cmd: pos[0] ?? "help", pos: pos.slice(1), flags };
}

export const str = (a: Args, name: string): string | undefined => (typeof a.flags[name] === "string" ? (a.flags[name] as string) : undefined);
export const num = (a: Args, name: string): number | undefined => {
  const v = str(a, name);
  if (v === undefined) return undefined;
  const n = Number(v);
  if (!Number.isFinite(n)) throw new UsageError(`--${name} must be a number`);
  return n;
};

export function editorFlag<K extends keyof EditorFields>(a: Args, key: K): EditorFields[K] | undefined {
  const raw = str(a, key);
  if (raw === undefined) return undefined;
  let value: unknown;
  try { value = JSON.parse(raw); }
  catch { throw new UsageError(`--${key} needs valid JSON`); }
  const problem = editorFieldProblem(key, value);
  if (problem) throw new UsageError(`--${key}: ${problem}`);
  return value as EditorFields[K];
}

/** One "Find a place" call the editor made before Build it (foreman place's tl.place-answer/1 usage figures). */
export interface PlaceCall { adapter: (typeof ADAPTERS)[number]; model: string; durationMs: number; tokensIn?: number; tokensOut?: number }

const PLACE_CALL_KEYS = ["adapter", "model", "durationMs", "tokensIn", "tokensOut"];
const isCount = (v: unknown): v is number => typeof v === "number" && Number.isInteger(v) && v >= 0;

/** Lane editor, 19 Nov: `foreman new --place-calls <json>`: the editor's place calls, each written as a job-level
 * `builder_run` (mode generate) so `tl ledger` counts their tokens. Checked before anything is written. */
export function placeCallsFlag(a: Args): PlaceCall[] | undefined {
  const raw = str(a, "place-calls");
  if (raw === undefined) return undefined;
  let value: unknown;
  try { value = JSON.parse(raw); }
  catch { throw new UsageError("--place-calls needs valid JSON"); }
  if (!Array.isArray(value) || value.length < 1 || value.length > 20) throw new UsageError("--place-calls: a list of 1 to 20 calls");
  value.forEach((c: unknown, i) => {
    const w = `--place-calls[${i}]`;
    if (c === null || typeof c !== "object" || Array.isArray(c)) throw new UsageError(`${w}: must be an object`);
    const o = c as Record<string, unknown>;
    for (const k of Object.keys(o)) if (!PLACE_CALL_KEYS.includes(k)) throw new UsageError(`${w}: unknown key "${k}"`);
    if (!(ADAPTERS as readonly unknown[]).includes(o["adapter"])) throw new UsageError(`${w}: adapter must be one of ${ADAPTERS.join(", ")}`);
    if (typeof o["model"] !== "string" || !o["model"].trim()) throw new UsageError(`${w}: model must be a non-empty string`);
    if (!isCount(o["durationMs"])) throw new UsageError(`${w}: durationMs must be an integer >= 0`);
    for (const k of ["tokensIn", "tokensOut"]) if (k in o && !isCount(o[k])) throw new UsageError(`${w}: ${k} must be an integer >= 0`);
  });
  return value as PlaceCall[];
}
