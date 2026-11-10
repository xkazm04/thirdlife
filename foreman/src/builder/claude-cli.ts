// Claude Code headless as a builder transport.
// Prompt over stdin, never argv. Three modes, three separate seams. Our timeout, our tree kill.
// Flags come from data/capabilities.json for the probed version, not from constants in this file.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import type { Builder, ProbeResult, RunError, RunRequest, RunResult } from "./types.js";
import { checkTimeout, MIN_TIMEOUT_MS } from "./types.js";
import { extractJson, schemaErrors } from "./json.js";
import { runProcess, resolveExe, type SpawnFn, type RunProcessResult } from "../proc.js";
import { PKG_ROOT } from "../paths.js";

export interface ClaudeCliOptions {
  /**
   * Path or name of the executable. Default: TL_CLAUDE_BIN, then `claude` on PATH.
   * A path ending in .js or .mjs is run with the current Node executable: that is how the tests put a stand-in
   * (dist/testing/fake-claude.js) behind the real spawn door.
   */
  bin?: string;
  /** The real environment by default. Tests pass their own. Values are never logged. */
  env?: NodeJS.ProcessEnv;
  /**
   * "inherit" (default): the child sees the environment as it is, and the probe reports the billing that follows.
   * "subscription": metering variables are removed from the child environment at this one door.
   */
  billing?: "inherit" | "subscription";
  /** Explicit consent for edit mode. Without it an edit run is refused. */
  allowEdit?: boolean;
  /**
   * Environment variables the child must not see: exact names, or a prefix ending in `*` (for example
   * "OTHER_PROJECT_KEY_*"). A builder with file or shell tools can read its own environment, so secrets that have
   * nothing to do with the build should not be in it. Default: nothing is hidden (the child sees what you see).
   */
  hideEnv?: string[];
  spawn?: SpawnFn;
  capabilitiesFile?: string;
}

/** Variables that move a run from the subscription login to metered billing. Names only; values are never read out. */
export const METERING_VARS = ["ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN"] as const;
export const PROVIDER_VARS = ["CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY"] as const;
/**
 * JOB.md (amendments of 2026-11-10): runs that give the model tools do not inherit variables whose names contain
 * one of these words, apart from what the adapter's own authentication needs (AUTH_VARS). Names only, never values.
 */
export const SECRET_NAME_RE = /KEY|TOKEN|SECRET|PASSWORD/i;
export const AUTH_VARS = ["ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN"] as const;

/** Removes key-like variables from an environment. Returns how many were removed (their names are not kept). */
export function withoutSecrets(env: NodeJS.ProcessEnv, keep: readonly string[] = AUTH_VARS): { env: NodeJS.ProcessEnv; removed: number } {
  const out: NodeJS.ProcessEnv = {};
  let removed = 0;
  const kept = new Set(keep.map((k) => k.toUpperCase()));
  for (const [name, value] of Object.entries(env)) {
    if (SECRET_NAME_RE.test(name) && !kept.has(name.toUpperCase())) removed += 1;
    else out[name] = value;
  }
  return { env: out, removed };
}

interface CapabilityEntry {
  version: string;
  observedOn: string;
  flags: {
    common: string[];
    model: string[];
    schema: string[];
    generate: string[];
    /** Replaces the text input flags of `common` when images are attached (stream-json user message on stdin). */
    imageInput?: { remove: string[]; add: string[] };
    addDir?: string[];
    "readonly-scan": string[];
    edit: string[];
    editTools: string;
    editToolsWithShell: string;
  };
}

interface StreamEvent {
  type?: string;
  subtype?: string;
  [k: string]: unknown;
}

const isSet = (env: NodeJS.ProcessEnv, name: string): boolean => {
  const v = env[name];
  return typeof v === "string" && v.length > 0;
};
const truthy = (env: NodeJS.ProcessEnv, name: string): boolean => {
  const v = env[name];
  return typeof v === "string" && v.length > 0 && v !== "0" && v.toLowerCase() !== "false";
};

