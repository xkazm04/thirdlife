// L1 of 21 Nov (JOB.md "Added 2026-11-21"): the design room (concept -> design -> review, one revise), builders that
// read the design, the quality loop (two revise rounds, keep the better, hold, accept, retry) and motion strips.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, foremanFor, readEvents, sampleConcept, sampleDesign, scriptWith, tempJob, v2Brief, type TempJob } from "./helpers.js";
import { FakeBuilder, type FakeStep } from "../builder/fake.js";
import { designRoom } from "../room.js";
import { planCheck, renderPlannerPrompt } from "../designer.js";
import { validateEvent, type Brief, type JobEvent, type PackageSpec } from "../events.js";
import { JobLog, rebuildState } from "../joblog.js";
import { statusTable } from "../status.js";
import { qualityNext } from "../quality_state.js";
import { qualityText, slopIds } from "../roomtext.js";
import { cardBriefText } from "../cards.js";
import { FAKE_VERBS_FILE } from "../verbs.js";
import { REPO_ROOT } from "../paths.js";

after(cleanup);

const estimate = { packages: 6, wallMinutes: 60, tokens: 900000 };
const ofType = <T extends JobEvent["type"]>(evs: JobEvent[], t: T): Extract<JobEvent, { type: T }>[] => evs.filter((e): e is Extract<JobEvent, { type: T }> => e.type === t);
const scores = (x: number): Record<string, number> => ({ hook: x, gif: x, depth: x, feel: x, fit: x });

// ---------------------------------------------------------------- the design room

