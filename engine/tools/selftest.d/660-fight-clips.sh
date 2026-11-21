# Lane L2 fight-clips (21 Nov 2026): the biped's fight clips and stick_yaw (engine/rigs/review/fight_case.gd, headless,
# under the classic, crisp and diorama looks). rig.fight.clips: the eight clips exist with the lengths of RIGS.md "Fight
# clips" and TLRigBipedFight.TIMING and end as the table says, deterministically; rig.fight.golden: every older clip gives
# the base tree's poses (rigs/review/fight_golden.txt), also with stick_yaw = 0 set every tick; rig.fight.yaw: the blade
# turns by about the yaw each way at the same height; rig.fight.cross: a held cross-check has the shaft level across the chest.

if [ -z "$FILTER" ] || [[ "rig.fight.clips rig.fight.golden rig.fight.yaw rig.fight.cross" == *"$FILTER"* ]]; then
  fc_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  fc_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && fc_engine="$(cygpath -m "$fc_engine")"
  fc_out="$(MSYS_NO_PATHCONV=1 timeout 600 "$fc_godot" --headless --fixed-fps 60 --path "$fc_engine" \
    --script res://rigs/review/fight_case.gd 2>&1 | tr -d '\015' | grep -a '^FIGHT \|SCRIPT ERROR')"
  for fc_case in clips golden yaw cross; do
    if [ -z "$FILTER" ] || [[ "rig.fight.$fc_case" == *"$FILTER"* ]]; then
      fc_line="$(echo "$fc_out" | grep -a "^FIGHT $fc_case " | head -1)"
      why=""
      if [ -z "$fc_line" ]; then why="no FIGHT $fc_case line (${fc_out:0:160})"
      elif echo "$fc_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$fc_out" | grep -a 'SCRIPT ERROR' | head -1)"
      elif [[ "$fc_line" != "FIGHT $fc_case ok=true"* ]]; then why="${fc_line:0:300}"; fi
      verdict "rig.fight.$fc_case" "$why" "${fc_line#FIGHT $fc_case ok=true }"
    fi
  done
fi
