# Grow a plain puck, plain ball and kit puck and compare measured meshes, shapes and mass.
# Probe the resting puck inside and outside its new collision boundary.
if [ -z "$FILTER" ] || [[ "feel.ball_radius" == *"$FILTER"* ]]; then
  radius_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  radius_engine="${TL_ENGINE_DIR:-$(cd "$HERE/.." && pwd)}"
  command -v cygpath >/dev/null 2>&1 && radius_engine="$(cygpath -m "$radius_engine")"
  radius_why=""
  radius_log="$OUT/ball-radius.log"
  MSYS_NO_PATHCONV=1 timeout 90 "$radius_godot" --headless --fixed-fps 60 --path "$radius_engine" \
    --script res://kernel/feel/ball_radius_case.gd >"$radius_log" 2>&1 || radius_why="probe exited $?"
  grep -aq '^RADIUS ok=true bodies=3 resting=true inside_hit=true outside_floor=true' "$radius_log" || radius_why="missing radius measurements in $radius_log"
  if grep -aqE 'SCRIPT ERROR|^ERROR:' "$radius_log"; then radius_why="$(grep -am1 -E 'SCRIPT ERROR|^ERROR:' "$radius_log")"; fi
  verdict feel.ball_radius "$radius_why" "3 shapes and meshes, unchanged masses, 0.25 m hits puck, 0.32 m hits floor"
fi
