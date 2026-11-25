// The design room and the quality loop on the wire (JOB.md "Added 2026-11-21"): brief.concept, brief.design,
// design_reviewed, plan packages' `serves`, and the milestone's round, kept and strips. The shapes as JSON schemas and
// the checks a schema cannot say (word limits, counts, a defensive verb, ids). Pure: no file, no process, and no
// import from events.ts, which imports this module (as v2.ts).
import { SNAKE_RE, words } from "./v2.js";

/** Word limits (JOB.md 2026-11-21). A design text field is at most `text` words unless named here. */
export const ROOM_LIMITS = {
  pitch: 20,
  why: 40,
  hook: 12,
  anchor: 6,
  borrow: 20,
  text: 30,
  playstyleTitle: 4,
  playstyleLine: 12,
  notes: 80,
  candidates: 5,
  pillars: 3,
  verbsMin: 2,
  verbsMax: 5,
  playstylesMin: 2,
  playstylesMax: 3,
  contextMin: 3,
  ceiling: 3,
  clips: 3,
  refsMin: 2,
  refsMax: 3,
  /** N4 of 22 Nov: the genre template the concept copies its core loop from. */
  reference: 20,
  copy: 20,
  copiesMin: 3,
  copiesMax: 6,
  /** Review rounds: a "revise" at round 1 runs the design step once more; round 2 is final. */
  reviewRounds: 2,
} as const;

export interface ConceptCandidate {
  pitch: string;
  /** The Designer's estimate of how typical the pitch is, 0..1. */
  likelihood: number;
}
/** N4 of 22 Nov (GAME-QUALITY.md section 11): the proven design one core loop copies. `own` names its own reference. */
export const TEMPLATE_IDS = ["duel", "rink_sport", "arcade_sport", "own"] as const;
export type TemplateId = (typeof TEMPLATE_IDS)[number];
export interface ConceptTemplate {
  id: TemplateId;
  /** The real, released games (or the research file) the core loop is copied from, at most 20 words. */
  reference: string;
  /** 3 to 6 lines, each at most 20 words: what is copied (rules, tables, archetypes), never a mood. */
  copies: string[];
}
export interface Concept {
  /** Optional on read (a concept made before 22 Nov has none); the concept step writes it. */
  template?: ConceptTemplate;
  candidates: ConceptCandidate[];
  chosen: number;
  why: string;
  hook: string;
  anchor: string;
  references: { game: string; borrow: string }[];
}
export interface DesignVerb {
  id: string;
  input: string;
  anticipation_f: number;
  active_f: number;
  recovery_f: number;
  cancel: string;
  defensive?: true;
  /** N4 of 22 Nov: the template move this verb copies (GAME-QUALITY.md section 11); its frames are the template's. */
  move?: string;
}
export interface DesignFeel {
  hitstop_f: [number, number];
  knockback: string;
  reaction: string;
  whiff: string;
  iframes_f: number;
  telegraph_f: number;
  shake: string;
  camera: string;
}
export interface DesignDoc {
  pillars: { line: string; rules_out: string }[];
  verbs: DesignVerb[];
  playstyles: { id: string; title: string; line: string }[];
  loops: { s3: string; s30: string; m3: string };
  context: string[];
  skill: { floor: string; ceiling: string[] };
  feel: DesignFeel;
  clips: { id: string; moment: string }[];
  first_minute: string;
  fail_state: string;
  out_of_scope: string[];
}
export const REVIEW_SCORES = ["hook", "gif", "depth", "feel", "fit"] as const;
export type ReviewScore = (typeof REVIEW_SCORES)[number];
export const REVIEW_VERDICTS = ["ok", "revise"] as const;
export type ReviewVerdict = (typeof REVIEW_VERDICTS)[number];
export interface DesignReview {
  round: number;
  verdict: ReviewVerdict;
  scores: Record<ReviewScore, number>;
  notes: string;
}
export const KEPT = ["new", "previous"] as const;
export type Kept = (typeof KEPT)[number];
export interface Strip {
  capture: string;
  label: string;
}

const nonEmpty = { type: "string", minLength: 1 } as const;
const snake = { type: "string", pattern: SNAKE_RE.source } as const;
const unit = { type: "number", minimum: 0, maximum: 1 } as const;
const frames = { type: "integer", minimum: 0, maximum: 600 } as const;
const obj = (required: readonly string[], properties: Record<string, object>): object => ({ type: "object", additionalProperties: false, required, properties });
const list = (items: object, minItems: number, maxItems?: number): object => ({ type: "array", minItems, ...(maxItems !== undefined ? { maxItems } : {}), items });

