// Asset spine tests: one injected failure per rule, on temp-dir fixtures. Run: node --test devx/test/assets.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import zlib from "node:zlib";
import * as ctx from "../lib/ctx.mjs";
import { checkPath, checkFile, checkTree, HARD_MAX_FILE_BYTES } from "../lib/assets/hygiene.mjs";
import { checkAssets } from "../lib/assets/check.mjs";
import { addAsset } from "../lib/assets/add.mjs";
import { parseScan, runScan } from "../lib/assets/scan.mjs";
import { serializeManifest, sha256File, validateManifest, validateEntry } from "../lib/assets/model.mjs";

const REPO = ctx.REPO;
const OWNER = "game.test_pack";

function png(w, h) { // a valid PNG header with a real IHDR; the body is irrelevant to the rules
  const b = Buffer.alloc(33);
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(b, 0);
  b.writeUInt32BE(13, 8); b.write("IHDR", 12); b.writeUInt32BE(w, 16); b.writeUInt32BE(h, 20);
  return Buffer.concat([b, zlib.deflateSync(Buffer.from("x"))]);
}

/** A repo-like root with the real budgets, one mesh, one texture, one data file, all registered and valid. */
function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "tl-assets-"));
  const dir = path.join(root, "assets", OWNER);
  fs.mkdirSync(dir, { recursive: true });
  fs.copyFileSync(path.join(REPO, "assets", "budgets.json"), path.join(root, "assets", "budgets.json"));
  fs.writeFileSync(path.join(dir, "ramp.glb"), Buffer.from("glTF-fake-mesh-bytes"));
  fs.writeFileSync(path.join(dir, "wood.png"), png(512, 256));
  fs.writeFileSync(path.join(dir, "tuning.json"), '{"a":1}');
  const prov = { tool: "blender", author: "me" };
  const ent = (id, kind, file, extra = {}) => ({ id, kind, source: "imported", origin: `assets/${OWNER}/${file}`, hash: sha256File(path.join(dir, file)),
    bytes: fs.statSync(path.join(dir, file)).size, license: "CC0-1.0", provenance: prov, owner: OWNER, ...extra });
  const m = { schema: "tl.assets/1", assets: [
    ent("pack.test.ramp", "mesh", "ramp.glb", { tris: 1200 }),
    ent("pack.test.tuning", "data", "tuning.json"),
    ent("pack.test.wood", "texture", "wood.png", { px: [512, 256] }),
  ] };
  fs.writeFileSync(path.join(root, "assets", "manifest.json"), serializeManifest(m));
  return { root, dir, m };
}
const save = (f) => fs.writeFileSync(path.join(f.root, "assets", "manifest.json"), serializeManifest(f.m));
const failing = (f, scanned = null) => { const r = checkAssets({ root: f.root, scanned }); return Object.entries(r.problems).flatMap(([s, l]) => l.map((p) => `${s}: ${p}`)); };
const expectFail = (f, step, re, scanned) => {
  const all = failing(f, scanned);
  assert.ok(all.some((p) => p.startsWith(step + ":") && re.test(p)), `expected a '${step}' problem matching ${re}, got:\n${all.join("\n") || "(none)"}`);
};

test("the valid fixture passes every static rule", () => {
  const f = fixture();
  assert.deepEqual(failing(f), []);
});

test("the committed manifest passes the static check", () => {
  const r = checkAssets({ root: REPO });
  const bad = Object.entries(r.problems).flatMap(([s, l]) => l.map((p) => `${s}: ${p}`));
  assert.deepEqual(bad, []);
  assert.ok(r.steps.length >= 4);
});

