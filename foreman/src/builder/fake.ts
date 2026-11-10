// The fake builder: deterministic and scriptable from a fixture. Every test uses it; it never touches the network.
import fs from "node:fs";
import path from "node:path";
import type { BuilderMode, BuilderOutcome } from "../events.js";
import type { Builder, ProbeResult, RunError, RunRequest, RunResult } from "./types.js";
import { checkTimeout } from "./types.js";
import { extractJson, schemaErrors } from "./json.js";

export interface FakeStep {
  /** All given fields must match. A step without `match` matches everything. */
  match?: {
    mode?: BuilderMode;
    role?: string;
    package?: string;
    round?: number;
    promptIncludes?: string;
    /** 1-based count of calls with the same role/package/round seen by this adapter instance. */
    attempt?: number;
  };
  delayMs?: number;
  /** Files to write, relative to the run's cwd (edit mode only). */
  write?: Record<string, string>;
  remove?: string[];
  text?: string;
  json?: unknown;
  /** Default "ok". "timeout" returns at once; use `hang` to wait for the caller's timeout instead. */
  outcome?: BuilderOutcome;
  hang?: boolean;
  error?: RunError;
  tokensIn?: number;
  tokensOut?: number;
  tokensCacheRead?: number;
}

export interface FakeScript {
  model?: string;
  probe?: Partial<ProbeResult>;
  steps: FakeStep[];
}

export interface FakeCall {
  req: RunRequest;
  step?: FakeStep;
  outcome: BuilderOutcome;
}

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

export class FakeBuilder implements Builder {
  readonly name = "fake" as const;
  readonly calls: FakeCall[] = [];
  private readonly attempts = new Map<string, number>();

  constructor(private readonly script: FakeScript) {}

  static fromFile(file: string): FakeBuilder {
    return new FakeBuilder(JSON.parse(fs.readFileSync(file, "utf8")) as FakeScript);
  }

  async probe(): Promise<ProbeResult> {
    return {
      adapter: "fake",
      ok: true,
      installed: true,
      version: "fake-1",
      authorized: true,
      auth: "none needed",
      billing: { mode: "none", evidence: "fake adapter: no model is called and nothing is billed" },
      zeroCost: true,
      notes: [],
      ...this.script.probe,
    };
  }

  async run(req: RunRequest): Promise<RunResult> {
    const started = Date.now();
    const model = req.model ?? this.script.model ?? "fake";
    const done = (outcome: BuilderOutcome, step: FakeStep | undefined, extra: Partial<RunResult>): RunResult => {
      this.calls.push({ req, ...(step ? { step } : {}), outcome });
      return {
        ok: outcome === "ok",
        outcome,
        raw: { adapter: "fake", step: step ?? null, meta: req.meta ?? null, mode: req.mode },
        durationMs: Date.now() - started,
        model,
        ...(step?.tokensIn !== undefined ? { tokensIn: step.tokensIn } : {}),
        ...(step?.tokensOut !== undefined ? { tokensOut: step.tokensOut } : {}),
        ...(step?.tokensCacheRead !== undefined ? { tokensCacheRead: step.tokensCacheRead } : {}),
        ...extra,
      };
    };
    const bad = checkTimeout(req.timeoutMs);
    if (bad) return done("error", undefined, { error: { kind: "config", message: bad } });

    const key = `${req.meta?.role ?? ""}|${req.meta?.package ?? ""}|${req.meta?.round ?? ""}`;
    const attempt = (this.attempts.get(key) ?? 0) + 1;
    this.attempts.set(key, attempt);
    const step = this.script.steps.find((s) => {
      const m = s.match;
      if (!m) return true;
      if (m.mode !== undefined && m.mode !== req.mode) return false;
      if (m.role !== undefined && m.role !== req.meta?.role) return false;
      if (m.package !== undefined && m.package !== req.meta?.package) return false;
      if (m.round !== undefined && m.round !== req.meta?.round) return false;
      if (m.attempt !== undefined && m.attempt !== attempt) return false;
      if (m.promptIncludes !== undefined && !req.prompt.includes(m.promptIncludes)) return false;
      return true;
    });
    if (!step) {
      return done("error", undefined, {
        error: { kind: "config", message: `fake script has no step for ${JSON.stringify(req.meta ?? {})} mode ${req.mode}` },
      });
    }

    if (step.hang) {
      await sleep(req.timeoutMs);
      return done("timeout", step, { error: { kind: "exit", message: `no answer within ${req.timeoutMs} ms` } });
    }
    if (step.delayMs !== undefined && step.delayMs > 0) {
      if (step.delayMs >= req.timeoutMs) {
        await sleep(req.timeoutMs);
        return done("timeout", step, { error: { kind: "exit", message: `no answer within ${req.timeoutMs} ms` } });
      }
      await sleep(step.delayMs);
    }

    if (req.mode === "edit") {
      const root = path.resolve(req.cwd);
      const inside = (rel: string): string => {
        const abs = path.resolve(root, rel);
        if (abs !== root && !abs.startsWith(root + path.sep)) throw new Error(`fake step path escapes cwd: ${rel}`);
        return abs;
      };
      for (const [rel, content] of Object.entries(step.write ?? {})) {
        const abs = inside(rel);
        fs.mkdirSync(path.dirname(abs), { recursive: true });
        fs.writeFileSync(abs, content);
      }
      for (const rel of step.remove ?? []) fs.rmSync(inside(rel), { force: true });
    }

    const outcome = step.outcome ?? "ok";
    if (outcome !== "ok") {
      return done(outcome, step, {
        ...(step.text !== undefined ? { text: step.text } : {}),
        error: step.error ?? { kind: outcome === "refused" ? "refusal" : "exit", message: `scripted ${outcome}` },
      });
    }

    let json: unknown = step.json;
    const text = step.text ?? (json !== undefined ? JSON.stringify(json) : "done");
    if (req.schema) {
      if (json === undefined) {
        const ex = extractJson(text);
        if (!ex.ok) {
          return done(ex.looksCutOff ? "truncated" : "error", step, {
            text,
            error: { kind: "parse", message: ex.reason },
          });
        }
        json = ex.value;
      }
      const errs = schemaErrors(req.schema, json);
      if (errs.length > 0) {
        return done("error", step, { text, json, error: { kind: "schema", message: errs.join("; ") } });
      }
    }
    return done("ok", step, { text, ...(json !== undefined ? { json } : {}) });
  }
}
