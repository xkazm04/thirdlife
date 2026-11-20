# Diorama wardrobe budgets, palette rebuilds, and posed hands on the real grip lines.
if [ -z "$FILTER" ] || [[ "character.clay" == *"$FILTER"* ]]; then
  clay_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  clay_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && clay_engine="$(cygpath -m "$clay_engine")"
  clay_log="$OUT/character-clay.log"
  why=""
  MSYS_NO_PATHCONV=1 timeout 90 "$clay_godot" --headless --fixed-fps 60 --path "$clay_engine" \
    --script res://rigs/review/clay_case.gd > "$clay_log" 2>&1 || why="Godot exit $?"
  clay_line="$(tr -d '\r' < "$clay_log" | grep -a '^CLAY ' | tail -1)"
  if [[ "$clay_line" != "CLAY ok=true "* ]]; then why="${why:+$why; }${clay_line:-missing CLAY result}"; fi
  if grep -aq 'SCRIPT ERROR' "$clay_log"; then why="${why:+$why; }script error in $clay_log"; fi
  verdict character.clay "$why" "${clay_line#CLAY ok=true }"
fi