// ---- schema rules
for (const [name, mutate, re] of [
  ["id not namespaced", (m) => { m.assets[0].id = "ramp"; }, /namespaced/],
  ["unknown kind", (m) => { m.assets[0].kind = "sound"; }, /kind must be/],
  ["unknown source", (m) => { m.assets[0].source = "scraped"; }, /source must be/],
  ["missing license", (m) => { delete m.assets[0].license; }, /license missing/],
  ["missing provenance.tool", (m) => { delete m.assets[0].provenance.tool; }, /provenance.tool/],
  ["unknown key", (m) => { m.assets[0].colour = "red"; }, /unknown key/],
  ["bad hash shape", (m) => { m.assets[0].hash = "abc"; }, /64 hex/],
  ["mesh without tris", (m) => { delete m.assets[0].tris; }, /tris .* required/],
  ["texture without px", (m) => { delete m.assets[2].px; }, /px .* required/],
  ["generated without model", (m) => { m.assets[0].source = "generated"; }, /provenance.model/],
  ["kit_part owned by a pack", (m) => { m.assets.push({ id: "kit.x", kind: "kit_part", source: "procedural", origin: "tlkit:x", hash: "a".repeat(40), bytes: 0, tris: 1, license: "x", provenance: { tool: "t", author: "a" }, owner: OWNER }); }, /owned by 'engine'/],
  ["duplicate id", (m) => { m.assets.push({ ...m.assets[0] }); }, /duplicate id/],
]) {
  test(`schema rejects: ${name}`, () => {
    const f = fixture();
    mutate(f.m);
    fs.writeFileSync(path.join(f.root, "assets", "manifest.json"), JSON.stringify(f.m)); // raw, so the writer cannot repair it
    expectFail(f, "manifest", re);
  });
}
test("schema rejects an unsorted manifest", () => {
  const f = fixture();
  f.m.assets.reverse();
  fs.writeFileSync(path.join(f.root, "assets", "manifest.json"), JSON.stringify(f.m));
  expectFail(f, "manifest", /not sorted/);
});
test("schema rejects a missing manifest file and broken JSON", () => {
  const f = fixture();
  fs.writeFileSync(path.join(f.root, "assets", "manifest.json"), "{nope");
  expectFail(f, "manifest", /unreadable/);
  fs.rmSync(path.join(f.root, "assets", "manifest.json"));
  expectFail(f, "manifest", /missing/);
});
test("validateEntry accepts a good procedural entry", () => {
  assert.deepEqual(validateEntry({ id: "kit.rink", kind: "kit_part", source: "procedural", origin: "tlkit:rink", hash: "a".repeat(40), bytes: 0, tris: 10, license: "first-party", provenance: { tool: "TLKit", author: "engine" }, owner: "engine" }), []);
  assert.ok(validateManifest({ schema: "tl.assets/9", assets: [] }).length > 0);
});

// ---- file rules
test("files rule: missing file", () => { const f = fixture(); fs.rmSync(path.join(f.dir, "ramp.glb")); expectFail(f, "files", /does not exist/); });
test("files rule: hash mismatch", () => { const f = fixture(); fs.appendFileSync(path.join(f.dir, "ramp.glb"), "x"); expectFail(f, "files", /hash mismatch/); });
test("files rule: bytes mismatch", () => { const f = fixture(); f.m.assets[0].bytes += 5; save(f); expectFail(f, "files", /bytes, file has/); });
test("files rule: png header disagrees with px", () => { const f = fixture(); f.m.assets[2].px = [256, 256]; save(f); expectFail(f, "files", /png header says 512x256/); });

