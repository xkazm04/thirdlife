# Timber Run

Enter the scaffold yard west of the walker plot from the village road, or play with `node devx/bin/tl.mjs play parkour`. Reach the two red flags on the tower within 60 seconds. The outgoing high line and lower return lane share a 50 × 28 m plot.

| Control | Action |
|---|---|
| WASD or arrows | Move relative to the orbit camera |
| Shift | Run |
| Space | Jump |
| C | Slide from a run. When the retry prompt appears at the low beam, return to the landing stripe |
| Right-drag / wheel | Orbit / zoom |
| R | Restart the race and pendulum. Keep this session’s best splits and best run |

Parkour uses the stock walking moves. In the operator’s windowed visit, F was pressed twice on stage alongside Space, Shift and W. The 449-sample stage record contained only jump, forward and run. After leaving, F took the village walker 11.077 m up. [Flight boundary check](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/round2/fly-probe-visit.txt)

## Course

1. **High line.** Run and jump the 3.4 m span. Jump the 3.8 m gap and press C on landing to slide beneath the 1.52 m beam. If it stops you standing, tap C at the retry prompt, run forward, then press C again. The walker automatically slope-slides down the 65° chute to the first split.
2. **Swing yard.** Follow the rising bend. Steer right to the first timber pad, turn back across the second and jump onto the centre of the 1.05 m balance beam. The pad centres are 2.15 m and 1.15 m right of the beam centreline. They face opposite ways at 22° and bank 8°. Read the counterweight at the beam’s cross-stripe. Keep running when the weight is swinging clear. If it is coming across your path, brake before the gantry and set off when you can reach the other side. A hit returns you to the near end of the beam while both the race and the pendulum keep going. At this checkpoint you face down the beam. If a side key was held through the fall, release it to steer that way again. You can run forward immediately. The far end records split two.
3. **Summit.** Run up the 3.2 m concrete bank and jump from the wooden lip across a 2.90 m gap to a crest 0.72 m higher. Ease off Shift on the tower. Jump the two 0.78 m ledges, then cross the summit stripe between the flags.

Twelve ordered checkpoints register landings and crossings. Falling costs the time it takes to recover. The HUD shows the current stage, its elapsed time and session best, and the current and best full-run times. The finish board shows all three splits. The pendulum swings ±56° over 156 physics frames at 60 Hz.

## Verification

On seeds 1 and 2 the perfect hand finished with zero falls and zero swing contacts in **806 race frames (13.433 s)**. Its splits were **338, 286 and 182**. The runner observed the finish at frame 808. On the default approach the bot braked for 18 frames. Across twelve matched start delays per seed, charging the weight caused six checkpoint returns and cost 5–18 frames against the timed runner. The other six approaches stayed open and both runners recorded the same finish times. [Phase results](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/round2/r3/verify/bot_swing_phases-1.json)

| Test in `tests/` | What it measures |
|---|---|
| `bot_course.gd` | Airborne crossings and grounded landings on both high gaps, slide within two samples of landing, slide inside the bar, over 2 m of slope descent, both pad landings, a grounded crossing of the swing, running flight to the crest, airborne ascent of both tower faces and all three splits. A clean finish requires zero falls and hits. |
| `bot_swing_phases.gd` | Twelve matched start delays. The blind runner keeps running even after a strike. Each strike must return it to the approach checkpoint with the first split intact. The timed runner must finish every lap clean and beat every struck run. When the blind runner crosses cleanly both runners must record the same time. |
| `bot_return_controls.gd` | Six omissions and a clean control. Straight ahead misses pad one. Keeping the first-pad line misses the beam. Skipping the second hop or the wall jump causes a fall. Withholding tower jumps leaves the walker below the first ledge for 90 ticks. Holding run through the tower with the same jump cues overshoots the summit approach. |
| `bot_beam_recovery.gd` | Fall off each side and hold the old strafe through respawn. Stay on the centreline, move forwards and turn again on a fresh press. |
| `bot_geometry.gd` | Checks horizontal and raised jump reach, slide clearance, chute angle, offset and spacing of pads, beam approach, maximum swing opening and minimum crossing time, and both tower rises. |
| `bot_obstacles.gd` | Omitting either high jump returns to its checkpoint. Running and jumping without sliding stops at the bar. R clears the attempt. |
| `bot_wall.gd` | A 4.50 m/s walking jump falls short. The same hand returns to the run-up, clears the crest at running speed and finishes. |
| `bot_splits.gd` | R between two finishes. An 80-frame delayed second start gives a slower race and a faster second stage. The HUD’s underlying split and full-run records keep each best independently. |
| `bot_ladder_course_{newcomer,regular,sharp}.gd` | Try a landing slide, use C to recover if blocked, slide inside the bar and finish within the clock. |
| `bot_ladder_retry_{newcomer,regular,sharp}.gd` | Deliberately hit the bar standing, use C to retry, slide under it and finish at the tower. |

