# Drive the visitor across banks, a ledge and a slide in the headless walk cases.
# Check each movement and camera verdict separately.

# --- walker-feel (lane M, 18 Nov 2026) ---
# The visitor's body with weight (terrain/world_space.gd `drive()`) and the chase camera's `avoid_space`, on ground
# built for each case, headless (kernel/world/walks/walk_case.gd): idle on a bank, jump, ledge, steep bank, pace, run
# slide, the camera along a hill. One verdict per case; a case missing from the output is a FAIL.
if [ -z "$FILTER" ] || [[ "walk.idle_bank walk.jump walk.ledge walk.steep walk.pace walk.slide walk.camera walk.canopy walk.biped_parity" == *"$FILTER"* ]]; then
  GW="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EW="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EW="$(cygpath -m "$EW")"
  wout="$(MSYS_NO_PATHCONV=1 "$GW" --headless --path "$EW" --script res://kernel/world/walks/walk_case.gd 2>&1 | tr -d '\015' | grep '^WALKCASE')"
  for wc in walk.idle_bank walk.jump walk.ledge walk.steep walk.pace walk.slide walk.camera walk.canopy walk.biped_parity; do
    if [ -n "$FILTER" ] && [[ "$wc" != *"$FILTER"* ]]; then continue; fi
    wl="$(echo "$wout" | grep "^WALKCASE $wc ")"
    why=""; [[ "$wl" == "WALKCASE $wc ok "* ]] || why="${wl:-no WALKCASE line for $wc}"
    verdict "$wc" "$why" "${wl#WALKCASE $wc ok }"
  done
fi

