# Rig, style, and tool bug candidates

All commands run from the worktree root in Git Bash. Each `REPRO ... FAIL` line records an observed defect in the current files.

## Clip capture deletes an existing source movie before validating the request

`engine/tools/look.sh:100` · **High**. A rejected capture can permanently delete a neighboring file.

For an output named `film.mp4`, the tool chooses `film.avi` as its temporary file and immediately unlinks it. The repro creates a disposable existing `film.avi` and requests `rig:typo`. The invalid kind exits 2 before Godot starts, but the file is already gone.

The output contract at `engine/tools/look.sh:11` names the requested MP4 and its PNG strip. It gives the caller no reason to reserve the neighboring AVI name, even on a rejected request.

```bash
bash docs/reports/astra-trial/d5/repro/r_clip_input.sh
```

```text
unknown rig kind typo
REPRO clip_input: FAIL invalid kind exited 2 and deleted the pre-existing film.avi beside the requested film.mp4
```

## An interrupted world comparison reports four matching hashes

`engine/tools/selftest.sh:205` · **High**. The determinism gate can certify a comparison that never ran.

The repro stops only the `world.sh same` child it starts, before its first hash. A direct control exits 143. In the selftest, the child exit status is discarded. Without a PASS line, the script extracts failure text using a second grep. An empty match leaves `why` empty, which `verdict` interprets as success.

`CLAUDE.md` and `docs/GATE-HONESTY.md:20` require a stopped run to produce a non-passing outcome. The verdict at `engine/tools/selftest.sh:206` specifically claims four solo and combined hashes agreed three times.

```bash
bash docs/reports/astra-trial/d5/repro/r_stopped_world.sh
```

```text
Stopped world.sh control exit=143
PASS world.same  (pack_min, ex_bounce and two ex_wall in one process: 4 hashes equal to the solo runs, three times)
selftest: 1 passed, 0 failed (reports in docs/reports/astra-trial/d5/repro)
REPRO stopped_world: FAIL world.same returned success after the world.sh child stopped before its first hash
```

## The flicker meter reports 100% pixel changes on a static 720p clip

`engine/rigs/review/boil.py:17` · **Medium**. The default capture resolution can produce a convincing but incorrect shimmer measurement.

The fixture contains twelve identical lossless 1280×720 YUV420p frames with alternating dark and light rows. The default 1080-reference band scales to rows 133 through 279, a requested height of 147. FFmpeg rounds this crop to chroma-aligned dimensions. The reader splits the returned bytes into 147-row frames anyway, shifting row boundaries between successive comparisons. A full-height measurement of the same file reads all twelve frames correctly.

`engine/rigs/review/boil.py:2` defines the statistic as a difference between consecutive frames inside the selected band. Identical frames must measure zero. `engine/tools/look.sh:12` specifies 1280×720 as the default clip size.

```bash
python docs/reports/astra-trial/d5/repro/r_boil.py
```

```text
boil frames=12 band=0..720 mean=0.000 flips_pct=0.000 (mean change per frame, grey levels; share of pixels changing by more than 24)
boil frames=11 band=133..280 mean=222.000 flips_pct=100.000 (mean change per frame, grey levels; share of pixels changing by more than 24)
REPRO boil: FAIL expected 12 identical frames, zero mean change and zero flips
```

## Omitted clip bones retain old rotations and can accumulate the look-at correction

`engine/rigs/tl_rig_node.gd:207` · **Medium**. A normal fall can twist the neck almost backwards, and an immediate clip change can leave a lasting shoulder offset.

`_apply` writes rotations only for bones named in the current pose. During the first part of `fall`, the authored poses omit `Neck`. With a constant horizontal `look_at` target, `_post_pose` multiplies its correction onto the previous neck rotation each tick. At tick 27 the shortest local rotation from neutral is 172°. Separately, switch from `cheer` to `idle` with zero blend. The missing `LeftShoulder` entry leaves a 12° rotation that a fresh rig playing the same idle clip does not have, even after 120 ticks.

`engine/rigs/RIGS.md:19` defines a clip as a pose function of its time with identity rest rotations. The ordinary blend treats missing rotations as identity at `engine/rigs/tl_rig_node.gd:200`. For the gaze, `engine/rigs/tl_rig_biped.gd:270` clamps horizontal yaw to 70° and assigns 40% to the neck, or 28° over the authored pose.

```bash
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_gaze.gd"
```

```text
REPRO gaze: FAIL at fall tick 27 a horizontal target has neck rotation 172.0 degrees, authored neck neutral, look limit 28 degrees
```

```bash
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_pose.gd"
```

```text
REPRO pose: FAIL expected identical idle shoulders after 120 ticks, difference=12.0 degrees
```

## Turning in the air twists the newly planted boots on touchdown

`engine/rigs/tl_rig_biped.gd:222` · **Medium**. A turn during a jump produces an extra 30° of boot rotation after the landing blend completes.

Two bipeds make the same vertical jump and land facing the same direction. One starts facing 30°. The other turns 1° on each airborne tick. `land()` initializes the new feet in the current body frame. The immediately following `step()` then compensates those new anchors for the yaw change since the last grounded tick, as if they had stayed on the floor throughout the jump.

`engine/rigs/biped/tl_rig_biped_gait.gd:199` describes placing both feet under the body after flight, and line 210 sets their new headings to the pelvis heading. The correction at line 115 is for a foot that was already standing on the floor. The repro measures the actual left-foot bone after the default four-frame landing blend.

```bash
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_land_turn.gd"
```

```text
REPRO land_turn: FAIL after landing blend: control boot yaw 0.0 degrees, turned-in-air boot yaw -30.0 degrees relative to the same body heading
```

## A filtered rig selftest takes its verdict from an earlier report

