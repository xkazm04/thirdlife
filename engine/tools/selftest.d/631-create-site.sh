# Night of 21 Nov 2026, lane L3: the village site reads a designer v2 job log in a real world (kernel/world/site.gd with
# the strict site/event_schema.gd). The village of boot/village.json, every plot pack_min, its two lots given the
# fixture jobs c5-building and c8-phase2 (engine/ui/fixtures/create/, every 2026-11-20 key but run_through), replayed
# one event per tick. A new key that the strict reader did not know would stop the log there (`log_error`) and the
# sign would show less than the file holds.
#   create_site.read   both sites read their whole log (events = events in the file), no log error, no script error
#   create_site.phase  each site's report says its phase: "phase 1 of 3: Slide and bump", "phase 2 of 3: Rivals and cracks"
if [ -z "$FILTER" ] || [[ "create_site.read" == *"$FILTER"* || "create_site.phase" == *"$FILTER"* ]]; then
  cs_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  cs_engine="$(cd "$HERE/.." && pwd)"
  cs_why=""
  cs_result=""
  if ! cs_dir="$(mktemp -d "$OUT/create-site-XXXXXX")"; then
    cs_why="could not create the fixture directory"
  fi
  if [ -z "$cs_why" ]; then
    if command -v cygpath >/dev/null 2>&1; then
      cs_engine="$(cygpath -am "$cs_engine")"
      cs_dir="$(cygpath -am "$cs_dir")"
    fi
    node - "$cs_engine" "$cs_dir" <<'NODE' || cs_why="could not prepare the village and its two jobs"
const fs = require("node:fs");
const [engine, dir] = process.argv.slice(2);
const walk = JSON.parse(fs.readFileSync(engine + "/boot/village.json", "utf8"));
walk.ticks = 240;
walk.events = [];
for (const plot of walk.plots) plot.pack = "pack_min";
const jobs = ["c5-building", "c8-phase2"];
for (const [i, lot] of walk.landscape.lots.entries()) {
  lot.job = dir + "/" + jobs[i];
  lot.replay = { ticks_per_event: 1 };
  fs.cpSync(engine + "/ui/fixtures/create/" + jobs[i], lot.job, { recursive: true });
}
fs.writeFileSync(dir + "/walk.json", JSON.stringify(walk));
NODE
  fi
  if [ -z "$cs_why" ]; then
    TL_CACHE_DIR="$cs_dir/cache" MSYS_NO_PATHCONV=1 timeout 300 "$cs_godot" --headless --fixed-fps 60 --path "$cs_engine" \
      res://kernel/host/host.tscn -- world "--walk=$cs_dir/walk.json" "--log=$cs_dir/replay.json" >"$cs_dir/world.log" 2>&1 || cs_why="world exited $?"
  fi
  if [ -z "$cs_why" ]; then
    cs_result="$(node - "$cs_dir" <<'NODE' 2>&1
const fs = require("node:fs"), assert = require("node:assert/strict");
const lines = fs.readFileSync(process.argv[2] + "/world.log", "utf8").split(/\r?\n/);
assert.ok(lines.some(l => l.startsWith("[tl] world done:") && l.endsWith("ticks=240")), "world did not finish");
const err = lines.find(l => l.startsWith("SCRIPT ERROR"));
assert.ok(!err, "world reported a script error: " + err);
const site = lines.find(l => l.startsWith("[site] {"));
assert.ok(site, "no [site] report line");
const sites = JSON.parse(site.slice(7)).sites;
assert.equal(sites.length, 2, "two sites");
const out = [];
for (const s of sites) {
  assert.equal(s.log_error, undefined, "lot " + s.lot + ": " + s.log_error);
  assert.equal(s.events, s.events_in_file, "lot " + s.lot + " showed " + s.events + " of " + s.events_in_file + " events");
  out.push(s.job.split("/").pop() + " " + s.events + "/" + s.events_in_file + " events, " + JSON.stringify(s.phase ?? null));
}
console.log("READ " + out.join("; "));
console.log("PHASE " + sites.map(s => s.phase ?? "").join(" | "));
NODE
)" || cs_why="$cs_result"
  fi
  if [ -z "$FILTER" ] || [[ "create_site.read" == *"$FILTER"* ]]; then
    verdict create_site.read "$cs_why" "$(echo "$cs_result" | grep '^READ ' | cut -c6-)"
  fi
  if [ -z "$FILTER" ] || [[ "create_site.phase" == *"$FILTER"* ]]; then
    cs_phase="$(echo "$cs_result" | grep '^PHASE ' | cut -c7-)"
    cs_pwhy="$cs_why"
    [ -z "$cs_pwhy" ] && [ "$cs_phase" != "phase 1 of 3: Slide and bump | phase 2 of 3: Rivals and cracks" ] && cs_pwhy="phases were: '$cs_phase'"
    verdict create_site.phase "$cs_pwhy" "$cs_phase"
  fi
fi
