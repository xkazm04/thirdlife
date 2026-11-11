// The Verifier: runs the RUNNER.md verbs by spawning TL_GODOT directly, with a timeout, and decides `ok` from
// the exit code, the last stdout line and the report file together. A builder's claim is never an input here.
import fs from "node:fs";
import path from "node:path";
import { isDeepStrictEqual } from "node:util";
import { VERB_LEVEL, LEVELS, type Level, type Verb } from "./events.js";
import { runProcess, type SpawnFn } from "./proc.js";
import { runnerArgv, type RunnerLocation } from "./builder/allowlist.js";
import { DEFAULT_GODOT, FAKE_RUNNER, REPO_ROOT } from "./paths.js";
import { withoutSecrets } from "./builder/claude-cli.js";

export type VerifyFlag =
  | "spawn_error"
  | "runner_timeout"
  | "stdout_not_json"
  | "report_missing"
  | "report_not_json"
  | "report_invalid"
  | "stdout_report_mismatch"
  | "exit_outcome_disagree"
  | "ok_outcome_disagree"
  | "verb_mismatch"
  | "exit_code_unknown";

export interface VerifyReport {
  schema: "tl.verify/1";
  verb: string;
  level: string;
  ok: boolean;
  outcome: "passed" | "failed" | "not_run" | "watchdog";
  checks: { id: string; ok: boolean; detail?: string }[];
  errors: { kind: string; file?: string; line?: number; message: string }[];
  [k: string]: unknown;
}

export interface VerifyResult {
  verb: Verb;
  level: Level;
  /** The verifier's own verdict: true only when exit code, stdout line and report file all say passed. */
  ok: boolean;
  exitCode?: number;
  /** The runner's report when it is usable. */
  report?: VerifyReport;
  /** Absolute path of the file a `verify` event should point at: the runner's report, or our verdict file. */
  reportFile: string;
  verdictFile: string;
  flags: VerifyFlag[];
  /** One-paragraph explanation, fed back to the builder with the report. */
  summary: string;
  durationMs: number;
}

export interface VerifierOptions {
  /** TL_GODOT. A path ending in .js or .mjs is run with the current Node executable (the fake runner). */
  godot?: string;
  /** TL_ENGINE_DIR. */
  engineDir?: string;
  timeoutMs?: number;
  spawn?: SpawnFn;
  env?: NodeJS.ProcessEnv;
}

const EXIT_OUTCOME: Record<number, VerifyReport["outcome"]> = { 0: "passed", 1: "failed", 2: "not_run", 3: "watchdog" };

/**
 * RUNNER.md (amendments of 2026-11-10): the top-level keys of a report are fixed; unknown `checks[].id` values and
 * unknown keys inside `metrics` are accepted. A top-level key outside this list makes the report invalid.
 */
export const REPORT_KEYS = [
  "schema", "verb", "level", "pack", "packVersion", "kernelApi", "ok", "outcome", "seed", "frames", "durationMs",
  "checks", "metrics", "errors", "composability", "bot", "capture",
] as const;

export function runnerLocation(godot: string, engineDir: string): RunnerLocation {
  if (/\.(mjs|js)$/i.test(godot)) return { exe: process.execPath, preArgs: [path.resolve(godot)], engineDir };
  return { exe: godot, preArgs: [], engineDir };
}

/** Resolves TL_GODOT and TL_ENGINE_DIR the way the CLI does. `fake` selects the bundled fake runner. */
export function resolveRunner(env: NodeJS.ProcessEnv, opts: { fake?: boolean; engineDir?: string } = {}): { godot: string; engineDir: string } {
  const godot = opts.fake ? FAKE_RUNNER : env["TL_GODOT"] && env["TL_GODOT"].length > 0 ? env["TL_GODOT"] : DEFAULT_GODOT;
  const engineDir = opts.engineDir ?? (env["TL_ENGINE_DIR"] && env["TL_ENGINE_DIR"].length > 0 ? env["TL_ENGINE_DIR"] : path.join(REPO_ROOT, "engine"));
  return { godot, engineDir: path.resolve(engineDir) };
}