export function parseEnvelope(stdout: string): { events: StreamEvent[]; noiseLines: number } {
  const trimmed = stdout.trim();
  const events: StreamEvent[] = [];
  let noise = 0;
  if (trimmed.startsWith("[")) {
    try {
      const arr = JSON.parse(trimmed) as unknown;
      if (Array.isArray(arr)) return { events: arr.filter((x) => x && typeof x === "object") as StreamEvent[], noiseLines: 0 };
    } catch {
      /* fall through to line mode */
    }
  }
  for (const line of trimmed.split(/\r?\n/)) {
    const l = line.trim();
    if (!l) continue;
    if (!l.startsWith("{")) {
      noise += 1;
      continue;
    }
    try {
      const v = JSON.parse(l) as unknown;
      if (v && typeof v === "object" && !Array.isArray(v)) events.push(v as StreamEvent);
      else noise += 1;
    } catch {
      noise += 1;
    }
  }
  return { events, noiseLines: noise };
}

const RATE_RE = /usage limit|rate limit|rate_limit|hit your limit|limit reached|too many requests|\b429\b|overloaded/i;
const AUTH_RE = /not logged in|please run \/login|invalid api key|authentication_error|oauth token (has )?expired|unauthorized|\b401\b/i;

function tail(s: string, n = 2000): string {
  return s.length <= n ? s : s.slice(s.length - n);
}

export class ClaudeCliBuilder implements Builder {
  readonly name = "claude-cli" as const;
  private readonly spawn: SpawnFn;
  private readonly baseEnv: NodeJS.ProcessEnv;
  private readonly billingPolicy: "inherit" | "subscription";
  private readonly allowEdit: boolean;
  private readonly hideEnv: string[];
  private readonly binSetting: string;
  private readonly capFile: string;
  private probed: ProbeResult | undefined;
  private preArgs: string[] = [];
  private caps: CapabilityEntry | undefined;

  constructor(opts: ClaudeCliOptions = {}) {
    this.spawn = opts.spawn ?? runProcess;
    this.baseEnv = opts.env ?? process.env;
    this.billingPolicy = opts.billing ?? "inherit";
    this.allowEdit = opts.allowEdit ?? false;
    this.hideEnv = (opts.hideEnv ?? []).filter((p) => p.replace(/\*$/, "").length > 0);
    this.binSetting = opts.bin ?? this.baseEnv["TL_CLAUDE_BIN"] ?? "claude";
    this.capFile = opts.capabilitiesFile ?? path.join(PKG_ROOT, "data", "capabilities.json");
  }

  /**
   * The one place the child's environment is built: the probe and every run use it.
   * A run that gives the model tools (`edit`, `readonly-scan`) never inherits key-like variables (SECRET_NAME_RE),
   * except the adapter's own authentication. A generate run has no tools and cannot read its environment.
   */
  childEnv(mode?: RunRequest["mode"]): { env: NodeJS.ProcessEnv; stripped: string[]; hidden: number } {
    let env: NodeJS.ProcessEnv = { ...this.baseEnv };
    const stripped: string[] = [];
    let hidden = 0;
    if (mode === "edit" || mode === "readonly-scan") {
      const cut = withoutSecrets(env);
      env = cut.env;
      hidden += cut.removed;
    }
    for (const name of Object.keys(env)) {
      const hit = this.hideEnv.some((p) => (p.endsWith("*") ? name.toUpperCase().startsWith(p.slice(0, -1).toUpperCase()) : name.toUpperCase() === p.toUpperCase()));
      if (hit) {
        delete env[name];
        hidden += 1;
      }
    }
    if (this.billingPolicy === "subscription") {
      for (const name of [...METERING_VARS, ...PROVIDER_VARS]) {
        if (isSet(env, name)) {
          delete env[name];
          stripped.push(name);
        }
      }
    }
    return { env, stripped, hidden };
  }

