// N4 of 22 Nov (GAME-QUALITY.md v2 section 12): the tofu stage. "Build the core verb with flat shapes, and kill it unless
// it is fun in an empty room" (docs/research/WHAT-MADE-GAMES-POPULAR.md). The first phase of a design-room job is the
// core verb exchange on flat shapes (milestone `blockout`), and its root contract names ONE bot in a line
//   TOFU CHECK: tests/<bot>.gd reports metrics feedback_f, skill_spread, ...
// That bot's `_bot_result()` carries a `metrics` object (PACK.md: any numbers beside ok and summary; the runner reports
// it as `bot.result.metrics`). When the blockout milestone is looked at, the Foreman reads the newest report of that bot
// and judges checklist items 1, 3, 9, 11, 12 and 15 (plus the template's own rows) with the critic's look: NOT ok is a
// revise round and then a quality hold, exactly like the critic (quality.ts). Not measured is not zero: an absent
// metric fails. Pure apart from reading bot reports.
import fs from "node:fs";
import path from "node:path";
import type { JobEvent, PackageSpec, Phase } from "./events.js";
import type { ConceptTemplate } from "./room_wire.js";
import { templateOf } from "./templates.js";

/** The milestone the tofu stage is (flat shapes, kit primitives, no art). */
export const TOFU_MILESTONE = "blockout";

export const TOFU_CHECK_RE = /^[ \t>*-]*TOFU CHECK:[ \t]*`?(tests\/[A-Za-z0-9_\/.-]+\.gd)`?[ \t]*(.*)$/m;

/** One row of the tofu check: a metric of the bot's `metrics` object, the checklist item it measures, its bound. */
export interface TofuMetric {
  id: string;
  item: string;
  min?: number;
  max?: number;
  /** How the bot counts it (the Planner pastes this into the root contract; builders read it). */
  how: string;
}

/** The six checklist items of the tofu stage (GAME-QUALITY.md section 12), as bot metrics. */
export const TOFU_METRICS: TofuMetric[] = [
  { id: "feedback_f", item: "1 feedback within 3 f", max: 3, how: "over every press of the core verb: the most frames from the press to the first frame the player's body or weapon visibly changed" },
  { id: "skill_spread", item: "3 an analogue skill dimension", min: 0.25, max: 0.95, how: "(best mean outcome - worst mean outcome) / best mean outcome over variants of the CORE verb alone (the same light or heavy pressed at another timing, spacing, charge or angle; a different move such as a bash is NOT a variant), each mean over at least 5 tries; outcome = damage, knockback or frame advantage. 1.0 means a variant that never works: that is a different verb, not skill" },
  { id: "skill_variants", item: "3 an analogue skill dimension", min: 3, how: "how many variants of the core verb skill_spread compared, each tried at least 5 times" },
  { id: "idle_max_f", item: "9 no idle opponent", max: 120, how: "the longest run of frames any opponent spent with no action (not moving with intent, not attacking, not defending)" },
  { id: "tell_min_f", item: "11 tells of 12 f or more", min: 12, how: "over every dangerous opponent action that started: the fewest frames from the first frame of its tell pose to its first active frame" },
  { id: "tells", item: "11 tells of 12 f or more", min: 3, how: "how many dangerous opponent actions tell_min_f counted" },
  { id: "pressure_waves", item: "12 pressure in waves", min: 2, how: "opponent attacks started per 3 s (180-frame) window; a wave is a busy window (3 or more starts) after a quiet one (1 or fewer); the count of waves (the duel house game's definition, tests/support/pilot.gd)" },
  { id: "lead_change_share", item: "15 leads change hands", min: 0.3, how: "over at least 3 rounds: the share of rounds in which the lead changed hands at least once (the duel house game's definition)" },
  { id: "close_rounds", item: "15 leads change hands", min: 1, how: "how many rounds ended close (the loser within 35 % of his health, or one point)" },
  // N4 loop round 3: the crazy colosseum proof's tofu bot passed every row while no strip showed a parry, a roll or a bash.
  { id: "verbs_used", item: "the whole exchange: every verb of the design pressed", min: 2, how: "how many of the design's verbs the bot pressed at least 3 times each in its run (the duel: light, heavy, block or parry, roll, bash); it must be all of them" },
];

