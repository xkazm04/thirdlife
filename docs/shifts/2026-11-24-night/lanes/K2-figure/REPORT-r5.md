K2 figure: report of round 5 (23 Nov 2026, 22:29 to 22:47)
Worktree C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-figure, on hokej be548e5, nothing committed.
(This round's notes are in this report; there is no ROUND-5.md.)

THE ROUND IN ONE PARAGRAPH
All four asks are done. A tracked run now holds a brace of 16 frames and a board fall, and a second short tracked run
holds a pin; both are compared with thirdjam's own figures. The two unexplained rows are explained: thirdjam's own
figure is not the same twice. Two Unreal runs given the same calls differ from each other on 11 rows by more than
1 cm (worst 5.01 cm), single frames of a stick, and that is more than ours differs from either run. The oracle's
world now has thirdjam's rink actor with an ice sheet of the rink's size, so the falls' wall rules run on real boards
in both figures, and they agree. I looked through all 29 sheets of round 4 and the film.

WHAT THE DIRECTOR ASKED, ITEM BY ITEM
1. A held brace and a pin in a tracked run: MET, in two runs.
   - verbs.stream.json, recorded again (seed 2, the hand now holds the cross-check 90 frames; state hash
     3ba801e4fee31b2b): SetCrossCheckHold 11 calls, the hold pose on for 16 frames once (1018 to 1034) and 15 at the
     end, bCrossBraced on 27 frames; also a board hit with a board fall (skater 7, frame 840), 6 knockdown calls,
     4 stumbles, 6 whiffs, 7 checks, 9 cross-checks, 7 hit-stops.
   - verbs_pin.stream.json (new: seed 5, the first 720 frames; state hash 5e7f0bb6d8a44737): the human pinned on
     the boards for 7 frames (654 to 661). Against thirdjam's figures: 7,200 of 7,200 rows within 1 cm, worst 0.96 cm.
   Not met in one run: no seed of five tried had a long brace, a pin and a board fall together.
2. The two unexplained rows: FOUND. thirdjam's Blueprint figure, given the same 1,800 frames of calls twice in two
   Unreal sessions: 47 rows differ by over 0.3 cm, 11 by over 1 cm, worst 5.01 cm, always the puck socket (the stick)
   for one to six frames, on other frames each time (frame 731 of skater 2 is off by 4.23 cm in run 1 and right in
   run 2). Ours against run 1: 17,997 of 18,000 rows within 1 cm, worst 4.23 cm; against run 2: 17,992, worst
   5.01 cm. Ours is the same on every run (the golden holds). Which of thirdjam's reads races I did not prove; the
   stick's learned offsets (SK2Tick) read the puck socket while Unreal evaluates the animation on a worker thread,
   and round 2 found the same kind of thing for bReady. The gate's tolerance (worst 6 cm, 97 % within 1 cm) stands for it.
3. The wall rules on real boards: MET. The oracle spawns thirdjam's ARinkActor and gives its "Ice" mesh a sheet of
   the rink's size (ARinkActor::Build wants a cartridge's game config, which Python cannot make; the Blueprint reads
   only that mesh's bounds). thirdjam's figure then reads RinkHX 4500, RinkHY 2250, RinkR 375 (read back from it):
   the numbers `set_rink` gives ours from the cartridge, which the gym now gives in every mode. The board fall at
   frame 840 and every knockdown beside a wall are in the comparison above. DEVIATION left: the corner radius comes
   from thirdjam's rule "half width / 6" in the oracle (no ice material there), which equals the cartridge's 3.75 m
   for this rink; with another rink the ice material's own radius would have to be given.
4. Looked through the 27 sheets and the film: DONE (all 29 sheets of round 4 at 2000 px a sheet row, the film as 30
   pairs a second apart, three new strips at full size: brace, board fall, pin). In none does a pair differ in pose.
   What I see:
   - The pictures are crowded: in about a third of the sheets another skater covers the followed one for two to six tiles (the
     gym's follow camera at 4.5 m; not the game's camera).
   - Bodies stand in each other at every contact (a checker in the man he felled, a poker in the carrier): the sim's
     circles, in both pictures, and in thirdjam's game.
   - thirdjam's figure throws ice dust while it slides after the board fall (frames 870 to 930); ours has none (the
     slide's particles are listed as not ported).
   - Sheets of verbs a few frames apart show the same frames under two names (the lift and the cross-check of frame
     427 are one moment): the sheet tool names by call.
   - Our gym's sky flickers brighter on some frames (a sun glare of the gym's own light); the oracle's ice is now a
     dark untextured sheet where the rink actor's mesh lies over the floor.
   - The brace reads: the stick across the chest for half a second, then the shove. The pin reads less: seven frames
     of a push with the stick, easy to miss at this camera.

