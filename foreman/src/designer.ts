// Designer, Planner and capture critic: generate-mode calls whose answers are validated before they are accepted.
import fs from "node:fs";
import path from "node:path";
import type { Brief, Creativity, Estimate, PackageSpec, Phase } from "./events.js";
import { planProblems } from "./events.js";
import { aspectProblems, crazyProblems, phaseProblems, LIMITS } from "./v2.js";
import type { ReactionView } from "./joblog.js";
import type { Builder, RunResult } from "./builder/types.js";
import { schemaErrors } from "./builder/json.js";
import { globToRegExp, scopeProblems } from "./scope.js";
import { critiqueSchema, type CritiqueResult } from "./verifier.js";
import { PKG_ROOT, REPO_ROOT } from "./paths.js";
import { ENTRY_SCRIPT, MANIFEST_FILE, depClosure } from "./manifest.js";
import { acceptanceOptions, verbOptionsText, type RunnerVerbs } from "./verbs.js";
import { planCardProblems, planHandProblems } from "./cards.js";
import { briefDesignText, conceptText, designAnswerSchema, qualityText, roomDesignProblems } from "./roomtext.js"; // JOB.md 2026-11-21: the design room
import { servesProblems, type Concept } from "./room_wire.js";
import { playerCheckProblems } from "./playercheck.js";
export { PLAYER_CHECK_RE, playerCheckProblems, playerChecks } from "./playercheck.js";

const prompt = (name: string): string => fs.readFileSync(path.join(PKG_ROOT, "prompts", name), "utf8");
const schema = (name: string): object => JSON.parse(prompt(name)) as object;
export const render = (template: string, vars: Record<string, string>): string => template.replace(/\{\{(\w+)\}\}/g, (_m, k: string) => vars[k] ?? "");

export interface GenerateCall {
  role: "designer" | "concept" | "design_review" | "planner" | "critic" | "placer" | "critic_compare";
  attempt: number;
  prompt: string;
  result: RunResult;
  /** Validation problems found by us after the adapter said ok. */
  problems: string[];
}

export type Generated<T> = { ok: true; value: T; calls: GenerateCall[] } | { ok: false; reason: string; calls: GenerateCall[] };

export interface GenerateOptions {
  model?: string;
  timeoutMs?: number;
  /** Total attempts when the answer does not validate. Default 2. */
  attempts?: number;
}

export interface PlanLimits {
  /** Most packages a plan may hold. A Planner answer with more is sent back once with this limit. */
  maxPackages?: number;
  /**
   * The runner's verbs and options, read from the engine (verbs.ts: <engine>/kernel/runner/verbs.json). Required:
   * the Foreman has no list of its own, and the real runner refuses an option it does not know with exit 2.
   */
  verbs: RunnerVerbs;
  /**
   * The recipe card ids the job's reference copy holds (`ref/cards/`, cards.ts cardIds). A plan's `card` must be one
   * of them (JOB.md 2026-11-17); absent means none, and then any `card` is refused.
   */
  cards?: string[];
  /** Lane C3: card id -> the hands its `hands` block checks; a plan naming that card must register tests/bot_hand_<hand>.gd for each. */
  cardHands?: Record<string, string[]>;
  /** JOB.md 2026-11-20: the v2 Planner writes `phases` (2 to 5); a hand-written plan and a re-plan may leave them out. */
  requirePhases?: boolean;
  /** JOB.md 2026-11-21: the clip ids of the brief's design; a package's `serves` must name only these. */
  clipIds?: string[];
}

/** The Planner's answer: the packages, the phases they are built in and, when one fits, the recipe card for the whole job. */
export interface PlanAnswer {
  packages: PackageSpec[];
  card?: string;
  phases?: Phase[];
}

