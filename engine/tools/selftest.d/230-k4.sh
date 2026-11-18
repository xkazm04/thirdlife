# Compare the square-aim bot with the perfect hand driving the same path.
# Check hit counts across all four hand profiles.

# --- K4 ---
# A person's hand aims: ex_pointer's bot through TLHand "perfect" gives ex_pointer's own bot hash; ex_pointer_hand's bot
# puts the aim on a jumping, sliding target through each profile: perfect hits all 20, and the hits fall from perfect to
# newcomer (seed 1: 20, 20, 11, 4) while the hand's aim reaction and the taps a lapse swallowed are counted.
if [ -z "$FILTER" ] || [[ "k4.hand_aim" == *"$FILTER"* ]]; then
  check k4.hand_aim_square_plain 0 bot "--pack=$EX/ex_pointer" --test=tests/bot_square.gd -- '"id":"bot.ok","ok":true'
  check k4.hand_aim_square_hand 0 bot "--pack=$EX/ex_pointer" --test=tests/bot_square_hand.gd -- '"id":"bot.ok","ok":true'
  why=""; h1="$(field k4.hand_aim_square_plain state_hash)"; h2="$(field k4.hand_aim_square_hand state_hash)"
  [ -n "$h1" ] && [ "$h1" = "$h2" ] || why="the perfect hand changed ex_pointer's bot hash ($h1 / $h2)"
  verdict k4.hand_aim_perfect_same_hash "$why" "ex_pointer: ${h1:0:16} with and without the perfect hand"
  check k4.hand_aim_lint 0 lint "--pack=$EX/ex_pointer_hand" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
  for p in perfect sharp regular newcomer; do
    t="bot_aim"; [ "$p" != perfect ] && t="bot_aim_$p"
    check "k4.hand_aim_$p" 0 bot "--pack=$EX/ex_pointer_hand" "--test=tests/$t.gd" -- '"id":"bot.ok","ok":true' "\"profile\":\"$p\""
  done
  why=""; prev=99
  for p in perfect sharp regular newcomer; do
    h="$(grep -o '"hits":[0-9]*' "$(report_of "k4.hand_aim_$p")" 2>/dev/null | head -1 | cut -d: -f2)"
    [ -n "$h" ] && [ "$h" -le "$prev" ] || why="${why:+$why; }hits do not fall from perfect to newcomer ($p: ${h:-none} after $prev)"
    prev="${h:-0}"
  done
  verdict k4.hand_aim_profiles_fall "$why" "hits of 20 on seed 1, perfect to newcomer"
fi

