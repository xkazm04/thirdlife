// Sequential Codex image_gen runner for the GTAI image brainstorm rounds.
// usage: node gen.mjs <roundDir>   (reads <roundDir>/jobs.json, writes <roundDir>/out/<name>.png, gen.log)
// jobs.json: { style, jobs: [{ name, track, refs: [file in refs/], prompt }] }; skips jobs whose out png exists.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const round = path.resolve(process.argv[2]);
const cfg = JSON.parse(fs.readFileSync(path.join(round, 'jobs.json'), 'utf8'));
const outDir = path.join(round, 'out');
fs.mkdirSync(outDir, { recursive: true });
const log = (m) => { const l = `[${new Date().toISOString()}] ${m}`; console.log(l); fs.appendFileSync(path.join(round, 'gen.log'), l + '\n'); };
const only = process.argv[3] ? new Set(process.argv[3].split(',')) : null;


const LOCK = process.env.IMAGE_LOCK || '';
async function takeLock() {
  if (!LOCK) return;
  for (;;) {
    try { fs.writeFileSync(LOCK, 'look-table', { flag: 'wx' }); return; } catch (e) {
      if (e.code !== 'EEXIST') throw e;
      try { if (Date.now() - fs.statSync(LOCK).mtimeMs > 20 * 60_000) { fs.unlinkSync(LOCK); continue; } } catch {}
      await new Promise((r) => setTimeout(r, 30_000));
    }
  }
}
const dropLock = () => { if (LOCK) try { fs.unlinkSync(LOCK); } catch {} };

let fails = 0;
for (const job of cfg.jobs) {
  if (only && !only.has(job.name)) continue;
  const target = path.join(outDir, `${job.name}.png`);
  if (fs.existsSync(target)) { log(`${job.name}: exists, skip`); continue; }
  const dir = path.join(round, 'jobs', job.name);
  fs.mkdirSync(path.join(dir, 'out'), { recursive: true });
  const refArgs = [];
  (job.refs || []).forEach((r, i) => { const dst = path.join(dir, `ref${i + 1}${path.extname(r)}`); fs.copyFileSync(path.join(round, 'refs', r), dst); refArgs.push('-i', dst); });
  const prompt = `Use the built-in image_gen tool (imagegen skill) to generate exactly ONE image, landscape. ${job.prompt}\n\n${cfg.style}\n\nThen copy the generated file to ./out/${job.name}.png and print the original path. Do not generate more than one image.`;
  await takeLock();
  const t0 = Date.now();
  log(`${job.name}: start (${job.track})`);
  const r = spawnSync(process.execPath, ['C:/nvm4w/nodejs/node_modules/@openai/codex/bin/codex.js', 'exec', '--skip-git-repo-check', '-s', 'workspace-write', '-o', 'last_message.txt', '-C', dir, ...refArgs, '--', prompt], { cwd: dir, encoding: 'utf8', timeout: 15 * 60_000, maxBuffer: 64 * 1024 * 1024 });
  dropLock();
  fs.writeFileSync(path.join(dir, 'codex.log'), `${r.stdout || ''}\n--- stderr ---\n${r.stderr || ''}`);
  const produced = path.join(dir, 'out', `${job.name}.png`);
  if (fs.existsSync(produced)) { fs.copyFileSync(produced, target); log(`${job.name}: ok ${Math.round((Date.now() - t0) / 1000)}s`); fails = 0; continue; }
  const tail = `${r.stderr || ''}${r.stdout || ''}`.slice(-600).replace(/\s+/g, ' ');
  log(`${job.name}: FAILED exit ${r.status} ${Math.round((Date.now() - t0) / 1000)}s :: ${tail}`);
  if (/usage limit|rate limit|quota|429|limit reached/i.test(tail)) { log('LIMIT: stopping the round'); process.exit(3); }
  if (++fails >= 3) { log('3 failures in a row: stopping'); process.exit(4); }
}
log('round done');
