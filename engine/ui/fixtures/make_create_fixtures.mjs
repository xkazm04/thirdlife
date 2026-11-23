// L3 (night of 21 Nov 2026): the job logs the Create page (ui/create/) is drawn from, one per state, written by hand
// against contracts/JOB.md "Added 2026-11-20" (the designer v2). No Foreman ran: L2 builds the commands in parallel.
// The output is committed under ui/fixtures/create/<name>/job.jsonl; run this again after a change and commit both.
//
//   node make_create_fixtures.mjs [<out dir>]        default: ui/fixtures/create beside this file
//
// One game, Penguin Push, told by a ten-year-old in one vague sentence, designed in crazy mode, built in three phases.
// Each fixture is a prefix of one story (plus two branches: a failure and a run-through job), so the states follow
// each other as a player meets them.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const out = process.argv[2] ?? path.join(here, "create");

const JOB = "penguin-push-20261121-1";
const T0 = Date.parse("2026-11-21T19:02:00.000Z");

const SENTENCE = "penguins pushing each other off an iceberg";

const ASPECTS = [
  { id: "player", icon: "player", title: "Your penguin", line: "Belly-slide fast, brake with your flippers to turn.",
    detail: "You steer a penguin that slides on its belly. Holding brake digs the flippers in for a sharp turn; a full-speed slide is hard to stop, so the edge is always close.",
    alternatives: [
      { id: "heavy", title: "Heavy emperor", line: "Slow to start, almost impossible to push over." },
      { id: "tiny", title: "Tiny rockhopper", line: "Hops over shoves, but flies far when hit." },
    ] },
  { id: "rivals", icon: "rival", title: "Three rival penguins", line: "They gang up on whoever leads the round.",
    detail: "Three computer penguins. Each picks a target every few seconds; the leader gets picked more often, so a lead is hard to keep and a comeback is always possible.",
    alternatives: [
      { id: "solo", title: "Every bird alone", line: "Each rival shoves whoever is nearest." },
      { id: "pairs", title: "Two against two", line: "You and a buddy penguin against a pair." },
    ] },
  { id: "iceberg", icon: "arena", title: "Shrinking iceberg", line: "Cracks spread from the edges every twenty seconds.",
    detail: "A round iceberg about thirty metres across. Every twenty seconds a ring of ice at the edge cracks and sinks, so the fight moves to the middle.",
    alternatives: [
      { id: "floes", title: "Drifting floes", line: "Small floes drift apart; jump the gaps." },
      { id: "bowl", title: "Ice bowl", line: "A slippery bowl that tips everyone to the middle." },
      { id: "ship", title: "Icebreaker deck", line: "A tilting ship deck that rolls with the waves." },
    ] },
  { id: "win", icon: "goal", title: "Last one standing", line: "Push the others into the sea; best of three rounds.",
    detail: "A round ends when one penguin is left on the ice. Three rounds; the winner of two takes the match.",
    alternatives: [
      { id: "fish", title: "Fish grab", line: "Most fish when the time runs out wins." },
      { id: "crown", title: "Hold the crown", line: "Keep the crown longest; a bump knocks it loose." },
    ] },
  { id: "orca", icon: "twist", title: "Orca hunts", line: "An orca circles and leaps out where the ice cracks.", crazy: true,
    detail: "Crazy mode adds an orca. Its fin circles the iceberg; where it leaps, the ice breaks and any penguin there is thrown high. Lure rivals onto its path.",
    alternatives: [
      { id: "seals", title: "Seal surfers", line: "Seals ride in on waves and shove everyone." },
      { id: "blizzard", title: "Sudden blizzard", line: "Snow hides the edge; listen for the cracks." },
    ] },
  { id: "cannon", icon: "power", title: "Snowball cannon", line: "Grab a fish, charge one giant snowball shot.", crazy: true,
    detail: "Crazy mode adds a power: fish appear on the ice; eating one fills a cannon that fires a snowball big enough to roll a rival off the edge.",
    alternatives: [
      { id: "jet", title: "Fish jet", line: "Eat a fish, rocket forward in a line." },
      { id: "glue", title: "Sticky feet", line: "Freeze in place for two seconds, unpushable." },
    ] },
];

