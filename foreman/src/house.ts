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
}

/** The house games' measuring bots (their own names, read from the packs on 22 Nov). */
export const HOUSE_BOTS: Record<string, HouseBot> = {
  duel: {
    pack: "duel",
    test: "tests/bot_checklist_wall.gd",
    args: ["--seed=1", "--frames=36000"],
    map: { idle_max_f: "pack_state.rival_passive_max", tell_min_f: "pack_state.rival_tells_min", contact_types: "keys:pack_state.kinds", one_sided_contacts: "pack_state.failures" },
  },
  arcade_sport: {
    pack: "hockey",
    test: "tests/bot_ladder_pro_regular.gd",
    args: ["--seed=1"],
    map: {},
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
}

const dig = (o: unknown, at: string): unknown => at.split(".").reduce<unknown>((x, k) => (x !== null && typeof x === "object" ? (x as Record<string, unknown>)[k] : undefined), o);

/** The figures of a house bot's report: its result's `metrics` first, then the map (a pure function of the report). */
export function houseFigures(report: unknown, bot: HouseBot): { metrics: Record<string, number>; hand?: string } {
  const out: Record<string, number> = {};
  const r = report as { bot?: { result?: Record<string, unknown> }; pack_state?: unknown } | undefined;
  const own = r?.bot?.result?.["metrics"];
  if (own !== null && typeof own === "object" && !Array.isArray(own)) for (const [k, v] of Object.entries(own as Record<string, unknown>)) if (typeof v === "number" && Number.isFinite(v)) out[k] = v;
  const src = { result: r?.bot?.result, pack_state: r?.pack_state };
  for (const [id, at] of Object.entries(bot.map)) {
    if (out[id] !== undefined) continue;
    const keys = at.startsWith("keys:");
    const v = dig(src, keys ? at.slice(5) : at);
    if (keys && v !== null && typeof v === "object") out[id] = Object.values(v as Record<string, unknown>).filter((x) => typeof x === "number" ? x > 0 : x !== undefined && x !== null).length;
    else if (!keys && typeof v === "number" && Number.isFinite(v)) out[id] = v;
  }
  const handOwn = (own as Record<string, unknown> | undefined)?.["hand"];
  const hand = typeof handOwn === "string" ? handOwn : typeof r?.bot?.result?.["hand"] === "string" ? (r.bot.result["hand"] as string) : undefined;
  return { metrics: out, ...(hand !== undefined ? { hand } : {}) };
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
    base = { ...base, ...fig, from: h.rel(vr.reportFile), ...(vr.ok ? {} : { note: `the house bot did not pass: ${vr.summary.slice(0, 200)}` }) };
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
      : `house game engine/packs/${base.pack} (${base.test}${by}), yours vs the house game's: ${cells.join(", ")}${unmeasured.length > 0 ? `; the house game does not report ${unmeasured.join(", ")}` : ""}${shortIds.length > 0 ? `. SHORT of the house game on ${shortIds.join(", ")}: copy how engine/packs/${base.pack} does it` : ". Not short of the house game on any figure it reports"}`;
  return { rows: out, line, short: shortIds };
}
