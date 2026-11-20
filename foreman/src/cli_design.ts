// JOB.md "Added 2026-11-20", the designer v2 commands: `react`, `redesign`, `phase`, and the flags `new` takes
// (`--creativity crazy`, `--run-through`). Kept out of cli.ts (its line ratchet); cli.ts hands in what it owns.
import path from "node:path";
import type { Builder, ProbeResult } from "./builder/types.js";
import { JobLog, waitingPhase } from "./joblog.js";
import { designBrief, type DesignerInput, type GenerateCall } from "./designer.js";
import { designerCardsText, designerEngineText } from "./designctx.js";
import { choiceProblem, type Creativity } from "./v2.js";
import { lockHolder } from "./requests.js";
import { UsageError, num, str, type Args } from "./cli_args.js";

export const NEW_HELP = `      [--creativity crazy|standard] [--run-through] [--engine-dir DIR]
        the Designer answers with a pitch, 3 to 7 aspect cards and the five fields. --creativity crazy adds one or two
        unexpected mechanics on top of the sentence (each an aspect marked crazy; standard, the default, writes no
        key). --run-through: the Foreman does not stop after each phase.
  react <job> <aspect> <choice> [--note "..."]
        the player's reaction to one aspect of the latest brief, before approval: choice is keep, drop or one of the
        aspect's alternative ids. The latest reaction per aspect counts.
  redesign <job> [--adapter A] [--model M] [--engine-dir DIR]
        the Designer again with the sentence, the latest brief and the reactions: a new brief (old reactions lapse)`;

export const PHASE_HELP = `  phase <job> pass|hold [--note "..."] [--no-run] [same options as run]
        the player's verdict on the phase that is done (foreman status names it): pass starts the next phase (after
        the last one: final verification and promotion); hold needs --note, the request for a change round on that
        phase's packages, after which the phase is done again. Then the job continues as resume would (--no-run only
        records the verdict). resume leaves a job that waits for a verdict as it is.`;

/** What cli.ts lends the design commands. */
export interface DesignDeps {
  jobDirOf(a: Args): string;
  makeBuilder(a: Args, jobDir: string): Builder;
  ensureBilling(log: JobLog, builder: Builder): Promise<ProbeResult>;
  writeGenerateCalls(log: JobLog, builder: Builder, calls: GenerateCall[], model: string | undefined): void;
  /** The engine directory a Designer call reads (designctx.ts): flag, job config, environment, default. */
  engineDir(a: Args, jobDir?: string): string;
  runJob(a: Args, out: (s: string) => void): Promise<number>;
}

/** JOB.md 2026-11-20: `--creativity crazy` (standard is the default and writes no key); anything else is an error. */
export function creativityFlag(a: Args): Creativity | undefined {
  const v = str(a, "creativity");
  if (v === undefined || v === "standard") return undefined;
  if (v === "crazy") return "crazy";
  throw new UsageError(`--creativity takes crazy (or standard, the default), got "${v}"`);
}

/** The Designer's input for a job: the sentence, creativity, the engine and the cards; `previous` for a redesign. */
export function designerInput(engineDir: string, sentence: string, creativity: Creativity | undefined, previous?: DesignerInput["previous"]): DesignerInput {
  return { sentence, ...(creativity !== undefined ? { creativity } : {}), engine: designerEngineText(engineDir), cards: designerCardsText(engineDir), ...(previous ? { previous } : {}) };
}

/** The line `new` and `redesign` print after a brief: what the player can do next. */
export const nextAfterBrief = (job: string): string =>
  `react to an aspect with: foreman react ${job} <aspect> keep|drop|<alternative> [--note "..."], redesign with: foreman redesign ${job}, approve with: foreman approve ${job}`;

function noteFlag(a: Args): string | undefined {
  const note = str(a, "note");
  if (note !== undefined && note.trim().length === 0) throw new UsageError("--note needs text (or leave it out)");
  return note?.trim();
}