export const templateSchema = obj(["id", "reference", "copies"], {
  id: { enum: TEMPLATE_IDS },
  reference: nonEmpty,
  copies: list(nonEmpty, ROOM_LIMITS.copiesMin, ROOM_LIMITS.copiesMax),
});

export const conceptSchema = obj(["candidates", "chosen", "why", "hook", "anchor", "references"], {
  template: templateSchema,
  candidates: list(obj(["pitch", "likelihood"], { pitch: nonEmpty, likelihood: unit }), ROOM_LIMITS.candidates, ROOM_LIMITS.candidates),
  chosen: { type: "integer", minimum: 0, maximum: ROOM_LIMITS.candidates - 1 },
  why: nonEmpty,
  hook: nonEmpty,
  anchor: nonEmpty,
  references: list(obj(["game", "borrow"], { game: nonEmpty, borrow: nonEmpty }), ROOM_LIMITS.refsMin, ROOM_LIMITS.refsMax),
});

export const designSchema = obj(["pillars", "verbs", "playstyles", "loops", "context", "skill", "feel", "clips", "first_minute", "fail_state", "out_of_scope"], {
  pillars: list(obj(["line", "rules_out"], { line: nonEmpty, rules_out: nonEmpty }), ROOM_LIMITS.pillars, ROOM_LIMITS.pillars),
  verbs: list(
    obj(["id", "input", "anticipation_f", "active_f", "recovery_f", "cancel"], {
      id: snake, input: nonEmpty, anticipation_f: frames, active_f: frames, recovery_f: frames, cancel: nonEmpty, defensive: { const: true }, move: snake,
    }),
    ROOM_LIMITS.verbsMin,
    ROOM_LIMITS.verbsMax,
  ),
  playstyles: list(obj(["id", "title", "line"], { id: snake, title: nonEmpty, line: nonEmpty }), ROOM_LIMITS.playstylesMin, ROOM_LIMITS.playstylesMax),
  loops: obj(["s3", "s30", "m3"], { s3: nonEmpty, s30: nonEmpty, m3: nonEmpty }),
  context: list(nonEmpty, ROOM_LIMITS.contextMin),
  skill: obj(["floor", "ceiling"], { floor: nonEmpty, ceiling: list(nonEmpty, ROOM_LIMITS.ceiling, ROOM_LIMITS.ceiling) }),
  feel: obj(["hitstop_f", "knockback", "reaction", "whiff", "iframes_f", "telegraph_f", "shake", "camera"], {
    hitstop_f: { type: "array", minItems: 2, maxItems: 2, items: frames },
    knockback: nonEmpty, reaction: nonEmpty, whiff: nonEmpty, iframes_f: frames, telegraph_f: frames, shake: nonEmpty, camera: nonEmpty,
  }),
  clips: list(obj(["id", "moment"], { id: snake, moment: nonEmpty }), ROOM_LIMITS.clips, ROOM_LIMITS.clips),
  first_minute: nonEmpty,
  fail_state: nonEmpty,
  out_of_scope: list(nonEmpty, 0),
});

export const reviewScoresSchema = obj(REVIEW_SCORES, Object.fromEntries(REVIEW_SCORES.map((k) => [k, unit])));

/** The event body of design_reviewed (JOB.md 2026-11-21). */
export const designReviewedSpec = {
  required: { round: { type: "integer", minimum: 1, maximum: ROOM_LIMITS.reviewRounds }, verdict: { enum: REVIEW_VERDICTS }, scores: reviewScoresSchema, notes: { type: "string" } },
};

/** The milestone keys of the quality loop. `round` is 1 or 2, and 3 and up after `foreman quality <job> retry`. */
export const milestoneRoomSpec = {
  round: { type: "integer", minimum: 1 },
  kept: { enum: KEPT },
  strips: { type: "array", items: obj(["capture", "label"], { capture: nonEmpty, label: { type: "string" } }) },
};

const over = (where: string, text: string, max: number): string[] => (words(text) > max ? [`${where} has ${words(text)} words; at most ${max}: "${text.length > 80 ? `${text.slice(0, 80)}...` : text}"`] : []);

