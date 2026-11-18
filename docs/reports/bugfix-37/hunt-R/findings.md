# D5 findings (arm a): walker and terrain work, 37ff186..d7d9fc8

How to run: from the worktree root, with `G` set to the Godot console exe (`tl doctor` prints it; here
`C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe`). Repros 4 and 6 use global class
names (TLRigs, TLBall), so they need the class cache: run `"$G" --headless --path engine --import` once in a fresh
worktree (takes about 3 s; it writes `engine/.godot/`, which is gitignored). Every repro is headless, counts ticks or
frames, starts nothing else, and frees its physics space.

```
G=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe
"$G" --headless --path engine --script ../docs/reports/astra-trial/d5/repro/<file>.gd 2>&1 | grep -E '^R[0-9]|ERROR'
```

Severity reflects what a player sees and how often. None of these is a state-hash break: the visitor's body is
outside every pack (world_space.gd header). I found no determinism break in scope.

---

## 1. A run slide or slope slide pose stays on after a game visit (medium)

- **Where**: `engine/kernel/world/visitor.gd:208-216` (`_drive_step` while hidden: rests the body, never touches the
  rig) and `visitor.gd:138-157` (`put`: resets body, yaw, rig rotation, not the clip). The clip is a hold clip:
  `engine/rigs/tl_rig_biped.gd:67` (`slide`, hold=true); `slope_slide` loops (`:68`). The only places that end them
  are the `end_slide` events in `_drive_step` (`visitor.gd:259-261`).
- **Failure**: if a person presses E while sliding (C while running, or on a steep bank), the game goes on stage
  (`view.gd:403` hides him), the body is rested, and on Q `visit.gd:_to_gate` calls `put()`. The rig is still in
  `slide`. He stands at the gate on his hip, and walks round in the slide pose, until a jump or a landing plays
  another clip.
- **Repro**: `repro/r4_clip_after_stage.gd` (needs the class cache)
- **Printed**:
  ```
  R4 sliding: body mode slide, rig clip 'slide'
  R4 2 s after put() at the gate: body mode ground, speed 0.00 m/s, rig clip 'slide'
  R4 then 2 s walking at 4.5 m/s: body mode ground, rig clip 'slide'
  ```

## 2. A pit with steep walls traps him: no jump at all in slope mode (medium)

- **Where**: `engine/kernel/world/terrain/world_body.gd:149`. `can_jump` is true only for `ground`, `slide`, or
  coyote `air`. In `slope` mode a jump press is buffered and then dropped. The slope branch (`:245-276`) only leaves
  `slope` for walkable ground or for no ground at all.
- **Failure**: walking down onto ground steeper than 55 degrees starts a slope slide (`_ground_move :328-330`). Where
  that ground does not end on walkable ground (two steep faces meeting: a pit, a V notch), he stays in `slope` mode
  forever. Steering never goes uphill (`:252-254`), and a jump that would clear the rim is refused. The only way out
  is a teleport.
- **Repro**: `repro/r2_slope_pit.gd`. A 0.8 m deep pit (less than the 0.94 m jump) with 62 degree walls, against the
  same pit with 45 degree walls. He walks in, then holds W outward at 9 m/s and presses jump every 10 ticks for up to
  1200 ticks.
- **Printed**:
  ```
  R2 pit walls 45 deg, 0.8 m deep (less than a jump, 0.94 m): after walking in feet (0.0, 0.0, -0.96); W(+z) at 9 m/s + jump every 10 ticks for up to 1200 ticks: feet (0.0, 0.39, 2.0), out at tick 62, jumps 2, ticks per mode { "air": 62, "ground": 1 }
  R2 pit walls 62 deg, 0.8 m deep (less than a jump, 0.94 m): after walking in feet (-0.03, -0.5, -0.02); W(+z) at 9 m/s + jump every 10 ticks for up to 1200 ticks: feet (-0.04, -0.5, -0.03), out at tick -1, jumps 0, ticks per mode { "slope": 1200 }
  ```
- **Not proven**: that the shipped landscape has such a pit. Candidates are the steep pad banks where a pad is cut
  into the land, the river channel (depth_m 5.6) and the two ponds at its ends. The mechanism is proven on built
  ground.

## 3. Kernel teleports are drawn as a glide now that physics interpolation is on for every pack (medium)

- **Where**: `engine/project.godot:30` (`common/physics_interpolation=true`, new in scope, project wide). The kernel's
  teleport calls never call `reset_physics_interpolation()`: `engine/kernel/api/tl_ball.gd:146-156` (`TLBall.place`,
  "a face-off, a reset after a goal"), `engine/kernel/api/tl_biped.gd:166-169` (`TLBiped.place`) and
  `tl_vehicle.gd:167`. Lane M added resets only to the visitor, TLChaseCam.snap and the stage re-base.
- **Failure**: every pack that places a ball, puck, skater or car (hockey's `_faceoff`, `main.gd:514-521`, after each
  goal) now has the frames rendered during that tick show the object partway between its old and new places. The
  puck streaks from the net to centre ice, and the skaters slide to their spots. Before the setting changed, the jump
  was clean.
