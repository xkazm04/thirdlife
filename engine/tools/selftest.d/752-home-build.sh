# WP1 (spark world-sandbox, 26 Nov 2026): the Home's block core (kernel/world/build/). In the landscape of
# boot/village.json (the Home grown by home/hook.gd) the case joins and hides faces, places 20,000 blocks over 4 chunks,
# meshes and collides them, undoes and redoes them, saves and loads them byte for byte, refuses protected cells and walks
# the visitor up a placed stair into a wall (kernel/world/build/build_case.gd). Frames, not wall clock; the final marker is
# required. Runs on its own too: `bash engine/tools/selftest.d/752-home-build.sh` prints `HOME build ok` when it passes.
home_build_cases=(home.build.forms home.build.glass home.build.bulk home.build.same home.build.undo home.build.files home.build.refuse home.build.walk)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_build_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_build_cases[*]}" == *"$FILTER"* ]]; then
  home_build_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_build_engine="$(cygpath -am "$home_build_engine")"
  home_build_log="$OUT/home-build.log"
  home_build_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$home_build_engine" \
    --script res://kernel/world/build/build_case.gd >"$home_build_log" 2>&1 || home_build_rc=$?
  for home_build_case in "${home_build_cases[@]}"; do
    home_build_name="${home_build_case#home.}"
    home_build_line="$(tr -d '\r' <"$home_build_log" | grep -F "HOME $home_build_name " | head -1)"
    why=""
    if [ "$home_build_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_build_log"; then
      why="stopped run (Godot exit $home_build_rc), ${home_build_line:-missing $home_build_case}; see $home_build_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_build_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_build_log")"
    elif [[ "$home_build_line" != "HOME $home_build_name ok "* ]]; then
      why="${home_build_line:-missing HOME $home_build_name verdict}"
    fi
    verdict "$home_build_case" "$why" "${home_build_line#HOME "$home_build_name" ok }"
  done
  if [ -n "${home_build_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_build_cases[@]}" ] && tr -d '\r' <"$home_build_log" | grep -qx 'HOME build ok'; then
      echo "HOME build ok"
    else
      echo "HOME build fail ($pass passed, $fail failed; see $home_build_log)"
    fi
  fi
fi
