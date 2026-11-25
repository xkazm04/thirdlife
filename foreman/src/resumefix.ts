// H1i item 1 (lane G5, the Director at ~20:00): a failed job's Resume (`foreman resume <job> --retry-failed`, Create's
// Resume button) re-ran only the final checks and failed at the same hand check, because the hand check's one send-back
// was spent before the job failed, --retry-failed retried only packages in the failed state (core was "promoted"), and
// core r11's fix for this very fault sat unmerged in its workspace (its round was refused by the possession bound that
// the person had lifted). On a resume of a job that failed on a hand check, the package that registers the failing test
// goes back to work: its waiting fix (a builder round that answered ok after its last merge, still in its workspace) is
// verified again without a builder run; with no waiting fix it is re-opened with the hand check's rows, as the first
// failure did. Then the final checks and the hand check run again.
import fs from "node:fs";
import type { JobEvent } from "./events.js";
import type { JobState } from "./joblog.js";
import type { HandRow, HandSummary } from "./handcheck.js";
import { HAND_CHECK } from "./rounds.js";

/** The rows of the last hand check (reports/hand-checks-s<seq>.json), or []. */
export function lastHandRows(reportsDir: string): HandRow[] {
  try {
    const last = fs.readdirSync(reportsDir).filter((f) => /^hand-checks-s\d+\.json$/.test(f)).sort((a, b) => Number(/\d+/.exec(a)?.[0]) - Number(/\d+/.exec(b)?.[0])).at(-1);
    if (last === undefined) return [];
    return (JSON.parse(fs.readFileSync(`${reportsDir}/${last}`, "utf8")) as HandSummary).rows ?? [];
  } catch {
    return [];
  }
}

/** The round of `id` whose builder answered ok after the package's last merge (its fix waits in the workspace), or undefined. */
export function waitingRound(events: readonly JobEvent[], id: string): number | undefined {
  let merged = 0;
  let built: { seq: number; round: number } | undefined;
  for (const e of events) {
    if (e.type === "merge" && e.package === id) merged = e.seq;
    if (e.type === "builder_run" && e.package === id && e.outcome === "ok" && e.round !== undefined) built = { seq: e.seq, round: e.round };
  }
  return built !== undefined && built.seq > merged ? built.round : undefined;
}

/**
 * The events a `--retry-failed` resume appends: failed (and dependency-blocked) packages queued again, as before; and,
 * when the job failed on a hand check, the owners of the failing tests sent back to work. `wsThere(id)` says whether a
 * package's workspace still exists.
 */
export function retryEvents(s: Pick<JobState, "order" | "packages" | "plan" | "jobState" | "card">, events: readonly JobEvent[], rows: HandRow[], wsThere: (id: string) => boolean): Record<string, unknown>[] {
  const out: Record<string, unknown>[] = [];
  const sent = new Set<string>();
  for (const id of s.order) {
    const p = s.packages[id];
    if (p !== undefined && (p.state === "failed" || (p.state === "blocked" && p.cause === "dependency"))) {
      out.push({ type: "package_state", package: id, state: "queued", round: 1, detail: "retry requested" });
      sent.add(id);
    }
  }
  const reason = s.jobState?.state === "failed" ? (s.jobState.reason ?? "") : "";
  if (!reason.startsWith("hand check of")) return out;
  const owners = new Map<string, HandRow[]>();
  for (const r of rows.filter((x) => !x.ok)) {
    const owner = s.plan.find((p) => (p.registers?.tests ?? []).includes(r.test));
    if (owner !== undefined && !sent.has(owner.id)) owners.set(owner.id, [...(owners.get(owner.id) ?? []), r]);
  }
  for (const [id, mine] of owners) {
    const lines = mine.map((r) => `${r.test} (${r.hand} hand): ${r.why}`).join("; ");
    const waiting = waitingRound(events, id);
    if (waiting !== undefined && wsThere(id)) {
      out.push({ type: "package_state", package: id, state: "verifying", round: waiting, detail: `resumed: round ${waiting}'s fix waited unmerged in ${id}'s workspace (the job failed at the hand check: ${lines}); it is checked again as it is, its builder is not run` });
    } else {
      const why = `${HAND_CHECK} (on resume) for card ${s.card ?? "?"}: ${lines}. Sent back to ${id}, which registers the test.`;
      out.push({ type: "reopened", package: id, reason: why });
      out.push({ type: "package_state", package: id, state: "queued", round: (s.packages[id]?.round ?? 0) + 1, detail: `${why} Change your files so the game meets the card's bound through that hand (the test plays the game's own policy through TLHand; do not make the test lie about won).` });
    }
  }
  return out;
}
