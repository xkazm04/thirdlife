# Timber Run · Round 2 · 19 November 2026

The revised pendulum caught a runner who held forward and run at **six of twelve start delays** on each of seeds 1, 2 and 3. Every hit returned the runner to the beam checkpoint. Continuing immediately cost 11–24 more race frames than reading the swing. At the six clear delays both runners finished in exactly the same time. The clean default run takes **806 race frames (13.433 s)**, with zero falls and zero hits. [Paired phase test](r2/verify/bot_swing_phases-1.json) · [Perfect-hand run](r2/verify/bot_course-1.json)

## What changed on the course

| Stage | Player action and result | Default split |
|---|---|---:|
| High line | Run-jump the 3.4 m span. Jump the 3.8 m gap and press C on landing to fit under the 1.52 m beam. The perfect hand landed at sample 179, slid at 180 and travelled 6.42 m down the chute in slope mode. The blocked-bar C retry remains available. | 338 frames / 5.63 s |
| Swing yard | The centres of the two banked pads moved to 2.15 m and 1.15 m right of the beam centreline. Steer out to the first board, turn back across the second, jump to the 1.05 m beam and read the pendulum at the cross-stripe. The default clean approach braked for 18 frames. | 286 / 4.77 s |
| Summit | Run up the bank and jump the 2.90 m gap to the raised crest. Release Shift on the short terraces, take both 0.78 m ledges and cross the flagged stripe. | 182 / 3.03 s |

A box attached to the visible weight follows its solid faces with a 6 cm contact margin. A walker contact counts as one hit and one fall. The HUD briefly displays “Weight hit · Back on beam”. A fall keeps the race clock, pendulum phase and earned splits. R resets the attempt and retains session records. Pad checkpoints now respawn on their actual banked boards. The swing starts at its turning point and follows a 156-physics-frame period. It uses the pack's race frame and stock TL collision facilities. The C retry still measures under 0.10 m horizontal travel over eight samples. Both placement calls convert course positions through `ctx.root.to_global`. [Lane construction](../../../../../../engine/packs/parkour/scripts/return_lane.gd) · [Rules and HUD](../../../../../../engine/packs/parkour/scripts/main.gd)

## Before and after

I replayed the operator’s blind probe on the round-one pack at delays 0, 13, …, 143 on seeds 1 and 2. All 24 runs reached the summit with zero falls. They took 776–923 race frames. The old assertion rejected successful laps because the bot had never waited. **The `bot_course` expectation changed.** A successful run now requires a witnessed grounded crossing, zero physical hits and a clean summit finish. Waiting remains a reported measurement. All previous high-line, wall, tower and split checks still apply. [Original default](r2/before/delay-0-seed-1.json) · [Original delayed run](r2/before/delay-143-seed-2.json)

The registered `bot_swing_phases` plays 24 full races per seed. Each pair uses the same start delay, high-line inputs, steering, jumps and tower policy. The only difference is whether the runner responds to the weight. The blind runner keeps going after a hit. The test checks the hit counter, fall counter, checkpoint 8, physical respawn near the beam entry, preserved first split and final race time. [Test source](../../../../../../engine/packs/parkour/tests/bot_swing_phases.gd) · [Seed 1](r2/verify/bot_swing_phases-1.json) · [Seed 2](r2/verify/bot_swing_phases-2.json) · [Seed 3](r2/verify/bot_swing_phases-3.json)

| Blind result | Start delay in physics frames | Extra full-race frames versus the timed runner |
|---|---|---|
| Hit and returned to the beam | 0, 13, 65, 78, 91, 143 | 18, 24, 12, 17, 24, 11 respectively |
| Cleared on the first approach | 26, 39, 52, 104, 117, 130 | 0 at every delay |

Independent fresh-process probes on seeds 1 and 2 gave the same six struck and six open delays. At delay zero from a fresh launch, holding run to the summit took 823 frames and one hit, against 806 without a hit. The table above uses paired restarts inside the registered test. [Blind fresh start](r2/continuous/push-0-1.json) · [Timed fresh start](r2/phase-trials/timed-0-seed-1.json)

