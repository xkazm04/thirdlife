# bugfix-37 lane world: the world's ground and its colliders (kernel/world/walks/bugfix_world_case.gd, headless, one
# Godot run for all eight). A pack's copied box keeps its shape (D9), a shut pad carries him until the game's colliders
# are in (D3), rim cover by triangles (D4), crossing triangles kept in far pictures (D13), flat-ground holes (D16), a road
# ending at the river (Q15), the pad height without pad_h (Q17), each road graded by its own width (Q21).
BFW_CASES="ground.ledger_shapes ground.shut_pad_solid ground.rotated_cover ground.crossing_faces ground.flat_holes ground.bridge_end ground.pad_lift ground.road_width"
if [ -z "$FILTER" ] || [[ "$BFW_CASES" == *"$FILTER"* ]]; then
  GG="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EG="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EG="$(cygpath -m "$EG")"
  # hunt2 A1: the Godot run's own exit status is read (PIPESTATUS); 0 or 1 is a run that completed (1: a case failed, its
  # line says which); anything else (124 timeout, 143 killed, a crash) is a stopped run and every case of it FAILs.
  bfw_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$GG" --headless --path "$EG" --script res://kernel/world/walks/bugfix_world_case.gd 2>&1 | tr -d '\015'; echo "HUNT2RC ${PIPESTATUS[0]}")"
  bfw_rc="$(echo "$bfw_out" | sed -n 's/^HUNT2RC //p' | tail -1)"
  for bc in $BFW_CASES; do
    bl="$(echo "$bfw_out" | grep -m1 "^BFWORLD $bc ")"
    why=""; [[ "$bl" == "BFWORLD $bc ok"* ]] || why="${bl:-no BFWORLD $bc line (the run stopped: $(echo "$bfw_out" | grep -m1 'SCRIPT ERROR' | cut -c1-120))}"
    if [ "$bfw_rc" != 0 ] && [ "$bfw_rc" != 1 ]; then why="the case run stopped (Godot exit ${bfw_rc:-unknown}) ${bl:+after: $bl}"; fi
    verdict "$bc" "$why" "${bl#BFWORLD $bc ok }"
  done
fi
