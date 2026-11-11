// The package loop: packages in dependency order, up to N at once, each in ws/<package>/.
// builder run -> verification -> (failure: report back, next round) -> merge in-scope files -> whole pack V0..V2.
// Everything that happens is an event in job.jsonl first; a kill at any line resumes from the log.
import fs from "node:fs";
import path from "node:path";
import type { Acceptance, BudgetPolicy, Cause, JobEvent, Milestone, PackageSpec } from "./events.js";
import { CHANGE_REASON_RE, JobLog, changeReason, type JobState, type PackageView } from "./joblog.js";
import type { Builder, RunResult } from "./builder/types.js";
import { deriveBashAllowlist } from "./builder/allowlist.js";
import type { Verifier, VerifyResult } from "./verifier.js";
import { BudgetGate, budgetVerdict } from "./budget.js";
import { copyDir, hashFile, listFiles, matchesAny, pruneEmptyDirs, snapshot } from "./scope.js";
import { engineWritable, promotePack, readManifest } from "./promoter.js";
import { existingText, prepareReference, referenceText, type Reference } from "./reference.js";
import { PKG_ROOT, REPO_ROOT, stripBom, toPosix } from "./paths.js";
import { CARRIED_FIELDS, MANIFEST_FILE, PACK_VERSION, acceptedCarriedFields, carriedOf, composeManifest, depClosure, dependants, manifestText, mergeCarried, type Carried } from "./manifest.js";
import { critic, replanPackages, whoOwns, DEFAULT_RUBRIC, type GenerateCall, type Generated, type PackageLine, type ReplanInput } from "./designer.js";
import { isFakeRunner, verbsFor, type RunnerVerbs } from "./verbs.js";

export class ForemanError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ForemanError";
  }
}

export interface ForemanOptions {
  jobDir: string;
  builder: Builder;
  verifier: Verifier;
  /** Packages built at once. Default 2. */
  parallel?: number;
  /** Rounds per package before it fails. Default 4 (JOB.md). */
  roundLimit?: number;
  builderTimeoutMs?: number;
  model?: string;
  budget?: BudgetPolicy;
  now?: () => Date;
  sleep?: (ms: number) => Promise<void>;
  isPlaying?: () => boolean;
  /** Text of the pack contract given to builders. Default: contracts/PACK.md. */
  packContract?: string;
  /** Promote the finished pack. Default true. */
  promote?: boolean;
  /**
   * Where a promoted pack is written: "job" (default) is <job>/promoted/<pack id>/, so a job ends `promoted` without
   * touching the engine; "engine" is <engineDir>/packs/<pack id>/, and falls back to "job" when that is not writable.
   */
  promoteTo?: "job" | "engine";
  /** Put failed packages back in the queue at round 1 before running. */
  retryFailed?: boolean;
  rateLimitRetries?: number;
  rateLimitBackoffMs?: number;
  /** Re-plans per job before it fails. Default 3 (JOB.md). */
  maxReplans?: number;
  /** Most packages a re-plan may leave in the plan (the same limit the first plan had). */
  maxPackages?: number;
  /** Test seam and override: who answers a re-plan. Default: the Planner prompt through `builder` in generate mode. */
  replanner?: (input: ReplanInput) => Promise<Generated<{ packages: PackageSpec[] }>>;
  /** Run the V5 critic on milestone captures. Default true. */
  critic?: boolean;
  /** Model for job-level generate calls made by the loop (re-plan, critic). Default: `model`. */
  plannerModel?: string;
  criticModel?: string;
  /** Milestone captures: resolution and the physics frames to render for each declared camera. */
  captureRes?: string;
  /** Fixed capture frames. Default: 25 % and 75 % of the first bot's finish frame in its last passing report (120 and 480 without one). */
  captureFrames?: number[];
  /**
   * Reference material for builders: the kernel's API.md and example packs. They are COPIED into <job>/ref/ once
   * and that copy is what a builder may read (--add-dir): the engine directory itself is never opened to a builder.
   */
  reference?: Reference;
  /**
   * The runner's verbs and options. Default: read from the runner that will be started (verbs.ts verbsFor: the
   * engine's kernel/runner/verbs.json). A missing file is an error when the run starts.
   */
  verbs?: RunnerVerbs;
  /**
   * Which optional manifest fields (footprint, params, on_leave, subject, moments) builders may write. Default: the
   * ones the engine's kernel/runner/manifest.gd names (all five for the bundled fake runner). A field the engine
   * does not accept is never asked for and is removed if a builder writes it, because lint would refuse the pack.
   */
  carriedFields?: string[];
  /**
   * N3b: how often a clock-based failure that the machine explains (the engine's reference pack fails its clock too)
   * is tried again before the round is recorded as inconclusive. Default 3.
   */
  clockRetries?: number;
  /** N3b: the pause before each of those tries, in ms; the last value repeats. Default [20000, 40000, 80000]. */
  clockPausesMs?: number[];
  /** N3b: the known-good pack the machine is measured with. Default <engine>/kernel/examples/pack_min. */
  referencePack?: string;
  /**
   * N3b: the reference pack's frame p99 (ms) from which the machine counts as busy even though the reference pack
   * still passed. Default 2. Measured in the real hockey job: a calm run has p99 about 1.7 x p50 (1.0 ms against
   * 0.6 ms on a 289-node pack); under load p50 stays and p99 jumps to 13..33 ms. The reference pack is tiny, so it
   * rarely breaks the 8 ms budget itself: its p99 is the gauge.
   */
  referenceBusyP99Ms?: number;
  /**
   * N3b: the reference pack's slowest single tick (ms, `tick_ms_max` of its smoke report) from which the machine
   * counts as busy. Default 2. Measured on the real runner 2026-11-11 02:04 with pack_min: 0.10 ms in two runs,
   * 4.46 ms in the one run that another process cut into. The reference run is short (about 1.3 s), so one
   * interrupted tick is the sensitive sign; its p99 moves much less than a big pack's.
   */
  referenceBusyTickMs?: number;
  /** N3 item 3: compare kit use and bypasses before and after every round. Default true (`--no-kit-gate` turns it off). */
  kitGate?: boolean;
  /** Test seam: called after every durable append; throwing simulates a kill at that exact event. */
  afterAppend?: (ev: JobEvent) => void;
  onEvent?: (ev: JobEvent) => void;
}

/** Causes after which a failed package goes back to the Planner (a refusal, a budget stop or a cancel do not). */
const REPLAN_CAUSES: Cause[] = ["verify_failed", "builder_error", "builder_timeout", "builder_truncated", "no_visible_change", "kit_regression"];

/** Fixed starts of the `detail` of a package sent back after its merge; the feedback and the resume read them. */
export const NO_VISIBLE_CHANGE = "NO VISIBLE CHANGE";
export const CRITIC_ROUND = "critic (V5) NOT ok, one extra round";
/** N3: fixed starts of the `detail` of a package that goes back to work after it was finished. */
export const CHANGE_ROUND = "CHANGE REQUEST";
export const DEP_CHANGED = "DEPENDENCY CHANGED";
export const KIT_REGRESSION = "KIT REGRESSION";
/**
 * The start of a `note` the Foreman writes itself (a fallback of the critic's round, a stated kit reason, the
 * pictures after a change). Builders' own notes (their DEVIATIONS) do not start with it; only those are handed to
 * the builders of dependent packages.
 */
export const FOREMAN_NOTE = "[foreman] ";

/** The figures a round may not make worse without saying why (N3 item 3). */
export interface KitFigures {
  /** `composability.bypasses.length` of the pack's lint report: places that do by hand what a primitive exists for. */
  bypasses: number;
  /**
   * Kit parts used, counted by the Foreman because the lint report has no such figure: `"kind": "..."` entries in
   * the pack's data/*.json (layout props and actors) plus `TLKit.` / `TLRigs.` call sites in its scripts.
   */
  kitUse: number;
}

