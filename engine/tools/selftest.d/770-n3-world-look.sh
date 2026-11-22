# N3 (night of 22-23 Nov 2026): what the owner saw in the World (Wren Valley), measured on the landscape that
# landscape.gd builds for boot/village.json, headless (kernel/world/home/n3_case.gd). The final marker is required.
#   n3.sight   the visitor's camera far plane reaches across the whole drawn valley (was 2000 m: hills cut at 2 km)
#   n3.tufts   the grass tufts appear and go by their own 32 m cell, not all at once 120 m from the village middle
#   n3.far_ground   a pack's far picture keeps its own ground where the mid picture has it (the 6 m grid moved it up to 2 m)
n3_cases=(n3.sight n3.tufts n3.far_ground)
if [ -z "$FILTER" ] || [[ "${n3_cases[*]}" == *"$FILTER"* ]]; then
  n3_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && n3_engine="$(cygpath -am "$n3_engine")"
  n3_log="$OUT/n3-world-look.log"
  n3_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 timeout 600 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$n3_engine" \
    --script res://kernel/world/home/n3_case.gd >"$n3_log" 2>&1 || n3_rc=$?
  for n3_case in "${n3_cases[@]}"; do
    n3_name="${n3_case#n3.}"
    n3_line="$(tr -d '\r' <"$n3_log" | grep -F "N3 $n3_name " | head -1)"
    why=""
    if [ "$n3_rc" != 0 ] && [ "$n3_rc" != 1 ] || ! grep -q '^N3 DONE' "$n3_log"; then
      why="stopped run (Godot exit $n3_rc), ${n3_line:-missing $n3_case}; see $n3_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$n3_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$n3_log")"
    elif [[ "$n3_line" != "N3 $n3_name ok "* ]]; then
      why="${n3_line:-missing N3 $n3_name verdict}"
    fi
    verdict "$n3_case" "$why" "${n3_line#N3 "$n3_name" ok }"
  done
fi
