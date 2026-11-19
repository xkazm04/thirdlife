# Lane walker round 3 (night of 19 Nov 2026): TL_CROWN_SWING=behind keeps the visitor's camera behind him near crowns
# (crown_camera.gd never swings it sideways). Runs the headless crown sweep of block 400 with the setting: it must
# finish its 2,880 poses with 0 sideways ticks. Its leaf counts are printed (the price of staying behind), not judged.

if [ -z "$FILTER" ] || [[ "walker.crown_swing_behind" == *"$FILTER"* ]]; then
  sw_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  sw_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && sw_engine="$(cygpath -m "$sw_engine")"
  sw_out="$(MSYS_NO_PATHCONV=1 TL_CROWN_SWING=behind timeout 200 "$sw_godot" --headless --fixed-fps 60 --path "$sw_engine" \
    --script res://kernel/world/walks/crown_case.gd -- regression 2>&1 | tr -d '\015' | grep -a '^CROWNCASE\|SCRIPT ERROR')"
  sw_line="$(echo "$sw_out" | grep -a '^CROWNCASE regression ' | head -1)"
  why=""
  if [ -z "$sw_line" ]; then why="no CROWNCASE line (${sw_out:0:120})"
  elif [[ "$sw_line" != *" frames=34560 poses=2880 "* ]]; then why="the sweep did not complete: $sw_line"
  elif [[ "$sw_line" != *" side=0 "* ]]; then why="it swung sideways with TL_CROWN_SWING=behind: $sw_line"
  elif echo "$sw_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$sw_out" | grep -a 'SCRIPT ERROR' | head -1)"; fi
  verdict walker.crown_swing_behind "$why" "${sw_line#CROWNCASE regression * }"
fi