/** Counts kit use in a pack directory (see KitFigures.kitUse). Comments in scripts do not count. */
export function countKitUse(packDir: string): number {
  let n = 0;
  for (const f of listFiles(packDir)) {
    const abs = path.join(packDir, f);
    if (f.startsWith("data/") && f.endsWith(".json")) n += (fs.readFileSync(abs, "utf8").match(/"kind"\s*:\s*"/g) ?? []).length;
    else if (f.endsWith(".gd") && !f.startsWith("tests/")) {
      for (const line of fs.readFileSync(abs, "utf8").split(/\r?\n/)) n += (line.replace(/#.*$/, "").match(/\bTL(Kit|Rigs)\s*\./g) ?? []).length;
    }
  }
  return n;
}

/** True when a builder's DEVIATIONS text says why kit use fell or a bypass was added (a `KIT:` line, or plain words). */
export function statesKitReason(deviations: string | undefined, hints: string[] = []): boolean {
  if (!deviations) return false;
  if (/^\s*[-*]?\s*\**KIT\**\s*:/im.test(deviations)) return true;
  if (/\b(kit|bypass\w*|TLKit|TLRigs|by hand|hand[- ]built|hand[- ]made|kernel primitive)\b/i.test(deviations)) return true;
  return hints.some((h) => h.length >= 4 && deviations.toLowerCase().includes(h.toLowerCase()));
}

/** A verification result with what the Foreman concluded on top: a kit regression, or "machine busy, no verdict". */
type Verified = VerifyResult & { inconclusive?: string };
type GateFailure = Verified & { kitRegression?: string };

/** N3b: the fixed start of the `detail` of a round whose clock-based failure was the machine's, not the pack's. */
export const MACHINE_BUSY = "inconclusive: machine busy";
/** N3b: the start of the note (after FOREMAN_NOTE) that says a repeated clock failure is the pack's own. */
export const NOT_LOAD = "not machine load";

/**
 * The deviations a builder states in its answer: everything under a line `DEVIATIONS:` up to a `QUESTION:` line or
 * the end. "none" (or nothing) means there are none.
 */
export function parseDeviations(text: string | undefined): string | undefined {
  if (!text) return undefined;
  const lines = text.split(/\r?\n/);
  let start = -1;
  let first = "";
  for (let i = 0; i < lines.length; i++) {
    const m = /^[\s#>*_-]*DEVIATIONS\**\s*:?\**\s*(.*)$/.exec(lines[i] as string);
    if (m) {
      start = i;
      first = m[1] ?? "";
    }
  }
  if (start < 0) return undefined;
  const body = [first];
  for (let i = start + 1; i < lines.length; i++) {
    if (/^\s*QUESTION:/.test(lines[i] as string)) break;
    body.push(lines[i] as string);
  }
  const out = body.join("\n").trim();
  if (out === "" || /^[-*\s]*(none|no deviations?|nothing|n\/a)[.!]?\s*$/i.test(out)) return undefined;
  return clip(out, 4000);
}

const BUILDER_CAUSE: Record<Exclude<RunResult["outcome"], "ok">, Cause> = {
  timeout: "builder_timeout",
  truncated: "builder_truncated",
  error: "builder_error",
  refused: "builder_error",
};

/** Whole-pack verification after every merge: V0 to V2. */
const PACK_GATE: Acceptance[] = [
  { level: "V1", verb: "lint", args: [] },
  { level: "V2", verb: "smoke", args: [] },
];

function render(template: string, vars: Record<string, string>): string {
  return template.replace(/\{\{(\w+)\}\}/g, (_m, k: string) => vars[k] ?? "");
}

function clip(s: string, n: number): string {
  return s.length <= n ? s : `${s.slice(0, n)}\n... (${s.length - n} more characters cut)`;
}

function listDetail(label: string, files: string[]): string {
  const shown = files.slice(0, 20).join(", ");
  return `${label}: ${shown}${files.length > 20 ? ` (+${files.length - 20} more)` : ""}`;
}

/**
   * What a builder did with its tools, read from the adapter's envelope (claude-cli stream-json events): how often
   * each tool was used, the shell commands it ran, and what the permission system refused. Evidence for the report
   * and the site, never an input to a verdict.
   */
export function builderConduct(raw: unknown): { tools: Record<string, number>; bash: string[]; denials: string[]; notes: string[] } {
  const out = { tools: {} as Record<string, number>, bash: [] as string[], denials: [] as string[], notes: [] as string[] };
  const events = (raw as { events?: unknown } | null)?.events;
  if (!Array.isArray(events)) return out;
  for (const ev of events as Record<string, unknown>[]) {
    if (ev?.["type"] === "assistant") {
      const content = (ev["message"] as { content?: unknown } | undefined)?.content;
      if (!Array.isArray(content)) continue;
      for (const c of content as Record<string, unknown>[]) {
        if (c?.["type"] !== "tool_use" || typeof c["name"] !== "string") continue;
        out.tools[c["name"]] = (out.tools[c["name"]] ?? 0) + 1;
        const cmd = (c["input"] as { command?: unknown } | undefined)?.command;
        if (c["name"] === "Bash" && typeof cmd === "string") out.bash.push(cmd.length > 600 ? `${cmd.slice(0, 600)}...` : cmd);
      }
    } else if (ev?.["type"] === "result" && Array.isArray(ev["permission_denials"])) {
      for (const d of ev["permission_denials"] as Record<string, unknown>[]) {
        const input = d?.["tool_input"] as Record<string, unknown> | undefined;
        const what = typeof input?.["command"] === "string" ? input["command"] : typeof input?.["file_path"] === "string" ? input["file_path"] : "";
        out.denials.push(`${String(d?.["tool_name"] ?? "?")}: ${String(what).slice(0, 300)}`);
      }
    }
  }
  return out;
}

/**
 * True when a failed verification could be the machine's load and not the pack: the watchdog tripped on a time
 * limit (not on its frame-counted or error-counted reasons), or the only failed check is the physics time budget.
 */
export function restsOnAClock(vr: VerifyResult): boolean {
  const r = vr.report;
  if (!r || vr.flags.length > 0 || vr.ok) return false;
  const failed = r.checks.filter((c) => !c.ok);
  if (r.outcome === "watchdog") {
    const detail = failed.find((c) => c.id === "smoke.watchdog")?.detail ?? "";
    return /tick_timeout|setup_timeout|did not return/.test(detail);
  }
  return failed.length > 0 && failed.every((c) => c.id === "invariants.frame_budget");
}

/**
 * When the ONLY failed check is the frame budget and the median frame alone is over half of it, the words that say
 * so; undefined otherwise. Such a pack is slow in every frame, which load does not explain.
 */
export function medianOverHalfBudget(vr: VerifyResult): string | undefined {
  const failed = (vr.report?.checks ?? []).filter((c) => !c.ok);
  if (vr.report?.outcome === "watchdog" || failed.length === 0 || !failed.every((c) => c.id === "invariants.frame_budget")) return undefined;
  const p50 = (vr.report?.["metrics"] as { frame_ms_p50?: unknown } | undefined)?.frame_ms_p50;
  const budget = Number(/budget (\d+(?:\.\d+)?) ms/.exec(failed[0]?.detail ?? "")?.[1] ?? "8");
  if (typeof p50 !== "number" || !(p50 > budget / 2)) return undefined;
  return `The median frame alone is ${p50} ms, over half of the ${budget} ms budget: the pack is slow in every frame, which machine load does not explain`;
}

/** The words of a clock-based failure: the failed checks' details (the p99 figure, the watchdog's reason). */
export function clockDetail(vr: VerifyResult): string {
  const failed = (vr.report?.checks ?? []).filter((c) => !c.ok && (c.id === "invariants.frame_budget" || c.id === "smoke.watchdog"));
  return failed.map((c) => c.detail ?? c.id).join("; ") || vr.summary;
}

/**
 * True when the runner exited by itself with NO output at all (not a timeout, not a spawn failure): it was killed
 * from outside or crashed before its first line. That is not a verdict about the pack.
 */
export function diedSilently(vr: VerifyResult): boolean {
  return !vr.ok && vr.flags.includes("stdout_not_json") && !vr.flags.includes("runner_timeout") && !vr.flags.includes("spawn_error") && vr.summary.includes('stdout is not JSON: ""');
}

export class Foreman {
  private readonly o: Required<Pick<ForemanOptions, "parallel" | "roundLimit" | "builderTimeoutMs" | "promote" | "rateLimitRetries" | "rateLimitBackoffMs" | "maxReplans">> &
    ForemanOptions;
  /** Milestones are worked one at a time (captures and the critic take seconds; the merge chain waits for them). */
  private milestoneBusy: Promise<void> = Promise.resolve();
  private log!: JobLog;
  private gate!: BudgetGate;
  private mergeChain: Promise<unknown> = Promise.resolve();
  private verbs: RunnerVerbs | undefined;
  /** N3b: packages whose round ended inconclusive (machine busy) in THIS run: not started again until the next run. */
  private readonly busyThisRun = new Set<string>();
  private readonly jobDir: string;
  private readonly template: string;
  private readonly packContract: string;

  constructor(opts: ForemanOptions) {
    this.o = {
      parallel: 2,
      roundLimit: 4,
      builderTimeoutMs: 30 * 60_000,
      promote: true,
      rateLimitRetries: 5,
      rateLimitBackoffMs: 60_000,
      maxReplans: 3,
      ...opts,
    };
    this.jobDir = path.resolve(opts.jobDir);
    this.template = fs.readFileSync(path.join(PKG_ROOT, "prompts", "builder.md"), "utf8");
    this.packContract = opts.packContract ?? fs.readFileSync(path.join(REPO_ROOT, "contracts", "PACK.md"), "utf8");
  }

  private get s(): JobState {
    return this.log.state;
  }
  private dir(...parts: string[]): string {
    return path.join(this.jobDir, ...parts);
  }
  private rel(abs: string): string {
    return toPosix(path.relative(this.jobDir, abs));
  }
  private append(body: Parameters<JobLog["append"]>[0]): JobEvent {
    const ev = this.log.append(body);
    this.o.onEvent?.(ev);
    return ev;
  }
  /** Report and transcript names carry the next seq, so a re-run never overwrites what an earlier event points at. */
  private reportPath(stem: string): string {
    return this.dir("reports", `${stem}-s${this.s.lastSeq + 1}.json`);
  }

  /** Runs (or resumes) the job to its end. Returns the final derived state. */
  async run(): Promise<JobState> {
    this.log = JobLog.open(this.jobDir, {
      ...(this.o.now ? { now: this.o.now } : {}),
      ...(this.o.afterAppend ? { afterAppend: this.o.afterAppend } : {}),
    });
    try {
      return await this.runOpen();
    } finally {
      this.log.close();
    }
  }

  private async runOpen(): Promise<JobState> {
    if (this.s.plan.length === 0) throw new ForemanError(`job ${this.s.job} has no plan_set yet (run \`foreman plan\`)`);
    // A finished job stays finished, unless a change request is waiting (N3): then it goes back to running.
    const waiting = this.s.changes.some((c) => c.state === "pending") || this.s.order.some((id) => this.pkg(id).state !== "promoted");
    if (this.s.jobState?.state === "done" && !waiting) return this.s;
    // A cancelled job stays cancelled unless the caller explicitly asks for its failed packages to be retried.
    if (this.s.jobState?.state === "cancelled" && !this.o.retryFailed) return this.s;
    // The runner's option list comes from the engine. Without it nothing is started and nothing is written.
    this.verbs = this.o.verbs ?? verbsFor(this.o.verifier.location);
    for (const d of ["pack", "ws", "reports", "captures"]) fs.mkdirSync(this.dir(d), { recursive: true });
    const now = this.o.now ?? (() => new Date());
    const sleep = this.o.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
    const before = this.s.jobState;
    this.append({
      type: "job_state",
      state: "running",
      reason: before ? (before.state === "done" ? "reopened by a change request (was done)" : `resumed (was ${before.state})`) : "started",
    });

    // The player's budget policy lives in the log: one given now is recorded, one recorded earlier still holds.
    const logged = this.s.budget;
    const isReal = (p: BudgetPolicy): boolean => p.kind !== "tokens_per_hour" || p.limit !== undefined;
    const policy = this.o.budget ?? (logged && isReal(logged.policy) ? logged.policy : undefined);
    const deps = { now, sleep, ...(this.o.isPlaying ? { isPlaying: this.o.isPlaying } : {}) };
    if (this.o.budget && JSON.stringify(logged?.policy) !== JSON.stringify(this.o.budget)) {
      this.append({ type: "budget", policy: this.o.budget, state: "running", reason: "policy set" });
    } else if (logged?.state === "paused" && budgetVerdict(policy, this.s, deps).allowed) {
      // Killed while paused, and the reason for the pause is gone: say so, or the log would stay paused for ever.
      this.append({ type: "budget", policy: logged.policy, state: "running", reason: "allowed again after a restart" });
    }
    this.gate = new BudgetGate(policy, this.log, deps);

    // pack/ is state on disk that the log cannot rebuild: if merged files are gone, continuing would be a lie.
    const lost: string[] = [];
    for (const id of this.s.order) {
      const p = this.pkg(id);
      if (p.state !== "promoted") continue;
      for (const f of p.mergedFiles ?? []) if (!fs.existsSync(this.dir("pack", f))) lost.push(`${id}: ${f}`);
    }
    if (lost.length > 0) {
      this.endJob("failed", clip(`pack/ no longer holds files the log says were merged (${lost.join(", ")}); restore pack/ or start a new job`, 400));
      return this.s;
    }
    for (const id of this.s.order) {
      if (!this.pkg(id).announced) this.append({ type: "package_state", package: id, state: "queued", round: 1 });
    }
    if (this.o.retryFailed) {
      for (const id of this.s.order) {
        const p = this.pkg(id);
        if (p.state === "failed" || (p.state === "blocked" && p.cause === "dependency")) {
          this.append({ type: "package_state", package: id, state: "queued", round: 1, detail: "retry requested" });
        }
      }
    }

    // Billing is in the log before the first builder_run, from the probe, in the real environment.
    const probe = await this.o.builder.probe();
    const b = this.s.billing;
    if (!b || b.adapter !== probe.adapter || b.mode !== probe.billing.mode || b.evidence !== probe.billing.evidence) {
      this.append({ type: "billing", adapter: probe.adapter, mode: probe.billing.mode, evidence: probe.billing.evidence });
    }
    if (!probe.ok) {
      this.endJob("failed", `builder ${probe.adapter} is not available: ${probe.notes.join("; ")}`);
      return this.s;
    }

    this.prepareReference();
    this.requeueReopened();
    await this.applyChangeRequests();

    for (;;) {
      // A milestone whose last merge is in the log but whose `milestone` event is not (a kill in between).
      await this.catchUpMilestones();
      this.requeueReopened();
      this.requeueNoVisibleChange();
      await this.schedule();
      const views = this.s.order.map((id) => this.pkg(id));
      if (views.every((p) => p.state === "promoted")) {
        await this.catchUpMilestones();
        await this.finish();
        break;
      }
      const held = (p: PackageView): boolean => p.state === "blocked" && (p.cause === "question" || p.cause === "machine_busy");
      if (views.some(held) && !views.some((p) => p.state === "failed")) {
        const waiting = views.filter((p) => p.state === "blocked" && p.cause === "question").map((p) => p.id);
        const busy = views.filter((p) => p.state === "blocked" && p.cause === "machine_busy").map((p) => p.id);
        const reasons = [waiting.length > 0 ? `waiting for answers: ${waiting.join(", ")}` : "", busy.length > 0 ? `machine busy: the verification of ${busy.join(", ")} was inconclusive (the engine's reference pack broke its time limits too); resume when the machine is free, the builder is not run again` : ""];
        this.append({ type: "job_state", state: "paused", reason: reasons.filter(Boolean).join("; ") });
        break;
      }
      // Failed after the round limit: back to the Planner, once per package, at most maxReplans times per job.
      const re = await this.tryReplan();
      if (re.replanned) continue;
      const failed = views.filter((p) => p.state === "failed").map((p) => `${p.id} (${p.cause ?? "?"})`);
      const blocked = views.filter((p) => p.state === "blocked").map((p) => `${p.id} (${p.cause ?? "?"})`);
      this.endJob("failed", clip([failed.length ? `failed: ${failed.join(", ")}` : "", blocked.length ? `blocked: ${blocked.join(", ")}` : "", re.reason].filter(Boolean).join("; "), 600));
      break;
    }
    return this.s;
  }

  // ---------- reference material ----------

  private refDir(): string {
    return this.dir("ref");
  }

  /** Copies the reference (API, law tables, examples, seeds, kit/rig/style documents) into <job>/ref/ (once). */
  private prepareReference(): void {
    prepareReference(this.refDir(), this.o.reference);
  }

  private referenceText(): string {
    return referenceText(this.refDir());
  }

  private kernelApiText(): string | undefined {
    const api = path.join(this.refDir(), "API.md");
    return fs.existsSync(api) ? fs.readFileSync(api, "utf8") : undefined;
  }

  // ---------- re-plan on failure ----------

  private logGenerateCalls(calls: GenerateCall[], model: string | undefined): void {
    for (const c of calls) {
      const file = this.dir("reports", `${c.role}-a${c.attempt}-s${this.s.lastSeq + 1}.json`);
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(
        file,
        JSON.stringify(
          {
            schema: "tl.foreman.transcript/1",
            adapter: this.o.builder.name,
            role: c.role,
            attempt: c.attempt,
            mode: "generate",
            prompt: c.prompt,
            problems: c.problems,
            result: { ok: c.result.ok, outcome: c.result.outcome, text: c.result.text, json: c.result.json, error: c.result.error, tokensIn: c.result.tokensIn, tokensOut: c.result.tokensOut, durationMs: c.result.durationMs, observed: c.result.observed },
            raw: c.result.raw,
          },
          null,
          1,
        ) + "\n",
      );
      this.append({
        type: "builder_run",
        adapter: this.o.builder.name,
        mode: "generate",
        model: c.result.model ?? model ?? "default",
        outcome: c.result.outcome,
        durationMs: Math.max(0, Math.round(c.result.durationMs)),
        ...(c.result.tokensIn !== undefined ? { tokensIn: c.result.tokensIn } : {}),
        ...(c.result.tokensOut !== undefined ? { tokensOut: c.result.tokensOut } : {}),
        ...(c.result.tokensCacheRead !== undefined ? { tokensCacheRead: c.result.tokensCacheRead } : {}),
        transcript: this.rel(file),
      });
    }
  }

  /**
   * JOB.md: a package that fails after the round limit goes back to the Planner once (a `replan` covering it and
   * its dependants); at most `maxReplans` re-plans per job. Returns why nothing was re-planned when that is the case.
   */
  private async tryReplan(): Promise<{ replanned: boolean; reason: string }> {
    const s = this.s;
    const views = s.order.map((id) => this.pkg(id));
    const allFailed = views.filter((p) => p.state === "failed");
    if (allFailed.length === 0) return { replanned: false, reason: "" };
    const cannot = allFailed.filter((p) => !REPLAN_CAUSES.includes(p.cause as Cause) || (p.detail ?? "").startsWith("builder refused"));
    if (cannot.length > 0) return { replanned: false, reason: `no re-plan: ${cannot.map((p) => `${p.id} (${p.cause ?? "?"})`).join(", ")} is not a failure a new plan can fix` };
    const resumed = s.pendingReplan !== undefined;
    if (!resumed) {
      const again = allFailed.filter((p) => s.replanned.includes(p.id));
      if (again.length > 0) return { replanned: false, reason: `no re-plan: ${again.map((p) => p.id).join(", ")} already went back to the Planner once` };
      if (s.replans >= this.o.maxReplans) return { replanned: false, reason: `no re-plan: the limit of ${this.o.maxReplans} re-plan(s) for this job is used up` };
    }
    if (!s.brief || !s.sentence || !s.packId || !s.title) return { replanned: false, reason: "no re-plan: the log has no brief" };

    const failedIds = new Set(allFailed.map((p) => p.id));
    const depIds = new Set(allFailed.flatMap((p) => dependants(s.plan, p.id)).filter((id) => !failedIds.has(id) && this.pkg(id).state !== "promoted"));
    const kept = s.plan.filter((p) => !failedIds.has(p.id) && !depIds.has(p.id));
    const input: ReplanInput = {
      sentence: s.sentence,
      packId: s.packId,
      title: s.title,
      brief: s.brief,
      packContract: this.packContract,
      ...(this.kernelApiText() !== undefined ? { kernelApi: this.kernelApiText() as string } : {}),
      existing: existingText(this.refDir()),
      builderTimeoutMs: this.o.builderTimeoutMs,
      kept,
      failed: allFailed.map((p) => {
        const report = p.lastVerify && !p.lastVerify.ok ? this.readClipped(this.dir(p.lastVerify.report), 4000) : undefined;
        return { spec: this.spec(p.id), cause: p.cause ?? "?", detail: p.detail ?? "", ...(report !== undefined ? { lastReport: report } : {}) };
      }),
      dependants: s.plan.filter((p) => depIds.has(p.id)),
    };
    const model = this.o.plannerModel ?? this.o.model;
    const res = this.o.replanner
      ? await this.o.replanner(input)
      : await replanPackages(this.o.builder, input, {
          ...(model ? { model } : {}),
          ...(this.o.maxPackages !== undefined ? { maxPackages: this.o.maxPackages } : {}),
          verbs: this.verbs ?? verbsFor(this.o.verifier.location),
        });
    this.logGenerateCalls(res.calls, model);
    if (!res.ok) return { replanned: false, reason: `re-plan failed: ${clip(res.reason, 300)}` };

    const fresh = res.value.packages;
    const oldIds = new Set(s.order);
    const freshIds = new Set(fresh.map((p) => p.id));
    if (!resumed) {
      this.append({
        type: "replan",
        reason: clip(`failed after ${this.o.roundLimit} round(s): ${allFailed.map((p) => `${p.id} (${p.cause ?? "?"})`).join(", ")}`, 300),
        added: [...freshIds].filter((x) => !oldIds.has(x)),
        removed: [...failedIds, ...depIds].filter((x) => !freshIds.has(x)),
        changed: [...freshIds].filter((x) => oldIds.has(x)),
      });
    }
    this.append({ type: "plan_set", packages: [...kept, ...fresh] });
    for (const p of fresh) this.append({ type: "package_state", package: p.id, state: "queued", round: 1, detail: "replanned" });
    return { replanned: true, reason: "" };
  }

  private readClipped(file: string, n: number): string | undefined {
    try {
      return clip(fs.readFileSync(file, "utf8"), n);
    } catch {
      return undefined;
    }
  }

  private pkg(id: string): PackageView {
    const p = this.s.packages[id];
    if (!p) throw new ForemanError(`unknown package ${id}`);
    return p;
  }
  private spec(id: string): PackageSpec {
    const p = this.s.plan.find((x) => x.id === id);
    if (!p) throw new ForemanError(`unknown package ${id}`);
    return p;
  }

  // ---------- scheduling ----------

  private async schedule(): Promise<void> {
    const running = new Map<string, Promise<void>>();
    let fatal: unknown;
    const dead = (p: PackageView): boolean => p.state === "failed" || (p.state === "blocked" && p.cause === "dependency");
    for (;;) {
      if (fatal === undefined) {
        // A package whose dependency can no longer be built is blocked, and says which one.
        let changed = true;
        while (changed) {
          changed = false;
          for (const id of this.s.order) {
            const p = this.pkg(id);
            if (running.has(id) || p.state === "promoted" || dead(p)) continue;
            const bad = p.deps.find((d) => dead(this.pkg(d)));
            if (bad !== undefined) {
              this.append({ type: "package_state", package: id, state: "blocked", round: p.round, cause: "dependency", detail: `depends on ${bad}, which is ${this.pkg(bad).state}` });
              changed = true;
            }
          }
        }
        for (const id of this.s.order) {
          if (running.size >= this.o.parallel) break;
          const p = this.pkg(id);
          if (running.has(id) || p.state === "promoted" || p.state === "failed") continue;
          if (p.state === "blocked" && p.cause === "question" && p.openQuestion !== undefined) continue;
          if (this.busyThisRun.has(id)) continue;
          if (!p.deps.every((d) => this.pkg(d).state === "promoted")) continue;
          const task = this.runPackage(id)
            .catch((e: unknown) => {
              if (fatal === undefined) fatal = e;
            })
            .finally(() => {
              running.delete(id);
            });
          running.set(id, task);
        }
      }
      if (running.size === 0) break;
      await Promise.race(running.values());
    }
    if (fatal !== undefined) throw fatal;
  }

  // ---------- one package ----------

  private wsDir(id: string): string {
    return this.dir("ws", id);
  }
  private baselineFile(id: string): string {
    return this.dir("ws", `${id}.baseline.json`);
  }

  /** Plan-order specs of the given package ids. */
  private specsOf(ids: Set<string>): PackageSpec[] {
    return this.s.plan.filter((p) => ids.has(p.id));
  }
  /**
   * The packages whose files are in pack/: the promoted ones, and one that was merged and then sent back for another
   * round (no visible change, the critic's extra round). Its files stay in pack/ until its next merge, so its
   * registers stay in the manifest too; otherwise another package merging meanwhile would be verified against a
   * manifest that does not match the files.
   */
  private promotedIds(): Set<string> {
    return new Set(this.s.order.filter((x) => this.pkg(x).state === "promoted" || (this.pkg(x).mergedFiles ?? []).length > 0));
  }

  /**
   * A package that was merged, sent back, and then failed for good: its files leave pack/ again (scopes are
   * disjoint, so every file it merged is its own) and the manifest is composed without it. Logged as a `merge`
   * with no files and everything in `removed`. pack/ is then what it was before the package's first merge.
   */
  private unmerge(id: string): void {
    const files = this.pkg(id).mergedFiles ?? [];
    if (files.length === 0) return;
    const packDir = this.dir("pack");
    for (const f of files) fs.rmSync(path.join(packDir, f), { force: true });
    pruneEmptyDirs(packDir);
    this.append({ type: "merge", package: id, files: [], removed: files });
    fs.mkdirSync(packDir, { recursive: true });
    fs.writeFileSync(path.join(packDir, MANIFEST_FILE), this.packManifestText());
  }
  /**
   * The pack's identity. The version is 0.1.0 until the first promotion and 0.1.<n> after the n-th: a change request
   * on a finished job therefore builds, verifies and promotes a pack with a new version (N3).
   */
  private jobIdentity(): { packId: string; title: string; version: string } {
    const n = this.s.promotions.length;
    const version = n === 0 ? PACK_VERSION : PACK_VERSION.replace(/\d+$/, String(n));
    return { packId: this.s.packId ?? "game.unnamed", title: this.s.title ?? this.s.packId ?? "Untitled", version };
  }

  // ---------- the manifest fields a builder owns (PACK.md, 2026-11-11): footprint, params, on_leave, subject, moments ----------

  private readText(file: string): string | undefined {
    try {
      return fs.readFileSync(file, "utf8");
    } catch {
      return undefined;
    }
  }
  private acceptedSet: Set<string> | undefined;
  /** The optional manifest fields this engine accepts (see ForemanOptions.carriedFields). */
  private accepted(): Set<string> {
    this.acceptedSet ??= new Set(this.o.carriedFields ?? (isFakeRunner(this.o.verifier.location) ? [...CARRIED_FIELDS] : acceptedCarriedFields(this.o.verifier.location.engineDir)));
    return this.acceptedSet;
  }
  private carried(text: string | undefined): Carried {
    const all = carriedOf(text);
    const ok = this.accepted();
    return Object.fromEntries(Object.entries(all).filter(([k]) => ok.has(k))) as Carried;
  }
  /** The paragraph of the builder prompt about the optional manifest fields: only what this engine accepts. */
  private optionalFieldsText(): string {
    const ok = this.accepted();
    const dataRule =
      "Keep every value a player might want to tune (a speed, a size, a count, a time or score limit, a difficulty, a colour strength) in a JSON file of yours under `data/` and read it through the kernel (`ctx.read_json`); do NOT write such values as constants in a script.";
    if (ok.size === 0) {
      return [
        "**Values a player may tune.** " + dataRule,
        "The engine you are verified with does not accept the optional manifest fields (`params`, `footprint`, `on_leave`, `subject`, `moments`) yet: do NOT add them to `pack.json`, lint would refuse the pack. Instead end your answer's file list with one line per tunable value: `TUNABLE: <data file> <dotted path> <min> <max> <step> <label>`.",
      ].join("\n");
    }
    const lines = [
      `There is ONE exception: ${ok.size === 1 ? "one optional field" : `${ok.size} optional fields`} of \`pack.json\` ${ok.size === 1 ? "is" : "are"} yours to write (${[...ok].map((k) => `\`${k}\``).join(", ")}), and the Foreman carries ${ok.size === 1 ? "it" : "them"} through unchanged (it puts back everything else). Add ${ok.size === 1 ? "it" : "them"} to the \`pack.json\` in your working directory; do not touch the other keys. The shape is in the pack contract below (last section) and lint checks it:`,
    ];
    if (ok.has("params")) {
      lines.push(
        "- `params`: **declare what a player may tune.** " +
          dataRule +
          ' For each such value add one entry `{"name", "file", "path", "min", "max", "step", "label"}`: `file` is the JSON file under `data/`, `path` the dotted path of the value in it, `label` a few plain words for a slider. Three to eight good entries are better than every number you have. Add your entries to the list that is there; never remove another package\'s entries.',
      );
    } else lines.push("- " + dataRule + " (This engine does not take `params` in the manifest yet: do not write that key.)");
    const rest = (["subject", "moments", "footprint", "on_leave"] as const).filter((k) => ok.has(k));
    const what: Record<string, string> = {
      subject: "`subject` (the node under the pack's `World` that a picture of this game is about)",
      moments: "`moments` (the frames or events worth a picture)",
      footprint: "`footprint` (the ground the game needs)",
      on_leave: "`on_leave` (what the game does when the player walks away)",
    };
    if (rest.length > 0) lines.push(`- ${rest.map((k) => what[k]).join(", ")}: write ${rest.length === 1 ? "it" : "them"} when your package is the one that knows (usually the root package).`);
    const no = CARRIED_FIELDS.filter((k) => !ok.has(k));
    if (no.length > 0) lines.push(`Do NOT write ${no.map((k) => `\`${k}\``).join(", ")}: this engine's manifest check does not accept ${no.length === 1 ? "it" : "them"} yet.`);
    return lines.join("\n");
  }
  private carriedBaseFile(id: string): string {
    return this.dir("ws", `${id}.carried.json`);
  }
  /** The carried fields pack/ holds now. */
  private packCarried(): Carried {
    return this.carried(this.readText(this.dir("pack", MANIFEST_FILE)));
  }
  /** The carried fields the package's workspace started with (written when the workspace was cut or refreshed). */
  private carriedBase(id: string): Carried {
    return this.carried(this.readText(this.carriedBaseFile(id)));
  }
  /**
   * The carried fields as the builder left them in its workspace's pack.json. A manifest that no longer parses (or
   * was deleted) gives the fields the workspace started with: a broken file must not lose another package's params.
   */
  private wsCarried(id: string): Carried {
    const text = this.readText(path.join(this.wsDir(id), MANIFEST_FILE));
    if (text === undefined) return fs.existsSync(this.wsDir(id)) ? this.carriedBase(id) : this.packCarried();
    try {
      JSON.parse(stripBom(text));
    } catch {
      return this.carriedBase(id);
    }
    return this.carried(text);
  }

  /**
   * The manifest a package's workspace is verified with: the package itself plus everything it depends on (composed
   * by the Foreman), plus the five optional fields exactly as the builder wrote them. The composed part does not
   * depend on what else happened to be merged when the workspace was cut, so it is the same after a resume.
   */
  private wsManifestText(id: string, carried: Carried = this.wsCarried(id)): string {
    const ids = depClosure(this.s.plan, id);
    for (const x of this.wsMembers(id)) ids.add(x);
    return manifestText(composeManifest(this.jobIdentity(), this.specsOf(ids), carried));
  }

  private membersFile(id: string): string {
    return this.dir("ws", `${id}.members.json`);
  }
  /**
   * N3b (defect 1 of the real hockey job): the packages whose merged files a workspace HOLDS, besides the package's
   * own dependencies. A workspace is a copy of the whole pack/, so it also holds the files of packages that merely
   * merged earlier (a sibling; for a re-opened root: its dependants). Their registrations belong in the manifest the
   * workspace is verified with, or lint refuses their scripts ("uses 'TLAudio' but the manifest does not declare the
   * capability 'audio'"). The list is written when the workspace is cut or refreshed, so it is the same after a
   * resume. Without the file (a workspace from before this fix): every package of which a merged file is present.
   */
  private wsMembers(id: string): string[] {
    const known = new Set(this.s.order);
    try {
      const list = JSON.parse(fs.readFileSync(this.membersFile(id), "utf8")) as unknown;
      if (Array.isArray(list)) return list.filter((x): x is string => typeof x === "string" && known.has(x) && x !== id);
    } catch {
      /* no list: derive it from the files */
    }
    const ws = this.wsDir(id);
    if (!fs.existsSync(ws)) return [...this.promotedIds()].filter((x) => x !== id);
    return this.s.order.filter((x) => x !== id && (this.pkg(x).mergedFiles ?? []).some((f) => fs.existsSync(path.join(ws, f))));
  }
  private writeMembers(id: string): void {
    fs.mkdirSync(this.dir("ws"), { recursive: true });
    fs.writeFileSync(this.membersFile(id), JSON.stringify([...this.promotedIds()].filter((x) => x !== id)) + "\n");
  }
  /**
   * The manifest of pack/ once `id` is merged: every promoted package plus this one, with the optional fields of
   * pack/ and this package's changes to them (three-way, so another package's params survive a stale workspace).
   */
  private packManifestText(plus?: string): string {
    const ids = this.promotedIds();
    if (plus !== undefined) ids.add(plus);
    const carried = plus !== undefined ? mergeCarried(this.carriedBase(plus), this.wsCarried(plus), this.packCarried()) : this.packCarried();
    return manifestText(composeManifest(this.jobIdentity(), this.specsOf(ids), carried));
  }

  /** The last round a package may use: the round limit counts from its last re-opening (N3). */
  private cap(id: string): number {
    return (this.pkg(id).roundBase ?? 1) + this.o.roundLimit - 1;
  }

  private ensureWs(id: string, fresh: boolean): void {
    const ws = this.wsDir(id);
    const base = this.baselineFile(id);
    if (!fresh && fs.existsSync(ws) && fs.existsSync(base)) {
      this.refreshWs(id);
      return;
    }
    fs.rmSync(ws, { recursive: true, force: true });
    copyDir(this.dir("pack"), ws);
    // pack.json is composed by the Foreman (JOB.md): the builder finds it in place and never owns it.
    fs.mkdirSync(ws, { recursive: true });
    const carried = this.packCarried();
    this.writeMembers(id);
    fs.writeFileSync(this.carriedBaseFile(id), JSON.stringify(carried, null, 1) + "\n");
    fs.writeFileSync(path.join(ws, MANIFEST_FILE), this.wsManifestText(id, carried));
    fs.writeFileSync(base, JSON.stringify(snapshot(ws), null, 1));
  }

  /**
   * Before a new builder round in a workspace that already exists: every file OUTSIDE the package's scope is brought
   * up to what pack/ holds now (a dependency may have been changed and merged again since the workspace was cut:
   * a change request, the critic naming the root). The package's own files are not touched.
   */
  private refreshWs(id: string): void {
    const ws = this.wsDir(id);
    const spec = this.spec(id);
    const packDir = this.dir("pack");
    const baseline = JSON.parse(fs.readFileSync(this.baselineFile(id), "utf8")) as Record<string, string>;
    const inPack = new Set(listFiles(packDir));
    let changed = false;
    for (const f of inPack) {
      if (f === MANIFEST_FILE || matchesAny(spec.scope, f)) continue;
      const h = hashFile(path.join(packDir, f));
      const mine = path.join(ws, f);
      if (!fs.existsSync(mine) || hashFile(mine) !== h) {
        fs.mkdirSync(path.dirname(mine), { recursive: true });
        fs.copyFileSync(path.join(packDir, f), mine);
        changed = true;
      }
      if (baseline[f] !== h) {
        baseline[f] = h;
        changed = true;
      }
    }
    for (const f of listFiles(ws)) {
      if (f === MANIFEST_FILE || matchesAny(spec.scope, f) || inPack.has(f)) continue;
      fs.rmSync(path.join(ws, f), { force: true });
      delete baseline[f];
      changed = true;
    }
    // The workspace now holds what pack/ holds: the manifest names the same packages (N3b).
    this.writeMembers(id);
    // The optional manifest fields: what the builder changed so far stays, the rest follows pack/.
    const theirs = this.packCarried();
    const merged = mergeCarried(this.carriedBase(id), this.wsCarried(id), theirs);
    const wanted = this.wsManifestText(id, merged);
    if (this.readText(path.join(ws, MANIFEST_FILE)) !== wanted) fs.writeFileSync(path.join(ws, MANIFEST_FILE), wanted);
    if (JSON.stringify(this.carriedBase(id)) !== JSON.stringify(theirs)) fs.writeFileSync(this.carriedBaseFile(id), JSON.stringify(theirs, null, 1) + "\n");
    if (changed) {
      pruneEmptyDirs(ws);
      fs.mkdirSync(ws, { recursive: true });
      baseline[MANIFEST_FILE] = hashFile(path.join(ws, MANIFEST_FILE));
      fs.writeFileSync(this.baselineFile(id), JSON.stringify(baseline, null, 1));
    }
  }

  /**
   * Splits what the builder changed into in-scope and out-of-scope. Out-of-scope files are removed from the
   * workspace (or put back to what pack/ has) before anything is verified, and returned so they can be recorded.
   */
  private dropOutOfScope(id: string): string[] {
    const ws = this.wsDir(id);
    const spec = this.spec(id);
    const baseline = JSON.parse(fs.readFileSync(this.baselineFile(id), "utf8")) as Record<string, string>;
    const packDir = this.dir("pack");
    const dropped: string[] = [];
    const present = new Set(listFiles(ws));
    // The manifest first: whatever the builder did to it, the composed text is put back before anything is verified.
    // The five optional fields (footprint, params, on_leave, subject, moments) are the builder's: they are carried
    // through as written. Any other difference from the composed manifest is undone and recorded.
    const wanted = this.wsManifestText(id);
    const manifestAbs = path.join(ws, MANIFEST_FILE);
    const had = fs.existsSync(manifestAbs) ? fs.readFileSync(manifestAbs, "utf8") : undefined;
    if (had !== wanted) {
      fs.writeFileSync(manifestAbs, wanted);
      let onlyCarried = false;
      let refused: string[] = [];
      try {
        const doc = JSON.parse(stripBom(had ?? "")) as Record<string, unknown>;
        const rest = Object.fromEntries(Object.entries(doc).filter(([k]) => !(CARRIED_FIELDS as readonly string[]).includes(k)));
        const composed = JSON.parse(this.wsManifestText(id, {})) as Record<string, unknown>;
        onlyCarried = JSON.stringify(rest) === JSON.stringify(composed);
        refused = CARRIED_FIELDS.filter((k) => doc[k] !== undefined && !this.accepted().has(k));
      } catch {
        /* not JSON: it was edited beyond the fields a builder owns */
      }
      // A field PACK.md describes but this engine's manifest check does not know yet would make lint refuse the pack.
      if (onlyCarried && refused.length > 0) dropped.push(`${MANIFEST_FILE} (the builder wrote ${refused.join(", ")}; this engine's manifest check does not accept ${refused.length === 1 ? "that field" : "those fields"} yet, so ${refused.length === 1 ? "it was" : "they were"} removed)`);
      else if (!onlyCarried) dropped.push(`${MANIFEST_FILE} (${had === undefined ? "deleted" : "edited"} by the builder; the Foreman's composed manifest was put back)`);
    }
    for (const f of present) {
      if (f === MANIFEST_FILE) continue;
      if (matchesAny(spec.scope, f)) continue;
      if (baseline[f] === hashFile(path.join(ws, f))) continue;
      const inPack = path.join(packDir, f);
      if (fs.existsSync(inPack)) {
        if (hashFile(inPack) === hashFile(path.join(ws, f))) continue;
        fs.copyFileSync(inPack, path.join(ws, f));
      } else fs.rmSync(path.join(ws, f), { force: true });
      dropped.push(f);
    }
    for (const f of Object.keys(baseline)) {
      // A file of another package deleted by this builder: put it back.
      if (f === MANIFEST_FILE || present.has(f) || matchesAny(spec.scope, f)) continue;
      const inPack = path.join(packDir, f);
      if (fs.existsSync(inPack)) {
        fs.mkdirSync(path.dirname(path.join(ws, f)), { recursive: true });
        fs.copyFileSync(inPack, path.join(ws, f));
        dropped.push(`${f} (deletion undone)`);
      }
    }
    pruneEmptyDirs(ws);
    return dropped.sort();
  }

  /**
   * What this package contributes: in-scope files of the workspace that are new or changed since the workspace was
   * cut from pack/. Measured against the baseline, not against pack/, so a merge redone after a kill lists the
   * same files again instead of an empty set.
   */
  private mergeSet(id: string): string[] {
    const ws = this.wsDir(id);
    const spec = this.spec(id);
    const baseline = JSON.parse(fs.readFileSync(this.baselineFile(id), "utf8")) as Record<string, string>;
    return listFiles(ws).filter((f) => f !== MANIFEST_FILE && matchesAny(spec.scope, f) && baseline[f] !== hashFile(path.join(ws, f)));
  }

  /** In-scope files the package deleted: they were in the workspace when it was cut and are gone now. */
  private removedSet(id: string): string[] {
    const ws = this.wsDir(id);
    const spec = this.spec(id);
    const baseline = JSON.parse(fs.readFileSync(this.baselineFile(id), "utf8")) as Record<string, string>;
    return Object.keys(baseline)
      .filter((f) => f !== MANIFEST_FILE && matchesAny(spec.scope, f) && !fs.existsSync(path.join(ws, f)))
      .sort();
  }

  private async runPackage(id: string): Promise<void> {
    const spec = this.spec(id);
    const first = this.pkg(id);
    let round = first.round;
    // Left running or verifying by a kill: the same round restarts and the log says so.
    // N3b: a round that ended "machine busy" is verified again in the next run; its builder is not run again.
    let resumed = first.state === "running" || first.state === "verifying" || (first.state === "blocked" && first.cause === "machine_busy");
    const wsThere = fs.existsSync(this.wsDir(id)) && fs.existsSync(this.baselineFile(id));
    // If the builder already answered ok for this round, its work is in ws/: verify it, do not pay for it twice.
    let skipBuilder = resumed && first.builtRounds.includes(round) && wsThere;

    for (;;) {
      if (!skipBuilder) {
        await this.gate.wait((reason) => {
          this.append({ type: "package_state", package: id, state: "blocked", round, cause: "budget", detail: reason });
        });
        const cur = this.pkg(id);
        const fresh = round === 1 && !resumed && cur.state === "queued";
        this.ensureWs(id, fresh);
        this.append({ type: "package_state", package: id, state: "running", round, ...(resumed ? { detail: "resumed" } : {}) });
        resumed = false;
        const res = await this.callBuilder(id, spec, round);
        if (res.outcome === "ok") this.recordNote(id, round, res.text);
        if (res.outcome === "ok" && this.raiseQuestion(id, round, res.text)) return;
        if (res.outcome !== "ok") {
          const cause: Cause = res.error?.kind === "rate_limit" ? "budget" : BUILDER_CAUSE[res.outcome];
          const why = `builder ${res.outcome}: ${clip(res.error?.message ?? "no detail", 300)}`;
          if (await this.keepAfterCriticRound(id, round, why)) return;
          if (this.isCriticKitRetry(id, round) && (await this.keepEarlier(id, round, why))) return;
          if (res.outcome === "refused" || cause === "budget" || round >= this.cap(id)) {
            if (await this.keepEarlier(id, round, why)) return;
            this.append({ type: "package_state", package: id, state: "failed", round, cause, detail: why });
            this.unmerge(id);
            return;
          }
          round += 1;
          continue;
        }
      }

      // Resumed after the builder answered: if that answer was a question the kill cut off before it was logged,
      // it is still in the transcript, and it still has to be asked.
      if (skipBuilder) this.recordNote(id, round, this.loggedAnswer(id, round));
      if (skipBuilder && this.raiseQuestion(id, round, this.loggedAnswer(id, round))) return;
      const dropped = this.dropOutOfScope(id);
      const details = [skipBuilder && resumed ? "resumed" : "", dropped.length > 0 ? listDetail("dropped out-of-scope files", dropped) : ""].filter(Boolean);
      this.append({ type: "package_state", package: id, state: "verifying", round, ...(details.length > 0 ? { detail: details.join("; ") } : {}) });
      skipBuilder = false;
      resumed = false;

      let failure: GateFailure | undefined;
      for (const a of spec.acceptance) {
        const vr = await this.verifyLogged(a, this.wsDir(id), `${id}-r${round}-${a.verb}`, { package: id, round });
        if (!vr.ok) {
          failure = vr;
          break;
        }
      }
      if (!failure) failure = await this.serialMerge(() => this.mergeAndGate(id, round));
      if (!failure) return;
      if (failure.inconclusive !== undefined) {
        // N3b: no verdict. The round is not lost, the builder gets no feedback for it, and nothing is merged: the
        // package waits (blocked, cause machine_busy) and the job pauses; `resume` verifies the same files again.
        this.busyThisRun.add(id);
        this.append({ type: "package_state", package: id, state: "blocked", round, cause: "machine_busy", detail: clip(failure.inconclusive, 900) });
        return;
      }
      if (failure.kitRegression !== undefined) {
        // N3 item 3: the round passed every check but made the kit figures worse without saying why. It is not
        // merged; the package gets the next round with the figures as feedback (a `failed`, then a `queued`).
        this.append({ type: "package_state", package: id, state: "failed", round, cause: "kit_regression", detail: clip(failure.kitRegression, 900) });
        // The critic's extra round gets exactly ONE more round for a kit regression; after that the job goes on.
        if (this.isCriticKitRetry(id, round) && (await this.keepEarlier(id, round, "kit_regression again in the one more round"))) return;
        if (round < this.cap(id)) {
          this.append({ type: "package_state", package: id, state: "queued", round: round + 1, detail: clip(failure.kitRegression, 900) });
          round += 1;
          continue;
        }
        if (await this.keepEarlier(id, round, "kit_regression")) return;
        this.unmerge(id);
        return;
      }
      if (await this.keepAfterCriticRound(id, round, `${failure.verb} (${failure.level}): ${clip(failure.summary, 200)}`)) return;
      if (this.isCriticKitRetry(id, round) && (await this.keepEarlier(id, round, `${failure.verb} (${failure.level}): ${clip(failure.summary, 200)}`))) return;
      if (round >= this.cap(id) && (await this.keepEarlier(id, round, `${failure.verb} (${failure.level}): ${clip(failure.summary, 200)}`))) return;
      if (round >= this.cap(id)) {
        this.append({
          type: "package_state",
          package: id,
          state: "failed",
          round,
          cause: "verify_failed",
          detail: clip(`${failure.verb} (${failure.level}) did not pass after ${round} rounds: ${failure.summary}`, 400),
        });
        this.unmerge(id);
        return;
      }
      round += 1;
    }
  }

  /**
   * One verification, written to the log. A verdict that rests on a CLOCK is not believed on one run: RUNNER.md
   * names three limits that read wall time (a tick over 250 ms, a setup call over 10 s, the physics p99 budget).
   * Observed on 2026-11-10 with the real engine under CPU load: `smoke` on a 120-frame pack ended as `watchdog`
   * (tick_timeout) in 3 of 10 runs and as its true result in the other 7. So such a result is run once more; both
   * runs are `verify` events, and the second one decides. A real runaway script simply trips twice.
   */
  private async verifyLogged(a: Pick<Acceptance, "verb" | "args">, packDir: string, stem: string, where: { package?: string; round: number; after?: string }): Promise<Verified> {
    const vr = await this.verifyTwice(a, packDir, stem, where);
    if (vr.ok || !restsOnAClock(vr)) return vr;
    // N3b (defect 2 of the real hockey job): the same clock-based failure twice. Before the pack is blamed, the
    // MACHINE is measured: the same verb on the engine's known-good reference pack. If that breaks a time limit as
    // well, the verdict is "inconclusive: machine busy": wait, try again, with a growing pause; a builder never gets
    // such a failure as feedback. If the reference pack passes, the failure is the pack's and goes to the builder.
    // A pack whose TYPICAL frame is already slow is slow code, whatever the machine does: under load the median stays
    // (hockey job: p50 0.9 ms calm and loaded) and only the p99 jumps. No measurement, no waiting.
    const typical = medianOverHalfBudget(vr);
    if (typical !== undefined) return { ...vr, summary: `${vr.summary}. ${typical}` };
    const who = where.package ?? where.after ?? (this.s.order[0] as string);
    const round = this.s.packages[who]?.round ?? 1;
    const tries = Math.max(0, this.o.clockRetries ?? 3);
    const pauses = this.o.clockPausesMs && this.o.clockPausesMs.length > 0 ? this.o.clockPausesMs : [20_000, 40_000, 80_000];
    const sleep = this.o.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
    let last: VerifyResult = vr;
    for (let n = 1; ; n++) {
      const ref = await this.measureMachine(a.verb);
      if (ref === undefined) return { ...last, summary: `${last.summary}. The machine could not be measured (no reference pack ${toPosix(this.referencePack())}), so this stands as the pack's failure` };
      if (!ref.busy) {
        const text = `${NOT_LOAD}: ${a.verb} failed on a clock (${clip(clockDetail(last), 200)}) and the engine's reference pack, run right after it on the same machine, did not (${ref.what}; ${ref.report}). The time is this pack's own.`;
        if (where.package !== undefined) this.append({ type: "note", package: where.package, round: where.round, text: `${FOREMAN_NOTE}${text}` });
        return { ...last, summary: `${last.summary}. The machine is not the cause: the engine's reference pack passed the same verb just now (${ref.what}; ${ref.report}), so this is the pack's own time` };
      }
      const figures = `${a.verb} on ${where.package !== undefined ? `the workspace of ${where.package}` : "the whole pack"} failed on a clock (${clip(clockDetail(last), 200)}), and so did the engine's reference pack (${ref.what}; ${ref.report})`;
      if (n > tries) {
        const text = `${MACHINE_BUSY}. ${figures}. Tried ${tries} more time(s) with pauses; the machine stayed busy. This is NOT a verdict about the pack: nothing was sent to the builder. Free the machine and run \`foreman resume\`: the same files are verified again.`;
        this.append({ type: "note", package: who, round, text: `${FOREMAN_NOTE}${text}` });
        return { ...last, inconclusive: text, summary: text };
      }
      const pause = pauses[Math.min(n - 1, pauses.length - 1)] as number;
      this.append({ type: "note", package: who, round, text: `${FOREMAN_NOTE}${MACHINE_BUSY}. ${figures}. Waiting ${Math.round(pause / 1000)} s, then try ${n} of ${tries}.` });
      await sleep(pause);
      last = await this.verifyOnce(a, packDir, `${stem}-retry${n}`, where);
      if (last.ok || !restsOnAClock(last)) return last;
    }
  }

  private referencePack(): string {
    return this.o.referencePack ?? path.join(this.o.verifier.location.engineDir, "kernel", "examples", "pack_min");
  }

  /**
   * Runs `verb` on the engine's reference pack. `busy` is true when that known-good pack breaks a time limit too.
   * Not a `verify` event (it is not about this job's pack); the report stays in reports/ and is named in a note.
   */
  private async measureMachine(failed: Acceptance["verb"]): Promise<{ busy: boolean; what: string; report: string } | undefined> {
    const pack = this.referencePack();
    if (!fs.existsSync(path.join(pack, MANIFEST_FILE))) return undefined;
    // `smoke` is the gauge whatever verb failed: it is the shortest run that reports frame times and can trip the watchdog.
    const verb: Acceptance["verb"] = "smoke";
    const r = await this.o.verifier.run({ verb, args: [], packDir: pack, reportFile: this.reportPath(`reference-${verb}-for-${failed}`) });
    const report = this.rel(r.reportFile);
    const limit = this.o.referenceBusyP99Ms ?? 2;
    const m = (r.report?.["metrics"] ?? {}) as { frame_ms_p50?: unknown; frame_ms_p99?: unknown; tick_ms_max?: unknown };
    const p99 = typeof m.frame_ms_p99 === "number" ? m.frame_ms_p99 : undefined;
    const tickLimit = this.o.referenceBusyTickMs ?? 2;
    if (r.ok && typeof m.tick_ms_max === "number" && m.tick_ms_max >= tickLimit) {
      return { busy: true, what: `it passed, but one of its ticks took ${m.tick_ms_max} ms (calm: about 0.1 ms; from ${tickLimit} ms on, something else is taking the processor)`, report };
    }
    if (r.ok && p99 !== undefined && p99 >= limit) return { busy: true, what: `it passed, but its frame p99 was ${p99} ms (p50 ${String(m.frame_ms_p50)} ms; from ${limit} ms on this tiny pack the machine counts as busy)`, report };
    if (r.ok) return { busy: false, what: `passed${p99 !== undefined ? `, frame p99 ${p99} ms` : ""}`, report };
    if (restsOnAClock(r)) return { busy: true, what: clip(clockDetail(r), 200), report };
    // The reference pack failed for another reason: that says nothing about load.
    return { busy: false, what: `it failed for another reason: ${clip(r.summary, 160)}`, report };
  }

  private async verifyOnce(a: Pick<Acceptance, "verb" | "args">, packDir: string, stem: string, where: { package?: string; round: number; after?: string }): Promise<VerifyResult> {
    const vr = await this.o.verifier.run({ verb: a.verb, args: a.args, packDir, reportFile: this.reportPath(stem) });
    this.append({
      type: "verify",
      ...(where.package !== undefined ? { package: where.package } : {}),
      round: where.round,
      level: vr.level,
      verb: vr.verb,
      ok: vr.ok,
      report: this.rel(vr.reportFile),
      ...(vr.exitCode !== undefined ? { exitCode: vr.exitCode } : {}),
      ...(where.after !== undefined ? { after: where.after } : {}),
    });
    return vr;
  }

  private async verifyTwice(a: Pick<Acceptance, "verb" | "args">, packDir: string, stem: string, where: { package?: string; round: number; after?: string }): Promise<VerifyResult> {
    let vr: VerifyResult | undefined;
    for (let attempt = 1; attempt <= 2; attempt++) {
      vr = await this.o.verifier.run({ verb: a.verb, args: a.args, packDir, reportFile: this.reportPath(attempt === 1 ? stem : `${stem}-again`) });
      this.append({
        type: "verify",
        ...(where.package !== undefined ? { package: where.package } : {}),
        round: where.round,
        level: vr.level,
        verb: vr.verb,
        ok: vr.ok,
        report: this.rel(vr.reportFile),
        ...(vr.exitCode !== undefined ? { exitCode: vr.exitCode } : {}),
        ...(where.after !== undefined ? { after: where.after } : {}),
      });
      // N3: a runner that ended without printing anything says nothing about the pack. Seen 2026-11-11 under CPU load:
      // when a Foreman's process tree is killed, the runner child dies a few milliseconds before the Foreman, which
      // then logged a failed verification (exit 1, empty stdout) and started the next round before it died itself.
      // Such a result is run once more as well; if the Foreman is being killed, it dies during that second run and
      // the resume simply verifies again.
      const silent = diedSilently(vr);
      if (vr.ok || !(restsOnAClock(vr) || silent)) break;
      if (attempt === 2) vr = { ...vr, summary: `${vr.summary}. This is the second run with the same ${silent ? "result (the runner ended without output both times)" : "clock-based result"} (the first run is in the log too)` };
    }
    return vr as VerifyResult;
  }

  /** A builder that ends its answer with a `QUESTION:` line is not done: the package waits for the player. */
  private raiseQuestion(id: string, round: number, text: string | undefined): boolean {
    const question = /^QUESTION:\s*(.+)$/m.exec(text ?? "")?.[1]?.trim();
    if (!question) return false;
    // Already asked and answered (the answer is newer than this run): do not ask again.
    const events = this.log.events;
    const runAt = [...events].reverse().find((e) => e.type === "builder_run" && e.package === id && e.round === round && e.outcome === "ok")?.seq ?? 0;
    if (events.some((e) => e.type === "answer" && e.package === id && e.seq > runAt)) return false;
    if (!events.some((e) => e.type === "question" && e.package === id && e.seq > runAt)) this.append({ type: "question", package: id, text: question });
    this.append({ type: "package_state", package: id, state: "blocked", round, cause: "question", detail: clip(question, 200) });
    return true;
  }

  /** The text of the last ok builder answer for a round, read back from its transcript. */
  private loggedAnswer(id: string, round: number): string | undefined {
    const run = [...this.log.events].reverse().find((e) => e.type === "builder_run" && e.package === id && e.round === round && e.outcome === "ok");
    if (!run || run.type !== "builder_run" || run.transcript === undefined) return undefined;
    try {
      const t = JSON.parse(fs.readFileSync(this.dir(run.transcript), "utf8")) as { result?: { text?: unknown } };
      return typeof t.result?.text === "string" ? t.result.text : undefined;
    } catch {
      return undefined;
    }
  }

  /** Merges are one at a time: the candidate that is verified is exactly what pack/ becomes. */
  private serialMerge<T>(fn: () => Promise<T>): Promise<T> {
    const next = this.mergeChain.then(fn, fn);
    this.mergeChain = next.catch(() => {});
    return next;
  }

  /**
   * Builds the candidate (pack/ plus this package's in-scope files), verifies it at V0 to V2, and only then
   * copies the files into pack/ and writes `merge` and `promoted`. pack/ never holds unverified files.
   */
  private async mergeAndGate(id: string, round: number): Promise<GateFailure | undefined> {
    const files = this.mergeSet(id);
    const ws = this.wsDir(id);
    const hadMerged = (this.pkg(id).mergedFiles ?? []).length > 0;
    // Files this package merged in an earlier round (a round after a milestone sent it back) and has deleted since
    // are removed too: the baseline predates them, so removedSet alone would leave them in pack/.
    const dropped = (this.pkg(id).mergedFiles ?? []).filter((f) => !fs.existsSync(path.join(ws, f)));
    const removed = [...new Set([...this.removedSet(id), ...dropped])].sort().filter((f) => fs.existsSync(path.join(this.dir("pack"), f)));
    const packDir = this.dir("pack");
    const candidate = this.dir("ws", `_candidate_${id}`);
    const manifest = this.packManifestText(id);
    fs.rmSync(candidate, { recursive: true, force: true });
    copyDir(packDir, candidate);
    for (const f of files) {
      fs.mkdirSync(path.dirname(path.join(candidate, f)), { recursive: true });
      fs.copyFileSync(path.join(ws, f), path.join(candidate, f));
    }
    for (const f of removed) fs.rmSync(path.join(candidate, f), { force: true });
    fs.writeFileSync(path.join(candidate, MANIFEST_FILE), manifest);
    const kitBefore = this.kitBefore(id, round);
    try {
      for (const a of PACK_GATE) {
        const vr = await this.verifyLogged(a, candidate, `${id}-r${round}-pack-${a.verb}`, { round, after: id });
        if (!vr.ok) return vr;
        // The pack the runner loaded must be the pack this job was created for, from the first merge on.
        const seen = vr.report?.["pack"];
        if (a.verb === "lint" && typeof seen === "string" && seen !== this.s.packId) {
          return { ...vr, ok: false, summary: `the runner reports pack id "${seen}" but this job was created for "${this.s.packId ?? "?"}": the merge is refused` };
        }
        if (a.verb === "lint") {
          const worse = this.kitRegression(id, round, kitBefore, vr, candidate);
          if (worse !== undefined) return { ...vr, ok: false, summary: worse, kitRegression: worse };
        }
      }
    } finally {
      fs.rmSync(candidate, { recursive: true, force: true });
    }
    for (const f of files) {
      fs.mkdirSync(path.dirname(path.join(packDir, f)), { recursive: true });
      fs.copyFileSync(path.join(ws, f), path.join(packDir, f));
    }
    for (const f of removed) fs.rmSync(path.join(packDir, f), { force: true });
    pruneEmptyDirs(packDir);
    fs.mkdirSync(packDir, { recursive: true });
    fs.writeFileSync(path.join(packDir, MANIFEST_FILE), manifest);
    this.append({ type: "merge", package: id, files, ...(removed.length > 0 ? { removed } : {}) });
    this.append({ type: "package_state", package: id, state: "promoted", round });
    // N3: a package that was merged before and is merged again has changed under the packages that depend on it.
    if (hadMerged) await this.reverifyDependants(id);
    await this.maybeMilestone(this.spec(id).milestone, id);
    return undefined;
  }

  // ---------- N3: re-opening a finished package ----------

  /** A promoted package goes back to work: `reopened`, then `queued` at the next round with the reason as feedback. */
  private reopen(id: string, reason: string, detail: string): void {
    const round = this.pkg(id).round + 1;
    this.append({ type: "reopened", package: id, reason: clip(reason, 600) });
    this.append({ type: "package_state", package: id, state: "queued", round, detail: clip(detail, 1500) });
  }

  /** A `reopened` whose `queued` is missing (a kill between the two events): write the `queued` now. */
  private requeueReopened(): void {
    for (const id of this.s.order) {
      const p = this.pkg(id);
      if (p.roundBase === undefined || p.roundBase !== p.round + 1 || p.state === "queued" || p.state === "running" || p.state === "verifying") continue;
      const last = [...this.log.events].reverse().find((e) => e.type === "reopened" && e.package === id);
      const reason = last && last.type === "reopened" ? last.reason : "";
      const m = CHANGE_REASON_RE.exec(reason);
      const change = m ? this.s.changes.find((c) => c.seq === Number(m[1])) : undefined;
      const detail = change ? `${CHANGE_ROUND}: ${change.text}` : reason.startsWith(CRITIC_ROUND) ? reason : `${DEP_CHANGED}: ${reason}`;
      this.append({ type: "package_state", package: id, state: "queued", round: p.roundBase, detail: clip(detail, 1500) });
    }
  }

  /** One line per package for the critic and the "who owns this" question. */
  private packageLines(): PackageLine[] {
    return this.s.plan.map((p) => {
      const merged = this.pkg(p.id).mergedFiles ?? [];
      return { id: p.id, title: p.title, milestone: p.milestone, deps: p.deps, files: merged.length > 0 ? merged : p.scope };
    });
  }

  /**
   * N3 item 1: every change request that has no `reopened` yet. With a package named, that package is the owner;
   * without one the Planner is asked which package owns the problem (one short generate call). The owner is
   * re-opened: the text joins its brief, it runs its normal rounds, and after its merge every package that depends
   * on it is verified again (reverifyDependants).
   */
  private async applyChangeRequests(): Promise<void> {
    for (const c of this.s.changes.filter((x) => x.state === "pending")) {
      let owner = c.package;
      let how = "the request names the package";
      if (owner === undefined) {
        const model = this.o.plannerModel ?? this.o.model;
        const res = await whoOwns(this.o.builder, { sentence: this.s.sentence ?? "", title: this.s.title ?? "", text: c.text, packages: this.packageLines() }, model ? { model } : {});
        this.logGenerateCalls(res.calls, model);
        if (res.ok) {
          owner = res.value.package;
          how = `the Planner names the package: ${clip(res.value.reason, 200)}`;
        } else {
          owner = this.s.plan.find((p) => p.deps.length === 0)?.id ?? (this.s.order[0] as string);
          how = `the Planner gave no usable answer (${clip(res.reason, 160)}), so the root package takes it`;
        }
      }
      this.reopen(owner, `${changeReason(c.seq)}; ${how}: ${clip(c.text, 300)}`, `${CHANGE_ROUND}: ${c.text}`);
    }
  }

  /**
   * After a finished package was merged AGAIN: the acceptance of every promoted package that depends on it is run
   * once more, now on the merged pack. One that still passes is left alone; one that fails is re-opened with the
   * failing report as feedback, and only then rebuilt.
   */
  private async reverifyDependants(id: string): Promise<void> {
    const packDir = this.dir("pack");
    for (const d of dependants(this.s.plan, id)) {
      const p = this.pkg(d);
      if (p.state !== "promoted") continue;
      let failure: VerifyResult | undefined;
      for (const a of this.spec(d).acceptance) {
        const vr = await this.verifyLogged(a, packDir, `${d}-r${p.round}-reverify-${a.verb}`, { package: d, round: p.round });
        if (!vr.ok) {
          failure = vr;
          break;
        }
      }
      // N3b: "machine busy" is no verdict; the final verification runs every check on the whole pack again.
      if (failure && (failure as Verified).inconclusive !== undefined) continue;
      if (failure) {
        const why = `${failure.verb} (${failure.level}) now fails on the merged pack: ${clip(failure.summary, 300)}`;
        this.reopen(d, `its dependency ${id} was changed and merged again, and ${why}`, `${DEP_CHANGED}: package ${id}, which yours depends on, was changed and merged again after your package was finished. Your acceptance check ${why}`);
      }
    }
  }

  /**
   * A package that was finished, went back to work (a change request, the critic, a changed dependency) and did not
   * pass within its rounds: the job is not thrown away for it. The files merged before stay in pack/ (they were
   * verified), the package is `promoted` again, and the `detail` says that the change was not made.
   */
  private async keepEarlier(id: string, round: number, why: string): Promise<boolean> {
    const p = this.pkg(id);
    const sentBack = p.roundBase !== undefined || this.log.events.some((e) => e.type === "package_state" && e.package === id && e.state === "queued" && (e.detail ?? "").startsWith(CRITIC_ROUND));
    if (!sentBack || (p.mergedFiles ?? []).length === 0) return false;
    this.append({ type: "package_state", package: id, state: "promoted", round, detail: clip(`re-opened, but no round passed (${why}); the files merged before it stay in pack/ and the change was NOT made`, 500) });
    await this.maybeMilestone(this.spec(id).milestone, id);
    return true;
  }

  // ---------- N3 item 3: kit use cannot fall silently ----------

  private kitFile(id: string): string {
    return this.dir("ws", `${id}.kit.json`);
  }

  /**
   * The figures of pack/ as it is now: bypasses from the whole-pack lint report that gated its last merge, kit use
   * counted from its files. Nothing before the first merge: an empty pack has nothing to fall from.
   */
  private packFigures(): KitFigures | undefined {
    if (!this.s.order.some((x) => (this.pkg(x).mergedFiles ?? []).length > 0)) return undefined;
    let bypasses: number | undefined;
    const events = this.log.events;
    const lastMerge = [...events].reverse().find((e) => e.type === "merge" && e.files.length > 0)?.seq ?? 0;
    for (const e of [...events].reverse()) {
      if (e.seq > lastMerge || e.type !== "verify" || e.verb !== "lint" || !e.ok || e.package !== undefined) continue;
      try {
        const r = JSON.parse(fs.readFileSync(this.dir(e.report), "utf8")) as { composability?: { bypasses?: unknown } };
        if (Array.isArray(r.composability?.bypasses)) bypasses = r.composability.bypasses.length;
      } catch {
        /* an unreadable report gives no figure */
      }
      break;
    }
    if (bypasses === undefined) return undefined;
    return { bypasses, kitUse: countKitUse(this.dir("pack")) };
  }

  /**
   * Compares the candidate (pack/ with this round's files merged in) with pack/ before the round. More bypasses or
   * less kit use is a regression unless the builder's DEVIATIONS for this round say why; then it passes and the
   * reason is recorded as a `note`. Returns the feedback text when the round fails for it.
   */
  private kitBefore(id: string, round: number): KitFigures | undefined {
    if (this.o.kitGate === false) return undefined;
    // The figures before the round are kept beside the workspace: a merge redone after a kill compares with the
    // same "before" and not with a pack/ that already holds this round's files.
    try {
      const kept = JSON.parse(fs.readFileSync(this.kitFile(id), "utf8")) as { round?: number; before?: KitFigures };
      if (kept.round === round && kept.before) return kept.before;
    } catch {
      /* none kept */
    }
    const before = this.packFigures();
    if (before) fs.writeFileSync(this.kitFile(id), JSON.stringify({ round, before }, null, 1) + "\n");
    return before;
  }

  private kitRegression(id: string, round: number, before: KitFigures | undefined, lint: VerifyResult, candidate: string): string | undefined {
    if (!before) return undefined;
    const list = (lint.report?.["composability"] as { bypasses?: unknown } | undefined)?.bypasses;
    if (!Array.isArray(list)) return undefined;
    const after: KitFigures = { bypasses: list.length, kitUse: countKitUse(candidate) };
    const worse: string[] = [];
    if (after.bypasses > before.bypasses) {
      const shown = (list as { file?: string; line?: number; pattern?: string; primitive?: string }[]).slice(-Math.min(6, after.bypasses - before.bypasses + 3)).map((b) => `${b.file ?? "?"}:${b.line ?? "?"} ${b.pattern ?? ""} (primitive: ${b.primitive ?? "?"})`);
      worse.push(`bypasses rose from ${before.bypasses} to ${after.bypasses} (the pack's lint report, composability.bypasses; the newest: ${shown.join("; ")})`);
    }
    if (after.kitUse < before.kitUse) worse.push(`kit parts used fell from ${before.kitUse} to ${after.kitUse} ("kind" entries in data/*.json plus TLKit./TLRigs. calls in scripts)`);
    if (worse.length === 0) return undefined;
    const figures = worse.join("; ");
    const said = [...this.s.notes].reverse().find((n) => n.package === id && n.round === round && !n.text.startsWith(FOREMAN_NOTE))?.text;
    const hints = (list as { pattern?: string; primitive?: string }[]).flatMap((b) => [b.pattern ?? "", b.primitive ?? ""]);
    if (statesKitReason(said, hints)) {
      const text = `${FOREMAN_NOTE}kit figures got worse in this round and the builder states why, so the round passes: ${figures}. Stated: ${clip(said ?? "", 1200)}`;
      if (!this.log.events.some((e) => e.type === "note" && e.package === id && e.round === round && e.text.startsWith(`${FOREMAN_NOTE}kit figures got worse`))) this.append({ type: "note", package: id, round, text });
      return undefined;
    }
    return `${KIT_REGRESSION}: ${figures}. The round passed its checks but was NOT merged. Use the kit parts and kernel primitives again (put back what was removed), or, if there is a real reason, state it under DEVIATIONS in a line that starts with "KIT:".`;
  }

  // ---------- milestones: captures, then the V5 critic, then the event ----------

  /**
   * The PREVIOUS milestone (the last one in the log), when every capture here is byte-identical to its capture of
   * the same camera and frame (JOB.md, second round). Different frames or cameras cannot be compared and do not count.
   */
  private identicalToPrevious(m: Milestone, captures: string[]): string | undefined {
    if (captures.length === 0) return undefined;
    const prev = this.s.milestones[this.s.milestones.length - 1];
    if (!prev || prev.captures.length !== captures.length) return undefined;
    const tail = (rel: string, milestone: string): string => path.basename(rel).slice(milestone.length);
    const same = captures.every((c) => {
      const twin = prev.captures.find((p) => tail(p, prev.milestone) === tail(c, m));
      return twin !== undefined && fs.existsSync(this.dir(twin)) && hashFile(this.dir(twin)) === hashFile(this.dir(c));
    });
    return same ? prev.milestone : undefined;
  }

  /**
   * JOB.md (second round): captures are taken at 25 % and 75 % of the frame at which the first bot finished in its
   * last passing report, so the image shows the game in play; 120 and 480 when there is no such report.
   */
  captureFramesFor(bot: string | undefined): number[] {
    if (this.o.captureFrames) return this.o.captureFrames;
    if (bot !== undefined) {
      for (const e of [...this.log.events].reverse()) {
        if (e.type !== "verify" || e.verb !== "bot" || !e.ok) continue;
        try {
          const r = JSON.parse(fs.readFileSync(this.dir(e.report), "utf8")) as { bot?: { test?: unknown; done?: unknown; frames?: unknown } };
          const f = r.bot?.frames;
          if (r.bot?.test !== bot || r.bot?.done !== true || typeof f !== "number" || !Number.isFinite(f) || f < 4) continue;
          return [Math.max(1, Math.round(f * 0.25)), Math.max(2, Math.round(f * 0.75))];
        } catch {
          /* an unreadable report is not a passing report */
        }
      }
    }
    return [120, 480];
  }

  /** A package left `failed` with cause no_visible_change and rounds to spare (a kill between the two events): next round. */
  private requeueNoVisibleChange(): void {
    for (const id of this.s.order) {
      const p = this.pkg(id);
      if (p.state === "failed" && (p.cause === "no_visible_change" || p.cause === "kit_regression") && p.round < this.cap(id)) {
        this.append({ type: "package_state", package: id, state: "queued", round: p.round + 1, detail: p.detail ?? NO_VISIBLE_CHANGE });
      }
    }
  }

  /**
   * True for the round that follows a kit regression in the critic's extra round. JOB.md lets the critic cost one
   * round; a kit regression in it gives one more (N3 item 3), and after that one the job continues whatever happens.
   */
  private isCriticKitRetry(id: string, round: number): boolean {
    const kitRetry = this.log.events.some((e) => e.type === "package_state" && e.package === id && e.round === round && e.state === "queued" && (e.detail ?? "").startsWith(KIT_REGRESSION));
    return kitRetry && this.isCriticRound(id, round - 1);
  }

  private isCriticRound(id: string, round: number): boolean {
    return this.log.events.some((e) => e.type === "package_state" && e.package === id && e.round === round && e.state === "queued" && (e.detail ?? "").startsWith(CRITIC_ROUND));
  }

  /**
   * JOB.md: after the critic's extra round the job continues whatever happens. If that round does not produce a
   * verified merge, the package stays as it was merged before it (pack/ never changed), and the milestone is written.
   */
  private async keepAfterCriticRound(id: string, round: number, why: string): Promise<boolean> {
    if (!this.isCriticRound(id, round)) return false;
    this.append({ type: "package_state", package: id, state: "promoted", round, detail: clip(`the extra round after the critic did not pass (${why}); the files merged before it stay in pack/`, 400) });
    await this.maybeMilestone(this.spec(id).milestone, id);
    return true;
  }

  /** The deviations a builder states under `DEVIATIONS:` become a `note` event (once per builder run). */
  private recordNote(id: string, round: number, text: string | undefined): void {
    const note = parseDeviations(text);
    if (note === undefined) return;
    const events = this.log.events;
    const runAt = [...events].reverse().find((e) => e.type === "builder_run" && e.package === id && e.round === round && e.outcome === "ok")?.seq ?? 0;
    if (events.some((e) => e.type === "note" && e.package === id && e.round === round && e.seq > runAt)) return;
    this.append({ type: "note", package: id, round, text: note });
  }

  /** The notes of every package this one depends on (directly or through another): part of its brief. */
  private depNotesText(id: string): string {
    const deps = depClosure(this.s.plan, id);
    deps.delete(id);
    const notes = this.s.notes.filter((n) => deps.has(n.package) && !n.text.startsWith(FOREMAN_NOTE));
    if (notes.length === 0) return "None stated: build against the contracts as written.";
    return [
      "The builders of these packages said they did NOT follow their contract to the letter. Where a note and a contract disagree, the note is what the files in your working directory really do:",
      ...notes.map((n) => `- ${n.package} (round ${n.round}): ${clip(n.text, 3000).replace(/\n/g, "\n  ")}`),
    ].join("\n");
  }

  private async catchUpMilestones(): Promise<void> {
    const seen = new Set<string>();
    for (const p of this.s.plan) {
      if (seen.has(p.milestone)) continue;
      seen.add(p.milestone);
      const members = this.s.plan.filter((x) => x.milestone === p.milestone);
      const last = [...members].reverse().find((x) => this.pkg(x.id).state === "promoted");
      if (last) await this.maybeMilestone(p.milestone, last.id);
    }
  }

  private maybeMilestone(m: Milestone, lastPackage: string): Promise<void> {
    const next = this.milestoneBusy.then(() => this.runMilestone(m, lastPackage));
    this.milestoneBusy = next.catch(() => {});
    return next;
  }

  /**
   * JOB.md: when the last package of a milestone is merged, `capture` for each declared camera (with the first bot
   * playing), then the V5 critic on those images, then `milestone` with the capture paths. A capture that fails is
   * tried once more (the window can die in the graphics driver under GPU load); the critic does not gate the job.
   */
  private async runMilestone(m: Milestone, lastPackage: string): Promise<void> {
    if (this.s.milestones.some((x) => x.milestone === m)) return;
    const members = this.s.plan.filter((p) => p.milestone === m).map((p) => p.id);
    if (members.length === 0 || !members.every((x) => this.pkg(x).state === "promoted")) return;
    // N3: the critic's extra round for this milestone went to another package (the one it named) and is not over
    // yet: the second look waits for it.
    const stillOut = this.log.events.some((e) => e.type === "reopened" && e.reason.startsWith(`${CRITIC_ROUND} (milestone ${m})`) && this.s.packages[e.package] !== undefined && !["promoted", "failed"].includes(this.pkg(e.package).state));
    if (stillOut) return;
    const packDir = this.dir("pack");
    let cameras: string[] = [];
    let tests: string[] = [];
    try {
      const mf = readManifest(packDir);
      cameras = mf.cameras;
      tests = mf.tests;
    } catch {
      /* no manifest: no captures */
    }
    const captures: string[] = [];
    const notes: string[] = [];
    const bot = tests[0];
    const frames = this.captureFramesFor(bot);
    for (const cam of cameras) {
      for (const frame of frames) {
        const out = this.dir("captures", `${m}-${cam}-f${frame}.png`);
        let ok = false;
        for (let attempt = 1; attempt <= 2 && !ok; attempt++) {
          fs.mkdirSync(path.dirname(out), { recursive: true });
          fs.rmSync(out, { force: true });
          const vr = await this.o.verifier.run({
            verb: "capture",
            args: [`--cam=${cam}`, `--frame=${frame}`, `--out=${toPosix(out)}`, `--res=${this.o.captureRes ?? "1280x720"}`, ...(bot !== undefined ? [`--test=${bot}`] : [])],
            packDir,
            reportFile: this.reportPath(`milestone-${m}-capture-${cam}-f${frame}`),
          });
          ok = vr.ok && fs.existsSync(out);
          this.append({
            type: "verify",
            round: 1,
            level: vr.level,
            verb: vr.verb,
            ok,
            report: this.rel(vr.reportFile),
            ...(vr.exitCode !== undefined ? { exitCode: vr.exitCode } : {}),
            after: lastPackage,
          });
          if (!ok) notes.push(`capture ${cam} frame ${frame}, attempt ${attempt} of 2, failed: ${clip(vr.summary, 160)}`);
        }
        if (ok) captures.push(this.rel(out));
      }
    }
    if (cameras.length === 0) notes.push("the pack declares no camera, so there is nothing to capture");
    // Rendering is deterministic, so a milestone that changed nothing a camera can see gives the very same bytes
    // as the milestone before it. Seen in the first real job: an art pass that passed V0 to V3 and drew nothing.
    const sameAs = this.identicalToPrevious(m, captures);
    if (sameAs !== undefined && m === "art_pass") {
      // JOB.md: an art pass that changed nothing a camera can see fails that round; its packages go to the next one
      // with this as the feedback. No `milestone` event is written: the milestone has not been reached.
      const detail = `${NO_VISIBLE_CHANGE}: every capture of the art_pass milestone (${captures.map((c) => path.basename(c)).join(", ")}) is byte-identical to the "${sameAs}" milestone's capture of the same camera and frame. An art pass must change what the camera sees.`;
      for (const id of members) {
        const round = this.pkg(id).round;
        this.append({ type: "package_state", package: id, state: "failed", round, cause: "no_visible_change", detail: clip(detail, 600) });
        if (round < this.cap(id)) this.append({ type: "package_state", package: id, state: "queued", round: round + 1, detail: clip(detail, 600) });
        else this.unmerge(id);
      }
      return;
    }
    if (sameAs !== undefined) notes.push(`NO VISIBLE CHANGE: every capture is byte-identical to the "${sameAs}" milestone's (same camera, same frame)`);

    let verdict = "critic not run";
    if (captures.length > 0 && this.o.critic !== false) {
      const model = this.o.criticModel ?? this.o.model;
      const res = await critic(this.o.builder, captures.map((c) => this.dir(c)), DEFAULT_RUBRIC, {
        ...(model ? { model } : {}),
        context: [`Game: ${this.s.title ?? ""} (${this.s.sentence ?? ""})`, `Mood asked for: ${this.s.brief?.mood ?? "(none)"}`, bot !== undefined ? `The bot ${bot} was playing while the frames were taken.` : "No bot was playing."].join("\n"),
        packages: this.packageLines(),
      });
      this.logGenerateCalls(res.calls, model);
      const file = this.reportPath(`critic-${m}`);
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(
        file,
        JSON.stringify(
          { schema: "tl.foreman.critique/1", milestone: m, captures, rubric: DEFAULT_RUBRIC, ...(res.ok ? { ok: res.value.ok, scores: res.value.scores, notes: res.value.notes, ...(res.value.package !== undefined ? { package: res.value.package } : {}) } : { error: res.reason }) },
          null,
          1,
        ) + "\n",
      );
      verdict = res.ok
        ? `critic (V5) ${res.value.ok ? "ok" : "NOT ok"}: ${Object.entries(res.value.scores).map(([k, v]) => `${k} ${v}`).join(", ")}; ${clip(res.value.notes.join(" | "), 500)} [${this.rel(file)}]`
        : `critic (V5) gave no usable answer: ${clip(res.reason, 200)} [${this.rel(file)}]`;
      // JOB.md: "NOT ok" gives the milestone's packages ONE extra round with the critic's notes as feedback. After
      // that round the milestone is written whatever the verdict.
      // N3 item 2: that round goes to the package the critic NAMES (the one whose files most likely cause what it
      // sees), through the re-open path, and not to whichever package just merged. A missing or unknown name falls
      // back to the milestone's own packages and is logged as a `note`.
      const critiqueFor = `${CRITIC_ROUND} (milestone ${m})`;
      const events = this.log.events;
      const hadRound =
        events.some((e) => e.type === "reopened" && e.reason.startsWith(critiqueFor)) ||
        events.some((e, i) => e.type === "package_state" && members.includes(e.package) && e.state === "queued" && (e.detail ?? "").startsWith(CRITIC_ROUND) && events[i - 1]?.type !== "reopened");
      if (res.ok && !res.value.ok && !hadRound) {
        const detail = `${CRITIC_ROUND}: ${Object.entries(res.value.scores).map(([k, v]) => `${k} ${v}`).join(", ")}. Critic's notes: ${res.value.notes.join(" | ")} [${this.rel(file)}]`;
        const named = res.value.package;
        const target = named !== undefined ? this.s.packages[named] : undefined;
        if (named !== undefined && target && target.state === "promoted" && (target.mergedFiles ?? []).length > 0) {
          this.reopen(named, `${critiqueFor}: the critic names this package as the cause of what it sees${members.includes(named) ? "" : ` (the milestone's own package(s): ${members.join(", ")})`}`, detail);
          return;
        }
        const why = named === undefined ? "the critic named no package" : !target ? `the critic named "${clip(named, 60)}", which is not a package of this plan` : `the critic named ${named}, which is not merged (state ${target.state})`;
        this.append({ type: "note", package: lastPackage, round: this.pkg(lastPackage).round, text: `${FOREMAN_NOTE}${why}; the critic's extra round goes to the package(s) of the ${m} milestone: ${members.join(", ")}` });
        for (const id of members) this.append({ type: "package_state", package: id, state: "queued", round: this.pkg(id).round + 1, detail: clip(detail, 1500) });
        return;
      }
      if (hadRound) verdict += " (the verdict after the one extra round that the critic's first NOT ok gave)";
    }
    this.append({
      type: "milestone",
      milestone: m,
      captures,
      summary: clip([`all ${members.length} package(s) of this milestone are merged and verified: ${members.join(", ")}`, `${captures.length} capture(s)`, verdict, ...notes].join("; "), 1500),
    });
  }

  // ---------- builder calls ----------

  /** What goes back to the builder as the next round's prompt, derived from the log alone. */
  private feedback(id: string, round: number): string {
    const parts: string[] = [];
    const p = this.pkg(id);
    if (p.lastAnswer !== undefined) parts.push(`Answer to your question: ${p.lastAnswer}`);
    // Sent back after a merge: no visible change (art pass), or the critic's one extra round.
    const queuedAs = (prefixes: string[]): string | undefined => {
      const e = [...this.log.events].reverse().find((x) => x.type === "package_state" && x.package === id && x.round === round && x.state === "queued" && prefixes.some((pre) => (x.detail ?? "").startsWith(pre)));
      return e && e.type === "package_state" ? (e.detail ?? "") : undefined;
    };
    // N3: re-opened after it was finished (a change request, a changed dependency), or not merged for a kit regression.
    const change = queuedAs([CHANGE_ROUND]);
    if (change !== undefined) {
      parts.push(
        `This package was finished and merged. The player now asks for a change, and this package owns the files that must change:\n${change}\n` +
          "Your files are in the working directory as they were merged; the other packages' files are as the pack holds them now. Make the change inside your scope and keep everything else working: your acceptance runs again, and then the acceptance of every package that depends on yours. " +
          "Where the change request and your contract disagree, the change request wins; say what you changed under DEVIATIONS, because the builders of dependent packages read that.",
      );
    }
    const depChanged = queuedAs([DEP_CHANGED]);
    if (depChanged !== undefined) {
      parts.push(`This package was finished and merged, and has been re-opened:\n${depChanged}\nThe changed files of that package are in your working directory now. Adapt your own files to them (the report is below); do not try to change the other package.`);
    }
    // N3b: a clock-based failure reaches the builder only after the machine was measured; say so.
    const notLoad = [...this.s.notes].reverse().find((n) => n.package === id && n.round === round - 1 && n.text.startsWith(`${FOREMAN_NOTE}${NOT_LOAD}`));
    if (notLoad) parts.push(`The Foreman measured the machine before reporting this: ${notLoad.text.slice(FOREMAN_NOTE.length)}`);
    const kit = queuedAs([KIT_REGRESSION]);
    if (kit !== undefined) parts.push(`Round ${round - 1} passed its checks but was not merged:\n${kit}\nYour files from that round are still in the working directory.`);
    const sentBack = [...this.log.events]
      .reverse()
      .find((e) => e.type === "package_state" && e.package === id && e.round === round && e.state === "queued" && ((e.detail ?? "").startsWith(CRITIC_ROUND) || (e.detail ?? "").startsWith(NO_VISIBLE_CHANGE)));
    if (sentBack && sentBack.type === "package_state") {
      parts.push(
        `Round ${round - 1} passed the Verifier and was merged, but the package was sent back: ${sentBack.detail ?? ""}\n` +
          "Your files from that round are still in the working directory. Change them so that the milestone captures (the pack's declared cameras, taken while the bot plays) show the difference. Passing the same checks again without a visible change is not enough.",
      );
    }
    if (round > 1) {
      const prev = round - 1;
      const events = this.log.events;
      const lastRun = [...events].reverse().find((e) => e.type === "builder_run" && e.package === id && e.round === prev);
      if (lastRun && lastRun.type === "builder_run" && lastRun.outcome !== "ok") {
        parts.push(
          `Your previous run (round ${prev}) ended with outcome "${lastRun.outcome}"` +
            (lastRun.outcome === "truncated" ? ": the answer was cut off. Your files are still in the working directory; continue from them." : ".") +
            (lastRun.outcome === "timeout" ? " It ran out of time. Your files are still in the working directory; finish the remaining work." : ""),
        );
      }
      const packPrefix = `reports/${id}-r${prev}-pack-`;
      // A failed run that a later run of the same check overruled (the second run of a clock-based verdict, a retry
      // after "machine busy") is not feedback: only a failure that still stands goes back to the builder (N3b).
      const base = (report: string): string => report.replace(/(\.verdict)?\.json$/i, "").replace(/-s\d+$/, "").replace(/-(again|retry\d+)$/, "");
      const mine = events.filter((e): e is Extract<JobEvent, { type: "verify" }> => e.type === "verify" && e.round === prev && (e.package === id || (e.package === undefined && e.report.startsWith(packPrefix))));
      const failing = [...mine].reverse().find((e) => !e.ok && !mine.some((x) => x.ok && x.seq > e.seq && base(x.report) === base(e.report)));
      if (failing && failing.type === "verify") {
        const reportAbs = this.dir(failing.report);
        const verdictAbs = reportAbs.endsWith(".verdict.json") ? reportAbs : reportAbs.replace(/\.json$/i, "") + ".verdict.json";
        let notes = "";
        try {
          const v = JSON.parse(fs.readFileSync(verdictAbs, "utf8")) as { notes?: string[]; flags?: string[] };
          notes = [...(v.flags?.length ? [`flags: ${v.flags.join(", ")}`] : []), ...(v.notes ?? [])].join(". ");
        } catch {
          /* the verdict file is a convenience; the report below is the substance */
        }
        let body = "(report file missing)";
        try {
          body = fs.readFileSync(reportAbs, "utf8");
        } catch {
          /* keep the placeholder */
        }
        parts.push(
          `The Verifier did not pass round ${prev}: ${failing.verb} (${failing.level})` +
            `${failing.package === undefined ? " on the whole pack with your files merged in" : " on your workspace"}.` +
            `${notes ? `\nVerifier notes: ${notes}` : ""}\nReport (tl.verify/1):\n${clip(body, 12_000)}\nFix the cause; do not work around the check.`,
        );
      }
    }
    return parts.length > 0 ? parts.join("\n\n") : round === 1 ? "First round: nothing to report yet." : "No report is available for the previous round.";
  }

  private buildPrompt(id: string, spec: PackageSpec, round: number, selfCheck: string[]): string {
    const s = this.s;
    const brief = s.brief ? Object.entries(s.brief).map(([k, v]) => `- ${k}: ${v}`).join("\n") : "(no brief in the log)";
    return render(this.template, {
      packId: s.packId ?? "",
      title: s.title ?? "",
      brief,
      packageId: id,
      packageTitle: spec.title,
      milestone: spec.milestone,
      deps: spec.deps.length > 0 ? spec.deps.join(", ") : "none",
      contract: spec.contract,
      scope: spec.scope.map((g) => `- ${g}`).join("\n"),
      acceptance:
        [...spec.acceptance.map((a) => `- ${a.verb} (${a.level}) ${a.args.join(" ")}`.trimEnd()), "- then, with your files merged: lint and smoke on the whole pack"].join("\n"),
      selfCheck:
        selfCheck.length > 0
          ? `You may run exactly these commands yourself to check your work (nothing else is allowed in the shell):\n${selfCheck.map((c) => `    ${c}`).join("\n")}`
          : "",
      round: String(round),
      roundLimit: String(Math.max(round, this.cap(id))),
      changes:
        (this.pkg(id).changes ?? []).length > 0
          ? `\n## Change requests from the player (made after this package was first finished; they are part of your brief, newest last, and win over the contract where the two disagree)\n${(this.pkg(id).changes ?? []).map((c, i) => `${i + 1}. ${c}`).join("\n")}\n`
          : "",
      depNotes: this.depNotesText(id),
      timeLimit: `${Math.max(1, Math.round(this.o.builderTimeoutMs / 60_000))} minutes`,
      feedback: this.feedback(id, round),
      packContract: this.packContract,
      manifest: this.wsManifestText(id).trimEnd(),
      registers: JSON.stringify(spec.registers ?? {}),
      optionalFields: this.optionalFieldsText(),
      reference: this.referenceText(),
    });
  }

  private async callBuilder(id: string, spec: PackageSpec, round: number): Promise<RunResult> {
    const ws = this.wsDir(id);
    const derived = deriveBashAllowlist(this.o.verifier.location, spec.acceptance, ws, this.dir("reports", `self-${id}`));
    for (let attempt = 1; ; attempt++) {
      const prompt = this.buildPrompt(id, spec, round, derived.commands);
      const refBefore = fs.existsSync(this.refDir()) ? snapshot(this.refDir()) : undefined;
      fs.mkdirSync(this.dir("reports", `self-${id}`), { recursive: true });
      const res = await this.o.builder.run({
        prompt,
        mode: "edit",
        cwd: ws,
        timeoutMs: this.o.builderTimeoutMs,
        ...(this.o.model ? { model: this.o.model } : {}),
        ...(derived.allow.length > 0 ? { bash: { allow: derived.allow, deny: derived.deny } } : {}),
        ...(refBefore ? { addDirs: [this.refDir()] } : {}),
        meta: { role: "builder", package: id, round },
      });
      // The reference copy is outside the workspace but inside the builder's reach: a write there is recorded.
      const refTouched = refBefore && JSON.stringify(refBefore) !== JSON.stringify(snapshot(this.refDir()));
      const conduct = builderConduct(res.raw);
      if (refTouched) {
        // Put the reference copy back as it was, so the next builder reads the real thing.
        conduct.notes.push("the builder changed files under ref/ (outside its workspace); the reference copy was restored");
        fs.rmSync(this.refDir(), { recursive: true, force: true });
        this.prepareReference();
      }
      const transcript = this.reportPath(`${id}-r${round}-builder`);
      fs.mkdirSync(path.dirname(transcript), { recursive: true });
      fs.writeFileSync(
        transcript,
        JSON.stringify(
          {
            schema: "tl.foreman.transcript/1",
            adapter: this.o.builder.name,
            package: id,
            round,
            attempt,
            mode: "edit",
            cwd: ws,
            timeoutMs: this.o.builderTimeoutMs,
            bash: { allow: derived.allow, deny: derived.deny, rejected: derived.rejected },
            conduct,
            prompt,
            result: { ok: res.ok, outcome: res.outcome, text: res.text, json: res.json, error: res.error, tokensIn: res.tokensIn, tokensOut: res.tokensOut, durationMs: res.durationMs, observed: res.observed },
            raw: res.raw,
          },
          null,
          1,
        ) + "\n",
      );
      this.append({
        type: "builder_run",
        package: id,
        round,
        adapter: this.o.builder.name,
        mode: "edit",
        model: res.model ?? this.o.model ?? "default",
        outcome: res.outcome,
        durationMs: Math.max(0, Math.round(res.durationMs)),
        ...(res.tokensIn !== undefined ? { tokensIn: res.tokensIn } : {}),
        ...(res.tokensOut !== undefined ? { tokensOut: res.tokensOut } : {}),
        ...(res.tokensCacheRead !== undefined ? { tokensCacheRead: res.tokensCacheRead } : {}),
        transcript: this.rel(transcript),
      });
      // What the child itself reports beats what we inferred from outside: a contradiction is logged at once.
      const seen = res.observed?.billingMode;
      if (seen !== undefined && this.s.billing && seen !== this.s.billing.mode) {
        this.append({
          type: "billing",
          adapter: this.o.builder.name,
          mode: seen,
          evidence: `the CLI's own init event reports apiKeySource=${res.observed?.apiKeySource ?? "?"}, which contradicts the probe`,
        });
      }
      if (res.outcome === "error" && res.error?.kind === "rate_limit" && attempt <= this.o.rateLimitRetries) {
        const waitMs = res.error.retryAfterMs ?? this.o.rateLimitBackoffMs * 2 ** (attempt - 1);
        const reason = `rate_limit: ${clip(res.error.message, 200)}`;
        this.append({ type: "package_state", package: id, state: "blocked", round, cause: "budget", detail: reason });
        await this.gate.pauseFor(reason, waitMs);
        await this.gate.wait();
        this.append({ type: "package_state", package: id, state: "running", round, detail: "retry after rate limit" });
        continue;
      }
      return res;
    }
  }

  // ---------- the end of a job ----------

  private async finish(): Promise<void> {
    // Promoted already and pack/ has not changed since: nothing to verify or promote again. A merge after the last
    // promotion (a change request) goes through the whole final verification and a NEW promotion.
    if (this.s.promoted && !this.s.mergedSincePromotion) {
      const unmade = this.s.changes.length > 0 ? "; no merge since the last promotion (a change that was asked for was not made: see the package's detail)" : "";
      this.endJob("done", `all packages promoted${unmade}`);
      return;
    }
    const nth = this.s.promotions.length + 1;
    const packDir = this.dir("pack");
    let tests: string[] = [];
    try {
      tests = readManifest(packDir).tests;
    } catch {
      /* lint below reports a broken manifest */
    }
    // The whole pack once more, now through V4: every bot the manifest lists must play the game to its end.
    const final: Acceptance[] = [
      ...PACK_GATE,
      { level: "V3", verb: "invariants", args: [] },
      ...tests.map((t): Acceptance => ({ level: "V4", verb: "bot", args: [`--test=${t}`] })),
    ];
    for (const a of final) {
      const stem = a.verb === "bot" ? `final-bot-${path.basename(a.args[0] ?? "x", ".gd")}` : `final-${a.verb}`;
      const vr = await this.verifyLogged(a, packDir, stem, { round: 1 });
      if (!vr.ok && vr.inconclusive !== undefined) {
        // N3b: the machine was busy during the final verification: the job waits, it has not failed.
        this.append({ type: "job_state", state: "paused", reason: clip(`machine busy: the final verification (${a.verb}) was inconclusive; resume when the machine is free. ${vr.inconclusive}`, 600) });
        return;
      }
      if (!vr.ok) {
        this.endJob("failed", clip(`final verification failed at ${a.verb} (${vr.level}): ${vr.summary}`, 400));
        return;
      }
    }
    // N3: a pack that is promoted AGAIN (after a change request) is photographed first, so that whoever asked for the
    // change can look at it: the declared cameras at the usual frames, into captures/promotion<n>-<cam>-f<frame>.png.
    // No critic, no gate; the paths are in a `note` on the package that was re-opened last.
    if (nth > 1) {
      const last = [...this.log.events].reverse().find((e) => e.type === "reopened");
      const owner = last && last.type === "reopened" && this.s.packages[last.package] ? last.package : (this.s.order[0] as string);
      const shots = await this.captureSet(`promotion${nth}`, owner, tests[0]);
      if (shots.length > 0) this.append({ type: "note", package: owner, round: this.pkg(owner).round, text: `${FOREMAN_NOTE}pictures of the pack as it is promoted the ${nth}${nth === 2 ? "nd" : nth === 3 ? "rd" : "th"} time (after the change): ${shots.join(", ")}` });
    }
    if (this.o.promote) {
      // JOB.md (second round): promotion goes to <job>/promoted/<pack id>/ by default, and also when the engine
      // directory was asked for but cannot be written, so a job can always end `promoted`.
      const engineDir = this.o.verifier.location.engineDir;
      const asked = this.o.promoteTo ?? "job";
      const toEngine = asked === "engine" && engineWritable(engineDir);
      let pr;
      try {
        // N3: an earlier promotion under the job directory is never overwritten. The first goes to promoted/<pack id>/
        // (as before), the n-th to promoted/<pack id>@<version>/ beside it; the last `promoted` event names the
        // current one. The engine's packs/ holds one pack per id, so there the newer one replaces the older.
        const dirName = nth > 1 ? `${this.s.packId ?? "pack"}@${this.jobIdentity().version}` : undefined;
        pr = toEngine ? promotePack(packDir, engineDir, this.s.packId) : promotePack(packDir, this.jobDir, this.s.packId, "promoted", dirName);
      } catch (e) {
        this.endJob("failed", clip(`promotion refused: ${e instanceof Error ? e.message : String(e)}`, 400));
        return;
      }
      this.append({ type: "promoted", packId: pr.packId, version: pr.version, dest: pr.dest });
      const where = toEngine ? "into the engine (packs/)" : `under the job directory (${pr.dest})${asked === "engine" ? "; the engine directory is not writable" : ""}`;
      this.endJob("done", `pack verified V0 to V4 and promoted ${where}${nth > 1 ? ` (promotion ${nth} of this job; the earlier one is kept)` : ""}`);
    } else {
      this.endJob("done", "pack verified V0 to V4; promotion was not requested");
    }
  }

  /**
   * Captures of pack/ for every declared camera at the usual frames, named <label>-<cam>-f<frame>.png. Each is a
   * `verify` event (capture, V5); a capture that fails is tried once more and then left out. Returns the paths.
   */
  private async captureSet(label: string, after: string, bot: string | undefined): Promise<string[]> {
    const packDir = this.dir("pack");
    let cameras: string[] = [];
    try {
      cameras = readManifest(packDir).cameras;
    } catch {
      /* no manifest: no captures */
    }
    const out: string[] = [];
    for (const cam of cameras) {
      for (const frame of this.captureFramesFor(bot)) {
        const file = this.dir("captures", `${label}-${cam}-f${frame}.png`);
        let ok = false;
        for (let attempt = 1; attempt <= 2 && !ok; attempt++) {
          fs.mkdirSync(path.dirname(file), { recursive: true });
          fs.rmSync(file, { force: true });
          const vr = await this.o.verifier.run({
            verb: "capture",
            args: [`--cam=${cam}`, `--frame=${frame}`, `--out=${toPosix(file)}`, `--res=${this.o.captureRes ?? "1280x720"}`, ...(bot !== undefined ? [`--test=${bot}`] : [])],
            packDir,
            reportFile: this.reportPath(`${label}-capture-${cam}-f${frame}`),
          });
          ok = vr.ok && fs.existsSync(file);
          this.append({ type: "verify", round: 1, level: vr.level, verb: vr.verb, ok, report: this.rel(vr.reportFile), ...(vr.exitCode !== undefined ? { exitCode: vr.exitCode } : {}), after });
        }
        if (ok) out.push(this.rel(file));
      }
    }
    return out;
  }

  /** The end of a job. The reducer closes the budget's derived state on this event (joblog.ts). */
  private endJob(state: "done" | "failed", reason: string): void {
    this.append({ type: "job_state", state, reason });
  }

  /**
   * Dry check: the builder prompt of every package of the plan, assembled exactly as a run would assemble it for the
   * package's current round (reference copy prepared, composed manifest, notes of dependencies, self-check
   * commands). No builder is called and no event is written.
   */
  previewBuilderPrompts(only?: string): { package: string; round: number; prompt: string }[] {
    this.log = JobLog.open(this.jobDir, this.o.now ? { now: this.o.now } : {});
    try {
      if (this.s.plan.length === 0) throw new ForemanError(`job ${this.s.job} has no plan_set yet (run \`foreman plan\`)`);
      this.prepareReference();
      return this.s.plan
        .filter((p) => only === undefined || p.id === only)
        .map((p) => {
          const round = this.pkg(p.id).round;
          const derived = deriveBashAllowlist(this.o.verifier.location, p.acceptance, this.wsDir(p.id), this.dir("reports", `self-${p.id}`));
          return { package: p.id, round, prompt: this.buildPrompt(p.id, p, round, derived.commands) };
        });
    } finally {
      this.log.close();
    }
  }
}
