# Observe the visitor's rig and wings during flight and for 40 ticks after touchdown.
if [[ -z "$FILTER" || "flight.pose" == *"$FILTER"* ]]; then
  flight_pose_case() {
    local engine dir godot rc line why=""
    engine="$(cd "$HERE/.." && pwd)"
    dir="$OUT/flight"
    mkdir -p "$dir"
    if command -v cygpath >/dev/null 2>&1; then
      engine="$(cygpath -m "$engine")"
      dir="$(cygpath -m "$dir")"
    fi
    godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
    MSYS_NO_PATHCONV=1 timeout 180 "$godot" --headless --fixed-fps 60 --path "$engine" \
      --log-file "$dir/pose.godot.log" --script res://kernel/runner/flight_case.gd -- pose > "$dir/pose.log" 2>&1
    rc=$?
    line="$(tr -d '\r' < "$dir/pose.log" | grep -a '^FLIGHT pose ')"
    if [[ "$line" != "FLIGHT pose PASS "* ]]; then why="${line:-missing measurement (exit $rc)}"
    elif [ "$rc" -ne 0 ]; then why="pose process exited $rc"
    elif grep -aEq '^(SCRIPT ERROR|ERROR):' "$dir/pose.log"; then why="engine error in $dir/pose.log"; fi
    verdict flight.pose "$why" "${line#FLIGHT pose PASS }"
  }
  flight_pose_case
fi
