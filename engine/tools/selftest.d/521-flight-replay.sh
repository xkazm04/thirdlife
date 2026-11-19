# Record a real device-driven visit, then feed the saved samples to a second visit.
if [[ -z "$FILTER" || "flight.replay" == *"$FILTER"* ]]; then
  flight_replay() {
    local dir="$OUT/flight-replay" engine record replay result why=""
    mkdir -p "$dir"
    engine="$(cd "$HERE/.." && pwd)"
    if command -v cygpath >/dev/null 2>&1; then
      dir="$(cygpath -m "$dir")"
      engine="$(cygpath -m "$engine")"
    fi
    local common=(--cost=model --load=block --ticks=240)
    rm -f "$dir/input.json"
    bash "$HERE/world.sh" visit-test wf_feel "--devices=$engine/kernel/runner/flight.devices.json" \
      "--record=$dir/input.json" "${common[@]}" > "$dir/record.log" 2>&1
    record=$?
    if [ "$record" != 0 ] || [ ! -s "$dir/input.json" ]; then
      verdict flight.replay "record failed (exit $record)"
      return
    fi
    bash "$HERE/world.sh" visit-test wf_feel "--input=$dir/input.json" "${common[@]}" > "$dir/replay.log" 2>&1
    replay=$?
    result="$(node - "$dir" <<'JS'
const fs = require("node:fs");
const dir = process.argv[2];
function paths(file) {
  const raw = fs.readFileSync(dir + "/" + file, "utf8");
  if (/^(SCRIPT ERROR|ERROR):/m.test(raw)) throw Error("engine error in " + file);
  const rows = raw.split(/\r?\n/).filter(l => l.startsWith("{")).map(l => JSON.parse(l));
  if (!rows.some(r => r.kind === "tour" && r.world_ticks === 240)) throw Error("incomplete visit");
  return rows.filter(r => r.kind === "visit_path");
}
const a = paths("record.log"), b = paths("replay.log");
const record = JSON.parse(fs.readFileSync(dir + "/input.json"));
const held = new Set(record.frames.filter(row => row[2] > 0).map(row => row[1]));
if (record.schema !== "tl.input/1" || record.length !== 240 || !["fly","forward","jump","slide"].every(k => held.has(k))
    || !a.some(r => r.mark === "airborne" && r.body === "fly")) throw Error("missing recorded flight");
const end = a.find(p => p.tick === 240).feet, again = b.find(p => p.tick === 240).feet;
const error = Math.hypot(...end.map((v, i) => v - again[i]));
if (!(error <= 0.001)) throw Error("final feet differ by " + error);
console.log("ticks=240 record=[" + end + "] replay=[" + again + "] delta_m=" + error.toFixed(3));
JS
)" || why="flight path or record check failed"
    [ "$replay" = 0 ] || why="replay exited $replay"
    verdict flight.replay "$why" "$result"
  }
  flight_replay
fi
