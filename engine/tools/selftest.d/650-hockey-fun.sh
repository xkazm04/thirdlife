# L5 (night of 21 Nov 2026): the hockey fun layer stays deterministic in frames. The hit-stop freezes bodies and the clock,
# the goal's replay moves bodies through recorded places: both must replay from the input record alone.
#   hockeyfun.record_bot     tests/bot_fun.gd (a hit-stop, a quiet bump, a goal with its replay) passes and writes its record
#   hockeyfun.record_replay  the record replays (no bot) to the bot run's state hash
#   hockeyfun.goalie_replay  the same for tests/bot_goalie.gd (the goalies' saves, a poke check, two goals)
hf_on() { [ -z "$FILTER" ] || [[ "$1" == *"$FILTER"* ]]; }
hf_pack="$(cd "$HERE/../packs/hockey" && pwd)"
command -v cygpath >/dev/null 2>&1 && hf_pack="$(cygpath -m "$hf_pack")"
hf_out="$OUT"
command -v cygpath >/dev/null 2>&1 && hf_out="$(cygpath -m "$OUT")"
if hf_on hockeyfun.record || hf_on hockeyfun.goalie; then
  rm -f "$hf_out/hf_fun.input.json" "$hf_out/hf_goalie.input.json"
  check hockeyfun.record_bot 0 bot "--pack=$hf_pack" --test=tests/bot_fun.gd --seed=1 "--record=$hf_out/hf_fun.input.json" -- '"id":"bot.ok","ok":true' '"id":"record.written","ok":true'
  check hockeyfun.record_replay 0 replay "--pack=$hf_pack" "--input=$hf_out/hf_fun.input.json" -- '"id":"replay.complete","ok":true'
  hf_why=""; hf_hb="$(field hockeyfun.record_bot state_hash)"; hf_hr="$(field hockeyfun.record_replay state_hash)"
  [ -n "$hf_hb" ] && [ "$hf_hb" = "$hf_hr" ] || hf_why="bot_fun's hash ($hf_hb) is not its replay's ($hf_hr)"
  verdict hockeyfun.record_same_hash "$hf_why" "bot_fun seed 1: bot ${hf_hb:0:16} = replay ${hf_hr:0:16}"
  check hockeyfun.goalie_bot 0 bot "--pack=$hf_pack" --test=tests/bot_goalie.gd --seed=1 "--record=$hf_out/hf_goalie.input.json" -- '"id":"bot.ok","ok":true'
  check hockeyfun.goalie_replay 0 replay "--pack=$hf_pack" "--input=$hf_out/hf_goalie.input.json" -- '"id":"replay.complete","ok":true'
  hf_why=""; hf_gb="$(field hockeyfun.goalie_bot state_hash)"; hf_gr="$(field hockeyfun.goalie_replay state_hash)"
  [ -n "$hf_gb" ] && [ "$hf_gb" = "$hf_gr" ] || hf_why="bot_goalie's hash ($hf_gb) is not its replay's ($hf_gr)"
  verdict hockeyfun.goalie_same_hash "$hf_why" "bot_goalie seed 1: bot ${hf_gb:0:16} = replay ${hf_gr:0:16}"
fi
