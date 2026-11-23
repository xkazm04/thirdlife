// N2 of 23 Nov: the game-design method (docs/design/METHOD.md) in the editor. The room's prompts carry its sections;
// a room design writes the method lines (FANTASY, TEARDOWN, 30 SECONDS, KILL IF) at the head of brief.rules and is sent
// back without them; the review, the Planner, the builders and the critic read them; the critic scores the kill lines
// the frames can show; `foreman status` prints the person's paper check before approval and the playtest card at a
// phase pause.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { REPO_ROOT } from "../paths.js";
import { METHOD_LINES, VERBS, cleanup, sampleConcept, sampleDesign, v2Brief } from "./helpers.js";
import { FakeBuilder, type FakeStep } from "../builder/fake.js";
import { designRoom } from "../room.js";
import { critic, renderDesignerPrompt, renderPlannerPrompt } from "../designer.js";
import { METHOD_DOC, killItem, methodBlock, methodLines, methodProblems, methodText, playtestCard } from "../method.js";
import { builderFeelSection } from "../roomtext.js";
import { designLines } from "../status.js";
import { tofuMetricsFor } from "../tofu.js";
import type { JobState } from "../joblog.js";

after(cleanup);

const estimate = { packages: 6, wallMinutes: 60, tokens: 900000 };
const ok = { scores: { hook: 0.8, gif: 0.8, depth: 0.8, feel: 0.8, fit: 0.8 }, slop: [], verdict: "ok", notes: "Sell the bank shot." };
const noMethod = (): ReturnType<typeof v2Brief> => ({ ...v2Brief(), rules: v2Brief().rules.split("\n").filter((l) => !/^(FANTASY|WORLD|TEARDOWN|30 SECONDS|KILL IF):/.test(l)).join("\n") });

