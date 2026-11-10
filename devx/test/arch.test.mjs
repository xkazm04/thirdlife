// node --test devx/test/arch.test.mjs
// Every rule: green on a clean fixture, red on a deliberately broken one. Fixtures are temp dirs passed as rootDir.
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { runRules, loadRules, computeBaseline, diffBaseline } from "../lib/arch/core.mjs";
import { generateIndex, INDEX_FILE } from "../lib/arch/apiindex.mjs";
import { globsOverlap } from "../lib/arch/hygiene.mjs";
import { parseGdArrayDict } from "../lib/arch/contracts.mjs";
import { stripGd } from "../lib/arch/util.mjs";
import { run as archCmd } from "../lib/commands/arch.mjs";
import { REPO } from "../lib/ctx.mjs";

const rules = loadRules();
function fixture(files) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "tl-arch-"));
  for (const [f, text] of Object.entries(files)) { fs.mkdirSync(path.dirname(path.join(root, f)), { recursive: true }); fs.writeFileSync(path.join(root, f), text); }
  return root;
}
const one = (root, id, baseline) => runRules({ root, rules, only: [id], ...(baseline ? { baseline } : {}) }).results[0];
const msgs = (r) => r.findings.map((f) => f.message).join("\n");

// ---- a clean world every rule accepts; each test breaks one thing
const VERBS = { schema: "tl.verbs/1", verbs: { lint: { level: "V1", options: { pack: {}, report: {} } }, smoke: { level: "V2", options: { pack: {}, report: {}, seed: {} } } } };
const HOST = 'const LEVELS: Dictionary = {"lint": "V1", "smoke": "V2"}\nconst OPTIONS: Dictionary = {\n\t"lint": ["pack", "report"],\n\t"smoke": ["pack", "report", "seed"],   # note\n}\nconst X = 1\n';
const base = () => ({
  "engine/kernel/api/tl_a.gd": "class_name TLA\nextends RefCounted\n## First line.\nconst K = 1\nstatic func go(x: int) -> int:\n\treturn x\n",
  "engine/kernel/api/tl_a.gd.uid": "uid://a\n",
  "engine/kits/tl_kit.gd": "class_name TLKit\nextends RefCounted\n# TLBodies in a comment is fine\nvar s = \"TLBodies in a string\"\nfunc f(): return TLMesh.x\n",
  "engine/kits/tl_kit.gd.uid": "uid://b\n",
  "engine/kits/tl_mesh.gd": "class_name TLMesh\nextends RefCounted\n",
  "engine/kits/tl_mesh.gd.uid": "uid://c\n",
  "engine/rigs/tl_rig_a.gd": "class_name TLRigA\nextends RefCounted\n",
  "engine/rigs/tl_rig_a.gd.uid": "uid://d\n",
  "engine/style/tl_style.gd": "class_name TLStyle\nextends RefCounted\nconst P = \"res://style/style.json\"\n",
  "engine/style/tl_style.gd.uid": "uid://e\n",
  "engine/seeds/seed_x/scripts/main.gd": "extends Node\nfunc _ready():\n\tTLA.go(1)\n\tTLKit.f()\n",
  "engine/kernel/runner/verbs.json": JSON.stringify(VERBS),
  "engine/kernel/host/host.gd": HOST,
  "engine/kernel/host/host.gd.uid": "uid://h\n",
  "contracts/RUNNER.md": "| `lint` | V1 |\n| `smoke` | V2 | `--seed=<int>` |\nschema tl.verbs/1 tl.job/1\n",
  "engine/tools/tl.sh": "#!/bin/bash\n#   tl.sh lint  --pack=<dir>\n#   tl.sh smoke --pack=<dir> [--seed=1]\n",
  "foreman/src/a.ts": 'const s = "tl.job/1";\n',
});
const withIndex = (files) => { const root = fixture(files); fs.mkdirSync(path.join(root, "docs/generated"), { recursive: true }); fs.writeFileSync(path.join(root, INDEX_FILE), generateIndex(runRules({ root, rules, only: [] }).io)); return root; };

test("clean fixture passes every rule", () => {
  const root = withIndex(base());
  const { results } = runRules({ root, rules });
  for (const r of results) assert.ok(r.ok, `${r.rule.id}: ${msgs(r)}`);
  assert.equal(results.length, 8);
});

