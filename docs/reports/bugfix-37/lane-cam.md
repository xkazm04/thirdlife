# bugfix-37 lane `cam`: the chase camera (TLChaseCam)

| D-id | defect | status | files | regression check | proof (before -> after) |
|---|---|---|---|---|---|
| D5 (Q5) | the cast ignores a body the sphere overlaps at its start: the camera stands inside a wall 0.2 m behind the point looked at | fixed | tl_chase_cam.gd | `cam.wall_start` | `a_camera_wall`: `FAIL ... inside at 0.2 m clearance=true, camera z=7.00` -> `PASS ... inside at 0.2 m clearance=false, camera z=0.05` |
| D5 (R4) | a crown 0.3-0.55 m over the point looked at: the camera ends 0.04-0.96 m from it (in his head), then pops to 8.71 m one cm higher | fixed | tl_chase_cam.gd | `cam.crown_band` | `r1b` mask 5: `h-0.200:0.96m h-0.100:0.50m h+0.000:0.04m` -> `8.71m` at every height; `r1` mask 5: `h-0.060:0.32m .. h+0.005:0.02m h+0.010:8.71m` -> `8.71m` at all 25 heights. A sweep over pine scales 0.80-1.35 and heights -1.0..+0.3 m (396 poses): nearest 8.71 m, 0 poses inside a crown or a trunk |
| D5 (P4) | a jump beside a trunk: the camera sits inside the crown | fixed (the solid part); see the choice below | tl_chase_cam.gd | `cam.canopy_jump` | `run.py canopy`: `anchor_in_crown=22 sightline_in_crown=32 camera_in_crown=32` -> `anchor_in_crown=22 sightline_in_crown=26 camera_in_crown=22`: the camera is in the crown ONLY on the 22 ticks the point looked at is in it (was 10 more) |
| D17 | `setup()` rejects `avoid_min` | fixed | tl_chase_cam.gd | `cam.avoid_min` | `a_avoid_min`: `FAIL ... got 2.5 m` -> `PASS ... got 4.0 m`; `run.py option`: `ERROR: unknown option 'avoid_min'` -> `avoid_min requested=4.0 applied=4.0` |
| D18 (R5) | on stage the visitor camera casts in global coordinates against the landscape-frame space | fixed (frame + snap on entering) | tl_chase_cam.gd, view.gd | `cam.rebase` | `r5_cam_rebase` (unchanged hunter script): `re-based ... camera 4.58 m ... avoid_pull 4.13` -> `camera 8.71 m ... avoid_pull 0.00` |
| Q19 | `snap()` keeps a stale `_heading` | fixed | tl_chase_cam.gd | `cam.snap_heading` | `a_snap_heading`: `FAIL ... got 0.0 m` -> `PASS ... got 8.0 m` |
| Q20 | `use_velocity`: an exact reversal never turns the camera | fixed | tl_chase_cam.gd | `cam.reverse` | `a_reverse_camera`: `FAIL ... camera 7.0 m ahead` -> `PASS ... camera -7.0 m ahead` |
| Q32 | a one-tick 90 degree turn draws one interpolated frame inside a box | fixed (clean root fix found) | tl_chase_cam.gd | `cam.cut_wall` | `a_camera_cut_wall --fixed-fps 120`: `FAIL ... interpolated frames inside=1` -> `PASS ... interpolated frames inside=0` |

All 8 regression cases were seeded red: run against `git show HEAD:engine/kernel/api/tl_chase_cam.gd` (swapped in and back),
all 8 printed `fail` with the hunters' figures (wall z 7.00, nearest 0.04 m with 9 bad poses, 10 ticks alone in the crown,
2.5 m, 4.58 m, 0.00 m, -7.00 m, 1 drawn frame inside); with the fix all 8 pass.

## What changed (engine/kernel/api/tl_chase_cam.gd)

- **Start overlap (D5 root).** Before each cast `_start()` asks the space two things at the point looked at: which bodies
  HOLD that point (`intersect_point`), and whether the `avoid_margin` sphere there touches anything else
  (`intersect_shape`). Bodies holding the point are left out of the cast (`exclude`). If the sphere touches something,
  its radius is halved until it is clear (0.3, 0.15, 0.075, 0.0375 m); under 2 cm a ray is cast instead (it stops 2 cm short).
  So a cast never starts overlapping the body it would miss.
- **Swing down (R4, the in-head pull).** When no swing UP (0..80 degrees, as before) is clear for `avoid_min`, the camera
  now tries swings DOWN in 10 degree steps and last the horizon itself, never below it. Under a crown just over his head it
  stands under the crown, level with his head, at full distance instead of 0.04 m from it. Moving away from the wanted
  angle is immediate, as moving up was before. Moving back toward it eases by `avoid_out`.
- **Frame (D18).** `avoid_space`'s bodies are taken to be in the coordinates of the camera's PARENT (a Node3D; otherwise
  global). The point looked at and the wanted place are carried into that frame for the casts, and the result is carried
  back. The visitor camera is a child of the landscape and the world's space is in landscape coordinates, so a stage
  re-base no longer shifts the casts. A pack's chase camera is a child of `ctx.cameras` (a plain Node), so it stays global,
  as before. I added no new public member. Choosing the parent frame needs no new option: visitor.gd and its wiring are
  untouched.
- **Snap on entering a stage (D18 glide).** `view.gd` `_set_stage(i >= 0)` calls `vcam.snap()` after the re-base, so the
  anchor (global coordinates) does not glide across the re-base.
