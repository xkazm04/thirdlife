// The composed manifest (JOB.md, amendments of 2026-11-10): pack.json is written by the Foreman from the job's
// packId, title and version plus the `registers` blocks of packages. No builder writes it and no scope contains it.
import fs from "node:fs";
import path from "node:path";
import type { PackageSpec } from "./events.js";

/** The entry script is a convention, not a choice: the root package of every plan owns this file. */
export const ENTRY_SCRIPT = "scripts/main.gd";
export const MANIFEST_FILE = "pack.json";
export const PACK_VERSION = "0.1.0";
export const KERNEL_API = "0.1";

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
export function composeManifest(job: { packId: string; title: string; version?: string }, packages: PackageSpec[]): Manifest {
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
