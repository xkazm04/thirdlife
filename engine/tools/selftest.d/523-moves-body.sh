# Measure the visitor in its own server space and the pack biped through its public controls.
moves_body_cases() {
  local engine dir godot script name line why rc selected
  engine="$(cd "$HERE/.." && pwd)"
  dir="$OUT/moves"
  if command -v cygpath >/dev/null 2>&1; then
    engine="$(cygpath -m "$engine")"
    dir="$(cygpath -m "$dir")"
  fi
  godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  for script in moves_case moves_biped_case; do
    local names=(ledge_reach mantle drop bar_catch bar_swing bar_release flight_unchanged)
    [[ "$script" == moves_biped_case ]] && names=(optin)
    selected=0
    for name in "${names[@]}"; do
      [[ -z "$FILTER" || "moves.$name" == *"$FILTER"* ]] && selected=1
    done
    [[ $selected == 1 ]] || continue
    mkdir -p "$dir"
    MSYS_NO_PATHCONV=1 timeout 180 "$godot" --headless --fixed-fps 60 --path "$engine" \
      --log-file "$dir/$script.godot.log" --script "res://kernel/runner/$script.gd" > "$dir/$script.log" 2>&1
    rc=$?
    for name in "${names[@]}"; do
      [[ -z "$FILTER" || "moves.$name" == *"$FILTER"* ]] || continue
      line="$(tr -d '\r' < "$dir/$script.log" | grep -a "^MOVES $name ")"
      why=""
      if [[ "$line" != "MOVES $name PASS "* ]]; then why="${line:-missing measurement}"
      elif [[ $rc != 0 ]]; then why="case process exited $rc"
      elif grep -aEq '^(SCRIPT ERROR|ERROR):' "$dir/$script.log"; then why="engine error in $dir/$script.log"; fi
      local detail="${line#MOVES "$name" PASS }"
      if [[ "$name" == flight_unchanged && -z "$why" ]]; then
        # Also require the complete round-one suite when this regression is run on its own.
        if TL_SELFTEST_DIR="$dir/flight" bash "$HERE/selftest.sh" flight. > "$dir/flight.log" 2>&1 &&
            [[ $(grep -c '^PASS flight\.' "$dir/flight.log") -ge 11 ]] &&
            grep -Eq '^selftest: [0-9]+ passed, 0 failed' "$dir/flight.log"; then
          detail+=" flight_cases=$(grep -c '^PASS flight\.' "$dir/flight.log")"
        else
          why="round-one flight suite incomplete or failed (see $dir/flight.log)"
        fi
      fi
      verdict "moves.$name" "$why" "$detail"
    done
  done
}
moves_body_cases
