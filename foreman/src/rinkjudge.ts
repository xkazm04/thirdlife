// E3d of 25 Nov: what the Foreman decides from a rink game's measured check, and from a person's change, before it acts.
// Lane E5's real proof shipped job 1 with about 33 goals a match (hokej plays 2 to 5): lane E2's check said "a goal flood"
// as a warning, and nothing acts on a warning. Lane K8's CHECK-CARTRIDGE-NOTE.md names the GROSS defects a check may fail
// a cartridge for (16 seeds see nothing finer); everything else stays words. And "the orange team is too strong" went
// through on a game whose teams are red and blue: a change that names what the game does not have is asked back.
// Pure apart from reading foreman/data/rink-goal-band.json.
import fs from "node:fs";
import path from "node:path";
import { PKG_ROOT } from "./paths.js";

/** The levels of a tl.rink.check/1 line (lane E2), and K8's two coarse cells under `defects` (`--defects`). */
export interface RinkCheckFacts {
  levels?: Record<string, { playtester?: Record<string, number>; plan?: Record<string, number> }>;
  defects?: { idle?: { matches: number; wins: number; not_over?: number }; skate_only?: { matches: number; wins: number; not_over?: number; clone_checked?: number; clone_mismatch?: number } };
  warnings?: string[];
  /** H1c: each toy's worth (check_cartridge.mjs --toys): the hand with and without it, paired by seed. */
  toys?: ToyFigure[];
}

export interface ToyFigure {
  toy: string;
  measured: boolean;
  matches?: number;
  wins_with?: number;
  wins_without?: number;
  points?: number;
  goal_diff?: number;
  changed?: number;
  /** H1e: the paired matches won only with the toy, and only without it. */
  won_only_with?: number;
  won_only_without?: number;
  /** H1e: what the paired matches say (check_cartridge.mjs toyClear, the same rule as toyClear below). */
  clear?: "nothing" | "little" | "helps" | "costs" | "not_clear";
  why?: string;
}

/**
 * H1e (lane G1's round 3, PROOF-G1.md section 14: at the check's 20 seeds three toys of four read the other way round
 * from 80 seeds: pickups -15 against -6, the pads -10 against +1, the pools -10 against +10): what the paired matches say.
 * "nothing" when no match plays differently; "helps" / "costs" when a two-sided sign test over the matches won only with
 * the toy and only without it gives p < 0.1; "little" when the win difference stays within 10 points even at the far end
 * of a 95 % margin; else "not_clear". Never a confident word from noise.
 */
export function toyClear(n: number, changed: number, onlyWith: number, onlyWithout: number, points: number): NonNullable<ToyFigure["clear"]> {
  if (changed === 0) return "nothing";
  const d = onlyWith + onlyWithout;
  const k = Math.min(onlyWith, onlyWithout);
  let tail = 0;
  for (let i = 0; i <= k; i++) {
    let c = 1;
    for (let j = 0; j < i; j++) c = (c * (d - j)) / (j + 1);
    tail += c;
  }
  const p = d === 0 ? 1 : Math.min(1, (2 * tail) / 2 ** d);
  if (p < 0.1) return onlyWith > onlyWithout ? "helps" : "costs";
  const margin = (100 * 1.96 * Math.sqrt(d)) / n;
  return Math.abs(points) + margin <= 10 ? "little" : "not_clear";
}

/**
 * H1c: the toys a person should hear about at the pause, in a person's words. H1e: only what the paired matches show;
 * a toy whose figures could be noise is "not clear yet", with the two counts. A toy that helps gets no line.
 */
