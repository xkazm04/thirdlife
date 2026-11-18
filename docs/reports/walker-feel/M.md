# Lane M: movement and camera — FINAL REPORT (10:37, 18 Nov 2026; lane end 13:00)

## Acceptance
1. walk.* selftest cases: **met**. Run `tl.sh selftest walk.` → 7 of 7 pass. The cases are headless (kernel/world/walks/walk_case.gd).
   - Idle on 20/35/50 deg banks for 600 ticks, placed and after a walk: drift 0.0000 m.
   - Jump: 0.943 m high, 33 ticks in the air. Coyote: jumps at 4 ticks, not at 12. Buffer: yes.
   - 3 m ledge: falls for 30 ticks, the largest drop in one tick is 0.193 m (before: 0.9 m per tick).
   - 65 deg bank: slides down for 53 ticks and stops at its foot. Walking up into it is refused.
   - Camera over a 30 deg hill with the view pitched -10 deg: -1.94 m (under the ground) without avoid_space, +0.35 m with it.
   - In the world, over 71 marks: the camera is at least 0.32 m above the ground (margin 0.3 m).
2. Before/after captures from the same ticks: **met**, with one gap.
   - Captures: camera on the bank, walking down the bank, jump at tick 1162, run slide at 1215, bluff slope at 310/330/360.
   - Sheet: M-sheet.jpg (468 KB). Raw stills are in stills/before and stills/after.
   - Gap: the run slide shows the run pose, because lane L's `slide` clip does not exist yet. The slide is proven by figures: 5.31 m from 9 m/s against 0.97 m for a plain stop.
3. Smoothness: **met**.
   - physics_interpolation=true.
   - put, setup and snap reset interpolation. view.gd's stage re-base is in PATCHES 1.
   - Trace with no fixed fps:
     - Interpolation off: 1.00 distinct position per tick. While running, the figure stands still in 123 of 140 frames.
     - Interpolation on: 9.76 distinct positions per tick for both figure and camera. Still in 0 of 140 frames. Measured at 594 fps on a busy machine.
4. Changed tests and the full gate: **not met (Director-owned remainder)**.
   - P11's "W 180 frames = 13.50 m" is now 13.24 m on purpose (acceleration). It was a builder figure; export.sh check asks only > 5 m.
   - boot/visit_proof.devices.json route needs PATCHES 3. With that patch, visit-proof passes.
   - `tl check --tier full`: 933 of 933 units completed (last green was 924). kernel.selftest is 176 (169 + 7).
   - arch fails (api-v1, api-index-fresh, reports-index-fresh), and so do 4 devx.test cases that assert the real tree is green. All of these come from TLChaseCam's new members needing KERNEL_API 1.6 and regenerated docs/generated/*.
   - That is manifest.gd plus `tl arch --index`, which are Director files (PATCHES 5). Every other step passes.
# Lane M: movement and camera (status, newest on top)

## 09:35 read the briefs and the code
- Read common.md, laws.md, lane-M.md, world_space.gd, visitor.gd, visit.gd, tl_chase_cam.gd, view.gd 440-588, WORLD.md body,
  PATCHES-P3 item 1, P11-CONTROLS.
- Readings to prove: (a) the creep is test_motion's depenetration (the drop test's travel carries a sideways push on a
  slope, and walk() runs every tick even with no input); (b) the "1.45 m drops" are walk()'s snap of step_up 0.55 + 0.9.
- The P11 figure "W 180 frames = 13.50 m" is a builder measurement (export.sh check only asks > 5 m in 210 frames of
  Shift+W): with acceleration it becomes less than 13.50 m on purpose.
- Plan: the movement physics (velocity, gravity, jump, slopes, slide) goes into world_space.gd as `drive()` (RefCounted,
  so a headless case can drive it on built ground); visitor.gd turns the person's wish into drive() calls and the rig wire;
  visit.gd declares Space (jump) and C (slide) and hands the wish over instead of moving player_pos.

## 09:42 M1 body built, headless proof green (7 of 7)
- BEFORE (old walk(), headless, `walks/walk_before.gd`): idle 600 ticks on a plane bank 20/35/50 deg: horizontal drift 0,
  the feet RISE 2.3 / 7.8 / 19.6 cm (depenetration). Walking off a 3 m ledge at 4.5 m/s: y 2.84 -> 1.94 -> 1.04 -> 0.14
  (0.9 m per tick, the old snap of 0.55 + 0.9: the one-tick drops). Reading (a) is refuted on a clean plane: no sideways
  creep there; the creep must be found in the world (profile run pending).
