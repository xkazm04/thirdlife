# Lint the six kernel example packs, run their bots and check invariants.
# Their reports expose the measured laws of motion and game state.

# ---------------------------------------------------------------- kernel examples: laws and primitives, by bot
# each example is linted (no fence hit, no bypass) and played by its own bot; the bot decides ok from measured numbers
for ex in slide bounce shuffle wall walker car; do
  check "ex.$ex.lint" 0 lint "--pack=$EX/ex_$ex" -- '"bypasses":\[\]'
done
check ex.slide.bot 0 bot "--pack=$EX/ex_slide" --frames=3000 -- '"rubber_on_ice_friction_measured":0\.1[0-9]*,"rubber_on_ice_friction_law":0\.1,' '"wood_on_asphalt_friction_law":0\.5,'
check ex.bounce.bot 0 bot "--pack=$EX/ex_bounce" --frames=3000 -- '"rubber_on_ice_restitution_law":0\.3,' '"spawned":[0-9]+'
check ex.shuffle.bot 0 bot "--pack=$EX/ex_shuffle" --frames=3000 -- '"gate_passes":2,'
check ex.wall.bot 0 bot "--pack=$EX/ex_wall" --frames=3000 -- '"pieces":18,'
check ex.walker.bot 0 bot "--pack=$EX/ex_walker" --frames=3000 -- '"walk_speed":2\.[23]'
check ex.car.bot 0 bot "--pack=$EX/ex_car" --frames=5400 -- '"grip_law_ice":0\.1,'
check ex.car.invariants 0 invariants "--pack=$EX/ex_car" --frames=1200 -- '"id":"invariants.determinism","ok":true'
check ex.wall.invariants 0 invariants "--pack=$EX/ex_wall" --frames=900 -- '"id":"invariants.determinism","ok":true'
check ex.walker.invariants 0 invariants "--pack=$EX/ex_walker" --frames=900 -- '"id":"invariants.determinism","ok":true'
check ex.bounce.invariants 0 invariants "--pack=$EX/ex_bounce" --frames=900 -- '"id":"invariants.determinism","ok":true'
check ex.shuffle.invariants 0 invariants "--pack=$EX/ex_shuffle" --frames=600 -- '"id":"invariants.determinism","ok":true'
check ex.slide.invariants 0 invariants "--pack=$EX/ex_slide" --frames=600 -- '"id":"invariants.determinism","ok":true'

