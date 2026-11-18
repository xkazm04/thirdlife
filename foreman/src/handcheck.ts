// Lane C2 (engine-world-next, 18 Nov): a built game is checked through a person's hand before it is promoted.
// The job's recipe card (plan_set.card, its copy in ref/cards/) may carry `hands`: {seeds, checks: [{hand, wins_min?,
// wins_max?, measured}]}. For every check the pack must register tests/bot_hand_<hand>.gd; the Foreman runs it on seeds
// 1..seeds (verb bot, V4) and counts the runs whose bot result says `won: true`. A missing test, a run that does not
// finish, a result without `won`, or a count outside the bounds fails the final verification: nothing is promoted.
// The verdict of a row comes from devx/lib/cards/hands.mjs, the same code `tl cards hands` judges with.
// Kept out of foreman.ts (line ratchet); the Foreman calls runHandChecks after its other final checks.
import { handTest, judgeHand } from "../../devx/lib/cards/hands.mjs";
import { cardOf, type Card } from "./cards.js";
import type { GateHost } from "./p10gate.js";
import { readManifest } from "./promoter.js";
import { HAND_CHECK } from "./rounds.js";

export interface HandCheck {
  hand: string;
  wins_min?: number;
  wins_max?: number;
  measured: string;
}
export interface HandRow {
  hand: string;
  test: string;
  seeds: number;
  completed: number;
  wins: number;
  ok: boolean;
  why: string;
}

/** The card's hand checks, or undefined when the card has none. */
export function handsOf(card: Card | undefined): { seeds: number; checks: HandCheck[] } | undefined {
  const h = (card as (Card & { hands?: { seeds: number; checks: HandCheck[] } }) | undefined)?.hands;
  return h && Array.isArray(h.checks) && h.checks.length > 0 ? h : undefined;
}

/**
 * Runs the job card's hand checks on pack/. Returns {rows, failure}: failure is "" when every check holds (or the
 * card has none), else the sentence for the job's reason. Each run is a logged `verify` (stem final-hand-<hand>-seed<k>).
 */
export async function runHandChecks(h: Pick<GateHost, "s" | "dir" | "verifyLogged">, packDir: string): Promise<{ rows: HandRow[]; failure: string }> {
  const hands = handsOf(h.s.card !== undefined ? cardOf(h.dir("ref"), h.s.card) : undefined);
  if (!hands) return { rows: [], failure: "" };
  let tests: string[] = [];
  try {
    tests = readManifest(packDir).tests;
  } catch {
    /* an unreadable manifest: every check below names its test as missing */
  }
  const rows: HandRow[] = [];
  for (const c of hands.checks) {
    const test = handTest(c.hand);
    if (!tests.includes(test)) {
      rows.push({ hand: c.hand, test, seeds: hands.seeds, completed: 0, wins: 0, ok: false, why: `the card asks for ${test} and the pack's manifest does not list it` });
      continue;
    }
    let completed = 0;
    let wins = 0;
    let unread = 0;
    for (let seed = 1; seed <= hands.seeds; seed++) {
      const vr = await h.verifyLogged({ verb: "bot", args: [`--test=${test}`, `--seed=${seed}`] }, packDir, `final-hand-${c.hand}-seed${seed}`, { round: 1 });
      const bot = (vr.report as { bot?: { done?: boolean; result?: { won?: unknown } } } | undefined)?.bot;
      if (!bot || bot.done !== true) continue;
      completed += 1;
      if (typeof bot.result?.won !== "boolean") unread += 1;
      else if (bot.result.won) wins += 1;
    }
    rows.push({ hand: c.hand, test, seeds: hands.seeds, completed, wins, ...judgeHand(c, hands.seeds, completed, wins, unread) });
  }
  const bad = rows.filter((r) => !r.ok);
  return { rows, failure: bad.length === 0 ? "" : `hand check of ${h.s.card ?? "the card"} failed, nothing promoted: ${bad.map((r) => `${r.hand}: ${r.why}`).join("; ")}` };
}

/**
 * Lane C3: a failed hand check is a round, not an end. The first failure since the last promotion (or change request)
 * re-opens, for ONE round, every package that registers a failing hand test, with the rows in its brief (reason and
 * detail start "hand check failed"; rounds.ts reads it as a final-verification round). Returns true when something was
 * sent back (the job goes on and checks again); false on a second failure, or when no package owns a failing test:
 * then the job ends unpromoted.
 */
export function sendBackHands(h: Pick<GateHost, "s" | "events" | "reopen">, rows: HandRow[]): boolean {
  let since = 0;
  for (let i = h.events.length - 1; i >= 0; i--) {
    const e = h.events[i];
    if (e && (e.type === "promoted" || e.type === "change_requested")) {
      since = e.seq;
      break;
    }
  }
  if (h.events.some((e) => e.type === "reopened" && e.seq > since && e.reason.startsWith(HAND_CHECK))) return false;
  const bad = rows.filter((r) => !r.ok);
  const owners = new Map<string, HandRow[]>();
  for (const r of bad) {
    const owner = h.s.plan.find((p) => (p.registers?.tests ?? []).includes(r.test));
    if (owner) owners.set(owner.id, [...(owners.get(owner.id) ?? []), r]);
  }
  if (owners.size === 0) return false;
  for (const [id, mine] of owners) {
    const lines = mine.map((r) => `${r.test} (${r.hand} hand): ${r.why}`).join("; ");
    const reason = `${HAND_CHECK} (1 of 1) for card ${h.s.card ?? "?"}: ${lines}. Sent back to ${id}, which registers the test.`;
    const detail = `${reason} The Foreman played each hand test on seeds 1..${mine[0]?.seeds ?? "?"} and counted won in its bot result. Change your files so the game meets the card's bound through that hand (the test plays the game's own policy through TLHand; do not make the test lie about won). This is ONE round; then the final verification and the hand checks run again, and a second failure ends the job unpromoted.`;
    h.reopen(id, reason, detail);
  }
  return true;
}
