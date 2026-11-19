# Hunt2 B7, B3, B9. One headless run, one required line for each selected case.
ww_cases="ground.concave_cover site.log_schema site.late_files"
if [ -z "$FILTER" ] || [[ "$ww_cases" == *"$FILTER"* ]]; then
  ww_dir="$(mktemp -d "$OUT/walker-world.XXXXXX")"
  ww_engine="$(cd "$HERE/.." && pwd)"
  ww_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  ww_rc=0
  if [[ -n "$ww_dir" ]] && cp -R "$ww_engine/kernel/world/site/fixtures/arrive" "$ww_dir/job" &&
      mv "$ww_dir/job/promoted" "$ww_dir/pending"; then
    ww_job="$(cd "$ww_dir/job" && pwd)"
    if command -v cygpath >/dev/null 2>&1; then
      ww_engine="$(cygpath -am "$ww_engine")"
      ww_job="$(cygpath -am "$ww_job")"
    fi
    MSYS_NO_PATHCONV=1 timeout 180 "$ww_godot" --headless --fixed-fps 60 --path "$ww_engine" \
      --script res://kernel/world/walks/walker_world_case.gd -- "$ww_job" >"$ww_dir/output" 2>&1 || ww_rc=$?
  else
    ww_rc=2
  fi
  for ww_case in $ww_cases; do
    ww_line="$(grep -am1 "^WALKERWORLD $ww_case " "$ww_dir/output" 2>/dev/null | tr -d '\r')"
    ww_why=""
    if [[ "$ww_line" != "WALKERWORLD $ww_case ok "* ]]; then
      ww_why="${ww_line:-missing WALKERWORLD $ww_case line} (exit $ww_rc)"
    elif [[ $ww_rc != 0 ]] || grep -aqE '^(SCRIPT ERROR|ERROR):' "$ww_dir/output"; then
      ww_why="Godot error or incomplete run (exit $ww_rc, see $ww_dir/output)"
    fi
    verdict "$ww_case" "$ww_why" "${ww_line#WALKERWORLD $ww_case ok }"
  done
fi
