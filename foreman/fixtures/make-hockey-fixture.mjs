// Regenerates fixtures/job-hockey-change/ (P10): the plan of the real hockey job of 2026-11-11
// (site/ice-hockey-three-against-20261111-1: four packages, their real scopes, acceptance and registers; contracts
// shortened) and a fake builder script that replays its FIRST change request, events 232 to 279 of that log:
//   the owner (hockey_core) makes the puck 0.35 m and merges; hockey_ai's own bot then fails on the merged pack and
//   hockey_ai is rebuilt; the rebuild passes its own bot (tests/bot_hockey_ai.gd) and breaks the owner's
//   (tests/bot_hockey.gd: the player loses 1 : 3). In the real job nothing ran that bot again until the final
//   verification, which failed the job. A third round of hockey_ai (the fix) is scripted for the Foreman that sends
//   the failure back.
// The fake runner's markers stand for the game: FAKE_TEST_NEEDS(<bot>:<token>) makes one bot fail until some file
// holds FAKE_HAS(<token>).
// Run: node fixtures/make-hockey-fixture.mjs      (only needed when the fixture itself changes)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const dir = path.join(here, "job-hockey-change");
fs.mkdirSync(dir, { recursive: true });

const job = "ice-hockey-change-replay-1";
const packId = "game.ice_hockey_three_against";
const title = "Ice hockey, three against three";
const ts = (n) => `2026-11-11T01:22:${String(n).padStart(2, "0")}.000Z`;
const lint = { level: "V1", verb: "lint", args: [] };
const smoke = { level: "V2", verb: "smoke", args: [] };
const inv = { level: "V3", verb: "invariants", args: [] };
const bot = (test, seed) => ({ level: "V4", verb: "bot", args: [`--seed=${seed}`, `--test=tests/${test}.gd`] });

const packages = [
  {
    id: "hockey_core",
    title: "Rink, puck, skaters, goals and the rule",
    milestone: "blockout",
    deps: [],
    scope: ["scripts/main.gd", "scripts/rink_api.gd", "data/venue.json", "data/tuning.json", "tests/bot_hockey.gd"],
    registers: { capabilities: ["physics", "input", "ui", "camera", "rules", "ball", "kit", "style", "biped"], tests: ["tests/bot_hockey.gd"], cameras: ["arena"] },
    contract:
      "scripts/main.gd: the entry script; builds the rink from data/venue.json, six skaters, the puck and two goals; first to rules.score_to_win goals wins.\n" +
      "data/tuning.json: rules.score_to_win, skater.skate_speed, shoot.speed, puck.radius, puck.height, puck.color, camera.pos, camera.fov.\n" +
      "scripts/rink_api.gd: puck_pos(), skater_pos(team, i), nearest_to_puck(team), set_ai(callable).\n" +
      "Input actions: move_up, move_down, move_left, move_right, shoot. The player is skater b0 of the blue team.\n" +
      "PLAYER CHECK: tests/bot_hockey.gd fails when the player's skater b0 took no shot or the blue team lost; it drives b0 through the input actions.",
    acceptance: [lint, smoke, bot("bot_hockey", 1), bot("bot_hockey", 2), inv],
  },
  {
    id: "hockey_ai",
    title: "Teammates and opponents",
    milestone: "greybox",
    deps: ["hockey_core"],
    scope: ["scripts/ai/*", "gen/ai_hook.gd", "data/ai.json", "tests/bot_hockey_ai.gd"],
    registers: { capabilities: ["ai", "physics"], assets: ["gen/ai_hook.gd"], tests: ["tests/bot_hockey_ai.gd"] },
    contract:
      "scripts/ai/brain.gd: decide(team, i, api) -> {move: Vector2, shoot: bool} for the five skaters the player does not control.\n" +
      "data/ai.json: red_skill (0..1), chase_radius_m, yield_radius_m.\n" +
      "tests/bot_hockey_ai.gd: with the player idle, both AI teams reach the puck and at least one goal falls.",
    acceptance: [lint, smoke, bot("bot_hockey_ai", 1), bot("bot_hockey_ai", 2), inv],
  },
  {
    id: "hockey_look",
    title: "Stands, markings, light",
    milestone: "art_pass",
    deps: ["hockey_core"],
    scope: ["gen/art_hook.gd", "data/venue_art.json"],
    registers: { capabilities: ["kit", "style"], assets: ["gen/art_hook.gd"] },
    contract: "gen/art_hook.gd adds the stands, the rink markings and the light masts from kit parts listed in data/venue_art.json; the view `arena` shows them.",
    acceptance: [lint, smoke, inv],
  },
  {
    id: "hockey_fx",
    title: "Sounds and goal effects",
    milestone: "tuned",
    deps: ["hockey_core"],
    scope: ["gen/fx_hook.gd", "scripts/fx/*", "data/fx.json"],
    registers: { capabilities: ["audio", "vfx"], assets: ["gen/fx_hook.gd"] },
    contract: "scripts/fx/fx.gd plays a horn and a burst at the goal on rules' `goal` event; volumes and sizes in data/fx.json.",
    acceptance: [lint, smoke, bot("bot_hockey", 1), inv],
  },
];

