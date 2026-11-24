// N4 of 22 Nov (GAME-QUALITY.md v2): the design copies a proven genre template (the template choice, the move frames,
// the research excerpts by genre), the tofu stage holds a core verb its bot does not prove fun, the critic always says
// which [H] items it cannot judge, and `foreman quality <job> retry` records and prints the resume command instead of
// running the job in the foreground.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, foremanFor, readEvents, sampleConcept, sampleDesign, scriptWith, tempJob, v2Brief, type TempJob } from "./helpers.js";
import { FakeBuilder, type FakeStep } from "../builder/fake.js";
import { designRoom } from "../room.js";
import { critic, planCheck, planPackages, renderPlannerPrompt } from "../designer.js";
import type { Brief, Concept, DesignDoc, JobEvent, PackageSpec, Phase } from "../events.js";
import { rebuildState } from "../joblog.js";
import { statusTable } from "../status.js";
import { builderFeelSection, checklistRows, criticChecklistText, hItems, H_LINE, withHLine } from "../roomtext.js";
import { conceptTemplateProblems, designTemplateProblems, templateExcerpt, templateForSentence } from "../templates.js";
import { judgeTofu, tofuLine, tofuMetricsFor, tofuPlanProblems, TOFU_METRICS } from "../tofu.js";
import { main } from "../cli.js";
import { FAKE_VERBS_FILE } from "../verbs.js";
import { toPosix } from "../paths.js";

after(cleanup);

const estimate = { packages: 6, wallMinutes: 60, tokens: 900000 };
const ofType = <T extends JobEvent["type"]>(evs: JobEvent[], t: T): Extract<JobEvent, { type: T }>[] => evs.filter((e): e is Extract<JobEvent, { type: T }> => e.type === t);

const duelTemplate = { id: "duel" as const, reference: "Dark Souls, Sekiro and For Honor (DUEL-PLAYBOOK)", copies: ["the 6.4 state machine with its 8-frame input buffer", "the mutual reactions of 6.3: every contact changes both fighters", "three archetypes: the Wall absorbs, the Duelist parries, the Dancer avoids"] };
const duelConcept = (): Concept => ({ ...sampleConcept(), template: duelTemplate, hook: "the crowd throws you the weapon it wants to see", anchor: "souls-like duel" });
/** A duel design that copies the table: light 18/4/16, heavy 32/5/28, roll 3/18/15, block 4/held/6. */
const duelDesign = (): DesignDoc => ({
  ...sampleDesign(),
  verbs: [
    { id: "slash", move: "light", input: "attack (J): a gladius cut", anticipation_f: 18, active_f: 4, recovery_f: 16, cancel: "chains into a second light at 12 f" },
    { id: "cleave", move: "heavy", input: "heavy (K): blocked, the attacker recoils -22", anticipation_f: 32, active_f: 5, recovery_f: 28, cancel: "feint until frame 20" },
    { id: "roll", move: "roll", input: "roll (space)", anticipation_f: 3, active_f: 18, recovery_f: 15, cancel: "none", defensive: true },
    { id: "guard", move: "block", input: "guard (L held)", anticipation_f: 4, active_f: 0, recovery_f: 6, cancel: "a tap is a parry", defensive: true },
  ],
});

/** The paddle fixture's brief as a duel: the duel design, and the house game's lock-on and shoulder camera said. */
const duelBrief = (): Brief => ({ ...v2Brief(), design: duelDesign(), rules: `${v2Brief().rules} Lock-on: each fighter always faces his rival.`, arena: `${v2Brief().arena} The camera looks over the shoulder, between the fighters.` });

// ---------------------------------------------------------------- the template choice

