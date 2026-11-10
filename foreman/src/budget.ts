// Budget policy: when the Foreman may spend tokens. Pauses and resumes are `budget` events in the log.
import type { BudgetPolicy } from "./events.js";
import type { JobLog, JobState } from "./joblog.js";

export interface BudgetDeps {
  now: () => Date;
  sleep: (ms: number) => Promise<void>;
  /** For only_while_playing: whether the player is in the world right now. Phase 3 supplies the real signal. */
  isPlaying?: () => boolean;
}

export type BudgetVerdict = { allowed: true } | { allowed: false; reason: string; waitMs: number };

const HOUR = 3_600_000;

export function parseWindow(limit: unknown): { from: number; to: number } | undefined {
  const m = /^(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})$/.exec(typeof limit === "string" ? limit : "22:00-07:00");
  if (!m) return undefined;
  const from = Number(m[1]) * 60 + Number(m[2]);
  const to = Number(m[3]) * 60 + Number(m[4]);
  if (from >= 1440 || to >= 1440 || from === to) return undefined;
  return { from, to };
}

/** Pure decision from the policy, the derived state (its token ledger) and the clock. */
export function budgetVerdict(policy: BudgetPolicy | undefined, state: JobState, deps: Pick<BudgetDeps, "now" | "isPlaying">): BudgetVerdict {
  if (!policy) return { allowed: true };
  const now = deps.now().getTime();
  switch (policy.kind) {
    case "tokens_per_hour": {
      if (typeof policy.limit !== "number") return { allowed: true };
      const recent = state.tokenLedger
        .map((e) => ({ t: Date.parse(e.ts), tokens: e.tokens }))
        .filter((e) => e.t > now - HOUR)
        .sort((a, b) => a.t - b.t);
      let used = recent.reduce((a, e) => a + e.tokens, 0);
      if (used < policy.limit) return { allowed: true };
      const total = used;
      let waitUntil = now;
      for (const e of recent) {
        used -= e.tokens;
        waitUntil = e.t + HOUR;
        if (used < policy.limit) break;
      }
      return {
        allowed: false,
        reason: `tokens_per_hour: ${total} tokens used in the last hour, limit ${policy.limit}`,
        waitMs: Math.max(1, waitUntil - now + 1),
      };
    }
    case "only_while_playing": {
      if (deps.isPlaying?.() ?? false) return { allowed: true };
      return { allowed: false, reason: "only_while_playing: the player is not in the world", waitMs: 5000 };
    }
    case "overnight": {
      const w = parseWindow(policy.limit);
      if (!w) return { allowed: false, reason: `overnight: limit ${JSON.stringify(policy.limit)} is not "HH:MM-HH:MM"`, waitMs: 60_000 };
      const d = deps.now();
      const minute = d.getHours() * 60 + d.getMinutes();
      const inside = w.from < w.to ? minute >= w.from && minute < w.to : minute >= w.from || minute < w.to;
      if (inside) return { allowed: true };
      const until = (w.from - minute + 1440) % 1440;
      return {
        allowed: false,
        reason: `overnight: outside the window ${typeof policy.limit === "string" ? policy.limit : "22:00-07:00"}`,
        waitMs: Math.max(1000, until * 60_000 - d.getSeconds() * 1000),
      };
    }
  }
}

/** Policy with no limit: what a `budget` event names when a rate limit pauses a job that has no policy set. */
export const NO_POLICY: BudgetPolicy = { kind: "tokens_per_hour" };

/**
 * One gate per job. Every builder call passes through `wait()`. A pause is written once however many packages
 * are waiting, and so is the resume.
 */
export class BudgetGate {
  private pause: Promise<void> | undefined;

  constructor(
    private readonly policy: BudgetPolicy | undefined,
    private readonly log: JobLog,
    private readonly deps: BudgetDeps,
  ) {}

  get paused(): boolean {
    return this.pause !== undefined;
  }

  /** Resolves when spending is allowed. `onBlocked` runs once if the caller has to wait. */
  async wait(onBlocked?: (reason: string) => void): Promise<void> {
    let told = false;
    for (;;) {
      if (!this.pause) {
        const v = budgetVerdict(this.policy, this.log.state, this.deps);
        if (v.allowed) return;
        this.startPause(v.reason, async () => {
          for (;;) {
            const again = budgetVerdict(this.policy, this.log.state, this.deps);
            if (again.allowed) return;
            await this.deps.sleep(again.waitMs);
          }
        });
      }
      if (!told && onBlocked) onBlocked(this.log.state.budget?.reason ?? "budget");
      told = true;
      await this.pause;
    }
  }

  /** A rate limit reported by the builder: pause everything for `ms`, then resume. */
  async pauseFor(reason: string, ms: number): Promise<void> {
    if (!this.pause) this.startPause(reason, () => this.deps.sleep(ms));
    await this.pause;
  }

  private startPause(reason: string, until: () => Promise<void>): void {
    const policy = this.policy ?? NO_POLICY;
    this.log.append({ type: "budget", policy, state: "paused", reason });
    const p = (async () => {
      try {
        await until();
        this.log.append({ type: "budget", policy, state: "running", reason: `resumed after: ${reason}` });
      } finally {
        this.pause = undefined;
      }
    })();
    this.pause = p;
    // The awaiting callers see the rejection; this stops an unhandled one if nobody is waiting yet.
    p.catch(() => {});
  }
}
