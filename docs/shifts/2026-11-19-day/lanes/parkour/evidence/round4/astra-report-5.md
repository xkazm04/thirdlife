# Timber Run · Skyline recovery and swing framing

**Design decision.** Fix the runway checkpoint and the timing driver. Keep the two transfers, their catch windows and the 60-second clock. A held pump input could walk a player off a checkpoint they had just earned. The timing driver also released some slow catches before the walker had swung far enough. Those faults warranted changes. Recoverable missed transfers remain part of the course.

## What happened at the runway

On course seed 16, Back was physically down when the runner respawned at frame 1747 (z 5.19 m, feet 10.08 m high). It stayed down until frame 1795. By then the runner had landed behind the headwall. On retry seed 11, Back stayed down from placement at frame 2128 until frame 2148, when the feet were already off the deck. The restored checkpoint was still 13. The lower approach supported the walker, so the old fall check never returned them. A perfect-hand test reproduced this with ordinary player controls. It failed on the shipped game at 0.085 m of drift. [Input samples](held-inputs.tsv) · [Baseline control](before-control/results.txt)

The checkpoint now ignores the carried Back press until release. W and lateral input are available on placement. A fresh Back press can walk off the rear edge. Landing on the lower approach then returns the player to the earned runway. The new test held Back for 16 ticks before placement and 45 ticks afterward. It measured **0.000 m drift**, advanced **2.31 m** with W and S both held, walked off on a fresh S, recovered and finished. Disabling the lower return makes that same test fail. [Seed 1 control](verify/bot_runway_recovery-1.json) · [Omission results](negatives/results.txt)

## What happened at the bars

The old driver assumed a running-speed catch and queued a release about five ticks after expected contact. On course seed 5 it requested the red release at frame 2084. The actual catch came at 2101 with angular speed 3.97 rad/s. The key arrived at 2102 with the last observed angle still 0.00 rad. A player needs the swing to gain height before releasing. [Release and catch samples](seed5-release-events.tsv)

All three hands now use the same approach and release policy. In flight the driver estimates time to the **next required grip** from consecutive foot positions, checks the projected hand height, and allows for slower initial rotation. While attached it predicts angle and speed over the measured input delay. It requests release on a forward stroke with predicted angle from 0.63 to below 1.35 rad and angular speed above 2.7 rad/s. These are bot decisions. Catch physics still come from the walker. The retry drill still deliberately takes the first low beam standing, and every hand must slide inside it and finish.

| Former newcomer loss | Shipped frames | Runway fix alone | Runway and timing policy |
|---|---:|---:|---:|
| Course 5 | 3,600 timeout | 3,600 timeout | 1,855 finish |
| Course 16 | 3,600 timeout | 2,259 finish | 2,931 finish |
| Retry 11 | 3,600 timeout | 2,919 finish | 2,148 finish |
| Retry 12 | 3,600 timeout | 3,600 timeout | 1,909 finish |
| Retry 18 | 3,600 timeout | 3,600 timeout | 1,833 finish |

The checkpoint change alone recovered both backward falls. The shared timing change recovered the other three seeds. The perfect hand still clears all four stages in 986 frames with zero falls. [Former-loss reruns](former-losses.tsv) · [Perfect run](verify/bot_course-1.json)

## Difficulty by hand

Both ladders ran through `node devx/bin/tl.mjs ladder` on the same four-stage geometry, seeds 1–20. Each completed 120 of 120 samples. Means include the 3,600 frames of a timeout. Only the TLHand profile differs between hands within a level. [Before](ladder-before.txt) · [After](ladder-after.txt)

| Level | Hand | Wins before | Wins after | Mean frames before | Mean frames after |
|---|---|---:|---:|---:|---:|
| Course | newcomer | 18/20 | 19/20 | 2,670 | 2,604 |
| Course | regular | 20/20 | 20/20 | 1,291 | 1,260 |
| Course | sharp | 20/20 | 20/20 | 1,081 | 1,079 |
| Forced C retry | newcomer | 17/20 | 19/20 | 2,467 | 2,403 |
| Forced C retry | regular | 20/20 | 20/20 | 1,378 | 1,432 |
| Forced C retry | sharp | 20/20 | 20/20 | 1,186 | 1,144 |

The two remaining timeouts were different seeds. Course 4 reached the runway at frame 1987, caught blue 10 times and red twice, and had 10 runway falls. Retry 8 reached it at 2148, caught blue 11 times and red five times, and had 11 runway falls. Both were still making attempts at the clock limit. I kept that timing difficulty. These figures measure the shared driver through TLHand over the whole race. [All 40 newcomer outcomes](newcomer-seeds-after.tsv) · [Final two transfer traces](remaining-transfers.tsv)

## Play camera and full run

The pack raises the orbit sightline toward the rods on the runway, widens its field of view from 55° to 60° through the transfer, then blends back on landing. The player keeps their orbit yaw, pitch and zoom. The comparison uses the same perfect-hand seed, physics frames, 1280 × 720 resolution and HUD on both sides. At frame 938 the red bar moves from the upper fifth of the image, partly under the timer panel, to just above the middle. The walker and the flagged landing remain visible. [Contact sheet](../../stills/astra-5/contact-sheet.jpg)

| Orbit view | Before | After |
|---|---|---|
| Blue hang · 924 | [Still](../../stills/astra-5/before-blue-hang.jpg) | [Still](../../stills/astra-5/after-blue-hang.jpg) |
| Airborne transfer · 938 | [Still](../../stills/astra-5/before-transfer.jpg) | [Still](../../stills/astra-5/after-transfer.jpg) |
| Red hang · 948 | [Still](../../stills/astra-5/before-red-hang.jpg) | [Still](../../stills/astra-5/after-red-hang.jpg) |

The windowed orbit clip shows the entire run and finish board at normal speed. It contains 1,044 frames at 60 fps, **17.40 s**. Race time is **16.433 s**, with splits of 338, 286, 182 and 180 physics frames. [Full run](astra-run-5.mp4) · [Stream verification](clip-stream.json) · [Capture state](movie.json)

## Gates

| Gate | Result |
|---|---|
| Pack lint | PASS, API 1.10 and pack 0.3.1. [Receipt](verify/lint.json) |
| Every registered bot, seeds 1 and 2 | PASS, 18 tests × 2 seeds, 36/36. The mistimed blue and red releases still miss. [All results](verify/results.txt) · [Grip omission control](verify/bot_grips-1.json) |
| Impossibility cases, seed 1 | All 13 one-value mutations made both `bot_geometry` and `bot_course` exit 1. The swing-contact, beam-landing and runway-return omissions also exited 1. In all 29 runs the sole failed check was `bot.ok`. [Results](negatives/results.txt) |
| Full, packs and world | PASS packs, 2/2 packs and 48/48 verb runs. PASS world, 8/8 registered games matched alone. Parkour matched at hash `f7abac006a45bd43` on frame 988. [Full gate](gate-full.txt) · [World registry](world-registry.txt) |
| Fast | PASS arch 12/12, assets 4/4, cards 3/3, devx 229/229, foreman typecheck clean. [Fast gate](gate-fast.txt) |

The pack uses its existing runway and orbit camera. This round required no kit addition or kernel change. The earlier ledge-height and translated-world findings remain with the lanes assigned by the Director.
