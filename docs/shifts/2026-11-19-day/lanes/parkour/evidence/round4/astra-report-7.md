# Timber Run · Aiming the jump to blue

**The play camera now stays behind the runner through take-off.** At frame 895 the two marks on the lip bracket the direction of travel, with the blue grip ahead. Forward input takes the runner straight up the runway on screen. At frame 915 the runner is visible from raised hands to boots, spanning **254 pixels** in the 720p HUD view. Round 6 showed zero runner pixels at that frame. [Six matched views](../../stills/astra-7/contact-sheet.jpg) · [Windowed full run](astra-run-7.mp4)

## Camera decision

The old hint started turning sideways as soon as the runner got onto the runway. Holding W still drove along the original orbit heading, so the apparent direction of travel diverged from the direction the player was aiming. By the jump, the near arch blocked the runner completely. I judged that a poor view for choosing a take-off point. The revised approach preserves the player's yaw and lowers the viewing angle to keep the stripe, runner and blue grip together.

Catching blue switches to the low side view. It holds through the transfer and red hang so the player can read both releases. Letting go of red switches back to the rear view for the flagged ramp. These cuts happen after the corresponding player action. Trial sweeps between the two camera positions passed behind a steel rib. The hint fades out as the runner reaches the landing. Right-drag and wheel still control the underlying orbit.

## Matched HUD stills

Perfect hand, seed 1, `tests/bot_course.gd`, `orbit`, HUD on, 1280 × 720. The complete images matched pixel for pixel at runway entry, on the blue forward swing, on red and on the final approach.

| Physics frame | Round 6 visible pixels | Round 7 visible pixels | Visible height before → after | Stills |
|---|---:|---:|---:|---|
| 870 · Runway entry | 19,028 | 19,028 | 257 → 257 px | [Before](../../stills/astra-7/before-870.jpg) · [After](../../stills/astra-7/after-870.jpg) |
| 895 · Run-up | 14,262 | 12,291 | 214 → 231 px | [Before](../../stills/astra-7/before-895.jpg) · [After](../../stills/astra-7/after-895.jpg) |
| 915 · Jump to blue | 0 | 14,439 | 0 → 254 px | [Before](../../stills/astra-7/before-915.jpg) · [After](../../stills/astra-7/after-915.jpg) |
| 926 · Blue forward swing | 17,239 | 17,239 | 221 → 221 px | [Before](../../stills/astra-7/before-926.jpg) · [After](../../stills/astra-7/after-926.jpg) |
| 948 · Red hang | 16,067 | 16,067 | 255 → 255 px | [Before](../../stills/astra-7/before-948.jpg) · [After](../../stills/astra-7/after-948.jpg) |
| 975 · Catch ramp approach | 15,755 | 15,755 | 231 → 231 px | [Before](../../stills/astra-7/before-975.jpg) · [After](../../stills/astra-7/after-975.jpg) |

I repeated the round-6 measurement on lossless PNGs. For each still, a scratch render hid the runner at the same frame. The count is the largest connected region at the runner where any RGB channel differs by more than 24. At frame 915 the original round-6 image and its hidden-runner render matched at every pixel. At 895 the rear silhouette is narrower and taller, and the runner is centred between the launch marks. [Pixel counts and bounds](runner-pixels-7.tsv)

I also compared two windowed recordings, one with the runner hidden, across all 123 consecutive movie frames from index 868 through 990. Every frame had a visible runner region. The smallest connected region was 7,647 pixels just after the red release, when the rod briefly crossed the on-screen body. Movie indices refer to the recording, and the six stills above use the capture tool’s physics-frame numbers. [Continuous visibility check](r7-gates/movie-visibility.tsv)

## Run and verification

The windowed clip contains 1,044 frames at 60 fps and plays at native speed for **17.40 s**, including the finish board. The perfect hand finished in 986 race frames (**16.433 s**) with zero falls. Splits were 338, 286, 182 and 180 frames. [Clip](astra-run-7.mp4) · [Stream verification](r7-gates/movie-stream.json) · [Recorded finish](r7-gates/movie-state.json)

- Pack lint passed. [Receipt](r7-gates/lint.json)
- All 18 registered bots passed on seeds 1 and 2. Each of the 36 complete state hashes and bot results matched both round 5 and round 6. A byte comparison against the round-6 pack found changes only in the two camera-related scripts and the README. [Bot results](r7-gates/results.txt) · [Three-round hash comparison](r7-gates/state-comparison.tsv)
- Full gate passed. Both packs completed all 48 verb runs, and all eight registered games matched standalone hashes in the world. Parkour matched at frame 988 with hash `f7abac006a45bd43`. [Full gate](r7-gates/full.txt) · [World registry](r7-gates/world.txt)
- Fast gate passed. Architecture 12/12, assets 4/4, cards 3/3, devx tests 229/229, and foreman typecheck clean. [Fast gate](r7-gates/fast.txt)