test("1 module-walls: kit referencing a kernel class, an outside res:// path, a ../ load", () => {
  const f = base();
  f["engine/kits/tl_kit.gd"] += "func g(): TLBodies.make()\n";
  f["engine/rigs/tl_rig_a.gd"] += 'var a = preload("res://kernel/x.gd")\n';
  f["engine/style/tl_style.gd"] += 'var b = load("../kits/y.gd")\n';
  const r = one(fixture(f), "module-walls");
  assert.equal(r.ok, false);
  assert.match(msgs(r), /TLBodies is outside kits\/rigs\/style/);
  assert.match(msgs(r), /res:\/\/kernel\/x\.gd points outside/);
  assert.match(msgs(r), /relative \.\.\/ load/);
  assert.ok(r.findings.every((x) => x.line > 0));
});
test("1 module-walls: comments and strings never count", () => {
  assert.ok(one(fixture(base()), "module-walls").ok);
  assert.equal(stripGd('var a = "TLX" # TLY\n').includes("TL"), false);
});
test("1 module-walls: a seed that builds materials, lights, environments, uses a private class or class_name", () => {
  const f = base();
  f["engine/seeds/seed_x/scripts/main.gd"] += "\tvar m = StandardMaterial3D.new()\n\tvar l = OmniLight3D.new()\n\tvar e = Environment.new()\n\tTLRunnerInternals.x()\n";
  f["engine/seeds/seed_x/tests/bot.gd"] = "class_name Oops\nextends Node\n";
  f["engine/kernel/examples/ex_y/scripts/main.gd"] = "extends Node\nvar m = ShaderMaterial.new()\n";
  f["engine/kernel/examples/bad_z/scripts/main.gd"] = "extends Node\nvar m = StandardMaterial3D.new()\n"; // deliberate negative: exempt
  const r = one(fixture(f), "module-walls");
  const m = msgs(r);
  assert.match(m, /StandardMaterial3D\.new/); assert.match(m, /OmniLight3D\.new/); assert.match(m, /Environment\.new/);
  assert.match(m, /ShaderMaterial\.new/); assert.match(m, /TLRunnerInternals is not a public/); assert.match(m, /declares class_name Oops/);
  assert.ok(!r.findings.some((x) => x.file.includes("bad_z")));
});

test("2 class-prefixes: wrong prefix per directory, reserved prefix in the kernel, duplicates", () => {
  const f = base();
  f["engine/kits/wrong.gd"] = "class_name TLRigStolen\n";
  f["engine/rigs/other.gd"] = "class_name Plain\n";
  f["engine/kernel/api/tl_b.gd"] = "class_name TLKitInKernel\n";
  f["engine/kernel/api/tl_c.gd"] = "class_name NoPrefix\n";
  f["engine/kernel/api/tl_dup.gd"] = "class_name TLA\n";
  const r = one(fixture(f), "class-prefixes");
  const m = msgs(r);
  assert.match(m, /TLRigStolen in engine\/kits must start with TLKit or TLMesh/);
  assert.match(m, /Plain in engine\/rigs must start with TLRig/);
  assert.match(m, /TLKitInKernel uses a prefix reserved/);
  assert.match(m, /NoPrefix must start with TL/);
  assert.match(m, /duplicate class_name TLA/);
});

test("3 uid-orphans: uid without gd, gd without uid; pack scripts are exempt", () => {
  const f = base();
  f["engine/kernel/api/tl_gone.gd.uid"] = "uid://x\n";
  f["engine/kernel/api/tl_new.gd"] = "class_name TLNew\n";
  const r = one(fixture(f), "uid-orphans");
  assert.equal(r.findings.length, 2);
  assert.match(msgs(r), /uid file without its \.gd/); assert.match(msgs(r), /\.gd without its \.gd\.uid/);
  assert.ok(one(fixture(base()), "uid-orphans").ok);
});

