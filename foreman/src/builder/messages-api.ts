// Messages API adapter: a stub that implements the interface. It never calls the API.
// Without the key variable the user names it refuses; with it, it still refuses and says it is a stub.
import type { Builder, ProbeResult, RunRequest, RunResult } from "./types.js";

export interface MessagesApiOptions {
  /** NAME of the environment variable that holds the key, chosen by the user. The value is never read out. */
  keyVar?: string;
  env?: NodeJS.ProcessEnv;
}

export class MessagesApiBuilder implements Builder {
  readonly name = "messages-api" as const;
  private readonly keyVar: string | undefined;
  private readonly env: NodeJS.ProcessEnv;

  constructor(opts: MessagesApiOptions = {}) {
    this.keyVar = opts.keyVar;
    this.env = opts.env ?? process.env;
  }

  private keyPresent(): boolean {
    if (!this.keyVar) return false;
    const v = this.env[this.keyVar];
    return typeof v === "string" && v.length > 0;
  }

  private reason(): string {
    if (!this.keyVar) return "messages-api: no key variable was named (pass --api-key-var NAME); nothing was sent";
    if (!this.keyPresent()) return `messages-api: the variable ${this.keyVar} is not set; nothing was sent`;
    return `messages-api: ${this.keyVar} is set, but this adapter is a Phase 0 stub and does not call the API; nothing was sent`;
  }

  async probe(): Promise<ProbeResult> {
    return {
      adapter: "messages-api",
      ok: false,
      installed: true,
      version: "stub",
      authorized: this.keyPresent(),
      auth: this.keyVar ? `key variable ${this.keyVar} is ${this.keyPresent() ? "set" : "not set"}` : "no key variable named",
      billing: {
        mode: "api_key",
        evidence: this.keyVar
          ? `messages-api always bills the key in ${this.keyVar} per token (${this.keyPresent() ? "set" : "not set"})`
          : "messages-api always bills an API key per token; no key variable was named",
      },
      zeroCost: true,
      notes: [this.reason()],
    };
  }

  async run(req: RunRequest): Promise<RunResult> {
    const kind = this.keyPresent() ? "not_available" : "auth";
    return {
      ok: false,
      outcome: "refused",
      raw: { adapter: "messages-api", stub: true, mode: req.mode, meta: req.meta ?? null },
      durationMs: 0,
      error: { kind, message: this.reason() },
    };
  }
}
