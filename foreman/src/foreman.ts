// The package loop: packages in dependency order, up to N at once, each in ws/<package>/.
// builder run -> verification -> (failure: report back, next round) -> merge in-scope files -> whole pack V0..V2.
// Everything that happens is an event in job.jsonl first; a kill at any line resumes from the log.
import fs from "node:fs";
import path from "node:path";
import type { Acceptance, BudgetPolicy, Cause, JobEvent, Milestone, PackageSpec } from "./events.js";
import { JobLog, changeReason, type JobState, type PackageView } from "./joblog.js";
import type { RunResult } from "./builder/types.js";
import { deriveBashAllowlist } from "./builder/allowlist.js";
import type { VerifyResult } from "./verifier.js";
import { BudgetGate, budgetVerdict } from "./budget.js";
import { copyDir, hashFile, listFiles, matchesAny, pruneEmptyDirs, snapshot } from "./scope.js";
import { engineWritable, promotePack, readManifest } from "./promoter.js";
import { existingText, prepareReference, referenceText } from "./reference.js";
import { cardBriefSection, cardLimits, cardsPlannerText } from "./cards.js";
import { packIsLastPromotion, restoreLastPromotion } from "./unmade.js";
import { runHandChecks, sendBackHands } from "./handcheck.js";
import { PKG_ROOT, REPO_ROOT, stripBom, toPosix } from "./paths.js";
import { CARRIED_FIELDS, MANIFEST_FILE, PACK_VERSION, kernelApiFor, acceptedCarriedFields, engineKnowsBase, carriedOf, composeManifest, depClosure, dependants, manifestText, mergeCarried, type Carried } from "./manifest.js";
import { builderFeelSection, servesLine } from "./roomtext.js"; // JOB.md 2026-11-21: builders read the design
import { briefText, critic, render, replanPackages, type GenerateCall, type PackageLine, type PlannerInput, type ReplanInput } from "./designer.js";
import { NEW_PACKAGE, grow, ownerOrNew, wireWaits, type GrowHost } from "./grow.js";
import { FINAL_NOTE, fastFinal, fastMerge, fastPromotion, mergeNote, roundAcceptance, whatChangedNote } from "./fastchange.js"; // E4b: a data-only change // E4 (24-25 Nov): a change may add a package
import { removedSince } from "./removal.js"; // H1 (E5e): what a change removed, named
import { criticRubric, inReach, phaseLine, phaseStep, replanPhases, stuckText, waitsForVerdict } from "./phases.js"; // JOB.md 2026-11-20: phases
import { writeGenerateCalls } from "./transcript.js";
import { botFinish, botMoments, planShots } from "./shots.js";
import { coreRouteOf, templateOf } from "./templates.js";
import { CARTRIDGE_INVALID, startFromBase } from "./coreroute.js"; // E3 of 24 Nov: a game on a core starts from the base
import { cartridgeChange, coreDataGate, diffRound, jobCore, phaseCheck } from "./coregate.js";
import { changeCandidates, coreChangeOwner } from "./coreowner.js"; // E3f: on a core, a change never goes to the base
import { decideLook, filmLook, hudArgs, hudOn, sendBack, stripsOn, verdictOfLook } from "./quality.js"; // JOB.md 2026-11-21: the quality loop
import { QUALITY_PAUSE, qualityNext } from "./quality_state.js"; // L2b: each milestone filmed with its newest packages' own bots
import { isFakeRunner, verbsFor, type RunnerVerbs } from "./verbs.js";
import { drainInbox } from "./inbox.js";
import { FINAL_FAILED, PACK_TEST_FAILED, PACK_TEST_NOT_MINE, STARVED, isStarved, presentValuesText, starvedStalls } from "./p10.js";
export { FINAL_FAILED, PACK_TEST_FAILED, PACK_TEST_NOT_MINE, STARVED, isStarved, presentValuesText, starvedStalls };
import type { ForemanOptions } from "./options.js"; // P10b: the options type and the pure functions live in their own modules; everything exported here still is
import { MACHINE_BUSY, NOT_LOAD, PACK_STALL, classifyStalls, clockDetail, cpuLoad, diedSilently, frameFigures, medianOverHalfBudget, restsOnAClock, stallOf, waitForQuiet, type GateFailure, type Stall, type Verified } from "./machine.js";
import { FOREMAN_NOTE, builderConduct, clip, countKitUse, parseDeviations, statesKitReason, type KitFigures } from "./conduct.js";
import { packTest, packTestsFor, finalLimit, finalSent, sendBackFinal, type GateHost } from "./p10gate.js";
// Why a round runs is one typed fold over the log (rounds.ts); the fixed starts of `detail` live there and are re-exported.
import { CHANGE_ROUND, CRITIC_ROUND, DEP_CHANGED, KIT_REGRESSION, NO_VISIBLE_CHANGE, criticReopenFor, detailKind, hadCriticRound, isCriticReopenFor, queuedDetail, requeueDetail, roundCap, roundKindOf, roundKinds, type RoundKind } from "./rounds.js";
export { CHANGE_ROUND, CRITIC_ROUND, DEP_CHANGED, KIT_REGRESSION, NO_VISIBLE_CHANGE };
export type { ForemanOptions, KitFigures, Stall };
export { FOREMAN_NOTE, MACHINE_BUSY, NOT_LOAD, PACK_STALL, builderConduct, classifyStalls, clockDetail, countKitUse, diedSilently, frameFigures, medianOverHalfBudget, parseDeviations, restsOnAClock, stallOf, statesKitReason };

export class ForemanError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ForemanError";
  }
}

/** Causes after which a failed package goes back to the Planner (a refusal, a budget stop or a cancel do not). */
const REPLAN_CAUSES: Cause[] = ["verify_failed", "builder_error", "builder_timeout", "builder_truncated", "no_visible_change", "kit_regression"];

const BUILDER_CAUSE: Record<Exclude<RunResult["outcome"], "ok">, Cause> = { timeout: "builder_timeout", truncated: "builder_truncated", error: "builder_error", refused: "builder_error" };

/** Whole-pack verification after every merge: V0 to V2. */
const PACK_GATE: Acceptance[] = [{ level: "V1", verb: "lint", args: [] }, { level: "V2", verb: "smoke", args: [] }];

