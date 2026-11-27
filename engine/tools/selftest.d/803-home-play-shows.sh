# Lane F3 (27 Nov 2026): what play shows a newcomer of the Home's rules (kernel/world/build/play_case_shows.gd): the E
# prompt over a use zone (rules_play.gd `use_prompt`, play_hud.gd), a hazard's stripes and a door's frame
# (play_looks.gd), the coin counter's words and when it shows, the street lamp open from the start (unlocks.json).
# Headless, frames not wall clock; the final marker is required. Alone:
# `bash engine/tools/selftest.d/803-home-play-shows.sh` prints `HOME play-shows ok`.
home_play_shows_cases=(home.play-shows.prompt home.play-shows.looks home.play-shows.counters home.play-shows.lamps)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_play_shows_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_play_shows_cases[*]}" == *"$FILTER"* ]]; then
  home_play_shows_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_play_shows_engine="$(cygpath -am "$home_play_shows_engine")"
  home_play_shows_log="$OUT/home-play-shows.log"
  home_play_shows_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 6000 --path "$home_play_shows_engine" \
    --script res://kernel/world/build/play_case_shows.gd >"$home_play_shows_log" 2>&1 || home_play_shows_rc=$?
  for home_play_shows_case in "${home_play_shows_cases[@]}"; do
    home_play_shows_name="${home_play_shows_case#home.}"
    home_play_shows_line="$(tr -d '\r' <"$home_play_shows_log" | grep -F "HOME $home_play_shows_name " | head -1)"
    why=""
    if [ "$home_play_shows_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_play_shows_log"; then
      why="stopped run (Godot exit $home_play_shows_rc), ${home_play_shows_line:-missing $home_play_shows_case}; see $home_play_shows_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_play_shows_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_play_shows_log")"
    elif [[ "$home_play_shows_line" != "HOME $home_play_shows_name ok "* ]]; then
      why="${home_play_shows_line:-missing HOME $home_play_shows_name verdict}"
    fi
    verdict "$home_play_shows_case" "$why" "${home_play_shows_line#HOME "$home_play_shows_name" ok }"
  done
  if [ -n "${home_play_shows_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_play_shows_cases[@]}" ] && tr -d '\r' <"$home_play_shows_log" | grep -qx 'HOME play-shows ok'; then
      echo "HOME play-shows ok"
    else
      echo "HOME play-shows fail ($pass passed, $fail failed; see $home_play_shows_log)"
    fi
  fi
fi
