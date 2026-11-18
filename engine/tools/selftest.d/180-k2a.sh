# Run the held-ball example with its skater and a moving carrier.
# Check that the skater's speed stays within the bot's limit.

# --- K2a ---
# A held ball is never a moving floor: ex_held's skater rides a held ball its carrier shakes at up to 18.6 m/s and
# skates off it; his speed stays within his own skate_speed + 1 (before the cure: 15.0 m/s, the hockey pack saw 47).
if [ -z "$FILTER" ] || [[ "k2.held" == *"$FILTER"* ]]; then
  check k2.held_lint 0 lint "--pack=$EX/ex_held" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
  check k2.held_bot 0 bot "--pack=$EX/ex_held" -- '"id":"bot.ok","ok":true' '"ball_peak":18\.[0-9]+'
fi

