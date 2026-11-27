// D27 lane T3, round 3 (the Director's last item; this lane's l3 copy, events 1334-1415): J2b's follow-up asked "the
// rival bots go mega only about once a minute: I want to face their giants about twice as often, so they should land
// their body checks on me and my mates more often". cartridge r15's builder lowered game.skater.check_speed_min 1.5 ->
// 1, and v0.1.29 played to v0.1.28's state hashes on every seed measured: the rate did not move, and the Foreman promoted
// it with no word. Match minutes and goals a match are already checked against the person's words (askedFigureMiss), on
// the quick diff only. A rate the person asks for ("more often", "twice as often", "fewer") is now checked the same way
// on the cartridge owner's round, diff or builder: the measured check (thirdjam's regular playtester) runs on the last
// promoted cartridge and on the round's, and the figure the words name must move the asked way by 5 % at least (the measure's own spread is about 2 %). A
// round that leaves it unmoved goes back to its builder once, with the figures; a second time it merges and the person
// reads "part of your change was NOT made: ...".
import fs from "node:fs";
import path from "node:path";
import type { GateHost } from "./p10gate.js";
import type { Verified } from "./machine.js";
import { gameCartridges, type CoreCheckRun } from "./coreroute.js";
import { coreCheck, jobCore } from "./coregate.js";
import { askedChange } from "./boundlift.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";

/** A rate the person asks for: the measured figure that counts it, and the way it must move. */
export interface RateAsk {
  figure: string;
  way: 1 | -1;
  said: string;
}

/** What the words name, and the measured figure (thirdjam's playtester at pro) that counts it. */
const TOPICS: [RegExp, string][] = [
  [/\b(body checks?|checks?|hits?|knock\w*|flatten\w*|giants?|mega)\b/i, "pro_knockdowns"],
  [/\bgoals?\b|\bscor\w*/i, "pro_goals_a_match"],
  [/\bshots?\b|\bshoot\w*/i, "pro_shots"],
  [/\bpass(?:es)?\b/i, "pro_passes_completed"],
];
const MORE = /\b(more often|twice as often|(?:two|three|\d+) times as often|as often again|more (?:of them|checks|hits|goals|shots|passes)|oftener)\b/i;
const FEWER = /\b(less often|half as often|fewer|rarer|more rarely|not as often)\b/i;

