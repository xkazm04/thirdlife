// L2b of 21 Nov: what a milestone's captures show, and who was playing. Found by the crazy proof job
// (fight-colosseum-20261120-2): the critic scored fun_promise 0 twice on the flood phase, "no water in any frame",
// while the flood package's own bot reported "flood at frame 2402". The captures were taken at 25 % and 75 % of the
// FIRST bot's finish (bot_bout, ~465 frames), so a late-game twist was never on camera.
// Now a milestone films up to two bots: the pack's first test as before (25 % and 75 % of its finish), and the own
// acceptance bot of the milestone's newest package that has one, at 25 % and 95 % of where THAT bot finished
// (bot_flood finishes at 2582: 75 % is 1937, before the flood; 95 % is 2453, inside it).
import fs from "node:fs";
import path from "node:path";
import type { JobEvent, PackageSpec } from "./events.js";

/** One bot to film for a milestone: which test, whose package, at which frames, and where that bot finished. */
export interface Shot {
  bot?: string;
  package?: string;
  frames: number[];
  /** The frame the bot finished at in its last passing report; absent when there is none. */
  finish?: number;
  /** "own": a package's own acceptance bot; "first": the pack's first test (the rule before L2b). */
  kind: "own" | "first";
  /** L1b: the clip ids (brief.design.clips) its package `serves`: the critic sees this shot's strips first. */
  clips?: string[];
  /** N4 loop round 9: the frames of `frames` that are the bot's contact moments (filmed as dense CONTACT strips). */
  moments?: number[];
}

/** At most this many bots are filmed per milestone (each at two frames, for every declared camera). */
export const MAX_SHOT_BOTS = 2;
export const OWN_FRACTIONS = [0.25, 0.95] as const;
export const FIRST_FRACTIONS = [0.25, 0.75] as const;

/** The frame a bot finished at in its last passing report in the log, or undefined. */
export function botFinish(jobDir: string, events: readonly JobEvent[], bot: string): number | undefined {
  for (const e of [...events].reverse()) {
    if (e.type !== "verify" || e.verb !== "bot" || !e.ok) continue;
    try {
      const r = JSON.parse(fs.readFileSync(path.join(jobDir, e.report), "utf8")) as { bot?: { test?: unknown; done?: unknown; frames?: unknown } };
      const f = r.bot?.frames;
      if (r.bot?.test !== bot || r.bot?.done !== true || typeof f !== "number" || !Number.isFinite(f) || f < 4) continue;
      return f;
    } catch {
      /* an unreadable report is not a passing report */
    }
  }
  return undefined;
}

/**
 * N4 loop round 8 (22 Nov): the frames where the bot saw the exchange happen, from its last passing report: the result's
 * `moments` (or `metrics.moments`), an object of kind -> frames. The crazy proof -3 was filmed at fixed fractions of its
 * bot's run and two of its strips were 60 frames of both fighters standing still.
 */
export function botMoments(jobDir: string, events: readonly JobEvent[], bot: string): { kind: string; frame: number }[] {
  for (const e of [...events].reverse()) {
    if (e.type !== "verify" || e.verb !== "bot" || !e.ok) continue;
    try {
      const r = JSON.parse(fs.readFileSync(path.join(jobDir, e.report), "utf8")) as { bot?: { test?: unknown; result?: { moments?: unknown; metrics?: { moments?: unknown } } } };
      if (r.bot?.test !== bot) continue;
      const m = r.bot.result?.moments ?? r.bot.result?.metrics?.moments;
      if (m === null || typeof m !== "object" || Array.isArray(m)) return [];
      const out: { kind: string; frame: number }[] = [];
      for (const [kind, v] of Object.entries(m as Record<string, unknown>)) for (const f of Array.isArray(v) ? v : []) if (typeof f === "number" && Number.isFinite(f) && f > 0) out.push({ kind, frame: Math.round(f) });
      return out.sort((a, b) => a.frame - b.frame);
    } catch {
      /* an unreadable report has no moments */
    }
  }
  return [];
}

