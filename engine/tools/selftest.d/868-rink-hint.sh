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

# Lane H2d (25 Nov): the header and the ability plate say the game's own rules and words (G1's Arsenal: a three-minute clock
# shown as "PERIOD 1" over an empty line; its CANNON called SHOTGUN on the base's plate).
#   rink.header         a copy of engine/templates/rink_game on a clock (game.rules.mode timer, 10,800 frames) with a shotgun
#                       held from the start and a skin that calls it a cannon: tests/bot_header.gd (the time left on every
#                       play frame, counting down; FIRST TO 5 for the same game on first-to; "F: CANNON" on the plate)
#   rink.header_window  the same copy captured in a window at frame 400 with the HUD on: the capture passes; the still is
#                       $OUT/rink_header/still.png
rd_o="$OUT/rink_header"
if [ -z "$FILTER" ] || [[ "rink.header" == *"$FILTER"* ]] || [[ "rink.header_window" == *"$FILTER"* ]]; then
  rm -rf "$rd_o"; mkdir -p "$rd_o"; cp -r "$HERE/../templates/rink_game" "$rd_o/pack"; find "$rd_o/pack" -name "*.uid" -delete
  rd_n="$rd_o/pack"; command -v cygpath >/dev/null 2>&1 && rd_n="$(cygpath -m "$rd_n")"
  node -e '
const fs = require("fs"), p = process.argv[1], d = p + "/data/";
const c = JSON.parse(fs.readFileSync(d + "hockey.regular.cartridge.json", "utf8"));
c.id = "clock"; c.title = "Clock";
const r = c.game.rules || {}; delete r.score_to_win; r.mode = "timer"; r.timer_frames = 10800; c.game.rules = r;
c.game.abilities = [{kind: "shotgun", trigger: "mode", charges: 3, magnitude: 1.5, cooldown_frames: 180}];
fs.writeFileSync(d + "clock.cartridge.json", JSON.stringify(c, null, 2));
const m = JSON.parse(fs.readFileSync(d + "match.json", "utf8")); m.cartridge = "clock.cartridge.json";
fs.writeFileSync(d + "match.json", JSON.stringify(m, null, 2));
const s = JSON.parse(fs.readFileSync(d + "skin.json", "utf8")); s.ability_names = {shotgun: "cannon"};
fs.writeFileSync(d + "skin.json", JSON.stringify(s, null, 2));
const pk = JSON.parse(fs.readFileSync(p + "/pack.json", "utf8")); pk.tests.push("tests/bot_header.gd");
fs.writeFileSync(p + "/pack.json", JSON.stringify(pk, null, 2));
' "$rd_n"
fi
rd_still="$rd_o/still.png"; command -v cygpath >/dev/null 2>&1 && rd_still="$(cygpath -m "$rd_still")"
check rink.header 0 bot "--pack=$rd_o/pack" --test=tests/bot_header.gd -- '"id":"bot.completed","ok":true' '"id":"bot.ok","ok":true' 'clock header on [0-9]+ frames'
check rink.header_window 0 capture "--pack=$rd_o/pack" --cam=follow --frame=400 --res=1280x720 --hud=on --test=tests/bot_match_hand.gd "--out=$rd_still" -- '"ok":true,"outcome":"passed"'
