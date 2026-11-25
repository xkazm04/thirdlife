# The effect boost's glow on the figure (lane H2b, 25 Nov), and (below) the budget class a Create game gets (lane H2c): boost_look.gd tells a skater's figure SetBoost(kind) when the
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

# H2c (25 Nov, the Director's ruling: a game made in Create is a dungeon, judged by the solo budget unless a person places
# it in the village). The runner's invariants --home, which the Foreman passes for its jobs (village for a job on a village
# lot, create otherwise), decides the budget class of a pack outside the engine's tree (a Create job's pack always is).
#   budget.home   kernel/examples/pack_min copied OUTSIDE the engine's tree, invariants 600 frames three ways: --home=create
#                 -> invariants.solo_budget ("a game made in Create"); --home=village -> invariants.many_budget ("placed in
#                 the village"); no --home -> invariants.many_budget ("not a pack of the engine's tree ... --home"); and
#                 --home=elsewhere is refused (not_run, exit 2)
bh_o="$OUT/budget_home"
if [ -z "$FILTER" ] || [[ "budget.home" == *"$FILTER"* ]]; then
  rm -rf "$bh_o"; mkdir -p "$bh_o"; cp -r "$HERE/../kernel/examples/pack_min" "$bh_o/pack"; find "$bh_o/pack" -name "*.uid" -delete
fi
check budget.home_create 0 invariants "--pack=$bh_o/pack" --frames=600 --bot-frames=600 --home=create -- '"id":"invariants.solo_budget","ok":true' 'a game made in Create'
check budget.home_village 0 invariants "--pack=$bh_o/pack" --frames=600 --bot-frames=600 --home=village -- '"id":"invariants.many_budget","ok":true' 'placed in the village'
check budget.home_none 0 invariants "--pack=$bh_o/pack" --frames=600 --bot-frames=600 -- '"id":"invariants.many_budget","ok":true' 'not a pack of the engine'
check budget.home_bad 2 invariants "--pack=$bh_o/pack" --frames=600 --home=elsewhere -- '--home must be create or village'
