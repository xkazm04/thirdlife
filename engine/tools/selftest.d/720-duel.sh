# N2 (night of 22 Nov 2026): the duel house game. Its contacts change BOTH fighters, and it is deterministic in frames.
#   duel.lint                 the pack lints with 0 bypasses
#   duel.contact_<drill>      a drill bot sees its contact with both fighters' states changed (parry, heavy block, clash, wall splat)
#   duel.replay_bot / _replay / _same   the parry->riposte drill's input record replays, with no bot, to the bot's hash
du_on() { [ -z "$FILTER" ] || [[ "duel.$1" == *"$FILTER"* ]]; }
du_pack="$(cd "$HERE/../packs/duel" && pwd)"
command -v cygpath >/dev/null 2>&1 && du_pack="$(cygpath -m "$du_pack")"
du_out="$OUT"
command -v cygpath >/dev/null 2>&1 && du_out="$(cygpath -m "$OUT")"
check duel.lint 0 lint "--pack=$du_pack" -- '"ok":true' '"bypasses":\[\]'
for du_d in light_parried heavy_block clash bash_wall; do
  check "duel.contact_$du_d" 0 bot "--pack=$du_pack" "--test=tests/bot_contact_$du_d.gd" --seed=1 --frames=3000 -- '"id":"bot.ok","ok":true' '"both":true'
done
if du_on "replay"; then
  rm -f "$du_out/duel_riposte.input.json"
  check duel.replay_bot 0 bot "--pack=$du_pack" "--test=tests/bot_contact_parry_riposte.gd" --seed=1 --frames=3000 "--record=$du_out/duel_riposte.input.json" -- '"id":"bot.ok","ok":true' '"id":"record.written","ok":true'
  check duel.replay_replay 0 replay "--pack=$du_pack" "--input=$du_out/duel_riposte.input.json" -- '"id":"replay.complete","ok":true'
  du_why=""; du_hb="$(field duel.replay_bot state_hash)"; du_hr="$(field duel.replay_replay state_hash)"
  [ -n "$du_hb" ] && [ "$du_hb" = "$du_hr" ] || du_why="the bot's hash ($du_hb) is not its replay's ($du_hr)"
  verdict duel.replay_same "$du_why" "parry_riposte seed 1: bot ${du_hb:0:16} = replay ${du_hr:0:16}"
fi