// ---- budget rules
test("budget rule: triangles per asset", () => { const f = fixture(); f.m.assets[0].tris = 20001; save(f); expectFail(f, "budgets", /20001 triangles exceeds/); });
test("budget rule: texture px", () => {
  const f = fixture();
  fs.writeFileSync(path.join(f.dir, "wood.png"), png(4096, 16));
  Object.assign(f.m.assets[2], { px: [4096, 16], hash: sha256File(path.join(f.dir, "wood.png")), bytes: fs.statSync(path.join(f.dir, "wood.png")).size });
  save(f);
  expectFail(f, "budgets", /4096x16 exceeds .* 2048px/);
});
test("budget rule: bytes per asset", () => { const f = fixture(); f.m.assets[1].bytes = 2 * 1024 * 1024; save(f); expectFail(f, "budgets", /exceeds the pack\/data limit/); });
test("budget rule: bytes per owner", () => {
  const f = fixture();
  const b = JSON.parse(fs.readFileSync(path.join(f.root, "assets", "budgets.json"), "utf8"));
  b.tiers.pack.owner.maxBytes = 10;
  fs.writeFileSync(path.join(f.root, "assets", "budgets.json"), JSON.stringify(b));
  expectFail(f, "budgets", /owner game\.test_pack: .* per-owner limit of 10/);
});
test("budget rule: a player_pack tier is stricter than pack", () => {
  const f = fixture(); f.m.assets[0].tier = "player_pack"; f.m.assets[0].tris = 12001; save(f);
  expectFail(f, "budgets", /12001 triangles exceeds the player_pack\/mesh limit of 12000/);
});
test("budget rule: a budgets file missing a kind is unusable", () => {
  const f = fixture();
  const b = JSON.parse(fs.readFileSync(path.join(f.root, "assets", "budgets.json"), "utf8"));
  delete b.tiers.pack.kinds.audio;
  fs.writeFileSync(path.join(f.root, "assets", "budgets.json"), JSON.stringify(b));
  expectFail(f, "manifest", /tiers\.pack\.kinds\.audio missing/);
});

