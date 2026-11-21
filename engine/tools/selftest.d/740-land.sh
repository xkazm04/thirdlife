# Compare both real village meshes and visitor spaces, then exercise records, streaming, heightfields and ledger.
# The final marker is required even when Godot exits cleanly at the physics-frame limit.
land_cases=(land.same_mesh land.seams land.colliders land.heightmap land.record land.rings land.ledger)
if [ -z "$FILTER" ] || [[ "${land_cases[*]}" == *"$FILTER"* ]]; then
  land_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && land_engine="$(cygpath -am "$land_engine")"
  land_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  land_log="$OUT/land-case.log"
  land_rc=0
  MSYS_NO_PATHCONV=1 TL_LAND_CASE= "$land_g" --headless --fixed-fps 60 --quit-after 1000 --path "$land_engine" \
    --script res://kernel/world/land/land_case.gd >"$land_log" 2>&1 || land_rc=$?
  for land_case in "${land_cases[@]}"; do
    land_line="$(tr -d '\r' <"$land_log" | grep -F "LAND $land_case " | head -1)"
    why=""
    if [ "$land_rc" != 0 ] || ! grep -q '^LAND DONE' "$land_log"; then
      why="stopped run (Godot exit $land_rc), ${land_line:-missing $land_case}"
    elif grep -q '^SCRIPT ERROR:' "$land_log"; then
      why="$(grep -m1 '^SCRIPT ERROR:' "$land_log")"
    elif [[ "$land_line" != "LAND $land_case ok "* ]]; then
      why="${land_line:-missing LAND $land_case verdict}"
    fi
    verdict "$land_case" "$why" "${land_line#LAND "$land_case" ok }"
  done
fi
