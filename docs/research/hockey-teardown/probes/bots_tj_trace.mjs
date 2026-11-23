// H2: thirdjam's JamTournament -trace=1 lines -> the bots' positional figures, with BEHAVIOUR-BOTS.md's definitions.
// node trace.mjs <trace.txt> ; the carrier is INFERRED (the trace names none): the skater nearest the puck within 1.5 m
// who moved with it over the last 0.1 s (displacements within 0.5 m): see carrierOf().
import fs from "node:fs";
const file = process.argv[2]; const lines = fs.readFileSync(file, "utf8").split("\n");
const RE = /TRACE f=(\d+)( frozen)? stall=\d puck\(([-\d.]+),([-\d.]+) v([-\d.]+)\)(.*)/;
const SK = /(\d)([HPCSB])\(([-\d.]+),([-\d.]+)\)>[-\d.]+\[[-\d.]+,[-\d.]+( SHOOT)?\]/g;
const DEB = 4, GX = 41.2, THIRD = 15, R = [2.3, 3.0], NEAR = [5, 10];
const C = {}; const A = {}; const add = (k, v = 1) => (C[k] = (C[k] ?? 0) + v); const push = (k, v) => (A[k] ??= []).push(v);
let cand = -1, candN = 0, hist = [], prev = null, prevPuck = null, holder = -1, takeF = 0, reached = [false, false], possTeam = -1, touches = 0, live = 0, matches = [], still = {};
const HAND = !file.includes("_brain"); const team = (i) => (i < 5 ? 0 : 1); const cw = (i) => (HAND && i === 0 ? "human" : nm(team(i))); const nm = (t) => (t === 0 ? "blue" : "red");
function carrierOf(sk, px, py, hist) {           // positions print to 0.1 m: compare 6-frame displacements (0.1 s), not 1-frame speeds
  const old = hist.length >= 6 ? hist[hist.length - 6] : null; let best = -1, bd = 1.5;
  for (let i = 0; i < sk.length; i++) {
    const d = Math.hypot(sk[i].x - px, sk[i].y - py); if (d > bd) continue;
    if (old && Math.hypot((sk[i].x - old.sk[i].x) - (px - old.px), (sk[i].y - old.sk[i].y) - (py - old.py)) > 0.5) continue;
    best = i; bd = d;
  }
  return best;
}
function endCarry() { if (holder >= 0) for (let i = 0; i < 2; i++) if (!reached[i]) add(`reach_never_${i}_${cw(holder)}`); }
for (const ln of lines) {
  if (ln.includes('"tool"')) { const j = JSON.parse(ln.slice(ln.indexOf("{"))); matches.push(j); endCarry(); holder = -1; prev = null; hist = []; possTeam = -1; continue; }
  const m = RE.exec(ln); if (!m) continue;
  const f = +m[1], frozen = !!m[2], px = +m[3], py = +m[4], pv = +m[5];
  const sk = [...m[6].matchAll(SK)].map((s) => ({ t: +s[1], r: s[2], x: +s[3], y: +s[4], shoot: !!s[5] }));
  if (sk.length !== 10) continue;
  if (frozen) { endCarry(); holder = -1; prev = sk; hist = []; continue; }
  live++; const raw = carrierOf(sk, px, py, hist); hist.push({ sk, px, py }); if (hist.length > 8) hist.shift();
  if (raw === cand) candN++; else { cand = raw; candN = 1; }
  const h = candN >= DEB ? cand : holder;                   // debounce: a new carrier (or loose) only after DEB frames in a row
  add("f_third_" + (px <= -THIRD ? "blue_def" : px >= THIRD ? "blue_off" : "neutral"));
  if (h < 0) add("f_loose");
  if (h >= 0 && h !== holder) {
    endCarry(); const t = team(h);
    if (t !== possTeam) { if (possTeam >= 0) push(`chain_${nm(possTeam)}`, touches); possTeam = t; touches = 0; }
    touches++; holder = h; takeF = live - (DEB - 1); reached = [false, false]; add(`takes_${nm(t)}`);
  } else if (h < 0 && holder >= 0) { endCarry(); holder = -1; }
  if (h >= 0) {
    const t = team(h), w = nm(t), sg = t === 0 ? 1 : -1, wc = cw(h); add(`f_carry_${w}`); if (wc !== w) add(`f_carry_${wc}`);
    let dmin = 1e9; const nn = [0, 0];
    for (let i = 0; i < 10; i++) { if (team(i) === t) continue; const d = Math.hypot(sk[i].x - sk[h].x, sk[i].y - sk[h].y); dmin = Math.min(dmin, d); NEAR.forEach((r, j) => { if (d <= r) nn[j]++; }); }
    nn.forEach((n, j) => { add(`near${j}_${w}`, n); if (wc !== w) add(`near${j}_${wc}`, n); });
    for (let i = 0; i < 2; i++) if (!reached[i] && dmin <= R[i]) { reached[i] = true; push(`reach_${i}_${wc}`, live - takeF); }
    const o = nm(1 - t);
    if (px * sg <= -THIRD) { let fc = 0; for (let i = 0; i < 10; i++) if (team(i) !== t && sk[i].x * sg <= -THIRD) fc++; add(`fc_f_${o}`); add(`fc_n_${o}`, fc); if (fc >= 2) add(`fc_2_${o}`); }
    let front = false, slot = false;
    for (let i = 0; i < 10; i++) { if (i === h) continue; if (team(i) === t) { add(`mate_dist_${w}`, Math.hypot(sk[i].x - sk[h].x, sk[i].y - sk[h].y)); add(`mate_n_${w}`); if (Math.hypot(sk[i].x - GX * sg, sk[i].y) < 6) front = true; } else if (Math.hypot(sk[i].x + GX * sg, sk[i].y) < 8) slot = true; }
    add(`f_poss_${w}`); if (front) add(`netfront_${w}`); if (slot) add(`slotcover_${o}`);
  }
  let near4 = 0;
  for (const t of [0, 1]) {
    let cx = 0, cy = 0, ch = 0; const idx = [...Array(10).keys()].filter((i) => team(i) === t);
    for (const i of idx) { cx += sk[i].x / 5; cy += sk[i].y / 5; if (Math.hypot(sk[i].x - px, sk[i].y - py) < 5) ch++; }
    for (const i of idx) add(`spread_${nm(t)}`, Math.hypot(sk[i].x - cx, sk[i].y - cy) / 5);
    add(`chase_${nm(t)}`, ch); if (ch >= 2) add(`chase2_${nm(t)}`); near4 += ch;
  }
  if (near4 >= 4) add("scrum4");
  for (let i = 0; i < 10; i++) {
    const v = prev ? Math.hypot(sk[i].x - prev[i].x, sk[i].y - prev[i].y) * 60 : 1; const sg = team(i) === 0 ? 1 : -1;
    const crease = Math.hypot(sk[i].x + GX * sg, sk[i].y) < 4;          // a back keeping the crease is thirdjam's goalie: not idle
    if (v < 0.5 && i !== h && !crease) { still[i] = (still[i] ?? 0) + 1; if (still[i] === 120) add(`idle_${nm(team(i))}`); } else still[i] = 0;
  }
  prev = sk;
}
const med = (a) => { const s = [...(a ?? [])].sort((x, y) => x - y); return s.length ? s[Math.floor(s.length / 2)] : NaN; };
const min = live / 3600; const g = (k) => C[k] ?? 0; const r2 = (x) => +(+x).toFixed(2);
const out = { file, matches: matches.length, live_min: r2(min), live_min_per_match: r2(min / matches.length), blue_wins: matches.filter((j) => j.winner === 0 || j.result === "win").length, agg: {}, play: {} };
for (const w of HAND ? ["human"] : []) { const a = A[`reach_0_human`] ?? []; const nev = g(`reach_never_0_human`); const tot = a.length + nev; const a3 = A[`reach_1_human`] ?? []; const n3 = g(`reach_never_1_human`);
  out.agg.carrier_human = { reach_2_3m: { med_f: med(a), within60: r2(a.filter((x) => x <= 60).length / tot), never: r2(nev / tot), carries: tot }, reach_3m: { med_f: med(a3), within60: r2(a3.filter((x) => x <= 60).length / (a3.length + n3)), never: r2(n3 / (a3.length + n3)) }, opp_within_5m: r2(g("near0_human") / g("f_carry_human")), opp_within_10m: r2(g("near1_human") / g("f_carry_human")) }; }
