// The perf scenarios. Each is a fixed, scripted run with a fixed seed; `run(ctx)` returns the metrics it measures (a metric a
// scenario does not measure is left out) or throws with the reason. The parsers are pure and tested on captured output.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const r3 = (v) => Math.round(Number(v) * 1000) / 1000;

/** The JSON objects among the lines of an output (the shell tools print tl.world/1 and tl.view/1 lines among text). */
export function jsonLines(text) {
  const out = [];
  for (const l of String(text).split(/\r?\n/)) {
    const t = l.trim();
    if (t.startsWith("{") && t.endsWith("}")) { try { out.push(JSON.parse(t)); } catch { /* not ours */ } }
  }
  return out;
}

/** tl.world/1 "world" line -> simulation metrics (a world tick = every pack's tick plus the physics step). */
export function fromWorldLine(w) {
  const m = {};
  if (w.iter_ms_p50 !== undefined) m.sim_tick_ms_p50 = r3(w.iter_ms_p50);
  if (w.iter_ms_p99 !== undefined) m.sim_tick_ms_p99 = r3(w.iter_ms_p99);
  if (w.iter_ms_max !== undefined) m.worst_tick_ms = r3(w.iter_ms_max);
  if (w.load_ms !== undefined) m.load_ms = Number(w.load_ms);
  return m;
}

/** The lines of one world run (headless `world` mode) -> metrics. */
export function parseWorld(text) {
  const lines = jsonLines(text);
  const w = lines.find((l) => l.kind === "world");
  if (!w) throw new Error("no tl.world/1 world line in the output");
  if ((w.errors ?? []).length || Number(w.script_errors) || Number(w.engine_errors)) throw new Error(`the world ran with errors: ${JSON.stringify(w.errors ?? []).slice(0, 200)} script ${w.script_errors} engine ${w.engine_errors}`);
  const m = fromWorldLine(w);
  const awake = lines.filter((l) => l.kind === "pack").map((l) => l.awake_bodies_at_end).filter((v) => v !== undefined);
  if (awake.length) m.bodies_awake = awake.reduce((a, b) => a + b, 0);
  return m;
}

/** The lines of a windowed tour (world.sh tour with TL_JSON=1) -> metrics. */
export function parseTour(text) {
  const lines = jsonLines(text);
  const w = lines.find((l) => l.kind === "world");
  const t = lines.find((l) => l.kind === "tour");
  if (!w) throw new Error("no world line in the tour output");
  if (!t) throw new Error("the window did not report the end of the tour");
  const m = fromWorldLine(w);
  if (t.frame_ms_p50_all !== undefined) m.frame_ms_p50 = r3(t.frame_ms_p50_all);
  if (t.render_gpu_ms_p50 !== undefined) m.gpu_ms = r3(t.render_gpu_ms_p50);
  if (t.render_cpu_ms_p50 !== undefined) m.render_cpu_ms = r3(t.render_cpu_ms_p50);
  // the frame tail is not in the tour line yet (docs/PATCHES-P1.md, patch 1): when it is, it is taken from there
  if (t.frame_ms_p99_all !== undefined) m.frame_ms_p99 = r3(t.frame_ms_p99_all);
  if (t.frame_ms_max_all !== undefined) m.worst_frame_ms = r3(t.frame_ms_max_all);
  // P5: how a world arrives. Milliseconds from the moment the world starts to build (the engine's own start is before
  // it) to the end of the first drawn frame, and from the start of the world until the sixth pack was attached (the
  // build queue's own clock; absent when nothing is queued).
  if (t.world_to_first_frame_ms !== undefined && Number(t.first_frame_ms) >= 0) m.first_frame_ms = Number(t.world_to_first_frame_ms);
  if (w.load?.six_built_ms !== undefined) m.six_built_ms = r3(w.load.six_built_ms);
  const pics = lines.filter((l) => l.kind === "picture");
  if (pics.length) {
    m.draw_calls = Math.max(...pics.map((p) => Number(p.draw_calls)));
    m.primitives = Math.max(...pics.map((p) => Number(p.primitives)));
  }
  return m;
}

/** `k.sh stats` -> {draw_calls, primitives}. The line is {"layout":..,"triangles":..,"draw_calls":..}-like; unknown keys are tolerated. */
export function parseStats(text) {
  const l = jsonLines(text).find((x) => x.draw_calls !== undefined || x.triangles !== undefined || x.primitives !== undefined || x.primitives_in_frame !== undefined);
  if (!l) throw new Error("no stats line in the output");
  const m = {};
  if (l.draw_calls !== undefined) m.draw_calls = Number(l.draw_calls);
  const prim = l.primitives_in_frame ?? l.primitives ?? l.triangles;
  if (prim !== undefined) m.primitives = Number(prim);
  for (const [k, to] of [["gpu_ms", "gpu_ms"], ["render_gpu_ms", "gpu_ms"], ["render_cpu_ms", "render_cpu_ms"], ["frame_ms_p50", "frame_ms_p50"], ["frame_ms_p99", "frame_ms_p99"]]) if (l[k] !== undefined) m[to] = r3(l[k]);
  return m;
}

