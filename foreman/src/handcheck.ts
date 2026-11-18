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
