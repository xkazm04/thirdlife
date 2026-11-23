// H1 build round: thirdjam's carry "blips" (car=0 -> not 0 -> 0 inside 20 frames) read again: where the puck was. node hand_blip.mjs (reads .tl/h1/tour/pro_regular30.log)
import fs from 'node:fs';
const re = /TRACE f=(\d+)( frozen)? stall=\d puck\((-?[\d.]+),(-?[\d.]+) v([\d.]+)\) (.*) since=\S+ ht=\S+ car=(-?\d+) lt=(-?\d+) fo=(\d)/;
const ms = []; let cur = null, last = 1e9;
for (const line of fs.readFileSync(process.argv[2] ?? 'tour/pro_regular30.log', 'utf8').split('\n')) {
  const m = re.exec(line); if (!m) continue; const f = +m[1]; if (f < last) { cur = []; ms.push(cur); } last = f;
  const sk = [...(' ' + m[6]).matchAll(/ (\d)([A-Z])\((-?[\d.]+),(-?[\d.]+)\)>(-?\d+)\[(-?[\d.]+),(-?[\d.]+)( SHOOT)?\]/g)].map((t) => ({ team: +t[1], x: +t[3], y: +t[4], yaw: +t[5], mx: +t[6], my: +t[7] }));
  cur.push({ f, px: +m[3], py: +m[4], pv: +m[5], sk, car: +m[7], fo: m[9] === '1', frozen: !!m[2] });
}
const stats = { blip: [], keep: [] };
for (const c of ms) for (let i = 6; i < c.length - 21; i++) {
  if (c[i - 1].car !== 0 || c[i].car === 0 || c[i].frozen || c[i].fo) continue;
  let back = -1; for (let j = i; j < i + 20; j++) { if (c[j].car === 0) { back = j; break; } if (c[j].car > 0) break; }
  const h = c[i - 1].sk[0], h5 = c[i - 6].sk[0];
  const v = Math.hypot(h.x - c[i - 2].sk[0].x, h.y - c[i - 2].sk[0].y) * 60, v5 = Math.hypot(h5.x - c[i - 7]?.sk[0].x, h5.y - c[i - 7]?.sk[0].y) * 60;
  const dyaw = Math.abs(((h.yaw - h5.yaw + 540) % 360) - 180);
  const opp = Math.min(...c[i].sk.slice(1).filter((s) => s.team !== 0).map((s) => Math.hypot(s.x - h.x, s.y - h.y)));
  const pd = Math.hypot(c[i].px - c[i].sk[0].x, c[i].py - c[i].sk[0].y);
  const rec = { v: +v.toFixed(1), dv: +(v - v5).toFixed(1), dyaw, opp: +opp.toFixed(1), pd: +pd.toFixed(2), pv: c[i].pv, gap: back - i };
  if (back > 0) stats.blip.push(rec);
}
const b = stats.blip; const q = (a, p) => { const s = [...a].sort((x, y) => x - y); return s[Math.floor(s.length * p)]; };
console.log('blips', b.length);
for (const k of ['v', 'dv', 'dyaw', 'opp', 'pd', 'pv', 'gap']) console.log(k, 'p10', q(b.map((r) => r[k]), 0.1), 'p50', q(b.map((r) => r[k]), 0.5), 'p90', q(b.map((r) => r[k]), 0.9));
console.log('opp within 3 m', b.filter((r) => r.opp < 3).length, 'yaw change >30 in 5f', b.filter((r) => r.dyaw > 30).length, 'puck speed - body speed > 4', b.filter((r) => r.pv - r.v > 4).length);
