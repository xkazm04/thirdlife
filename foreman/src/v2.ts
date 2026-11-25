// The designer v2 wire (JOB.md "Added 2026-11-20"): pitch, aspects, creativity, phases. The shapes and the checks
// that a JSON schema cannot say (word limits, unique ids, a partition of packages). Pure: no file, no process, and no
// import from events.ts, which imports this module.

/** JOB.md 2026-11-20: the fixed icon set of an aspect card. */
export const ASPECT_ICONS = ["player", "rival", "arena", "goal", "twist", "camera", "power", "time", "crowd", "ball", "vehicle", "weapon", "build", "music", "story"] as const;
export type AspectIcon = (typeof ASPECT_ICONS)[number];
export const CREATIVITY = ["crazy"] as const;
export type Creativity = (typeof CREATIVITY)[number];
export const VERDICTS = ["pass", "hold"] as const;
export type PhaseVerdict = (typeof VERDICTS)[number];
/** The two choices every aspect offers besides its alternatives. An alternative id may not be one of them. */
export const FIXED_CHOICES = ["keep", "drop"] as const;

/** Word limits (JOB.md 2026-11-20). */
export const LIMITS = {
  pitch: 20,
  title: 4,
  line: 12,
  detail: 60,
  try: 12,
  aspectsMin: 3,
  aspectsMax: 7,
  altsMin: 2,
  altsMax: 3,
  phasesMin: 2,
  phasesMax: 5,
  crazyMin: 1,
  crazyMax: 2,
} as const;

export const SNAKE_RE = /^[a-z][a-z0-9_]*$/;

export interface AspectAlternative {
  id: string;
  title: string;
  line: string;
  /**
   * H1i (the Director, after lane G5: a ball chosen "Never Held" was still held to the hockey card's possession bound): the
   * plan's tofu rows this choice makes meaningless (metric ids, tofu.ts), written by the Designer. The Foreman lifts them
   * when the person picks this alternative. Absent otherwise (never []).
   */
  lifts?: string[];
}
export interface Aspect {
  id: string;
  icon: AspectIcon;
  title: string;
  line: string;
  detail: string;
  alternatives: AspectAlternative[];
  /** Only on an aspect crazy mode added; absent otherwise (never false). */
  crazy?: true;
  /**
   * H1d (the Director's choice (b), JOB.md at landing): this card as written needs new engine code (a core patch); absent
   * otherwise. Then `hours` says about how many more hours of work, and one alternative does it with data only.
   */
  needs?: "core";
  hours?: number;
}
export interface Phase {
  id: string;
  title: string;
  /** What the player can do when this phase is done (at most 12 words). */
  try: string;
  packages: string[];
}

/** Words as a person counts them: runs of non-space characters. */
export function words(text: string): number {
  return text.trim().split(/\s+/).filter((w) => w.length > 0).length;
}

const nonEmpty = { type: "string", minLength: 1 } as const;
const snake = { type: "string", pattern: SNAKE_RE.source } as const;

export const alternativeSchema = {
  type: "object",
  additionalProperties: false,
  required: ["id", "title", "line"],
  properties: { id: snake, title: nonEmpty, line: nonEmpty, lifts: { type: "array", minItems: 1, uniqueItems: true, items: snake } },
} as const;

export const aspectSchema = {
  type: "object",
  additionalProperties: false,
  required: ["id", "icon", "title", "line", "detail", "alternatives"],
  properties: {
    id: snake,
    icon: { enum: ASPECT_ICONS },
    title: nonEmpty,
    line: nonEmpty,
    detail: nonEmpty,
    alternatives: { type: "array", minItems: LIMITS.altsMin, maxItems: LIMITS.altsMax, items: alternativeSchema },
    crazy: { const: true },
    needs: { const: "core" },
    hours: { type: "integer", minimum: 1 },
  },
} as const;

export const aspectsSchema = { type: "array", minItems: LIMITS.aspectsMin, maxItems: LIMITS.aspectsMax, items: aspectSchema } as const;

export const phaseSchema = {
  type: "object",
  additionalProperties: false,
  required: ["id", "title", "try", "packages"],
  properties: {
    id: snake,
    title: nonEmpty,
    try: nonEmpty,
    packages: { type: "array", minItems: 1, items: snake },
  },
} as const;

export const phasesSchema = { type: "array", minItems: LIMITS.phasesMin, maxItems: LIMITS.phasesMax, items: phaseSchema } as const;

const over = (where: string, text: string, max: number): string[] => (words(text) > max ? [`${where} has ${words(text)} words; at most ${max}: "${text.length > 80 ? `${text.slice(0, 80)}...` : text}"`] : []);