function worldSh(ctx, args, { timeout = 600000, env = {} } = {}) {
  const r = ctx.bash(path.join(ctx.ENGINE, "tools", "world.sh"), args, { cwd: ctx.REPO, timeout, env: { TL_JSON: "1", ...env } });
  return r;
}

/** P12. One windowed measurement at a time on this machine: several windows on one spot of the screen throttle each
 * other to about 270 ms a frame (P5's verification). The lock is a directory in the system's temporary folder; a lock
 * older than `staleMs` is taken over (its holder died). The window goes to TL_PERF_WINDOW_POS when it is set. */
export function withWindowLock(fn, { dir = path.join(os.tmpdir(), "tl_window.lock"), waitMs = 900000, staleMs = 900000 } = {}) {
  const t0 = Date.now();
  for (;;) {
    try { fs.mkdirSync(dir); break; } catch (e) {
      if (e?.code !== "EEXIST") throw e;
      let age = 0;
      try { age = Date.now() - fs.statSync(dir).mtimeMs; } catch { continue; }
      if (age > staleMs) { try { fs.rmdirSync(dir); } catch { /* another waiter took it over */ } continue; }
      if (Date.now() - t0 > waitMs) throw new Error(`another windowed measurement held ${dir} for ${Math.round(waitMs / 1000)} s`);
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 2000);
    }
  }
  try { return fn(); } finally { try { fs.rmdirSync(dir); } catch { /* already gone */ } }
}

function windowEnv(env) {
  return process.env.TL_PERF_WINDOW_POS ? { TL_WINDOW_POS: process.env.TL_PERF_WINDOW_POS, ...env } : env;
}

/** Best (lowest) of the metric values over repeated runs: a busy moment only ever adds time. Counts are equal across runs. */
export function bestOf(runs) {
  const out = {};
  for (const m of runs) for (const [k, v] of Object.entries(m)) {
    if (k === "bodies_awake") out[k] = v;
    else if (out[k] === undefined || v < out[k]) out[k] = v;
  }
  return out;
}

export const SCENARIOS = {
  tour6: {
    describe: "the world tour (engine/tools/world.sh tour tour): six packs, the landscape, a visitor, in a 1920x1080 window",
    windowed: true,
    run(ctx) {
      const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tl_perf_tour_"));
      try {
        const r = withWindowLock(() => worldSh(ctx, ["tour", "tour", `--out-dir=${dir}`, "--pictures-only"], { env: windowEnv({ TL_VIEW_TIMEOUT: "420" }) }));
        return parseTour(r.stdout);
      } finally { fs.rmSync(dir, { recursive: true, force: true }); }
    },
  },
  walk30: {
    describe: "a visitor runs through a village of 30 games that are built as he approaches (world.sh tour walk30), 1920x1080 window",
    windowed: true,
    run(ctx) {
      const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tl_perf_walk30_"));
      try {
        const r = withWindowLock(() => worldSh(ctx, ["tour", "walk30", `--out-dir=${dir}`, "--pictures-only"], { env: windowEnv({ TL_VIEW_TIMEOUT: "540" }) }));
        return parseTour(r.stdout);
      } finally { fs.rmSync(dir, { recursive: true, force: true }); }
    },
  },
  mix30: {
    describe: "one stage game, four sideline games, the rest far (walks/bench_mix_30.json), headless",
    windowed: false,
    run(ctx) { return parseWorld(worldSh(ctx, ["walk", "bench_mix_30.json"]).stdout); },
  },
  pile600: {
    describe: "one pack with 600 awake bodies (world.sh run --packs=w_pile --seeds=600 --frames=400), headless",
    windowed: false,
    run(ctx) { return parseWorld(worldSh(ctx, ["run", "--packs=w_pile", "--seeds=600", "--frames=400", "--state=1"]).stdout); },
  },
  hero1440: {
    describe: "the kit lab's hero view at 2560x1440 (engine/tools/k.sh stats main hero): draw calls and primitives",
    windowed: true,
    run(ctx) {
      const r = ctx.bash(path.join(ctx.ENGINE, "tools", "k.sh"), ["stats", "main", "hero"], { cwd: ctx.REPO, timeout: 300000, env: { TMO: "240" } });
      return parseStats(r.stdout);
    },
  },
  load6: {
    describe: "time to load six packs and the landscape (a short windowed tour: load_ms of the world, landscape build time)",
    windowed: true,
    run(ctx) {
      const dir = fs.mkdtempSync(path.join(os.tmpdir(), "tl_perf_load_"));
      try {
        const r = withWindowLock(() => worldSh(ctx, ["tour", "tour", `--out-dir=${dir}`, "--pictures-only", "--ticks=40"], { env: windowEnv({ TL_VIEW_TIMEOUT: "300" }) }));
        const lines = jsonLines(r.stdout);
        const w = lines.find((l) => l.kind === "world"), t = lines.find((l) => l.kind === "tour");
        if (!w) throw new Error("no world line in the output");
        const m = { load_ms: Number(w.load_ms) };
        if (t?.landscape?.build_ms !== undefined) m.load_ms += Number(t.landscape.build_ms);
        return m;
      } finally { fs.rmSync(dir, { recursive: true, force: true }); }
    },
  },
};
