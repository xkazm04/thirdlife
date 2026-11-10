// `tl assets add`: register an in-place file. Pure over a repo root (tests use temp dirs). Never writes an invalid manifest.
import fs from "node:fs";
import path from "node:path";
import { MANIFEST_REL, readJson, writeManifest, sha256File, pngSize, ownerDir, KINDS } from "./model.mjs";
import { checkAssets } from "./check.mjs";
import { checkPath } from "./hygiene.mjs";

/** opts: {id, kind, owner, license, tool, model?, promptHash?, author?, tris?, px?, tier?}. Returns {ok, errors[], warnings[], entry?}. */
export function addAsset({ root, file, opts }) {
  const errors = [];
  const warnings = [];
  for (const k of ["id", "kind", "owner", "license", "tool"]) if (!opts[k]) errors.push(`--${k} is required`);
  if (!file) errors.push("a file path is required");
  if (errors.length) return { ok: false, errors, warnings };
  if (!KINDS.includes(opts.kind) || opts.kind === "kit_part") return { ok: false, errors: [`--kind must be one of ${KINDS.filter((k) => k !== "kit_part").join("|")} (kit_part entries come from tl assets scan)`], warnings };

  const abs = path.resolve(root, file);
  const rel = path.relative(root, abs).split(path.sep).join("/");
  const pe = checkPath(rel, { ownerDir: ownerDir(opts.owner) });
  if (pe.length) return { ok: false, errors: pe, warnings };
  if (!fs.existsSync(abs) || !fs.statSync(abs).isFile()) return { ok: false, errors: [`${rel}: not a file`], warnings };

  const mpath = path.join(root, MANIFEST_REL);
  const manifest = fs.existsSync(mpath) ? readJson(mpath) : { schema: "tl.assets/1", assets: [] };
  if (manifest.assets.some((e) => e.id === opts.id)) return { ok: false, errors: [`id '${opts.id}' is already registered`], warnings };

  const hash = sha256File(abs);
  const dup = manifest.assets.filter((e) => e.hash === hash);
  for (const d of dup) warnings.push(`same bytes as '${d.id}' (${d.origin}): consider reusing it instead of registering a copy`);
  const png = pngSize(abs);
  const entry = {
    id: opts.id, kind: opts.kind, source: opts.model ? "generated" : "imported", origin: rel, hash, bytes: fs.statSync(abs).size,
    license: opts.license,
    provenance: { tool: opts.tool, ...(opts.model ? { model: opts.model } : {}), ...(opts.promptHash ? { prompt_hash: opts.promptHash } : {}), author: opts.author ?? opts.owner },
    owner: opts.owner,
  };
  if (opts.tris !== undefined) entry.tris = Number(opts.tris);
  if (opts.kind === "texture") entry.px = opts.px ? String(opts.px).split("x").map(Number) : png ?? undefined;
  if (opts.tier) entry.tier = opts.tier;

  const next = { ...manifest, assets: [...manifest.assets, entry] };
  // validate the would-be manifest by writing it, checking, and rolling back when the new entry has problems
  const before = fs.existsSync(mpath) ? fs.readFileSync(mpath) : null;
  writeManifest(root, next);
  const res = checkAssets({ root });
  const all = Object.entries(res.problems).flatMap(([s, list]) => list.map((p) => `${s}: ${p}`));
  const mine = all.filter((p) => p.includes(opts.id) || p.includes(rel));
  for (const p of all) if (!mine.includes(p)) warnings.push(`pre-existing: ${p}`);
  if (mine.length) {
    if (before) fs.writeFileSync(mpath, before); else fs.rmSync(mpath);
    return { ok: false, errors: mine, warnings };
  }
  return { ok: true, errors: [], warnings, entry };
}
