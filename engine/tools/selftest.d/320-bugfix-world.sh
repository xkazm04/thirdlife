# bugfix-37 lane world: the world's ground and its colliders (kernel/world/walks/bugfix_world_case.gd, headless, one
# Godot run for all eight). A pack's copied box keeps its shape (D9), a shut pad carries him until the game's colliders
# are in (D3), rim cover by triangles (D4), crossing triangles kept in far pictures (D13), flat-ground holes (D16), a road
# ending at the river (Q15), the pad height without pad_h (Q17), each road graded by its own width (Q21).
BFW_CASES="ground.ledger_shapes ground.shut_pad_solid ground.rotated_cover ground.crossing_faces ground.flat_holes ground.bridge_end ground.pad_lift ground.road_width"
if [ -z "$FILTER" ] || [[ "$BFW_CASES" == *"$FILTER"* ]]; then
  GG="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EG="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EG="$(cygpath -m "$EG")"
  bfw_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$GG" --headless --path "$EG" --script res://kernel/world/walks/bugfix_world_case.gd 2>&1 | tr -d '\015')"
  for bc in $BFW_CASES; do
    bl="$(echo "$bfw_out" | grep -m1 "^BFWORLD $bc ")"
    why=""; [[ "$bl" == "BFWORLD $bc ok"* ]] || why="${bl:-no BFWORLD $bc line (the run stopped: $(echo "$bfw_out" | grep -m1 'SCRIPT ERROR' | cut -c1-120))}"
    verdict "$bc" "$why" "${bl#BFWORLD $bc ok }"
  done
fi
