// H1f of the day run of 25 Nov 2026 (editor hardening, round 6), from lanes G2 (robot football) and G4 (half court).
// Each test failed on main 2c2a16f and passes now.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, foremanFor, readEvents, sampleConcept, scriptWith, tempDir, tempJob, v2Brief } from "./helpers.js";
import { spawnSync } from "node:child_process";
import { JobLog } from "../joblog.js";
import type { FakeStep } from "../builder/fake.js";
import type { Brief, JobEvent, PackageSpec } from "../events.js";
import { REPO_ROOT } from "../paths.js";
import { HOCKEY_COURT, courtOf, tofuMetricsFor, tofuPlannerText } from "../tofu.js";
import { lookNotPlay } from "../playsame.js";
import { personDecisionsText } from "../phases.js";
import { notesKept } from "../quality.js";
import { whatChangedNote } from "../fastchange.js";
import { main } from "../cli.js";
import { grantedScope, pathsIn } from "../scopegrant.js";

after(cleanup);

// ---------------------------------------------------------------- 1. a person's yes widens the scope

test("H1f 1 (G4 events 232-243: \"You may change scripts/main.gd, scripts/core and scripts/bodies\", and the Foreman dropped all three as out of scope): a person's yes to a scope question widens the package's scope for that change, and the merge says what was widened", async () => {
  const job = tempJob("h1f-scope");
  assert.equal((await foremanFor(job, { promoteTo: "job" }).foreman.run()).jobState?.state, "done");
  const log = JobLog.open(job.jobDir);
  log.append({ type: "change_requested", text: "Make the rival paddle twice as fast.", package: "paddle_ai" });
  log.close();
  const steps: FakeStep[] = [
    { match: { role: "builder", package: "paddle_ai", promptIncludes: "Answer to your question" }, write: { "scripts/main.gd": "extends Node\n# the rival's speed cap lives here: raised\n" }, text: "Raised the cap in main.gd.\nDEVIATIONS: scripts/main.gd changed, as allowed" },
    { match: { role: "builder", package: "paddle_ai" }, text: "The speed cap is in the entry script.\nQUESTION: May the fix touch scripts/main.gd, which is outside my scope?" },
  ];
  assert.equal((await foremanFor(job, { promoteTo: "job", script: scriptWith(steps) }).foreman.run()).jobState?.state, "paused");
  assert.equal(await main(["answer", job.jobDir, "paddle_ai", "Yes. You may change scripts/main.gd so the rival is faster."], () => {}), 0);
  const from = readEvents(job.jobDir).at(-1)?.seq ?? 0;
  const s = await foremanFor(job, { promoteTo: "job", script: scriptWith(steps) }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > from);
  assert.ok(!later.some((e) => e.type === "package_state" && /dropped out-of-scope files: scripts\/main\.gd/.test(e.detail ?? "")), "not dropped");
  const merge = later.find((e) => e.type === "merge" && e.package === "paddle_ai");
  assert.ok(merge?.type === "merge" && merge.files.includes("scripts/main.gd"), JSON.stringify(merge));
  const note = later.find((e) => e.type === "note" && e.text.startsWith("[foreman] scope widened for this change"));
  assert.equal(note?.type === "note" ? note.text : "", "[foreman] scope widened for this change, on the person's answer: paddle_ai may change scripts/main.gd; merged outside its plan scope: scripts/main.gd");
  assert.match(fs.readFileSync(path.join(job.jobDir, "pack", "scripts", "main.gd"), "utf8"), /raised/);
  // G4's own words, as the answer read them
  assert.deepEqual(pathsIn("Yes, the frame-time failure. You may change scripts/main.gd, scripts/core and scripts/bodies so six players run within the budget."), ["scripts/main.gd", "scripts/core/**", "scripts/bodies/**"]);
  // a no, or an answer to a question that is not about scope, widens nothing
  const ev = (seq: number, body: Record<string, unknown>): JobEvent => ({ v: 1, seq, ts: "t", job: "j", ...body }) as unknown as JobEvent;
  assert.deepEqual(grantedScope([ev(1, { type: "reopened", package: "x", reason: "r" }), ev(2, { type: "question", package: "x", text: "May the fix touch scripts/main.gd outside my scope?" }), ev(3, { type: "answer", package: "x", text: "No, keep to your files: scripts/main.gd is core's.", by: "player" })], "x"), []);
  assert.deepEqual(grantedScope([ev(1, { type: "question", package: "x", text: "Which colour, red or blue?" }), ev(2, { type: "answer", package: "x", text: "Yes, blue, see data/skin.json", by: "player" })], "x"), []);
});

