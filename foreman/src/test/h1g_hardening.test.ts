// H1g of the day run of 25 Nov 2026 (editor hardening, round 7): the Director's answers to H1f's questions, from lanes
// G2 (robot football) and G4 (half court). Each test failed on main fea8abb and passes now.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawn } from "node:child_process";
import { cleanup, foremanFor, readEvents, sampleConcept, scriptWith, tempDir, tempJob, v2Brief } from "./helpers.js";
import type { FakeStep } from "../builder/fake.js";
import type { Brief, JobEvent, PackageSpec } from "../events.js";
import { cameraNotesMissed, steadyNotes } from "../camnote.js";
import { REPO_ROOT } from "../paths.js";
import { grantedScope } from "../scopegrant.js";
import { botWords, lookNotPlay } from "../playsame.js";
import { afterMerge } from "../halfmade.js";
import { foreignWords, gameWords, hasBodies } from "../gamewords.js";
import { contactDiff } from "../revisepair.js";
import { houseItem } from "../quality.js";
import { JobLog } from "../joblog.js";

after(cleanup);

const ev = (seq: number, e: Record<string, unknown>): JobEvent => ({ v: 1, seq, ts: "2026-11-25T12:00:00.000Z", job: "j", ...e }) as unknown as JobEvent;

// ---------------------------------------------------------------- 1. a bare yes grants the question's paths

test("H1g 1 (G4 events 221-224: \"Can the Foreman ... widen this package's scope to `scripts/core/**`, `scripts/main.gd` and `scripts/bodies/**` ...?\" answered \"Yes, let it change what it needs.\", and nothing was widened): a bare yes grants the paths the builder's question named", () => {
  // G4's real words, events 221 and 224
  const q = "Can the Foreman either widen this package's scope to `scripts/core/**`, `scripts/main.gd` and `scripts/bodies/**` (or assign the per-figure optimisation to their owners), or, if the remaining cost proves to be the engine's own figure animation, change the 1.0 ms budget for this six-player pack?";
  const evs = [ev(1, { type: "reopened", package: "crews_stakes", reason: "r" }), ev(221, { type: "question", package: "crews_stakes", text: q }), ev(224, { type: "answer", package: "crews_stakes", text: "Yes, let it change what it needs.", by: "player" })];
  assert.deepEqual(grantedScope(evs, "crews_stakes"), ["scripts/core/**", "scripts/main.gd", "scripts/bodies/**"]);
  assert.deepEqual(grantedScope([...evs.slice(0, 2), ev(224, { type: "answer", package: "crews_stakes", text: "Yes, go ahead.", by: "player" })], "crews_stakes"), ["scripts/core/**", "scripts/main.gd", "scripts/bodies/**"], "\"yes, go ahead\"");
  // a yes that names paths grants those, not the question's; a no grants nothing
  assert.deepEqual(grantedScope([...evs.slice(0, 2), ev(224, { type: "answer", package: "crews_stakes", text: "Yes, but only scripts/main.gd.", by: "player" })], "crews_stakes"), ["scripts/main.gd"]);
  assert.deepEqual(grantedScope([...evs.slice(0, 2), ev(224, { type: "answer", package: "crews_stakes", text: "No, raise the budget instead.", by: "player" })], "crews_stakes"), []);
});

// ---------------------------------------------------------------- 2. only some bots changed: name the ones that did not

