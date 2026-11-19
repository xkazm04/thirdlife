# Lane walker (night of 19 Nov 2026): the held run slide keeps the biped above the floor (engine/rigs/review/
# walker_slide_floor.gd, headless). Before the fix the folded left foot sat 0.151 m under the floor (bugfix-37 new
# finding). A missing RIGCASE line is a FAIL.

if [ -z "$FILTER" ] || [[ "rig.walker.slide_floor" == *"$FILTER"* ]]; then
  GG="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EG="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EG="$(cygpath -m "$EG")"
  ws_out="$(MSYS_NO_PATHCONV=1 timeout 200 "$GG" --headless --path "$EG" --script res://rigs/review/walker_slide_floor.gd 2>&1 | tr -d '\015' | grep -a '^RIGCASE\|SCRIPT ERROR')"
  ws_line="$(echo "$ws_out" | grep -a '^RIGCASE slide_floor ' | head -1)"
  why=""
  if [ -z "$ws_line" ]; then why="no RIGCASE slide_floor line (${ws_out:0:120})"
  elif [[ "$ws_line" != "RIGCASE slide_floor ok "* ]]; then why="${ws_line#RIGCASE }"
  elif echo "$ws_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$ws_out" | grep -a 'SCRIPT ERROR' | head -1)"; fi
  verdict rig.walker.slide_floor "$why" "${ws_line#RIGCASE slide_floor ok }"
fi
