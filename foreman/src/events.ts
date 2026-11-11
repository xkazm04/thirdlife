// Job events (tl.job/1), exactly as contracts/JOB.md lists them.
// Strict by construction: an unknown `type`, an unknown key or a missing required key is an error.
import { Ajv2020 } from "ajv/dist/2020.js";
import type { ValidateFunction } from "ajv";

export const PACKAGE_STATES = ["queued", "running", "blocked", "verifying", "promoted", "failed"] as const;
export type PackageState = (typeof PACKAGE_STATES)[number];
export const MILESTONES = ["blockout", "greybox", "art_pass", "tuned"] as const;
export type Milestone = (typeof MILESTONES)[number];
export const LEVELS = ["V0", "V1", "V2", "V3", "V4", "V5", "V6"] as const;
export type Level = (typeof LEVELS)[number];
export const CAUSES = [
  "verify_failed",
  "builder_error",
  "builder_timeout",
  "builder_truncated",
  "budget",
  "dependency",
  "question",
  "cancelled",
  "no_visible_change",
  "kit_regression",
  /** N3b: a verification was inconclusive because the machine was busy (the engine's reference pack broke its clock too). */
  "machine_busy",
] as const;
export type Cause = (typeof CAUSES)[number];
export const ADAPTERS = ["claude-cli", "messages-api", "fake"] as const;
export type AdapterName = (typeof ADAPTERS)[number];
export const MODES = ["generate", "readonly-scan", "edit"] as const;
export type BuilderMode = (typeof MODES)[number];
export const OUTCOMES = ["ok", "timeout", "truncated", "error", "refused"] as const;
export type BuilderOutcome = (typeof OUTCOMES)[number];
export const VERBS = ["lint", "smoke", "invariants", "bot", "capture"] as const;
export type Verb = (typeof VERBS)[number];
export const JOB_STATES = ["running", "paused", "done", "failed", "cancelled"] as const;
export type JobRunState = (typeof JOB_STATES)[number];
export const BUDGET_KINDS = ["tokens_per_hour", "only_while_playing", "overnight"] as const;
export type BudgetKind = (typeof BUDGET_KINDS)[number];

export const BILLING_MODES = ["subscription", "api_key", "none"] as const;
export type BillingMode = (typeof BILLING_MODES)[number];

export const PACKAGE_ID_RE = /^[a-z][a-z0-9_]*$/;
export const PACK_ID_RE = /^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/;

export interface Brief {
  rules: string;
  arena: string;
  ai: string;
  controls: string;
  mood: string;
}
export interface Estimate {
  packages: number;
  wallMinutes: number;
  tokens: number;
}
export interface Acceptance {
  level: Level;
  verb: Verb;
  /** Runner options without the leading dashes handled for you: e.g. ["--seed=1", "--frames=600"]. */
  args: string[];
}
/** What a package adds to the composed manifest (pack.json is written by the Foreman, never by a builder). */
export interface Registers {
  capabilities?: string[];
  /** Asset generators under gen/. */
  assets?: string[];
  /** Bot scripts under tests/. */
  tests?: string[];
  /** Named capture views. */
  cameras?: string[];
}
export const CAPABILITIES = ["physics", "input", "ui", "audio", "vfx", "camera", "rules", "ai", "spawn", "fracture", "vehicle", "biped", "ball", "kit", "style"] as const;
export interface PackageSpec {
  id: string;
  title: string;
  milestone: Milestone;
  deps: string[];
  scope: string[];
  contract: string;
  acceptance: Acceptance[];
  registers?: Registers;
}
export interface BudgetPolicy {
  kind: BudgetKind;
  /** tokens_per_hour: integer tokens. overnight: "HH:MM-HH:MM" local window. only_while_playing: omitted. */
  limit?: number | string;
}

interface Base {
  v: 1;
  seq: number;
  ts: string;
  job: string;
}
export type JobEvent = Base & EventBody;

