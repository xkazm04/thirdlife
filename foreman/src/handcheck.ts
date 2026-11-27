// Lane C2 (engine-world-next, 18 Nov): a built game is checked through a person's hand before it is promoted.
// The job's recipe card (plan_set.card, its copy in ref/cards/) may carry `hands`: {seeds, checks: [{hand, wins_min?,
// wins_max?, measured}]}. For every check the pack must register tests/bot_hand_<hand>.gd; the Foreman runs it on seeds
// 1..seeds (verb bot, V4) and counts the runs whose bot result says `won: true`. A missing test, a run that does not
// finish, a result without `won`, or a count outside the bounds fails the final verification: nothing is promoted.
// The verdict of a row comes from devx/lib/cards/hands.mjs, the same code `tl cards hands` judges with.
// Kept out of foreman.ts (line ratchet); the Foreman calls runHandChecks after its other final checks.
import fs from "node:fs";
import path from "node:path";
import { handTest, judgeHand } from "../../devx/lib/cards/hands.mjs";
import { cardOf, type Card } from "./cards.js";
import type { GateHost } from "./p10gate.js";
import { readManifest } from "./promoter.js";
import { HAND_CHECK } from "./rounds.js";
import { BALANCE_SKIPPED, askedChange, handMovedNote } from "./boundlift.js";
import type { JobEvent } from "./events.js";
import { tofuOf } from "./tofu.js";

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

/** Lane C4: the report one hand check leaves (reports/hand-checks-s<seq>.json). */
export const HAND_SUMMARY = "tl.hand-checks/1";
export interface HandSummary {
  schema: string;
  card: string;
  version: string;
  title: string;
  seeds: number;
  rows: (HandRow & { wins_min?: number; wins_max?: number })[];
}
const boundsOf = (checks: HandCheck[], hand: string): { wins_min?: number; wins_max?: number } => {
  const c = checks.find((x) => x.hand === hand);
  return { ...(c?.wins_min !== undefined ? { wins_min: c.wins_min } : {}), ...(c?.wins_max !== undefined ? { wins_max: c.wins_max } : {}) };
};

/** The card's hand checks, or undefined when the card has none. */
export function handsOf(card: Card | undefined): { seeds: number; checks: HandCheck[] } | undefined {
  const h = (card as (Card & { hands?: { seeds: number; checks: HandCheck[] } }) | undefined)?.hands;
  return h && Array.isArray(h.checks) && h.checks.length > 0 ? h : undefined;
}

/**
 * Runs the job card's hand checks on pack/. Returns {rows, failure}: failure is "" when every check holds (or the
 * card has none), else the sentence for the job's reason. Each run is a logged `verify` (stem final-hand-<hand>-seed<k>).
 */
