// Lane C2 (engine-world-next, 18 Nov): the job card's hand checks at final verification (handcheck.ts).
//   a pack whose hand tests meet the card's bounds is promoted; one that misses a bound, or lacks a hand test, is not.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempDir, tempJob, foremanFor, readEvents, fixtureScript, fixturePlan, VERBS, type TempJob } from "./helpers.js";
import { planCheck } from "../designer.js";
import { validateEvent, type JobEvent, type PackageSpec } from "../events.js";
import { prepareReference } from "../reference.js";
import { REPO_ROOT } from "../paths.js";
import { handsOf } from "../handcheck.js";
import { cardOf, cardsPlannerText } from "../cards.js";
import type { FakeStep } from "../builder/fake.js";

after(cleanup);

const HAND_TESTS = ["tests/bot_hand_idle.gd", "tests/bot_hand_perfect.gd"];

/** A job on the fixture plan whose card asks idle <= 0 and perfect >= `min` of 4 seeds; court owns the hand tests. */
function handJob(label: string, min: number, register = HAND_TESTS): TempJob {
  const job = tempJob(label);
  const cards = path.join(tempDir(`${label}-cards`), "cards");
  fs.mkdirSync(cards, { recursive: true });
  const card = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "engine", "cards", "knock_down.json"), "utf8")) as Record<string, unknown>;
  card["hands"] = { seeds: 4, checks: [{ hand: "idle", wins_max: 0, measured: "test" }, { hand: "perfect", wins_min: min, measured: "test" }] };
  fs.writeFileSync(path.join(cards, "knock_down.json"), JSON.stringify(card));
  prepareReference(path.join(job.jobDir, "ref"), { cardsDir: cards });
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter((l) => l.length > 0).map((l) => {
    const ev = JSON.parse(l) as JobEvent;
    if (ev.type !== "plan_set") return l;
    const court = ev.packages.find((p) => p.id === "court") as PackageSpec;
    court.scope.push(...HAND_TESTS);
    court.registers = { tests: register };
    return JSON.stringify(validateEvent({ ...ev, card: "card.knock_down" }));
  });
  fs.writeFileSync(file, lines.join("\n") + "\n");
  return job;
}
/** The fixture's builder; court also writes the two hand tests: idle never wins, perfect wins seeds 1..perfectWins.
 *  With `secondRound`, court's round 2 (the round a failed hand check sends back) writes perfect winning that many. */
function handScript(perfectWins: number, secondRound?: number): { steps: FakeStep[] } {
  const base = fixtureScript();
  const court = base.steps.find((s) => s.match?.package === "court") as FakeStep;
  const withHands: FakeStep = {
    ...court,
    delayMs: 0,
    write: { ...court.write, "tests/bot_hand_idle.gd": "extends Node\n# idle: presses nothing FAKE_WON(0)\n", "tests/bot_hand_perfect.gd": `extends Node\n# perfect hand FAKE_WON(${perfectWins})\n` },
  };
  const again: FakeStep[] = secondRound === undefined ? [] : [{ ...withHands, match: { role: "builder", package: "court", round: 2 }, write: { ...withHands.write, "tests/bot_hand_perfect.gd": `extends Node\n# perfect hand, after the fix FAKE_WON(${secondRound})\n` } }];
  return { ...base, steps: [...again, withHands, ...base.steps.map((s) => ({ ...s, delayMs: 0 }))] };
}
const handVerifies = (jobDir: string): Extract<JobEvent, { type: "verify" }>[] =>
  readEvents(jobDir).filter((e): e is Extract<JobEvent, { type: "verify" }> => e.type === "verify" && /final-hand-/.test(e.report));

test("hands 1: a pack whose hand tests meet the card (idle 0 of 4, perfect 4 of 4 >= 3) is promoted; every seed of every hand ran", async () => {
  const job = handJob("hands-pass", 3);
  assert.equal(handsOf(cardOf(path.join(job.jobDir, "ref"), "card.knock_down"))?.checks.length, 2);
  assert.match(cardsPlannerText(path.join(job.jobDir, "ref")), /hand checks: when you name this card, some package must register tests\/bot_hand_idle\.gd, tests\/bot_hand_perfect\.gd/);
  const s = await foremanFor(job, { promoteTo: "job", script: handScript(4) }).foreman.run();
  assert.equal(s.jobState?.state, "done", s.jobState?.reason);
  assert.equal(s.promotions.length, 1);
  const runs = handVerifies(job.jobDir);
  assert.equal(runs.length, 8, "2 hands x 4 seeds");
  assert.deepEqual(runs.map((e) => /final-hand-(\w+)-seed(\d+)/.exec(e.report)?.slice(1).join(":")), ["idle:1", "idle:2", "idle:3", "idle:4", "perfect:1", "perfect:2", "perfect:3", "perfect:4"]);
  assert.ok(runs.every((e) => e.level === "V4" && e.verb === "bot"));
});

