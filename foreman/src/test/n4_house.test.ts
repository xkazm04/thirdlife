// N4 loop of 22 Nov: the editor copies the two house games, not only the research. A template names its house game
// (engine/packs/duel, engine/packs/hockey); the design step and the Planner read its README rules, builders read its
// files from their reference copy, and a copied move is checked against the house game's own frame table.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, foremanFor, readEvents, sampleConcept, scriptWith, tempDir, tempJob, v2Brief } from "./helpers.js";
import type { FakeStep } from "../builder/fake.js";
import type { Brief, PackageSpec } from "../events.js";
import { houseCompare, houseFigures, HOUSE_BOTS, type HouseBaseline } from "../house.js";
import { judgeTofu, tofuLine, tofuMetricsFor } from "../tofu.js";
import { briefTemplateProblems, houseExcerpt, houseFrameDiff, houseKeepProblems, houseMoves, movesOf, templateExcerpt, templateOf, templatesMenuText, type Template } from "../templates.js";
import { REPO_ROOT } from "../paths.js";

after(cleanup);

const duel = templateOf("duel") as Template;
const sport = templateOf("arcade_sport") as Template;
const duelTemplate = { id: "duel" as const, reference: "DUEL-PLAYBOOK", copies: ["state machine", "mutual reactions", "the Wall, the Duelist, the Dancer"] };

test("house: the duel template reads engine/packs/duel's data/moves.json as its frame table; the house frames agree with the playbook today", () => {
  const h = houseMoves(duel);
  assert.ok(h, "engine/packs/duel/data/moves.json is read");
  assert.deepEqual(Object.fromEntries(Object.entries(h).map(([id, m]) => [id, [m.anticipation_f, m.active_f ?? "held", m.recovery_f]])), {
    light: [18, 4, 16], heavy: [32, 5, 28], charged: [54, 6, 36], bash: [14, 6, 24], block: [4, "held", 6], parry: [1, 12, 20], roll: [3, 18, 15], dodge: [2, 8, 12], taunt: [0, 0, 60],
  });
  assert.deepEqual(houseFrameDiff(duel), [], "N2's open question: the house frames are the playbook's");
  // A house game whose table moved wins over the research: the check and the diff follow it.
  const engine = tempDir("house-engine");
  fs.mkdirSync(path.join(engine, "packs", "duel", "data"), { recursive: true });
  const moves = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "engine", "packs", "duel", "data", "moves.json"), "utf8")) as Record<string, Record<string, unknown>>;
  moves["light"] = { ...moves["light"], windup: 20 };
  fs.writeFileSync(path.join(engine, "packs", "duel", "data", "moves.json"), JSON.stringify(moves));
  assert.deepEqual(houseFrameDiff(duel, engine), ["light: research 18/4/16, house game 20/4/16"]);
  assert.equal(movesOf(duel, engine)["light"]?.anticipation_f, 20);
  assert.equal(movesOf(duel, path.join(engine, "none"))["light"]?.anticipation_f, 18, "no house table: the research's");
  assert.equal(houseMoves(sport), undefined, "hockey has no moves table");
});

