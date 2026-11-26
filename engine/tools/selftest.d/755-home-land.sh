# M2 (spark world-sandbox, 26 Nov 2026): land sculpt and paint in the Home (kernel/world/build/land_layer.gd and its
# land_*.gd, tools/sculpt_tool.gd, tools/paint_tool.gd). In the landscape of boot/village.json a headless case drives
# the tools as a person does (B, T, 1-4, 0-8, the pointer on the ground, LMB held for frames), then asks the layer:
# protected areas, one op per stroke with undo exact, paint and the eraser, the seam to the valley (worst gap), a walker
# on a raised hill, a block on it, scatter hidden and moved, the same ops -> the same mesh hashes, save -> load -> save
# byte-identical, and the cost (kernel/world/build/land_case.gd). Frames, not wall clock; the final marker is required.
# Runs on its own too: `bash engine/tools/selftest.d/755-home-land.sh` prints `HOME land ok` when it passes.
home_land_cases=(home.land.protect home.land.stroke home.land.paint home.land.seam home.land.collide home.land.block home.land.scatter home.land.hash home.land.files home.land.cost)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_land_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_land_cases[*]}" == *"$FILTER"* ]]; then
  home_land_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_land_engine="$(cygpath -am "$home_land_engine")"
  home_land_log="$OUT/home-land.log"
  home_land_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 6000 --path "$home_land_engine" \
    --script res://kernel/world/build/land_case.gd >"$home_land_log" 2>&1 || home_land_rc=$?
  for home_land_case in "${home_land_cases[@]}"; do
    home_land_name="${home_land_case#home.}"
    home_land_line="$(tr -d '\r' <"$home_land_log" | grep -F "HOME $home_land_name " | head -1)"
    why=""
    if [ "$home_land_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_land_log"; then
      why="stopped run (Godot exit $home_land_rc), ${home_land_line:-missing $home_land_case}; see $home_land_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_land_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_land_log")"
    elif [[ "$home_land_line" != "HOME $home_land_name ok "* ]]; then
      why="${home_land_line:-missing HOME $home_land_name verdict}"
    fi
    verdict "$home_land_case" "$why" "${home_land_line#HOME "$home_land_name" ok }"
  done
  if [ -n "${home_land_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_land_cases[@]}" ] && tr -d '\r' <"$home_land_log" | grep -qx 'HOME land ok'; then
      echo "HOME land ok"
    else
      echo "HOME land fail ($pass passed, $fail failed; see $home_land_log)"
    fi
  fi
fi
