# Start the recorded visit on the ground just inside ex_walker's south wall in wf_feel.
if [[ -z "$FILTER" || "moves.replay" == *"$FILTER"* ]]; then
  moves_village_replay() {
    local engine dir phase rc result
    engine="$(cd "$HERE/.." && pwd)"
    dir="$OUT/moves-replay"
    mkdir -p "$dir"
    if command -v cygpath >/dev/null 2>&1; then
      dir="$(cygpath -m "$dir")"
      engine="$(cygpath -m "$engine")"
    fi
    node - "$engine" "$dir" <<'JS' || { verdict moves.replay "fixture creation failed"; return; }
const fs = require("node:fs");
const [engine, dir] = process.argv.slice(2);
const walk = JSON.parse(fs.readFileSync(engine + "/kernel/world/walks/wf_feel.json"));
walk.player = [[0, [-115, 4, -28.2]], [120, [-115, 4, -24]]];
const devices = [[45,"key","W",1],[53,"key","Space",1],[55,"key","Space",0],[67,"key","W",0]];
for (let t=46; t<=100; t++) devices.push([t,"mark","wall",0]);
fs.writeFileSync(dir + "/walk.json", JSON.stringify(walk));
fs.writeFileSync(dir + "/devices.json", JSON.stringify(devices));
JS
    rm -f "$dir/input.json"
    for phase in record replay; do
      local args=("--input=$dir/input.json")
      [[ "$phase" == record ]] && args=("--devices=$dir/devices.json" "--record=$dir/input.json")
      bash "$HERE/world.sh" visit-test "$dir/walk.json" --cost=model --load=block --ticks=120 \
        "${args[@]}" > "$dir/$phase.log" 2>&1
      rc=$?
      if [[ $rc != 0 ]] || grep -aEq '^(SCRIPT ERROR|ERROR):' "$dir/$phase.log"; then
        verdict moves.replay "$phase failed (exit $rc, see $dir/$phase.log)"
        return
      fi
    done
    result="$(node - "$dir" <<'JS'
const fs = require("node:fs");
const dir = process.argv[2];
const read = f => fs.readFileSync(dir + "/" + f, "utf8");
const rows = f => read(f).split(/\r?\n/).filter(l => l.startsWith("{")).map(l => JSON.parse(l));
const [a,b] = ["record.log","replay.log"].map(rows);
const record = JSON.parse(read("input.json"));
const modes = a.filter(r => r.mark === "wall").map(r => r.body);
if (record.schema !== "tl.input/1" || record.length !== 120 || !a.some(r => r.kind === "visit_record" && r.ok)
    || !["forward","jump"].every(k => record.frames.some(row => row[1] === k && row[2] > 0))
    || !modes.includes("hang") || !modes.includes("mantle")) throw Error("missing recorded jump, hang or mantle");
function end(rows) {
  if (!rows.some(r => r.kind === "tour" && r.world_ticks === 120)) throw Error("incomplete visit");
  return rows.find(r => r.kind === "visit_path" && r.tick === 120).feet;
}
const first = end(a), again = end(b);
const delta = Math.hypot(...first.map((v,i) => v-again[i]));
if (!(first[1] >= 6.99 && delta <= 0.001)) throw Error("incorrect landing or replay");
console.log("wf_feel/ex_walker ticks=120 hang=true mantle=true feet=[" + first + "] replay=[" + again + "] delta_m=" + delta.toFixed(3));
JS
)" && verdict moves.replay "" "$result" || verdict moves.replay "recorded move or replay mismatch"
  }
  moves_village_replay
fi