test("room: concept -> design -> review (revise) -> design -> review (ok); the brief carries concept and design; the verdict is recomputed from scores and slop", async () => {
  const steps: FakeStep[] = [
    { match: { role: "concept" }, json: { concept: sampleConcept() } },
    { match: { role: "designer", attempt: 1 }, json: { brief: v2Brief(), estimate } },
    { match: { role: "designer", attempt: 2 }, json: { brief: { ...v2Brief(), pitch: "Bank the ball past Rival Rex and brace his smash." }, estimate } },
    // The producer says ok, but gif is under the bar and it names a slop id: the room makes it a revise.
    { match: { role: "design_review", attempt: 1 }, json: { scores: { ...scores(0.8), gif: 0.4 }, slop: ["one_attack_button"], verdict: "ok", notes: "Nothing to clip yet." } },
    { match: { role: "design_review", attempt: 2 }, json: { scores: scores(0.8), slop: [], verdict: "ok", notes: "The bank shot sells it." } },
  ];
  const b = new FakeBuilder({ steps });
  const r = await designRoom(b, { sentence: "a ball-and-paddle game in a walled court" });
  assert.ok(r.ok, r.ok ? "" : r.reason);
  assert.deepEqual(b.calls.map((c) => c.req.meta?.role), ["concept", "designer", "design_review", "designer", "design_review"]);
  assert.deepEqual(r.value.reviews.map((x) => [x.round, x.verdict]), [[1, "revise"], [2, "ok"]]);
  assert.match(r.value.reviews[0]?.notes ?? "", /Nothing to clip yet\. Slop: one_attack_button\./);
  assert.deepEqual(r.value.brief.concept, sampleConcept());
  assert.deepEqual(r.value.brief.design, sampleDesign());
  assert.equal(r.value.brief.pitch, "Bank the ball past Rival Rex and brace his smash.");
  // The design step sees the chosen concept; its second run sees the producer's notes and its own previous design.
  assert.match(b.calls[1]?.req.prompt ?? "", /chosen pitch: Paddle duel where walls bank shots past Rival Rex\./);
  assert.match(b.calls[1]?.req.prompt ?? "", /## 6\. The slop list/);
  assert.match(b.calls[3]?.req.prompt ?? "", /The producer sent your design back \(review round 1 of 2\)[^]*gif 0\.4[^]*Slop: one_attack_button/);
  assert.match(b.calls[2]?.req.prompt ?? "", /This is review round 1 of 2/);
  assert.match(b.calls[4]?.req.prompt ?? "", /review round 2 of 2 \(the final round/);
  // The concept prompt asks for five candidates with likelihoods and carries the marketability section.
  assert.match(b.calls[0]?.req.prompt ?? "", /FIVE candidate concepts[^]*## 3\. Marketability/);
});

test("room: round 2 is final (a second revise still sets the brief); word limits and a missing defensive verb are sent back", async () => {
  const twice = new FakeBuilder({ steps: [{ match: { role: "concept" }, json: { concept: sampleConcept() } }, { match: { role: "designer" }, json: { brief: v2Brief(), estimate } }, { match: { role: "design_review" }, json: { scores: scores(0.5), slop: [], verdict: "revise", notes: "Still flat." } }] });
  const r = await designRoom(twice, { sentence: "s" });
  assert.ok(r.ok);
  assert.deepEqual(r.value.reviews.map((x) => x.verdict), ["revise", "revise"]);
  // A concept over its word limits, then a fixed one.
  const long = { ...sampleConcept(), hook: Array.from({ length: 14 }, () => "very").join(" ") };
  const c = new FakeBuilder({ steps: [{ match: { role: "concept", attempt: 1 }, json: { concept: long } }, { match: { role: "concept", attempt: 2 }, json: { concept: sampleConcept() } }, { match: { role: "designer" }, json: { brief: v2Brief(), estimate } }, { match: { role: "design_review" }, json: { scores: scores(0.9), slop: [], verdict: "ok", notes: "ok" } }] });
  assert.ok((await designRoom(c, { sentence: "s" })).ok);
  assert.match(c.calls[1]?.req.prompt ?? "", /concept hook has 14 words; at most 12/);
  // A design without a defensive verb is sent back; an unknown slop id is refused.
  const soft = { ...v2Brief(), design: { ...sampleDesign(), verbs: sampleDesign().verbs.map((v) => ({ id: v.id, input: v.input, anticipation_f: v.anticipation_f, active_f: v.active_f, recovery_f: v.recovery_f, cancel: v.cancel })) } };
  const d = new FakeBuilder({ steps: [{ match: { role: "concept" }, json: { concept: sampleConcept() } }, { match: { role: "designer" }, json: { brief: soft, estimate } }] });
  const rd = await designRoom(d, { sentence: "s" });
  assert.equal(rd.ok, false);
  assert.match(rd.ok ? "" : rd.reason, /at least one verb is defensive/);
  const e = new FakeBuilder({ steps: [{ match: { role: "concept" }, json: { concept: sampleConcept() } }, { match: { role: "designer" }, json: { brief: v2Brief(), estimate } }, { match: { role: "design_review" }, json: { scores: scores(0.9), slop: ["meh"], verdict: "ok", notes: "ok" } }] });
  const re = await designRoom(e, { sentence: "s" });
  assert.match(re.ok ? "" : re.reason, /slop ids meh are not in the slop list \(one_attack_button, /);
});

test("handbook: the sections the prompts carry are found by number, the slop ids by line; the Designer prompt lost the speed-stat and no-ragdoll steers", () => {
  assert.deepEqual(slopIds().slice(0, 10), ["one_attack_button", "recoloured_rivals", "borrowed_clips", "hit_without_reaction", "camera_behind_scenery", "hud_only_twist", "skill_removing_autoaim", "every_hit_floors", "fighters_overlap", "placeholder_in_clip_moment"]);
  assert.match(qualityText(["2"]), /^## 2\. Feel numbers at 60 Hz[^]*Hit-stop on attacker and victim together/);
  assert.doesNotMatch(qualityText(["2"]), /## 3\./);
  const builderRules = qualityText(["7:Builder"]);
  assert.match(builderRules, /^## 7\. Rules by role \(Builder\)\n11\. /);
  assert.doesNotMatch(builderRules, /Critic|19\. /);
  const designer = fs.readFileSync(path.join(REPO_ROOT, "foreman", "prompts", "designer.md"), "utf8");
  assert.doesNotMatch(designer, /Difficulty is their speed, reaction and aggression/);
  assert.doesNotMatch(designer, /no ragdoll/);
  assert.doesNotMatch(designer, /one main verb done brilliantly/);
  assert.match(designer, /TLHit\.react\(victim, from_dir, strength\)[^]*TLHit\.down\(victim, frames, from_dir\)/);
  assert.match(designer, /At least one is defensive/);
});

// ---------------------------------------------------------------- wire

test("wire: brief.concept/design, design_reviewed, serves and the milestone's round/kept/strips read strictly", () => {
  const base = { v: 1, seq: 2, ts: "2026-11-21T10:00:00.000Z", job: "j" };
  assert.doesNotThrow(() => validateEvent({ ...base, type: "brief_set", brief: { ...v2Brief(), concept: sampleConcept() }, estimate }));
  assert.throws(() => validateEvent({ ...base, type: "brief_set", brief: { ...v2Brief(), design: { ...sampleDesign(), vibe: 1 } }, estimate }), /unknown key "vibe"/);
  assert.throws(() => validateEvent({ ...base, type: "brief_set", brief: { ...v2Brief(), design: { ...sampleDesign(), clips: sampleDesign().clips.slice(0, 2) } }, estimate }), /clips/);
  assert.doesNotThrow(() => validateEvent({ ...base, type: "design_reviewed", round: 1, verdict: "revise", scores: scores(0.5), notes: "flat" }));
  assert.throws(() => validateEvent({ ...base, type: "design_reviewed", round: 3, verdict: "ok", scores: scores(0.5), notes: "x" }), /round/);
  assert.throws(() => validateEvent({ ...base, type: "design_reviewed", round: 1, verdict: "ok", scores: { ...scores(0.5), fun: 1 }, notes: "x" }), /unknown key "fun"/);
  const ms = { ...base, type: "milestone", milestone: "blockout", captures: [], summary: "s" };
  assert.doesNotThrow(() => validateEvent({ ...ms, round: 2, kept: "previous", strips: [{ capture: "captures/blockout-hero-bot_rally-strip-f90.png", label: "MOTION STRIP" }] }));
  assert.throws(() => validateEvent({ ...ms, kept: "new" }), /"kept" comes with a "round"/);
  assert.throws(() => validateEvent({ ...ms, round: 0 }), /round/);
  // A plan's serves names clip ids of the brief's design.
  const plan = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "job-paddle", "job.jsonl"), "utf8").split("\n")[3] as string).packages as PackageSpec[];
  const verbs = JSON.parse(fs.readFileSync(FAKE_VERBS_FILE, "utf8"));
  const served = plan.map((p, i) => (i === 0 ? { ...p, serves: ["bank_past_rex", "brace_counter"] } : p));
  const clipIds = sampleDesign().clips.map((c) => c.id);
  assert.deepEqual(planCheck(served, { verbs, clipIds }), []);
  assert.match(planCheck(plan.map((p, i) => (i === 0 ? { ...p, serves: ["slow_mo"] } : p)), { verbs, clipIds }).join("\n"), /serves "slow_mo", which is not a clip id of the brief's design \(bank_past_rex, brace_counter, sudden_death\)/);
});

// ---------------------------------------------------------------- builders and the Planner read the design

/** The fixture job with a v2 brief that carries a design doc, the plan's root serving two clips, one milestone. */
function designJob(label: string, oneMilestone = true): TempJob {
  const job = tempJob(label);
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  const brief = JSON.parse(lines[1] as string) as { brief: Brief };
  brief.brief = { ...v2Brief(), concept: sampleConcept() };
  lines[1] = JSON.stringify(brief);
  const plan = JSON.parse(lines[3] as string) as { packages: PackageSpec[] };
  for (const p of plan.packages) {
    if (oneMilestone) p.milestone = "blockout";
    if (p.id === "core") p.serves = ["bank_past_rex", "brace_counter"];
  }
  lines[3] = JSON.stringify(plan);
  fs.writeFileSync(file, lines.map((l) => l + "\n").join(""));
  return job;
}

test("builders: every package prompt carries the design's verbs, feel sheet and clips, the Feel rules and the handbook; a brief without a design keeps the old prompt", async () => {
  const job = designJob("builder-design", false);
  const { foreman, builder } = foremanFor(job, { promoteTo: "job" });
  assert.equal((await foreman.run()).jobState?.state, "done");
  const core = builder.calls.find((c) => c.req.meta?.package === "core")?.req.prompt ?? "";
  assert.match(core, /- verbs \(frames at 60 Hz\):\n[^]*- brace \(DEFENSIVE\): paddle_brace \(shift\); anticipation 2 f, active 20 f, recovery 8 f/);
  assert.match(core, /- hit-stop: 3 to 6 frames on attacker AND victim/);
  assert.match(core, /- clip moments [^]*bank_past_rex: a bank shot that beats the lunge of Rex/);
  assert.match(core, /your package serves these clip moments \(make them happen and look good first\): bank_past_rex \("a bank shot/);
  assert.match(core, /# Feel \(docs\/GAME-QUALITY\.md\)[^]*## 2\. Feel numbers at 60 Hz[^]*## 6\. The slop list[^]*## 7\. Rules by role \(Builder\)/);
  assert.match(core, /make the acceptance pass AND land the feel sheet/);
  const court = builder.calls.find((c) => c.req.meta?.package === "court")?.req.prompt ?? "";
  assert.doesNotMatch(court, /your package serves these clip moments/, "court serves no clip");
  // A job made before the room: no Feel section, no design lines.
  const old = tempJob("builder-old");
  const o = foremanFor(old, { promoteTo: "job" });
  await o.foreman.run();
  const p = o.builder.calls.find((c) => c.req.meta?.package === "core")?.req.prompt ?? "";
  assert.doesNotMatch(p, /# Feel \(docs|game design doc/);
  // The Planner reads the whole design, the handbook and the rule that the root lands the feel sheet.
  const brief = { ...v2Brief(), concept: sampleConcept() };
  const plan = renderPlannerPrompt({ sentence: "s", packId: "game.x", title: "X", brief, packContract: "(c)" }, { verbs: JSON.parse(fs.readFileSync(FAKE_VERBS_FILE, "utf8")) });
  assert.match(plan, /- concept:\n  - chosen pitch: [^]*- pillars:[^]*- playstyles:[^]*- skill: floor: /);
  assert.match(plan, /Never cut the feel sheet to fit a package[^]*## 2\. Feel numbers at 60 Hz/);
  assert.match(plan, /`serves`: the clip ids/);
  // The card's fun block reaches builders (cardBriefText, as `tl cards brief` prints it).
  const card = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "engine", "cards", "knock_down.json"), "utf8"));
  assert.match(cardBriefText(card), /What makes this kind of game fun[^]*\n- juice: A block that breaks gets debris/);
});

// ---------------------------------------------------------------- the quality loop

const criticAt = (attempt: number, ok: boolean, note: string, pkg = "court"): FakeStep => ({
  match: { role: "critic", attempt },
  json: { ok, scores: { silhouette: 0.8, readability: ok ? 0.8 : 0.4, style_consistency: 0.7, shows_play: 0.7, fun_promise: ok ? 0.8 : 0.3 }, notes: [note], ...(ok ? {} : { package: pkg }) },
});
const courtRound = (round: number, marker: string): FakeStep => ({ match: { role: "builder", package: "court", round }, write: { "data/court.json": `{"width_m": 16, "depth_m": 9, "wall_height_m": 1.2, "mark": "${marker}"}\n` }, text: "Done.\nDEVIATIONS: none" });
const answer = (job: TempJob, text: string): void => {
  const log = JobLog.open(job.jobDir);
  try {
    log.append({ type: "comment", milestone: "blockout", text, by: "player" });
  } finally {
    log.close();
  }
};

test("loop: NOT ok -> revise round 1 (snapshot) -> the critic keeps the PREVIOUS version (pack/ restored, merge events) -> round 2 -> ok, kept new", async () => {
  const job = designJob("loop-previous");
  let atRound1 = "";
  const steps = [criticAt(1, false, "the court is a grey slab"), criticAt(2, false, "worse: walls hide the ball"), criticAt(3, true, "the court reads now"), { match: { role: "critic_compare" }, json: { keep: "previous", why: "image 1 shows the ball; image 3 hides it behind a wall" } }, courtRound(2, "R2"), courtRound(3, "R3")];
  const { foreman, builder } = foremanFor(job, {
    critic: true,
    promoteTo: "job",
    script: scriptWith(steps),
    afterAppend: (ev) => {
      if (ev.type === "milestone" && ev.round === 1) atRound1 = fs.readFileSync(path.join(job.jobDir, "pack", "data", "court.json"), "utf8");
    },
  });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  const ms = ofType(evs, "milestone");
  assert.deepEqual(ms.map((m) => [m.round, m.kept]), [[1, "previous"], [2, "new"]]);
  assert.match(ms[0]?.summary ?? "", /critic \(V5\) NOT ok: [^]*grey slab[^]*revise round 1 of 2: kept previous \(image 1 shows the ball[^]*pack\/ was put back to reports\/quality-blockout-r1\/pack; the new version was critic \(V5\) NOT ok[^]*walls hide the ball/);
  assert.doesNotMatch(atRound1, /R2/, "kept previous: the round-1 files are gone from pack/");
  // (court changed file contents only, so its merged-file list is the same and the restore needs no merge event)
  assert.ok(ms[0]?.captures.every((c) => c.startsWith("reports/quality-blockout-r1/captures/")), "the kept version's captures are the snapshot's");
  assert.match(fs.readFileSync(path.join(job.jobDir, "pack", "data", "court.json"), "utf8"), /R3/);
  // Round 2's feedback says which version stands and what the critic said.
  const p3 = builder.calls.filter((c) => c.req.meta?.package === "court").map((c) => c.req.prompt)[2] ?? "";
  assert.match(p3, /critic \(V5\) NOT ok, revise round 2 of 2 \(milestone blockout\): [^\n]*grey slab/);
  assert.equal(builder.calls.filter((c) => c.req.meta?.role === "critic_compare").length, 1, "an ok new version needs no compare");
  // The resume path reads the same decision from the log.
  assert.deepEqual(qualityNext(evs, "blockout", ["core", "court", "paddle_ai"]), { next: "closed" });
});

test("loop: still NOT ok after round 2 holds the job (also with run_through); status names it; retry runs one more round with the note; accept ends it", async () => {
  const job = designJob("loop-hold");
  const bad = (n: number): FakeStep => criticAt(n, false, `still flat ${n}`);
  const opts = { critic: true, promoteTo: "job" as const, script: scriptWith([bad(1), bad(2), bad(3), bad(4), courtRound(2, "R2"), courtRound(3, "R3"), courtRound(4, "R4")]) };
  const one = foremanFor(job, opts);
  const s1 = await one.foreman.run();
  assert.deepEqual(s1.jobState, { state: "paused", reason: "quality" });
  assert.deepEqual(s1.qualityHeld && [s1.qualityHeld.milestone, s1.qualityHeld.round], ["blockout", 2]);
  assert.equal(s1.promoted, undefined, "a hold never promotes");
  const table = statusTable(rebuildState(job.jobDir));
  assert.match(table, /HELD     quality: milestone blockout is still NOT ok after revise round 2/);
  assert.match(table, /critic   silhouette 0\.8, readability 0\.4[^\n]*still flat/);
  assert.match(table, /answer   foreman quality paddle-court-20261110-1 accept \[--note "\.\.\."\]   or   foreman quality paddle-court-20261110-1 retry --note/);
  assert.match(table, /milestone blockout round 2 kept (new|previous): NOT ok, /);
  // Run again without an answer: nothing happens.
  const n = readEvents(job.jobDir).length;
  await foremanFor(job, opts).foreman.run();
  assert.equal(readEvents(job.jobDir).length, n, "a held job waits");
  // retry with a note: one more round (3), its builder reads the note; still NOT ok: held again at round 3.
  answer(job, "quality retry: give Rex a red shield and raise the camera");
  const two = foremanFor(job, opts);
  const s2 = await two.foreman.run();
  assert.deepEqual(s2.jobState, { state: "paused", reason: "quality" });
  assert.equal(s2.qualityHeld?.round, 3);
  const retryPrompt = two.builder.calls.filter((c) => c.req.meta?.package === "court").at(-1)?.req.prompt ?? "";
  assert.match(retryPrompt, /revise round 3 of 3 \(milestone blockout\)[^\n]*The owner held the job and asks: give Rex a red shield and raise the camera/);
  // accept: the job goes on and ends done.
  answer(job, "quality accept");
  const s3 = await foremanFor(job, opts).foreman.run();
  assert.equal(s3.jobState?.state, "done", JSON.stringify(s3.jobState));
  assert.equal(s3.qualityHeld, undefined);
  // run_through holds too.
  const rt = designJob("loop-hold-rt");
  const file = path.join(rt.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  lines[0] = JSON.stringify({ ...JSON.parse(lines[0] as string), run_through: true });
  fs.writeFileSync(file, lines.map((l) => l + "\n").join(""));
  assert.deepEqual((await foremanFor(rt, opts).foreman.run()).jobState, { state: "paused", reason: "quality" });
});

// ---------------------------------------------------------------- motion strips

test("strips: with --strip in the engine's verbs.json every filmed point gets a 4x3 strip; the critic sees them labelled, with feel and slop in the rubric; without it, stills only", async () => {
  const job = designJob("strips");
  const verbs = JSON.parse(fs.readFileSync(FAKE_VERBS_FILE, "utf8"));
  verbs.verbs.capture.options.strip = { type: "string", default: "" };
  fs.mkdirSync(path.join(job.engineDir, "kernel", "runner"), { recursive: true });
  fs.writeFileSync(path.join(job.engineDir, "kernel", "runner", "verbs.json"), JSON.stringify(verbs, null, 1));
  const critic: FakeStep = { match: { role: "critic" }, json: { ok: true, scores: { silhouette: 0.8, readability: 0.8, style_consistency: 0.8, shows_play: 0.8, fun_promise: 0.8, feel: 0.7, slop: 1 }, notes: ["a slap with a 4-frame hold"] } };
  const { foreman, builder } = foremanFor(job, { critic: true, promoteTo: "job", captureFrames: [120], script: scriptWith([critic]) });
  assert.equal((await foreman.run()).jobState?.state, "done");
  const ms = ofType(readEvents(job.jobDir), "milestone");
  assert.deepEqual(ms[0]?.strips?.map((x) => x.capture), ["captures/blockout-hero-bot_rally-strip-f90.png"]);
  assert.ok(fs.existsSync(path.join(job.jobDir, "captures", "blockout-hero-bot_rally-strip-f90.png")));
  assert.match(ms[0]?.summary ?? "", /1 capture\(s\), 1 strip\(s\)/);
  const call = builder.calls.find((c) => c.req.meta?.role === "critic");
  assert.equal(call?.req.images?.length, 2, "the still and the strip");
  assert.match(call?.req.prompt ?? "", /MOTION STRIP \(4 columns x 3 rows, read left to right, top to bottom: frames 90, 95, \.\.\. 145, 5 frames apart\)/);
  assert.match(call?.req.prompt ?? "", /- feel: In the MOTION STRIPS[^\n]*\n- slop: 1\.0 when you see NO item of the slop list[^\n]*one_attack_button/);
  const verify = readEvents(job.jobDir).filter((e) => e.type === "verify" && e.verb === "capture" && /strip/.test(e.report));
  assert.equal(verify.length, 1);
  // The fixture engine has no --strip: stills only, the rubric as before.
  const plain = designJob("strips-off");
  const p = foremanFor(plain, { critic: true, promoteTo: "job", captureFrames: [120], script: scriptWith([{ match: { role: "critic" }, json: { ok: true, scores: { silhouette: 0.8, readability: 0.8, style_consistency: 0.8, shows_play: 0.8, fun_promise: 0.8 }, notes: ["fine"] } }]) });
  assert.equal((await p.foreman.run()).jobState?.state, "done");
  assert.equal(ofType(readEvents(plain.jobDir), "milestone")[0]?.strips, undefined);
});
