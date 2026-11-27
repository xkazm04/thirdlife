# Lane LP (27 Nov 2026, the Home look polished): what the polished looks hand the shaders (kernel/world/build/
# look_case.gd, headless, the landscape of boot/village.json): planted growth reaches the cel shader as its own kind
# (meadow, flowers, tall grass), a stone path carries its own coordinates in UV2 and draws the dirt path's earth field
# with a round end, and a poured pond's mesh carries a bank depth whose waterline runs in short segments inside the land.
# Frames, not wall clock; the final marker is required.
# Runs on its own too: `bash engine/tools/selftest.d/768-home-look2.sh` prints `HOME look2 ok` when it passes.
home_look2_cases=(home.look2.growth home.look2.stone home.look2.shore)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_look2_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_look2_cases[*]}" == *"$FILTER"* ]]; then
  home_look2_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_look2_engine="$(cygpath -am "$home_look2_engine")"
  home_look2_log="$OUT/home-look2.log"
  home_look2_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 6000 --path "$home_look2_engine" \
    --script res://kernel/world/build/look_case.gd >"$home_look2_log" 2>&1 || home_look2_rc=$?
  for home_look2_case in "${home_look2_cases[@]}"; do
    home_look2_name="${home_look2_case#home.}"
    home_look2_line="$(tr -d '\r' <"$home_look2_log" | grep -F "HOME $home_look2_name " | head -1)"
    why=""
    if [ "$home_look2_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_look2_log"; then
      why="stopped run (Godot exit $home_look2_rc), ${home_look2_line:-missing $home_look2_case}; see $home_look2_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_look2_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_look2_log")"
    elif [[ "$home_look2_line" != "HOME $home_look2_name ok "* ]]; then
      why="${home_look2_line:-missing HOME $home_look2_name verdict}"
    fi
    verdict "$home_look2_case" "$why" "${home_look2_line#HOME "$home_look2_name" ok }"
  done
  if [ -n "${home_look2_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_look2_cases[@]}" ] && tr -d '\r' <"$home_look2_log" | grep -qx 'HOME look2 ok'; then
      echo "HOME look2 ok"
    else
      echo "HOME look2 fail ($pass passed, $fail failed; see $home_look2_log)"
    fi
  fi
fi
