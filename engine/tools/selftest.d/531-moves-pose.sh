# Lane flight round 2 (19 Nov 2026): the village visitor's figure on a ledge and a bar (kernel/world/moves_pose_case.gd).
# Headless: a run and jump at a 2.4 m wall catches, the rig plays `hang` facing the wall with its hands within 0.35 m of
# the edge, mantles (`mantle`) and stands upright on top; a jump under a bar catches, `swing` plays with the hands within
# 0.30 m of the bar through a pumped swing, and the figure is upright within 20 ticks of the release; two runs are equal.

if [ -z "$FILTER" ] || [[ "moves.pose" == *"$FILTER"* ]]; then
  mp_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  mp_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && mp_engine="$(cygpath -m "$mp_engine")"
  mp_out="$(MSYS_NO_PATHCONV=1 timeout 180 "$mp_godot" --headless --fixed-fps 60 --path "$mp_engine" \
    --script res://kernel/world/moves_pose_case.gd 2>&1 | tr -d '\015' | grep -a '^MOVESPOSE\|SCRIPT ERROR')"
  mp_line="$(echo "$mp_out" | grep -a '^MOVESPOSE ' | head -1)"
  why=""
  if [ -z "$mp_line" ]; then why="no MOVESPOSE line (${mp_out:0:160})"
  elif echo "$mp_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$mp_out" | grep -a 'SCRIPT ERROR' | head -1)"
  elif [[ "$mp_line" != "MOVESPOSE ok=true "* ]]; then why="$mp_line"; fi
  verdict moves.pose "$why" "${mp_line#MOVESPOSE ok=true }"
fi
