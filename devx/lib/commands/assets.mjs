// `tl assets`: the asset spine. list | check [--static] | scan | add <file> ...   (contracts/ASSETS.md)
import fs from "node:fs";
import path from "node:path";
import { REPO, printVerdict, step } from "../ctx.mjs";
import { MANIFEST_REL, readJson, writeManifest, serializeManifest, validateManifest, tierOf } from "../assets/model.mjs";
import { checkAssets } from "../assets/check.mjs";
import { runScan, kitEntries } from "../assets/scan.mjs";
import { addAsset } from "../assets/add.mjs";

export const summary = "asset spine: list | check [--static] | scan | add <file> --id --kind --owner --license --tool";

function parseArgs(args) {
  const opts = {};
  const pos = [];
  const flags = new Set(["static", "json"]);
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (!a.startsWith("--")) { pos.push(a); continue; }
    const eq = a.indexOf("=");
    const key = (eq === -1 ? a.slice(2) : a.slice(2, eq)).replace(/-([a-z])/g, (_, c) => c.toUpperCase());
    if (eq !== -1) opts[key] = a.slice(eq + 1);
    else if (flags.has(key)) opts[key] = true;
    else opts[key] = args[++i];
  }
  return { opts, pos };
}

const usage = () => { console.error("usage: tl assets list [--kind k] [--owner o] | check [--static] | scan | add <file> --id --kind --owner --license --tool [--model --prompt-hash --author --tris --px WxH]"); return 2; };

export async function run(args, ctx) {
  const [sub, ...rest] = args;
  const { opts, pos } = parseArgs(rest);
  const root = process.env.TL_ASSETS_ROOT ? path.resolve(process.env.TL_ASSETS_ROOT) : REPO;
  switch (sub) {
    case "list": return list(root, opts);
    case "check": return check(root, opts, ctx);
    case "scan": return scan(root, ctx);
    case "add": return add(root, pos, opts);
    default: return usage();
  }
}

function list(root, opts) {
  let m;
  try { m = readJson(path.join(root, MANIFEST_REL)); } catch (e) { console.error(`cannot read ${MANIFEST_REL}: ${e.message}`); return 2; }
  const rows = m.assets.filter((e) => (!opts.kind || e.kind === opts.kind) && (!opts.owner || e.owner === opts.owner));
  for (const e of rows) console.log(`${e.id.padEnd(30)} ${e.kind.padEnd(9)} ${e.source.padEnd(10)} ${tierOf(e).padEnd(11)} ${(e.owner).padEnd(12)} ${e.tris !== undefined ? String(e.tris).padStart(7) + " tris" : "".padStart(12)} ${String(e.bytes).padStart(9)} B  ${e.hash.slice(0, 10)}`);
  console.log(`${rows.length} of ${m.assets.length} assets`);
  return 0;
}

function check(root, opts, ctx) {
  let scanned = null;
  const extra = [];
  if (!opts.static) {
    const s = runScan(ctx);
    if (s.couldNotRun) { console.error(s.errors.join("\n")); return 2; }
    if (!s.ok) extra.push(step("scan", false, s.ms, s.errors.join("; ")));
    else { scanned = s.rows; extra.push(step("scan", true, s.ms, `${s.rows.length} kit parts built twice`)); }
  }
  const r = checkAssets({ root, scanned });
  return printVerdict("assets check", [...extra, ...r.steps], { mode: opts.static ? "static" : "full", problems: Object.fromEntries(Object.entries(r.problems).filter(([, v]) => v.length)) });
}

function scan(root, ctx) {
  const s = runScan(ctx);
  if (s.couldNotRun) { console.error(s.errors.join("\n")); return 2; }
  if (!s.ok) { console.error("scan failed: " + s.errors.join("; ")); return 1; }
  const mp = path.join(root, MANIFEST_REL);
  const cur = fs.existsSync(mp) ? readJson(mp) : { schema: "tl.assets/1", assets: [] };
  const keep = cur.assets.filter((e) => !(e.kind === "kit_part" && e.source === "procedural" && e.owner === "engine"));
  const next = { schema: "tl.assets/1", assets: [...keep, ...kitEntries(s.rows)] };
  const bad = validateManifest({ ...next, assets: [...next.assets].sort((a, b) => (a.id < b.id ? -1 : 1)) });
  if (bad.length) { console.error("scan produced an invalid manifest:\n" + bad.join("\n")); return 1; }
  const before = fs.existsSync(mp) ? fs.readFileSync(mp, "utf8") : "";
  fs.mkdirSync(path.dirname(mp), { recursive: true });
  writeManifest(root, next);
  const after = serializeManifest(next);
  console.log(`scan: ${s.rows.length} kit parts, ${after === before ? "manifest unchanged" : "manifest updated"} (${MANIFEST_REL}), ${s.ms} ms`);
  return 0;
}

function add(root, pos, opts) {
  if (pos.length !== 1) return usage();
  const r = addAsset({ root, file: pos[0], opts });
  for (const w of r.warnings) console.log(`WARN  ${w}`);
  if (!r.ok) { for (const e of r.errors) console.error(`FAIL  ${e}`); return 1; }
  console.log(`PASS  registered ${r.entry.id} (${r.entry.kind}, ${r.entry.bytes} bytes, sha256 ${r.entry.hash.slice(0, 12)})`);
  return 0;
}
