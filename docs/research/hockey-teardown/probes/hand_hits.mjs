#!/usr/bin/env node
// H1 hand, round 2: the frame timeline of each hit scene of hand_step.gd (scenes_hit.json; ours only: thirdjam's timelines are
// its own automation lines, read in BEHAVIOUR-HAND.md section 2).   node hand_hits.mjs <dir of CSVs>  -> one JSON line a scene
// Frames are counted from the press: the key's frame is 1 (the tap at age 0 acts in that frame's pack step; a drill script's
// press acts in the drill's first frame, one frame before age 0).
import fs from 'node:fs'; import path from 'node:path';
const dir = process.argv[2];
const read = (f) => { const [h, ...l] = fs.readFileSync(path.join(dir, f), 'utf8').trim().split('\n'); const k = h.split(',');
  return l.map((r) => { const v = r.split(','); const o = {}; k.forEach((c, i) => (o[c] = /^(holder|b0st|r0st|hit_class|hit_kind)$/.test(c) ? v[i] : +v[i])); return o; }); };
const first = (rows, f, from = 0) => { for (let i = from; i < rows.length; i++) if (f(rows[i], i)) return i; return -1; };
const runs = (rows, f, from) => { let n = 0; for (let i = from; i < rows.length; i++) if (f(rows[i])) n++; return n; };
for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.csv')).sort()) {
  const r = read(f), name = f.replace('.csv', ''), victimB0 = name.startsWith('victim');
  const f0 = r[0].f - (victimB0 ? 1 : 0);                  // the press's pack frame
  const o = { scene: name };
  const hi = first(r, (x) => x.hit_f >= f0 - 1);
  if (name.startsWith('poke')) {
    const press = r[30].f, took = first(r, (x) => x.holder !== "r0", 30);
    o.dist_at_press = +Math.hypot(r[30].px - r[30].x, r[30].pz - r[30].z).toFixed(2);
    o.took = took >= 0 && r[took].holder !== 'r0'; o.frames_to_take = took >= 0 ? r[took].f - press : null; o.after = took >= 0 ? r[took].holder || 'loose' : 'r0';
    o.poke_ready_again = first(r, (x, i) => i > 31 && x.poke_ready === 1 && r[i - 1].poke_ready === 0) >= 0 ? r[first(r, (x, i) => i > 31 && x.poke_ready === 1 && r[i - 1].poke_ready === 0)].f - press : null;
    console.log(JSON.stringify(o)); continue;
  }
  o.windup_frames = runs(r, (x) => x.windup === 1, 0); o.swing_frames = runs(r, (x) => x.swing === 1, 0);
  o.check_ready_again = (() => { const i = first(r, (x, j) => j > 1 && x.check_ready === 1 && r[j - 1].check_ready === 0); return i >= 0 ? r[i].f - f0 : null; })();
  o.stop_frames = runs(r, (x) => x.stop_left > 0, 0);
  if (hi < 0) { o.hit = 'none'; console.log(JSON.stringify(o)); continue; }
  const h = r[hi]; o.hit = h.hit_class; o.kind = h.hit_kind; o.ratio = h.hit_ratio; o.closing = h.hit_closing; o.contact_frame = h.hit_f - f0 + 1;
  const vic = victimB0 ? 'b0st' : 'r0st', att = victimB0 ? 'r0st' : 'b0st';
  const dn = r.filter((x, i) => i >= hi && x[vic].startsWith('d')).length, st = r.filter((x, i) => i >= hi && x[vic] === 's').length;
  o.victim_down_frames = dn; o.victim_stumble_frames = st;
  const free = first(r, (x) => x[vic] === '' && x.stop_left === 0, hi + 1);
  o.victim_free_frame = free >= 0 ? r[free].f - f0 : null;
  o.attacker_stumble_frames = r.filter((x, i) => i >= hi && x[att] === 's').length;
  const sp = (x) => (victimB0 ? x.rspeed : x.speed), vs = (x) => (victimB0 ? x.speed : x.rspeed);
  o.attacker_v_before = +sp(r[Math.max(0, hi - 2)]).toFixed(2); o.attacker_v_after = +sp(r[Math.min(hi + 6, r.length - 1)]).toFixed(2);
  o.victim_v_after = +vs(r[Math.min(hi + 6, r.length - 1)]).toFixed(2);
  if (victimB0) {   // his hand back: two frames in a row in which his speed toward -z grows (he holds the up key from age 8)
    const back = first(r, (x, i) => i > hi + 1 && i > 9 && r[i].vz < r[i - 1].vz - 0.05 && r[i - 1].vz < r[i - 2].vz - 0.05, hi + 2);
    o.hand_back_frame = back >= 0 ? r[back - 1].f - f0 : null;
  }
  o.puck_after = h.holder === undefined ? '' : (r[Math.min(hi + 10, r.length - 1)].holder || 'loose');
  console.log(JSON.stringify(o));
}