test("house: the design step and the Planner read the house README's rules; a builder reads the file list in ref/packs/<pack>/", () => {
  const design = templateExcerpt(duelTemplate, "design");
  assert.match(design, /### 6\.3 Contact results[^]*# The house game: engine\/packs\/duel \(game\.duel\)[^]*the house game's win[^]*data\/moves\.json: the frame table[^]*## How to play[^]*## The rules[^]*## The rivals[^]*## What changed from the playbook/);
  const planner = templateExcerpt(duelTemplate, "planner");
  assert.match(planner, /### 6\.4 State machine[^]*# The house game[^]*## What changed from the playbook/);
  assert.doesNotMatch(planner, /## 1\. The proven models/, "the Planner reads the implementable spec, not the history");
  const builder = templateExcerpt(duelTemplate, "builder");
  assert.match(builder, /Your reference copy holds it whole: ref\/packs\/duel\/[^]*scripts\/contact\.gd: the interaction matrix[^]*scripts\/feel\.gd[^]*keep the lock-on/);
  assert.doesNotMatch(builder, /## How to play/, "builders read the files, not the README");
  const hockey = houseExcerpt(sport, "design");
  assert.match(hockey, /engine\/packs\/hockey[^]*scripts\/hits\.gd[^]*## How to play[^]*## Contact and skating/);
  // Refreshed from N3's landing (main b024967): the carry, the poke and the utility AI are read, with its README section.
  assert.match(hockey, /scripts\/carry\.gd: the puck as a state[^]*scripts\/ai\/carrier\.gd: the carrier's utility scores[^]*tests\/metrics\.gd[^]*## Puck, speed and the bots' decisions/);
  assert.equal(houseFigures({ bot: { result: { metrics: { lengths: [120, 300, 180, 240] } } } }, HOUSE_BOTS["arcade_sport"] as (typeof HOUSE_BOTS)["arcade_sport"] & object).metrics["possession_median_f"], 210, "N3's possession lengths: the median");
  assert.match(templatesMenuText(), /`duel`[^\n]*House game \(the reference implementation on this engine\): engine\/packs\/duel \(game\.duel\)/);
  assert.equal(houseExcerpt(duel, "design", path.join(tempDir("no-engine"), "engine")), "", "no house pack: no excerpt");
});

test("house: a duel brief keeps the house game's lock-on and shoulder camera; facing that follows the walk is sent back", () => {
  assert.deepEqual(houseKeepProblems("Lock-on: you always face the rival. The camera over the shoulder.", duelTemplate), []);
  const p = houseKeepProblems("Facing follows movement; the camera is a fixed top view.", duelTemplate).join(" | ");
  assert.match(p, /keeps the lock-on: each fighter always faces his rival/);
  assert.match(p, /keeps the camera over the shoulder/);
  assert.deepEqual(houseKeepProblems("anything", { id: "own", reference: "Pong", copies: ["a", "b", "c"] }), []);
  // Wired into the design step's checks through briefTemplateProblems (rules, controls, arena and the feel camera).
  const design = { verbs: [], feel: { camera: "over the shoulder" } } as unknown as Parameters<typeof briefTemplateProblems>[0]["design"];
  assert.match(briefTemplateProblems({ design, rules: "facing follows the walk", controls: "", arena: "" }, duelTemplate).join(""), /lock-on/);
  assert.deepEqual(briefTemplateProblems({ rules: "x", controls: "", arena: "" }, duelTemplate), [], "no design: nothing to check");
});

// ---------------------------------------------------------------- the critic compares with the house game

test("house compare: the house bot's figures by the tofu names (its own metrics first, then the map over its result and pack state); shortfalls named", async () => {
  // The real pilot's result (engine/packs/duel tests/bot_checklist_wall.gd, seed 1, read 22 Nov 02:00): idle 45, tell 14, failures 0.
  const report = { bot: { result: { ok: true, summary: "s", rival_passive_max: 45, rival_tells_min: 14, kinds: { clash: 3, hit_heavy: 13 }, failures: 0, hand: { decisions: 156 } } } };
  assert.deepEqual(houseFigures(report, HOUSE_BOTS["duel"] as (typeof HOUSE_BOTS)["duel"] & object), { metrics: { idle_max_f: 45, tell_min_f: 14, one_sided_contacts: 0 } }, "the hand's stats object is not a hand name");
  assert.deepEqual(houseFigures({ pack_state: { rival_passive_max: 64 } }, HOUSE_BOTS["duel"] as (typeof HOUSE_BOTS)["duel"] & object).metrics, { idle_max_f: 64 }, "pack_state when the result lacks it");
  const { contactFrame } = await import("../house.js");
  assert.equal(contactFrame({ bot: { frames: 148, result: { contact: { f: 46 } } } }), 46, "the real heavy_block drill: contact at frame 46");
  assert.equal(contactFrame({ bot: { frames: 600 } }), 540);
  // Round 4: hockey's ladder bot reports its moments (real seed 1: poked at 523); the first listed kind it saw wins.
  const moments = (HOUSE_BOTS["arcade_sport"] as (typeof HOUSE_BOTS)["arcade_sport"] & object).strip?.moments;
  assert.equal(contactFrame({ bot: { frames: 6770, result: { metrics: { moments: { poked: [523], bobble: [2819, 4445] } } } } }, moments), 523);
  assert.equal(contactFrame({ bot: { frames: 6770, result: { metrics: { moments: { one_timer: [900], poked: [523] } } } } }, moments), 900);
  assert.equal(contactFrame({ bot: { frames: 6770, result: { metrics: { moments: {} } } } }, moments), 6710);
  // N2's pilot `metrics` (main 3004e58): read first; skill_spread / skill_variants / contact_types are its own definitions and dropped.
  const own = { bot: { result: { metrics: { idle_max_f: 50, feedback_f: 2, skill_spread: 0.9, skill_variants: 6, contact_types: 10, hand: "regular" } } }, pack_state: { rival_passive_max: 64 } };
  assert.deepEqual(houseFigures(own, HOUSE_BOTS["duel"] as (typeof HOUSE_BOTS)["duel"] & object), { metrics: { idle_max_f: 50, feedback_f: 2 }, hand: "regular", skipped: ["skill_spread", "skill_variants", "contact_types"] });
  const rows = tofuMetricsFor(duelTemplate);
  const base: HouseBaseline = { schema: "tl.foreman.house/1", pack: "duel", test: "tests/bot_checklist_wall.gd", hand: "regular", metrics: { idle_max_f: 64, tell_min_f: 18, contact_types: 6, one_sided_contacts: 0 } };
  const built = judgeTofu({ feedback_f: 2, skill_spread: 0.4, skill_variants: 3, idle_max_f: 110, tell_min_f: 18, tells: 5, pressure_waves: 2, lead_change_share: 0.4, close_rounds: 2, contact_types: 3, one_sided_contacts: 0 }, rows, "tests/bot_tofu.gd");
  const c = houseCompare(built, base, rows);
  assert.deepEqual(c.short, ["idle_max_f", "contact_types"], "passes its own bounds, yet worse than the house game beyond the margin");
  assert.match(c.line, /^house game engine\/packs\/duel \(tests\/bot_checklist_wall\.gd through the regular hand\), yours vs the house game's: idle_max_f 110 vs 64 SHORT, tell_min_f 18 vs 18, contact_types 3 vs 6 SHORT, one_sided_contacts 0 vs 0; the house game does not report feedback_f[^]*SHORT of the house game on idle_max_f, contact_types: copy how engine\/packs\/duel does it$/);
  assert.deepEqual(houseCompare(undefined, base, rows).short, ["idle_max_f", "tell_min_f", "contact_types", "one_sided_contacts"], "not reported where the house game reports is short");
  assert.match(houseCompare(built, { ...base, metrics: {} }, rows).line, /no figure to compare by the tofu names/);
});

/** A tiny duel house game the fake runner plays: its checklist bot reports the tofu names. */
function fakeHouse(): { reference: { cardsDir: string; housePacks: string[] } } {
  const engine = tempDir("house-mini");
  const pack = path.join(engine, "packs", "duel");
  fs.mkdirSync(path.join(pack, "tests"), { recursive: true });
  fs.mkdirSync(path.join(pack, "scripts"), { recursive: true });
  fs.writeFileSync(path.join(pack, "pack.json"), JSON.stringify({ id: "game.duel", version: "0.1.0", kernelApi: "0.1", title: "Duel", capabilities: ["physics"], entry: "scripts/main.gd", assets: [], tests: ["tests/bot_checklist_wall.gd", "tests/bot_contact_heavy_block.gd"], cameras: ["side"] }, null, 1));
  fs.writeFileSync(path.join(pack, "tests", "bot_contact_heavy_block.gd"), "extends Node\n");
  fs.writeFileSync(path.join(pack, "scripts", "main.gd"), "extends Node\nfunc _pack_setup(ctx) -> void:\n\tpass\n");
  fs.writeFileSync(path.join(pack, "tests", "bot_checklist_wall.gd"), `extends Node\n# FAKE_METRICS(${JSON.stringify({ idle_max_f: 64, tell_min_f: 18, contact_types: 6, one_sided_contacts: 0, feedback_f: 2, hand: "regular" })})\n`);
  fs.writeFileSync(path.join(pack, "README.md"), "# Duel\n");
  const cards = path.join(engine, "cards");
  fs.mkdirSync(cards, { recursive: true });
  fs.copyFileSync(path.join(REPO_ROOT, "engine", "cards", "duel.json"), path.join(cards, "duel.json"));
  return { reference: { cardsDir: cards, housePacks: [pack] } };
}

test("house compare: a duel job measures the house game once (reports/house-duel.json), sets its tofu figures beside it at every look, films the house game's exchange as a strip, and the critic scores house_game", async () => {
  const job = tempJob("house-look");
  const { FAKE_VERBS_FILE } = await import("../verbs.js");
  const verbs = JSON.parse(fs.readFileSync(FAKE_VERBS_FILE, "utf8"));
  verbs.verbs.capture.options.strip = { type: "string", default: "" };
  fs.mkdirSync(path.join(job.engineDir, "kernel", "runner"), { recursive: true });
  fs.writeFileSync(path.join(job.engineDir, "kernel", "runner", "verbs.json"), JSON.stringify(verbs, null, 1));
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  const brief = JSON.parse(lines[1] as string) as { brief: Brief };
  brief.brief = { ...v2Brief(), concept: { ...sampleConcept(), template: duelTemplate } };
  lines[1] = JSON.stringify(brief);
  const plan = JSON.parse(lines[3] as string) as { packages: PackageSpec[] };
  plan.packages = plan.packages.map((p) => ({ ...p, milestone: "blockout" as const })).map((p) => (p.id === "core" ? { ...p, contract: `${p.contract}\n${tofuLine(duelTemplate, "tests/bot_rally.gd")}`, acceptance: [...p.acceptance, { level: "V4" as const, verb: "bot" as const, args: ["--test=tests/bot_rally.gd", "--frames=1200"] }] } : p));
  lines[3] = JSON.stringify(plan);
  fs.writeFileSync(file, lines.map((l) => l + "\n").join(""));
  const base = scriptWith().steps.find((x) => x.match?.package === "core") as FakeStep;
  const metrics = { feedback_f: 2, skill_spread: 0.4, skill_variants: 3, idle_max_f: 110, tell_min_f: 18, tells: 5, pressure_waves: 2, lead_change_share: 0.4, close_rounds: 2, contact_types: 3, one_sided_contacts: 0, verbs_used: 2, hand: "regular" };
  const core: FakeStep = { ...base, write: { ...(base.write ?? {}), "tests/bot_rally.gd": ((base.write ?? {})["tests/bot_rally.gd"] as string).replace(/# FAKE_METRICS\(.*\)\n/, "") + `# FAKE_METRICS(${JSON.stringify(metrics)})\n` } };
  const criticStep: FakeStep = { match: { role: "critic" }, json: { ok: true, scores: { silhouette: 0.8, readability: 0.8, style_consistency: 0.8, shows_play: 0.8, fun_promise: 0.8, feel: 0.7, slop: 1, house_game: 0.7 }, notes: ["the rival waits longer than the Wall does"] } };
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", critic: true, ...fakeHouse(), script: scriptWith([criticStep, core]) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const house = JSON.parse(fs.readFileSync(path.join(job.jobDir, "reports", "house-duel.json"), "utf8")) as HouseBaseline;
  assert.deepEqual([house.test, house.hand, house.metrics["idle_max_f"], house.metrics["contact_types"], house.skipped], ["tests/bot_checklist_wall.gd", "regular", 64, undefined, ["contact_types"]], "round 4: contact_types is the house game's own count, not compared");
  const ms = readEvents(job.jobDir).filter((e) => e.type === "milestone");
  assert.match(ms[0]?.type === "milestone" ? ms[0].summary : "", /house game engine\/packs\/duel \(tests\/bot_checklist_wall\.gd through the regular hand\), yours vs the house game's: [^]*idle_max_f 110 vs 64 SHORT/);
  const call = builder.calls.find((c) => c.req.meta?.role === "critic");
  assert.match(call?.req.prompt ?? "", /The house game of this game's template, engine\/packs\/duel, is the bar[^]*SHORT of the house game on idle_max_f[^]*- house_game: Against the house game engine\/packs\/duel/);
  assert.equal(readEvents(job.jobDir).filter((e) => e.type === "verify" && e.verb === "bot" && /house-duel-s/.test(e.report)).length, 1, "measured once per job");
  // Round 2: the house game's own exchange, filmed once from 15 frames before its contact (the fake drill finishes at 600: 540), last in the critic's images.
  const kept = JSON.parse(fs.readFileSync(path.join(job.jobDir, "reports", "house-duel.json"), "utf8")) as HouseBaseline;
  assert.deepEqual(kept.strips?.map((x) => x.capture), ["reports/house-duel/strip-side-f525.png"]);
  assert.ok(fs.existsSync(path.join(job.jobDir, "reports", "house-duel", "strip-side-f525.png")));
  assert.match(call?.req.prompt ?? "", /image (\d+) of \1, attached to this message: strip-side-f525\.png: HOUSE GAME engine\/packs\/duel \(the bar, not this build\): MOTION STRIP[^\n]*a heavy blocked/);
  assert.match(call?.req.prompt ?? "", /When an image is labelled HOUSE GAME, set this build's strips beside it/);
});

test("planner: contracts name the house game's rows instead of retyping them, and a Planner call has 20 minutes (the standard proof timed out at 10)", async () => {
  const { planPackages, renderPlannerPrompt, PLANNER_TIMEOUT_MS } = await import("../designer.js");
  const { FakeBuilder } = await import("../builder/fake.js");
  const { fixturePlan, fixturePhases } = await import("./helpers.js");
  const { FAKE_VERBS_FILE } = await import("../verbs.js");
  const verbs = JSON.parse(fs.readFileSync(FAKE_VERBS_FILE, "utf8"));
  const brief: Brief = { ...v2Brief(), concept: { ...sampleConcept(), template: duelTemplate } };
  const text = renderPlannerPrompt({ sentence: "a fight in a colosseum", packId: "game.x", title: "X", brief, packContract: "(c)" }, { verbs });
  assert.match(text, /a contract \*\*names, it does not retype\*\*[^]*ref\/packs\/duel\/data\/moves\.json[^]*Keep each contract under about 900 words/);
  assert.equal(PLANNER_TIMEOUT_MS, 20 * 60_000);
  const b = new FakeBuilder({ steps: [{ match: { role: "planner" }, json: { packages: fixturePlan(), phases: fixturePhases() } }] });
  await planPackages(b, { sentence: "s", packId: "game.paddle_court", title: "P", brief: v2Brief(), packContract: "(c)" }, { verbs });
  assert.equal(b.calls[0]?.req.timeoutMs, PLANNER_TIMEOUT_MS);
});

test("planner timeout: `plan --timeout-ms` reaches the Planner call (a slow answer inside it passes, outside it times out); a re-plan has 20 minutes too", async () => {
  const { main } = await import("../cli.js");
  const { FIXTURE, fixturePlan, fixturePhases } = await import("./helpers.js");
  const { replanPackages, PLANNER_TIMEOUT_MS } = await import("../designer.js");
  const { FakeBuilder } = await import("../builder/fake.js");
  const { FAKE_VERBS_FILE } = await import("../verbs.js");
  const make = (label: string): { jobDir: string; script: string } => {
    const root = tempDir(label);
    const jobDir = path.join(root, "job");
    fs.mkdirSync(jobDir);
    const lines = fs.readFileSync(path.join(FIXTURE, "job.jsonl"), "utf8").split("\n").filter(Boolean).slice(0, 3);
    fs.writeFileSync(path.join(jobDir, "job.jsonl"), lines.join("\n") + "\n");
    const script = path.join(root, "fake.json");
    fs.writeFileSync(script, JSON.stringify({ steps: [{ match: { role: "planner" }, delayMs: 400, json: { packages: fixturePlan(), phases: fixturePhases() } }] }));
    return { jobDir, script };
  };
  const quiet = (): void => {};
  const slow = make("plan-timeout-short");
  assert.equal(await main(["plan", slow.jobDir, "--adapter", "fake", "--fake-script", slow.script, "--no-reference", "--timeout-ms", "100"], quiet), 1, "the 400 ms answer is past a 100 ms limit");
  const ok = make("plan-timeout-long");
  assert.equal(await main(["plan", ok.jobDir, "--adapter", "fake", "--fake-script", ok.script, "--no-reference", "--planner-timeout-ms", "5000"], quiet), 0);
  assert.ok(readEvents(ok.jobDir).some((e) => e.type === "plan_set"));
  const verbs = JSON.parse(fs.readFileSync(FAKE_VERBS_FILE, "utf8"));
  const b = new FakeBuilder({ steps: [{ match: { role: "planner" }, json: { packages: [] } }] });
  const plan = fixturePlan();
  await replanPackages(b, { sentence: "s", packId: "game.paddle_court", title: "P", brief: v2Brief(), packContract: "(c)", kept: plan.slice(0, 2), failed: [{ spec: plan[2] as PackageSpec, cause: "rounds", detail: "x" }], dependants: [] }, { verbs });
  assert.equal(b.calls[0]?.req.timeoutMs, PLANNER_TIMEOUT_MS);
});

test("round 3: the tofu bot must press every verb of the design (verbs_used = the verb count); the root copies the house cameras, declares no wide view, shows the resource bars", async () => {
  const { judgeTofu, tofuMetricsFor, tofuPlannerText } = await import("../tofu.js");
  const rows = tofuMetricsFor(duelTemplate, 5);
  assert.equal(rows.find((m) => m.id === "verbs_used")?.min, 5);
  const all = { feedback_f: 1, skill_spread: 0.4, skill_variants: 4, idle_max_f: 42, tell_min_f: 12, tells: 57, pressure_waves: 4, lead_change_share: 1, close_rounds: 1, contact_types: 5, one_sided_contacts: 0 };
  // The crazy proof's figures (blockout round 1): every row passed, yet no strip showed a parry, a roll or a bash.
  assert.match(judgeTofu({ ...all, verbs_used: 2 }, rows, "tests/bot_tofu.gd").line, /verbs_used 2 \(wants >= 5; item the whole exchange/);
  assert.equal(judgeTofu({ ...all, verbs_used: 5 }, rows, "tests/bot_tofu.gd").ok, true);
  assert.match(tofuPlannerText(duelTemplate, 5), /`verbs_used` >= 5/);
  const { renderPlannerPrompt } = await import("../designer.js");
  const { FAKE_VERBS_FILE } = await import("../verbs.js");
  const text = renderPlannerPrompt({ sentence: "a fight", packId: "game.x", title: "X", brief: { ...v2Brief(), concept: { ...sampleConcept(), template: duelTemplate } }, packContract: "(c)" }, { verbs: JSON.parse(fs.readFileSync(FAKE_VERBS_FILE, "utf8")) });
  assert.match(text, /copy its cameras \(the duel: over the shoulder offset to the side, and a side view[^]*\*\*Every\s+camera a package declares is filmed and judged at every milestone\*\*[^]*resource bars the template uses \(the duel: health,\s+stamina and posture[^]*\*\*The tofu bot plays every verb\.\*\*/);
  assert.match(text, /\*\*Flat shapes are not bare bodies\.\*\*[^]*gen\/arms\.gd[^]*data\/rivals\.json/);
  assert.match(templateExcerpt(duelTemplate, "builder"), /gen\/arms\.gd: the weapons/);
  assert.match(text, /`verbs_used` >= 2/, "the fixture design has two verbs");
});

test("round 5: every concept step sees the earlier designs of its sentence in its mode; the third soul-swap crazy is sent back", async () => {
  const { takenFor, earlierText, earlierProblems } = await import("../concepts.js");
  const site = path.join(tempDir("earlier"), "site");
  const ev = (job: string, seq: number, body: object): string => JSON.stringify({ v: 1, seq, ts: "2026-11-22T01:00:00.000Z", job, ...body });
  const make = (job: string, crazy: boolean, hook: string, pitch: string): void => {
    fs.mkdirSync(path.join(site, job), { recursive: true });
    const concept = { ...sampleConcept(), hook, candidates: sampleConcept().candidates.map((c, i) => (i === sampleConcept().chosen ? { ...c, pitch } : c)) };
    fs.writeFileSync(path.join(site, job, "job.jsonl"), [ev(job, 1, { type: "job_created", sentence: "A fight in a colosseum", packId: "game.fight", title: "Fight", ...(crazy ? { creativity: "crazy" } : {}) }), ev(job, 2, { type: "brief_set", brief: { ...v2Brief(), concept }, estimate: { packages: 6, wallMinutes: 60, tokens: 900000 } })].join("\n") + "\n");
  };
  // The hooks of 22 Nov, verbatim: the standard proofs broke the walls; the crazy ones swapped souls on a parry.
  make("fight-1", false, "wall splats smash the arena open and breaches drop rivals to lions", "Colosseum duel where wall splats shatter the arena wall, and a splat through the breach drops rivals to lions.");
  make("fight-2", true, "parrying a heavy swaps your soul into your rival's body", "Parry a heavy and souls swap: you wake inside your rival's body, his health and archetype, fighting your old self.");
  const crazy = takenFor(site, "a fight in a colosseum", "crazy");
  assert.deepEqual([crazy.taken?.length, crazy.earlier?.map((c) => c.hook)], [1, ["parrying a heavy swaps your soul into your rival's body"]]);
  assert.match(earlierText(crazy.earlier), /# Earlier designs of this same sentence in this mode[^]*parrying a heavy swaps your soul[^]*The HOOK must come from another idea family/);
  const third = { ...sampleConcept(), hook: "a perfect parry swaps your soul into the rival's body", candidates: sampleConcept().candidates.map((c, i) => (i === sampleConcept().chosen ? { ...c, pitch: "Souls-like duel where a perfect parry swaps your soul into the rival's body." } : c)) };
  assert.match(earlierProblems(third, crazy.earlier, "a fight in a colosseum").join(""), /the chosen hook is too close to an earlier design of this sentence \("parrying a heavy swaps your soul into your rival's body"\): they share parry, swap, soul, body/);
  // Another family passes: the hook of the -2 room's own candidate list ("Night games: torches ring the sand ...").
  assert.deepEqual(earlierProblems({ ...third, hook: "every parry snuffs a torch until the duel ends in darkness" }, crazy.earlier, "a fight in a colosseum"), []);
  // And the standard walls: the fourth "breach" hook is sent back too.
  const std = takenFor(site, "a fight in a colosseum", undefined);
  assert.match(earlierProblems({ ...third, hook: "wall splats break the arena open into a lion pit" }, std.earlier, "a fight in a colosseum").join(""), /too close/);
  assert.equal(earlierText(undefined), "");
});
