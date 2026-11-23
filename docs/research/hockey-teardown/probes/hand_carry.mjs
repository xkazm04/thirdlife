#!/usr/bin/env node
// H1 hand: carries and pick-ups of the human in played matches, the same rules for both games.
//   node hand_carry.mjs ours <dir of match_s*.csv>          (hand_match.gd: our ladder hand, TLHand)
//   node hand_carry.mjs tj <JamTournament -trace=1 log>     (thirdjam's playtester as the human, index 0)
// A carry ends: by a stick release (the puck leaves faster than him by 6 m/s or more: pass or shot), taken (the next holder
// within 20 frames is an opponent and nothing launched the puck), loose (nobody has it for 20 frames, nothing launched it),
// back to him (he holds it again within 20 frames, nobody else did: a blip off the blade), or a stoppage (play stopped). Pick-up: a loose puck whose centre comes within `ring` m of his centre; success = his within
// 15 frames; binned by the puck's speed relative to him. Positions in TJ's trace are rounded to 0.1 m: speeds there are
// read over 5 frames.
import fs from 'node:fs'; import path from 'node:path';
const [game, src] = process.argv.slice(2);

function loadOurs(dir) {
  const ms = [];
  for (const f of fs.readdirSync(dir).filter((f) => /^match_s\d+\.csv$/.test(f))) {
    const [h, ...l] = fs.readFileSync(path.join(dir, f), 'utf8').trim().split('\n'); const k = h.split(',');
    ms.push(l.map((r) => { const v = r.split(','); const o = {}; k.forEach((c, i) => (o[c] = v[i])); return {
      live: o.live === '1', x: +o.x, z: +o.z, px: +o.px, pz: +o.pz, pv: Math.hypot(+o.pvx, +o.pvz), pvx: +o.pvx, pvz: +o.pvz,
      holder: o.holder === 'b0' ? 'me' : o.holder === '' ? '' : o.holder.startsWith('b') ? 'mate' : 'opp', kind: o.rel_kind, relf: +o.rel_f, f: +o.f, down: o.down }; }));
  }
  return { ms, ring: 1.45, goal: 26 };
}
function loadTj(file) {
  const ms = []; let cur = null, last = 1e9;
  const re = /TRACE f=(\d+)( frozen)? stall=\d puck\((-?[\d.]+),(-?[\d.]+) v([\d.]+)\) 0H\((-?[\d.]+),(-?[\d.]+)\)>(-?\d+)\[[^\]]*\](.*) since=\S+ ht=\S+ car=(-?\d+) lt=(-?\d+) fo=(\d)/;
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const m = re.exec(line); if (!m) continue; const f = +m[1];
    if (f < last) { cur = []; ms.push(cur); } last = f;
    const teams = [...m[9].matchAll(/ (\d)[A-Z]\(/g)].map((t) => +t[1]); const car = +m[10];
    cur.push({ f, live: !m[2] && m[12] === '0', x: +m[6], z: +m[7], px: +m[3], pz: +m[4], pv: +m[5],
      holder: car < 0 ? '' : car === 0 ? 'me' : teams[car - 1] === 0 ? 'mate' : 'opp' });
  }
  for (const c of ms) for (let i = 0; i < c.length; i++) { const j = Math.max(0, i - 5); const n = i - j || 1;   // the puck's velocity from its positions
    c[i].pvx = (c[i].px - c[j].px) * 60 / n; c[i].pvz = (c[i].pz - c[j].pz) * 60 / n; }
  return { ms, ring: 1.1, goal: 41 };
}

