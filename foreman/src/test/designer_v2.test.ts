// JOB.md "Added 2026-11-20": the designer v2 wire, one test (at least) per new event and per new command, plus the
// Designer's and the Planner's checks, the critic's fun_promise item and the cards' fun block (CARDS.md).
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { validateEvent, EventError, type Brief } from "../events.js";
import { foldEvents, LogError } from "../joblog.js";
import { designBrief, planCheck, planPackages, renderDesignerPrompt, renderPlannerPrompt, DEFAULT_RUBRIC } from "../designer.js";
import { criticRubric, replanPhases } from "../phases.js";
import { designerCardsText, designerEngineText } from "../designctx.js";
import { FakeBuilder } from "../builder/fake.js";
import { main, UsageError } from "../cli.js";
import { cleanup, tempDir, readEvents, fixturePhases, fixturePlan, v2Brief, roomSteps, VERBS, FIXTURE } from "./helpers.js";
import { PKG_ROOT, REPO_ROOT } from "../paths.js";
import type { JobEvent } from "../events.js";

after(cleanup);

const base = { v: 1, ts: "2026-11-21T01:00:00.000Z", job: "j-20261121-1" };
const ev = (seq: number, body: object): JobEvent => validateEvent({ ...base, seq, ...body });
const created = (extra: object = {}): object => ({ type: "job_created", sentence: "a fight in a colosseum", packId: "game.fight", title: "Fight", ...extra });
const estimate = { packages: 4, wallMinutes: 30, tokens: 200000 };
const run = async (argv: string[]): Promise<{ code: number; text: string }> => {
  const lines: string[] = [];
  const code = await main(argv, (s) => lines.push(s));
  return { code, text: lines.join("\n") };
};
const fold = (bodies: object[]): ReturnType<typeof foldEvents> => foldEvents("j", bodies.map((b, i) => ev(i + 1, b)));

// ---------------------------------------------------------------- events

test("v2 event job_created: creativity is only \"crazy\" and run_through only true; both optional, never null", () => {
  assert.doesNotThrow(() => ev(1, created()));
  assert.doesNotThrow(() => ev(1, created({ creativity: "crazy", run_through: true })));
  assert.throws(() => ev(1, created({ creativity: "standard" })), EventError, "standard is the absent key");
  assert.throws(() => ev(1, created({ creativity: "wild" })), EventError);
  assert.throws(() => ev(1, created({ run_through: false })), EventError, "absent, never false");
  assert.throws(() => ev(1, created({ creativity: null })), EventError);
  const s = fold([created({ creativity: "crazy", run_through: true })]);
  assert.equal(s.creativity, "crazy");
  assert.equal(s.runThrough, true);
});