export type EventBody =
  | { type: "job_created"; sentence: string; packId: string; title: string }
  | { type: "brief_set"; brief: Brief; estimate: Estimate }
  | { type: "brief_approved"; by: "player" | "auto" }
  | { type: "plan_set"; packages: PackageSpec[] }
  | { type: "package_state"; package: string; state: PackageState; round: number; cause?: Cause; detail?: string }
  | {
      type: "builder_run";
      /** Omitted for job-level generate runs (Designer, Planner, critic). See the report: proposed JOB.md wording. */
      package?: string;
      round?: number;
      adapter: AdapterName;
      mode: BuilderMode;
      model: string;
      outcome: BuilderOutcome;
      durationMs: number;
      tokensIn?: number;
      tokensOut?: number;
      /** The part of tokensIn that was read from the prompt cache (counts at 0.1 against a token policy). */
      tokensCacheRead?: number;
      transcript?: string;
    }
  | {
      type: "verify";
      package?: string;
      round: number;
      level: Level;
      verb: Verb;
      ok: boolean;
      report: string;
      /** Omitted when the runner never exited by itself (spawn failure, killed on timeout). */
      exitCode?: number;
      /** Whole-pack checks only: the package whose merge (or milestone) this check belongs to. */
      after?: string;
    }
  | { type: "merge"; package: string; files: string[]; removed?: string[] }
  | { type: "note"; package: string; round: number; text: string }
  /** N3: the player (or an answer with --change) asks for a change to a finished package. `package` when it was named. */
  | { type: "change_requested"; text: string; package?: string }
  /** N3: a promoted package goes back to work: a change request, the critic naming it, or a dependency that changed. */
  | { type: "reopened"; package: string; reason: string }
  | { type: "question"; package: string; text: string }
  | { type: "answer"; package: string; text: string; by: string }
  | { type: "milestone"; milestone: Milestone; captures: string[]; summary: string }
  | { type: "comment"; milestone: Milestone; text: string; by: "player" }
  | { type: "replan"; reason: string; added: string[]; removed: string[]; changed: string[] }
  | { type: "budget"; policy: BudgetPolicy; state: "running" | "paused"; reason: string }
  | { type: "billing"; adapter: AdapterName; mode: BillingMode; evidence: string }
  | { type: "promoted"; packId: string; version: string; dest: string }
  | { type: "job_state"; state: JobRunState; reason?: string };

export type EventType = EventBody["type"];
export type EventOf<T extends EventType> = Extract<JobEvent, { type: T }>;

// ---------- schemas ----------
const str = { type: "string" } as const;
const nonEmpty = { type: "string", minLength: 1 } as const;
const int0 = { type: "integer", minimum: 0 } as const;
const int1 = { type: "integer", minimum: 1 } as const;
const strList = { type: "array", items: str } as const;
const pkgId = { type: "string", pattern: PACKAGE_ID_RE.source } as const;
const pkgIdList = { type: "array", items: pkgId } as const;
const relPath = { type: "string", minLength: 1, pattern: "^(?![A-Za-z]:|/|\\\\)(?!.*(^|/)\\.\\.(/|$))[^\\\\]+$" } as const;

const acceptanceSchema = {
  type: "object",
  additionalProperties: false,
  required: ["level", "verb", "args"],
  properties: { level: { enum: LEVELS }, verb: { enum: VERBS }, args: strList },
} as const;

export const registersSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    capabilities: { type: "array", uniqueItems: true, items: { enum: CAPABILITIES } },
    assets: { type: "array", items: { type: "string", pattern: "^gen/[A-Za-z0-9_/]+\.gd$" } },
    tests: { type: "array", items: { type: "string", pattern: "^tests/[A-Za-z0-9_/]+\.gd$" } },
    cameras: { type: "array", items: { type: "string", pattern: "^[a-z][a-z0-9_]*$" } },
  },
} as const;

export const packageSpecSchema = {
  type: "object",
  additionalProperties: false,
  required: ["id", "title", "milestone", "deps", "scope", "contract", "acceptance"],
  properties: {
    registers: registersSchema,
    id: pkgId,
    title: nonEmpty,
    milestone: { enum: MILESTONES },
    deps: pkgIdList,
    scope: { type: "array", minItems: 1, items: relPath },
    contract: nonEmpty,
    acceptance: { type: "array", items: acceptanceSchema },
  },
} as const;

export const briefSchema = {
  type: "object",
  additionalProperties: false,
  required: ["rules", "arena", "ai", "controls", "mood"],
  properties: { rules: nonEmpty, arena: nonEmpty, ai: nonEmpty, controls: nonEmpty, mood: nonEmpty },
} as const;

export const estimateSchema = {
  type: "object",
  additionalProperties: false,
  required: ["packages", "wallMinutes", "tokens"],
  properties: { packages: int1, wallMinutes: { type: "number", minimum: 0 }, tokens: int0 },
} as const;