The other omission controls use the real walker and actual checkpoints. Without steering, the runner misses pad one. Keeping the first-pad line clears the pads but misses the balance beam. Omitting the second hop falls at checkpoint 6. Running off the wall lip or taking a 4.50 m/s walking jump falls short of the raised crest. Omitting tower jumps leaves the walker below the first riser for 90 ticks. Keeping Shift held with the same jump cues falls back to checkpoint 11. On the high line, omitting either jump causes a fall and withholding C leaves the walker at the low bar. The chute uses the walker’s automatic slope slide. [Return omissions](r2/verify/bot_return_controls-1.json) · [Wall control](r2/verify/bot_wall-1.json) · [High-line omissions](r2/verify/bot_obstacles-1.json)

An 80-frame delay before the second run produced splits of 418, 284 and 182 after the initial 338, 286 and 182. The session stored 338, 284 and 182 as its stage bests and 806 as its race best. [Split regression](r2/verify/bot_splits-1.json)

## Difficulty by hand

All three ladder hands now use identical high-line jump intent at 1.95 m before either lip, identical lateral steering and pad take-off cues, the same phase and speed rule at the weight, and the same wall and tower jump cues. Only the profile supplied to `TLHand.create` changes. On the retry level every hand deliberately hits the bar standing before trying C. The separate perfect proof retains its 0.85 m high-line take-off for the original airborne and landing measurements, then shares the return driver. [High-line ladder policy](../../../../../../engine/packs/parkour/tests/bot_ladder_retry_regular.gd) · [Return policy](../../../../../../engine/packs/parkour/tests/support/run_hand.gd)

Twenty seeds per cell, starting from a fresh race. A win requires sliding inside the low beam and finishing within 3,600 frames. The means include all twenty attempts, including timeouts. [Ladder PASS lines and measurements](r2/ladder.txt)

| Level | Hand | Wins | Mean frames | Mean seconds |
|---|---|---:|---:|---:|
| Course | Newcomer | 17/20 | 2,316 | 38.60 |
| Course | Regular | 20/20 | 971 | 16.18 |
| Course | Sharp | 20/20 | 845 | 14.08 |
| Forced C retry | Newcomer | 17/20 | 2,042 | 34.03 |
| Forced C retry | Regular | 20/20 | 1,041 | 17.35 |

## Impossibility and test sensitivity

Each data case changes one value in a scratch copy. Both `bot_geometry` and `bot_course` must return exit 1 with a completed bot and passing load, script, engine and watchdog checks. The original no-wait probe also ran against both impossible swing settings. [Exit lines](r2/negatives/results.txt) · [Reproduction commands](../../../../../../engine/packs/parkour/README.md)

| Mutation | Expected and observed failure |
|---|---|
| Second gap 12 m | Clears gap one, falls at gap two. Measured level reach is 4.95 m. |
| Bar clearance 0.55 m | The 0.84 m sliding capsule cannot pass. |
| Pad spacing 13 m | At least 8.78 m separates the boards. The runner falls after pad one. |
| First pad lateral offset 11 m | At least 6.76 m separates the corner from the first pad. |
| Beam entry offset 12 m | At least 9.89 m separates the second pad from the beam. |
| Swing angle 0° | The weight covers the lane permanently. Both approaches take a hit. |
| Swing period 12 frames | The half-cycle is six frames and a straight sprint needs at least 15. Waiting times out, charging is struck. |
| Crest rise 2.4 m | The crest exceeds the 1.00 m apex and the jump falls short. |
| Tower step rise 1.85 m | The first ledge blocks the runner until timeout. |

Removing the live contact response is a separate regression control. With the callback disabled, all twelve blind crossings recorded zero hits. The registered regression finished and returned exit 1 with only `bot.ok` false. [Missing-contact result](r2/negatives/missing-contact.json)

## Construction and verification

