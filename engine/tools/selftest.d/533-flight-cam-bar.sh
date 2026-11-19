# Lane flight round 3 (19 Nov 2026): the visitor's camera leaves marked bars out of its avoidance: walking under a bar and a hard swing on it give no lift, no pull and no pop (largest step under 0.6 m), while the old behaviour (control) lifts 60 deg and pulls 8.7 m.
# Headless (kernel/world/flight_cam_bar_case.gd); prints one `CAMBAR ok=<bool> ...` line.

if [ -z "$FILTER" ] || [[ "moves.cam_bar" == *"$FILTER"* ]]; then
  b_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  b_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && b_engine="$(cygpath -m "$b_engine")"
  b_out="$(MSYS_NO_PATHCONV=1 timeout 180 "$b_godot" --headless --fixed-fps 60 --path "$b_engine"     --script res://kernel/world/flight_cam_bar_case.gd 2>&1 | tr -d '\015' | grep -a '^CAMBAR\|SCRIPT ERROR')"
  b_line="$(echo "$b_out" | grep -a '^CAMBAR ' | head -1)"
  why=""
  if [ -z "$b_line" ]; then why="no CAMBAR line (${b_out:0:160})"
  elif echo "$b_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$b_out" | grep -a 'SCRIPT ERROR' | head -1)"
  elif [[ "$b_line" != "CAMBAR ok=true "* ]]; then why="$b_line"; fi
  verdict moves.cam_bar "$why" "${b_line#CAMBAR ok=true }"
fi
