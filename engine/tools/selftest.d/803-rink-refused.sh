# D27 item 8 (lane T-editor, 27 Nov): a rink game whose core refuses its cartridge or rules file says so and stops; it never
# goes on with a null core (S4: main's exe refused "unknown rule bot_ability_share" in data/harbour.rules.json, then crashed
# with exit 139). The fix is the base's (engine/templates/rink_game/scripts/main.gd, byte-equal in packs/hokej).
#   rink.refused_smoke     the base with a rules file of an unknown switch: the 600 frames run to the end with exactly the
#                          core's error and the base's plain-words line (2 errors), not a cascade stopped by the watchdog
#   rink.refused_dungeon   the same pack as a dungeon through boot (the exe's scene), headless: it ends on its frames, no crash
rr_t="$HERE/../templates/rink_game"
rr_p="$OUT/rink_refused"
if [ -z "$FILTER" ] || [[ "rink.refused" == *"$FILTER"* ]]; then
  rm -rf "$rr_p"; cp -r "$rr_t" "$rr_p"; find "$rr_p" -name "*.uid" -delete
  printf '{"schema": "tl.rink.rules/1", "rules": {"bot_ability_share": 0.7}}\n' > "$rr_p/data/hockey.regular.rules.json"
fi
check rink.refused_smoke 1 smoke "--pack=$rr_p" --frames=600 -- '"detail":"2 errors in 600 frames"' 'unknown rule' 'so the game cannot start' '"id":"smoke.watchdog","ok":true'
if [ -z "$FILTER" ] || [[ "rink.refused_dungeon" == *"$FILTER"* ]]; then
  why=""
  rr_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  rr_e="$(cd "$HERE/.." && pwd)"; rr_d="$rr_p"; rr_o="$OUT/rink_refused_dungeon.json"
  command -v cygpath >/dev/null 2>&1 && { rr_e="$(cygpath -am "$rr_e")"; rr_d="$(cygpath -am "$rr_d")"; rr_o="$(cygpath -am "$rr_o")"; }
  rm -f "$rr_o"
  MSYS_NO_PATHCONV=1 timeout 180 "$rr_g" --headless --path "$rr_e" res://boot/boot.tscn -- "--dungeon=$rr_d" --frames=600 "--out=$rr_o" > "$OUT/rink_refused_dungeon.log" 2>&1
  rr_rc=$?
  [ "$rr_rc" = 139 ] && why="crashed (exit 139)"
  [ "$rr_rc" = 124 ] && why="did not end in 180 s"
  grep -q '"why":"frames"' "$rr_o" 2>/dev/null || why="${why:+$why; }the dungeon did not end on its frames (see $OUT/rink_refused_dungeon.log)"
  verdict rink.refused_dungeon "$why" "exit $rr_rc, ended on its frames"
fi