test("v2 event brief_set: pitch and aspects are optional on read; their word limits, ids and icons are enforced", () => {
  const b = v2Brief(true);
  assert.doesNotThrow(() => ev(2, { type: "brief_set", brief: b, estimate }));
  const v1 = { rules: "r", arena: "a", ai: "i", controls: "c", mood: "m" };
  assert.doesNotThrow(() => ev(2, { type: "brief_set", brief: v1, estimate }), "a v1 brief still reads");
  const clone = (): Brief => JSON.parse(JSON.stringify(b)) as Brief;
  const long = clone();
  long.pitch = Array.from({ length: 21 }, (_, i) => `w${i}`).join(" ");
  assert.throws(() => ev(2, { type: "brief_set", brief: long, estimate }), /pitch has 21 words; at most 20/);
  const title = clone();
  (title.aspects ?? [])[0]!.title = "one two three four five";
  assert.throws(() => ev(2, { type: "brief_set", brief: title, estimate }), /title has 5 words; at most 4/);
  const detail = clone();
  (detail.aspects ?? [])[0]!.detail = Array.from({ length: 61 }, () => "x").join(" ");
  assert.throws(() => ev(2, { type: "brief_set", brief: detail, estimate }), /detail has 61 words; at most 60/);
  const dupe = clone();
  (dupe.aspects ?? [])[1]!.id = "paddle";
  assert.throws(() => ev(2, { type: "brief_set", brief: dupe, estimate }), /the id is used twice in the brief/);
  const keep = clone();
  (keep.aspects ?? [])[0]!.alternatives[0]!.id = "keep";
  assert.throws(() => ev(2, { type: "brief_set", brief: keep, estimate }), /"keep" and "drop" are the player's fixed choices/);
  const icon = clone() as unknown as { aspects: { icon: string }[] };
  icon.aspects[0]!.icon = "sword";
  assert.throws(() => ev(2, { type: "brief_set", brief: icon, estimate }), EventError);
  const crazyFalse = clone() as unknown as { aspects: { crazy?: boolean }[] };
  crazyFalse.aspects[0]!.crazy = false;
  assert.throws(() => ev(2, { type: "brief_set", brief: crazyFalse, estimate }), EventError, "crazy is true or absent");
  const two = clone();
  two.aspects = (two.aspects ?? []).slice(0, 2);
  assert.throws(() => ev(2, { type: "brief_set", brief: two, estimate }), EventError, "3 to 7 aspects");
  const oneAlt = clone();
  (oneAlt.aspects ?? [])[0]!.alternatives = (oneAlt.aspects ?? [])[0]!.alternatives.slice(0, 1);
  assert.throws(() => ev(2, { type: "brief_set", brief: oneAlt, estimate }), EventError, "2 or 3 alternatives");
});

test("v2 event aspect_reacted: names an aspect of the latest brief and a choice it offers; the latest counts; a new brief clears them; none after approval", () => {
  const head = [created(), { type: "brief_set", brief: v2Brief(), estimate }];
  const s = fold([...head, { type: "aspect_reacted", aspect: "rival", choice: "twin_rivals" }, { type: "aspect_reacted", aspect: "rival", choice: "drop", note: "no rival, just me" }, { type: "aspect_reacted", aspect: "court", choice: "keep" }]);
  assert.deepEqual(s.reactions["rival"], { choice: "drop", note: "no rival, just me", seq: 4 });
  assert.equal(s.reactions["court"]?.choice, "keep");
  assert.throws(() => fold([...head, { type: "aspect_reacted", aspect: "ghost", choice: "keep" }]), (e: unknown) => e instanceof LogError && /names aspect "ghost"/.test(e.message));
  assert.throws(() => fold([...head, { type: "aspect_reacted", aspect: "rival", choice: "ice_court" }]), (e: unknown) => e instanceof LogError && /choice "ice_court" is not one of aspect "rival"/.test(e.message));
  assert.throws(() => fold([...head, { type: "brief_approved", by: "player" }, { type: "aspect_reacted", aspect: "rival", choice: "keep" }]), /after brief_approved/);
  assert.throws(() => ev(3, { type: "aspect_reacted", aspect: "rival", choice: "keep", note: "" }), EventError, "a note is never empty");
  const again = fold([...head, { type: "aspect_reacted", aspect: "rival", choice: "keep" }, { type: "brief_set", brief: v2Brief(), estimate }]);
  assert.deepEqual(again.reactions, {});
  assert.equal(again.briefs, 2);
});

test("v2 event plan_set.phases: 2 to 5, every package in exactly one, deps in the same phase or earlier, try at most 12 words", () => {
  const plan = fixturePlan();
  assert.doesNotThrow(() => ev(4, { type: "plan_set", packages: plan, phases: fixturePhases() }));
  assert.doesNotThrow(() => ev(4, { type: "plan_set", packages: plan }), "without phases: one phase, as before");
  const p = fixturePhases();
  assert.throws(() => ev(4, { type: "plan_set", packages: plan, phases: [p[0]] }), EventError, "one phase is not a phase list");
  assert.throws(() => ev(4, { type: "plan_set", packages: plan, phases: [{ ...p[0], packages: ["core"] }, p[1]] }), /package "court" is in no phase/);
  assert.throws(() => ev(4, { type: "plan_set", packages: plan, phases: [p[0], { ...p[1], packages: ["paddle_ai", "court"] }] }), /is in phase "court_plays" and in phase "rival"/);
  assert.throws(() => ev(4, { type: "plan_set", packages: plan, phases: [{ ...p[0], packages: ["court"] }, { ...p[1], packages: ["paddle_ai", "core"] }] }), /depends on "core", which is in the later phase "rival"/);
  assert.throws(() => ev(4, { type: "plan_set", packages: plan, phases: [{ ...p[0], try: "one two three four five six seven eight nine ten eleven twelve thirteen" }, p[1]] }), /try has 13 words; at most 12/);
  assert.throws(() => ev(4, { type: "plan_set", packages: plan, phases: [p[0], { ...p[1], packages: ["paddle_ai", "ghost"] }] }), /names package "ghost", which is not in the plan/);
  const s = fold([created(), { type: "plan_set", packages: plan, phases: fixturePhases() }]);
  assert.deepEqual(s.phases.map((x) => [x.id, x.state]), [["court_plays", "open"], ["rival", "open"]]);
});

test("v2 event phase_done: names a phase of the latest plan; the phase waits for a verdict", () => {
  const head = [created(), { type: "plan_set", packages: fixturePlan(), phases: fixturePhases() }];
  const s = fold([...head, { type: "phase_done", phase: "court_plays" }]);
  assert.equal(s.phases[0]?.state, "done");
  assert.equal(s.phases[0]?.doneCount, 1);
  assert.throws(() => fold([...head, { type: "phase_done", phase: "nope" }]), (e: unknown) => e instanceof LogError && /names phase "nope"/.test(e.message));
  assert.throws(() => ev(3, { type: "phase_done", phase: "court_plays", extra: 1 }), /unknown key "extra"/);
});

test("v2 event phase_reviewed: pass or hold (a hold needs its note), only on a done phase; by player or auto", () => {
  const head = [created(), { type: "plan_set", packages: fixturePlan(), phases: fixturePhases() }, { type: "phase_done", phase: "court_plays" }];
  assert.throws(() => ev(4, { type: "phase_reviewed", phase: "court_plays", verdict: "hold", by: "player" }), /a "hold" needs a "note"/);
  assert.throws(() => ev(4, { type: "phase_reviewed", phase: "court_plays", verdict: "maybe", by: "player" }), EventError);
  assert.throws(() => ev(4, { type: "phase_reviewed", phase: "court_plays", verdict: "pass", by: "bot" }), EventError);
  const held = fold([...head, { type: "phase_reviewed", phase: "court_plays", verdict: "hold", note: "smaller court", by: "player" }]);
  assert.equal(held.phases[0]?.state, "held");
  assert.deepEqual(held.phases[0]?.hold, { seq: 4, note: "smaller court", applied: false });
  const passed = fold([...head, { type: "phase_reviewed", phase: "court_plays", verdict: "pass", by: "auto" }]);
  assert.equal(passed.phases[0]?.state, "passed");
  assert.throws(() => fold([...head, { type: "phase_reviewed", phase: "rival", verdict: "pass", by: "player" }]), /phase "rival" is open, not done/);
  // A hold's change round: the reopened reason carries the hold's seq; the note joins the package's change requests.
  const reopened = fold([...head, { type: "phase_reviewed", phase: "court_plays", verdict: "hold", note: "smaller court", by: "player" }, { type: "package_state", package: "court", state: "promoted", round: 1 }, { type: "reopened", package: "court", reason: "phase hold (event 4) on phase court_plays; x: smaller court" }]);
  assert.equal(reopened.phases[0]?.hold?.applied, true);
  assert.deepEqual(reopened.packages["court"]?.changes, ["smaller court"]);
});

test("data/job-events.schema.json carries the three new events", () => {
  const doc = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "data", "job-events.schema.json"), "utf8")) as { events: Record<string, unknown> };
  for (const t of ["aspect_reacted", "phase_done", "phase_reviewed"]) assert.ok(doc.events[t], t);
});