export async function generate<T>(
  builder: Builder,
  role: GenerateCall["role"],
  template: string,
  vars: Record<string, string>,
  jsonSchema: object,
  check: (value: unknown) => string[],
  opts: GenerateOptions,
  mode: "generate" | "readonly-scan" = "generate",
  cwd = "",
  images: string[] = [],
): Promise<Generated<T>> {
  const calls: GenerateCall[] = [];
  let feedback = "";
  const attempts = opts.attempts ?? 2;
  for (let attempt = 1; attempt <= attempts; attempt++) {
    const text = render(template, { ...vars, schema: JSON.stringify(jsonSchema, null, 1), feedback });
    const result = await builder.run({
      prompt: text,
      mode,
      cwd,
      schema: jsonSchema,
      timeoutMs: opts.timeoutMs ?? 10 * 60_000,
      ...(opts.model ? { model: opts.model } : {}),
      ...(images.length > 0 ? { images } : {}),
      meta: { role },
    });
    let problems: string[] = [];
    if (result.outcome === "ok") {
      // The adapter validated against the schema; we do it again here because acceptance is ours to decide.
      problems = schemaErrors(jsonSchema, result.json);
      if (!problems.length) problems = check(result.json);
      calls.push({ role, attempt, prompt: text, result, problems });
      if (problems.length === 0) return { ok: true, value: result.json as T, calls };
    } else {
      calls.push({ role, attempt, prompt: text, result, problems });
      // Only an answer that came back but did not validate is worth asking again; a timeout or refusal is not.
      if (!(result.outcome === "error" && (result.error?.kind === "schema" || result.error?.kind === "parse"))) {
        return { ok: false, reason: `${role}: builder ${result.outcome}: ${result.error?.message ?? "no detail"}`, calls };
      }
      problems = [result.error.message];
    }
    feedback = `\n# Your previous answer was rejected\n${problems.map((p) => `- ${p}`).join("\n")}\nAnswer again with one valid JSON object.`;
  }
  const last = calls[calls.length - 1];
  return { ok: false, reason: `${role}: answer still invalid after ${attempts} attempts: ${(last?.problems.length ? last.problems : [last?.result.error?.message ?? "invalid"]).join("; ")}`, calls };
}

export interface DesignerOutput {
  brief: Brief;
  estimate: Estimate;
}

/** JOB.md 2026-11-20: what the Designer is given besides the sentence. */
export interface DesignerInput {
  sentence: string;
  /** Absent = standard. */
  creativity?: Creativity;
  /** What the engine can build (designctx.ts designerEngineText): the feasibility guard. */
  engine?: string;
  /** The recipe cards with their `fun` blocks (designctx.ts designerCardsText). */
  cards?: string;
  /** A redesign (`foreman redesign`): the latest brief and the reactions that stand on it. */
  previous?: { brief: Brief; reactions: Record<string, ReactionView> };
  /** JOB.md 2026-11-21: the design room's chosen concept (step 1), and the producer's notes on a revise (step 3). */
  concept?: Concept;
  review?: string;
}

const CREATIVITY_TEXT: Record<"standard" | Creativity, string> = {
  standard:
    "STANDARD. Serve the player's words: every aspect serves the game they asked for, and every gap is filled with the most fun choice that fits it. Surprise them with depth, not with things they did not ask for. No aspect carries `crazy`.",
  crazy:
    "CRAZY. Keep every word the player said: the game they asked for is all still there, done as well as in standard mode. On top of it add ONE or TWO unexpected mechanics that make the player laugh or gasp: a rule from another kind of game, a place that behaves like a character, a rival nobody expects, a power with a cost. Crazy is not the standard twist made bigger (a standard design already has a hazard or a twist): a crazy mechanic bends a rule the player takes for granted, such as what scores, who they control, what a hit does, or what the place and the audience do. Each crazy mechanic is its own aspect with `\"crazy\": true` (so the player can drop it with one tap), and the rest of the design must still stand without it. Crazy is still buildable: a surprising use of what the engine has (a spawner, a rule, a law of a surface, a camera), never a new engine feature. Mark only those one or two aspects crazy.",
};

