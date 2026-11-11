// Designer, Planner and capture critic: generate-mode calls whose answers are validated before they are accepted.
import fs from "node:fs";
import path from "node:path";
import type { Brief, Estimate, PackageSpec } from "./events.js";
import { planProblems } from "./events.js";
import type { Builder, RunResult } from "./builder/types.js";
import { schemaErrors } from "./builder/json.js";
import { globToRegExp, scopeProblems } from "./scope.js";
import { critiqueSchema, type CritiqueResult } from "./verifier.js";
import { PKG_ROOT, REPO_ROOT } from "./paths.js";
import { ENTRY_SCRIPT, MANIFEST_FILE, depClosure } from "./manifest.js";
import { acceptanceOptions, verbOptionsText, type RunnerVerbs } from "./verbs.js";

const prompt = (name: string): string => fs.readFileSync(path.join(PKG_ROOT, "prompts", name), "utf8");
const schema = (name: string): object => JSON.parse(prompt(name)) as object;
const render = (template: string, vars: Record<string, string>): string => template.replace(/\{\{(\w+)\}\}/g, (_m, k: string) => vars[k] ?? "");

export interface GenerateCall {
  role: "designer" | "planner" | "critic";
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
}

async function generate<T>(
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
      problems = [...schemaErrors(jsonSchema, result.json), ...(result.json !== undefined ? check(result.json) : ["no JSON in the answer"])];
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

/** One sentence in, a validated brief and estimate out. */
export function designBrief(builder: Builder, sentence: string, opts: GenerateOptions = {}): Promise<Generated<DesignerOutput>> {
  return generate<DesignerOutput>(builder, "designer", prompt("designer.md"), { sentence }, schema("brief.schema.json"), () => [], opts);
}

/** Problems of a plan beyond its JSON shape: graph errors, scopes, the composed manifest, acceptance options. */
export function planCheck(packages: PackageSpec[], limits: PlanLimits): string[] {
  const out = [...planProblems(packages)];
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

/** P10 item 6: the line a contract names the player's check with. */
export const PLAYER_CHECK_RE = /^[ \t>*-]*PLAYER CHECK:[ \t]*`?(tests\/[A-Za-z0-9_\/.-]+\.gd)`?[ \t]*(.*)$/m;

/** The player checks a plan names: the bot, the package whose contract names it, and what the line says it fails on. */
export function playerChecks(packages: PackageSpec[]): { package: string; test: string; what: string }[] {
  const out: { package: string; test: string; what: string }[] = [];
  for (const p of packages) {
    for (const m of p.contract.matchAll(new RegExp(PLAYER_CHECK_RE.source, "gm"))) out.push({ package: p.id, test: m[1] as string, what: (m[2] ?? "").trim() });
  }
  return out;
}

/**
 * P10 item 6 (the real hockey job, finding 7): a game the player takes part in needs a bot that FAILS when the
 * human-controlled side has nothing to do. A plan "has player input" when a package registers the capability
 * `input`. Such a plan must name the check in a contract, in one line a builder reads too:
 *   PLAYER CHECK: tests/<bot>.gd fails when <what the player's side can no longer do>
 * The bot must be registered by a package of the plan (the final verification runs every registered bot, whatever
 * the acceptance lists say), and the line must say what it fails on. Whether the bot really fails then is the
 * builder's work and the Verifier's: a plan check reads words.
 */
export function playerCheckProblems(packages: PackageSpec[]): string[] {
  const withInput = packages.filter((p) => (p.registers?.capabilities ?? []).includes("input"));
  if (withInput.length === 0) return [];
  const checks = playerChecks(packages);
  const example = 'PLAYER CHECK: tests/<bot>.gd fails when <what the human-controlled side can no longer do>';
  if (checks.length === 0) {
    return [
      `the game has player input (package "${withInput[0]?.id ?? ""}" registers the capability "input") but no contract names a player check. Add ONE line to the contract of the package that owns the bot: "${example}" (for example: "fails when the player's skater took no shot", "fails when the result is the same with and without the player's inputs", "fails when the player's side never touched the ball"). The bot drives the player's input actions, and its \`ok\` must depend on what the player's side did, not only on the game reaching its end`,
    ];
  }
  const out: string[] = [];
  const registered = new Set(packages.flatMap((p) => p.registers?.tests ?? []));
  for (const c of checks) {
    if (!registered.has(c.test)) out.push(`package "${c.package}": the PLAYER CHECK line names ${c.test}, which no package registers in registers.tests`);
    if (c.what.replace(/[^A-Za-z]/g, "").length < 12) out.push(`package "${c.package}": the PLAYER CHECK line for ${c.test} must say what the bot fails on ("${example}")`);
  }
  return out;
}

export interface PlannerInput {
  sentence: string;
  packId: string;
  title: string;
  brief: Brief;
  packContract?: string;
  /** Text of the kernel's API.md, so that contracts name primitives that exist. */
  kernelApi?: string;
  /** What already exists in the engine (kit, rigs, style, seeds, by name): reference.ts existingText(<job>/ref). */
  existing?: string;
  /** The hard wall-clock limit of ONE builder run, so that packages are sized to fit it. */
  builderTimeoutMs?: number;
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
    brief: Object.entries(input.brief).map(([k, v]) => `- ${k}: ${v}`).join("\n"),
    packContract,
    kernelApi: input.kernelApi ?? "(not available)",
    existing: input.existing ?? "Nothing but the kernel API below: no kit, no rigs, no style layer and no seed games were found for this job.",
    timeLimit: String(minutes),
    limit: limitLine(limits),
    verbOptions: verbOptionsText(limits.verbs),
    replan,
  };
}

/** The Planner prompt exactly as the first attempt of `planPackages` sends it (dry check; no model is called). */
export function renderPlannerPrompt(input: PlannerInput, limits: PlanLimits): string {
  return render(prompt("planner.md"), { ...plannerVars(input, limits, ""), schema: JSON.stringify(schema("plan.schema.json"), null, 1), feedback: "" });
}

function limitLine(limits: PlanLimits): string {
  return limits.maxPackages !== undefined ? `At most ${limits.maxPackages} packages in total for this job (a hard limit).` : "Three to eight packages for a mini-game.";
}

export function planPackages(builder: Builder, input: PlannerInput, opts: GenerateOptions & PlanLimits): Promise<Generated<{ packages: PackageSpec[] }>> {
  return generate<{ packages: PackageSpec[] }>(
    builder,
    "planner",
    prompt("planner.md"),
    plannerVars(input, opts, ""),
    schema("plan.schema.json"),
    (v) => planCheck((v as { packages: PackageSpec[] }).packages, opts),
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
      return [...clash, ...planCheck([...input.kept, ...fresh.filter((p) => !keptIds.has(p.id))], opts)];
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
  opts: GenerateOptions & { threshold?: number; handOff?: "generate" | "readonly-scan"; context?: string; packages?: PackageLine[] } = {},
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
          .map((cap, i) => (handOff === "readonly-scan" ? `- ${path.basename(cap)} (open it with your Read tool)` : `- image ${i + 1} of ${captures.length}, attached to this message: ${path.basename(cap)}`))
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
