// N4 loop round 2 (22 Nov): the critic compares a built game with its template's HOUSE GAME, by the same metric names.
// Once per job the Foreman plays one bot of the house game (its reference copy ref/packs/<pack>/, the regular hand) and
// keeps what it measured (reports/house-<pack>.json). The house bot reports either a `metrics` object in its result
// under the tofu names (GAME-QUALITY.md section 12), or the figures its pack state carries, read through a map. At every
// look of a job with a template, the built game's tofu figures are set beside the house game's: a row where the house
// game passes and the build does not, or where the build is worse than the house game by more than a margin, is a
// shortfall; the critic reads the table and the job's verdict names the shortfalls. Not measured is said, never zero.
import fs from "node:fs";
import type { GateHost } from "./p10gate.js";
import type { ConceptTemplate } from "./room_wire.js";
import { templateOf } from "./templates.js";
import { tofuMetricsFor, type TofuMetric, type TofuResult } from "./tofu.js";

/** How one house game is measured: the bot, and where each metric is in its report when it has no `metrics` object. */
export interface HouseBot {
  pack: string;
  test: string;
  args: string[];
  /** metric id -> a path in the report: "pack_state.x", "result.x", or "keys:pack_state.x" (how many keys have a count above 0). */
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
    strip: { test: "tests/bot_contact_heavy_block.gd", cam: "side", args: ["--seed=1"], label: "a heavy blocked: both freeze 6 frames, the defender slides back in blockstun, the attacker's blade bounces off and he rebounds 40 frames" },
  },
  arcade_sport: {
    pack: "hockey",
    test: "tests/bot_ladder_pro_regular.gd",
    hand: "regular",
    args: ["--seed=1"],
    // N3's ladder bots return `metrics` (main b61300f): possession_median_f and the tofu names directly; the median of
    // the raw lengths stays as the fallback for an older pack.
    map: { possession_median_f: "median:result.metrics.lengths|result.metrics.raw.lengths" },
    // idle_max_f there is the longest live stretch without a take, shot, pass or release (a dead puck: 606 f on pro
    // regular seed 1). The tofu row is checklist item 9, an OPPONENT that does nothing for 2 s; a skater carrying or
    // supporting acts. Different definitions: not compared, never loosened (N4 round 4; asked of N3: opponent idle).
    skip: ["idle_max_f"],
    // Round 4: the house hockey's own moment filmed from the same ladder bot (metrics.moments: frames by kind, read on
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
  strips?: { capture: string; label: string }[];
}

/** The frame of the first contact a house drill logged (pack_state.log[0].f), else 60 frames before the bot finished. */
export function contactFrame(report: unknown, moments: string[] = []): number | undefined {
  const r = report as { pack_state?: { log?: { f?: unknown }[] }; bot?: { frames?: unknown; result?: { contact?: { f?: unknown }; metrics?: { moments?: Record<string, unknown> } } } } | undefined;
  const m = r?.bot?.result?.metrics?.moments;
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
  try {
    return JSON.parse(fs.readFileSync(file, "utf8")) as HouseBaseline;
  } catch {
    /* not measured yet */
  }
  const packDir = h.dir("ref", "packs", bot.pack);
  let base: HouseBaseline = { schema: "tl.foreman.house/1", pack: bot.pack, test: bot.test, metrics: {} };
  if (!fs.existsSync(packDir)) base = { ...base, note: `the job's reference copy has no ref/packs/${bot.pack}/` };
  else {
    const vr = await h.verifyLogged({ verb: "bot", args: [`--test=${bot.test}`, ...bot.args] }, packDir, `house-${bot.pack}`, { round: 1 });
    const fig = houseFigures(vr.report, bot);
    base = { ...base, hand: bot.hand, ...fig, from: h.rel(vr.reportFile), ...(vr.ok ? {} : { note: `the house bot did not pass: ${vr.summary.slice(0, 200)}` }) };
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
}

/** How much worse than the house game a figure may be before it is a shortfall (a share of the house figure, or 1 for a count). */
const MARGIN = 0.25;

/** The built game's figures beside the house game's, by the template's tofu rows. */
export function houseCompare(built: TofuResult | undefined, base: HouseBaseline, rows: TofuMetric[] = tofuMetricsFor(undefined)): { rows: HouseRow[]; line: string; short: string[] } {
  const out: HouseRow[] = rows.map((m) => {
    const b = built?.rows.find((r) => r.id === m.id)?.value;
    const hv = base.metrics[m.id];
    let short = false;
    if (hv !== undefined) {
      const passes = (v: number): boolean => (m.min === undefined || v >= m.min) && (m.max === undefined || v <= m.max);
      if (b === undefined) short = true;
      else if (passes(hv) && !passes(b)) short = true;
      else {
        const slack = Math.max(Math.abs(hv) * MARGIN, Number.isInteger(hv) ? 1 : 0.05);
        // Lower is better for a bound with only a max (idle, feedback, one-sided contacts); higher for a min.
        if (m.max !== undefined && m.min === undefined && b > hv + slack) short = true;
        if (m.min !== undefined && m.max === undefined && b < hv - slack) short = true;
      }
    }
    return { id: m.id, ...(b !== undefined ? { built: b } : {}), ...(hv !== undefined ? { house: hv } : {}), short };
  });
  const shortIds = out.filter((r) => r.short).map((r) => r.id);
  const by = base.hand !== undefined ? ` through the ${base.hand} hand` : "";
  const cells = out.filter((r) => r.house !== undefined).map((r) => `${r.id} ${r.built ?? "not reported"} vs ${r.house}${r.short ? " SHORT" : ""}`);
  const unmeasured = out.filter((r) => r.house === undefined).map((r) => r.id);
  const line =
    cells.length === 0
      ? `house game engine/packs/${base.pack} (${base.test}): no figure to compare by the tofu names${base.note ? ` (${base.note})` : ""}`
      : `house game engine/packs/${base.pack} (${base.test}${by}), yours vs the house game's: ${cells.join(", ")}${unmeasured.length > 0 ? `; the house game does not report ${unmeasured.join(", ")}${(base.skipped ?? []).length > 0 ? ` (it measures ${(base.skipped ?? []).join(", ")} another way)` : ""}` : ""}${shortIds.length > 0 ? `. SHORT of the house game on ${shortIds.join(", ")}: copy how engine/packs/${base.pack} does it` : ". Not short of the house game on any figure it reports"}`;
  return { rows: out, line, short: shortIds };
}
