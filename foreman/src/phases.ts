// JOB.md "Added 2026-11-20": the build runs in phases the player tries and passes. What the Foreman does with them,
// kept out of foreman.ts (its line ratchet) the way p10gate.ts is: functions of the job state and of the GateHost.
//   - a package of a later phase is not started before the player passed the phases before it;
//   - a phase whose packages are all merged (and whose whole-pack checks after the last merge passed: the merge gate)
//     is done: `phase_done`, then `job_state paused` reason "phase", or with run_through the Foreman's own pass;
//   - the first phase is the greybox (docs/design/METHOD.md section 10): only a person passes it, also with run_through
//     (the owner's decision of 23 Nov); run_through passes the phases after it;
//   - `hold` with a note is a change round on that phase's packages (the package the Planner names among them);
//   - a re-plan keeps the phases; a stuck phase is named when the job fails.
import type { JobEvent, PackageSpec, Phase } from "./events.js";
import { currentPhase, holdReason, passesItself, phaseIndexOf, waitingPhase, type JobState } from "./joblog.js";
import { funPromiseItem, DEFAULT_RUBRIC, type GenerateCall, type PackageLine, type RubricItem } from "./designer.js";
import { CHANGE_ROUND } from "./rounds.js";
import { NEW_PACKAGE, ownerOrNew } from "./grow.js";
import { clip } from "./conduct.js";
import type { ForemanOptions } from "./options.js";

/** What the phase functions need of the Foreman (a subset of p10gate.ts GateHost, plus the generate-call log). */
export interface PhaseHost {
  readonly o: ForemanOptions;
  readonly s: JobState;
  append(body: Parameters<import("./joblog.js").JobLog["append"]>[0]): JobEvent;
  reopen(id: string, reason: string, detail: string): void;
  logGenerateCalls(calls: GenerateCall[], model: string | undefined): void;
  /** E4 (24-25 Nov): grows the plan for a hold whose note adds something no package holds (grow.ts); absent: never. */
  grow?(c: { seq: number; text: string }, why: string, head: string): Promise<{ added: string[] } | { reason: string }>;
}

/** A job paused for the player's verdict on a phase stays paused on `run`/`resume`: `foreman phase` answers it. */
export function waitsForVerdict(s: JobState): boolean {
  const wait = waitingPhase(s);
  return wait !== undefined && !passesItself(s, wait) && s.jobState?.state === "paused" && !s.changes.some((c) => c.state === "pending");
}

/** May this package be started now? Without phases, always; with them, when its phase is the current one or earlier. */
export function inReach(s: JobState, id: string): boolean {
  if (s.qualityHeld) return false; // JOB.md 2026-11-21: a quality hold starts nothing until the owner answers it
  const cur = currentPhase(s);
  if (!cur) return true;
  const idx = phaseIndexOf(s, id);
  return idx === -1 || idx <= s.phases.indexOf(cur);
}

/**
 * After the scheduler returned: a phase hold without its change round gets one ("continue"); a current phase whose
 * packages are all merged is done (`phase_done`), then passed by the Foreman itself with run_through ("continue";
 * never the first phase, the greybox: passesItself), or the job waits for the player (`job_state paused`, reason
 * "phase": "paused"). "none": the rest of the loop decides
 * (a failure, a question, the end of the job).
 */
export async function phaseStep(h: PhaseHost): Promise<"continue" | "paused" | "none"> {
  if (h.s.phases.length === 0) return "none";
  if ((await applyHolds(h)) > 0) return "continue";
  const cur = currentPhase(h.s);
  if (!cur) return "none";
  if (!cur.packages.every((id) => h.s.packages[id]?.state === "promoted")) return "none";
  if (cur.state === "held" && cur.hold !== undefined && !cur.hold.applied) return "none";
  if (cur.state !== "done") h.append({ type: "phase_done", phase: cur.id });
  if (passesItself(h.s, cur)) {
    h.append({ type: "phase_reviewed", phase: cur.id, verdict: "pass", by: "auto" });
    return "continue";
  }
  h.append({ type: "job_state", state: "paused", reason: "phase" });
  return "paused";
}

/** The package lines (id, title, milestone, deps, files) of some packages of the plan, for the Planner's owner question. */
export function packageLinesOf(s: JobState, ids: string[]): PackageLine[] {
  return s.plan
    .filter((p) => ids.includes(p.id))
    .map((p) => {
      const merged = s.packages[p.id]?.mergedFiles ?? [];
      return { id: p.id, title: p.title, milestone: p.milestone, deps: p.deps, files: merged.length > 0 ? merged : p.scope };
    });
}

/**
 * `hold` with a note runs a change round on that phase's packages (the note is the request). The package that takes
 * it: the phase's only package, or the one the Planner names among the phase's packages (one short call, as for a
 * change request without --package); the phase's first package when the Planner gives no usable answer.
 */