/** The rows for a job: the six items, then the template's own (the duel's contacts, the sport's possession). */
export function tofuMetricsFor(template: ConceptTemplate | undefined, verbs?: number): TofuMetric[] {
  const t = templateOf(template?.id);
  const base = verbs !== undefined ? TOFU_METRICS.map((m) => (m.id === "verbs_used" ? { ...m, min: verbs } : m)) : TOFU_METRICS;
  return [...base, ...(t?.metrics ?? []).map((m) => ({ id: m.id, item: m.item, ...(m.min !== undefined ? { min: m.min } : {}), ...(m.max !== undefined ? { max: m.max } : {}), how: m.item }))];
}

const bound = (m: Pick<TofuMetric, "min" | "max">): string => (m.min !== undefined && m.max !== undefined ? `${m.min} to ${m.max}` : m.min !== undefined ? `>= ${m.min}` : `<= ${m.max}`);

/** The exact line the root contract carries. */
export function tofuLine(template: ConceptTemplate | undefined, test = "tests/bot_tofu.gd"): string {
  return `TOFU CHECK: ${test} reports metrics ${tofuMetricsFor(template).map((m) => m.id).join(", ")}`;
}

/** The Planner's tofu block: the line to write, the metrics with their bounds and how the bot counts them. */
export function tofuPlannerText(template: ConceptTemplate | undefined, verbs?: number): string {
  return [
    "The first phase is the tofu stage (docs/GAME-QUALITY.md section 12): the core verb exchange on flat shapes. Its packages are milestone `blockout` (and no package of a later phase is). The root package's contract carries this line, word for word (the plan is refused without it):",
    `  ${tofuLine(template)}`,
    "That bot is registered by the root package and runs in its acceptance. Its `_bot_result()` returns `{ok, summary, metrics: {...}}` with every metric below COUNTED from the frames it played (never a constant), plus `hand` (the TLHand profile it played the player's side through). When the blockout milestone is reached the Foreman judges them; any metric absent or out of bounds sends the root back (two revise rounds) and then holds the job, before the second phase starts. Paste the rows into the root contract:",
    ...tofuMetricsFor(template, verbs).map((m) => `  - \`${m.id}\` ${bound(m)} (checklist item ${m.item}): ${m.how}`),
  ].join("\n");
}

/** The plan's tofu bot: the package whose contract carries the line, and the test it names. */
export function tofuOf(plan: readonly PackageSpec[]): { package: string; test: string } | undefined {
  for (const p of plan) {
    const m = TOFU_CHECK_RE.exec(p.contract);
    if (m) return { package: p.id, test: m[1] as string };
  }
  return undefined;
}

/**
 * Problems of a plan's tofu stage. `required` (a brief with a design doc): the root contract carries the line. When a
 * line is there: one only, in the root package, naming every metric; the bot registered by that package and run in its
 * acceptance; the first phase is the blockout milestone, exactly (its packages blockout, no later package blockout).
 */
export function tofuPlanProblems(packages: PackageSpec[], phases: Phase[] | undefined, required: boolean, template: ConceptTemplate | undefined): string[] {
  const lines = packages.flatMap((p) => [...p.contract.matchAll(new RegExp(TOFU_CHECK_RE.source, "gm"))].map((m) => ({ pkg: p, test: m[1] as string, rest: m[2] ?? "" })));
  const root = packages.find((p) => p.deps.length === 0);
  if (lines.length === 0) return required ? [`the first phase is the tofu stage (docs/GAME-QUALITY.md section 12): add this line to the contract of the root package${root ? ` "${root.id}"` : ""}, word for word: "${tofuLine(template)}", register that bot in the root package and run it in its acceptance`] : [];
  const out: string[] = [];
  if (lines.length > 1) out.push(`the plan names ${lines.length} TOFU CHECK lines (${lines.map((l) => `${l.pkg.id}: ${l.test}`).join("; ")}): exactly one, in the root package`);
  const l = lines[0] as (typeof lines)[number];
  if (root && l.pkg.id !== root.id) out.push(`the TOFU CHECK line is in package "${l.pkg.id}"; it belongs to the root package "${root.id}" (the core verb exchange)`);
  const missing = tofuMetricsFor(template).map((m) => m.id).filter((id) => !new RegExp(`\\b${id}\\b`).test(l.rest));
  if (missing.length > 0) out.push(`the TOFU CHECK line must name every metric (missing: ${missing.join(", ")}): "${tofuLine(template, l.test)}"`);
  if (!(l.pkg.registers?.tests ?? []).includes(l.test)) out.push(`package "${l.pkg.id}" names the tofu bot ${l.test} but does not register it in registers.tests`);
  if (!l.pkg.acceptance.some((a) => a.verb === "bot" && a.args.includes(`--test=${l.test}`))) out.push(`package "${l.pkg.id}" must run the tofu bot in its acceptance: {"level": "V4", "verb": "bot", "args": ["--test=${l.test}", ...]}`);
  if (l.pkg.milestone !== TOFU_MILESTONE) out.push(`the tofu package "${l.pkg.id}" is milestone "${l.pkg.milestone}"; the tofu stage is flat shapes: milestone "${TOFU_MILESTONE}"`);
  const first = phases?.[0];
  if (first !== undefined) {
    if (!first.packages.includes(l.pkg.id)) out.push(`the tofu package "${l.pkg.id}" must be in the first phase "${first.id}"`);
    for (const id of first.packages) {
      const p = packages.find((x) => x.id === id);
      if (p && p.milestone !== TOFU_MILESTONE) out.push(`package "${id}" is in the tofu phase "${first.id}" but is milestone "${p.milestone}": every package of the first phase is "${TOFU_MILESTONE}"`);
    }
    for (const p of packages) if (p.milestone === TOFU_MILESTONE && !first.packages.includes(p.id)) out.push(`package "${p.id}" is milestone "${TOFU_MILESTONE}" but not in the tofu phase "${first.id}": a later package is greybox or later`);
  }
  return out;
}

