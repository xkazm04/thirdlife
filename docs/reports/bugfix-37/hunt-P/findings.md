# D5 findings · arm B

Godot 4.7.2, Jolt, 60 physics ticks per second. Run each command from the worktree root. The runner uses `TL_GODOT` or the repository's documented Windows executable and imports a fresh worktree when needed. It exits zero when the reported observation reproduces. Run all nine with `python docs/reports/astra-trial/d5/repro/run.py all`. The two pad cases use a 320 × 180 window at 0,1440 because headless landscape construction skips the village physics space and ground shader.

### 1. A rebuilt game silently loses its stage replay · high

`engine/kernel/runner/visit.gd:270` uses the number of nonzero action rows as the recording's length after the old input object has been freed. One tap on tick 18 of a 20-tick visit gives one row. The session writer rejects tick 18 in a one-tick record. The caller discards the error, clears the recording and leaves no stage replay for those inputs. The control closes the same recording while the input object is alive.

`python docs/reports/astra-trial/d5/repro/run.py record`

```text
rebuilt=false sampled_ticks=20 action_rows=1 action_tick=18 saved=true length=20
rebuilt=true sampled_ticks=20 action_rows=1 action_tick=18 saved=false length=-1
```

### 2. A closed village pad lets the walker fall through it · high

`engine/kernel/world/draw/view_seam.gd:99` closes the hole in the material while a plot with known ground awaits its game and picture. At `engine/kernel/world/landscape.gd:522`, the terrain collider already omits that plot's interior. The test builds this pre-arrival state, runs the viewer's hole update and places the walker at the height of the visible pad. With the plot still pending, gravity takes the idle walker 46.33 m below it in 120 ticks. This measures the consequence of the pending state. Arrival time in a live world varies.

`python docs/reports/astra-trial/d5/repro/run.py coldpad`

```text
arrived=false pictures=0 cut_radius_after=0.0 visible_pad_y=0.00 support=false idle_120_y=-46.33 grounded=false
```

### 3. Rotating a square floor opens an uncovered hole around it · medium

`engine/kernel/world/draw/draw_base.gd:223` counts a rotated mesh's axis-aligned bounding rectangle as ground. A centered 64 m square in a circular plot of radius 40 m receives no hole. Turn the same square 45° and the classifier reports 100% coverage, instructing the viewer to cut the world ground out. Vertical rays against the actual floor triangles miss 122 of the classifier's 144 sample points. Those points fall inside the 42.5 m cut.

`python docs/reports/astra-trial/d5/repro/run.py cover`

```text
plot_r=40 sheet=64x64 yaw0_own=false yaw45_own=true reported_cover=1.000 rays_missing=122/144
```

### 4. Jumping beside a trunk puts the camera inside its crown · medium

`engine/kernel/api/tl_chase_cam.gd:156` starts every candidate sweep at the smoothed look point. When a jump carries that point into the camera-only crown, the camera has no recovery for the initial overlap. The test uses the visitor's follow settings, its 1 | 4 mask and the tree collider produced by `add_trunk`. The walker jumps vertically 1.2 m from the trunk. An independent layer-4 point query finds the camera itself inside the solid crown for 32 ticks. This measures the modeled core, inside the branches covered by the lane's existing limitation.

`python docs/reports/astra-trial/d5/repro/run.py canopy`

```text
ticks=90 jump_tick=20 before_jump_camera_inside=0 anchor_in_crown=22 sightline_in_crown=32 camera_in_crown=32
```

### 5. A walker placed on a steep bank can stand there and jump · medium

`engine/kernel/world/terrain/world_body.gd:183` checks only whether the idle downward probe hit something. Placement resets the body to grounded. A hit on a 65° face therefore preserves standing and grants a ground jump, despite the 55° limit. This affects placement at spawn or a gate. The existing steep-bank test exercises entry from a flat ledge.

`python docs/reports/astra-trial/d5/repro/run.py bank`

```text
bank=65 limit=55 idle_ticks=600 drift_m=0.000 mode=ground jump=true
```

### 6. Entering a game mid-slide leaves the figure sliding after exit · medium

`engine/kernel/world/visitor.gd:211` resets the hidden walker's movement state during play. Gate placement at `engine/kernel/world/visitor.gd:150` resets it again. Neither transition ends the rig's held slide clip. The test runs into a slide, enters a stage, leaves through the normal gate callback and walks for three seconds. The body covers 13.24 m on foot while the rig still holds the slide pose.

`python docs/reports/astra-trial/d5/repro/run.py gate`

```text
entry_clip=slide after_gate_ticks=180 mode=ground distance_m=13.24 clip=slide
```

### 7. Flat-ground tours leave the hole open while a game is pending · medium

`engine/kernel/world/landscape.gd:58` gives the flat sheet its material without registering that material on the landscape node. The hole updater at `engine/kernel/world/draw/view_seam.gd:86` consequently returns early on the `--landscape=off` path. For a not-yet-arrived plot with no picture, the actual ground shader retains a cut 85 m across. Finding 2 exercises the separate village path, where this shader update succeeds.

`python docs/reports/astra-trial/d5/repro/run.py flatpad`

```text
flat_ground=true arrived=false pictures=0 cut_radius_before=42.5 cut_radius_after=42.5
```

### 8. Camera setup rejects its documented minimum avoidance distance · low

`engine/kernel/api/tl_chase_cam.gd:50` omits `avoid_min` from the accepted setup options. The public chase factory forwards its options to this method. A pack following `engine/kernel/API.md:416` gets an error and retains the default 2.5 m.

`python docs/reports/astra-trial/d5/repro/run.py option`

```text
ERROR: TLChaseCam: unknown option 'avoid_min'
avoid_min requested=4.0 applied=2.5
```

### 9. The native walk-case runner succeeds after selecting zero cases · low

`engine/kernel/world/walks/walk_case.gd:28` matches the filter against short names such as `jump`. Supplying the case's printed name `walk.jump` selects nothing. Line 67 treats zero successes out of zero cases as a successful exit, violating the found-zero rule. This affects direct filtered invocation. The unfiltered runner completed all eight cases.

`python docs/reports/astra-trial/d5/repro/run.py filter`

```text
WALKCASE done 0 0
godot_exit=0
```

### Unreproduced suspicion

- The 0.55 m step-up sweep looked capable of wedging the 1.8 m walker at a 2.0 m doorway. In 120 walking ticks it registered two blocked ticks, cleared the 3 m-long passage and reached z = 6.20 m from z = −2.00 m. The 2.6 m control reached z = 6.74 m. A permanent obstruction did not reproduce.
