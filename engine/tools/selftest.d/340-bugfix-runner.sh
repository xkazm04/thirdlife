# Bugfix-37 lane runner: the kernel runner's stage hand-over and the kernel teleports (headless, no wall clock).
# runner.stage_record_rebuilt (D2): a game rebuilt on stage keeps its visit record, `length` = ticks sampled.
# runner.stage_handover (D10): the bot's held press is let go when the person takes the game on stage.
# runner.place_no_glide (D15): TLBall/TLBiped/TLVehicle.place are drawn at the new place at once (interpolation reset).

_bfr_godot() {
  local gg="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  local eg; eg="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && eg="$(cygpath -m "$eg")"
  MSYS_NO_PATHCONV=1 timeout 200 "$gg" --headless --path "$eg" --script "$1" 2>&1 | tr -d '\015' | grep '^BUGFIXRUNNER'
}

if [ -z "$FILTER" ] || [[ "runner.stage_record_rebuilt" == *"$FILTER"* ]] || [[ "runner.stage_handover" == *"$FILTER"* ]]; then
  bfr_stage="$(_bfr_godot res://kernel/runner/bugfix_runner_stage.gd)"
  line="$(printf '%s\n' "$bfr_stage" | grep '^BUGFIXRUNNER record ')"
  why=""; [[ "$line" == "BUGFIXRUNNER record ok"* ]] || why="${line:-no BUGFIXRUNNER record line}"
  verdict runner.stage_record_rebuilt "$why" "${line#BUGFIXRUNNER record ok - }"
  line="$(printf '%s\n' "$bfr_stage" | grep '^BUGFIXRUNNER handover ')"
  why=""; [[ "$line" == "BUGFIXRUNNER handover ok"* ]] || why="${line:-no BUGFIXRUNNER handover line}"
  verdict runner.stage_handover "$why" "${line#BUGFIXRUNNER handover ok - }"
fi

if [ -z "$FILTER" ] || [[ "runner.place_no_glide" == *"$FILTER"* ]]; then
  line="$(_bfr_godot res://kernel/runner/bugfix_runner_place.gd | grep '^BUGFIXRUNNER place ')"
  why=""; [[ "$line" == "BUGFIXRUNNER place ok"* ]] || why="${line:-no BUGFIXRUNNER place line}"
  verdict runner.place_no_glide "$why" "${line#BUGFIXRUNNER place ok - }"
fi
