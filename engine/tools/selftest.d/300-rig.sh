# Measure sole slip across five speeds and directions and after a running jump.
# Check that the biped provides the clips used by those moves.

# ---------------------------------------------------------------- walker-feel, lane L: the biped's feet and moves (rig.)
# The feet stand where they are put: six sole points; a point on the floor two frames running may not move (engine/rigs/
# review/review.gd, 400 frames, headless). Mean under 0.2 m/s at a jog, a sprint, a sidestep and backward (18 Nov: 0.06 to
# 0.10; the gait before it: 0.9 to 9.2), with a foot on the floor in at least 100 frames (a run that printed nothing fails).
if [ -z "$FILTER" ] || [[ "rig.feet_plant" == *"$FILTER"* ]] || [[ "rig.moves" == *"$FILTER"* ]]; then
  if [ -z "$FILTER" ] || [[ "rig.feet_plant" == *"$FILTER"* ]]; then
    why=""; seen=""
    for c in "4.5:0" "9.0:0" "4.5:90" "4.5:180" "1.4:0"; do
      line="$(RIG_ARGS="--dir=${c#*:}" bash "$HERE/look.sh" slip "${c%%:*}" walk 2>&1 | tr -d '' | grep -a 'contact\|SCRIPT ERROR' | head -1)"
      mean="$(echo "$line" | grep -o 'mean_ms=[0-9.]*' | cut -d= -f2)"; onf="$(echo "$line" | grep -o ' on_floor=[0-9]*' | cut -d= -f2)"
      if [ -z "$mean" ] || [ -z "$onf" ]; then why="${why:+$why; }$c: no contact line (${line:0:80})"
      elif [ "$onf" -lt 100 ]; then why="${why:+$why; }$c: a foot on the floor in only $onf frames"
      elif ! awk -v m="$mean" 'BEGIN { exit !(m < 0.2) }'; then why="${why:+$why; }$c: soles slide $mean m/s (limit 0.2)"; fi
      seen="${seen:+$seen, }${c%%:*} m/s dir ${c#*:} = $mean"
    done
    verdict rig.feet_plant "$why" "sole slide, mean m/s: $seen"
  fi
  if [ -z "$FILTER" ] || [[ "rig.moves" == *"$FILTER"* ]]; then
    why=""
    for mv in jump land slide slope_slide air; do
      grep -q "add_clip(\"$mv\"" "$HERE/../rigs/tl_rig_biped.gd" || why="${why:+$why; }tl_rig_biped.gd adds no clip $mv"
    done
    # a jump at a run: off the floor, the air pose, the landing; no script error, and the feet are planted again after it
    line="$(RIG_ARGS="--jump-at=90 --jump-v=8.5" bash "$HERE/look.sh" slip 4.5 walk 2>&1 | tr -d '' | grep -a 'contact\|SCRIPT ERROR' | head -1)"
    mean="$(echo "$line" | grep -o 'mean_ms=[0-9.]*' | cut -d= -f2)"
    if [ -z "$mean" ]; then why="${why:+$why; }jump run: no contact line (${line:0:80})"
    elif ! awk -v m="$mean" 'BEGIN { exit !(m < 0.6) }'; then why="${why:+$why; }jump run: soles slide $mean m/s (limit 0.6)"; fi
    verdict rig.moves "$why" "clips jump, land, slide, slope_slide, air; a run with a jump: sole slide $mean m/s"
  fi
fi