function listDetail(label: string, files: string[]): string {
  const shown = files.slice(0, 20).join(", ");
  return `${label}: ${shown}${files.length > 20 ? ` (+${files.length - 20} more)` : ""}`;
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
  private engineApi: string | undefined; // the engine's KERNEL_API (manifest.ts kernelApiFor): every pack.json of the job declares it
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
  /** P10b: what p10gate.ts needs of this Foreman (its functions were methods here). State and log are read live. */
  private get gateHost(): GateHost {
    const log = (): JobLog => this.log;
    const state = (): JobState => this.s;
    return {
      o: this.o,
      get s() {
        return state();
      },
      get events() {
        return log().events;
      },
      dir: (...parts) => this.dir(...parts),
      rel: (abs) => this.rel(abs),
      pkg: (id) => this.pkg(id),
      append: (body) => this.append(body),
      reopen: (id, reason, detail) => this.reopen(id, reason, detail),
      verifyLogged: (a, packDir, stem, where) => this.verifyLogged(a, packDir, stem, where),
      logGenerateCalls: (calls, model) => this.logGenerateCalls(calls, model),
    };
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
      let s = await this.runOpen();
      // P10 item 4: something was put into the inbox while the job was ending (an answer to the question it paused
      // for, a change request on the pack it just promoted): the same process goes on with it, as a resume would.
      for (let again = 0; again < 20 && s.jobState?.state !== "cancelled" && this.takeInbox() > 0; again++) s = await this.runOpen();
      return s;
    } finally {
      this.log.close();
    }
  }

  /**
   * P10 item 4: writes what waits in <job>/inbox.jsonl into the log, each entry as the event it would have been
   * (`answer`, `change_requested`). Synchronous, so it cannot fall between two events of a package. Returns the
   * number of events written.
   */
  private takeInbox(): number {
    const r = drainInbox(this.jobDir, () => this.log.events, () => this.s, (body) => this.append(body));
    return r.appended.length;
  }

  /** P10: the Planner's answer to "which package owns this change request", by the request's seq (this run only). */
  private readonly askedOwners = new Map<number, { owner: string; how: string }>();

  /**
   * True when a pending change request could be applied now: its package (named, or already chosen by the Planner)
   * is finished, merged and idle. One that names none and has not been asked about yet is ready to be asked.
   */
  private changeReady(c: { seq?: number; package?: string; text?: string }, running?: ReadonlyMap<string, unknown>): boolean {
    if (c.text !== undefined && wireWaits(this.s, c.text)) return false; // E4: a wire request waits for the package it wires in
    // No builder is in flight (the start of a run, or the scheduler has returned): as before P10, whatever state
    // the package is in. `foreman change --package X` on a job that failed on X is how X is asked to try again.
    if (running === undefined) return true;
    const id = c.package ?? (c.seq !== undefined ? this.askedOwners.get(c.seq)?.owner : undefined);
    if (id === undefined) return true;
    const p = this.s.packages[id];
    return p !== undefined && p.state === "promoted" && (p.mergedFiles ?? []).length > 0 && !(running?.has(id) ?? false);
  }

  private async runOpen(): Promise<JobState> {
    if (this.s.plan.length === 0) throw new ForemanError(`job ${this.s.job} has no plan_set yet (run \`foreman plan\`)`);
    // A finished job stays finished, unless a change request is waiting (N3): then it goes back to running.
    const waiting = this.s.changes.some((c) => c.state === "pending") || this.s.order.some((id) => this.pkg(id).state !== "promoted");
    if (this.s.jobState?.state === "done" && !waiting) return this.s;
    // A cancelled job stays cancelled unless the caller explicitly asks for its failed packages to be retried.
    if (this.s.jobState?.state === "cancelled" && !this.o.retryFailed) return this.s;
    if (waitsForVerdict(this.s)) return this.s; // a phase waits for the player's verdict: `foreman phase` answers it
    if (this.s.qualityHeld && this.s.jobState?.state === "paused") return this.s; // JOB.md 2026-11-21: `foreman quality` answers it
    // The runner's option list comes from the engine. Without it nothing is started and nothing is written.
    this.verbs = this.o.verbs ?? verbsFor(this.o.verifier.location);
    // JOB.md 2026-11-17: the kernel version every pack.json declares is the engine's own; unreadable, nothing starts.
    this.engineApi = kernelApiFor(this.o.verifier.location);
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
    this.takeInbox();
    this.requeueReopened();
    await this.applyChangeRequests();

    for (;;) {
      // A milestone whose last merge is in the log but whose `milestone` event is not (a kill in between).
      await this.catchUpMilestones();
      this.requeueReopened();
      this.requeueNoVisibleChange();
      await this.schedule();
      // P10 item 4: what arrived while the last builders ran, before anything is decided about the job.
      const took = this.takeInbox();
      if ((await this.applyChangeRequests()) > 0) continue;
      // An answer that arrived just now: the scheduler looks at its package again.
      if (took > 0) continue;
      if (this.s.qualityHeld) { // JOB.md 2026-11-21: still NOT ok after the last revise round: the owner decides (also with run_through)
        this.append({ type: "job_state", state: "paused", reason: QUALITY_PAUSE });
        break;
      }
      const step = await phaseStep(Object.assign(this.gateHost, { grow: (c: { seq: number; text: string }, why: string, head: string) => grow(this.growHost, c, why, head), atPhaseDone: (ph: string) => phaseCheck(this.gateHost, ph) })); // a phase whose packages are all merged is done: pass, or wait for the player
      if (step === "paused") break;
      if (step === "continue") continue;
      const views = this.s.order.map((id) => this.pkg(id));
      if (views.every((p) => p.state === "promoted")) {
        await this.catchUpMilestones();
        if (this.s.qualityHeld) continue; // a look just held the job: the pause above, never a promotion
        // P10 item 2: a failed final verification after a change sends the failure back to a package.
        if (await this.finish()) continue;
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
      this.endJob("failed", clip([stuckText(this.s), failed.length ? `failed: ${failed.join(", ")}` : "", blocked.length ? `blocked: ${blocked.join(", ")}` : "", re.reason].filter(Boolean).join("; "), 600), true);
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
    writeGenerateCalls({ jobDir: this.jobDir, adapter: this.o.builder.name, lastSeq: () => this.s.lastSeq, append: (b) => this.append(b) }, calls, model);
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
      cards: cardsPlannerText(this.refDir()),
      builderTimeoutMs: this.o.builderTimeoutMs,
      ...(s.reviews.length > 0 ? { review: (s.reviews.at(-1) as { notes: string }).notes } : {}), // L1b: the producer's last warnings
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
          ...(this.o.plannerTimeoutMs !== undefined ? { timeoutMs: this.o.plannerTimeoutMs } : {}),
          ...(this.o.maxPackages !== undefined ? { maxPackages: this.o.maxPackages } : {}),
          verbs: this.verbs ?? verbsFor(this.o.verifier.location),
          ...cardLimits(this.refDir()),
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
    this.append({ type: "plan_set", packages: [...kept, ...fresh], ...(s.card !== undefined ? { card: s.card } : {}), ...replanPhases(s, fresh, new Set([...failedIds, ...depIds])) }); // card and phases stay
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
    const pollMs = Math.max(20, this.o.inboxPollMs ?? 1000);
    for (;;) {
      if (fatal === undefined) {
        // P10 item 4: the safe point. Between two awaits nothing else runs, so an `answer` or a `change_requested`
        // written here cannot fall into the middle of a package's round. An answered package is started below, in
        // this same pass, while the other packages go on building. A change request re-opens its package only
        // when that package is finished and idle; until then it waits in the log as `pending`.
        this.takeInbox();
        if (this.s.changes.some((c) => c.state === "pending" && this.changeReady(c, running))) await this.applyChangeRequests(running);
      }
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
          if (this.busyThisRun.has(id) || !inReach(this.s, id)) continue; // a later phase waits for the player's pass
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
      // Wakes when a package ends, or after `inboxPollMs` to look into the inbox (a real timer: `sleep` is a test seam
      // for the pauses the Foreman takes on purpose, and may return at once).
      let timer: NodeJS.Timeout | undefined;
      const tick = new Promise<void>((r) => {
        timer = setTimeout(r, pollMs);
      });
      await Promise.race([...running.values(), tick]);
      clearTimeout(timer);
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
  private jobIdentity(): { packId: string; title: string; version: string; kernelApi: string; base?: string } {
    const n = this.s.promotions.length;
    const version = n === 0 ? PACK_VERSION : PACK_VERSION.replace(/\d+$/, String(n));
    // E3g: a game on a core names its base, so lint counts only its own lines (when this engine's lint knows the key)
    const base = coreRouteOf(this.s.brief?.concept?.template)?.base;
    const knows = base !== undefined && (this.knowsBase ??= isFakeRunner(this.o.verifier.location) || engineKnowsBase(this.o.verifier.location.engineDir));
    return { packId: this.s.packId ?? "game.unnamed", title: this.s.title ?? this.s.packId ?? "Untitled", version, kernelApi: (this.engineApi ??= kernelApiFor(this.o.verifier.location)), ...(knows ? { base } : {}) };
  }
  private knowsBase: boolean | undefined;

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

  /** The last round a package may use (rounds.ts): one round per re-opening by a failed final verification (`finalRounds` counts those per job). */
  private cap(id: string): number {
    return roundCap(this.pkg(id), roundKinds(this.log.events), this.o.roundLimit);
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
    const all = listFiles(ws).filter((f) => f !== MANIFEST_FILE && matchesAny(spec.scope, f) && baseline[f] !== hashFile(path.join(ws, f)));
    // E3f (E5b): the base never merges a file a later package owns, and a re-opened package lists only what differs from pack/
    // (job 1's diff listed match.json and the drill test, byte-identical, so a data-only change took the full path).
    const theirs = spec.kind === "base" ? this.s.plan.filter((p) => p.id !== id).flatMap((p) => p.scope) : [];
    const mine = all.filter((f) => !(theirs.length > 0 && matchesAny(theirs, f) && fs.existsSync(this.dir("pack", f))));
    const had = new Set(this.pkg(id).mergedFiles ?? []);
    const changed = mine.filter((f) => !(had.has(f) && fs.existsSync(this.dir("pack", f)) && hashFile(this.dir("pack", f)) === hashFile(path.join(ws, f))));
    return changed.length > 0 ? changed : mine; // nothing differs (a merge redone after a kill): the same list again
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
        // P10 item 5: starved calls the engine counted in the round before (a round that failed for another reason).
        const before = [resumed ? "resumed" : "", this.starvedDetail(id).replace(/ of this round:/, ` of round ${round - 1}:`)].filter(Boolean).join("; ");
        this.append({ type: "package_state", package: id, state: "running", round, ...(before ? { detail: before } : {}) });
        resumed = false;
        const diff = spec.kind === "base" ? undefined : await diffRound(this.gateHost, id, round, this.wsDir(id));
        if (diff === undefined && this.pkg(id).openQuestion !== undefined) return; // H1: the diff's next try asked the person again (a removal)
        const res = spec.kind === "base" ? this.startFromBase(id, spec, round) : diff ?? (await this.callBuilder(id, spec, round)); // E3: the base, and a cartridge diff, are the Foreman's
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

      let failure: GateFailure | undefined = await coreDataGate(this.gateHost, id, round, this.wsDir(id), this.mergeSet(id)); // E3: a cartridge edit is validated first
      for (const a of failure !== undefined ? [] : roundAcceptance(this.s, spec, round)) { // E4b: a diff round keeps lint + the player check
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
        this.starvedByPackage.delete(id);
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
          detail: clip([`${failure.verb} (${failure.level}) did not pass after ${round} rounds: ${failure.summary}`, this.starvedDetail(id)].filter(Boolean).join(". "), 600),
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
    if (!vr.ok && isStarved(vr)) return this.starvedVerdict(a, packDir, stem, where, vr);
    if (vr.ok || !restsOnAClock(vr)) return vr;
    // The same check failed on a clock twice. Before a builder hears of it, the Foreman asks whether it was the
    // machine (N3b, N3c; the real hockey job of 2026-11-11):
    //   1. only the frame budget, and the MEDIAN frame is over half of it: slow code, to the builder;
    //   2. watchdog stalls with a frame number in every run: at DIFFERENT places -> the machine (a deterministic pack
    //      that stalls in its own code stalls at the same frame every time), whatever a reference run says;
    //      at the SAME place -> the pack, to the builder with the frame;
    //   3. otherwise the gauge: smoke on the engine's reference pack, right after. Busy -> the machine; not busy ->
    //      reported to the builder as measured (a passing reference run is evidence about the moment after, no proof).
    // "The machine" means: a note, a pause, the check again, up to `clockRetries` times; then the round is
    // inconclusive (package blocked with cause machine_busy, job paused). A builder never gets it as feedback.
    const typical = medianOverHalfBudget(vr);
    if (typical !== undefined) return { ...vr, summary: `${vr.summary}. ${typical}` };
    const who = where.package ?? where.after ?? (this.s.order[0] as string);
    const round = this.s.packages[who]?.round ?? 1;
    const tries = Math.max(0, this.o.clockRetries ?? 3);
    const pauses = this.o.clockPausesMs && this.o.clockPausesMs.length > 0 ? this.o.clockPausesMs : [20_000, 40_000, 80_000];
    const sleep = this.o.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
    const what = `${a.verb} on ${where.package !== undefined ? `the workspace of ${where.package}` : "the whole pack"}`;
    const runs: VerifyResult[] = [...(vr.firstRun && restsOnAClock(vr.firstRun) ? [vr.firstRun] : []), vr];
    let last: VerifyResult = vr;
    for (let n = 1; ; n++) {
      const stalls = classifyStalls(runs);
      let figures: string;
      if (stalls.verdict === "pack") {
        const text = `${PACK_STALL}: ${what}: ${stalls.text}`;
        if (where.package !== undefined) this.append({ type: "note", package: where.package, round: where.round, text: `${FOREMAN_NOTE}${text}` });
        return { ...last, summary: `${last.summary}. ${stalls.text}` };
      }
      if (stalls.verdict === "machine_load") figures = `${what}: ${stalls.text}`;
      else {
        const times = frameFigures(runs);
        const ref = await this.measureMachine(a.verb);
        if (ref === undefined) return { ...last, summary: `${last.summary}. The machine could not be measured (no reference pack ${toPosix(this.referencePack())}), so this is reported as it was measured` };
        if (!ref.busy) {
          const text = `${NOT_LOAD}: ${a.verb} failed on a clock (${clip(clockDetail(last), 200)}${times ? `; ${times}` : ""}) and the engine's reference pack, run right after it on the same machine, did not (${ref.what}; ${ref.report}). That is evidence about the moment AFTER the failure, not proof that the machine was free during it (${stalls.text}). Nothing else points at the machine, so the failure is reported as it was measured.`;
          if (where.package !== undefined) this.append({ type: "note", package: where.package, round: where.round, text: `${FOREMAN_NOTE}${text}` });
          return { ...last, summary: `${last.summary}. The engine's reference pack passed right after (${ref.what}; ${ref.report}): the machine was not shown to be busy, so this is reported as it was measured` };
        }
        figures = `${what} failed on a clock (${clip(clockDetail(last), 200)}${times ? `; ${times}` : ""}), and so did the engine's reference pack (${ref.what}; ${ref.report})`;
      }
      if (n > tries) {
        const text = `${MACHINE_BUSY}. ${figures}. Tried ${tries} more time(s) with pauses; the machine stayed busy. This is NOT a verdict about the pack: nothing was sent to the builder. Free the machine and run \`foreman resume\`: the same files are verified again.`;
        this.append({ type: "note", package: who, round, text: `${FOREMAN_NOTE}${text}` });
        return { ...last, inconclusive: text, summary: text };
      }
      const pause = pauses[Math.min(n - 1, pauses.length - 1)] as number;
      this.append({ type: "note", package: who, round, text: `${FOREMAN_NOTE}${MACHINE_BUSY}. ${figures}. Waiting ${Math.round(pause / 1000)} s, then try ${n} of ${tries}.` });
      await sleep(pause);
      await waitForQuiet(() => this.loadNow(), sleep, this.o.busyCpuPct ?? 70, this.o.quietWaitMs ?? 600_000); // H1b: again on a quieter machine
      last = await this.verifyOnce(a, packDir, `${stem}-retry${n}`, where);
      if (!last.ok && isStarved(last)) return this.starvedVerdict(a, packDir, `${stem}-retry${n}`, where, last);
      if (last.ok || !restsOnAClock(last)) return last;
      runs.push(last);
    }
  }

  /**
   * P10 item 5: the runner itself says the machine starved the run (after its own two re-runs of 90 s each). That is
   * the engine's verdict, not a guess of the Foreman's: no reference run, no comparison of frames. The check is tried
   * again after the usual pauses (`clockRetries`, `clockPausesMs`); a run that then gives a real verdict decides.
   * If it stays starved the round is inconclusive: nothing goes to a builder, no round is spent, the package waits
   * with cause `machine_busy` and the job pauses.
   */
  private async starvedVerdict(a: Pick<Acceptance, "verb" | "args">, packDir: string, stem: string, where: { package?: string; round: number; after?: string }, first: VerifyResult): Promise<Verified> {
    const who = where.package ?? where.after ?? (this.s.order[0] as string);
    const round = this.s.packages[who]?.round ?? 1;
    const tries = Math.max(0, this.o.clockRetries ?? 3);
    const pauses = this.o.clockPausesMs && this.o.clockPausesMs.length > 0 ? this.o.clockPausesMs : [20_000, 40_000, 80_000];
    const sleep = this.o.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
    const what = `${a.verb} on ${where.package !== undefined ? `the workspace of ${where.package}` : "the whole pack"}`;
    const said = (vr: VerifyResult): string => clip(vr.report?.errors.find((e) => e.kind === "engine" && /^starved:/.test(e.message))?.message ?? "starved", 240);
    let last = first;
    for (let n = 1; ; n++) {
      const figures = `${STARVED}: ${what} ended exit ${last.exitCode ?? "?"}, not_run, and the engine says why: "${said(last)}" [${this.rel(last.reportFile)}]`;
      if (n > tries) {
        const text = `${MACHINE_BUSY}. ${figures}. Tried ${tries} more time(s) with pauses; the machine stayed busy. This is NOT a verdict about the pack: nothing was sent to the builder and no round was spent. Free the machine and run \`foreman resume\`: the same files are verified again.`;
        this.append({ type: "note", package: who, round, text: `${FOREMAN_NOTE}${text}` });
        return { ...last, inconclusive: text, summary: text };
      }
      const pause = pauses[Math.min(n - 1, pauses.length - 1)] as number;
      this.append({ type: "note", package: who, round, text: `${FOREMAN_NOTE}${MACHINE_BUSY}. ${figures}. Waiting ${Math.round(pause / 1000)} s, then try ${n} of ${tries}.` });
      await sleep(pause);
      last = await this.verifyOnce(a, packDir, `${stem}-starved${n}`, where);
      if (last.ok || !isStarved(last)) return last;
    }
  }

  private loadNow = (): Promise<number | undefined> => (this.o.machineLoad ?? (isFakeRunner(this.o.verifier.location) ? async () => undefined : cpuLoad))();

  private referencePack(): string {
    return this.o.referencePack ?? path.join(this.o.verifier.location.engineDir, "kernel", "examples", "pack_min");
  }

  /**
   * Runs `verb` on the engine's reference pack. `busy` is true when that known-good pack breaks a time limit too.
   * Not a `verify` event (it is not about this job's pack); the report stays in reports/ and is named in a note.
   */
  private async measureMachine(failed: Acceptance["verb"]): Promise<{ busy: boolean; what: string; report: string } | undefined> {
    const load = await this.loadNow(); // H1b: room.sh's measure first: a processor over the day's ceiling is a busy machine
    if (load !== undefined && load > (this.o.busyCpuPct ?? 70)) return { busy: true, what: `the machine's processor was at ${load} % (the room.sh measure; busy above ${this.o.busyCpuPct ?? 70} %)`, report: "no reference run needed" };
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
    this.countStarved(where.package ?? where.after, vr);
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

  private async verifyTwice(a: Pick<Acceptance, "verb" | "args">, packDir: string, stem: string, where: { package?: string; round: number; after?: string }): Promise<VerifyResult & { firstRun?: VerifyResult }> {
    let vr: VerifyResult | undefined;
    let first: VerifyResult | undefined;
    for (let attempt = 1; attempt <= 2; attempt++) {
      vr = await this.o.verifier.run({ verb: a.verb, args: a.args, packDir, reportFile: this.reportPath(attempt === 1 ? stem : `${stem}-again`) });
      this.countStarved(where.package ?? where.after, vr);
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
      if (attempt === 1) first = vr;
      if (attempt === 2) vr = { ...vr, summary: `${vr.summary}. This is the second run with the same ${silent ? "result (the runner ended without output both times)" : "clock-based result"} (the first run is in the log too)` };
    }
    return { ...(vr as VerifyResult), ...(first !== undefined ? { firstRun: first } : {}) };
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
      // P10 item 1: after a change, every test of the pack runs on the candidate before it becomes pack/.
      for (const t of fastMerge(this.s, files) ? [] : packTestsFor(this.gateHost, id, candidate, hadMerged)) { // E4b: none for a data-only change
        const bad = await packTest(this.gateHost, id, round, t, candidate);
        if (bad !== undefined) return bad;
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
    const starved = this.starvedDetail(id);
    this.append({ type: "package_state", package: id, state: "promoted", round, ...(starved ? { detail: starved } : {}) });
    // N3: a package that was merged before and is merged again has changed under the packages that depend on it.
    if (hadMerged && fastMerge(this.s, files)) {
      // E4b: a data-only change: the dependants' files and the milestone's look did not change (fastchange.ts)
      this.append({ type: "note", package: id, round, text: clip(mergeNote(files, dependants(this.s.plan, id)), 1000) });
      return undefined;
    }
    if (hadMerged) await this.reverifyDependants(id);
    await this.maybeMilestone(this.spec(id).milestone, id);
    return undefined;
  }

  // ---------- P10 item 5: what the machine did to a round ----------

  private readonly starvedByPackage = new Map<string, { stalls: number; ms: number; runs: number }>();
  private countStarved(id: string | undefined, vr: VerifyResult): void {
    const s = starvedStalls(vr);
    if (id === undefined || s.stalls <= 0) return;
    const had = this.starvedByPackage.get(id) ?? { stalls: 0, ms: 0, runs: 0 };
    this.starvedByPackage.set(id, { stalls: had.stalls + s.stalls, ms: had.ms + s.ms, runs: had.runs + 1 });
  }
  /** The words for a round's `detail` when the engine counted starved calls in its checks; "" when it counted none. */
  private starvedDetail(id: string): string {
    const s = this.starvedByPackage.get(id);
    this.starvedByPackage.delete(id);
    if (!s || s.stalls <= 0) return "";
    return `starved_stalls ${s.stalls}${s.ms > 0 ? ` (${Math.round(s.ms)} ms)` : ""} in ${s.runs} check run(s) of this round: the machine held the processor back; the engine's limits count processor time, so nothing failed for it`;
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
      this.append({ type: "package_state", package: id, state: "queued", round: p.roundBase, detail: clip(requeueDetail(this.log.events, this.s, id), 1500) });
    }
  }

  private rootId(): string {
    return this.s.plan.find((p) => p.deps.length === 0)?.id ?? (this.s.order[0] as string);
  }

  /** E4: what grow.ts needs of this Foreman; the planner's input is built as for a re-plan. State is read live. */
  private get growHost(): GrowHost {
    const state = (): JobState => this.s;
    const model = this.o.plannerModel ?? this.o.model;
    const input = (): PlannerInput | undefined => {
      const s = this.s;
      if (!s.brief || !s.sentence || !s.packId || !s.title) return undefined;
      const api = this.kernelApiText();
      return { sentence: s.sentence, packId: s.packId, title: s.title, brief: s.brief, packContract: this.packContract, ...(api !== undefined ? { kernelApi: api } : {}),
        existing: existingText(this.refDir()), cards: cardsPlannerText(this.refDir()), builderTimeoutMs: this.o.builderTimeoutMs };
    };
    return {
      get s() {
        return state();
      },
      builder: this.o.builder,
      ...(model ? { model } : {}),
      limits: { ...(this.o.plannerTimeoutMs !== undefined ? { timeoutMs: this.o.plannerTimeoutMs } : {}), verbs: this.verbs ?? verbsFor(this.o.verifier.location), ...cardLimits(this.refDir()) },
      plannerInput: input,
      append: (body) => this.append(body),
      logGenerateCalls: (calls, m) => this.logGenerateCalls(calls, m),
    };
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
  private async applyChangeRequests(running?: ReadonlyMap<string, unknown>): Promise<number> {
    let applied = 0;
    for (const c of this.s.changes.filter((x) => x.state === "pending")) {
      // P10 item 4: a request that arrives while its package is being built waits until that package is finished.
      if (!this.changeReady(c, running)) continue;
      let owner = c.package;
      let how = "the request names the package";
      if (owner === undefined) {
        // The Planner is asked ONCE per request in a run; the answer is kept while the request waits for its package.
        let known = this.askedOwners.get(c.seq);
        if (known === undefined) {
          const model = this.o.plannerModel ?? this.o.model;
          const res = await ownerOrNew(this.o.builder, { sentence: this.s.sentence ?? "", title: this.s.title ?? "", text: c.text, packages: changeCandidates(this.packageLines(), this.s.plan, jobCore(this.gateHost)) }, model ? { model } : {});
          this.logGenerateCalls(res.calls, model);
          known = res.ok
            ? { owner: res.value.package, how: res.value.package === NEW_PACKAGE ? clip(res.value.reason, 200) : `the Planner names the package: ${clip(res.value.reason, 200)}` }
            : { owner: this.rootId(), how: `the Planner gave no usable answer (${clip(res.reason, 160)}), so the root package takes it` };
          this.askedOwners.set(c.seq, known);
        }
        owner = known.owner;
        how = known.how;
        if (owner === NEW_PACKAGE) {
          // E4: no package's files hold the request: the plan grows (grow.ts), once no builder runs
          if (running !== undefined) continue;
          const g = await grow(this.growHost, c, how);
          if ("added" in g) {
            applied += 1;
            continue;
          }
          owner = this.rootId();
          how = `${g.reason}, so the root package takes it`;
          this.askedOwners.set(c.seq, { owner, how });
        }
        const moved = coreChangeOwner(this.s.plan, jobCore(this.gateHost), owner, c.text); // E3f (E5b job 2): never the base on a core
        if (moved.why !== undefined) [owner, how] = [moved.owner, `${how}; ${moved.why}`];
        // Asked while other packages ran: the package it names must be finished and idle as well, or the request waits.
        if (!this.changeReady({ ...c, package: owner }, running)) continue;
      }
      this.reopen(owner, `${changeReason(c.seq)}; ${how}: ${clip(c.text, 300)}`, `${CHANGE_ROUND}: ${c.text}`);
      await cartridgeChange(this.gateHost, owner, this.pkg(owner).round, c.text); // E3b: on a core, a cartridge diff first (coregate.ts)
      applied += 1;
    }
    return applied;
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
    const sentBack = p.roundBase !== undefined || hadCriticRound(roundKinds(this.log.events), id);
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
    if (after.kitUse < before.kitUse) worse.push(`kit parts used fell from ${before.kitUse} to ${after.kitUse} ("kind" entries in data/*.json but a core's cartridge and rules, plus TLKit./TLRigs. calls in scripts)`);
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
    const tail = (rel: string, milestone: string): string => path.basename(rel).slice(milestone.length);
    // L2b: only the first test's shot (<m>-<cam>-f<frame>.png) is the same every milestone; a package's own bot is not.
    const firstShot = (list: string[], ms: string): string[] => list.filter((c) => /^-[a-z0-9_]+-f\d+\.png$/.test(tail(c, ms)));
    captures = firstShot(captures, m);
    const prev = [...this.s.milestones].reverse().find((x) => x.milestone !== m); // 21 Nov: not a revise round's own earlier look
    if (captures.length === 0 || !prev || firstShot(prev.captures, prev.milestone).length !== captures.length) return undefined;
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
    const f = bot !== undefined ? botFinish(this.jobDir, this.log.events, bot) : undefined;
    return f !== undefined ? [Math.max(1, Math.round(f * 0.25)), Math.max(2, Math.round(f * 0.75))] : [120, 480];
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
    return roundKindOf(this.log.events, id, round) === "critic_kit_retry";
  }

  private isCriticRound(id: string, round: number): boolean {
    return roundKindOf(this.log.events, id, round) === "critic";
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
    const members = this.s.plan.filter((p) => p.milestone === m).map((p) => p.id);
    if (members.length === 0 || !members.every((x) => this.pkg(x).state === "promoted")) return;
    // N3: a revise round for this milestone went to another package (the one the critic named) and is not over yet.
    const stillOut = this.log.events.some((e) => e.type === "reopened" && isCriticReopenFor(e.reason, m) && this.s.packages[e.package] !== undefined && !["promoted", "failed"].includes(this.pkg(e.package).state));
    if (stillOut) return;
    // JOB.md 2026-11-21, the quality loop (quality_state.ts decides from the log, quality.ts acts).
    const q = qualityNext(this.log.events, m, members);
    if (q.next === "closed" || q.next === "held") return;
    if (q.next === "send") return sendBack(this.gateHost, m, members, lastPackage, q.round, { ...q.look, verdict: verdictOfLook(this.gateHost, q.look) }, q.note);
    let cameras: string[] = [];
    let tests: string[] = [];
    try {
      const mf = readManifest(this.dir("pack"));
      cameras = mf.cameras;
      tests = mf.tests;
    } catch {
      /* no manifest: no captures */
    }
    const shots = planShots(this.s.plan, this.log.events, members, tests, (b) => botFinish(this.jobDir, this.log.events, b), this.o.captureFrames, (b) => botMoments(this.jobDir, this.log.events, b), templateOf(this.s.brief?.concept?.template?.id)?.filmFirst); // N4 rounds 8, 16: film the exchange, its signature contacts first
    const film = await filmLook(this.gateHost, m, shots, cameras, lastPackage, this.o.strips !== false && stripsOn(this.verbs), hudOn(this.verbs)); // H1: filmed as a person sees it
    const { captures, notes } = film;
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
    await decideLook(this.gateHost, m, members, lastPackage, film, shots, q.round, notes);
  }

  // ---------- builder calls ----------

  /** What goes back to the builder as the next round's prompt, derived from the log alone. */
  private feedback(id: string, round: number): string {
    const parts: string[] = [];
    const p = this.pkg(id);
    if (p.lastAnswer !== undefined) parts.push(`Answer to your question: ${p.lastAnswer}`);
    // Sent back after a merge: no visible change (art pass), or the critic's one extra round.
    const queuedAs = (...kinds: RoundKind[]): string | undefined => queuedDetail(this.log.events, id, round, kinds);
    // N3: re-opened after it was finished (a change request, a changed dependency), or not merged for a kit regression.
    const change = queuedAs("change");
    if (change !== undefined) {
      parts.push(
        `This package was finished and merged. The player now asks for a change, and this package owns the files that must change:\n${change}\n` +
          "Your files are in the working directory as they were merged; the other packages' files are as the pack holds them now. Make the change inside your scope and keep everything else working: your acceptance runs again, and then the acceptance of every package that depends on yours. " +
          "Where the change request and your contract disagree, the change request wins; say what you changed under DEVIATIONS, because the builders of dependent packages read that.",
      );
    }
    const depChanged = queuedAs("dep_changed");
    if (depChanged !== undefined) {
      parts.push(`This package was finished and merged, and has been re-opened:\n${depChanged}\nThe changed files of that package are in your working directory now. Adapt your own files to them (the report is below); do not try to change the other package.`);
    }
    // P10 item 2: re-opened because the final verification of the whole pack failed after this package merged.
    const fin = queuedAs("final_failed");
    if (fin !== undefined) {
      const rel = /\[report: ([^\]]+)\]/.exec(fin)?.[1];
      const body = rel !== undefined ? this.readClipped(this.dir(rel), 12_000) : undefined;
      parts.push(
        `This package was finished and merged, and the WHOLE pack then failed its final verification, so nothing was promoted:\n${fin}\n` +
          "The other packages' files are in your working directory as the pack holds them now. Change your own files so that the check passes again, without undoing what a change request asked for (see the change requests above, if any). You have ONE round for this: your acceptance runs, then every test of the pack with your files merged in, then the final verification again. Say what you changed under DEVIATIONS." +
          (body !== undefined ? `\nReport of the failed check (tl.verify/1):\n${body}` : ""),
      );
    }
    // P10 item 1: the round before was refused because a test of the pack failed with its files merged in.
    const packTest = [...this.s.notes].reverse().find((n) => n.package === id && n.round === round - 1 && n.text.startsWith(`${FOREMAN_NOTE}${PACK_TEST_FAILED}`));
    // E3 of 24 Nov: the round before changed a cartridge the validator refused (coregate.ts): its problems.
    const cart = [...this.s.notes].reverse().find((n) => n.package === id && n.round === round - 1 && n.text.startsWith(`${FOREMAN_NOTE}${CARTRIDGE_INVALID}`));
    if (cart) parts.push(`Round ${round - 1} was not run: ${cart.text.slice(FOREMAN_NOTE.length)}`);
    if (packTest) parts.push(`${packTest.text.slice(FOREMAN_NOTE.length)}\nEvery test of the pack must pass with your files in, not only your own acceptance: the report of the failed test is below. Change YOUR files; you cannot change the other package or its test.`);
    // N3b: a clock-based failure reaches the builder only after the machine was measured; say so.
    const notLoad = [...this.s.notes].reverse().find((n) => n.package === id && n.round === round - 1 && (n.text.startsWith(`${FOREMAN_NOTE}${NOT_LOAD}`) || n.text.startsWith(`${FOREMAN_NOTE}${PACK_STALL}`)));
    if (notLoad) parts.push(`${notLoad.text.startsWith(`${FOREMAN_NOTE}${PACK_STALL}`) ? "The Foreman compared the two runs before reporting this" : "The Foreman measured the machine before reporting this"}: ${notLoad.text.slice(FOREMAN_NOTE.length)}`);
    const kit = queuedAs("kit_regression");
    if (kit !== undefined) parts.push(`Round ${round - 1} passed its checks but was not merged:\n${kit}\nYour files from that round are still in the working directory.`);
    const sentBack = queuedAs("critic", "no_visible_change");
    if (sentBack !== undefined) {
      parts.push(
        `Round ${round - 1} passed the Verifier and was merged, but the package was sent back: ${sentBack}\n` +
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
      const base = (report: string): string => report.replace(/(\.verdict)?\.json$/i, "").replace(/-s\d+$/, "").replace(/(-(again|retry\d+|starved\d+))+$/, "");
      const mine = events.filter((e): e is Extract<JobEvent, { type: "verify" }> => e.type === "verify" && e.round === prev && (e.package === id || (e.package === undefined && e.report.startsWith(packPrefix))));
      const failing = [...mine].reverse().find((e) => !e.ok && !mine.some((x) => x.ok && x.seq > e.seq && base(x.report) === base(e.report)));
      // N3c: the runs of that check, read again from their reports. If the watchdog stopped them at different frames
      // it was the machine (also in a log written before this rule existed): the builder is told exactly that and
      // is NOT given the report as a failure of its pack.
      const sameCheck = failing ? mine.filter((e) => !e.ok && base(e.report) === base(failing.report)) : [];
      const reread = sameCheck.map((e): VerifyResult | undefined => {
        try {
          const report = JSON.parse(fs.readFileSync(this.dir(e.report), "utf8")) as VerifyResult["report"];
          return report && Array.isArray(report.checks) && Array.isArray(report.errors) ? { verb: e.verb, level: e.level, ok: false, report, reportFile: e.report, verdictFile: e.report, flags: [], summary: "", durationMs: 0 } : undefined;
        } catch {
          return undefined;
        }
      });
      const stalled = reread.length >= 2 && reread.every((r) => r !== undefined) ? classifyStalls(reread as VerifyResult[]) : undefined;
      if (failing && stalled?.verdict === "machine_load") {
        parts.push(
          `Round ${prev} did not pass ${failing.verb} (${failing.level}), but NOT because of your pack: ${stalled.text}\n` +
            "Do not look for a stall in your code or in another package's files, do not ask a question about it and do not restructure anything for it. If an earlier message of the Foreman called this the pack's own time, that was wrong. Check that your files still meet your contract and finish; the same check will simply run again.",
        );
      } else if (failing && failing.type === "verify") {
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
    const brief = s.brief ? briefText(s.brief) + phaseLine(s, id) + servesLine(s.brief, spec) : "(no brief in the log)";
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
          ? `\n## Change requests from the player (made after this package was first finished; they are part of your brief, newest last, and win over the contract where the two disagree)\n${(this.pkg(id).changes ?? []).map((c, i) => `${i + 1}. ${c}`).join("\n")}\n${this.presentValues(id, spec)}`
          : "",
      depNotes: this.depNotesText(id),
      timeLimit: `${Math.max(1, Math.round(this.o.builderTimeoutMs / 60_000))} minutes`,
      feedback: this.feedback(id, round),
      packContract: this.packContract,
      manifest: this.wsManifestText(id).trimEnd(),
      registers: JSON.stringify(spec.registers ?? {}),
      optionalFields: this.optionalFieldsText(),
      reference: this.referenceText(),
      card: cardBriefSection(this.refDir(), s.card),
      feel: s.brief?.design !== undefined ? builderFeelSection(s.brief.concept?.template) : "",
    });
  }

  /** P10 item 3: the values a change request is measured against, read from the package's workspace (or pack/). */
  private presentValues(id: string, spec: PackageSpec): string {
    const ws = this.wsDir(id);
    const text = presentValuesText(fs.existsSync(path.join(ws, MANIFEST_FILE)) ? ws : this.dir("pack"), spec.scope);
    return text === "" ? "" : `\n${text}\n`;
  }

  /**
   * E3 of 24 Nov: a "start from the base" package (kind "base", coreroute.ts) is the Foreman's own round: the job's copy
   * of the base goes into the workspace, and the round is verified and merged like a builder's. No builder, no tokens.
   */
  private startFromBase(id: string, spec: PackageSpec, round: number): RunResult {
    const r = startFromBase(this.wsDir(id), this.refDir(), this.dir("pack"), spec, this.s.plan, coreRouteOf(this.s.brief?.concept?.template));
    this.append({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${r.text}` });
    return r.ok ? { ok: true, outcome: "ok", raw: { foreman: "base", files: r.files }, durationMs: 0 } : { ok: false, outcome: "refused", raw: { foreman: "base" }, durationMs: 0, error: { kind: "refusal", message: r.text } };
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

  private async finish(): Promise<boolean> {
    // Promoted already and pack/ has not changed since: nothing to verify or promote again. A merge after the last
    // promotion (a change request) goes through the whole final verification and a NEW promotion.
    if (this.s.promoted && (!this.s.mergedSincePromotion || packIsLastPromotion(this.gateHost))) {
      const unmade = this.s.changes.length > 0 ? "; no merge since the last promotion (a change that was asked for was not made: see the package's detail)" : "";
      this.endJob("done", `all packages promoted${unmade}`);
      return false;
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
    // E5 (25 Nov): a game on a core is held to what its base is held to; the base (thirdjam's whole match) fails the
    // invariants frame budgets by itself, so the final verification of every core game would fail on it.
    const core = coreRouteOf(this.s.brief?.concept?.template) !== undefined;
    const final: Acceptance[] = [
      ...PACK_GATE,
      ...(core ? [] : [{ level: "V3", verb: "invariants", args: [] } as Acceptance]),
      ...tests.map((t): Acceptance => ({ level: "V4", verb: "bot", args: [`--test=${t}`] })),
    ];
    const fast = fastPromotion(this.s, this.log.events); // E4b: every merge since the last promotion was data only
    if (fast) this.append({ type: "note", package: this.lastReopened(), round: this.pkg(this.lastReopened()).round, text: FINAL_NOTE });
    for (const a of fast ? fastFinal(final) : final) {
      const stem = a.verb === "bot" ? `final-bot-${path.basename(a.args[0] ?? "x", ".gd")}` : `final-${a.verb}`;
      const vr = await this.verifyLogged(a, packDir, stem, { round: 1 });
      if (!vr.ok && vr.inconclusive !== undefined) {
        // N3b: the machine was busy during the final verification: the job waits, it has not failed.
        this.append({ type: "job_state", state: "paused", reason: clip(`machine busy: the final verification (${a.verb}) was inconclusive; resume when the machine is free. ${vr.inconclusive}`, 600) });
        return false;
      }
      if (!vr.ok) {
        // P10 item 2: after a change (an earlier promotion exists) the failure goes back to a package while rounds
        // are left; when they are spent the change was not made and the job ends on the earlier promotion.
        const back = sendBackFinal(this.gateHost, a, vr);
        if (back === "sent") return true;
        if (back === "spent") {
          const p = this.s.promoted;
          this.endJob("done", clip(`the change was NOT made: the final verification still fails at ${a.verb} (${vr.level}) after ${finalSent(this.gateHost)} round(s) that it sent back to a package (limit ${finalLimit(this.gateHost)}); the job ends on the earlier promotion ${p?.packId ?? "?"} ${p?.version ?? "?"} (${p?.dest ?? "?"}), which is untouched and still the pack to play.${restoreLastPromotion(this.gateHost)} Last failure: ${vr.summary}`, 900));
          return false;
        }
        this.endJob("failed", clip(`final verification failed at ${a.verb} (${vr.level}): ${vr.summary}`, 400), true);
        return false;
      }
    }
    const hands = fast ? { rows: [], failure: "" } : await runHandChecks(this.gateHost, packDir); // lane C2: the card's hand checks (handcheck.ts)
    if (hands.failure) return sendBackHands(this.gateHost, hands.rows) || (this.endJob("failed", clip(hands.failure, 700), true), false);
    // N3: a pack that is promoted AGAIN (after a change request) is photographed first, so that whoever asked for the
    // change can look at it: the declared cameras at the usual frames, into captures/promotion<n>-<cam>-f<frame>.png.
    // No critic, no gate; the paths are in a `note` on the package that was re-opened last.
    if (nth > 1) {
      const owner = this.lastReopened();
      const shots = await this.captureSet(`promotion${nth}`, owner, tests[0], fast);
      this.append({ type: "note", package: owner, round: this.pkg(owner).round, text: whatChangedNote(this.log.events, this.jobIdentity().version, removedSince(path.resolve(this.jobDir, this.s.promotions.at(-1)?.dest ?? "pack"), this.dir("pack"))) }); // E3f: one line for Create; H1: each removal on its own line
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
        return false;
      }
      this.append({ type: "promoted", packId: pr.packId, version: pr.version, dest: pr.dest });
      const where = toEngine ? "into the engine (packs/)" : `under the job directory (${pr.dest})${asked === "engine" ? "; the engine directory is not writable" : ""}`;
      this.endJob("done", `pack verified V0 to V4 and promoted ${where}${nth > 1 ? ` (promotion ${nth} of this job; the earlier one is kept)` : ""}`);
    } else {
      this.endJob("done", "pack verified V0 to V4; promotion was not requested");
    }
    return false;
  }

  /**
   * Captures of pack/ for every declared camera at the usual frames, named <label>-<cam>-f<frame>.png. Each is a
   * `verify` event (capture, V5); a capture that fails is tried once more and then left out. Returns the paths.
   */
  /** The package re-opened last (a change's owner), else the first of the plan. */
  private lastReopened(): string {
    const last = [...this.log.events].reverse().find((e) => e.type === "reopened");
    return last && last.type === "reopened" && this.s.packages[last.package] ? last.package : (this.s.order[0] as string);
  }

  private async captureSet(label: string, after: string, bot: string | undefined, one = false): Promise<string[]> {
    const packDir = this.dir("pack");
    let cameras: string[] = [];
    try {
      cameras = readManifest(packDir).cameras;
    } catch {
      /* no manifest: no captures */
    }
    const out: string[] = [];
    for (const cam of one ? cameras.slice(0, 1) : cameras) {
      for (const frame of one ? this.captureFramesFor(bot).slice(0, 1) : this.captureFramesFor(bot)) { // E4b: ONE look for a data-only change
        const file = this.dir("captures", `${label}-${cam}-f${frame}.png`);
        let ok = false;
        for (let attempt = 1; attempt <= 2 && !ok; attempt++) {
          fs.mkdirSync(path.dirname(file), { recursive: true });
          fs.rmSync(file, { force: true });
          const vr = await this.o.verifier.run({
            verb: "capture",
            args: [`--cam=${cam}`, `--frame=${frame}`, `--out=${toPosix(file)}`, `--res=${this.o.captureRes ?? "1280x720"}`, ...(bot !== undefined ? [`--test=${bot}`] : []), ...hudArgs(hudOn(this.verbs))], // H1: the person sees the HUD
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
  private endJob(state: "done" | "failed", reason: string, unmade = false): void {
    // unmade: an ending without a promotion; after a change, pack/ goes back to the last promotion first (unmade.ts).
    const restored = unmade ? restoreLastPromotion(this.gateHost) : "";
    this.append({ type: "job_state", state, reason: restored ? `${reason} The change was NOT made.${clip(restored, 400)}` : reason });
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
