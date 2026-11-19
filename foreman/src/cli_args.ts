import { editorFieldProblem, type EditorFields } from "./events.js";

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
