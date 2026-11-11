// N3b, N3c: whether a failed check is the machine's or the pack's, read from the runner's reports. Pure functions;
// moved out of foreman.ts in P10b, which re-exports them.
import type { VerifyResult } from "./verifier.js";

/** A verification result with what the Foreman concluded on top: a kit regression, or "machine busy, no verdict". */
export type Verified = VerifyResult & { inconclusive?: string };
export type GateFailure = Verified & { kitRegression?: string };

/** N3b: the fixed start of the `detail` of a round whose clock-based failure was the machine's, not the pack's. */
export const MACHINE_BUSY = "inconclusive: machine busy";
/** N3b: the start of the note (after FOREMAN_NOTE) that says a repeated clock failure is the pack's own. */
export const NOT_LOAD = "machine not shown busy";
/** N3c: the start of the note that says the watchdog stopped two runs at the same frame: the pack's own stall. */
export const PACK_STALL = "the same stall twice";

/** Where the watchdog stopped a run, read from the report's error message as the runner writes it ("... (frame N)"). */
export interface Stall {
  frame?: number;
  /** The callback that did not return: `_pack_tick`, `_bot_tick`, `_pack_setup`, ... */
  callback?: string;
  file?: string;
  message: string;
}

export function stallOf(vr: VerifyResult): Stall | undefined {
  const r = vr.report;
  if (!r || r.outcome !== "watchdog") return undefined;
  const err = r.errors.find((e) => e.kind === "watchdog");
  const message = err?.message ?? r.checks.find((c) => c.id === "smoke.watchdog" && !c.ok)?.detail ?? "";
  if (!/tick_timeout|setup_timeout|did not return/.test(message)) return undefined;
  const frame = /\(frame (\d+)\)/.exec(message)?.[1];
  const callback = /(?:tick_timeout|setup_timeout): (\w+)/.exec(message)?.[1];
  return { ...(frame !== undefined ? { frame: Number(frame) } : {}), ...(callback !== undefined ? { callback } : {}), ...(err?.file !== undefined ? { file: err.file } : {}), message };
}

/** The frame times a failing run still reported (median and p99), in words; undefined when no run reported any. */
export function frameFigures(runs: VerifyResult[]): string | undefined {
  for (const vr of [...runs].reverse()) {
    const m = (vr.report?.["metrics"] ?? {}) as { frame_ms_p50?: unknown; frame_ms_p99?: unknown };
    if (typeof m.frame_ms_p50 !== "number" || typeof m.frame_ms_p99 !== "number") continue;
    const small = m.frame_ms_p99 < 8;
    return `the frames it did run were ${small ? "ordinary" : "slow at the tail"}: median ${m.frame_ms_p50} ms, p99 ${m.frame_ms_p99} ms${small && vr.report?.outcome === "watchdog" ? ", so single ticks blew the watchdog's limit while the frames around them stayed far under the 8 ms budget" : ""}`;
  }
  return undefined;
}

/**
 * N3c: what the runs of ONE check on the SAME files say together when the watchdog stopped each of them.
 * A pack is deterministic: a stall that its own code causes comes at the same frame, in the same callback, every
 * time. Stalls at different places are the machine (the scheduler took the processor away for longer than the
 * limit); a short reference run seldom catches such a moment, so it is not asked. Without a frame number in every
 * report the runs decide nothing and the gauge is used.
 */
export function classifyStalls(runs: VerifyResult[]): { verdict: "machine_load" | "pack" | "undecided"; text: string } {
  const stalls = runs.map(stallOf);
  if (runs.length < 2) return { verdict: "undecided", text: "one run only, nothing to compare" };
  if (stalls.some((s) => s === undefined || s.frame === undefined)) return { verdict: "undecided", text: "the reports do not all name the frame at which the run stalled, so the runs cannot be compared" };
  const all = stalls as (Stall & { frame: number })[];
  const place = (s: Stall): string => `frame ${s.frame}${s.callback ? ` in ${s.callback}` : ""}${s.file ? ` (${s.file})` : ""}`;
  const distinct = new Set(all.map((s) => `${s.frame}|${s.callback ?? ""}`)).size;
  const times = frameFigures(runs);
  const tail = times ? ` Of the frame times a failing run still reported, ${times}.` : "";
  if (distinct === all.length) {
    return {
      verdict: "machine_load",
      text: `the watchdog stopped ${all.length} runs of the same check on the same files at ${all.length} DIFFERENT places (${all.map(place).join("; ")}). A deterministic pack that stalls in its own code stalls at the same frame every time, so this is the machine (something else held the processor longer than the time limit), whatever a reference run says afterwards.${tail}`,
    };
  }
  if (distinct === 1) {
    return {
      verdict: "pack",
      text: `the watchdog stopped ${all.length} runs of the same check on the same files at the SAME place, ${place(all[0] as Stall)}. A stall that repeats at the same frame is in the pack's own code: look at what ${all[0]?.callback ?? "the script"} does at frame ${all[0]?.frame}.${tail}`,
    };
  }
  return { verdict: "undecided", text: `the watchdog stopped ${all.length} runs at ${all.map(place).join("; ")}: some places repeat and some do not` };
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
