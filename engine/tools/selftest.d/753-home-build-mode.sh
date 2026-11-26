# WP2 (spark world-sandbox, 26 Nov 2026): build mode in the Home (kernel/world/build/build_mode.gd, mounted by
# home/hook.gd). In the landscape of boot/village.json a headless case pushes input events as a person makes them (B,
# the wheel, 1-8, Tab, R, mouse motion, LMB clicks and a drag, Ctrl+Z, RMB), aims at a game lot (refused, the hotbar
# names it), leaves build mode (build.json saved), autosaves, then loads the save into a fresh landscape
# (kernel/world/build/build_mode_case.gd). Frames, not wall clock; the final marker is required. Runs on its own too:
# `bash engine/tools/selftest.d/753-home-build-mode.sh` prints `HOME build-mode ok` when it passes.
home_mode_cases=(home.mode.keys home.mode.place home.mode.refuse home.mode.save home.mode.load)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_mode_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_mode_cases[*]}" == *"$FILTER"* ]]; then
  home_mode_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_mode_engine="$(cygpath -am "$home_mode_engine")"
  home_mode_log="$OUT/home-build-mode.log"
  home_mode_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$home_mode_engine" \
    --script res://kernel/world/build/build_mode_case.gd >"$home_mode_log" 2>&1 || home_mode_rc=$?
  for home_mode_case in "${home_mode_cases[@]}"; do
    home_mode_name="${home_mode_case#home.}"
    home_mode_line="$(tr -d '\r' <"$home_mode_log" | grep -F "HOME $home_mode_name " | head -1)"
    why=""
    if [ "$home_mode_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_mode_log"; then
      why="stopped run (Godot exit $home_mode_rc), ${home_mode_line:-missing $home_mode_case}; see $home_mode_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_mode_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_mode_log")"
    elif [[ "$home_mode_line" != "HOME $home_mode_name ok "* ]]; then
      why="${home_mode_line:-missing HOME $home_mode_name verdict}"
    fi
    verdict "$home_mode_case" "$why" "${home_mode_line#HOME "$home_mode_name" ok }"
  done
  if [ -n "${home_mode_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_mode_cases[@]}" ] && tr -d '\r' <"$home_mode_log" | grep -qx 'HOME build-mode ok'; then
      echo "HOME build-mode ok"
    else
      echo "HOME build-mode fail ($pass passed, $fail failed; see $home_mode_log)"
    fi
  fi
fi
