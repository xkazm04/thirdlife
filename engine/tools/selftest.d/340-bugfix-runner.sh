# Bugfix-37 lane runner: the kernel runner's stage hand-over and the kernel teleports (headless, no wall clock).
# runner.stage_record_rebuilt (D2): a game rebuilt on stage keeps its visit record, `length` = ticks sampled.
# runner.stage_handover (D10): the bot's held press is let go when the person takes the game on stage.
# runner.place_no_glide (D15): TLBall/TLBiped/TLVehicle.place are drawn at the new place at once (interpolation reset).

_bfr_godot() {
  local gg="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  local eg; eg="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && eg="$(cygpath -m "$eg")"
  # hunt2 A1: the Godot run's own exit status is read (PIPESTATUS); 0 or 1 is a run that completed (1: a case failed, its
  # line says which); anything else (124 timeout, 143 killed, a crash) is a stopped run and every case of it FAILs.
  # A stopped run prints only `BUGFIXRUNNER stopped <exit>`: no case line is taken from it.
  local out; out="$(MSYS_NO_PATHCONV=1 timeout 200 "$gg" --headless --path "$eg" --script "$1" 2>&1 | tr -d '\015' | grep '^BUGFIXRUNNER'; echo "HUNT2RC ${PIPESTATUS[0]}")"
  local rc; rc="$(printf '%s\n' "$out" | sed -n 's/^HUNT2RC //p' | tail -1)"
  if [ "$rc" != 0 ] && [ "$rc" != 1 ]; then echo "BUGFIXRUNNER stopped ${rc:-unknown}"; return; fi
  printf '%s\n' "$out" | grep -v '^HUNT2RC '
}

if [ -z "$FILTER" ] || [[ "runner.stage_record_rebuilt" == *"$FILTER"* ]] || [[ "runner.stage_handover" == *"$FILTER"* ]]; then
  bfr_stage="$(_bfr_godot res://kernel/runner/bugfix_runner_stage.gd)"
  line="$(printf '%s\n' "$bfr_stage" | grep '^BUGFIXRUNNER record ')"
  why=""; [[ "$line" == "BUGFIXRUNNER record ok"* ]] || why="${line:-no BUGFIXRUNNER record line}"
  [[ "$bfr_stage" == "BUGFIXRUNNER stopped "* ]] && why="the case run stopped (Godot exit ${bfr_stage#BUGFIXRUNNER stopped })"
  verdict runner.stage_record_rebuilt "$why" "${line#BUGFIXRUNNER record ok - }"
  line="$(printf '%s\n' "$bfr_stage" | grep '^BUGFIXRUNNER handover ')"
  why=""; [[ "$line" == "BUGFIXRUNNER handover ok"* ]] || why="${line:-no BUGFIXRUNNER handover line}"
  [[ "$bfr_stage" == "BUGFIXRUNNER stopped "* ]] && why="the case run stopped (Godot exit ${bfr_stage#BUGFIXRUNNER stopped })"
  verdict runner.stage_handover "$why" "${line#BUGFIXRUNNER handover ok - }"
fi

if [ -z "$FILTER" ] || [[ "runner.place_no_glide" == *"$FILTER"* ]]; then
  bfr_place="$(_bfr_godot res://kernel/runner/bugfix_runner_place.gd)"
  line="$(printf '%s\n' "$bfr_place" | grep '^BUGFIXRUNNER place ')"
  why=""; [[ "$line" == "BUGFIXRUNNER place ok"* ]] || why="${line:-no BUGFIXRUNNER place line}"
  [[ "$bfr_place" == "BUGFIXRUNNER stopped "* ]] && why="the case run stopped (Godot exit ${bfr_place#BUGFIXRUNNER stopped })"
  verdict runner.place_no_glide "$why" "${line#BUGFIXRUNNER place ok - }"
fi
