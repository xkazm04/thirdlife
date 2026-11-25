# The effect boost's glow on the figure (lane H2b, 25 Nov): boost_look.gd tells a skater's figure SetBoost(kind) when the
# snapshot's Boosts (RinkCore 1.4) changes for him, as thirdjam's game mode does from UJamEffectSystem::GetBoostKindFor.
#   rink.boost_glow  cores/rink/view/boost_glow_case.gd, headless: two recording pawns, five frames: the figure is told on a
#                    change only, never when never boosted, and told "" when a core without Boosts reports nothing
if [ -z "$FILTER" ] || [[ "rink.boost_glow" == *"$FILTER"* ]]; then
  why=""; note=""
  bg_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  bg_e="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && bg_e="$(cygpath -am "$bg_e")"
  bg_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$bg_g" --headless --path "$bg_e" --script res://cores/rink/view/boost_glow_case.gd 2>&1 | tr -d '\015')"
  bg_l="$(echo "$bg_out" | grep -m1 '^BOOSTGLOW')"
  [[ "$bg_l" == "BOOSTGLOW ok=true"* ]] || why="${bg_l:-no BOOSTGLOW line (the run stopped)}"
  bg_err="$(echo "$bg_out" | grep -m1 'SCRIPT ERROR')"
  [ -z "$bg_err" ] || why="${why:+$why; }$bg_err"
  note="$(echo "$bg_l" | cut -c19-200)"
  verdict rink.boost_glow "$why" "$note"
fi
