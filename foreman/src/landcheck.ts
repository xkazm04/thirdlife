// D27 item 4 (lane J19 of 27 Nov): the person asked for a shield charge that bowls a line over like pins. core r14 built
// `rush` with a reach of 1.15 m, but two fighters' pushboxes keep their centres 1.4 m apart, so the charger stopped
// against the body before his blow could reach it: 0 knockdowns from 15 rushes over three seeds, and v0.1.5 and v0.1.6
// were promoted with it. Every check passed because none counted whether the new move ever lands.
// In a person's change that asks for an attack, every new move its builder names (`NEW MOVE: <id>`, or "New moves `x`")
// must land at least once in the Foreman's bot runs of the round. A bot test of the package counts it in its metrics as
// `moves: {<id>: {started, landed}}` (a landing only from the game's own contact events). A move that is not counted, not
// used or never lands sends the round back to the builder, with the figures; after the look's revise budget
// (QUALITY_ROUNDS) the round merges and the person is told plainly that this part of the change was not made.
import fs from "node:fs";
import path from "node:path";
import type { JobEvent, PackageSpec } from "./events.js";
import type { GateHost } from "./p10gate.js";
import type { VerifyResult } from "./verifier.js";
import { askedChange } from "./boundlift.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";
import { NOT_DONE, NOT_MADE, noteLines, ownerOf } from "./halfmade.js";
import { cartridgeOwner } from "./coreowner.js";
import { NO_KEY } from "./keyfind.js";
import { QUALITY_ROUNDS } from "./quality_state.js";
import { tofuOf } from "./tofu.js";

/** Words a person uses for an attack: a move that is meant to land on somebody. */
export const ATTACK_WORDS = /\b(attack\w*|charg\w*|slam\w*|smash\w*|strik\w*|punch\w*|kick\w*|dunk\w*|meteor|uppercut\w*|ground.?pound\w*|leap\w*|lunge\w*|tackl\w*|bash\w*|throw\w*|hammer\w*|swing\w*|blast\w*|bowl\w*|knock\w*|floor\w*|stomp\w*|shockwave\w*|special move\w*|big moves?|finisher\w*|combo\w*|shoulder.?barge\w*|body.?check\w*)\b/i;

/** The start of the Foreman's note when every new move landed. */
export const MOVES_LAND = `${FOREMAN_NOTE}new move lands in the Foreman's bot run`;

const ID = /^[a-z][a-z0-9_]*$/;