for (const w of ["blue", "red"]) {
  const rc = (i) => { const a = A[`reach_${i}_${w}`] ?? []; const nev = g(`reach_never_${i}_${w}`); const tot = a.length + nev; return { med_f: med(a), within60: r2(a.filter((x) => x <= 60).length / tot), never: r2(nev / tot), carries: tot }; };
  const o = w === "blue" ? "red" : "blue"; const ti = w === "blue" ? 0 : 1;
  const pt = matches[0]?.tool === "thirdjam.playtest/1";   // the person-like hand on b0: its line has team totals, not per skater
  const shots = matches.reduce((x, j) => x + (pt ? (ti === 0 ? j.shots + j.shots_mates : j.shots_opp) : j.shots.slice(ti * 5, ti * 5 + 5).reduce((a, b) => a + b, 0)), 0);
  const touchesJ = pt ? NaN : matches.reduce((x, j) => x + j.touches.slice(ti * 5, ti * 5 + 5).reduce((a, b) => a + b, 0), 0);
  const goals = matches.reduce((x, j) => x + j.goals[ti], 0);
  out.agg[`carrier_${w}`] = { pressed_by: o, reach_2_3m: rc(0), reach_3m: rc(1), opp_within_5m: r2(g(`near0_${w}`) / g(`f_carry_${w}`)), opp_within_10m: r2(g(`near1_${w}`) / g(`f_carry_${w}`)) };
  out.agg[`${o}_pressing`] = { forecheckers_mean: r2(g(`fc_n_${o}`) / g(`fc_f_${o}`)), forecheck_2plus_share: r2(g(`fc_2_${o}`) / g(`fc_f_${o}`)) };
  out.play[w] = { shots_pm: r2(shots / min), goals_pm: r2(goals / min), touches_pm_game: r2(touchesJ / min), takes_inferred_pm: r2(g(`takes_${w}`) / min),
    chain_touches_mean: r2((A[`chain_${w}`] ?? []).reduce((a, b) => a + b, 0) / Math.max((A[`chain_${w}`] ?? []).length, 1)), possession_share: r2(g(`f_poss_${w}`) / live),
    spread_m: r2(g(`spread_${w}`) / live), chasers_mean: r2(g(`chase_${w}`) / live), chase2_share: r2(g(`chase2_${w}`) / live), mate_dist_to_carrier_m: r2(g(`mate_dist_${w}`) / g(`mate_n_${w}`)),
    net_front_share: r2(g(`netfront_${w}`) / g(`f_poss_${w}`)), slot_covered_share: r2(g(`slotcover_${w}`) / g(`f_poss_${o}`)), idle_2s_pm: r2(g(`idle_${w}`) / min) };
}
if (matches[0]?.tool === "thirdjam.playtest/1") { const S = (k) => matches.reduce((x, j) => x + (j[k] ?? 0), 0); const H = matches.reduce((x, j) => [0, 1, 2].map((i) => x[i] + j.hold_frames[i]), [0, 0, 0]); const hs = H[0] + H[1] + H[2];
  out.human = { touches_pm: r2(S("touches") / min), fed_pm: r2(S("passes_received") / min), mates_shots_pm: r2(S("shots_mates") / min), opp_shots_pm: r2(S("shots_opp") / min), bot_hits_on_him_pm: r2(S("bot_hits_on_human") / min),
    bot_check_presses_pm_all: r2(S("bot_check_presses") / min), bot_checks_landed_pm_all: r2(S("bot_checks_landed") / min), bot_cross_landed_pm_all: r2(S("bot_cross_landed") / min), knockdowns_all_pm: r2(S("knockdowns_all") / min),
    first_touch_s_med: r2(med(matches.map((j) => j.first_touch).filter((x) => x >= 0)) / 60), first_goal_against_s_med: r2(med(matches.map((j) => j.first_goal_against).filter((x) => x >= 0)) / 60), hold_mate_opp_none: [r2(H[0] / hs), r2(H[1] / hs), r2(H[2] / hs)], his_shots_pm: r2(S("shots") / min), his_passes_pm: r2(S("passes") / min) }; }
out.play.loose_share = r2(g("f_loose") / live); out.play.scrum4_share = r2(g("scrum4") / live);
out.play.thirds = { blue_def: r2(g("f_third_blue_def") / live), neutral: r2(g("f_third_neutral") / live), blue_off: r2(g("f_third_blue_off") / live) };
console.log(JSON.stringify(out));