- **Repro**: `repro/r6_place_interpolated.gd` (needs the class cache): a puck placed from x 0 to x 30 at tick 20.
  `get_global_transform_interpolated()` is read on every drawn frame.
- **Printed**:
  ```
  R6 physics_interpolation setting: true
  R6 80 frames drawn over 40 ticks; TLBall.place() from x 0 to x 30 at tick 20; frames drawn with the puck between the two places: 2 [6.42, 18.84]
  ```
  A second run printed `82 frames ... 2 [9.03, 21.45]`. Headless draws as fast as the machine allows, so how many
  frames fall inside the teleport tick, and where, changes from run to run. Every run so far has shown at least one
  in-between frame.

## 4. The visitor camera dives into his head under a pine crown 0.3-0.55 m above the point it looks at (medium)

- **Where**: `engine/kernel/world/visitor.gd:91` (`avoid_mask = 1 | 4`, crowns in the camera's mask, round 2), crown
  core `engine/kernel/world/terrain/world_space.gd:140-149` (from 2.2 s over the trunk foot), cast and pull-in
  `engine/kernel/api/tl_chase_cam.gd:118-151`.
- **Failure**: the camera sphere (0.3 m) is cast from the point looked at (1.7 m over his feet). Take a crown whose
  bottom is 0.3-0.55 m above that point. The cast meets the crown at once in every direction, up-swings included, so
  the camera is put 0.04-0.96 m from the point looked at, inside the figure's head (`avoid_min` 2.5 m cannot be met).
  One centimetre higher, the sphere starts inside the crown, Jolt ignores the starting overlap, and the camera is back
  at 8.71 m: it pops between the two. Landscape pines (`landscape.gd:426`, trunk 0.42 x scale, foot 0.2 m into the
  ground, scale 0.8-1.35) put a crown bottom in that band on flat ground for scales of about 1.10 to 1.22. That is
  roughly a fifth of the pines, anywhere within about 2 m of the trunk, with the camera on the open side. On sloping
  ground every pine has such a band on its uphill side.
- **Repro**: `repro/r1_cam_in_crown.gd` (fine sweep of standing height round the edge, -0.06 to +0.06 m) and
  `repro/r1b_cam_crown_band.gd` (coarse sweep, -0.8 to 0 m). Pine scale 1.1; visitor camera options; camera behind him
  in the open; mask 1 (round 1) against mask 1|4 (shipped).
- **Printed** (r1b, then the r1 edge):
  ```
  R1 pine scale 1.10, camera mask 1, ...: h-0.800:8.71m ... h-0.100:8.71m h+0.000:8.71m
  R1 pine scale 1.10, camera mask 5, ...: h-0.800:8.71m h-0.700:8.71m h-0.600:8.71m h-0.500:8.71m h-0.400:8.71m h-0.300:8.71m h-0.200:0.96m h-0.100:0.50m h+0.000:0.04m
  R1 (r1, mask 5): ... h-0.010:0.09m h-0.005:0.07m h+0.000:0.04m h+0.005:0.02m h+0.010:8.71m h+0.015:8.71m ...
  ```

## 5. While a game is on stage, the visitor camera avoids the ground at the wrong place (low)

- **Where**: `engine/kernel/world/draw/view.gd:394` re-bases the landscape (`landscape.transform =
  plot.affine_inverse()`). The visitor and `VisitorCam` are children of the landscape, while the world's physics space
  stays in landscape coordinates. `tl_chase_cam.gd:174-183` builds `_look` and the cast from GLOBAL positions and
  casts them into `avoid_space` unchanged.
- **Failure**: when the game on stage has no camera of its own, `view.gd:408` makes the visitor camera current. Every
  tick of that stage, the camera avoids geometry shifted by the plot's transform. Here it is pulled 4.13 m in by
  ground that is not between it and him. It can equally be left inside real geometry. `_anchor` also glides from the
  old global place to the new one, because there is no snap on entering.
- **Repro**: `repro/r5_cam_rebase.gd`: flat ground, a plot at (40, 3, 0) with yaw 30, re-based as `_set_stage`
  does.
- **Printed**:
  ```
  R5 landscape at identity: camera 8.71 m from the point looked at (wanted 8.71), avoid_pull 0.00
  R5 landscape re-based on a plot at (40, 3, 0) yaw 30: camera 4.58 m from the point looked at (wanted 8.71), avoid_pull 4.13; camera in landscape coordinates (0.0, 2.7, 4.47), the ground there is y 0
  ```

## 6. Walking at an angle into a too-steep bank stops him dead: not "a wall" (low)

- **Where**: `engine/kernel/world/terrain/world_body.gd:331-333`. An up-slope landing refuses the WHOLE move (returns
  `from`, `n = ZERO`), and `drive()` then zeroes the velocity (`:200-201`). The header (`:12`) says this is refused
  "as before (a wall)". Note: the old `walk()` refused the same way, so this is kept behaviour, but the new code and
  its header promise a wall.
- **Failure**: walking at 45 degrees into the foot of a 65 degree bank, the part of the wish along the bank is lost.
  He creeps 1.51 m in 3 s and is blocked in 149 of 180 ticks. Against a real wall in the same place he slides 9.36 m
  along it.
- **Repro**: `repro/r7_bank_diagonal.gd`
- **Printed**:
  ```
  R7 wall: 180 ticks walking at 4.5 m/s, 45 deg into it: moved 9.36 m along it (x), ends at (9.36, 0.0, 0.34), blocked 52 ticks, modes { "ground": 180 }
  R7 bank65: 180 ticks walking at 4.5 m/s, 45 deg into it: moved 1.51 m along it (x), ends at (1.51, 0.03, -0.01), blocked 149 ticks, modes { "ground": 176, "air": 4 }
  ```

## 7. `avoid_min` is documented as a chase-camera option but setup() rejects it (low, contract)

- **Where**: `engine/kernel/api/tl_chase_cam.gd:49-53`. The accepted list has `avoid_space`, `avoid_margin`,
  `avoid_mask`, `avoid_out`, but not `avoid_min`. `engine/kernel/API.md:416` (1.6) lists `avoid_min` among the
  `ctx.cameras.chase` options, and the class header documents it.
- **Failure**: a pack passing `avoid_min` gets `ERROR: TLChaseCam: unknown option 'avoid_min'`, and the value stays
  2.5.
- **Repro**: `repro/r3_cam_avoid_min.gd`
- **Printed**:
  ```
  ERROR: TLChaseCam: unknown option 'avoid_min'
  R3 asked avoid_margin 0.2 -> 0.20, avoid_min 1.0 -> 2.50
  ```

## 8. A slide pressed on the tick he runs off an edge keeps the slide pose through the fall (low)

- **Where**: `engine/kernel/world/terrain/world_body.gd:159-162` starts the slide, then `_ground_move` finds no
  ground and `:202-208` appends `end_slide` in the same tick. `engine/kernel/world/visitor.gd:259-261` plays `&""` for
  `end_slide` only when the mode BEFORE the tick was `slide` or `slope`; it was `ground`.
- **Failure**: the `slide` hold clip stays on while he falls, sitting on his hip in mid-air. It ends only when the
  landing clip plays.
- **Repro**: `repro/r8_slide_at_edge.gd` (needs the class cache): running at 9 m/s toward a 3 m drop, C pressed on
  each tick in turn until a slide starts on the edge tick.
- **Printed**:
  ```
  R8 pressed C at tick 49 on the edge: mode ground -> air, rig clip 'slide'; 10 ticks later, falling (mode air, feet y 2.54): rig clip 'slide'
  ```

## 9. The jump buffer is 6 ticks before landing, not BUFFER = 8 (low)

- **Where**: `engine/kernel/world/terrain/world_body.gd:145-150`. The buffer counts down at the start of every tick,
  the jump check runs before the landing in the same tick, so the jump can only fire the tick after landing. The
  header (`:8-9`) and `BUFFER: int = 8` say a press is kept 8 ticks. (walk.jump checks a press 5 ticks early only.)
- **Failure**: a press 7 or 8 ticks before the landing tick is lost: no jump on landing.
- **Repro**: `repro/r9_jump_buffer.gd`
- **Printed**:
  ```
  R9 first jump at tick 5 lands at tick 38; a second press k ticks before that landing tick: k1:jumps k2:jumps k3:jumps k4:jumps k5:jumps k6:jumps k7:no k8:no k9:no k10:no (BUFFER = 8)
  ```

---

## Suspicions I could not reproduce (labelled, not scored)

- **S1. Rotated pack ground fools `ground_cover`.** `draw_base.gd:216-236` uses the axis-aligned box of a transformed
  mesh. A pack ground sheet that is rotated inside its pack (a square at 45 degrees) would count as covering rim
  points it does not cover, and the hole would be cut: sky pits at the corners (blink B1 again). No pack found that
  does this.
- **S2. The hole state of an arrived plot can lag up to 9 frames.** `view_seam.gd:79-80` (`shut_holes` runs every 10
  process frames). When a game arrives, its hole may stay shut for up to 9 frames while its ground is drawn, so the
  pad and the pack ground could z-fight. Not rendered.
- **S3. Replaying a recorded visit may not reproduce the visitor's path.** The body walks in a space whose pack
  colliders are copied in wall-clock slices (`view_seam.gd:62-76`, `world_space.gd:214-268`, budget in usec), so
  under `--input` replay the body could depend on machine speed. This is older than today's change, which made the
  body velocity-based. Not run.
- **S4. Re-pressed keys after a focus loss may count as a new press.** `boot.gd:439-446` re-presses keys
  TL_EXE_KEYS holds. A held Space or C would then be a new jump or slide. Not tested with a second window.