export async function applyHolds(h: PhaseHost): Promise<number> {
  let applied = 0;
  for (const ph of h.s.phases) {
    const hold = ph.hold;
    if (ph.state !== "held" || hold === undefined || hold.applied) continue;
    const mine = ph.packages.filter((id) => h.s.packages[id] !== undefined);
    if (mine.length === 0) continue;
    let owner = mine[0] as string;
    let how = "the phase has one package";
    if (mine.length > 1 || h.grow !== undefined) {
      // E4: with a grow hook the Planner may also answer "new": the note adds something no package of the phase holds
      const model = h.o.plannerModel ?? h.o.model;
      const res = await ownerOrNew(h.o.builder, { sentence: h.s.sentence ?? "", title: h.s.title ?? "", text: hold.note, packages: packageLinesOf(h.s, mine) }, model ? { model } : {});
      h.logGenerateCalls(res.calls, model);
      if (res.ok && res.value.package === NEW_PACKAGE && h.grow !== undefined) {
        const g = await h.grow({ seq: hold.seq, text: hold.note }, clip(res.value.reason, 200), `${holdReason(hold.seq)} on phase ${ph.id}`);
        if ("added" in g) {
          applied += 1;
          continue;
        }
        how = `${g.reason}, so the phase's first package takes it`;
      } else if (res.ok && res.value.package !== NEW_PACKAGE) {
        owner = res.value.package;
        how = `the Planner names the package among the phase's ${mine.join(", ")}: ${clip(res.value.reason, 200)}`;
      } else if (!res.ok) how = `the Planner gave no usable answer (${clip(res.reason, 160)}), so the phase's first package takes it`;
    }
    h.reopen(owner, `${holdReason(hold.seq)} on phase ${ph.id}; ${how}: ${clip(hold.note, 300)}`, `${CHANGE_ROUND}: ${hold.note}`);
    applied += 1;
  }
  return applied;
}

/**
 * The phases of a re-plan's plan_set, as `{phases}` to spread into it ({} without phases). The phases stay; a
 * replacement package goes to the phase it was in (a new id: the phase being built now), and later when one of its
 * dependencies is in a later phase. A phase left empty is dropped; with fewer than two left the plan runs as one
 * phase from here on (no `phases`).
 */
export function replanPhases(s: JobState, fresh: PackageSpec[], replaced: Set<string>): { phases?: Phase[] } {
  if (s.phases.length === 0) return {};
  const cur = currentPhase(s);
  const curIdx = cur ? s.phases.indexOf(cur) : s.phases.length - 1;
  const freshIds = new Set(fresh.map((p) => p.id));
  const at = new Map<string, number>();
  s.phases.forEach((ph, i) => {
    for (const id of ph.packages) if (!replaced.has(id) && !freshIds.has(id)) at.set(id, i);
  });
  for (const p of fresh) at.set(p.id, Math.max(curIdx, s.phases.findIndex((ph) => ph.packages.includes(p.id))));
  for (let pass = 0; pass <= fresh.length; pass++) {
    let moved = false;
    for (const p of fresh) {
      for (const d of p.deps) {
        const di = at.get(d);
        if (di !== undefined && di > (at.get(p.id) ?? 0)) {
          at.set(p.id, di);
          moved = true;
        }
      }
    }
    if (!moved) break;
  }
  const phases: Phase[] = s.phases
    .map((ph, i) => ({ id: ph.id, title: ph.title, try: ph.try, packages: [...at.entries()].filter(([, x]) => x === i).map(([id]) => id) }))
    .filter((ph) => ph.packages.length > 0);
  return phases.length >= 2 ? { phases } : {};
}

/** The phase line of a builder's brief: which phase the package is built in and what the player can do after it. */
export function phaseLine(s: JobState, id: string): string {
  const i = phaseIndexOf(s, id);
  const ph = s.phases[i];
  if (ph === undefined) return "";
  return `\n- phase: this package is built in phase ${i + 1} of ${s.phases.length}, "${ph.title}". When the phase is done the player stops and tries it with their own hands: "${ph.try}". Make that true, and make it feel good.`;
}

/** A failing job names the phase that did not complete ("" without phases). */
export function stuckText(s: JobState): string {
  const ph = currentPhase(s);
  if (!ph) return "";
  return `phase ${ph.id} ("${ph.title}") did not complete: ${ph.packages.filter((id) => s.packages[id]?.state !== "promoted").map((id) => `${id} ${s.packages[id]?.state ?? "?"}`).join(", ")}`;
}

/**
 * L2 of 21 Nov: the critic's rubric for a milestone. With a promise to the player (the `try` line of the phase the
 * milestone's last package is in, or the brief's pitch) the `fun_promise` item joins the default four.
 */
export function criticRubric(s: JobState, lastPackage: string): RubricItem[] {
  const promise = s.phases[phaseIndexOf(s, lastPackage)]?.try ?? s.brief?.pitch;
  return promise !== undefined ? [...DEFAULT_RUBRIC, funPromiseItem(promise)] : DEFAULT_RUBRIC;
}