function shapeProblems(r: unknown): string[] {
  const out: string[] = [];
  if (r === null || typeof r !== "object" || Array.isArray(r)) return ["report is not a JSON object"];
  const o = r as Record<string, unknown>;
  if (o["schema"] !== "tl.verify/1") out.push(`schema is ${JSON.stringify(o["schema"])}, expected "tl.verify/1"`);
  if (typeof o["verb"] !== "string") out.push("verb is missing");
  if (typeof o["level"] !== "string" || !(LEVELS as readonly string[]).includes(o["level"])) out.push("level is missing or unknown");
  if (typeof o["ok"] !== "boolean") out.push("ok is not a boolean");
  if (typeof o["outcome"] !== "string" || !["passed", "failed", "not_run", "watchdog"].includes(o["outcome"])) out.push("outcome is missing or unknown");
  if (!Array.isArray(o["checks"])) out.push("checks is not an array");
  if (!Array.isArray(o["errors"])) out.push("errors is not an array");
  if (Array.isArray(o["checks"])) {
    o["checks"].forEach((c, i) => {
      const ck = c as { id?: unknown; ok?: unknown } | null;
      if (ck === null || typeof ck !== "object" || typeof ck.id !== "string" || typeof ck.ok !== "boolean") out.push(`checks[${i}] needs a string id and a boolean ok`);
    });
  }
  if (o["metrics"] !== undefined && (o["metrics"] === null || typeof o["metrics"] !== "object" || Array.isArray(o["metrics"]))) out.push("metrics is not an object");
  for (const k of Object.keys(o)) if (!(REPORT_KEYS as readonly string[]).includes(k)) out.push(`unknown top-level key "${k}"`);
  return out;
}

export class Verifier {
  readonly location: RunnerLocation;
  private readonly timeoutMs: number;
  private readonly spawn: SpawnFn;
  private readonly env: NodeJS.ProcessEnv;

  constructor(opts: VerifierOptions = {}) {
    const r = resolveRunner(opts.env ?? process.env, opts.engineDir !== undefined ? { engineDir: opts.engineDir } : {});
    this.location = runnerLocation(opts.godot ?? r.godot, opts.engineDir ?? r.engineDir);
    this.timeoutMs = opts.timeoutMs ?? 10 * 60_000;
    this.spawn = opts.spawn ?? runProcess;
    // Pack code runs inside the runner: it gets no key-like variables either (the fence is lint, not a sandbox).
    this.env = withoutSecrets(opts.env ?? process.env, []).env;
  }