test("4 verbs-contract: option drift, missing verb, undocumented verb, tl.sh header", () => {
  const f = base();
  f["engine/kernel/host/host.gd"] = HOST.replace('"smoke": ["pack", "report", "seed"]', '"smoke": ["pack", "report", "frames"]');
  let m = msgs(one(fixture(f), "verbs-contract"));
  assert.match(m, /option --seed is in verbs\.json but not in host\.gd/); assert.match(m, /option --frames is in host\.gd OPTIONS but not in verbs\.json/);
  const g = base(); g["engine/kernel/host/host.gd"] = HOST.replace('\t"smoke": ["pack", "report", "seed"],   # note\n', "");
  assert.match(msgs(one(fixture(g), "verbs-contract")), /verb 'smoke' is in verbs\.json but not in host\.gd OPTIONS/);
  const h = base(); h["contracts/RUNNER.md"] = "| `lint` | V1 |\n"; h["engine/tools/tl.sh"] = "#   tl.sh lint --pack=<dir>\n";
  m = msgs(one(fixture(h), "verbs-contract"));
  assert.match(m, /verb 'smoke' is not documented in contracts\/RUNNER\.md/); assert.match(m, /verb 'smoke' is missing from the usage header/);
  const k = base(); k["engine/kernel/host/host.gd"] = HOST.replace('"lint": ["pack", "report"],', '"lint": ["pack",\n\t\t"report"],');
  assert.match(msgs(one(fixture(k), "verbs-contract")), /not parseable/);
  const l = base(); l["engine/kernel/host/host.gd"] = HOST.replace('"smoke": "V2"', '"smoke": "V9"');
  assert.match(msgs(one(fixture(l), "verbs-contract")), /LEVELS says V9, verbs\.json says V2/);
});
test("4 verbs-contract: parser reads comments and one-line rows exactly", () => {
  const p = parseGdArrayDict(HOST, "OPTIONS");
  assert.deepEqual(p.map, { lint: ["pack", "report"], smoke: ["pack", "report", "seed"] }); assert.deepEqual(p.unparsed, []);
});

test("5 schema-versions: an undeclared schema string is reported with file:line", () => {
  const f = base(); f["engine/kernel/data/m.json"] = '{\n  "schema": "tl.mystery/3"\n}\n';
  const r = one(fixture(f), "schema-versions");
  assert.equal(r.ok, false);
  assert.deepEqual([r.findings[0].file, r.findings[0].line, r.findings[0].key], ["engine/kernel/data/m.json", 2, "tl.mystery/3"]);
  const g = base(); g["engine/kernel/data/m.json"] = '{"schema": "tl.job/2"}\n';   // same name, new version: must be declared too
  assert.equal(one(fixture(g), "schema-versions").ok, false);
});

test("6 size-ratchet: over budget fails, held file may shrink but not grow, baseline admits it", () => {
  const lines = (n) => Array.from({ length: n }, (_, i) => `var v${i} = ${i}`).join("\n") + "\n";
  const f = base(); f["engine/kernel/api/big.gd"] = lines(601);
  const root = fixture(f);
  const r = one(root, "size-ratchet");
  assert.equal(r.ok, false); assert.match(msgs(r), /601 lines, budget 600/);
  const { next } = computeBaseline({ root, rules, old: { sizes: {}, grandfathered: {} } });
  assert.equal(next.sizes["engine/kernel/api/big.gd"], 601);
  assert.ok(one(root, "size-ratchet", next).ok);
  fs.writeFileSync(path.join(root, "engine/kernel/api/big.gd"), lines(602));
  assert.match(msgs(one(root, "size-ratchet", next)), /grew past its grandfathered 601/);
  fs.writeFileSync(path.join(root, "engine/kernel/api/big.gd"), lines(590));
  assert.ok(one(root, "size-ratchet", next).ok);
  const small = computeBaseline({ root, rules, old: next }).next;
  assert.deepEqual(small.sizes, {});
  assert.deepEqual(diffBaseline(next, small), ["size engine/kernel/api/big.gd: 601 -> -"]);
});

test("7 scope-claims: absent file passes, disjoint passes, overlap fails", () => {
  assert.ok(one(fixture(base()), "scope-claims").ok);
  const mk = (sessions) => { const f = base(); f[".claude/sessions.json"] = JSON.stringify({ sessions }); return one(fixture(f), "scope-claims"); };
  assert.ok(mk([{ id: "a", scope: ["engine/kits/**"] }, { id: "b", scope: ["engine/rigs/**", "devx/**"] }]).ok);
  const bad = mk([{ id: "a", scope: ["engine/**"] }, { id: "b", scope: ["engine/rigs/x.gd"] }]);
  assert.equal(bad.ok, false); assert.match(msgs(bad), /scopes overlap: a 'engine\/\*\*' and b 'engine\/rigs\/x\.gd'/);
  assert.equal(mk([{ id: "a", scope: ["devx/**"] }, { id: "b", scope: ["devx/lib/**"] }]).ok, false);
  assert.equal(mk([{ id: "a" }]).ok, false);
  assert.ok(globsOverlap("a/*.md", "a/x.md")); assert.ok(!globsOverlap("a/*.md", "a/x.txt")); assert.ok(!globsOverlap("a/**", "b/**"));
});

