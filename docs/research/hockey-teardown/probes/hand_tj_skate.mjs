#!/usr/bin/env node
// H1 hand (23 Nov): thirdjam's skater law, frame by frame at 60 Hz, for step responses a person's keys give.
// A code integration (instrument (c) of the brief), NOT the running game: a port of UJamSim::StepSkater of the build that ran
// (C:/t/t5/Game/Source/JamCore/Private/JamSim.cpp:1266-1478, constants JamSim.h:499-505, JamCartridge.h FJamSkaterConfig,
// hockey.regular: speed 11, accel 12, turn 5, grip 3, glide 0.147). Free skater path only: no lunge, spin, zone, breakaway, contact.
// It is checked against the build's own automation TIMING lines (Jam.Core.Movement.*, run headless on .tl/tj-run): see check().
//   node hand_tj_skate.mjs [--csv <dir>]      prints one JSON line of measures; with --csv writes curves tj_<scene>.csv
import fs from 'node:fs'; import path from 'node:path';
const DT = 1 / 60;
export const REG = { speed: 11, accel: 12, turn: 5, grip: 3, glide: 0.147, brake: 6, free: 1.15, carry: 0.92, sprint: 0.15, sprintCarry: 0.08,
  drain: 180, refill: 360, rev: 26, burstFrames: 20, burstMult: 1.8, ownStop: true, restFrames: 6, restKept: 3.0, restHold: 1.0 };
const SLOW = 2.0, REST = 1.0, CUTF = 10, CUTDOT = 0.5, REVDOT = -0.5, PIVOT = 0.5, CAP = 0.97;
const wrap = (a) => { while (a > Math.PI) a -= 2 * Math.PI; while (a < -Math.PI) a += 2 * Math.PI; return a; };
const rot = (y, t, st) => { const d = wrap(t - y); return Math.abs(d) <= st ? t : y + Math.sign(d) * st; };
const mt = (a, b, d) => (Math.abs(b - a) <= d ? b : a + Math.sign(b - a) * d);
const dot = (a, b) => a[0] * b[0] + a[1] * b[1];
const len = (a) => Math.hypot(a[0], a[1]);

export function skater(c = REG, o = {}) {
  return { p: [0, 0], v: o.v ?? [0, 0], yaw: o.yaw ?? 0, stam: c.drain * c.refill, hist: Array(CUTF).fill(null).map(() => [0, 0]), hi: 0,
    burst: 0, earned: false, rest: o.rest ?? c.restFrames, revLast: false, carrying: !!o.carrying, c };
}

