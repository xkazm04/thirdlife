# D5 assigned-file bug hunt

Twelve findings reproduced on Godot 4.7.2 or with the shipped Python detector. Run each command from the worktree root. `REPRO … FAIL` records the observed defect. The capture fixtures use indexed RGB8 data and do not require a window.

## A round rebuild silently drops recorded stage input

`engine/kernel/runner/visit.gd:270` · **High.** A recorded player action disappears, so replay cannot supply it to the game.

When the on-stage holder is rebuilt, the old input has already been freed. The fallback puts the count of nonzero entries into `length`. Ten ticks with one action on tick 9 therefore declare a length of 1. The writer rejects frame 9, removes its temporary file, and the caller ignores the error. Closing a live input with identical samples writes a valid companion file.

```sh
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_stage_record.gd"
```

```text
sampled frames=10, recorded entries=[[9, "move", 1.0]]
REPRO stage_record: FAIL expected first round sidecar with length 10, file exists=false
control with input alive: length=10, entries=[[9.0, "move", 1.0]]
```

`visit.gd:10` defines `length` as samples taken and promises a separate record for the game. `session.gd:7` explains the sparse encoding. Its reader at line 70 requires every entry’s frame to be below `length`. This is a data-loss case in the fallback added for M2’s freed-input error.

## A held bot action survives the handoff to the player

`engine/kernel/runner/visit.gd:250` · **High.** A player taking over a game can inherit continuous acceleration with the accelerator released.

The drive bot holds `gas` through `TLInput.press`. Entering the stage stops the bot and enables devices on the same input. Its injected value stays at 1. The reproduction checks 120 player ticks with the physical W key up throughout.

```sh
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_stage_input.gd"
```

```text
REPRO stage_input: FAIL bot_off=true, physical W=false, gas active on 120/120 player ticks
```

`visit.gd:223` says stage input comes from the person’s devices or that visit’s replay. `tl_input.gd:151` specifies that an injected press survives until release. The shipped drive bot uses precisely this form of throttle input at `engine/seeds/seed_drive/tests/bot_laps.gd:42`.

## Starting the avoidance sphere near a wall puts the camera inside it

`engine/kernel/api/tl_chase_cam.gd:158` · **High.** A wall can occupy the camera’s actual physics position with avoidance enabled.

The target looks away from a solid wall, placing the requested camera behind the target and inside that wall. With 1.2 m between the look point and the wall, avoidance keeps the camera out. At 0.2 m the look point is still outside, but its 0.3 m query sphere already overlaps. The motion cast permits full travel to z=7, inside a wall spanning z=0.2 to 10.2. An independent physics point query checks both results.

```sh
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_camera_wall.gd"
```

```text
REPRO camera_wall: FAIL expected camera outside wall, inside at 1.2 m clearance=false, inside at 0.2 m clearance=true, camera z=7.00
```

`tl_chase_cam.gd:11` promises the camera never enters bodies in the selected space. Both tests use a layer-1 box and the default mask. The lane’s known limitation concerns the visual shape of foliage outside a crown collider.

## A camera turn crosses a wall between clear physics poses

`engine/kernel/api/tl_chase_cam.gd:151` · **Medium.** A rapid orbit can put an interpolated camera frame inside an obstacle.

One 90-degree turn moves the camera between two clear positions 8 m from a stationary target. A box is centered at (4, 1, 4), clear of both sight lines. At 120 frames/s and 60 physics ticks/s, a physics point query finds the camera’s interpolated transform at the center of the box for one frame. The repro samples Godot’s actual interpolated transform headlessly.

```sh
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --fixed-fps 120 --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_camera_cut_wall.gd"
```

```text
REPRO camera_cut_wall: FAIL physics poses inside=0, interpolated frames inside=1, last interior position=(4.0, 1.0, 4.0)
```

`tl_chase_cam.gd:11` promises the camera stays outside the selected space. The project enables physics interpolation and `visitor.gd:335` uses the same interpolated camera transform to measure where it is drawn. The two endpoint casts leave the path between those endpoints unchecked.

## Reversing straight back leaves the chase camera ahead of travel

`engine/kernel/api/tl_chase_cam.gd:172` · **Medium.** The velocity-follow camera stays on the wrong side for the entire reverse run.

With `use_velocity=true` and default stiffness 0.07, move 60 ticks along −Z and 300 along +Z. Each blend of the old unit heading and its exact opposite still points in the old direction. Normalization restores that heading every tick. Setting `follow=1` in the repro removes positional easing from the measurement.

```sh
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_reverse_camera.gd"
```

```text
REPRO reverse_camera: FAIL after 300 reverse ticks, expected 7.0 m behind travel, camera 7.0 m ahead
```

`tl_chase_cam.gd:25` defines `use_velocity` as staying behind the direction of travel. The target moves 30 m in the new direction during the measurement.

## Leaving a game preserves the walker’s held slide pose

`engine/kernel/world/visitor.gd:213` · **Medium.** A stationary walker remains visibly posed in a slide after returning to the gate.

Build speed on flat ground, start a run slide, then enter a game before it ends. The hidden walker resets its body to ground. Returning with `put()` resets the rig’s rotation at line 155. Neither reset ends the held clip, and the rested body has no slide left to end. The real biped still reports `slide` after two seconds standing still.

```sh
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_stage_pose.gd"
```

```text
before stage: body=slide, rig=slide
REPRO stage_pose: FAIL 120 idle ticks after return, body=ground, speed=0.0, rig clip='slide'
```