const L = game === 'tj' ? loadTj(src) : loadOurs(src); const ms = L.ms, ring = process.argv[4] ? +process.argv[4] : L.ring;   // optional 3rd argument: a common disc (m)
const causes = { stick: 0, pass_to_mate: 0, back_to_him: 0, taken: 0, loose: 0, stoppage: 0 }, kinds = {}; let carryF = 0, liveF = 0, carries = 0;
const lens = []; const pick = {}; const R = (v) => (v < 4 ? '0-4' : v < 8 ? '4-8' : v < 12 ? '8-12' : v < 16 ? '12-16' : v < 20 ? '16-20' : '20+');
for (const c of ms) {
  const vme = (i) => { const j = Math.max(0, i - 5); const n = i - j || 1; return [(c[i].x - c[j].x) * 60 / n, (c[i].z - c[j].z) * 60 / n]; };
  let start = -1, lastPick = -99;
  for (let i = 1; i < c.length; i++) {
    const r = c[i], p = c[i - 1];
    if (r.live) liveF++;
    if (r.holder === 'me' && r.live) carryF++;
    if (r.holder === 'me' && p.holder !== 'me') start = i;
    if (p.holder === 'me' && r.holder !== 'me' && start >= 0) {
      carries++; lens.push((i - start) / 60); start = -1;
      if (!r.live || c.slice(i, i + 3).some((q) => !q.live)) { causes.stoppage++; continue; }
      const v = vme(i - 1), sp = Math.hypot(v[0], v[1]);
      const k = Math.min(i + 3, c.length - 1), jump = Math.max(...c.slice(i, k + 1).map((q) => Math.hypot(q.pvx, q.pvz))) - sp;
      let next = ''; for (let j = i; j < Math.min(i + 20, c.length); j++) if (c[j].holder) { next = c[j].holder; break; }
      if (r.kind !== undefined) kinds[r.kind || '?'] = (kinds[r.kind || '?'] || 0) + 1;
      if (next === 'me') causes.back_to_him++;
      else if (jump >= 6) { causes.stick++; if (next === 'mate') causes.pass_to_mate++; }
      else if (next === 'opp' || next === 'mate') causes.taken += next === 'opp' ? 1 : 0, causes.loose += next === 'mate' ? 1 : 0;
      else causes.loose++;
    }
    // pick-up chances: a loose puck enters his ring (once per 30 frames)
    if (r.live && r.holder !== 'me' && (p.holder === '' || r.holder === '') && i - lastPick > 30) {
      const d = Math.hypot(r.px - r.x, r.pz - r.z), dp = Math.hypot(p.px - p.x, p.pz - p.z);
      if (d <= ring && dp > ring && r.holder === '') {
        lastPick = i; const v = vme(i), rel = Math.hypot(r.pvx - v[0], r.pvz - v[1]);
        let got = -1, other = ''; for (let j = i; j < Math.min(i + 15, c.length); j++) { if (c[j].holder === 'me') { got = j - i; break; } if (c[j].holder && !other) other = c[j].holder; }
        const b = (pick[R(rel)] ??= { n: 0, mine: 0, other: 0, frames: [] }); b.n++; if (got >= 0) { b.mine++; b.frames.push(got); } else if (other) b.other++;
      }
    }
  }
}
const merged = [];   // carries with the blips (back to him inside 20 frames, nobody else) folded in
for (const c of ms) { let st = -1, gap = 0; for (let i = 0; i < c.length; i++) { const h = c[i].holder;
  if (h === 'me') { if (st < 0) st = i; gap = 0; } else if (st >= 0) { if (h === '' && gap < 20) gap++; else { merged.push((i - gap - st) / 60); st = -1; gap = 0; } } } }
const perMin = (n) => +(n / (carryF / 3600)).toFixed(2), med = (a) => { const s = [...a].sort((x, y) => x - y); return s.length ? +s[Math.floor(s.length / 2)].toFixed(2) : null; };
const out = { game, matches: ms.length, live_min: +(liveF / 3600).toFixed(1), carry_min: +(carryF / 3600).toFixed(2), carry_share: +(carryF / liveF).toFixed(3), carries,
  carry_median_s: med(lens), merged_carries: merged.length, merged_median_s: med(merged), merged_p90_s: +[...merged].sort((a, b) => a - b)[Math.floor(merged.length * 0.9)].toFixed(2), carry_p90_s: +[...lens].sort((a, b) => a - b)[Math.floor(lens.length * 0.9)].toFixed(2),
  ends_per_carry_min: Object.fromEntries(Object.entries(causes).map(([k, n]) => [k, perMin(n)])), ends_n: causes, our_release_kinds: Object.keys(kinds).length ? kinds : undefined,
  pickup_ring_m: ring, pickup: Object.fromEntries(['0-4', '4-8', '8-12', '12-16', '16-20', '20+'].filter((k) => pick[k]).map((k) => [k, { n: pick[k].n, his: +(pick[k].mine / pick[k].n).toFixed(2), other_took: pick[k].other, frames_med: med(pick[k].frames) }])) };
console.log(JSON.stringify(out));
