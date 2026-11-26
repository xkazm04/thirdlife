# M3 (spark world-sandbox, 26 Nov 2026): unlocks from play (kernel/world/build/unlocks.gd, unlocks.json, trophies.gd,
# kernel/dungeon/dungeon.gd `close`). Headless: the shipped rules read clean and never lock M1's content; a scripted
# dungeon end (the paddle seed) writes trophies.json (plays, wins, best), a counted run writes nothing; rules met and
# unmet with their conditions; a locked part, material and stamp refuse in the tools (piece_unlock_case.gd). Frames, not
# wall clock; the final marker is required. Alone: `bash engine/tools/selftest.d/758-home-unlocks.sh` prints `HOME unlocks ok`.
home_unlocks_cases=(home.unlocks.rules home.unlocks.dungeon home.unlocks.met home.unlocks.tools)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_unlocks_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_unlocks_cases[*]}" == *"$FILTER"* ]]; then
  home_unlocks_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_unlocks_engine="$(cygpath -am "$home_unlocks_engine")"
  home_unlocks_log="$OUT/home-unlocks.log"
  home_unlocks_rc=0
  TL_HOME= TL_HOME_BUILD_DIR= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 2400 --path "$home_unlocks_engine" \
    --script res://kernel/world/build/piece_unlock_case.gd >"$home_unlocks_log" 2>&1 || home_unlocks_rc=$?
  for home_unlocks_case in "${home_unlocks_cases[@]}"; do
    home_unlocks_name="${home_unlocks_case#home.}"
    home_unlocks_line="$(tr -d '\r' <"$home_unlocks_log" | grep -F "HOME $home_unlocks_name " | head -1)"
    why=""
    if [ "$home_unlocks_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_unlocks_log"; then
      why="stopped run (Godot exit $home_unlocks_rc), ${home_unlocks_line:-missing $home_unlocks_case}; see $home_unlocks_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_unlocks_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_unlocks_log")"
    elif [[ "$home_unlocks_line" != "HOME $home_unlocks_name ok "* ]]; then
      why="${home_unlocks_line:-missing HOME $home_unlocks_name verdict}"
    fi
    verdict "$home_unlocks_case" "$why" "${home_unlocks_line#HOME "$home_unlocks_name" ok }"
  done
  if [ -n "${home_unlocks_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_unlocks_cases[@]}" ] && tr -d '\r' <"$home_unlocks_log" | grep -qx 'HOME unlocks ok'; then
      echo "HOME unlocks ok"
    else
      echo "HOME unlocks fail ($pass passed, $fail failed; see $home_unlocks_log)"
    fi
  fi
fi
