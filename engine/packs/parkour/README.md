# Timber Run

Enter the scaffold yard west of the walker plot from the village road, or play with `node devx/bin/tl.mjs play parkour`. Reach the flagged catch ramp within 60 seconds. Four stages share a 50 × 28 m plot.

| Control | Action |
|---|---|
| WASD or arrows | Move relative to the orbit camera |
| Shift | Run |
| Space | Jump, mantle a caught ledge, or release a bar with an upward hop |
| C | Slide from a run. Drop from a ledge or bar. At the low-beam retry prompt, return to the landing stripe |
| Right-drag / wheel | Orbit / zoom |
| R | Restart the race and pendulum. Keep this session’s best splits and best run |

The pack walker opts into the kernel’s ledge and bar moves. Its action map has no flight binding. In the operator’s windowed visit, F was pressed twice on stage alongside Space, Shift and W. The 449-sample stage record contained only jump, forward and run. After leaving, F took the village walker 11.077 m up. [Flight boundary check](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/round2/fly-probe-visit.txt)

## Course

1. **High line.** Run and jump the 3.4 m span. Jump the 3.8 m gap and press C on landing to slide beneath the 1.52 m beam. If it stops you standing, tap C at the retry prompt, run forward, then press C again. The walker automatically slope-slides down the 65° chute to the first split.
2. **Swing yard.** Follow the rising bend. Steer right to the first timber pad, turn back across the second and jump onto the centre of the 1.05 m balance beam. The pad centres are 2.15 m and 1.15 m right of the beam centreline. They face opposite ways at 22° and bank 8°. Read the counterweight at the beam’s cross-stripe. Keep running when the weight is swinging clear. If it is coming across your path, brake before the gantry and set off when you can reach the other side. A hit returns you to the near end of the beam while both the race and the pendulum keep going. At this checkpoint you face down the beam. If a side key was held through the fall, release it to steer that way again. You can run forward immediately. The far end records split two. Keep your feet inside the pad or beam. If you skim its edge and land beyond the required checkpoint, the race returns you to your last landing.
3. **Summit.** Run up the 3.2 m concrete bank and jump from the wooden lip across a 2.90 m gap to a crest 0.72 m higher. Ease off Shift on the tower. Jump the two 0.78 m ledges, then cross the summit stripe and turn toward the high concrete wall.

4. **Skyline.** Jump toward the 3.00 m headwall to catch its lip. Hold forward or press Space to mantle. The wooden runway is your checkpoint. Run between its edge marks and jump to the blue bar, 1.30 m beyond the edge and 3.05 m above the deck. Swing forward and release with Space to catch red, 4.00 m away and 1.55 m higher. Release on the rising forward stroke to land on the inclined timber ramp. Its near edge is 3.50 m beyond red. If you lose speed, alternate forward and back with the swing to build it again. Both bars must be touched in order on the same attempt. A fall returns you to the runway. If Back was held to pump the swing, release it before stepping backward again. Forward and side movement are available immediately. Walking off the rear and landing on the lower headwall approach also returns you to the earned runway checkpoint. The camera stays behind you as you aim between the runway marks and jump for blue. Catch blue and the view turns side-on so you can read the swing. Releasing red brings the flagged landing back in front of you.

Fourteen ordered checkpoints register landings and crossings. Falling costs the time it takes to recover. The HUD shows the current stage, its elapsed time and session best, and the current and best full-run times. The finish board shows all four splits. The pendulum swings ±56° over 156 physics frames at 60 Hz.

## Verification

On seeds 1 and 2 the perfect hand finished with zero falls and zero weight contacts in **986 race frames (16.433 s)**. The splits were **338, 286, 182 and 180**. The bot observed the wall hang at frame 843, the mantle at 844, the catches at 921 and 945, and the releases at 927 and 951. In the earlier swing yard it braked for 18 ticks. Charging the weight caused six checkpoint returns in twelve matched start phases and cost 6–19 ticks. [Perfect run](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/round4/verify/bot_course-1.json) · [Pendulum phases](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/round4/verify/bot_swing_phases-1.json)

