# Hockey campaign, lane K2 rounds 3 and 4 (23 Nov 2026): the puck verbs and the contact of thirdjam's figure driver and the game mode's part
# around the pawns, on a match segment of the real rink core (engine/cores/rink/view/verb_gym.gd, headless: five a side
# with the bots playing, the human from the recorded raw hand cores/rink/view/verbs.stream.json, every skater a pawn
# and a figure). rig.skater.verbs: every frame of the segment runs, and the human's figure breaks no defect band on
# more frames, or worse, than it did when it was measured in parity with thirdjam's. rig.skater.verbs.oracle: frame by
# frame the figures stand where thirdjam's own figures stood in Unreal when they were given the same calls
# (rigs/skater/review/oracle_verbs.json: the human and two bots of the ten that were compared; worst 6 cm, 97 % of the
# rows within 1 cm). rig.skater.verbs.throw and .toys: two more recorded segments (a heavy check: the thrown victim;
# thirdjam's arsenal cartridge: a goal's celebration, the held ability). A stream names the state hash of its match: a
# core that replays it into another match fails the case by that name, not by a pose. rink.view.show: thirdjam's own tests of the hit-stop picks and the puck show, ported with their
# expected values, and 600 frames of the real core through the show object (cores/rink/view/skater_show_case.gd).
# rink.view.hits: thirdjam's tests of the hit read's model (the whiffs of a miss, the re-time of a check) ported with
# their expected values, and the verb run through it (cores/rink/view/hit_read_case.gd).

