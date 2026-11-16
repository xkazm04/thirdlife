// node --test devx/test/reportsindex.test.mjs
// docs/generated/REPORTS.md: one page of the reports' pack-author changes and the questions they raised, with mechanical
// stale marks, and rule reports-index-fresh that keeps it equal to what `tl arch --index` generates. Fixtures are temp
// dirs; the real-tree case asserts structure, never the corpus totals (they move whenever a report lands).
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { runRules, loadRules } from "../lib/arch/core.mjs";
import { makeIo } from "../lib/arch/util.mjs";
import { generateReports, REPORTS_FILE } from "../lib/arch/reportsindex.mjs";
import { run as archCmd } from "../lib/commands/arch.mjs";
import { REPO } from "../lib/ctx.mjs";

const rules = loadRules();
function fixture(files) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "tl-reports-"));
  for (const [f, text] of Object.entries(files)) { fs.mkdirSync(path.dirname(path.join(root, f)), { recursive: true }); fs.writeFileSync(path.join(root, f), text); }
  return root;
}
const one = (root) => runRules({ root, rules, only: ["reports-index-fresh"] }).results[0];
const msgs = (r) => r.findings.map((f) => f.message).join("\n");
const gen = (root) => generateReports(makeIo(root)).text;
const header = (id, date, brief) => `# ${id} a thing: builder report\n\nBrief \`${brief}\`. Builder wall time 13:22 to 15:02 on ${date}.\n\n---\n\n`;

const tree = () => ({
  "engine/kernel/runner/manifest.gd": 'extends RefCounted\nconst KERNEL_API: String = "1.5"\n',
  "engine/here.gd": "extends Node\n",
  "briefs/BRIEF-A.md": "# brief A\n",
  "docs/reports/A.md": header("A", "2026-11-11", "briefs/BRIEF-A.md") +
    "## STATUS\n\nAll built and proven.\n\n## WHAT CHANGED FOR A PACK AUTHOR\n" +
    "- Write `\"kernelApi\": \"1.0\"`; 0.1 still runs.\n" +
    "- Call `engine/gone.gd` for the old helper.\n" +
    "- Call `engine/here.gd:3` for the new one,\n  which is live.\n\n" +
    "## QUESTIONS\n1. Keep the rounding?\n2. **Lint `_input`?** It changes PACK.md.\n   - a sub point\n3. Timer acceptable?\n4. Who takes patch 2a?\n\n" +
    "```\n## Questions\n1. not a question: inside a code fence\n```\n\n" +
    "## Director verification\n\n### Director's decisions on the builder's questions\n1. Yes.\n",
  "docs/reports/B.md": header("B", "2026-11-12", "briefs/BRIEF-X.md") +
    "## Status\n\nPartly built.\n\n## What a pack author must know\n- Say `\"kernelApi\": \"1.5\"` for the new bind.\n",
});

test("1 a pack-author section (any case) lists its bullets under the report's id and date, newest report first", () => {
  const t = gen(fixture(tree()));
  const sec = t.slice(t.indexOf("## What changed for a pack author"), t.indexOf("## Questions raised"));
  assert.ok(sec.indexOf("### B (2026-11-12)") >= 0 && sec.indexOf("### A (2026-11-11)") > sec.indexOf("### B (2026-11-12)"), sec);
  const a = sec.slice(sec.indexOf("### A (2026-11-11)"));
  assert.equal(a.split("\n").filter((l) => l.startsWith("- ")).length, 3, a);
  assert.match(a, /docs\/reports\/A\.md:\d+.*Write `"kernelApi": "1\.0"`; 0\.1 still runs\./);
  assert.match(a, /for the new one, which is live\./, "a continuation line joins its bullet");
});

