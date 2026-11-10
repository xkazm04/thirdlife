// Rules 3, 6, 7: uid pairs, the per-file size ratchet, and session scope claims.
import { lineCount, globToRe } from "./util.mjs";

/** Rule 3. Every X.gd.uid has its X.gd and every X.gd has its X.gd.uid. Godot writes the uid when the editor or an
 *  import first sees a script; scripts only ever loaded by the runner (packs, seeds, examples, templates: params.noUidDirs) never get one, so
 *  those are exempt from the .gd-needs-uid half; an orphan .uid is flagged everywhere. */
export function uidOrphans(io, rule = {}) {
  const noUid = rule.params?.noUidDirs ?? ["engine/seeds/", "engine/packs/", "engine/kernel/examples/", "devx/templates/"];
  const set = new Set(io.files);
  const findings = [];
  for (const f of io.files) {
    if (f.endsWith(".gd.uid") && !set.has(f.slice(0, -4))) findings.push({ file: f, key: f, message: "uid file without its .gd" });
    if (f.endsWith(".gd") && !set.has(f + ".uid") && !noUid.some((d) => f.startsWith(d))) findings.push({ file: f, key: f, message: ".gd without its .gd.uid" });
  }
  return { findings };
}

/** Rule 6. A tracked source file may not exceed `budget` lines; a file already over is held at its baseline size: it may
 *  shrink, never grow. Baseline shape: {sizes: {file: lines}}. */
export function sizeRatchet(io, rule) {
  const p = { budget: 600, exts: [".gd", ".ts", ".mjs"], ...(rule.params ?? {}) };
  const sizes = io.baseline.sizes ?? {};
  const findings = [];
  let grand = 0;
  io.current = {};
  for (const f of io.files) {
    if (!p.exts.some((e) => f.endsWith(e)) || f.includes("node_modules/")) continue;
    const n = lineCount(io.read(f));
    if (n <= p.budget) continue;
    io.current[f] = n;
    const held = sizes[f];
    if (held === undefined) findings.push({ file: f, key: f, message: `${n} lines, budget ${p.budget}; split it (or run \`tl arch --update-baseline\` if it must be grandfathered)` });
    else if (n > held) findings.push({ file: f, key: f, message: `${n} lines, grew past its grandfathered ${held} (budget ${p.budget}): a file may shrink but not grow` });
    else grand++;
  }
  return { findings, notes: grand ? [`${grand} file(s) over ${p.budget} held at their baseline size`] : [] };
}

/** Two globs overlap when they could name the same file. Exact when either has no wildcard; otherwise conservative:
 *  the literal directory prefixes (up to the first wildcard segment) must not be disjoint. */
export function globsOverlap(a, b) {
  const wild = (g) => /[*?]/.test(g);
  if (!wild(a) && !wild(b)) return a === b;
  if (!wild(a)) return globToRe(b).test(a);
  if (!wild(b)) return globToRe(a).test(b);
  const pre = (g) => g.split("/").filter((_, i, arr) => !arr.slice(0, i + 1).some((s) => /[*?]/.test(s)));
  const pa = pre(a), pb = pre(b);
  const n = Math.min(pa.length, pb.length);
  for (let i = 0; i < n; i++) if (pa[i] !== pb[i]) return false;
  return true;
}

/** Rule 7. .claude/sessions.json = {"sessions":[{"id","scope":["glob"],"note"}]}; no two sessions' scopes overlap. */
export function scopeClaims(io, rule) {
  const file = rule.params?.file ?? ".claude/sessions.json";
  if (!io.has(file)) return { findings: [], notes: [`${file} absent: nothing claimed`] };
  let doc;
  try { doc = JSON.parse(io.read(file)); } catch (e) { return { findings: [{ file, key: "parse", message: `not valid JSON: ${e.message}` }] }; }
  const sessions = Array.isArray(doc?.sessions) ? doc.sessions : null;
  if (!sessions) return { findings: [{ file, key: "shape", message: 'expected {"sessions":[{"id","scope":["glob"]}]}' }] };
  const findings = [];
  for (const s of sessions) if (typeof s?.id !== "string" || !Array.isArray(s.scope)) findings.push({ file, key: `shape:${s?.id}`, message: `session ${JSON.stringify(s?.id)} needs a string id and a scope array` });
  const ok = sessions.filter((s) => typeof s?.id === "string" && Array.isArray(s.scope));
  for (let i = 0; i < ok.length; i++) for (let j = i + 1; j < ok.length; j++) {
    for (const ga of ok[i].scope) for (const gb of ok[j].scope) {
      if (globsOverlap(ga, gb)) findings.push({ file, key: `${ok[i].id}|${ok[j].id}|${ga}|${gb}`, message: `scopes overlap: ${ok[i].id} '${ga}' and ${ok[j].id} '${gb}'` });
    }
  }
  return { findings, notes: [`${ok.length} session(s) checked`] };
}
