// E3 of 24-25 Nov (lane "route"): the Foreman's route from a sentence to a game ON A CORE. The owner, 24 Nov ~23:20:
// "game like this can be built by user from the editor". DIRECTIONS.md direction 10: a few deep cores, many cartridges.
// A user's game on the rink core is a CARTRIDGE (engine/cores/rink, `tj.cartridge/1`, optional `tl.rink.rules/1` sidecar)
// over a working BASE (engine/templates/rink_game, lane E1: hokej made skinnable) plus a SKIN (data/skin.json): never a
// fresh hand-written simulation. So the plan of a core game is:
//   1. "start from the base": a package of kind "base" the Foreman executes itself (no builder): the job's reference copy
//      of the base (ref/base/<base>/) is copied into its workspace and verified and merged like any package;
//   2. small packages that edit data/<name>.cartridge.json, data/skin.json, an optional data/<name>.rules.json, and only
//      when needed a small script. Their scopes may lie inside the base's scope: the base yields those files.
// A cartridge edit is validated before any runner verb (lane E2's foreman/src/cartridge.ts; until it lands, the
// envelope check below), and a milestone look runs lane E2's measured check (`bash engine/tools/rink.sh check-cartridge
// <file>`) on the game's cartridge beside the same check on the house game's (engine/packs/hokej).
// Pure apart from reading files and the one process the measured check starts.
import { execFile } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import type { PackageSpec, Phase, Registers } from "./events.js";
import { copyDir, globToRegExp, listFiles, matchesAny } from "./scope.js";
import { REPO_ROOT, stripBom, toPosix } from "./paths.js";
import { validateCartridgeText, validateRulesText } from "./cartridge.js"; // lane E2: the core's own verdicts
import { grossDefects, type RinkCheckFacts } from "./rinkjudge.js"; // E3d: what acts on a check

/** The package kind the Foreman executes itself. */
export const BASE_KIND = "base";

/** One core route: the core, the base a job starts from, the house game, the documents builders read. */
export interface CoreRoute {
  /** The core id (`ctx.cores.open(<core>, ...)`): engine/cores/<core>/. */
  core: string;
  /** The base a job starts from: engine/templates/<base>/ (copied to the job's ref/base/<base>/). */
  base: string;
  /** The house game on the core: engine/packs/<house>/ (copied to ref/packs/<house>/ by its card). */
  house: string;
  /** The house game's cartridge, pack-relative: the measured check's other side. */
  houseCartridge: string;
  /** Engine-relative documents and folders a job's reference copy carries (to the same place under ref/), when present. */
  docs: { src: string; dest: string; what: string }[];
  /** The measured check, engine-relative, as a person types it (`<file>` is the cartridge). */
  check: string;
}

export const RINK_ROUTE: CoreRoute = {
  core: "rink",
  base: "rink_game",
  house: "hokej",
  houseCartridge: "data/hockey.thirdlife.cartridge.json",
  docs: [
    { src: "cores/rink/SNAPSHOT.md", dest: "cores/rink/SNAPSHOT.md", what: "the core's GDScript surface and every field of its per-frame snapshot" },
    { src: "cores/rink/GAMEMODE.md", dest: "cores/rink/GAMEMODE.md", what: "what is play (the core) and what is presentation (the pack): the shell's whole job" },
    { src: "cores/rink/CARTRIDGE.md", dest: "cores/rink/CARTRIDGE.md", what: "the cartridge catalog in player words: every key, its limits, what a person feels when it changes (lane E2)" },
    { src: "cores/rink/schema", dest: "cores/rink/schema", what: "the cartridge's readable schema and limits (lane E2, from JamSchemaData.inl)" },
    { src: "cores/rink/native/content/Cartridges/modes", dest: "cores/rink/modes", what: "thirdjam's twelve mode cartridges and MODES.md: each a full cut of hockey.regular with only the listed keys changed (the worked examples)" },
  ],
  check: "bash engine/tools/rink.sh check-cartridge <file>",
};

export const CORE_ROUTES: CoreRoute[] = [RINK_ROUTE];

/** The job's copy of the base: ref/base/<base>/. */
export const baseRefDir = (refDir: string, route: CoreRoute): string => path.join(refDir, "base", route.base);
/** The engine's base: engine/templates/<base>/. */
export const baseEngineDir = (engineDir: string, route: CoreRoute): string => path.join(engineDir, "templates", route.base);
/** True when a base directory holds a pack (its pack.json). */
export const hasBase = (dir: string): boolean => fs.existsSync(path.join(dir, "pack.json"));

const readJson = (file: string): unknown => JSON.parse(stripBom(fs.readFileSync(file, "utf8")));

/** Top-level files of a base that are not copied into a job's pack: the manifest (the Foreman composes it) and documents. */
const notCopied = (rel: string): boolean => rel === "pack.json" || (!rel.includes("/") && /\.(md|txt)$/i.test(rel)) || rel.split("/").includes(".godot") || rel.endsWith(".import") || rel.endsWith(".uid");

/** The files of a base that a job's pack gets (pack-relative, sorted). */
export function baseFiles(baseDir: string): string[] {
  return listFiles(baseDir).filter((f) => !notCopied(f));
}

/** The base package's scope: one glob per top-level directory of the base, a literal per top-level file. */
export function baseScope(baseDir: string): string[] {
  const out = new Set<string>();
  for (const f of baseFiles(baseDir)) out.add(f.includes("/") ? `${f.split("/")[0]}/**` : f);
  return [...out].sort();
}

