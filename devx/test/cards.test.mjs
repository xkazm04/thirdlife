// Recipe cards: the real tree is green, and every rule fails on an injected fault (temp-dir copies, never repo files).
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { REPO } from "../lib/ctx.mjs";
import { checkCards, validateCard, checkCardAgainstTree } from "../lib/cards/check.mjs";
import { cardBrief } from "../lib/commands/cards.mjs";

const COPY = ["engine/cards", "engine/seeds/seed_paddle", "engine/kernel/api", "engine/kits", "assets/manifest.json", "contracts/pack.schema.json"];
function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "tl-cards-"));
  for (const rel of COPY) fs.cpSync(path.join(REPO, rel), path.join(root, rel), { recursive: true });
  for (const f of fs.readdirSync(path.join(root, "engine/cards"))) if (f !== "two_sides_ball.json") fs.rmSync(path.join(root, "engine/cards", f));
  return root;
}
const cardPath = (root) => path.join(root, "engine/cards/two_sides_ball.json");
const load = (root) => JSON.parse(fs.readFileSync(cardPath(root), "utf8"));
/** Applies `mutate` to the card in a fresh fixture and returns every problem line the check reports. */
function problemsAfter(mutate) {
  const root = fixture();
  try {
    const card = load(root);
    const out = mutate(card, root);
    fs.writeFileSync(cardPath(root), JSON.stringify(out ?? card, null, 2));
    const r = checkCards({ root });
    return { all: [...r.problems.shape, ...r.problems.tree], steps: r.steps };
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
}
const expectProblem = (mutate, re) => {
  const { all, steps } = problemsAfter(mutate);
  assert.ok(all.some((p) => re.test(p)), `expected a problem matching ${re}, got: ${JSON.stringify(all)}`);
  assert.ok(steps.some((s) => !s.ok), "a problem must turn a step red");
};

test("the committed cards pass on the real tree and cover every seed", () => {
  const r = checkCards({ root: REPO });
  assert.deepEqual([...r.problems.shape, ...r.problems.tree, ...r.problems.uncovered], []);
  assert.ok(r.steps.every((s) => s.ok));
  assert.ok(r.cards.length >= 3);
});

test("the untouched fixture copy passes (so every failure below is caused by its mutation)", () => {
  const { all } = problemsAfter(() => {});
  assert.deepEqual(all, []);
});

test("shape: unknown key, missing key, null, empty list, wrong schema, bad id, bad version", () => {
  expectProblem((c) => { c.extra = 1; }, /unknown key 'extra'/);
  expectProblem((c) => { delete c.acceptance; }, /missing 'acceptance'/);
  expectProblem((c) => { c.not_when = null; }, /'not_when' is null/);
  expectProblem((c) => { c.do = []; }, /'do' must be a non-empty list/);
  expectProblem((c) => { c.schema = "tl.card/2"; }, /schema must be 'tl.card\/1'/);
  expectProblem((c) => { c.id = "two_sides_ball"; }, /must look like card\./);
  expectProblem((c) => { c.version = "1"; }, /must be x\.y\.z/);
  expectProblem((c) => { c.bot.extra = "x"; }, /bot: unknown key 'extra'/);
  expectProblem((c) => { c.variants[0] = { ask: "x" }; }, /variants\[0\]: missing 'change'/);
  expectProblem((c) => { c.api.push("rules.add_score"); }, /must look like TLClass\.member/);
  expectProblem((c) => { c.kit_parts.push("ball"); }, /lists 'ball' twice/);
  expectProblem((c) => { c.swap_parts.push("ball"); }, /in both kit_parts and swap_parts/);
});

test("file name must match the id, and ids are unique", () => {
  expectProblem((c) => { c.id = "card.other_name"; }, /lives in engine\/cards\/other_name\.json/);
  const root = fixture();
  try {
    fs.copyFileSync(cardPath(root), path.join(root, "engine/cards/zz_copy.json"));
    const r = checkCards({ root });
    assert.ok(r.problems.shape.some((p) => /already used by/.test(p)));
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});

test("references: seed, capability, kit part, swap part, api, rules key, data file, bot", () => {
  expectProblem((c) => { c.seed = "seed_nowhere"; }, /seed 'seed_nowhere' has no/);
  expectProblem((c) => { c.capabilities.push("telepathy"); }, /'telepathy' is not in contracts\/pack\.schema\.json/);
  expectProblem((c) => { c.capabilities.push("vehicle"); }, /'vehicle' is not declared by seed_paddle/);
  expectProblem((c) => { c.kit_parts.push("trampoline"); }, /kit part 'trampoline' does not exist in the kit/);
  expectProblem((c) => { c.kit_parts.push("crane"); }, /kit part 'crane' is not used by seed_paddle/);
  expectProblem((c) => { c.swap_parts.push("trampoline"); }, /swap part 'trampoline' does not exist/);
  expectProblem((c) => { c.api.push("TLNowhere.create"); }, /no class TLNowhere/);
  expectProblem((c) => { c.api.push("TLBall.teleport"); }, /TLBall has no func, signal or var 'teleport'/);
  expectProblem((c) => { c.api.push("TLRules.pass_checkpoint"); }, /'TLRules.pass_checkpoint' is never used in seed_paddle/);
  expectProblem((c) => { c.rules_keys.push("laps_to_win"); }, /rules key 'laps_to_win' is not set/);
  expectProblem((c) => { c.data_files.push({ file: "data/none.json", role: "x" }); }, /data file 'data\/none\.json' does not exist/);
  expectProblem((c) => { c.bot.template = "tests/bot_none.gd"; }, /bot template 'tests\/bot_none\.gd' does not exist/);
});

test("the engine moving under a card is caught: a renamed API member, a removed kit part, a seed that stopped using a part", () => {
  expectProblem((c, root) => {   // the kernel renames TLBall.shoot_at
    const f = path.join(root, "engine/kernel/api/tl_ball.gd");
    fs.writeFileSync(f, fs.readFileSync(f, "utf8").replace(/func shoot_at\(/, "func launch_at("));
  }, /TLBall has no func, signal or var 'shoot_at'/);
  expectProblem((c, root) => {   // the kit drops the paddle
    const f = path.join(root, "assets/manifest.json");
    const m = JSON.parse(fs.readFileSync(f, "utf8")); m.assets = m.assets.filter((a) => a.id !== "kit.paddle");
    fs.writeFileSync(f, JSON.stringify(m));
  }, /kit part 'paddle' does not exist in the kit/);
  expectProblem((c, root) => {   // the seed's court no longer has stands
    const f = path.join(root, "engine/seeds/seed_paddle/data/court.json");
    fs.writeFileSync(f, fs.readFileSync(f, "utf8").replace(/"kind"\s*:\s*"stands"/g, '"kind": "cabin"'));
  }, /kit part 'stands' is not used by seed_paddle/);
});

test("a bot that left the seed's manifest tests is caught; a missing asset manifest is named, not guessed around", () => {
  expectProblem((c, root) => {
    const f = path.join(root, "engine/seeds/seed_paddle/pack.json");
    const m = JSON.parse(fs.readFileSync(f, "utf8")); m.tests = []; fs.writeFileSync(f, JSON.stringify(m));
  }, /is not in seed_paddle's manifest tests/);
  expectProblem((c, root) => { fs.rmSync(path.join(root, "assets/manifest.json")); }, /assets\/manifest\.json unreadable/);
});

test("coverage: a seed with no card turns the coverage step red", () => {
  const root = fixture();
  try {
    fs.cpSync(path.join(REPO, "engine/seeds/seed_wall"), path.join(root, "engine/seeds/seed_wall"), { recursive: true });
    const r = checkCards({ root });
    assert.deepEqual(r.problems.uncovered, ["seed_wall"]);
    assert.equal(r.steps.find((s) => s.id === "cards.coverage").ok, false);
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});

test("invalid JSON and an empty cards directory are errors", () => {
  const root = fixture();
  try {
    fs.writeFileSync(cardPath(root), "{ not json");
    assert.ok(checkCards({ root }).problems.shape.some((p) => /not valid JSON/.test(p)));
    fs.rmSync(cardPath(root));
    assert.ok(checkCards({ root }).problems.shape.some((p) => /holds no card/.test(p)));
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});

test("validateCard and checkCardAgainstTree work alone; the brief is deterministic and carries the card", () => {
  const card = load(REPO);
  assert.deepEqual(validateCard(card), []);
  assert.deepEqual(checkCardAgainstTree(card, REPO), []);
  const a = cardBrief(card), b = cardBrief(JSON.parse(JSON.stringify(card)));
  assert.equal(a, b);
  for (const needle of [card.id, `engine/seeds/${card.seed}/`, card.bot.template, card.do[0], card.dont[0], card.acceptance[0], card.variants[0].ask]) {
    assert.ok(a.includes(needle), `brief lacks: ${needle}`);
  }
});
