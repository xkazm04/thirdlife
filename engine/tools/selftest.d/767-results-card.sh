# Lane K (spark world-sandbox M5, 27 Nov 2026): the results card after a dungeon. Headless, frames only: the paddle seed
# played as a person plays it (frames 0, the Home's trophies in a temporary TL_HOME_BUILD_DIR) and left; boot/hub.gd
# `_on_dungeon_left` (a stand-in boot node) shows kernel/dungeon/results_card.gd instead of the menu: plays, wins, best and
# what THIS end newly unlocked (unlocks.json); a second identical end shows no "Unlocked" line; a key or a click after
# the card's hold frames closes it to the menu; a counted run records nothing and shows no card
# (kernel/dungeon/results_card_case.gd). The final marker is required. Runs on its own too:
# `bash engine/tools/selftest.d/767-results-card.sh` prints `HOME results-card ok`.
home_results_card_cases=(home.results-card.win home.results-card.again home.results-card.third home.results-card.none)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_results_card_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_results_card_cases[*]}" == *"$FILTER"* ]]; then
  home_results_card_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_results_card_engine="$(cygpath -am "$home_results_card_engine")"
  home_results_card_log="$OUT/home-results-card.log"
  home_results_card_rc=0
  TL_HOME= TL_HOME_BUILD_DIR= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$home_results_card_engine" \
    --script res://kernel/dungeon/results_card_case.gd >"$home_results_card_log" 2>&1 || home_results_card_rc=$?
  for home_results_card_case in "${home_results_card_cases[@]}"; do
    home_results_card_name="${home_results_card_case#home.results-card.}"
    home_results_card_line="$(tr -d '\r' <"$home_results_card_log" | grep -F "RESULTS $home_results_card_name " | head -1)"
    why=""
    if [ "$home_results_card_rc" != 0 ] && ! grep -q '^RESULTS DONE' "$home_results_card_log"; then
      why="stopped run (Godot exit $home_results_card_rc), ${home_results_card_line:-missing $home_results_card_case}; see $home_results_card_log"
    elif ! grep -q '^RESULTS DONE' "$home_results_card_log"; then
      why="stopped run (no RESULTS DONE); see $home_results_card_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_results_card_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_results_card_log")"
    elif [[ "$home_results_card_line" != "RESULTS $home_results_card_name ok "* ]]; then
      why="${home_results_card_line:-missing RESULTS $home_results_card_name verdict}"
    fi
    verdict "$home_results_card_case" "$why" "${home_results_card_line#RESULTS "$home_results_card_name" ok }"
  done
  if [ -n "${home_results_card_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_results_card_cases[@]}" ] && tr -d '\r' <"$home_results_card_log" | grep -qx 'RESULTS ok'; then
      echo "HOME results-card ok"
    else
      echo "HOME results-card fail ($pass passed, $fail failed; see $home_results_card_log)"
    fi
  fi
fi
