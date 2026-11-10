# seed.wall: knock the wall down in sixty seconds

A walker in a dirt yard throws heavy balls at a row of six concrete barrier blocks. A block breaks into the pieces
the kit prepared for it once it has taken enough impact. Every piece knocked more than 0.6 m out of its place is a
point. Reach 40 points before the 60 second clock runs out.

```
bash engine/tools/tl.sh play --pack=engine/seeds/seed_wall        WASD walk (Shift runs), Space throws where you face
bash engine/tools/tl.sh bot  --pack=engine/seeds/seed_wall        the bot knocks the wall down
```

## What it shows

| Need | How this seed does it | API |
|---|---|---|
| Destructible scenery from data | six `barrier_wall` props in `data/yard.json`, ids `block_0` .. `block_5`; each gets its own fracture | `TLFracture.attach(part, {"hp", "threshold", "kick", "scatter"})`, signals `broke`, `settled`, member `pieces` |
| Damage from impacts | nothing to write: a `TLBall` reports each hit, the block's `TLDamage` takes `100 x (J - T) / T` health for an impact of J N*s above the threshold T | `fracture.damage.hp` |
| A character | the kernel builds the biped rig; camera-relative walking | `TLBiped.create(opts)`, `drive_from_input(ctx.input, map, cam.yaw_basis())` |
| Carrying and throwing | the ball rides in front of the walker's chest, then leaves with a velocity | `TLBall.hold(player, offset)`, `TLBall.release(velocity)` |
| Rig clips from game events | `carry` while holding a ball, back to walking after the throw, `cheer` on a win | `player.rig.play(&"carry")`, `play(&"")` |
| Score and a time limit | `data/rules.json`: `score_to_win` and `time_limit_seconds`; `reason` tells which ended the game | `TLRules.add_score`, signal `finished(winner, reason)` |
| Effects and sound | dust and debris when a block breaks, a puff on a hard hit; whistle, break, horn. Contact sounds play by themselves | `TLVfx.burst`, `TLAudio.play`, `TLAudio.count` |
| A camera that follows the player | an orbit camera behind and above the walker, plus a fixed view from the layout | `ctx.cameras.orbit(player, opts, &"player")` |
| Seeded randomness | each block is up to 15 % tougher or weaker; the kernel also scatters the pieces from `ctx.rng` | `ctx.rng.randf_range` |

Signal handlers here only queue an event (`_events.append([...])`). `_pack_tick` acts on the queue as its last
step. Two reasons: bodies must not be created or moved inside a physics callback, and a bot must never see the
rules say "over" before the pack has reacted to it.

## Files

- `data/yard.json` venue. The script uses every prop whose id starts with `block_`, and the layout's `spawn`.
- `data/rules.json` `{"sides": ["player"], "score_to_win": 40, "time_limit_seconds": 60}`.
- `data/tuning.json` walker, ball pool, throw, block toughness, camera.
- `scripts/main.gd` 131 lines of glue.
- `tests/bot_knock.gd` the bot.

## How the bot plays and how it decides it won

It uses the player's actions only. It lines up with the nearest standing block, 5 to 9.5 m in front of the wall,
creeps forward (a small "forward" also turns the walker to face the wall) and taps `throw` whenever it holds a ball
and faces the wall; too close, it walks out and comes in again. When every block is broken it throws at the rubble.
`ok` is true when the rules say `state == "over"` with `reason == "score"`, the HUD says "THE WALL IS DOWN", one
`break` sound was recorded per broken block and the horn sounded once. `reason == "time"` fails.
Measured: 40 to 45 pieces down in 18.5 to 21.2 s with 15 to 17 throws, at seeds 1 to 5.

## To make it your own

A taller or longer wall is `params` of the blocks in `yard.json`. Tougher blocks are `hp` in `tuning.json`; a
lighter ball needs a lower `threshold` or it does no damage at all (an 8 kg ball at 19 m/s is about 150 N*s; the
default threshold of concrete is 260 N*s). A kick instead of a throw is the same `release` with a flat velocity.