- **snap() (Q19).** It now sets `_heading` to the target's facing and `_last_pos` to its place.
- **Reversal (Q20).** When the wanted heading is exactly opposite (dot < -0.999), the heading is turned round the up axis
  by `stiffness` of 180 degrees. Every other turn keeps the old lerp exactly.
- **Cut (Q32).** After a tick's move, a ray from the last place to the new one (in the avoid frame). If it meets anything
  in `avoid_space`, `reset_physics_interpolation()` makes it a cut. This applies only with `avoid_space`.
- `setup()` accepts `avoid_min` (D17). The header and API.md lines say all of the above.

## The choices I made (an owner may want them otherwise)

1. **His head inside a crown (the look point itself inside a camera-only solid):** that crown is looked out of. The
   camera stands where the cast against everything else puts it, normally at full distance outside the crown. It is
   inside the crown only when something else (a trunk right behind him) keeps it closer than the crown's edge. In
   `cam.canopy_jump` the camera is in the crown on exactly the ticks the point looked at is in it (22 of 22). Alternatives
   are a crown-exit placement, or treating crowns as see-through when the head is in one. Those are feel decisions for
   the owner.
2. **A wall or trunk right behind him** (Q5's wall at 0.2 m, the P4 trunk at 0.28 m behind the head): no angle up or down
   is clear, so the camera comes in close to his head (0.05 m in front of the wall, or 0.44 m with the trunk behind). It is
   never in the wall. Swinging SIDEWAYS round him, or hiding the figure when the camera is that close, is the owner's call.
   The pre-fix code put it inside the wall (z 7.00) or, with the trunk, at the same 0.44 m. Deferred as feel.
3. Down-swings stop at the horizon (no camera below his head looking up). The owner may want lower.

## Re-run commands (from W = C:/Users/kazda/kiro/third-life/.claude/worktrees/bugfix-37)

```
G=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe; R=$PWD/docs/reports/bugfix-37
for s in hunt-Q/repro/a_camera_wall.gd hunt-Q/repro/a_avoid_min.gd hunt-Q/repro/a_snap_heading.gd hunt-Q/repro/a_reverse_camera.gd \
         hunt-R/repro/r1_cam_in_crown.gd hunt-R/repro/r1b_cam_crown_band.gd hunt-R/repro/r5_cam_rebase.gd; do
  timeout 200 "$G" --headless --path engine --script "$R/$s" 2>&1 | grep -E "REPRO|^R[0-9]"; done
timeout 200 "$G" --headless --fixed-fps 120 --path engine --script "$R/hunt-Q/repro/a_camera_cut_wall.gd" 2>&1 | grep REPRO
python docs/reports/bugfix-37/hunt-P/repro/run.py canopy     # still prints REPRODUCED: its test is camera_in_crown > 0 (see choice 1); read the figures
python docs/reports/bugfix-37/hunt-P/repro/run.py option     # now "D5 reproduced 0/1": fixed
bash engine/tools/selftest.sh cam.            # the 8 cases of 310-bugfix-cam.sh
bash engine/tools/selftest.sh walk.           # the walker's 14 cases (walk.camera, walk.canopy among them)
```

## Files

- changed: `engine/kernel/api/tl_chase_cam.gd`, `engine/kernel/API.md` (the chase-camera `avoid_space` and `snap()` lines only),
  `engine/kernel/world/draw/view.gd` (one line in `_set_stage`)
- added: `engine/tools/selftest.d/310-bugfix-cam.sh`, `engine/kernel/world/walks/bugfix_cam_case.gd` (+ `.gd.uid`),
  `engine/kernel/world/walks/bugfix_cam_cut.gd` (+ `.gd.uid`), this report

## Existing tests and moved figures

- `walk.camera`: unchanged (lowest camera height 0.35 m; -1.94 m without avoid_space), before and after.
- `walk.canopy`: PASS before and after. The counts are unchanged (mask 1: 221 / 73; mask 1|4: 0 / 0). **Moved:** the nearest
  camera to the point looked at went from **1.91 m to 2.83 m**. The down-swing finds room under a crown where the up-swing
  alone pulled in. This is better, not loosened, and walk_case.gd was not touched.
- `walk.` (all 14 cases): PASS.
- `tl arch`: api-index-fresh PASS, api-v1 PASS (kernel API 1.8, no new public member: the new constant is private
  `_RAY_R`). The failing steps are not this lane's: uid-orphans (the hunters' repro .gd under docs/reports), size-ratchet
  (boot.gd, walk_case.gd, ...) and reports-index-fresh.
- Packs: `tl check --tier full --only packs` PASS: `[2/2] found 2, completed 2; verb runs 33 of 33`, hockey bot hashes e.g.
  `bot_hockey a29dcdf02a16dd1c@4186` (full output in `docs/reports/bugfix-37/cam/packs-check.txt`). It ran before the
  private rename `RAY_R` -> `_RAY_R`, a name-only change. The default path (no avoid_space)
  changes only in `snap()` (heading re-read: in `ctx.cameras.frame()` and setup it equals the facing anyway) and on exact
  reversals with `use_velocity` (no pack uses it). API.md calls the cameras "visual only", outside the state hash.

## Questions for the Director

- None on contracts. No KERNEL_API bump: no new public member. The D18 rule "the space is in the parent's coordinates" is
  documented in the header and API.md. If you prefer an explicit option (`avoid_frame`), that would be a 1.9 addition.
- Owner feel decisions: choices 1-3 above (crown with the head in it, the wall right behind him, no below-horizon swing).
