# Lane walker round 2 (night of 19 Nov 2026), hunt2 B12: a rejected first style load (a missing --style file) leaves
# the default palette reachable (engine/kernel/world/walks/walker_style_case.gd, headless). A missing STYLECASE line is a FAIL.

if [ -z "$FILTER" ] || [[ "style.first_reject" == *"$FILTER"* ]]; then
  GG="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EG="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EG="$(cygpath -m "$EG")"
  sf_out="$(MSYS_NO_PATHCONV=1 timeout 120 "$GG" --headless --path "$EG" --script res://kernel/world/walks/walker_style_case.gd 2>&1 | tr -d '\015' | grep -a '^STYLECASE\|SCRIPT ERROR')"
  sf_line="$(echo "$sf_out" | grep -a '^STYLECASE first_reject ' | head -1)"
  why=""
  if [ -z "$sf_line" ]; then why="no STYLECASE line (${sf_out:0:120})"
  elif [[ "$sf_line" != "STYLECASE first_reject ok "* ]]; then why="${sf_line#STYLECASE }"
  elif echo "$sf_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$sf_out" | grep -a 'SCRIPT ERROR' | head -1)"; fi
  verdict style.first_reject "$why" "${sf_line#STYLECASE first_reject ok }"
fi
