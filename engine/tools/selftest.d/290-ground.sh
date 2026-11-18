# Check the ground openings under plots with different pack geometry.
# The headless ground case checks when each opening may be visible.

# --- walker-feel T (18 Nov): the ground stops blinking ---
# The world's ground is cut open only under a pack whose own ground covers its plot (ex_car's boxes: no hole, so no
# sky pit), and a plot that draws nothing yet keeps its hole shut (kernel/world/walks/ground_case.gd, headless).
if [ -z "$FILTER" ] || [[ "ground.no_sky_pit" == *"$FILTER"* ]]; then
  GG="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EG="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EG="$(cygpath -m "$EG")"
  out="$(MSYS_NO_PATHCONV=1 "$GG" --headless --path "$EG" --script res://kernel/world/walks/ground_case.gd 2>&1 | tr -d '\015' | grep '^GROUNDCASE')"
  why=""; [[ "$out" == "GROUNDCASE ok"* ]] || why="${out:-no GROUNDCASE line}"
  verdict ground.no_sky_pit "$why" "${out#GROUNDCASE ok }"
fi

