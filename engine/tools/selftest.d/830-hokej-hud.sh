# Hokej's screen (lane K5 of the hockey port): thirdjam's HUD and match flow, HEAD 8dc713c6.
#   hokej.hud_rules   thirdjam's own assertions on the pure HUD rules, then a recorded match (its human played by thirdjam's
#                     playerbot) fed frame by frame to the pack's HUD: MATCH card, markers under cards, YOU tag, faceoff dial,
#                     panel, take, possession. More than 100,000 checks and none failed; a stopped run is a FAIL.
#   hokej.hud_layer   the kernel's TLHudLayer: TLHud.add_layer gives one layer per id, in layout units of 1080 a screen.
check hokej.hud_rules 0 bot "--pack=$HERE/../packs/hokej" --test=tests/bot_hud_rules.gd -- '"id":"bot.completed","ok":true' '"id":"bot.ok","ok":true' '[0-9]{6} checks, 0 failed'
if [ -z "$FILTER" ] || [[ "hokej.hud_layer" == *"$FILTER"* ]]; then
  why=""
  grep -q '^func add_layer(id: StringName, unit_h: float = 1080.0) -> TLHudLayer:' "$HERE/../kernel/api/tl_hud.gd" || why="TLHud.add_layer is missing"
  grep -q '^class_name TLHudLayer' "$HERE/../kernel/api/tl_hud_layer.gd" || why="${why:+$why; }TLHudLayer is missing"
  grep -q 'TLHudLayer' "$HERE/../kernel/API.md" || why="${why:+$why; }API.md does not document TLHudLayer"
  verdict hokej.hud_layer "$why"
fi
