# M5 lane L (spark world-sandbox, 27 Nov 2026): the land look in the Home (kernel/world/build/land_look_case.gd, headless,
# the landscape of boot/village.json, the tools driven as a person does): a raise stroke is a cosine bell (no plateau),
# a flattened terrace's steep side carries the rock code, one painted cell's weights are the (1, 3, 3, 1)^2 / 64 blur,
# lowering under the river's water ribbon is refused beyond the 71 m band, the land layer draws its ghost of a dry run,
# and what a whole edited chunk's mesh costs. Frames, not wall clock; the final marker is required.
# Runs on its own too: `bash engine/tools/selftest.d/764-home-look.sh` prints `HOME look ok` when it passes.
home_look_cases=(home.look.bell home.look.terrace home.look.paint home.look.river home.look.ghost home.look.cost)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_look_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_look_cases[*]}" == *"$FILTER"* ]]; then
  home_look_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_look_engine="$(cygpath -am "$home_look_engine")"
  home_look_log="$OUT/home-look.log"
  home_look_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 6000 --path "$home_look_engine" \
    --script res://kernel/world/build/land_look_case.gd >"$home_look_log" 2>&1 || home_look_rc=$?
  for home_look_case in "${home_look_cases[@]}"; do
    home_look_name="${home_look_case#home.}"
    home_look_line="$(tr -d '\r' <"$home_look_log" | grep -F "HOME $home_look_name " | head -1)"
    why=""
    if [ "$home_look_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_look_log"; then
      why="stopped run (Godot exit $home_look_rc), ${home_look_line:-missing $home_look_case}; see $home_look_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_look_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_look_log")"
    elif [[ "$home_look_line" != "HOME $home_look_name ok "* ]]; then
      why="${home_look_line:-missing HOME $home_look_name verdict}"
    fi
    verdict "$home_look_case" "$why" "${home_look_line#HOME "$home_look_name" ok }"
  done
  if [ -n "${home_look_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_look_cases[@]}" ] && tr -d '\r' <"$home_look_log" | grep -qx 'HOME look ok'; then
      echo "HOME look ok"
    else
      echo "HOME look fail ($pass passed, $fail failed; see $home_look_log)"
    fi
  fi
fi
