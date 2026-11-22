// N4 loop round 2 (22 Nov): the critic compares a built game with its template's HOUSE GAME, by the same metric names.
// Once per job the Foreman plays one bot of the house game (its reference copy ref/packs/<pack>/, the regular hand) and
// keeps what it measured (reports/house-<pack>.json). The house bot reports either a `metrics` object in its result
// under the tofu names (GAME-QUALITY.md section 12), or the figures its pack state carries, read through a map. At every
// look of a job with a template, the built game's tofu figures are set beside the house game's: a row where the house
// game passes and the build does not, or where the build is worse than the house game by more than a margin, is a
// shortfall; the critic reads the table and the job's verdict names the shortfalls. Not measured is said, never zero.
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import type { GateHost } from "./p10gate.js";
import type { ConceptTemplate } from "./room_wire.js";
import { templateOf } from "./templates.js";
import { tofuMetricsFor, type TofuMetric, type TofuResult } from "./tofu.js";
import { resultMoments } from "./shots.js";
import { snapshot } from "./scope.js";

/** How one house game is measured: the bot, and where each metric is in its report when it has no `metrics` object. */
export interface HouseBot {
  pack: string;
  test: string;
  args: string[];
  /** metric id -> a path in the report: "pack_state.x", "result.x", "keys:pack_state.x" (how many keys have a count above 0), "median:x" or "ratio:x/y". */
  map: Record<string, string>;
  /** The TLHand profile the bot plays through (said in every comparison). */
  hand: string;
  /** Round 4: tofu names the house bot reports under another definition: never compared (said in the line). */
  skip?: string[];
  /** Round 2: the house game's own exchange filmed as a motion strip for the critic: a drill bot and a camera. */
  strip?: { test: string; cam: string; args: string[]; label: string; moments?: string[] };
}

/** The house games' measuring bots (their own names, read from the packs on 22 Nov). */
export const HOUSE_BOTS: Record<string, HouseBot> = {
  duel: {
    pack: "duel",
    test: "tests/bot_checklist_wall.gd",
    hand: "regular",
    // N2's pilot returns `metrics` under the tofu names (main 3004e58). Its skill_spread is over all hits and its
    // skill_variants the distinct verbs used; the tofu rows count variants of the core verb only: not compared.
    skip: ["skill_spread", "skill_variants", "contact_types"],
    args: ["--seed=1", "--frames=36000"],
    // Read from the real runner on 22 Nov 02:00: the pilot's result carries these (the verify report has no pack_state).
    // contact_types is left out: the house game counts every 6.3 row (and ko, absorbed); a build's own names are coarser.
    map: { idle_max_f: "result.rival_passive_max|pack_state.rival_passive_max", tell_min_f: "result.rival_tells_min|pack_state.rival_tells_min", one_sided_contacts: "result.failures|pack_state.failures" },
    // Round 11: a moment of a real match (N2's pilot returns `moments` since duel round 8): the measuring bot itself, at its
    // first parry (real seed 1: parried at 2269; the drill's blocked heavy is the fallback when no moment is reported).
    strip: { test: "tests/bot_checklist_wall.gd", cam: "side", args: ["--seed=1", "--frames=36000"], moments: ["parried", "blocked_heavy", "clash", "guard_break", "wall_splat", "hit_heavy"], label: "a moment of a real match against the Wall, regular hand (a parry: both freeze, the gold flash, the attacker flung open; or a blocked heavy, a clash, a guard break): what each body does on contact" },
  },
  arcade_sport: {
    pack: "hockey",
    test: "tests/bot_ladder_pro_regular.gd",
    hand: "regular",
    args: ["--seed=1"],
    // N3's ladder bots return `metrics` (main b61300f): possession_median_f and the tofu names directly; the median of
    // the raw lengths stays as the fallback for an older pack.
    // D3 of 22 Nov: the spacing rows from the house's raw counts (crowd4, overlap_frames over live frames).
    map: { possession_median_f: "median:result.metrics.lengths|result.metrics.raw.lengths", scrum_share: "ratio:result.metrics.raw.crowd4/result.metrics.raw.live", overlap_share: "ratio:result.metrics.raw.overlap_frames/result.metrics.raw.live" },
    // idle_max_f was a dead puck until N3's round 2 (fc2961f) and was skipped; since then it is the tofu row's own
    // definition (tests/metrics.gd: a red field skater under 0.5 m/s, not carrying, not down, the longest live stretch;
    // 70 f on pro regular seed 1, read 22 Nov 12:53), the dead puck is dead_puck_max_f. Compared now (D3 22 Nov).
    // Round 4: the house hockey's own moment filmed from the same ladder bot (metrics.raw.moments since N3 round 1, see shots.resultMoments: frames by kind, read on
    // the real runner 22 Nov 02:40: seed 1 gave poked [523], bobble [2819, ...]); the chase camera follows the play.
    strip: { test: "tests/bot_ladder_pro_regular.gd", cam: "chase", args: ["--seed=1"], moments: ["one_timer", "poked", "poke", "lost", "bobble"], label: "a moment of the house hockey's play (a one-timer, a poke or a lost puck): the carry on the blade, the stick, the puck's readable loss" },
  },
};

