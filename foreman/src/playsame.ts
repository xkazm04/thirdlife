// H1f of 25 Nov (lane G2, about 70 minutes of critic revise rounds: a score panel, a radar, a crowd, robot detail; its
// newcomer match stayed frame for frame the greybox's): when the critic sent a look back for reasons about PLAY (contact
// reads as a clump, no hit-stop, the bots pile up), a revise round whose bots play exactly as before changed the look and
// not the play, and the person is told so plainly. The cheapest honest measure is the one the verifier already gives:
// every bot run reports what the bot counted (its result: moments by frame, won, goals, touches, the tofu metrics), per
// test and seed; deterministic, so the same counts for every bot run on both sides of the round mean the play did not
// change. Nothing is played again for it. Not the run's `state_hash`: it moves with any node of the look (G2's newcomer
// match hashed differently after a crowd was added, its moments and counts frame for frame the same).
import fs from "node:fs";
import type { JobEvent } from "./events.js";
import type { GateHost } from "./p10gate.js";
import { FOREMAN_NOTE } from "./conduct.js";

/** Words of a critic's reason that are about play, not the picture. */
export const PLAY_WORDS = /\b(clump\w*|pile\w*|overlap\w*|merg\w*|blob|hit-?stop|stagger\w*|react\w*|contact|bump\w*|crash\w*|bots?|tackl\w*|knock\w*|shove\w*|recoil\w*|bounc\w*|stumbl\w*|chas\w*|press\w*|spacing|scrum|pass\w*|possession|idle|stands? still|exchange|collid\w*|hits?)\b/i;

/** The start of the Foreman's note (after FOREMAN_NOTE). */
export const LOOK_NOT_PLAY = "the look changed, the play did not";

interface BotRun {
  test: string;
  sig: string;
}

/** A bot run's signature: its test and seed, and what it counted (its result without the summary words). Undefined when unreadable. */
function botRun(h: Pick<GateHost, "dir">, e: Extract<JobEvent, { type: "verify" }>): BotRun | undefined {
  try {
    const r = JSON.parse(fs.readFileSync(h.dir(...e.report.split("/")), "utf8")) as { seed?: unknown; bot?: { test?: unknown; done?: unknown; frames?: unknown; result?: Record<string, unknown> } };
    if (typeof r.bot?.test !== "string" || r.bot.done !== true || r.bot.result === undefined) return undefined;
    const { summary: _words, ...counted } = r.bot.result;
    return { test: `${r.bot.test}${r.seed !== undefined && r.seed !== 1 ? ` (seed ${String(r.seed)})` : ""}`, sig: JSON.stringify([r.bot.frames ?? null, counted]) };
  } catch {
    return undefined;
  }
}

/** The newest passing run of each bot test among `events`. */
function newest(h: Pick<GateHost, "dir">, events: readonly JobEvent[]): Map<string, string> {
  const out = new Map<string, string>();
  for (const e of events) {
    if (e.type !== "verify" || e.verb !== "bot" || !e.ok) continue;
    const b = botRun(h, e);
    if (b !== undefined) out.set(b.test, b.sig);
  }
  return out;
}

/**
 * After a revise round that started after event `from` (the snapshot's seq): when the critic's reasons that sent it
 * (`reasons`) were about play and every bot test run on both sides of the round counted exactly the same, the words for
 * the person; undefined otherwise.
 */
export function lookNotPlay(h: Pick<GateHost, "dir" | "events">, from: number | undefined, round: number, reasons: string[] | undefined): string | undefined {
  const asked = (reasons ?? []).join(" ");
  const hit = PLAY_WORDS.exec(asked);
  if (hit === null || from === undefined) return undefined;
  const before = newest(h, h.events.filter((e) => e.seq <= from));
  const after = newest(h, h.events.filter((e) => e.seq > from));
  const both = [...after.keys()].filter((t) => before.has(t));
  if (both.length === 0 || both.some((t) => before.get(t) !== after.get(t))) return undefined;
  return `${LOOK_NOT_PLAY}: the critic's reasons were about play ("${hit[0]}"), and after revise round ${round} ${both.join(", ")} ${both.length === 1 ? "plays" : "play"} frame for frame as before (the same moments at the same frames, the same counted figures). The round changed how the game looks, not how it plays`;
}

/** Appends the note to the person when it applies; returns its words (for the milestone summary) or undefined. */
export function sayLookNotPlay(h: Pick<GateHost, "dir" | "events" | "append" | "pkg">, from: number | undefined, round: number, reasons: string[] | undefined, owner: string): string | undefined {
  const said = lookNotPlay(h, from, round, reasons);
  if (said !== undefined) h.append({ type: "note", package: owner, round: h.pkg(owner).round, text: `${FOREMAN_NOTE}${said}` });
  return said;
}
