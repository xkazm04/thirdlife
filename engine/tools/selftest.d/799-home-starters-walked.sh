# Lane F3 (27 Nov 2026): the three starter courses played by the real walker (kernel/world/build/play_case_starters.gd):
# each stamp placed on natural ground (the stamp tool's curb), a real visitor steered at a walk from the grass, the
# rules in play over the real facade. Pad hop at a walk, at a run and with W let go in the air; Tower climb at three
# jump leads; Garden gate through its gate on E (the prompt shown) with its three coins; every floor walked onto from
# grass at four heights. Headless, frames not wall clock; the final marker is required. Alone:
# `bash engine/tools/selftest.d/799-home-starters-walked.sh` prints `HOME starters-walked ok`.
home_starters_walked_cases=(home.starters-walked.pad home.starters-walked.padrun home.starters-walked.padlet home.starters-walked.tower home.starters-walked.garden home.starters-walked.ground)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_starters_walked_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_starters_walked_cases[*]}" == *"$FILTER"* ]]; then
  home_starters_walked_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_starters_walked_engine="$(cygpath -am "$home_starters_walked_engine")"
  home_starters_walked_log="$OUT/home-starters-walked.log"
  home_starters_walked_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 30000 --path "$home_starters_walked_engine" \
    --script res://kernel/world/build/play_case_starters.gd >"$home_starters_walked_log" 2>&1 || home_starters_walked_rc=$?
  for home_starters_walked_case in "${home_starters_walked_cases[@]}"; do
    home_starters_walked_name="${home_starters_walked_case#home.}"
    home_starters_walked_line="$(tr -d '\r' <"$home_starters_walked_log" | grep -F "HOME $home_starters_walked_name " | head -1)"
    why=""
    if [ "$home_starters_walked_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_starters_walked_log"; then
      why="stopped run (Godot exit $home_starters_walked_rc), ${home_starters_walked_line:-missing $home_starters_walked_case}; see $home_starters_walked_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_starters_walked_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_starters_walked_log")"
    elif [[ "$home_starters_walked_line" != "HOME $home_starters_walked_name ok "* ]]; then
      why="${home_starters_walked_line:-missing HOME $home_starters_walked_name verdict}"
    fi
    verdict "$home_starters_walked_case" "$why" "${home_starters_walked_line#HOME "$home_starters_walked_name" ok }"
  done
  if [ -n "${home_starters_walked_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_starters_walked_cases[@]}" ] && tr -d '\r' <"$home_starters_walked_log" | grep -qx 'HOME starters-walked ok'; then
      echo "HOME starters-walked ok"
    else
      echo "HOME starters-walked fail ($pass passed, $fail failed; see $home_starters_walked_log)"
    fi
  fi
fi