test("H1g 2 (G2's blockout revise round 2, reasons about contact: the newcomer's and the perfect hand's matches stayed frame for frame the same while the tofu bot's figures moved, and nothing was said): the bots that did not change are named in words", () => {
  const dir = path.join(REPO_ROOT, "foreman", "fixtures", "h1g", "g2-blockout-r2");
  const evs = fs.readFileSync(path.join(dir, "job.jsonl"), "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l) as JobEvent);
  const look = JSON.parse(fs.readFileSync(path.join(dir, "look.json"), "utf8")) as { atSeq: number; notes: string[] };
  const said = lookNotPlay({ dir: (...p: string[]) => path.join(dir, ...p), events: evs } as never, look.atSeq, 2, look.notes);
  assert.equal(said, "the look changed, part of the play did not: the critic's reasons were about play (\"contact\"), and after revise round 2 the player bot (tests/bot_player.gd), the newcomer's match and the perfect hand's match did not change (the same moments at the same frames, the same counted figures); only the tofu bot's figures and the button-masher's match changed");
  assert.equal(botWords("tests/bot_ladder_pro_regular.gd"), "the regular hand's match at pro");
  assert.equal(botWords("tests/bot_hand_newcomer.gd (seed 3)"), "the newcomer's match (seed 3)");
});

// ---------------------------------------------------------------- 3. a steady-camera note, measured

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
  const at = JSON.parse(lines[1] as string) as { seq: number; ts: string; job: string };
  const head = lines.slice(0, 2);
  const tail = lines.slice(2).map((l) => JSON.parse(l) as { seq: number }).map((e) => JSON.stringify({ ...e, seq: e.seq + reactions.length }));
  const added = reactions.map((r, i) => JSON.stringify({ v: 1, seq: at.seq + 1 + i, ts: at.ts, job: at.job, type: "aspect_reacted", ...r }));
  fs.writeFileSync(file, [...head, ...added, ...tail].map((l) => l + "\n").join(""));
  return job;
}
const criticOk = (attempt: number): FakeStep => ({ match: { role: "critic", attempt }, json: { ok: true, scores: { silhouette: 0.8, readability: 0.8, style_consistency: 0.7, shows_play: 0.7, fun_promise: 0.8, kill_criteria: 0.9 }, notes: ["the court reads"] } });
const court = (round: number, cam: string): FakeStep => ({ match: { role: "builder", package: "court", round }, write: { "data/court.json": `{"width_m": 16, "depth_m": 9, "wall_height_m": 1.2, "mark": "FAKE_CAMERA(${cam})"}\n` }, text: "Done.\nDEVIATIONS: none" });

test("H1g 3 (G4: \"keep the camera steady behind me like a TV game, no swinging\" on a kept card; the view slid after the player and only the critic's eye could say so): the runner's camera figures are checked against a steady-camera note by the Foreman, whatever the critic scored", async () => {
  // G4's real pack, played by the runner with H1g's camera figures (tests/bot_play.gd, seed 1), and its real note
  const dir = path.join(REPO_ROOT, "foreman", "fixtures", "h1g", "g4-camera");
  const evs = fs.readFileSync(path.join(dir, "job.jsonl"), "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l) as JobEvent);
  const g4 = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "h1e", "g4-brief.json"), "utf8")) as Brief;
  const s = { brief: g4, reactions: { close_camera: { choice: "keep", note: "keep the camera steady behind me like a TV game, no swinging", seq: 14 }, spring: { choice: "drop", note: "I just want plain street ball, no speed boost off screens", seq: 13 } } };
  const missed = cameraNotesMissed({ dir: (...p: string[]) => path.join(dir, ...p), events: evs, s } as never);
  assert.equal(missed.length, 1);
  assert.match(missed[0] ?? "", /^person's note not kept: "keep the camera steady behind me like a TV game, no swinging": measured, the game's camera travels [0-9.]+ m a second \(p90 over tests\/bot_play\.gd's run, the runner's camera figures; steady is at most 15 degrees and 1\.5 m a second\)/);
  // a still camera keeps it; a note that is not about the camera is not checked
  assert.deepEqual(cameraNotesMissed({ dir: (...p: string[]) => path.join(dir, ...p), events: [], s } as never), [], "no figure, no claim");
  assert.deepEqual(steadyNotes({ brief: g4, reactions: { autumn_arches: { choice: "keep", note: "like my picture: tall brick viaduct arches", seq: 15 } } } as never), []);
  // in the loop: the critic says ok, the camera slides 9.2 m a second: the look is NOT ok and the round is told the person's words
  const job = designJob("h1g-cam", [{ aspect: "court", choice: "keep", note: "keep the camera steady, no swinging" }]);
  const steps = [court(1, "4,9.2"), criticOk(1), criticOk(2), court(2, "4,0.4")];
  const { foreman, builder } = foremanFor(job, { critic: true, promoteTo: "job", script: scriptWith(steps) });
  const st = await foreman.run();
  assert.equal(st.jobState?.state, "done", JSON.stringify(st.jobState));
  const revise = builder.calls.filter((c) => c.req.meta?.package === "court").at(-1)?.req.prompt ?? "";
  assert.match(revise, /revise round 1 of 2 \(milestone blockout\)[^\n]*Critic's notes: person's note not kept: "keep the camera steady, no swinging": measured, the game's camera travels 9\.2 m a second/);
  const ms = readEvents(job.jobDir).filter((e) => e.type === "milestone");
  assert.deepEqual(ms.map((m) => (m.type === "milestone" ? m.kept ?? "" : "")), ["new"], "the steadier version passes and is kept");
});