/** Up to `n` moments to film: the first frame of each kind in turn (variety first), at least 31 frames in (a strip's lead-up), sorted by frame. */
export function pickMoments(moments: { kind: string; frame: number }[], n: number): number[] {
  const usable = moments.filter((m) => m.frame > 30);
  const kinds = [...new Set(usable.map((m) => m.kind))];
  const out: number[] = [];
  for (let round = 0; out.length < n && round < usable.length; round++) {
    for (const k of kinds) {
      const f = usable.filter((m) => m.kind === k)[round]?.frame;
      if (f !== undefined && !out.includes(f) && out.length < n) out.push(f);
    }
  }
  return out.sort((a, b) => a - b);
}

/** The two capture frames for a finish frame: [25 %, 95 %] for a package's own bot, [25 %, 75 %] for the first test; 120 and 480 without one. */
export function shotFrames(finish: number | undefined, kind: Shot["kind"]): number[] {
  if (finish === undefined) return [120, 480];
  const [a, b] = kind === "own" ? OWN_FRACTIONS : FIRST_FRACTIONS;
  return [Math.max(1, Math.round(finish * a)), Math.max(2, Math.round(finish * b))];
}

/**
 * The bots a milestone is filmed with. First, as before L2b, the manifest's first test at 25 % and 75 % of its finish
 * (the same shot every milestone, so the art-pass check can compare like with like). Then the milestone's packages,
 * newest merge first, each with its own acceptance bot (a test its acceptance runs AND it registers), one shot per
 * bot, until MAX_SHOT_BOTS bots are filmed. `fixed` (the captureFrames option) sets the frames of every shot.
 */
export function planShots(
  plan: PackageSpec[],
  events: readonly JobEvent[],
  members: string[],
  manifestTests: string[],
  finishOf: (bot: string) => number | undefined,
  fixed?: number[],
  momentsOf: (bot: string) => { kind: string; frame: number }[] = () => [],
): Shot[] {
  // Round 8: where the bot reports its moments, film them. The first test keeps its 25 % frame (the art-pass check compares
  // the same frame milestone to milestone) and films its first moment second; a package's own bot films two moments.
  const atMoments = (bot: string | undefined, base: number[], keepFirst: boolean): number[] => {
    if (bot === undefined) return base;
    const m = pickMoments(momentsOf(bot), keepFirst ? 1 : 2);
    if (m.length === 0) return base;
    return keepFirst ? [base[0] as number, ...m.filter((f) => f !== base[0])] : m.length === 1 ? [...m, ...base.slice(1).filter((f) => f !== m[0])].slice(0, 2) : m;
  };
  // Round 9: which of a shot's frames are contact moments (their strips are dense: see CONTACT_STRIP).
  const momentsIn = (bot: string | undefined, frames: number[]): { moments?: number[] } => {
    if (bot === undefined) return {};
    const all = new Set(momentsOf(bot).map((x) => x.frame));
    const hit = frames.filter((f) => all.has(f));
    return hit.length > 0 ? { moments: hit } : {};
  };
  const first = manifestTests[0];
  const firstFinish = first !== undefined ? finishOf(first) : undefined;
  const firstOwner = first !== undefined ? plan.find((p) => (p.registers?.tests ?? []).includes(first))?.id : undefined;
  const servesOf = (id: string | undefined): { clips?: string[] } => { const sv = plan.find((p) => p.id === id)?.serves ?? []; return sv.length > 0 ? { clips: sv } : {}; };
  const shots: Shot[] = [{ ...(first !== undefined ? { bot: first } : {}), ...(firstOwner !== undefined ? { package: firstOwner } : {}), ...servesOf(firstOwner), frames: fixed ?? atMoments(first, shotFrames(firstFinish, "first"), true), ...(fixed === undefined ? momentsIn(first, atMoments(first, shotFrames(firstFinish, "first"), true)) : {}), ...(firstFinish !== undefined ? { finish: firstFinish } : {}), kind: "first" }];
  const taken = new Set(first !== undefined ? [first] : []);
  const lastMerge = new Map<string, number>();
  for (const e of events) if (e.type === "merge" && e.files.length > 0) lastMerge.set(e.package, e.seq);
  // L1b: a package that serves a clip moment is filmed before the newest one that serves none.
  const serving = (id: string): number => ((plan.find((p) => p.id === id)?.serves ?? []).length > 0 ? 1 : 0);
  const newest = [...members].sort((a, b) => serving(b) - serving(a) || (lastMerge.get(b) ?? 0) - (lastMerge.get(a) ?? 0));
  for (const id of newest) {
    if (shots.length >= MAX_SHOT_BOTS) break;
    const spec = plan.find((p) => p.id === id);
    const runs = (spec?.acceptance ?? []).filter((a) => a.verb === "bot").map((a) => a.args.find((x) => x.startsWith("--test="))?.slice("--test=".length));
    const bot = runs.find((t): t is string => t !== undefined && (spec?.registers?.tests ?? []).includes(t) && manifestTests.includes(t) && !taken.has(t));
    if (bot === undefined) continue;
    taken.add(bot);
    const finish = finishOf(bot);
    const own = fixed ?? atMoments(bot, shotFrames(finish, "own"), false);
    shots.push({ bot, package: id, frames: own, ...(fixed === undefined ? momentsIn(bot, own) : {}), ...(finish !== undefined ? { finish } : {}), kind: "own", ...servesOf(id) });
  }
  return shots;
}

