# Check aim validity with and without a bot and compare the pointer replay hash.
# needs: OUTW from 110-p7.sh.

# --- K1 ---
# The aim (ctx.input.declare_aim): ex_pointer's stick follows the point its bot sets round a square, holds its heading
# with the aim on the figure or taken away; without a bot the aim is invalid on every frame (the pack raises an error
# in a smoke run if it is ever valid); a bot run recorded and replayed gives the bot's hash (the aim is in the record).
if [ -z "$FILTER" ] || [[ "k1.pointer" == *"$FILTER"* ]]; then
  KREC="$OUTW/k1_pointer.input.json"; rm -f "$KREC"
  check k1.pointer_lint 0 lint "--pack=$EX/ex_pointer" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
  check k1.pointer_smoke 0 smoke "--pack=$EX/ex_pointer" --seed=1 --frames=600 -- '"id":"smoke.no_script_errors","ok":true,"detail":"0 errors in 600 frames"'
  check k1.pointer_bot 0 bot "--pack=$EX/ex_pointer" "--record=$KREC" -- '"id":"bot.ok","ok":true' '"follow_frames":\[5,10,10,10\]' '"dead_frames":30,'
  check k1.pointer_replay 0 replay "--pack=$EX/ex_pointer" "--input=$KREC" -- '"id":"replay.complete","ok":true'
  check k1.pointer_invariants 0 invariants "--pack=$EX/ex_pointer" --frames=600 -- '"id":"invariants.determinism","ok":true' '"id":"invariants.bot_deterministic","ok":true'
  why=""; hb="$(field k1.pointer_bot state_hash)"; hr="$(field k1.pointer_replay state_hash)"
  [ -n "$hb" ] && [ "$hb" = "$hr" ] || why="the bot's hash ($hb) is not the replay's ($hr)"
  grep -q '"aim@x",' "$KREC" 2>/dev/null || why="${why:+$why; }the record holds no aim"
  verdict k1.pointer_replay_hash "$why" "ex_pointer: bot ${hb:0:16} = replay ${hr:0:16}; $(grep -o '"aim",1' "$KREC" 2>/dev/null | wc -l | tr -d ' ') frames with a valid aim"
fi

