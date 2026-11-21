# Biped contact reactions on the walking and skating versions of all three looks.
if [ -z "$FILTER" ] || [[ "rig.react.clips rig.react.pose" == *"$FILTER"* ]]; then
  react_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  react_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && react_engine="$(cygpath -m "$react_engine")"
  react_log="$OUT/reaction-poses.log"
  react_status=0
  MSYS_NO_PATHCONV=1 timeout 180 "$react_godot" --headless --fixed-fps 60 --path "$react_engine" \
    --script res://rigs/review/reaction_case.gd >"$react_log" 2>&1 || react_status=$?
  for react_case in clips pose; do
    react_line="$(tr -d '\r' <"$react_log" | grep -a "^REACT $react_case " | head -1)"
    why=""
    if grep -aq 'SCRIPT ERROR' "$react_log"; then why="$(grep -am1 'SCRIPT ERROR' "$react_log")"
    elif [[ "$react_line" != "REACT $react_case ok=true "* ]]; then why="${react_line:-missing REACT line (exit $react_status)}"
    elif [ "$react_status" != 0 ] && ! grep -aq '^REACT .* ok=false ' "$react_log"; then why="Godot exited $react_status"; fi
    verdict "rig.react.$react_case" "$why" "${react_line#REACT $react_case ok=true }"
  done
fi
