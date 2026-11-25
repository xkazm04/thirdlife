# A game's own hint line has a slot in the base and never covers the commentator's caption (lane H2b, 25 Nov; G1's Arsenal
# drew "F: BUBBLE  Green spots reload it" as its own bottom label, over the caption for the first ten seconds of every match).
#   rink.hint_slot    a copy of engine/templates/rink_game, tests/bot_hint.gd: a recorded match fed to the base's own hud.gd with
#                     a hint on every frame, three screen shapes: the hint drawn on every frame and never touching the
#                     caption's plate or the faceoff hint's
#   rink.hint_window  the same copy with main.gd saying a hint through the meta (ctx.root "rink_hint"), captured in a window at
#                     frame 200 with the HUD on (the opening caption is up): the capture passes; the still is
#                     $OUT/rink_hint/still.png
rh_t="$HERE/../templates/rink_game"
rh_o="$OUT/rink_hint"
if [ -z "$FILTER" ] || [[ "rink.hint_slot" == *"$FILTER"* ]] || [[ "rink.hint_window" == *"$FILTER"* ]]; then
  rm -rf "$rh_o"; mkdir -p "$rh_o"; cp -r "$rh_t" "$rh_o/pack"; find "$rh_o/pack" -name "*.uid" -delete
  # the game's own script line: say the hint every simulated frame (the first statement of _pack_tick)
  # bot_hint.gd is the base's own check, not in pack.json (a game's verification does not run it): the copy registers it
  node -e 'const fs = require("fs"), f = process.argv[1] + "/pack.json"; const m = JSON.parse(fs.readFileSync(f, "utf8")); m.tests.push("tests/bot_hint.gd"); fs.writeFileSync(f, JSON.stringify(m, null, 2));' "$(cd "$rh_o/pack" && pwd -W 2>/dev/null || pwd)"
  sed -i 's/^func _pack_tick(\(.*\)$/func _pack_tick(\1\n\tctx.root.set_meta(\&"rink_hint", "F: BUBBLE  Green spots reload it")/' "$rh_o/pack/scripts/main.gd"
fi
rh_still="$rh_o/still.png"; command -v cygpath >/dev/null 2>&1 && rh_still="$(cygpath -m "$rh_still")"
check rink.hint_slot 0 bot "--pack=$rh_o/pack" --test=tests/bot_hint.gd -- '"id":"bot.completed","ok":true' '"id":"bot.ok","ok":true' 'hint drawn on [0-9]+ of [0-9]+ frames'
if [ -z "$FILTER" ] || [[ "rink.hint_window" == *"$FILTER"* ]]; then
  grep -q 'ctx.root.set_meta(&"rink_hint"' "$rh_o/pack/scripts/main.gd" || verdict rink.hint_window "the copy's main.gd has no _pack_tick to say the hint in"
fi
check rink.hint_window 0 capture "--pack=$rh_o/pack" --cam=follow --frame=200 --res=1280x720 --hud=on --test=tests/bot_match_hand.gd "--out=$rh_still" -- '"ok":true,"outcome":"passed"'
