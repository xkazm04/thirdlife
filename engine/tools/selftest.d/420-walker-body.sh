# A narrow V supports the capsule. A replacement plot floor lifts its standing visitor.
# Run the selected cases to completion and require one passing WALKCASE line per name.
walker_cases=(walk.v_wedge walk.v_asymmetric walk.v_yaw walk.v_terrain walk.single_face walk.step_edge walk.pad_swap)
if [ -z "$FILTER" ] || [[ "${walker_cases[*]}" == *"$FILTER"* ]]; then
  walker_gd="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  walker_engine="$(cd "$HERE/.." && pwd)"
  if command -v cygpath >/dev/null 2>&1; then walker_engine="$(cygpath -m "$walker_engine")"; fi
  walker_log="$OUT/420-walker-body.txt"
  walker_rc=0
  MSYS_NO_PATHCONV=1 "$walker_gd" --headless --path "$walker_engine" --script res://kernel/world/walks/walk_case_c.gd -- "$FILTER" > "$walker_log" 2>&1 || walker_rc=$?
  walker_lines="$(tr -d '\r' < "$walker_log" | grep '^WALKCASE ')"
  walker_n=0
  for wc in "${walker_cases[@]}"; do
    if [[ "$wc" == *"$FILTER"* ]]; then walker_n=$((walker_n+1)); fi
  done
  for wc in "${walker_cases[@]}"; do
    if [[ "$wc" != *"$FILTER"* ]]; then continue; fi
    wl="$(echo "$walker_lines" | grep -F "WALKCASE $wc ")"
    why=""
    if [[ "$wl" != "WALKCASE $wc ok "* || "$wl" == *$'\n'* ]]; then
      why="${wl:-no WALKCASE line for $wc}"
    elif [ "$walker_rc" -ne 0 ] || ! grep -Fxq "WALKCASE done $walker_n $walker_n" <<< "$walker_lines"; then
      why="incomplete or failed run (Godot exit $walker_rc; see $walker_log)"
    fi
    verdict "$wc" "$why" "${wl#WALKCASE $wc ok }"
  done
fi