// ---------------------------------------------------------------- 5. a change with two asks, half made

test("H1g 5 (G2 events 642-730: \"team play + first to 5\" went to core; core's builder made the match length and wrote \"NOT DONE here: teammates running into open space ... belong to another package\"; the job ended done and the what-changed line repeated the whole request): the rest goes on to the package that owns it, and the what-changed line says what was not made apart", async () => {
  const job = tempJob("h1g-half");
  assert.equal((await foremanFor(job, { promoteTo: "job" }).foreman.run()).jobState?.state, "done");
  const log = JobLog.open(job.jobDir);
  log.append({ type: "change_requested", text: "Make the rival twice as fast, and make the court walls twice as high.", package: "paddle_ai" });
  log.close();
  const from = readEvents(job.jobDir).at(-1)?.seq ?? 0;
  const steps: FakeStep[] = [
    { match: { role: "builder", package: "paddle_ai" }, write: { "data/ai.json": "{\"speed\": 2.0}\n" }, text: "Done.\nDEVIATIONS:\n- The rival's top speed is doubled (data/ai.json speed 1.0 -> 2.0).\n- NOT DONE here (the change request): the wall height lives in `data/court.json`, which belongs to another package." },
    { match: { role: "builder", package: "court" }, write: { "data/court.json": "{\"width_m\": 16, \"depth_m\": 9, \"wall_height_m\": 2.4}\n" }, text: "Done.\nDEVIATIONS:\n- The walls are 2.4 m high (were 1.2)." },
  ];
  const s = await foremanFor(job, { promoteTo: "job", script: scriptWith(steps) }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > from);
  const rest = later.find((e) => e.type === "change_requested" && e.package === "court");
  assert.equal(rest?.type === "change_requested" ? rest.text : "", "[foreman] the rest of your change, which paddle_ai did not make (\"NOT DONE here (the change request): the wall height lives in `data/court.json`, which belongs to another package.\"): \"Make the rival twice as fast, and make the court walls twice as high.\"");
  assert.ok(later.some((e) => e.type === "merge" && e.package === "court" && e.files.includes("data/court.json")), "court made the rest");
  assert.match(fs.readFileSync(path.join(job.jobDir, "pack", "data", "court.json"), "utf8"), /2\.4/);
  const wc = later.filter((e) => e.type === "note" && e.text.startsWith("[foreman] what changed in")).at(-1);
  const line = wc?.type === "note" ? wc.text : "";
  assert.match(line, /asked "Make the rival twice as fast, and make the court walls twice as high\."; what you will see, in the builder's words: The rival's top speed is doubled \(data\/ai\.json speed 1\.0 -> 2\.0\)\. \/ The walls are 2\.4 m high \(were 1\.2\)\.; files: data\/ai\.json, data\/court\.json/);
  assert.doesNotMatch(line.split("\n")[0] ?? "", /NOT DONE/, "what was not made is not what you will see");
  assert.match(line, /\npart of your change was NOT made by paddle_ai; it went on to court, which made it; court's files paddle_ai names: NOT DONE here/);
  assert.equal(later.filter((e) => e.type === "change_requested").length, 1, "asked once: the person's words appear once in what changed");
  // nobody owns the rest: the person is told plainly
  const lone = afterMerge([{ id: "core", scope: ["scripts/main.gd"] } as PackageSpec], [ev(1, { type: "reopened", package: "core", reason: "change request (event 0): x" }), ev(2, { type: "note", package: "core", round: 2, text: "- first to 5\n- NOT DONE here: teammates running into open space need a team AI, which this game does not have" })], "core", 2, ["data/tuning.json"], "team play and first to 5");
  assert.deepEqual(lone.map((e) => e["text"]), ["[foreman] part of your change was NOT made: core made what it could and says: NOT DONE here: teammates running into open space need a team AI, which this game does not have. No other package owns the rest: say it again as a change of its own if you still want it"]);
});

// ---------------------------------------------------------------- 6. body rows only for games with bodies

test("H1g 6 (G5 event 69: a bumper-kart game was sent 49 house contact rows to add, hits.body_window, stand_brace, sprint_stability, stumble_ratio ...): the rows of a body that stands, braces and stumbles reach only a game whose design has bodies that take a hit; a kart game is judged by its own contact", () => {
  const g5 = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "h1g", "g5-brief.json"), "utf8")) as Brief;
  const g4 = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "h1e", "g4-brief.json"), "utf8")) as Brief;
  const g2 = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "h1e", "g2-brief.json"), "utf8")) as Brief;
  assert.equal(hasBodies(g5), false, "karts spin out; nothing in its design stumbles, tumbles or falls");
  assert.equal(hasBodies(g4), true, "the basketball's kids stumble");
  assert.equal(hasBodies(g2), true, "the robots tumble and clamber up");
  const build = path.join(tempDir("h1g-kart"), "pack");
  fs.mkdirSync(path.join(build, "data"), { recursive: true });
  fs.copyFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "h1g", "g5-tuning.json"), path.join(build, "data", "tuning.json"));
  const hockey = path.join(REPO_ROOT, "engine", "packs", "hockey");
  const now = contactDiff(build, hockey, "arcade_sport", "hockey", 14, gameWords(g5));
  assert.ok(now !== undefined);
  for (const k of ["body_window", "bot_body_window", "stand_brace", "side_brace", "sprint_stability", "stumble_ratio", "stability_speed", "unseen_stability"]) assert.ok(!now.missing.some((x) => x.includes(`hits.${k} `)), `${k} is a body's, not a kart's`);
  assert.ok(now.missing.length < 49, `${now.missing.length} rows asked (G5 was sent 49)`);
  assert.match(now.line, /belong to engine\/packs\/hockey's own play \([^)]*\bbody\b[^)]*\), which this game's design does not have/);
  // a game of people keeps them
  const g4now = contactDiff(build, hockey, "arcade_sport", "hockey", 14, gameWords(g4));
  assert.ok(g4now?.missing.some((x) => x.includes("hits.stumble_ratio")), "how a body takes contact is still asked of the basketball");
  // the house_game rubric item says so in words
  const foreign = foreignWords(gameWords(g5), ["hits.stand_brace", "hits.stumble_ratio"]);
  assert.match(houseItem("hockey", foreign).text, /share \(how they take contact, the team's play\)\. This game has no bodies that stumble or fall/);
});