export interface TofuRow {
  id: string;
  item: string;
  want: string;
  value?: number;
  ok: boolean;
}
export interface TofuResult {
  ok: boolean;
  rows: TofuRow[];
  hand?: string;
  /** The bot report the metrics were read from (job-relative), absent when none was found. */
  from?: string;
  line: string;
}

/** The metrics of the newest finished report of `test` in the log: {metrics, hand, from}, or {} when none has metrics. */
export function readTofuMetrics(jobDir: string, events: readonly JobEvent[], test: string): { metrics?: Record<string, unknown>; hand?: string; from?: string } {
  for (const e of [...events].reverse()) {
    if (e.type !== "verify" || e.verb !== "bot") continue;
    try {
      const r = JSON.parse(fs.readFileSync(path.join(jobDir, e.report), "utf8")) as { bot?: { test?: unknown; done?: unknown; result?: { metrics?: unknown; hand?: unknown } } };
      if (r.bot?.test !== test || r.bot.done !== true) continue;
      const m = r.bot.result?.metrics;
      const metrics = m !== null && typeof m === "object" && !Array.isArray(m) ? (m as Record<string, unknown>) : undefined;
      const hand = typeof metrics?.["hand"] === "string" ? (metrics["hand"] as string) : typeof r.bot.result?.hand === "string" ? (r.bot.result.hand as string) : undefined;
      return { ...(metrics !== undefined ? { metrics } : {}), ...(hand !== undefined ? { hand } : {}), from: e.report };
    } catch {
      /* an unreadable report is not a measurement */
    }
  }
  return {};
}

/** Judges the metrics: every row present and a finite number inside its bound. */
export function judgeTofu(metrics: Record<string, unknown> | undefined, rows: TofuMetric[], test: string, hand?: string, from?: string): TofuResult {
  const out: TofuRow[] = rows.map((m) => {
    const v = metrics?.[m.id];
    const value = typeof v === "number" && Number.isFinite(v) ? v : undefined;
    const ok = value !== undefined && (m.min === undefined || value >= m.min) && (m.max === undefined || value <= m.max);
    return { id: m.id, item: m.item, want: bound(m), ...(value !== undefined ? { value } : {}), ok };
  });
  const ok = out.every((r) => r.ok);
  const by = hand !== undefined ? ` through the ${hand} hand` : "";
  const bad = out.filter((r) => !r.ok).map((r) => `${r.id} ${r.value === undefined ? "not reported" : r.value} (wants ${r.want}; item ${r.item})`);
  const where = from === undefined ? `no finished report of ${test} was found` : metrics === undefined ? `${test} reported no \`metrics\` object in its result` : "";
  const line = ok
    ? `tofu stage ok (${test}${by}): ${out.map((r) => `${r.id} ${r.value}`).join(", ")}`
    : `TOFU STAGE NOT ok (${test}${by}), the core verb is not proven fun on flat shapes: ${[where, ...bad].filter(Boolean).join("; ")}. Make the root's exchange meet these, counted by the bot from what it played`;
  return { ok, rows: out, ...(hand !== undefined ? { hand } : {}), ...(from !== undefined ? { from } : {}), line };
}
