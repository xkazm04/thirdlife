// A user's rink game IS a cartridge (thirdjam's tj.cartridge/1) on the rink core, plus an optional tl.rink.rules/1 sidecar (the
// thirdlife variant's switches). This module lets the Foreman check one before any engine runs:
//   validateCartridgeText / validateCartridge   thirdjam's own validator (engine/cores/rink/schema/validate.mjs, copied byte for byte
//                                              from thirdjam 8dc713c6 schema/, with the schema files extracted from the C++ loader's
//                                              embedded copy): the same verdicts as the core's C++ UJamCartridge::Validate (parity
//                                              test: src/test/cartridge.test.ts against verdicts recorded from the built core)
//   validateRulesText                          the sidecar, as the core's reader (native/glue/rink_rules.cpp) checks it
//   applyChanges                               a small change set (key path -> value) applied to a cartridge, then validated: what
//                                              an iteration ("make it faster") sends instead of a new cartridge
// Errors are sentences that start with a JSON pointer (thirdjam's convention): a model reads them to repair its own output.
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { REPO_ROOT } from "./paths.js";

export const RINK_SCHEMA_DIR = path.join(REPO_ROOT, "engine", "cores", "rink", "schema");
export const RINK_CONTENT_DIR = path.join(REPO_ROOT, "engine", "cores", "rink", "native", "content");
export const RINK_PATCHES_DIR = path.join(REPO_ROOT, "engine", "cores", "rink", "native", "patches-thirdlife");

export interface Verdict {
  ok: boolean;
  errors: string[];
}

interface ThirdjamValidator {
  validateCartridgeText(text: string): Verdict;
  validateCartridge(obj: unknown): Verdict;
}

let validator: ThirdjamValidator | null = null;

async function load(): Promise<ThirdjamValidator> {
  if (validator) return validator;
  const file = path.join(RINK_SCHEMA_DIR, "validate.mjs");
  if (!fs.existsSync(file)) throw new Error(`the rink schema is not in this tree (${file})`);
  validator = (await import(pathToFileURL(file).href)) as ThirdjamValidator;
  return validator;
}

/** A cartridge's text, parsed strictly (duplicate keys, trailing commas, comments are errors) and validated. */
export async function validateCartridgeText(text: string): Promise<Verdict> {
  return (await load()).validateCartridgeText(text);
}

/** An already-parsed cartridge, validated. */
export async function validateCartridge(obj: unknown): Promise<Verdict> {
  return (await load()).validateCartridge(obj);
}

// ---------------------------------------------------------------- the rules sidecar (tl.rink.rules/1)

export interface RuleSwitch {
  key: string;
  /** The value range TlSetRule accepts (`if (Value < min || Value > max) return false;` in its line); absent = any number. */
  min?: number;
  max?: number;
  /** The patch file that adds it. */
  patch: string;
}

/** The switches native/patches-thirdlife defines: every `if (K == "<key>") { ... }` line of TlSetRule in the patch files, with
 *  the value range the line refuses outside of (patch 0004: `if (Value < 0.0 || Value > 60.0) return false;`). */
export function ruleSwitches(patchesDir: string = RINK_PATCHES_DIR): RuleSwitch[] {
  if (!fs.existsSync(patchesDir)) return [];
  const out = new Map<string, RuleSwitch>();
  for (const f of fs.readdirSync(patchesDir).filter((n) => n.endsWith(".patch")).sort()) {
    for (const m of fs.readFileSync(path.join(patchesDir, f), "utf8").matchAll(/^\+\s*if \(K == "([a-z0-9_]+)"\)(.*)$/gm)) {
      const sw: RuleSwitch = { key: m[1]!, patch: f };
      const r = /if \(Value < (-?[\d.]+) \|\| Value > (-?[\d.]+)\) return false;/.exec(m[2] ?? "");
      if (r) { sw.min = Number(r[1]); sw.max = Number(r[2]); }
      else if (/return false/.test(m[2] ?? "")) throw new Error(`${f}: the switch ${sw.key} refuses values in a way this reader does not know: ${m[2]}`);
      out.set(sw.key, sw);
    }
  }
  return [...out.values()].sort((x, y) => x.key.localeCompare(y.key));
}

/** The switch names (ruleSwitches without the ranges). */
export function knownRules(patchesDir: string = RINK_PATCHES_DIR): string[] {
  return ruleSwitches(patchesDir).map((s) => s.key);
}

const LEVELS = ["rookie", "pro", "all_star"];

// ApplyDifficultyTune's syntax (thirdjam AI/DifficultyProfile.cpp): "k=v;k=v", a pair under 160 bytes, a '=' in it, the value a
// whole number as strtod reads it. Which keys exist is the core's to say (130+ names): an unknown key fails at the core's reset.
function tuneSyntax(text: string): string {
  for (const pair of text.split(";")) {
    if (pair.length === 0) continue;
    if (Buffer.byteLength(pair, "utf8") >= 160) return "pair too long";
    const eq = pair.indexOf("=");
    if (eq < 0) return `no '=' in pair: ${pair}`;
    const v = pair.slice(eq + 1);
    if (!/^\s*[+-]?(\d+\.?\d*([eE][+-]?\d+)?|\.\d+([eE][+-]?\d+)?|inf(inity)?|nan)$/i.test(v)) return `not a number: ${pair}`;
  }
  return "";
}