export function toyLines(toys: ToyFigure[] | undefined): string[] {
  // the card's words: the toy without its kinds in brackets (the check's warning keeps them), at most about 60 characters
  const up = (s: string): string => { const t = s.replace(/ \([^)]*\)$/, ""); return t.charAt(0).toUpperCase() + t.slice(1); };
  const out: string[] = [];
  for (const t of toys ?? []) {
    if (!t.measured) {
      out.push(`${up(t.toy)}: not measured${t.why !== undefined ? `: ${t.why.slice(0, 120)}` : ""}`);
      continue;
    }
    const n = t.matches ?? 0;
    const clear = t.clear ?? (t.won_only_with !== undefined && t.won_only_without !== undefined ? toyClear(n, t.changed ?? 1, t.won_only_with, t.won_only_without, t.points ?? 0) : t.changed === 0 ? "nothing" : "not_clear");
    const pair = `won only with it ${t.won_only_with ?? "?"}, only without it ${t.won_only_without ?? "?"}, of ${n}`;
    if (clear === "nothing") out.push(`${up(t.toy)}: changes nothing (${t.wins_with} of ${n} wins with and without)`);
    else if (clear === "little") out.push(`${up(t.toy)}: changes little (${t.wins_with} of ${n} wins with, ${t.wins_without} without)`);
    // the Director's H1c decision: a toy that costs the player is said in words here, never a check warning
    else if (clear === "costs") out.push(`${up(t.toy)}: costs you (${pair})`);
    else if (clear === "not_clear") out.push(`${up(t.toy)}: not clear yet (${pair})`);
  }
  return out;
}

/** The goals-a-match band, derived from thirdjam's own cartridges (foreman/scripts/rink-goal-band.mjs). */
export interface GoalBand {
  /** The lowest and highest goals a match any shipped cartridge played at any level. */
  min: number;
  max: number;
  /** What a cartridge may play before it is a gross defect: a quarter of the span past either end (lane E2's words rule). */
  lo: number;
  hi: number;
  source: string;
  /** E3f: goals a minute and a match's minutes, from the same cartridges and levels, with the same quarter-span rule. */
  rate?: Span;
  minutes?: Span;
}

/** A derived figure's range over thirdjam's cartridges, and what a cartridge may play before it is a gross defect. */
export interface Span {
  min: number;
  max: number;
  lo: number;
  hi: number;
}

export const GOAL_BAND_FILE = path.join(PKG_ROOT, "data", "rink-goal-band.json");

/** The band, or undefined when the file is missing (then no goals verdict is given, and that is said). */
export function goalBand(file = GOAL_BAND_FILE): GoalBand | undefined {
  try {
    const d = JSON.parse(fs.readFileSync(file, "utf8")) as { band: { min: number; max: number }; from: Record<string, unknown>; hand: string; made: string; rate?: { min: number; max: number }; minutes?: { min: number; max: number } };
    const r1 = (x: number): number => Math.round(x * 10) / 10;
    const span = (b: { min: number; max: number }): Span => ({ min: b.min, max: b.max, lo: Math.max(0, r1(b.min - (b.max - b.min) / 4)), hi: r1(b.max + (b.max - b.min) / 4) });
    const g = span(d.band);
    return { ...g, ...(d.rate !== undefined ? { rate: span(d.rate) } : {}), ...(d.minutes !== undefined ? { minutes: span(d.minutes) } : {}), source: `${Object.keys(d.from).length} of thirdjam's cartridges (the regular cut and the modes of MODES.md) played by ${d.hand}, ${d.made} (foreman/data/rink-goal-band.json)` };
  } catch {
    return undefined;
  }
}

/** Words of a person's change that ask for speed: then a speed beyond thirdjam's range is the person's wish, not a warning. */
export const SPEED_WORDS = /\b(fast|faster|fastest|quick|quicker|speed|speedy|slow|slower|zippy|rocket)\b/i;

/**
 * The gross defects of a check (K8's table): goals a match outside the band at any level; more than a quarter of a level's
 * matches that never end; the idle hand winning half or more at pro; skating alone winning a third or more at pro (only
 * when the planning hand's copies of the sim were exact: clone_mismatch 0, else the hand is NOT VALID and that is said).
 * `notes` are words beside them: an unmeasured defect, and the speed warnings marked as asked for when `asked` asks.
 */
