// `foreman explain <job>`: where the tokens went (per package, per round, per reason), why each round ran, and the
// one command to type next. Pure: it reads the events and the state folded from them and returns data; the CLI
// prints it. It writes nothing and appends no event. Why a round ran comes from rounds.ts (one classifier).
import type { BuilderOutcome, JobEvent, Level, Verb } from "./events.js";
import { isGreybox, passesItself, waitingPhase, weightedTokens, type JobState } from "./joblog.js";
import { roundKindOf, roundKinds, type RoundFold, type RoundKind } from "./rounds.js";

export interface RoundVerify {
  verb: Verb;
  level: Level;
  ok: boolean;
  report: string;
}

export interface RoundCost {
  round: number;
  kind: RoundKind;
  why: string;
  /** The last builder outcome of the round; omitted when no builder ran in it (a resumed verification). */
  outcome?: BuilderOutcome;
  /** Builder runs in the round (a rate-limit retry or a restart after a kill adds one). */
  runs: number;
  durationMs: number;
  tokensIn: number;
  tokensOut: number;
  /** As a token policy counts them (JOB.md: cache-read tokens at 0.1), summed per run like the state's ledger. */
  weighted: number;
  /** The last verification of the round: the package's own checks and the whole-pack checks after its merge. */
  verify?: RoundVerify;
}

export interface PackageCost {
  id: string;
  state: string;
  weighted: number;
  rounds: RoundCost[];
}

export interface Explanation {
  job: string;
  title?: string;
  state: string;
  lastSeq: number;
  packages: PackageCost[];
  /** Job-level runs (Designer, Planner, critic): no package, no round. Omitted with --package or when there were none. */
  jobRuns?: { runs: number; tokensIn: number; tokensOut: number; weighted: number };
  /** Weighted tokens by why the round ran (a RoundKind), plus `job` for the job-level runs. Only kinds that spent. */
  costByWhy: Record<string, number>;
  weighted: number;
  next: string;
}

const oneLine = (s: string, n = 160): string => {
  const t = s.replace(/\s+/g, " ").trim();
  return t.length > n ? `${t.slice(0, n - 1)}~` : t;
};

/** The default of a round that has no `queued` (the Verifier's failure sends the package straight to its next round). */
const kindOf = (fold: RoundFold, id: string, round: number): RoundKind => roundKindOf(fold, id, round) ?? (round <= 1 ? "first" : "verify_retry");

interface Acc {
  cost: RoundCost;
  /** What ended the round badly, as the next round's reason reads it. */
  failure?: string;
}

function packageRounds(state: JobState, events: readonly JobEvent[], fold: RoundFold, id: string): RoundCost[] {
  const byRound = new Map<number, Acc>();
  const at = (round: number): Acc => {
    let a = byRound.get(round);
    if (!a) byRound.set(round, (a = { cost: { round, kind: kindOf(fold, id, round), why: "", runs: 0, durationMs: 0, tokensIn: 0, tokensOut: 0, weighted: 0 } }));
    return a;
  };
  let current = 0;
  for (const e of events) {
    if (e.type === "package_state" && e.package === id) at((current = e.round));
    else if (e.type === "builder_run" && e.package === id && e.round !== undefined) {
      const a = at(e.round);
      a.cost.runs += 1;
      a.cost.outcome = e.outcome;
      a.cost.durationMs += e.durationMs;
      a.cost.tokensIn += e.tokensIn ?? 0;
      a.cost.tokensOut += e.tokensOut ?? 0;
      if (e.tokensIn !== undefined || e.tokensOut !== undefined) a.cost.weighted += weightedTokens(e.tokensIn ?? 0, e.tokensOut ?? 0, e.tokensCacheRead);
      if (e.outcome !== "ok") a.failure = `builder ${e.outcome}`;
    } else if (e.type === "verify" && (e.package === id || (e.package === undefined && e.after === id && e.round === current))) {
      // A whole-pack check after the merge counts for the round it names when that is the package's round then
      // (a milestone capture can name round 1 while the package is in a later one).
      const a = at(e.round);
      a.cost.verify = { verb: e.verb, level: e.level, ok: e.ok, report: e.report };
      if (!e.ok) a.failure = `${e.verb} ${e.level} FAILED`;
      else delete a.failure; // a clock-based failure run once more and passed: the second run decides
    }
  }
  // Change requests this package was re-opened for, oldest first: the k-th change round answers the k-th of them.
  const changes = state.changes.filter((c) => c.owner === id);
  let changeRound = 0;
  const rounds = [...byRound.values()].sort((x, y) => x.cost.round - y.cost.round);
  return rounds.map((a, i) => {
    const prev = i > 0 ? rounds[i - 1] : undefined;
    const c = a.cost;
    c.why = whyText(c.kind, prev?.cost.round === c.round - 1 ? prev?.failure : undefined, c.kind === "change" ? changes[changeRound++]?.seq : undefined);
    return c;
  });
}

