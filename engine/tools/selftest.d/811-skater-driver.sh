# Hockey campaign, lane K2 round 2 (23 Nov 2026): thirdjam's figure driver in our engine, on the real rink core
# (engine/cores/rink/view/figure_gym.gd, headless; the core steps the gym's scripted hand, thirdjam's pawn makes the
# figure's calls). rig.skater.driver: every frame of the hand runs, and on no check (blade on the ice, skates on the
# ice, bone lengths, pose pops, the shaft against the legs, the puck socket) does our figure break more frames, or
# worse, than thirdjam's own does on that run. rig.skater.oracle: frame by frame our figure stands where thirdjam's
# own figure stood in Unreal when it was given the same calls (rigs/skater/review/oracle_gym.json: 940 frames, twelve
# points; worst 6 cm, 97 % of the frames within 1 cm; measured 0.02 cm and 100 %). rig.skater.red: with the body sunk
# 3 cm the defect gate fails (a test that cannot fail is no test).

if [ -z "$FILTER" ] || [[ "rig.skater.driver rig.skater.oracle rig.skater.red" == *"$FILTER"* ]]; then
  sd_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  sd_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && sd_engine="$(cygpath -m "$sd_engine")"
  sd_run() { MSYS_NO_PATHCONV=1 timeout 300 "$sd_godot" --headless --fixed-fps 60 --path "$sd_engine" res://cores/rink/view/figure_gym.tscn -- "$@" 2>&1 | tr -d '\015' | grep -a '^tl.skater.figure_gym/1 \|SCRIPT ERROR' | head -3; }
  if [ -z "$FILTER" ] || [[ "rig.skater.driver" == *"$FILTER"* ]]; then
    sd_out="$(sd_run)"; why=""
    if echo "$sd_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$sd_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif ! echo "$sd_out" | grep -aq '"frames_asked":940,"frames_done":940'; then why="not 940 of 940 frames: ${sd_out:0:240}"
    elif ! echo "$sd_out" | grep -aq '"ok":true'; then why="$(echo "$sd_out" | grep -ao '"error":"[^"]*"' | head -1)"; fi
    verdict "rig.skater.driver" "$why" "$(echo "$sd_out" | grep -ao '"frames_done":[0-9]*' | head -1) $(echo "$sd_out" | grep -ao '"defect_gate":"[^"]*"' | head -1)"
  fi
  if [ -z "$FILTER" ] || [[ "rig.skater.oracle" == *"$FILTER"* ]]; then
    sd_out="$(sd_run --oracle=res://rigs/skater/review/oracle_gym.json)"; why=""
    if echo "$sd_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$sd_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif ! echo "$sd_out" | grep -aq '"frames_compared":940'; then why="not 940 frames compared: ${sd_out:0:240}"
    elif ! echo "$sd_out" | grep -aq '"ok":true'; then why="$(echo "$sd_out" | grep -ao '"error":"[^"]*"' | head -1)"; fi
    verdict "rig.skater.oracle" "$why" "$(echo "$sd_out" | grep -ao '"worst_cm":[0-9.]*' | head -1) $(echo "$sd_out" | grep -ao '"share_within":[0-9.]*' | head -1)"
  fi
  if [ -z "$FILTER" ] || [[ "rig.skater.red" == *"$FILTER"* ]]; then
    sd_out="$(sd_run --break=sink)"; why=""
    if ! echo "$sd_out" | grep -aq '"frames_done":940'; then why="the run did not finish: ${sd_out:0:240}"
    elif ! echo "$sd_out" | grep -aq '"ok":false' || ! echo "$sd_out" | grep -aq 'defects: blade'; then why="the sunk body passed the defect gate: ${sd_out:0:240}"; fi
    verdict "rig.skater.red" "$why" "sunk 3 cm: $(echo "$sd_out" | grep -ao 'blade: [0-9]* frames break the band' | head -1)"
  fi
fi
