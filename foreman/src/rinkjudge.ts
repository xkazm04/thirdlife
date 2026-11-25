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
}

export const GOAL_BAND_FILE = path.join(PKG_ROOT, "data", "rink-goal-band.json");

/** The band, or undefined when the file is missing (then no goals verdict is given, and that is said). */
export function goalBand(file = GOAL_BAND_FILE): GoalBand | undefined {
  try {
    const d = JSON.parse(fs.readFileSync(file, "utf8")) as { band: { min: number; max: number }; from: Record<string, unknown>; hand: string; made: string };
    const span = d.band.max - d.band.min;
    const r1 = (x: number): number => Math.round(x * 10) / 10;
    return { min: d.band.min, max: d.band.max, lo: Math.max(0, r1(d.band.min - span / 4)), hi: r1(d.band.max + span / 4), source: `${Object.keys(d.from).length} of thirdjam's cartridges (the regular cut and the modes of MODES.md) played by ${d.hand}, ${d.made} (foreman/data/rink-goal-band.json)` };
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
  for (const [lv, l] of Object.entries(line.levels ?? {})) {
    const p = l.playtester;
    if (p === undefined) continue;
    const goals = Math.round(((p["goals_for"] ?? 0) + (p["goals_against"] ?? 0)) * 10) / 10;
    if (band !== undefined && (goals < band.lo || goals > band.hi)) defects.push(`${goals} goals a match at ${lv} (thirdjam's regular playtester): thirdjam's own cartridges play ${band.min} to ${band.max}, so ${band.lo} to ${band.hi} is the band`);
    const n = p["matches"] ?? 0;
    if (n > 0 && (p["not_over"] ?? 0) > n / 4) defects.push(`${p["not_over"]} of ${n} matches at ${lv} never end (the 10-minute stop): nobody can score`);
  }
  if (band !== undefined && defects.some((d) => d.includes(" goals a match at "))) notes.push(`the goals band: ${band.source}`);
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
