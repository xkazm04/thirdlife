#!/usr/bin/env node
// K3 shell: our camera (the pack's port, per frame from bot_gym_hand's trace) against thirdjam's own camera code (the oracle)
// fed the same skater path. Usage: node compare_trace.mjs <bot report.json> <camera_oracle.exe> [--csv out.csv]
// Prints the first frame and size of any difference over 1 cm (position, height) or 0.1 degree (pitch, yaw), and the maxima.
import fs from 'node:fs'; import { execFileSync } from 'node:child_process';
const [rep, exe] = process.argv.slice(2);
const d = JSON.parse(fs.readFileSync(rep, 'utf8'));
const tr = d.bot.result.metrics.raw.trace;   // [frame, x, y, yaw, cam_x, cam_y, cam_h, cam_pitch, cam_yaw]
const out = execFileSync(exe, { input: tr.map((r) => `${r[0]} ${r[1]} ${r[2]} ${r[3]}`).join('\n') + '\n', maxBuffer: 1 << 26 }).toString();
const tj = out.trim().split('\n').map((l) => l.split(' ').map(Number));
const wrap = (a) => { while (a > 180) a -= 360; while (a < -180) a += 360; return a; };
const max = { pos: 0, h: 0, pitch: 0, yaw: 0 }, at = { pos: -1, h: -1, pitch: -1, yaw: -1 }; let first = null; const rows = ['frame,ours_x,ours_y,ours_h,ours_pitch,ours_yaw,tj_x,tj_y,tj_h,tj_pitch,tj_yaw'];
for (let i = 0; i < tr.length; i++) {
  const o = tr[i], t = tj[i];
  const e = { pos: Math.hypot(o[4] - t[1], o[5] - t[2]), h: Math.abs(o[6] - t[3]), pitch: Math.abs(o[7] - t[4]), yaw: Math.abs(wrap(o[8] - t[5])) };
  for (const k in e) if (e[k] > max[k]) { max[k] = e[k]; at[k] = o[0]; }
  if (!first && (e.pos > 0.01 || e.h > 0.01 || e.pitch > 0.1 || e.yaw > 0.1)) first = { frame: o[0], ...e, ours: o.slice(4), thirdjam: t.slice(1) };
  rows.push([o[0], ...o.slice(4), ...t.slice(1)].join(','));
}
const k = process.argv.indexOf('--csv'); if (k > 0) fs.writeFileSync(process.argv[k + 1], rows.join('\n') + '\n');
const ok = !first && tr.length === tj.length && tr.length > 0;
console.log(`${ok ? 'PASS' : 'FAIL'} camera vs thirdjam's StepThirdPerson: ${tr.length} frames; max |pos| ${(max.pos * 100).toFixed(4)} cm (frame ${at.pos}), |h| ${(max.h * 100).toFixed(4)} cm (frame ${at.h}), |pitch| ${max.pitch.toFixed(5)} deg (frame ${at.pitch}), |yaw| ${max.yaw.toFixed(5)} deg (frame ${at.yaw})`);
if (first) console.log('first difference over 1 cm / 0.1 deg:', JSON.stringify(first));
console.log(JSON.stringify({ schema: 'k3.camera_compare/1', ok, frames: tr.length, max, at, first }));
process.exit(ok ? 0 : 1);
