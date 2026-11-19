# A site's reserved plot keeps the editor's heading through arrival.
for ay_probe in entry solids; do
  ay_case="site.arrived_yaw_$ay_probe"
  if [ -n "$FILTER" ] && [[ "$ay_case" != *"$FILTER"* ]]; then continue; fi
  ay_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  ay_engine="$(cd "$HERE/.." && pwd)"
  if command -v cygpath >/dev/null 2>&1; then ay_engine="$(cygpath -am "$ay_engine")"; fi
  why=""
  ay_log="$OUT/arrived-yaw-$ay_probe.log"
  MSYS_NO_PATHCONV=1 "$ay_godot" --headless --fixed-fps 60 --quit-after 600 --path "$ay_engine" \
    --script "res://kernel/world/site/fixtures/arrived_yaw_$ay_probe.gd" >"$ay_log" 2>&1 || why="Godot exited $?"
  if ! grep -q "^SITE ARRIVED YAW ${ay_probe^^} OK" "$ay_log" || grep -Eq '^(SCRIPT ERROR|ERROR):' "$ay_log"; then
    why="$ay_probe proof did not finish cleanly: $(tail -8 "$ay_log")"
  fi
  case "$ay_probe" in
    entry) ay_detail="40 x 12 m, +30/-30/0 degrees, oriented gaps and held/released entry";;
    solids) ay_detail="initial and sliced copies: turned bin wall, clear old position, bent rim and pack-local rays";;
  esac
  verdict "$ay_case" "$why" "$ay_detail"
done

for ay_proof in record hash stage; do
  ay_case="site.arrived_yaw_$ay_proof"
  if [ -n "$FILTER" ] && [[ "$ay_case" != *"$FILTER"* ]]; then continue; fi
  ay_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  ay_engine="$(cd "$HERE/.." && pwd)"
  if ! ay_dir="$(mktemp -d "$OUT/arrived-yaw-$ay_proof-XXXXXX")"; then
    verdict "$ay_case" "could not create fixture directory"
    continue
  fi
  if command -v cygpath >/dev/null 2>&1; then
    ay_engine="$(cygpath -am "$ay_engine")"
    ay_dir="$(cygpath -am "$ay_dir")"
  fi
  why=""
  ay_result="$(node "$ay_engine/kernel/world/site/fixtures/arrived_yaw_world.cjs" "$ay_proof" "$ay_engine" "$ay_dir" "$ay_godot" 2>&1)" || why="$ay_result"
  verdict "$ay_case" "$why" "$ay_result"
  rm -rf -- "$ay_dir"
done
