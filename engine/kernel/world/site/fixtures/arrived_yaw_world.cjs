// Exercise the normal world, world-file and replay entry points with real promoted jobs.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {spawnSync} = require("node:child_process");
const [proof, engine, dir, godot] = process.argv.slice(2);
const fixtures = engine + "/kernel/world/site/fixtures";
const read = path => JSON.parse(fs.readFileSync(path, "utf8"));
const write = (path, value) => fs.writeFileSync(path, JSON.stringify(value));
const packName = "example.bounce@0.1.0";

function world(args, ticks) {
  const result = spawnSync(godot, ["--headless", "--fixed-fps", "60", "--path", engine,
    "res://kernel/host/host.tscn", "--", "world", ...args],
    {encoding: "utf8", env: {...process.env, TL_CACHE_DIR: dir + "/cache"}, windowsHide: true});
  if (result.error) throw result.error;
  const output = result.stdout + "\n" + result.stderr;
  assert.equal(result.status, 0, output.slice(-2500));
  assert.doesNotMatch(output, /^(?:SCRIPT ERROR|ERROR):/m);
  const end = output.match(/^\[tl\] world done: packs=(\d+) ticks=(\d+)\r?$/m);
  assert.ok(end, "world did not reach its end marker");
  if (ticks !== undefined) assert.equal(Number(end[2]), ticks);
  return output.split(/\r?\n/);
}

function makeJob(name, at, yaw, fromDraft = false, promoteTwice = false) {
  const job = dir + "/" + name;
  fs.cpSync(fixtures + "/arrive", job, {recursive: true});
  const path = job + "/job.jsonl";
  const rows = fs.readFileSync(path, "utf8").trimEnd().split("\n").map(JSON.parse);
  const created = rows[0];
  created.sentence += " " + name;
  if (yaw !== undefined) {
    const lot = {at, radius: 30, yaw_deg: yaw};
    if (fromDraft) {
      fs.mkdirSync(dir + "/_editor", {recursive: true});
      write(dir + "/_editor/" + name + ".json", {schema: "tl.editor-draft/1", request: created.sentence, lot});
    } else created.lot = lot;
  }
  if (promoteTwice) {
    const dest = "promoted/example.bounce@0.1.1";
    fs.cpSync(job + "/promoted/" + packName, job + "/" + dest, {recursive: true});
    const manifest = job + "/" + dest + "/pack.json";
    write(manifest, {...read(manifest), version: "0.1.1"});
    rows.push({...rows.find(e => e.type === "promoted"), seq: rows.length + 1, version: "0.1.1", dest});
  }
  fs.writeFileSync(path, rows.map(row => JSON.stringify(row)).join("\n") + "\n");
  return {at, h: 3, radius: 30, job, replay: {ticks_per_event: 2}};
}

function record() {
  const walk = read(fixtures + "/site_arrive.json");
  const centres = [[40, 0], [120, 10], [190, 20], [260, 30]];
  const yaws = [-30, 15, undefined, undefined];
  walk.landscape.lots = [makeJob("job", centres[0], 30, false, true), makeJob("draft", centres[1], -15, true),
    makeJob("legacy", centres[2]), makeJob("zero", centres[3], 0)];
  walk.player = [[0, [40, 0, 0]]];
  walk.ticks = 100;
  walk.events = [{t: 1, e: "enter"}, {t: 50, e: "enter"}];
  write(dir + "/walk.json", walk);
  const lines = world(["--walk=" + dir + "/walk.json", "--log=" + dir + "/log.json", "--save=" + dir + "/world.json"], 100);
  const log = read(dir + "/log.json");
  assert.ok(log.events.some(e => e.e === "refused" && e.ask === "enter" && e.t === 1));
  assert.ok(log.events.some(e => e.e === "tier" && e.plot === "site_0" && e.to === "stage" && e.t === 50));
  assert.ok(log.events.some(e => e.e === "reload" && e.plot === "site_0" && e.t === 42));
  const draftPath = dir + "/_editor/draft.json";
  const draft = read(draftPath);
  draft.lot.yaw_deg = 90;
  write(draftPath, draft);
  const replay = world(["--replay=" + dir + "/log.json", "--log=" + dir + "/again.json"], 100);
  assert.deepEqual(read(dir + "/again.json").walk.plots, log.walk.plots);
  world(["--world=" + dir + "/world.json", "--frames=2", "--save=" + dir + "/loaded.json"]);
  const saved = read(dir + "/world.json").plots, loaded = read(dir + "/loaded.json").plots;
  for (const [i, at] of centres.entries()) {
    const index = walk.plots.length + i, plot = log.walk.plots[index], id = "site_" + i;
    assert.deepEqual([plot.id, plot.site_lot, plot.yaw, plot.origin], [id, i, yaws[i], [at[0], 3, at[1]]]);
    assert.equal(Object.hasOwn(plot, "yaw"), yaws[i] !== undefined);
    for (const file of [saved, loaded]) {
      assert.deepEqual([file[index].id, file[index].yaw, file[index].origin], [id, yaws[i] ?? 0, plot.origin]);
    }
    for (const run of [lines, replay]) {
      assert.ok(run.includes(`[site] lot ${i}: example.bounce 0.1.0 arrives on plot ${id} at world tick 38`));
      const site = JSON.parse(run.find(l => l.startsWith("[site] {")).slice(7)).sites[i];
      assert.deepEqual([site.plot, site.at, site.yaw_deg, site.arrived_at], [id, at, yaws[i] ? -yaws[i] : undefined, i === 0 ? 42 : 38]);
    }
  }
  // A +10 m local X marker at the recorded job heading must land on the editor's +X/+Z side.
  const angle = log.walk.plots[walk.plots.length].yaw * Math.PI / 180;
  assert.ok(Math.abs(10 * Math.cos(angle) - 8.660254) < 1e-6 && Math.abs(-10 * Math.sin(angle) - 5) < 1e-6);
  // A recorded scheduler footprint can differ from the (measured) drawing radius.
  // Run fresh decisions on that reservation to see the size restored by the actual promotion.
  const reserved = log.walk;
  reserved.plots[walk.plots.length].footprint.size_m = [40, 12];
  const outside = [40 + 11 * Math.sin(angle), 0, 11 * Math.cos(angle)];
  reserved.player = [[0, outside], [50, outside], [51, [40, 0, 0]]];
  reserved.events = [{t: 50, e: "enter", plot: "site_0"}, {t: 52, e: "enter"}];
  write(dir + "/reserved.json", reserved);
  world(["--walk=" + dir + "/reserved.json", "--log=" + dir + "/reserved-log.json"], 100);
  const decisions = read(dir + "/reserved-log.json").events;
  assert.ok(decisions.some(e => e.t === 50 && e.e === "refused" && e.plot === "site_0"));
  assert.ok(decisions.some(e => e.t === 52 && e.to === "stage" && e.plot === "site_0"));
  console.log("job -30, draft +15, legacy/zero omitted; arrival 38, reload 42, enter 50; save/load and changed-draft replay");
}

