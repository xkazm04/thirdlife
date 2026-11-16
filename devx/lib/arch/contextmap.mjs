// context-map.json is the one partition of the repo: the skills target by it and docs/OWNERSHIP.md's scope map is generated
// from it. Rule context-map-cover: every tracked file lies in exactly one context. Rule ownership-fresh: the block between
// the generated:scope-map markers in docs/OWNERSHIP.md equals what `tl arch --index` writes; the prose around it stays
// hand-written.
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { globToRe } from "./util.mjs";

export const CONTEXT_MAP = "context-map.json";
export const OWNERSHIP_FILE = "docs/OWNERSHIP.md";
export const MARK_BEGIN = "<!-- generated:scope-map -->";
export const MARK_END = "<!-- /generated:scope-map -->";

/** -> {map} or {finding}; {absent: true} when the tree has no context map. */
export function loadContextMap(io) {
  if (!io.has(CONTEXT_MAP)) return { absent: true };
  let map;
  try { map = JSON.parse(io.read(CONTEXT_MAP)); } catch (e) { return { finding: { file: CONTEXT_MAP, key: "parse", message: `not valid JSON: ${e.message}` } }; }
  if (map?.schema !== "tl.contextmap/1" || !Array.isArray(map.contexts) || map.contexts.some((c) => typeof c?.name !== "string" || !Array.isArray(c.paths))) {
    return { finding: { file: CONTEXT_MAP, key: "shape", message: 'expected {"schema":"tl.contextmap/1","contexts":[{"name","paths":["glob"]}]}' } };
  }
  return { map };
}

/** Tracked files only: an untracked scratch file (a crash dump) belongs to nobody and must not fail the gate. Falls back
 *  to io.files outside a git work tree (fixtures). */
function trackedFiles(io) {
  if (io.has(".git")) {
    const r = spawnSync("git", ["ls-files", "--cached"], { cwd: io.root, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
    if (r.status === 0) return [...new Set(r.stdout.split("\n").map((s) => s.trim()).filter(Boolean))].filter((f) => io.has(f)).sort();
  }
  return io.files;
}

/** Rule context-map-cover. A file no context names is a finding; so is a file two contexts name (one file, two owners). */
export function contextMapCover(io) {
  const m = loadContextMap(io);
  if (m.absent) return { findings: [], notes: [`${CONTEXT_MAP} absent: nothing to cover`] };
  if (m.finding) return { findings: [m.finding] };
  const res = m.map.contexts.map((c) => ({ name: c.name, res: c.paths.map(globToRe) }));
  const files = trackedFiles(io);
  const findings = [];
  for (const f of files) {
    const hit = res.filter((c) => c.res.some((r) => r.test(f))).map((c) => c.name);
    if (!hit.length) findings.push({ file: f, key: `uncovered:${f}`, message: `${f} is in no context of ${CONTEXT_MAP}: add a glob to the context that owns it` });
    else if (hit.length > 1) findings.push({ file: f, key: `overlap:${f}`, message: `${f} is in ${hit.length} contexts (${hit.join(", ")}): one file, one owner` });
  }
  return { findings, notes: [`${files.length} tracked file(s) in ${res.length} context(s)`] };
}

const cell = (s) => String(s).replace(/\|/g, "\\|").replace(/\n/g, " ");

/** The scope map table (one row per context, in map order) -> {text, findings}. A missing owner or rule is a finding,
 *  never an empty cell. */
export function generateScopeMap(map) {
  const findings = [];
  const lines = [
    `Generated from \`${CONTEXT_MAP}\` by \`tl arch --index\`; do not edit between the markers (rule \`ownership-fresh\`).`,
    "",
    "| Context | Group | Path globs | Owner role | Change rule |",
    "|---|---|---|---|---|",
  ];
  for (const c of map.contexts) {
    for (const k of ["owner", "rule"]) {
      if (typeof c[k] !== "string" || !c[k].trim()) findings.push({ file: CONTEXT_MAP, key: `no-${k}:${c.name}`, message: `context ${c.name} has no ${k}` });
    }
    const owner = c.owner?.trim() ? c.owner : "(no owner)";
    const rule = c.rule?.trim() ? c.rule : "(no rule)";
    lines.push(`| ${cell(c.name)} | ${cell(c.group ?? "-")} | ${c.paths.map((g) => "`" + cell(g) + "`").join(", ")} | ${cell(owner)} | ${cell(rule)} |`);
  }
  return { text: lines.join("\n") + "\n", findings };
}

/** Splits docs/OWNERSHIP.md around the markers -> {before, block, after, line} or null. `line` = first line of the block. */
function splitMarked(text) {
  const a = text.indexOf(MARK_BEGIN + "\n");
  const b = text.indexOf(MARK_END, a + 1);
  if (a < 0 || b < 0) return null;
  const start = a + MARK_BEGIN.length + 1;
  return { before: text.slice(0, start), block: text.slice(start, b), after: text.slice(b), line: text.slice(0, start).split("\n").length };
}

/** Rule ownership-fresh. */
export function ownershipFresh(io) {
  const m = loadContextMap(io);
  if (m.absent) return { findings: [], notes: [`${CONTEXT_MAP} absent: no scope map to generate`] };
  if (m.finding) return { findings: [m.finding] };
  const g = generateScopeMap(m.map);
  const findings = [...g.findings];
  if (!io.has(OWNERSHIP_FILE)) return { findings: [...findings, { file: OWNERSHIP_FILE, key: "absent", message: `${OWNERSHIP_FILE} absent: it carries the generated scope map` }] };
  const s = splitMarked(io.read(OWNERSHIP_FILE));
  if (!s) return { findings: [...findings, { file: OWNERSHIP_FILE, key: "markers", message: `no ${MARK_BEGIN} ... ${MARK_END} block: put the markers where the scope map goes and run \`tl arch --index\`` }] };
  if (s.block !== g.text) {
    const have = s.block.split("\n"), want = g.text.split("\n");
    let i = 0;
    while (i < Math.max(have.length, want.length) && have[i] === want[i]) i++;
    findings.push({ file: OWNERSHIP_FILE, line: s.line + i, key: "stale", message: `scope map is stale at row ${JSON.stringify(have[i] ?? "")}, generated ${JSON.stringify(want[i] ?? "")}: run \`tl arch --index\` (never edit between the markers)` });
  }
  return { findings, notes: [`${m.map.contexts.length} context(s) in the scope map`] };
}

/** `tl arch --index`: rewrite the block between the markers; prose outside them stays byte-identical. -> {ok, lines}. */
export function writeScopeMap(io, root) {
  const m = loadContextMap(io);
  if (m.absent) return { ok: true, lines: [`${CONTEXT_MAP} absent: no scope map`] };
  if (m.finding) return { ok: false, lines: [`NOT written: ${OWNERSHIP_FILE} (${m.finding.message})`] };
  const g = generateScopeMap(m.map);
  const f = path.join(root, OWNERSHIP_FILE);
  const text = fs.existsSync(f) ? fs.readFileSync(f, "utf8").replace(/\r\n/g, "\n") : null;
  const s = text === null ? null : splitMarked(text);
  if (!s) return { ok: false, lines: [`NOT written: ${OWNERSHIP_FILE} has no ${MARK_BEGIN} ... ${MARK_END} block`] };
  const next = s.before + g.text + s.after;
  if (next !== text) fs.writeFileSync(f, next);
  return { ok: g.findings.length === 0, lines: [`${next === text ? "unchanged" : "wrote"} ${OWNERSHIP_FILE} scope map (${m.map.contexts.length} contexts)`, ...g.findings.map((x) => `  ${x.message}`)] };
}
