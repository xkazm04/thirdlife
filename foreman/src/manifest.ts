// The composed manifest (JOB.md, amendments of 2026-11-10): pack.json is written by the Foreman from the job's
// packId, title and version plus the `registers` blocks of packages. No builder writes it and no scope contains it.
import fs from "node:fs";
import path from "node:path";
import type { PackageSpec } from "./events.js";
import { PKG_ROOT, stripBom, toPosix } from "./paths.js";
import type { RunnerLocation } from "./builder/allowlist.js";
import { isFakeRunner } from "./verbs.js";

/** The entry script is a convention, not a choice: the root package of every plan owns this file. */
export const ENTRY_SCRIPT = "scripts/main.gd";
export const MANIFEST_FILE = "pack.json";
export const PACK_VERSION = "0.1.0";

/** Where an engine declares the kernel API it offers (`const KERNEL_API: String = "1.5"`). */
export const KERNEL_API_FILE = "kernel/runner/manifest.gd";
/** The fake runner's engine (the bundled fixture, a .txt holding the same constant): what a job run against the fake runner and an empty engine reads. */
export const FAKE_KERNEL_API_FILE = path.join(PKG_ROOT, "fixtures", "engine", "kernel", "runner", "kernel_api.txt");

/** The `KERNEL_API` constant of a kernel/runner/manifest.gd text, or undefined when it declares none. */
export function kernelApiIn(src: string): string | undefined {
  return /^const\s+KERNEL_API\s*(?::\s*String\s*)?=\s*"(\d+\.\d+)"/m.exec(src)?.[1];
}

/**
 * JOB.md 2026-11-17: a pack the Foreman writes declares the KERNEL_API of the engine it was built against, read from
 * that engine (`<engine>/kernel/runner/manifest.gd`), never a constant in the Foreman. The bundled fake runner with
 * an engine directory that has no such file reads the fake engine's own file (as verbs.ts does for verbs.json).
 * Anything else without a readable constant is an error: nothing is built against an engine whose version is unknown.
 */
export function kernelApiFor(location: RunnerLocation): string {
  const own = path.join(location.engineDir, ...KERNEL_API_FILE.split("/"));
  const file = fs.existsSync(own) || !isFakeRunner(location) ? own : FAKE_KERNEL_API_FILE;
  let src: string;
  try {
    src = fs.readFileSync(file, "utf8");
  } catch {
    throw new KernelApiError(`the engine's kernel API version cannot be read: no ${toPosix(file)} (the Foreman writes the engine's KERNEL_API into every pack.json and has no version of its own)`);
  }
  const v = kernelApiIn(src);
  if (v === undefined) throw new KernelApiError(`the engine's kernel API version cannot be read: ${toPosix(file)} declares no \`const KERNEL_API: String = "<major>.<minor>"\``);
  return v;
}

export class KernelApiError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "KernelApiError";
  }
}

export interface Manifest {
  id: string;
  version: string;
  kernelApi: string;
  title: string;
  capabilities: string[];
  entry: string;
  assets: string[];
  tests: string[];
  cameras?: string[];
  /** PACK.md, amendments of 2026-11-11: optional fields a BUILDER writes; the Foreman carries them through unchanged. */
  footprint?: unknown;
  params?: unknown;
  on_leave?: unknown;
  subject?: unknown;
  moments?: unknown;
  /** E3g: the base the pack started from (engine/templates/<base>/): lint counts only the pack's own game lines. */
  base?: string;
}

/** E3g: whether the engine's manifest check knows `base` (its kernel/runner/manifest.gd names the key). */
export function engineKnowsBase(engineDir: string): boolean {
  try {
    return /^\s*"base":/m.test(fs.readFileSync(path.join(engineDir, "kernel", "runner", "manifest.gd"), "utf8"));
  } catch {
    return false;
  }
}

/** The optional manifest fields a builder owns (PACK.md, last section). Everything else in pack.json is composed. */
export const CARRIED_FIELDS = ["footprint", "params", "on_leave", "subject", "moments"] as const;
export type Carried = Partial<Record<(typeof CARRIED_FIELDS)[number], unknown>>;

/**
 * Which of the optional fields the engine's manifest check accepts. PACK.md (2026-11-11) describes all five, but an
 * engine whose kernel/runner/manifest.gd does not know a key refuses the whole manifest ("unknown keys are errors":
 * seen on 2026-11-11 00:28 in site/_engine_snapshot3 AND in engine/, both with the manifest.gd of 2026-11-10 18:59).
 * So the Foreman looks: a field counts as accepted when the checker's source names it. No file: none are accepted.
 */
export function acceptedCarriedFields(engineDir: string): string[] {
  let src: string;
  try {
    src = fs.readFileSync(path.join(engineDir, "kernel", "runner", "manifest.gd"), "utf8");
  } catch {
    return [];
  }
  return CARRIED_FIELDS.filter((k) => src.includes(`"${k}"`));
}

