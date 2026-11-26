# M4 (spark world-sandbox, 26 Nov 2026): the LLM command bar in the Home's build mode
# (kernel/world/build/tools/command_tool.gd, COMMAND.md). In the landscape of boot/village.json a headless case drives
# it as a person does (B, Enter, the sentence typed into the field, Enter, Esc, Ctrl+Z) with a DRY Foreman door (it
# records `world-edit --in <ask> --out <answer>` and starts nothing) and answer files the case writes: the bar takes the
# keyboard (the visitor's input sees no W), the ask is written, a pending marker thinks, the answer is a ghost that
# touches nothing, Enter keeps it as one batch by "llm" that one Ctrl+Z takes back, Esc reverts, two asks may wait, the
# 31st call of a day is refused, and a missing Foreman is named (kernel/world/build/command_case.gd). No model is
# called. Frames, not wall clock; the final marker is required. Runs on its own too:
# `bash engine/tools/selftest.d/757-home-command.sh` prints `HOME command ok` when it passes.
home_cmd_cases=(home.command.open home.command.typing home.command.ask home.command.ghost home.command.accept home.command.revert home.command.pending home.command.cap home.command.offline)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_cmd_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_cmd_cases[*]}" == *"$FILTER"* ]]; then
  home_cmd_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_cmd_engine="$(cygpath -am "$home_cmd_engine")"
  home_cmd_log="$OUT/home-command.log"
  home_cmd_rc=0
  TL_HOME= TL_STYLE=crisp TL_COMMAND_DEVICES= MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$home_cmd_engine" \
    --script res://kernel/world/build/command_case.gd >"$home_cmd_log" 2>&1 || home_cmd_rc=$?
  for home_cmd_case in "${home_cmd_cases[@]}"; do
    home_cmd_name="${home_cmd_case#home.}"
    home_cmd_line="$(tr -d '\r' <"$home_cmd_log" | grep -F "HOME $home_cmd_name " | head -1)"
    why=""
    if [ "$home_cmd_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_cmd_log"; then
      why="stopped run (Godot exit $home_cmd_rc), ${home_cmd_line:-missing $home_cmd_case}; see $home_cmd_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_cmd_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_cmd_log")"
    elif [[ "$home_cmd_line" != "HOME $home_cmd_name ok "* ]]; then
      why="${home_cmd_line:-missing HOME $home_cmd_name verdict}"
    fi
    verdict "$home_cmd_case" "$why" "${home_cmd_line#HOME "$home_cmd_name" ok }"
  done
  if [ -n "${home_cmd_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_cmd_cases[@]}" ] && tr -d '\r' <"$home_cmd_log" | grep -qx 'HOME command ok'; then
      echo "HOME command ok"
    else
      echo "HOME command fail ($pass passed, $fail failed; see $home_cmd_log)"
    fi
  fi
fi
