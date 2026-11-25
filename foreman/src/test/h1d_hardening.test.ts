// H1d of the day run of 25 Nov 2026 (editor hardening, round 4), from lane G1's Arsenal hockey round 2
// (d25-arsenal PROOF-G1.md sections 6-11, its job's events). Each test failed on main 1969842 and passes now.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, foremanFor, readEvents, scriptWith, tempDir, tempJob } from "./helpers.js";
import { JobLog, rebuildState } from "../joblog.js";
import { FakeBuilder, type FakeStep } from "../builder/fake.js";
import type { Foreman } from "../foreman.js";
import type { JobEvent, PackageSpec } from "../events.js";
import type { GateHost } from "../p10gate.js";
import { main } from "../cli.js";
import { RINK_ROUTE } from "../coreroute.js";
import { coreChangeOwner } from "../coreowner.js";
import { askedAgain, plainQuestion } from "../asktwice.js";
import { removedSince } from "../removal.js";
import { askedFigureMiss, toyLines } from "../rinkjudge.js";
import { cartridgeChange } from "../coregate.js";
import { whatChangedNote } from "../fastchange.js";
import { REPO_ROOT } from "../paths.js";

after(cleanup);

// ---------------------------------------------------------------- 1. a version that errors in a window is not promoted

test("H1d 1 (G1 events 354-363: v0.1.3 promoted although all eight promotion pictures said ok: false, a commentary line with no voice): a script error in the promotion pictures refuses the promotion, in words; the earlier version stays", async () => {
  const job = tempJob("h1d-window");
  const s1 = await foremanFor(job, { promoteTo: "job" }).foreman.run();
  assert.equal(s1.jobState?.state, "done");
  const log = JobLog.open(job.jobDir);
  log.append({ type: "change_requested", text: "Let the commentator call the faceoff.", package: "core" });
  log.close();
  const voice: FakeStep = { match: { role: "builder", package: "core" }, write: { "scripts/main.gd": "extends Node\n# the faceoff call FAKE_WINDOW_ERROR\n" }, text: "A faceoff call.\nDEVIATIONS: none" };
  const s = await foremanFor(job, { promoteTo: "job", script: scriptWith([voice]) }).foreman.run();
  assert.equal(s.jobState?.state, "failed", JSON.stringify(s.jobState));
  assert.match(s.jobState?.reason ?? "", /^promotion refused: in a window, as a person plays it, the game throws script errors in 2 of 2 promotion picture\(s\): rink audio: no voice for commentary line 'faceoff\.drop\.04' \(scripts\/main\.gd:2\)\. The headless checks do not meet them, so they passed\. A version that errors in front of the player is not promoted\. Earlier version v0\.1\.0 stays the one to play\. The change was NOT made\./);
  const st = rebuildState(job.jobDir, { write: false });
  assert.equal(st.promotions.length, 1, "no second promotion");
  assert.ok(!fs.readFileSync(path.join(job.jobDir, "pack", "scripts", "main.gd"), "utf8").includes("FAKE_WINDOW_ERROR"), "pack/ is v0.1.0 again");
  const shots = readEvents(job.jobDir).filter((e) => e.type === "verify" && e.verb === "capture" && /promotion2-capture-/.test(e.report));
  assert.ok(shots.length >= 2 && shots.every((e) => e.type === "verify" && !e.ok));
});

// ---------------------------------------------------------------- 2. play words go to the cartridge

/** Lane G1's plan (plan_set of three-against-three-hockey-20261125-1), word for word. */
const G1_PLAN = [
  { id: "base", kind: "base", scope: ["assets/**", "data/**", "gen/**", "scripts/**", "tests/**"] },
  { id: "cartridge", scope: ["data/harbour.cartridge.json", "data/match.json"] },
  { id: "harbour", scope: ["scripts/main.gd", "scripts/harbour.gd", "scripts/harbour_toys.gd", "data/tuning.json", "data/harbour_venue.json", "data/drill_slush100.cartridge.json", "tests/bot_harbour.gd"] },
  { id: "skin", scope: ["data/skin.json", "data/harbour_commentary.json"] },
] as unknown as PackageSpec[];
const CHANGE3 = "Using the toys well should win matches. Let my bubble come back by itself eight seconds after I pop it, as often as I like. And make the green spots hand out a trick worth having: a cannon shot that flattens anyone in its way, or a big hip check.";

