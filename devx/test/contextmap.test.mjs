// node --test devx/test/contextmap.test.mjs
// context-map.json is the one partition of the repo: rule context-map-cover (every tracked file in exactly one context) and
// rule ownership-fresh (the scope map in docs/OWNERSHIP.md is the table `tl arch --index` generates from it).
// Fixtures are temp dirs (no .git: the file walk stands in for git ls-files).
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { runRules, loadRules, computeBaseline } from "../lib/arch/core.mjs";
import { generateScopeMap, MARK_BEGIN, MARK_END, OWNERSHIP_FILE } from "../lib/arch/contextmap.mjs";
import { run as archCmd } from "../lib/commands/arch.mjs";
import { REPO } from "../lib/ctx.mjs";

const rules = loadRules();
const one = (root, id) => runRules({ root, rules, only: [id] }).results[0];
const msgs = (r) => r.findings.map((f) => f.message).join("\n");
function fixture(files) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "tl-cmap-"));
  for (const [f, text] of Object.entries(files)) { fs.mkdirSync(path.dirname(path.join(root, f)), { recursive: true }); fs.writeFileSync(path.join(root, f), text); }
  return root;
}
const MAP = {
  schema: "tl.contextmap/1",
  contexts: [
    { name: "kernel", group: "engine", owner: "engine", rule: "selftest green", paths: ["engine/kernel/**"] },
    { name: "devx", group: "devx", owner: "devx", rule: "`tl check --tier fast`", paths: ["devx/**", "context-map.json", "CLAUDE.md"] },
    { name: "docs", group: "docs", owner: "whoever changes the thing", rule: "docs in the same commit", paths: ["docs/**"] },
  ],
};
const PROSE_TOP = "# Ownership\n\nHand-written intro.\n\n## Scope map\n\n";
const PROSE_END = "\n## Claims\n\nHand-written claims prose.\n";
const ownership = (map) => `${PROSE_TOP}${MARK_BEGIN}\n${generateScopeMap(map).text}${MARK_END}\n${PROSE_END}`;
const tree = (map = MAP, extra = {}) => ({
  "context-map.json": JSON.stringify(map, null, 2),
  "engine/kernel/a.gd": "extends Node\n",
  "devx/x.mjs": "export {};\n",
  "CLAUDE.md": "# start\n",
  [OWNERSHIP_FILE]: ownership(map),
  ...extra,
});

test("clean fixture: both rules pass", () => {
  const root = fixture(tree());
  for (const id of ["context-map-cover", "ownership-fresh"]) { const r = one(root, id); assert.ok(r.ok, `${id}: ${msgs(r)}`); }
});

test("context-map-cover: a tracked file matching no context glob is 1 finding naming it", () => {
  const root = fixture(tree(MAP, { "engine/boot/games.json": "{}\n" }));
  const r = one(root, "context-map-cover");
  assert.equal(r.ok, false);
  assert.equal(r.findings.length, 1, msgs(r));
  assert.equal(r.findings[0].file, "engine/boot/games.json");
  assert.match(r.findings[0].message, /engine\/boot\/games\.json/);
});

test("context-map-cover: a file in two contexts is 1 overlap finding naming both", () => {
  const map = structuredClone(MAP);
  map.contexts[2].paths.push("CLAUDE.md");
  const root = fixture(tree(map));
  const r = one(root, "context-map-cover");
  assert.equal(r.ok, false);
  assert.equal(r.findings.length, 1, msgs(r));
  assert.equal(r.findings[0].file, "CLAUDE.md");
  assert.match(r.findings[0].message, /devx/);
  assert.match(r.findings[0].message, /docs/);
});