/** Problems of a pitch and an aspect list beyond the JSON shape: word limits and unique ids. */
export function aspectProblems(pitch: string | undefined, aspects: Aspect[] | undefined): string[] {
  const out: string[] = [];
  if (pitch !== undefined) out.push(...over("pitch", pitch, LIMITS.pitch));
  const ids = new Set<string>();
  for (const a of aspects ?? []) {
    const w = `aspect "${a.id}"`;
    if (ids.has(a.id)) out.push(`${w}: the id is used twice in the brief`);
    ids.add(a.id);
    out.push(...over(`${w} title`, a.title, LIMITS.title), ...over(`${w} line`, a.line, LIMITS.line), ...over(`${w} detail`, a.detail, LIMITS.detail));
    // H1d: a card that needs engine code says how many hours; hours alone mean nothing
    if (a.needs === "core" && a.hours === undefined) out.push(`${w}: needs "core" without "hours": say about how many more hours the engine code takes`);
    if (a.needs === undefined && a.hours !== undefined) out.push(`${w}: "hours" without needs "core": hours are only for a card that needs new engine code`);
    const alt = new Set<string>();
    for (const x of a.alternatives) {
      const wx = `${w} alternative "${x.id}"`;
      if (alt.has(x.id)) out.push(`${wx}: the id is used twice in this aspect`);
      alt.add(x.id);
      if ((FIXED_CHOICES as readonly string[]).includes(x.id)) out.push(`${wx}: "keep" and "drop" are the player's fixed choices; name the alternative after what it is`);
      out.push(...over(`${wx} title`, x.title, LIMITS.title), ...over(`${wx} line`, x.line, LIMITS.line));
    }
  }
  return out;
}

/** How many aspects of a brief crazy mode added. */
export const crazyCount = (aspects: Aspect[] | undefined): number => (aspects ?? []).filter((a) => a.crazy === true).length;

/**
 * The crazy rule of a brief (JOB.md 2026-11-20): a standard job has no crazy aspect; a crazy job has at most two.
 * `first`: the first brief of a crazy job must have at least one (a redesign may have none, when the player dropped them).
 */
export function crazyProblems(aspects: Aspect[] | undefined, creativity: Creativity | undefined, first: boolean): string[] {
  const n = crazyCount(aspects);
  if (creativity !== "crazy") return n > 0 ? [`${n} aspect(s) carry "crazy": true, but this job is standard (crazy is only for aspects crazy mode added)`] : [];
  if (n > LIMITS.crazyMax) return [`${n} aspects carry "crazy": true; crazy mode adds one or two`];
  if (first && n < LIMITS.crazyMin) return [`this job is crazy: add one or two unexpected mechanics on top of the player's words, each its own aspect with "crazy": true`];
  return [];
}

/** Is `choice` a valid reaction to `aspect`: keep, drop or one of its alternative ids. */
export function choiceProblem(aspect: Aspect, choice: string): string | undefined {
  if ((FIXED_CHOICES as readonly string[]).includes(choice)) return undefined;
  if (aspect.alternatives.some((x) => x.id === choice)) return undefined;
  return `choice "${choice}" is not one of aspect "${aspect.id}": keep, drop, ${aspect.alternatives.map((x) => x.id).join(", ")}`;
}

/**
 * Problems of a plan's phases against its packages (JOB.md 2026-11-20): unique ids, the try line's word limit, every
 * package in exactly one phase, and a package's deps in its own phase or an earlier one.
 */
export function phaseProblems(phases: Phase[], packages: { id: string; deps: string[] }[]): string[] {
  const out: string[] = [];
  const ids = new Set<string>();
  const phaseOf = new Map<string, number>();
  phases.forEach((ph, i) => {
    if (ids.has(ph.id)) out.push(`phase id "${ph.id}" is used twice`);
    ids.add(ph.id);
    out.push(...over(`phase "${ph.id}" try`, ph.try, LIMITS.try));
    for (const p of ph.packages) {
      if (phaseOf.has(p)) out.push(`package "${p}" is in phase "${phases[phaseOf.get(p) as number]?.id ?? "?"}" and in phase "${ph.id}"; every package is in exactly one phase`);
      else phaseOf.set(p, i);
    }
  });
  const known = new Set(packages.map((p) => p.id));
  for (const p of phaseOf.keys()) if (!known.has(p)) out.push(`a phase names package "${p}", which is not in the plan`);
  for (const p of packages) {
    const at = phaseOf.get(p.id);
    if (at === undefined) {
      out.push(`package "${p.id}" is in no phase; every package is in exactly one phase`);
      continue;
    }
    for (const d of p.deps) {
      const dat = phaseOf.get(d);
      if (dat !== undefined && dat > at) out.push(`package "${p.id}" (phase "${phases[at]?.id ?? "?"}") depends on "${d}", which is in the later phase "${phases[dat]?.id ?? "?"}"; a dependency is built in the same phase or an earlier one`);
    }
  }
  return out;
}
