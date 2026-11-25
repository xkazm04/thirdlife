# The rink game base (lane E1): engine/templates/rink_game is hokej's generic part, byte for byte, and plays.
#   rink.template        the shared files (scripts/**, gen/**, assets/**, the carried tests and data) equal hokej's
#   rink.template_bots   the template's bot_skin and bot_first_match pass headless (ROOKIE to the end card)
rt_t="$HERE/../templates/rink_game"
rt_h="$HERE/../packs/hokej"
if [ -z "$FILTER" ] || [[ "rink.template" == *"$FILTER"* ]]; then
  why=""; n=0
  for f in $(cd "$rt_t" && find scripts gen assets -type f ! -name "*.import" ! -name "*.uid" | sort) tests/bot_match_hand.gd tests/bot_first_match.gd tests/bot_skin.gd \
      data/hud_barks.json data/gym.json data/view.json data/skin.json data/hockey.regular.cartridge.json; do
    n=$((n+1))
    if [ ! -f "$rt_h/$f" ]; then why="${why:+$why; }$f: not in hokej"; elif ! cmp -s "$rt_t/$f" "$rt_h/$f"; then why="${why:+$why; }$f differs from hokej"; fi
  done
  [ "$n" -gt 20 ] || why="${why:+$why; }only $n files compared (a stopped run)"
  verdict rink.template "$why" "$n files equal hokej's"
fi
check rink.template_bots 0 bot "--pack=$rt_t" --test=tests/bot_first_match.gd -- '"id":"bot.completed","ok":true' '"id":"bot.ok","ok":true' 'level rookie'