/** The brief as text for the Planner and the builders: the five fields, then the pitch and the aspect cards. */
export function briefText(brief: Brief): string {
  const lines = (["rules", "arena", "ai", "controls", "mood"] as const).map((k) => `- ${k}: ${brief[k]}`);
  if (brief.pitch !== undefined) lines.push(`- pitch: ${brief.pitch}`);
  if (brief.design !== undefined) lines.push(briefDesignText(brief, "all"));
  if (brief.aspects !== undefined && brief.aspects.length > 0) {
    lines.push("- aspects (the design as the player saw it):");
    for (const a of brief.aspects) lines.push(`  - ${a.id} [${a.icon}]${a.crazy === true ? " (crazy)" : ""}: ${a.title}: ${a.line}. ${a.detail}`);
  }
  return lines.join("\n");
}

/** The player's reactions to the aspects of a brief, one line per aspect, as the Designer (redesign) and the Planner read them. */
export function reactionsText(brief: Brief, reactions: Record<string, ReactionView>): string {
  const out: string[] = [];
  for (const a of brief.aspects ?? []) {
    const r = reactions[a.id];
    const note = r?.note !== undefined ? `; the player's note: "${r.note}"` : "";
    if (r === undefined) out.push(`- ${a.id} ("${a.title}"): no reaction: as designed`);
    else if (r.choice === "keep") out.push(`- ${a.id} ("${a.title}"): KEEP${note}`);
    else if (r.choice === "drop") out.push(`- ${a.id} ("${a.title}"): DROP: the player does not want this aspect; it is not in the game${note}`);
    else {
      const alt = a.alternatives.find((x) => x.id === r.choice);
      out.push(`- ${a.id} ("${a.title}"): the player CHOSE the alternative ${r.choice} ("${alt?.title ?? "?"}": ${alt?.line ?? "?"}) instead of "${a.title}"${note}`);
    }
  }
  return out.join("\n");
}

function designerVars(input: DesignerInput): Record<string, string> {
  const redesign =
    input.previous === undefined
      ? ""
      : [
          "",
          "# This is a REDESIGN: the player reacted to your previous brief",
          `Your previous brief (JSON):\n${JSON.stringify(input.previous.brief, null, 1)}`,
          "The player's reactions (the latest per aspect):",
          reactionsText(input.previous.brief, input.previous.reactions),
          "How to answer:",
          "- KEEP: the aspect stays; you may sharpen its words, not change its idea.",
          "- DROP: the aspect is gone, and it does not come back under another id or another name. Close the gap it leaves so the game still plays.",
          "- A chosen alternative becomes the aspect: its title and line are now the main ones, with the same id; write 2 or 3 fresh alternatives for it.",
          "- A note is the player's own words: it wins over your design where the two disagree.",
          "- An aspect with no reaction keeps its idea; adjust it where the reactions call for it.",
          "Then check the whole design against the fun checklist again: the rules, arena, ai, controls and mood must describe the game as it is NOW.",
          "",
        ].join("\n");
  return {
    sentence: input.sentence,
    creativity: CREATIVITY_TEXT[input.creativity ?? "standard"],
    engine: input.engine ?? "(the engine was not described for this call: design with bipeds, vehicles, balls, cameras, effects, sound, a HUD and simple kit parts only)",
    cards: input.cards ?? "(no recipe cards)",
    redesign,
    concept: input.concept ? conceptText(input.concept) : "(no concept step ran: design the boldest game that fits the words)",
    quality: qualityText(["1", "2", "6"]),
    review: input.review ?? "",
  };
}

/** Problems of a Designer answer beyond the JSON schema: word limits, unique ids, the crazy rule, dropped aspects. */
export function designerProblems(brief: Brief, input: Pick<DesignerInput, "creativity" | "previous">): string[] {
  const out = [...aspectProblems(brief.pitch, brief.aspects), ...roomDesignProblems(brief)];
  if (brief.pitch === undefined || brief.aspects === undefined) out.push("the brief needs a pitch and 3 to 7 aspects");
  out.push(...crazyProblems(brief.aspects, input.creativity, input.previous === undefined));
  if (input.previous) {
    const dropped = Object.entries(input.previous.reactions).filter(([, r]) => r.choice === "drop").map(([id]) => id);
    for (const id of dropped) if ((brief.aspects ?? []).some((a) => a.id === id)) out.push(`aspect "${id}" was dropped by the player and must not be in the redesign`);
  }
  return out;
}

