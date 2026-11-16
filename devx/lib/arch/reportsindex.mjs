// docs/generated/REPORTS.md: one page over docs/reports/**/*.md. Per report its id, date, brief and status; then every
// bullet of a "what changed for a pack author" section, newest report first, with mechanical stale marks; then every
// numbered item of a Questions section. `tl arch --index` writes it; rule reports-index-fresh keeps it equal to what
// would be generated. The reports themselves are history and are never edited.
import { createHash } from "node:crypto";

export const REPORTS_FILE = "docs/generated/REPORTS.md";
const DIR = "docs/reports/";
const MANIFEST = "engine/kernel/runner/manifest.gd";
const REGEN = "node devx/bin/tl.mjs arch --index";
// The spellings the reports use: What changed / WHAT CHANGED / What changes / What a pack author must know / For a pack author.
const PACK_RE = /^(?:\d+\.\s*)?(?:what (?:changed|changes) for a pack author|what a pack author must know|for a pack author)\b/i;
const QUESTIONS_RE = /^(?:\d+\.\s*)?questions\b/i;
const STATUS_RE = /^status\b/i;
const ITEM_RE = /^(?:[-*]|\d+[.)])\s+/;
const NUM_RE = /^\d+[.)]\s+/;

const cell = (s) => String(s).replace(/\|/g, "\\|");
const short = (s, n) => {
  if (s.length <= n) return s;
  let t = s.slice(0, n).replace(/\s+\S*$/, "");
  if ((t.match(/`/g) ?? []).length % 2) t += "`";   // never leave a code span open
  return t + " ...";
};

/** Headings outside code fences: [{i (0-based line), level, title}]. */
function headings(lines) {
  const out = [];
  let fence = null;
  lines.forEach((l, i) => {
    const f = l.match(/^\s*(```|~~~)/);
    if (f) { fence = fence === null ? f[1] : fence === f[1] ? null : fence; return; }
    if (fence) return;
    const m = l.match(/^(#{1,6})\s+(.*?)\s*#*\s*$/);
    if (m) out.push({ i, level: m[1].length, title: m[2] });
  });
  return out;
}

/** Body line range [from, to) of each heading: up to the next heading of the same or a higher level. */
function sections(lines) {
  const hs = headings(lines);
  return hs.map((h, k) => {
    const next = hs.slice(k + 1).find((x) => x.level <= h.level);
    return { ...h, from: h.i + 1, to: next ? next.i : lines.length };
  });
}

/** Items of a section: top-level list items (a continuation line joins its item); with none, its paragraphs.
 *  -> [{line (1-based), text, numbered}]. Code fences inside the section are skipped. */
function items(lines, sec, { paragraphs = false } = {}) {
  const out = [];
  let cur = null, fence = false, blank = false;
  for (let i = sec.from; i < sec.to; i++) {
    const l = lines[i];
    if (/^\s*(```|~~~)/.test(l)) { fence = !fence; cur = null; continue; }
    if (fence) continue;
    if (!l.trim()) { blank = true; continue; }
    if (ITEM_RE.test(l)) { cur = { line: i + 1, text: l.replace(ITEM_RE, "").trim(), numbered: NUM_RE.test(l) }; out.push(cur); }
    else if (cur && (!blank || /^\s/.test(l))) cur.text += " " + l.trim().replace(ITEM_RE, "");
    else cur = null;
    blank = false;
  }
  if (out.length || !paragraphs) return out;
  for (let i = sec.from; i < sec.to; i++) {   // no list: one item per paragraph
    if (!lines[i].trim()) { cur = null; continue; }
    if (cur) cur.text += " " + lines[i].trim(); else { cur = { line: i + 1, text: lines[i].trim(), numbered: false }; out.push(cur); }
  }
  return out;
}

const ver = (s) => s.split(".").map(Number);
const below = (a, b) => { const [x, y] = [ver(a), ver(b)]; return x[0] < y[0] || (x[0] === y[0] && (x[1] ?? 0) < (y[1] ?? 0)); };

/** Repo-path-shaped backticked spans of a text (`a/b`, an optional `:line` and trailing `/` dropped). */
function cited(text) {
  const out = [];
  for (const m of text.matchAll(/`([^`\s]+)`/g)) {
    const p = m[1].replace(/:\d+(?:-\d+)?(?:,\s*\d+(?:-\d+)?)*$/, "").replace(/\/$/, "");
    if (/^[\w.-]+(?:\/[\w.-]+)+$/.test(p)) out.push(p);
  }
  return out;
}

/** The two mechanical stale tests -> list of marks. */
function staleMarks(text, live, kernel) {
  const marks = [];
  const gone = [];
  for (const p of cited(text)) {
    if (!live.top.has(p.split("/")[0])) continue;
    if (!live.files.has(p) && !live.dirs.has(p)) gone.push(p);
  }
  if (gone.length) marks.push("[stale: path gone]");
  if (kernel && [...text.matchAll(/kernelApi[`"']*\s*[:=]?\s*[`"']*(\d+\.\d+)/g)].some((m) => below(m[1], kernel))) marks.push(`[stale: kernel now ${kernel}]`);
  return marks;
}

/** One report file -> {id, file, date, brief, status, pack: [items], questions: [items]}. */
function parseReport(io, file) {
  const lines = io.read(file).split("\n");
  const head = [];
  for (const l of lines.slice(0, 12)) { if (/^---\s*$/.test(l) || /^## /.test(l)) break; head.push(l); }
  const date = head.join("\n").match(/\b\d{4}-\d{2}-\d{2}\b/)?.[0];
  const briefPath = head.join("\n").match(/`(briefs\/[^`\s]+)`/)?.[1];
  const secs = sections(lines);
  const st = secs.find((s) => s.level >= 2 && STATUS_RE.test(s.title));
  const status = st ? lines.slice(st.from, st.to).map((l) => l.trim()).find((l) => l && !/^(```|~~~)/.test(l))?.replace(ITEM_RE, "") : undefined;
  const r = { id: file.slice(DIR.length, -3), file, date, status, pack: [], questions: [] };
  if (briefPath) r.brief = io.has(briefPath) ? `\`${briefPath}\`` : `brief missing: \`${briefPath}\``;
  for (const s of secs.filter((x) => x.level >= 2 && PACK_RE.test(x.title))) r.pack.push(...items(lines, s, { paragraphs: true }));
  for (const s of secs.filter((x) => x.level >= 2 && QUESTIONS_RE.test(x.title))) r.questions.push(...items(lines, s).filter((x) => x.numbered));
  return r;
}

/** -> {text, reports}. Deterministic: depends only on the files of the tree. */
export function generateReports(io) {
  const files = io.files.filter((f) => f.startsWith(DIR) && f.endsWith(".md")).sort();
  const live = { files: new Set(io.files), dirs: new Set(), top: new Set() };
  for (const f of io.files) { const parts = f.split("/"); for (let k = 1; k < parts.length; k++) live.dirs.add(parts.slice(0, k).join("/")); if (parts.length > 1) live.top.add(parts[0]); }
  const kernel = io.has(MANIFEST) ? io.read(MANIFEST).match(/const KERNEL_API(?::\s*String)?\s*=\s*"([\d.]+)"/)?.[1] : undefined;
  const reports = files.map((f) => parseReport(io, f));
  for (const r of reports) for (const b of r.pack) b.marks = staleMarks(b.text, live, kernel);
  const newest = [...reports].sort((a, b) => (b.date ?? "").localeCompare(a.date ?? "") || a.id.localeCompare(b.id));
  const nPack = reports.reduce((n, r) => n + r.pack.length, 0);
  const nStale = reports.reduce((n, r) => n + r.pack.filter((b) => b.marks.length).length, 0);
  const nQ = reports.reduce((n, r) => n + r.questions.length, 0);
  const at = (r, x) => `\`${r.file}:${x.line}\``;
  const L = [
    "# Report digest",
    "",
    `Generated from \`${DIR}**/*.md\`, \`briefs/\` and \`${MANIFEST}\` by \`${REGEN}\`; do not edit (rule \`reports-index-fresh\`).`,
    "The reports are history and stay as written; this page only collects them.",
    "",
    `${reports.length} reports, ${nPack} pack-author bullets (${nStale} marked stale), ${nQ} questions raised.`,
    "",
    "A stale mark is one of two mechanical tests on a pack-author bullet, nothing more:",
    "- `[stale: path gone]`: the bullet cites in backticks a repo path (first segment a top-level directory of the repo, an optional `:line` dropped) that no file or directory of the tree matches now.",
    `- \`[stale: kernel now X]\`: the bullet names a \`kernelApi\` version below \`KERNEL_API\` in \`${MANIFEST}\` (X${kernel ? ` = ${kernel}` : ": not found, test off"}).`,
    "",
    "An unmarked bullet passed both tests; it was not read for being right.",
    "",
    "## Reports",
    "",
    "| Report | Date | Brief | Status |",
    "|---|---|---|---|",
    ...newest.map((r) => `| ${cell(r.id)} | ${r.date ?? "-"} | ${cell(r.brief ?? "-")} | ${cell(r.status ? short(r.status, 140) : "-")} |`),
    "",
    "## What changed for a pack author (newest report first)",
    "",
  ];
  for (const r of newest.filter((x) => x.pack.length)) {
    L.push(`### ${r.id} (${r.date ?? "undated"})`, "");
    for (const b of r.pack) L.push(`- ${at(r, b)} ${[...b.marks, short(b.text, 400)].join(" ")}`);
    L.push("");
  }
  L.push(`## Questions raised (${nQ})`, "",
    "Numbered items under a report's Questions heading, as the builder asked them. This page cannot tell an answered question",
    "from an unanswered one: where the Director answered, it is in that report's \"Director's decisions on the builder's questions\".",
    "");
  for (const r of newest.filter((x) => x.questions.length)) {
    L.push(`### ${r.id} (${r.date ?? "undated"})`, "");
    r.questions.forEach((q, k) => L.push(`${k + 1}. ${at(r, q)} ${short(q.text, 300)}`));
    L.push("");
  }
  return { text: L.join("\n").replace(/\n+$/, "") + "\n", reports };
}

/** Every path a pack-author bullet cites, as globs (`p` and `p/**`): a change to any of them can turn the digest's stale
 *  marks, so the arch step must run under `tl check --changed` (devx/lib/gate/steps/arch.mjs). Sorted, deduplicated. */
export function citedPathGlobs(io) {
  const files = io.files.filter((f) => f.startsWith(DIR) && f.endsWith(".md"));
  const out = new Set();
  for (const f of files) for (const b of parseReport(io, f).pack) for (const p of cited(b.text)) { out.add(p); out.add(`${p}/**`); }
  return [...out].sort();
}

/** Rule reports-index-fresh. A tree with no reports and no digest passes. Cheap: reads the reports once, no Godot. */
export function reportsIndexFresh(io) {
  const g = generateReports(io);
  if (!g.reports.length && !io.has(REPORTS_FILE)) return { findings: [], notes: [`no ${DIR} reports: nothing to digest`] };
  if (!io.has(REPORTS_FILE)) return { findings: [{ file: REPORTS_FILE, key: "missing", message: `${REPORTS_FILE} missing; run \`${REGEN}\`` }] };
  const have = io.read(REPORTS_FILE);
  if (have === g.text) return { findings: [], notes: [`${g.reports.length} report(s) digested`] };
  const a = have.split("\n"), b = g.text.split("\n");
  let i = 0;
  while (i < a.length && a[i] === b[i]) i++;
  // The key carries the generated text's hash: a baseline can never hold a later staleness.
  const key = "stale:" + createHash("sha1").update(g.text).digest("hex").slice(0, 12);
  return { findings: [{ file: REPORTS_FILE, line: i + 1, key, message: `${REPORTS_FILE} is stale at line ${i + 1} (a report, a brief, a cited path or KERNEL_API changed); run \`${REGEN}\` and commit it` }] };
}
