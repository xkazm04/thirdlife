# M6 lane T (27 Nov 2026): the Rules hand tool in the Home's build mode (kernel/world/build/tools/rules_tool.gd,
# rules_tool_presets.gd, rules_tool_card.gd, zone_draw.gd, rules_layer.gd `preview_node`; contracts/BUILD.md
# "Milestone 6"). Headless, no landscape, through build mode's own input path: the 8 presets (start, checkpoint,
# finish, coin, door, jump pad, hazard, message) each ONE batch with its look and rules, one undo each, delete (the
# zone and the rules naming it, one batch), the name field and its guard (Enter / Esc neither open the command bar
# nor leave build mode), the side card's describe lines, the knobs (one batch each), preview_node (one node per
# changed zone, red removed, null when none), the zones drawn while building and hidden in play, the presets as placed played by rules_run.gd
# (kernel/world/build/rules_tool_case.gd). Frames, not wall clock; the final marker is required. Runs on its own too:
# `bash engine/tools/selftest.d/775-home-rules-tool.sh` prints `HOME rules-tool ok` when it passes.
home_rules_tool_cases=(home.rules-tool.presets home.rules-tool.undo home.rules-tool.delete home.rules-tool.field home.rules-tool.describe home.rules-tool.knobs home.rules-tool.ghost home.rules-tool.draw home.rules-tool.runs)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_rules_tool_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_rules_tool_cases[*]}" == *"$FILTER"* ]]; then
  home_rules_tool_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_rules_tool_engine="$(cygpath -am "$home_rules_tool_engine")"
  home_rules_tool_log="$OUT/home-rules-tool.log"
  home_rules_tool_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$home_rules_tool_engine" \
    --script res://kernel/world/build/rules_tool_case.gd >"$home_rules_tool_log" 2>&1 || home_rules_tool_rc=$?
  for home_rules_tool_case in "${home_rules_tool_cases[@]}"; do
    home_rules_tool_name="${home_rules_tool_case#home.}"
    home_rules_tool_line="$(tr -d '\r' <"$home_rules_tool_log" | grep -F "HOME $home_rules_tool_name " | head -1)"
    why=""
    if [ "$home_rules_tool_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_rules_tool_log"; then
      why="stopped run (Godot exit $home_rules_tool_rc), ${home_rules_tool_line:-missing $home_rules_tool_case}; see $home_rules_tool_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_rules_tool_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_rules_tool_log")"
    elif [[ "$home_rules_tool_line" != "HOME $home_rules_tool_name ok "* ]]; then
      why="${home_rules_tool_line:-missing HOME $home_rules_tool_name verdict}"
    fi
    verdict "$home_rules_tool_case" "$why" "${home_rules_tool_line#HOME "$home_rules_tool_name" ok }"
  done
  if [ -n "${home_rules_tool_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_rules_tool_cases[@]}" ] && tr -d '\r' <"$home_rules_tool_log" | grep -qx 'HOME rules-tool ok'; then
      echo "HOME rules-tool ok"
    else
      echo "HOME rules-tool fail ($pass passed, $fail failed; see $home_rules_tool_log)"
    fi
  fi
fi
