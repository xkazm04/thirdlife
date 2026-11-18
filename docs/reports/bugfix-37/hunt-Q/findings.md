# D5 findings, arm C (Opus directing GPT 6.2 Astra)

All commands run from the worktree root in Git Bash, with
`G=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe` set first (each repro file also carries its
full command as its first comment). The project must have been imported once (`"$G" --headless --path engine --import`).

Every repro was written by Astra and **re-run by the Director (Opus) on this worktree**; "printed" is the Director's run.
Line numbers are of the current files. Without git (trial rule) I could not tell which lines changed today; *(may predate
today)* marks a finding in a scoped file but in code that does not look like the walker-feel work. "Reach" notes say whether
the shipped game gets there (read from the callers, cross-checked by an Astra skeptic run, `astra/review.md`).


## High

### 1. A stopped `world.sh same` is reported as PASS
`engine/tools/selftest.sh:205` (verdict at 206). **High**: the determinism gate certifies a comparison that never ran (CLAUDE.md
"a stopped run is never a pass", `docs/GATE-HONESTY.md`). When the child dies before printing anything, `grep -q '^PASS world.same'`
fails, the fallback `grep -E 'DIFFERENT|NO HASH|FAIL|not every'` matches nothing, `why` stays empty and `verdict` prints PASS. The
child's exit status is never read. The repro kills only the `world.sh same` child it starts itself (via BASH_ENV), before its
first hash. *(may predate today)*
```
bash docs/reports/astra-trial/d5/repro/r_stopped_world.sh
```
printed:
```
Stopped world.sh control exit=143
PASS world.same  (pack_min, ex_bounce and two ex_wall in one process: 4 hashes equal to the solo runs, three times)
selftest: 1 passed, 0 failed (reports in docs/reports/astra-trial/d5/repro)
REPRO stopped_world: FAIL world.same returned success after the world.sh child stopped before its first hash
```

