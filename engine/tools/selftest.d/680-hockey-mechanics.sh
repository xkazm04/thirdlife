# L4 (day of 21 Nov 2026): the thirdjam port in hockey (puck on the blade, reverse brake and burst, the stability contact
# model, the cross-check) is deterministic in frames: each bot's input record replays, with no bot, to the bot's hash.
#   hockeymech.<bot>_bot      the bot passes on seed 1 and writes its record
#   hockeymech.<bot>_replay   the record replays (no bot)
#   hockeymech.<bot>_same     the two state hashes are equal (bots: carry_turn, reverse_stop, contact, sprint, charge)
hm_on() { [ -z "$FILTER" ] || [[ "hockeymech.$1" == *"$FILTER"* ]]; }
hm_pack="$(cd "$HERE/../packs/hockey" && pwd)"
command -v cygpath >/dev/null 2>&1 && hm_pack="$(cygpath -m "$hm_pack")"
hm_out="$OUT"
command -v cygpath >/dev/null 2>&1 && hm_out="$(cygpath -m "$OUT")"
for hm_bot in bot_carry_turn bot_reverse_stop bot_contact bot_sprint bot_charge; do
  if hm_on "${hm_bot}_"; then
    rm -f "$hm_out/hm_$hm_bot.input.json"
    check "hockeymech.${hm_bot}_bot" 0 bot "--pack=$hm_pack" "--test=tests/$hm_bot.gd" --seed=1 "--record=$hm_out/hm_$hm_bot.input.json" -- '"id":"bot.ok","ok":true' '"id":"record.written","ok":true'
    check "hockeymech.${hm_bot}_replay" 0 replay "--pack=$hm_pack" "--input=$hm_out/hm_$hm_bot.input.json" -- '"id":"replay.complete","ok":true'
    hm_why=""; hm_hb="$(field "hockeymech.${hm_bot}_bot" state_hash)"; hm_hr="$(field "hockeymech.${hm_bot}_replay" state_hash)"
    [ -n "$hm_hb" ] && [ "$hm_hb" = "$hm_hr" ] || hm_why="$hm_bot's hash ($hm_hb) is not its replay's ($hm_hr)"
    verdict "hockeymech.${hm_bot}_same" "$hm_why" "$hm_bot seed 1: bot ${hm_hb:0:16} = replay ${hm_hr:0:16}"
  fi
done