export async function runHandChecks(h: Pick<GateHost, "s" | "dir" | "verifyLogged"> & Partial<Pick<GateHost, "events" | "append">>, packDir: string): Promise<{ rows: HandRow[]; failure: string }> {
  const card = h.s.card !== undefined ? cardOf(h.dir("ref"), h.s.card) : undefined;
  const hands = handsOf(card);
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
  // Lane C4: the rows of this hand check as one report (reports/hand-checks-s<seq>.json, the seq of the last hand run),
  // so status, explain and the designer panel show them without re-reading every run's report.
  const summary: HandSummary = { schema: HAND_SUMMARY, card: card?.id ?? "", version: card?.version ?? "", title: card?.title ?? "", seeds: hands.seeds, rows: rows.map((r) => ({ ...r, ...boundsOf(hands.checks, r.hand) })) };
  fs.writeFileSync(h.dir("reports", `hand-checks-s${h.s.lastSeq}.json`), JSON.stringify(summary, null, 1) + "\n");
  personAsked(h, rows, hands.checks);
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
    // H1j (the Director): every Resume of a failed job grants one more send-back ("try again with today's editor")
    if (e && (e.type === "promoted" || e.type === "change_requested" || (e.type === "job_state" && e.state === "running" && e.reason === "resumed (was failed)"))) {
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

/**
 * N27 (night of 27 Nov, lane T): in a person's change (boundlift.ts askedChange) a hand count outside the card's bound is
 * the balance the person moved, not a refusal: a play change keeps it as a note to the person (BALANCE_MOVED, with the
 * count before the change), a change to the view or the screen only skips it. Never for the idle hand (a player who does
 * nothing must not win: that is not balance), never for a run that did not finish or a result without `won`, and never
 * for a look change or a "make it fairer" change: there the bound guards as before.
 */
function personAsked(h: Partial<Pick<GateHost, "events" | "append">> & Pick<GateHost, "dir" | "s">, rows: HandRow[], checks: HandCheck[]): void {
  const asked = askedChange(h.events);
  if (asked === undefined || (asked.kind !== "play" && asked.kind !== "view")) return;
  const before = handsBefore(h, h.events ?? [], asked.seq);
  for (const r of rows) {
    const b = boundsOf(checks, r.hand);
    const outside = (b.wins_min !== undefined && r.wins < b.wins_min) || (b.wins_max !== undefined && r.wins > b.wins_max);
    if (r.ok || r.hand === "idle" || r.completed !== r.seeds || !outside || !r.why.includes("the card asks")) continue;
    const bound = [b.wins_min !== undefined ? `${b.wins_min} or more` : "", b.wins_max !== undefined ? `${b.wins_max} or less` : ""].filter(Boolean).join(" and ");
    const text = asked.kind === "play" ? handMovedNote(r.hand, r.wins, r.seeds, before.get(r.hand), bound) : `${BALANCE_SKIPPED}: a change to the view or the screen only; the card's ${r.hand} hand check ${r.wins} of ${r.seeds} (bound ${bound}), not judged`;
    r.ok = true;
    r.why = `${r.why}; not judged: your change ${asked.kind === "play" ? "moved it (a note tells you)" : "is to the view only"}`;
    const owner = h.s.plan.find((p) => (p.registers?.tests ?? []).includes(r.test))?.id ?? h.s.plan[0]?.id;
    if (owner !== undefined) h.append?.({ type: "note", package: owner, round: h.s.packages[owner]?.round ?? 1, text });
  }
}

/** The hand counts of the newest hand-checks report written before the change (seq), by hand. */
function handsBefore(h: Pick<GateHost, "dir">, events: readonly JobEvent[], seq: number): Map<string, { wins: number; seeds: number }> {
  const out = new Map<string, { wins: number; seeds: number }>();
  let dir: string[] = [];
  try {
    dir = fs.readdirSync(h.dir("reports"));
  } catch {
    return out;
  }
  const best = dir.map((f) => ({ f, n: Number(/^hand-checks-s(\d+)\.json$/.exec(f)?.[1] ?? NaN) })).filter((x) => Number.isFinite(x.n) && x.n < seq).sort((a, b) => b.n - a.n)[0];
  if (best === undefined || events.length === 0) return out;
  try {
    const sum = JSON.parse(fs.readFileSync(h.dir("reports", best.f), "utf8")) as HandSummary;
    for (const r of sum.rows) out.set(r.hand, { wins: r.wins, seeds: r.seeds });
  } catch {
    /* unreadable: no figure before */
  }
  return out;
}

// ---------- N27 (night of 27 Nov, lane T): the Foreman's measures are the Foreman's ----------
// On 25 Nov builders rewrote the tofu bot's own input policy to pass its bounds (G4; G19 core r5 changed
// tests/bot_tofu.gd; J11 tonight, tests/support/pilot.gd, which the bot loads). The plan's tofu bot and every test script
// it loads are the measure the Foreman judges its bounds by: from their first merge into
// pack/ on, a builder round that edits or deletes it is put back to pack/'s version before anything is verified, and the
// job log names it (MEASURE_KEPT). Before the first merge the builder writes it, as before. The card's hand tests are not
// frozen yet: the fake runner's fixtures (hands.test.ts 4 and 6) express "the game was fixed" by rewriting the hand test,
// so freezing them needs the fake runner to read its wins from a game file first (named in lane T's report). A game on a
// core has no such file in the pack: its measured check is lane E2's lab (engine/cores/rink/lab), which reads only the
// cartridge and rules file it is handed, and no workspace holds the lab or its bands.

/** The start of the Foreman's note when a builder's edit of a measure was undone. */
export const MEASURE_KEPT = "[foreman] measure kept";

/** The pack scripts the Foreman judges its bounds by: the plan's tofu bot and the test scripts it loads (as merged in pack/). */
export function measureTests(h: Pick<GateHost, "s"> & Partial<Pick<GateHost, "dir">>): string[] {
  const t = tofuOf(h.s.plan);
  if (t === undefined) return [];
  // J11 of 27 Nov (biplane r16): the tofu bot's input policy lived in tests/support/pilot.gd, which the bot loads
  // (ctx.load_script); the builder edited it to pass. Every test script the merged bot loads is the measure too.
  const out = [t.test];
  for (let i = 0; i < out.length && h.dir !== undefined; i++) {
    let text = "";
    try {
      text = fs.readFileSync(h.dir("pack", ...(out[i] as string).split("/")), "utf8");
    } catch {
      continue;
    }
    for (const m of text.matchAll(/\b(?:load_script|preload|load)\(\s*"(?:res:\/\/)?(tests\/[A-Za-z0-9_\/.-]+\.gd)"/g)) if (!out.includes(m[1] as string)) out.push(m[1] as string);
  }
  return out;
}

/** Puts back every measure the round's workspace changed (only those already in pack/); returns the files and appends the note. */
export function keepMeasures(h: Pick<GateHost, "s" | "dir" | "append">, id: string, round: number, ws: string): string[] {
  const kept: string[] = [];
  for (const f of measureTests(h)) {
    const packed = h.dir("pack", ...f.split("/"));
    if (!fs.existsSync(packed)) continue; // not merged yet: the builder is still writing it
    const mine = path.join(ws, ...f.split("/"));
    const same = fs.existsSync(mine) && fs.readFileSync(mine).equals(fs.readFileSync(packed));
    if (same) continue;
    fs.mkdirSync(path.dirname(mine), { recursive: true });
    fs.copyFileSync(packed, mine);
    kept.push(f);
  }
  if (kept.length > 0) h.append({ type: "note", package: id, round, text: `${MEASURE_KEPT}: ${kept.join(", ")} ${kept.length === 1 ? "is a measure" : "are measures"} the Foreman judges by (merged before this round); this round's edit was undone and the round is verified with the measure as merged. Change the game, never the test that measures it.` });
  return kept;
}
