# The moved site's height in a real village layout, and the two walls the visitor meets at its entrance.
if [ -z "$FILTER" ] || [[ "site.editor_pad" == *"$FILTER"* || "site.no_ring" == *"$FILTER"* ]]; then
  es_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  es_engine="$(cd "$HERE/.." && pwd)"
  if ! es_dir="$(mktemp -d "$OUT/editor-site-XXXXXX")"; then
    verdict site.editor_pad "could not create the fixture directory"
    verdict site.no_ring "could not create the fixture directory"
    return
  fi
  if command -v cygpath >/dev/null 2>&1; then
    es_engine="$(cygpath -am "$es_engine")"
    es_dir="$(cygpath -am "$es_dir")"
  fi

  if [ -z "$FILTER" ] || [[ "site.editor_pad" == *"$FILTER"* ]]; then
    why=""
    node - "$es_engine" "$es_dir" <<'NODE' || why="could not prepare the village and its two jobs"
const fs = require("node:fs");
const [engine, dir] = process.argv.slice(2);
const walk = JSON.parse(fs.readFileSync(engine + "/boot/village.json", "utf8"));
walk.ticks = 420;
walk.player = [[0, [-225, 0, 68]]];
walk.events = [];
for (const plot of walk.plots) plot.pack = "pack_min"; // Keep all the village's terrain inputs.
for (const [i, lot] of walk.landscape.lots.entries()) {
  lot.job = dir + "/job-" + i;
  lot.replay = { ticks_per_event: 20 };
  fs.cpSync(engine + "/kernel/world/site/fixtures/arrive", lot.job, { recursive: true });
}
const file = walk.landscape.lots[0].job + "/job.jsonl";
const log = fs.readFileSync(file, "utf8"), end = log.indexOf("\n");
const created = JSON.parse(log.slice(0, end));
created.lot = { at: [-225, 68], yaw_deg: 15, radius: 32 };
fs.writeFileSync(file, JSON.stringify(created) + log.slice(end));
fs.writeFileSync(dir + "/walk.json", JSON.stringify(walk));
NODE
    if [ -z "$why" ]; then
      TL_CACHE_DIR="$es_dir/cache" MSYS_NO_PATHCONV=1 "$es_godot" --headless --fixed-fps 60 --path "$es_engine" \
        res://kernel/host/host.tscn -- world "--walk=$es_dir/walk.json" "--log=$es_dir/replay.json" >"$es_dir/world.log" 2>&1 || why="world exited $?"
    fi
    if [ -z "$why" ]; then
      es_result="$(node - "$es_dir" <<'NODE' 2>&1
const fs = require("node:fs"), assert = require("node:assert/strict");
const read = name => fs.readFileSync(process.argv[2] + "/" + name, "utf8");
const lines = read("world.log").split(/\r?\n/);
assert.ok(lines.some(line => line.startsWith("[tl] world done:") && line.endsWith("ticks=420")), "world did not finish");
assert.ok(!lines.some(line => line.startsWith("SCRIPT ERROR")), "world reported a script error");
const [moved, kept] = JSON.parse(lines.find(line => line.startsWith("[site] {")).slice(7)).sites;
// Independent reference from VillageTerrain.base_h on the windowed village landscape.
const land = 5.558897357;
assert.deepEqual(moved.at, [-225, 68]);
assert.equal(moved.arrived, "example.bounce@0.1.0");
assert.ok(Math.abs(moved.pad_h - land) <= 0.05, "reported pad_h=" + moved.pad_h);
assert.ok(lines.includes("[site] lot 0: pad h 2.0 -> " + moved.pad_h.toFixed(2) + " m (the land at the new centre)"));
assert.equal(kept.pad_h, undefined);
const walk = JSON.parse(read("replay.json")).walk;
for (const [site, expected] of [[moved, moved.pad_h], [kept, 1]]) {
  const lot = walk.landscape.lots[site.lot];
  assert.equal(lot.h, expected);
  const origin = [lot.at[0], expected, lot.at[1]];
  assert.deepEqual(walk.plots.find(p => p.site_lot === site.lot).origin, origin);
  const pack = lines.filter(line => line.startsWith('{"schema":"tl.world/1","kind":"pack"'))
    .map(line => JSON.parse(line)).find(p => p.plot === site.plot);
  assert.deepEqual([pack.plot_origin[0], pack.plot_origin[2]], lot.at);
  assert.ok(Math.abs(pack.plot_origin[1] - expected) < 0.000001, "runtime plot height (Vector3 precision)");
}
console.log("base_h(-225,68)=" + land.toFixed(6) + " m, moved pad=" + moved.pad_h.toFixed(6) + " m, stationary pad=1 m");
NODE
)" || why="$es_result"
    fi
    verdict site.editor_pad "$why" "$es_result"
  fi

  if [ -z "$FILTER" ] || [[ "site.no_ring" == *"$FILTER"* ]]; then
    why=""
    MSYS_NO_PATHCONV=1 "$es_godot" --headless --fixed-fps 60 --quit-after 1200 --path "$es_engine" \
      --script res://kernel/world/site/fixtures/no_ring.gd >"$es_dir/rails.log" 2>&1 || why="Godot exited $?"
    grep -q '^SITE RAILS OK' "$es_dir/rails.log" || why="rail proof did not finish: $(grep -m1 'SCRIPT ERROR' "$es_dir/rails.log")"
    if grep -q '^SCRIPT ERROR' "$es_dir/rails.log"; then why="$(grep -m1 '^SCRIPT ERROR' "$es_dir/rails.log")"; fi
    verdict site.no_ring "$why" "worker mesh and two 1.2 m entrance walls checked before and after refit"
  fi
  rm -rf -- "$es_dir"
fi