// ---------------------------------------------------------------- 2. court-scaled tofu bounds; more toy seeds when unclear

const FX = path.join(REPO_ROOT, "foreman", "fixtures", "h1e");
const brief = (f: string): Brief => JSON.parse(fs.readFileSync(path.join(FX, f), "utf8")) as Brief;

test("H1f 2a (the Director's answer: team ball games get bounds scaled to the court): G4's 15 x 11 m half court with six players counts a scrum within 1.5 m, not the hockey's 5 m on 1800 m², in the plan's rows and in every judgement", () => {
  const g4 = courtOf(brief("g4-brief.json"));
  assert.deepEqual(g4, { area: 165, players: 6 });
  assert.deepEqual(courtOf(brief("g2-brief.json")), { area: 2560, players: 6 }, "G2's 64 x 40 m pitch, three a side");
  const row = tofuMetricsFor({ id: "arcade_sport" } as never, 5, g4).find((m) => m.id === "scrum_share");
  assert.equal(row?.max, 0.3, "the bound is the house game's");
  assert.equal(row?.item, "spacing, no scrum: the share of live frames in which 4 or more field players (not keepers) stand within 1.5 m of the ball or puck (scaled to this court, 165 m² and 6 players, from the house hockey's 4 of 6 within 5 m on 1800 m²)");
  assert.match(tofuPlannerText({ id: "arcade_sport" } as never, 5, g4), /`scrum_share` <= 0\.3 \(checklist item spacing, no scrum: the share of live frames in which 4 or more field players \(not keepers\) stand within 1\.5 m/);
  const hockey = tofuMetricsFor({ id: "arcade_sport" } as never, 5, HOCKEY_COURT).find((m) => m.id === "scrum_share");
  assert.match(hockey?.item ?? "", /4 or more field skaters \(not goalies\) stand within 5 m of the puck/, "the hockey's own court: the row as it was");
  assert.equal(courtOf({ rules: "a duel on a bridge" }), undefined, "no court, no scaling");
});

test("H1f 2b (the Director's answer: a toy unclear at 20 seeds is played on up to 80, inside the cache and the pool; \"not clear yet\" only if 80 is still unclear): the stand-in lab's noisy toys are measured at 80, the F ability that changes nothing stays at 20", () => {
  const cache = path.join(tempDir("h1f-toys80"), "cache");
  const r = spawnSync(process.execPath, [path.join(REPO_ROOT, "engine", "cores", "rink", "lab", "check_cartridge.mjs"), path.join(REPO_ROOT, "foreman", "fixtures", "h1", "harbour.g1.cartridge.json"), "--toys", "--json-only"], { encoding: "utf8", env: { ...process.env, TL_RINKLAB_EXE: path.join(REPO_ROOT, "foreman", "fixtures", "h1", "fake-rinklab.mjs"), TL_RINK_CHECK_CACHE: cache } });
  const line = JSON.parse((r.stdout ?? "").trim().split(/\r?\n/).at(-1) ?? "{}") as { toys: { toy: string; matches: number; clear: string }[] };
  const by = (w: string) => line.toys.find((t) => t.toy.startsWith(w));
  assert.equal(by("the F ability")?.matches, 20, "clear at 20 (no match plays differently): not played again");
  assert.equal(by("the F ability")?.clear, "nothing");
  for (const w of ["the pickups", "the fast-ice zones", "the slow-ice zones"]) {
    assert.equal(by(w)?.matches, 80, `${w}: unclear at 20, played to 80`);
    assert.equal(by(w)?.clear, "not_clear", `${w}: the stand-in's noise is still unclear at 80, so it is said so`);
  }
  assert.equal(fs.readdirSync(cache).length, 2, "both stages inside the cache");
  const again = spawnSync(process.execPath, [path.join(REPO_ROOT, "engine", "cores", "rink", "lab", "check_cartridge.mjs"), path.join(REPO_ROOT, "foreman", "fixtures", "h1", "harbour.g1.cartridge.json"), "--toys", "--json-only"], { encoding: "utf8", env: { ...process.env, TL_RINKLAB_EXE: path.join(REPO_ROOT, "foreman", "fixtures", "h1", "fake-rinklab.mjs"), TL_RINK_CHECK_CACHE: cache } });
  assert.equal((JSON.parse((again.stdout ?? "").trim().split(/\r?\n/).at(-1) ?? "{}") as { cached?: boolean }).cached, true, "the second check reads both stages from the cache");
});

// ---------------------------------------------------------------- 3. the look changed, the play did not

function designJob(label: string, reactions: Record<string, unknown>[] = []): ReturnType<typeof tempJob> {
  const job = tempJob(label);
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  const b = JSON.parse(lines[1] as string) as { brief: Brief };
  b.brief = { ...v2Brief(), concept: sampleConcept() };
  lines[1] = JSON.stringify(b);
  const plan = JSON.parse(lines[3] as string) as { packages: PackageSpec[] };
  for (const p of plan.packages) p.milestone = "blockout";
  lines[3] = JSON.stringify(plan);
  // the person's reactions to the aspect cards, before the plan (as Create writes them)
  const at = JSON.parse(lines[1] as string) as { seq: number; ts: string; job: string };
  const head = lines.slice(0, 2);
  const tail = lines.slice(2).map((l) => JSON.parse(l) as { seq: number }).map((e) => JSON.stringify({ ...e, seq: e.seq + reactions.length }));
  const added = reactions.map((r, i) => JSON.stringify({ v: 1, seq: at.seq + 1 + i, ts: at.ts, job: at.job, type: "aspect_reacted", ...r }));
  fs.writeFileSync(file, [...head, ...added, ...tail].map((l) => l + "\n").join(""));
  return job;
}
const criticAt = (attempt: number, ok: boolean, notes: string[]): FakeStep => ({ match: { role: "critic", attempt }, json: { ok, scores: { silhouette: 0.8, readability: ok ? 0.8 : 0.4, style_consistency: 0.7, shows_play: 0.7, fun_promise: ok ? 0.8 : 0.3, kill_criteria: 0.9 }, notes, ...(ok ? {} : { package: "court" }) } });
const courtRound = (round: number, mark: string): FakeStep => ({ match: { role: "builder", package: "court", round }, write: { "data/court.json": `{"width_m": 16, "depth_m": 9, "wall_height_m": 1.2, "mark": "${mark}"}\n` }, text: "Done.\nDEVIATIONS: none" });

test("H1f 3 (G2: about 70 min of critic rounds changed the score panel, the radar, the crowd and the robots; the newcomer match stayed frame for frame the same): when the critic's reasons were about play and every bot plays exactly as before the revise round, the person is told \"the look changed, the play did not\"", async () => {
  const job = designJob("h1f-look");
  const steps = [criticAt(1, false, ["the contact reads as a clump: four bodies pile into one blob, no hit-stop"]), criticAt(2, true, ["the court reads now"]), courtRound(2, "a brighter court")];
  const s = await foremanFor(job, { critic: true, promoteTo: "job", script: scriptWith(steps) }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const evs = readEvents(job.jobDir);
  const note = evs.find((e) => e.type === "note" && e.text.startsWith("[foreman] the look changed, the play did not"));
  // H1g: the bots in words ("the rally bot (tests/bot_rally.gd)"; it was the bare file name)
  assert.match(note?.type === "note" ? note.text : "", /^\[foreman\] the look changed, the play did not: the critic's reasons were about play \("contact"\), and after revise round 1 the rally bot \(tests\/bot_rally\.gd\) plays frame for frame as before \(the same moments at the same frames, the same counted figures\)\. The round changed how the game looks, not how it plays$/);
  const ms = evs.filter((e) => e.type === "milestone").at(-1);
  assert.match(ms?.type === "milestone" ? ms.summary : "", /the look changed, the play did not/);
  // a bot that counts differently after the round: nothing to say (the play changed)
  const snap = (JSON.parse(fs.readFileSync(path.join(job.jobDir, "reports", "quality-blockout-r1", "look.json"), "utf8")) as { atSeq: number }).atSeq;
  const host = { dir: (...p: string[]) => path.join(job.jobDir, ...p), events: evs } as never;
  assert.ok(lookNotPlay(host, snap, 1, ["the bots pile up"]) !== undefined);
  const lastBot = evs.filter((e) => e.type === "verify" && e.verb === "bot" && e.seq > snap).at(-1);
  const file = path.join(job.jobDir, ...(lastBot?.type === "verify" ? lastBot.report : "").split("/"));
  const r = JSON.parse(fs.readFileSync(file, "utf8")) as { bot: { result: Record<string, unknown> } };
  r.bot.result["moments"] = { goal: [301] };
  fs.writeFileSync(file, JSON.stringify(r));
  assert.equal(lookNotPlay(host, snap, 1, ["the bots pile up"]), undefined, "the bot counted a moment at another frame: the play changed");
  // reasons about the picture only: nothing to say
  assert.equal(lookNotPlay({ dir: (...p: string[]) => path.join(job.jobDir, ...p), events: evs } as never, 0, 1, ["the walls are grey and the sky is flat"]), undefined);
});

// ---------------------------------------------------------------- 4. the person's notes on kept cards

test("H1f 4 (G4 event 14: the camera card kept with \"keep the camera steady behind me like a TV game, no swinging\"; the game's camera turned with the player and no look said so): a note on a kept card is a requirement the critic checks, and a note not kept makes the look NOT ok", async () => {
  // the words the critic reads, from G4's real reactions
  const g4 = brief("g4-brief.json");
  const text = personDecisionsText({ brief: g4, reactions: { close_camera: { choice: "keep", note: "keep the camera steady behind me like a TV game, no swinging", seq: 14 }, spring: { choice: "drop", note: "I just want plain street ball, no speed boost off screens", seq: 13 } } } as never);
  assert.match(text, /A NOTE on a KEPT or CHOSEN aspect is the person's REQUIREMENT, as binding as a drop: check each against the frames \("[^"]+": "keep the camera steady behind me like a TV game, no swinging"\); for each one the frames do not keep, write a note that starts "person's note not kept:"/);
  // the look: a critic that says ok but names the note as not kept does not pass it
  const job = designJob("h1f-note", [{ aspect: "court", choice: "keep", note: "keep the camera steady, no swinging" }]);
  const steps = [criticAt(1, true, ["person's note not kept: \"keep the camera steady, no swinging\": the hero camera swings with the paddle (image 2)", "the court reads"]), criticAt(2, true, ["the camera holds still now"]), courtRound(2, "a steady camera")];
  const { foreman, builder } = foremanFor(job, { critic: true, promoteTo: "job", script: scriptWith(steps) });
  const s = await foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const prompt = builder.calls.find((c) => c.req.meta?.role === "critic")?.req.prompt ?? "";
  assert.match(prompt, /KEPT "Walled court" \(the person's note: "keep the camera steady, no swinging"\)[^]*A NOTE on a KEPT or CHOSEN aspect is the person's REQUIREMENT/);
  const revise = builder.calls.filter((c) => c.req.meta?.package === "court").at(-1)?.req.prompt ?? "";
  assert.match(revise, /revise round 1 of 2 \(milestone blockout\)[^\n]*Critic's notes: person's note not kept: "keep the camera steady, no swinging"/);
  assert.equal(notesKept({ ok: true, scores: {}, notes: ["fine"], report: "r" })?.ok, true);
});

// ---------------------------------------------------------------- 5. what changed, in the person's words first

test("H1f 5 (G2 v0.1.1: \"what changed ... files: data/tuning.json, scripts/sim/sim.gd, ...\" named files, not what the person will see): after the person's words, the builder's own words of what changed, then the files", () => {
  const evs = fs.readFileSync(path.join(FX, "g2-change-events.jsonl"), "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l) as JobEvent);
  const line = whatChangedNote(evs, "0.1.1");
  assert.ok(line.startsWith("[foreman] what changed in v0.1.1 (since v0.1.0): asked \"When I slide into a robot it should be launched into the air"), line);
  assert.match(line, /; what you will see, in the builder's words: Any slide at 6 m\/s or faster into an upright opponent now floors it [^/]* \/ The slider that floors a non-carrier still lies 40 frames [^/]* \/ The captain's slide \(robot 0\) now also hits and floors his own mates\.[^;]*\(and 12 more in its note\); files: data\/tuning\.json, scripts\/sim\/sim\.gd, scripts\/view\/show\.gd, tests\/bot_player\.gd\na test was changed: tests\/bot_player\.gd \(core\)$/); // D27 item 21: a test the change changed gets its own line
  assert.ok(line.indexOf("asked") < line.indexOf("builder's words") && line.indexOf("builder's words") < line.indexOf("files:"), "the person's words, then what they will see, then the files");
});
