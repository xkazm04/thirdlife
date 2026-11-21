# Exercise the feel example through the same public verbs a pack author runs.
# The bot checks measured values, and invariants repeats both idle and bot runs.
lab_pack="$EX/ex_feel_lab"
check feel.lab_lint 0 lint "--pack=$lab_pack" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
check feel.lab_smoke 0 smoke "--pack=$lab_pack" --frames=1450 -- '"id":"smoke.loads","ok":true'
check feel.lab_bot 0 bot "--pack=$lab_pack" --frames=1450 -- '"id":"bot.ok","ok":true' '"id":"bot.completed","ok":true' '"case_count":12' '"contact_count":13' '"failed_cases":\[\]'
check feel.lab_invariants 0 invariants "--pack=$lab_pack" --frames=1450 --bot-frames=1450 -- '"id":"invariants.bot_deterministic","ok":true'
