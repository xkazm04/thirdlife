// The composed manifest (JOB.md, amendments of 2026-11-10): pack.json is written by the Foreman from the job's
// packId, title and version plus the `registers` blocks of packages. No builder writes it and no scope contains it.
import fs from "node:fs";
import path from "node:path";
import type { PackageSpec } from "./events.js";
import { stripBom } from "./paths.js";

/** The entry script is a convention, not a choice: the root package of every plan owns this file. */
export const ENTRY_SCRIPT = "scripts/main.gd";
export const MANIFEST_FILE = "pack.json";
export const PACK_VERSION = "0.1.0";
export const KERNEL_API = "1.0";

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
 */
export function composeManifest(job: { packId: string; title: string; version?: string }, packages: PackageSpec[], carried: Carried = {}): Manifest {
  const cameras = union(packages.map((p) => p.registers?.cameras));
  return {
    id: job.packId,
    version: job.version ?? PACK_VERSION,
    kernelApi: KERNEL_API,
    title: job.title.trim().slice(0, 80) || job.packId,
    capabilities: union(packages.map((p) => p.registers?.capabilities)),
    entry: ENTRY_SCRIPT,
    assets: union(packages.map((p) => p.registers?.assets)),
    tests: union(packages.map((p) => p.registers?.tests)),
    ...(cameras.length > 0 ? { cameras } : {}),
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
