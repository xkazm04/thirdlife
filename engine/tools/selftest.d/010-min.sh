# Run the five verbs on pack_min, compare state hashes across seeds,
# and check the capture and res:// pack paths.

# ---------------------------------------------------------------- the good pack: all five verbs
check min.lint 0 lint "--pack=$EX/pack_min" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]' '"gdscript_lines":\{"scripts":[0-9]+'
check min.smoke 0 smoke "--pack=$EX/pack_min" --seed=1 --frames=3600 -- '"id":"smoke.no_script_errors","ok":true,"detail":"0 errors in 3600 frames"' '"state_hash":"[0-9a-f]{64}"'
check min.smoke_again 0 smoke "--pack=$EX/pack_min" --seed=1 --frames=3600
check min.smoke_seed2 0 smoke "--pack=$EX/pack_min" --seed=2 --frames=3600
if [ -z "$FILTER" ] || [[ "min.determinism" == *"$FILTER"* ]]; then
  h1="$(field min.smoke state_hash)"; h2="$(field min.smoke_again state_hash)"; h3="$(field min.smoke_seed2 state_hash)"
  why=""
  [ -z "$h1" ] && why="no state_hash"
  [ "$h1" != "$h2" ] && why="same seed gave different hashes ($h1 / $h2)"
  [ "$h1" = "$h3" ] && why="${why:+$why; }a different seed gave the same hash"
  verdict min.determinism "$why" "seed 1: ${h1:0:16} twice; seed 2: ${h3:0:16}"
fi
check min.invariants 0 invariants "--pack=$EX/pack_min" -- '"id":"invariants.determinism","ok":true' '"id":"invariants.bot_deterministic","ok":true' '"id":"invariants.below_ground","ok":true' '"id":"invariants.frame_budget","ok":true' '"id":"invariants.entity_budget","ok":true'
check min.bot 0 bot "--pack=$EX/pack_min" --test=tests/bot_roll.gd -- '"id":"bot.completed","ok":true' '"id":"bot.ok","ok":true' '"bot":\{"test":"tests/bot_roll.gd","done":true,"frames":[0-9]+,'
PNG="$OUT/min_hero.png"; command -v cygpath >/dev/null 2>&1 && PNG="$(cygpath -m "$PNG")"
check min.capture 0 capture "--pack=$EX/pack_min" --cam=hero --frame=120 "--out=$PNG" --res=1280x720 -- '"id":"capture.written","ok":true' '"capture":\{"cam":"hero","frame":120,' '"width":1280,"height":720'
if [ -z "$FILTER" ] || [[ "min.capture_file" == *"$FILTER"* ]]; then
  why=""; [ -s "$PNG" ] || why="no image at $PNG"
  [ -z "$why" ] && [ "$(head -c 4 "$PNG" | tail -c 3)" != "PNG" ] && why="not a PNG file"
  verdict min.capture_file "$why" "$(wc -c < "$PNG" 2>/dev/null | tr -d ' ') bytes"
fi
check min.res_path 0 lint --pack=res://kernel/examples/pack_min
check min.res_path_smoke 0 smoke --pack=res://kernel/examples/pack_min --frames=120