| Test in `tests/` | What it measures |
|---|---|
| `bot_course.gd` | Airborne crossings and grounded landings on both high gaps, slide within two samples of landing, slide inside the bar, over 2 m of slope descent, both pad landings, a grounded crossing of the swing, running flight to the crest, airborne ascent of both tower faces, the headwall hang and mantle, both ordered bar catches and releases, and all four splits. A clean finish requires zero falls and hits. |
| `bot_swing_phases.gd` | Twelve matched start delays. The blind runner keeps running even after a strike. Each strike must return it to the approach checkpoint with the first split intact. The timed runner must finish every lap clean and beat every struck run. When the blind runner crosses cleanly both runners must record the same time. |
| `bot_return_controls.gd` | Six omissions and a clean control. Straight ahead misses pad one. Keeping the first-pad line misses the beam. Skipping the second hop or the wall jump causes a fall. Withholding tower jumps leaves the walker below the first ledge for 90 ticks. Holding run through the tower with the same jump cues overshoots the summit approach. |
| `bot_beam_recovery.gd` | Fall off each side and hold the old strafe through respawn. Stay on the centreline, move forwards and turn again on a fresh press. |
| `bot_runway_recovery.gd` | Hold Back through a drop from blue. Measure drift on respawn, advance with W and S both down, then release and freshly press Back to walk off the rear. Recover from the lower approach and finish. |
| `bot_geometry.gd` | Checks horizontal and raised jump reach, slide clearance, chute angle, offset and spacing of pads, beam approach, maximum swing opening and minimum crossing time, both tower rises, headwall and blue-bar heights, and the first-swing reach bounds for red and the ramp. |
| `bot_headwall.gd` | Run against the face for 75 grounded ticks, catch and hold for 18 ticks, drop to the approach with C, then mantle and finish. |
| `bot_grips.gd` | Run off the runway, release at the bottom of blue, then release red on the return swing. Each falls below the runway. The timed fourth attempt finishes. |
| `bot_landing_recovery.gd` | Stay supported on the beam with the feet outside its stripe. Passing the landing returns the walker to pad two. A centred jump then finishes the course. |
| `bot_obstacles.gd` | Omitting either high jump returns to its checkpoint. Running and jumping without sliding stops at the bar. R clears the attempt. |
| `bot_wall.gd` | A 4.50 m/s walking jump falls short. The same hand returns to the run-up, clears the crest at running speed and finishes. |
| `bot_splits.gd` | R between two finishes. An 80-frame delayed second start gives a slower race and a faster second stage. Waiting at the headwall only on lap one makes the second lap replace Skyline’s best by 44 ticks. The HUD’s underlying split and full-run records keep each best independently. |
| `bot_ladder_course_{newcomer,regular,sharp}.gd` | Try a landing slide, use C to recover if blocked, slide inside the bar and finish within the clock. |
| `bot_ladder_retry_{newcomer,regular,sharp}.gd` | Deliberately hit the bar standing, use C to retry, slide under it and finish on the Skyline ramp. |

```sh
bash engine/tools/tl.sh lint --pack=engine/packs/parkour
bash engine/tools/tl.sh bot --pack=engine/packs/parkour --test=tests/bot_course.gd --seed=1
bash engine/tools/tl.sh bot --pack=engine/packs/parkour --test=tests/bot_swing_phases.gd --seed=1
node devx/bin/tl.mjs ladder --pack engine/packs/parkour --cells course_newcomer,course_regular,course_sharp,retry_newcomer,retry_regular,retry_sharp --seeds 20
node devx/bin/tl.mjs check --tier full --only packs,world
node devx/bin/tl.mjs check --tier fast
```

### Difficulty by hand

Each ladder level uses one input policy across its hands. It calls for a high-line jump 1.95 m before each lip, uses common pad take-off and steering cues, reads the same pendulum phase and approach speed, and uses the same wall and tower take-offs. Only the profile passed to `TLHand.create` changes. The retry drill changes the first slide instruction for every hand. The separately scripted perfect-hand proof above uses a 0.85 m high-line take-off lead and the same return and Skyline driver.

The controller lets one side tap reach the controls and release before requesting another. After a fall it measures lateral travel from the respawn position. On a C retry it requests the slide 3.0 m before the bar. The win still requires an active slide inside the opening.

On Skyline the driver measures the ticks between a jump request and its delivered input. In flight it uses the last two foot positions to estimate when the hands will reach the next required bar and how quickly that catch will swing forward. While attached it predicts the swing angle and forward angular speed when the requested input will arrive. It pumps again if the predicted stroke is too slow. Every hand uses these same observations and thresholds. A ladder win requires both grips and a grounded finish before the 3,600-frame limit. The clock continues during recovery.