interface Spec {
  required: Record<string, object>;
  optional?: Record<string, object>;
}

const SPECS: Record<EventType, Spec> = {
  job_created: {
    required: { sentence: nonEmpty, packId: { type: "string", pattern: PACK_ID_RE.source }, title: nonEmpty },
  },
  brief_set: { required: { brief: briefSchema, estimate: estimateSchema } },
  brief_approved: { required: { by: { enum: ["player", "auto"] } } },
  plan_set: { required: { packages: { type: "array", minItems: 1, items: packageSpecSchema } } },
  package_state: {
    required: { package: pkgId, state: { enum: PACKAGE_STATES }, round: int1 },
    optional: { cause: { enum: CAUSES }, detail: str },
  },
  builder_run: {
    required: {
      adapter: { enum: ADAPTERS },
      mode: { enum: MODES },
      model: str,
      outcome: { enum: OUTCOMES },
      durationMs: int0,
    },
    optional: { package: pkgId, round: int1, tokensIn: int0, tokensOut: int0, tokensCacheRead: int0, transcript: relPath },
  },
  verify: {
    required: { round: int1, level: { enum: LEVELS }, verb: { enum: VERBS }, ok: { type: "boolean" }, report: relPath },
    optional: { package: pkgId, exitCode: { type: "integer" }, after: pkgId },
  },
  merge: { required: { package: pkgId, files: { type: "array", items: relPath } }, optional: { removed: { type: "array", items: relPath } } },
  note: { required: { package: pkgId, round: int1, text: nonEmpty } },
  change_requested: { required: { text: nonEmpty }, optional: { package: pkgId } },
  reopened: { required: { package: pkgId, reason: nonEmpty } },
  question: { required: { package: pkgId, text: nonEmpty } },
  answer: { required: { package: pkgId, text: nonEmpty, by: nonEmpty } },
  milestone: { required: { milestone: { enum: MILESTONES }, captures: { type: "array", items: relPath }, summary: str } },
  comment: { required: { milestone: { enum: MILESTONES }, text: nonEmpty, by: { enum: ["player"] } } },
  replan: { required: { reason: nonEmpty, added: pkgIdList, removed: pkgIdList, changed: pkgIdList } },
  budget: {
    required: {
      policy: {
        type: "object",
        additionalProperties: false,
        required: ["kind"],
        properties: { kind: { enum: BUDGET_KINDS }, limit: { type: ["number", "string"] } },
      },
      state: { enum: ["running", "paused"] },
      reason: str,
    },
  },
  billing: {
    required: { adapter: { enum: ADAPTERS }, mode: { enum: BILLING_MODES }, evidence: nonEmpty },
  },
  promoted: {
    required: { packId: { type: "string", pattern: PACK_ID_RE.source }, version: nonEmpty, dest: nonEmpty },
  },
  job_state: { required: { state: { enum: JOB_STATES } }, optional: { reason: str } },
};

export const EVENT_TYPES = Object.keys(SPECS) as EventType[];

const ISO_UTC = "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d{1,9})?Z$";

function buildSchema(type: EventType, spec: Spec): object {
  return {
    type: "object",
    additionalProperties: false,
    required: ["v", "seq", "ts", "job", "type", ...Object.keys(spec.required)],
    properties: {
      v: { const: 1 },
      seq: int1,
      ts: { type: "string", pattern: ISO_UTC },
      job: nonEmpty,
      type: { const: type },
      ...spec.required,
      ...(spec.optional ?? {}),
    },
  };
}

/** The whole event vocabulary as plain JSON schemas (one per type); also written to data/job-events.schema.json. */
export function eventSchemas(): Record<EventType, object> {
  const out = {} as Record<EventType, object>;
  for (const t of EVENT_TYPES) out[t] = buildSchema(t, SPECS[t]);
  return out;
}

const ajv = new Ajv2020({ allErrors: true, allowUnionTypes: true });
const validators = new Map<EventType, ValidateFunction>();
for (const t of EVENT_TYPES) validators.set(t, ajv.compile(buildSchema(t, SPECS[t])));

export class EventError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "EventError";
  }
}