  private loadCaps(version: string | undefined): { entry: CapabilityEntry | undefined; note?: string } {
    let entries: CapabilityEntry[] = [];
    try {
      const doc = JSON.parse(fs.readFileSync(this.capFile, "utf8")) as { adapters?: Record<string, CapabilityEntry[]> };
      entries = doc.adapters?.["claude-cli"] ?? [];
    } catch (e) {
      return { entry: undefined, note: `capability matrix unreadable (${this.capFile}): ${(e as Error).message}` };
    }
    const exact = entries.find((e) => e.version === version);
    if (exact) return { entry: exact };
    const newest = entries[entries.length - 1];
    if (!newest) return { entry: undefined, note: "capability matrix has no claude-cli entry" };
    return {
      entry: newest,
      note: `no capability entry for version ${version ?? "unknown"}: using the one observed for ${newest.version} on ${newest.observedOn} (unverified for this version)`,
    };
  }

  async probe(): Promise<ProbeResult> {
    const notes: string[] = [];
    const { env, stripped, hidden } = this.childEnv();
    if (this.hideEnv.length > 0) notes.push(`${hidden} environment variable(s) matching ${this.hideEnv.join(", ")} are hidden from the CLI`);
    const keyLike = withoutSecrets(env).removed;
    notes.push(`edit and readonly-scan runs do not inherit key-like variables (names containing KEY, TOKEN, SECRET or PASSWORD): ${keyLike} hidden in this environment`);
    const base: ProbeResult = {
      adapter: "claude-cli",
      ok: false,
      installed: false,
      authorized: false,
      auth: "unknown",
      billing: { mode: "subscription", evidence: "not determined: the CLI was not found" },
      zeroCost: true,
      notes,
    };
    let exe = resolveExe(this.binSetting, env);
    this.preArgs = [];
    if (/\.(mjs|js)$/i.test(this.binSetting) && fs.existsSync(this.binSetting)) {
      exe = process.execPath;
      this.preArgs = [path.resolve(this.binSetting)];
    }
    if (!exe) {
      notes.push(`executable "${this.binSetting}" not found (set TL_CLAUDE_BIN or put claude on PATH)`);
      return (this.probed = base);
    }
    base.executable = exe;
    const ver = await this.spawn({ exe, args: [...this.preArgs, "--version"], env, cwd: os.tmpdir(), timeoutMs: 20_000 });
    if (ver.spawnError || ver.exitCode !== 0) {
      notes.push(`"--version" failed: ${ver.spawnError ?? `exit ${ver.exitCode}`} ${tail(ver.stderr, 300)}`.trim());
      return (this.probed = base);
    }
    base.installed = true;
    const m = /(\d+\.\d+\.\d+)/.exec(ver.stdout);
    if (m?.[1]) base.version = m[1];
    else notes.push(`could not read a version from: ${ver.stdout.trim().slice(0, 80)}`);

    const caps = this.loadCaps(base.version);
    this.caps = caps.entry;
    if (caps.note) notes.push(caps.note);

    // Zero-token authorization proof, through the same door and environment as a real run.
    const st = await this.spawn({ exe, args: [...this.preArgs, "auth", "status", "--json"], env, cwd: os.tmpdir(), timeoutMs: 30_000 });
    let status: { loggedIn?: boolean; authMethod?: string; subscriptionType?: string; apiProvider?: string } = {};
    try {
      const parsed = extractJson(st.stdout);
      if (parsed.ok && parsed.value && typeof parsed.value === "object") status = parsed.value as typeof status;
      else notes.push(`"auth status --json" printed no JSON (exit ${st.exitCode ?? "none"})`);
    } catch {
      notes.push(`"auth status --json" could not be read`);
    }
    base.authorized = status.loggedIn === true;
    // Only these non-identifying fields are kept; email and organisation are deliberately not read out.
    base.auth = base.authorized
      ? `logged in (authMethod=${status.authMethod ?? "?"}${status.subscriptionType ? `, subscriptionType=${status.subscriptionType}` : ""})`
      : "not logged in";

    const keyVars = METERING_VARS.filter((n) => isSet(env, n));
    const provVars = PROVIDER_VARS.filter((n) => truthy(env, n));
    const strippedNote = stripped.length > 0 ? `; removed from the child environment by the Foreman: ${stripped.join(", ")}` : "";
    if (keyVars.length > 0) {
      base.billing = {
        mode: "api_key",
        evidence: `${keyVars.join(" and ")} is set in the environment the CLI inherits: runs bill per token, not the subscription`,
      };
    } else if (provVars.length > 0) {
      base.billing = { mode: "api_key", evidence: `${provVars.join(" and ")} is set: runs bill a cloud provider account per token` };
    } else if (base.authorized && status.authMethod === "claude.ai") {
      base.billing = {
        mode: "subscription",
        evidence: `claude auth status reports authMethod=claude.ai${status.subscriptionType ? ` (subscriptionType=${status.subscriptionType})` : ""}; ${METERING_VARS.join(" and ")} are not set${strippedNote}`,
      };
    } else if (base.authorized && isSet(env, "CLAUDE_CODE_OAUTH_TOKEN")) {
      base.billing = { mode: "subscription", evidence: `CLAUDE_CODE_OAUTH_TOKEN is set (a subscription token)${strippedNote}` };
    } else if (base.authorized) {
      base.billing = {
        mode: "api_key",
        evidence: `claude auth status reports authMethod=${status.authMethod ?? "unknown"}, which is not a claude.ai subscription login`,
      };
    } else {
      base.billing = { mode: "subscription", evidence: `not logged in and no key variable set: no run would start${strippedNote}` };
      notes.push("not authorized: run `claude auth login`");
    }
    if (!this.caps) notes.push("no usable capability entry: runs are refused");
    base.ok = base.installed && base.authorized && this.caps !== undefined;
    return (this.probed = base);
  }

