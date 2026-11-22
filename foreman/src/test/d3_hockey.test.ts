// D3 of 22 Nov, round 5: what hockey -2 (ice-hockey-frozen-pond-20261122-2) taught the arcade_sport template.
// Its design chose a low chase camera behind the skater; the critic could find neither the puck nor the player, and the
// near skater covered every exchange. Its tofu bot passed every row while every strip showed 3 to 6 skaters merged into
// one blob. Now the template keeps the house camera and the readable puck (read from the house game's own data), and the
// tofu stage has two spacing rows measured as the house hockey measures them.
import { test } from "node:test";
import assert from "node:assert/strict";
import { HOUSE_BOTS, houseFigures } from "../house.js";
import { houseExcerpt, houseKeepProblems, templateOf, type Template } from "../templates.js";
import { judgeTofu, tofuLine, tofuMetricsFor } from "../tofu.js";

const sport = templateOf("arcade_sport") as Template;
const tpl = { id: "arcade_sport" as const, reference: "r", copies: [] };

test("arcade_sport keeps the house camera and the readable puck: hockey -2's camera words fail, the house game's pass", () => {
  // hockey -2's own words (its brief's arena and design.feel.camera).
  const lowChase = "Low Chase Camera: ride right behind your skater with the net ahead. The camera sits low behind the player.";
  const problems = houseKeepProblems(lowChase, tpl);
  assert.ok(problems.some((p) => /keeps the play camera: a broadcast camera from the near side looking DOWN/.test(p)));
  assert.ok(problems.some((p) => /keeps the puck and your skater readable at a glance/.test(p)));
  const house = "A broadcast camera looks down at 50 degrees from the near side and follows the puck. The puck is drawn bigger with a hot rim, and a green ring under your skater marks you. The puck sticks to the blade on a spring. Passing beats skating: the carrier is slower (x0.88). The AI scores SHOOT, PASS and CARRY every 15 frames with vetoes.";
  assert.deepEqual(houseKeepProblems(house, tpl), []);
});

test("the builder reads the house hockey's camera and puck look live from its data/tuning.json", () => {
  const ex = houseExcerpt(sport, "builder");
  assert.match(ex, /- the play camera \(data\/tuning\.json `follow`[^\n]*: \{"fov":\d+,"pitch_deg":\d+/);
  assert.match(ex, /- the readable puck and rings \(data\/tuning\.json `look`[^\n]*: \{"puck_scale":[\d.]+,"puck_height_scale":[\d.]+,"puck_rim":[\d.]+/);
  assert.doesNotMatch(ex, /"names":\{/, "only the puck and ring keys of `look`, not its labels");
});

test("the spacing rows: a scrum or merged bodies fail the tofu stage; not measured fails; the house figures read the same way", () => {
  const rows = tofuMetricsFor(tpl);
  assert.deepEqual(rows.filter((m) => m.id === "scrum_share" || m.id === "overlap_share").map((m) => [m.id, m.max]), [["scrum_share", 0.3], ["overlap_share", 0.02]]);
  assert.match(tofuLine(tpl), /possession_median_f, scrum_share, overlap_share$/);
  const spacing = rows.filter((m) => m.id === "scrum_share" || m.id === "overlap_share");
  assert.equal(judgeTofu({ scrum_share: 0.19, overlap_share: 0 }, spacing, "tests/bot_tofu.gd").ok, true, "the house hockey's own figures pass");
  const scrum = judgeTofu({ scrum_share: 0.45, overlap_share: 0.06 }, spacing, "tests/bot_tofu.gd");
  assert.equal(scrum.ok, false);
  assert.match(scrum.line, /scrum_share 0\.45 \(wants <= 0\.3[^]*overlap_share 0\.06 \(wants <= 0\.02/);
  assert.match(judgeTofu({}, spacing, "tests/bot_tofu.gd").line, /scrum_share not reported/, "hockey -2's bot did not count spacing: that fails");
  // The house ladder bot's raw counts (pro regular seed 1 on 22 Nov: crowd4 1225, overlap_frames 0 of 6598 live frames).
  const report = { bot: { result: { metrics: { raw: { live: 6598, crowd4: 1225, overlap_frames: 0, lengths: [120, 200] } } } } };
  const fig = houseFigures(report, HOUSE_BOTS["arcade_sport"] as NonNullable<(typeof HOUSE_BOTS)["arcade_sport"]>);
  assert.deepEqual([fig.metrics["scrum_share"], fig.metrics["overlap_share"]], [0.186, 0]);
});