/**
 * One sentence in, a validated brief and estimate out. A string is the sentence alone (standard, no engine text).
 * JOB.md 2026-11-20: the v2 Designer writes a pitch and 3 to 7 aspects; crazy mode adds one or two crazy aspects.
 */
export function designBrief(builder: Builder, input: string | DesignerInput, opts: GenerateOptions = {}): Promise<Generated<DesignerOutput>> {
  const i: DesignerInput = typeof input === "string" ? { sentence: input } : input;
  return generate<DesignerOutput>(builder, "designer", prompt("designer.md"), designerVars(i), designAnswerSchema(), (v) => designerProblems((v as DesignerOutput).brief, i), opts);
}

/** The Designer prompt exactly as the first attempt of `designBrief` sends it (dry check; no model is called). */
export function renderDesignerPrompt(input: DesignerInput): string {
  return render(prompt("designer.md"), { ...designerVars(input), schema: JSON.stringify(designAnswerSchema(), null, 1), feedback: "" });
}

/** JOB.md 2026-11-20: problems of a plan's phases, and of a missing `phases` when the Planner must write them. */
export function planPhaseProblems(packages: PackageSpec[], phases: unknown, required: boolean): string[] {
  if (phases === undefined) {
    return required
      ? [`the plan has no "phases": group the packages into ${LIMITS.phasesMin} to ${LIMITS.phasesMax} phases the player tries one after another, each {id, title, try, packages}; the first phase is the smallest thing that plays`]
      : [];
  }
  const list = phases as Phase[];
  const out = phaseProblems(list, packages);
  const root = packages.find((p) => p.deps.length === 0);
  if (root && list[0] && !list[0].packages.includes(root.id)) out.push(`the root package "${root.id}" must be in the first phase "${list[0].id}": the first phase is the smallest thing that plays`);
  return out;
}