function hash() {
  const at = [40, 0], ticks = 350, seed = 1;
  const walk = read(fixtures + "/site_arrive.json");
  const lot = makeJob("hash", at, 0);
  Object.assign(walk, {ticks, events: [], player: [[0, [40, 0, 0]]]});
  walk.landscape.lots = [lot];
  write(dir + "/walk.json", walk);
  const hashes = [];
  function checkRun(lines, logPath, yaw) {
    const log = read(logPath);
    const plot = log.walk.plots.find(p => p.id === "site_0");
    assert.equal(plot.seed, seed);
    assert.equal(plot.yaw, yaw);
    const site = JSON.parse(lines.find(l => l.startsWith("[site] {")).slice(7)).sites[0];
    assert.equal(site.arrived, packName);
    const pack = log.packs.find(p => p.plot === "site_0");
    assert.equal(pack.ticks, 241, "promoted bot must finish its own 241 frames");
    assert.match(pack.state_hash, /^[0-9a-f]{64}$/);
    hashes.push(pack.state_hash);
  }
  for (const yaw of [0, 30]) {
    const jobLog = lot.job + "/job.jsonl";
    const rows = fs.readFileSync(jobLog, "utf8").trimEnd().split("\n").map(JSON.parse);
    rows[0].lot.yaw_deg = yaw;
    fs.writeFileSync(jobLog, rows.map(row => JSON.stringify(row)).join("\n") + "\n");
    const logPath = dir + "/world-" + yaw + ".json";
    checkRun(world(["--walk=" + dir + "/walk.json", "--log=" + logPath], ticks), logPath, yaw ? -yaw : undefined);
  }
  const replayLog = dir + "/replay.json";
  checkRun(world(["--replay=" + dir + "/world-30.json", "--log=" + replayLog], ticks), replayLog, -30);
  const report = dir + "/solo.json";
  const solo = spawnSync("bash", [engine + "/tools/tl.sh", "bot", "--pack=" + lot.job + "/promoted/" + packName,
    "--seed=" + seed, "--frames=241", "--report=" + report],
    {encoding: "utf8", env: {...process.env, TL_QUIET: "1", TL_GODOT: godot}, windowsHide: true});
  if (solo.error) throw solo.error;
  assert.equal(solo.status, 0, solo.stdout + solo.stderr);
  const result = read(report);
  assert.deepEqual([result.schema, result.ok, result.outcome, result.frames], ["tl.verify/1", true, "passed", 241]);
  hashes.push(result.metrics.state_hash);
  assert.equal(new Set(hashes).size, 1, "world zero, world turned, replay, solo: " + hashes.join(", "));
  console.log("seed 1, 241 bot frames, world 0 = editor +30 = replay = tl.sh bot: " + hashes[0]);
}

function stage() {
  const walk = read(fixtures + "/site_arrive.json");
  walk.landscape.lots = [makeJob("stage", [40, 0], 30)];
  walk.player = [[0, [40, 0, 0]]];
  walk.road = [[-100, 34], [140, 34]];
  walk.ticks = 100;
  walk.events = [];
  write(dir + "/walk.json", walk);
  const result = spawnSync(godot, ["--headless", "--fixed-fps", "60", "--quit-after", "600", "--path", engine,
    "--script", "res://kernel/world/site/fixtures/arrived_yaw_stage.gd", "--", dir + "/walk.json"],
    {encoding: "utf8", env: {...process.env, TL_CACHE_DIR: dir + "/cache"}, windowsHide: true});
  if (result.error) throw result.error;
  const output = result.stdout + "\n" + result.stderr;
  assert.equal(result.status, 0, output.slice(-2500));
  assert.doesNotMatch(output, /^(?:SCRIPT ERROR|ERROR):/m);
  assert.match(output, /^SITE ARRIVED YAW STAGE OK\r?$/m);
  console.log("turned visitor marker, local stage camera, relative second plot, road-facing return 5 m outside");
}

if (proof === "record") record();
else if (proof === "hash") hash();
else if (proof === "stage") stage();
else throw new Error("unknown proof: " + proof);