const BRIEF = {
  rules: "Last penguin on the iceberg wins the round; best of three rounds. The ice shrinks every 20 s.",
  arena: "A round iceberg, 30 m across, in open sea; edge rings crack and sink.",
  ai: "Three rival penguins pick a target every 3 s, the leader more often.",
  controls: "WASD steer the belly slide, Space brakes for a sharp turn, F fires the snowball cannon.",
  mood: "Bright, splashy and silly: big splashes, squawks, a cheering seal crowd.",
  pitch: "Slide, bump and splash three rivals off a shrinking iceberg while an orca circles.",
  aspects: ASPECTS,
};

// after a redesign with: player -> tiny, cannon dropped, orca kept with a note
const BRIEF2 = {
  ...BRIEF,
  controls: "WASD steer the belly slide, Space hops over a shove.",
  pitch: "Hop and bump three rivals off a shrinking iceberg while a goofy orca circles.",
  aspects: [
    { ...ASPECTS[0], title: "Tiny rockhopper", line: "Hops over shoves, but flies far when hit.",
      alternatives: [{ id: "heavy", title: "Heavy emperor", line: "Slow to start, almost impossible to push over." },
        { id: "slider", title: "Belly slider", line: "Belly-slide fast, brake with your flippers to turn." }] },
    ASPECTS[1], ASPECTS[2], ASPECTS[3],
    { ...ASPECTS[4], title: "Goofy orca", line: "A clumsy orca flops onto the ice where it cracks." },
  ],
};

const PACKAGES = [
  { id: "ice_arena", title: "Iceberg and sea", milestone: "blockout", deps: [], scope: ["scripts/arena*.gd", "data/arena.json"],
    contract: "Builds the round iceberg and the sea; sink_ring(k) drops ring k.", acceptance: [{ level: "V2", verb: "smoke", args: [] }],
    registers: { capabilities: ["physics"] } },
  { id: "penguin_moves", title: "Belly slide and brake", milestone: "blockout", deps: ["ice_arena"], scope: ["scripts/penguin*.gd", "data/penguin.json"],
    contract: "The player's penguin: slide, brake, bump.\nPLAYER CHECK: tests/bot_push.gd fails when the player can no longer push a dummy off.",
    acceptance: [{ level: "V4", verb: "bot", args: ["tests/bot_push.gd"] }], registers: { capabilities: ["input"], tests: ["tests/bot_push.gd"] } },
  { id: "rivals_ai", title: "Three rival penguins", milestone: "greybox", deps: ["penguin_moves"], scope: ["scripts/rival*.gd"],
    contract: "Three rivals that pick a target every 3 s.", acceptance: [{ level: "V4", verb: "bot", args: ["tests/bot_rounds.gd"] }],
    registers: { capabilities: ["ai"], tests: ["tests/bot_rounds.gd"] } },
  { id: "cracks_orca", title: "Cracks and the orca", milestone: "greybox", deps: ["ice_arena"], scope: ["scripts/orca*.gd", "data/orca.json"],
    contract: "Edge rings crack every 20 s; the orca leaps where ice breaks.", acceptance: [{ level: "V3", verb: "invariants", args: [] }] },
  { id: "look_sound", title: "Splashes and the crowd", milestone: "art_pass", deps: ["rivals_ai", "cracks_orca"], scope: ["scripts/look*.gd"],
    contract: "Splashes, squawks, the seal crowd.", acceptance: [{ level: "V5", verb: "capture", args: [] }], registers: { capabilities: ["vfx", "audio"] } },
];

const PHASES = [
  { id: "slide", title: "Slide and bump", try: "Slide your penguin around and bump a dummy into the sea.", packages: ["ice_arena", "penguin_moves"] },
  { id: "rivals", title: "Rivals and cracks", try: "Survive three rivals while the ice cracks under you.", packages: ["rivals_ai", "cracks_orca"] },
  { id: "show", title: "Orca show", try: "Play full rounds with splashes, squawks and the goofy orca.", packages: ["look_sound"] },
];