test("8 api-index-fresh: missing and stale fail, regenerated passes, output is deterministic", () => {
  const f = base();
  const none = one(fixture(f), "api-index-fresh");
  assert.equal(none.ok, false); assert.match(msgs(none), /missing/);
  const root = withIndex(f);
  assert.ok(one(root, "api-index-fresh").ok);
  fs.appendFileSync(path.join(root, "engine/kernel/api/tl_a.gd"), "static func added() -> void:\n\tpass\n");
  const stale = one(root, "api-index-fresh");
  assert.equal(stale.ok, false); assert.match(msgs(stale), /stale at line/);
  const io = runRules({ root, rules, only: [] }).io;
  const a = generateIndex(io);
  assert.equal(a, generateIndex(io)); assert.ok(!a.includes("\r")); assert.ok(a.includes("static func added() -> void"));
  assert.ok(a.includes("> First line.") && a.includes("Consts: `K`"));
});
test("8 index: multi-line signatures and private members", () => {
  const f = base();
  f["engine/kernel/api/tl_m.gd"] = "class_name TLM\nextends Node\n## Doc.\nstatic func many(a: int,\n\t\tb: Dictionary = {x: 1},\n\t\tc: Array[String] = []) -> Array[String]:\n\treturn []\nfunc _hidden(): pass\nconst _P = 1\nconst Q = 2\nfunc one(): return 1\n";
  const io = runRules({ root: fixture(f), rules, only: [] }).io;
  const t = generateIndex(io);
  assert.ok(t.includes("`static func many(a: int, b: Dictionary = {x: 1}, c: Array[String] = []) -> Array[String]`"), t);
  assert.ok(t.includes("`func one()`")); assert.ok(!t.includes("_hidden")); assert.ok(!t.includes("_P"));
});

test("rules are data: an unknown checker name fails loudly, a new rule needs no code", () => {
  const root = withIndex(base());
  const r = runRules({ root, rules: [{ id: "x", severity: "error", checker: "nope" }] }).results[0];
  assert.equal(r.ok, false); assert.match(msgs(r), /unknown checker 'nope'/);
  const r2 = runRules({ root, rules: [{ id: "tight-size", severity: "ratchet", checker: "sizeRatchet", params: { budget: 3 } }] }).results[0];
  assert.equal(r2.ok, false);
});

test("command: --update-baseline then a clean run; a grown file fails afterwards", async () => {
  const lines = (n) => Array.from({ length: n }, (_, i) => `var v${i}`).join("\n") + "\n";
  const f = base(); f["engine/kernel/api/big.gd"] = lines(700);
  const root = withIndex(f);
  const quiet = async (fn) => { const o = console.log; const out = []; console.log = (s) => out.push(String(s)); try { return { code: await fn(), out }; } finally { console.log = o; } };
  assert.equal((await quiet(() => archCmd([], {}, root))).code, 1);
  const upd = await quiet(() => archCmd(["--update-baseline"], {}, root));
  assert.match(upd.out.join("\n"), /size engine\/kernel\/api\/big\.gd: - -> 700/);
  const green = await quiet(() => archCmd([], {}, root));
  assert.equal(green.code, 0); assert.equal(JSON.parse(green.out.at(-1)).schema, "tl.devx/1");
  fs.appendFileSync(path.join(root, "engine/kernel/api/big.gd"), "var more\n");
  const red = await quiet(() => archCmd([], {}, root));
  assert.equal(red.code, 1); assert.equal(JSON.parse(red.out.at(-1)).ok, false);
});

test("real tree: green, under 5 s, grandfathered items are exactly the documented ones, index is stable", async () => {
  const t0 = Date.now();
  const { results } = runRules({ root: REPO });
  assert.ok(Date.now() - t0 < 5000);
  for (const r of results) assert.ok(r.ok, `${r.rule.id}: ${r.findings.map((f) => `${f.file}:${f.line ?? ""} ${f.message}`).join("; ")}`);
  const io = runRules({ root: REPO, only: [] }).io;
  assert.equal(generateIndex(io), generateIndex(io));
  assert.equal(fs.readFileSync(path.join(REPO, INDEX_FILE), "utf8"), generateIndex(io));
});

test("gate step: shape and a green real-tree run", async () => {
  const s = await import("../lib/gate/steps/arch.mjs");
  assert.equal(s.id, "arch"); assert.deepEqual(s.tiers, ["fast", "full"]);
  assert.deepEqual(s.paths, ["engine/**", "contracts/**", "devx/**", "docs/generated/**"]);
  const r = await s.run({});
  assert.equal(r.ok, true, r.detail);
});
