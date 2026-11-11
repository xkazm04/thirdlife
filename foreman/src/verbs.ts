// The runner's verbs and options, read from the engine: <engine>/kernel/runner/verbs.json (tl.verbs/1).
// The Foreman keeps no copy of this list. A missing or unreadable file is an error, never a silent fallback.
import fs from "node:fs";
import path from "node:path";
import type { RunnerLocation } from "./builder/allowlist.js";
import { schemaErrors } from "./builder/json.js";
import { FAKE_RUNNER, PKG_ROOT, stripBom, toPosix } from "./paths.js";

export interface VerbOption {
  type: string;
  required?: boolean;
  default?: unknown;
}
export interface VerbSpec {
  level: string;
  options: Record<string, VerbOption>;
}
export interface RunnerVerbs {
  schema: "tl.verbs/1";
  /** The file this list was read from (forward slashes). */
  source: string;
  verbs: Record<string, VerbSpec>;
}

export class VerbsError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "VerbsError";
  }
}

export const VERBS_FILE = "kernel/runner/verbs.json";
/** The verbs file of the bundled fake runner: the fake engine's own list (the fake runner reads the same file). */
export const FAKE_VERBS_FILE = path.join(PKG_ROOT, "fixtures", "engine", "kernel", "runner", "verbs.json");

const verbsSchema = {
  type: "object",
  required: ["schema", "verbs"],
  properties: {
    schema: { const: "tl.verbs/1" },
    verbs: {
      type: "object",
      minProperties: 1,
      additionalProperties: {
        type: "object",
        required: ["level", "options"],
        properties: {
          level: { type: "string" },
          options: {
            type: "object",
            additionalProperties: { type: "object", required: ["type"], properties: { type: { type: "string" }, required: { type: "boolean" } } },
          },
        },
      },
    },
  },
} as const;

/** Reads and checks one verbs file. Throws VerbsError naming the file and what is wrong with it. */
export function readVerbsFile(file: string): RunnerVerbs {
  const shown = toPosix(file);
  let text: string;
  try {
    text = fs.readFileSync(file, "utf8");
  } catch (e) {
    throw new VerbsError(
      `the runner's option list cannot be read: ${shown} (${(e as NodeJS.ErrnoException).code ?? "unreadable"}). ` +
        `The Foreman reads the verbs and options from the engine (tl.verbs/1) and has no copy of its own: point TL_ENGINE_DIR (or --engine-dir) at an engine that has ${VERBS_FILE}.`,
    );
  }
  let doc: unknown;
  try {
    doc = JSON.parse(stripBom(text));
  } catch (e) {
    throw new VerbsError(`the runner's option list is not JSON: ${shown} (${(e as Error).message})`);
  }
  const errs = schemaErrors(verbsSchema, doc);
  if (errs.length > 0) throw new VerbsError(`the runner's option list is not a tl.verbs/1 file: ${shown}: ${errs.join("; ")}`);
  const d = doc as { verbs: Record<string, VerbSpec> };
  return { schema: "tl.verbs/1", source: shown, verbs: d.verbs };
}

/** The verbs of an engine directory. */
export function loadVerbs(engineDir: string): RunnerVerbs {
  return readVerbsFile(path.join(engineDir, ...VERBS_FILE.split("/")));
}

/**
 * The verbs of the runner that will really be started. The bundled fake runner is its own engine: its list is
 * fixtures/engine/kernel/runner/verbs.json (which the fake runner itself obeys), whatever engine directory it is
 * pointed at. Every other runner: the engine directory's file, or an error.
 */
export function verbsFor(location: RunnerLocation): RunnerVerbs {
  const isFake = isFakeRunner(location);
  if (isFake && !fs.existsSync(path.join(location.engineDir, ...VERBS_FILE.split("/")))) return readVerbsFile(FAKE_VERBS_FILE);
  return loadVerbs(location.engineDir);
}

/** True when the runner is the bundled fake runner (a script run with node). */
export function isFakeRunner(location: RunnerLocation): boolean {
  return location.preArgs.some((a) => path.resolve(a) === path.resolve(FAKE_RUNNER));
}

/** Options the Foreman sets itself on every call; a plan may not carry them. */
const FOREMAN_OPTIONS = new Set(["pack", "report"]);
/** Verbs a package's acceptance may use (captures are taken by the Foreman at milestones). */
export const ACCEPTANCE_VERBS = ["lint", "smoke", "invariants", "bot"] as const;

/** The options a plan's acceptance may carry for a verb, or undefined when the verb is not an acceptance verb. */
export function acceptanceOptions(verbs: RunnerVerbs, verb: string): string[] | undefined {
  if (!(ACCEPTANCE_VERBS as readonly string[]).includes(verb)) return undefined;
  const spec = verbs.verbs[verb];
  if (!spec) return undefined;
  return Object.keys(spec.options).filter((o) => !FOREMAN_OPTIONS.has(o));
}

/** One line per acceptance verb for the Planner prompt, written from the engine's list. */
export function verbOptionsText(verbs: RunnerVerbs): string {
  const lines: string[] = [];
  for (const verb of ACCEPTANCE_VERBS) {
    const spec = verbs.verbs[verb];
    if (!spec) continue;
    const opts = (acceptanceOptions(verbs, verb) ?? []).map((o) => {
      const d = spec.options[o];
      const def = d?.default !== undefined && typeof d.default !== "object" ? `, default ${String(d.default)}` : "";
      return `\`--${o}=<${d?.type ?? "value"}>\`${verb === "bot" && o === "test" ? " (required: `--test=tests/<file>.gd`)" : def ? ` (${def.slice(2)})` : ""}`;
    });
    lines.push(`  - \`${verb}\` (${spec.level}): ${opts.length > 0 ? opts.join(", ") : "no options"}`);
  }
  return lines.join("\n");
}