`engine/tools/selftest.sh:159` · **Medium**. The same named test can fail in a clean directory or pass on stale data without running its bot.

Selecting `rig.vehicle_drives` skips the `kit.bot` producer at line 156 because the names do not match. The consumer still reads `kit.bot.json` from `TL_SELFTEST_DIR`. The repro runs once with an empty directory, then seeds a retained result with a distinctive 99 m/s speed and repeats exactly the same selection. The second invocation prints that speed as its own result.

`engine/tools/selftest.sh:154` describes each claim as measured by one bot run. Its documented name filter at line 4 and the gate completion rule require a verdict from the selected run.

```bash
bash docs/reports/astra-trial/d5/repro/r_stale_case.sh
```

```text
FAIL rig.vehicle_drives: the kit.bot report lacks /"rig_vehicle_ok":true/
PASS rig.vehicle_drives  (TLRigs vehicle: top 99 m/s, wheel yaw 0.25 rad when steering right)
REPRO stale_case: FAIL identical selected case, empty report directory exit 1, retained result exit 0
```

## A filter matching zero selftests exits successfully

`engine/tools/selftest.sh:961` · **Medium**. A typo in a targeted gate command gives automation a green exit status.

`walk.jmup` selects no cases. The trailer shows zero passed and zero failed. The exit test checks only the failure count, so the command returns 0.

The zero-found rule in `CLAUDE.md` and `docs/GATE-HONESTY.md:14` requires a non-passing result when no units were found.

```bash
bash docs/reports/astra-trial/d5/repro/r_empty_filter.sh
```

```text
selftest: 0 passed, 0 failed (reports in docs/reports/astra-trial/d5/repro)
REPRO empty_filter: FAIL expected a nonzero status for zero matching cases, got 0
```

## The held run-slide leaves the trailing hand 31 cm above the floor

`engine/rigs/biped/tl_rig_biped_moves.gd:93` · **Medium**. The visible slide pose misses its specified contact point on level ground.

Play `slide` on a scale-one biped at floor height and tick for one second. The entry blend and the 0.30-second clip have both finished. The repro applies the actual `LeftHand` bone transform to all 972 rigid-weighted hand vertices from the real mesh generator. Even the lowest one is 0.309 m above the floor.

`engine/rigs/biped/tl_rig_biped_moves.gd:83` and `engine/rigs/RIGS.md:53` specify that the left hand trails on the floor. This is the held pose on flat ground.

```bash
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_slide.gd"
```

```text
REPRO slide: FAIL held slide at tick 60, floor y=0, lowest of 972 left-hand vertices y=0.309 m
```

## A late-spawned biped holds its initial blink

`engine/rigs/tl_rig_biped.gd:265` · **Low**. A newly spawned character can keep its eyes shut for several seconds.

Setup ticks frame 0 and closes the eyes. The frame-driven blink restores the normal face only at phase 6. If the first controller tick is frame 100, that phase has already passed. At frame 120 the late-spawned biped still has the closed-eye scale, while a biped ticked continuously is open. With sequential ticks thereafter, the next restore is frame 210.

`engine/rigs/tl_rig_biped.gd:260` specifies a six-frame blink every 204 frames. `engine/rigs/tl_rig_node.gd:137` identifies the tick argument as the kernel frame counter, so a late spawn can legitimately start at a nonzero frame.

```bash
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_spawn_face.gd"
```

```text
REPRO spawn_face: FAIL frame=120 eye height for a biped spawned at 100: 0.07, expected 1.00
```

## The build-time blink expression keeps the eyes open

`engine/rigs/tl_rig_biped.gd:73` · **Low**. Two supported ways of requesting the same held expression produce visibly different faces.

Building with `expression = blink` sets the face to happy, eyes open. The blink branch then skips the periodic eye updates for that expression. Calling `set_param` with the same value on a second biped closes its eyes immediately. The difference persists through 240 ticks.

`engine/rigs/tl_rigs.gd:7` says same-name build parameters initialize the runtime parameters. `engine/rigs/tl_rig_biped.gd:191` implements the closed expression and line 260 describes it as holding the eyes shut.

```bash
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_blink.gd"
```

```text
REPRO blink: FAIL expected build-time blink eye height 0.07, got 1.00 at tick 240
```

## Changing the stick color at runtime leaves the original shaft in place

`engine/rigs/tl_rig_biped.gd:175` · **Low**. A pack can recolor a skater through the documented API but its stick keeps the wrong color.

A skater built with `colors.stick = car_red` has a different stick mesh hash from a default skater. Applying those colors to the default skater through `set_param` leaves its stick hash identical to the original. The `colors` handler rebuilds the skinned body. The separate stick mesh reads its palette key only during construction at line 124.

`engine/rigs/tl_rig_biped.gd:6` lists runtime `colors`, and `engine/rigs/RIGS.md:142` lists `stick` as a supported part key. The build-time control verifies that this palette change really changes the generated shaft.

```bash
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_color.gd"
```

```text
REPRO color: FAIL stick mesh: distinct build colors=true, runtime recolor kept old mesh hash=true, matches requested color=false
```

## The review scene puts a requested red skater in a blue jersey

`engine/rigs/review/review.gd:105` · **Low**. A red-team review capture shows the wrong uniform.

In skate mode the blue branch always runs because its condition is `team == blue or skate`. The red branch is unreachable. The repro opens the real review scene with both options and reads the jersey palette key from the built rig.

`engine/rigs/review/review.gd:5` advertises both team choices. Line 108 explicitly assigns the `car_red` palette to a red jersey.

```bash
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_team.gd" -- --mode=skate --team=red
```

```text
REPRO team: FAIL --mode=skate --team=red expected car_red jersey, got car_blue
```

## Suspicions (not reproduced)

- None retained.
