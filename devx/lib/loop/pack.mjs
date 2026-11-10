// Pack discovery for the fast loop.
import fs from "node:fs";
import path from "node:path";

/** Newest mtime of any file under dir (bounded depth). */
export function newestMtime(dir, depth = 4) {
  let best = 0;
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch { return 0; }
  for (const e of ents) {
    const p = path.join(dir, e.name);
    try {
      if (e.isDirectory()) { if (depth > 0) best = Math.max(best, newestMtime(p, depth - 1)); }
      else best = Math.max(best, fs.statSync(p).mtimeMs);
    } catch { /* skip */ }
  }
  return best;
}

/** Pack dirs (those with a pack.json) directly under each root; the deliberately broken bad_* examples are skipped. */
export function listPacks(roots) {
  const out = [];
  for (const r of roots) {
    let ents;
    try { ents = fs.readdirSync(r, { withFileTypes: true }); } catch { continue; }
    for (const e of ents) {
      if (!e.isDirectory() || e.name.startsWith("bad_")) continue;
      const p = path.join(r, e.name);
      if (fs.existsSync(path.join(p, "pack.json"))) out.push(p);
    }
  }
  return out;
}

export function newestPack(roots) {
  let best = null, bm = -1;
  for (const p of listPacks(roots)) { const m = newestMtime(p); if (m > bm) { bm = m; best = p; } }
  return best;
}

/** "paddle" -> engine/seeds/seed_paddle, "seed_paddle" likewise, or any existing pack dir as given. */
export function resolveSeed(spec, seedsDir, cwd = process.cwd()) {
  const cands = [path.resolve(cwd, spec), path.join(seedsDir, spec), path.join(seedsDir, "seed_" + spec)];
  return cands.find((c) => fs.existsSync(path.join(c, "pack.json"))) ?? null;
}
