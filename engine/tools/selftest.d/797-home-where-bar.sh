# F2 (27 Nov 2026 day, the newcomer's playtest #3, #4, #7): building where you stand (kernel/world/build/hotbar.gd
# `at`, build_mode.gd `_click_bar`, buildable.gd, refusal_tint.gd, tools/stamp_tool.gd `_redden`). Headless, in the
# landscape of res://boot/village.json: a click on a tool tab or a slot picks it and never builds behind the bar (the
# ray there meets the ground in reach); a click in a gap of the bar does nothing; the text lines under the bar and the
# world still build; Sculpt in the village tints the refused cells, says why as a sentence and finds the way to
# buildable ground; a stamp on a game lot turns its ghost red and
# points to ground free of lots; a cursor past the reach says so (kernel/world/build/build_where_case.gd -- bar).
# Frames, not wall clock; the final marker is required. Runs on its own too:
# `bash engine/tools/selftest.d/797-home-where-bar.sh` prints `HOME where-bar ok` when it passes.
home_where_bar_cases=(home.where.tab home.where.slot home.where.village home.where.lot home.where.reach)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_where_bar_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_where_bar_cases[*]}" == *"$FILTER"* ]]; then
  home_where_bar_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_where_bar_engine="$(cygpath -am "$home_where_bar_engine")"
  home_where_bar_log="$OUT/home-where-bar.log"
  home_where_bar_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"     --headless --fixed-fps 60 --quit-after 12000 --path "$home_where_bar_engine"     --script res://kernel/world/build/build_where_case.gd -- bar >"$home_where_bar_log" 2>&1 || home_where_bar_rc=$?
  for home_where_bar_case in "${home_where_bar_cases[@]}"; do
    home_where_bar_name="${home_where_bar_case#home.}"
    home_where_bar_line="$(tr -d '\r' <"$home_where_bar_log" | grep -F "HOME $home_where_bar_name " | head -1)"
    why=""
    if [ "$home_where_bar_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_where_bar_log"; then
      why="stopped run (Godot exit $home_where_bar_rc), ${home_where_bar_line:-missing $home_where_bar_case}; see $home_where_bar_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_where_bar_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_where_bar_log")"
    elif [[ "$home_where_bar_line" != "HOME $home_where_bar_name ok "* ]]; then
      why="${home_where_bar_line:-missing HOME $home_where_bar_name verdict}"
    fi
    verdict "$home_where_bar_case" "$why" "${home_where_bar_line#HOME "$home_where_bar_name" ok }"
  done
  if [ -n "${home_where_bar_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_where_bar_cases[@]}" ] && tr -d '\r' <"$home_where_bar_log" | grep -qx 'HOME where ok'; then
      echo "HOME where-bar ok"
    else
      echo "HOME where-bar fail ($pass passed, $fail failed; see $home_where_bar_log)"
    fi
  fi
fi
