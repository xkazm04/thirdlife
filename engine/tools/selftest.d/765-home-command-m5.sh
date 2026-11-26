# M5 lane C (spark world-sandbox, 27 Nov 2026): the LLM command bar's M5 part (kernel/world/build/COMMAND.md "M5").
# In the landscape of boot/village.json a headless case (kernel/world/build/command_m5_case.gd) drives build mode as a
# person does, with a DRY Foreman door and the answer files a FAKE Foreman would write: an ask at the stream near the
# spawn carries the measured `water` (ground = the bed); the ask's tables list only what play has unlocked and gain
# mats 11/12 and the granted parts after trophies; an answer naming a locked part and material shows them refused
# "locked: <condition>" and Enter keeps the rest; an answer of land, paint, put, place, pour, path and plant ops shows a
# ghost node per layer that draws one and a counts note over every kind; the stamps tool's G opens the name field
# ("Stamp 1" selected), "My tower" is saved and the held Enter neither opens the command bar nor leaves build mode.
# No model is called. Frames, not wall clock; the final marker is required. Runs on its own too:
# `bash engine/tools/selftest.d/765-home-command-m5.sh` prints `HOME command-m5 ok` when it passes.
home_command_m5_cases=(home.command-m5.water home.command-m5.locked home.command-m5.ghosts home.command-m5.locks home.command-m5.stamp)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_command_m5_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_command_m5_cases[*]}" == *"$FILTER"* ]]; then
  home_cm5_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_cm5_engine="$(cygpath -am "$home_cm5_engine")"
  home_cm5_log="$OUT/home-command-m5.log"
  home_cm5_rc=0
  TL_HOME= TL_STYLE=crisp TL_COMMAND_DEVICES= MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$home_cm5_engine" \
    --script res://kernel/world/build/command_m5_case.gd >"$home_cm5_log" 2>&1 || home_cm5_rc=$?
  for home_cm5_case in "${home_command_m5_cases[@]}"; do
    home_cm5_name="${home_cm5_case#home.}"
    home_cm5_line="$(tr -d '\r' <"$home_cm5_log" | grep -F "HOME $home_cm5_name " | head -1)"
    why=""
    if [ "$home_cm5_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_cm5_log"; then
      why="stopped run (Godot exit $home_cm5_rc), ${home_cm5_line:-missing $home_cm5_case}; see $home_cm5_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_cm5_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_cm5_log")"
    elif [[ "$home_cm5_line" != "HOME $home_cm5_name ok "* ]]; then
      why="${home_cm5_line:-missing HOME $home_cm5_name verdict}"
    fi
    verdict "$home_cm5_case" "$why" "${home_cm5_line#HOME "$home_cm5_name" ok }"
  done
  if [ -n "${home_command_m5_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_command_m5_cases[@]}" ] && tr -d '\r' <"$home_cm5_log" | grep -qx 'HOME command-m5 ok'; then
      echo "HOME command-m5 ok"
    else
      echo "HOME command-m5 fail ($pass passed, $fail failed; see $home_cm5_log)"
    fi
  fi
fi
