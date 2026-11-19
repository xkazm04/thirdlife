# Headless village kit trees on level and sloped ground, measured against independent foliage hulls.
# Require the completed sweep, its clearance verdict and a clean engine exit.
if [ -z "$FILTER" ] || [[ "walker.crown" == *"$FILTER"* ]]; then
  crown_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  crown_engine="$(cd "$HERE/.." && pwd)"
  crown_dir="$(cd "$OUT" && pwd)"
  if command -v cygpath >/dev/null 2>&1; then
    crown_engine="$(cygpath -m "$crown_engine")"
    crown_dir="$(cygpath -m "$crown_dir")"
  fi
  crown_log="$crown_dir/walker-crown.log"
  crown_exit=0
  MSYS_NO_PATHCONV=1 TL_CACHE_DIR="$crown_dir" "$crown_godot" --headless \
    --fixed-fps 60 --quit-after 500 --path "$crown_engine" \
    --log-file "$crown_dir/walker-crown-engine.log" --script res://kernel/world/walks/crown_case.gd \
    -- regression >"$crown_log" 2>&1 || crown_exit=$?
  crown_line="$(tr -d '\r' <"$crown_log" | grep -a '^CROWNCASE regression ')"
  crown_why=""
  if [ -z "$crown_line" ]; then
    crown_why="no CROWNCASE regression line (Godot exit $crown_exit)"
  elif [[ "$crown_line" != "CROWNCASE regression ok frames=34560 poses=2880 "* ]]; then
    crown_why="$crown_line"
  elif [ "$crown_exit" -ne 0 ] || grep -aq 'SCRIPT ERROR\|^ERROR:' "$crown_log"; then
    crown_why="Godot exit $crown_exit or engine error in $crown_log"
  fi
  verdict walker.crown "$crown_why" "${crown_line#CROWNCASE regression ok }"
fi
