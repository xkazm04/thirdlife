J11b report (biplane, one more change, 05:38-06:07, 27 Nov night)

- Tree fast-forwarded to main b1444245 (contains bd5d4b06: T2 + the 800-character change box); foreman rebuilt;
  class cache re-imported.
- Change 7, sent 05:39:15 (482 characters): take out the graze rule, keep my own smoke out of my view, her pull-up
  after my loop in every round. core r23, 4.0 min, 0.97M in; merged 05:46:41 first time, no balance note, no
  refusal, nothing extra. PROMOTED v0.1.4 at 06:02:40 (final verification all ok).
- Came out as asked: yes for all three, in its own note and in the files (no "graze" left in combat.gd or
  tuning.json; own_size 0.4 / own_life 0.35 / own_sink 5 / own_flame 0.5 for my plane only; _follow_loop() runs in
  every round). Seen in the clip: her pull-up after my loop in round 2. Not seen: the late-round smoke (the clip is
  early round 2; the long film lost the window lock and the disk was at 13 GB).
- The old test-pilot edit REMAINS: tests/support/pilot.gd in v0.1.4 is byte for byte v0.1.3's, which still has r15's
  five lines. Change 7 touched no test file.
- Figures (seed 1, bot_juice): 3600 frames twice, hash 66997af2 both, 0 script errors; 18000 frames, 0 errors, per
  minute: my loops 1.8, hers 0.8, REVERSED 0.2, her rolls 3.4, deflects 1.0 hers + 0.4 mine, shoot-downs 0.2 (one
  seed; one kill fewer than v0.1.3 in 5 minutes).
- Clip: clips/v014_editor_round2_loops.mp4 (20 s). Stills: stills/v014_editor_round2_sheet.jpg,
  stills/v014_editor_her_loop_pullup.jpg.
- Disk: deleted my duplicate mp4s and the lane backup under .tl/j11 (about 85 MB); no raw .avi left.

landable J11b: .tl/jobs/biplane-duel-two-biplanes-20261125-1/promoted/game.biplane_duel_two_biplanes@0.1.4
  (tree d25-biplane), menu title "Biplane duel (juice)", replacing v0.1.3.
