// N2 of 23 Nov: the game-design method (docs/design/METHOD.md) in the editor. The room's prompts carry its sections;
// a room design writes the method lines (FANTASY, TEARDOWN, 30 SECONDS, KILL IF) at the head of brief.rules and is sent
// back without them; the review, the Planner, the builders and the critic read them; the critic scores the kill lines
// the frames can show; `foreman status` prints the person's paper check before approval and the playtest card at a
// phase pause.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { METHOD_LINES, VERBS, cleanup, sampleConcept, v2Brief } from "./helpers.js";
import { FakeBuilder, type FakeStep } from "../builder/fake.js";
import { designRoom } from "../room.js";
import { critic, renderPlannerPrompt } from "../designer.js";
import { METHOD_DOC, killItem, methodBlock, methodLines, methodProblems, methodText, playtestCard } from "../method.js";
import { builderFeelSection } from "../roomtext.js";
import { designLines } from "../status.js";
import type { JobState } from "../joblog.js";

after(cleanup);

const estimate = { packages: 6, wallMinutes: 60, tokens: 900000 };
const ok = { scores: { hook: 0.8, gif: 0.8, depth: 0.8, feel: 0.8, fit: 0.8 }, slop: [], verdict: "ok", notes: "Sell the bank shot." };
const noMethod = (): ReturnType<typeof v2Brief> => ({ ...v2Brief(), rules: v2Brief().rules.split("\n").filter((l) => !/^(FANTASY|TEARDOWN|30 SECONDS|KILL IF):/.test(l)).join("\n") });

test("METHOD.md: sections 1-14 by number, the role rules of section 14, and every cited source listed", () => {
  const doc = fs.readFileSync(METHOD_DOC, "utf8");
  for (let n = 1; n <= 14; n++) assert.match(doc, new RegExp(`^## ${n}\\. `, "m"), `section ${n}`);
  for (const role of ["Concept", "Designer", "Reviewer", "Planner", "Builder", "Critic", "Person"]) assert.ok(methodText([`14:${role}`]).includes(`(${role})`), `role ${role}`);
  const sources = doc.slice(doc.indexOf("## Sources"));
  const cited = new Set([...doc.slice(0, doc.indexOf("## Sources")).matchAll(/\[([0-9][0-9, ]*)\]/g)].flatMap((m) => (m[1] as string).split(",").map((x) => Number(x.trim()))));
  assert.ok(cited.size >= 25, `${cited.size} sources cited`);
  for (const n of cited) assert.match(sources, new RegExp(`^${n}\\. .*\\S`, "m"), `source ${n} is listed`);
  assert.match(methodText(["1"]), /a person wants to play it again|A bot figure never passes a stage/);
});

test("method lines: parsed from brief.rules by label; counts and word limits are checked; a brief without them has none", () => {
  const l = methodLines(v2Brief().rules);
  assert.equal(l.fantasy.length, 1);
  assert.equal(l.teardown.length, 1);
  assert.equal(l.thirty.length, 1);
  assert.equal(l.kill.length, 2);
  assert.deepEqual(methodProblems(v2Brief()), []);
  const none = methodProblems(noMethod());
  assert.equal(none.length, 4, none.join("\n"));
  assert.match(none.join("\n"), /exactly one "FANTASY: [^]*1 to 3 "TEARDOWN: [^]*exactly one "30 SECONDS: [^]*2 to 4 "KILL IF: /);
  const long = methodProblems({ rules: `${METHOD_LINES}\nKILL IF: ${"word ".repeat(31)}` });
  assert.match(long.join("\n"), /KILL IF line \(31 words, limit 30\)/);
  assert.equal(methodBlock(noMethod()), "");
  assert.equal(killItem(noMethod()), undefined);
  assert.deepEqual(playtestCard(noMethod(), "j", { id: "core", try: "t" }, true), []);
});

