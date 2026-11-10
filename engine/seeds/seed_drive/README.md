# seed.drive: three laps against the clock

One car on a small road loop. Pass four checkpoints in order to complete a lap; do three laps before the 90 second
clock runs out. A striped pad on the near straight fills the nitro tank. Loose cones stand on the road and come back
after 30 seconds. There is no opponent: it is a solo timed drive.

```
bash engine/tools/tl.sh play --pack=engine/seeds/seed_drive        A / D steer, W gas, S reverse, Space brake, Shift nitro
bash engine/tools/tl.sh bot  --pack=engine/seeds/seed_drive        the bot drives three laps
```

## What it shows

| Need | How this seed does it | API |
|---|---|---|
| A road from data | `data/track.json` has one entry in `circuits[]`; the built road node carries its centre line | `TLKit.build_layout`, metadata `tl_centre_line`, `tl_length`, `tl_half_width` on `nodes["loop"]` |
| Placing things on the road | `_road(s, off)`: `s` metres along the centre line, `off` metres to the right. Start position, checkpoints and cones all use it | plain vector code over the centre line |
| A car | the kernel builds the coupe rig and takes sizes and mass from it; tuning comes from `tuning.json` | `TLVehicle.create(opts)`, `drive_from_input(ctx.input, map)` |
| Laps and a clock | `data/rules.json`: `laps_to_win`, `checkpoints`, `time_limit_seconds` | `TLRules.pass_checkpoint("car", index)` from a `TLTrigger` per checkpoint |
| A pad that gives something | a trigger where the layout put the prop `pad`; it fills `car.nitro_charge` | `TLBodies.trigger(&"sphere", radius)`, signal `entered` |
| Things that come back | a spawner keeps one cone on each point and replaces it after its lifetime | `TLSpawner.create(factory, {"points", "max_alive", "lifetime_frames", "jitter"})` |
| A kit part the game may knock over | `_loose_cone()` tags a kit `cone` as a dynamic prop and lets the kernel make its body | `TLBodies.from_part` |
| A chase camera and a fixed one | the first registered view is the one `play` shows | `ctx.cameras.chase(car, opts)`, `ctx.cameras.add_view` |
| A driving aid for HUD or bots | two points on the centre line: `ahead` (steer here) and `far` (slow down for this) | `TLSteer.keep_lane(pos, heading, line, look_ahead, true)` |
| Seeded randomness | each cone lands up to 0.35 m from its place | the spawner's `jitter` draws from `ctx.rng` |

## Files

- `data/track.json` venue. The script looks up two ids: `loop` (the road) and `pad` (the first strip of the nitro pad).
- `data/rules.json` `{"sides": ["car"], "laps_to_win": 3, "checkpoints": 4, "time_limit_seconds": 90}`.
- `data/tuning.json` start place, checkpoint shares of the lap, cones, car tuning (any `TLVehicle` member).
- `scripts/main.gd` 130 lines of glue.
- `tests/bot_laps.gd` the bot.

## How the bot drives and how it decides it won

It uses the player's actions only. It steers its nose toward `ahead`; it reads how far `far` is off to one side as
"a bend is coming" and slows from 19 m/s toward 10 m/s in time; it holds `nitro` after the pad while the road ahead
is straight. `ok` is true when the rules say `state == "over"`, `winner == "car"`, `reason == "laps"` with three laps,
the pad was visited three times and nitro started at least once. A run that ends with `reason == "time"` fails.
Measured: three laps in 58.6 s, never more than 1.2 m off the centre line.

## To make it your own

Move the control points in `track.json`: checkpoints, cones and the start follow, because all of them are placed
by `s`. Keep the pad's `s` in `track.json` on a straight. More laps or a tighter clock are one number in `rules.json`.
