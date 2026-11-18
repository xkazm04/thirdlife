# Bugfix-37 lane `rig` (engine/rigs)

| D-id | defect | status | files | regression check | proof (repro line before -> after) |
|---|---|---|---|---|---|
| D11 (Q10) | bones a clip omits keep a stale rotation; gaze accumulates | fixed | engine/rigs/tl_rig_node.gd (`_apply`), RIGS.md | rig.bugfix.pose_rest, rig.bugfix.gaze | r_gaze: `FAIL ... neck rotation 172.0 degrees` -> `PASS ... 28.0 degrees`; r_pose: `FAIL ... difference=12.0 degrees` -> `PASS ... difference=0.0 degrees` |
| Q11 | land-turn foot twist | fixed | engine/rigs/biped/tl_rig_biped_gait.gd (`land`) | rig.bugfix.land_turn | `FAIL ... control 0.0, turned-in-air -30.0` -> `PASS ... control 0.0, turned-in-air 0.0` |
| Q27 | late-spawn eyes shut | fixed | engine/rigs/tl_rig_biped.gd (`_post_pose`, `_face`) | rig.bugfix.spawn_face | `FAIL ... 0.07, expected 1.00` -> `PASS ... 1.00, expected 1.00` |
| Q28 | build-time blink ignored | fixed | engine/rigs/tl_rig_biped.gd (`setup`, `_post_pose`) | rig.bugfix.build_blink | `FAIL expected 0.07, got 1.00` -> `PASS expected 0.07, got 0.07` |
| Q29 | runtime `colors` does not recolour the stick | fixed | engine/rigs/tl_rig_biped.gd (`_stick_mesh`, `_param_changed`) | rig.bugfix.stick_color | `FAIL ... kept old mesh hash=true, matches=false` -> `PASS ... kept old=false, matches=true` |
| Q30 | review red skater unreachable | fixed | engine/rigs/review/review.gd | rig.bugfix.review_team | `FAIL ... got car_blue` -> `PASS ... got car_red` (control `--mode=skate` with no team: still car_blue) |
| Q31 | slide hand 0.31 m above floor vs doc "on the floor" | fixed by correcting the doc; changing the pose is deferred to the owner | engine/rigs/biped/tl_rig_biped_moves.gd (doc comment), RIGS.md:53 | none (doc only) | r_slide still `FAIL ... lowest of 972 left-hand vertices y=0.309 m` (unchanged on purpose) |

## What each fix does
- **D11**: `TLRigNode._apply` now writes every bone: a bone the pose names takes its rotation; a bone it does not name goes back
  to its rest rotation (identity), the value `mix` already blends a missing bone towards. So `fall` (no Neck) no longer feeds
  the look_at correction its own last result (it composed `extra * current` every tick), and `cheer -> idle` no longer leaves
  the shoulders raised. Rotation only; face bones (scale/position) are untouched. Bot `look_at` sets an absolute Head
  rotation after `_apply`, so it is unaffected.
- **Q11**: `TLRigBipedGait.land()` sets `_yaw_seen = NAN`. `step()` is not called in the air, so the yaw from before take-off
  survived and the first grounded `step()` rotated the newly planted feet by the whole air turn. The feet are put down in the
  body's current frame, so there is no earlier heading to keep.
