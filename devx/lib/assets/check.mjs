// `tl assets check` as a library: pure over a repo root, so tests run it on temp-dir fixtures.
import fs from "node:fs";
import path from "node:path";
import { step } from "../ctx.mjs";
import { checkPath, checkFile, checkTree } from "./hygiene.mjs";
import { MANIFEST_REL, BUDGETS_REL, readJson, validateManifest, validateBudgets, checkBudgets, tierOf, ownerDir, sha256File, pngSize } from "./model.mjs";

const trunc = (list, n = 3) => (list.length === 0 ? "" : list.slice(0, n).join("; ") + (list.length > n ? `; ... (${list.length - n} more)` : ""));

/**
 * Runs every static rule. `scanned` (optional, full mode) is the list of {id, hash, tris} the kit scan produced; the
 * engine-owned kit_part entries must match it exactly. Returns {steps, problems} where problems is {stepId: string[]}.
 */
export function checkAssets({ root, scanned = null }) {
  const steps = [];
  const problems = {};
  const add = (id, t0, list, okDetail) => {
    problems[id] = list;
    steps.push(step(id, list.length === 0, Date.now() - t0, list.length ? trunc(list) : okDetail));
  };

  // manifest + budgets file
  let t0 = Date.now();
  let manifest = null, budgets = null;
  const mp = [];
  try { manifest = readJson(path.join(root, MANIFEST_REL)); } catch (e) { mp.push(`${MANIFEST_REL}: ${e.code === "ENOENT" ? "missing" : "unreadable: " + e.message}`); }
  try { budgets = readJson(path.join(root, BUDGETS_REL)); } catch (e) { mp.push(`${BUDGETS_REL}: ${e.code === "ENOENT" ? "missing" : "unreadable: " + e.message}`); }
  if (manifest) mp.push(...validateManifest(manifest));
  if (budgets) mp.push(...validateBudgets(budgets));
  add("manifest", t0, mp, `${manifest?.assets?.length ?? 0} assets, schema ok`);
  if (!manifest || !Array.isArray(manifest.assets)) return { steps, problems };
  const entries = manifest.assets.filter((e) => e && typeof e === "object" && typeof e.id === "string");
  const foreign = entries.filter((e) => e.source !== "procedural" && typeof e.origin === "string");

  // files: exist, bytes and hash match, png dimensions match
  t0 = Date.now();
  const fp = [];
  for (const e of foreign) {
    if (checkPath(e.origin).length) continue; // hygiene reports it
    const abs = path.join(root, e.origin);
    if (!fs.existsSync(abs)) { fp.push(`${e.id}: file '${e.origin}' does not exist`); continue; }
    const size = fs.statSync(abs).size;
    if (size !== e.bytes) fp.push(`${e.id}: manifest says ${e.bytes} bytes, file has ${size}`);
    const h = sha256File(abs);
    if (h !== e.hash) fp.push(`${e.id}: hash mismatch (manifest ${String(e.hash).slice(0, 12)}, file ${h.slice(0, 12)})`);
    if (e.kind === "texture" && Array.isArray(e.px)) {
      const real = pngSize(abs);
      if (real && (real[0] !== e.px[0] || real[1] !== e.px[1])) fp.push(`${e.id}: manifest says ${e.px[0]}x${e.px[1]}, png header says ${real[0]}x${real[1]}`);
    }
  }
  add("files", t0, fp, `${foreign.length} foreign files present, hashes match`);

  // budgets
  t0 = Date.now();
  const budgetsOk = budgets && validateBudgets(budgets).length === 0;
  add("budgets", t0, budgetsOk ? checkBudgets({ assets: entries }, budgets) : ["budgets file unusable"], "all assets within tier budgets");

  // hygiene: every foreign origin, plus every file that sits in an owner directory
  t0 = Date.now();
  const hp = [];
  for (const e of foreign) {
    const dir = typeof e.owner === "string" ? ownerDir(e.owner) : null;
    const pp = checkPath(e.origin, { ownerDir: dir });
    if (pp.length) { hp.push(...pp.map((p) => `${e.id}: ${p}`)); continue; }
    const cap = budgetsOk ? budgets.tiers?.[tierOf(e)]?.kinds?.[e.kind]?.maxBytes : undefined;
    if (fs.existsSync(path.join(root, e.origin))) hp.push(...checkFile(path.join(root, e.origin), { kind: e.kind, maxBytes: cap }).map((p) => `${e.id}: ${p}`));
  }
  const assetsDir = path.join(root, "assets");
  const registered = new Set(foreign.map((e) => path.posix.normalize(e.origin)));
  let scannedFiles = 0;
  if (fs.existsSync(assetsDir)) {
    const dirs = fs.readdirSync(assetsDir, { withFileTypes: true }).filter((x) => x.isDirectory() || x.isSymbolicLink());
    dirs.sort((a, b) => (a.name < b.name ? -1 : 1));
    for (const d of dirs) {
      const t = checkTree(path.join(assetsDir, d.name));
      scannedFiles += t.files.length;
      hp.push(...t.problems.map((p) => `assets/${d.name}/${p}`));
      for (const f of t.files) if (!registered.has(`assets/${d.name}/${f}`)) hp.push(`assets/${d.name}/${f}: file is not registered in the manifest`);
    }
  }
  add("hygiene", t0, hp, `${foreign.length} registered, ${scannedFiles} files in owner dirs, no executable content`);

  // procedural: engine kit parts must equal a fresh scan (full mode only)
  if (scanned) {
    t0 = Date.now();
    const pp = [];
    const want = new Map(scanned.map((s) => [s.id, s]));
    const have = new Map(entries.filter((e) => e.kind === "kit_part" && e.source === "procedural").map((e) => [e.id, e]));
    for (const [id, s] of want) {
      const e = have.get(id);
      if (!e) { pp.push(`${id}: in the kit but not in the manifest`); continue; }
      if (e.hash !== s.hash) pp.push(`${id}: hash drifted (manifest ${String(e.hash).slice(0, 12)}, kit ${s.hash.slice(0, 12)})`);
      if (e.tris !== s.tris) pp.push(`${id}: triangles drifted (manifest ${e.tris}, kit ${s.tris})`);
    }
    for (const id of have.keys()) if (!want.has(id)) pp.push(`${id}: in the manifest but no longer in the kit`);
    add("procedural", t0, pp.length ? [...pp, "run: tl assets scan"] : [], `${want.size} kit parts re-derived, hashes equal`);
  }
  return { steps, problems };
}
