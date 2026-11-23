#!/usr/bin/env node
// H1 hand: writes the probe's drills into a COPY of the pack's data/drills.json and the scene lists for hand_step.gd.
//   node hand_scenes.mjs <pack copy dir> <out dir>   -> <out>/scenes_move.json, scenes_pick.json, scenes_ring.json
import fs from 'node:fs'; import path from 'node:path';
const [pack, out] = process.argv.slice(2);
const file = path.join(pack, 'data/drills.json'); const D = JSON.parse(fs.readFileSync(file, 'utf8'));
D.drills = D.drills.filter((d) => !d.id.startsWith('h1_'));
const add = (d) => D.drills.push(d);
const far = [22, 13];
add({ id: 'h1_lane', place: { b0: [-22, 0, 1, 0] }, puck: far });
add({ id: 'h1_turn', place: { b0: [-22, -11, 1, 0] }, puck: far });
add({ id: 'h1_carry_lane', place: { b0: [-22, 0, 1, 0] }, puck: [-21.25, 0.3], carrier: 'b0' });
add({ id: 'h1_carry_turn', place: { b0: [-22, -11, 1, 0] }, puck: [-21.25, -10.7], carrier: 'b0' });
const S = (name, drill, frames, segs, wait = 15) => ({ name, drill, frames, segs, wait });
const move = [
  S('start', 'h1_lane', 200, [[0, 200, 1, 0, 0]]), S('release', 'h1_lane', 330, [[0, 150, 1, 0, 0]]),
  S('reverse', 'h1_lane', 330, [[0, 150, 1, 0, 0], [150, 330, -1, 0, 0]]), S('turn90', 'h1_turn', 270, [[0, 150, 1, 0, 0], [150, 270, 0, 1, 0]]),
  S('sprint', 'h1_lane', 240, [[0, 240, 1, 0, 1]]),
  S('tap3', 'h1_lane', 360, [[0, 3, 1, 0, 0]]), S('tap6', 'h1_lane', 360, [[0, 6, 1, 0, 0]]), S('tap12', 'h1_lane', 360, [[0, 12, 1, 0, 0]]),
  S('carry_start', 'h1_carry_lane', 200, [[0, 200, 1, 0, 0]]), S('carry_release', 'h1_carry_lane', 330, [[0, 150, 1, 0, 0]]),
  S('carry_reverse', 'h1_carry_lane', 330, [[0, 150, 1, 0, 0], [150, 330, -1, 0, 0]]), S('carry_turn90', 'h1_carry_turn', 270, [[0, 150, 1, 0, 0], [150, 270, 0, 1, 0]]),
  S('carry_sprint', 'h1_carry_lane', 240, [[0, 240, 1, 0, 1]]), S('carry_sprint_turn90', 'h1_carry_turn', 270, [[0, 150, 1, 0, 1], [150, 270, 0, 1, 1]]),
  S('carry_tap6', 'h1_carry_lane', 360, [[0, 6, 1, 0, 0]]),
];
// Pick-up 1: he glides at v (no keys, as placed, facing +x) over a still puck that lies `off` m beside his line.
const pick = [];
for (const v of [2, 4, 6, 8, 10, 12]) for (const off of [-1.8, -1.2, -0.6, 0, 0.6, 1.2, 1.8]) {
  const id = `h1_pk_${v}_${off}`; add({ id, place: { b0: [-20, 0, 1, 0] }, velocity: { b0: [v, 0] }, puck: [-12, off] });
  pick.push(S(`pick_v${v}_o${off}`, id, Math.ceil(10 / v * 60) + 30, [], 0));
}
// Pick-up 2: he stands (no keys) facing +x; a loose puck comes at him from `ang` degrees off his facing, at u m/s, aimed `off` m beside his centre.
for (const ang of [0, 90, 180]) for (const u of [4, 8, 12, 16, 20, 24]) for (const off of [0, 0.8]) {
  const a = ang * Math.PI / 180, dir = [Math.cos(a), Math.sin(a)], side = [-dir[1], dir[0]], p = [6 * dir[0] + off * side[0], 6 * dir[1] + off * side[1]];
  const id = `h1_rc_${ang}_${u}_${off}`; add({ id, place: { b0: [0, 0, 1, 0] }, puck: [+p[0].toFixed(3), +p[1].toFixed(3)], puck_vel: [+(-u * dir[0]).toFixed(3), +(-u * dir[1]).toFixed(3)] });
  pick.push(S(`recv_a${ang}_u${u}_o${off}`, id, 60, [], 0));
}
// R-0069: a still puck in his ring, he stands still and presses nothing: is it his, and when?
const ring = [];
for (const d of [0.6, 0.9, 1.2, 1.4, 1.6, 1.9]) for (const ang of [0, 90, 180, 270]) {
  const a = ang * Math.PI / 180, id = `h1_ring_${d}_${ang}`; add({ id, place: { b0: [0, 0, 1, 0] }, puck: [+(d * Math.cos(a)).toFixed(3), +(d * Math.sin(a)).toFixed(3)] });
  ring.push(S(`ring_d${d}_a${ang}`, id, 40, [], 0));
}
fs.writeFileSync(file, JSON.stringify(D, null, 1));
fs.mkdirSync(out, { recursive: true });
for (const [n, l] of [['move', move], ['pick', pick], ['ring', ring]]) fs.writeFileSync(path.join(out, `scenes_${n}.json`), JSON.stringify(l));
console.log(JSON.stringify({ drills: D.drills.length, move: move.length, pick: pick.length, ring: ring.length }));