// ---- the story, event by event (no v/seq/ts/job: added when written)
const story = [];
const mark = {};
const at = (name) => { mark[name] = story.length; };
const ev = (type, rest, afterS = 20) => story.push({ type, ...rest, _after: afterS });

function build(pkg, round = 1, detail) {
  ev("package_state", { package: pkg, state: "running", round, ...(detail ? { detail } : {}) }, 5);
  ev("builder_run", { package: pkg, round, adapter: "claude-cli", mode: "edit", model: "opus", outcome: "ok", durationMs: 412000, tokensIn: 310000, tokensOut: 9800 }, 412);
  ev("package_state", { package: pkg, state: "verifying", round }, 1);
  ev("verify", { package: pkg, round, level: "V2", verb: "smoke", ok: true, report: `reports/${pkg}-r${round}-smoke.json`, exitCode: 0 }, 40);
  ev("verify", { round, level: "V2", verb: "smoke", ok: true, report: `reports/${pkg}-r${round}-pack-smoke.json`, exitCode: 0, after: pkg }, 30);
  ev("merge", { package: pkg, files: [`scripts/${pkg}.gd`] }, 1);
  ev("package_state", { package: pkg, state: "promoted", round }, 1);
}

ev("job_created", { sentence: SENTENCE, packId: "game.penguin_push", title: "Penguin Push", creativity: "crazy" }, 0);
ev("billing", { adapter: "claude-cli", mode: "subscription", evidence: "claude CLI login (no ANTHROPIC_API_KEY)" }, 1);
at("designing");
ev("builder_run", { adapter: "claude-cli", mode: "generate", model: "opus", outcome: "ok", durationMs: 48000, tokensIn: 21000, tokensOut: 2900 }, 48);
ev("brief_set", { brief: BRIEF, estimate: { packages: 5, wallMinutes: 70, tokens: 1800000 } }, 1);
at("pitch");
ev("aspect_reacted", { aspect: "player", choice: "tiny" }, 30);
ev("aspect_reacted", { aspect: "orca", choice: "keep", note: "make the orca funny, not scary" }, 20);
ev("aspect_reacted", { aspect: "cannon", choice: "drop" }, 10);
at("reacted");
ev("builder_run", { adapter: "claude-cli", mode: "generate", model: "opus", outcome: "ok", durationMs: 44000, tokensIn: 24000, tokensOut: 2600 }, 44);
ev("brief_set", { brief: BRIEF2, estimate: { packages: 5, wallMinutes: 65, tokens: 1700000 } }, 1);
at("redesigned");
ev("aspect_reacted", { aspect: "iceberg", choice: "floes" }, 25);
ev("brief_approved", { by: "player" }, 15);
ev("builder_run", { adapter: "claude-cli", mode: "generate", model: "opus", outcome: "ok", durationMs: 90000, tokensIn: 60000, tokensOut: 7000 }, 90);
ev("plan_set", { packages: PACKAGES, phases: PHASES }, 1);
ev("job_state", { state: "running", reason: "plan of 5 packages in 3 phases" }, 2);
build("ice_arena");
ev("package_state", { package: "penguin_moves", state: "running", round: 1 }, 5);
at("building");
ev("builder_run", { package: "penguin_moves", round: 1, adapter: "claude-cli", mode: "edit", model: "opus", outcome: "ok", durationMs: 380000, tokensIn: 290000, tokensOut: 9000 }, 380);
ev("package_state", { package: "penguin_moves", state: "verifying", round: 1 }, 1);
ev("verify", { package: "penguin_moves", round: 1, level: "V4", verb: "bot", ok: true, report: "reports/penguin_moves-r1-bot.json", exitCode: 0 }, 60);
ev("verify", { round: 1, level: "V2", verb: "smoke", ok: true, report: "reports/penguin_moves-r1-pack-smoke.json", exitCode: 0, after: "penguin_moves" }, 30);
ev("merge", { package: "penguin_moves", files: ["scripts/penguin.gd", "data/penguin.json", "tests/bot_push.gd"] }, 1);
ev("package_state", { package: "penguin_moves", state: "promoted", round: 1 }, 1);
ev("phase_done", { phase: "slide" }, 1);
ev("job_state", { state: "paused", reason: "phase" }, 1);
at("phase_done");
ev("phase_reviewed", { phase: "slide", verdict: "hold", note: "the penguin turns too slowly, make the brake snappier", by: "player" }, 240);
ev("job_state", { state: "running", reason: "phase slide held: a change round" }, 2);
ev("reopened", { package: "penguin_moves", reason: "phase slide held (event 0): the penguin turns too slowly, make the brake snappier" }, 1);
ev("package_state", { package: "penguin_moves", state: "queued", round: 2, detail: "CHANGE REQUEST: the penguin turns too slowly, make the brake snappier" }, 1);
ev("package_state", { package: "penguin_moves", state: "running", round: 2 }, 3);
at("held");
ev("builder_run", { package: "penguin_moves", round: 2, adapter: "claude-cli", mode: "edit", model: "opus", outcome: "ok", durationMs: 200000, tokensIn: 150000, tokensOut: 5000 }, 200);
ev("package_state", { package: "penguin_moves", state: "verifying", round: 2 }, 1);
ev("verify", { package: "penguin_moves", round: 2, level: "V4", verb: "bot", ok: true, report: "reports/penguin_moves-r2-bot.json", exitCode: 0 }, 60);
ev("merge", { package: "penguin_moves", files: ["scripts/penguin.gd", "data/penguin.json"] }, 1);
ev("package_state", { package: "penguin_moves", state: "promoted", round: 2 }, 1);
ev("phase_done", { phase: "slide" }, 1);
ev("job_state", { state: "paused", reason: "phase" }, 1);
ev("phase_reviewed", { phase: "slide", verdict: "pass", by: "player" }, 120);
ev("job_state", { state: "running", reason: "phase slide passed" }, 2);
build("cracks_orca");
ev("package_state", { package: "rivals_ai", state: "running", round: 1 }, 5);
at("phase2");
const failFrom = story.length;
ev("builder_run", { package: "rivals_ai", round: 1, adapter: "claude-cli", mode: "edit", model: "opus", outcome: "ok", durationMs: 350000, tokensIn: 280000, tokensOut: 8000 }, 350);
ev("package_state", { package: "rivals_ai", state: "verifying", round: 1 }, 1);
ev("verify", { package: "rivals_ai", round: 1, level: "V4", verb: "bot", ok: true, report: "reports/rivals_ai-r1-bot.json", exitCode: 0 }, 60);
ev("merge", { package: "rivals_ai", files: ["scripts/rivals.gd"] }, 1);
ev("package_state", { package: "rivals_ai", state: "promoted", round: 1 }, 1);
ev("phase_done", { phase: "rivals" }, 1);
ev("job_state", { state: "paused", reason: "phase" }, 1);
ev("phase_reviewed", { phase: "rivals", verdict: "pass", by: "player" }, 300);
ev("job_state", { state: "running", reason: "phase rivals passed" }, 2);
build("look_sound");
ev("phase_done", { phase: "show" }, 1);
ev("job_state", { state: "paused", reason: "phase" }, 1);
ev("phase_reviewed", { phase: "show", verdict: "pass", by: "player" }, 200);
ev("job_state", { state: "running", reason: "phase show passed: final verification" }, 2);
ev("verify", { round: 1, level: "V4", verb: "bot", ok: true, report: "reports/final-bot_rounds.json", exitCode: 0 }, 60);
ev("promoted", { packId: "game.penguin_push", version: "0.1.0", dest: "promoted/game.penguin_push" }, 5);
ev("job_state", { state: "done", reason: "promoted 0.1.0" }, 1);
at("done");