// ---- hygiene rules
test("hygiene.checkPath", () => {
  const own = `assets/${OWNER}/`;
  assert.deepEqual(checkPath(`assets/${OWNER}/a/b.png`, { ownerDir: own }), []);
  assert.match(checkPath("../x.png")[0], /\.\./);
  assert.match(checkPath(`assets/${OWNER}/../evil.png`, { ownerDir: own }).join(), /\.\./);
  assert.match(checkPath("/etc/passwd")[0], /absolute/);
  assert.match(checkPath("C:/Windows/x.png")[0], /absolute/);
  assert.match(checkPath("a\\b.png")[0], /backslash/);
  assert.match(checkPath("assets/other.pack/x.png", { ownerDir: own })[0], /outside the owner/);
  assert.match(checkPath("res://x.png")[0], /URL/);
  assert.match(checkPath("")[0], /empty/);
});
test("hygiene rule in check: origin outside the owner dir", () => {
  const f = fixture(); fs.mkdirSync(path.join(f.root, "assets", "someone.else")); fs.writeFileSync(path.join(f.root, "assets", "someone.else", "a.glb"), "glTF");
  f.m.assets[0].origin = "assets/someone.else/a.glb"; save(f); expectFail(f, "hygiene", /outside the owner/);
});
test("hygiene rule in check: '..' in an origin", () => { const f = fixture(); f.m.assets[0].origin = `assets/${OWNER}/../x.glb`; save(f); expectFail(f, "hygiene", /'\.\.'/); });
test("hygiene rule in check: absolute origin", () => { const f = fixture(); f.m.assets[0].origin = "/tmp/x.glb"; save(f); expectFail(f, "hygiene", /absolute/); });
test("hygiene rule: extension not allowed for the kind", () => {
  const f = fixture(); f.m.assets[0].kind = "mesh"; fs.copyFileSync(path.join(f.dir, "wood.png"), path.join(f.dir, "fake.png"));
  Object.assign(f.m.assets[0], { origin: `assets/${OWNER}/fake.png`, hash: sha256File(path.join(f.dir, "fake.png")), bytes: fs.statSync(path.join(f.dir, "fake.png")).size }); save(f);
  expectFail(f, "hygiene", /'\.png' is not allowed for kind 'mesh'/);
});
for (const ext of [".gd", ".dll", ".exe", ".sh", ".bat", ".so", ".cmd", ".ps1"]) {
  test(`hygiene rule: ${ext} in an asset dir is rejected even when unregistered`, () => {
    const f = fixture(); fs.writeFileSync(path.join(f.dir, "payload" + ext), "echo hi");
    expectFail(f, "hygiene", new RegExp(`payload\\${ext}.*executable or script`));
  });
}
test("hygiene rule: a script registered as data is rejected", () => {
  const f = fixture(); fs.writeFileSync(path.join(f.dir, "run.gd"), "extends Node");
  Object.assign(f.m.assets[1], { origin: `assets/${OWNER}/run.gd`, hash: sha256File(path.join(f.dir, "run.gd")), bytes: 12 }); save(f);
  expectFail(f, "hygiene", /run\.gd.*never allowed/);
});
test("hygiene rule: executable bytes behind an innocent extension", () => {
  const f = fixture(); fs.writeFileSync(path.join(f.dir, "sneaky.png"), Buffer.concat([Buffer.from("MZ"), Buffer.alloc(60)]));
  expectFail(f, "hygiene", /sneaky\.png.*Windows executable/);
  fs.writeFileSync(path.join(f.dir, "sneaky.png"), "#!/bin/sh\nrm -rf /\n");
  expectFail(f, "hygiene", /sneaky\.png.*shebang/);
});
test("hygiene rule: unregistered file in an owner dir", () => { const f = fixture(); fs.writeFileSync(path.join(f.dir, "stray.json"), "{}"); expectFail(f, "hygiene", /stray\.json: file is not registered/); });
test("hygiene rule: single-file size limit (checkFile and hard ceiling)", () => {
  const f = fixture();
  assert.match(checkFile(path.join(f.dir, "ramp.glb"), { kind: "mesh", maxBytes: 5 })[0], /exceeds the single-file limit of 5/);
  assert.equal(HARD_MAX_FILE_BYTES, 64 * 1024 * 1024);
  assert.deepEqual(checkFile(path.join(f.dir, "ramp.glb"), { kind: "mesh" }), []);
});
test("hygiene rule: a symbolic link is rejected (skipped where links need privileges)", (t) => {
  const f = fixture();
  try { fs.symlinkSync(path.join(f.dir, "ramp.glb"), path.join(f.dir, "link.glb")); } catch { t.skip("cannot create symlinks here"); return; }
  assert.match(checkFile(path.join(f.dir, "link.glb"), { kind: "mesh" })[0], /symbolic link/);
  assert.ok(checkTree(f.dir).problems.some((p) => /link\.glb.*symbolic link/.test(p)));
});
test("hygiene.checkTree lists files and flags only the bad ones", () => {
  const f = fixture(); fs.writeFileSync(path.join(f.dir, "x.dll"), "x");
  const t = checkTree(f.dir);
  assert.deepEqual(t.files, ["ramp.glb", "tuning.json", "wood.png", "x.dll"]);
  assert.equal(t.problems.length, 1);
});

// ---- procedural (full mode)
test("procedural rule: hash drift, a new kit part, a removed kit part", () => {
  const f = fixture();
  const kp = (id, hash, tris) => ({ id, kind: "kit_part", source: "procedural", origin: `tlkit:${id.slice(4)}`, hash, bytes: 0, tris, license: "first-party", provenance: { tool: "TLKit", author: "engine" }, owner: "engine" });
  f.m.assets.push(kp("kit.a", "a".repeat(40), 10), kp("kit.gone", "c".repeat(40), 5)); save(f);
  const scanned = [{ id: "kit.a", hash: "b".repeat(40), tris: 11 }, { id: "kit.new", hash: "d".repeat(40), tris: 1 }];
  expectFail(f, "procedural", /kit\.a: hash drifted/, scanned);
  expectFail(f, "procedural", /kit\.a: triangles drifted/, scanned);
  expectFail(f, "procedural", /kit\.new: in the kit but not in the manifest/, scanned);
  expectFail(f, "procedural", /kit\.gone: in the manifest but no longer in the kit/, scanned);
});

