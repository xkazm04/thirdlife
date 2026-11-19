# A site samples the same village ground when it starts there or moves there.
if [ -z "$FILTER" ] || [[ "site.auto_pad" == *"$FILTER"* ]]; then
  ap_engine="$(cd "$HERE/.." && pwd)"
  ap_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  if ! ap_dir="$(mktemp -d "$OUT/auto-pad-XXXXXX")"; then
    verdict site.auto_pad "could not create fixture directory"
    return
  fi
  if command -v cygpath >/dev/null 2>&1; then
    ap_engine="$(cygpath -am "$ap_engine")"
    ap_dir="$(cygpath -am "$ap_dir")"
  fi
  why=""
  ap_result="$(node - "$ap_engine" "$ap_dir" "$ap_godot" <<'NODE' 2>&1
const fs = require("node:fs");
const assert = require("node:assert/strict");
const {spawnSync} = require("node:child_process");
const [engine, dir, godot] = process.argv.slice(2);
const village = JSON.parse(fs.readFileSync(engine + "/boot/village.json", "utf8"));
const [first, fixed] = village.landscape.lots;
const centre = [-225, 68];
fixed.h = 13.375;
village.ticks = 60;
village.player = [[0, [-225, 0, 68]]];
village.events = [];
for (const plot of village.plots) plot.pack = "pack_min";
for (const [i, lot] of village.landscape.lots.entries()) {
  lot.job = dir + "/job-" + i;
  lot.replay = {ticks_per_event: 1};
  fs.cpSync(engine + "/kernel/world/site/fixtures/arrive", lot.job, {recursive: true});
  const path = lot.job + "/job.jsonl";
  const rows = fs.readFileSync(path, "utf8").split("\n");
  const created = JSON.parse(rows[0]);
  created.lot = {at: i === 0 ? centre : lot.at, radius: i === 0 ? 32 : lot.radius, yaw_deg: 0};
  rows[0] = JSON.stringify(created);
  fs.writeFileSync(path, rows.join("\n"));
}
const moved = structuredClone(village);
first.at = centre;
delete first.h;

function run(walk, label) {
  const path = dir + "/" + label;
  fs.writeFileSync(path + ".json", JSON.stringify(walk));
  const result = spawnSync(godot, ["--headless", "--fixed-fps", "60", "--path", engine,
    "res://kernel/host/host.tscn", "--", "world", "--walk=" + path + ".json", "--log=" + path + ".log.json"],
    {encoding: "utf8", env: {...process.env, TL_CACHE_DIR: dir + "/cache"}, windowsHide: true});
  if (result.error) throw result.error;
  const output = result.stdout + "\n" + result.stderr;
  assert.equal(result.status, 0, label + " world exit: " + output.slice(-1500));
  assert.match(output, /^\[tl\] world done: .*ticks=60\r?$/m);
  assert.doesNotMatch(output, /^(?:SCRIPT ERROR|ERROR):/m);
  const lines = output.split(/\r?\n/);
  const [sampled, kept] = JSON.parse(lines.find(line => line.startsWith("[site] {")).slice(7)).sites;
  const logged = JSON.parse(fs.readFileSync(path + ".log.json", "utf8")).walk;
  // Same final village bounds and independent terrain reference as block 501.
  assert.ok(Math.abs(sampled.pad_h - 5.558897357) <= 0.05, label + " pad_h=" + sampled.pad_h);
  assert.equal(sampled.arrived, "example.bounce@0.1.0");
  const change = label === "moved" ? ["2.0", "new centre"] : ["auto", "centre"];
  assert.ok(lines.includes(`[site] lot 0: pad h ${change[0]} -> ${sampled.pad_h.toFixed(2)} m (the land at the ${change[1]})`));
  assert.ok(!Object.hasOwn(kept, "pad_h"), "stationary explicit height was resampled");
  const packs = lines.filter(line => line.startsWith('{"schema":"tl.world/1","kind":"pack"')).map(line => JSON.parse(line));
  for (const [site, at, height] of [[sampled, centre, sampled.pad_h], [kept, fixed.at, fixed.h]]) {
    const plot = logged.plots.find(p => p.site_lot === site.lot);
    assert.equal(logged.landscape.lots[site.lot].h, height);
    assert.deepEqual(plot.origin, [at[0], height, at[1]]);
    const [x, y, z] = packs.find(p => p.plot === site.plot).plot_origin;
    assert.deepEqual([x, z], at);
    assert.ok(Math.abs(y - height) < 0.000001, label + " runtime plot height=" + y);
  }
  if (label === "reserved") assert.equal(logged.landscape.pad_h[logged.plots.findIndex(p => p.site_lot === 0)], sampled.pad_h);
  return logged;
}
const reserved = run(village, "stationary");
run(moved, "moved");
// Older logs can already contain this plot with origin.y = 0 and no lot height.
const index = reserved.plots.findIndex(p => p.site_lot === 0);
delete reserved.landscape.lots[0].h;
reserved.plots[index].origin[1] = 0;
reserved.landscape.pad_h[index] = 0;
run(reserved, "reserved");
console.log("stationary auto, old reservation and moved pad at 5.56 m; stationary explicit pad at 13.375 m");
NODE
)" || why="$ap_result"
  verdict site.auto_pad "$why" "$ap_result"
  rm -rf -- "$ap_dir"
fi