// ---------------------------------------------------------------- Designer

test("designer v2: the prompt is fun-first (checklist, wow example, no 'do not invent'), carries the engine and the cards' fun lines; standard and crazy say different things", () => {
  const engine = path.join(REPO_ROOT, "engine");
  const standard = renderDesignerPrompt({ sentence: "a fight in a colosseum", engine: designerEngineText(engine), cards: designerCardsText(engine) });
  assert.doesNotMatch(standard, /Do not invent features/);
  for (const k of ["A camera that serves the verb", "Juice on the verbs that matter", "Rivals with character", "A first minute that teaches by playing", "Stakes that make the next round matter", "An intensity curve", "One twist", "A worked example of depth", "STANDARD."]) assert.ok(standard.includes(k), k);
  assert.match(standard, /ctx\.cameras\.shake\(amount, frames\)/, "the cameras section of API.md is in the prompt");
  assert.match(standard, /## 17\. What the kernel does not do yet/);
  assert.match(standard, /- barrier_wall: /, "the kit's parts");
  assert.match(standard, /fun, first minute: /, "the cards' fun blocks");
  const crazy = renderDesignerPrompt({ sentence: "a fight in a colosseum", creativity: "crazy" });
  assert.match(crazy, /CRAZY\. Keep every word the player said/);
  assert.doesNotMatch(crazy, /STANDARD\./);
});

test("designer v2: crazy needs one or two crazy aspects, standard none; an answer that breaks the rule or a word limit is sent back with the reason", async () => {
  const plain = v2Brief();
  const crazy = v2Brief(true);
  const okCrazy = new FakeBuilder({ steps: [{ match: { role: "designer" }, json: { brief: crazy, estimate } }] });
  assert.ok((await designBrief(okCrazy, { sentence: "s", creativity: "crazy" })).ok);
  const noCrazy = new FakeBuilder({ steps: [{ match: { role: "designer", attempt: 1 }, json: { brief: plain, estimate } }, { match: { role: "designer", attempt: 2 }, json: { brief: crazy, estimate } }] });
  const r = await designBrief(noCrazy, { sentence: "s", creativity: "crazy" });
  assert.ok(r.ok);
  assert.match(noCrazy.calls[1]?.req.prompt ?? "", /this job is crazy: add one or two unexpected mechanics/);
  const standardWithCrazy = new FakeBuilder({ steps: [{ match: { role: "designer" }, json: { brief: crazy, estimate } }] });
  const s = await designBrief(standardWithCrazy, { sentence: "s" });
  assert.equal(s.ok, false);
  assert.match(s.ok ? "" : s.reason, /this job is standard/);
  const three = { ...crazy, aspects: [...(crazy.aspects ?? []), { ...(crazy.aspects ?? [])[3]!, id: "b" }, { ...(crazy.aspects ?? [])[3]!, id: "c" }] };
  const tooMany = await designBrief(new FakeBuilder({ steps: [{ match: { role: "designer" }, json: { brief: three, estimate } }] }), { sentence: "s", creativity: "crazy" });
  assert.match(tooMany.ok ? "" : tooMany.reason, /3 aspects carry "crazy": true; crazy mode adds one or two/);
  const wordy = { ...plain, pitch: Array.from({ length: 25 }, () => "very").join(" ") };
  const w = await designBrief(new FakeBuilder({ steps: [{ match: { role: "designer" }, json: { brief: wordy, estimate } }] }), { sentence: "s" });
  assert.match(w.ok ? "" : w.reason, /pitch has 25 words/);
  const v1 = await designBrief(new FakeBuilder({ steps: [{ match: { role: "designer" }, json: { brief: { rules: "r", arena: "a", ai: "i", controls: "c", mood: "m" }, estimate } }] }), "s");
  assert.equal(v1.ok, false, "the v2 Designer must write a pitch and aspects");
});

test("designer v2 redesign: the prompt carries the previous brief and every reaction; a dropped aspect may not come back", async () => {
  const prev = v2Brief();
  const reactions = { rival: { choice: "drop", note: "no rival", seq: 3 }, court: { choice: "ice_court", seq: 4 } };
  const text = renderDesignerPrompt({ sentence: "s", previous: { brief: prev, reactions } });
  assert.match(text, /This is a REDESIGN/);
  assert.match(text, /- rival \("Rival Rex"\): DROP: .*the player's note: "no rival"/);
  assert.match(text, /- court \("Walled court"\): the player CHOSE the alternative ice_court \("Ice court"/);
  assert.match(text, /- paddle \("Your paddle"\): no reaction: as designed/);
  const back = new FakeBuilder({ steps: [{ match: { role: "designer" }, json: { brief: prev, estimate } }] });
  const r = await designBrief(back, { sentence: "s", previous: { brief: prev, reactions } });
  assert.match(r.ok ? "" : r.reason, /aspect "rival" was dropped by the player and must not be in the redesign/);
});

// ---------------------------------------------------------------- Planner and phases

test("planner v2: the Planner writes phases (sent back without them); the root must be in the first phase; the prompt carries the reactions", async () => {
  const plan = fixturePlan();
  assert.match(planCheck(plan, { verbs: VERBS, requirePhases: true }).join("\n"), /the plan has no "phases"/);
  assert.deepEqual(planCheck(plan, { verbs: VERBS }), [], "a hand-written plan may leave them out");
  const p = fixturePhases();
  assert.match(planCheck(plan, { verbs: VERBS }, undefined, [{ ...p[1], packages: ["paddle_ai", "court"] }, { ...p[0], packages: ["core"] }]).join("\n"), /depends on "core", which is in the later phase|must be in the first phase/);
  const brief = v2Brief(true);
  const input = { sentence: "s", packId: "game.paddle_court", title: "Paddle Court", brief, reactions: { rival: { choice: "drop", seq: 3 } }, creativity: "crazy" as const, packContract: "(contract)" };
  const text = renderPlannerPrompt(input, { verbs: VERBS });
  assert.match(text, /# Phases: the player tries the game as it grows/);
  assert.match(text, /made in CRAZY mode/);
  assert.match(text, /- rival \("Rival Rex"\): DROP/);
  assert.match(text, /magnet_ball \[twist\] \(crazy\): Magnet ball/);
  const b = new FakeBuilder({ steps: [{ match: { role: "planner", attempt: 1 }, json: { packages: plan } }, { match: { role: "planner", attempt: 2 }, json: { packages: plan, phases: p } }] });
  const r = await planPackages(b, input, { verbs: VERBS });
  assert.ok(r.ok);
  assert.deepEqual(r.value.phases?.map((x) => x.id), ["court_plays", "rival"]);
});

test("replan keeps the phases: a replacement goes to the current phase or later, after its dependencies; an emptied phase is dropped", () => {
  const plan = fixturePlan();
  const s = fold([created(), { type: "plan_set", packages: plan, phases: fixturePhases() }, { type: "phase_done", phase: "court_plays" }, { type: "phase_reviewed", phase: "court_plays", verdict: "pass", by: "auto" }]);
  const fresh = [{ ...plan[2]!, id: "rival_ai" }];
  assert.deepEqual(replanPhases(s, fresh, new Set(["paddle_ai"])).phases?.map((x) => [x.id, x.packages]), [["court_plays", ["core", "court"]], ["rival", ["rival_ai"]]]);
  const early = fold([created(), { type: "plan_set", packages: plan, phases: fixturePhases() }]);
  const two = replanPhases(early, [{ ...plan[1]!, id: "court2" }], new Set(["court"]));
  assert.deepEqual(two.phases?.map((x) => x.packages), [["core", "court2"], ["paddle_ai"]]);
  assert.deepEqual(replanPhases(fold([created(), { type: "plan_set", packages: plan }]), fresh, new Set()), {}, "no phases, none made");
});

test("critic: the fun_promise item joins the rubric with the phase's try line (or the pitch); without either the rubric is the default four", () => {
  const s = fold([created(), { type: "brief_set", brief: v2Brief(), estimate }, { type: "plan_set", packages: fixturePlan(), phases: fixturePhases() }]);
  const r = criticRubric(s, "paddle_ai");
  assert.deepEqual(r.map((x) => x.id), [...DEFAULT_RUBRIC.map((x) => x.id), "fun_promise"]);
  assert.match(r[4]?.text ?? "", /"Beat a rival paddle that chases the ball"/);
  const noPhases = fold([created(), { type: "brief_set", brief: v2Brief(), estimate }]);
  assert.match(criticRubric(noPhases, "core")[4]?.text ?? "", /Slap a speeding ball/);
  assert.deepEqual(criticRubric(fold([created()]), "core"), DEFAULT_RUBRIC);
  assert.doesNotMatch(fs.readFileSync(path.join(PKG_ROOT, "prompts", "critic.md"), "utf8"), /not fun/);
});

// ---------------------------------------------------------------- commands

function newJob(label: string, brief: Brief = v2Brief(), extra: string[] = []): { site: string; jobDir: string; script: string; made: Promise<{ code: number; text: string }> } {
  const root = tempDir(label);
  const site = path.join(root, "site");
  const script = path.join(root, "fake.json");
  fs.writeFileSync(script, JSON.stringify({ steps: [{ match: { role: "designer", promptIncludes: "REDESIGN" }, json: { brief: { ...brief, pitch: "A redesigned pitch." }, estimate } }, { match: { role: "designer" }, json: { brief, estimate } }, ...roomSteps()] }));
  const made = run(["new", "a ball-and-paddle game in a walled court", "--site", site, "--adapter", "fake", "--fake-script", script, "--engine-dir", path.join(REPO_ROOT, "engine"), ...extra]);
  return { site, script, made, get jobDir() { return path.join(site, fs.readdirSync(site)[0] as string); } };
}

test("command new --creativity crazy --run-through: both keys in job_created, the Designer told CRAZY; a bad value writes nothing", async () => {
  const j = newJob("v2-new", v2Brief(true), ["--creativity", "crazy", "--run-through"]);
  const r = await j.made;
  assert.equal(r.code, 0, r.text);
  const evs = readEvents(j.jobDir);
  const first = evs[0];
  assert.ok(first?.type === "job_created" && first.creativity === "crazy" && first.run_through === true);
  assert.match(r.text, /foreman react .* keep\|drop\|<alternative>/);
  const transcript = evs.find((e) => e.type === "builder_run");
  const prompt = (JSON.parse(fs.readFileSync(path.join(j.jobDir, transcript?.type === "builder_run" ? transcript.transcript ?? "" : ""), "utf8")) as { prompt: string }).prompt;
  assert.match(prompt, /CRAZY\. Keep every word/);
  const standard = newJob("v2-new-std", v2Brief(), ["--creativity", "standard"]);
  assert.equal((await standard.made).code, 0);
  assert.ok(!("creativity" in (readEvents(standard.jobDir)[0] ?? {})), "standard writes no key");
  const site = path.join(tempDir("v2-new-bad"), "site");
  await assert.rejects(run(["new", "x", "--site", site, "--adapter", "fake", "--creativity", "wild"]), (e: unknown) => e instanceof UsageError && /--creativity takes crazy/.test(e.message));
  assert.equal(fs.existsSync(site), false);
});

test("command react: checked against the latest brief before anything is written; the reaction is an aspect_reacted event", async () => {
  const j = newJob("v2-react");
  assert.equal((await j.made).code, 0);
  const n = readEvents(j.jobDir).length;
  await assert.rejects(run(["react", j.jobDir, "ghost", "keep"]), /no aspect "ghost" in the latest brief \(paddle, rival, court\)/);
  await assert.rejects(run(["react", j.jobDir, "rival", "ice_court"]), /choice "ice_court" is not one of aspect "rival": keep, drop, twin_rivals, wall_bot/);
  await assert.rejects(run(["react", j.jobDir, "rival"]), /usage: foreman react/);
  assert.equal(readEvents(j.jobDir).length, n, "nothing written");
  const ok = await run(["react", j.jobDir, "rival", "twin_rivals", "--note", "two of them, please"]);
  assert.equal(ok.code, 0);
  const last = readEvents(j.jobDir).at(-1);
  assert.deepEqual(last?.type === "aspect_reacted" ? [last.aspect, last.choice, last.note] : [], ["rival", "twin_rivals", "two of them, please"]);
  const st = await run(["status", j.jobDir]);
  assert.match(st.text, /aspect   rival\s+\[rival\] Rival Rex: .* -> twin_rivals \("two of them, please"\)/);
  assert.equal((await run(["approve", j.jobDir])).text, "brief approved by player with 1 reaction(s) to its aspects; the Planner sees them");
  await assert.rejects(run(["react", j.jobDir, "rival", "keep"]), /already approved/);
});

test("command redesign: the Designer again with the brief and the reactions; a new brief_set clears them; refused after approval", async () => {
  const j = newJob("v2-redesign");
  assert.equal((await j.made).code, 0);
  assert.equal((await run(["react", j.jobDir, "court", "drop"])).code, 0);
  const r = await run(["redesign", j.jobDir, "--adapter", "fake", "--fake-script", j.script, "--engine-dir", path.join(REPO_ROOT, "engine")]);
  // The fake answers the redesign with the same aspects, the dropped court among them: sent back twice, refused.
  assert.equal(r.code, 1, r.text);
  assert.match(r.text, /aspect "court" was dropped by the player and must not be in the redesign; the earlier brief stands/);
  assert.equal(readEvents(j.jobDir).filter((e) => e.type === "brief_set").length, 1);
  assert.equal((await run(["react", j.jobDir, "court", "keep"])).code, 0);
  const ok = await run(["redesign", j.jobDir, "--adapter", "fake", "--fake-script", j.script, "--engine-dir", path.join(REPO_ROOT, "engine")]);
  assert.equal(ok.code, 0, ok.text);
  const evs = readEvents(j.jobDir);
  const last = evs.at(-1);
  assert.ok(last?.type === "brief_set" && last.brief.pitch === "A redesigned pitch.");
  const t = evs.filter((e) => e.type === "builder_run" && (e.transcript ?? "").startsWith("reports/designer-")).at(-1); // the design step (the room also ran concept and review)
  const prompt = (JSON.parse(fs.readFileSync(path.join(j.jobDir, t?.type === "builder_run" ? t.transcript ?? "" : ""), "utf8")) as { prompt: string }).prompt;
  assert.match(prompt, /- court \("Walled court"\): KEEP/);
  const st = await run(["status", j.jobDir]);
  assert.match(st.text, /design   standard, design 2: A redesigned pitch\./);
  assert.doesNotMatch(st.text, /-> keep/, "the reactions lapsed with the new brief");
  const dry = await run(["prompts", j.jobDir, "--designer", "--engine-dir", path.join(REPO_ROOT, "engine")]);
  assert.match(dry.text, /DESIGNER PROMPT/);
  assert.match(dry.text, /This is a REDESIGN/);
  assert.equal((await run(["approve", j.jobDir])).code, 0);
  await assert.rejects(run(["redesign", j.jobDir, "--adapter", "fake", "--fake-script", j.script]), /already approved/);
});

test("command phase: refused without a phase that waits, and hold without a note; nothing is written", async () => {
  const root = tempDir("v2-phase-cmd");
  const jobDir = path.join(root, "job");
  fs.mkdirSync(jobDir);
  const lines = fs.readFileSync(path.join(FIXTURE, "job.jsonl"), "utf8").split("\n").filter(Boolean).slice(0, 4);
  fs.writeFileSync(path.join(jobDir, "job.jsonl"), lines.join("\n") + "\n");
  await assert.rejects(run(["phase", jobDir, "pass"]), /this job's plan has no phases/);
  await assert.rejects(run(["phase", jobDir, "maybe"]), /usage: foreman phase <job> pass\|hold/);
  await assert.rejects(run(["phase", jobDir, "hold"]), /hold needs --note/);
  assert.equal(readEvents(jobDir).length, 4);
});

// ---------------------------------------------------------------- cards (CARDS.md `fun`)

test("cards fun: every card has a fun block; tl cards check refuses a missing key, an empty list and an undeclared TL member", async () => {
  const check = (await import(pathToFileURL(path.join(REPO_ROOT, "devx", "lib", "cards", "check.mjs")).href)) as {
    validateCard: (c: unknown, w?: string) => string[];
    checkCardAgainstTree: (c: unknown, root: string) => string[];
    loadCards: (root: string) => { cards: { card: { id: string; fun?: Record<string, string[]> } }[] };
  };
  const { cards } = check.loadCards(REPO_ROOT);
  assert.equal(cards.length, 6); // N2 of 22 Nov: card.duel; E3 of 24 Nov: card.rink_core
  for (const { card } of cards) {
    assert.deepEqual(Object.keys(card.fun ?? {}), ["camera", "juice", "rivals", "first_minute", "stakes"], card.id);
    assert.deepEqual(check.validateCard(card), []);
    assert.deepEqual(check.checkCardAgainstTree(card, REPO_ROOT), []);
  }
  const card = JSON.parse(JSON.stringify(cards[0]?.card)) as { fun: Record<string, string[]> };
  delete card.fun["stakes"];
  assert.match(check.validateCard(card).join("\n"), /fun: missing 'stakes'/);
  card.fun["stakes"] = [];
  assert.match(check.validateCard(card).join("\n"), /'stakes' must be a non-empty list/);
  card.fun["stakes"] = ["a score"];
  card.fun["juice"] = ["shake it (TLCameras.wobble)"];
  assert.match(check.checkCardAgainstTree(card, REPO_ROOT).join("\n"), /fun\.juice names TLCameras\.wobble: TLCameras has no func, signal or var 'wobble'/);
  card.fun["juice"] = ["shake it (TLNope.shake)"];
  assert.match(check.checkCardAgainstTree(card, REPO_ROOT).join("\n"), /no class TLNope in engine\//);
});