export function grossDefects(line: RinkCheckFacts, asked?: string, band: GoalBand | undefined = goalBand()): { defects: string[]; notes: string[] } {
  const defects: string[] = [];
  const notes: string[] = [];
  const short: string[] = [];
  for (const [lv, l] of Object.entries(line.levels ?? {})) {
    const p = l.playtester;
    if (p === undefined) continue;
    const goals = Math.round(((p["goals_for"] ?? 0) + (p["goals_against"] ?? 0)) * 10) / 10;
    if (band !== undefined && (goals < band.lo || goals > band.hi)) defects.push(`${goals} goals a match at ${lv} (thirdjam's regular playtester): thirdjam's own cartridges play ${band.min} to ${band.max}, so ${band.lo} to ${band.hi} is the band`);
    // E3f (E5b: job 1 was first to 5 in 1.2 min, 6.3 goals a minute; "ok" with a warning): goals a MINUTE against what
    // thirdjam's modes play (sudden death's one goal in half a minute included), and a match longer than any of them.
    const mins = p["minutes"];
    if (band?.rate !== undefined && mins !== undefined && mins > 0) {
      const rate = Math.round((goals / mins) * 100) / 100;
      if (rate < band.rate.lo || rate > band.rate.hi) defects.push(`${rate} goals a minute at ${lv} (${goals} goals in ${mins} min, thirdjam's regular playtester): thirdjam's own cartridges score ${band.rate.min} to ${band.rate.max} a minute (sudden death included), so ${band.rate.lo} to ${band.rate.hi} is the band: the match is over before a person has played it`);
    }
    if (band?.minutes !== undefined && mins !== undefined && mins > band.minutes.hi) defects.push(`a match lasts ${mins} min at ${lv}: thirdjam's own cartridges last ${band.minutes.min} to ${band.minutes.max}, so ${band.minutes.hi} is the most`);
    else if (band?.minutes !== undefined && mins !== undefined && mins < band.minutes.min) short.push(`${mins} min at ${lv}`);
    const n = p["matches"] ?? 0;
    if (n > 0 && (p["not_over"] ?? 0) > n / 4) defects.push(`${p["not_over"]} of ${n} matches at ${lv} never end (the 10-minute stop): nobody can score`);
  }
  if (band !== undefined && defects.some((d) => d.includes(" goals a match at ") || d.includes(" goals a minute at ") || d.startsWith("a match lasts "))) notes.push(`the goals band: ${band.source}`);
  // Shorter than any of thirdjam's modes but scoring at a rate they play: not a defect by the data, said in words.
  if (short.length > 0 && band?.minutes !== undefined) notes.push(`matches shorter than any of thirdjam's modes (${short.join(", ")}; the shortest, sudden death, lasts ${band.minutes.min} min or more), at a goal rate thirdjam's modes play: words, not a defect`);
  if (band === undefined) notes.push("goals a match not judged: foreman/data/rink-goal-band.json is missing (node foreman/scripts/rink-goal-band.mjs)");
  const idle = line.defects?.idle;
  if (idle !== undefined && idle.matches > 0 && idle.wins / idle.matches >= 0.5) defects.push(`the idle hand (nothing pressed) wins ${idle.wins} of ${idle.matches} at pro: the game is won without the player`);
  const skate = line.defects?.skate_only;
  if (skate !== undefined && (skate.clone_mismatch ?? 0) > 0) notes.push(`planning hand NOT VALID for this cartridge (${skate.clone_mismatch} of ${skate.clone_checked ?? "?"} frames of its sim copies differ): the skating-only cell is not judged`);
  else if (skate !== undefined && skate.matches > 0 && skate.wins / skate.matches >= 1 / 3) defects.push(`skating alone (no shot, pass or check) wins ${skate.wins} of ${skate.matches} at pro: the game is won without its verbs`);
  if (line.defects === undefined) notes.push("the idle and skating-only hands were not played (no --defects cells in the line)");
  for (const w of line.warnings ?? []) if (/speed/i.test(w) && asked !== undefined && SPEED_WORDS.test(asked)) notes.push(`${w} (asked for by the person: "${asked}")`);
  return { defects, notes };
}

// ---------- a person's change against what the game has ----------

