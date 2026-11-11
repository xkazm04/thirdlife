import { test, after } from "node:test";
import assert from "node:assert/strict";
import { FakeBuilder } from "../builder/fake.js";
import { designBrief, planPackages, planCheck, critic } from "../designer.js";
import { cleanup, fixturePlan, VERBS } from "./helpers.js";
import type { PackageSpec } from "../events.js";

after(cleanup);

const brief = { rules: "first to 5", arena: "16 m by 9 m, walled", ai: "follows the ball", controls: "paddle_up, paddle_down", mood: "flat blocks" };
const estimate = { packages: 3, wallMinutes: 20, tokens: 150000 };
const sentence = "a ball-and-paddle game in a walled court";

test("designer: a valid brief is accepted; the prompt carries the sentence and the schema; the call is generate mode", async () => {
  const b = new FakeBuilder({ steps: [{ match: { role: "designer" }, json: { brief, estimate }, tokensIn: 900, tokensOut: 200 }] });
  const r = await designBrief(b, sentence);
  assert.ok(r.ok);
  assert.deepEqual(r.value, { brief, estimate });
  assert.equal(r.calls.length, 1);
  const req = b.calls[0]?.req;
  assert.equal(req?.mode, "generate");
  assert.ok(req?.schema);
  assert.match(req?.prompt ?? "", /"a ball-and-paddle game in a walled court"/);
  assert.match(req?.prompt ?? "", /"additionalProperties": false/);
});

test("designer: an invalid brief is rejected with the reasons and asked again once; a second invalid answer fails", async () => {
  const b = new FakeBuilder({
    steps: [
      { match: { role: "designer", attempt: 1 }, json: { brief: { ...brief, vibe: "extra key" }, estimate } },
      { match: { role: "designer", attempt: 2 }, json: { brief, estimate } },
    ],
  });
  const r = await designBrief(b, sentence);
  assert.ok(r.ok);
  assert.equal(r.calls.length, 2);
  assert.equal(r.calls[0]?.result.outcome, "error");
  assert.match(b.calls[1]?.req.prompt ?? "", /Your previous answer was rejected/);
  assert.match(b.calls[1]?.req.prompt ?? "", /additional properties "vibe"/);

  const never = new FakeBuilder({ steps: [{ match: { role: "designer" }, json: { brief: { rules: "only this" }, estimate } }] });
  const bad = await designBrief(never, sentence);
  assert.equal(bad.ok, false);
  assert.equal(bad.calls.length, 2);
  assert.match(bad.ok ? "" : bad.reason, /still invalid after 2 attempts/);
});

test("designer: a timeout or a truncated answer is not retried and is reported as what it is", async () => {
  const hang = new FakeBuilder({ steps: [{ match: { role: "designer" }, hang: true }] });
  const r = await designBrief(hang, sentence, { timeoutMs: 30 });
  assert.equal(r.ok, false);
  assert.equal(r.calls.length, 1);
  assert.match(r.ok ? "" : r.reason, /builder timeout/);
  const cut = new FakeBuilder({ steps: [{ match: { role: "designer" }, text: '{"brief": {"rules": "first to' }] });
  const c = await designBrief(cut, sentence);
  assert.equal(c.calls[0]?.result.outcome, "truncated");
  assert.match(c.ok ? "" : c.reason, /builder truncated/);
});