function whyText(kind: RoundKind, prevFailure: string | undefined, changeSeq: number | undefined): string {
  switch (kind) {
    case "first":
      return "first build";
    case "verify_retry":
      return prevFailure !== undefined ? `retry after ${prevFailure}` : "retry";
    case "critic":
      return "critic extra round";
    case "critic_kit_retry":
      return "one more round after the critic's (kit regression)";
    case "kit_regression":
      return "retry after a kit regression";
    case "no_visible_change":
      return "retry: no visible change";
    case "change":
      return changeSeq !== undefined ? `change request #${changeSeq}` : "change request";
    case "dep_changed":
      return "dependency changed";
    case "final_failed":
      return "final verification failed";
  }
}

/** The one thing to type next, or why there is nothing to type. */
export function nextStep(state: JobState, lock: { pid?: number; alive: boolean }): string {
  const job = state.job;
  const asking = state.order.map((id) => state.packages[id]).find((p) => p?.openQuestion !== undefined);
  if (asking) return `foreman answer ${job} ${asking.id} "<your answer>"   (${asking.id} asks: "${oneLine(asking.openQuestion ?? "", 300)}")`;
  const js = state.jobState?.state;
  if (js === "done") return state.promoted ? `nothing; promoted ${state.promoted.packId} ${state.promoted.version} -> ${state.promoted.dest}` : "nothing; the job is done";
  if (js === "cancelled") return `nothing; the job was cancelled${state.jobState?.reason ? `: ${state.jobState.reason}` : ""}`;
  if (lock.alive && state.budget?.state === "paused") return `waiting on budget: ${state.budget.reason}`;
  if (js === "failed") {
    const f = state.order.map((id) => state.packages[id]).find((p) => p?.state === "failed");
    const v = f?.lastVerify;
    const why = f ? `${f.id} failed: ${f.cause ?? "no cause"}${v && !v.ok ? `; last verify ${v.verb} ${v.level} FAILED ${v.report}` : ""}` : `the job failed${state.jobState?.reason ? `: ${state.jobState.reason}` : ""}`;
    return `foreman resume ${job} --retry-failed   (${why})`;
  }
  // JOB.md 2026-11-20: a job waiting on a phase is never a hang: name the phase and the command that answers it.
  const wait = waitingPhase(state);
  // The person gate (owner, 23 Nov): the greybox waits for a person's hand, also with run-through.
  if (wait && !passesItself(state, wait) && js === "paused" && !lock.alive) return `foreman phase ${job} pass   or   foreman phase ${job} hold --note "<what to change>"   (phase ${wait.id} ${state.runThrough === true && isGreybox(state, wait) ? "is the greybox and waits for your hand even with run-through" : "is done"}; try it: "${wait.try}")`;
  if (js === "running" || js === "paused") {
    if (lock.alive) return `nothing to type; the Foreman is running (pid ${lock.pid})`;
    const gone = lock.pid !== undefined ? `: pid ${lock.pid} is gone` : "";
    return js === "running" ? `foreman resume ${job} (the Foreman is not running${gone}; log stops at event ${state.lastSeq})` : `foreman resume ${job}   (paused${state.jobState?.reason ? `: ${state.jobState.reason}` : ""})`;
  }
  if (!state.brief) return `nothing to explain yet: the job has no brief (foreman new)`;
  if (!state.briefApprovedBy) return (state.brief.aspects ?? []).length > 0 ? `foreman approve ${job}   (or first: foreman react ${job} <aspect> keep|drop|<alternative>, foreman redesign ${job})` : `foreman approve ${job}`;
  if (state.plan.length === 0) return `foreman plan ${job}`;
  return `foreman run ${job}`;
}