Both measurements use the same four-stage course and seeds 1–20. Means include timeouts at 3,600 frames. The five prior newcomer losses now finish. Course seed 4 and forced-retry seed 8 still reach the clock limit after repeated transfers. [Shipped Skyline](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/round4/ladder-before.txt) · [Revised runway and driver](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/round4/ladder-after.txt)

| Level | Hand | Wins before | Wins after | Mean frames before | Mean frames after |
|---|---|---:|---:|---:|---:|
| Course | newcomer | 18/20 | 19/20 | 2,670 | 2,604 |
| Course | regular | 20/20 | 20/20 | 1,291 | 1,260 |
| Course | sharp | 20/20 | 20/20 | 1,081 | 1,079 |
| Forced C retry | newcomer | 17/20 | 19/20 | 2,467 | 2,403 |
| Forced C retry | regular | 20/20 | 20/20 | 1,378 | 1,432 |
| Forced C retry | sharp | 20/20 | 20/20 | 1,186 | 1,144 |

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
| `return.json` | `wall_crest_rise_m = 2.4` | The 2.40 m crest exceeds the 1.00 m jump apex. Its concrete pier is set back 0.82 m so the timber nose offers no handhold. |
| `return.json` | `tower_step_rise_m = 1.85` | The first high ledge stops the runner until timeout. |
| `upper.json` | `ledge_rise_m = 4.3` | The lip exceeds the walker’s 3.80 m maximum catch height from a level approach. |
| `upper.json` | `first_bar_rise_m = 4.5` | Even at the jump apex the hands are below blue. |
| `upper.json` | `bar_spacing_m = 19` | Red lies beyond the 10.10 m optimistic running-transfer bound. |
| `upper.json` | `landing_gap_m = 21` | The near end of the ramp lies beyond the 11.56 m optimistic landing bound. |

```sh
bash engine/tools/tl.sh bot --pack="$bad" --test=tests/bot_geometry.gd --seed=1
bash engine/tools/tl.sh bot --pack="$bad" --test=tests/bot_course.gd --seed=1
```

All 13 single-value mutations reject both the geometry check and the actual course run. Disabling the lower-approach return separately makes the fresh-Back runway test fail. A separate API 1.10 precision repro uses a reachable 3.05 m headwall. The standing-room query reports the supporting floor as an obstruction. The shipped headwall is 3.00 m. [Mutation results](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/round4/negatives/results.txt) · [Lip probe](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/round3/ledge-fit.txt)

There is also a negative control for the timing test itself. In a scratch copy, disable the line that sets `swing_hit_pending` in `_weight_contact`, then run `bot_swing_phases.gd`. The missing contact penalty must turn the test red. [Negative results](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/r2/negatives/results.txt)

### Capture

Use `tests/bot_course.gd` on seed 1 for the clean run. Use `tests/bot_swing_phases.gd` for its first blind crossing and recovery. The registered camera names and physics frames are below. For a full-speed windowed clip use `orbit`, HUD on and 1,040 physics frames including the finish hold.

| View | Frame | View | Frame |
|---|---:|---|---:|
| `overview` | 1 | `balance` | 573 |
| `jump` | 73 | `swing` | 611 |
| `under_bar` | 228 | `wall` | 687 |
| `chute` | 288 | `tower` | 781 |
| `pads` | 496 | `orbit` with HUD | 1015 |
| `swing` blind approach | 580 | `orbit` blind recovery with HUD | 588 |
| `headwall` | 843 | `blue_grip` | 924 |
| `transfer` | 938 | `red_grip` | 948 |
| `catch_deck` | 986 | | |

The course gallery includes the village road and the finish board. The play-camera comparison shows the runway entry, run-up, jump to blue, both hangs and the landing approach at frames 870, 895, 915, 926, 948 and 975, with the HUD on. At frame 915 the visible runner measures 254 pixels tall in the 720p view. The windowed full run plays at native speed for 17.40 s including the finish board. [Course gallery](../../../docs/shifts/2026-11-19-day/lanes/parkour/stills/astra-4/contact-sheet.jpg) · [Before and after](../../../docs/shifts/2026-11-19-day/lanes/parkour/stills/astra-7/contact-sheet.jpg) · [Full run](../../../docs/shifts/2026-11-19-day/lanes/parkour/evidence/round4/astra-run-7.mp4)
