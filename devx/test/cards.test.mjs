// Recipe cards: the real tree is green, and every rule fails on an injected fault (temp-dir copies, never repo files).
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { REPO } from "../lib/ctx.mjs";
import { checkCards, validateCard, checkCardAgainstTree, loadCards } from "../lib/cards/check.mjs";
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

// ---- 2026-11-17 (lane C): a card may point at a house game (`pack`, engine/packs/<name>) instead of a seed.
/** A fixture with the hockey card and the hockey house pack (the seed card stays, so coverage holds). */
function houseFixture() {
  const root = fixture();
  fs.cpSync(path.join(REPO, "engine/packs/hockey"), path.join(root, "engine/packs/hockey"), { recursive: true });
  fs.copyFileSync(path.join(REPO, "engine/cards/team_possession.json"), path.join(root, "engine/cards/team_possession.json"));
  return root;
}
const housePath = (root) => path.join(root, "engine/cards/team_possession.json");
function houseProblemsAfter(mutate) {
  const root = houseFixture();
  try {
    const card = JSON.parse(fs.readFileSync(housePath(root), "utf8"));
    const out = mutate(card, root);
    fs.writeFileSync(housePath(root), JSON.stringify(out ?? card, null, 2));
    const r = checkCards({ root });
    return { all: [...r.problems.shape, ...r.problems.tree], steps: r.steps, r };
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
}
const expectHouseProblem = (mutate, re) => {
  const { all, steps } = houseProblemsAfter(mutate);
  assert.ok(all.some((p) => re.test(p)), `expected a problem matching ${re}, got: ${JSON.stringify(all)}`);
  assert.ok(steps.some((s) => !s.ok), "a problem must turn a step red");
};

test("house pack: the hockey card passes on the real tree and in a fixture; coverage still counts seeds only", () => {
  const real = checkCards({ root: REPO });
  assert.ok(real.cards.some((c) => c.id === "card.team_possession" && c.pack === "hockey"));
  assert.ok(real.cards.length >= 4);
  const { all, r } = houseProblemsAfter(() => {});
  assert.deepEqual(all, []);
  assert.deepEqual(r.problems.uncovered, [], "a house-pack card is not a seed card, and needs none");
  assert.match(r.steps.find((s) => s.id === "cards.coverage").detail, /^1 seeds, each has a card/);
});

test("house pack: a broken `pack` reference, both or neither of seed and pack, and every seed rule applied to the house pack turn it red", () => {
  expectHouseProblem((c) => { c.pack = "curling"; }, /house pack 'curling' has no engine\/packs\/curling\/pack\.json/);
  expectHouseProblem((c) => { c.seed = "seed_paddle"; }, /exactly one of 'seed' and 'pack' must be given/);
  expectHouseProblem((c) => { delete c.pack; }, /exactly one of 'seed' and 'pack' must be given/);
  expectHouseProblem((c) => { c.capabilities.push("vehicle"); }, /'vehicle' is not declared by hockey/);
  expectHouseProblem((c) => { c.kit_parts.push("crane"); }, /kit part 'crane' is not used by hockey/);
  expectHouseProblem((c) => { c.api.push("TLBall.shoot_at"); }, /'TLBall\.shoot_at' is never used in hockey/);
  expectHouseProblem((c) => { c.rules_keys.push("laps_to_win"); }, /rules key 'laps_to_win' is not set in hockey's data/);
  expectHouseProblem((c) => { c.data_files.push({ file: "data/rules.json", role: "x" }); }, /data file 'data\/rules\.json' does not exist in hockey/);
  expectHouseProblem((c) => { c.bot.template = "tests/bot_nowhere.gd"; }, /bot template 'tests\/bot_nowhere\.gd' does not exist in hockey/);
  // The pack moving under the card: the venue loses its scoreboard.
  expectHouseProblem((c, root) => {
    const f = path.join(root, "engine/packs/hockey/data/venue_art.json");
    fs.writeFileSync(f, fs.readFileSync(f, "utf8").replace(/"kind"\s*:\s*"scoreboard"/g, '"kind": "sign"'));
  }, /kit part 'scoreboard' is not used by hockey/);
});

test("house pack: the brief starts from engine/packs/<pack>/ and names it a house game", () => {
  const card = JSON.parse(fs.readFileSync(path.join(REPO, "engine/cards/team_possession.json"), "utf8"));
  const text = cardBrief(card);
  assert.match(text, /^Start from: engine\/packs\/hockey\/ \(copy its shape/m);
  assert.match(text, /^Kit parts the house game already uses: /m);
  assert.doesNotMatch(text, /engine\/seeds\/undefined/);
});

// ---- lane C2 (18 Nov): `hands`, what a person's hand must find; `tl cards hands` runs it on a pack.
import { handRows, overlayPack, readHandRun, parseHandArgs } from "../lib/cards/handrun.mjs";
import { judgeHand, wilson } from "../lib/cards/hands.mjs";

test("hands: every committed card's block is valid; shape errors are named", () => {
  for (const { card } of loadCards(REPO).cards) if (card.hands) assert.deepEqual(validateCard(card), [], card.id);
  expectProblem((c) => { c.hands = { seeds: 20, checks: [{ hand: "idle", wins_max: 0, measured: "m", extra: 1 }] }; }, /checks\[0\]: unknown key 'extra'/);
  expectProblem((c) => { c.hands = { seeds: 20, checks: [{ hand: "lefty", wins_max: 0, measured: "m" }] }; }, /hand 'lefty' must be one of idle, newcomer, regular, sharp, perfect/);
  expectProblem((c) => { c.hands = { seeds: 20, checks: [{ hand: "idle", measured: "m" }] }; }, /give wins_min, wins_max or both/);
  expectProblem((c) => { c.hands = { seeds: 20, checks: [{ hand: "idle", wins_min: 5, wins_max: 2, measured: "m" }] }; }, /wins_min is above wins_max/);
  expectProblem((c) => { c.hands = { seeds: 20, checks: [{ hand: "idle", wins_max: 21, measured: "m" }] }; }, /wins_max must be an integer 0\.\.20/);
  expectProblem((c) => { c.hands = { seeds: 0, checks: [{ hand: "idle", wins_max: 0, measured: "m" }] }; }, /seeds must be an integer 1\.\.40/);
  expectProblem((c) => { c.hands = { seeds: 20, checks: [{ hand: "idle", wins_max: 0, measured: "m" }, { hand: "idle", wins_max: 0, measured: "m" }] }; }, /hand 'idle' is checked twice/);
  expectProblem((c) => { c.hands = { seeds: 20, checks: [] }; }, /'checks' must be a non-empty list/);
  expectProblem((c) => { c.hands = { seeds: 20, checks: [{ hand: "idle", wins_max: 0 }] }; }, /missing 'measured'/);
});

test("hands: the brief tells builders which hand tests to write and what they must find", () => {
  const card = JSON.parse(fs.readFileSync(path.join(REPO, "engine/cards/knock_down.json"), "utf8"));
  const text = cardBrief(card);
  assert.match(text, /^Hand checks \(the Foreman runs them before it promotes, seeds 1 to 20\): register tests\/bot_hand_<hand>\.gd/m);
  assert.match(text, /^- idle: wins at most 0 of 20 \(measured: seed_wall idle 0 of 20/m);
  assert.match(text, /^- perfect: wins at least 16 of 20 \(measured: /m);
});

test("hands: judge and runner core: holds, a bound missed, a run not finished, a result without won, a missing test", async () => {
  assert.deepEqual(wilson(0, 20), { lo: 0, hi: 16 });
  assert.deepEqual(wilson(20, 20), { lo: 84, hi: 100 });
  assert.equal(judgeHand({ wins_max: 0 }, 20, 20, 0).ok, true);
  assert.match(judgeHand({ wins_min: 16 }, 20, 20, 15).why, /15 of 20 won .*the card asks at least 16/);
  assert.match(judgeHand({ wins_max: 0 }, 20, 19, 0).why, /19 of 20 runs finished/);
  assert.match(judgeHand({ wins_max: 0 }, 20, 20, 0, 1).why, /no boolean "won"/);
  const line = (done, won) => JSON.stringify({ schema: "tl.verify/1", checks: [{ id: "bot.completed", ok: done }], bot: { result: won === undefined ? {} : { won } } });
  assert.deepEqual(readHandRun(`banner\n${line(true, true)}\n`), { done: true, won: true });
  assert.deepEqual(readHandRun(line(true, undefined)), { done: true, won: undefined });
  const hands = { seeds: 4, checks: [{ hand: "idle", wins_max: 0, measured: "m" }, { hand: "perfect", wins_min: 3, measured: "m" }, { hand: "newcomer", wins_min: 1, measured: "m" }] };
  const runBot = async (test, seed) => (test.endsWith("idle.gd") ? line(true, false) : seed === 4 ? line(false, false) : line(true, true));
  const rows = await handRows(hands, 4, ["tests/bot_hand_idle.gd", "tests/bot_hand_perfect.gd"], 2, runBot);
  assert.deepEqual(rows.map((r) => `${r.hand}:${r.ok}:${r.completed}:${r.wins}`), ["idle:true:4:0", "perfect:false:3:3", "newcomer:false:0:0"]);
  assert.match(rows[2].why, /does not list tests\/bot_hand_newcomer\.gd/);
  assert.throws(() => parseHandArgs(["x"]), /--card is required/);
});

test("hands: --tests lays bot_hand files over a temporary copy and lists them; the pack itself is untouched", () => {
  const before = fs.readFileSync(path.join(REPO, "engine/seeds/seed_wall/pack.json"), "utf8");
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tl-hand-tests-"));
  try {
    fs.writeFileSync(path.join(dir, "bot_probe.gd.txt"), "extends Node\n");
    fs.writeFileSync(path.join(dir, "bot_hand_idle.gd"), 'extends "bot_probe.gd"\n');
    const out = overlayPack(path.join(REPO, "engine/seeds/seed_wall"), dir);
    try {
      const man = JSON.parse(fs.readFileSync(path.join(out, "pack.json"), "utf8"));
      assert.ok(man.tests.includes("tests/bot_hand_idle.gd"));
      assert.ok(!man.tests.includes("tests/bot_probe.gd"), "only bot_hand_<hand>.gd files are listed");
      assert.ok(fs.existsSync(path.join(out, "tests", "bot_probe.gd")));
    } finally { fs.rmSync(out, { recursive: true, force: true }); }
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  assert.equal(fs.readFileSync(path.join(REPO, "engine/seeds/seed_wall/pack.json"), "utf8"), before);
});

test("hands (C3): every hand a card checks has its tests/bot_hand_<hand>.gd in the example and in its manifest tests", () => {
  expectProblem((c, root) => { fs.rmSync(path.join(root, "engine/seeds/seed_paddle/tests/bot_hand_sharp.gd")); }, /hand check 'sharp': tests\/bot_hand_sharp\.gd does not exist in seed_paddle/);
  expectProblem((c, root) => {
    const f = path.join(root, "engine/seeds/seed_paddle/pack.json");
    fs.writeFileSync(f, fs.readFileSync(f, "utf8").replace(', "tests/bot_hand_idle.gd"', ""));
  }, /hand check 'idle': tests\/bot_hand_idle\.gd is not in seed_paddle's manifest tests/);
  const text = cardBrief(JSON.parse(fs.readFileSync(path.join(REPO, "engine/cards/two_sides_ball.json"), "utf8")));
  assert.match(text, /^The example's hand tests, to copy \(a plan without them is refused\): engine\/seeds\/seed_paddle\/tests\/bot_hand_idle\.gd, engine\/seeds\/seed_paddle\/tests\/bot_hand_sharp\.gd, engine\/seeds\/seed_paddle\/tests\/bot_hand_perfect\.gd$/m);
  assert.match(text, /idle: press nothing, and never stop on your own/);
});

test("hands (C4): --seeds below the card's count is refused with a sentence; more seeds scale each bound by its share", async () => {
  const { seedsBelow, scaleHands, runHands } = await import("../lib/cards/handrun.mjs");
  const ctx = await import("../lib/ctx.mjs");
  const hands = { seeds: 20, checks: [{ hand: "idle", wins_max: 0, measured: "m" }, { hand: "perfect", wins_min: 16, measured: "m" }, { hand: "sharp", wins_min: 1, wins_max: 5, measured: "m" }] };
  assert.match(seedsBelow(hands, 3), /^--seeds 3 is below the 20 seeds this card's bounds were measured on: a bound like "at least 16 of 20" cannot be judged on fewer runs\. Use --seeds 20 or more\.$/);
  assert.equal(seedsBelow(hands, 20), "");
  assert.equal(scaleHands(hands, 20), hands);
  assert.deepEqual(scaleHands(hands, 40).checks.map((c) => [c.wins_min, c.wins_max]), [[undefined, 0], [32, undefined], [2, 10]]);
  assert.deepEqual(scaleHands(hands, 30).checks.map((c) => [c.wins_min, c.wins_max]), [[undefined, 0], [24, undefined], [2, 7]]);
  let ran = 0;
  const errs = [];
  const orig = console.error;
  console.error = (m) => errs.push(String(m));
  try {
    const code = await runHands(["engine/seeds/seed_wall", "--card", "knock_down", "--seeds", "3"], ctx, { runBot: async () => { ran += 1; return ""; } });
    assert.equal(code, 2, "could not run: exit 2");
  } finally { console.error = orig; }
  assert.equal(ran, 0, "nothing is run");
  assert.match(errs.join("\n"), /--seeds 3 is below the 20 seeds/);
});

test("editor recipes live on the four cards and validate against the interview and footprint shapes", () => {
  const { cards } = loadCards(REPO);
  for (const name of ["knock_down", "team_possession", "timed_drive", "two_sides_ball"]) {
    const { card } = cards.find(({ card }) => card.id === "card." + name);
    assert.ok(card.interview?.questions.length, name);
    assert.ok(card.footprint?.source, name);
    assert.deepEqual(validateCard(card, card.id), []);
  }
});

test("interview references, option uniqueness and nested keys are checked", () => {
  expectProblem((c) => { c.interview.questions[0].propose = "foo"; }, /questions\[0\]: propose 'foo' is not one of its options/);
  expectProblem((c) => { c.interview.questions[0].options.push(c.interview.questions[0].options[0]); }, /duplicate option id/);
  expectProblem((c) => { c.interview.questions[1].extra = true; }, /questions\[1\]: unknown key 'extra'/);
  expectProblem((c) => { c.footprint.shape = "lake"; }, /footprint:.*shape/);
  expectProblem((c) => { c.interview.variants[0].set.kind = "lost"; }, /variants\[0\].*'lost'/);
});

test("interview size modifiers, stands and estimate bounds are validated", () => {
  const card = load(REPO), opt = card.interview.questions[0].options[0];
  opt.stands = true;
  for (const size of [{ scale: 0.5 }, { set: [1, 2, 3] }, { add: [0, -2, 4] }]) {
    opt.size = size;
    assert.deepEqual(validateCard(card), []);
  }
  for (const size of [{}, { add: [1, 2] }, { set: [1, 0, 3] }, { scale: 0 }, { scale: 2, add: [0, 0, 1] }, { width: 20 }]) {
    opt.size = size;
    assert.match(validateCard(card).join("\n"), /options\[0\].size/);
  }
  delete opt.size;
  opt.stands = false;
  card.interview.estimate.packages = 1.5;
  card.interview.estimate.minutes = 0;
  const errors = validateCard(card).join("\n");
  for (const field of ["stands", "packages", "minutes"]) assert.ok(errors.includes(field));
});