if [ -z "$FILTER" ] || [[ "rig.skater.verbs rig.skater.verbs.oracle rig.skater.verbs.throw rig.skater.verbs.toys rink.view.show rink.view.hits" == *"$FILTER"* ]]; then
  sv_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  sv_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && sv_engine="$(cygpath -m "$sv_engine")"
  sv_run() { MSYS_NO_PATHCONV=1 timeout 300 "$sv_godot" --headless --fixed-fps 60 --path "$sv_engine" res://cores/rink/view/verb_gym.tscn -- "$@" 2>&1 | tr -d '\015' | grep -a '^tl.skater.verb_gym\|SCRIPT ERROR'; }
  if [ -z "$FILTER" ] || [[ "rig.skater.verbs" == *"$FILTER"* ]]; then
    sv_out="$(sv_run)"; why=""
    if echo "$sv_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$sv_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif ! echo "$sv_out" | grep -aq '"frames_asked":1800,"frames_done":1800'; then why="not 1800 of 1800 frames: ${sv_out:0:240}"
    elif ! echo "$sv_out" | grep -aq '"ok":true'; then why="$(echo "$sv_out" | grep -ao '"error":"[^"]*"' | head -1)"; fi
    verdict "rig.skater.verbs" "$why" "$(echo "$sv_out" | grep -ao '"frames_done":[0-9]*' | head -1) $(echo "$sv_out" | grep -ao '"skaters":[0-9]*' | head -1) $(echo "$sv_out" | grep -ao '"state_hash":"[0-9a-f]*"' | head -1)"
  fi
  if [ -z "$FILTER" ] || [[ "rig.skater.verbs.oracle" == *"$FILTER"* ]]; then
    sv_out="$(sv_run --oracle=res://rigs/skater/review/oracle_verbs.json)"; why=""
    if echo "$sv_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$sv_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif ! echo "$sv_out" | grep -aq '"frames_compared":1800'; then why="not 1800 frames compared: ${sv_out:0:240}"
    elif ! echo "$sv_out" | grep -aq '"ok":true'; then why="$(echo "$sv_out" | grep -ao '"error":"[^"]*"' | head -1)"; fi
    verdict "rig.skater.verbs.oracle" "$why" "$(echo "$sv_out" | grep -ao '"rows_compared":[0-9]*' | head -1) $(echo "$sv_out" | grep -ao '"worst_cm":[0-9.]*' | head -1) $(echo "$sv_out" | grep -ao '"share_within":[0-9.]*' | head -1)"
  fi
  if [ -z "$FILTER" ] || [[ "rig.skater.verbs.throw" == *"$FILTER"* ]]; then
    # a short segment (420 frames, seed 7): the human checks a carrier at full closing speed, who is thrown (the heavy fall):
    # the victim's figure against thirdjam's
    sv_out="$(sv_run --stream=res://cores/rink/view/verbs_throw.stream.json --who=7 --oracle=res://rigs/skater/review/oracle_throw.json)"; why=""
    if echo "$sv_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$sv_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif ! echo "$sv_out" | grep -aq '"frames_compared":420'; then why="not 420 frames compared: ${sv_out:0:240}"
    elif ! echo "$sv_out" | grep -aq '"ok":true'; then why="$(echo "$sv_out" | grep -ao '"error":"[^"]*"' | head -1)"; fi
    verdict "rig.skater.verbs.throw" "$why" "$(echo "$sv_out" | grep -ao '"rows_compared":[0-9]*' | head -1) $(echo "$sv_out" | grep -ao '"worst_cm":[0-9.]*' | head -1)"
  fi
  if [ -z "$FILTER" ] || [[ "rig.skater.verbs.toys" == *"$FILTER"* ]]; then
    # thirdjam's arsenal cartridge (abilities held, a goal): the celebration and the equipment calls, three figures against thirdjam's
    sv_out="$(sv_run --stream=res://cores/rink/view/verbs_toys.stream.json --oracle=res://rigs/skater/review/oracle_toys.json)"; why=""
    if echo "$sv_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$sv_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif ! echo "$sv_out" | grep -aq '"frames_compared":1330'; then why="not 1330 frames compared: ${sv_out:0:240}"
    elif ! echo "$sv_out" | grep -aq '"PlayCelebrate":2'; then why="no celebration in the run"
    elif ! echo "$sv_out" | grep -aq '"ok":true'; then why="$(echo "$sv_out" | grep -ao '"error":"[^"]*"' | head -1)"; fi
    verdict "rig.skater.verbs.toys" "$why" "$(echo "$sv_out" | grep -ao '"rows_compared":[0-9]*' | head -1) $(echo "$sv_out" | grep -ao '"worst_cm":[0-9.]*' | head -1) $(echo "$sv_out" | grep -ao '"PlayCelebrate":[0-9]*' | head -1) $(echo "$sv_out" | grep -ao '"SetBoostEquipped":[0-9]*' | head -1)"
  fi
  if [ -z "$FILTER" ] || [[ "rink.view.show" == *"$FILTER"* ]]; then
    sv_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$sv_godot" --headless --fixed-fps 60 --path "$sv_engine" -s res://cores/rink/view/skater_show_case.gd 2>&1 | tr -d '\015')"; why=""
    sv_pass="$(echo "$sv_out" | grep -ac '^PASS ')"; sv_fail="$(echo "$sv_out" | grep -ac '^FAIL ')"
    if echo "$sv_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$sv_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif [ "$sv_fail" != "0" ]; then why="$(echo "$sv_out" | grep -a '^FAIL ' | head -1)"
    elif [ "$sv_pass" != "5" ]; then why="$sv_pass of 5 cases ran"; fi
    verdict "rink.view.show" "$why" "cases=$sv_pass of 5 failed=$sv_fail"
  fi
  if [ -z "$FILTER" ] || [[ "rink.view.hits" == *"$FILTER"* ]]; then
    sv_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$sv_godot" --headless --fixed-fps 60 --path "$sv_engine" -s res://cores/rink/view/hit_read_case.gd 2>&1 | tr -d '\015')"; why=""
    sv_pass="$(echo "$sv_out" | grep -ac '^PASS ')"; sv_fail="$(echo "$sv_out" | grep -ac '^FAIL ')"
    if echo "$sv_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$sv_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif [ "$sv_fail" != "0" ]; then why="$(echo "$sv_out" | grep -a '^FAIL ' | head -1)"
    elif [ "$sv_pass" != "6" ]; then why="$sv_pass of 6 cases ran"; fi
    verdict "rink.view.hits" "$why" "cases=$sv_pass of 6 failed=$sv_fail"
  fi
fi
