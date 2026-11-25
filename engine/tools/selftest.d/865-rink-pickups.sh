# Pickups seen (lane H2, 25 Nov): the rink core reports the effect system's pickups and events (SNAPSHOT.md v1.4), the base
# draws them. Before, a cartridge's game.pickups played unseen (lane E1b's report: RinkCore 1.3 kept them to the effect system).
#   rink.snapshot_pickups  tools/rink_pickups.gd: thirdjam's Arsenal cartridge, 3,600 frames: every pickup that lands in the
#                          snapshot's Pickups has its pickup_spawn in EffectEvents on that frame at its Pos, every one that
#                          leaves has its pickup_take; some are taken, boosts are seen; a second core never asked for a snapshot
#                          hashes the same on every frame; the regular cartridge reports none
#   rink.pickups_drawn     a copy of engine/templates/rink_game with a cartridge of all five built-in pickup kinds: tests/bot_toys.gd
#                          plays 2,400 frames, pickups are put down and taken, and the beacons standing are the core's
if [ -z "$FILTER" ] || [[ "rink.snapshot_pickups" == *"$FILTER"* ]]; then
  why=""; note=""
  if [ ! -f "$HERE/../cores/rink/bin/rink_core.windows.template_debug.x86_64.dll" ]; then why="the extension is not built (run: bash engine/tools/rink.sh build)"; else
    rp_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
    rp_e="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && rp_e="$(cygpath -am "$rp_e")"
    rp_out="$(MSYS_NO_PATHCONV=1 timeout 600 "$rp_g" --headless --path "$rp_e" --script res://cores/rink/tools/rink_pickups.gd -- --seed=1 --frames=3600 2>&1 | tr -d '\015')"
    rp_l="$(echo "$rp_out" | grep -m1 '^PASS  rink pickups\|^FAIL  rink pickups')"
    [[ "$rp_l" == "PASS  rink pickups"* ]] || why="${rp_l:-no pickups line (the run stopped)}"
    [[ "$rp_l" == *"(3600 of 3600 frames)"* ]] || [ -n "$why" ] || why="fewer than 3,600 frames compared: $rp_l"
    note="$(echo "$rp_out" | grep -m1 '^PICKUPS' | cut -c9-260)"
  fi
  verdict rink.snapshot_pickups "$why" "$note"
fi

rp_t="$HERE/../templates/rink_game"
rp_o="$OUT/rink_pickups"
if [ -z "$FILTER" ] || [[ "rink.pickups_drawn" == *"$FILTER"* ]]; then
  rm -rf "$rp_o"; mkdir -p "$rp_o"; cp -r "$rp_t" "$rp_o/pack"; find "$rp_o/pack" -name "*.uid" -delete
  rp_n="$rp_o/pack"
  if command -v cygpath >/dev/null 2>&1; then rp_n="$(cygpath -m "$rp_n")"; fi
  node -e '
const fs = require("fs"), d = process.argv[1] + "/data/";
const c = JSON.parse(fs.readFileSync(d + "hockey.regular.cartridge.json", "utf8"));
c.id = "pickups"; c.title = "Pickups";
c.game.pickups = [
  {kind: "speed", spawn_every_frames: 120, duration_frames: 300, magnitude: 1.5, max_on_ice: 2},
  {kind: "precision", spawn_every_frames: 150, duration_frames: 300, max_on_ice: 2},
  {kind: "heavy_puck", spawn_every_frames: 180, duration_frames: 300, max_on_ice: 1},
  {kind: "big_puck", spawn_every_frames: 210, duration_frames: 300, max_on_ice: 1},
  {kind: "reverse_other", spawn_every_frames: 240, duration_frames: 200, max_on_ice: 1}];
fs.writeFileSync(d + "pickups.cartridge.json", JSON.stringify(c, null, 2));
const m = JSON.parse(fs.readFileSync(d + "match.json", "utf8")); m.cartridge = "pickups.cartridge.json"; m.difficulty = "rookie";
fs.writeFileSync(d + "match.json", JSON.stringify(m, null, 2));
' "$rp_n"
fi
check rink.pickups_drawn 0 bot "--pack=$rp_o/pack" --test=tests/bot_toys.gd -- '"id":"bot.completed","ok":true' '"id":"bot.ok","ok":true' 'pickups put down [1-9][0-9]*, taken [1-9]'