```sh
bash engine/tools/tl.sh lint --pack=engine/packs/parkour
bash engine/tools/tl.sh bot --pack=engine/packs/parkour --test=tests/bot_course.gd --seed=1
bash engine/tools/tl.sh bot --pack=engine/packs/parkour --test=tests/bot_swing_phases.gd --seed=1
node devx/bin/tl.mjs ladder --pack engine/packs/parkour --cells course_newcomer,course_regular,course_sharp,retry_newcomer,retry_regular,retry_sharp --seeds 20
node devx/bin/tl.mjs check --tier full --only packs,world
node devx/bin/tl.mjs check --tier fast
```

### Difficulty by hand

Each ladder level uses one input policy across its hands. It calls for a high-line jump 1.95 m before each lip, uses common pad take-off and steering cues, reads the same pendulum phase and approach speed, and uses the same wall and tower take-offs. Only the profile passed to `TLHand.create` changes. The retry drill changes the first slide instruction for every hand. The separately scripted perfect-hand proof above uses a 0.85 m high-line take-off lead and the same return driver.

The controller lets one side tap reach the controls and release before requesting another. After a fall it measures lateral travel from the respawn position. On a C retry it requests the slide 3.0 m before the bar. The win still requires an active slide inside the opening.

Each column covers seeds 1–20 at 60 Hz. Mean race frames include timeouts. The newcomer’s repeated beam falls prompted the change. Its course mean fell by 550 frames while the perfect-hand route still takes 806. [Before measurements](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/round2/r3/ladder-before.txt) · [After measurements](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/round2/r3/ladder-after.txt) · [Design decision](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/round2/astra-report-3.md)

| Level | TLHand | Wins before | Wins after | Mean frames before | Mean frames after | Mean seconds after |
|---|---|---:|---:|---:|---:|---:|
| Course | newcomer | 17/20 | 20/20 | 2,316 | 1,766 | 29.43 |
| Course | regular | 20/20 | 20/20 | 971 | 970 | 16.17 |
| Course | sharp | 20/20 | 20/20 | 845 | 841 | 14.02 |
| Forced C retry | newcomer | 17/20 | 20/20 | 2,042 | 1,698 | 28.30 |
| Forced C retry | regular | 20/20 | 20/20 | 1,041 | 1,062 | 17.70 |
| Forced C retry | sharp | 20/20 | 20/20 | 908 | 898 | 14.97 |

### Impossibility cases

Make one data change at a time in a scratch copy, leaving the shipped pack playable. Run both commands below. In each case the bot completes with exit 1 and only `bot.ok` fails.

| File in `data/` | Single change | Observed failure |
|---|---|---|
| `course.json` | `chain_gap_m = 12` | The second gap exceeds the measured 4.95 m reach. The first still clears. |
| `course.json` | `bar_clearance_m = 0.55` | Even the 0.84 m sliding capsule stops at the bar. |
| `return.json` | `pad_spacing_m = 13` | The opposing pad edges are at least 8.78 m apart. The runner falls after pad one. |
| `return.json` | `pad_offsets_m = [11, 1.15]` | At least 6.76 m separates the corner from pad one. The runner falls before landing on it. |
| `return.json` | `beam_entry_offset_m = 12` | The nearest beam edge is at least 9.89 m past pad two. |
| `return.json` | `swing_degrees = 0` | The weight covers the beam permanently. A crossing attempt strikes it and returns to the near checkpoint. |
| `return.json` | `swing_period_frames = 12` | The half-cycle lasts 6 frames. Even a straight sprint needs at least 15 to clear the weight and capsule. Waiting times out, charging takes a hit. |
| `return.json` | `wall_crest_rise_m = 2.4` | The crest exceeds the 1.00 m jump apex above the lip. |
| `return.json` | `tower_step_rise_m = 1.85` | The first high ledge stops the runner until timeout. |

```sh
bash engine/tools/tl.sh bot --pack="$bad" --test=tests/bot_geometry.gd --seed=1
bash engine/tools/tl.sh bot --pack="$bad" --test=tests/bot_course.gd --seed=1
```

There is also a negative control for the timing test itself. In a scratch copy, disable the line that sets `swing_hit_pending` in `_weight_contact`, then run `bot_swing_phases.gd`. The missing contact penalty must turn the test red. [Negative results](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/r2/negatives/results.txt)

### Capture

Use `tests/bot_course.gd` on seed 1 for the clean run. Use `tests/bot_swing_phases.gd` for its first blind crossing and recovery. The registered camera names and physics frames are below. For a full-speed windowed clip use `orbit`, HUD on and 855 frames including the finish hold.

| View | Frame | View | Frame |
|---|---:|---|---:|
| `overview` | 1 | `balance` | 573 |
| `jump` | 73 | `swing` | 611 |
| `under_bar` | 228 | `wall` | 687 |
| `chute` | 288 | `tower` | 781 |
| `pads` | 496 | `orbit` with HUD | 837 |
| `swing` blind approach | 580 | `orbit` blind recovery with HUD | 588 |

The gallery includes the plot from the village road. [Contact sheet](../../../docs/shifts/2026-11-19-day/lanes/parkour/stills/astra-2/contact-sheet.jpg)