/** The capture file of a milestone shot: the first shot keeps the old name; a second bot's carries the bot's stem. */
export function shotFile(milestone: string, cam: string, frame: number, shot: Shot, index: number): string {
  const stem = shot.bot !== undefined ? path.basename(shot.bot, ".gd") : "nobot";
  return index === 0 ? `${milestone}-${cam}-f${frame}.png` : `${milestone}-${cam}-${stem}-f${frame}.png`;
}

/** What the critic is told about one capture: the camera, the frame, and which bot of which package was playing. */
export function shotLabel(cam: string, frame: number, shot: Shot): string {
  if (shot.bot === undefined) return `camera ${cam}, frame ${frame}, no bot playing`;
  const share = shot.finish !== undefined ? `, ${Math.round((frame / shot.finish) * 100)} % of the frame ${shot.finish} where it finished` : "";
  const whose = shot.package !== undefined ? ` of package ${shot.package}` : "";
  return `camera ${cam}, frame ${frame}, while ${shot.bot}${whose} plays${share}`;
}

/** JOB.md 2026-11-21: a motion strip is a 4x3 tile of 12 frames, 5 apart (`capture --strip=12x5`). */
export const STRIP = { count: 12, step: 5 } as const;

/**
 * N4 loop round 9: a CONTACT strip around a moment the bot reported: 12 frames 2 apart from 10 before it, so a 6-frame
 * hit-stop holds both bodies still over 3 tiles (5 apart it is one tile, and the critic of the proofs read "no visible
 * hit-stop" on cores that freeze both bodies). Real house duel heavy_block, contact at 46: tiles 6-9 of f36 hold.
 */
export const CONTACT_STRIP = { count: 12, step: 2, before: 10 } as const;

/** The first frame of the strip around a filmed point: 30 frames before it, so the strip holds the lead-up and the result. */
export const stripFrom = (frame: number): number => Math.max(1, frame - 30);

/** `captures/<milestone>-<cam>-<bot stem>-strip-f<from>.png` (JOB.md 2026-11-21). */
export function stripFile(milestone: string, cam: string, shot: Shot, from: number): string {
  return `${milestone}-${cam}-${shot.bot !== undefined ? path.basename(shot.bot, ".gd") : "nobot"}-strip-f${from}.png`;
}

/** What the critic is told about a strip: the tile's reading order and frames, the camera and the bot. */
export function stripLabel(cam: string, from: number, shot: Shot, step: number = STRIP.step): string {
  const last = from + step * (STRIP.count - 1);
  const contact = step !== STRIP.step ? `CONTACT (a moment the bot reported, frame ${from + CONTACT_STRIP.before}; ${step} frames apart, so a hit-stop shows as tiles that hold still) ` : "";
  return `${shot.clips?.length ? `CLIP MOMENT ${shot.clips.join(", ")} (its package serves it): ` : ""}${contact}MOTION STRIP (4 columns x 3 rows, read left to right, top to bottom: frames ${from}, ${from + step}, ... ${last}, ${step} frames apart) of ${shotLabel(cam, from, shot).replace(/^camera /, "camera ")}`;
}