Checked `ground_patch`, `kerb`, `scaffold`, `timber_frame`, `flag`, `barrier_wall`, `watch_tower`, `lumber` and `pallet` in the kit catalogue. The track uses wood and concrete patches for walkable faces, kerbs for the balance beam, arm, weight caps and approach stripe, a timber frame for the pivot, scaffold decks for the crest and tower, and summit flags. The catalogue watch tower has a single solid bounding box, so the playable tower uses individual terraces. Round two required zero new kit parts and zero kernel changes. [Kit catalogue](../../../../../../engine/kits/KIT.md) · [Pack lint](r2/lint.json)

| Gate | Result and evidence |
|---|---|
| Pack lint | PASS for schema, layout, fence, capabilities and size. Zero reported bypasses. [Lint](r2/lint.json) |
| Registered bots | PASS 36/36 on seeds 1, 2 and 3, twelve bots per seed. All ten prior registrations also passed in the intermediate build. [Final PASS lines](r2/verify/results.txt) · [Intermediate runs](r2/stage-bots/) |
| Negative controls | PASS 21/21 expected failures. Eighteen geometry and traversal runs, two blind impossible-swing runs and one disabled-contact regression. Each exited 1 with only the bot verdict red. [Negative lines](r2/negatives/results.txt) |
| Full tier, packs and world | PASS packs 2/2 with 42/42 verb runs. PASS world 8/8. The normal parkour run matched `5dcb8573e86c20c6` in-world and alone at frame 808. [Final full gate](r2/full.txt) · [Eight hash pairs](r2/world.txt) |
| Parkour invariants | PASS. Two 3,600-frame idle runs agreed. Two clean bot runs agreed at frame 808. Frame p50 was 0.405 ms, p99 was 0.805 ms, with 453 nodes and 92 bodies. [Invariant checks](r2/invariants.json) |
| Strikes and recoveries in a world | PASS world.alone. A scratch manifest selected `bot_swing_phases` as its first test. Parkour and paddle shared a world. Parkour’s 12 pairs of races ended at tick 20,987 with hash `afcfd2d546622b1d` both in-world and alone. [Collision replay hash pair](r2/world-swing.txt) |
| Fast tier | PASS arch 12/12, assets 4/4, cards 3/3, devx.test 226/226 and Foreman typecheck. [Fast gate](r2/fast.txt) |

The first combined run returned **FAIL packs** on hockey’s 1.012 ms median against a 1.0 ms budget. World passed 8/8 on that run. Hockey’s isolated invariants rerun passed at 0.855 ms, followed by the complete combined rerun above. [First gate](r2/full-first.txt) · [Isolated rerun](r2/hockey-rerun.json)

## Visual evidence

Thirteen new stills cover the two lanes, village road and finish HUD. The swing sequence shows the weight swung clear, an impending blind strike and the runner back on the near beam with the hit message. [Contact sheet](../stills/astra-2/contact-sheet.jpg) · [Open](../stills/astra-2/swing.jpg) · [Strike](../stills/astra-2/strike.jpg) · [Recovery](../stills/astra-2/recovery.jpg) · [Village road](../stills/astra-2/village-road.jpg) · [Capture reports](r2/views/)

The windowed builder clip runs at native speed for **14.317 s**, including the finish hold. The encoded video is H.264, 1920 × 1080, 60 fps and 859 frames. I checked the orbit view in motion samples and the encoded finish board. For an independent operator take, use seed 1, `tests/bot_course.gd`, `orbit`, HUD on and 855 physics frames. [Full run](r2/astra-run-2.mp4) · [Final game state](r2/movie.json) · [Encoded stream](r2/clip-stream.json)

## Director questions and handoff

- Should a future vertical wall support a ledge grab or mantle? The current run-up wall works with the stock running jump.
- Should a future swinging bar allow the walker to hang and release? The current obstacle tests a crossing on foot.

The operator’s independent recording and human playtest remain open. The builder’s clip, gallery and automated verification are ready for review.