// One frame. move = [x, y] (keys: length 1), sprint, brake: booleans.
export function step(s, move, sprint = false, brake = false) {
  const c = s.c, full = c.drain * c.refill; let mag = len(move);
  const carryMul = s.carrying ? c.carry : 1, sb = s.carrying ? c.sprintCarry : c.sprint;
  const wantSprint = sprint && sb > 0 && s.stam > 0 && mag * mag > 0.0025;
  if (wantSprint) s.stam = Math.max(0, s.stam - c.refill); else if (s.stam < full) s.stam = Math.min(full, s.stam + c.drain);
  let sprintMul = wantSprint ? 1 + sb : 1;
  if (s.carrying && wantSprint) sprintMul = Math.max(1, Math.min(sprintMul, (1 + c.sprint) * CAP / carryMul));
  let first = false;
  if (c.burstFrames > 0) {
    const md = mag * mag > 0.0025 ? [move[0] / mag, move[1] / mag] : [0, 0]; let cut = false;
    if (md[0] || md[1]) for (const w of s.hist) if ((w[0] || w[1]) && dot(w, md) < CUTDOT) { cut = true; break; }
    if (cut) s.hist = s.hist.map(() => [...md]);
    s.hist[s.hi] = md; s.hi = (s.hi + 1) % CUTF;
    if (!c.ownStop) s.earned = false;
    const restKept = c.restKept > 0 ? Math.max(REST, c.restKept) : REST;
    const armOwn = cut || (dot(s.v, s.v) < SLOW * SLOW && (!c.ownStop || s.earned));
    const rested = c.restFrames > 0 && s.rest >= c.restFrames && dot(s.v, s.v) < restKept * restKept;
    if (armOwn) s.burst = c.burstFrames; else if (rested) s.burst = Math.max(s.burst, c.burstFrames);
    first = s.burst > 0; if (!(armOwn || rested) && s.burst > 0) s.burst--;
  }
  let braking = false, thrust = false; const freeMul = s.carrying ? 1 : c.free;
  const top0 = c.speed * sprintMul * carryMul * freeMul, acc = c.accel * sprintMul * carryMul * freeMul * (first ? Math.max(1, c.burstMult) : 1);
  if (mag > 1) { move = [move[0] / mag, move[1] / mag]; mag = 1; }
  thrust = mag > 0.05; const top = top0 * mag;
  if (mag > 0.05) s.yaw = rot(s.yaw, Math.atan2(move[1], move[0]), c.turn * DT);
  const f = [Math.cos(s.yaw), Math.sin(s.yaw)], V = len(s.v);
  const rev = c.rev > 0 && mag > 0.05 && !brake && V > 1e-6 && dot(move, s.v) < REVDOT * mag * V;
  if (rev) { const cut = c.rev * Math.min(mag, 1) * DT; if (V > 1) braking = true; s.v = V > cut ? [s.v[0] * (V - cut) / V, s.v[1] * (V - cut) / V] : [0, 0]; }
  else {
    let along = dot(s.v, f); let side = [s.v[0] - f[0] * along, s.v[1] - f[1] * along];
    const pivot = c.rev > 0 && mag > 0.05 && V < PIVOT && dot(move, f) < REVDOT * mag;
    if (pivot && c.restKept > 0) thrust = false;
    if (mag > 0.05 && !brake && !pivot && along < top) along = Math.min(top, along + acc * mag * DT);
    along = mt(along, 0, (c.glide + (brake ? c.brake : 0)) * DT);
    const k = Math.max(0, 1 - (c.grip + (brake ? c.brake * 0.5 : 0)) * DT); side = [side[0] * k, side[1] * k];
    s.v = [f[0] * along + side[0], f[1] * along + side[1]]; if (brake && V > 1) braking = true;
  }
  s.revLast = braking && rev;
  if (c.ownStop && c.burstFrames > 0) { if (braking) s.earned = true; else if (dot(s.v, s.v) >= SLOW * SLOW) s.earned = false; }
  if (c.restFrames > 0 && c.burstFrames > 0) {
    const v2 = dot(s.v, s.v), hold = Math.max(REST, c.restHold, c.restKept), push = thrust;
    if (v2 < REST * REST && !push) s.rest = Math.min(s.rest + 1, c.restFrames); else if (v2 >= hold * hold || push) s.rest = 0;
  }
  s.p = [s.p[0] + s.v[0] * DT, s.p[1] + s.v[1] * DT];
  return s;
}

// A scene: frames of [move, sprint] from a start; returns rows [frame, x, y, speed, yaw].
export function run(s, n, input) { const rows = [[0, ...s.p, len(s.v), s.yaw]]; for (let i = 1; i <= n; i++) { const [m, sp] = input(i, s); step(s, m, sp); rows.push([i, ...s.p, len(s.v), s.yaw]); } return rows; }
const firstAt = (rows, f) => { const r = rows.find(f); return r ? r[0] : -1; };