export interface HouseBaseline {
  schema: "tl.foreman.house/1";
  pack: string;
  test: string;
  hand?: string;
  /** The metric figures measured, by the tofu names. */
  metrics: Record<string, number>;
  /** The bot report it was read from (job-relative), or why there is none. */
  from?: string;
  note?: string;
  /** Round 4: tofu names the house bot reported under another definition, left out of the comparison. */
  skipped?: string[];
  /** Round 2: the house game's exchange as motion strips (job-relative), filmed once; [] when it could not be. */
  strips?: { capture: string; label: string; kind?: string }[];
  /**
   * D3 of 22 Nov: what the baseline was measured from: the house pack's files, the house bot and its strip moment kinds,
   * and HOUSE_MEASURE. A baseline whose key differs from today's is measured and filmed again (proofs -5 and -6 kept a
   * KO-fallback house strip, filmed before N4 round 13 taught the reader where the duel pilot keeps its moments).
   */
  key?: string;
}

/** Bumped when the way the house baseline is read or filmed changes (a cached baseline from before is then stale). */
export const HOUSE_MEASURE = "d3-2026-11-22-1";

/** The key of a house baseline: the house pack's files, the bot (test, args, strip and its moment kinds), HOUSE_MEASURE. */
export function houseKey(packDir: string, bot: HouseBot): string {
  const files = fs.existsSync(packDir) ? snapshot(packDir) : {};
  return crypto.createHash("sha1").update(JSON.stringify({ m: HOUSE_MEASURE, files, test: bot.test, args: bot.args, map: bot.map, skip: bot.skip ?? [], strip: bot.strip ?? null })).digest("hex").slice(0, 16);
}

/** The first listed moment the house bot saw, with its kind; else the drill's contact frame or 60 before the finish (no kind). */
export function contactMoment(report: unknown, moments: string[] = []): { frame: number; kind?: string } | undefined {
  const m = resultMoments((report as { bot?: { result?: unknown } } | undefined)?.bot?.result);
  for (const k of moments) {
    const f = Array.isArray(m?.[k]) ? (m?.[k] as unknown[])[0] : undefined;
    if (typeof f === "number" && Number.isFinite(f)) return { frame: f, kind: k };
  }
  const f = contactFrame(report, []);
  return f !== undefined ? { frame: f } : undefined;
}

/** The frame of the first contact a house drill logged (pack_state.log[0].f), else 60 frames before the bot finished. */
export function contactFrame(report: unknown, moments: string[] = []): number | undefined {
  const r = report as { pack_state?: { log?: { f?: unknown }[] }; bot?: { frames?: unknown; result?: { contact?: { f?: unknown }; moments?: Record<string, unknown>; metrics?: { moments?: Record<string, unknown> } } } } | undefined;
  const m = resultMoments(r?.bot?.result); // the duel pilot: result.moments; hockey: metrics.raw.moments (D3 22 Nov)
  // Round 4: the first listed moment the bot saw (hockey's metrics.moments), before a drill's contact frame.
  const moment = moments.map((k) => (Array.isArray(m?.[k]) ? (m?.[k] as unknown[])[0] : undefined)).find((x) => typeof x === "number");
  const f = moment ?? r?.bot?.result?.contact?.f ?? r?.pack_state?.log?.[0]?.f; // the duel's drill reports result.contact.f
  if (typeof f === "number" && Number.isFinite(f)) return f;
  const done = r?.bot?.frames;
  return typeof done === "number" && Number.isFinite(done) ? Math.max(1, done - 60) : undefined;
}

/** Writes the job's house baseline back (after its strips were filmed). */
export function saveBaseline(h: Pick<GateHost, "dir">, base: HouseBaseline): void {
  fs.writeFileSync(h.dir("reports", `house-${base.pack}.json`), JSON.stringify(base, null, 1) + "\n");
}

const dig = (o: unknown, at: string): unknown => at.split(".").reduce<unknown>((x, k) => (x !== null && typeof x === "object" ? (x as Record<string, unknown>)[k] : undefined), o);

