// The options of a Foreman run (moved out of foreman.ts in P10b; foreman.ts re-exports the type).
import type { BudgetPolicy, JobEvent, PackageSpec } from "./events.js";
import type { Builder } from "./builder/types.js";
import type { Verifier } from "./verifier.js";
import type { Generated, ReplanInput } from "./designer.js";
import type { Reference } from "./reference.js";
import type { RunnerVerbs } from "./verbs.js";

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
  /**
   * P10 item 1: when every test of the pack runs on the merge candidate, besides the package's own acceptance and
   * lint and smoke. "after_change" (default): for a package that was re-opened or is merged again (a change request,
   * the critic, a changed dependency, a failed final verification). "always": for every merge. "never": as before P10.
   */
  packTests?: "after_change" | "always" | "never";
  /**
   * P10 item 2: how often a failed final verification after a promotion may send the failure back to a package
   * (one round each) before the change ends as "not made". Default: `roundLimit`.
   */
  finalRounds?: number;
  /** P10 item 4: how often the scheduling loop looks into <job>/inbox.jsonl while builders run, in ms. Default 1000. */
  inboxPollMs?: number;
  /** Test seam: called after every durable append; throwing simulates a kill at that exact event. */
  afterAppend?: (ev: JobEvent) => void;
  onEvent?: (ev: JobEvent) => void;
}
