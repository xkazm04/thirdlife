# M6 lane P (27 Nov 2026): the Home's rules in the visit (kernel/world/build/rules_play.gd, play_facade.gd,
# play_doors.gd, play_looks.gd, play_hud.gd; block_mesh.gd's mask; visitor.gd launch / teleport_to). Headless, no
# landscape: a world space of its own, a real visitor steered as a person's keys steer it, build mode with its rules
# in play over the real facade. The mesher leaves an open zone's cells out of the mesh and the body (no mask: no
# change); a scripted walk start -> coin -> door (use) -> launch -> checkpoint -> lava -> out of the world -> finish
# -> restart with the HUD, the records and the E rule; the same walk twice gives the same facade calls; the looks;
# build mode mid-run (kernel/world/build/play_case.gd, play_case_course.gd). Frames, not wall clock; the final marker
# is required. Runs on its own too: `bash engine/tools/selftest.d/774-home-rules-play.sh` prints `HOME rules-play ok`.
home_rules_play_cases=(home.rules-play.mask home.rules-play.walk home.rules-play.same home.rules-play.looks home.rules-play.build)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_rules_play_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_rules_play_cases[*]}" == *"$FILTER"* ]]; then
  home_rules_play_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_rules_play_engine="$(cygpath -am "$home_rules_play_engine")"
  home_rules_play_log="$OUT/home-rules-play.log"
  home_rules_play_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 9000 --path "$home_rules_play_engine" \
    --script res://kernel/world/build/play_case.gd >"$home_rules_play_log" 2>&1 || home_rules_play_rc=$?
  for home_rules_play_case in "${home_rules_play_cases[@]}"; do
    home_rules_play_name="${home_rules_play_case#home.}"
    home_rules_play_line="$(tr -d '\r' <"$home_rules_play_log" | grep -F "HOME $home_rules_play_name " | head -1)"
    why=""
    if [ "$home_rules_play_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_rules_play_log"; then
      why="stopped run (Godot exit $home_rules_play_rc), ${home_rules_play_line:-missing $home_rules_play_case}; see $home_rules_play_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_rules_play_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_rules_play_log")"
    elif [[ "$home_rules_play_line" != "HOME $home_rules_play_name ok "* ]]; then
      why="${home_rules_play_line:-missing HOME $home_rules_play_name verdict}"
    fi
    verdict "$home_rules_play_case" "$why" "${home_rules_play_line#HOME "$home_rules_play_name" ok }"
  done
  if [ -n "${home_rules_play_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_rules_play_cases[@]}" ] && tr -d '\r' <"$home_rules_play_log" | grep -qx 'HOME rules-play ok'; then
      echo "HOME rules-play ok"
    else
      echo "HOME rules-play fail ($pass passed, $fail failed; see $home_rules_play_log)"
    fi
  fi
fi
