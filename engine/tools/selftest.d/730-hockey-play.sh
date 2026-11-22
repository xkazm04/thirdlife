# N3 (night of 22 Nov 2026): hockey's puck carry state (poke odds rolled on the seeded generator, dangle and self-loss,
# pickup and bobble by relative speed, the soft magnet, the one-timer window) and the utility AI replay from the input
# record alone: each bot's record replays, with no bot, to the bot's state hash.
#   hockeyplay.<bot>_bot / _replay / _same   (bots: poke, dangle, reception, ai_play)
hp_on() { [ -z "$FILTER" ] || [[ "hockeyplay.$1" == *"$FILTER"* ]]; }
hp_pack="$(cd "$HERE/../packs/hockey" && pwd)"
command -v cygpath >/dev/null 2>&1 && hp_pack="$(cygpath -m "$hp_pack")"
hp_out="$OUT"
command -v cygpath >/dev/null 2>&1 && hp_out="$(cygpath -m "$OUT")"
for hp_bot in bot_poke bot_dangle bot_reception bot_ai_play; do
  if hp_on "${hp_bot}_"; then
    rm -f "$hp_out/hp_$hp_bot.input.json"
    check "hockeyplay.${hp_bot}_bot" 0 bot "--pack=$hp_pack" "--test=tests/$hp_bot.gd" --seed=1 "--record=$hp_out/hp_$hp_bot.input.json" -- '"id":"bot.ok","ok":true' '"id":"record.written","ok":true'
    check "hockeyplay.${hp_bot}_replay" 0 replay "--pack=$hp_pack" "--input=$hp_out/hp_$hp_bot.input.json" -- '"id":"replay.complete","ok":true'
    hp_why=""; hp_hb="$(field "hockeyplay.${hp_bot}_bot" state_hash)"; hp_hr="$(field "hockeyplay.${hp_bot}_replay" state_hash)"
    [ -n "$hp_hb" ] && [ "$hp_hb" = "$hp_hr" ] || hp_why="$hp_bot's hash ($hp_hb) is not its replay's ($hp_hr)"
    verdict "hockeyplay.${hp_bot}_same" "$hp_why" "$hp_bot seed 1: bot ${hp_hb:0:16} = replay ${hp_hr:0:16}"
  fi
done
