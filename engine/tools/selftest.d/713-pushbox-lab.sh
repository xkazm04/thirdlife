# Exercise the pushbox example through the same public verbs a pack author runs.
# The bot checks measured values, and invariants repeats both idle and bot runs.
pushbox_pack="$EX/ex_pushbox_lab"
check feel.pushbox_lint 0 lint "--pack=$pushbox_pack" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
check feel.pushbox_smoke 0 smoke "--pack=$pushbox_pack" --frames=420 -- '"id":"smoke.loads","ok":true'
check feel.pushbox_bot 0 bot "--pack=$pushbox_pack" --frames=420 -- '"id":"bot.ok","ok":true' '"id":"bot.completed","ok":true' '"stunned_ticks":120' '"stunned_travel":[0-9.]+' '"radii_sum":0\.64'
check feel.pushbox_invariants 0 invariants "--pack=$pushbox_pack" --frames=420 --bot-frames=420 -- '"id":"invariants.bot_deterministic","ok":true'