THE NUMBERS
- Main run against thirdjam run 1 (the golden's): rows 18,000, within 1 cm 17,997, worst 4.23 cm; by skater 0.48,
  1.18, 4.23, 0.28, 0.10, 0.29, 0.08, 0.80, 0.10, 0.06. The golden holds skaters 0, 6, 7 (worst of them 0.80 cm).
- Pin run: rows 7,200, within 1 cm 7,200, worst 0.96 cm. Its golden holds the human (0.16 MB).
- Defects at parity (the human, main run, our mesh): blade under the ice 29 frames (4.96 cm), a skate 474 of 1,044
  skating frames (9.28 cm), a joint over 40 degrees a frame 192 (169.7), shaft near a leg 4 (3.95 cm), puck socket 3.

GATES
All run 22:39 to 22:46, after the last engine edit (only lane documents and media changed since).
- node devx/bin/tl.mjs check --tier fast: PASS, exit 0: arch [12/12], assets [4/4], cards [3/3], devx.test [229/229],
  foreman.typecheck clean.
- bash engine/tools/selftest.sh rig.skater (blocks 810, 811, 812): 10 passed, 0 failed:
    PASS rig.skater.body, .clips, .ref, .play, .driver (940 frames), .oracle (worst_cm 0.01), .red
    PASS rig.skater.verbs ("frames_done":1800 "skaters":10 "state_hash":"3ba801e4fee31b2b")
    PASS rig.skater.verbs.oracle ("rows_compared":5400 "worst_cm":0.8 "share_within":1.0)
    PASS rig.skater.verbs.pin ("rows_compared":720 "worst_cm":0.01 "SetBoardPin":2)
- bash engine/tools/selftest.sh rink.view: 2 passed, 0 failed (rink.view.show 5 of 5 cases, rink.view.hits 6 of 6).
- The full tier, style pins, the pack's checks: NOT RUN (not touched; the Director's rule).
- The ten-skater comparisons (18,000 and 7,200 rows) and the two-run comparison of thirdjam with itself were run by
  hand against files under .tl/; the gate holds 5,400 + 720 rows.

CHANGED FILES
engine/cores/rink/view/verbs.stream.json (recorded again), verbs_pin.stream.json (new, 0.19 MB), verb_gym.gd (the
hand's hold 90 frames, the rink in every mode and in calls.json, two counters), hit_read_case.gd (the expected hash);
engine/rigs/skater/review/oracle_verbs.json (made again), oracle_pin.json (new), skater_defects.gd (the verb tables);
engine/tools/skater/driver_oracle.py (the rink actor, TL_ORACLE_DEBUG_WHO); engine/tools/selftest.d/812-skater-verbs.sh
(+ rig.skater.verbs.pin); engine/rigs/RIGS.md (the skater's section: numbers, the pin run, thirdjam's own noise).
No figure code changed this round. No contract, rule table or pack file edited. No git command wrote.

BEHAVIOUR CHANGES: none in the figure, the pawn or the show. verbs.stream.json is again another match.

WHAT IS NOT KNOWN OR NOT DONE
- The owner has not seen any of it.
- The cause of thirdjam's run-to-run difference is measured, not located in its graph.
- The hold pose flips on for single frames four times in the main run (435, 465, 992, 1755) before the long hold:
  thirdjam's pawn rule as ported (the early hold), the same calls in both figures; whether the game's own pawn does
  that I cannot say, the pawn is still checked by reading only.
- The trip has no caller. Dive, slide, wipe, bonk, equipment, slide particles, contact shadow: not ported (round 6).
- One Unreal session at a time was kept; no crash this round.

FOR K3: nothing changes. FOR K1: nothing new.

QUESTIONS FOR THE DIRECTOR
1. Round 6 as said (abilities and weapons, dash, dive, slide tackle, celebrations, boost glow)? The regular cartridge
   never calls them, so the gym needs a cartridge that does: which one (thirdjam's sandbox cut, or K1's word)?
2. The slide's ice dust and the contact shadow are effects, not poses: this lane's, or the look's (K7)?

WHAT THE DIRECTOR SHOULD LOOK AT (all under docs/shifts/2026-11-24-night/lanes/K2-figure/media/)
- r5_brace_f1014_f1038.jpg            the held cross-check, every third frame, thirdjam above, ours below
- r5_board_fall_s7_f0837_f0993.jpg    a bot checked into the boards: the fall against the wall, the sit, the get-up (real rink)
- r5_pin_f0648_f0672.jpg              the human pinned on the boards
- r5_s7_knockdown_f0840_three.jpg, r5_pin_board_pin_f0654_three.jpg     the same as whole sheets
- r5_looked_r4_sheets_0.jpg .. _4.jpg, r5_looked_r4_film_grid.jpg       what I looked through (round 4's 29 sheets, the film)

THE NEXT THREE THINGS: the last family against the same oracle; the slide's effects if they are this lane's; a
hand that a person recorded, when the owner has played.
