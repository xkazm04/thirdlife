# M6 round 3, lane T (27 Nov 2026): the starter courses shipped with the game (kernel/world/build/starters/*.json,
# made by stamp_starters_make.gd; listed first in the stamp tool) and a placed course's run name (contracts/BUILD.md
# "Courses travel": the field prefilled "<name> (2)", Enter renames, Esc shares). Headless, no landscape: the files
# (valid tl.stamp/2, under 4,000 blocks, materials 1-9), the tool's Starters page, each starter placed and finished by
# a scripted feet path (rules_run.gd), the run-name field and its guard (kernel/world/build/stamp_starters_case.gd).
# Frames, not wall clock; the final marker is required. Runs on its own too: prints `HOME stamp-starters ok`.
home_stamp_starters_cases=(home.stamp-starters.files home.stamp-starters.tool home.stamp-starters.runs home.stamp-starters.runname)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_stamp_starters_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_stamp_starters_cases[*]}" == *"$FILTER"* ]]; then
  home_stamp_starters_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_stamp_starters_engine="$(cygpath -am "$home_stamp_starters_engine")"
  mkdir -p "$OUT"
  home_stamp_starters_log="$OUT/home-stamp-starters.log"
  home_stamp_starters_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$home_stamp_starters_engine" \
    --script res://kernel/world/build/stamp_starters_case.gd >"$home_stamp_starters_log" 2>&1 || home_stamp_starters_rc=$?
  for home_stamp_starters_case in "${home_stamp_starters_cases[@]}"; do
    home_stamp_starters_name="${home_stamp_starters_case#home.}"
    home_stamp_starters_line="$(tr -d '\r' <"$home_stamp_starters_log" | grep -F "HOME $home_stamp_starters_name " | head -1)"
    why=""
    if [ "$home_stamp_starters_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_stamp_starters_log"; then
      why="stopped run (Godot exit $home_stamp_starters_rc), ${home_stamp_starters_line:-missing $home_stamp_starters_case}; see $home_stamp_starters_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_stamp_starters_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_stamp_starters_log")"
    elif [[ "$home_stamp_starters_line" != "HOME $home_stamp_starters_name ok "* ]]; then
      why="${home_stamp_starters_line:-missing HOME $home_stamp_starters_name verdict}"
    fi
    verdict "$home_stamp_starters_case" "$why" "${home_stamp_starters_line#HOME "$home_stamp_starters_name" ok }"
  done
  if [ -n "${home_stamp_starters_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_stamp_starters_cases[@]}" ] && tr -d '\r' <"$home_stamp_starters_log" | grep -qx 'HOME stamp-starters ok'; then
      echo "HOME stamp-starters ok"
    else
      echo "HOME stamp-starters fail ($pass passed, $fail failed; see $home_stamp_starters_log)"
    fi
  fi
fi