  async run(req: RunRequest): Promise<RunResult> {
    switch (req.mode) {
      case "generate":
        return this.runGenerate(req);
      case "readonly-scan":
        return this.runReadonlyScan(req);
      case "edit":
        return this.runEdit(req);
    }
  }

  private fail(outcome: "error" | "refused", error: RunError, raw: unknown = {}): RunResult {
    return { ok: false, outcome, raw, durationMs: 0, error };
  }

  private async ready(req: RunRequest): Promise<{ exe: string; caps: CapabilityEntry } | RunResult> {
    const bad = checkTimeout(req.timeoutMs);
    if (bad) return this.fail("error", { kind: "config", message: bad });
    const p = this.probed ?? (await this.probe());
    if (!p.installed || !p.executable) return this.fail("refused", { kind: "not_available", message: p.notes.join("; ") || "claude CLI not installed" }, { probe: p });
    if (!p.authorized) return this.fail("refused", { kind: "auth", message: "claude CLI is not logged in" }, { probe: p });
    if (!this.caps) return this.fail("refused", { kind: "config", message: "no capability entry for the claude CLI" }, { probe: p });
    return { exe: p.executable, caps: this.caps };
  }

  private fill(tokens: string[], vars: Record<string, string>): string[] {
    return tokens.map((t) => t.replace(/\{(\w+)\}/g, (whole, k: string) => vars[k] ?? whole));
  }