/** Explains the whole job, or only package `only` (then without the job-level runs). */
export function explain(state: JobState, events: readonly JobEvent[], lock: { pid?: number; alive: boolean }, only?: string): Explanation {
  const fold = roundKinds(events);
  const ids = only !== undefined ? [only] : state.order;
  const packages: PackageCost[] = ids.map((id) => {
    const rounds = packageRounds(state, events, fold, id);
    return { id, state: state.packages[id]?.state ?? "?", weighted: rounds.reduce((a, r) => a + r.weighted, 0), rounds };
  });
  const costByWhy: Record<string, number> = {};
  for (const p of packages) for (const r of p.rounds) if (r.weighted > 0) costByWhy[r.kind] = (costByWhy[r.kind] ?? 0) + r.weighted;
  let jobRuns: Explanation["jobRuns"];
  if (only === undefined) {
    for (const e of events) {
      if (e.type !== "builder_run" || e.package !== undefined) continue;
      jobRuns ??= { runs: 0, tokensIn: 0, tokensOut: 0, weighted: 0 };
      jobRuns.runs += 1;
      jobRuns.tokensIn += e.tokensIn ?? 0;
      jobRuns.tokensOut += e.tokensOut ?? 0;
      if (e.tokensIn !== undefined || e.tokensOut !== undefined) jobRuns.weighted += weightedTokens(e.tokensIn ?? 0, e.tokensOut ?? 0, e.tokensCacheRead);
    }
    if (jobRuns && jobRuns.weighted > 0) costByWhy["job"] = jobRuns.weighted;
  }
  const weighted = packages.reduce((a, p) => a + p.weighted, 0) + (jobRuns?.weighted ?? 0);
  return {
    job: state.job,
    ...(state.title !== undefined ? { title: state.title } : {}),
    state: state.jobState?.state ?? "created",
    lastSeq: state.lastSeq,
    packages,
    ...(jobRuns ? { jobRuns } : {}),
    costByWhy,
    weighted,
    next: nextStep(state, lock),
  };
}

const verifyText = (v: RoundVerify | undefined): string => (v ? `${v.verb} ${v.level} ${v.ok ? "ok" : `FAILED ${v.report}`}` : "not verified");

/** The text `foreman explain` prints: a head, one block per package with one line per round, the job runs, `next:`. */
export function explainText(ex: Explanation & { card?: string[] }): string {
  const lines: string[] = [];
  lines.push(`job      ${ex.job}${ex.title ? `  "${ex.title}"` : ""}   state ${ex.state}   events ${ex.lastSeq}`);
  const by = Object.entries(ex.costByWhy).sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k} ${v}`).join(", ");
  lines.push(`cost     weighted ${ex.weighted}${by ? `   by why: ${by}` : ""}`);
  lines.push(...(ex.card ?? []));
  const all = ex.packages.flatMap((p) => p.rounds);
  const whyW = Math.max(0, ...all.map((r) => r.why.length));
  const outW = Math.max(0, ...all.map((r) => (r.outcome ?? "-").length));
  const msW = Math.max(0, ...all.map((r) => `${r.durationMs}ms`.length));
  const tokW = Math.max(0, ...all.map((r) => `in ${r.tokensIn} out ${r.tokensOut} w ${r.weighted}`.length));
  for (const p of ex.packages) {
    lines.push("");
    lines.push(`${p.id}  ${p.state}  ${p.rounds.length} round(s)  weighted ${p.weighted}`);
    for (const r of p.rounds) {
      const runs = r.runs > 1 ? `  (${r.runs} builder runs)` : "";
      lines.push(`  r${String(r.round).padEnd(3)} ${r.why.padEnd(whyW)}  ${(r.outcome ?? "-").padEnd(outW)}  ${`${r.durationMs}ms`.padStart(msW)}  ${`in ${r.tokensIn} out ${r.tokensOut} w ${r.weighted}`.padEnd(tokW)}  ${verifyText(r.verify)}${runs}`);
    }
  }
  if (ex.jobRuns) {
    lines.push("");
    lines.push(`(job)  ${ex.jobRuns.runs} job-level run(s) (Designer, Planner, critic)  in ${ex.jobRuns.tokensIn} out ${ex.jobRuns.tokensOut} w ${ex.jobRuns.weighted}`);
  }
  lines.push("");
  lines.push(`next: ${ex.next}`);
  return lines.join("\n");
}
