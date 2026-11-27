// E4 (night of 24-25 Nov 2026): a change request may GROW the game. Until now a change (or a phase hold) re-opened ONE
// existing package inside its scope (N3, foreman.ts applyChangeRequests; phases.ts applyHolds), so "add rocket skates"
// to a finished game had nowhere to go. Now the owner question may answer "new": the request adds something no
// package's files can hold. The Planner is then asked for at most GROW_MAX new packages (the planner prompt as for a
// first plan, plus a growth section: the kept packages are fixed), the plan is written again (`plan_set` = the kept
// packages + the new ones; the phases stay and the new packages join the phase being built now, or the last one), and
// each new package is opened for the request (`reopened` with the change request's reason, so the request is taken
// and its text joins the new package's brief), then `queued` at round 1.
// A new package that must be called from a kept package's script names that package in `wire`: the Foreman writes a
// change request of its own for it (`[foreman] wire in ...`), which waits until the new package is merged.
// Kept out of foreman.ts (its size ratchet), like phases.ts and p10gate.ts. Proposed JOB.md wording: the lane's REPORT.
import type { JobEvent, PackageSpec } from "./events.js";
import { changeReason, type JobLog, type JobState } from "./joblog.js";
import { generate, packageLinesText, planCheck, renderPlannerPrompt, clipLimit, type GenerateCall, type Generated, type GenerateOptions, type PackageLine, type PlanLimits, type PlannerInput } from "./designer.js";
import type { Builder } from "./builder/types.js";
import { replanPhases } from "./phases.js";
import { CHANGE_ROUND } from "./rounds.js";
import { clip, FOREMAN_NOTE } from "./conduct.js";
import fs from "node:fs";
import path from "node:path";
import { PKG_ROOT } from "./paths.js";
import { BOTS_PROPERTIES, botsProblems, botsPromptText } from "./botsdefault.js";

/** The owner answer that says no package owns the request: it adds something new. */
export const NEW_PACKAGE = "new";
/** At most this many packages are added for one request. */
export const GROW_MAX = 2;
/** The words in a new package's `reopened` reason after the change request's seq. */
export const GROW_WORDS = "the Planner adds a package for it";
/** A wire request's text: `[foreman] wire in <pkg> (...)`; the request waits until <pkg> is promoted. */
export const WIRE_RE = /^\[foreman\] wire in ([a-z][a-z0-9_]*) /;

const OWNER_PROMPT = `You are the Planner for Third Life. A game pack has been built from the packages listed below. The player now asks
for a change. Decide which ONE package owns the files that must change to make it happen, or say that none does.

# Game
{{title}} ({{sentence}})

# The player's change request
{{text}}

# Packages (id, milestone, dependencies, title, files it owns)
{{packages}}

Rules:
- Name the package whose own files cause what the player wants changed. Sizes, shapes, positions, rules, speeds, the
  camera and the bot usually belong to the package that builds the play space (often the root); colours, materials,
  props and effects to an art or feel package. A game whose rules come from a data file (a cartridge, a tuning file)
  changes in the package that owns that file, also for a new ability, pickup, zone or variant the file has a place for.
- If more than one package is involved, name the one the others depend on: the packages that depend on it are
  verified again after the change, and rebuilt only if they then fail.
- Answer "new" only when the request ADDS something the game does not have at all and that belongs in none of these
  packages' files (a new mechanic, a new kind of object, a new screen). Bigger, faster, stronger, slower, another
  colour or another number is never "new": name the package that owns it.
{{bots}}

Answer with ONE JSON object and nothing else, matching this JSON schema exactly:

{{schema}}

- \`package\`: one id from the list above, exactly as written, or "new".
- \`reason\`: one sentence.
- \`move\`, \`bots\`, \`bot_packages\`, \`use\`, \`answer\`: as the section on a new move says; omit them all when the request adds no move.
{{feedback}}`;

const ownerSchema = {
  type: "object",
  additionalProperties: false,
  required: ["package", "reason"],
  properties: { package: { type: "string" }, reason: { type: "string" }, ...BOTS_PROPERTIES }, // S1-bots A: a new move and the bots (botsdefault.ts)
} as const;

/** The owner answer: a package (or "new") and why; with a new move, what the bots do with it (botsdefault.ts). */
export interface OwnerAnswer {
  package: string;
  reason: string;
  move?: string;
  bots?: string;
  bot_packages?: string[];
  use?: string;
  answer?: string;
}

/**
 * Which package owns a change request, or NEW_PACKAGE. The prompt keeps the old owner question's words ("Decide which
 * ONE package owns"), so a fake script written for it answers this one too.
 */
export function ownerOrNew(
  builder: Builder,
  input: { sentence: string; title: string; text: string; packages: PackageLine[] },
  opts: GenerateOptions = {},
): Promise<Generated<OwnerAnswer>> {
  const ids = input.packages.map((p) => p.id);
  return generate<OwnerAnswer>(
    builder,
    "planner",
    OWNER_PROMPT,
    { sentence: input.sentence, title: input.title, text: input.text, packages: packageLinesText(input.packages), bots: botsPromptText(input.packages) },
    ownerSchema,
    (v) => {
      const pkg = (v as { package: string }).package;
      return [...(ids.includes(pkg) || pkg === NEW_PACKAGE ? [] : [`"package" must be one of: ${ids.join(", ")}, or "${NEW_PACKAGE}"`]), ...botsProblems(v as OwnerAnswer, ids)];
    },
    { timeoutMs: 3 * 60_000, ...opts },
  );
}

