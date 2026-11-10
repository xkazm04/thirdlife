// Regenerates fixtures/job-paddle/ (job.jsonl up to plan_set, and the fake builder's script).
// Run: node fixtures/make-fixture.mjs      (only needed when the fixture itself changes)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const dir = path.join(here, "job-paddle");
fs.mkdirSync(dir, { recursive: true });

const job = "paddle-court-20261110-1";
const packId = "game.paddle_court";
const ts = (n) => `2026-11-10T17:00:${String(n).padStart(2, "0")}.000Z`;

const packages = [
  {
    id: "core",
    title: "Entry script and rally bot",
    milestone: "blockout",
    deps: [],
    scope: ["scripts/main.gd", "tests/bot_rally.gd"],
    registers: { capabilities: ["physics", "input", "rules", "ball", "ai", "camera"], tests: ["tests/bot_rally.gd"], cameras: ["hero"] },
    contract:
      "The manifest is composed by the Foreman: entry scripts/main.gd, tests [tests/bot_rally.gd], one camera view (hero).\n" +
      "scripts/main.gd: _pack_setup(ctx), _pack_start(), _pack_tick(frame), _pack_state() -> {score: {left: int, right: int}, rally: int}.\n" +
      "Input actions: paddle_up, paddle_down. tests/bot_rally.gd: holds the ball in play for 300 frames.",
    acceptance: [
      { level: "V1", verb: "lint", args: [] },
      { level: "V2", verb: "smoke", args: ["--seed=1", "--frames=600"] },
    ],
  },
  {
    id: "court",
    title: "Walled court layout",
    milestone: "blockout",
    deps: ["core"],
    scope: ["data/court.json", "scripts/court.gd"],
    contract:
      "data/court.json: {width_m: 16, depth_m: 9, wall_height_m: 1.2, walls: [north, south], goals: [west, east]}.\n" +
      "scripts/court.gd: static func build(ctx, layout: Dictionary) -> void; builds walls under ctx.root from kit parts.",
    acceptance: [
      { level: "V1", verb: "lint", args: [] },
      { level: "V2", verb: "smoke", args: ["--seed=1", "--frames=600"] },
    ],
  },
  {
    id: "paddle_ai",
    title: "Opponent paddle",
    milestone: "greybox",
    deps: ["core"],
    scope: ["data/ai.json", "scripts/paddle_ai.gd"],
    contract:
      "data/ai.json: {reaction_frames: 8, max_speed_mps: 6.0, error_m: 0.3}.\n" +
      "scripts/paddle_ai.gd: func decide(ball_y: float, paddle_y: float, tuning: Dictionary) -> float (axis in -1..1).",
    acceptance: [
      { level: "V1", verb: "lint", args: [] },
      { level: "V2", verb: "smoke", args: ["--seed=1", "--frames=600"] },
      { level: "V4", verb: "bot", args: ["--test=tests/bot_rally.gd", "--frames=1200"] },
    ],
  },
];

const events = [
  { type: "job_created", sentence: "a ball-and-paddle game in a walled court", packId, title: "Paddle Court" },
  {
    type: "brief_set",
    brief: {
      rules: "Two paddles, one ball. A ball passing a paddle scores for the other side. First to 5 wins.",
      arena: "A flat court 16 m by 9 m with walls on the long sides and open goal lines on the short sides.",
      ai: "The opponent paddle follows the ball with a reaction delay and a speed cap.",
      controls: "paddle_up and paddle_down move the player's paddle along the goal line.",
      mood: "Flat-shaded blocks, two team colours, soft top light.",
    },
    estimate: { packages: 3, wallMinutes: 20, tokens: 150000 },
  },
  { type: "brief_approved", by: "auto" },
  { type: "plan_set", packages },
];
fs.writeFileSync(
  path.join(dir, "job.jsonl"),
  events.map((e, i) => JSON.stringify({ v: 1, seq: i + 1, ts: ts(i), job, ...e })).join("\n") + "\n",
);

