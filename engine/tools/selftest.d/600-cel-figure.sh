# Recolouring, all wardrobe budgets, the queued rig and a live return to classic.
if [ -z "$FILTER" ] || [[ "character.cel.wardrobe" == *"$FILTER"* ]]; then
  cel_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && cel_engine="$(cygpath -m "$cel_engine")"
  cel_log="$OUT/cel-figure.log"
  cel_why=""
  MSYS_NO_PATHCONV=1 timeout 90 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --path "$cel_engine" --script res://rigs/review/cel_case.gd > "$cel_log" 2>&1 || cel_why="exit $?"
  cel_line="$(tr -d '\r' < "$cel_log" | grep -a '^CEL_FIGURE ok=true ')"
  if [ -z "$cel_line" ] || grep -aEq 'SCRIPT ERROR|^ERROR:' "$cel_log"; then cel_why="see $cel_log"; fi
  verdict character.cel.wardrobe "$cel_why" "${cel_line#CEL_FIGURE ok=true }"
fi
