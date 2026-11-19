# Bugfix-37 rig lane: the biped's pose, face, landing and stick colour, and the review scene's team (headless Godot,
# engine/rigs/review/bugfix_rig_cases.gd and bugfix_rig_team.gd). Each case needs its own output line: a missing line
# is a FAIL. Defects: D11 (pose_rest, gaze), Q11 (land_turn), Q27 (spawn_face), Q28 (build_blink), Q29 (stick_color),
# Q30 (review_team); docs/reports/bugfix-37/lane-rig.md.

rig_bf_any=""
for rig_bf_c in pose_rest gaze land_turn spawn_face build_blink stick_color; do
  if [ -z "$FILTER" ] || [[ "rig.bugfix.$rig_bf_c" == *"$FILTER"* ]]; then rig_bf_any=1; fi
done
if [ -n "$rig_bf_any" ]; then
  GG="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EG="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EG="$(cygpath -m "$EG")"
  # hunt2 A1: the Godot run's own exit status is read (PIPESTATUS); 0 or 1 is a run that completed (1: a case failed, its
  # line says which); anything else (124 timeout, 143 killed, a crash) is a stopped run and every case of it FAILs.
  rig_bf_out="$(MSYS_NO_PATHCONV=1 timeout 200 "$GG" --headless --path "$EG" --script res://rigs/review/bugfix_rig_cases.gd 2>&1 | tr -d '\015' | grep -a '^RIGCASE\|SCRIPT ERROR'; echo "HUNT2RC ${PIPESTATUS[0]}")"
  rig_bf_rc="$(echo "$rig_bf_out" | sed -n 's/^HUNT2RC //p' | tail -1)"
  for rig_bf_c in pose_rest gaze land_turn spawn_face build_blink stick_color; do
    if [ -z "$FILTER" ] || [[ "rig.bugfix.$rig_bf_c" == *"$FILTER"* ]]; then
      line="$(echo "$rig_bf_out" | grep -a "^RIGCASE $rig_bf_c " | head -1)"
      why=""
      if [ "$rig_bf_rc" != 0 ] && [ "$rig_bf_rc" != 1 ]; then why="the case run stopped (Godot exit ${rig_bf_rc:-unknown}) ${line:+after: ${line#RIGCASE }}"
      elif [ -z "$line" ]; then why="no RIGCASE $rig_bf_c line (${rig_bf_out:0:120})"
      elif [[ "$line" != "RIGCASE $rig_bf_c ok "* ]]; then why="${line#RIGCASE }"
      elif echo "$rig_bf_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$rig_bf_out" | grep -a 'SCRIPT ERROR' | head -1)"; fi
      verdict "rig.bugfix.$rig_bf_c" "$why" "${line#RIGCASE $rig_bf_c ok }"
    fi
  done
fi

# Q30: the review scene (engine/rigs/review/review.gd) makes a red skater with --team=red; a skater with no --team stays blue.
if [ -z "$FILTER" ] || [[ "rig.bugfix.review_team" == *"$FILTER"* ]]; then
  GG="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EG="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EG="$(cygpath -m "$EG")"
  red="$(MSYS_NO_PATHCONV=1 timeout 200 "$GG" --headless --path "$EG" --script res://rigs/review/bugfix_rig_team.gd -- --mode=skate --team=red 2>&1 | tr -d '\015' | grep -a '^RIGTEAM' | head -1; echo "HUNT2RC ${PIPESTATUS[0]}")"
  red_rc="$(echo "$red" | sed -n 's/^HUNT2RC //p')"; red="$(echo "$red" | grep -v '^HUNT2RC ')"
  blue="$(MSYS_NO_PATHCONV=1 timeout 200 "$GG" --headless --path "$EG" --script res://rigs/review/bugfix_rig_team.gd -- --mode=skate 2>&1 | tr -d '\015' | grep -a '^RIGTEAM' | head -1; echo "HUNT2RC ${PIPESTATUS[0]}")"
  blue_rc="$(echo "$blue" | sed -n 's/^HUNT2RC //p')"; blue="$(echo "$blue" | grep -v '^HUNT2RC ')"
  why=""
  [ "$red_rc" = 0 ] || why="the --team=red run stopped (Godot exit ${red_rc:-unknown})"
  [ "$blue_rc" = 0 ] || why="${why:+$why; }the default run stopped (Godot exit ${blue_rc:-unknown})"
  [ "$red" == "RIGTEAM car_red" ] || why="--team=red gave '${red:-no RIGTEAM line}'"
  [ "$blue" == "RIGTEAM car_blue" ] || why="${why:+$why; }no --team gave '${blue:-no RIGTEAM line}'"
  verdict rig.bugfix.review_team "$why" "red: ${red#RIGTEAM }, default: ${blue#RIGTEAM }"
fi
