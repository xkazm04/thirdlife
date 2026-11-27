# Round 2 lane C (27 Nov 2026): the space check's findings, the words a fix ask carries to the model
# (kernel/world/build/command_space.gd `findings`). A headless case (kernel/world/build/command_fix_case.gd -- findings)
# on a hand-laid stone platform with a DRY Foreman door and FAKE answers: a floating block, a pad over nothing and a
# coin in a cube each get a line with their cells; a 5-cell gap gets "a gap too wide ... 6.0 m across (5 empty cells)"
# and the climb from the platform "2.0 m up"; a 2-block pillar beside the start gets "a climb too high ... 2.0 m up";
# a reachable course gets none. No model is called. Frames, not wall clock. Runs on its own:
# `bash engine/tools/selftest.d/787-home-command-findings.sh` prints `HOME command-findings ok` when it passes.
home_command_findings_cases=(home.command-findings.floating home.command-findings.gap home.command-findings.wall)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_command_findings_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_command_findings_cases[*]}" == *"$FILTER"* ]]; then
  home_cfd_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_cfd_engine="$(cygpath -am "$home_cfd_engine")"
  home_cfd_log="$OUT/home-command-findings.log"
  home_cfd_rc=0
  TL_HOME= TL_STYLE=crisp TL_COMMAND_DEVICES= MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$home_cfd_engine" \
    --script res://kernel/world/build/command_fix_case.gd -- findings >"$home_cfd_log" 2>&1 || home_cfd_rc=$?
  for home_cfd_case in "${home_command_findings_cases[@]}"; do
    home_cfd_name="${home_cfd_case#home.}"
    home_cfd_line="$(tr -d '\r' <"$home_cfd_log" | grep -F "HOME $home_cfd_name " | head -1)"
    why=""
    if [ "$home_cfd_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_cfd_log"; then
      why="stopped run (Godot exit $home_cfd_rc), ${home_cfd_line:-missing $home_cfd_case}; see $home_cfd_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_cfd_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_cfd_log")"
    elif [[ "$home_cfd_line" != "HOME $home_cfd_name ok "* ]]; then
      why="${home_cfd_line:-missing HOME $home_cfd_name verdict}"
    fi
    verdict "$home_cfd_case" "$why" "${home_cfd_line#HOME "$home_cfd_name" ok }"
  done
  if [ -n "${home_command_findings_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_command_findings_cases[@]}" ] && tr -d '\r' <"$home_cfd_log" | grep -qx 'HOME command-findings ok'; then
      echo "HOME command-findings ok"
    else
      echo "HOME command-findings fail ($pass passed, $fail failed; see $home_cfd_log)"
    fi
  fi
fi
