// The cartridge validator (src/cartridge.ts) against the rink core's own C++: the same verdict on every case of the corpus
// (src/cartridge_corpus.ts: every cartridge thirdjam ships, broken and harmless copies of hockey.regular and Pond, rules sidecars).
// The C++ verdicts were recorded from the built core by engine/cores/rink/tools/rink_validate.gd into
// fixtures/cartridge-cpp-verdicts.json; when the corpus changes, re-record them (the test says how).
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { REPO_ROOT } from "../paths.js";
import { buildCorpus } from "../cartridge_corpus.js";
import { validateCartridgeText, validateCartridge, validateRulesText, applyChanges, knownRules, parsePath, shippedCartridges, RINK_CONTENT_DIR } from "../cartridge.js";

const FIXTURE = path.join(REPO_ROOT, "foreman", "src", "test", "fixtures", "cartridge-cpp-verdicts.json");
const RERECORD = "re-record: cd foreman && npm run build && node dist/cartridge_corpus.js --write ../.tl/cartcorpus && godot --headless --path engine "
  + "--script res://cores/rink/tools/rink_validate.gd -- --dir=<abs .tl/cartcorpus> --out=<abs foreman/src/test/fixtures/cartridge-cpp-verdicts.json>";

interface CppCase { name: string; kind: string; sha1: string; ok: boolean; error: string }

test("cartridge: the same verdict as the core's C++ on every case of the corpus, both ways", async () => {
  const cpp = (JSON.parse(fs.readFileSync(FIXTURE, "utf8")) as { cases: CppCase[] }).cases;
  const corpus = buildCorpus();
  assert.equal(corpus.length, cpp.length, `the corpus has ${corpus.length} cases, the recorded verdicts ${cpp.length}; ${RERECORD}`);
  let accepted = 0, refused = 0;
  const differ: string[] = [];
  for (const [i, c] of corpus.entries()) {
    const k = cpp[i]!;
    assert.equal(k.sha1, c.sha1, `case ${i} "${c.name}" is not the text the C++ verdict was recorded on; ${RERECORD}`);
    const v = c.kind === "cartridge" ? await validateCartridgeText(c.text) : validateRulesText(c.text);
    if (v.ok !== k.ok) differ.push(`${c.name}: C++ ${k.ok ? "accepts" : "refuses (" + k.error.slice(0, 120) + ")"}, TS ${v.ok ? "accepts" : "refuses (" + (v.errors[0] ?? "") + ")"}`);
    if (v.ok) accepted++;
    else {
      refused++;
      assert.ok(v.errors.length > 0 && v.errors.every((e) => e.length > 0), `${c.name}: a refusal names its error`);
    }
  }
  assert.deepEqual(differ, [], "verdicts differ");
  assert.ok(accepted >= 30 && refused >= 50, `both ways: ${accepted} accepted, ${refused} refused`);
});

test("cartridge: every cartridge thirdjam ships is valid (14+ cuts)", async () => {
  const files = shippedCartridges();
  assert.ok(files.length >= 14, `${files.length} shipped cartridges`);
  for (const f of files) {
    const v = await validateCartridgeText(fs.readFileSync(f, "utf8"));
    assert.ok(v.ok, `${path.basename(f)}: ${v.errors.join("; ")}`);
  }
});

test("cartridge: a refusal is a sentence that starts with the JSON pointer of the fault", async () => {
  const base = JSON.parse(fs.readFileSync(path.join(RINK_CONTENT_DIR, "Cartridges", "hockey.regular.cartridge.json"), "utf8"));
  const r = await applyChanges(base, { "game.skater.speed": 33 });
  assert.equal(r.ok, false);
  assert.match(r.errors[0]!, /^at \/game\/skater\/speed: 33 is above the maximum 16/);
});

test("cartridge: applyChanges applies a change set to a copy, says what moved, and validates", async () => {
  const base = JSON.parse(fs.readFileSync(path.join(RINK_CONTENT_DIR, "Cartridges", "hockey.regular.cartridge.json"), "utf8"));
  const before = JSON.stringify(base);
  const r = await applyChanges(base, { "game.skater.speed": 13, "game.rink.length_m": 60, "game.rink.width_m": 30, "game.teams[0].colour_hex": "#3366ff" });
  assert.ok(r.ok, r.errors.join("; "));
  assert.equal(JSON.stringify(base), before, "the base is never modified");
  assert.equal((r.cartridge as any).game.skater.speed, 13);
  assert.equal((r.cartridge as any).game.teams[0].colour_hex, "#3366ff");
  assert.deepEqual(r.changed, ["game.skater.speed: 11 -> 13", "game.rink.length_m: 90 -> 60", "game.rink.width_m: 45 -> 30", 'game.teams[0].colour_hex: "#2e7bd6" -> "#3366ff"'.replace("#2e7bd6", (base.game.teams[0].colour_hex as string))]);
  // absent = omitted: null removes the key (the default then applies), never writes null
  const d = await applyChanges(base, { "game.puck.drag": null, "game.rules.no_such": undefined });
  assert.ok(d.ok, d.errors.join("; "));
  assert.equal("drag" in (d.cartridge as any).game.puck, false);
  assert.deepEqual(d.changed, ["game.puck.drag: 0.5 -> absent", "game.rules.no_such: absent -> absent"]);
  // a new block is created on the way, and the validator judges it
  const n = await applyChanges(base, { "game.stick.reach_m": 1.4 });
  assert.equal(typeof (n.cartridge as any).game.stick, "object");
  const direct = await validateCartridge(n.cartridge);
  assert.equal(n.ok, direct.ok);
});

test("cartridge: key paths", () => {
  assert.deepEqual(parsePath("game.teams[1].skaters[0].spawn"), ["game", "teams", 1, "skaters", 0, "spawn"]);
  assert.deepEqual(parsePath("values.skater_speed"), ["values", "skater_speed"]);
  assert.throws(() => parsePath("game..x["));
});

test("cartridge: the rules sidecar knows the switches of native/patches-thirdlife", () => {
  assert.ok(knownRules().includes("net_carry_wall"), knownRules().join(","));
  assert.equal(validateRulesText('{"schema":"tl.rink.rules/1","rules":{"net_carry_wall":true}}').ok, true);
  assert.match(validateRulesText('{"schema":"tl.rink.rules/1","rules":{"rocket_skates":1}}').errors[0]!, /unknown rule "rocket_skates"/);
});
