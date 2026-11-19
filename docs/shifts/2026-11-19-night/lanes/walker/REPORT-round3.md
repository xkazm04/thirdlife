Lane walker, round 3 (n19-walker3 from 16534db), 04:30-04:58 by the worktree clock. Nothing committed. Site code untouched.

1. Bluff terrain crawl back below the pre-crest level, crest lines kept. Built by Astra r6 (session 01a1f1db-6958-7902-8db2-bef4ed3b65b3, 174,813 tokens).
   Bluff terrain-only flips: 2.217 % (r3c) -> 1.987 % (target <= 2.010 %, the level before the crest rule).
   Mean grey change: 1.823 -> 1.821. Near-crest flips: 9.54 -> 8.62 %.
   Kept:
     crest coverage: bluff 80/82, shoulder 299/299, bank 60/64
     HEAD's strong contours: same 8-bit opacity on all 36,076 px
     flat grazing false ink: 0/279,300
     STYLE.md thin pan: 2.625 %
     0 extra texture reads
   How: the wide brush's own depth taps keep its soft edge where it crosses a ridge, and the crest stroke is capped at
   55 %. Variant table with commands: r6/MEASUREMENTS.md.
   Check style.walker.ink (block 430): 2 new brush-flank cases. I re-ran it: the r3c shader fails ("close terrain crest
   expected opacity in [0.5, 0.55] got 0.624"), the new shader passes.
   r6/ holds 779 MB of measuring clips; do not commit them.
2. Slide-entry foot dip. Built by D.
   The dip came from the slide pose itself, not the crossfade (with blend 0 it was still -0.128 m).
   Fix (engine/rigs/biped/tl_rig_biped_moves.gd): the hips drop late (k^3) while the legs fold, and the entry hips go
   -0.16 -> -0.10 m.
   Entry lowest point: -0.148 m (RightFoot, frame 6) -> -0.018 m (frame 4). Held pose unchanged (+0.006 m).
   Check: rig.walker.slide_entry (block 410, second line of walker_slide_floor.gd). Red on HEAD (-0.148), green now.
3. Camera's sideways swing near crowns, behind a setting. Built by D.
   TL_CROWN_SWING=behind (crown_camera.gd): yaw 0 only. Absent or `sideways`: unchanged.
   New read-only counters side_ticks and max_side. visitor.gd prints a `visitor_cam` line when the visitor leaves.
   Headless crown sweep (2,880 poses, 34,560 frames):
     default: 648 sideways ticks, at most 90 deg; 0 head-out frames in or near leaves
     behind: 0 sideways ticks; head-out camera inside leaves 116 frames, within 0.5 m 624 frames (the price of staying behind)
   Check: walker.crown_swing_behind (block 490). It errors on the HEAD camera, which has no counter, and passes now.
   The default walker.crown case now also prints side=648 max_side=90.
   Clips: swing/swing_sideways.mp4 and swing/swing_behind.mp4 (wf_canopy: a run up the bank among the trees, then a
   slow full turn under them). Both runs printed side_ticks 0, so the two clips look alike. The sideways swing does not
   occur on that route; it shows only in the sweep's close-to-trunk poses. A clip that shows the difference needs a
   pose pressed against a trunk; I did not find one in the village in the time.
   Not documented in WORLD.md (outside this round's claim): the doc is in crown_camera.gd's header.

GATES (final tree)
  --only world,packs: PASS world 8/8 (world = alone), PASS packs 2/2, 34/34 verb runs. No hockey budget miss.
  fast tier: PASS arch 12/12, assets 4/4, cards 3/3, devx.test 226/226, foreman.typecheck.
  Touched blocks: rig.walker 2/2, walker.crown 2/2 (incl. crown_swing_behind), walk. 24/24, style.walker.ink 1/1.
  Kernel selftest grows by 2 cases (slide_entry, crown_swing_behind); the ink block stays one verdict.