/** The carried fields of a manifest text; nothing when the text is not a JSON object. */
export function carriedOf(text: string | undefined): Carried {
  if (text === undefined) return {};
  let doc: unknown;
  try {
    doc = JSON.parse(stripBom(text));
  } catch {
    return {};
  }
  if (doc === null || typeof doc !== "object" || Array.isArray(doc)) return {};
  const out: Carried = {};
  for (const k of CARRIED_FIELDS) {
    const v = (doc as Record<string, unknown>)[k];
    if (v !== undefined && v !== null) out[k] = v;
  }
  return out;
}

const same = (a: unknown, b: unknown): boolean => JSON.stringify(a) === JSON.stringify(b);
const named = (v: unknown): v is { name: string }[] => Array.isArray(v) && v.every((x) => x !== null && typeof x === "object" && typeof (x as { name?: unknown }).name === "string");

/**
 * Three-way merge of the carried fields: `base` is what the builder's workspace started with, `mine` what the
 * builder left, `theirs` what pack/ holds now (another package may have merged meanwhile). What the builder did not
 * touch keeps the pack's value; `params` and `moments` are merged entry by entry (by `name`), so two packages can
 * each declare their own.
 */
export function mergeCarried(base: Carried, mine: Carried, theirs: Carried): Carried {
  const out: Carried = {};
  for (const k of CARRIED_FIELDS) {
    const b = base[k];
    const m = mine[k];
    const t = theirs[k];
    let v: unknown;
    if (same(b, m)) v = t;
    else if ((k === "params" || k === "moments") && named(m ?? []) && named(t ?? []) && named(b ?? [])) {
      const mineList = (m ?? []) as { name: string }[];
      const baseList = (b ?? []) as { name: string }[];
      const list = [...((t ?? []) as { name: string }[])];
      for (const e of mineList) {
        const was = baseList.find((x) => x.name === e.name);
        if (was && same(was, e)) continue;
        const at = list.findIndex((x) => x.name === e.name);
        if (at >= 0) list[at] = e;
        else list.push(e);
      }
      const removed = baseList.filter((x) => !mineList.some((e) => e.name === x.name)).map((x) => x.name);
      v = list.filter((x) => !removed.includes(x.name));
      if ((v as unknown[]).length === 0) v = undefined;
    } else v = m;
    if (v !== undefined) out[k] = v;
  }
  return out;
}

function union(lists: (string[] | undefined)[]): string[] {
  const out: string[] = [];
  for (const l of lists) for (const x of l ?? []) if (!out.includes(x)) out.push(x);
  return out;
}

/**
 * The manifest for a pack that holds exactly `packages` (given in plan order, which fixes the order of asset
 * generators and tests). Pure: the same input always gives the same text.
 * E3g: `job.base` (the core route's base, given only when the engine's lint knows the key) is written as `base` when a
 * package of kind "base" (coreroute.ts BASE_KIND) is among `packages`: lint then counts only the pack's own game lines.
 */
export function composeManifest(job: { packId: string; title: string; version?: string; kernelApi: string; base?: string }, packages: PackageSpec[], carried: Carried = {}): Manifest {
  const cameras = union(packages.map((p) => p.registers?.cameras));
  const base = job.base !== undefined && packages.some((p) => p.kind === "base") ? { base: job.base } : {};
  return {
    id: job.packId,
    version: job.version ?? PACK_VERSION,
    kernelApi: job.kernelApi,
    title: job.title.trim().slice(0, 80) || job.packId,
    capabilities: union(packages.map((p) => p.registers?.capabilities)),
    entry: ENTRY_SCRIPT,
    assets: union(packages.map((p) => p.registers?.assets)),
    tests: union(packages.map((p) => p.registers?.tests)),
    ...(cameras.length > 0 ? { cameras } : {}),
    ...base,
    ...Object.fromEntries(CARRIED_FIELDS.filter((k) => carried[k] !== undefined).map((k) => [k, carried[k]])),
  };
}

export function manifestText(m: Manifest): string {
  return JSON.stringify(m, null, 2) + "\n";
}

export function writeManifest(dir: string, m: Manifest): void {
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, MANIFEST_FILE), manifestText(m));
}

/** `id` and everything it depends on, directly or not. */
export function depClosure(plan: PackageSpec[], id: string): Set<string> {
  const byId = new Map(plan.map((p) => [p.id, p]));
  const out = new Set<string>();
  const visit = (x: string): void => {
    if (out.has(x)) return;
    out.add(x);
    for (const d of byId.get(x)?.deps ?? []) visit(d);
  };
  visit(id);
  return out;
}

/** Packages that depend on `id`, directly or not (not `id` itself). */
export function dependants(plan: PackageSpec[], id: string): string[] {
  return plan.filter((p) => p.id !== id && depClosure(plan, p.id).has(id)).map((p) => p.id);
}
