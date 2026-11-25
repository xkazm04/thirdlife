// E3 of 24-25 Nov: the plan of a game on a core (coreroute.ts), as the plan check and the Planner prompt read it. Out of
// designer.ts (its size ratchet), which calls these at four places: the core route of a plan, the core problems of a
// plan, the packages a builder builds, the Planner's sections.
import type { Brief, PackageSpec, Phase } from "./events.js";
import type { ConceptTemplate } from "./room_wire.js";
import { coreRouteOf, templateOf } from "./templates.js";
import { baseRefDir, coreLinesText, corePlanProblems, isBase, normalizeCorePlan as normalizeWith, type CoreRoute } from "./coreroute.js";
export { overlapAllowed } from "./coreroute.js";

/** A plan's limits as these read them (designer.ts PlanLimits). */
interface CoreLimits {
  template?: ConceptTemplate;
  refDir?: string;
  cards?: string[];
}

/** E3 of 24 Nov: the core route of a plan's template and the base in the job's reference copy (undefined: a hand-built game). */
export function planCore(limits: Pick<CoreLimits, "template" | "refDir">): { route: CoreRoute; baseDir?: string } | undefined {
  const route = coreRouteOf(limits.template);
  if (route === undefined) return undefined;
  return { route, ...(limits.refDir !== undefined ? { baseDir: baseRefDir(limits.refDir, route) } : {}) };
}

/** The base package of a core plan fixed from the job's base (unchanged without a core or a base). */
export const normalizeCorePlan = <T extends { packages: PackageSpec[] }>(plan: T, core: { route: CoreRoute; baseDir?: string } | undefined): T => normalizeWith(plan, core?.route, core?.baseDir);

/** The package limit (`maxPackages`) counts the packages a builder builds: all of them, less the base of a core plan. */
export function packageLimitProblems(packages: PackageSpec[], limits: CoreLimits & { maxPackages?: number }): string[] {
  const built = planCore(limits) !== undefined ? packages.filter((p) => !isBase(p)).length : packages.length;
  if (limits.maxPackages === undefined || built <= limits.maxPackages) return [];
  return [`the plan has ${built} packages${built !== packages.length ? " a builder builds (the base is the Foreman's)" : ""}; the limit for this job is ${limits.maxPackages}: merge concerns until it fits`];
}

/** The core problems of a plan: the shape on a core and its card; a base package in a hand-built game is refused. */
export function corePlanCheck(packages: PackageSpec[], limits: CoreLimits, card: unknown, phases: Phase[] | undefined): string[] {
  const core = planCore(limits);
  if (core === undefined) return packages.filter(isBase).map((p) => `package "${p.id}" is of kind "base", but this game is not on a core (its template names no base): every package is built by a builder`);
  const out = corePlanProblems(packages, phases, core.route, core.baseDir);
  const want = templateOf(limits.template?.id)?.card;
  if (want !== undefined && (limits.cards ?? []).includes(want) && card !== want) out.push(`a game on the ${core.route.core} core names its card: "card": "${want}"${typeof card === "string" ? ` (not ${card}: that card builds a hand-made game)` : ""}`);
  return out;
}

/** E3 of 24 Nov: the tofu section of a core plan's Planner prompt: there is no tofu stage; the core carries the feel. */
export function coreTofuText(template: ConceptTemplate | undefined): string | undefined {
  const r = coreRouteOf(template);
  if (r === undefined) return undefined;
  return `No tofu stage: this game is on the ${r.core} core, whose simulation and bots carry the feel (the house game engine/packs/${r.house} plays like thirdjam). No package is milestone \`blockout\` and no contract carries a TOFU CHECK line. The first phase is the base with this game's cartridge (milestone \`greybox\`): playable at once, measured by \`${r.check}\` beside the house game's cartridge, then played by a person.`;
}

/** E3 of 24 Nov: the Planner's "game on a core" section ("" for a hand-built game). */
export function corePlannerText(brief: Brief): string {
  const r = coreRouteOf(brief.concept?.template);
  if (r === undefined) return "";
  const lines = coreLinesText(brief.rules);
  return [
    "",
    `# This game is ON THE ${r.core.toUpperCase()} CORE: plan it cartridge first`,
    `The game is a cartridge over the base engine/templates/${r.base}/ (the job's ref/base/${r.base}/), never a new simulation. The plan has this shape, and the plan check refuses any other:`,
    `1. **Package 1, "start from the base"**: \`{"id": "base", "kind": "base", "title": "Start from the ${r.base} base", "milestone": "greybox", "deps": [], "scope": ["scripts/**"], "contract": "start from the base", "acceptance": []}\`. The Foreman executes it itself (no builder, no tokens): it copies the base whole and fixes this package's scope, registers, contract and acceptance from the base (lint, smoke, the base's first-match bot). It is the root; every other package depends on it. It does not count against the package limit.`,
    `2. **The cartridge package**: scope \`data/<name>.cartridge.json\` (the base's own cartridge, or a new file named for this game together with the base's data line that names which cartridge the match plays: the base's README says which) plus, when the brief changes a Third Life switch, \`data/<name>.rules.json\`. Its contract lists the brief's CARTRIDGE lines as key paths and values, names the nearest of thirdjam's modes to copy (ref/cores/${r.core}/modes/MODES.md) and keeps every other key the base's. Its acceptance runs the base's bots: \`bot --test=tests/bot_first_match.gd\` and the PLAYER CHECK bot the base's contract names. It is in the first phase with the base: the greybox is the base with this game's cartridge.`,
    `3. **The skin package** (in the first phase too, or the second): scope \`data/skin.json\`: the brief's SKIN lines (title, team names, colours, words).`,
    `4. Only when the brief asks for something the cartridge and the skin cannot say, ONE small package with a script (scope \`scripts/<name>.gd\` and the data it reads); never a skating, puck, contact, bot or camera script: those are the core's. Scopes of later packages may name files inside the base's scope: the base yields them.`,
    "Every cartridge or rules file a builder writes is validated by the Foreman before lint and smoke (foreman/src/cartridge.ts, lane E2), and every look runs the measured check on the game's cartridge beside the house game's. Name the card of this route in the answer.",
    ...(lines !== "" ? ["What the design changes (the brief's CARTRIDGE and SKIN lines):", lines] : []),
  ].join("\n");
}