const COLOURS: [string, [number, number, number]][] = [
  ["red", [216, 58, 52]], ["orange", [255, 140, 40]], ["yellow", [240, 210, 40]], ["gold", [212, 175, 55]], ["green", [60, 170, 80]],
  ["teal", [0, 128, 128]], ["blue", [47, 107, 222]], ["purple", [130, 60, 170]], ["pink", [240, 110, 170]], ["white", [240, 240, 240]],
  ["black", [25, 25, 25]], ["grey", [128, 128, 128]], ["brown", [130, 80, 40]],
];
const COLOUR_WORDS = new Map<string, string>([...COLOURS.map(([n]) => [n, n] as [string, string]), ["gray", "grey"], ["violet", "purple"], ["cyan", "teal"]]);

/** The nearest colour word to a #RRGGBB hex (undefined for anything else). */
export function colourName(hex: string | undefined): string | undefined {
  const m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex ?? "");
  if (!m) return undefined;
  const c = [1, 2, 3].map((i) => parseInt(m[i] as string, 16));
  let best: [string, number] = ["", Infinity];
  for (const [n, rgb] of COLOURS) {
    const d = rgb.reduce((s, x, i) => s + (x - (c[i] as number)) ** 2, 0);
    if (d < best[1]) best = [n, d];
  }
  return best[0];
}

/** A team as the person meets it: its name in the skin, its colour on the ice (the cartridge's colour_hex), its side. */
export interface TeamSeen {
  name?: string;
  colour?: string;
  side: "yours" | "the bots'";
}

/** The teams of a game as the person sees them (skin team_names, cartridge game.teams[].colour_hex; team 0 is the person's). */
export function teamsSeen(skin: unknown, cartridge: unknown): TeamSeen[] {
  const names = ((skin as { team_names?: unknown } | undefined)?.team_names ?? []) as unknown[];
  const teams = (((cartridge as { game?: { teams?: unknown } } | undefined)?.game?.teams ?? []) as { colour_hex?: string }[]);
  const n = Math.max(names.length, teams.length);
  return Array.from({ length: n }, (_, i) => ({ ...(typeof names[i] === "string" ? { name: names[i] as string } : {}), ...(colourName(teams[i]?.colour_hex) !== undefined ? { colour: colourName(teams[i]?.colour_hex) as string } : {}), side: i === 0 ? ("yours" as const) : ("the bots'" as const) }));
}

const says = (t: TeamSeen): string => `${t.colour ?? "?"}${t.name !== undefined ? ` (${t.name})` : ""}`;

/**
 * The question a change must be asked back with, when its words name a team the game does not have ("the orange team"
 * when the teams are red and blue), or undefined. Teams are what the person sees: the skin's names and the colours on the
 * ice, never the cartridge's ids (job 1's ids were "blue" and "orange" on red and blue teams).
 */
export function absentInChange(text: string, skin: unknown, cartridge: unknown): string | undefined {
  const teams = teamsSeen(skin, cartridge);
  if (teams.length === 0) return undefined;
  const lower = text.toLowerCase();
  const named = new Set(teams.flatMap((t) => [t.colour, ...(t.name ?? "").toLowerCase().split(/\s+/)].filter((x): x is string => x !== undefined && x !== "")));
  for (const m of lower.matchAll(/\b([a-z]+)\s+(?:team|side|skaters|players|bots|guys|ones)\b/g)) {
    const w = COLOUR_WORDS.get(m[1] as string);
    if (w === undefined || named.has(w)) continue;
    const mine = teams[0] as TeamSeen;
    const bots = teams[1];
    const guess = /\b(strong|good|hard|fast|tough|win|wins|better)\b/.test(lower) ? bots : undefined;
    return `There is no ${w} team in this game: your side is ${says(mine)}${bots !== undefined ? `, the bots are ${says(bots)}` : ""}. ${guess !== undefined ? `Did you mean the ${guess.colour ?? "other"} team, the bots?` : "Which team did you mean?"} Say it again with the team's colour or name, and the change is made.`;
  }
  return undefined;
}

