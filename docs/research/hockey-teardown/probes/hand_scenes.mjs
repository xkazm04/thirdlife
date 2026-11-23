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
// Round 2, hits. The victim r0 stands at the centre facing b0 (front), across (side) or away (behind); b0 glides at v (no keys)
// from a 0.45 m surface gap and presses at age 0. As victim, b0 holds the up key (-z) from age 8 to show when his hand comes back.
const FACE = { front: [-1, 0], side: [0, 1], behind: [1, 0] };
const hit = [];
const H = (name, d, frames, extra = {}) => { add(d); hit.push({ name, drill: d.id, frames, segs: [], wait: 0, ...extra }); };
const at = (f, v, more = {}) => ({ place: { r0: [0, 0, ...f] }, place_from: { b0: ['r0', -0.45, 0, 1, 0] }, velocity: { b0: [v, 0] }, puck: far, ...more });
for (const [k, f] of Object.entries(FACE)) {
  for (const v of [4, 6, 9, 11]) {
    H(`check_${k}_v${v}`, { id: `h1_ck_${k}_${v}`, ...at(f, v) }, 200, { taps: [[0, 'check']] });
    if (v === 4 || v === 9) H(`cross_${k}_v${v}`, { id: `h1_cx_${k}_${v}`, ...at(f, v) }, 200, { taps: [[0, 'cross']] });
  }
  H(`bump_${k}_v9`, { id: `h1_bp_${k}`, ...at(f, 9) }, 120);
  const bf = k === 'front' ? [-1, 0] : k === 'side' ? [0, 1] : [1, 0];
  for (const [n, act] of [['victim', 'check'], ['victimx', 'cross']])
    H(`${n}_${k}_v9`, { id: `h1_${n}_${k}`, place: { b0: [0, 0, ...bf] }, place_from: { r0: ['b0', -0.45, 0, 1, 0] }, velocity: { r0: [9, 0] }, move: { r0: [1, 0] },
      puck: far, script: [[0, 'r0', act]] }, 260, { segs: [[8, 260, 0, -1, 0]] });
}
for (const [k, f, pk] of [['side', [0, 1], [0, 1.24]], ['behind', [1, 0], [1.24, 0]]]) for (const act of ['check', 'cross'])
  H(`carrier_${act}_${k}_v9`, { id: `h1_c${act}_${k}`, ...at(f, 9, { puck: pk, carrier: 'r0' }) }, 200, { taps: [[0, act]] });
H('held_front_v9', { id: 'h1_hd_front', place: { r0: [0, 0, -1, 0] }, place_from: { b0: ['r0', -3, 0, 1, 0] }, velocity: { b0: [9, 0] }, puck: far }, 200, { holds: [[0, 60, 'cross']] });
H('whiff_check', { id: 'h1_wf_ck', place: { b0: [-8, 0, 1, 0], r0: [6, 0, -1, 0] }, puck: far }, 120, { taps: [[0, 'check'], [14, 'check'], [40, 'check']] });
H('whiff_cross', { id: 'h1_wf_cx', place: { b0: [-8, 0, 1, 0], r0: [6, 0, -1, 0] }, puck: far }, 120, { taps: [[0, 'cross'], [14, 'cross'], [50, 'cross']] });
// pokes (E) at a standing carrier whose puck is 1.8 m from b0, in front of him and at his side: 10 tries each (the take is a dice roll)
for (const [k, b] of [['front', [2.93, 0.5, -1, 0]], ['side', [1.13, 2.3, 0, -1]]]) for (let i = 0; i < 20; i++)   // pressed at 30: a new carrier cannot be poked for 24 frames
  H(`poke_${k}_${i}`, { id: `h1_pk_${k}_${i}`, place: { r0: [0, 0, 1, 0], b0: b }, puck: [1.24, 0], carrier: 'r0' }, 100, { taps: [[30, 'poke']] });
// the cross-check timed as a person times it: pressed when the gap closes in its wind-up (10 frames at v)
for (const [k, f] of Object.entries(FACE)) for (const v of [4, 9]) {
  const g = +(v * 10 / 60).toFixed(2), ge = +(v * 10 / 60 + 0.5).toFixed(2);
  H(`crosse_${k}_v${v}`, { id: `h1_ce_${k}_${v}`, place: { r0: [0, 0, ...f] }, place_from: { b0: ['r0', -ge, 0, 1, 0] }, velocity: { b0: [v, 0] }, puck: far }, 200, { taps: [[0, 'cross']] });
  H(`crosst_${k}_v${v}`, { id: `h1_ct_${k}_${v}`, place: { r0: [0, 0, ...f] }, place_from: { b0: ['r0', -g, 0, 1, 0] }, velocity: { b0: [v, 0] }, puck: far }, 200, { taps: [[0, 'cross']] });
}
for (const [k, f, pk] of [['side', [0, 1], [0, 1.24]], ['behind', [1, 0], [1.24, 0]]])
  H(`carrier_crosst_${k}_v9`, { id: `h1_cct_${k}`, place: { r0: [0, 0, ...f] }, place_from: { b0: ['r0', -1.5, 0, 1, 0] }, velocity: { b0: [9, 0] }, puck: pk, carrier: 'r0' }, 200, { taps: [[0, 'cross']] });
fs.writeFileSync(file, JSON.stringify(D, null, 1));
fs.mkdirSync(out, { recursive: true });
for (const [n, l] of [['move', move], ['pick', pick], ['ring', ring], ['hit', hit]]) fs.writeFileSync(path.join(out, `scenes_${n}.json`), JSON.stringify(l));
console.log(JSON.stringify({ drills: D.drills.length, move: move.length, pick: pick.length, ring: ring.length, hit: hit.length }));
