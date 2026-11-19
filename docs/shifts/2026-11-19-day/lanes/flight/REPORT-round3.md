Lane flight, round 3 (d19-flight3 from main 0f714bc), day of 19 Nov 2026, about 13:20-13:40 by the worktree clock.
All by me (Opus); no Codex round (0 Codex tokens). Nothing copied in from main or other trees. Nothing committed.

0. LEDGE AT 3.05 m (the parkour lane's Skyline): FIXED
   Cause (their trace confirmed): walker_grips `_fits` (standing room on the lip, the capsule 1 mm over the floor, margin
   1 mm, recovery as collision) read a contact 2.4e-7 m deep at those coordinates (float noise) and refused the catch.
   Fix: engine/kernel/world/terrain/walker_grips.gd `_fits` accepts contacts no deeper than FIT_TOL = 0.1 mm.
   Case moves.ledge_fit (block 536, kernel/runner/ledge_fit_case.gd): the Skyline slab (3.8 x 3.4 x 1.0, top y 10.13,
   x -22.79) at ledge heights 2.90 / 2.95 / 3.00 / 3.05 / 3.10 m: all five caught and mantled onto. On the unfixed code
   the same case caught 0 of 5 (in this geometry even 2.90 failed). moves.ledge_reach still refuses a top with no room.
1. CAMERA IGNORES MARKED BARS: DONE
   engine/kernel/api/tl_chase_cam.gd `_bar_rids()` (private): bodies in the group `tl_bar` in avoid_space are left out of
   the start test, the arm cast and the cut ray. engine/kernel/api/tl_biped.gd `mark_bar` now also adds the body to
   `tl_bar` (same signature; no new public member, no version bump). engine/kernel/world/terrain/crown_camera.gd adds
   the world space's copied bars (`bars`, set by visitor.gd from world_space `copied_bars`); `ignore_bars` exists only
   for the control in the case.
   Case moves.cam_bar (533, kernel/world/flight_cam_bar_case.gd), the village visitor: walking under a bar and a hard
   swing on it: lift 0.000000 deg, pull 0.000002 m, largest camera step 0.236 m. Control (old behaviour): lift 60 deg,
   pull 8.66 m, a 10.05 m jump of the camera in one tick.
   Pack path, in case 535: a TLChaseCam on a pack biped under a marked bar has the lift and pull of the same run with
   nothing to avoid (0 deg, 0.099 m: that 0.1 m is the arm's own easing after the catch, measured with avoid_mask 0);
   control (bar not in the group) lifts 60 deg and pulls 6.08 m. A pack keeps its player's body out of avoid_mask as before.
   Clip: clip-cam-bar.mp4 (5.5 s, the camera stays behind him through the swing) and sheet_cam_bar.jpg.
2. SOFT END OF A HARD SWING: DONE
   walker_grips: pumping adds no energy once the swing's energy would carry it past SOFT_AMP = 85 deg, and energy above
   that (a fast entry) is bled off by BRAKE = 6/s (ramped over the first quarter of the excess). The 100 deg LIMIT stays
   as a guard only.
   Case moves.swing_soft (534, kernel/world/swing_soft_case.gd): pumping 60 s from a dead hang peaks at 84.89 deg,
   0 ticks at the guard, largest change of angular speed 0.445 rad/s per tick; a run at 9 m/s into the bar (entry
   8.18 rad/s) peaks at 81.06 deg, 0 guard ticks, 0.850 rad/s per tick. On the unfixed code the same case: 100.00 deg,
   98 guard ticks, a 5.273 rad/s dead stop in one tick. The small-amplitude period is unchanged (moves.bar_swing
   1.344014 s vs 1.345150 s).
3. GRIP-POSE CASE FOR PACK BIPEDS: DONE
   Case moves.biped_grip (535, kernel/runner/biped_grip_case.gd): a TLBiped (moves ledge + bar) in an ordinary scene:
   hang clip, sink -0.400 m, hands within 0.304 m of the lip; mantle onto the top, the rig back to its transform at once;
   swing clip, hands within 0.273 m of the bar, facing drift 0.000 deg through the swing, upright 15 frames after the
   release; plus the camera check above. Not tested: body_scale other than 1 (the body's grip heights do not scale; say
   if packs need scaled bipeds on bars).

API.md (1.10 section): marked bars are left out of chase-camera avoidance; the soft end of the swing. No new public names.
moves_demo.gd: `--behind` (camera stays behind on the bar) for the clip; CRLF kept.

GATES (this tree)
  fast: PASS arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck (re-run after the last edit).
  selftest flight.: 12 passed, 0 failed. moves.: 14 passed, 0 failed (10 before + 533-536).
  full --only world,packs,kit.selftest: PASS world 8/8 (world = alone), PASS packs 2/2 (44/44 verb runs), PASS
  kit.selftest 95/95.

FILES (all mine; commit exactly these)
  engine/kernel/world/terrain/walker_grips.gd, engine/kernel/api/tl_chase_cam.gd, engine/kernel/api/tl_biped.gd,
  engine/kernel/world/terrain/crown_camera.gd, engine/kernel/world/visitor.gd, engine/kernel/API.md,
  engine/kernel/world/moves_demo.gd, engine/kernel/world/flight_cam_bar_case.gd(.uid), engine/kernel/world/swing_soft_case.gd(.uid),
  engine/kernel/runner/biped_grip_case.gd(.uid), engine/kernel/runner/ledge_fit_case.gd(.uid),
  engine/tools/selftest.d/533-flight-cam-bar.sh, 534-flight-swing-soft.sh, 535-flight-biped-grip.sh, 536-flight-ledge-fit.sh,
  docs/shifts/2026-11-19-day/lanes/flight/{STANDUP.md, REPORT-round3.txt, clip-cam-bar.mp4, sheet_cam_bar.jpg}.

NOTES
  - FIT_TOL 0.1 mm: a real obstruction of the standing room is millimetres or more; a ceiling touching the capsule top
    by less than 0.1 mm now counts as room.
  - The 100 deg guard can still be met by a fall onto a bar at a very high speed (the brake ramps over the excess);
    nothing in the village or the parkour pack produces that as far as measured.
NEXT: grip heights that scale with body_scale; A/D shuffle along a ledge; a soft camera ease after the bar catch (the
  0.1 m arm easing).