// ---------------------------------------------------------------- 4b. the lock a page is reading

test("H1g 4b (create.pause.path, 2 of 6 runs on 25 Nov: \"phase/quality did not work: EPERM, Permission denied: ...foreman.lock\" in JobLog.close, while the Create page read the lock's pid): closing the log waits out a reader that holds the lock open", { skip: process.platform !== "win32" ? "a Windows sharing rule" : false }, async () => {
  const job = tempJob("h1g-lock");
  const log = JobLog.open(job.jobDir);
  const lock = path.join(job.jobDir, "foreman.lock");
  assert.ok(fs.existsSync(lock));
  // a reader that opens the file as Godot's FileAccess does (no delete sharing) and holds it 400 ms
  const ps = `$f=[System.IO.File]::Open('${lock.replace(/'/g, "''")}','Open','Read','Read'); Write-Output 'open'; Start-Sleep -Milliseconds 400; $f.Close()`;
  const holder = spawn("powershell.exe", ["-NoProfile", "-Command", ps], { stdio: ["ignore", "pipe", "inherit"] });
  await new Promise<void>((resolve, reject) => {
    holder.stdout.on("data", (d: Buffer) => { if (d.toString().includes("open")) resolve(); });
    holder.on("exit", () => reject(new Error("the reader ended before it opened the lock")));
  });
  log.close();
  assert.equal(fs.existsSync(lock), false, "the lock is gone once the reader lets go");
  await new Promise((r) => holder.on("exit", r));
});