test("room: the concept, design and review prompts carry the method; a design without the method lines is sent back, then kept", async () => {
  const steps: FakeStep[] = [
    { match: { role: "concept" }, json: { concept: sampleConcept() } },
    { match: { role: "designer", attempt: 1 }, json: { brief: noMethod(), estimate } },
    { match: { role: "designer", attempt: 2 }, json: { brief: v2Brief(), estimate } },
    { match: { role: "design_review" }, json: ok },
  ];
  const b = new FakeBuilder({ steps });
  const r = await designRoom(b, { sentence: "a ball-and-paddle game in a walled court" });
  assert.ok(r.ok, r.ok ? "" : r.reason);
  assert.deepEqual(b.calls.map((c) => c.req.meta?.role), ["concept", "designer", "designer", "design_review"]);
  const [concept, design1, design2, review] = b.calls.map((c) => c.req.prompt);
  // Concept: the test, fantasy first, references as teardown lines, and the method's sections pasted.
  assert.match(concept ?? "", /# The test: a person wants to play it again[^]*\*\*The fantasy first\.\*\*[^]*# The method \(docs\/design\/METHOD\.md\)\n## 1\. The test, and what evidence counts[^]*## 4\. Stage 1: the fantasy[^]*## 9\. Stage 6: the reference-game teardown[^]*## 14\. Rules by role \(Concept\)/);
  // Design: the stages in order, the line format, and the method's 30-second, feel and kill sections.
  assert.match(design1 ?? "", /# Work in the method's order[^]*1\. \*\*Fantasy\*\*[^]*8\. \*\*Kill criteria\*\*[^]*KILL IF: <at most 30 words>[^]*## 7\. Stage 4: the 30-second test[^]*## 11\. Stage 8: kill criteria[^]*## 14\. Rules by role \(Designer\)/);
  assert.doesNotMatch(design1 ?? "", /## 1\. Design practice/, "GAME-QUALITY section 1 is replaced by the method");
  assert.match(design2 ?? "", /Your previous answer was rejected[^]*exactly one "FANTASY: /);
  // Review: the method lines of THIS design, and the reviewer's rules.
  assert.match(review ?? "", /# The method lines of this design \(the head of `rules`\)\n- the fantasy: I am the wall-banking ace[^]*- kill if: a slap reads as the ball sliding[^]*## 14\. Rules by role \(Reviewer\)[^]*walk the 30 SECONDS line as the newcomer/);
  assert.deepEqual(methodLines(r.value.brief.rules).kill.length, 2, "the kept brief carries its kill lines");
});

test("Planner and builders: the first phase is a greybox a person plays; feel numbers in data/tuning.json; the builder's feel section names the method lines", () => {
  const plan = renderPlannerPrompt({ sentence: "s", packId: "game.x", title: "X", brief: { ...v2Brief(), concept: sampleConcept() }, packContract: "(c)" }, { verbs: VERBS });
  assert.match(plan, /# The method \(docs\/design\/METHOD\.md\): the first phase is a greybox a person plays\n## 14\. Rules by role \(Planner\)[^]*then a PERSON plays it for 5 minutes and passes or holds it[^]*`data\/tuning\.json`/);
  assert.match(plan, /- rules: FANTASY: I am the wall-banking ace/, "the brief text starts with the method lines");
  const feel = builderFeelSection(sampleConcept().template);
  assert.match(feel, /a person plays this, so it must feel good in the hand[^]*FANTASY \(what the player must feel\)[^]*## 14\. Rules by role \(Builder\)/);
});

test("critic: the method's critic rules in the prompt; kill_criteria is a rubric item the answer must score", async () => {
  const item = killItem(v2Brief());
  assert.ok(item);
  assert.equal(item.id, "kill_criteria");
  assert.match(item.text, /\(1\) a newcomer never banks a shot[^]*\(2\) a slap reads as the ball sliding[^]*a person must judge it/);
  const b = new FakeBuilder({ steps: [{ match: { role: "critic", attempt: 1 }, json: { ok: true, scores: { readability: 0.8 }, notes: ["a slap"] } }, { match: { role: "critic" }, json: { ok: false, scores: { readability: 0.8, kill_criteria: 0 }, notes: ["kill line 2: the ball slides off the paddle in image 1"] } }] });
  const res = await critic(b, ["x.png"], [{ id: "readability", text: "r" }, item], { attempts: 2 });
  assert.ok(res.ok);
  assert.equal(res.value.ok, false, "a kill line seen fails the look");
  assert.match(b.calls[0]?.req.prompt ?? "", /Watch as a newcomer meets the game[^]*# How to watch: the method \(docs\/design\/METHOD\.md\)\n## 14\. Rules by role \(Critic\)[^]*- kill_criteria: The design's kill criteria/);
  assert.match(b.calls[1]?.req.prompt ?? "", /scores has no entry for rubric item "kill_criteria"/);
});

test("status: the paper check before approval, the playtest card at a phase pause (first phase with its 30 seconds), none with run-through", () => {
  const phases = [{ id: "core", title: "Core", try: "Bank a slap past Rex", packages: ["root"], state: "done" as const, doneCount: 1, reviews: [] }, { id: "rex", title: "Rex", try: "Beat Rex's lunge", packages: ["rival"], state: "open" as const, doneCount: 0, reviews: [] }];
  const base = { job: "j1", brief: v2Brief(), briefs: 1, reviews: [], reactions: {}, phases: [], jobState: undefined } as unknown as JobState;
  const paper = designLines(base);
  assert.ok(paper.some((l) => /^paper    read these aloud before you approve/.test(l)), paper.join("\n"));
  assert.ok(paper.some((l) => /^paper    kill if: a newcomer never banks a shot/.test(l)));
  const waiting = { ...base, briefApprovedBy: "player", phases, jobState: { state: "paused", reason: "phase" } } as unknown as JobState;
  const card = designLines(waiting).filter((l) => l.startsWith("playtest"));
  assert.match(card.join("\n"), /^playtest phase core: play it yourself[^]*playtest the fantasy: I am the wall-banking ace[^]*playtest first 30 s: 0-5 s[^]*playtest promise: Bank a slap past Rex[^]*playtest kill if: a newcomer never banks[^]*playtest then: did you want one more go\? yes: foreman phase j1 pass/);
  assert.deepEqual(designLines({ ...waiting, runThrough: true } as unknown as JobState).filter((l) => l.startsWith("playtest")), []);
});