/** What the base's own manifest registers (capabilities, generators, bots, cameras). */
export function baseRegisters(baseDir: string): Registers {
  try {
    const m = readJson(path.join(baseDir, "pack.json")) as { capabilities?: string[]; assets?: string[]; tests?: string[]; cameras?: string[] };
    return {
      ...(m.capabilities?.length ? { capabilities: [...m.capabilities] } : {}),
      ...(m.assets?.length ? { assets: [...m.assets] } : {}),
      ...(m.tests?.length ? { tests: [...m.tests] } : {}),
      ...(m.cameras?.length ? { cameras: [...m.cameras] } : {}),
    };
  } catch {
    return {};
  }
}

/** The base's bots a cartridge package runs (the floor): first match and match bot first, then the rest in manifest order. */
export function baseBots(baseDir: string): string[] {
  const tests = baseRegisters(baseDir).tests ?? [];
  const first = ["tests/bot_first_match.gd", "tests/bot_match_hand.gd"].filter((t) => tests.includes(t));
  return [...first, ...tests.filter((t) => !first.includes(t))];
}

/** The base's cartridges (data/*.cartridge.json) and the one its data names as the game's (skin.json or match.json `cartridge`). */
export function baseCartridges(baseDir: string): { all: string[]; game?: string } {
  const all = baseFiles(baseDir).filter((f) => /^data\/[^/]+\.cartridge\.json$/.test(f));
  for (const f of ["data/skin.json", "data/match.json"]) {
    try {
      const c = (readJson(path.join(baseDir, f)) as { cartridge?: unknown }).cartridge;
      if (typeof c === "string" && all.includes(`data/${c}`)) return { all, game: `data/${c}` };
    } catch {
      /* not there */
    }
  }
  return { all, ...(all.length === 1 ? { game: all[0] as string } : {}) };
}

/**
 * The base's player check: a `PLAYER CHECK: tests/<bot>.gd fails when ...` line one of its bots carries (in a comment),
 * else the house bot whose `ok` needs the human's carry and shot (hokej's tests/bot_match_hand.gd), else undefined.
 */
export function basePlayerCheck(baseDir: string): string | undefined {
  const tests = baseRegisters(baseDir).tests ?? [];
  for (const t of tests) {
    try {
      const m = /PLAYER CHECK:\s*(tests\/[A-Za-z0-9_/.-]+\.gd)\s+(fails when .+?)\s*$/m.exec(fs.readFileSync(path.join(baseDir, ...t.split("/")), "utf8"));
      if (m && tests.includes(m[1] as string)) return `PLAYER CHECK: ${m[1]} ${m[2]}`;
    } catch {
      /* unreadable test: no line */
    }
  }
  return tests.includes("tests/bot_match_hand.gd") ? "PLAYER CHECK: tests/bot_match_hand.gd fails when the human's skater never carried the puck or took no shot" : undefined;
}

/** The base package of a core plan, as the Foreman fixes it (the Planner's id, title and serves are kept). */
export function basePackage(route: CoreRoute, baseDir: string, planned?: Partial<PackageSpec>): PackageSpec {
  const bots = baseBots(baseDir).slice(0, 1);
  const registers = baseRegisters(baseDir);
  const player = basePlayerCheck(baseDir);
  return {
    id: planned?.id ?? "base",
    kind: BASE_KIND,
    title: planned?.title ?? `Start from the ${route.base} base`,
    milestone: "greybox",
    deps: [],
    scope: baseScope(baseDir),
    contract: `Start from the base: the Foreman copies engine/templates/${route.base}/ (the job's ref/base/${route.base}/) into the pack whole, as it is: a working game on the ${route.core} core (ctx.cores.open("${route.core}", <cartridge>)). No builder runs for this package. Later packages change the game by editing the base's data: the cartridge (data/<name>.cartridge.json), the skin (data/skin.json), an optional rules sidecar (data/<name>.rules.json); a file a later package's scope names is that package's from then on. The base's bots: ${(registers.tests ?? []).join(", ") || "none"}.${player !== undefined ? `\n${player}` : ""}`,
    acceptance: [{ level: "V1", verb: "lint", args: [] }, { level: "V2", verb: "smoke", args: [] }, ...bots.map((t) => ({ level: "V4" as const, verb: "bot" as const, args: [`--test=${t}`] }))],
    ...(Object.keys(registers).length > 0 ? { registers } : {}),
    ...(planned?.serves !== undefined ? { serves: planned.serves } : {}),
  };
}

export const isBase = (p: Pick<PackageSpec, "kind">): boolean => p.kind === BASE_KIND;

/** A core plan with its base package fixed from the base (unchanged when there is no base package or no base). */
export function normalizeCorePlan<T extends { packages: PackageSpec[] }>(plan: T, route: CoreRoute | undefined, baseDir: string | undefined): T {
  if (route === undefined || baseDir === undefined || !hasBase(baseDir)) return plan;
  // E5 (25 Nov, the first real core job): the Planner gave the cartridge package `invariants`; the base itself fails its
  // frame budgets (thirdjam's whole match: p50 3.5 ms against the 1 ms of "one of many", p99 4.07 against 4), so no data
  // edit could pass it and the builder blocked on a question no person can answer. A core game is held to what the base
  // is held to: invariants is dropped from every package (the base's own acceptance is lint, smoke and its bot).
  const held = (p: PackageSpec): PackageSpec => (p.acceptance.some((a) => a.verb === "invariants") ? { ...p, acceptance: p.acceptance.filter((a) => a.verb !== "invariants") } : p);
  return { ...plan, packages: plan.packages.map((p) => (isBase(p) ? basePackage(route, baseDir, p) : held(p))) };
}

