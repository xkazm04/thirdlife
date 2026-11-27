# M5 lane W (spark world-sandbox, 27 Nov 2026): still water in the Home (kernel/world/build/water_layer.gd and its
# water_*.gd, tools/water_tool.gd). On flat ground a headless case holds the pour's fill to hand computations (a dug
# hollow fills to 10 cm under its spill, a notch lowers it, an open slope and a 3,000-cell bowl are refused), undo,
# drain, tl.build/3 save -> load -> save byte-identical with the journal replayed, `pour` through expand_input,
# water_runs and the ghost; in the landscape of boot/village.json the river and the protected areas refuse, the water
# tool is driven as a person drives it (B, T, the pointer, the wheel, LMB, Ctrl+Z, 2), the surface is drawn in the
# still-water look with no body, and a valley tree under the water is hidden and back (kernel/world/build/water_case.gd).
# Frames, not wall clock; the final marker is required.
# Runs on its own too: `bash engine/tools/selftest.d/761-home-water.sh` prints `HOME water ok` when it passes.
home_water_cases=(home.water.hollow home.water.notch home.water.refuse home.water.undo home.water.files home.water.input home.water.river home.water.tool home.water.scatter home.water.cost)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_water_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_water_cases[*]}" == *"$FILTER"* ]]; then
  home_water_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_water_engine="$(cygpath -am "$home_water_engine")"
  home_water_log="$OUT/home-water.log"
  home_water_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 6000 --path "$home_water_engine" \
    --script res://kernel/world/build/water_case.gd >"$home_water_log" 2>&1 || home_water_rc=$?
  for home_water_case in "${home_water_cases[@]}"; do
    home_water_name="${home_water_case#home.}"
    home_water_line="$(tr -d '\r' <"$home_water_log" | grep -F "HOME $home_water_name " | head -1)"
    why=""
    if [ "$home_water_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_water_log"; then
      why="stopped run (Godot exit $home_water_rc), ${home_water_line:-missing $home_water_case}; see $home_water_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_water_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_water_log")"
    elif [[ "$home_water_line" != "HOME $home_water_name ok "* ]]; then
      why="${home_water_line:-missing HOME $home_water_name verdict}"
    fi
    verdict "$home_water_case" "$why" "${home_water_line#HOME "$home_water_name" ok }"
  done
  if [ -n "${home_water_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_water_cases[@]}" ] && tr -d '\r' <"$home_water_log" | grep -qx 'HOME water ok'; then
      echo "HOME water ok"
    else
      echo "HOME water fail ($pass passed, $fail failed; see $home_water_log)"
    fi
  fi
fi