/** The figures of a house bot's report: its result's `metrics` first, then the map (a pure function of the report). */
export function houseFigures(report: unknown, bot: HouseBot): { metrics: Record<string, number>; hand?: string; skipped?: string[] } {
  const out: Record<string, number> = {};
  const r = report as { bot?: { result?: Record<string, unknown> }; pack_state?: unknown } | undefined;
  const own = r?.bot?.result?.["metrics"];
  if (own !== null && typeof own === "object" && !Array.isArray(own)) for (const [k, v] of Object.entries(own as Record<string, unknown>)) if (typeof v === "number" && Number.isFinite(v)) out[k] = v;
  const src = { result: r?.bot?.result, pack_state: r?.pack_state };
  for (const [id, at] of Object.entries(bot.map)) {
    if (out[id] !== undefined) continue;
    if (at.startsWith("ratio:")) {
      const [num, den] = at.slice(6).split("/").map((x) => dig(src, x));
      if (typeof num === "number" && typeof den === "number" && Number.isFinite(num) && den > 0) out[id] = Math.round((num / den) * 1000) / 1000;
      continue;
    }
    const keys = at.startsWith("keys:");
    const median = at.startsWith("median:");
    const paths = (keys ? at.slice(5) : median ? at.slice(7) : at).split("|");
    const v = paths.map((x) => dig(src, x)).find((x) => x !== undefined);
    if (median) {
      const xs = (Array.isArray(v) ? v : []).filter((x): x is number => typeof x === "number" && Number.isFinite(x)).sort((a, b) => a - b);
      if (xs.length > 0) out[id] = xs.length % 2 === 1 ? (xs[(xs.length - 1) / 2] as number) : ((xs[xs.length / 2 - 1] as number) + (xs[xs.length / 2] as number)) / 2;
    } else if (keys && v !== null && typeof v === "object") out[id] = Object.values(v as Record<string, unknown>).filter((x) => typeof x === "number" ? x > 0 : x !== undefined && x !== null).length;
    else if (!keys && typeof v === "number" && Number.isFinite(v)) out[id] = v;
  }
  const skipped = (bot.skip ?? []).filter((k) => out[k] !== undefined);
  for (const k of skipped) delete out[k];
  const handOwn = (own as Record<string, unknown> | undefined)?.["hand"];
  const hand = typeof handOwn === "string" ? handOwn : typeof r?.bot?.result?.["hand"] === "string" ? (r.bot.result["hand"] as string) : undefined;
  return { metrics: out, ...(hand !== undefined ? { hand } : {}), ...(skipped.length > 0 ? { skipped } : {}) };
}

/** The job's house baseline for its template: read from reports/house-<pack>.json, or measured once and written there. */
export async function houseBaseline(h: GateHost, template: ConceptTemplate | undefined): Promise<HouseBaseline | undefined> {
  const bot = template !== undefined ? HOUSE_BOTS[template.id] : undefined;
  if (bot === undefined || templateOf(template?.id)?.house === undefined) return undefined;
  const file = h.dir("reports", `house-${bot.pack}.json`);
  const packDir = h.dir("ref", "packs", bot.pack);
  const key = houseKey(packDir, bot);
  let stale: string | undefined;
  try {
    const cached = JSON.parse(fs.readFileSync(file, "utf8")) as HouseBaseline;
    if (cached.key === key) return cached;
    stale = cached.key === undefined ? "it has no key (measured before D3 of 22 Nov)" : "the house pack, its bot or its moment kinds changed";
  } catch {
    /* not measured yet */
  }
  let base: HouseBaseline = { schema: "tl.foreman.house/1", pack: bot.pack, test: bot.test, metrics: {}, key, ...(stale !== undefined ? { note: `measured again: the cached baseline was stale (${stale})` } : {}) };
  if (!fs.existsSync(packDir)) base = { ...base, note: `the job's reference copy has no ref/packs/${bot.pack}/` };
  else {
    const vr = await h.verifyLogged({ verb: "bot", args: [`--test=${bot.test}`, ...bot.args] }, packDir, `house-${bot.pack}`, { round: 1 });
    const fig = houseFigures(vr.report, bot);
    base = { ...base, hand: bot.hand, ...fig, from: h.rel(vr.reportFile), ...(vr.ok ? {} : { note: `${base.note !== undefined ? `${base.note}; ` : ""}the house bot did not pass: ${vr.summary.slice(0, 200)}` }) };
  }
  fs.mkdirSync(h.dir("reports"), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(base, null, 1) + "\n");
  return base;
}

export interface HouseRow {
  id: string;
  built?: number;
  house?: number;
  short: boolean;
  /** The build's figure is contradicted by its own film. */
  contradicted?: true;
  /** D3 of 22 Nov: the house game's own figure is outside the template's bound for the row. */
  houseOutside?: true;
}