test("METHOD.md: sections 1-14 by number, the role rules of section 14, and every cited source listed", () => {
  const doc = fs.readFileSync(METHOD_DOC, "utf8");
  for (let n = 1; n <= 14; n++) assert.match(doc, new RegExp(`^## ${n}\\. `, "m"), `section ${n}`);
  for (const role of ["Concept", "Designer", "Reviewer", "Planner", "Builder", "Critic", "Director", "Person"]) assert.ok(methodText([`14:${role}`]).includes(`(${role})`), `role ${role}`);
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
  assert.equal(none.length, 5, none.join("\n"));
  assert.match(none.join("\n"), /exactly one "FANTASY: [^]*exactly one "WORLD: [^]*1 to 3 "TEARDOWN: [^]*exactly one "30 SECONDS: [^]*2 to 4 "KILL IF: /);
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
  // The person gate (owner, 23 Nov): with run-through too, the first phase (the greybox) waits for a hand with the card;
  // run-through passes only a later phase, which shows no card.
  const rtFirst = designLines({ ...waiting, runThrough: true } as unknown as JobState);
  assert.deepEqual(rtFirst.filter((l) => l.startsWith("playtest")), card);
  assert.ok(rtFirst.some((l) => l.startsWith("waiting  phase core is the greybox and waits for your hand (run-through passes only the phases after it)")), rtFirst.join("\n"));
  const second = [{ ...phases[0], state: "passed" as const }, { ...phases[1], state: "done" as const, doneCount: 1 }];
  const rtLater = designLines({ ...waiting, phases: second, runThrough: true } as unknown as JobState);
  assert.deepEqual(rtLater.filter((l) => l.startsWith("playtest")), []);
  assert.ok(rtLater.some((l) => l === "waiting  phase rex is done; run-through passes it when the Foreman runs: foreman resume j1"), rtLater.join("\n"));
  assert.ok(designLines({ ...waiting, phases: second } as unknown as JobState).some((l) => l.startsWith("playtest phase rex")), "without run-through a later phase gets its card");
});

test("CASES.md: the hockey and duel method lines pass the editor's own checks, and each case walks the eight stages with its sources", () => {
  const doc = fs.readFileSync(path.join(REPO_ROOT, "docs", "design", "CASES.md"), "utf8");
  const blocks = [...doc.matchAll(/```\n([^`]*?)```/g)].map((m) => m[1] as string);
  assert.equal(blocks.length, 2, "one block of method lines per case");
  for (const b of blocks) assert.deepEqual(methodProblems({ rules: b }), [], b.slice(0, 60));
  for (const c of ["## Case A: arcade hockey", "## Case B: a melee duel"]) {
    const next = doc.indexOf("\n## Case", doc.indexOf(c) + 5);
    const part = doc.slice(doc.indexOf(c), next < 0 ? doc.length : next);
    for (const st of ["Stage 1: the fantasy", "Stage 2: pillars", "Stage 3: the core loop", "Stage 4: the 30-second test", "Stage 5: the feel spec", "Stage 6: the teardown", "Stage 7: the greybox", "Stage 8: kill criteria", "What our build did instead", "### Sources"]) assert.ok(part.includes(st), `${c}: ${st}`);
  }
  assert.match(doc, /Stage 6b: thirdjam, our own reference \(N1, 23 Nov\)[^]*112[^]*34 body widths/);
});

test("round 2 (N1's lessons): the designer states the size of the world in the player's units; the playtest card asks for the worst three things, worst first", () => {
  const p = renderDesignerPrompt({ sentence: "ice hockey", concept: sampleConcept() });
  assert.match(p, /5\. \*\*The feel spec\*\*: first, the `WORLD:` line: the size of the world in the player's units[^]*No rule exists only to pass a bot figure[^]*\nWORLD: <body size; the arena in body widths or lengths/);
  assert.match(p, /## 8\. Stage 5: the feel spec, in numbers[^]*\*\*The size of the world comes first, in the player's units\*\*/);
  const card = playtestCard(v2Brief(), "j1", { id: "core", try: "t" }, true).join("\n");
  assert.match(card, /hold --note "<the worst three things you felt, worst first; where it stopped being fun>"/);
});

test("round 2: the keep-the-better compare reads the design's method lines and lets a seen kill line lose; METHOD names N1's central finding", () => {
  const tpl = fs.readFileSync(path.join(REPO_ROOT, "foreman", "prompts", "critic-compare.md"), "utf8");
  assert.match(tpl, /# The design's method lines[^\n]*\n\{\{method\}\}[^]*one of the design's kill lines\nis plainly seen loses/);
  assert.match(fs.readFileSync(path.join(REPO_ROOT, "foreman", "src", "quality.ts"), "utf8"), /method: methodBlock\(h\.s\.brief\) \|\| "\(the design carries no method lines\)"/);
  const doc = fs.readFileSync(METHOD_DOC, "utf8");
  assert.match(doc, /\*\*Our measures cannot see what he sees\*\* \(N1's central finding\)/);
  assert.match(methodText(["14:Director"]), /accepts an experience: a minute of play from the player's camera/);
});

test("round 4: the WORLD line (N1's top finding) is required, names the player's units, reaches the paper check; the tell floor is 20 frames", () => {
  const l = methodLines(v2Brief().rules);
  assert.equal(l.world.length, 1);
  const without = { rules: v2Brief().rules.split("\n").filter((x) => !x.startsWith("WORLD:")).join("\n") };
  assert.match(methodProblems(without).join("\n"), /exactly one "WORLD: <body size/);
  const metres = { rules: v2Brief().rules.replace(/^WORLD: .*$/m, "WORLD: the court is 16 m by 9 m and the ball flies at 12 m/s.") };
  assert.match(methodProblems(metres).join("\n"), /WORLD line names no size in the player's units/);
  assert.match(methodBlock(v2Brief()), /- the world in the player's units: paddles 1\.6 m wide; the court 10 body widths long/);
  const tell = tofuMetricsFor(undefined, 2).find((m) => m.id === "tell_min_f");
  assert.equal(tell?.min, 20, "a person's reliable reaction (CASES.md [B25]); was 12");
  assert.match(fs.readFileSync(path.join(REPO_ROOT, "docs", "GAME-QUALITY.md"), "utf8"), /\| 11 \| Each dangerous opponent action has a tell >= 20 frames/);
});

test("round 5: a house game is a working base, not the bar; each template carries its bar (the reference numbers and the teardown's do-not-copy lines) to the design step, the builders and the critic", async () => {
  const { templateExcerpt, templateOf, houseKeepProblems } = await import("../templates.js");
  const { barContext, houseItem } = await import("../quality.js");
  const sportT = { id: "arcade_sport" as const, reference: "NHL 94", copies: ["possession", "utility AI", "roles"] };
  const duelT = { id: "duel" as const, reference: "For Honor", copies: ["state machine", "mutual", "archetypes"] };
  for (const part of ["design", "builder"] as const) {
    const sport = templateExcerpt(sportT, part);
    assert.match(sport, /a working base on this engine, NOT the quality bar[^]*# The bar: the reference games, not the house game \(docs\/design\/CASES\.md; docs\/research\/hockey-teardown\/TEARDOWN\.md\)[^]*112 body widths[^]*drag 0\.5\/s[^]*ARRIVE at about 8 m\/s[^]*Do NOT copy these from the house game[^]*figures drawn 2\.2x/, part);
    const duel = templateExcerpt(duelT, part);
    assert.match(duel, /# The bar: the reference games[^]*at least 24 frames[^]*Do NOT copy[^]*written over the rival's head/, part);
  }
  assert.equal(templateOf("arcade_sport")?.bar?.dont.length, 10);
  assert.equal(templateOf("duel")?.bar?.dont.length, 10);
  assert.match(barContext(duelT), /^The bar is the reference games, not the house game \(docs\/research\/duel-teardown\/TEARDOWN\.md\)\. What the house game does that a build must NOT copy/);
  assert.equal(barContext(undefined), "");
  assert.match(houseItem("duel").text, /a FLOOR and not the bar[^]*Reaching the house game is not reaching the bar/);
  // The camera keep: hockey -2's low chase camera still fails; thirdjam's camera bound to you, behind and above, passes.
  const tj = "The camera is bound to your skater, behind and above, with an aim anchor. The puck is drawn bigger with a hot rim and a ring under your skater. The puck sticks to the blade on a spring. The carrier is slower (x0.92) and a pass beats skating. The AI scores SHOOT, PASS and CARRY every frame (utility).";
  assert.deepEqual(houseKeepProblems(tj, sportT), []);
  assert.ok(houseKeepProblems("Low chase camera right behind your skater.", sportT).some((p) => /keeps the play camera bound to YOUR skater and raised/.test(p)));
});

test("round 6 (the Director's ruling): a copied move may wind up slower than the house game's, up to the bar (duel light 30, heavy 60), never faster", async () => {
  const { designTemplateProblems } = await import("../templates.js");
  const duelT = { id: "duel" as const, reference: "For Honor", copies: ["state machine", "mutual", "archetypes"] };
  const base = sampleDesign();
  const design = (light: number, heavy = 32): typeof base => ({
    ...base,
    verbs: [
      { id: "slash", input: "LMB", anticipation_f: light, active_f: 4, recovery_f: 16, cancel: "none", move: "light" },
      { id: "cleave", input: "RMB", anticipation_f: heavy, active_f: 5, recovery_f: 28, cancel: "none", move: "heavy" },
      { id: "guard", input: "SPACE", anticipation_f: 4, active_f: 1, recovery_f: 6, cancel: "slash", defensive: true, move: "block" },
    ],
  });
  const lightProblems = (f: number): string => designTemplateProblems(design(f), duelT).filter((p) => p.includes('"slash"')).join(" | ");
  assert.equal(lightProblems(18), "", "the house game's light (18)");
  assert.equal(lightProblems(26), "", "slower, inside For Honor's 24-30");
  assert.match(lightProblems(31), /anticipation_f 31 \(the table: 18 to 30: at least the house game's, at most the bar's\)/);
  assert.match(lightProblems(16), /anticipation_f 16 \(the table: 18 to 30/);
  const heavy = (f: number): string => designTemplateProblems(design(18, f), duelT).filter((p) => p.includes('"cleave"')).join(" | ");
  assert.equal(heavy(60), "");
  assert.match(heavy(61), /anticipation_f 61 \(the table: 32 to 60/);
  // A move with no bar maximum is still copied exactly: the block's 4-frame raise.
  const blockSlow = { ...design(18), verbs: design(18).verbs.map((v) => (v.move === "block" ? { ...v, anticipation_f: 8 } : v)) };
  assert.match(designTemplateProblems(blockSlow, duelT).join(" | "), /"guard" copies the duel move "block" but changes its frames: anticipation_f 8 \(the table: 4\)/);
});