test("2 a bullet citing a path that no longer exists is marked [stale: path gone]; a live path is not", () => {
  const t = gen(fixture(tree()));
  assert.match(t, /\[stale: path gone\][^\n]*`engine\/gone\.gd`/);
  assert.doesNotMatch(t, /\[stale[^\n]*`engine\/here\.gd:3`/);
});

test("3 a kernelApi stamp below KERNEL_API in manifest.gd is marked [stale: kernel now 1.5]; the current one is not", () => {
  const t = gen(fixture(tree()));
  assert.match(t, /\[stale: kernel now 1\.5\][^\n]*"kernelApi": "1\.0"/);
  assert.doesNotMatch(t, /\[stale[^\n]*"kernelApi": "1\.5"/);
  assert.match(t, /`\[stale: path gone\]`/, "the header names the path test");
  assert.match(t, /`\[stale: kernel now X\]`/, "the header names the kernelApi test");
});

test("4 numbered questions are listed as questions raised with report id and line, counted in the header; fences and the Director's decisions are not questions", () => {
  const root = fixture(tree());
  const t = gen(root);
  assert.match(t, /^## Questions raised \(4\)$/m);
  assert.match(t, /4 questions raised/);
  const q = t.slice(t.indexOf("## Questions raised"));
  const items = q.split("\n").filter((l) => /^\d+\. /.test(l));
  assert.equal(items.length, 4, q);
  const src = fs.readFileSync(path.join(root, "docs/reports/A.md"), "utf8").split("\n");
  for (const l of items) {
    const m = l.match(/`docs\/reports\/A\.md:(\d+)`/);
    assert.ok(m, l);
    assert.match(src[Number(m[1]) - 1], /^\d+\. /, `line ${m[1]} is the question`);
  }
  assert.match(q, /Who takes patch 2a\?/);
  assert.doesNotMatch(t, /not a question|^\d+\. [^\n]*Yes\.$/m);
  assert.doesNotMatch(t, /\bopen\b/i, "the digest cannot tell answered from open, so it never says open");
});

test("5 a report whose header names a brief that is missing shows 'brief missing'; a present brief is named", () => {
  const t = gen(fixture(tree()));
  assert.match(t, /^\| B \| 2026-11-12 \| brief missing: `briefs\/BRIEF-X\.md` \| Partly built\. \|$/m);
  assert.match(t, /^\| A \| 2026-11-11 \| `briefs\/BRIEF-A\.md` \| All built and proven\. \|$/m);
});

test("6 rule reports-index-fresh: a digest differing from the generated text fails naming the file and the regen command; equal passes; regen fixes", async () => {
  const root = fixture(tree());
  let r = one(root);
  assert.equal(r.ok, false, "missing digest");
  assert.match(msgs(r), /node devx\/bin\/tl\.mjs arch --index/);
  fs.mkdirSync(path.join(root, "docs/generated"), { recursive: true });
  fs.writeFileSync(path.join(root, REPORTS_FILE), gen(root));
  assert.ok(one(root).ok, msgs(one(root)));
  fs.writeFileSync(path.join(root, "docs/reports/C.md"), header("C", "2026-11-13", "briefs/BRIEF-A.md") + "## Questions\n1. New?\n");
  r = one(root);
  assert.equal(r.ok, false, "a new report without a regen is red");
  assert.equal(r.findings[0].file, REPORTS_FILE);
  assert.match(msgs(r), /docs\/generated\/REPORTS\.md.*node devx\/bin\/tl\.mjs arch --index/);
  const log = console.log; console.log = () => {};
  try { await archCmd(["--index"], {}, root); } finally { console.log = log; }
  assert.ok(one(root).ok, `after --index: ${msgs(one(root))}`);
  assert.ok(one(fixture({ "engine/here.gd": "x\n" })).ok, "a tree with no reports and no digest passes");
});

test("7 real tree: every report is a row, the digest is fresh, P7-CONTRACT.md:237 is marked stale", () => {
  const io = makeIo(REPO);
  const g = generateReports(io);
  const reports = io.files.filter((f) => /^docs\/reports\/.+\.md$/.test(f));
  assert.ok(reports.length > 0);
  assert.equal(g.reports.length, reports.length);
  for (const f of reports) assert.ok(g.text.includes(`| ${f.slice("docs/reports/".length, -3)} |`), `row for ${f}`);
  assert.match(g.text, /`docs\/reports\/P7-CONTRACT\.md:237` \[stale: kernel now \d+\.\d+\]/);
  const r = one(REPO);
  assert.ok(r.ok, msgs(r));
});
