# M6 round 2, lane T (27 Nov 2026): courses travel (contracts/BUILD.md "Courses travel: tl.stamp/2 and the share code";
# kernel/world/build/stamp_file.gd, tools/stamp_tool.gd). Headless, no landscape: a box with no zones stays tl.stamp/1
# byte for byte; a course stamped as tl.stamp/2 (the zones wholly inside, the rules naming only them) round trips;
# placed at 4 rots its zone boxes turn with the blocks in one batch; placed into a Home with zones it takes the next
# free ids with every reference rewritten; the placed course still runs to its finish (rules_run.gd); the TL1- share
# code round trips and its refusals (prefix, cut short, alphabet, stream, JSON, unknown keys, a stray zone, too long);
# the stamp tool's Ctrl+C / Ctrl+V and placing (kernel/world/build/stamp_courses_case.gd). Frames, not wall clock; the
# final marker is required. Runs on its own too: prints `HOME stamp-courses ok` when it passes.
home_stamp_courses_cases=(home.stamp-courses.v1 home.stamp-courses.v2 home.stamp-courses.turns home.stamp-courses.renumber home.stamp-courses.run home.stamp-courses.code home.stamp-courses.refusals home.stamp-courses.tool)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_stamp_courses_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_stamp_courses_cases[*]}" == *"$FILTER"* ]]; then
  home_stamp_courses_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_stamp_courses_engine="$(cygpath -am "$home_stamp_courses_engine")"
  mkdir -p "$OUT"
  home_stamp_courses_log="$OUT/home-stamp-courses.log"
  home_stamp_courses_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$home_stamp_courses_engine" \
    --script res://kernel/world/build/stamp_courses_case.gd >"$home_stamp_courses_log" 2>&1 || home_stamp_courses_rc=$?
  for home_stamp_courses_case in "${home_stamp_courses_cases[@]}"; do
    home_stamp_courses_name="${home_stamp_courses_case#home.}"
    home_stamp_courses_line="$(tr -d '\r' <"$home_stamp_courses_log" | grep -F "HOME $home_stamp_courses_name " | head -1)"
    why=""
    if [ "$home_stamp_courses_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_stamp_courses_log"; then
      why="stopped run (Godot exit $home_stamp_courses_rc), ${home_stamp_courses_line:-missing $home_stamp_courses_case}; see $home_stamp_courses_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_stamp_courses_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_stamp_courses_log")"
    elif [[ "$home_stamp_courses_line" != "HOME $home_stamp_courses_name ok "* ]]; then
      why="${home_stamp_courses_line:-missing HOME $home_stamp_courses_name verdict}"
    fi
    verdict "$home_stamp_courses_case" "$why" "${home_stamp_courses_line#HOME "$home_stamp_courses_name" ok }"
  done
  if [ -n "${home_stamp_courses_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_stamp_courses_cases[@]}" ] && tr -d '\r' <"$home_stamp_courses_log" | grep -qx 'HOME stamp-courses ok'; then
      echo "HOME stamp-courses ok"
    else
      echo "HOME stamp-courses fail ($pass passed, $fail failed; see $home_stamp_courses_log)"
    fi
  fi
fi
