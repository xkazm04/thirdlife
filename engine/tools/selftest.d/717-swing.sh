# Measure the returned ribbons through the pack and repeat both idle and bot runs.
swing_pack="$EX/ex_swing_lab"
check swing.lint 0 lint "--pack=$swing_pack" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
check swing.smoke 0 smoke "--pack=$swing_pack" --frames=220 -- '"id":"smoke.no_engine_errors","ok":true'
check swing.bot 0 bot "--pack=$swing_pack" --frames=220 -- '"id":"bot.ok","ok":true' '"lifetimes":\[20,40,46\]'
check swing.invariants 0 invariants "--pack=$swing_pack" --frames=220 --bot-frames=220 -- '"id":"invariants.determinism","ok":true' '"id":"invariants.bot_deterministic","ok":true'
