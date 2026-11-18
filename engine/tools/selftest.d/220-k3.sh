# Lint and play the large-body version of the held-ball example.
# Check the skater's drift with a puck held and released underfoot.

# --- K3 ---
# A ball is never a floor, held or loose, whatever the body's size: ex_held_big's still skater (body_scale 2.2, a 0.66 m
# capsule) has a held puck moved under the rim of his body and then shot from under him at 25 m/s; he stays where he
# stood (the kernel of K2, which knew only held balls, let the loose puck carry him 61 m).
if [ -z "$FILTER" ] || [[ "k3.held_big" == *"$FILTER"* ]]; then
  check k3.held_big_lint 0 lint "--pack=$EX/ex_held_big" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
  check k3.held_big_bot 0 bot "--pack=$EX/ex_held_big" -- '"id":"bot.ok","ok":true' '"moved":0(\.0[0-9]*)?,' '"puck_peak":2[0-9](\.[0-9])?'
fi