/** The moves a builder's note names as new: `NEW MOVE: a, b` lines, and "New moves `a` (...) and `b`" lines. */
export function newMovesOf(note: string): string[] {
  const out: string[] = [];
  const loose: string[] = [];
  for (const raw of note.split(/\r?\n/)) {
    const line = raw.replace(/^\s*[-*]\s*/, "");
    const tag = /^NEW MOVES?:\s*(.+)$/i.exec(line);
    if (tag) {
      // the ids come first: "NEW MOVE: rush, slam" or "NEW MOVE: cannon_shot. It is the core's shotgun, ..."
      const head = ((tag[1] as string).replace(/\([^()]*\)/g, "").split(/\.(?:\s|$)|:/)[0] ?? "");
      for (const w of head.split(/[,;]|\band\b/)) {
        // an id is one word (D27 round 4, JB's Arsenal copy: "NEW MOVE: the meteor (`shotgun`) was added by the cartridge's
        // round, not by mine" gave the moves "the" and "not")
        const words = w.trim().replace(/`/g, "").split(/\s+/).filter(Boolean);
        const id = words[0] ?? "";
        if (words.length === 1 && ID.test(id)) out.push(id);
      }
      continue;
    }
    // D27 round 3 (J19, core r14: "Fighter: new `cd` dictionary and `ready(m)` method. The 8-frame buffer takes the new
    // moves ..." gave the moves cd and ready): explicit NEW MOVE lines win; without them, only a line that starts "New moves"
    if (!/^new (?:special |big )?(?:moves?|attacks?|abilit(?:y|ies))\b/i.test(line)) continue;
    let flat = line;
    for (let i = 0; i < 4; i++) flat = flat.replace(/\([^()]*\)/g, "");
    for (const m of flat.matchAll(/`([^`]+)`/g)) if (ID.test(m[1] as string)) loose.push(m[1] as string);
  }
  return [...new Set(out.length > 0 ? out : loose)];
}

export interface MoveCount {
  started: number;
  landed?: number;
  /** D27 item 12: the frame of the last use in the run, and the run's frames: a count that stops early is no measure. */
  lastF?: number;
  frames?: number;
}

/** D27 item 12: a count is honest when its bot kept using the move into the last third of its run. */
export const KEEP_SHARE = 2 / 3;

/** `moves` of one bot report: bot.result.metrics.moves, bot.result.moves or bot.result.metrics.raw.moves. */
export function movesOfReport(report: unknown): Record<string, MoveCount> {
  const r = (report as { bot?: { result?: Record<string, unknown> } } | undefined)?.bot?.result;
  const metrics = r?.["metrics"] as Record<string, unknown> | undefined;
  const raw = metrics?.["raw"] as Record<string, unknown> | undefined;
  const m = (metrics?.["moves"] ?? r?.["moves"] ?? raw?.["moves"]) as unknown;
  if (m === null || typeof m !== "object" || Array.isArray(m)) return {};
  const out: Record<string, MoveCount> = {};
  for (const [k, v] of Object.entries(m as Record<string, unknown>)) {
    if (v === null || typeof v !== "object") continue;
    const started = (v as Record<string, unknown>)["started"];
    const landed = (v as Record<string, unknown>)["landed"];
    const lastF = (v as Record<string, unknown>)["last_f"];
    const frames = (report as { bot?: { frames?: unknown } } | undefined)?.bot?.frames;
    if (typeof started !== "number") continue;
    out[k] = { started, ...(typeof landed === "number" ? { landed } : {}), ...(typeof lastF === "number" ? { lastF } : {}), ...(typeof frames === "number" ? { frames } : {}) };
  }
  return out;
}

export interface LandVerdict {
  moves: string[];
  /** Summed over the round's bot reports. */
  counts: Record<string, MoveCount & { tests: string[] }>;
  missing: string[];
  unused: string[];
  never: string[];
  /** D27 item 12: counted, but its bot stopped using the move before the last third of its run (or gave no last_f). */
  stopped: string[];
  ok: boolean;
}

/** Judges the new moves against the counts of the given bot reports ({test, report}). */
export function judgeLanding(moves: readonly string[], reports: readonly { test: string; report: unknown }[]): LandVerdict {
  const counts: LandVerdict["counts"] = {};
  for (const { test, report } of reports) {
    for (const [k, v] of Object.entries(movesOfReport(report))) {
      const c = (counts[k] ??= { started: 0, tests: [] });
      c.started += v.started;
      // a landing is a use that hit somebody: a test that counts victims (J19 round 3: bot_crew "landed 8 of 6") is held to
      // its uses, so the share never passes 100 %
      if (v.landed !== undefined) c.landed = (c.landed ?? 0) + Math.min(v.landed, v.started);
      // the latest use over the runs, against that run's length: how far into its run the bot kept using the move
      const share = (x: { lastF?: number; frames?: number }): number => (x.lastF !== undefined && x.frames ? x.lastF / x.frames : -1);
      if (v.lastF !== undefined && (c.lastF === undefined || share(v) > share(c))) {
        c.lastF = v.lastF;
        if (v.frames !== undefined) c.frames = v.frames;
      }
      if (!c.tests.includes(test)) c.tests.push(test);
    }
  }
  const missing = moves.filter((m) => counts[m] === undefined);
  const unused = moves.filter((m) => counts[m] !== undefined && (counts[m] as MoveCount).started <= 0);
  // a move counted without `landed` is not an attack (a brace, a dash): it is used, not judged on landing
  const never = moves.filter((m) => counts[m] !== undefined && (counts[m] as MoveCount).started > 0 && (counts[m] as MoveCount).landed === 0);
  // D27 item 12 (J19, round 1: rush "landed 1 of 13" because the builder's test stopped pressing once it landed; a hand
  // that kept charging saw 0 of 11): a count is judged only when its bot kept using the move into the last third of its run
  const stopped = moves.filter((m) => {
    const c = counts[m];
    if (c === undefined || c.started <= 0 || c.landed === undefined || never.includes(m)) return false;
    return c.lastF === undefined || (c.frames !== undefined && c.lastF < c.frames * KEEP_SHARE);
  });
  return { moves: [...moves], counts, missing, unused, never, stopped, ok: missing.length + unused.length + never.length + stopped.length === 0 };
}

const figure = (id: string, c: MoveCount | undefined): string => (c === undefined ? `${id} not counted` : c.landed === undefined ? `${id} used ${c.started} times` : `${id} landed ${c.landed} of ${c.started}${c.started > 0 ? ` (${Math.round((100 * c.landed) / c.started)} %)` : ""}`);
const lastUse = (id: string, c: MoveCount | undefined): string => `${id}'s last use was ${c?.lastF === undefined ? "not reported (no last_f)" : `at frame ${c.lastF} of ${c.frames ?? "?"}`}`;

/** The new moves the builders of `id` named since the person's change began. */
function namedSince(events: readonly JobEvent[], id: string, since: number): string[] {
  const notes = events.filter((e) => e.type === "note" && e.package === id && e.seq > since && !e.text.startsWith(FOREMAN_NOTE)).map((e) => (e.type === "note" ? e.text : ""));
  // the newest note that names moves is the builder's word on them (J1 d27: "shotgun" in r15, then "meteor" in r16)
  return [...notes].reverse().map(newMovesOf).find((m) => m.length > 0) ?? [];
}

/**
 * After a round's acceptance passed on the workspace: the failure the round gets when a new attack the person asked for
 * never lands in its bot runs; undefined when it lands, when no attack was asked, when the builder named no new move,
 * or once the revise budget is spent (then the person's note says it was not made).
 */
export function landGate(h: Pick<GateHost, "s" | "pkg" | "dir" | "rel" | "append" | "events">, id: string, round: number): VerifyResult | undefined {
  const asked = askedChange(h.events);
  if (asked === undefined || asked.kind !== "play" || !ATTACK_WORDS.test(asked.text)) return undefined;
  const moves = namedSince(h.events, id, asked.seq);
  if (moves.length === 0) return undefined;
  // J1 (d27 copy, harbour r15): a round that hands part of the change on (a NOT DONE line another package owns, the
  // cartridge on a core) cannot make its move land yet: the Foreman's final bot run judges it (finalLandNotes)
  if (handsOn(h.s.plan, h.events, id, asked.seq)) {
    const note = `${WAITS}: ${moves.join(", ")} of ${id} waits for the part of the change ${id} handed on; the Foreman's final bot run says whether it lands`;
    if (!h.events.some((e) => e.type === "note" && e.package === id && e.round === round && e.text.startsWith(WAITS))) h.append({ type: "note", package: id, round, text: note });
    return undefined;
  }
  const runs = h.events.filter((e) => e.type === "verify" && e.package === id && e.round === round && e.verb === "bot" && e.ok);
  const reports = runs.flatMap((e) => {
    if (e.type !== "verify") return [];
    try {
      const report = JSON.parse(fs.readFileSync(h.dir(e.report), "utf8")) as { bot?: { test?: string } };
      return [{ test: report.bot?.test ?? e.report, report }];
    } catch {
      return [];
    }
  });
  const v = judgeLanding(moves, reports);
  const said = moves.map((m) => figure(m, v.counts[m])).join(", ");
  const tests = [...new Set(reports.map((r) => r.test))];
  const once = (start: string, text: string): void => {
    if (!h.events.some((e) => e.type === "note" && e.package === id && e.round === round && e.text.startsWith(start))) h.append({ type: "note", package: id, round, text });
  };
  if (v.ok) {
    once(MOVES_LAND, `${MOVES_LAND}: ${said} (${tests.join(", ")})`);
    return undefined;
  }
  const p = h.pkg(id);
  if (p.round - (p.roundBase ?? 1) >= QUALITY_ROUNDS) {
    const bad = [...v.missing, ...v.unused, ...v.never, ...v.stopped];
    once(`${FOREMAN_NOTE}${NOT_MADE} by ${id}: the new move`, `${FOREMAN_NOTE}${NOT_MADE} by ${id}: the new move${bad.length === 1 ? "" : "s"} ${bad.join(", ")} ${bad.length === 1 ? "does" : "do"} not land in the Foreman's bot run (${said}) after ${p.round - (p.roundBase ?? 1) + 1} rounds; the rest of the change is kept. Say it again (for example "the ${bad[0]} never hits anyone") to have it made.`);
    return undefined;
  }
  const tofu = tofuOf(h.s.plan)?.test;
  const own = [...new Set((h.s.plan.find((x) => x.id === id)?.acceptance ?? []).flatMap((a) => (a.verb === "bot" ? a.args.flatMap((x) => (x.startsWith("--test=") ? [x.slice(7)] : [])) : [])).filter((t) => t !== tofu))];
  const parts: string[] = [];
  if (v.stopped.length > 0) parts.push(`${v.stopped.map((m) => lastUse(m, v.counts[m])).join(", ")}: the count must come from a bot that keeps using the move to the end of its run, wherever it can land, and never stops once it has landed; report "last_f" (the frame of its last use) beside started and landed`);
  if (v.never.length > 0) parts.push(`${v.never.map((m) => figure(m, v.counts[m])).join(", ")}: a move that never lands is not made. Find why it misses in the game (its reach against how close the bodies can get, its hit test, its arc, when a bot uses it) and make it land as the person asked`);
  if (v.unused.length > 0) parts.push(`${v.unused.join(", ")} started 0 times: the bot test that counts it must use it where it can land`);
  if (v.missing.length > 0) parts.push(`no bot test of your package reports ${v.missing.map((m) => `moves.${m}`).join(", ")}: add \`"moves": {"${v.missing[0]}": {"started": <n>, "landed": <n>}}\` to the metrics of a bot test your acceptance runs${own.length > 0 ? ` (${own.join(", ")})` : ""}, count a landing only from the game's own contact events, and let that bot use the move where it can land`);
  const summary = `The person asked for a new attack ("${clip(asked.text, 240)}"). In this round's bot runs (${tests.join(", ") || "none"}) ${parts.join("; ")}. Never count a landing the game did not make, and never change the Foreman's tofu bot for it.`;
  const file = h.dir("reports", `${id}-r${round}-move-lands-s${h.s.lastSeq + 1}.json`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify({ schema: "tl.foreman.move-lands/1", verb: "bot", level: "V4", ok: false, outcome: "failed", by: "the Foreman (landcheck.ts) on this round's bot reports", checks: moves.map((m) => ({ id: `lands.${m}`, ok: !v.missing.includes(m) && !v.unused.includes(m) && !v.never.includes(m), detail: figure(m, v.counts[m]) })), errors: [{ kind: "lands", message: summary }] }, null, 1) + "\n");
  h.append({ type: "verify", package: id, round, level: "V4", verb: "bot", ok: false, report: h.rel(file) });
  return { verb: "bot", level: "V4", ok: false, summary, reportFile: file, verdictFile: file, flags: [], durationMs: 0 };
}

/** The start of the note for a move judged by the final bot run instead of its own round. */
export const WAITS = `${FOREMAN_NOTE}new move judged at the end`;

/** Does a builder of `id` hand part of the change on since event `since` (a NOT DONE line whose files another package owns, or the cartridge's)? */
export function handsOn(plan: readonly PackageSpec[], events: readonly JobEvent[], id: string, since: number): boolean {
  const cart = cartridgeOwner(plan)?.id;
  const lines = events.flatMap((e) => (e.type === "note" && e.package === id && e.seq > since && !e.text.startsWith(FOREMAN_NOTE) ? noteLines(e.text) : [])).filter((l) => NOT_DONE.test(l));
  return lines.some((l) => ownerOf(plan, id, l) !== undefined || (cart !== undefined && cart !== id && /cartridge/i.test(l) && !NO_KEY.test(l)));
}

/**
 * At a promotion in a person's attack change: every new move a builder named that no round saw land (MOVES_LAND), judged
 * against the final verification's bot reports. A move that never lands, or that no bot counts, is told to the person as
 * not made (it reaches the what-changed card); one that lands gets the figures. [] when nothing is due.
 */
export function finalLandNotes(h: Pick<GateHost, "s" | "dir" | "events">): { type: "note"; package: string; round: number; text: string }[] {
  const asked = askedChange(h.events);
  if (asked === undefined || asked.kind !== "play" || !ATTACK_WORDS.test(asked.text)) return [];
  const since = h.events.filter((e) => e.seq > asked.seq);
  const judged = new Set(since.flatMap((e) => (e.type === "note" && (e.text.startsWith(MOVES_LAND) || (e.text.startsWith(`${FOREMAN_NOTE}${NOT_MADE} by `) && e.text.includes(": the new move"))) ? [e.package ?? ""] : [])));
  const ids = [...new Set(since.flatMap((e) => (e.type === "note" && e.package !== undefined && !judged.has(e.package) && !e.text.startsWith(FOREMAN_NOTE) && newMovesOf(e.text).length > 0 ? [e.package] : [])))];
  const named = ids.flatMap((id) => namedSince(h.events, id, asked.seq).map((m) => [id, m] as [string, string]));
  if (named.length === 0) return [];
  const finals = since.filter((e) => e.type === "verify" && e.package === undefined && e.after === undefined && e.verb === "bot" && e.ok);
  const lastRound = finals.at(-1)?.type === "verify" ? (finals.at(-1) as { round: number }).round : undefined;
  const reports = finals.flatMap((e) => {
    if (e.type !== "verify" || e.round !== lastRound) return [];
    try {
      const report = JSON.parse(fs.readFileSync(h.dir(e.report), "utf8")) as { bot?: { test?: string } };
      return [{ test: report.bot?.test ?? e.report, report }];
    } catch {
      return [];
    }
  });
  const out: { type: "note"; package: string; round: number; text: string }[] = [];
  for (const id of [...new Set(named.map(([p]) => p))]) {
    const moves = named.filter(([p]) => p === id).map(([, m]) => m);
    const v = judgeLanding(moves, reports);
    const said = moves.map((m) => figure(m, v.counts[m])).join(", ");
    const round = lastRound ?? 1;
    if (v.ok) out.push({ type: "note", package: id, round, text: `${MOVES_LAND}: ${said} (the final run: ${[...new Set(reports.map((r) => r.test))].join(", ")})` });
    else {
      const bad = [...v.missing, ...v.unused, ...v.never, ...v.stopped];
      out.push({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${NOT_MADE} by ${id}: the new move${bad.length === 1 ? "" : "s"} ${bad.join(", ")} ${v.never.length > 0 ? "never landed" : "was not seen to land"} in the Foreman's final bot run (${said}). Say it again (for example "the ${bad[0]} never hits anyone") to have it made.` });
    }
  }
  return out;
}