test("hands 2 (fail twice): perfect wins 1 of 4 where the card asks 3; court gets ONE round back with the rows, fails again, and the job ends unpromoted", async () => {
  const job = handJob("hands-fail", 3);
  const s = await foremanFor(job, { promoteTo: "job", script: handScript(1) }).foreman.run();
  assert.equal(s.jobState?.state, "failed");
  const evs = readEvents(job.jobDir);
  const back = evs.filter((e): e is Extract<JobEvent, { type: "reopened" }> => e.type === "reopened");
  assert.equal(back.length, 1, "one round back, not two");
  assert.equal(back[0]?.package, "court", "the package that registers the failing test");
  assert.match(back[0]?.reason ?? "", /^hand check failed \(1 of 1\) for card card\.knock_down: tests\/bot_hand_perfect\.gd \(perfect hand\): 1 of 4 won .*the card asks at least 3/);
  const queued = evs.find((e) => e.type === "package_state" && e.package === "court" && e.state === "queued" && e.seq > (back[0]?.seq ?? 0));
  assert.ok(queued && queued.type === "package_state" && queued.round === 2 && (queued.detail ?? "").startsWith("hand check failed"), "a queued round 2 whose detail starts hand check");
  assert.equal(handVerifies(job.jobDir).length, 16, "the hand checks ran twice (2 hands x 4 seeds each time)");
  assert.equal(s.promotions.length, 0, "nothing promoted");
  assert.equal(fs.existsSync(path.join(job.jobDir, "promoted")), false);
  assert.match(s.jobState?.reason ?? "", /^hand check of card\.knock_down failed, nothing promoted: perfect: 1 of 4 won \(Wilson 95 % \d+\.\.\d+\); the card asks at least 3/);
  assert.doesNotMatch(s.jobState?.reason ?? "", /idle:/, "the idle row held");
});

test("hands 3: a pack that does not register a hand test the card asks for is NOT promoted; a job whose card has no hands runs none", async () => {
  const job = handJob("hands-missing", 3, ["tests/bot_hand_idle.gd"]);
  const s = await foremanFor(job, { promoteTo: "job", script: handScript(4) }).foreman.run();
  assert.equal(s.jobState?.state, "failed");
  assert.match(s.jobState?.reason ?? "", /perfect: the card asks for tests\/bot_hand_perfect\.gd and the pack's manifest does not list it/);
  const plain = tempJob("hands-none");
  const p = await foremanFor(plain, { promoteTo: "job" }).foreman.run();
  assert.equal(p.jobState?.state, "done");
  assert.equal(handVerifies(plain.jobDir).length, 0);
});

test("hands 4 (fail then pass): perfect wins 1 of 4, court's round back fixes it to 4 of 4, the hand checks pass and the pack is promoted", async () => {
  const job = handJob("hands-fix", 3);
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", script: handScript(1, 4) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", s.jobState?.reason);
  assert.equal(s.promotions.length, 1);
  const evs = readEvents(job.jobDir);
  assert.equal(evs.filter((e) => e.type === "reopened").length, 1);
  const r2 = builder.calls.find((c) => c.req.meta?.role === "builder" && c.req.meta?.package === "court" && c.req.meta?.round === 2);
  assert.match(r2?.req.prompt ?? "", /hand check failed \(1 of 1\)[^]*1 of 4 won/, "the rows are in court's brief");
  assert.match(fs.readFileSync(path.join(job.jobDir, "promoted", "game.paddle_court", "tests", "bot_hand_perfect.gd"), "utf8"), /FAKE_WON\(4\)/);
});

test("hands 5 (plan): a plan that names a card with hand checks and registers no hand tests is refused; registering them passes", () => {
  const plan = fixturePlan();
  const cardHands = { "card.knock_down": ["idle", "perfect"] };
  const refused = planCheck(plan, { verbs: VERBS, cards: ["card.knock_down"], cardHands }, "card.knock_down");
  assert.match(refused.join("\n"), /the card card\.knock_down has hand checks, and no package registers tests\/bot_hand_idle\.gd, tests\/bot_hand_perfect\.gd\. Register each in registers\.tests/);
  const court = plan.find((p) => p.id === "court") as PackageSpec;
  court.scope.push(...HAND_TESTS);
  court.registers = { tests: HAND_TESTS };
  assert.deepEqual(planCheck(plan, { verbs: VERBS, cards: ["card.knock_down"], cardHands }, "card.knock_down"), []);
  assert.deepEqual(planCheck(fixturePlan(), { verbs: VERBS, cards: ["card.knock_down"], cardHands }), [], "no card named: nothing owed");
});
