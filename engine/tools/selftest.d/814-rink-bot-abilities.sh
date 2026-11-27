# Lane S4-core (27 Nov, spike arm A): patch 0005 of the thirdlife core, the bots' abilities and the dive (CARTRIDGE.md section 1).
#   rink.bot_abilities  every 0005 switch at 0 hashes as RinkCore on every frame of thirdjam's Shotgun mode; switched on, bots use the
#                       shotgun and dive, the same seed hashes the same twice; a bad value and an unknown key are refused
# A missing thirdlife build is a FAIL that names the command; it is never skipped as a pass.
if [ -z "$FILTER" ] || [[ "rink.bot_abilities" == *"$FILTER"* ]]; then
  ba_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  ba_e="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && ba_e="$(cygpath -am "$ba_e")"
  why=""; note=""
  if [ ! -f "$HERE/../cores/rink/bin/rink_core_thirdlife.windows.template_debug.x86_64.dll" ]; then
    why="the thirdlife core is not built (bash engine/tools/rink.sh build thirdlife)"
  else
    ba_out="$(MSYS_NO_PATHCONV=1 timeout 900 "$ba_g" --headless --path "$ba_e" --script res://cores/rink/tools/rink_bot_abilities.gd -- --seed=1 --frames=3600 2>&1 | tr -d '\015')"
    ba_l="$(echo "$ba_out" | grep -m1 '^PASS  rink bot abilities\|^FAIL  rink bot abilities\|^NOT RUN  rink bot abilities')"
    [[ "$ba_l" == "PASS  rink bot abilities"* ]] || why="${ba_l:-no line (the run stopped)}"
    note="$(echo "$ba_out" | grep -m1 '^BOTAB on' | cut -c7-200)"
  fi
  verdict rink.bot_abilities "$why" "$note"
fi