export function measure(c = REG, carrying = false) {
  const out = {}, curves = {};
  const top = c.speed * (carrying ? c.carry : c.free);
  const st = run(skater(c, { carrying }), 240, () => [[1, 0], false]); curves.start = st;
  for (const q of [0.5, 0.9]) { const f = firstAt(st, (r) => r[3] >= q * top); out[`to${q * 100}_f`] = f; out[`to${q * 100}_m`] = +st[f][1].toFixed(2); }
  out.top = +top.toFixed(3);
  const atTop = () => skater(c, { v: [top, 0], rest: 0, carrying });
  const gl = run(atTop(), 600, () => [[0, 0], false]); curves.release = gl;
  out.release_v_after_1s = +gl[60][3].toFixed(2); out.release_m_1s = +gl[60][1].toFixed(2); out.release_stop_s = +(top / c.glide).toFixed(0);
  const rv = run(atTop(), 240, () => [[-1, 0], false]); curves.reverse = rv;
  const still = firstAt(rv, (r) => r[3] < 0.05); out.reverse_still_f = still; out.reverse_still_m = +rv[still][1].toFixed(2);
  out.reverse_back6_f = firstAt(rv, (r, i) => i > 0 && r[1] < rv[i - 1]?.[1] && r[3] >= 6);
  for (const deg of [90, 180]) {
    const a = deg * Math.PI / 180, m = [Math.cos(a), Math.sin(a)];
    const tr = run(atTop(), 240, () => [m, false]); curves[`turn${deg}`] = tr;
    const face = firstAt(tr, (r) => Math.abs(wrap(r[4] - a)) < 1e-3);
    const head = firstAt(tr, (r, i) => i > 0 && Math.abs(wrap(Math.atan2(r[2] - tr[i - 1][2], r[1] - tr[i - 1][1]) - a)) < 0.1 && r[3] > 0.5);
    let minv = 99; for (const r of tr.slice(0, head > 0 ? head + 1 : 240)) minv = Math.min(minv, r[3]);
    const xs = tr.slice(0, head > 0 ? head + 1 : 240).map((r) => r[1]), ys = tr.slice(0, head > 0 ? head + 1 : 240).map((r) => r[2]);
    out[`turn${deg}`] = { facing_f: face, heading_f: head, min_speed: +minv.toFixed(2), speed_at_heading: head > 0 ? +tr[head][3].toFixed(2) : null,
      width_m: +(Math.max(...xs) - Math.min(...xs)).toFixed(2), depth_m: +(Math.max(...ys) - Math.min(...ys)).toFixed(2), back_to_90pct_f: firstAt(tr, (r) => r[0] > (head > 0 ? head : 0) && r[3] >= 0.9 * top) };
  }
  if (!carrying) {
    const sp = run(skater(c), 600, () => [[1, 0], true]); curves.sprint = sp;
    out.sprint_top = +Math.max(...sp.map((r) => r[3])).toFixed(3); out.sprint_frames = c.drain; out.sprint_refill_frames = c.refill;
    out.sprint_to90_f = firstAt(sp, (r) => r[3] >= 0.9 * out.sprint_top);
  }
  for (const n of [3, 6, 12]) {
    const t = run(skater(c, { carrying }), 600, (i) => [i <= n ? [1, 0] : [0, 0], false]);
    out[`tap${n}`] = { v_peak: +Math.max(...t.map((r) => r[3])).toFixed(2), m_at_release: +t[n][1].toFixed(3), m_after_1s: +t[n + 60][1].toFixed(2), m_after_5s: +t[Math.min(n + 300, 600)][1].toFixed(2) };
    curves[`tap${n}`] = t;
  }
  out.first_motion_f = firstAt(st, (r) => r[3] > 0);   // in the sim step: the press frame itself moves the body
  return { out, curves };
}

// The build's automation lines to reproduce (copy of auto1.log TIMING lines is in the report): standing, input behind, 6 m/s after N frames.
export function check(c = REG) {
  const rv = run(skater(c, { v: [c.speed * c.free, 0], rest: 0 }), 240, () => [[-1, 0], false]);
  const behind = run(skater(c), 120, () => [[-1, 0], false]);
  return { reverse_still_f: firstAt(rv, (r) => r[3] < 1e-9), reverse_back6_f: firstAt(rv, (r, i) => i > 0 && r[1] < rv[i - 1][1] && r[3] >= 6),
    behind_to6_f: firstAt(behind, (r, i) => i > 0 && behind[i][1] < behind[i - 1][1] && r[3] >= 6) };
}

if ((process.argv[1] ?? '').endsWith('hand_tj_skate.mjs')) {
  const free = measure(REG, false), car = measure(REG, true);
  const j = process.argv.indexOf('--scenes');
  if (j > 0) { // the probe's own scene list (hand_scenes.mjs): the same keys, frame by frame, written as hand_step.gd writes ours
    const sc = JSON.parse(fs.readFileSync(process.argv[j + 1], 'utf8')), d = process.argv[j + 2]; fs.mkdirSync(d, { recursive: true });
    for (const c of sc) { const s = skater(REG, { carrying: c.drill.includes('carry') }); const rows = ['age,x,z,speed,fx,fz'];
      for (let a = 0; a <= c.frames; a++) { rows.push([a, s.p[0], s.p[1], len(s.v), Math.cos(s.yaw), Math.sin(s.yaw)].map((x) => +(+x).toFixed(4)).join(','));
        let k = [0, 0], sp = false; for (const g of c.segs) if (a >= g[0] && a < g[1]) { k = [g[2], g[3]]; sp = !!g[4]; } step(s, k, sp); }
      fs.writeFileSync(path.join(d, c.name + '.csv'), rows.join('\n') + '\n'); }
  }
  const i = process.argv.indexOf('--csv');
  if (i > 0) { const d = process.argv[i + 1]; fs.mkdirSync(d, { recursive: true });
    for (const [tag, m] of [['free', free], ['carry', car]]) for (const k in m.curves) fs.writeFileSync(path.join(d, `tj_${tag}_${k}.csv`), 'frame,x,y,speed,yaw\n' + m.curves[k].map((r) => r.map((x) => +x.toFixed(4)).join(',')).join('\n')); }
  console.log(JSON.stringify({ tool: 'hand_tj_skate', free: free.out, carrier: car.out, check: check() }));
}
