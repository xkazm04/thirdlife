# Lint and run the down, shove and stumble example.
# Check the bot's scaled-body measurements and deterministic replay.

# --- K2b ---
# TLBiped down / shove / stumble and the body sized with the rig (ex_down): frames down, move ignored, signals, the
# shove, the stumble, two 2.2-scaled figures with body_scale never closer than their bodies; deterministic.
if [ -z "$FILTER" ] || [[ "k2.down" == *"$FILTER"* ]]; then
  check k2.down_lint 0 lint "--pack=$EX/ex_down" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
  check k2.down_smoke 0 smoke "--pack=$EX/ex_down" --frames=600 -- '"id":"smoke.no_script_errors","ok":true'
  check k2.down_bot 0 bot "--pack=$EX/ex_down" -- '"id":"bot.ok","ok":true' '"down_frames":113,' '"least_sized":1\.3[0-9]*,'
  check k2.down_invariants 0 invariants "--pack=$EX/ex_down" --frames=600 -- '"id":"invariants.bot_deterministic","ok":true'
fi