test("planner: the fixture plan passes; graph and scope mistakes are named", async () => {
  const plan = fixturePlan();
  assert.deepEqual(planCheck(plan, { verbs: VERBS }), []);
  const b = new FakeBuilder({ steps: [{ match: { role: "planner" }, json: { packages: plan } }] });
  const r = await planPackages(b, { sentence, packId: "game.paddle_court", title: "Paddle Court", brief, packContract: "(contract)" }, { verbs: VERBS });
  assert.ok(r.ok);
  assert.equal(r.value.packages.length, 3);
  assert.match(b.calls[0]?.req.prompt ?? "", /Pack id: game\.paddle_court/);

  const clone = (): PackageSpec[] => JSON.parse(JSON.stringify(plan)) as PackageSpec[];
  const overlap = clone();
  (overlap[1] as PackageSpec).scope.push("scripts/main.gd");
  assert.match(planCheck(overlap, { verbs: VERBS }).join("\n"), /"core" and "court" both claim scope "scripts\/main\.gd"/);
  const inside = clone();
  (inside[2] as PackageSpec).scope = ["scripts/**"];
  assert.match(planCheck(inside, { verbs: VERBS }).join("\n"), /scope "scripts\/main\.gd" of package "core" lies inside scope "scripts\/\*\*" of package "paddle_ai"/);
  const cycle = clone();
  (cycle[0] as PackageSpec).deps = ["court"];
  assert.match(planCheck(cycle, { verbs: VERBS }).join("\n"), /dependency cycle/);
  const noManifest = clone();
  (noManifest[0] as PackageSpec).scope = ["pack.json", "scripts/main.gd", "tests/bot_rally.gd"];
  assert.match(planCheck(noManifest, { verbs: VERBS }).join("\n"), /package "core": scope must not include pack\.json/);
  const botNoTest = clone();
  (botNoTest[2] as PackageSpec).acceptance = [{ level: "V4", verb: "bot", args: [] }];
  assert.match(planCheck(botNoTest, { verbs: VERBS }).join("\n"), /bot acceptance needs --test/);
  const inject = clone();
  (inject[0] as PackageSpec).acceptance = [{ level: "V2", verb: "smoke", args: ["--seed=1; rm -rf ."] }];
  assert.match(planCheck(inject, { verbs: VERBS }).join("\n"), /is not a plain --key=value/);
  const escape = clone();
  (escape[0] as PackageSpec).scope.push("../outside.gd");
  assert.match(planCheck(escape, { verbs: VERBS }).join("\n"), /leaves the pack/);

  const badPlanner = new FakeBuilder({ steps: [{ match: { role: "planner" }, json: { packages: cycle } }] });
  const bad = await planPackages(badPlanner, { sentence, packId: "game.paddle_court", title: "Paddle Court", brief, packContract: "(contract)" }, { verbs: VERBS });
  assert.equal(bad.ok, false);
  assert.equal(bad.calls.length, 2, "a plan that fails our checks is sent back once");
  assert.match(badPlanner.calls[1]?.req.prompt ?? "", /dependency cycle/);
});

test("critic (V5 seam): scores per rubric item; ok is recomputed from the scores, not taken on the model's word", async () => {
  const rubric = [
    { id: "silhouette", text: "paddles and ball read against the court" },
    { id: "readability", text: "score is legible" },
  ];
  const good = new FakeBuilder({ steps: [{ match: { role: "critic" }, json: { ok: true, scores: { silhouette: 0.9, readability: 0.7 }, notes: ["clear"] } }] });
  const r = await critic(good, ["/captures/blockout-hero.png"], rubric);
  assert.ok(r.ok);
  assert.deepEqual(r.value, { ok: true, scores: { silhouette: 0.9, readability: 0.7 }, notes: ["clear"] });
  assert.equal(good.calls[0]?.req.mode, "generate");
  assert.match(good.calls[0]?.req.prompt ?? "", /blockout-hero\.png/);

  const flatterer = new FakeBuilder({ steps: [{ match: { role: "critic" }, json: { ok: true, scores: { silhouette: 0.9, readability: 0.2 }, notes: [] } }] });
  const f = await critic(flatterer, ["/captures/a.png"], rubric);
  assert.ok(f.ok);
  assert.equal(f.value.ok, false);
  assert.match(f.value.notes.join(" "), /critic said ok=true; scores against threshold 0\.6 give ok=false/);

  const missing = new FakeBuilder({ steps: [{ match: { role: "critic" }, json: { ok: true, scores: { silhouette: 0.9 }, notes: [] } }] });
  const m = await critic(missing, ["/captures/a.png"], rubric);
  assert.equal(m.ok, false);

  const none = await critic(good, [], rubric);
  assert.ok(none.ok);
  assert.equal(none.value.ok, false, "no captures can never be a pass");

  const scan = new FakeBuilder({ steps: [{ match: { role: "critic", mode: "readonly-scan" }, json: { ok: true, scores: { silhouette: 1, readability: 1 }, notes: [] } }] });
  const s = await critic(scan, ["/captures/a.png"], rubric, { handOff: "readonly-scan" });
  assert.ok(s.ok);
  assert.equal(scan.calls[0]?.req.mode, "readonly-scan");
});