/** How much worse than the house game a figure may be before it is a shortfall (a share of the house figure, or 1 for a count). */
const MARGIN = 0.25;

/** The built game's figures beside the house game's, by the template's tofu rows. */
export function houseCompare(built: TofuResult | undefined, base: HouseBaseline, rows: TofuMetric[] = tofuMetricsFor(undefined)): { rows: HouseRow[]; line: string; short: string[] } {
  const out: HouseRow[] = rows.map((m) => {
    const row = built?.rows.find((r) => r.id === m.id);
    const b = row?.value;
    const hv = base.metrics[m.id];
    let short = false;
    // D3 of 22 Nov: a figure the film contradicts is never as good as the house game's (filmcheck.ts).
    if (hv !== undefined && row?.contradicted !== undefined) short = true;
    else if (hv !== undefined) {
      const passes = (v: number): boolean => (m.min === undefined || v >= m.min) && (m.max === undefined || v <= m.max);
      if (b === undefined) short = true;
      else if (passes(hv) && !passes(b)) short = true;
      else {
        const slack = Math.max(Math.abs(hv) * MARGIN, Number.isInteger(hv) ? 1 : 0.05);
        // Lower is better for a bound with only a max (idle, feedback, one-sided contacts); higher for a min.
        if (m.max !== undefined && m.min === undefined && b > hv + slack) short = true;
        if (m.min !== undefined && m.max === undefined && b < hv - slack) short = true;
        // D3 of 22 Nov: a band (possession_median_f 240-600) has no better side: the house game's figure is the bar, and a
        // build further from it than the margin is short. Hockey -2 held possession 377 frames against the house's 164
        // (endless board scrums on its strips) and the line said "not short on any figure".
        if (m.min !== undefined && m.max !== undefined && Math.abs(b - hv) > slack) short = true;
      }
    }
    const outside = hv !== undefined && ((m.min !== undefined && hv < m.min) || (m.max !== undefined && hv > m.max));
    return { id: m.id, ...(b !== undefined ? { built: b } : {}), ...(hv !== undefined ? { house: hv } : {}), short, ...(row?.contradicted !== undefined ? { contradicted: true as const } : {}), ...(outside ? { houseOutside: true as const } : {}) };
  });
  // D3 of 22 Nov: a house figure outside the template's own bound is said: the bound or the house game is wrong, and the Director decides which.
  const outsideRows = out.filter((r) => r.houseOutside === true).map((r) => { const m = rows.find((x) => x.id === r.id); return `${r.id} ${r.house} (the template's bound: ${m?.min !== undefined && m.max !== undefined ? `${m.min} to ${m.max}` : m?.min !== undefined ? `>= ${m.min}` : `<= ${m?.max}`})`; });
  // D3 of 22 Nov: a claim the build's film contradicts where the house game has no figure (moments_on_film, hockey's
  // idle_max_f) still cannot pass this compare: it is named short, with why.
  const filmOnly = (built?.rows ?? []).filter((r) => r.contradicted !== undefined && !out.some((o) => o.id === r.id && o.house !== undefined)).map((r) => r.id);
  const shortIds = [...out.filter((r) => r.short).map((r) => r.id), ...filmOnly];
  const by = base.hand !== undefined ? ` through the ${base.hand} hand` : "";
  const cells = out.filter((r) => r.house !== undefined).map((r) => `${r.id} ${r.built ?? "not reported"}${r.contradicted ? " (CONTRADICTED by the film)" : ""} vs ${r.house}${r.short ? " SHORT" : ""}`);
  const unmeasured = out.filter((r) => r.house === undefined).map((r) => r.id);
  const line =
    cells.length === 0
      ? `house game engine/packs/${base.pack} (${base.test}): no figure to compare by the tofu names${base.note ? ` (${base.note})` : ""}`
      : `house game engine/packs/${base.pack} (${base.test}${by}), yours vs the house game's: ${cells.join(", ")}${unmeasured.length > 0 ? `; the house game does not report ${unmeasured.join(", ")}${(base.skipped ?? []).length > 0 ? ` (it measures ${(base.skipped ?? []).join(", ")} another way)` : ""}` : ""}${shortIds.length > 0 ? `. SHORT of the house game on ${shortIds.join(", ")}: copy how engine/packs/${base.pack} does it` : ". Not short of the house game on any figure it reports"}`;
  const said = outsideRows.length > 0 ? `${line}. The house game itself sits outside the template's bound on ${outsideRows.join(", ")}: judged against the house figure` : line;
  return { rows: out, line: filmOnly.length > 0 ? `${said}. The build's own film contradicts its ${filmOnly.join(", ")} (no house figure to compare): short until the film agrees` : said, short: shortIds };
}
