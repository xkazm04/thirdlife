# M6 round 2, lane P (27 Nov 2026): the best run's ghost (kernel/world/build/play_ghost.gd; contracts/BUILD.md "The
# best run's ghost"). Headless, no landscape: a straight track (Start pad, Flag 8 m on) in a world space of its own, a
# real visitor steered as keys steer it, build mode with its rules in play. The first finish writes runs/dash.json
# (tl.run-ghost/1: round trip byte for byte, sample 0 = his feet at frame 0); a slower finish keeps it, a faster one
# replaces it; on a restart the ghost stands on the kept track at every frame and goes at its end; G hides and shows
# it; unknown keys, a short track, a wrong schema are refused (no ghost); a Home with no file has no ghost
# (kernel/world/build/play_ghost_case.gd). Frames, not wall clock; the final marker is required. Runs on its own too:
# `bash engine/tools/selftest.d/791-home-run-ghost.sh` prints `HOME run-ghost ok` when it passes.
home_run_ghost_cases=(home.run-ghost.written home.run-ghost.kept home.run-ghost.follows home.run-ghost.key home.run-ghost.refused home.run-ghost.none)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_run_ghost_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_run_ghost_cases[*]}" == *"$FILTER"* ]]; then
  home_run_ghost_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_run_ghost_engine="$(cygpath -am "$home_run_ghost_engine")"
  home_run_ghost_log="$OUT/home-run-ghost.log"
  home_run_ghost_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 9000 --path "$home_run_ghost_engine" \
    --script res://kernel/world/build/play_ghost_case.gd >"$home_run_ghost_log" 2>&1 || home_run_ghost_rc=$?
  for home_run_ghost_case in "${home_run_ghost_cases[@]}"; do
    home_run_ghost_name="${home_run_ghost_case#home.}"
    home_run_ghost_line="$(tr -d '\r' <"$home_run_ghost_log" | grep -F "HOME $home_run_ghost_name " | head -1)"
    why=""
    if [ "$home_run_ghost_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_run_ghost_log"; then
      why="stopped run (Godot exit $home_run_ghost_rc), ${home_run_ghost_line:-missing $home_run_ghost_case}; see $home_run_ghost_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_run_ghost_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_run_ghost_log")"
    elif [[ "$home_run_ghost_line" != "HOME $home_run_ghost_name ok "* ]]; then
      why="${home_run_ghost_line:-missing HOME $home_run_ghost_name verdict}"
    fi
    verdict "$home_run_ghost_case" "$why" "${home_run_ghost_line#HOME "$home_run_ghost_name" ok }"
  done
  if [ -n "${home_run_ghost_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_run_ghost_cases[@]}" ] && tr -d '\r' <"$home_run_ghost_log" | grep -qx 'HOME run-ghost ok'; then
      echo "HOME run-ghost ok"
    else
      echo "HOME run-ghost fail ($pass passed, $fail failed; see $home_run_ghost_log)"
    fi
  fi
fi
