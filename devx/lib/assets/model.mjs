// tl.assets/1: manifest model, hand validator (no ajv in devx), deterministic writer. Mirrors contracts/assets.schema.json.
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

export const SCHEMA = "tl.assets/1";
export const BUDGET_SCHEMA = "tl.assets.budgets/1";
export const KINDS = ["kit_part", "mesh", "texture", "audio", "material", "rig", "data"];
export const SOURCES = ["procedural", "imported", "generated"];
export const TIERS = ["engine", "pack", "player_pack"];
export const MANIFEST_REL = "assets/manifest.json";
export const BUDGETS_REL = "assets/budgets.json";

export const ID_RE = /^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$/;
export const OWNER_RE = /^(engine|[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+)$/;
export const PROC_ORIGIN_RE = /^[a-z][a-z0-9_.]*:[A-Za-z0-9_.-]+$/;
export const SHA1_RE = /^[0-9a-f]{40}$/;
export const SHA256_RE = /^[0-9a-f]{64}$/;

const ENTRY_KEYS = ["id", "kind", "source", "origin", "params", "hash", "bytes", "tris", "px", "license", "provenance", "owner", "tier"];
const PROV_KEYS = ["tool", "model", "prompt_hash", "author"];

export const tierOf = (e) => e.tier ?? (e.owner === "engine" ? "engine" : "pack");
export const ownerDir = (owner) => `assets/${owner}/`;
export const sha256File = (abs) => crypto.createHash("sha256").update(fs.readFileSync(abs)).digest("hex");

const isInt = (v) => Number.isInteger(v) && v >= 0;
const isStr = (v) => typeof v === "string" && v.length > 0;

/** Returns the problems of one entry (strings prefixed with its id). */
export function validateEntry(e, where = "entry") {
  const out = [];
  if (e === null || typeof e !== "object" || Array.isArray(e)) return [`${where}: not an object`];
  const tag = isStr(e.id) ? e.id : where;
  const bad = (m) => out.push(`${tag}: ${m}`);
  for (const k of Object.keys(e)) if (!ENTRY_KEYS.includes(k)) bad(`unknown key '${k}'`);
  if (!isStr(e.id) || !ID_RE.test(e.id)) bad(`id must be namespaced like kit.rink or pack.marble.ramp (${ID_RE})`);
  if (!KINDS.includes(e.kind)) bad(`kind must be one of ${KINDS.join("|")}`);
  if (!SOURCES.includes(e.source)) bad(`source must be one of ${SOURCES.join("|")}`);
  if (!isStr(e.origin)) bad("origin missing");
  else if (e.source === "procedural" && !PROC_ORIGIN_RE.test(e.origin)) bad(`procedural origin must be '<generator>:<name>', got '${e.origin}'`);
  if (e.params !== undefined && (e.params === null || typeof e.params !== "object" || Array.isArray(e.params))) bad("params must be an object");
  if (e.source === "procedural") { if (!(typeof e.hash === "string" && SHA1_RE.test(e.hash))) bad("procedural hash must be a 40 hex TLKit.hash"); }
  else if (!(typeof e.hash === "string" && SHA256_RE.test(e.hash))) bad("hash must be 64 hex sha256 of the file bytes");
  if (!isInt(e.bytes)) bad("bytes must be a non-negative integer");
  if (e.kind === "kit_part" || e.kind === "mesh") { if (!isInt(e.tris)) bad("tris (integer) is required for kit_part and mesh"); }
  else if (e.tris !== undefined && !isInt(e.tris)) bad("tris must be a non-negative integer");
  if (e.px !== undefined && !(Array.isArray(e.px) && e.px.length === 2 && e.px.every((n) => Number.isInteger(n) && n > 0))) bad("px must be [width, height]");
  if (e.kind === "texture" && e.source !== "procedural" && e.px === undefined) bad("px [w,h] is required for an imported or generated texture");
  if (!isStr(e.license)) bad("license missing");
  if (!isStr(e.owner) || !OWNER_RE.test(e.owner)) bad(`owner must be 'engine' or a pack id (${OWNER_RE})`);
  if (e.tier !== undefined && !TIERS.includes(e.tier)) bad(`tier must be one of ${TIERS.join("|")}`);
  if (e.tier === "engine" && e.owner !== "engine") bad("tier 'engine' is only for owner 'engine'");
  if (e.owner === "engine" && e.tier !== undefined && e.tier !== "engine") bad("owner 'engine' is always tier 'engine'");
  const p = e.provenance;
  if (p === null || typeof p !== "object" || Array.isArray(p)) bad("provenance {tool, author} missing");
  else {
    for (const k of Object.keys(p)) if (!PROV_KEYS.includes(k)) bad(`provenance: unknown key '${k}'`);
    if (!isStr(p.tool)) bad("provenance.tool missing");
    if (!isStr(p.author)) bad("provenance.author missing");
    for (const k of ["model", "prompt_hash"]) if (p[k] !== undefined && !isStr(p[k])) bad(`provenance.${k} must be a non-empty string`);
    if (e.source === "generated" && !(isStr(p.model) && isStr(p.prompt_hash))) bad("a generated asset needs provenance.model and provenance.prompt_hash");
  }
  if (e.kind === "kit_part") {
    if (e.source !== "procedural") bad("kit_part is always procedural");
    if (e.owner !== "engine") bad("kit_part is owned by 'engine'");
  }
  return out;
}

export function validateManifest(m) {
  if (m === null || typeof m !== "object" || Array.isArray(m)) return ["manifest is not an object"];
  const out = [];
  for (const k of Object.keys(m)) if (k !== "schema" && k !== "assets") out.push(`manifest: unknown key '${k}'`);
  if (m.schema !== SCHEMA) out.push(`manifest.schema must be '${SCHEMA}'`);
  if (!Array.isArray(m.assets)) return [...out, "manifest.assets must be an array"];
  const seen = new Set();
  m.assets.forEach((e, i) => {
    out.push(...validateEntry(e, `assets[${i}]`));
    if (e && typeof e.id === "string") { if (seen.has(e.id)) out.push(`${e.id}: duplicate id`); seen.add(e.id); }
  });
  const ids = m.assets.map((e) => e?.id).filter((x) => typeof x === "string");
  if (ids.some((id, i) => i > 0 && ids[i - 1] > id)) out.push("manifest.assets is not sorted by id (tl assets scan and add write it sorted)");
  return out;
}

export function validateBudgets(b) {
  if (b === null || typeof b !== "object") return ["budgets is not an object"];
  const out = [];
  if (b.schema !== BUDGET_SCHEMA) out.push(`budgets.schema must be '${BUDGET_SCHEMA}'`);
  const num = (v) => Number.isInteger(v) && v > 0;
  for (const t of TIERS) {
    const tier = b.tiers?.[t];
    if (!tier) { out.push(`budgets.tiers.${t} missing`); continue; }
    if (!num(tier.owner?.maxBytes)) out.push(`budgets.tiers.${t}.owner.maxBytes must be a positive integer`);
    for (const k of KINDS) {
      const kb = tier.kinds?.[k];
      if (!kb) { out.push(`budgets.tiers.${t}.kinds.${k} missing`); continue; }
      if (!num(kb.maxBytes)) out.push(`budgets.tiers.${t}.kinds.${k}.maxBytes must be a positive integer`);
      if (["kit_part", "mesh", "rig"].includes(k) && !num(kb.maxTris)) out.push(`budgets.tiers.${t}.kinds.${k}.maxTris must be a positive integer`);
      if (k === "texture" && !num(kb.maxPx)) out.push(`budgets.tiers.${t}.kinds.${k}.maxPx must be a positive integer`);
    }
  }
  return out;
}

/** Budget problems for a whole manifest (per asset, then per owner). */
export function checkBudgets(manifest, budgets) {
  const out = [];
  const totals = new Map();
  for (const e of manifest.assets) {
    const tier = tierOf(e);
    const kb = budgets.tiers?.[tier]?.kinds?.[e.kind];
    if (!kb) { out.push(`${e.id}: no budget for kind '${e.kind}' in tier '${tier}'`); continue; }
    if (Number.isInteger(e.bytes) && e.bytes > kb.maxBytes) out.push(`${e.id}: ${e.bytes} bytes exceeds the ${tier}/${e.kind} limit of ${kb.maxBytes}`);
    if (kb.maxTris !== undefined && Number.isInteger(e.tris) && e.tris > kb.maxTris) out.push(`${e.id}: ${e.tris} triangles exceeds the ${tier}/${e.kind} limit of ${kb.maxTris}`);
    if (kb.maxPx !== undefined && Array.isArray(e.px) && Math.max(...e.px) > kb.maxPx) out.push(`${e.id}: texture ${e.px[0]}x${e.px[1]} exceeds the ${tier}/${e.kind} limit of ${kb.maxPx}px`);
    const key = `${tier}|${e.owner}`;
    totals.set(key, (totals.get(key) ?? 0) + (Number.isInteger(e.bytes) ? e.bytes : 0));
  }
  for (const [key, sum] of [...totals].sort()) {
    const [tier, owner] = key.split("|");
    const cap = budgets.tiers?.[tier]?.owner?.maxBytes;
    if (cap !== undefined && sum > cap) out.push(`owner ${owner}: ${sum} bytes in total exceeds the ${tier} per-owner limit of ${cap}`);
  }
  return out;
}

/** Fixed key order, sorted by id, LF, trailing newline: the same input always gives the same bytes. */
export function serializeManifest(m) {
  const order = (e) => {
    const o = {};
    for (const k of ENTRY_KEYS) {
      if (e[k] === undefined) continue;
      o[k] = k === "provenance" ? Object.fromEntries(PROV_KEYS.filter((p) => e.provenance[p] !== undefined).map((p) => [p, e.provenance[p]])) : e[k];
    }
    return o;
  };
  const assets = [...m.assets].sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0)).map(order);
  const lines = assets.map((e) => "    " + JSON.stringify(e));
  return `{\n  "schema": "${SCHEMA}",\n  "assets": [\n${lines.join(",\n")}\n  ]\n}\n`;
}

export function readJson(abs) { return JSON.parse(fs.readFileSync(abs, "utf8")); }
export function writeManifest(root, m) { fs.writeFileSync(path.join(root, MANIFEST_REL), serializeManifest(m)); }

/** PNG dimensions from the IHDR chunk, or null when the file is not a PNG. */
export function pngSize(abs) {
  try {
    const b = fs.readFileSync(abs);
    if (b.length < 24 || b.readUInt32BE(0) !== 0x89504e47) return null;
    return [b.readUInt32BE(16), b.readUInt32BE(20)];
  } catch { return null; }
}