test("H1d 2 (G1 event 280: change 3 went to `harbour`, the drawing, 33.5 min and 3.98 M tokens, not made): on a core game play words go to the cartridge's owner even when the Planner names another package that is not the base; a picture and the skin's words stay where the Planner put them", () => {
  const moved = coreChangeOwner(G1_PLAN, RINK_ROUTE, "harbour", CHANGE3);
  assert.equal(moved.owner, "cartridge");
  assert.match(moved.why ?? "", /these words ask for play, not a picture: the change goes to "cartridge", which owns the game's cartridge \(data\/harbour\.cartridge\.json, data\/match\.json\)/);
  assert.deepEqual(coreChangeOwner(G1_PLAN, RINK_ROUTE, "harbour", "make the bubble glow brighter and draw the arrows yellow"), { owner: "harbour" });
  assert.deepEqual(coreChangeOwner(G1_PLAN, RINK_ROUTE, "skin", "rename the teams the Otters and the Gulls"), { owner: "skin" });
  assert.deepEqual(coreChangeOwner(G1_PLAN, undefined, "harbour", CHANGE3), { owner: "harbour" }, "off a core nothing moves");
});

// ---------------------------------------------------------------- 3 and 4: the chip, and one question per change

const AI_JSON = '{\n "reaction_frames": 8,\n "max_speed_mps": 6,\n "error_m": 0.3\n}\n';
const AI_GD = "extends RefCounted\n\nfunc decide(ball_y: float, paddle_y: float, tuning: Dictionary) -> float:\n\treturn signf(ball_y - paddle_y)\n";

async function changedJob(label: string, steps: FakeStep[]): Promise<{ job: ReturnType<typeof tempJob>; first: Awaited<ReturnType<Foreman["run"]>> }> {
  const job = tempJob(label);
  const done = await foremanFor(job, { promoteTo: "job" }).foreman.run();
  assert.equal(done.jobState?.state, "done");
  const log = JobLog.open(job.jobDir);
  log.append({ type: "change_requested", text: "Make the rival paddle twice as fast.", package: "paddle_ai" });
  log.close();
  const first = await foremanFor(job, { promoteTo: "job", script: scriptWith(steps) }).foreman.run();
  return { job, first };
}

test("H1d 3 (G1 events 292-301: the \"Yes, let it\" chip sent the person's answer, not the request, so the cartridge builder never saw it): the other package's change request is the person's request, then the question and the answer", async () => {
  const steps: FakeStep[] = [
    { match: { role: "builder", package: "paddle_ai", promptIncludes: "Answer to your question" }, write: { "data/ai.json": AI_JSON, "scripts/paddle_ai.gd": AI_GD }, text: "Done.\nDEVIATIONS: none" },
    { match: { role: "builder", package: "paddle_ai" }, text: "Its speed is the core's.\nQUESTION: May core be changed so that the rival paddle moves twice as fast?" },
    { match: { role: "builder", package: "core" }, write: { "scripts/main.gd": "extends Node\n" }, text: "Faster.\nDEVIATIONS: none" },
  ];
  const { job, first } = await changedJob("h1d-chip", steps);
  assert.equal(first.jobState?.state, "paused");
  assert.equal(await main(["answer", job.jobDir, "paddle_ai", "Yes, let it change what it needs.", "--change", "core"], () => {}), 0);
  const asked = readEvents(job.jobDir).at(-1);
  assert.ok(asked?.type === "change_requested");
  assert.equal(asked.package, "core");
  assert.equal(asked.text, "Make the rival paddle twice as fast.\n(paddle_ai could not make it alone and asked: \"May core be changed so that the rival paddle moves twice as fast?\"; the person answered: \"Yes, let it change what it needs.\")");
});

test("H1d 4 (G1 events 288, 316, 324: harbour asked the same thing after every answer, 3 times, 4 builder runs, 13.5 min, the 2nd and 3rd in JSON): a package asks once per change; asked again it is told plainly it cannot be done (off a core), or the change goes back to routing (on a core); a question is words, not JSON", async () => {
  const again = "QUESTION: Will core set `ai` to the single entry `{\"max_speed_mps\":12,\"reaction_frames\":4}` and nothing else?";
  const steps: FakeStep[] = [
    { match: { role: "builder", package: "paddle_ai", promptIncludes: "Answer to your question" }, text: `Still not mine.\nDEVIATIONS: speed not changed\n${again}` },
    { match: { role: "builder", package: "paddle_ai" }, text: "Its speed is the core's.\nQUESTION: May core be changed so that the rival paddle moves twice as fast?" },
  ];
  const { job, first } = await changedJob("h1d-twice", steps);
  assert.equal(first.jobState?.state, "paused");
  assert.equal(await main(["answer", job.jobDir, "paddle_ai", "No, do it with your own files."], () => {}), 0);
  const from = readEvents(job.jobDir).at(-1)?.seq ?? 0;
  const s = await foremanFor(job, { promoteTo: "job", script: scriptWith(steps) }).foreman.run();
  const later = readEvents(job.jobDir).filter((e) => e.seq > from);
  assert.equal(later.filter((e) => e.type === "question").length, 0, "not asked a second time");
  const note = later.find((e) => e.type === "note" && e.text.startsWith("[foreman] asked again after your answer: "));
  assert.equal(note?.type === "note" ? note.text : "", "[foreman] asked again after your answer: paddle_ai cannot make this change: It asked \"May core be changed so that the rival paddle moves twice as fast?\", you answered \"No, do it with your own files.\", and it asks again (\"Will core set ai to the single entry (the settings it names above) and nothing else?\"). It is not asked a third time: the change was NOT made, and the files paddle_ai merged before stay. Say it again in other words, or name what matters most.");
  assert.notEqual(s.jobState?.state, "paused", "the job does not wait for a third answer");
  assert.equal(plainQuestion("Will the cartridge package set `game.abilities` to the single entry `{\"kind\":\"shield\",\"trigger\":\"mode\",\"duration_frames\":240,\"cooldown_frames\":480}` (no `charges`)?"), "Will the cartridge package set game.abilities to the single entry (the settings it names above) (no charges)?");
  // on a core (G1's plan and words): the change goes back to routing, to the cartridge's owner, with the request and the answer
  const appended: Record<string, unknown>[] = [];
  const h = { s: { plan: G1_PLAN, packages: { cartridge: { state: "promoted" }, harbour: { state: "running" } } }, pkg: () => ({ changes: [CHANGE3] }), append: (e: Record<string, unknown>) => (appended.push(e), e) } as unknown as Parameters<typeof askedAgain>[0];
  const said = askedAgain(h, RINK_ROUTE, "harbour", 6, "Will the cartridge package set game.abilities to the single entry {\"kind\":\"shield\"}?", { question: "Can the cartridge package apply the three ability entries above?", answer: "Yes: the bubble that comes back by itself every eight seconds, and nothing else on F." });
  assert.match(said, /^harbour cannot make this change: .*\. The change goes to cartridge, which owns the game's settings, with your request and your answer/);
  const routed = appended.find((e) => e["type"] === "change_requested");
  assert.equal(routed?.["package"], "cartridge");
  assert.ok(String(routed?.["text"]).startsWith(CHANGE3));
});

// ---------------------------------------------------------------- 5. removals from the game's own diff

test("H1d 5 (G1 event 362: v0.1.3's note said \"removed: a shield\", which was the drill file's, not the game's): removals come from the cartridge the game plays", () => {
  const fx = path.join(REPO_ROOT, "foreman", "fixtures", "h1d");
  assert.deepEqual(removedSince(path.join(fx, "v012"), path.join(fx, "v013")), [{ where: "game.abilities", what: "a slow_puck" }]);
});

// ---------------------------------------------------------------- 6. a figure the person named

test("H1d 6 (G1 change 1: \"so a match lasts about three minutes\" became 2.1 min, \"measured, no warning\"): a minutes or goals figure in the person's words is set against the figure after the change, and a miss is said in words, on its own line of the what-changed note", async () => {
  const words = "The matches are over in a minute and a goal falls every ten seconds. Make goals much harder to score so a match lasts about three minutes.";
  assert.equal(askedFigureMiss(words, { pro_minutes: 2.1, pro_goals_a_match: 7.7 }), "you asked for matches of about 3 minutes; they last 2.1 min at pro now (thirdjam's regular playtester, measured after the change): the change falls short of what you asked");
  assert.equal(askedFigureMiss(words, { pro_minutes: 2.8 }), undefined, "met within a quarter");
  assert.equal(askedFigureMiss("make the goals bigger", { pro_minutes: 1 }), undefined);
  // the diff path, as G1's change 1 ran it (event 234's diff; the check's figures before and after)
  const dir = tempDir("h1d-figure");
  fs.mkdirSync(path.join(dir, "pack", "data"), { recursive: true });
  fs.copyFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "h1", "harbour.g1.cartridge.json"), path.join(dir, "pack", "data", "harbour.cartridge.json"));
  fs.writeFileSync(path.join(dir, "pack", "data", "match.json"), JSON.stringify({ difficulty: "rookie", cartridge: "harbour.cartridge.json" }));
  const appended: Record<string, unknown>[] = [];
  let calls = 0;
  const builder = new FakeBuilder({ steps: [{ match: { role: "cartridge" }, json: { changes: { "game.rink.goal_width_m": 2.8, "game.skater.goalie.reach_m": 1.4, "game.skater.goalie.block_height_m": 0.9 }, why: "smaller nets and better keepers" } }] });
  const h = {
    o: { builder, coreCheck: async () => (calls++ === 0 ? { code: 0, figures: { pro_minutes: 1.5, pro_goals_a_match: 6.8 }, summary: "measured, no warning" } : { code: 0, figures: { pro_minutes: 2.1, pro_goals_a_match: 7.7 }, summary: "measured, no warning" }), verifier: { location: { engineDir: path.join(REPO_ROOT, "engine"), preArgs: [] } } },
    s: { plan: G1_PLAN, lastSeq: 230, notes: [], packages: {}, order: G1_PLAN.map((p) => p.id), brief: { concept: { template: { id: "rink_sport" } } }, title: "Harbour", sentence: "hockey" },
    events: [],
    dir: (...p: string[]) => path.join(dir, ...p),
    rel: (abs: string) => path.relative(dir, abs).split(path.sep).join("/"),
    pkg: () => ({ round: 2, changes: [words] }),
    append: (e: Record<string, unknown>) => (appended.push(e), e),
    logGenerateCalls: () => {},
  } as unknown as GateHost;
  assert.equal(await cartridgeChange(h, "cartridge", 2, words), true);
  const miss = appended.find((e) => e["type"] === "note" && String(e["text"]).startsWith("[foreman] not what you asked: "));
  assert.equal(miss?.["text"], "[foreman] not what you asked: you asked for matches of about 3 minutes; they last 2.1 min at pro now (thirdjam's regular playtester, measured after the change): the change falls short of what you asked");
  const ev = (seq: number, body: Record<string, unknown>): JobEvent => ({ v: 1, seq, ts: "t", job: "j", ...body }) as unknown as JobEvent;
  const log = [ev(1, { type: "promoted", packId: "p", version: "0.1.0", dest: "promoted/p" }), ev(2, { type: "change_requested", text: words }), ev(3, { ...(miss as object), type: "note", package: "cartridge", round: 2 }), ev(4, { type: "merge", package: "cartridge", round: 2, files: ["data/harbour.cartridge.json"] })];
  assert.match(whatChangedNote(log, "0.1.1"), /files: data\/harbour\.cartridge\.json\nnot what you asked: you asked for matches of about 3 minutes; they last 2\.1 min at pro now/);
});

test("H1d (the Director's H1c decisions): a toy that costs the player is said in words on the card, not as a check warning; the base's README offers engine code as a cost the person decides, never an order", () => {
  // H1e: a cost is said only when the paired matches show it (here 0 won only with it, 5 only without it), with the counts
  assert.deepEqual(toyLines([{ toy: "the slow-ice zones (2)", measured: true, matches: 20, wins_with: 8, wins_without: 13, points: -25, goal_diff: -1.2, changed: 20, won_only_with: 0, won_only_without: 5 }]), ["The slow-ice zones: costs you (won only with it 0, only without it 5, of 20)"]);
  const readme = fs.readFileSync(path.join(REPO_ROOT, "engine", "templates", "rink_game", "README.md"), "utf8");
  assert.ok(!/needs a core patch/.test(readme), "no order");
  assert.match(readme, /the person\s+decides whether to pay that\. Never order it: offer the nearest data-only way first/);
});