const events = [
  { type: "job_created", sentence: "Ice hockey, three against three: skaters, a puck, two goals, first to three goals wins. I play one skater with WASD and shoot with space.", packId, title },
  {
    type: "brief_set",
    brief: {
      rules: "Three skaters a side, one puck, two goals. First to three goals wins.",
      arena: "An ice rink 60 m by 30 m with boards and two goals.",
      ai: "Two blue teammates and three red opponents chase, pass and shoot.",
      controls: "WASD moves the player's skater (blue b0), space shoots.",
      mood: "Bright arena light, clean ice, two team colours.",
    },
    estimate: { packages: 4, wallMinutes: 60, tokens: 1400000 },
  },
  { type: "brief_approved", by: "auto" },
  { type: "plan_set", packages },
];
fs.writeFileSync(path.join(dir, "job.jsonl"), events.map((e, i) => JSON.stringify({ v: 1, seq: i + 1, ts: ts(i), job, ...e })).join("\n") + "\n");

const json = (v) => JSON.stringify(v, null, 1) + "\n";
const tuning = (puck, camera) => json({ rules: { score_to_win: 3 }, skater: { skate_speed: 7.5, radius: 0.45 }, shoot: { speed: 18 }, puck, camera });
const TUNING_FIRST = tuning({ radius: 0.15, height: 0.05, color: [0.25, 0.25, 0.28] }, { pos: [0, 38, 22], fov: 50 });
// The first change request as the real builder made it: nine times the contract's radius, near-black, camera higher.
const TUNING_BIG = tuning({ radius: 0.35, height: 0.18, color: [0.02, 0.02, 0.03] }, { pos: [0, 52, 14], fov: 50 });
const venue = json({
  rink: { length_m: 60, width_m: 30, corner_radius_m: 8.5 },
  props: [
    { kind: "rink", at: [0, 0, 0] },
    { kind: "goal", at: [-26, 0, 0], team: "blue" },
    { kind: "goal", at: [26, 0, 0], team: "red" },
  ],
});
const mainGd = (extra) =>
  [
    "extends Node",
    "",
    "var _ctx",
    'var _score := {"blue": 0, "red": 0}',
    "",
    "func _pack_setup(ctx) -> void:",
    "\t_ctx = ctx",
    '\tctx.cameras.add_view("arena")',
    "",
    "func _pack_tick(frame: int) -> void:",
    "\tpass",
    "",
    "func _pack_state() -> Dictionary:",
    '\treturn {"score": _score}',
    ...extra,
    "",
  ].join("\n");
const rinkApi = ["extends RefCounted", "", "func puck_pos() -> Vector3:", "\treturn Vector3.ZERO", ""].join("\n");
const botGd = (summary) =>
  [
    "extends Node",
    "",
    "var _frames := 0",
    "",
    "func _bot_tick(frame: int) -> void:",
    "\t_frames = frame",
    "",
    "func _bot_done() -> bool:",
    "\treturn _frames >= 600",
    "",
    "func _bot_result() -> Dictionary:",
    `\treturn {"ok": true, "summary": "${summary}"}`,
    "",
  ].join("\n");
const brain = (extra) => ["extends RefCounted", "", "func decide(team: String, i: int, api) -> Dictionary:", '\treturn {"move": Vector2.ZERO, "shoot": false}', ...extra, ""].join("\n");
const hook = (what) => ["extends RefCounted", "", "static func build(ctx) -> void:", `\tpass # ${what}`, ""].join("\n");

