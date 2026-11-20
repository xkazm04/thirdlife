// Regenerates fixtures/job-phases/ (JOB.md "Added 2026-11-20"): a CRAZY job whose brief has a pitch, four aspect
// cards (one of them crazy) and the player's reactions, approved, then a plan in THREE phases:
//   1. court_plays: core + court        "Rally the ball off the walls with your paddle"
//   2. rival:       paddle_ai           "Beat Rival Rex, who lunges at every ball"
//   3. magnet:      fx (the crazy one)  "Every tenth hit the ball sticks, then flies"
// The fake builder's script is job-paddle's plus: court round 2 (the change round of a phase hold), the fx package,
// the Planner's answer to "which package owns this hold", and a critic that scores the fun_promise item too.
// Run: node fixtures/make-phases-fixture.mjs      (only needed when the fixture itself changes)
// Played by src/test/phases.test.ts; by hand: foreman init-fixture <dir> --phases, then run / phase / status.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const src = path.join(here, "job-paddle");
const dir = path.join(here, "job-phases");
fs.mkdirSync(dir, { recursive: true });

const job = "paddle-court-crazy-20261121-1";
const packId = "game.paddle_court_crazy";
const ts = (n) => `2026-11-21T01:00:${String(n).padStart(2, "0")}.000Z`;
const paddle = fs.readFileSync(path.join(src, "job.jsonl"), "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const paddlePlan = paddle.find((e) => e.type === "plan_set").packages;
const paddleBrief = paddle.find((e) => e.type === "brief_set");

const fx = {
  id: "fx",
  title: "Magnet ball and juice",
  milestone: "tuned",
  deps: ["core"],
  scope: ["data/fx.json", "scripts/fx.gd"],
  contract:
    "data/fx.json: {magnet_every_hits: 10, magnet_hold_frames: 60, release_speed_mps: 14, shake_m: 0.08, shake_frames: 10}.\n" +
    "scripts/fx.gd: func on_hit(hit_count: int, tuning: Dictionary) -> String returns \"magnet\" on every magnet_every_hits-th hit, else \"\".\n" +
    "A goal shakes the view (ctx.cameras.shake(shake_m, shake_frames)), bursts goal_flash (TLVfx.burst) and plays score (TLAudio.play).",
  acceptance: [
    { level: "V1", verb: "lint", args: [] },
    { level: "V2", verb: "smoke", args: ["--seed=1", "--frames=600"] },
    { level: "V4", verb: "bot", args: ["--test=tests/bot_rally.gd", "--frames=1200"] },
  ],
};
const packages = [...paddlePlan, fx];
const phases = [
  { id: "court_plays", title: "The court plays", try: "Rally the ball off the walls with your paddle", packages: ["core", "court"] },
  { id: "rival", title: "Rival Rex", try: "Beat Rival Rex, who lunges at every ball", packages: ["paddle_ai"] },
  { id: "magnet", title: "Magnet ball", try: "Every tenth hit the ball sticks, then flies", packages: ["fx"] },
];

const brief = {
  ...paddleBrief.brief,
  pitch: "Slap a speeding ball past Rival Rex; every tenth hit the ball turns magnetic and sticks to a wall.",
  aspects: [
    { id: "paddle", icon: "player", title: "Your paddle", line: "Slide along your goal and slap the ball back", detail: "paddle_up and paddle_down move it; every return speeds the ball up by 5 percent, so rallies always end.", alternatives: [{ id: "two_paddles", title: "Two paddles", line: "Steer a front and a back paddle at once" }, { id: "spin_bat", title: "A spinning bat", line: "Spin to whack the ball at an angle" }] },
    { id: "rival", icon: "rival", title: "Rival Rex", line: "A greedy paddle that lunges at every ball", detail: "TLSteer.intercept_point with an 8-frame reaction; a lunge leaves his far corner open for 20 frames. He grins on a goal and sulks on a miss.", alternatives: [{ id: "twin_rivals", title: "Twin rivals", line: "Two small paddles share the far goal" }, { id: "wall_only", title: "The wall", line: "No rival: beat your own best rally" }] },
    { id: "court", icon: "arena", title: "Walled court", line: "Walls bounce the ball, a goal behind each end", detail: "16 m by 9 m on a kit rink floor for a fast slide; a fixed view of the whole court with your paddle as its subject.", alternatives: [{ id: "ice_court", title: "Ice court", line: "Everything slides faster on bare ice" }, { id: "round_court", title: "Round court", line: "A ring with four goals and four rivals" }] },
    { id: "magnet_ball", icon: "twist", title: "Magnet ball", line: "Every tenth hit the ball sticks, then flies", detail: "On the tenth hit the pack holds the ball on the wall it touches for 60 frames with a hum, then fires it at 14 m/s toward a random goal (ctx.rng).", alternatives: [{ id: "split_ball", title: "Splitting ball", line: "A hard hit splits the ball in two" }, { id: "tilting_court", title: "Tilting court", line: "The court tilts toward whoever leads" }], crazy: true },
  ],
};

const events = [
  { type: "job_created", sentence: "a ball-and-paddle game in a walled court", packId, title: "Paddle Court", creativity: "crazy" },
  { type: "brief_set", brief, estimate: { packages: 4, wallMinutes: 30, tokens: 200000 } },
  { type: "aspect_reacted", aspect: "court", choice: "keep" },
  { type: "aspect_reacted", aspect: "magnet_ball", choice: "keep", note: "love it, but the hum should be loud" },
  { type: "brief_approved", by: "player" },
  { type: "plan_set", packages, phases },
];
fs.writeFileSync(path.join(dir, "job.jsonl"), events.map((e, i) => JSON.stringify({ v: 1, seq: i + 1, ts: ts(i), job, ...e })).join("\n") + "\n");

const script = JSON.parse(fs.readFileSync(path.join(src, "fake-builder.json"), "utf8"));
const critic = script.steps.find((s) => s.match?.role === "critic");
critic.json.scores.fun_promise = 0.7;
critic.json.notes.push("the paddle is mid-return in the frame: the promised rally is visible");
const smallCourt = JSON.stringify({ width_m: 12, depth_m: 7, wall_height_m: 1.2, walls: ["north", "south"], goals: ["west", "east"] }, null, 1) + "\n";
script.steps.unshift(
  {
    // The hold's change round: court, round 2, after the player said the rallies are too slow.
    match: { role: "builder", package: "court", round: 2, promptIncludes: "CHANGE REQUEST" },
    delayMs: 60,
    write: { "data/court.json": smallCourt },
    text: "Made the court 12 m by 7 m so the ball comes back sooner.\nDEVIATIONS: data/court.json width_m 16 -> 12, depth_m 9 -> 7 (the player's hold note).",
    tokensIn: 3000,
    tokensOut: 200,
  },
  {
    // "Which package owns this hold?" (owner.md, role planner): the court, among the phase's core and court.
    match: { role: "planner", promptIncludes: "rallies" },
    json: { package: "court", reason: "the court's size decides how long the ball travels between returns" },
    tokensIn: 700,
    tokensOut: 40,
  },
  {
    match: { role: "builder", package: "fx" },
    delayMs: 60,
    write: {
      "data/fx.json": JSON.stringify({ magnet_every_hits: 10, magnet_hold_frames: 60, release_speed_mps: 14, shake_m: 0.08, shake_frames: 10 }, null, 1) + "\n",
      "scripts/fx.gd": ["extends RefCounted", "", "func on_hit(hit_count: int, tuning: Dictionary) -> String:", '\tif hit_count > 0 and hit_count % int(tuning.get("magnet_every_hits", 10)) == 0:', '\t\treturn "magnet"', '\treturn ""', ""].join("\n"),
    },
    text: "Done. Wrote data/fx.json and scripts/fx.gd.",
    tokensIn: 3500,
    tokensOut: 400,
  },
);
fs.writeFileSync(path.join(dir, "fake-builder.json"), JSON.stringify(script, null, 1) + "\n");
fs.writeFileSync(path.join(dir, "foreman.config.json"), JSON.stringify({ godot: "@fake", engineDir: "engine-out" }, null, 1) + "\n");
for (const leftover of ["pack", "ws", "reports", "captures", "ref", "engine-out", "state.json", "foreman.lock", "children.jsonl", "promoted"]) {
  fs.rmSync(path.join(dir, leftover), { recursive: true, force: true });
}
console.log(`fixture written to ${dir}`);