/** `react`, `redesign` and `phase`. Each checks its values against JOB.md 2026-11-20 before it writes anything. */
export async function designCommand(a: Args, out: (s: string) => void, d: DesignDeps): Promise<number> {
  if (a.cmd === "react") {
    const [, aspect, choice] = a.pos;
    if (!aspect || !choice) throw new UsageError('usage: foreman react <job> <aspect> <choice> [--note "..."]   (choice: keep, drop or an alternative id)');
    const note = noteFlag(a);
    const log = JobLog.open(d.jobDirOf(a));
    try {
      const s = log.state;
      if (!s.brief) throw new UsageError("this job has no brief yet");
      if (s.briefApprovedBy) throw new UsageError(`the brief is already approved (by ${s.briefApprovedBy}); reactions come before approval`);
      const aspects = s.brief.aspects ?? [];
      if (aspects.length === 0) throw new UsageError("the latest brief has no aspect cards (it was made before the designer v2)");
      const found = aspects.find((x) => x.id === aspect);
      if (!found) throw new UsageError(`no aspect "${aspect}" in the latest brief (${aspects.map((x) => x.id).join(", ")})`);
      const bad = choiceProblem(found, choice);
      if (bad !== undefined) throw new UsageError(bad);
      log.append({ type: "aspect_reacted", aspect, choice, ...(note !== undefined ? { note } : {}) });
      out(`reaction recorded: ${aspect} -> ${choice}${note !== undefined ? ` (note: ${note})` : ""}`);
      return 0;
    } finally {
      log.close();
    }
  }

  if (a.cmd === "redesign") {
    const jobDir = d.jobDirOf(a);
    const log = JobLog.open(jobDir);
    try {
      const s = log.state;
      if (!s.brief || !s.sentence) throw new UsageError("this job has no brief yet");
      if (s.briefApprovedBy) throw new UsageError(`the brief is already approved (by ${s.briefApprovedBy}); a redesign comes before approval`);
      const builder = d.makeBuilder(a, jobDir);
      const probe = await d.ensureBilling(log, builder);
      if (!probe.ok) {
        out(`builder not available: ${probe.notes.join("; ")}`);
        return 1;
      }
      const model = str(a, "model");
      const t = num(a, "timeout-ms");
      const input = designerInput(d.engineDir(a, jobDir), s.sentence, s.creativity, { brief: s.brief, reactions: s.reactions });
      const res = await designBrief(builder, input, { ...(model ? { model } : {}), ...(t !== undefined ? { timeoutMs: t } : {}) });
      d.writeGenerateCalls(log, builder, res.calls, model);
      if (!res.ok) {
        // The earlier brief and its reactions stand: a failed redesign changes nothing the player decided.
        out(`Designer failed: ${res.reason}; the earlier brief stands`);
        return 1;
      }
      log.append({ type: "brief_set", brief: res.value.brief, estimate: res.value.estimate });
      out(JSON.stringify(res.value, null, 1));
      out(`brief set (design ${log.state.briefs}); ${nextAfterBrief(log.job)}`);
      return 0;
    } finally {
      log.close();
    }
  }

  // phase: phase_reviewed by the player on the phase that waits; then the job continues as resume would.
  const jobDir = d.jobDirOf(a);
  const verdict = a.pos[1];
  if (verdict !== "pass" && verdict !== "hold") throw new UsageError('usage: foreman phase <job> pass|hold [--note "..."]');
  const note = noteFlag(a);
  if (verdict === "hold" && note === undefined) throw new UsageError('hold needs --note "<what to change first>": it is the request for the change round');
  const holder = lockHolder(jobDir);
  if (holder.alive) throw new UsageError(`a Foreman (pid ${holder.pid ?? "?"}) is running this job; a verdict is given while the job waits for one (foreman status)`);
  const log = JobLog.open(jobDir);
  try {
    const ph = waitingPhase(log.state);
    if (!ph) {
      const cur = log.state.phases.find((x) => x.state !== "passed");
      throw new UsageError(log.state.phases.length === 0 ? "this job's plan has no phases" : cur ? `no phase waits for a verdict: phase ${cur.id} is ${cur.state === "held" ? "in its change round" : "being built"}` : "every phase has passed");
    }
    log.append({ type: "phase_reviewed", phase: ph.id, verdict, ...(note !== undefined ? { note } : {}), by: "player" });
    out(`phase ${ph.id} ${verdict === "pass" ? "passed" : `held: ${note ?? ""}`}`);
  } finally {
    log.close();
  }
  if (a.flags["no-run"] === true) {
    out(`continue with: foreman resume ${path.basename(jobDir)}`);
    return 0;
  }
  return d.runJob({ ...a, cmd: "resume", pos: [a.pos[0] as string] }, out);
}
