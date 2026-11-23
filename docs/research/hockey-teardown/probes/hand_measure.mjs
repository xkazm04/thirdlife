#!/usr/bin/env node
// H1 hand: the same measures from both games' step-response CSVs (columns age,x,z,speed,...; one row per frame at 60 Hz).
//   node hand_measure.mjs <ours dir> <thirdjam dir>    -> one JSON line {ours, tj}
// Scenes (hand_scenes.mjs): start/sprint/taps from rest; release, reverse (the 180), turn90 act at age 150 after 150 frames of full stick.
import fs from 'node:fs'; import path from 'node:path';
const read = (d, n) => { const f = path.join(d, n + '.csv'); if (!fs.existsSync(f)) return null;
  const [h, ...l] = fs.readFileSync(f, 'utf8').trim().split('\n'); const k = h.split(',');
  return l.map((r) => { const v = r.split(','); const o = {}; k.forEach((c, i) => (o[c] = c === 'holder' ? v[i] : +v[i])); return o; }); };
const first = (rows, f, from = 0) => { for (let i = from; i < rows.length; i++) if (f(rows[i], i)) return i; return -1; };
const r2 = (x) => (x == null || x < 0 && x !== -1 ? x : +(+x).toFixed(2));
const ACT = 150;

function scenes(d, pre = '') {
  const o = {}; const st = read(d, pre + 'start'); if (!st) return o;
  const top = Math.max(...st.map((r) => r.speed)); o.top = r2(top);
  for (const q of [50, 90]) { const i = first(st, (r) => r.speed >= q / 100 * top); o[`to${q}_f`] = i; o[`to${q}_m`] = r2(st[i].x - st[0].x); }
  o.first_motion_f = first(st, (r) => r.speed > 0.01);
  const rl = read(d, pre + 'release'); if (rl) { o.release_v1s = r2(rl[ACT + 60].speed); o.release_m1s = r2(rl[ACT + 60].x - rl[ACT].x);
    o.release_decel = r2((rl[ACT].speed - rl[ACT + 60].speed)); }
  const rv = read(d, pre + 'reverse'); if (rv) {
    const still = first(rv, (r, i) => i > ACT && (r.speed < 0.3 || r.x < rv[i - 1].x), ACT + 1);
    o.rev_v0 = r2(rv[ACT].speed); o.rev_still_f = still - ACT; o.rev_still_m = r2(Math.max(...rv.slice(ACT, still + 1).map((r) => r.x)) - rv[ACT].x);
    o.rev_back6_f = first(rv, (r, i) => i > still && r.x < rv[i - 1].x && r.speed >= 6, still) - ACT;
    const t90 = top * 0.9; o.rev_back90_f = first(rv, (r, i) => i > still && r.x < rv[i - 1].x && r.speed >= t90, still) - ACT; }
  const tn = read(d, pre + 'turn90'); if (tn) {
    const hd = (i) => Math.atan2(tn[i].z - tn[i - 1].z, tn[i].x - tn[i - 1].x);
    const face = first(tn, (r, i) => i > ACT && (r.fz ?? 0) > 0.999, ACT + 1);
    const head = first(tn, (r, i) => i > ACT && Math.abs(hd(i) - Math.PI / 2) < 10 * Math.PI / 180, ACT + 1);
    const seg = tn.slice(ACT, head + 1);
    o.t90_v0 = r2(tn[ACT].speed); o.t90_facing_f = face > 0 ? face - ACT : -1; o.t90_heading_f = head - ACT;
    o.t90_min_v = r2(Math.min(...seg.map((r) => r.speed))); o.t90_max_v = r2(Math.max(...tn.slice(ACT).map((r) => r.speed)));
    o.t90_overshoot_m = r2(Math.max(...tn.slice(ACT).map((r) => r.x)) - tn[ACT].x); o.t90_v_at_heading = r2(tn[head].speed); }
  const sp = read(d, pre + 'sprint'); if (sp) { const s = Math.max(...sp.map((r) => r.speed)); o.sprint_top = r2(s); o.sprint_gain = r2(s / top);
    o.sprint_to90_f = first(sp, (r) => r.speed >= 0.9 * s); o.sprint_v_at_240 = r2(sp[Math.min(240, sp.length - 1)].speed); }
  for (const n of [3, 6, 12]) { const t = read(d, pre + 'tap' + n); if (!t) continue;
    o[`tap${n}_peak`] = r2(Math.max(...t.map((r) => r.speed))); o[`tap${n}_m_release`] = +(t[n].x - t[0].x).toFixed(3); o[`tap${n}_m_1s`] = r2(t[n + 60].x - t[0].x); }
  return o;
}

// The carrier: the puck's distance from the body's centre through each scene (ours only: the port carries no puck).
function puck(d) {
  const o = {};
  for (const n of ['carry_start', 'carry_release', 'carry_reverse', 'carry_turn90', 'carry_sprint', 'carry_sprint_turn90', 'carry_tap6']) {
    const t = read(d, n); if (!t || !('px' in t[0])) continue;
    const dist = t.map((r) => Math.hypot(r.px - r.x, r.pz - r.z)); const held = t.map((r) => r.holder === 'b0');
    const lost = first(t, (r, i) => i > 0 && !held[i]);
    o[n] = { held_all: lost < 0, lost_at: lost, d_min: r2(Math.min(...dist.slice(1))), d_max: r2(Math.max(...dist.slice(1))),
      d_after_act: n.includes('turn') || n.includes('reverse') || n.includes('release') ? r2(Math.max(...dist.slice(ACT, ACT + 60))) : null };
  }
  return o;
}

if (process.argv[1].endsWith('hand_measure.mjs')) {
  const [ours, tj] = process.argv.slice(2);
  console.log(JSON.stringify({ ours: { free: scenes(ours), carrier: scenes(ours, 'carry_'), puck: puck(ours) }, tj: { free: scenes(tj), carrier: scenes(tj, 'carry_') } }));
}
