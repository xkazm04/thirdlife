# Lane DN (day of 27 Nov 2026): day and night in the Home (kernel/world/home/day_case.gd, two headless runs: TLStyle
# headless as every headless run, and TLStyle drawing on the dummy renderer so the kit builds its lights). The clock in
# frames, N and H in build mode, the tl.home-settings/1 file, the cycle off until a folder is opened and off headless,
# the noon look and globals byte for byte the style's own, the timeline, the lamps' sockets, the 48-light cap (nearest
# the camera), the choice following the camera, lamps one by one at dusk, lifted lamps gone. The final marker is required.
# Runs on its own too: `bash engine/tools/selftest.d/776-home-daynight.sh` prints `HOME daynight ok` when it passes.
home_dn_cases=(home.daynight.off_headless home.daynight.off home.daynight.clock home.daynight.keys home.daynight.settings
  home.daynight.stage home.daynight.noon home.daynight.timeline home.daynight.sockets home.daynight.cap home.daynight.follow home.daynight.dusk
  home.daynight.lift home.daynight.cost)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_dn_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_dn_cases[*]}" == *"$FILTER"* ]]; then
  home_dn_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_dn_engine="$(cygpath -am "$home_dn_engine")"
  home_dn_rc_headless=0; home_dn_rc_look=0
  for home_dn_mode in headless look; do
    home_dn_rc=0
    TL_HOME= TL_HOME_BUILD_DIR= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
      --headless --fixed-fps 60 --quit-after 9000 --path "$home_dn_engine" \
      --script res://kernel/world/home/day_case.gd -- "--mode=$home_dn_mode" >"$OUT/home-daynight-$home_dn_mode.log" 2>&1 || home_dn_rc=$?
    eval "home_dn_rc_$home_dn_mode=$home_dn_rc"
  done
  for home_dn_case in "${home_dn_cases[@]}"; do
    home_dn_name="${home_dn_case#home.}"
    home_dn_mode=look; [ "$home_dn_name" = "daynight.off_headless" ] && home_dn_mode=headless
    home_dn_log="$OUT/home-daynight-$home_dn_mode.log"
    home_dn_rc="home_dn_rc_$home_dn_mode"; home_dn_rc="${!home_dn_rc}"
    home_dn_line="$(tr -d '\r' <"$home_dn_log" | grep -F "HOME $home_dn_name " | head -1)"
    why=""
    if [ "$home_dn_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_dn_log"; then
      why="stopped run (Godot exit $home_dn_rc), ${home_dn_line:-missing $home_dn_case}; see $home_dn_log"
    elif grep -qE '^SCRIPT ERROR' "$home_dn_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR' "$home_dn_log")"
    elif [[ "$home_dn_line" != "HOME $home_dn_name ok "* ]]; then
      why="${home_dn_line:-missing HOME $home_dn_name verdict}"
    fi
    verdict "$home_dn_case" "$why" "${home_dn_line#HOME "$home_dn_name" ok }"
  done
  if [ -n "${home_dn_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_dn_cases[@]}" ] && tr -d '\r' <"$OUT/home-daynight-headless.log" | grep -qx 'HOME daynight headless ok' \
       && tr -d '\r' <"$OUT/home-daynight-look.log" | grep -qx 'HOME daynight look ok'; then
      echo "HOME daynight ok"
    else
      echo "HOME daynight fail ($pass passed, $fail failed; see $OUT/home-daynight-*.log)"
    fi
  fi
fi