  // --- generate: no tools, neutral temp cwd, no workspace ---
  private async runGenerate(req: RunRequest): Promise<RunResult> {
    const r = await this.ready(req);
    if ("outcome" in r) return r;
    const neutral = fs.mkdtempSync(path.join(os.tmpdir(), "tl-foreman-gen-"));
    try {
      let common = [...r.caps.flags.common];
      let stdin: string | undefined;
      if (req.images && req.images.length > 0) {
        const how = r.caps.flags.imageInput;
        if (!how) return this.fail("refused", { kind: "config", message: "this CLI version has no known way to attach images to a generate run" });
        const content: unknown[] = [];
        for (const img of req.images) {
          const ext = path.extname(img).toLowerCase();
          const media = ext === ".png" ? "image/png" : ext === ".jpg" || ext === ".jpeg" ? "image/jpeg" : undefined;
          if (!media) return this.fail("error", { kind: "config", message: `unsupported image type: ${img}` });
          if (!fs.existsSync(img)) return this.fail("error", { kind: "config", message: `image not found: ${img}` });
          content.push({ type: "image", source: { type: "base64", media_type: media, data: fs.readFileSync(img).toString("base64") } });
        }
        content.push({ type: "text", text: req.prompt });
        // Drop the text-input flag pair(s) and add the stream-json ones.
        for (let i = 0; i + how.remove.length <= common.length; i++) {
          if (how.remove.every((t, k) => common[i + k] === t)) {
            common.splice(i, how.remove.length);
            break;
          }
        }
        common = [...common, ...how.add];
        stdin = JSON.stringify({ type: "user", message: { role: "user", content } }) + "\n";
      }
      const args = [...common, ...r.caps.flags.generate, ...this.optional(r.caps, req)];
      return await this.exec(r.exe, args, neutral, req, stdin);
    } finally {
      fs.rmSync(neutral, { recursive: true, force: true });
    }
  }

  // --- readonly-scan: read tools only, in the given directory ---
  private async runReadonlyScan(req: RunRequest): Promise<RunResult> {
    const r = await this.ready(req);
    if ("outcome" in r) return r;
    const cwd = path.resolve(req.cwd);
    if (!fs.existsSync(cwd)) return this.fail("error", { kind: "config", message: `cwd does not exist: ${cwd}` });
    const args = [...r.caps.flags.common, ...r.caps.flags["readonly-scan"], ...this.addDirs(r.caps, req), ...this.optional(r.caps, req)];
    return this.exec(r.exe, args, cwd, req);
  }