const plan = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "prompts", "plan.schema.json"), "utf8")) as { properties: { packages: Record<string, unknown> } };
export const growSchema = {
  type: "object",
  additionalProperties: false,
  required: ["packages"],
  properties: {
    packages: { ...plan.properties.packages, maxItems: GROW_MAX },
    wire: { type: "array", maxItems: 2, items: { type: "string" } },
  },
};

export interface GrowAnswer {
  packages: PackageSpec[];
  wire?: string[];
}

/** The growth section under the planner prompt. */
export function growText(kept: PackageSpec[], text: string, why: string): string {
  return [
    "",
    "# This is a GROWTH after a change request (not a first plan)",
    "The game is built and the player has played it. The packages below are merged and verified. They are fixed: do not return them, do not reuse their ids, do not put their files in a scope.",
    `Kept packages (JSON):\n${JSON.stringify(kept, null, 1)}`,
    `The player asks: "${text}"`,
    `No kept package's files can hold it (${why}). Return ONLY the NEW package(s) that add it, at most ${GROW_MAX}: their own files (new paths, never a kept package's), deps on the kept packages they build on, a contract and an acceptance as for any package. The game must still play as before where the request does not change it.`,
    "When a kept package's script must call the new package's code (the entry script that starts the game, a loop that ticks it), name that kept package in `wire` (at most 2). It is re-opened after your new package is merged, with the request to call it as your contract says. Without `wire` the new package must take effect through what the kept packages already read.",
    "The recipe card and the phases stay as they are: omit `card` and `phases`. The Foreman puts the new packages into the phase being built now, or into the last phase.",
  ].join("\n");
}

/** Problems of a growth answer beyond its JSON shape: ids, wires, and the whole plan with it. */
export function growProblems(v: GrowAnswer, kept: PackageSpec[], limits: PlanLimits): string[] {
  const keptIds = new Set(kept.map((p) => p.id));
  const out = v.packages.filter((p) => keptIds.has(p.id)).map((p) => `package id "${p.id}" belongs to a kept package: return only NEW packages`);
  for (const w of v.wire ?? []) if (!keptIds.has(w)) out.push(`wire names "${w}", which is not a kept package (${[...keptIds].join(", ")})`);
  out.push(...planCheck([...kept, ...v.packages.filter((p) => !keptIds.has(p.id))], { ...limits, requirePhases: false }));
  return out;
}

export function growPackages(builder: Builder, input: PlannerInput & { kept: PackageSpec[]; text: string; why: string }, opts: GenerateOptions & PlanLimits): Promise<Generated<GrowAnswer>> {
  const limits: PlanLimits = { ...opts, ...clipLimit(input.brief), maxPackages: input.kept.length + GROW_MAX };
  return generate<GrowAnswer>(
    builder,
    "planner",
    "{{base}}\n{{grow}}\n{{feedback}}",
    { base: renderPlannerPrompt(input, limits), grow: growText(input.kept, input.text, input.why) },
    growSchema,
    (v) => growProblems(v as GrowAnswer, input.kept, limits),
    opts,
  );
}

/** What the Foreman gives grow(): its log, its state, and the planner's input as a re-plan would build it. */
export interface GrowHost {
  readonly s: JobState;
  readonly builder: Builder;
  readonly model?: string;
  readonly limits: GenerateOptions & PlanLimits;
  plannerInput(): PlannerInput | undefined;
  append(body: Parameters<JobLog["append"]>[0]): JobEvent;
  logGenerateCalls(calls: GenerateCall[], model: string | undefined): void;
}

/**
 * Grows the plan for change request `c` (its owner answer was NEW_PACKAGE). Returns the new package ids, or a reason
 * why nothing was added (the caller then gives the request to the root package, as before). `head` starts the new
 * packages' `reopened` reason: the change request's (default) or a phase hold's (`phase hold (event N) on phase P`).
 */
export async function grow(h: GrowHost, c: { seq: number; text: string }, why: string, head = changeReason(c.seq)): Promise<{ added: string[] } | { reason: string }> {
  const base = h.plannerInput();
  if (base === undefined) return { reason: "the log has no brief to plan from" };
  const kept = h.s.plan;
  const res = await growPackages(h.builder, { ...base, kept, text: c.text, why }, { ...h.limits, ...(h.model ? { model: h.model } : {}) });
  h.logGenerateCalls(res.calls, h.model);
  if (!res.ok) return { reason: `the Planner could not add a package (${clip(res.reason, 200)})` };
  const fresh = res.value.packages;
  h.append({ type: "plan_set", packages: [...kept, ...fresh], ...(h.s.card !== undefined ? { card: h.s.card } : {}), ...replanPhases(h.s, fresh, new Set()) });
  for (const p of fresh) {
    h.append({ type: "reopened", package: p.id, reason: clip(`${head}; ${GROW_WORDS} (${why}): ${c.text}`, 600) });
    h.append({ type: "package_state", package: p.id, state: "queued", round: 1, detail: clip(`${CHANGE_ROUND}: ${c.text}`, 1500) });
  }
  for (const w of res.value.wire ?? []) {
    const names = fresh.map((p) => p.id).join(", ");
    h.append({ type: "change_requested", package: w, text: clip(`${FOREMAN_NOTE}wire in ${fresh[0]?.id ?? names} (added for ${head.startsWith("phase hold") ? "phase hold" : "change request"} event ${c.seq}; new: ${names}): call it as its contract says, so that "${c.text}" happens in the game`, 1000) });
  }
  return { added: fresh.map((p) => p.id) };
}

/** A Foreman wire request waits until the package it wires in is merged. */
export function wireWaits(s: JobState, text: string): boolean {
  const m = WIRE_RE.exec(text);
  if (!m) return false;
  const p = s.packages[m[1] as string];
  return p !== undefined && p.state !== "promoted";
}
