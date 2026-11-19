# One world reads three copies of the arrival fixture, each with its own jobs root.
if [ -z "$FILTER" ] || [[ "site.editor_lot_job" == *"$FILTER"* ]]; then
  jl_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  jl_engine="$(cd "$HERE/.." && pwd)"
  jl_dir="$(mktemp -d "$OUT/editor-joblot-XXXXXX")"
  if command -v cygpath >/dev/null 2>&1; then
    jl_engine="$(cygpath -m "$jl_engine")"
    jl_dir="$(cygpath -m "$jl_dir")"
  fi
  why=""
  node - "$jl_engine" "$jl_dir" <<'NODE' || why="could not prepare fixture copies"
const fs = require("node:fs"), path = require("node:path");
const [engine, root] = process.argv.slice(2);
const lots = [[40, 0], [-40, 60], [70, 70]].map((at, i) => {
  const dir = root + "/jobs-" + i, job = dir + "/bounce";
  fs.cpSync(path.join(engine, "kernel/world/site/fixtures/arrive"), job, { recursive: true });
  if (i < 2) {
    const file = job + "/job.jsonl", log = fs.readFileSync(file, "utf8"), end = log.indexOf("\n");
    const created = JSON.parse(log.slice(0, end));
    created.lot = { at: i === 0 ? [100, -30] : [-100, 40], yaw_deg: 15, radius: i === 0 ? 26 : 22 };
    fs.writeFileSync(file, JSON.stringify(created) + log.slice(end));
    if (i === 1) {
      fs.mkdirSync(dir + "/_editor");
      fs.writeFileSync(dir + "/_editor/bounce.json", JSON.stringify({ schema: "tl.editor-draft/1",
        request: created.sentence, lot: { at: [45, 70], radius: 18, yaw_deg: 0 } }));
    }
  }
  return { at, radius: 30, h: 0, job, replay: { ticks_per_event: 20 } };
});
fs.writeFileSync(root + "/walk.json", JSON.stringify({ schema: "tl.walk/1", name: "editor_joblot",
  visitor: true, ticks: 60, mode: "bot", plots: [{ id: "a", pack: "pack_min", origin: [-120, 0, 0], seed: 1 }],
  landscape: { lots }, player: [[0, [0, 0, 40]]] }));
NODE
  if [ -z "$why" ]; then
    TL_CACHE_DIR="$jl_dir/cache" MSYS_NO_PATHCONV=1 "$jl_godot" --headless --fixed-fps 60 --path "$jl_engine" \
      res://kernel/host/host.tscn -- world "--walk=$jl_dir/walk.json" > "$jl_dir/world.log" 2>&1 || why="world exited $?"
  fi
  if [ -z "$why" ]; then
    why="$(node - "$jl_dir/world.log" <<'NODE' 2>&1
const assert = require("node:assert/strict");
const lines = require("node:fs").readFileSync(process.argv[2], "utf8").split(/\r?\n/);
assert.ok(lines.some(line => line.startsWith("[tl] world done")), "world did not finish");
const sites = JSON.parse(lines.find(line => line.startsWith("[site] {")).slice(7)).sites;
assert.deepEqual(sites.map(s => [s.lot, s.at, s.radius, s.lot_from]), [
  [0, [100, -30], 26, "job log"], [1, [-100, 40], 22, "job log"], [2, [70, 70], 30, undefined],
]);
assert.ok(lines.includes("[site] lot 0: at [100.0, -30.0], radius 26.0 m, from the job log"));
NODE
)" || why="${why:-invalid site report}"
  fi
  verdict site.editor_lot_job "$why" "two logged lots, one conflicting draft, one walk placement"
fi
