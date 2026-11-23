H1 hand: REPORT, round 1 (areas 1 and 3, section 0 drafted). Round 2 (area 2, sections 4-6) waits for the Director.

Deliverable: docs/research/hockey-teardown/BEHAVIOUR-HAND.md (sections 0, 1, 3, 6-partial; 2, 4, 5 marked "Round 2").

Acceptance, round 1 part
- Every row has two measured numbers or says why not: met for areas 1 and 3. thirdjam's skating is a port of its StepSkater
  (labelled [T-law], a code integration), checked against the build's own automation TIMING lines run headless on .tl/tj-run
  (port reproduces 30/2.97/45, 24/1.89, 35/56, 6, 42/0.075, the four top speeds; one value off by a frame). Rows thirdjam did
  not stage say so (16 and 24 m/s loose pucks).
- Area 1 speed-over-time curves of both games on one plot, start / stop / turn: met, media/beh_move.jpg (101 KB).
- Area 3 carry-loss causes per minute and pick-up success against speed, both games: met, media/beh_puck.jpg (121 KB);
  thirdjam's per-cause split is partial (hits from its own counts; poke vs touch not separable in its 0.1 m trace).
- Window check: ours, 6 scenes re-run in a rendered window: 4 byte-identical, 2 within 0.002 m (puck bounce), same outcomes;
  media/beh_window.mp4 (23 s, 1.9 MB), media/beh_window_sheet.jpg. thirdjam not filmed (its real sim checked headless instead).
- Nothing under engine/, foreman/, contracts/, devx/ changed.

Gates: node devx/bin/tl.mjs check --tier fast: PASS arch [12/12], PASS assets [4/4], PASS cards [3/3],
  PASS devx.test [229/229] 229 pass 0 fail, PASS foreman.typecheck. (First run FAILed arch rule 3 uid-orphans on the probe .gd
  files; fixed by hand-written .gd.uid files beside them.)
thirdjam automation (its own tests, the build): 90 of 90 Success (Jam.Core.Movement/Possession/Contact/Tackling/... filter).

Changed files (all new): docs/research/hockey-teardown/BEHAVIOUR-HAND.md; media/beh_move.jpg, beh_puck.jpg, beh_window.mp4,
  beh_window_sheet.jpg; probes/hand_step.gd(+.uid), hand_match.gd(+.uid), hand_scenes.mjs, hand_measure.mjs, hand_tj_skate.mjs,
  hand_carry.mjs, hand_plot.py; docs/shifts/2026-11-23-day/lanes/H1-hand/STANDUP.md, REPORT.txt.
  The worktree also shows " D docs/shifts/2026-11-23-night/lanes/N1-teardown/BRIEF.md": not mine, it was deleted before I started.

Key findings (round 1)
1. In metres both bodies answer the keys almost alike (first step +0.41 vs +0.45 m/s a frame, 6-frame tap 2.5 vs 2.8 m,
   same 0.147 m/s2 glide). The difference is the body: 15.8 vs 5.2 body widths a second (12.65 vs 9.2 m/s on 0.8 vs 1.76 m).
2. Ours reaches 90 % of top in 19 frames / 0.8 body width (thirdjam 34 / 4.7): no build-up to feel.
3. Reverse stop: ours 19 frames, 1.39 m (0.8 bw); thirdjam 29-30 frames, 2.97 m (3.7 bw).
4. Carrier penalty: free skater gains 2.5 m/s (thirdjam) vs 1.1 m/s (ours) on a carrier.
5. Puck glued in ours: comes back to him by itself 24.8 vs 0.3 times a carry-minute; never came off in 7 carry drills.
6. R-0069 holds in ours: a still puck within 1.45 m is his on frame 1 at every angle (16/16), never at 1.6 m+.

Questions for the Director
- None blocking. The owner's evening play will be the witness the numbers lack.

Next three (round 2): area 2 frame timelines (press, active, contact, victim free, attacker free) in both games from the
build's JAMHIT/JAMPRESS/JAMLUNGE test lines and our hit drills; section 4 behaviour sheet with targets marked data / pack /
kernel; section 5 method note and the rest of section 6.