  // --- edit: file tools inside cwd, shell only for the derived allowlist, explicit consent ---
  private async runEdit(req: RunRequest): Promise<RunResult> {
    if (!this.allowEdit) {
      return this.fail("refused", {
        kind: "permission",
        message: "edit mode lets the CLI write files: it needs explicit consent (allowEdit, or --allow-edit on the foreman CLI)",
      });
    }
    const r = await this.ready(req);
    if ("outcome" in r) return r;
    const cwd = path.resolve(req.cwd);
    if (!fs.existsSync(cwd)) return this.fail("error", { kind: "config", message: `cwd does not exist: ${cwd}` });
    const allow = req.bash?.allow ?? [];
    const deny = req.bash?.deny ?? [];
    // Rules travel in a per-call settings file outside the workspace, never in argv.
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tl-foreman-edit-"));
    const settingsFile = path.join(dir, "settings.json");
    fs.writeFileSync(settingsFile, JSON.stringify({ permissions: { allow, deny } }, null, 1));
    try {
      const editTools = allow.length > 0 ? r.caps.flags.editToolsWithShell : r.caps.flags.editTools;
      const args = [
        ...r.caps.flags.common,
        ...this.fill(r.caps.flags.edit, { settingsFile, editTools }),
        ...this.addDirs(r.caps, req),
        ...this.optional(r.caps, req),
      ];
      return await this.exec(r.exe, args, cwd, req);
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  }

  /** One flag group per extra directory, never a variadic list (a variadic flag would swallow what follows it). */
  private addDirs(caps: CapabilityEntry, req: RunRequest): string[] {
    const tpl = caps.flags.addDir;
    if (!tpl || !req.addDirs) return [];
    return req.addDirs.flatMap((d) => this.fill(tpl, { dir: path.resolve(d) }));
  }

  private optional(caps: CapabilityEntry, req: RunRequest): string[] {
    const out: string[] = [];
    if (req.model) out.push(...this.fill(caps.flags.model, { model: req.model }));
    if (req.schema) out.push(...this.fill(caps.flags.schema, { schema: JSON.stringify(req.schema) }));
    return out;
  }

  private async exec(exe: string, args: string[], cwd: string, req: RunRequest, stdin?: string): Promise<RunResult> {
    const { env } = this.childEnv(req.mode);
    const timeoutMs = Math.max(MIN_TIMEOUT_MS, Math.floor(req.timeoutMs));
    const proc = await this.spawn({ exe, args: [...this.preArgs, ...args], cwd, env, stdin: stdin ?? req.prompt, timeoutMs });
    return this.normalize(proc, args, cwd, req, timeoutMs);
  }

  /** Every dialect of the answer channel ends up as one RunResult. Public for tests with recorded envelopes. */
  normalize(proc: RunProcessResult, args: string[], cwd: string, req: RunRequest, timeoutMs: number): RunResult {
    const { events, noiseLines } = parseEnvelope(proc.stdout);
    const init = events.find((e) => e.type === "system" && e.subtype === "init");
    const result = [...events].reverse().find((e) => e.type === "result");
    const assistants = events.filter((e) => e.type === "assistant");
    const raw = {
      adapter: "claude-cli",
      mode: req.mode,
      meta: req.meta ?? null,
      argv: args,
      cwd,
      timeoutMs,
      exitCode: proc.exitCode ?? null,
      timedOut: proc.timedOut,
      spawnError: proc.spawnError ?? null,
      noiseLines,
      stderrTail: tail(proc.stderr),
      stdoutTail: events.length === 0 ? tail(proc.stdout) : undefined,
      events,
    };
    const usage = (result?.["usage"] ?? undefined) as Record<string, unknown> | undefined;
    const num = (v: unknown): number => (typeof v === "number" && Number.isFinite(v) ? v : 0);
    const tokens =
      usage !== undefined
        ? {
            tokensIn: num(usage["input_tokens"]) + num(usage["cache_creation_input_tokens"]) + num(usage["cache_read_input_tokens"]),
            tokensOut: num(usage["output_tokens"]),
            // Observed in the result events of the 2026-11-10 real job: usage.cache_read_input_tokens.
            ...(typeof usage["cache_read_input_tokens"] === "number" ? { tokensCacheRead: num(usage["cache_read_input_tokens"]) } : {}),
          }
        : {};
    const observed: RunResult["observed"] = {};
    if (init) {
      if (Array.isArray(init["tools"])) observed.tools = (init["tools"] as unknown[]).map(String);
      if (typeof init["permissionMode"] === "string") observed.permissionMode = init["permissionMode"];
      if (typeof init["apiKeySource"] === "string") {
        observed.apiKeySource = init["apiKeySource"];
        observed.billingMode = init["apiKeySource"] === "none" ? "subscription" : "api_key";
      }
    }
    const model = typeof init?.["model"] === "string" ? (init["model"] as string) : req.model;
    const lastAssistantText = (): string | undefined => {
      for (let i = assistants.length - 1; i >= 0; i--) {
        const content = (assistants[i]?.["message"] as { content?: unknown } | undefined)?.content;
        if (Array.isArray(content)) {
          const t = content
            .filter((c): c is { type: string; text: string } => !!c && typeof c === "object" && (c as { type?: unknown }).type === "text")
            .map((c) => c.text)
            .join("");
          if (t) return t;
        }
      }
      return undefined;
    };
    const make = (outcome: RunResult["outcome"], extra: Partial<RunResult>): RunResult => ({
      ok: outcome === "ok",
      outcome,
      raw,
      durationMs: proc.durationMs,
      ...tokens,
      ...(model ? { model } : {}),
      ...(Object.keys(observed).length > 0 ? { observed } : {}),
      ...extra,
    });
    const partial = lastAssistantText();
    const withText = partial !== undefined ? { text: partial } : {};

    if (proc.spawnError) return make("error", { error: { kind: "spawn", message: proc.spawnError } });
    if (proc.timedOut) {
      return make("timeout", { ...withText, error: { kind: "exit", message: `killed by the Foreman after ${timeoutMs} ms (process tree)` } });
    }
    const errText = `${typeof result?.["result"] === "string" ? (result["result"] as string) : ""}\n${proc.stderr}`;
    if (!result) {
      if (assistants.length > 0) {
        return make("truncated", { ...withText, error: { kind: "exit", message: `the stream ended without a result event (exit ${proc.exitCode ?? "none"})` } });
      }
      if (RATE_RE.test(errText)) return make("error", { error: { kind: "rate_limit", message: tail(errText.trim(), 400) } });
      if (AUTH_RE.test(errText)) return make("refused", { error: { kind: "auth", message: tail(errText.trim(), 400) } });
      return make("error", {
        error: { kind: "exit", message: `exit ${proc.exitCode ?? "none"} with no result event: ${tail((proc.stderr || proc.stdout).trim(), 400)}` },
      });
    }
    const subtype = typeof result["subtype"] === "string" ? result["subtype"] : "";
    const stop = typeof result["stop_reason"] === "string" ? result["stop_reason"] : undefined;
    const text = typeof result["result"] === "string" ? (result["result"] as string) : partial;
    const t = text !== undefined ? { text } : {};
    if (subtype === "error_max_turns" || subtype === "error_max_budget_usd") {
      return make("truncated", { ...t, error: { kind: "exit", message: `the CLI stopped the run: ${subtype}` } });
    }
    if (result["is_error"] === true || (subtype !== "" && subtype !== "success")) {
      const msg = tail(errText.trim(), 400) || subtype || "the CLI reported an error";
      // Observed on 2.1.322: every run carries a rate_limit_event {rate_limit_info: {status, resetsAt (epoch s)}}
      // and the result has api_error_status (null on success).
      const rl = [...events].reverse().find((e) => e.type === "rate_limit_event");
      const info = rl?.["rate_limit_info"] as { status?: unknown; resetsAt?: unknown } | undefined;
      const apiStatus = result["api_error_status"];
      const limited = apiStatus === 429 || (typeof info?.status === "string" && info.status !== "allowed" && info.status !== "allowed_warning");
      if (limited || RATE_RE.test(errText)) {
        const resetsAt = info?.resetsAt;
        const retryAfterMs = typeof resetsAt === "number" ? Math.max(0, resetsAt * 1000 - Date.now()) : undefined;
        return make("error", { ...t, error: { kind: "rate_limit", message: msg, ...(retryAfterMs !== undefined ? { retryAfterMs } : {}) } });
      }
      if (apiStatus === 401 || apiStatus === 403 || AUTH_RE.test(errText)) return make("refused", { ...t, error: { kind: "auth", message: msg } });
      return make("error", { ...t, error: { kind: "api", message: msg } });
    }
    if (stop === "max_tokens" || stop === "model_context_window_exceeded") {
      return make("truncated", { ...t, error: { kind: "exit", message: `the answer stopped at ${stop}` } });
    }
    if (stop === "refusal") return make("refused", { ...t, error: { kind: "refusal", message: "the model declined to answer" } });
    if (proc.exitCode !== 0) {
      return make("error", { ...t, error: { kind: "exit", message: `exit ${proc.exitCode ?? "none"} despite a success result` } });
    }
    if (req.schema) {
      let value: unknown = result["structured_output"];
      if (value === undefined) {
        const ex = extractJson(text ?? "");
        if (!ex.ok) {
          return make(ex.looksCutOff ? "truncated" : "error", { ...t, error: { kind: "parse", message: ex.reason } });
        }
        value = ex.value;
      }
      const errs = schemaErrors(req.schema, value);
      if (errs.length > 0) return make("error", { ...t, json: value, error: { kind: "schema", message: errs.join("; ") } });
      return make("ok", { ...t, json: value });
    }
    return make("ok", t);
  }
}