/** Problems of a plan beyond its JSON shape: graph errors, scopes, the composed manifest, acceptance options, phases. */
export function planCheck(packages: PackageSpec[], limits: PlanLimits, card?: unknown, phases?: unknown): string[] {
  const out = [...planProblems(packages), ...planCardProblems(card, limits.cards ?? []), ...planHandProblems(packages, typeof card === "string" ? card : undefined, limits.cardHands ?? {})];
  out.push(...planPhaseProblems(packages, phases, limits.requirePhases === true), ...servesProblems(packages, limits.clipIds));
  if (limits.maxPackages !== undefined && packages.length > limits.maxPackages) {
    out.push(`the plan has ${packages.length} packages; the limit for this job is ${limits.maxPackages}: merge concerns until it fits`);
  }
  for (const p of packages) out.push(...scopeProblems(p.scope).map((m) => `package "${p.id}": ${m}`));
  // Disjointness of globs in general is hard; these two tests catch what planners actually get wrong:
  // the same glob twice, and one package's literal path falling inside another's glob.
  for (let i = 0; i < packages.length; i++) {
    for (let j = 0; j < packages.length; j++) {
      if (i === j) continue;
      const a = packages[i] as PackageSpec;
      const b = packages[j] as PackageSpec;
      for (const ga of a.scope) {
        for (const gb of b.scope) {
          if (ga === gb) {
            if (i < j) out.push(`packages "${a.id}" and "${b.id}" both claim scope "${ga}"`);
          } else if (!/[*?]/.test(ga) && globToRegExp(gb).test(ga)) {
            out.push(`scope "${ga}" of package "${a.id}" lies inside scope "${gb}" of package "${b.id}"`);
          }
        }
      }
    }
  }
  // The manifest is composed by the Foreman: nobody owns pack.json, and exactly one root owns the entry script.
  for (const p of packages) {
    if (p.scope.some((g) => globToRegExp(g).test(MANIFEST_FILE))) {
      out.push(`package "${p.id}": scope must not include ${MANIFEST_FILE} (the Foreman writes it from the registers blocks)`);
    }
  }
  const roots = packages.filter((p) => p.deps.length === 0);
  if (roots.length !== 1) {
    out.push(`exactly one package may have no dependencies (the root that owns ${ENTRY_SCRIPT}); this plan has ${roots.length}: ${roots.map((p) => p.id).join(", ") || "none"}`);
  }
  const graphOk = planProblems(packages).length === 0;
  for (const root of roots) {
    if (!root.scope.some((g) => globToRegExp(g).test(ENTRY_SCRIPT))) {
      out.push(`root package "${root.id}" must have ${ENTRY_SCRIPT} in its scope: it is the entry script of every pack`);
    }
    if ((root.registers?.tests ?? []).length === 0) {
      out.push(`root package "${root.id}" must register at least one bot in registers.tests: a pack without a test does not pass lint`);
    }
  }
  for (const p of packages) {
    const reg = p.registers ?? {};
    for (const f of [...(reg.tests ?? []), ...(reg.assets ?? [])]) {
      if (!p.scope.some((g) => globToRegExp(g).test(f))) out.push(`package "${p.id}": registers "${f}" but its scope does not contain that file`);
    }
    const visible = graphOk ? [...depClosure(packages, p.id)] : [p.id];
    const tests = new Set(visible.flatMap((id) => packages.find((x) => x.id === id)?.registers?.tests ?? []));
    for (const acc of p.acceptance) {
      const allowed = acceptanceOptions(limits.verbs, acc.verb);
      if (allowed === undefined) {
        out.push(`package "${p.id}": acceptance verb "${acc.verb}" is not allowed (captures are taken by the Foreman at milestones)`);
        continue;
      }
      for (const x of acc.args) {
        const m = /^--([a-z][a-z0-9-]*)=[^\s;&|<>`$]+$/.exec(x);
        if (!m) out.push(`package "${p.id}": acceptance argument ${JSON.stringify(x)} is not a plain --key=value`);
        else if (!allowed.includes(m[1] as string)) {
          out.push(`package "${p.id}": ${acc.verb} does not take --${m[1]} (allowed: ${allowed.map((o) => `--${o}`).join(", ") || "no options"}; from ${limits.verbs.source})`);
        }
      }
      if (acc.verb === "bot") {
        const t = acc.args.find((x) => x.startsWith("--test="))?.slice("--test=".length);
        if (t === undefined || !/^tests\/.+\.gd$/.test(t)) out.push(`package "${p.id}": a bot acceptance needs --test=tests/<file>.gd`);
        else if (!tests.has(t)) {
          out.push(`package "${p.id}": bot acceptance runs ${t}, which neither this package nor a package it depends on registers in registers.tests`);
        }
      }
    }
  }
  out.push(...playerCheckProblems(packages));
  return [...new Set(out)];
}

export interface PlannerInput {
  sentence: string;
  packId: string;
  title: string;
  brief: Brief;
  /** JOB.md 2026-11-20: the reactions that stand on the approved brief (the Planner sees both). */
  reactions?: Record<string, ReactionView>;
  /** JOB.md 2026-11-20: absent = standard. */
  creativity?: Creativity;
  packContract?: string;
  /** Text of the kernel's API.md, so that contracts name primitives that exist. */
  kernelApi?: string;
  /** What already exists in the engine (kit, rigs, style, seeds, by name): reference.ts existingText(<job>/ref). */
  existing?: string;
  /** The recipe cards the job offers, with when each applies and when not: cards.ts cardsPlannerText(<job>/ref). */
  cards?: string;
  /** The hard wall-clock limit of ONE builder run, so that packages are sized to fit it. */
  builderTimeoutMs?: number;
  /** JOB.md 2026-11-21: the producer's last notes on the design (its warnings to the build). */
  review?: string;
}

/** The Foreman's default builder time limit (foreman.ts), named to the Planner when the caller gives none. */
export const DEFAULT_BUILDER_TIMEOUT_MS = 30 * 60_000;

function plannerVars(input: PlannerInput, limits: PlanLimits, replan: string): Record<string, string> {
  const packContract = input.packContract ?? fs.readFileSync(path.join(REPO_ROOT, "contracts", "PACK.md"), "utf8");
  const minutes = Math.max(1, Math.round((input.builderTimeoutMs ?? DEFAULT_BUILDER_TIMEOUT_MS) / 60_000));
  return {
    sentence: input.sentence,
    packId: input.packId,
    title: input.title,
    brief: briefText(input.brief),
    reactions:
      (input.brief.aspects ?? []).length > 0
        ? [
            `The player approved this brief${input.creativity === "crazy" ? " (made in CRAZY mode: the aspects marked crazy are unexpected mechanics added on top of the player's words)" : ""} with these reactions to its aspect cards. They are the player's decisions and win over the brief's text where the two disagree: a dropped aspect is NOT built, a chosen alternative is built instead of the aspect, a note is followed.`,
            reactionsText(input.brief, input.reactions ?? {}),
          ].join("\n")
        : "The brief has no aspect cards (made before the designer v2): build what the brief says.",
    packContract,
    kernelApi: input.kernelApi ?? "(not available)",
    existing: input.existing ?? "Nothing but the kernel API below: no kit, no rigs, no style layer and no seed games were found for this job.",
    cards: input.cards ?? "This engine has no recipe cards: omit `card`.",
    timeLimit: String(minutes),
    limit: limitLine(limits),
    verbOptions: verbOptionsText(limits.verbs),
    replan,
    review: input.review !== undefined ? `
The producer's last review of this design (its warnings: make each one true in a contract): ${input.review}
` : "",
    quality: input.brief.design !== undefined ? qualityText(["2", "6", "7:Planner"]) : "(the brief has no game design doc: build the brief as it is)",
  };
}

/** The Planner prompt exactly as the first attempt of `planPackages` sends it (dry check; no model is called). */
export function renderPlannerPrompt(input: PlannerInput, limits: PlanLimits): string {
  return render(prompt("planner.md"), { ...plannerVars(input, limits, ""), schema: JSON.stringify(schema("plan.schema.json"), null, 1), feedback: "" });
}

function limitLine(limits: PlanLimits): string {
  return limits.maxPackages !== undefined ? `At most ${limits.maxPackages} packages in total for this job (a hard limit).` : "Four to ten packages for a mini-game: a real design needs room for the core exchange with its feel sheet, the rivals, the twist and the clip moments.";
}

/** JOB.md 2026-11-21: the clip ids a plan's `serves` may name (none without a design doc). */
export const clipLimit = (brief: Brief): { clipIds?: string[] } => (brief.design ? { clipIds: brief.design.clips.map((c) => c.id) } : {});

export function planPackages(builder: Builder, input: PlannerInput, opts: GenerateOptions & PlanLimits): Promise<Generated<PlanAnswer>> {
  return generate<PlanAnswer>(
    builder,
    "planner",
    prompt("planner.md"),
    plannerVars(input, opts, ""),
    schema("plan.schema.json"),
    (v) => planCheck((v as PlanAnswer).packages, { requirePhases: true, ...opts, ...clipLimit(input.brief) }, (v as PlanAnswer).card, (v as PlanAnswer).phases),
    opts,
  );
}

export interface ReplanInput extends PlannerInput {
  /** Packages already merged and verified: fixed, not to be returned. */
  kept: PackageSpec[];
  /** The packages that failed, why, and (when there is one) the last failing verify report. */
  failed: { spec: PackageSpec; cause: string; detail: string; lastReport?: string }[];
  /** Packages that depend on a failed one. */
  dependants: PackageSpec[];
}

/**
 * Re-plan after a failure: the Planner returns replacement packages for the failed ones and their dependants only.
 * The answer is validated together with the kept packages, so scopes, the graph and the limits hold for the whole plan.
 */
export function replanPackages(builder: Builder, input: ReplanInput, opts: GenerateOptions & PlanLimits): Promise<Generated<{ packages: PackageSpec[] }>> {
  const keptIds = new Set(input.kept.map((p) => p.id));
  const room = opts.maxPackages !== undefined ? opts.maxPackages - input.kept.length : undefined;
  const replan = [
    "",
    "# This is a RE-PLAN after a failure",
    "Some packages are already merged and verified. They are fixed: do not return them, do not reuse their ids, do not put their files in a scope.",
    `Kept packages (JSON):\n${JSON.stringify(input.kept, null, 1)}`,
    "These packages FAILED after all their rounds and must be cut again (differently: smaller, a clearer contract, or a simpler acceptance):",
    ...input.failed.map(
      (f) => `- ${f.spec.id}: cause ${f.cause}; ${f.detail}\n  the package as it was planned: ${JSON.stringify(f.spec)}${f.lastReport ? `\n  last failing verify report: ${f.lastReport}` : ""}`,
    ),
    input.dependants.length > 0
      ? `These packages depend on a failed one and must be returned again (changed or not):\n${JSON.stringify(input.dependants, null, 1)}`
      : "No other package depends on the failed ones.",
    `Return ONLY the replacement packages${room !== undefined ? ` (at most ${room})` : ""}. Their deps may name kept packages.`,
    "The job's recipe card (if it has one) stays as it is: omit `card` in this answer.",
    "The job's phases stay as they are: omit `phases` in this answer. The Foreman puts each replacement package into the phase being built now, or into the phase of its latest dependency when that is later.",
  ].join("\n");
  return generate<{ packages: PackageSpec[] }>(
    builder,
    "planner",
    prompt("planner.md"),
    plannerVars(input, opts, replan),
    schema("plan.schema.json"),
    (v) => {
      const fresh = (v as { packages: PackageSpec[] }).packages;
      const clash = fresh.filter((p) => keptIds.has(p.id)).map((p) => `package id "${p.id}" belongs to a kept package: do not return kept packages`);
      const phases = (v as PlanAnswer).phases !== undefined ? ["omit `phases` in a re-plan: the job's phases stay, and the Foreman places the replacement packages"] : [];
      return [...clash, ...phases, ...planCheck([...input.kept, ...fresh.filter((p) => !keptIds.has(p.id))], { ...opts, ...clipLimit(input.brief), requirePhases: false }, (v as PlanAnswer).card)];
    },
    opts,
  );
}

/** One line per package for the critic and for the "who owns this" question: id, title, milestone, deps, files. */
export interface PackageLine {
  id: string;
  title: string;
  milestone: string;
  deps: string[];
  /** The files the package owns in pack/ (what it merged), or its scope globs when it has merged nothing yet. */
  files: string[];
}

export function packageLinesText(lines: PackageLine[]): string {
  if (lines.length === 0) return "(no package list was given)";
  return lines
    .map((p) => `- ${p.id} (${p.milestone}${p.deps.length > 0 ? `, depends on ${p.deps.join(", ")}` : ", the root"}): ${p.title}. Files: ${p.files.slice(0, 30).join(", ") || "(none yet)"}`)
    .join("\n");
}

export const ownerSchema = {
  type: "object",
  additionalProperties: false,
  required: ["package", "reason"],
  properties: { package: { type: "string" }, reason: { type: "string" } },
} as const;

/**
 * N3: which package owns the cause of a change request? One short generate call (role planner). The answer must
 * name one of the listed packages; anything else is asked once more and then refused.
 */
export function whoOwns(
  builder: Builder,
  input: { sentence: string; title: string; text: string; packages: PackageLine[] },
  opts: GenerateOptions = {},
): Promise<Generated<{ package: string; reason: string }>> {
  const ids = input.packages.map((p) => p.id);
  return generate<{ package: string; reason: string }>(
    builder,
    "planner",
    prompt("owner.md"),
    { sentence: input.sentence, title: input.title, text: input.text, packages: packageLinesText(input.packages) },
    ownerSchema,
    (v) => (ids.includes((v as { package: string }).package) ? [] : [`"package" must be one of: ${ids.join(", ")}`]),
    { timeoutMs: 3 * 60_000, ...opts },
  );
}

export interface RubricItem {
  id: string;
  text: string;
}

/**
 * L2 of 21 Nov: the critic's `fun_promise` dimension. Given the promise of the phase being judged (its `try` line) or,
 * without phases, the brief's pitch: do the captures show it HAPPENING? Added to the default rubric when there is one.
 */
export function funPromiseItem(promise: string): RubricItem {
  return { id: "fun_promise", text: `The frames show this promise to the player happening, not only a place where it could happen: "${promise}". Judge what you see in motion (the verb being done, the rival reacting, the effect of a hit); 0 when nothing of it is visible.` };
}

/** The V5 rubric of Phase 0 (brief WP3b, Part 1 item 4). */
export const DEFAULT_RUBRIC: RubricItem[] = [
  { id: "silhouette", text: "The objects that matter (players, balls, goals, the play surface) have clear, distinct silhouettes against the background." },
  { id: "readability", text: "A new viewer can tell at a glance what the play space is and where the action is; nothing important is hidden, cut off or too small." },
  { id: "style_consistency", text: "Shapes, palette and light are consistent with each other and with the mood the brief asks for." },
  { id: "shows_play", text: "The frame shows the game being played (things in motion or mid-action, in a plausible state), not an empty or broken scene." },
];

/**
 * V5: critic(captures[], rubric) -> {ok, scores, notes}, a generate-mode builder run that is GIVEN the images.
 *
 * Image hand-off, observed live on claude-cli 2.1.322 (2026-11-10): `claude --help` has no image flag, but a
 * headless run takes `--input-format stream-json` and one user message on stdin whose content holds base64 image
 * blocks followed by the text. That works with `--tools ""`, so the critic stays in generate mode (no tools, no
 * workspace). `handOff: "readonly-scan"` remains as the fallback: the run then happens in the captures directory
 * with the read tools only and the prompt names the files.
 * `context` is free text put in front of the rubric (the brief's mood, which bot was playing).
 */
export async function critic(
  builder: Builder,
  captures: string[],
  rubric: RubricItem[] = DEFAULT_RUBRIC,
  opts: GenerateOptions & { threshold?: number; handOff?: "generate" | "readonly-scan"; context?: string; packages?: PackageLine[]; /** L2b: per capture, what it shows (camera, frame, which bot of which package). */ labels?: string[] } = {},
): Promise<Generated<CritiqueResult>> {
  const threshold = opts.threshold ?? 0.6;
  const handOff = opts.handOff ?? "generate";
  const dir = captures[0] !== undefined ? path.dirname(path.resolve(captures[0])) : "";
  const res = await generate<CritiqueResult>(
    builder,
    "critic",
    prompt("critic.md"),
    {
      captures:
        captures
          .map((cap, i) => (handOff === "readonly-scan" ? `- ${path.basename(cap)} (open it with your Read tool)` : `- image ${i + 1} of ${captures.length}, attached to this message: ${path.basename(cap)}`) + (opts.labels?.[i] ? `: ${opts.labels[i]}` : ""))
          .join("\n") || "(none)",
      context: opts.context ?? "(none given)",
      packages: packageLinesText(opts.packages ?? []),
      rubric: rubric.map((r) => `- ${r.id}: ${r.text}`).join("\n"),
      threshold: String(threshold),
    },
    critiqueSchema,
    (v) => {
      const cr = v as CritiqueResult;
      const out: string[] = [];
      for (const r of rubric) if (typeof cr.scores[r.id] !== "number") out.push(`scores has no entry for rubric item "${r.id}"`);
      for (const k of Object.keys(cr.scores)) if (!rubric.some((r) => r.id === k)) out.push(`scores has an entry "${k}" that is not in the rubric`);
      return out;
    },
    opts,
    handOff,
    dir,
    handOff === "generate" ? captures.map((cap) => path.resolve(cap)) : [],
  );
  if (!res.ok) return res;
  // `ok` is recomputed from the scores: the model's own summary bit is not trusted over its numbers.
  const allPass = captures.length > 0 && rubric.every((r) => (res.value.scores[r.id] ?? 0) >= threshold);
  const notes = [...res.value.notes];
  if (res.value.ok !== allPass) notes.push(`critic said ok=${res.value.ok}; scores against threshold ${threshold} give ok=${allPass}`);
  if (captures.length === 0) notes.push("no captures were given");
  const named = typeof res.value.package === "string" && res.value.package.trim() !== "" ? res.value.package.trim() : undefined;
  return { ok: true, value: { ok: allPass, scores: res.value.scores, notes, ...(named !== undefined ? { package: named } : {}) }, calls: res.calls };
}
