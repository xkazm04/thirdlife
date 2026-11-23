H1 hand: REPORT, round 2 (area 2, sections 4-6, section 0 finished). Round 1 landed as merge 5d07c50.

Deliverable: docs/research/hockey-teardown/BEHAVIOUR-HAND.md, now complete (sections 0-6).

Acceptance
- Every row has two measured numbers or says why not: met. thirdjam's hit/poke rows come from its build's own contact tests
  (JAMSTAND "the rule", JAMBRACE, JAMHIT, POKEDRILL; 90 of 90 Success); where no test prints a frame (window, cooldowns, poke
  window) the row says "code" and names the constant. Speeds thirdjam did not stage are left blank, not computed.
- Area 1 curves both games on one plot: met in round 1 (media/beh_move.jpg).
- Area 2 frame timeline (press, active, contact, victim free, attacker free / press works again) for both games: met,
  media/beh_hits.jpg (71 KB) and section 2.1 (body check, cross-check incl. late and held, poke, being hit).
- Area 3 carry-loss causes per minute and pick-up vs speed: met in round 1.
- Section 4 numbers a builder can apply without asking: 19 shared rows (file:line, key, present value, target, thirdjam's
  number, kind), route A (5 rows), route B (8 rows), what each breaks, the choice.
- Window check area 2: 4 hit scenes re-run rendered, the same contact/freeze/down/free frames as headless;
  media/beh_hits_window.mp4 (20 s, 1.1 MB), beh_hits_window_sheet.jpg.
- Nothing under engine/, foreman/, contracts/, devx/ changed.

Gates: node devx/bin/tl.mjs check --tier fast: PASS arch [12/12], PASS assets [4/4], PASS cards [3/3],
  PASS devx.test [229/229] 229 pass 0 fail, PASS foreman.typecheck.

Changed files (round 2): docs/research/hockey-teardown/BEHAVIOUR-HAND.md; media/beh_hits.jpg, beh_hits_window.mp4,
  beh_hits_window_sheet.jpg (new); probes/hand_hits.mjs, hand_plot_hits.py (new); probes/hand_step.gd (taps/holds and a hit
  tail of columns, appended: round 1's measures read by header still work), probes/hand_scenes.mjs (the hit scenes);
  docs/shifts/2026-11-23-day/lanes/H1-hand/STANDUP.md, REPORT.txt.

Key findings (round 2)
1. The hit law is the same in both to three digits (front 9 m/s: ratio 1.17; behind 2.19; side braced bump 0.35).
2. A knockdown takes the hand longer in ours: keys back at frame 104 vs 70 (front 9 m/s): +24 kernel rise, +8 whole-game freeze.
3. The whole game freezes 5-9 frames on every hit >= 5 m/s within 24 m: 3.97 a minute in play; thirdjam: 3 frames, picture only.
4. Bodies are walls: unpressed contact at 9 m/s stops the attacker dead and does not move the man (thirdjam: 4.3 / 2.5 m/s).
5. Wind-ups 12/10 vs 8/8; press-again 42/46/41 vs none/30/14 frames; a cross pressed within 10 frames of the meeting only
   pushes (ratio 0.33-0.5) because the collision stops the attacker first.
6. The poke is a dice roll (14/20 front, 7/20 side measured) at frames 7-13 and sends the puck away; thirdjam's is certain at
   frames 1-8 and rolls the puck to the poker.

Questions for the Director
- Section 4.4 recommends S1-S19 now, then route B (life-size, 90 x 45). B needs an art and camera decision (B2, B7) and lane
  H2's view on data/ai.json distances (A5, B8). The owner said scale plays a minority role; the measurement says the body is
  where the two games differ in what a hand sees. That is his call.
- Section 5 is a proposal for METHOD.md (14 lines); not applied.

Next three: measure the cursor sweep / dangle against thirdjam's sweep and deke (3.3); film thirdjam's skater and a hit in its
window (its keys are camera-relative); after the build, re-run hand_step.gd + hand_hits.mjs on the new pack as the acceptance.