/** Validates one parsed event. Throws EventError naming the offending key. */
export function validateEvent(value: unknown): JobEvent {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new EventError("event is not a JSON object");
  }
  const type = (value as { type?: unknown }).type;
  if (typeof type !== "string") throw new EventError("event has no string `type`");
  const validate = validators.get(type as EventType);
  if (!validate) throw new EventError(`unknown event type "${type}"`);
  if (!validate(value)) {
    const msgs = (validate.errors ?? []).map((e) => {
      if (e.keyword === "additionalProperties") {
        const where = e.instancePath ? ` at ${e.instancePath}` : "";
        return `unknown key "${String((e.params as { additionalProperty?: string }).additionalProperty)}"${where}`;
      }
      if (e.keyword === "required") {
        const where = e.instancePath ? ` at ${e.instancePath}` : "";
        return `missing key "${String((e.params as { missingProperty?: string }).missingProperty)}"${where}`;
      }
      return `${e.instancePath || "/"} ${e.message ?? "invalid"}`;
    });
    throw new EventError(`${type}: ${[...new Set(msgs)].join("; ")}`);
  }
  const ev = value as JobEvent;
  for (const [k, v] of Object.entries(ev)) {
    if (v === null) throw new EventError(`${type}: key "${k}" is null (absent values are omitted)`);
  }
  if (ev.type === "package_state") {
    const needs = ev.state === "failed" || ev.state === "blocked";
    if (needs && ev.cause === undefined) throw new EventError(`package_state ${ev.state}: missing key "cause"`);
    if (!needs && ev.cause !== undefined) {
      throw new EventError(`package_state ${ev.state}: key "cause" is only allowed with failed or blocked`);
    }
  }
  if (ev.type === "verify" && ev.after !== undefined && ev.package !== undefined) {
    throw new EventError(`verify: "after" is only allowed on a whole-pack check (no "package")`);
  }
  if (ev.type === "builder_run" && (ev.package === undefined) !== (ev.round === undefined)) {
    throw new EventError(`builder_run: "package" and "round" are given together or both omitted`);
  }
  if (ev.type === "budget") {
    // JOB.md: integer tokens for tokens_per_hour (omitted for a rate-limit pause), "HH:MM-HH:MM" for overnight,
    // nothing for only_while_playing.
    const { kind, limit } = ev.policy;
    if (kind === "tokens_per_hour" && limit !== undefined && !(typeof limit === "number" && Number.isInteger(limit) && limit > 0)) {
      throw new EventError(`budget: tokens_per_hour limit must be a positive integer number of tokens, got ${JSON.stringify(limit)}`);
    }
    if (kind === "overnight" && !(typeof limit === "string" && /^\d{1,2}:\d{2}-\d{1,2}:\d{2}$/.test(limit))) {
      throw new EventError(`budget: overnight limit must be "HH:MM-HH:MM", got ${JSON.stringify(limit)}`);
    }
    if (kind === "only_while_playing" && limit !== undefined) throw new EventError(`budget: only_while_playing takes no limit`);
  }
  if (ev.type === "plan_set") {
    const problems = planProblems(ev.packages);
    if (problems.length > 0) throw new EventError(`plan_set: ${problems.join("; ")}`);
  }
  return ev;
}

/** Structural problems of a plan that a JSON schema cannot say: duplicate ids, unknown or cyclic deps. */
export function planProblems(packages: PackageSpec[]): string[] {
  const out: string[] = [];
  const ids = new Set<string>();
  for (const p of packages) {
    if (ids.has(p.id)) out.push(`duplicate package id "${p.id}"`);
    ids.add(p.id);
  }
  for (const p of packages) {
    for (const d of p.deps) {
      if (!ids.has(d)) out.push(`package "${p.id}" depends on unknown "${d}"`);
      if (d === p.id) out.push(`package "${p.id}" depends on itself`);
    }
  }
  if (out.length === 0) {
    const byId = new Map(packages.map((p) => [p.id, p]));
    const mark = new Map<string, 1 | 2>();
    const visit = (id: string, trail: string[]): void => {
      const m = mark.get(id);
      if (m === 2) return;
      if (m === 1) {
        out.push(`dependency cycle: ${[...trail, id].join(" -> ")}`);
        return;
      }
      mark.set(id, 1);
      for (const d of byId.get(id)?.deps ?? []) visit(d, [...trail, id]);
      mark.set(id, 2);
    };
    for (const p of packages) visit(p.id, []);
  }
  return out;
}

export const VERB_LEVEL: Record<Verb, Level> = { lint: "V1", smoke: "V2", invariants: "V3", bot: "V4", capture: "V5" };
