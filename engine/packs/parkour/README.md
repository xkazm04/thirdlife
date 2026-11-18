# Timber Run

Run `node devx/bin/tl.mjs play parkour`. In the village, enter the scaffold course on the south side of the road, west of the walker plot. Beat the 60-second clock and your best time this session.

| Control | Action |
|---|---|
| WASD or arrows | Move relative to the orbit camera |
| Shift | Run |
| Space | Jump |
| C | Slide while running on the ground |
| Right-drag / wheel | Orbit / zoom |
| R | Start another attempt |

Run up to the striped take-off boards. Jump the 3.4 m gap to the first checkpoint. Keep running, jump the 3.8 m gap, and **press C as your feet land**. The landing earns the second checkpoint. The striped beam sits 5.5 m into this deck and leaves 1.52 m of clearance. A standing runner is 1.80 m tall and slides at 0.84 m.

If the beam stops you, **tap C to return to the landing stripe**. Keep running forward and tap C again to slide. Crossing under the beam earns the third checkpoint. Ride the 65-degree concrete chute down and cross the finish stripe. A fall returns you to your last checkpoint while the clock keeps running. R clears the attempt and keeps the session best.

## Verification

The course layout is the same at every seed. A clean `perfect`-hand run takes 338 race frames (5.633 seconds at 60 Hz). The runner reports 340 frames because the bot observes the finished rules on its following tick.

| Test | What must happen |
|---|---|
| `tests/bot_course.gd` | Jump and land beyond both spans, enter a run slide within two samples of landing the chain, travel under the beam in slide mode, descend at least 2 m in slope mode and finish without a fall. |
| `tests/bot_geometry.gd` | Each positive gap fits the measured 4.95 m airborne reach at 9 m/s. The beam fits only the short capsule. The chute exceeds the 55-degree walk limit. |
| `tests/bot_obstacles.gd` | Running off each lip without jumping returns the runner to its checkpoint. A standing runner pressing forward and trying a jump stays at the near face of the beam. R resets the clock and sends the runner back to the start. |
| `tests/bot_ladder_retry_regular.gd` | A regular hand holds forward, runs into the beam, uses C to return to the landing checkpoint, passes under the beam in slide mode and finishes. |

Run the pack checks from the repository root.

```sh
bash engine/tools/tl.sh lint --pack=engine/packs/parkour
bash engine/tools/tl.sh bot --pack=engine/packs/parkour --test=tests/bot_course.gd --seed=1
node devx/bin/tl.mjs ladder --pack engine/packs/parkour --cells retry_regular --seeds 20
node devx/bin/tl.mjs check --tier full --only packs
bash engine/tools/selftest.sh walk.biped_parity
```

To reproduce the negative case, copy the pack to a scratch folder and set `chain_gap_m` to `12.0` in its `data/course.json`. Set the shell variable `bad` to the scratch pack path and run each command below. Both exit 1. The geometry bot identifies gap 2, and the input bot falls after clearing only gap 1.

```sh
bash engine/tools/tl.sh bot --pack="$bad" --test=tests/bot_geometry.gd
bash engine/tools/tl.sh bot --pack="$bad" --test=tests/bot_course.gd
```

The play view is `orbit`. Capture views are `overview`, `jump`, `under_bar` and `chute`. For the moving views pass `--test=tests/bot_course.gd` to the capture verb. Frames 73, 228 and 288 show the jump, bar and descent.