test("ownership-fresh: a scope block that differs from the generated table names the first differing row", () => {
  const files = tree();
  files[OWNERSHIP_FILE] = files[OWNERSHIP_FILE].replace("| `docs/**` | whoever changes the thing |", "| `docs/**`, `CLAUDE.md` | whoever changes the thing |");
  assert.notEqual(files[OWNERSHIP_FILE], tree()[OWNERSHIP_FILE], "the edit took");
  const root = fixture(files);
  const r = one(root, "ownership-fresh");
  assert.equal(r.ok, false);
  assert.equal(r.findings.length, 1, msgs(r));
  assert.equal(r.findings[0].file, OWNERSHIP_FILE);
  assert.match(r.findings[0].message, /docs/);
  assert.match(r.findings[0].message, /CLAUDE\.md/);
  assert.ok(r.findings[0].line > 0);
});

test("--update-baseline never grandfathers an unmapped file, a stale scope map or a stale reports digest (regenerate instead)", () => {
  const files = tree(MAP, { "engine/boot/games.json": "{}\n" });
  files[OWNERSHIP_FILE] = files[OWNERSHIP_FILE].replace("| `docs/**` | whoever changes the thing |", "| `docs/**`, `CLAUDE.md` | whoever changes the thing |");
  const root = fixture(files);
  const ids = ["context-map-cover", "ownership-fresh", "reports-index-fresh"];
  for (const id of ids.slice(0, 2)) assert.equal(one(root, id).ok, false, `${id} fails on the fixture`);
  const { next } = computeBaseline({ root, rules, old: { sizes: {}, grandfathered: {} } });
  for (const id of ids) assert.equal(next.grandfathered[id], undefined, `${id} must never be held by the baseline`);
});

test("ownership-fresh: missing markers are a finding", () => {
  const files = tree();
  files[OWNERSHIP_FILE] = PROSE_TOP + "| a | b |\n" + PROSE_END;
  const r = one(fixture(files), "ownership-fresh");
  assert.equal(r.ok, false);
  assert.match(msgs(r), /generated:scope-map/);
});

test("a context with no owner or rule: the generator emits a finding, not an empty cell", () => {
  const map = structuredClone(MAP);
  delete map.contexts[0].owner;
  delete map.contexts[1].rule;
  const g = generateScopeMap(map);
  assert.ok(g.findings.some((f) => f.message === "context kernel has no owner"), JSON.stringify(g.findings));
  assert.ok(g.findings.some((f) => f.message === "context devx has no rule"), JSON.stringify(g.findings));
  assert.doesNotMatch(g.text, /\|[ \t]*\|/, "no empty cell");
  const r = one(fixture(tree(map)), "ownership-fresh");
  assert.equal(r.ok, false);
  assert.match(msgs(r), /context kernel has no owner/);
});

test("tl arch --index writes the block between the markers and leaves the prose outside byte-identical", async () => {
  const files = tree();
  files[OWNERSHIP_FILE] = `${PROSE_TOP}${MARK_BEGIN}\n| stale | table |\n${MARK_END}\n${PROSE_END}`;
  const root = fixture(files);
  assert.equal(one(root, "ownership-fresh").ok, false, "stale before");
  const log = console.log; console.log = () => {};
  try { await archCmd(["--index"], {}, root); } finally { console.log = log; }
  const after = fs.readFileSync(path.join(root, OWNERSHIP_FILE), "utf8");
  assert.equal(after, ownership(MAP));
  assert.ok(after.startsWith(PROSE_TOP + MARK_BEGIN + "\n"));
  assert.ok(after.endsWith(MARK_END + "\n" + PROSE_END));
  assert.ok(one(root, "ownership-fresh").ok, "fresh after");
});

test("real tree: every tracked file in exactly one context, and the OWNERSHIP scope map is fresh", () => {
  for (const id of ["context-map-cover", "ownership-fresh"]) { const r = one(REPO, id); assert.ok(r.ok, `${id}: ${r.findings.length} finding(s): ${msgs(r).slice(0, 600)}`); }
  const map = JSON.parse(fs.readFileSync(path.join(REPO, "context-map.json"), "utf8"));
  assert.equal(map.schema, "tl.contextmap/1");
  const text = fs.readFileSync(path.join(REPO, OWNERSHIP_FILE), "utf8");
  for (const c of map.contexts) for (const g of c.paths) assert.ok(text.includes("`" + g + "`"), `OWNERSHIP names ${g}`);
});
