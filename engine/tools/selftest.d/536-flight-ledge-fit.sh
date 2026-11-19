# Lane flight round 3 (19 Nov 2026): the parkour lane's Skyline ledge (a slab top at y 10.13, ledges 2.90-3.10 m): float-noise contacts in the standing-room test no longer refuse the catch (walker_grips FIT_TOL 0.1 mm; before: 0 of 5 caught).
# Headless (kernel/runner/ledge_fit_case.gd); prints one `LEDGEFIT ok=<bool> ...` line.

if [ -z "$FILTER" ] || [[ "moves.ledge_fit" == *"$FILTER"* ]]; then
  b_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  b_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && b_engine="$(cygpath -m "$b_engine")"
  b_out="$(MSYS_NO_PATHCONV=1 timeout 180 "$b_godot" --headless --fixed-fps 60 --path "$b_engine" --script res://kernel/runner/ledge_fit_case.gd 2>&1 | tr -d '\015' | grep -a '^LEDGEFIT\|SCRIPT ERROR')"
  b_line="$(echo "$b_out" | grep -a '^LEDGEFIT ' | head -1)"
  why=""
  if [ -z "$b_line" ]; then why="no LEDGEFIT line (${b_out:0:160})"
  elif echo "$b_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$b_out" | grep -a 'SCRIPT ERROR' | head -1)"
  elif [[ "$b_line" != "LEDGEFIT ok=true "* ]]; then why="$b_line"; fi
  verdict moves.ledge_fit "$why" "${b_line#LEDGEFIT ok=true }"
fi
