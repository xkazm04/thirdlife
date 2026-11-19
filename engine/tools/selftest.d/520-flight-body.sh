# One scene build for the village measurements. Missing lines, script errors and
# stopped processes fail even when an earlier measurement printed PASS.
flight_block() {
  local engine godot dir script name log rc detail why
  engine="$(cd "$HERE/.." && pwd)"
  dir="$OUT/flight"
  if command -v cygpath >/dev/null 2>&1; then
    engine="$(cygpath -m "$engine")"
    dir="$(cygpath -m "$dir")"
  fi
  godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  for script in flight_case flight_biped_case; do
    local names=(ratio accel ceiling sweep collide land gate)
    [ "$script" = flight_biped_case ] && names=(biped)
    local selected=0
    for name in "${names[@]}"; do
      [[ -z "$FILTER" || "flight.$name" == *"$FILTER"* ]] && selected=1
    done
    [ "$selected" = 1 ] || continue
    mkdir -p "$dir"
    log="$dir/$script.log"
    MSYS_NO_PATHCONV=1 timeout 180 "$godot" --headless --fixed-fps 60 --path "$engine" \
      --log-file "$dir/$script.godot.log" --script "res://kernel/runner/$script.gd" > "$log" 2>&1
    rc=$?
    for name in "${names[@]}"; do
      detail="$(tr -d '\r' < "$log" | grep -a "^FLIGHT $name " | head -1)"
      why=""
      if [[ "$detail" != "FLIGHT $name PASS "* ]]; then why="${detail:-missing measurement}"
      elif [ "$rc" -ne 0 ]; then why="case process exited $rc"
      elif grep -aEq '^(SCRIPT ERROR|ERROR):' "$log"; then why="engine error in $log"; fi
      verdict "flight.$name" "$why" "${detail#FLIGHT "$name" PASS }"
    done
  done
}
flight_block