- Built `world_space.gd drive()` (velocity body) + `walks/walk_case.gd` (headless selftest cases). Numbers: gravity 24
  m/s^2, jump 6.93 m/s (0.94 m, 33 ticks in air), coyote 6 ticks, buffer 8 ticks, accel 34 m/s^2 (rest->4.5 in 8 ticks,
  4.5->9 in 8), decel 42 (9->0 in 13 ticks, 0.89 m), tap = a step (wish kept 9 ticks: a 6-tick tap moves 0.62 m),
  snap down 0.35 m (more is a fall), slope slide gravity-along-slope, friction 3, max 14 m/s, steer 4 m/s^2; run slide
  from >= 6 m/s, decay 7 m/s^2, ends < 2.6 m/s or 70 ticks.
- walk_case: idle_bank drift 0.0000 m (20/35/50 deg, placed and after a walk); jump 0.943 m 33 ticks, coyote yes at 4
  ticks / no at 12, buffer yes; ledge 3 m: largest one-tick drop 0.193 m, 30 ticks falling; steep 65 deg: slides 53
  ticks, stops at its foot (z 0.65, y 0.001), walking up into it refused; pace above; slide 5.31 m vs 0.97 m stop;
  camera along a 30 deg hill pitched -10: -1.94 m under ground without avoid, 0.35 m above with it.
- Edge fix found by measurement: the capsule's round foot on a ledge corner reported a steep normal (he "slope-slid"
  off every edge and lost his speed): `_steep_under()` ray decides edge vs slope.
- Wired: visitor.gd `wish()` + `_drive_step()` (rig wire, clips only if `rig.clips()` has them), visit.gd Space=jump,
  C=slide, the wish replaces the player_pos push; TLChaseCam opt-in anchor_follow / avoid_space; project.godot
  physics_interpolation=true. BEFORE captures will run from an untouched copy of the engine (scratchpad/before).

## 09:58 M1, M2, M3 built; in-world before/after; visit-proof found and patched; full gate running
- The owner's creep REPRODUCED in the world (wf_bluff, the bluff's face at x 60, z -201): BEFORE, walking onto the face
  is "refused" and the old re-drop sinks him 0.06 m per tick: he crawls down the face at 3.5 m/s, and goes on crawling
  after W is let go (tick 440 y 4.28 -> tick 480 y 2.61, nothing pressed). AFTER: a slope slide that gains speed (0.36
  -> 0.87 m per 4 ticks), lands at the foot, stops (y 0.89, still from tick 428). On a walkable bank (kit pad, 21 deg,
  (-60, 23.7)) neither version moves in 600 idle ticks (0.00 m).
- Captures, same device script and ticks, BEFORE from an untouched engine copy (scratchpad/before), AFTER from the
  worktree: stills/before|after/*.png, sheet docs/reports/walker-feel/M-sheet.jpg (468 KB; rows: camera on the bank
  pitched -10 / walking down the bank / jump at tick 1162 / run slide at 1215 / bluff at 310, 330, 360). BEFORE the
  camera is under the bank (the pad's underside and kerb float across the sky); AFTER it stands over the ground.
- M3 detail found by looking: pulled straight in over the bluff's edge the camera ended inside his head; now it is first
  swung up (10 degree steps, <= 80 deg) to be clear for 2.5 m (`avoid_min`): it looks down at him over the edge.
- Interpolation proof (no --fixed-fps, frames outrun ticks; device `trace` prints the INTERPOLATED transforms per drawn
  frame): interpolation OFF (engine copy, the same code): 400 frames over 49 ticks (495 fps, busy machine), 1.00
  distinct figure / camera positions per tick, the figure stands still in 123 of 140 frames while running. ON: 400
  frames over 41 ticks (594 fps), 9.76 distinct positions per tick for both, still in 0 of 140, drawn speed p50 9.00 m/s.
- world.sh visit-proof FAILED with the new body (the route was tuned to the old stall on the paddle pad's bank; the
  replays still agreed). Also a real bug found there: a level step onto a steep edge was refused forever (stuck at
  (-67.4, 11.7)); fixed: refuse only a move INTO the slope (uphill), a move along/down it starts the slope slide.
  With the device file patched (M-PATCHES 3, file docs/reports/walker-feel/visit_proof.devices.patched.json) he enters
  at 1460 and Q leaves at 1700 to (0, -2.52, -21.0) as in P11.
- Split for the size ratchet: the body is terrain/world_body.gd (325 lines; world_space.gd 386, delegates drive/rest;
  a WeakRef back to the space, no cycle: the headless case's RID leak at exit is gone).
- Selftest block `walk.*` (7 cases) added to engine/tools/selftest.sh; `selftest.sh walk.`: 7 passed.
- Fast gate: arch FAILS on api-v1 (TLChaseCam additions want KERNEL_API 1.6: manifest.gd, not lane M's: PATCHES 5),
  api-index-fresh and reports-index-fresh (regenerated by `arch --index`, Director). size-ratchet fixed by the split.