// ---- add
test("add registers a file, writes deterministically, warns on same-hash, refuses duplicate ids and scripts", () => {
  const f = fixture();
  fs.copyFileSync(path.join(f.dir, "ramp.glb"), path.join(f.dir, "ramp_copy.glb"));
  const base = { id: "pack.test.copy", kind: "mesh", owner: OWNER, license: "CC0-1.0", tool: "blender", tris: 10 };
  const ok = addAsset({ root: f.root, file: `assets/${OWNER}/ramp_copy.glb`, opts: base });
  assert.equal(ok.ok, true, ok.errors.join());
  assert.match(ok.warnings.join(), /same bytes as 'pack\.test\.ramp'/);
  const written = fs.readFileSync(path.join(f.root, "assets", "manifest.json"), "utf8");
  assert.deepEqual(failing(f), []);
  assert.equal(written, serializeManifest(JSON.parse(written)), "manifest bytes are canonical");
  const dup = addAsset({ root: f.root, file: `assets/${OWNER}/ramp_copy.glb`, opts: base });
  assert.equal(dup.ok, false); assert.match(dup.errors.join(), /already registered/);
  fs.writeFileSync(path.join(f.dir, "evil.gd"), "extends Node");
  const evil = addAsset({ root: f.root, file: `assets/${OWNER}/evil.gd`, opts: { ...base, id: "pack.test.evil", kind: "data" } });
  assert.equal(evil.ok, false); assert.match(evil.errors.join(), /evil\.gd/);
  assert.equal(fs.readFileSync(path.join(f.root, "assets", "manifest.json"), "utf8"), written, "a refused add leaves the manifest untouched");
  const outside = addAsset({ root: f.root, file: "assets/budgets.json", opts: { ...base, id: "pack.test.out", kind: "data" } });
  assert.equal(outside.ok, false); assert.match(outside.errors.join(), /outside the owner/);
});
test("add fills px from a png header and marks a model-made asset generated", () => {
  const f = fixture(); fs.writeFileSync(path.join(f.dir, "gen.png"), png(64, 64));
  const r = addAsset({ root: f.root, file: `assets/${OWNER}/gen.png`, opts: { id: "pack.test.gen", kind: "texture", owner: OWNER, license: "CC0-1.0", tool: "imgmodel", model: "m-1", promptHash: "abc123" } });
  assert.equal(r.ok, true, r.errors.join());
  assert.deepEqual(r.entry.px, [64, 64]);
  assert.equal(r.entry.source, "generated");
  assert.equal(r.entry.provenance.prompt_hash, "abc123");
});

// ---- scan
test("parseScan sorts rows and demands TLASSET_DONE", () => {
  const out = 'TLASSET {"id":"kit.b","part":"b","hash":"x","tris":1}\nTLASSET {"id":"kit.a","part":"a","hash":"y","tris":2}\nTLASSET_DONE 2 parts, 0 errors\n';
  const r = parseScan(out);
  assert.deepEqual(r.rows.map((x) => x.id), ["kit.a", "kit.b"]); assert.deepEqual(r.errors, []);
  assert.match(parseScan("TLASSET {}\n").errors.join(), /TLASSET_DONE/);
  assert.match(parseScan("TLASSET_ERROR build failed: rink\nTLASSET_DONE 1 parts, 1 errors").errors[0], /build failed/);
});
test("scan twice gives identical rows, and they match the committed manifest", (t) => {
  if (!ctx.resolveGodot()) { t.skip("no Godot"); return; }
  const a = runScan(ctx), b = runScan(ctx);
  assert.ok(a.ok && b.ok, [...a.errors, ...b.errors].join());
  assert.deepEqual(a.rows, b.rows);
  const committed = JSON.parse(fs.readFileSync(path.join(REPO, "assets", "manifest.json"), "utf8")).assets.filter((e) => e.kind === "kit_part");
  assert.deepEqual(committed.map((e) => [e.id, e.hash, e.tris]), a.rows.map((r) => [r.id, r.hash, r.tris]));
});