test("template: a fight copies the duel; its copies name the state machine, the mutual reactions and the archetypes; an `own` reference passes for another genre", () => {
  assert.equal(templateForSentence("a fight in a colosseum")?.id, "duel");
  assert.equal(templateForSentence("ice hockey three against three")?.id, "rink_sport"); // E3 of 24 Nov: hockey is on the rink core
  assert.equal(templateForSentence("football, five a side")?.id, "arcade_sport");
  assert.equal(templateForSentence("a race with ducks"), undefined);
  assert.deepEqual(conceptTemplateProblems(duelConcept(), "a fight in a colosseum"), []);
  // An invented core for a fight is sent back, naming the duel template.
  assert.match(conceptTemplateProblems(sampleConcept(), "a fight in a colosseum").join(" "), /the template is "duel" \(Dark Souls \/ Sekiro \/ For Honor[^]*put the novelty in the hook/);
  // A duel whose copies are moods names what is missing.
  const vague = { ...duelConcept(), template: { ...duelTemplate, copies: ["the feel of Dark Souls", "tense", "weighty swords"] } };
  const p = conceptTemplateProblems(vague, "a fight in a colosseum").join(" | ");
  assert.match(p, /must name the state machine/);
  assert.match(p, /must name the mutual reactions/);
  assert.match(p, /must name the three rival archetypes/);
  // No template at all is a problem; `own` for a paddle game is fine.
  const { template: _drop, ...none } = sampleConcept();
  assert.match(conceptTemplateProblems(none, "a paddle game").join(""), /the concept needs `template`/);
  assert.deepEqual(conceptTemplateProblems(sampleConcept(), "a ball-and-paddle game in a walled court"), []);
});

test("template: a verb that copies a move carries the table's frames exactly; a duel copies at least three moves, an attack and a defence", () => {
  assert.deepEqual(designTemplateProblems(duelDesign(), duelTemplate), []);
  const para = { ...duelDesign(), verbs: duelDesign().verbs.map((v) => (v.move === "light" ? { ...v, anticipation_f: 6, recovery_f: 12 } : v)) };
  assert.match(designTemplateProblems(para, duelTemplate).join(""), /verb "slash" copies the duel move "light" but changes its frames: anticipation_f 6 \(the table: 18 to 30: at least the house game's, at most the bar's\), recovery_f 12 \(the table: 16\)\. Copy the table, not a paraphrase/);
  const unmove = (v: DesignDoc["verbs"][number]): DesignDoc["verbs"][number] => { const { move: _m, ...rest } = v; return rest; };
  const few = { ...duelDesign(), verbs: duelDesign().verbs.map((v) => (v.move === "light" || v.move === "heavy" ? unmove(v) : v)) };
  const pf = designTemplateProblems(few, duelTemplate).join(" | ");
  assert.match(pf, /at least 3 verbs copy a move[^|]*2 do/);
  assert.match(pf, /one verb copies an attack move \(light, heavy, charged, bash\)/);
  assert.match(designTemplateProblems({ ...duelDesign(), verbs: [...duelDesign().verbs.slice(0, 3), { ...(duelDesign().verbs[3] as DesignDoc["verbs"][number]), move: "uppercut" }] }, duelTemplate).join(""), /move "uppercut", which is not in the duel move table/);
  // A defence move must be marked defensive.
  const undef = { ...duelDesign(), verbs: duelDesign().verbs.map((v) => { if (v.move !== "roll") return v; const { defensive: _d, ...rest } = v; return rest; }) };
  assert.match(designTemplateProblems(undef, duelTemplate).join(""), /verb "roll" copies the defence move "roll": mark it "defensive": true/);
  // `own` has no table to check.
  assert.deepEqual(designTemplateProblems(sampleDesign(), sampleConcept().template), []);
});

test("template: the room on 'a fight in a colosseum' sends an invented core and paraphrased frames back; the design step and the review read DUEL-PLAYBOOK, not the hockey research", async () => {
  const paraphrased = { ...duelBrief(), design: { ...duelDesign(), verbs: duelDesign().verbs.map((v) => (v.move === "heavy" ? { ...v, anticipation_f: 10 } : v)) } };
  const steps: FakeStep[] = [
    { match: { role: "concept", attempt: 1 }, json: { concept: { ...sampleConcept(), hook: "a stone-slam brawler" } } },
    { match: { role: "concept", attempt: 2 }, json: { concept: duelConcept() } },
    { match: { role: "designer", attempt: 1 }, json: { brief: paraphrased, estimate } },
    { match: { role: "designer", attempt: 2 }, json: { brief: duelBrief(), estimate } },
    { match: { role: "design_review" }, json: { scores: { hook: 0.8, gif: 0.8, depth: 0.8, feel: 0.8, fit: 0.8 }, slop: [], verdict: "ok", notes: "Copies the duel; sell the crowd's weapon." } },
  ];
  const b = new FakeBuilder({ steps });
  const r = await designRoom(b, { sentence: "a fight in a colosseum" });
  assert.ok(r.ok, r.ok ? "" : r.reason);
  assert.deepEqual(b.calls.map((c) => c.req.meta?.role), ["concept", "concept", "designer", "designer", "design_review"]);
  assert.equal(r.value.brief.concept?.template?.id, "duel");
  assert.deepEqual(r.value.brief.design?.verbs.map((v) => [v.move, v.anticipation_f, v.active_f, v.recovery_f]), [["light", 18, 4, 16], ["heavy", 32, 5, 28], ["roll", 3, 18, 15], ["block", 4, 0, 6]]);
  // The concept prompt carries the template menu and v2's principles; attempt 2 is told why attempt 1 failed.
  // D3 of 22 Nov: the move line names the move id and the clip apart (the first hockey job's concept read "poke 5/7/12
  // (`cross_check`)" as "move cross_check" and its design step failed three times on it).
  assert.match(b.calls[0]?.req.prompt ?? "", /# The genre templates[^]*`duel`: a melee duel[^]*move "light" 18\/4\/16 \(its clip `strike`, not a move id\)[^]*`arcade_sport`[^]*move "poke" 5\/7\/12 \(its clip `cross_check`, not a move id\)[^]*`own`[^]*## 8\. What made games last/);
  assert.match(b.calls[1]?.req.prompt ?? "", /the template is "duel"/);
  // The design step reads the duel research (the contact table and the state machine), never the hockey one.
  const design = b.calls[2]?.req.prompt ?? "";
  assert.match(design, /# The genre template: duel[^]*### 6\.3 Contact results[^]*### 6\.4 State machine[^]*### 6\.7 Three rivals/);
  assert.doesNotMatch(design, /Puck carry/);
  assert.match(design, /## 10\. The plays-twice checklist/);
  assert.match(b.calls[3]?.req.prompt ?? "", /changes its frames: anticipation_f 10 \(the table: 32 to 60/);
  assert.match(b.calls[4]?.req.prompt ?? "", /# The genre template the concept copies[^]*### 6\.2 Moves/);
  // An `own` concept reads no research excerpt.
  assert.equal(templateExcerpt(sampleConcept().template, "design"), "");
});

test("template: the Planner reads the duel excerpt and the tofu block; builders read the implementable spec of their genre only", () => {
  const brief: Brief = { ...v2Brief(), concept: duelConcept(), design: duelDesign() };
  const plan = renderPlannerPrompt({ sentence: "a fight in a colosseum", packId: "game.x", title: "X", brief, packContract: "(c)" }, { verbs: JSON.parse(fs.readFileSync(FAKE_VERBS_FILE, "utf8")) });
  assert.match(plan, /- genre template: duel, copied from Dark Souls[^]*copies the template move heavy/);
  assert.match(plan, /# The genre template: duel[^]*### 6\.5 Interaction matrix/);
  assert.match(plan, /# The tofu stage[^]*TOFU CHECK: tests\/bot_tofu\.gd reports metrics feedback_f, skill_spread, skill_variants, idle_max_f, tell_min_f, tells, pressure_waves, lead_change_share, close_rounds, verbs_used, contact_types, one_sided_contacts/);
  assert.match(plan, /`feedback_f` <= 3 \(checklist item 1 feedback within 3 f\)/);
  assert.match(plan, /`card\.duel`\)\. When that card is in the list,\s+it is the default/);
  const feel = builderFeelSection(duelTemplate);
  assert.match(feel, /Every contact changes BOTH bodies[^]*# The genre template: duel \(a melee duel\), from docs\/research\/DUEL-PLAYBOOK\.md[^]*## 2\. Mutual reaction[^]*### 6\.3 Contact results/);
  assert.doesNotMatch(feel, /## 1\. The proven models/);
  assert.match(builderFeelSection({ id: "arcade_sport", reference: "NHL 94", copies: ["possession", "utility", "roles"] }), /### 5\.1 Puck carry/);
  assert.doesNotMatch(builderFeelSection(sampleConcept().template), /# The genre template/);
});

// ---------------------------------------------------------------- the tofu stage

const goodMetrics = { feedback_f: 2, skill_spread: 0.4, skill_variants: 3, idle_max_f: 60, tell_min_f: 24, tells: 6, pressure_waves: 3, lead_change_share: 0.5, close_rounds: 2, verbs_used: 2, hand: "regular" };
const badMetrics = { feedback_f: 7, skill_spread: 0.1, skill_variants: 3, idle_max_f: 300, tell_min_f: 8, tells: 6, lead_change_share: 0, close_rounds: 2, hand: "regular" };

test("tofu: the metrics judge checklist items 1, 3, 9, 11, 12 and 15; an absent metric is not measured, and not measured fails; the duel adds its contact rows", () => {
  assert.deepEqual(TOFU_METRICS.map((m) => m.item.split(" ")[0]), ["1", "3", "3", "9", "11", "11", "12", "15", "15", "the"]);
  const rows = tofuMetricsFor(undefined);
  const ok = judgeTofu(goodMetrics, rows, "tests/bot_tofu.gd", "regular", "reports/x.json");
  assert.equal(ok.ok, true);
  assert.match(ok.line, /^tofu stage ok \(tests\/bot_tofu\.gd through the regular hand\): feedback_f 2, skill_spread 0\.4/);
  const bad = judgeTofu(badMetrics, rows, "tests/bot_tofu.gd", "regular", "reports/x.json");
  assert.equal(bad.ok, false);
  assert.match(bad.line, /^TOFU STAGE NOT ok[^]*feedback_f 7 \(wants <= 3; item 1 feedback within 3 f\)[^]*idle_max_f 300 \(wants <= 120[^]*tell_min_f 8 \(wants >= 20[^]*pressure_waves not reported \(wants >= 2/);
  assert.match(judgeTofu(undefined, rows, "tests/bot_tofu.gd", undefined, "reports/x.json").line, /reported no `metrics` object/);
  assert.match(judgeTofu(undefined, rows, "tests/bot_tofu.gd").line, /no finished report of tests\/bot_tofu\.gd was found/);
  const duelRows = tofuMetricsFor(duelTemplate);
  assert.deepEqual(duelRows.slice(-2).map((m) => m.id), ["contact_types", "one_sided_contacts"]);
  assert.equal(judgeTofu(goodMetrics, duelRows, "t").ok, false, "a duel bot must report its contacts");
  assert.equal(judgeTofu({ ...goodMetrics, contact_types: 4, one_sided_contacts: 0 }, duelRows, "t").ok, true);
  assert.equal(judgeTofu({ ...goodMetrics, contact_types: 4, one_sided_contacts: 1 }, duelRows, "t").ok, false);
});

/** The paddle fixture's plan with the tofu line on core and core running its bot (all blockout: the tofu milestone). */
function tofuPlan(packages: PackageSpec[]): PackageSpec[] {
  return packages.map((p) => (p.id === "core" ? { ...p, contract: `${p.contract}\n${tofuLine(undefined, "tests/bot_rally.gd")}`, acceptance: [...p.acceptance, { level: "V4", verb: "bot", args: ["--test=tests/bot_rally.gd", "--frames=1200"] }] } : p));
}

test("tofu: a fresh plan of a design-room brief must carry the TOFU CHECK line in its root; the tofu phase is exactly the blockout milestone", async () => {
  const job = tempJob("tofu-plan");
  const plan = readEvents(job.jobDir).find((e) => e.type === "plan_set");
  const packages = (plan?.type === "plan_set" ? plan.packages : []).map((p) => ({ ...p, milestone: p.id === "paddle_ai" ? ("greybox" as const) : ("blockout" as const) }));
  const phases: Phase[] = [{ id: "tofu", title: "Tofu", try: "Slap the ball past Rex on flat shapes", packages: ["core", "court"] }, { id: "rival", title: "Rex", try: "Beat Rex", packages: ["paddle_ai"] }];
  assert.match(tofuPlanProblems(packages, phases, true, undefined).join(""), /add this line to the contract of the root package "core", word for word: "TOFU CHECK: tests\/bot_tofu\.gd reports metrics feedback_f/);
  assert.deepEqual(tofuPlanProblems(packages, phases, false, undefined), [], "not required, no line: nothing to check");
  assert.deepEqual(tofuPlanProblems(tofuPlan(packages), phases, true, undefined), []);
  // A later package in blockout, a tofu package outside the first phase, a line without its metrics.
  const moved = tofuPlan(packages).map((p) => (p.id === "paddle_ai" ? { ...p, milestone: "blockout" as const } : p));
  assert.match(tofuPlanProblems(moved, phases, true, undefined).join(""), /package "paddle_ai" is milestone "blockout" but not in the tofu phase "tofu"/);
  const short = tofuPlan(packages).map((p) => (p.id === "core" ? { ...p, contract: p.contract.replace(/, pressure_waves.*$/m, "") } : p));
  assert.match(tofuPlanProblems(short, phases, true, undefined).join(""), /must name every metric \(missing: pressure_waves, lead_change_share, close_rounds, verbs_used\)/);
  const grey = tofuPlan(packages).map((p) => (p.id === "core" ? { ...p, milestone: "greybox" as const } : p));
  assert.match(tofuPlanProblems(grey, phases, true, undefined).join(""), /the tofu package "core" is milestone "greybox"; the tofu stage is flat shapes: milestone "blockout"/);
  // planCheck carries it: required for a fresh plan of a design brief.
  const verbs = JSON.parse(fs.readFileSync(FAKE_VERBS_FILE, "utf8"));
  assert.match(planCheck(packages, { verbs, requireTofu: true, requirePhases: true }, undefined, phases).join(""), /the first phase is the tofu stage/);
  // A fresh Planner answer needs it only for a brief whose concept names a template (a room brief of 22 Nov on).
  const answer = { packages, phases };
  const old = await planPackages(new FakeBuilder({ steps: [{ match: { role: "planner" }, json: answer }] }), { sentence: "s", packId: "game.paddle_court", title: "P", brief: v2Brief(), packContract: "(c)" }, { verbs });
  assert.ok(old.ok, old.ok ? "" : old.reason);
  const v3 = await planPackages(new FakeBuilder({ steps: [{ match: { role: "planner" }, json: answer }] }), { sentence: "s", packId: "game.paddle_court", title: "P", brief: { ...v2Brief(), concept: sampleConcept() }, packContract: "(c)" }, { verbs, });
  assert.equal(v3.ok, false);
  assert.match(v3.ok ? "" : v3.reason, /the first phase is the tofu stage/);
});

/** The design job of quality.test.ts (all blockout), with the tofu line, and the core builder's bot reporting `metrics`. */
function tofuJob(label: string): TempJob {
  const job = tempJob(label);
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  const brief = JSON.parse(lines[1] as string) as { brief: Brief };
  brief.brief = { ...v2Brief(), concept: sampleConcept() };
  lines[1] = JSON.stringify(brief);
  const plan = JSON.parse(lines[3] as string) as { packages: PackageSpec[] };
  plan.packages = tofuPlan(plan.packages.map((p) => ({ ...p, milestone: "blockout" as const })));
  lines[3] = JSON.stringify(plan);
  fs.writeFileSync(file, lines.map((l) => l + "\n").join(""));
  return job;
}
/** The fixture's core step, its bot reporting these metrics, for round `round` (all rounds when absent). */
function coreWith(metrics: object, round?: number): FakeStep {
  const base = scriptWith().steps.find((s) => s.match?.package === "core") as FakeStep;
  // The fixture's bot reports passing metrics; this one replaces them.
  const bot = ((base.write ?? {})["tests/bot_rally.gd"] as string).replace(/# FAKE_METRICS\(.*\)\n/, "") + `\n# FAKE_METRICS(${JSON.stringify(metrics)})\n`;
  return { ...base, match: { role: "builder", package: "core", ...(round !== undefined ? { round } : {}) }, write: { ...(base.write ?? {}), "tests/bot_rally.gd": bot } };
}

test("tofu: a core whose bot misses the metrics is sent back to the root with the failed rows; fixed in round 1 it passes and the job goes on (no critic needed)", async () => {
  const job = tofuJob("tofu-pass");
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", script: scriptWith([coreWith(badMetrics, 1), coreWith(goodMetrics)]) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  const reopen = ofType(evs, "reopened").find((e) => e.package === "core");
  assert.ok(reopen, "the root was sent back");
  const p2 = builder.calls.filter((c) => c.req.meta?.package === "core").at(-1)?.req.prompt ?? "";
  assert.match(p2, /revise round 1 of 2 \(milestone blockout\)[^\n]*TOFU STAGE NOT ok \(tests\/bot_rally\.gd through the regular hand\)[^\n]*feedback_f 7 \(wants <= 3/);
  const ms = ofType(evs, "milestone");
  assert.deepEqual(ms.map((m) => [m.milestone, m.round]), [["blockout", 1]]);
  assert.match(ms[0]?.summary ?? "", /tofu stage ok \(tests\/bot_rally\.gd through the regular hand\): feedback_f 2/);
  const tofuReports = fs.readdirSync(path.join(job.jobDir, "reports")).filter((f) => f.startsWith("tofu-blockout"));
  assert.equal(tofuReports.length, 2, "one tofu report per look");
});

test("tofu: still failing after round 2 holds the job exactly like the quality loop; status names it; nothing later starts", async () => {
  const job = tofuJob("tofu-hold");
  const opts = { promoteTo: "job" as const, script: scriptWith([coreWith(badMetrics)]) };
  const s = await foremanFor(job, opts).foreman.run();
  assert.deepEqual(s.jobState, { state: "paused", reason: "quality" });
  assert.deepEqual(s.qualityHeld && [s.qualityHeld.milestone, s.qualityHeld.round], ["blockout", 2]);
  assert.equal(s.promoted, undefined);
  const table = statusTable(rebuildState(job.jobDir));
  assert.match(table, /HELD     quality: milestone blockout is still NOT ok after revise round 2/);
  assert.match(table, /critic   tofu 0; TOFU STAGE NOT ok/);
  const ms = ofType(readEvents(job.jobDir), "milestone");
  assert.match(ms.at(-1)?.summary ?? "", /tofu stage NOT ok: tofu 0; TOFU STAGE NOT ok/);
  // With the critic on, its verdict joins: a passing critic does not pass a failing tofu stage.
  const both = tofuJob("tofu-hold-critic");
  const ok = { match: { role: "critic" }, json: { ok: true, scores: { silhouette: 0.8, readability: 0.8, style_consistency: 0.8, shows_play: 0.8, fun_promise: 0.8, kill_criteria: 0.9 }, notes: ["a clean rally"] } };
  const s2 = await foremanFor(both, { ...opts, critic: true, script: scriptWith([ok, coreWith(badMetrics)]) }).foreman.run();
  assert.deepEqual(s2.jobState, { state: "paused", reason: "quality" });
  const tofuFile = fs.readdirSync(path.join(both.jobDir, "reports")).filter((f) => f.startsWith("tofu-blockout")).at(-1) as string;
  const merged = JSON.parse(fs.readFileSync(path.join(both.jobDir, "reports", tofuFile), "utf8")) as { notes: string[]; by: string; critic: string; package: string };
  assert.deepEqual([merged.by, merged.package, merged.notes.at(-2)], ["critic (V5) and tofu stage", "core", "a clean rally"]);
  assert.match(merged.critic, /^reports\/critic-blockout-s\d+\.json$/);
  assert.match(ofType(readEvents(both.jobDir), "milestone").at(-1)?.summary ?? "", /critic \(V5\) and tofu stage NOT ok: silhouette 0\.8[^]*tofu 0; TOFU STAGE NOT ok/);
});

// ---------------------------------------------------------------- the retry fix

test("quality retry: records the owner's answer and prints the resume command with the options given; it never runs the job", async () => {
  const job = tofuJob("tofu-retry");
  await foremanFor(job, { promoteTo: "job", script: scriptWith([coreWith(badMetrics)]) }).foreman.run();
  const before = readEvents(job.jobDir).length;
  const out: string[] = [];
  const code = await main(["quality", job.jobDir, "retry", "--note", "make the rival press sooner", "--adapter", "claude-cli", "--model", "opus", "--engine", "C:/tl engine"], (x) => out.push(x));
  assert.equal(code, 0);
  const evs = readEvents(job.jobDir);
  assert.equal(evs.length, before + 1, "one event: the answer; no builder ran, no job_state running");
  const last = evs.at(-1);
  assert.equal(last?.type, "comment");
  assert.equal(last?.type === "comment" ? last.text : "", "quality retry: make the rival press sooner");
  assert.match(out.join("\n"), /quality retry on milestone blockout \(note: make the rival press sooner\)/);
  const resume = out.find((l) => l.startsWith("recorded; the job is not started. continue with: ")) ?? "";
  assert.equal(resume, `recorded; the job is not started. continue with: foreman resume ${toPosix(job.jobDir)} --adapter claude-cli --model opus --engine "C:/tl engine"`);
  // The resume path then runs the retry round (round 3) and holds again.
  const s = await foremanFor(job, { promoteTo: "job", script: scriptWith([coreWith(badMetrics)]) }).foreman.run();
  assert.equal(s.qualityHeld?.round, 3);
});

// ---------------------------------------------------------------- the critic's [H] line

test("critic: the checklist block names the [C] items frames show and the [H] items no capture passes; every answer ends with the [H] line", async () => {
  assert.equal(checklistRows().length, 30);
  assert.deepEqual(hItems(), [2, 4, 13, 21, 26, 28, 30]);
  const text = criticChecklistText();
  assert.match(text, /\[C\]: a capture can show them[^]*- 24\. Juice on every hit[^]*\[H\]: only a person playing can[^]*- 30\. Voluntary replay/);
  assert.deepEqual(withHLine(["a", "[H] items not judged: whatever"]), ["a", `${H_LINE} (items 2, 4, 13, 21, 26, 28, 30)`]);
  const img = path.join(tempJob("critic-h").root, "shot.png");
  fs.writeFileSync(img, Buffer.from("89504e470d0a1a0a", "hex"));
  const b = new FakeBuilder({ steps: [{ match: { role: "critic" }, json: { ok: true, scores: { silhouette: 0.8, readability: 0.8, style_consistency: 0.8, shows_play: 0.8 }, notes: ["two fighters trade blows"] } }] });
  const r = await critic(b, [img]);
  assert.ok(r.ok);
  assert.equal(r.value.notes.at(-1), `${H_LINE} (items 2, 4, 13, 21, 26, 28, 30)`);
  assert.match(b.calls[0]?.req.prompt ?? "", /# The plays-twice checklist[^]*The last note is: \[H\] items not judged: a person must play it/);
});