// the failure branch: rivals_ai never passes its bot
const failed = story.slice(0, failFrom).concat([
  { type: "builder_run", package: "rivals_ai", round: 4, adapter: "claude-cli", mode: "edit", model: "opus", outcome: "ok", durationMs: 300000, tokensIn: 250000, tokensOut: 7000, _after: 1400 },
  { type: "package_state", package: "rivals_ai", state: "verifying", round: 4, _after: 1 },
  { type: "verify", package: "rivals_ai", round: 4, level: "V4", verb: "bot", ok: false, report: "reports/rivals_ai-r4-bot.json", exitCode: 1, _after: 60 },
  { type: "package_state", package: "rivals_ai", state: "failed", round: 4, cause: "verify_failed", detail: "tests/bot_rounds.gd: no round ended in 9000 frames", _after: 1 },
  { type: "package_state", package: "look_sound", state: "blocked", round: 1, cause: "dependency", detail: "rivals_ai failed", _after: 1 },
  { type: "job_state", state: "failed", reason: "rivals_ai failed after 4 rounds", _after: 1 },
]);

// the Designer could not write a brief
const designFailed = [story[0], story[1],
  { type: "builder_run", adapter: "claude-cli", mode: "generate", model: "opus", outcome: "timeout", durationMs: 300000, _after: 300 },
  { type: "job_state", state: "failed", reason: "the Designer did not answer in 300 s", _after: 1 },
];

