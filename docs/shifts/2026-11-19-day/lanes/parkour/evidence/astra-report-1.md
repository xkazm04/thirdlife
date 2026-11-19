# Timber Run · Lane parkour · 19 November 2026

Course F now has three stages and twelve ordered checkpoints inside its original 50 × 28 m village plot. The perfect hand reached the summit in **848 race frames, 14.133 seconds at 60 Hz**, with zero falls. The runner observed the finish at frame 850. [Course instructions](../../../../../../engine/packs/parkour/README.md) · [Finish board](../stills/astra-1/finish.jpg) · [Seed 1 run](final/bot_course-1.json)

## What plays

| Stage | Course and checkpoint behaviour | Perfect-hand split |
|---|---|---:|
| High line | The original 3.4 m running jump, 3.8 m jump into the 1.52 m slide beam, and 65° slope slide. C still sends a blocked runner back to the landing stripe. The old finish stripe records the first split. | 338 frames / 5.633 s |
| Swing yard | Follow the rising bend, jump across two offset wooden pads yawed ±22° and banked ±8°, then land on the 1.05 m balance beam. A physical counterweight swings through the crossing under a timber gantry. The perfect hand waited 71 ticks and crossed on foot. The far end records the split and the next run-up. | 328 / 5.467 s |
| Summit | Run up the concrete bank through 3.2 m of elevation. Jump 2.90 m to a crest 0.72 m above the lip, ease off Shift, and jump two further 0.78 m ledges. The grounded stripe between the red flags finishes the race. | 182 / 3.033 s |

The play camera turns through the two bends. The HUD shows the current stage, next move, elapsed split, stage best, race time and race best. Falls and C retries keep the clock running. R clears the attempt and keeps the session records. A two-run probe added an 80-frame start delay. Its splits were `[338, 328, 182]` and `[418, 326, 182]`, and its stage records were `[338, 326, 182]`. [Split regression](final/bot_splits-1.json)

**Moved expectation.** In course F, frame 338 ended the race. It now closes High line. The full-course and forced-retry bots must reach the tower. The perfect-hand bot still proves both original airborne crossings, the two-sample landing-to-slide limit, travel beneath the bar, the slope drop and zero falls. It additionally witnesses the balance crossing, running flight to the crest and both summit jumps. The original missed-gap, blocked-beam and R-reset probe still passes. [Perfect-hand result](final/bot_course-2.json) · [Obstacle regression](final/bot_obstacles-1.json)

## Construction

Checked `ground_patch`, `kerb`, `scaffold`, `timber_frame`, `flag`, `barrier_wall`, `watch_tower`, `lumber` and `pallet` in the kit catalogue. The new route uses the first five. Wood and concrete patches supply banked, walkable tops and piers. Kerbs supply take-off stripes, the narrow beam and the swinging arm and weight caps. The timber frame holds the pivot. Scaffold decks brace the crest and three summit terraces. The catalogue’s watch tower has one solid bounding box, so the summit uses individually walkable decks. The yard retains its crane, cabin, tyres, lumber, pallet, barricade and trees. [Kit catalogue](../../../../../../engine/kits/KIT.md) · [Return lane](../../../../../../engine/packs/parkour/scripts/return_lane.gd)

The pendulum rotates its kit colliders about the pivot through ±56° on a 156-frame period derived from `TLRules.total_frames`. R restarts that phase and falls preserve it. The course uses the stock walker moves and pack-local transforms. Both calls to `place()` convert through `ctx.root.to_global`. The C prompt still requires less than 0.10 m horizontal displacement over eight samples. Changes are confined to the pack and lane evidence. Kernel and kit source changes count zero. [Lint and composability](final/lint.json)

## Gates