const script = {
  model: "fake",
  steps: [
    {
      // Event 234 of the real log: the Planner names the owner of a request that names none.
      match: { role: "planner", promptIncludes: "The player's change request" },
      json: { package: "hockey_core", reason: "The puck's size and colour, and the camera framing of the rink and goals, are all defined in the root package's files (data/tuning.json, data/venue.json, scripts/main.gd)" },
      tokensIn: 3498,
      tokensOut: 143,
    },
    {
      match: { role: "builder", package: "hockey_core", round: 1 },
      write: { "scripts/main.gd": mainGd([]), "scripts/rink_api.gd": rinkApi, "data/venue.json": venue, "data/tuning.json": TUNING_FIRST, "tests/bot_hockey.gd": botGd("blue 3 : 0 red, the player took 5 shots") },
      text: "Built the rink, the puck, six skaters, two goals and the rule.\nDEVIATIONS: none",
    },
    {
      // Events 237 to 249: the owner's round after the change request. The bigger puck breaks the AI's own bot.
      match: { role: "builder", package: "hockey_core" },
      write: { "data/tuning.json": TUNING_BIG, "scripts/main.gd": mainGd(["# the puck is 0.35 m now: FAKE_TEST_NEEDS(bot_hockey_ai:big_puck)"]) },
      text:
        "Made the puck bigger and near-black and raised the camera.\nDEVIATIONS:\n- The puck is now radius 0.35 m, height 0.18 m and near-black. The contract said the default puck part, about 0.04 m radius, and the earlier build used 0.15 m. Dependent packages should not assume the small size for the puck's visuals, effects or reach.\n- The camera is now pos [0,52,14], so both goals and the whole rink are in view.",
    },
    {
      match: { role: "builder", package: "hockey_ai", round: 1 },
      write: { "scripts/ai/brain.gd": brain([]), "gen/ai_hook.gd": hook("rink_api.set_ai(brain.decide)"), "data/ai.json": json({ red_skill: 0.9, chase_radius_m: 30, yield_radius_m: 0 }), "tests/bot_hockey_ai.gd": botGd("both AI teams reached the puck; 2 goals") },
      text: "Wrote the brain for five skaters.\nDEVIATIONS: none",
    },
    {
      // Events 262 to 274: the rebuild. It passes its own bot again and takes the game from the player: the owner's
      // bot (tests/bot_hockey.gd) now loses 1 : 3. Nothing in the real job ran that bot before the final verification.
      match: { role: "builder", package: "hockey_ai", round: 2 },
      write: { "scripts/ai/brain.gd": brain(["# reach scaled to the big puck: FAKE_HAS(big_puck)", "# red forwards reach every loose puck first: FAKE_TEST_NEEDS(bot_hockey:player_gets_the_puck)"]), "data/ai.json": json({ red_skill: 0.9, chase_radius_m: 30, yield_radius_m: 0 }) },
      text: "Adapted the skaters' reach to the bigger puck.\nDEVIATIONS:\n- Reach and stick radius follow puck.radius from data/tuning.json.",
    },
    {
      // What the real job needed a second change request for: the AI yields to the player.
      match: { role: "builder", package: "hockey_ai" },
      write: { "scripts/ai/brain.gd": brain(["# reach scaled to the big puck: FAKE_HAS(big_puck)", "# blue teammates and red forwards yield while b0 is near the puck"]), "data/ai.json": json({ red_skill: 0.6, chase_radius_m: 30, yield_radius_m: 4.5 }) },
      text:
        "The AI yields to the player's skater.\nDEVIATIONS:\n- `red_skill` is 0.6, not the contract default of 0.9.\n- Blue AI yields the puck to b0 when b0 is the nearest blue skater. Red non-back skaters hold back while b0 is within 4.5 m of the puck and they are more than 3 m away.",
    },
    {
      match: { role: "builder", package: "hockey_look" },
      write: { "gen/art_hook.gd": hook("stands, markings, light masts"), "data/venue_art.json": json({ props: [{ kind: "stand", at: [0, 0, -19] }, { kind: "stand", at: [0, 0, 19] }, { kind: "light_mast", at: [-30, 0, -17] }] }) },
      text: "Added stands and masts.\nDEVIATIONS: none",
    },
    {
      match: { role: "builder", package: "hockey_fx" },
      write: { "gen/fx_hook.gd": hook("fx.gd on rules.goal"), "scripts/fx/fx.gd": ["extends RefCounted", "", "func on_goal(team: String) -> void:", "\tpass", ""].join("\n"), "data/fx.json": json({ horn_volume_db: -6, burst_size_m: 2.5 }) },
      text: "Horn and burst on a goal.\nDEVIATIONS: none",
    },
    {
      match: { role: "critic" },
      json: { ok: true, scores: { silhouette: 0.8, readability: 0.7, style_consistency: 0.7, shows_play: 0.7 }, notes: ["the rink and both goals read clearly"] },
    },
  ],
};
fs.writeFileSync(path.join(dir, "fake-builder.json"), JSON.stringify(script, null, 1) + "\n");
fs.writeFileSync(path.join(dir, "foreman.config.json"), JSON.stringify({ godot: "@fake", engineDir: "engine-out" }, null, 1) + "\n");
for (const leftover of ["pack", "ws", "reports", "captures", "ref", "engine-out", "promoted", "state.json", "foreman.lock", "children.jsonl", "inbox.jsonl", "inbox.rejected.jsonl"]) {
  fs.rmSync(path.join(dir, leftover), { recursive: true, force: true });
}
console.log(`fixture written to ${dir}`);
