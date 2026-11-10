// The builder transport contract: probe() and run(). Per-tool flags are data behind it.
import type { AdapterName, BuilderMode, BuilderOutcome } from "../events.js";

export interface ProbeResult {
  adapter: AdapterName;
  /** True when the adapter can answer a run right now. */
  ok: boolean;
  installed: boolean;
  version?: string;
  authorized: boolean;
  /** How authorization was established, in words (never a secret). */
  auth: string;
  billing: { mode: "subscription" | "api_key" | "none"; evidence: string };
  /** True when the probe itself spent no tokens. */
  zeroCost: boolean;
  /** Human-readable problems when ok is false, or caveats when it is true. */
  notes: string[];
  executable?: string;
}

export interface RunRequest {
  prompt: string;
  mode: BuilderMode;
  /** generate: ignored (a neutral temp directory is used). readonly-scan and edit: the workspace. */
  cwd: string;
  /** JSON schema the answer must satisfy; the adapter returns the parsed, validated value in `json`. */
  schema?: object;
  model?: string;
  timeoutMs: number;
  /**
   * edit mode only: permission rules for the shell commands the builder may run to check its own work. The Foreman
   * derives them from the package's acceptance commands (see allowlist.ts); nobody writes them by hand. Without
   * it the builder gets no shell at all.
   */
  bash?: { allow: string[]; deny: string[] };
  /**
   * generate mode only: absolute paths of images (PNG or JPEG) the model must see with the prompt. claude-cli sends
   * them as base64 image blocks in a stream-json user message; an adapter that cannot do this must refuse the run.
   */
  images?: string[];
  /** readonly-scan and edit: extra directories the file tools may read (reference material outside the workspace). */
  addDirs?: string[];
  /** Labels for transcripts and for the fake adapter's script. Never sent to a model. */
  meta?: { role?: string; package?: string; round?: number };
}

export interface RunError {
  kind:
    | "rate_limit"
    | "auth"
    | "spawn"
    | "exit"
    | "parse"
    | "schema"
    | "config"
    | "api"
    | "refusal"
    | "not_available"
    | "permission";
  message: string;
  /** When the tool said when to come back. */
  retryAfterMs?: number;
}

export interface RunResult {
  ok: boolean;
  outcome: BuilderOutcome;
  text?: string;
  json?: unknown;
  /** The tool's full envelope (events, stderr tail, exit code, argv). Metering and diagnosis read this. */
  raw: unknown;
  durationMs: number;
  tokensIn?: number;
  tokensOut?: number;
  /** The part of tokensIn read from the prompt cache, when the adapter reports it. */
  tokensCacheRead?: number;
  model?: string;
  error?: RunError;
  /** What the child itself reported about its posture (tools, permission mode, key source), when it does. */
  observed?: { tools?: string[]; permissionMode?: string; apiKeySource?: string; billingMode?: "subscription" | "api_key" };
}

export interface Builder {
  readonly name: AdapterName;
  probe(): Promise<ProbeResult>;
  run(req: RunRequest): Promise<RunResult>;
}

/** Smallest timeout an adapter that spawns a real process accepts; anything lower is treated as misconfiguration. */
export const MIN_TIMEOUT_MS = 1000;

export function checkTimeout(timeoutMs: number): string | undefined {
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) return `timeoutMs must be a positive number, got ${timeoutMs}`;
  return undefined;
}