const manifest = {
  id: packId,
  version: "0.1.0",
  kernelApi: "0.1",
  title: "Paddle Court",
  capabilities: ["physics", "input", "rules", "ball", "ai"],
  entry: "scripts/main.gd",
  assets: [],
  tests: ["tests/bot_rally.gd"],
};
const mainGd = [
  "extends Node",
  "",
  "var _ctx",
  'var _score := {"left": 0, "right": 0}',
  "var _rally := 0",
  "",
  "func _pack_setup(ctx) -> void:",
  "\t_ctx = ctx",
  "",
  "func _pack_start() -> void:",
  "\t_rally = 0",
  "",
  "func _pack_tick(frame: int) -> void:",
  "\t_rally = frame",
  "",
  "func _pack_state() -> Dictionary:",
  '\treturn {"score": _score, "rally": _rally}',
  "",
].join("\n");
const botGd = [
  "extends Node",
  "",
  "var _ctx",
  "var _frames := 0",
  "",
  "func _bot_setup(ctx) -> void:",
  "\t_ctx = ctx",
  "",
  "func _bot_tick(frame: int) -> void:",
  "\t_frames = frame",
  "",
  "func _bot_done() -> bool:",
  "\treturn _frames >= 300",
  "",
  "func _bot_result() -> Dictionary:",
  '\treturn {"ok": true, "summary": "kept the ball in play for 300 frames"}',
  "",
].join("\n");
const courtGd = ["extends RefCounted", "", "static func build(ctx, layout: Dictionary) -> void:", "\tfor wall in layout.get(\"walls\", []):", "\t\tpass", ""].join("\n");
const aiGood = [
  "extends RefCounted",
  "",
  "func decide(ball_y: float, paddle_y: float, tuning: Dictionary) -> float:",
  '\tvar err: float = tuning.get("error_m", 0.3)',
  "\tif absf(ball_y - paddle_y) < err:",
  "\t\treturn 0.0",
  "\treturn signf(ball_y - paddle_y)",
  "",
].join("\n");
// Round 1 of paddle_ai: the builder says it is done, and the script errors at runtime.
const aiBroken = aiGood.replace("\treturn signf(ball_y - paddle_y)", "\treturn FAKE_SCRIPT_ERROR(ball_y - paddle_y)");

const script = {
  model: "fake",
  steps: [
    {
      match: { role: "builder", package: "core" },
      delayMs: 120,
      write: {
        "pack.json": JSON.stringify(manifest, null, 1) + "\n",
        "scripts/main.gd": mainGd,
        "tests/bot_rally.gd": botGd,
        "NOTES.txt": "builder scratch notes: this file is outside the package scope\n",
      },
      text: "Done. Wrote pack.json, scripts/main.gd, tests/bot_rally.gd.",
      tokensIn: 5200,
      tokensOut: 900,
    },
    {
      match: { role: "builder", package: "court" },
      delayMs: 120,
      write: {
        "data/court.json": JSON.stringify({ width_m: 16, depth_m: 9, wall_height_m: 1.2, walls: ["north", "south"], goals: ["west", "east"] }, null, 1) + "\n",
        "scripts/court.gd": courtGd,
      },
      text: "Done. Wrote data/court.json and scripts/court.gd.",
      tokensIn: 4100,
      tokensOut: 600,
    },
    {
      match: { role: "builder", package: "paddle_ai", round: 1 },
      delayMs: 120,
      write: {
        "data/ai.json": JSON.stringify({ reaction_frames: 8, max_speed_mps: 6.0, error_m: 0.3 }, null, 1) + "\n",
        "scripts/paddle_ai.gd": aiBroken,
      },
      text: "All done and verified: everything works perfectly.",
      tokensIn: 4300,
      tokensOut: 700,
    },
    {
      match: { role: "builder", package: "paddle_ai" },
      delayMs: 120,
      write: { "scripts/paddle_ai.gd": aiGood },
      text: "Fixed the call in decide().",
      tokensIn: 5000,
      tokensOut: 300,
    },
    {
      // The V5 critic at each milestone: scores for the default rubric.
      match: { role: "critic" },
      json: { ok: true, scores: { silhouette: 0.8, readability: 0.7, style_consistency: 0.7, shows_play: 0.6 }, notes: ["a single flat frame; the court outline reads clearly"] },
      tokensIn: 900,
      tokensOut: 80,
    },
  ],
};
fs.writeFileSync(path.join(dir, "fake-builder.json"), JSON.stringify(script, null, 1) + "\n");
// This job pins its runner: the bundled fake one, promoting into a directory of its own (never the real engine/).
fs.writeFileSync(path.join(dir, "foreman.config.json"), JSON.stringify({ godot: "@fake", engineDir: "engine-out" }, null, 1) + "\n");
// Whatever an in-place run left behind is removed: the fixture is the three files above.
for (const leftover of ["pack", "ws", "reports", "captures", "ref", "engine-out", "state.json", "foreman.lock", "children.jsonl"]) {
  fs.rmSync(path.join(dir, leftover), { recursive: true, force: true });
}
console.log(`fixture written to ${dir}`);
