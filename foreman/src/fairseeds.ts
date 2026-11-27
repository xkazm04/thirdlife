// D27b item 32 (lane T2-editor; J2nd's court copy, events 1664-1858): "make it fairer" was tuned blind. court_exchange
// r15: "I could not measure the newcomer win share; the newcomer hand test is not one of the commands I may run" (event
// 1673); the final check then measured 10 of 20 against the card's 13 (event 1782); crews_stakes r17, sent back for it:
// "The newcomer win share was measured on seed 1 only (one win). The seeds 1-20 count is unmeasured" (event 1786); the
// second final check measured 11 of 20 and the job failed unpromoted (event 1858), each guess about 35 min of final checks.
// In a fairness change, and in a round the card's hand check sent back, the builder gets the measure it is judged by: the
// card's bound, the last hand check's result for every seed (won or lost, the bot's own summary), and the hand test
// among the commands it may run on its own workspace (one seed per run).
import fs from "node:fs";
import path from "node:path";
import type { Acceptance } from "./events.js";
import type { GateHost } from "./p10gate.js";
import { askedChange } from "./boundlift.js";
import { cardOf } from "./cards.js";
import { clip } from "./conduct.js";
import { handsOf, type HandCheck } from "./handcheck.js";
import { handTest } from "../../devx/lib/cards/hands.mjs";
import { readManifest } from "./promoter.js";
import { HAND_CHECK } from "./rounds.js";

type Host = Pick<GateHost, "s" | "events" | "dir">;

/** The card's hand checks when `id` tunes fairness now: a person's fairness change, or a round a hand check sent back. */
function fairHands(h: Host, id: string): { seeds: number; checks: HandCheck[]; why: string } | undefined {
  const hands = handsOf(h.s.card !== undefined ? cardOf(h.dir("ref"), h.s.card) : undefined);
  if (hands === undefined) return undefined;
  const asked = askedChange(h.events);
  const reopen = [...h.events].reverse().find((e) => e.type === "reopened" && e.package === id);
  const sentBack = reopen?.type === "reopened" && reopen.reason.startsWith(HAND_CHECK) && (asked === undefined || reopen.seq > asked.seq);
  if (asked?.kind !== "fair" && !sentBack) return undefined;
  return { ...hands, why: asked?.kind === "fair" ? `The person asked for fairness ("${clip(asked.text, 200)}")` : "The card's hand check sent this package back" };
}

/** The tests a package's workspace manifest lists (pack/'s when the workspace has none). */
function listedTests(h: Host, id: string): string[] {
  for (const dir of [h.dir("ws", id), h.dir("pack")]) {
    try {
      if (fs.existsSync(path.join(dir, "pack.json"))) return readManifest(dir).tests;
    } catch {
      /* next */
    }
  }
  return [];
}

/** The hand checks the builder of `id` may run itself (one seed each; the builder changes --seed), [] when not tuning fairness. */
export function fairChecks(h: Host, id: string): Acceptance[] {
  const hands = fairHands(h, id);
  if (hands === undefined) return [];
  const listed = listedTests(h, id);
  return hands.checks.map((c) => handTest(c.hand)).filter((t) => listed.includes(t)).map((t) => ({ level: "V4", verb: "bot", args: [`--test=${t}`, "--seed=1"] }) as Acceptance);
}

/** One hand's last result per seed, from the newest run of each seed (reports/final-hand-<hand>-seed<k>-s<seq>.json). */
export function perSeed(h: Pick<GateHost, "events" | "dir">, hand: string, seeds: number): { seed: number; won?: boolean; summary: string; frames?: number; seq: number }[] {
  const out: { seed: number; won?: boolean; summary: string; frames?: number; seq: number }[] = [];
  for (let seed = 1; seed <= seeds; seed++) {
    const stem = `reports/final-hand-${hand}-seed${seed}-s`;
    const e = [...h.events].reverse().find((x) => x.type === "verify" && x.report.startsWith(stem) && !/-(again|retry\d+|starved\d+|longer)/.test(x.report));
    if (e === undefined || e.type !== "verify") continue;
    try {
      const r = JSON.parse(fs.readFileSync(h.dir(e.report), "utf8")) as { bot?: { done?: boolean; frames?: number; result?: { won?: unknown; summary?: unknown } } };
      const won = typeof r.bot?.result?.won === "boolean" ? r.bot.result.won : undefined;
      out.push({ seed, ...(won !== undefined ? { won } : {}), summary: typeof r.bot?.result?.summary === "string" ? clip(r.bot.result.summary.replace(/\s+/g, " "), 140) : r.bot?.done === true ? "" : "did not finish", ...(typeof r.bot?.frames === "number" ? { frames: r.bot.frames } : {}), seq: e.seq });
    } catch {
      out.push({ seed, summary: "report unreadable", seq: e.seq });
    }
  }
  return out;
}

const boundText = (c: HandCheck): string => (c.wins_min !== undefined && c.wins_max !== undefined ? `${c.wins_min} to ${c.wins_max}` : c.wins_min !== undefined ? `at least ${c.wins_min}` : c.wins_max !== undefined ? `at most ${c.wins_max}` : "any");

/** The prompt section for a builder that tunes fairness: the measure, the last result per seed, and how to run it itself. "" otherwise. */
export function fairText(h: Host, id: string): string {
  const hands = fairHands(h, id);
  if (hands === undefined) return "";
  const runnable = fairChecks(h, id).map((a) => a.args[0]?.slice("--test=".length));
  const parts = hands.checks.map((c) => {
    const test = handTest(c.hand);
    const rows = perSeed(h, c.hand, hands.seeds);
    const known = rows.filter((r) => r.won !== undefined);
    const won = known.filter((r) => r.won === true).length;
    const frames = rows.flatMap((r) => (r.frames !== undefined ? [r.frames] : []));
    const last = rows.length === 0 ? "The Foreman has not run it yet in this job." : `Its last run: won ${won} of ${rows.length} seed(s) run. Per seed: ${rows.map((r) => `${r.seed} ${r.won === true ? "WON" : r.won === false ? "lost" : "?"}${r.summary !== "" ? ` (${r.summary})` : ""}`).join("; ")}.`;
    const run = runnable.includes(test) ? ` You may run it yourself on your workspace: it is among the commands below with --seed=1; change the seed for each run (one run plays one whole match${frames.length > 0 ? `, about ${Math.round(frames.reduce((a, b) => a + b, 0) / frames.length)} frames` : ""}) and read result.won on its last line. Run it on the seeds it lost and on enough of the others to see the count move before you finish, and write the count you measured under DEVIATIONS ("${c.hand} won N of M in my runs").` : ` It is not in your workspace's manifest, so only the Foreman runs it, on the whole pack.`;
    return `- the ${c.hand} hand (${test}) on seeds 1..${hands.seeds}: the card asks ${boundText(c)} wins. ${last}${run}`;
  });
  return `\n\n## The measure your fairness change is judged by\n${hands.why}. Before it promotes, the Foreman plays the card's hand checks and counts the runs whose bot result says won: true:\n${parts.join("\n")}\nTune against these runs, not by guess: each final check costs the person about half an hour.`;
}
