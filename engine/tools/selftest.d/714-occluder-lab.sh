# Exercise the occluder example through the same public verbs a pack author runs.
# The bot checks measured values, and invariants repeats both idle and bot runs.
occluder_pack="$EX/ex_occluder_lab"
check feel.occluder_lint 0 lint "--pack=$occluder_pack" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
check feel.occluder_smoke 0 smoke "--pack=$occluder_pack" --frames=230 -- '"id":"smoke.loads","ok":true'
check feel.occluder_bot 0 bot "--pack=$occluder_pack" --frames=230 -- '"id":"bot.ok","ok":true' '"id":"bot.completed","ok":true' '"pillar_samples":11' '"min_alpha_loss":0\.(69|7)'
check feel.occluder_invariants 0 invariants "--pack=$occluder_pack" --frames=230 --bot-frames=230 -- '"id":"invariants.bot_deterministic","ok":true'