### 2. The world's copy of a pack's primitive colliders loses its shapes when the pack's nodes go
`engine/kernel/world/terrain/world_space.gd:317` (immediate copy) and `:263` (sliced copy, `step_pack`). **High** if reached:
the visitor falls through a floor that is still drawn. Concave faces are re-made and kept in `_keep` (line 31: "Shape3D
resources that must outlive their bodies"), but box/sphere/capsule shapes are attached by the PACK's own `Shape3D`
(`_static(sh, ...)`) and never kept; when the holder is freed the resource dies and the body has no shape. `begin_pack` says
(line 193) "the pack's nodes may move or go later". Reach (Director read `draw/view.gd:351-361`: colliders are copied only on a plot's FIRST arrival; Astra skeptic traced the rest): a next round frees the old holder and rebuilds the pack from its seed, so in `walks/tour_next_round.json` the walker room's `TLBodies` box walls (`engine/kernel/examples/ex_walker/scripts/main.gd:24`) stay drawn but lose collision after the first restart (not run end to end). *(the copying is P14; may predate today)*
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_ledger_collider.gd"
```
printed:
```
REPRO ledger_collider immediate: FAIL before=0.50 expected_after=0.50 actual_after=nan
REPRO ledger_collider sliced: FAIL before=0.50 expected_after=0.50 actual_after=nan
```


## Medium

### 3. A rebuilt on-stage game drops the recorded visit of that game
`engine/kernel/runner/visit.gd:270`. **Medium**: data loss with `--record`, in the fallback added today (walker-feel round 2,
comment at 262). When the holder was rebuilt while on stage, `length` is written as the number of SPARSE entries
(`_stage_rec[2].size()`) instead of the ticks sampled (`visit.gd:10`: "`length` the samples taken"). Ten ticks with one press at
tick 9 give `length` 1; the session writer rejects frame 9 >= length and no file is written (the caller ignores the error). The
control (input still alive) writes length 10.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_stage_record.gd"
```
printed:
```
sampled frames=10, recorded entries=[[9, "move", 1.0]]
REPRO stage_record: FAIL expected first round sidecar with length 10, file exists=false
control with input alive: length=10, entries=[[9.0, "move", 1.0]]
```

### 4. A bot's held press survives the hand-over to the person on stage
`engine/kernel/runner/visit.gd:239-250` (`stage()`). **Medium**: entering a game sets `bot_off` and `accept_devices` but never
releases what the bot injected; `TLInput.press` holds "until `release()`" (`tl_input.gd:151`). The drive bot holds `gas` this way
(`engine/seeds/seed_drive/tests/bot_laps.gd:42`), so the person's car can keep accelerating with W up. Reach (skeptic review, read not run): the boot village runs drive in bot mode; entering its stage while the bot accelerates leaves `gas` held. *(may predate today)*
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_stage_input.gd"
```
printed:
```
REPRO stage_input: FAIL bot_off=true, physical W=false, gas active on 120/120 player ticks
```

### 5. The avoiding camera goes inside a body its query sphere already touches at the look point
`engine/kernel/api/tl_chase_cam.gd:158` (`_cast`). **Medium**: the header (line 11) promises "the camera never goes inside what
that space holds". `cast_motion` ignores a body the sphere overlaps at its start, so when the look point is within
`avoid_margin` of a body the whole way counts as free and the camera is placed inside it (z=7 inside a wall spanning z=0.2..10.2).
In the visitor his capsule (radius 0.35 > margin 0.3) keeps layer-1 walls off the look axis, so it needs a camera-only crown
(layer 4) near the look point, or a pack using `avoid_space` directly. Reach (skeptic review, calculated not run): a pine crown starts about 1.81 m above ground for scale 1; standing 1 m from the trunk the 1.7 m look point is 0.11 m under it, inside the margin, and a jump raises the anchor about 0.87 m.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_camera_wall.gd"
```
printed:
```
REPRO camera_wall: FAIL expected camera outside wall, inside at 1.2 m clearance=false, inside at 0.2 m clearance=true, camera z=7.00
```

### 6. A shut hole shows the pad, but the visitor's collider under it stays open
`engine/kernel/world/draw/view_seam.gd:104-118` (`close_holes`, today's B2 fix) against `engine/kernel/world/landscape.gd:517-522`
(the terrain collider skips the plot's inside). **Medium**: for a plot whose game has not arrived and has no cached picture, the
world's pad is drawn (hole radius 0) but there is no ground under it: a body on the visible pad falls 11.8 m in 60 ticks. Reach (skeptic review, read not run): a race on first arrival with no cached picture, e.g. `walks/visitor_walk.json` starts 22 m from the paddle plot's rim; nobody has recorded a person falling there.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_unloaded_pad.gd"
```
printed:
```
REPRO unloaded_pad: FAIL hole_radius=0.0 visible_pad_y=0.00 support_y=nan feet_y_after_60=-11.80
```

### 7. Rim coverage uses the axis-aligned box of a rotated deck: a hole opens where nothing covers it
`engine/kernel/world/draw/draw_base.gd:222` (`ground_cover`, today's lane T work). **Medium**: line 206 defines the figure as "the
share of the plot's rim that the pack's own wide meshes really cover" (minimum 0.95, line 213). A 40 x 90 m deck turned 45 degrees
covers 48 of 144 rim samples but its AABB encloses all 144, so it is accepted as ground and the 42.5 m hole opens: sky through
the ground, the blink class lane T fixed.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_rotated_ground.gd"
```
printed:
```
REPRO rotated_ground: control yaw=0 physical_coverage=48/144 reported=0.333 hole_radius=0.0
REPRO rotated_ground: FAIL yaw=45 physical_coverage=48/144 reported=1.000 hole_radius=42.5
```

### 8. A body put at rest on ground steeper than the limit stands there for ever
`engine/kernel/world/terrain/world_body.gd:179-189` (the standing branch). **Medium**: the header (line 10) says ground steeper than
`max_slope_deg` makes him slide; the standing shortcut only checks that SOME ground is under him, never its normal. Put at rest
on a 65 degree bank (limit 55; `put`, setup, leaving a game) he stays grounded 120 of 120 ticks and moves 0 m.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_steep_rest.gd"
```
printed:
```
REPRO steep_rest: FAIL slope=65 limit=55 grounded_ticks=120/120 downhill_metres=0.000
```

### 9. Entering a game during a run slide leaves the figure in the slide pose after leaving
`engine/kernel/world/visitor.gd:211-218` (`_drive_step`, hidden branch) and `put()` (138-157). **Medium**: the hidden branch rests
the body, `put` rests it again, nothing plays `&""`; the body has no slide left to end, so the held `slide` clip stays.
WORLD.md:197 says the visitor ends a held slide with `&""`. Two seconds standing still after returning: still `slide`.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_stage_pose.gd"
```
printed:
```
before stage: body=slide, rig=slide
REPRO stage_pose: FAIL 120 idle ticks after return, body=ground, speed=0.0, rig clip='slide'
```

### 10. Bones a clip omits keep their last rotation; the gaze correction then accumulates
`engine/rigs/tl_rig_node.gd:207` (`_apply` writes only the bones in the pose). **Medium**: the blend (line 200) treats a missing
bone as identity, `_apply` leaves it as it was. With `look_at` set (hockey does: `packs/hockey/scripts/main.gd:505`) during the
part of `fall` that omits `Neck`, `_post_pose` multiplies its correction onto the previous neck rotation every tick: 172 degrees at
tick 27 (limit 28). Second symptom: `cheer` then `idle` with blend 0 leaves `LeftShoulder` 12 degrees off a fresh rig for good.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_gaze.gd"
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_pose.gd"
```
printed:
```
REPRO gaze: FAIL at fall tick 27 a horizontal target has neck rotation 172.0 degrees, authored neck neutral, look limit 28 degrees
REPRO pose: FAIL expected identical idle shoulders after 120 ticks, difference=12.0 degrees
```

### 11. Turning in the air twists the newly planted feet on landing
`engine/rigs/tl_rig_biped.gd:222` with `engine/rigs/biped/tl_rig_biped_gait.gd:115,199-210`. **Medium** (today's gait): `land()`
plants both feet under the body at the pelvis heading, then the next `step()` applies the yaw correction meant for feet that
stayed on the floor, using the yaw change since the last grounded tick. A body that turned 30 degrees in the air lands with its
boots 30 degrees off; the control (same jump, no turn) lands at 0.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_land_turn.gd"
```
printed:
```
REPRO land_turn: FAIL after landing blend: control boot yaw 0.0 degrees, turned-in-air boot yaw -30.0 degrees relative to the same body heading
```

### 12. boil.py misreads a 720p clip: a still picture measures as 100 % flicker
`engine/rigs/review/boil.py:13-17`. **Medium** (the tool that measured the shimmer work gives a false figure): the default band
200..420 scales to 133..280 on a 1280x720 clip (look.sh's default size), an odd height of 147; ffmpeg's crop of a yuv420p stream
rounds it to an even height, but the reader reshapes the bytes as 147-row frames, so each frame is misaligned against the next.
Twelve identical frames: mean 222, 100 % flips; the same file read full height: 0.
```
python docs/reports/astra-trial/d5/repro/r_boil.py
```
printed:
```
boil frames=12 band=0..720 mean=0.000 flips_pct=0.000 (...)
boil frames=11 band=133..280 mean=222.000 flips_pct=100.000 (...)
REPRO boil: FAIL expected 12 identical frames, zero mean change and zero flips
```

### 13. A selftest filter that matches nothing exits 0
`engine/tools/selftest.sh:960-961`. **Medium** (gate honesty: found 0 is never PASS): `walk.jmup` runs 0 cases, prints
`0 passed, 0 failed` and exits 0 because only `fail` is tested.
```
bash docs/reports/astra-trial/d5/repro/r_empty_filter.sh
```
printed:
```
selftest: 0 passed, 0 failed (reports in docs/reports/astra-trial/d5/repro)
REPRO empty_filter: FAIL expected a nonzero status for zero matching cases, got 0
```

### 14. walk_case.gd: asking for a case by its printed name runs nothing and exits 0
`engine/kernel/world/walks/walk_case.gd:29` (filter on short names) and `:67` (`quit(0 if _ok == _n ...)`). **Medium** (same law,
today's file): the header names the cases `walk.*`; `-- walk.jump` matches none of the short names, `WALKCASE done 0 0`, exit 0.
```
bash docs/reports/astra-trial/d5/repro/a_walk_filter.sh
```
printed:
```
filter=jump exit=0 WALKCASE done 1 1
filter=walk.jump exit=0 WALKCASE done 0 0
REPRO walk_filter: FAIL selected an existing case, ran zero and exited successfully
```

### 15. A road whose last points reach the river aborts the landscape build
`engine/kernel/world/landscape.gd:288-289` (the bridge probe reads `pts[(a+b)/2 + 1]`). **Medium** (a SCRIPT ERROR stops `build()`
before the terrain and its collider are recorded; unusual input: the shipped village road crosses the river well inside its
length). WORLD.md:135 puts a bridge "where the main road is within 17 m of the river"; a road ending 16 m from it qualifies only
at its last sample. *(may predate today)*
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_bridge_endpoint.gd"
```
printed:
```
SCRIPT ERROR: Out of bounds get index '16' (on base: 'PackedVector2Array')
REPRO bridge_endpoint: FAIL road_end=(0,0) river_x=16 build_completed=false
```

### 16. A plot-covering floor made of two big triangles vanishes from both distant pictures
`engine/kernel/world/draw/draw_pictures.gd:396-401`. **Medium**: the rule says "a triangle wholly outside the plot is not part of
the stand-in", but the test looks only at the corners: a 100 x 100 m plane on a 40 m plot has all four corners outside, so both
triangles (which cover the whole plot) are dropped; the same plane subdivided keeps 30 triangles per picture.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_crossing_faces.gd"
```
printed:
```
REPRO crossing_faces: FAIL subdivisions=0 source_covers_plot=true mid_triangles=0 far_triangles=0
REPRO crossing_faces: control subdivisions=3 source_covers_plot=true mid_triangles=30 far_triangles=30
```

### 17. Optional pad height falls back to the LIFTED plot origin
`engine/kernel/world/landscape.gd:103`. **Medium**: line 7 defines `pad_h` as "the walk's plot origin y", line 12 says `plots` come
with the lift included, so a pack whose floor is at local y=5 gets a pad at -5 and a collider 4.68 m under its rim. Reach (Director read `draw/view.gd:351-361`: colliders are copied only on a plot's FIRST arrival; Astra skeptic traced the rest): a next round frees the old holder and rebuilds the pack from its seed, so in `walks/tour_next_round.json` the walker room's `TLBodies` box walls (`engine/kernel/examples/ex_walker/scripts/main.gd:24`) stay drawn but lose collision after the first restart (not run end to end).1
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_pad_lift.gd"
```
printed:
```
REPRO pad_lift: control explicit_pad=true pack_rim_y=0.00 pad_y=0.00 collider_y_at_r39=0.00
REPRO pad_lift: FAIL explicit_pad=false pack_rim_y=0.00 pad_y=-5.00 collider_y_at_r39=-4.68
```


## Low

### 18. TLChaseCam.setup rejects `avoid_min`, an option API.md lists
`engine/kernel/api/tl_chase_cam.gd:49-50` (the allow list) against `engine/kernel/API.md:416`. **Low**: `push_error` "unknown option
'avoid_min'" and the value stays 2.5. (Found independently by the Director and by Astra.)
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_avoid_min.gd"
```
printed:
```
ERROR: TLChaseCam: unknown option 'avoid_min'
REPRO avoid_min: FAIL expected setup option 4.0 m, got 2.5 m
```

### 19. `snap()` after a teleport and turn puts the camera on the old side
`engine/kernel/api/tl_chase_cam.gd:57-68`. **Low**: `snap()` refreshes the anchor and the look point but not `_heading`, so the
first drawn tick after `visitor.put()` (`_to_gate` turns him away from the venue) shows him from the side; the next tick corrects
it in steer mode (stiffness 1); a scripted camera (stiffness 0.05) swings round over seconds.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_snap_heading.gd"
```
printed:
```
REPRO snap_heading: FAIL expected 8.0 m behind the teleported target immediately, got 0.0 m
```

### 20. `use_velocity`: an exact reversal never turns the camera
`engine/kernel/api/tl_chase_cam.gd:172`. **Low** (latent: no pack or kernel caller sets `use_velocity`): `lerp(h, -h, 0.07)` still
points along `h` and is normalised back to `h` every tick; 300 ticks of reverse travel keep the camera 7 m AHEAD.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_reverse_camera.gd"
```
printed:
```
REPRO reverse_camera: FAIL after 300 reverse ticks, expected 7.0 m behind travel, camera 7.0 m ahead
```

### 21. All roads are graded with the first road's half width
`engine/kernel/world/terrain/village_terrain.gd:131-133`. **Low** (in the shipped landscape the main road is first, so the spur
roads, `half * 0.8` at landscape.gd:187, are graded at the main road's width; the 12.8 m error needs a narrower road first):
each road carries its own `half` (line 28); "lists, not singletons".
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_road_width.gd"
```
printed:
```
REPRO road_width: FAIL expected_y=19.98 wide_first=19.98 narrow_first=7.19
```

### 22. A filtered `rig.*` claim takes its verdict from an old kit.bot report
`engine/tools/selftest.sh:157-159`. **Low** *(may predate today)*: `rig.vehicle_drives` alone skips the `kit.bot` run but reads
`kit.bot.json` from `TL_SELFTEST_DIR`; with a stale file it passes on figures it never measured (99 m/s).
```
bash docs/reports/astra-trial/d5/repro/r_stale_case.sh
```
printed:
```
selftest: 0 passed, 1 failed (...)                      <- clean directory, exit 1
PASS rig.vehicle_drives  (TLRigs vehicle: top 99 m/s, wheel yaw 0.25 rad when steering right)   <- stale file, exit 0
REPRO stale_case: FAIL identical selected case, empty report directory exit 1, retained result exit 0
```

### 23. blink_detect.py's "3x3 erosion" checks four neighbours, not eight
`engine/kernel/world/walks/blink_detect.py:44-51`. **Low**: the docstring says "it and its eight neighbours"; the code ANDs only
up/down/left/right, so 14 isolated 5-pixel crosses (no full 3x3 block anywhere) pass the default 12-pixel event threshold.
```
python -B docs/reports/astra-trial/d5/repro/a_blink_erosion.py
```
printed:
```
full 3x3 foreground neighbourhoods=0
REPRO blink_erosion: FAIL expected 0 surviving pixels, got 14 (default event threshold 12)
```

### 24. blink_detect.py drops the exact sky mask when little sky is visible
`engine/kernel/world/walks/blink_detect.py:89-90`. **Low**: the magenta mask is used only if a sampled frame has more than 50
magenta pixels; looking down (50 sky pixels) the colour guess is used and 2,964 grey court pixels count as a hole.
```
python -B docs/reports/astra-trial/d5/repro/a_sky_mask.py
```
printed:
```
magenta pixels above horizon=51, sky_mask=True, reported hole pixels=0
magenta pixels above horizon=50, sky_mask=False, reported hole pixels=2964
REPRO sky_mask: FAIL expected 0 holes below horizon, got 1
```

### 25. blink_detect.py crashes when the capture size changes mid-run
`engine/kernel/world/walks/blink_detect.py:86-91`. **Low**: one mask is built from the first picture and applied to all; a window
resized during capture (each .raw carries its own size in frames.jsonl) ends in a traceback with no totals line.
```
python -B docs/reports/astra-trial/d5/repro/a_capture_resize.py
```
printed:
```
ValueError: operands could not be broadcast together with shapes (270,400) (270,480)
REPRO capture_resize: FAIL 3 indexed RGB8 frames, exit=1, totals printed=False
```

### 26. A finished run slide is "ended" again when he later walks off a ledge
`engine/kernel/world/terrain/world_body.gd:207`. **Low** (no visible effect today: `visitor.gd` plays `&""` on `end_slide` only
when the mode was slide or slope): `_slide_t` is not reset when the slide ends, so the next ground-to-air step emits a second
`end_slide` in `drive()`'s documented events.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_stale_slide.gd"
```
printed:
```
REPRO stale_slide: FAIL tick=258 transition=ground->air events=["end_slide"] slide_starts=1 slide_ends=2
```

### 27. A biped first ticked at a late frame keeps its eyes shut until the next blink cycle
`engine/rigs/tl_rig_biped.gd:255-265`. **Low**: setup ticks frame 0 (eyes closed); they reopen only at blink phase 6, which a rig
first ticked at frame 100 has passed: still shut at frame 120, open again at 210.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_spawn_face.gd"
```
printed:
```
REPRO spawn_face: FAIL frame=120 eye height for a biped spawned at 100: 0.07, expected 1.00
```

### 28. `expression = blink` at build time keeps the eyes open; the same value via set_param closes them
`engine/rigs/tl_rig_biped.gd:73` (build) against `:191` (set_param). **Low**: tl_rigs.gd:7 says build parameters initialise the
runtime ones.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_blink.gd"
```
printed:
```
REPRO blink: FAIL expected build-time blink eye height 0.07, got 1.00 at tick 240
```

### 29. Runtime `colors` does not recolour the stick
`engine/rigs/tl_rig_biped.gd:175` (the `colors` handler rebuilds the body only; the stick reads its palette key at build, 124).
**Low**: RIGS.md:142 lists `stick` as a colour key.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_color.gd"
```
printed:
```
REPRO color: FAIL stick mesh: distinct build colors=true, runtime recolor kept old mesh hash=true, matches requested color=false
```

### 30. The review scene cannot show a red skater
`engine/rigs/review/review.gd:105`: `team == "blue" or skate` makes the red branch unreachable in skate mode. **Low** (tool).
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_team.gd" -- --mode=skate --team=red
```
printed:
```
REPRO team: FAIL --mode=skate --team=red expected car_red jersey, got car_blue
```

### 31. The held run-slide pose leaves the trailing hand 0.31 m above the floor
`engine/rigs/biped/tl_rig_biped_moves.gd:85-103` (`slide`). **Low** (a look defect of today's moves): the doc comment (line 83) and
`engine/rigs/RIGS.md:53` say the left hand trails on the floor; with the clip's own hip drop applied (the repro builds the
default scale-1 biped and plays the real held clip), the lowest of the hand's 972 vertices is 0.309 m above the floor. In play
the held pose is reached at tick 18 of a ~55-tick slide.
```
timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/r_slide.gd"
```
printed:
```
REPRO slide: FAIL held slide at tick 60, floor y=0, lowest of 972 left-hand vertices y=0.309 m
```

### 32. A one-tick 90 degree mouse turn draws one camera frame inside an obstacle
`engine/kernel/api/tl_chase_cam.gd:143-159` with physics interpolation on (`engine/project.godot`). **Low**: the avoidance checks
the two tick poses only; the drawn frame between them is a straight interpolation along the chord, which can pass through a
box both poses clear (header line 11: "never goes inside"). A person's turn is not clamped in yaw: the shipped
`walks/wf_feel.devices.json` sends 600 px (90 degrees) in one tick. Run with `--fixed-fps 120`:
```
timeout 120 "$G" --headless --fixed-fps 120 --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/a_camera_cut_wall.gd"
```
printed:
```
REPRO camera_cut_wall: FAIL physics poses inside=0, interpolated frames inside=1, last interior position=(4.0, 1.0, 4.0)
```


## Suspicions and items not accepted (do not score)

- **Not accepted: `look.sh clip` deletes `<out>.avi` before validating the kind** (`engine/tools/look.sh:100`, repro
  `docs/reports/astra-trial/d5/repro/r_clip_input.sh` prints FAIL). The `.avi` is look.sh's own intermediate movie
  (`--write-movie "$avi"`); removing a stale one is its design. Listed so a reviewer sees it was weighed.
- Suspicion (Director, not reproduced): `visitor.gd` `_frame_usec` gains one entry per drawn frame for a whole visit and is read
  only at the end of a scripted walk; in a person's long visit it is never used and never trimmed (a slow growth, about 1.7 MB
  an hour at 60 fps).
- Suspicion (not reproduced end to end): findings 2, 4, 5, 6 and 17 are proven at the function level by their repros; whether the
  shipped walks reach them was read from the callers (Director for 2 and 17, Astra's skeptic run `astra/review.md` for all),
  not run in a world.