// run-through: the Foreman passes every phase itself; the reaction carries a note. A log written before the person gate
// of 23 Nov (the Foreman no longer passes the first phase itself, foreman/src/design_state.ts passesItself); the panel
// still reads such logs as they are.
function runThrough() {
  const s = [];
  for (const e of story) {
    if (e.type === "job_created") { s.push({ ...e, title: "Penguin Push (run through)", run_through: true }); continue; }
    if (e.type === "phase_reviewed") { if (e.verdict === "pass") s.push({ ...e, by: "auto", _after: 0 }); continue; }
    if (e.type === "job_state" && e.state === "paused") continue;
    s.push(e);
  }
  // drop the hold's change round: keep the first phase_done of slide and the auto pass after it
  const out = [];
  let skip = false;
  for (const e of s) {
    if (e.type === "job_state" && /held/.test(e.reason ?? "")) { skip = true; continue; }
    if (skip) { if (e.type === "phase_reviewed") { skip = false; out.push(e); } continue; }
    out.push(e);
  }
  // the first phase_done of slide gets its auto pass right after it
  const k = out.findIndex((e) => e.type === "phase_done" && e.phase === "slide");
  if (!(out[k + 1]?.type === "phase_reviewed")) out.splice(k + 1, 0, { type: "phase_reviewed", phase: "slide", verdict: "pass", by: "auto", _after: 0 });
  return out;
}

function write(name, events, title) {
  const dir = path.join(out, name);
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  let t = T0;
  const lines = events.map((e, i) => {
    const { _after, ...rest } = e;
    t += (_after ?? 20) * 1000;
    const body = i === 0 && title ? { ...rest, title } : rest;
    // the reopened reason names the seq of the hold it answers
    if (body.type === "reopened" && /\(event 0\)/.test(body.reason)) {
      const hold = events.findIndex((x) => x.type === "phase_reviewed" && x.verdict === "hold");
      body.reason = body.reason.replace("(event 0)", `(event ${hold + 1})`);
    }
    return JSON.stringify({ v: 1, seq: i + 1, ts: new Date(t).toISOString(), job: JOB, ...body });
  });
  fs.writeFileSync(path.join(dir, "job.jsonl"), lines.map((l) => l + "\n").join(""));
  console.log(`${name}: ${lines.length} events`);
}

fs.mkdirSync(out, { recursive: true });
write("c1-designing", story.slice(0, mark.designing));
write("c2-pitch", story.slice(0, mark.pitch));
write("c3-reacted", story.slice(0, mark.reacted));
write("c4-redesigned", story.slice(0, mark.redesigned));
write("c5-building", story.slice(0, mark.building));
write("c6-phase-done", story.slice(0, mark.phase_done));
write("c7-held", story.slice(0, mark.held));
write("c8-phase2", story.slice(0, mark.phase2));
write("c9-done", story.slice(0, mark.done));
write("c10-failed", failed);
write("c11-design-failed", designFailed);
write("c12-run-through", runThrough());
