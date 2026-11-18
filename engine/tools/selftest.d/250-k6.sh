# Run both held-ball examples in a world with per-pack physics spaces.
# Compare each skater's hash with its solo run.

# --- K6 ---
# The ball-under-the-feet test asks the pack's own physics space: in a world (a space per pack) ex_held and ex_held_big
# hash as they do alone. Before the cure the query saw an empty space there and a held or shot puck carried the skater.
if [ -z "$FILTER" ] || [[ "k6.world_ball_floor" == *"$FILTER"* ]]; then
  out="$(bash "$HERE/world.sh" alone "--packs=$EX/ex_held_big,$EX/ex_held" --mode=bot --frames=2000 2>&1)"
  why=""; echo "$out" | grep -q '^PASS world.alone' || why="a pack hashes differently in a world: $(echo "$out" | grep -E 'DIFFERENT|FAIL' | head -3 | tr '\n' ' ')"
  [ "$(echo "$out" | grep -c '| same$')" = 2 ] || why="${why:+$why; }not both packs reported same"
  verdict k6.world_ball_floor "$why" "ex_held_big and ex_held: world = alone"
fi