  /**
   * Runs one verb against a pack directory. `reportFile` is where the runner is told to write; a verdict file
   * (`<reportFile minus .json>.verdict.json`) with our own cross-checks is always written next to it.
   */
  async run(req: { verb: Verb; args?: string[]; packDir: string; reportFile: string; timeoutMs?: number }): Promise<VerifyResult> {
    const packDir = path.resolve(req.packDir);
    const reportFile = path.resolve(req.reportFile);
    const verdictFile = reportFile.replace(/\.json$/i, "") + ".verdict.json";
    fs.mkdirSync(path.dirname(reportFile), { recursive: true });
    // A stale report from an earlier run must never be read as this run's answer.
    fs.rmSync(reportFile, { force: true });
    const argv = runnerArgv(this.location, { verb: req.verb, args: req.args ?? [] }, packDir, reportFile);
    const timeoutMs = req.timeoutMs ?? this.timeoutMs;
    // RUNNER.md: captures use Direct3D 12 so that every image comes from one backend. The snapshot engine still
    // tries the default driver first unless told, so the Verifier says it (an explicit TL_RENDER_DRIVERS wins).
    const env = req.verb === "capture" && !this.env["TL_RENDER_DRIVERS"] ? { ...this.env, TL_RENDER_DRIVERS: "d3d12" } : this.env;
    const proc = await this.spawn({ exe: this.location.exe, args: argv, env, timeoutMs, cwd: path.dirname(reportFile) });

    const flags: VerifyFlag[] = [];
    const notes: string[] = [];
    let fromStdout: unknown;
    let fromFile: unknown;
    let report: VerifyReport | undefined;

    if (proc.spawnError) {
      flags.push("spawn_error");
      notes.push(`the runner could not be started: ${proc.spawnError}`);
    } else if (proc.timedOut) {
      flags.push("runner_timeout");
      notes.push(`the runner did not finish within ${timeoutMs} ms and its process tree was killed`);
    } else {
      const lines = proc.stdout.split(/\r?\n/).map((l) => l.trim()).filter((l) => l.length > 0);
      const last = lines[lines.length - 1];
      try {
        if (last === undefined) throw new Error("no output");
        fromStdout = JSON.parse(last);
      } catch {
        flags.push("stdout_not_json");
        notes.push(`the last line of the runner's stdout is not JSON: ${JSON.stringify((last ?? "").slice(0, 160))}`);
      }
      if (!fs.existsSync(reportFile)) {
        flags.push("report_missing");
        notes.push("the runner wrote no report file");
      } else {
        try {
          fromFile = JSON.parse(fs.readFileSync(reportFile, "utf8"));
        } catch {
          flags.push("report_not_json");
          notes.push("the report file is not JSON");
        }
      }
      // Same content, whatever the key order or whitespace each side was written with.
      if (fromStdout !== undefined && fromFile !== undefined && !isDeepStrictEqual(fromStdout, fromFile)) {
        flags.push("stdout_report_mismatch");
        notes.push("the last stdout line and the report file differ");
      }
      const candidate = fromFile ?? fromStdout;
      if (candidate !== undefined) {
        const problems = shapeProblems(candidate);
        if (problems.length > 0) {
          flags.push("report_invalid");
          notes.push(`the report is not a tl.verify/1 report: ${problems.join("; ")}`);
        } else {
          report = candidate as VerifyReport;
          if (report.verb !== req.verb) {
            flags.push("verb_mismatch");
            notes.push(`asked for ${req.verb}, the report is for ${report.verb}`);
          }
          if (report.ok !== (report.outcome === "passed")) {
            flags.push("ok_outcome_disagree");
            notes.push(`report says ok=${report.ok} with outcome=${report.outcome}`);
          }
          const expected = proc.exitCode !== undefined ? EXIT_OUTCOME[proc.exitCode] : undefined;
          if (expected === undefined) {
            flags.push("exit_code_unknown");
            notes.push(`exit code ${proc.exitCode ?? "none"} is not one RUNNER.md defines`);
          } else if (expected !== report.outcome) {
            flags.push("exit_outcome_disagree");
            notes.push(`exit code ${proc.exitCode} means ${expected}, the report says ${report.outcome}`);
          }
        }
      }
    }

    const ok = flags.length === 0 && proc.exitCode === 0 && report !== undefined && report.ok === true && report.outcome === "passed";
    if (flags.length === 0 && report && !ok) {
      const failed = report.checks.filter((c) => !c.ok).map((c) => c.id);
      notes.push(`${req.verb} ${report.outcome}: failed checks [${failed.join(", ")}], ${report.errors.length} errors`);
    }
    if (ok) notes.push(`${req.verb} passed`);
    const level = report && (LEVELS as readonly string[]).includes(report.level) ? (report.level as Level) : VERB_LEVEL[req.verb];
    const verdict = {
      schema: "tl.foreman.verdict/1",
      verb: req.verb,
      level,
      ok,
      flags,
      notes,
      ...(proc.exitCode !== undefined ? { exitCode: proc.exitCode } : {}),
      timedOut: proc.timedOut,
      durationMs: proc.durationMs,
      runnerReportUsable: report !== undefined,
      argv,
      stdoutTail: proc.stdout.slice(-1500),
      stderrTail: proc.stderr.slice(-1500),
    };
    fs.writeFileSync(verdictFile, JSON.stringify(verdict, null, 1) + "\n");
    // The event must point at a file that exists and tells the truth: the runner's report only when it is usable.
    const usable = report !== undefined && fs.existsSync(reportFile) && !flags.includes("report_not_json");
    return {
      verb: req.verb,
      level,
      ok,
      ...(proc.exitCode !== undefined ? { exitCode: proc.exitCode } : {}),
      ...(report ? { report } : {}),
      reportFile: usable ? reportFile : verdictFile,
      verdictFile,
      flags,
      summary: notes.join(". "),
      durationMs: proc.durationMs,
    };
  }
}

// ---------- V5: the critic seam ----------

export interface CritiqueResult {
  ok: boolean;
  scores: Record<string, number>;
  notes: string[];
  /** N3: the package whose files most likely cause what the critic sees (one id of the list it was given). */
  package?: string;
}

export const critiqueSchema = {
  type: "object",
  additionalProperties: false,
  required: ["ok", "scores", "notes"],
  properties: {
    ok: { type: "boolean" },
    scores: { type: "object", additionalProperties: { type: "number", minimum: 0, maximum: 1 } },
    notes: { type: "array", items: { type: "string" } },
    package: { type: "string" },
  },
} as const;