`engine/kernel/world/WORLD.md:197` specifies that the visitor ends a held slide by playing the empty clip. `engine/rigs/RIGS.md:53` identifies `slide` as a held pose.

## A teleport with a new facing snaps the camera to the old side

`engine/kernel/api/tl_chase_cam.gd:66` · **Medium.** A camera cut can reveal the wrong side of the walker for its first frame.

Teleport the target, turn it 90 degrees, and call `snap()`. The anchor immediately moves to the new position. `_wanted()` still uses the pre-teleport heading. At the requested distance of 8 m, the camera is beside the target, with zero displacement along its new backward axis.

```sh
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_snap_heading.gd"
```

```text
REPRO snap_heading: FAIL expected 8.0 m behind the teleported target immediately, got 0.0 m
```

`engine/kernel/API.md:424` promises immediate placement after a teleport or cut. `visitor.gd:137` gives a concrete caller that promises the camera behind a walker who has just been repositioned and turned.

## The public chase-camera factory rejects its minimum-distance option

`engine/kernel/api/tl_chase_cam.gd:50` · **Low.** A pack cannot configure the documented lift threshold through the camera factory.

Pass `{"avoid_min": 4.0}` to the real `TLCameras.chase()` with a target in the scene tree. The setup allowlist omits the option, emits an engine error, and leaves the threshold at its default of 2.5 m.

```sh
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_avoid_min.gd"
```

```text
ERROR: TLChaseCam: unknown option 'avoid_min'
REPRO avoid_min: FAIL expected setup option 4.0 m, got 2.5 m
```

`engine/kernel/API.md:416` explicitly lists `avoid_min` among the 1.6 options accepted by `ctx.cameras.chase(target, opts)`.

## Selecting a walk case by its printed name runs zero cases and succeeds

`engine/kernel/world/walks/walk_case.gd:67` · **Medium.** The standalone selftest can return a successful exit for a requested case it never exercised.

The filter matches against short names at line 29. Asking for `jump` executes one case. Asking for its printed name `walk.jump` executes none. The trailer compares passed with run, so zero equals zero and the process exits 0. Both invocations use the script’s documented filter argument.

```sh
bash docs/reports/astra-trial/d5/repro/a_walk_filter.sh
```

```text
filter=jump exit=0 WALKCASE done 1 1
filter=walk.jump exit=0 WALKCASE done 0 0
REPRO walk_filter: FAIL selected an existing case, ran zero and exited successfully
```

The `walk_case.gd:2` header names the cases `walk.*`. The root `CLAUDE.md` requires a run that finds zero tests to report failure. The reproduction targets the standalone entry point.

## A sky-masked capture reports a hole in fully drawn ground

`engine/kernel/world/walks/blink_detect.py:90` · **Medium.** The detector can falsely count thousands of ground pixels as a hole.

Two RGB8 captures have the same rendered gray court below the horizon. Their only difference is a single magenta sky pixel above the horizon. With 51 magenta pixels the detector uses the exact mask. With 50 it falls back to a color guess and counts 2,964 court pixels as a hole.

```sh
python -B docs/reports/astra-trial/d5/repro/a_sky_mask.py
```

```text
magenta pixels above horizon=51, sky_mask=True, reported hole pixels=0
magenta pixels above horizon=50, sky_mask=False, reported hole pixels=2964
REPRO sky_mask: FAIL expected 0 holes below horizon, got 1
```

`boot.gd:520` defines magenta as the marker for untouched depth and `blink_detect.py:89` describes that marker as exact. All magenta pixels in both fixtures are above the horizon.

## The blink detector counts isolated crosses as solid patches

`engine/kernel/world/walks/blink_detect.py:47` · **Medium.** Thin flashes can pass the default event threshold without a single qualifying 3×3 patch.

The middle of three indexed RGB8 frames contains 14 separated red plus signs, each five pixels. No center has all eight neighbors. The erosion checks only horizontal and vertical neighbors, so the detector reports a 14-pixel event at the default threshold of 12. The repro also counts full 3×3 blocks directly.

```sh
python -B docs/reports/astra-trial/d5/repro/a_blink_erosion.py
```

```text
full 3x3 foreground neighbourhoods=0
REPRO blink_erosion: FAIL expected 0 surviving pixels, got 14 (default event threshold 12)
```

`blink_detect.py:7` specifies a 3×3 erosion. The function’s own docstring at line 45 explicitly requires the center and all eight neighbors.

## Resizing the capture window prevents the blink report from completing

`engine/kernel/world/walks/blink_detect.py:91` · **Medium.** A valid capture spanning a resize produces a traceback and loses the summary for the whole run.

The fixture contains three complete RGB8 files with correct per-frame sizes. The first two are 960×540, and the last is 800×540. Each decodes successfully. The detector builds one HUD mask from the first image and applies it to all images, raising a shape error before it prints any totals.

```sh
python -B docs/reports/astra-trial/d5/repro/a_capture_resize.py
```

```text
ValueError: operands could not be broadcast together with shapes (270,400) (270,480)
REPRO capture_resize: FAIL 3 indexed RGB8 frames, exit=1, totals printed=False
```

`boot.gd:494` describes per-picture size metadata, and line 563 writes each image’s actual dimensions. `blink_detect.py:11` promises a final line with totals. Uniform frame size is never required by the capture format.

## Suspicions (not reproduced)

None retained.