/** The rates a person's words ask for, one per figure; [] when the words ask none. */
export function rateAsks(text: string): RateAsk[] {
  const out: RateAsk[] = [];
  for (const s of text.split(/(?<=[.!?])\s+(?=[A-Z"])/)) {
    for (const part of s.split(/[:;]|,\s*so\b/)) {
      const way = MORE.test(part) ? 1 : FEWER.test(part) ? -1 : 0;
      if (way === 0) continue;
      const topic = TOPICS.find(([re]) => re.test(part)) ?? TOPICS.find(([re]) => re.test(s));
      if (topic !== undefined && !out.some((r) => r.figure === topic[1])) out.push({ figure: topic[1], way, said: part.trim() });
    }
  }
  return out;
}

/** The asks a measured run before and after leaves unmoved: a figure that did not move the asked way by 5 %. */
export function unmoved(asks: readonly RateAsk[], before: Record<string, number>, after: Record<string, number>): { ask: RateAsk; before: number; after: number }[] {
  return asks.flatMap((ask) => {
    const b = before[ask.figure];
    const a = after[ask.figure];
    if (typeof b !== "number" || typeof a !== "number") return [];
    const moved = ask.way > 0 ? a >= b * 1.05 && a > b : a <= b * 0.95 && a < b; // 5 %: the measure's own spread (v0.1.28 vs l3's v0.1.29, the same play: 32 -> 32.7) is about 2 %
    return moved ? [] : [{ ask, before: b, after: a }];
  });
}

/** The start of the round's failed check (its report's message) and of the person's note (after FOREMAN_NOTE). */
export const RATE_UNMOVED = "the rate you asked for did not move";

/** The words for one unmoved ask. */
const said = (m: { ask: RateAsk; before: number; after: number }): string => `"${clip(m.ask.said, 160)}": ${m.ask.figure} ${m.before} before, ${m.after} after (${m.ask.way > 0 ? "up" : "down"} by 5 % at least is the ask)`;

/**
 * The cartridge owner's round in a person's change on a core, when the words ask for a rate: the measured check before
 * (the last promoted cartridge, run once a change and kept) and after (the round's). Undefined when there is nothing to
 * judge, when it moved, when the check could not run, or when the round was already sent back once for it (then the
 * person's note is written and the round merges).
 */
export async function rateGate(h: Pick<GateHost, "s" | "o" | "events" | "dir" | "rel" | "append" | "pkg">, id: string, round: number, ws: string): Promise<Verified | undefined> {
  if (jobCore(h as GateHost) === undefined) return undefined;
  const asked = askedChange(h.events);
  const promoted = h.s.promoted?.dest;
  if (asked === undefined || promoted === undefined) return undefined;
  const asks = rateAsks(asked.text);
  if (asks.length === 0) return undefined;
  const cart = gameCartridges(h.dir("pack"), h.s.plan).find((c) => c.owner === id);
  if (cart === undefined) return undefined;
  const now = path.join(ws, ...cart.file.split("/"));
  const then = h.dir(...promoted.split("/"), ...cart.file.split("/"));
  if (!fs.existsSync(now) || !fs.existsSync(then)) return undefined;
  const keep = h.dir("reports", `rate-before-s${asked.seq}.json`);
  let before: CoreCheckRun | undefined;
  try {
    before = JSON.parse(fs.readFileSync(keep, "utf8")) as CoreCheckRun;
  } catch {
    before = await coreCheck(h as GateHost, then);
    if (before.code !== 2) {
      fs.mkdirSync(path.dirname(keep), { recursive: true });
      fs.writeFileSync(keep, JSON.stringify(before, null, 1) + "\n");
    }
  }
  const after = await coreCheck(h as GateHost, now);
  if (before.code === 2 || after.code === 2) return undefined; // could not run: no verdict, never a pass claimed
  const misses = unmoved(asks, before.figures, after.figures);
  if (misses.length === 0) return undefined;
  const words = misses.map(said).join("; ");
  const sentBack = (h.events ?? []).some((e) => e.type === "verify" && e.package === id && e.seq > asked.seq && !e.ok && /-rate-s\d+\.json$/.test(e.report));
  if (sentBack) {
    h.append({ type: "note", package: id, round, text: `${FOREMAN_NOTE}part of your change was NOT made: ${RATE_UNMOVED} after ${id} was sent back once (thirdjam's regular playtester at pro, measured before and after): ${words}` });
    return undefined;
  }
  const summary = `${RATE_UNMOVED}: the person asked for it in words the measured check counts, and thirdjam's regular playtester at pro measures it before your round and after: ${words}. Change the cartridge so that figure moves the way the person asked (another key may be the one that does it); a key that leaves it where it was is not the change.`;
  const file = h.dir("reports", `${id}-r${round}-rate-s${h.s.lastSeq + 1}.json`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify({ schema: "tl.foreman.rate/1", verb: "bot", level: "V4", ok: false, outcome: "failed", by: "the Foreman (ratecheck.ts), the measured check before and after", before: before.figures, after: after.figures, checks: misses.map((m) => ({ id: `rate.${m.ask.figure}`, ok: false, detail: said(m) })), errors: [{ kind: "rate", message: summary }] }, null, 1) + "\n");
  h.append({ type: "verify", package: id, round, level: "V4", verb: "bot", ok: false, report: h.rel(file) });
  return { ok: false, verb: "bot", level: "V4", summary, reportFile: file, verdictFile: file, flags: [], durationMs: 0 } as unknown as Verified;
}