/** Files a core game's later packages edit: the cartridge, the rules sidecar, the skin. */
export const CORE_DATA_RE = /^data\/(?:[^/]+\.cartridge\.json|[^/]+\.rules\.json|skin\.json)$/;
const CARTRIDGE_RE = /^data\/[^/]+\.cartridge\.json$/;

/**
 * Problems of a plan on a core: one base package, the root; a package that owns the game's cartridge, in the first
 * phase with the base (the greybox is the base with the game's cartridge: playable at once); no blockout milestone.
 */
export function corePlanProblems(packages: PackageSpec[], phases: Phase[] | undefined, route: CoreRoute, baseDir: string | undefined): string[] {
  const out: string[] = [];
  const bases = packages.filter(isBase);
  const where = `engine/templates/${route.base}`;
  if (baseDir === undefined || !hasBase(baseDir)) out.push(`this game is on the ${route.core} core, but the job's reference copy has no base (ref/base/${route.base}/ from ${where}/): the core route cannot start (lane E1's base has not landed in this engine)`);
  if (bases.length !== 1) out.push(`a game on the ${route.core} core starts from the base: exactly one package of kind "${BASE_KIND}" (found ${bases.length}): {"id": "base", "kind": "${BASE_KIND}", "title": "Start from the ${route.base} base", "milestone": "greybox", "deps": [], "scope": ["scripts/**"], "contract": "start from the base", "acceptance": []} (the Foreman fixes its scope, registers and acceptance from ${where})`);
  const base = bases[0];
  if (base !== undefined && base.deps.length > 0) out.push(`the base package "${base.id}" is the root: it has no deps`);
  for (const p of packages) if (p.milestone === "blockout") out.push(`package "${p.id}" is milestone "blockout": a game on a core has no tofu stage (the core carries the feel); the first phase is the base with the game's cartridge, milestone "greybox"`);
  const rest = packages.filter((p) => !isBase(p));
  const owners = rest.filter((p) => p.scope.some((g) => CARTRIDGE_RE.test(g) || (/[*?]/.test(g) && ["data/game.cartridge.json"].some((f) => globToRegExp(g).test(f)))));
  if (rest.length === 0) out.push(`the plan only starts from the base: add the package that writes this game's cartridge (scope data/<name>.cartridge.json; the base's cartridge is the starting point)`);
  else if (owners.length === 0) out.push(`no package owns the game's cartridge: one package's scope names data/<name>.cartridge.json (the keys the brief's CARTRIDGE lines change)`);
  for (const p of rest) {
    if (base !== undefined && !p.deps.includes(base.id) && !p.deps.some((d) => packages.find((x) => x.id === d) !== undefined)) out.push(`package "${p.id}" must depend on the base "${base.id}" (directly or through another package)`);
    const code = p.scope.filter((g) => !CORE_DATA_RE.test(g) && !/^data\//.test(g));
    if (code.some((g) => /^(assets|gen)\//.test(g))) out.push(`package "${p.id}": a game on a core changes data and, only if needed, a small script; assets/ and gen/ are the base's (scope ${code.join(", ")})`);
  }
  const first = phases?.[0];
  if (first !== undefined && base !== undefined) {
    if (!first.packages.includes(base.id)) out.push(`the first phase "${first.id}" holds the base package "${base.id}"`);
    if (owners.length > 0 && !owners.some((o) => first.packages.includes(o.id))) out.push(`the first phase "${first.id}" holds the package that writes the game's cartridge (${owners.map((o) => o.id).join(" or ")}): the greybox is the base with the game's cartridge, playable at once`);
  }
  return out;
}

/** True when a scope overlap between two packages is allowed: one of them is the base, which yields the files. */
export const overlapAllowed = (a: Pick<PackageSpec, "kind">, b: Pick<PackageSpec, "kind">): boolean => isBase(a) || isBase(b);

// ---------- the brief: the cartridge keys and skin fields the game changes ----------

export interface CoreLines {
  cartridge: { path: string; value: string }[];
  skin: { field: string; value: string }[];
}

/** The CARTRIDGE and SKIN lines of a brief's rules text (after the method lines): `CARTRIDGE: game.rink.length_m = 60 (why)`. */
export function coreLines(rules: string | undefined): CoreLines {
  const out: CoreLines = { cartridge: [], skin: [] };
  for (const raw of (rules ?? "").split(/\r?\n/)) {
    const m = /^\s*(?:[-*]\s*)?(CARTRIDGE|SKIN)\s*:\s*([A-Za-z_][A-Za-z0-9_.[\]]*)\s*(?:=|:|->|to)?\s*(.*?)\s*$/.exec(raw);
    if (!m) continue;
    if (m[1] === "CARTRIDGE") out.cartridge.push({ path: m[2] as string, value: m[3] as string });
    else out.skin.push({ field: m[2] as string, value: m[3] as string });
  }
  return out;
}

/** Every key path of a JSON document: objects dotted, arrays as `[]` (`game.teams[]`, `game.teams[].skaters[]`). */
export function keyPaths(doc: unknown, at = "", out = new Set<string>()): Set<string> {
  if (Array.isArray(doc)) {
    if (at !== "") out.add(at);
    out.add(`${at}[]`);
    for (const x of doc) keyPaths(x, `${at}[]`, out);
  } else if (doc !== null && typeof doc === "object") {
    if (at !== "") out.add(at);
    for (const [k, v] of Object.entries(doc as Record<string, unknown>)) keyPaths(v, at === "" ? k : `${at}.${k}`, out);
  } else if (at !== "") out.add(at);
  return out;
}

/**
 * The key paths of a JSON schema (properties, items, $defs followed one level by name). With `dir`, a `$ref` that names
 * a sibling schema file (`"game.schema.json"`, E5 25 Nov: the cartridge envelope's `game` is one) is read from there:
 * without it every game.* key of the schema was unknown and the first real Designer was refused three times for
 * game.effects, game.rules.hooks and game.contact.*_windup_frames, which CARTRIDGE.md lists.
 */
export function schemaPaths(schema: unknown, at = "", out = new Set<string>(), defs?: Record<string, unknown>, depth = 0, dir?: string): Set<string> {
  if (depth > 12 || schema === null || typeof schema !== "object") return out;
  const s = schema as Record<string, unknown>;
  const d = defs ?? ((s["$defs"] ?? s["definitions"]) as Record<string, unknown> | undefined);
  const raw = typeof s["$ref"] === "string" ? (s["$ref"] as string) : undefined;
  const ref = raw !== undefined ? /#\/(?:\$defs|definitions)\/(.+)$/.exec(raw)?.[1] : undefined;
  if (ref !== undefined && d?.[ref] !== undefined) return schemaPaths(d[ref], at, out, d, depth + 1, dir);
  if (raw !== undefined && dir !== undefined && /^[\w.-]+\.json$/.test(raw) && fs.existsSync(path.join(dir, raw))) {
    try {
      return schemaPaths(readJson(path.join(dir, raw)), at, out, undefined, depth + 1, dir);
    } catch {
      /* unreadable: no paths below */
    }
  }
  if (at !== "") out.add(at);
  for (const [k, v] of Object.entries((s["properties"] ?? {}) as Record<string, unknown>)) schemaPaths(v, at === "" ? k : `${at}.${k}`, out, d, depth + 1, dir);
  if (s["items"] !== undefined) schemaPaths(s["items"], `${at}[]`, out, d, depth + 1, dir);
  for (const k of ["allOf", "anyOf", "oneOf"]) for (const x of (s[k] ?? []) as unknown[]) schemaPaths(x, at, out, d, depth + 1, dir);
  return out;
}

/** The cartridge key paths the engine knows: the house game's cartridge, the mode cartridges, lane E2's schema (when there). */
export function knownCartridgePaths(engineDir: string, route: CoreRoute = RINK_ROUTE): Set<string> {
  const out = new Set<string>();
  const files = [path.join(engineDir, "packs", route.house, ...route.houseCartridge.split("/"))];
  const modes = path.join(engineDir, ...((route.docs.find((d) => d.dest.endsWith("/modes"))?.src ?? "").split("/")));
  if (fs.existsSync(modes)) for (const f of listFiles(modes)) if (f.endsWith(".cartridge.json")) files.push(path.join(modes, f));
  for (const f of files) {
    try {
      keyPaths(readJson(f), "", out);
    } catch {
      /* unreadable: no paths */
    }
  }
  const schemaDir = path.join(engineDir, "cores", route.core, "schema");
  if (fs.existsSync(schemaDir)) {
    for (const f of listFiles(schemaDir).filter((x) => /cartridge.*\.schema\.json$/.test(x))) {
      try {
        schemaPaths(readJson(path.join(schemaDir, f)), "", out, undefined, 0, schemaDir);
      } catch {
        /* unreadable schema: no paths */
      }
    }
  }
  return out;
}

/** A path the brief names, normalised (`game.teams[0].skaters` -> `game.teams[].skaters`). */
const norm = (p: string): string => p.replace(/\[\d*\]/g, "[]");

/** True when `p` is a known path, or a known path lies under it, or it lies under a known list (`game.teams[]...`). */
export function knownPath(p: string, known: Set<string>): boolean {
  const n = norm(p);
  if (known.has(n)) return true;
  for (const k of known) {
    if (k.startsWith(`${n}.`) || k.startsWith(`${n}[]`)) return true;
    if (k.endsWith("[]") && n.startsWith(k)) return true;
  }
  return false;
}

/** The base's skin fields (data/skin.json top-level keys and one level below), or undefined when the base has no skin. */
export function skinFields(baseDir: string | undefined): Set<string> | undefined {
  if (baseDir === undefined) return undefined;
  const file = path.join(baseDir, "data", "skin.json");
  if (!fs.existsSync(file)) return undefined;
  try {
    const out = keyPaths(readJson(file));
    // E5c (25 Nov): the optional keys the base's skin reader declares but its data/skin.json leaves out (E1b's
    // `team_plural`): the Designer reads them in the base's README and was refused for them twice
    const reader = path.join(baseDir, "scripts", "hud", "skin.gd");
    if (fs.existsSync(reader)) for (const m of fs.readFileSync(reader, "utf8").matchAll(/"([a-z_]+)":\s*TYPE_[A-Z]+/g)) out.add(m[1] as string);
    return out;
  } catch {
    return undefined;
  }
}

/** E5c: the README calls `levels` "the level row's words"; the Designer writes `SKIN: level words = ...` (field "level"). */
const skinAlias = (field: string, skin: Set<string>): boolean => field === "level" && skin.has("levels");

export const CORE_LIMITS = { cartridgeLines: [1, 16], skinLines: [1, 10] } as const;

/**
 * The design step's checks of a core brief: 1 to 16 CARTRIDGE lines naming known key paths, 1 to 10 SKIN lines naming
 * the base's skin fields (when the base is there: lane E1). Lines go in brief.rules after the method lines.
 */
export function coreBriefProblems(rules: string, route: CoreRoute, engineDir: string): string[] {
  const l = coreLines(rules);
  const out: string[] = [];
  const need = `a game on the ${route.core} core names what it changes in the base, in brief.rules after the method lines, one per line`;
  if (l.cartridge.length < CORE_LIMITS.cartridgeLines[0] || l.cartridge.length > CORE_LIMITS.cartridgeLines[1]) out.push(`${need}: 1 to 16 "CARTRIDGE: <key path> = <value> (what the player feels)" lines, for example "CARTRIDGE: game.rink.length_m = 60 (a pond, every pass reaches)" (found ${l.cartridge.length})`);
  if (l.skin.length < CORE_LIMITS.skinLines[0] || l.skin.length > CORE_LIMITS.skinLines[1]) out.push(`${need}: 1 to 10 "SKIN: <field> = <value>" lines (the title, team names, colours, words), for example "SKIN: title = POND" (found ${l.skin.length})`);
  const known = knownCartridgePaths(engineDir, route);
  if (known.size > 0) {
    for (const c of l.cartridge) if (!knownPath(c.path, known)) out.push(`CARTRIDGE line names "${c.path}", which is not a key of the ${route.core} cartridge (tj.cartridge/1: see ${route.docs[2]?.src ?? "the catalog"} and the modes); keys start at the envelope (title, theme) or at game. (game.rink, game.teams, game.skater, game.rules, game.look, ...)`);
  }
  const skin = skinFields(baseEngineDir(engineDir, route));
  if (skin !== undefined) for (const s of l.skin) if (!knownPath(s.field, skin) && !skinAlias(s.field, skin)) out.push(`SKIN line names "${s.field}", which is not a field of the base's data/skin.json (${[...skin].filter((x) => !x.includes(".")).join(", ")})`);
  return out;
}

/** The core lines as the Planner and the builders read them ("" without any). */
export function coreLinesText(rules: string | undefined): string {
  const l = coreLines(rules);
  if (l.cartridge.length + l.skin.length === 0) return "";
  return [...l.cartridge.map((c) => `- cartridge ${c.path}: ${c.value}`), ...l.skin.map((s) => `- skin ${s.field}: ${s.value}`)].join("\n");
}

// ---------- the base package's execution ----------

/**
 * The base package's round: the base's files copied into the workspace, except the files a later package of the plan
 * owns that pack/ already holds (those are that package's now: a re-run of the base never undoes a cartridge edit).
 * Returns what was copied and why nothing could be.
 */
export function startFromBase(ws: string, refDir: string, packDir: string, spec: PackageSpec, plan: readonly PackageSpec[], route: CoreRoute | undefined): { ok: boolean; text: string; files: string[] } {
  if (route === undefined) return { ok: false, text: `package "${spec.id}" is of kind "${BASE_KIND}", but the job's template names no core route`, files: [] };
  const src = baseRefDir(refDir, route);
  if (!hasBase(src)) return { ok: false, text: `start from the base: the job's reference copy has no ref/base/${route.base}/ (engine/templates/${route.base}, lane E1, is not in this engine)`, files: [] };
  const others = plan.filter((p) => p.id !== spec.id).flatMap((p) => p.scope);
  const copied: string[] = [];
  const kept: string[] = [];
  for (const f of baseFiles(src)) {
    if (!matchesAny(spec.scope, f)) continue;
    if (matchesAny(others, f) && fs.existsSync(path.join(packDir, f))) {
      // E3f (E5b job 2): "kept" means the workspace holds pack/'s file, not the base's copy left from round 1.
      fs.mkdirSync(path.dirname(path.join(ws, ...f.split("/"))), { recursive: true });
      fs.copyFileSync(path.join(packDir, ...f.split("/")), path.join(ws, ...f.split("/")));
      kept.push(f);
      continue;
    }
    const dest = path.join(ws, ...f.split("/"));
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(path.join(src, ...f.split("/")), dest);
    copied.push(f);
  }
  return { ok: true, files: copied, text: `started from the base engine/templates/${route.base}/ (ref/base/${route.base}/): ${copied.length} file(s) copied, no builder${kept.length > 0 ? `; kept as pack/ holds them (later packages own them): ${kept.join(", ")}` : ""}` };
}

// ---------- the cartridge edit: validated before any runner verb ----------

export interface CartridgeVerdict {
  file: string;
  /** Lane E2's sentences, each starting with a JSON pointer ("at /game/skater/speeed: unknown key ..."): a model repairs from them. */
  problems: string[];
  /** Who checked: thirdjam's validator for a cartridge, the core's rules reader for a sidecar (foreman/src/cartridge.ts). */
  by: string;
}

/** One cartridge or rules file of a workspace, checked as the core checks it (lane E2's foreman/src/cartridge.ts). */
export async function validateCartridgeFile(dir: string, file: string): Promise<CartridgeVerdict> {
  const text = stripBom(fs.readFileSync(path.join(dir, ...file.split("/")), "utf8"));
  if (file.endsWith(".rules.json")) return { file, problems: validateRulesText(text).errors, by: "the core's rules reader (foreman/src/cartridge.ts validateRulesText)" };
  return { file, problems: (await validateCartridgeText(text)).errors, by: "thirdjam's validator (foreman/src/cartridge.ts validateCartridgeText)" };
}

/** The cartridge and rules files among `files` (pack-relative). */
export const coreDataFiles = (files: string[]): string[] => files.filter((f) => /^data\/[^/]+\.(cartridge|rules)\.json$/.test(f)).sort();

/** The start of the Foreman's note (after FOREMAN_NOTE) when a round's cartridge edit did not validate. */
export const CARTRIDGE_INVALID = "cartridge edit not valid";

// ---------- the measured check (lane E2's lab: `rink.sh check-cartridge`, a tl.rink.check/1 line last) ----------

export interface CoreCheckRun {
  /** 0 measured, 1 refused or a match did not end, 2 could not run (check_cartridge.mjs's exit codes). */
  code: number;
  /** The figures a person will meet, read through thirdjam's regular playtester at pro (`pro_*`) and its wins at each level. */
  figures: Record<string, number>;
  /** One line: what it said (its warnings, its problems, or why it could not run). */
  summary: string;
  /** E3d: the gross defects (rinkjudge.ts) that make a measured cartridge fail (code 1): goals, no end, won idle or skating. */
  defects?: string[];
}

interface RinkCheckLine extends RinkCheckFacts {
  tool?: string;
  ok?: boolean;
  ran?: boolean;
  why?: string;
  refused?: string[];
  warnings?: string[];
  problems?: string[];
}

/** The last `{"tool":"tl.rink.check/1", ...}` line of a check's output, or undefined. */
export function rinkCheckLine(stdout: string): RinkCheckLine | undefined {
  for (const l of stdout.split(/\r?\n/).map((x) => x.trim()).filter((x) => x.startsWith("{")).reverse()) {
    try {
      const j = JSON.parse(l) as RinkCheckLine;
      if (j.tool === "tl.rink.check/1") return j;
    } catch {
      /* not the line */
    }
  }
  return undefined;
}

/** The figures of a tl.rink.check/1 line: the pro playtester's match figures, and the wins of each level. */
export function figuresOf(line: RinkCheckLine | undefined): Record<string, number> {
  const out: Record<string, number> = {};
  for (const [lv, l] of Object.entries(line?.levels ?? {})) {
    const p = l.playtester;
    if (p === undefined) continue;
    if (typeof p["wins"] === "number" && typeof p["matches"] === "number") out[`${lv}_wins_of_${p["matches"]}`] = p["wins"];
    if (lv !== "pro") continue;
    if (typeof p["goals_for"] === "number" && typeof p["goals_against"] === "number") out["pro_goals_a_match"] = Math.round((p["goals_for"] + p["goals_against"]) * 10) / 10;
    for (const k of ["minutes", "carry_s", "loose_share", "shots", "passes_completed", "speed_mean", "changes_min", "human_touches_min", "knockdowns"]) if (typeof p[k] === "number") out[`pro_${k}`] = p[k] as number;
  }
  return out;
}

/** What a check's line and exit code mean, as a run. */
export function rinkCheckRun(code: number, stdout: string, asked?: string): CoreCheckRun {
  const line = rinkCheckLine(stdout);
  if (line === undefined) return { code: 2, figures: {}, summary: `could not run: no tl.rink.check/1 line in its output (exit ${code}): ${stdout.trim().split(/\r?\n/).slice(-2).join(" | ").slice(0, 300)}` };
  const c = code === 0 && line.ok === true ? 0 : line.ran === false && line.refused === undefined ? 2 : code === 0 ? 1 : code === 1 ? 1 : 2;
  const said = c === 2 ? `could not run: ${line.why ?? `exit ${code}`}` : line.refused !== undefined ? `refused by thirdjam's validator: ${line.refused.slice(0, 4).join("; ")}` : (line.problems ?? []).length > 0 ? `did not complete: ${(line.problems ?? []).join("; ")}` : (line.warnings ?? []).length > 0 ? `measured, warnings: ${(line.warnings ?? []).join("; ")}` : "measured, no warning";
  const figures = figuresOf(line);
  for (const [k, cell] of Object.entries(line.defects ?? {})) if (cell !== undefined) figures[`${k}_wins_of_${cell.matches}`] = cell.wins;
  // E3d: a measured cartridge with a gross defect fails (code 1), with the defects first; the rest stays words.
  const judged = c === 0 ? grossDefects(line, asked) : { defects: [], notes: [] };
  if (judged.defects.length > 0) return { code: 1, figures, defects: judged.defects, summary: `GROSS DEFECTS: ${judged.defects.join("; ")}${judged.notes.length > 0 ? `; ${judged.notes.join("; ")}` : ""}`.slice(0, 1200) };
  return { code: c, figures, summary: [said, ...judged.notes].join("; ").slice(0, 900) };
}

/** Lane E2's check, run: `bash <engine>/tools/rink.sh check-cartridge <file> [--rules <sidecar>] --json-only` (10 minutes at most). */
export function runRinkCheck(engineDir: string, file: string, asked?: string, timeoutMs = 10 * 60_000): Promise<CoreCheckRun> {
  const script = path.join(engineDir, "tools", "rink.sh");
  if (!fs.existsSync(script)) return Promise.resolve({ code: 2, figures: {}, summary: `could not run: ${toPosix(script)} is not there` });
  const rules = file.replace(/\.cartridge\.json$/, ".rules.json");
  const args = [toPosix(script), "check-cartridge", toPosix(file), ...(rules !== file && fs.existsSync(rules) ? ["--rules", toPosix(rules)] : []), "--defects", "--json-only"];
  return new Promise((resolve) => {
    execFile("bash", args, { timeout: timeoutMs, windowsHide: true, maxBuffer: 8 * 1024 * 1024 }, (err, stdout) => {
      const code = err === null ? 0 : typeof (err as { code?: unknown }).code === "number" ? ((err as { code: number }).code) : 2;
      resolve(rinkCheckRun(code, stdout, asked));
    });
  });
}

/**
 * The fake runner's stand-in for the measured check (tests and the fake end-to-end proof): thirdjam's validator, then a
 * tl.rink.check/1 line made from the cartridge (the rink, the teams, the skaters' speed), judged as the real line is. The
 * marker FAKE_CORE_CHECK_FAIL in it makes a match that does not end.
 */
export async function fakeRinkCheck(file: string, asked?: string): Promise<CoreCheckRun> {
  if (!fs.existsSync(file)) return { code: 2, figures: {}, summary: `could not run: ${toPosix(file)} is not there` };
  const text = stripBom(fs.readFileSync(file, "utf8"));
  // E3d: a recorded real line for this very cartridge (TL_FAKE_RINK_LINES=<dir>, <sha1 of the cartridge's JSON>.json): the
  // fake proof replays lane E5's real measurements of its real job (the 33-goal pond) instead of making figures up.
  const recorded = process.env["TL_FAKE_RINK_LINES"];
  if (recorded !== undefined) {
    let key = "";
    try {
      key = crypto.createHash("sha1").update(JSON.stringify(JSON.parse(text))).digest("hex");
    } catch {
      /* not JSON: the validator says so below */
    }
    const f = path.join(recorded, `${key}.json`);
    if (key !== "" && fs.existsSync(f)) return rinkCheckRun(0, fs.readFileSync(f, "utf8"), asked);
  }
  const v = await validateCartridgeText(text);
  if (!v.ok) return rinkCheckRun(1, JSON.stringify({ tool: "tl.rink.check/1", ok: false, ran: false, refused: v.errors }));
  const g = ((JSON.parse(text) as { game?: Record<string, unknown> }).game ?? {}) as { rink?: { length_m?: number }; skater?: { speed?: number } };
  const speed = g.skater?.speed ?? 11;
  const playtester = { wins: 6, matches: 10, goals_for: 2.2, goals_against: 1.6, minutes: Math.round(((g.rink?.length_m ?? 90) / 90) * 40) / 10, carry_s: 2.1, loose_share: 0.35, shots: 14, passes_completed: 22, speed_mean: Math.round(speed * 0.62 * 100) / 100, changes_min: 9.5, human_touches_min: 5.1, knockdowns: 6 };
  const fail = text.includes("FAKE_CORE_CHECK_FAIL");
  const line = { tool: "tl.rink.check/1", ok: !fail, ran: true, levels: { rookie: { playtester: { ...playtester, wins: 9 } }, pro: { playtester }, all_star: { playtester: { ...playtester, wins: 2 } } }, defects: { idle: { matches: 16, wins: 0, not_over: 0 }, skate_only: { matches: 16, wins: 1, not_over: 0, clone_checked: 1000, clone_mismatch: 0 } }, warnings: speed > 13 ? ["the skaters' mean speed (m/s) at pro is above anything thirdjam ships (6.2..10.3)"] : [], problems: fail ? ["pro seed 3: the match did not end (fake: FAKE_CORE_CHECK_FAIL)"] : [] };
  return rinkCheckRun(fail ? 1 : 0, `fake lab\n${JSON.stringify(line)}`, asked);
}

/** The game's cartridges in pack/: those a non-base package of the plan owns, else every cartridge there. */
export function gameCartridges(packDir: string, plan: readonly PackageSpec[]): { file: string; owner?: string }[] {
  const all = listFiles(path.join(packDir, "data")).filter((f) => f.endsWith(".cartridge.json")).map((f) => `data/${f}`);
  const owned = all.map((file) => ({ file, owner: plan.find((p) => !isBase(p) && matchesAny(p.scope, file))?.id })).filter((x) => x.owner !== undefined);
  return owned.length > 0 ? (owned as { file: string; owner: string }[]) : all.map((file) => ({ file }));
}

/** The core route as reference text for a builder: where the documents and the base are in its copy. */
export function coreReferenceLines(refDir: string, route: CoreRoute): string[] {
  const at = (...p: string[]): string => toPosix(path.join(refDir, ...p));
  const lines: string[] = [];
  const base = baseRefDir(refDir, route);
  if (hasBase(base)) lines.push(`- The base this game started from (a working game on the ${route.core} core; its README says what the skin and the cartridge change): ${at("base", route.base)}/`);
  for (const d of route.docs) if (fs.existsSync(path.join(refDir, ...d.dest.split("/")))) lines.push(`- The ${route.core} core: ${d.what}: ${at(...d.dest.split("/"))}${fs.statSync(path.join(refDir, ...d.dest.split("/"))).isDirectory() ? "/" : ""}`);
  return lines;
}

/** Copies a route's documents and base from an engine into a reference copy (what exists; nothing fails when absent). */
export function copyCoreReference(engineDir: string, refDir: string, route: CoreRoute): void {
  if (!fs.existsSync(path.join(engineDir, "cores", route.core))) return;
  for (const d of route.docs) {
    const src = path.join(engineDir, ...d.src.split("/"));
    if (!fs.existsSync(src)) continue;
    const dest = path.join(refDir, ...d.dest.split("/"));
    if (fs.statSync(src).isDirectory()) copyDir(src, dest);
    else {
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      fs.copyFileSync(src, dest);
    }
  }
  const base = baseEngineDir(engineDir, route);
  if (hasBase(base)) copyDir(base, baseRefDir(refDir, route));
}

/** A section of a markdown file from its heading to the next heading of the same level ("" when absent). */
export function sectionOf(file: string, heading: RegExp): string {
  if (!fs.existsSync(file)) return "";
  const lines = stripBom(fs.readFileSync(file, "utf8")).split(/\r?\n/);
  const at = lines.findIndex((l) => heading.test(l));
  if (at < 0) return "";
  const level = /^(#+) /.exec(lines[at] as string)?.[1]?.length ?? 2;
  const stop = new RegExp(`^#{1,${level}} `);
  let end = lines.findIndex((l, i) => i > at && stop.test(l));
  if (end < 0) end = lines.length;
  return lines.slice(at, end).join("\n").trim();
}
const fileText = (file: string): string => (fs.existsSync(file) ? stripBom(fs.readFileSync(file, "utf8")).trim() : "");
const posixRel = (root: string, abs: string): string => path.relative(root, abs).replace(/\\/g, "/");

/**
 * E3 of 24 Nov: the excerpt of a template on a core. The design step and the Planner read the core route whole (API.md
 * section 24, the cartridge catalog CARTRIDGE.md, the twelve modes, the base's README: lanes E1, E2); a builder reads
 * where its reference copy holds them. A document that has not landed yet is named as missing, never guessed.
 */
export function coreExcerpt(t: { id: string; title: string }, core: CoreRoute, part: "design" | "planner" | "builder", root = REPO_ROOT): string {
  const engine = path.join(root, "engine");
  const base = baseEngineDir(engine, core);
  const catalog = path.join(engine, "cores", core.core, "CARTRIDGE.md");
  const modes = path.join(engine, ...(core.docs.find((d) => d.dest.endsWith("/modes"))?.src ?? "").split("/"), "MODES.md");
  const head = [
    `# The genre template: ${t.id} (${t.title})`,
    `This game runs ON THE ${core.core.toUpperCase()} CORE (kernel API section 24, \`ctx.cores\`): thirdjam's own simulation and bots, compiled whole into the engine. The skating, the puck, the sticks, the contact, the bots' decisions, the camera and the keys are the core's and they stay: they are why the house game engine/packs/${core.house} feels like thirdjam. A game here is a CARTRIDGE (\`tj.cartridge/1\`: rink, teams, speeds, contact, rules, hooks, variants, zones, obstacles, pickups, abilities, look, camera; an optional \`tl.rink.rules/1\` sidecar of Third Life switches) over the BASE engine/templates/${core.base}/ (a working game on the core: hokej made skinnable; its SKIN, data/skin.json, holds the title, team names, colours and words). Never plan, design or build a new simulation, a new skater or a new camera: change the cartridge and the skin.`,
    `The design names what it changes, in brief.rules after the method lines, one per line: \`CARTRIDGE: <key path> = <value> (what the player feels)\` (1 to 16 lines, the paths of the catalog or the modes below: \`game.rink.length_m\`, \`game.teams\`, \`game.rules.score_to_win\`, \`game.look.tier\`) and \`SKIN: <field> = <value>\` (1 to 10 lines: the title, the team names and colours, the words). Change only what serves the player's words; every key you do not name stays the base's. A twist that no key can say (a kick, a ball that bounces, a new body) is not buildable on this core: say so in the design instead of promising it.`,
    `The measured check of a cartridge: \`${core.check}\` plays it headless with the core's bots and the planning hand and reports what a person will meet (goals a match, carry length, dead verbs); it runs at every look beside the same check on the house game's cartridge (${core.house}: ${core.houseCartridge}). The bots are the floor; a person playing the first phase is the gate.`,
  ];
  if (part === "builder") {
    return [...head, `Your reference copy holds the core's documents under ref/cores/${core.core}/ (SNAPSHOT.md, GAMEMODE.md, CARTRIDGE.md, schema/, modes/) and the base under ref/base/${core.base}/ (its README first): the section "Reference material" below names each path. Every cartridge or rules file you write is validated by the Foreman (foreman/src/cartridge.ts, lane E2) BEFORE lint and smoke: unknown keys and values out of limits are errors and send the round back with the problems.`].join("\n") + "\n";
  }
  const api = sectionOf(path.join(engine, "kernel", "API.md"), /^## 24\. /);
  const out = [...head, ""];
  out.push(api !== "" ? `## The kernel API, section 24 in full (engine/kernel/API.md)\n${api}` : "(engine/kernel/API.md has no section 24 in this engine)");
  const cat = fileText(catalog);
  out.push("", cat !== "" ? `## The cartridge catalog (engine/cores/${core.core}/CARTRIDGE.md, lane E2)\n${cat}` : `## The cartridge catalog\n(engine/cores/${core.core}/CARTRIDGE.md has not landed yet (lane E2): the key paths are those of the house game's cartridge engine/packs/${core.house}/${core.houseCartridge} and of the modes below)`);
  const m = fileText(modes);
  if (m !== "") out.push("", `## thirdjam's twelve modes: worked examples of a cartridge cut (${posixRel(root, modes)})\n${m}`);
  const readme = fileText(path.join(base, "README.md"));
  out.push("", readme !== "" && hasBase(base) ? `## The base and its skin (engine/templates/${core.base}/README.md, lane E1)\n${readme}` : `## The base\n(engine/templates/${core.base}/ has not landed yet (lane E1): the job cannot start from the base until it does)`);
  return out.join("\n") + "\n";
}