/** The sidecar, as RinkGlue::LoadRules reads it (native/glue/rink_rules.cpp): unknown keys and unknown rules are errors. */
export function validateRulesText(text: string, patchesDir: string = RINK_PATCHES_DIR): Verdict {
  let root: unknown;
  try {
    root = JSON.parse(text);
  } catch (e) {
    return { ok: false, errors: [`rules file: ${(e as Error).message}`] };
  }
  if (typeof root !== "object" || root === null || Array.isArray(root)) return { ok: false, errors: ["rules file: not an object"] };
  const known = new Map(ruleSwitches(patchesDir).map((s) => [s.key, s]));
  const fail = (e: string): Verdict => ({ ok: false, errors: [e] });
  let schema = false;
  for (const [k, v] of Object.entries(root as Record<string, unknown>)) {
    if (k === "schema") {
      if (v !== "tl.rink.rules/1") return fail('rules file: schema must be "tl.rink.rules/1"');
      schema = true;
    } else if (k === "title" || k === "notes") {
      if (typeof v !== "string") return fail(`rules file: ${k} must be a string`);
    } else if (k === "rules") {
      if (typeof v !== "object" || v === null || Array.isArray(v)) return fail("rules file: rules must be an object");
      for (const [rk, rv] of Object.entries(v as Record<string, unknown>)) {
        if (typeof rv !== "number" && typeof rv !== "boolean") return fail(`rules file: rule ${rk} must be a number or a bool`);
        const sw = known.get(rk);
        if (!sw) return fail(`unknown rule "${rk}" (not a switch of native/patches-thirdlife)`);
        const x = typeof rv === "boolean" ? (rv ? 1 : 0) : rv;
        if ((sw.min !== undefined && x < sw.min) || (sw.max !== undefined && x > sw.max)) return fail(`rule "${rk}": ${x} is outside ${sw.min}..${sw.max} (${sw.patch})`);
      }
    } else if (k === "levels") {
      if (typeof v !== "object" || v === null || Array.isArray(v)) return fail("rules file: levels must be an object");
      for (const [lk, lv] of Object.entries(v as Record<string, unknown>)) {
        if (!LEVELS.includes(lk) || typeof lv !== "string") return fail(`rules file: levels.${lk} must be rookie | pro | all_star with a tune string`);
        const e = tuneSyntax(lv);
        if (e) return fail(`level tune: ${e}`);
      }
    } else return fail(`rules file: unknown key "${k}"`);
  }
  if (!schema) return fail('rules file: no schema (want "tl.rink.rules/1")');
  return { ok: true, errors: [] };
}

// ---------------------------------------------------------------- change sets

/** A key path: dots between names, [n] for a list element ("game.skater.max_speed", "game.teams[1].color", "values.speed"). */
export function parsePath(p: string): (string | number)[] {
  const out: (string | number)[] = [];
  for (const part of p.split(".")) {
    const m = /^([^[\]]*)((\[\d+\])*)$/.exec(part);
    if (!m) throw new Error(`bad key path "${p}"`);
    if (m[1]) out.push(m[1]);
    for (const i of (m[2] ?? "").matchAll(/\[(\d+)\]/g)) out.push(Number(i[1]));
  }
  if (out.length === 0) throw new Error(`empty key path "${p}"`);
  return out;
}

export interface ChangeResult extends Verdict {
  cartridge: Record<string, unknown>;
  /** Each change as "path: before -> after" (absent = the key was not there / is removed). */
  changed: string[];
}

/**
 * Applies `changes` (key path -> new value; null or undefined = remove the key: absent is omitted, never null) to a copy of
 * `base`, creates missing objects on the way, and validates the result. The base is never modified.
 */
export async function applyChanges(base: Record<string, unknown>, changes: Record<string, unknown>): Promise<ChangeResult> {
  const out = structuredClone(base);
  const changed: string[] = [];
  const show = (v: unknown): string => (v === undefined ? "absent" : JSON.stringify(v));
  for (const [p, value] of Object.entries(changes)) {
    const keys = parsePath(p);
    let node: any = out;
    for (let i = 0; i < keys.length - 1; i++) {
      const k = keys[i]!;
      if (node[k] === undefined || node[k] === null) {
        if (value === null || value === undefined) { node = undefined; break; }
        node[k] = typeof keys[i + 1] === "number" ? [] : {};
      }
      node = node[k];
      if (typeof node !== "object") throw new Error(`key path "${p}": ${keys.slice(0, i + 1).join(".")} is not an object or a list`);
    }
    if (node === undefined) { changed.push(`${p}: absent -> absent`); continue; }
    const last = keys[keys.length - 1]!;
    const before = node[last];
    if (value === null || value === undefined) {
      if (Array.isArray(node) && typeof last === "number") node.splice(last, 1);
      else delete node[last];
    } else node[last] = structuredClone(value);
    changed.push(`${p}: ${show(before)} -> ${show(value === null ? undefined : value)}`);
  }
  const v = await validateCartridge(out);
  return { ...v, cartridge: out, changed };
}

/** Every cartridge thirdjam ships in the content dir (Cartridges/*.cartridge.json, modes/, modes/parked/), by file name. */
export function shippedCartridges(contentDir: string = RINK_CONTENT_DIR): string[] {
  const out: string[] = [];
  for (const sub of ["Cartridges", "Cartridges/modes", "Cartridges/modes/parked"]) {
    const d = path.join(contentDir, sub);
    if (!fs.existsSync(d)) continue;
    for (const f of fs.readdirSync(d).filter((n) => n.endsWith(".cartridge.json")).sort()) out.push(path.join(d, f));
  }
  return out;
}
