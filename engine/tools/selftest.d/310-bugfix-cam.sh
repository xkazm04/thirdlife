# Bugfix-37 cam lane: the chase camera (TLChaseCam) never ends inside what `avoid_space` holds, takes `avoid_min`, casts in
# its parent's frame, snaps behind the new facing, turns on an exact reversal, and draws no frame inside a box on a cut
# (headless Godot, engine/kernel/world/walks/bugfix_cam_case.gd and bugfix_cam_cut.gd). Each case needs its own output
# line: a missing line is a FAIL. Defects D5 (wall_start, crown_band, canopy_jump), D17, D18, Q19, Q20, Q32.

cam_bf_cases="wall_start crown_band canopy_jump avoid_min rebase snap_heading reverse"
cam_bf_any=""
for cam_bf_c in $cam_bf_cases; do
  if [ -z "$FILTER" ] || [[ "cam.$cam_bf_c" == *"$FILTER"* ]]; then cam_bf_any=1; fi
done
if [ -n "$cam_bf_any" ]; then
  GC="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EC="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EC="$(cygpath -m "$EC")"
  cam_bf_out="$(MSYS_NO_PATHCONV=1 timeout 200 "$GC" --headless --path "$EC" --script res://kernel/world/walks/bugfix_cam_case.gd 2>&1 | tr -d '\015' | grep -a '^CAMCASE\|SCRIPT ERROR')"
  for cam_bf_c in $cam_bf_cases; do
    if [ -z "$FILTER" ] || [[ "cam.$cam_bf_c" == *"$FILTER"* ]]; then
      line="$(echo "$cam_bf_out" | grep -a "^CAMCASE cam.$cam_bf_c " | head -1)"
      why=""
      if [ -z "$line" ]; then why="no CAMCASE cam.$cam_bf_c line (${cam_bf_out:0:120})"
      elif [[ "$line" != "CAMCASE cam.$cam_bf_c ok "* ]]; then why="${line#CAMCASE }"
      elif echo "$cam_bf_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$cam_bf_out" | grep -a 'SCRIPT ERROR' | head -1)"; fi
      verdict "cam.$cam_bf_c" "$why" "${line#CAMCASE cam.$cam_bf_c ok }"
    fi
  done
fi

# Q32: two drawn frames per tick (--fixed-fps 120); a quarter turn in one tick must not draw the camera inside a box.
if [ -z "$FILTER" ] || [[ "cam.cut_wall" == *"$FILTER"* ]]; then
  GC="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EC="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EC="$(cygpath -m "$EC")"
  cam_cut_out="$(MSYS_NO_PATHCONV=1 timeout 200 "$GC" --headless --fixed-fps 120 --path "$EC" --script res://kernel/world/walks/bugfix_cam_cut.gd 2>&1 | tr -d '\015' | grep -a '^CAMCASE\|SCRIPT ERROR')"
  line="$(echo "$cam_cut_out" | grep -a "^CAMCASE cam.cut_wall " | head -1)"
  why=""
  if [ -z "$line" ]; then why="no CAMCASE cam.cut_wall line (${cam_cut_out:0:120})"
  elif [[ "$line" != "CAMCASE cam.cut_wall ok "* ]]; then why="${line#CAMCASE }"
  elif echo "$cam_cut_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$cam_cut_out" | grep -a 'SCRIPT ERROR' | head -1)"; fi
  verdict cam.cut_wall "$why" "${line#CAMCASE cam.cut_wall ok }"
fi
