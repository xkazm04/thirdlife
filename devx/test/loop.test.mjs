import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createDetector, diffScans, scanFiles } from "../lib/loop/detect.mjs";
import { parseReport, findings, formatFinding } from "../lib/loop/findings.mjs";
import { runCycle, orderVerbs } from "../lib/loop/cycle.mjs";
import { scaffoldPack, scaffoldBot, kitpartRecipe } from "../lib/commands/new.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const fixture = (n) => fs.readFileSync(path.join(here, "fixtures", n), "utf8");

test("diffScans: added, removed, touched", () => {
  const a = new Map([["x", 1], ["y", 1]]);
  const b = new Map([["x", 2], ["z", 1]]);
  assert.deepEqual(diffScans(a, b).sort(), ["x", "y", "z"]);
  assert.deepEqual(diffScans(a, a), []);
});

test("detector: debounce with a fake clock", () => {
  let t = 0, snap = new Map([["a", 1]]);
  const d = createDetector({ scan: () => snap, now: () => t, debounceMs: 500 });
  assert.equal(d.poll(), null);                         // nothing changed
  t = 300; snap = new Map([["a", 2]]);
  assert.equal(d.poll(), null);                         // changed, window open
  t = 600; assert.equal(d.poll(), null);                // 300 ms quiet: not yet
  t = 700; snap = new Map([["a", 3]]);
  assert.equal(d.poll(), null);                         // another save restarts the window
  t = 1100; assert.equal(d.poll(), null);               // 400 ms
  t = 1200; assert.deepEqual(d.poll(), ["a"]);          // 500 ms quiet: fires once
  t = 2000; assert.equal(d.poll(), null);               // and not again
});

test("detector: several files collapse into one trigger", () => {
  let t = 0, snap = new Map();
  const d = createDetector({ scan: () => snap, now: () => t, debounceMs: 500 });
  snap = new Map([["b", 1]]); t = 100; d.poll();
  snap = new Map([["b", 1], ["a", 1]]); t = 200; d.poll();
  t = 700; assert.deepEqual(d.poll(), ["a", "b"]);
});

test("scanFiles sees a real edit by mtime", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tlscan-"));
  const f = path.join(dir, "a.gd");
  fs.writeFileSync(f, "x"); fs.writeFileSync(path.join(dir, "skip.txt"), "x");
  const s1 = scanFiles([dir], [".gd", ".json"]);
  assert.deepEqual([...s1.keys()], [f]);
  fs.utimesSync(f, new Date(2000, 0, 1), new Date(2000, 0, 1));
  assert.deepEqual(diffScans(s1, scanFiles([dir], [".gd"])), [f]);
  fs.rmSync(dir, { recursive: true });
});

test("findings parser on a real failing lint report (fixture)", () => {
  const raw = "some noise\n" + fixture("lint_fail.json");
  const rep = parseReport(raw);
  assert.equal(rep.schema, "tl.verify/1");
  assert.equal(rep.ok, false);
  const f = findings(rep);
  assert.equal(f.length, 3);
  assert.deepEqual(f[0], { kind: "fence", where: "scripts/main.gd:3", message: "'OS.' is outside the fence" });
  assert.match(formatFinding(f[2]), /capability\s+scripts\/main\.gd:53\s+uses 'TLBodies'/);
  assert.equal(findings(rep, 2).length, 2);
});

test("findings: failed checks when errors[] is empty; bot summary; no report", () => {
  const checks = { schema: "tl.verify/1", ok: false, errors: [], checks: [{ id: "smoke.loads", ok: true, detail: "" }, { id: "invariants.determinism", ok: false, detail: "hash differs" }] };
  assert.deepEqual(findings(checks), [{ kind: "invariants.determinism", where: "", message: "hash differs" }]);
  const bot = { schema: "tl.verify/1", ok: false, errors: [], checks: [], bot: { test: "tests/b.gd", result: { ok: false, summary: "lost 1 : 5" } } };
  assert.equal(findings(bot)[0].message, "lost 1 : 5");
  assert.equal(parseReport("not json\n{broken"), null);
  assert.deepEqual(findings(null), []);
});

test("cycle: stops at the first failure and keeps verb order", async () => {
  const calls = [];
  const fake = async (verb) => { calls.push(verb); return verb === "smoke" ? { code: 1, stdout: fixture("lint_fail.json"), stderr: "", ms: 5 } : { code: 0, stdout: "", stderr: "", ms: 5 }; };
  const res = await runCycle(orderVerbs(["bot", "lint", "smoke"]), fake);
  assert.deepEqual(calls, ["lint", "smoke"]);
  assert.equal(res.ok, false);
  assert.equal(res.results[1].findings.length, 3);
  assert.throws(() => orderVerbs(["lint", "invariants"]), /unknown verb/);
});

test("cycle: exit 2 without a report is a labelled FAIL; cancellation aborts", async () => {
  const res = await runCycle(["lint"], async () => ({ code: 2, stdout: "", stderr: "pack not found", ms: 1 }));
  assert.equal(res.ok, false);
  assert.equal(res.results[0].findings[0].kind, "not_run");
  assert.match(res.results[0].findings[0].message, /pack not found/);
  const aborted = await runCycle(["lint", "smoke"], async () => ({ code: 0, stdout: "", stderr: "", ms: 1 }), () => true);
  assert.equal(aborted.aborted, true);
});

test("scaffold: pack files, substitution, id valid, bot registered", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tlnew-"));
  const files = scaffoldPack("my_game", path.join(dir, "p"));
  assert.ok(files.includes("tests/bot_my_game.gd") && files.includes("pack.json"));
  const m = JSON.parse(fs.readFileSync(path.join(dir, "p", "pack.json"), "utf8"));
  assert.equal(m.id, "game.my_game");
  assert.equal(m.title, "My Game");
  assert.deepEqual(m.tests, ["tests/bot_my_game.gd"]);
  assert.ok(!fs.readFileSync(path.join(dir, "p", "README.md"), "utf8").includes("{{"));
  assert.equal(scaffoldBot("second", path.join(dir, "p")), "tests/bot_second.gd");
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(dir, "p", "pack.json"), "utf8")).tests, ["tests/bot_my_game.gd", "tests/bot_second.gd"]);
  assert.throws(() => scaffoldBot("second", path.join(dir, "p")), /already exists/);
  fs.rmSync(dir, { recursive: true });
});

test("kitpart recipe is read from KIT.md and edits nothing", () => {
  const r = kitpartRecipe("widget");
  assert.match(r, /\[ \] Add a row to `TLKit\.PARTS`/);
  assert.match(r, /widget/);
});
