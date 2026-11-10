// Runs the rules against a root directory and applies the baseline. No Godot, no network.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { CHECKERS } from "./checkers.mjs";
import { makeIo } from "./util.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const DEVX = path.resolve(HERE, "..", "..");
export const RULES_FILE = path.join(DEVX, "arch.rules.json");
export const BASELINE_REL = "devx/arch.baseline.json";

export const loadRules = (file = RULES_FILE) => JSON.parse(fs.readFileSync(file, "utf8")).rules;
export function loadBaseline(root) {
  try { return JSON.parse(fs.readFileSync(path.join(root, BASELINE_REL), "utf8")); } catch { return { schema: "tl.arch.baseline/1", sizes: {}, grandfathered: {} }; }
}

/** -> {results: [{rule, ok, ms, findings, grandfathered, notes}], io}. `only` = array of rule ids. */
export function runRules({ root, rules = loadRules(), baseline = loadBaseline(root), only = null }) {
  const io = makeIo(root, { baseline });
  const results = [];
  for (const rule of rules) {
    if (only && !only.includes(rule.id)) continue;
    const t0 = Date.now();
    const fn = CHECKERS[rule.checker];
    if (!fn) { results.push({ rule, ok: false, ms: 0, findings: [{ file: "devx/arch.rules.json", key: "unknown-checker", message: `rule '${rule.id}' names unknown checker '${rule.checker}'` }], grandfathered: [], notes: [] }); continue; }
    let r;
    try { r = fn(io, rule); } catch (e) { r = { findings: [{ file: "devx/lib/arch", key: "crash", message: `checker ${rule.checker} crashed: ${e.message}` }] }; }
    const held = new Set(baseline.grandfathered?.[rule.id] ?? []);
    const findings = r.findings.filter((f) => !held.has(f.key));
    const grandfathered = r.findings.filter((f) => held.has(f.key));
    results.push({ rule, ok: findings.length === 0, ms: Date.now() - t0, findings, grandfathered, notes: r.notes ?? [] });
  }
  return { results, io };
}

/** The baseline that would make the current tree pass: sizes of over-budget files, keys of grandfatherable findings.
 *  Never includes api-index-fresh (regenerate instead), scope-claims, or the crash/unknown-checker pseudo findings. */
export function computeBaseline({ root, rules = loadRules(), old = loadBaseline(root) }) {
  const bare = { schema: "tl.arch.baseline/1", sizes: {}, grandfathered: {} };
  const { results, io } = runRules({ root, rules, baseline: bare });
  const next = { schema: "tl.arch.baseline/1", sizes: Object.fromEntries(Object.entries(io.current ?? {}).sort()), grandfathered: {} };
  for (const r of results) {
    if (["size-ratchet", "api-index-fresh", "scope-claims"].includes(r.rule.id)) continue;
    const keys = [...new Set(r.findings.filter((f) => f.key !== "crash" && f.key !== "unknown-checker").map((f) => f.key))].sort();
    if (keys.length) next.grandfathered[r.rule.id] = keys;
  }
  return { next, old };
}

export function diffBaseline(old, next) {
  const out = [];
  for (const f of new Set([...Object.keys(old.sizes ?? {}), ...Object.keys(next.sizes)])) {
    const a = old.sizes?.[f], b = next.sizes[f];
    if (a !== b) out.push(`size ${f}: ${a ?? "-"} -> ${b ?? "-"}`);
  }
  for (const id of new Set([...Object.keys(old.grandfathered ?? {}), ...Object.keys(next.grandfathered)])) {
    const a = new Set(old.grandfathered?.[id] ?? []), b = new Set(next.grandfathered[id] ?? []);
    for (const k of b) if (!a.has(k)) out.push(`+ ${id}: ${k}`);
    for (const k of a) if (!b.has(k)) out.push(`- ${id}: ${k}`);
  }
  return out;
}
