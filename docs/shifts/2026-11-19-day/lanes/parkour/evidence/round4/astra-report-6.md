# Timber Run · Framing the Skyline swing

The walker’s hands, torso and boots are now visible together on both bars. At frame 926 the boots swing out to the right before the blue release. At 938 the runner crosses toward the red rod. At 948 the red hang and the flagged timber landing are in the same shot. [Before-and-after contact sheet](../../stills/astra-6/contact-sheet.jpg)

## What changed

The play camera moves around and below the near steel arch on the approach to blue. At full strength it turns 78° to the side of the player’s orbit and lowers the sightline by 58°. With the default 33° orbit pitch, that puts the eye 25° below the point it follows. The lens opens from 55° to 59° and looks 2.3 m ahead to include the next target. The hint blends out between the last swing and the finish stripe.

At the default orbit the landing remains to the runner’s right. A child of the pack’s orbit camera composes the rendered pose after the ordinary orbit updates. Drag and wheel still operate on that orbit, and the walker continues to read its ordinary yaw. A byte comparison with the operator’s round-5 pack snapshot found changes in the README, camera setup in `scripts/main.gd`, and the new `scripts/skyline_camera.gd`.

## Visible runner at 1280 × 720

| Play-camera frame | Visible pixels before | Visible pixels after | Visible height before → after | Matched HUD stills |
|---|---:|---:|---:|---|
| 924 · Blue hang | 3,004 | 15,548 | 49 → 253 px | [Before](../../stills/astra-6/before-blue-hang.jpg) · [After](../../stills/astra-6/after-blue-hang.jpg) |
| 926 · Forward swing on blue | 4,058 | 17,239 | 77 → 221 px | [Before](../../stills/astra-6/before-mid-swing.jpg) · [After](../../stills/astra-6/after-mid-swing.jpg) |
| 938 · Airborne transfer | 8,977 | 13,797 | 176 → 223 px | [Before](../../stills/astra-6/before-transfer.jpg) · [After](../../stills/astra-6/after-transfer.jpg) |
| 948 · Red hang | 2,791 | 16,067 | 48 → 255 px | [Before](../../stills/astra-6/before-red-hang.jpg) · [After](../../stills/astra-6/after-red-hang.jpg) |

Each pair uses `orbit`, HUD on, seed 1 and the same `bot_course` physics frame. Each measurement pairs the original lossless PNG with a scratch render at the same frame with only the runner hidden. We counted the largest connected group of changed pixels at the runner, with an absolute difference above 24 in any RGB channel, and measured its height. The count estimates the connected visible silhouette and excludes detached details and faint antialiased edges. It accounts for occlusion by the rod, deck and ribs. [Pixel counts and bounding rectangles](runner-pixels-6.tsv)

The full-speed windowed recording runs **17.40 s** at 60 fps, including the finish board. The perfect hand finished in **986 race frames (16.433 s)** with zero falls. The splits were 338, 286, 182 and 180 frames. [Full run](astra-run-6.mp4) · [Stream details](r6-gates/movie-stream.json) · [Recorded finish state](r6-gates/movie-state.json)

The two shots taken outside the hint also agree. Before the runway, every pixel at frame 840 matched round 5. On the finish board at frame 1015, only five of 921,600 pixels exceeded the 24-level difference threshold. [Orbit return comparison](r6-gates/orbit-return.tsv)

## Verification

- Pack lint passed with the camera script inside the pack fence. [Lint receipt](r6-gates/lint.json)
- All 18 registered bots passed on seeds 1 and 2. All 36 complete state hashes and bot results matched the archived round-5 runs. [Bot results](r6-gates/results.txt) · [Hash comparison](r6-gates/state-comparison.tsv)
- Full gate passed. Both packs completed all 48 verb runs, and all eight registered games matched their standalone hashes in the world. Parkour matched at frame 988 with hash `f7abac006a45bd43`. [Full gate](r6-gates/full.txt) · [World hashes](r6-gates/world.txt)
- Fast gate passed. Architecture 12/12, assets 4/4, cards 3/3, devx tests 229/229, and foreman typecheck clean. [Fast gate](r6-gates/fast.txt)