| Gate | Verdict |
|---|---|
| Stage build checkpoints | High line and Swing yard each passed lint and all five then-registered bots on seeds 1 and 2. The initial Summit build passed lint and nine bots on both seeds. [Stage 1](stage-1/lint.json) · [Stage 2](stage-2/bot_course-2.json) · [Stage 3](stage-3/bot_course-2.json) |
| Final pack lint | PASS. Schema, layout, fence, capabilities and size. Zero kit parts added and zero reported bypasses. [Lint](final/lint.json) |
| Every registered bot, seeds 1 and 2 | PASS 20/20. Ten bots on each seed. The wall control left the lip airborne at 4.50 m/s, fell short, returned to the beam exit and finished after a running jump. [Seed 1 wall](final/bot_wall-1.json) · [Seed 2 wall](final/bot_wall-2.json) · [All PASS lines](final/results.txt) |
| Full tier, packs and world | PASS packs 2/2, 40/40 verb runs. PASS world 8/8. Parkour reached the same `29645e99e8ff098e` after 850 bot frames in the shared world and alone. [Final gate output](full-final.txt) · [Eight hash pairs](world.txt) |
| Pack invariants | PASS. Two idle 3,600-frame sims agreed. Two independent clean bot runs agreed at frame 850. Both frame budgets and the entity budget passed. [Invariant checks](invariants.json) |
| Fast tier | PASS arch 12/12, assets 4/4, cards 3/3, devx tests 226/226, Foreman typecheck clean. [Fast output](fast.txt) |
| Negative data controls | PASS 14/14 expected failures. Both bots completed in each case and only `bot.ok` failed. [Exit lines](negatives/results.txt) |

## Difficulty measured through TLHand

Twenty consecutive seeds per cell. A course win requires a witnessed run slide under the low beam and a summit finish inside 3,600 frames. The retry level additionally requires deliberately being blocked and using C to return to the checkpoint. Bots use profile-specific take-off anticipation. The means include every completed seed, including a timeout. [Ladder output](ladder.txt)

| Level | Hand | Wins | Mean race frames | Mean seconds |
|---|---|---:|---:|---:|
| Course | Newcomer | 20/20 | 1,566 | 26.10 |
| Course | Regular | 20/20 | 970 | 16.17 |
| Course | Sharp | 20/20 | 979 | 16.32 |
| Forced retry | Newcomer | 19/20 | 1,350 | 22.50 |
| Forced retry | Regular | 20/20 | 1,045 | 17.42 |

## Impossibility probes

Each row changes one field in a scratch copy. Both `bot_geometry` and the perfect-hand `bot_course` returned exit 1 with clean script, engine and watchdog checks. [Reproduction commands](../../../../../../engine/packs/parkour/README.md) · [Fourteen results](negatives/results.txt)

| Obstacle | Single change | Observed failure |
|---|---|---|
| Chain gap | `chain_gap_m = 12` | First jump cleared, second failed. Running reach is 4.95 m. |
| Slide | `bar_clearance_m = 0.55` | Both jumps cleared. The 0.84 m sliding capsule stayed at the bar until timeout. |
| Angled pads | `pad_spacing_m = 13` | The projected gap is 8.78 m. The first pad registered, then the runner fell. |
| Balance beam | `beam_entry_offset_m = 12` | The nearest beam edge is 9.89 m away. Both pads registered, then the runner fell. |
| Swing | `swing_degrees = 0` | The weight remained in the opening. The runner timed out at return station 19.95 m. |
| Run-up wall | `wall_crest_rise_m = 2.4` | The crest exceeded the walker’s 1.00 m apex and the runner fell back to the run-up checkpoint. |
| Tower | `tower_step_rise_m = 1.85` | The crest registered. The first high terrace stopped the runner until timeout. |

## Visual evidence and operator handoff

The builder gallery contains eleven stills and a contact sheet. It includes all six obstacle kinds, the chute, the course overview, the visitor’s actual view from the village road, and the finish board. I also inspected the play camera through the bend, pad jumps, pendulum, wall and finish. The village tour rendered five of five requested pictures. [Contact sheet](../stills/astra-1/contact-sheet.jpg) · [Road view](../stills/astra-1/village-road.jpg) · [Windowed tour log](village-road.txt) · [Capture reports and road walk](views/)

A windowed builder reference for the operator follows the orbit camera all the way from the start to the finish board. The H.264 clip is **15.067 s, 1280 × 720, 60 fps, 904 video frames** including the finish hold. Its captured game state records 848 race frames, three splits and zero falls. For the operator’s independent recording, use seed 1, `tests/bot_course.gd`, `orbit`, HUD on and capture through physics frame 900 at native speed. [Full run](astra-run-1.mp4) · [Movie result](movie.json) · [Stream properties](clip-stream.json)

All builder acceptance checks are complete. The operator’s independent recording and a human playtest remain outside this build pass.

## Questions for the Director

- Should a future vertical face support a ledge grab or mantle? The present course reaches its terraces with a run-up and stock jumps.
- Should future obstacles let the player grab a swinging bar and release it? That needs a walker attachment and release move. Here the weight swings independently and the player times a crossing on foot.