- **Q27/Q28**: the face is now a function of the frame alone: inside a blink window (frame % 204 < 6, not for `blink`)
  the blink face, otherwise `_expr()` (the expression's face). `setup` calls `_expr()` instead of `_face(1, 0)`. `_face`
  skips rewriting an unchanged (mood, blink), so the per-tick call is cheap.
- **Q29**: the stick mesh is built by `TLRigBipedMesh._stick_mesh(colors)`; `colors` set at runtime rebuilds it as well as the body.
- **Q30**: `team = args.team, or "blue" for a skater`; red now reachable, the default skater stays blue.
- **Q31 (chosen option: correct the doc)**: a sweep of the left arm alone (upper arm x -64..0, z -70..15, elbow 0..10) could
  not get the hand lower than 0.095 m: the shoulder is too high in this pose. Reaching the floor needs the torso to lean
  left (Spine/Chest roll), which changes the slide's silhouette: a look decision for the owner. The doc comment and RIGS.md
  now say "left arm trailing low behind (the hand about 0.3 m above the floor)". Sweep script:
  `docs/reports/bugfix-37/rig/slide_sweep.gd.txt` (rename to .gd and run: `timeout 200 "$G" --headless --path engine --script <copy>.gd`). Side figure from the sweep: the lowest vertex of the whole held slide pose is
  y = -0.151 m (some part, likely a leg or the hip, is below the floor). I did not look into it; it may be worth a separate finding.

## Commands
Repros (from W, `G` = the Godot console exe, `R=docs/reports/bugfix-37/hunt-Q/repro`):
```
timeout 200 "$G" --headless --path engine --script "$PWD/$R/r_gaze.gd"
timeout 200 "$G" --headless --path engine --script "$PWD/$R/r_pose.gd"
timeout 200 "$G" --headless --path engine --script "$PWD/$R/r_land_turn.gd"
timeout 200 "$G" --headless --path engine --script "$PWD/$R/r_spawn_face.gd"
timeout 200 "$G" --headless --path engine --script "$PWD/$R/r_blink.gd"
timeout 200 "$G" --headless --path engine --script "$PWD/$R/r_color.gd"
timeout 200 "$G" --headless --path engine --script "$PWD/$R/r_team.gd" -- --mode=skate --team=red
timeout 200 "$G" --headless --path engine --script "$PWD/$R/r_slide.gd"
```
Selftest: `bash engine/tools/selftest.sh rig.bugfix` (7 cases), all rig cases: `bash engine/tools/selftest.sh rig.`

## Files
Changed: engine/rigs/tl_rig_node.gd, engine/rigs/tl_rig_biped.gd, engine/rigs/biped/tl_rig_biped_gait.gd, engine/rigs/tl_rig_biped_mesh.gd (`_stick_mesh(colors)`, moved out of tl_rig_biped.gd for the 600-line budget),
engine/rigs/biped/tl_rig_biped_moves.gd (doc comment only), engine/rigs/review/review.gd, engine/rigs/RIGS.md (slide row; a
sentence in "How animation works" on the rest rotation).
Added: engine/rigs/review/bugfix_rig_cases.gd, engine/rigs/review/bugfix_rig_team.gd, engine/tools/selftest.d/330-bugfix-rig.sh,
docs/reports/bugfix-37/rig/slide_sweep.gd.txt (investigation only), this report. 300-rig.sh not edited.

## Tests run and expectations
- `selftest.sh rig.`: 12 passed, 0 failed (kit.bot, rig.biped_walks_and_skates walk 2.3 m/s, rig.vehicle_drives,
  rig.feet_plant 0.025..0.097 m/s, rig.moves jump-run sole slide 0.204 m/s (limit 0.6; I have no pre-fix figure for it),
  and the 7 rig.bugfix cases).
- `tl check --tier full --only kit.selftest`: PASS 91/91 (two runs, same hashes).
- `tl check --tier full --only packs`: PASS, found 2, completed 2, verb runs 33 of 33. The state hash covers only physics
  bodies (kernel/host/statehash.gd) and rig bones are not bodies, so hockey's hash cannot move because of the rig pose.
  hockey bot hashes: bot_hockey a29dcdf02a16dd1c@4186, regular 28d668ebc65abf8e@1530, newcomer 91562a2ecebef858@3563.
- No test expectation moved. Visible behaviour changes: a bone that a clip omits now goes back to rest (for example, after cheer
  the shoulders drop back; while in `fall` the neck and head start from rest). A biped whose ticks skip frames now shows its
  expression's face at once.

## Questions for the Director
- No new public member, no KERNEL_API bump (`_face_now` is private; `TLRigBipedMesh._stick_mesh(colors)` is an underscore static on the rig's mesh helper; arch api-v1 PASS at 1.8).
- Owner: should the slide's trailing hand really touch the floor? That needs the torso to lean left. The pose is unchanged for now.
