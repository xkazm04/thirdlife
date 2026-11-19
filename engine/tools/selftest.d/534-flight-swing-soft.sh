# Lane flight round 3 (19 Nov 2026): a hard-pumped or fast-entered bar swing ends softly near 85 deg (no dead stop at the 100 deg guard; on the old code: 98 guard ticks, 5.27 rad/s jumps).
# Headless (kernel/world/swing_soft_case.gd); prints one `SWINGSOFT ok=<bool> ...` line.

if [ -z "$FILTER" ] || [[ "moves.swing_soft" == *"$FILTER"* ]]; then
  b_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  b_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && b_engine="$(cygpath -m "$b_engine")"
  b_out="$(MSYS_NO_PATHCONV=1 timeout 180 "$b_godot" --headless --fixed-fps 60 --path "$b_engine" --script res://kernel/world/swing_soft_case.gd 2>&1 | tr -d '\015' | grep -a '^SWINGSOFT\|SCRIPT ERROR')"
  b_line="$(echo "$b_out" | grep -a '^SWINGSOFT ' | head -1)"
  why=""
  if [ -z "$b_line" ]; then why="no SWINGSOFT line (${b_out:0:160})"
  elif echo "$b_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$b_out" | grep -a 'SCRIPT ERROR' | head -1)"
  elif [[ "$b_line" != "SWINGSOFT ok=true "* ]]; then why="$b_line"; fi
  verdict moves.swing_soft "$why" "${b_line#SWINGSOFT ok=true }"
fi
