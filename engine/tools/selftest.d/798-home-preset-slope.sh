# F2 (27 Nov 2026 day, the newcomer's playtest #6): Rules presets placed on natural ground fire for a person standing
# on it (kernel/world/build/rules_tool_presets.gd `fit_ground`, tools/rules_tool.gd `stand_at`). Headless, in the
# landscape of res://boot/village.json: a Door on a wall whose blocks stand a cell over the feet in front (the
# playtest's course), and a Jump pad clicked on ground just under a whole metre: the preset's box holds the feet cell
# (rules_run.gd `feet_cell`) at every point of the columns a person stands in (the box as drawn before held none), E
# opens the door and walking on launches; a Checkpoint on the wall's top keeps the box as drawn
# (kernel/world/build/build_where_case.gd -- slope). Frames, not wall clock; the final marker is required. Runs on its
# own too: `bash engine/tools/selftest.d/798-home-preset-slope.sh` prints `HOME preset-slope ok` when it passes.
home_preset_slope_cases=(home.slope.door home.slope.pad)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_preset_slope_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_preset_slope_cases[*]}" == *"$FILTER"* ]]; then
  home_preset_slope_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_preset_slope_engine="$(cygpath -am "$home_preset_slope_engine")"
  home_preset_slope_log="$OUT/home-preset-slope.log"
  home_preset_slope_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"     --headless --fixed-fps 60 --quit-after 12000 --path "$home_preset_slope_engine"     --script res://kernel/world/build/build_where_case.gd -- slope >"$home_preset_slope_log" 2>&1 || home_preset_slope_rc=$?
  for home_preset_slope_case in "${home_preset_slope_cases[@]}"; do
    home_preset_slope_name="${home_preset_slope_case#home.}"
    home_preset_slope_line="$(tr -d '\r' <"$home_preset_slope_log" | grep -F "HOME $home_preset_slope_name " | head -1)"
    why=""
    if [ "$home_preset_slope_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_preset_slope_log"; then
      why="stopped run (Godot exit $home_preset_slope_rc), ${home_preset_slope_line:-missing $home_preset_slope_case}; see $home_preset_slope_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_preset_slope_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_preset_slope_log")"
    elif [[ "$home_preset_slope_line" != "HOME $home_preset_slope_name ok "* ]]; then
      why="${home_preset_slope_line:-missing HOME $home_preset_slope_name verdict}"
    fi
    verdict "$home_preset_slope_case" "$why" "${home_preset_slope_line#HOME "$home_preset_slope_name" ok }"
  done
  if [ -n "${home_preset_slope_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_preset_slope_cases[@]}" ] && tr -d '\r' <"$home_preset_slope_log" | grep -qx 'HOME where ok'; then
      echo "HOME preset-slope ok"
    else
      echo "HOME preset-slope fail ($pass passed, $fail failed; see $home_preset_slope_log)"
    fi
  fi
fi
