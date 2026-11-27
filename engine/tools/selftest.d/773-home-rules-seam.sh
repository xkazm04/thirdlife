# M6 SEAM (27 Nov 2026, lane S6): rules and runs in the Home (kernel/world/build/rules_check.gd, rules_layer.gd,
# rules_run.gd, rules_facade.gd, rules_play.gd, home_records.gd, tl.build/4 in build_file.gd; contracts/BUILD.md
# "Milestone 6"). Headless, no landscape: every zone/unzone/rule/unrule refusal reason, apply/undo/redo, tl.build/4
# saved and loaded byte for byte (a v3 Home stays v3), an LLM answer's ids renumbered, the ask's zones/rules/
# rules_room, describe, the runtime over a scripted feet path with a recording facade (enter, count, use, every,
# start, checkpoint, respawn, finish, records and "new best", effects in order, determinism), tl.records/1, and the
# wiring in build mode (kernel/world/build/rules_case.gd, rules_case_run.gd). Frames, not wall clock; the final
# marker is required. Runs on its own too: `bash engine/tools/selftest.d/773-home-rules-seam.sh` prints
# `HOME rules-seam ok` when it passes.
home_rules_cases=(home.rules-seam.ops home.rules-seam.undo home.rules-seam.files home.rules-seam.renumber home.rules-seam.region home.rules-seam.run home.rules-seam.records home.rules-seam.play)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_rules_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_rules_cases[*]}" == *"$FILTER"* ]]; then
  home_rules_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_rules_engine="$(cygpath -am "$home_rules_engine")"
  home_rules_log="$OUT/home-rules-seam.log"
  home_rules_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 1200 --path "$home_rules_engine" \
    --script res://kernel/world/build/rules_case.gd >"$home_rules_log" 2>&1 || home_rules_rc=$?
  for home_rules_case in "${home_rules_cases[@]}"; do
    home_rules_name="${home_rules_case#home.}"
    home_rules_line="$(tr -d '\r' <"$home_rules_log" | grep -F "HOME $home_rules_name " | head -1)"
    why=""
    if [ "$home_rules_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_rules_log"; then
      why="stopped run (Godot exit $home_rules_rc), ${home_rules_line:-missing $home_rules_case}; see $home_rules_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_rules_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_rules_log")"
    elif [[ "$home_rules_line" != "HOME $home_rules_name ok "* ]]; then
      why="${home_rules_line:-missing HOME $home_rules_name verdict}"
    fi
    verdict "$home_rules_case" "$why" "${home_rules_line#HOME "$home_rules_name" ok }"
  done
  if [ -n "${home_rules_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_rules_cases[@]}" ] && tr -d '\r' <"$home_rules_log" | grep -qx 'HOME rules-seam ok'; then
      echo "HOME rules-seam ok"
    else
      echo "HOME rules-seam fail ($pass passed, $fail failed; see $home_rules_log)"
    fi
  fi
fi