/** Problems of a concept beyond its JSON shape: word limits. */
export function conceptProblems(c: Concept): string[] {
  const out: string[] = [];
  c.candidates.forEach((x, i) => out.push(...over(`concept candidate ${i} pitch`, x.pitch, ROOM_LIMITS.pitch)));
  out.push(...over("concept why", c.why, ROOM_LIMITS.why), ...over("concept hook", c.hook, ROOM_LIMITS.hook), ...over("concept anchor", c.anchor, ROOM_LIMITS.anchor));
  c.references.forEach((r, i) => out.push(...over(`concept reference ${i} (${r.game}) borrow`, r.borrow, ROOM_LIMITS.borrow)));
  if (c.template !== undefined) {
    out.push(...over("concept template reference", c.template.reference, ROOM_LIMITS.reference));
    c.template.copies.forEach((x, i) => out.push(...over(`concept template copies ${i}`, x, ROOM_LIMITS.copy)));
  }
  return out;
}

/**
 * Problems of a design doc that the reader enforces (counts and ids): at least one defensive verb, unique verb,
 * playstyle and clip ids, hit-stop min <= max. `wordLimits` adds the word limits the writer enforces.
 */
export function designProblems(d: DesignDoc, wordLimits = false): string[] {
  const out: string[] = [];
  const unique = (what: string, ids: string[]): void => {
    const seen = new Set<string>();
    for (const id of ids) {
      if (seen.has(id)) out.push(`design ${what} id "${id}" is used twice`);
      seen.add(id);
    }
  };
  unique("verb", d.verbs.map((v) => v.id));
  unique("playstyle", d.playstyles.map((p) => p.id));
  unique("clip", d.clips.map((c) => c.id));
  if (!d.verbs.some((v) => v.defensive === true)) out.push('design verbs: at least one verb is defensive (a block, a dodge, a roll, a parry), marked "defensive": true');
  const [lo, hi] = d.feel.hitstop_f;
  if (lo > hi) out.push(`design feel hitstop_f is [${lo}, ${hi}]: [min, max] with min <= max`);
  if (!wordLimits) return out;
  const T = ROOM_LIMITS.text;
  d.pillars.forEach((p, i) => out.push(...over(`design pillar ${i} line`, p.line, T), ...over(`design pillar ${i} rules_out`, p.rules_out, T)));
  for (const v of d.verbs) out.push(...over(`design verb "${v.id}" input`, v.input, T), ...over(`design verb "${v.id}" cancel`, v.cancel, T));
  for (const p of d.playstyles) out.push(...over(`design playstyle "${p.id}" title`, p.title, ROOM_LIMITS.playstyleTitle), ...over(`design playstyle "${p.id}" line`, p.line, ROOM_LIMITS.playstyleLine));
  for (const k of ["s3", "s30", "m3"] as const) out.push(...over(`design loops ${k}`, d.loops[k], T));
  d.context.forEach((c, i) => out.push(...over(`design context ${i}`, c, T)));
  out.push(...over("design skill floor", d.skill.floor, T));
  d.skill.ceiling.forEach((c, i) => out.push(...over(`design skill ceiling ${i}`, c, T)));
  for (const k of ["knockback", "reaction", "whiff", "shake", "camera"] as const) out.push(...over(`design feel ${k}`, d.feel[k], T));
  for (const c of d.clips) out.push(...over(`design clip "${c.id}" moment`, c.moment, T));
  out.push(...over("design first_minute", d.first_minute, T), ...over("design fail_state", d.fail_state, T));
  d.out_of_scope.forEach((c, i) => out.push(...over(`design out_of_scope ${i}`, c, T)));
  return out;
}

/** Problems of a review beyond its shape: the notes' word limit. */
export function reviewProblems(r: Pick<DesignReview, "notes">): string[] {
  return over("review notes", r.notes, ROOM_LIMITS.notes);
}

/** JOB.md 2026-11-21: a package's `serves` names clip ids of the brief's design (unique per package). */
export function servesProblems(packages: { id: string; serves?: string[] }[], clipIds: string[] | undefined): string[] {
  const out: string[] = [];
  for (const p of packages) {
    if (p.serves === undefined) continue;
    if (new Set(p.serves).size !== p.serves.length) out.push(`package "${p.id}": serves names a clip twice`);
    if (clipIds === undefined) continue;
    for (const c of p.serves) if (!clipIds.includes(c)) out.push(`package "${p.id}": serves "${c}", which is not a clip id of the brief's design (${clipIds.join(", ") || "none"})`);
  }
  return out;
}
