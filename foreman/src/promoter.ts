// The Promoter: copies a fully verified pack/ into the engine's packs/ directory.
import fs from "node:fs";
import path from "node:path";
import { PACK_ID_RE } from "./events.js";
import { copyDir } from "./scope.js";

export interface Promotion {
  packId: string;
  version: string;
  /** Forward slashes: packs/<id> relative to the engine directory, or promoted/<id> relative to the job directory. */
  dest: string;
  destAbs: string;
}

export function readManifest(packDir: string): { id: string; version: string; tests: string[]; cameras: string[] } {
  const m = JSON.parse(fs.readFileSync(path.join(packDir, "pack.json"), "utf8")) as Record<string, unknown>;
  const id = m["id"];
  const version = m["version"];
  if (typeof id !== "string" || !PACK_ID_RE.test(id)) throw new Error(`pack.json has no valid id`);
  if (typeof version !== "string") throw new Error(`pack.json has no version`);
  const list = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : []);
  return { id, version, tests: list(m["tests"]), cameras: list(m["cameras"]) };
}

/**
 * Copies into a temporary sibling first and swaps it in, so the engine never sees a half-copied pack.
 * The caller has already verified `packDir`; this function does not judge anything.
 */
export function promotePack(packDir: string, engineDir: string, expectedId?: string, sub = "packs"): Promotion {
  const m = readManifest(packDir);
  if (expectedId !== undefined && m.id !== expectedId) {
    throw new Error(`pack.json id is "${m.id}" but the job was created for "${expectedId}"`);
  }
  const packs = path.join(path.resolve(engineDir), sub);
  fs.mkdirSync(packs, { recursive: true });
  const destAbs = path.join(packs, m.id);
  const tmp = path.join(packs, `.${m.id}.incoming-${process.pid}`);
  fs.rmSync(tmp, { recursive: true, force: true });
  copyDir(packDir, tmp);
  fs.rmSync(destAbs, { recursive: true, force: true });
  fs.renameSync(tmp, destAbs);
  return { packId: m.id, version: m.version, dest: `${sub}/${m.id}`, destAbs };
}

/** True when a pack could be written under <dir>/packs/ (tried with a probe file; nothing is left behind). */
export function engineWritable(engineDir: string): boolean {
  const packs = path.join(path.resolve(engineDir), "packs");
  const made = !fs.existsSync(packs);
  const probe = path.join(packs, `.foreman-write-probe-${process.pid}`);
  try {
    fs.mkdirSync(packs, { recursive: true });
    fs.writeFileSync(probe, "");
    fs.rmSync(probe, { force: true });
    if (made && fs.readdirSync(packs).length === 0) fs.rmdirSync(packs);
    return true;
  } catch {
    return false;
  }
}