// ---------- E3f: a change a person would not see ----------

/** Words that ask for an easier game (the bots too strong) and for a harder one (too easy). */
export const EASIER_WORDS = /\b(too (?:strong|good|hard|tough|fast for me)|can'?t (?:win|score|beat)|easier|weaker)\b/i;
export const HARDER_WORDS = /\b(too (?:easy|weak|slow for me)|harder|no challenge|stronger bots)\b/i;

/**
 * E3f (E5b job 1: "the orange team is too strong" while the player's side won 10 of 10 at pro went through as a diff no
 * person could feel): a change asking for an easier game when the measured hand on the person's seat already wins 9 in
 * 10 or more at every level (or a harder one when it wins 1 in 10 or fewer) is answered with the figures, as a question,
 * before anything is changed. Undefined when the words ask neither or the figures do not say so.
 */
export function unseenChange(text: string, figures: Record<string, number>): string | undefined {
  const levels = Object.entries(figures).flatMap(([k, v]) => {
    const m = /^(rookie|pro|all_star)_wins_of_(\d+)$/.exec(k);
    return m ? [{ level: (m[1] as string).replace("_", " "), wins: v, of: Number(m[2]) }] : [];
  });
  if (levels.length === 0) return undefined;
  const said = levels.map((l) => `${l.wins} of ${l.of} at ${l.level}`).join(", ");
  const by = "thirdjam's regular playtester on your seat";
  if (EASIER_WORDS.test(text) && !HARDER_WORDS.test(text) && levels.every((l) => l.of > 0 && l.wins / l.of >= 0.9)) return `Your side already wins ${said} (${by}), so weaker bots would hardly show. Did you mean something else that feels too strong (their speed, their checks, a bigger rink), or should the bots be weaker still? Say which, and the change is made.`;
  if (HARDER_WORDS.test(text) && !EASIER_WORDS.test(text) && levels.every((l) => l.of > 0 && l.wins / l.of <= 0.1)) return `Your side already loses almost every match: it wins ${said} (${by}), so stronger bots would hardly show. Did you mean something else, or should they be stronger still? Say which, and the change is made.`;
  return undefined;
}

const NUMBER_WORDS: Record<string, number> = { one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10, twelve: 12, fifteen: 15, twenty: 20 };
const num = (w: string): number => NUMBER_WORDS[w.toLowerCase()] ?? Number(w);

/**
 * H1d (lane G1's change 1: "so a match lasts about three minutes" became 2.1 min at pro and the check said "measured, no
 * warning"): a figure the person's words name that the check measures (a match's minutes, goals a match), against the
 * figure after the change (thirdjam's regular playtester at pro). Words when it is missed by more than a quarter;
 * undefined when the words name no such figure or it was met.
 */
export function askedFigureMiss(text: string, after: Record<string, number>): string | undefined {
  const out: string[] = [];
  const mins = [...text.matchAll(/\b(\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|twelve|fifteen|twenty)[- ]?(?:minutes?|mins?)\b/gi)].at(-1);
  const m = after["pro_minutes"];
  if (mins !== undefined && typeof m === "number") {
    const want = num(mins[1] as string);
    if (Number.isFinite(want) && want > 0 && Math.abs(m - want) > want * 0.25) out.push(`you asked for matches of about ${want} minute${want === 1 ? "" : "s"}; they last ${m} min at pro now`);
  }
  const goals = [...text.matchAll(/\b(\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|twelve|fifteen|twenty)\s+goals?\s+(?:a|per|in a)\s+(?:match|game)\b/gi)].at(-1);
  const g = after["pro_goals_a_match"];
  if (goals !== undefined && typeof g === "number") {
    const want = num(goals[1] as string);
    if (Number.isFinite(want) && want > 0 && Math.abs(g - want) > want * 0.25) out.push(`you asked for about ${want} goals a match; there are ${g} at pro now`);
  }
  return out.length > 0 ? `${out.join("; ")} (thirdjam's regular playtester, measured after the change): the change falls short of what you asked` : undefined;
}
