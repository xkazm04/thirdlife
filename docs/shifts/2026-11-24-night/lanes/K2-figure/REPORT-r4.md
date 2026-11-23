K2 figure: report of round 4 (23 Nov 2026, 21:44 to 22:20)
Worktree C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-figure, on hokej 2bede87, nothing committed.

THE ROUND IN ONE PARAGRAPH
The contact is ported, both sides, and proven against thirdjam's own figures: on a 1,800-frame match segment of the
real core (ten figures, thirdjam's bus, hit-stops, its puck actor) 17,998 of 18,000 rows stand within 1 cm, worst
1.61 cm; the two rows over are single frames I could not explain. The hit read's whiffs and re-time are ported
(thirdjam's tests, 6 of 6). The puck is drawn in the gym and in the oracle, and with it the look at the puck is now
compared. The head socket was checked against thirdjam's mesh in Unreal: its place was right, its own turn was
missing and is added. A native pose blend would save about 0.9 ms of the ten figures' 2.2 ms (measured, not built).
NOT covered by the tracked run: a brace held for more than a frame, a board pin, the wall rules with a real rink.

WHAT THE DIRECTOR ASKED, ITEM BY ITEM
1. Contact, family by family against the same oracle: MET, in one landing (the draft held on its first complete run).
   Attacker: PlayCheck (ChkScan, three sizes), SetWindupTakes / PlayCheckWindup / the wind takes, the bus's check
   cut, PlayCrossCheck (wind), SetCrossCheckHold with the hold layer, the release, PlayWhiff (check and cross),
   PlayCheckMiss. Victim: PlayHitReaction, PlayStumble, SetKnockedDown with the falls by direction and size, board
   fall, lie loops, get-ups (early, quick, snap, wall), PlayBoardHit, SetBoardPin, the whip, the mesh's turn / slide.
   On the tracked run (all ten figures): PlayCheck 4, PlayCheckWindup 4, PlayCrossCheck 7, SetCrossCheckHold 4,
   PlayWhiff 3, PlayHitReaction 16, PlayStumble 3, SetKnockedDown 8 (4 falls), PlayBoardHit 1 (with a board fall),
   bus deliveries check 70, knockdown 40, lift 70, deke 20, 7 hit-stops, 3 re-times. On round 3's stream, compared by hand before
   (18,000 of 18,000 rows, worst 0.48 cm): 6 checks, 5 cross-checks, 31 hit reactions, 7 knockdowns, 10 pin calls.
   WEAK SPOTS: the hold pose was wanted for one frame at a time (two times); no pin in the tracked run; the trip has
   no caller; which fall kinds and sizes occurred was not counted beyond the human's (Knockdown_Left).
2. The hit read in the show: MET as engine/cores/rink/view/hit_read.gd beside skater_show.gd (which is at 594 of 600
   lines). The model, the whiff calls, the re-time. It needed no fact the snapshot lacks; `last_human_input` is taken
   and not read (thirdjam's model reads states and events only). Not compared with Unreal as a unit; its calls
   reached both figures. Its bars, lean and pop (HUD, camera) are not ported.
3. The puck drawn in the gym and the oracle: MET. Ours: the kit's puck where FJamPuckShow draws it, on the socket
   after the frame's pose (AJamPuck::Tick). The oracle: thirdjam's AJamPuck at the same point. Drawn on a blade on
   755 of 1,800 frames. Seen in media/r4_crop_knockdown_f1128_f1200.jpg (the loose puck beside the fallen man).
4. human_pass_target: waits for K1; PlayCallForPass still never fires.
5. The head socket: CHECKED, small fix. thirdjam's mesh socket head_socket: on the bone "head_socket", offset 0,
   quaternion (0.707107, 0, 0, 0.707107) against the bone (a roll of -90 degrees); puck_socket: on stick_socket at
   (19.42, -141.45, 4.8) cm, no turn (both read from the mesh in Unreal in the oracle run). Ours had the place right
   (head_socket and head within 0.02 cm of thirdjam's on every compared frame) and no turn: `socket_transform(
   &"head_socket")` now carries it. thirdjam's marker rule (HUDWidget.cpp:1114-1121) uses the socket's place and the
   head bone's place only, so the chevron's place does not change with this; what lane K3 saw has another cause
   (in thirdjam the socket is 49 cm above the head bone, the marker comes back 18 cm along that line).
6. A native pose blend, measured: ten figures, the verb segment, median of five instrumented runs 2,316 us a frame
   (uninstrumented 2,155; 1,912 to 2,727 on a machine at 83 % load):
     anim.evaluate 1,322 (blend / blend2 369, sample_clip 339, layered 216, aim weigh 173, modify_bone 83, glue 136)
     anim.update 436 | the pawns' calls 243 | figure._show 167 (globals 120, skeleton writes 37) | show 72 | rest 62
   A native library for sample_clip, blend, layered, modify_bone and globals (1,133 us today) would save 0.78 / 0.94 /
   1.0 ms (low / likely / high) and leave 1.2 to 1.4 ms; the whole evaluate as one native call a figure about 1.4 ms.
   The native costs are estimates from stand-ins (one GDExtension call 0.16 to 0.3 us), nothing was built.
   Cheaper first: layered() at full weight (it is, on 8.79 of 8.85 calls) about 0.1 ms; sample_clip on packed
   arrays about 0.08 ms; the aim's weigh stopping at the first triangle about 0.07 ms (not measured).

THE NUMBERS
- Tracked run (verbs.stream.json, seed 2, pro, state hash ee65d6ad51f4b067, score 1:0): rows 18,000, within 1 cm
  17,998, worst 1.61 cm (frame 1074 skater 1 puck_socket; the other: frame 1359 skater 8, 1.26 cm). Worst by skater:
  0.48, 1.61, 0.74, 0.07, 0.03, 0.54, 0.54, 0.03, 1.26, 0.06. The golden holds skaters 0, 6 and 7 (1.15 MB).
- The skating gym's golden, made again: 940 of 940 frames, worst 0.01 cm.
- Defects at parity (the human, tracked run, counted on our mesh): blade under the ice 40 frames (4.07 cm), a skate
  382 of 938 skating frames (10.62 cm), a joint over 40 degrees a frame 180 frames (174.7: an upper arm as a
  knockdown starts), the shaft within 4.5 cm of a leg's axis 10 frames (0.63 cm), puck socket 1, lengths 0.
- Cost on the tracked run: about 2.0 ms a frame for ten figures with pawns, bus, show and hit read (1.96 measured).

GATES
- node devx/bin/tl.mjs check --tier fast (22:18, after the last engine edit): PASS, exit 0: arch [12/12], assets
  [4/4], cards [3/3], devx.test [229/229], foreman.typecheck clean.
- bash engine/tools/selftest.sh rig.skater (22:10 to 22:16; blocks 810, 811, 812): 9 passed, 0 failed:
    PASS rig.skater.body, .clips, .ref, .play                                                              (810)
    PASS rig.skater.driver ("frames_done":940, parity), .oracle ("worst_cm":0.01 "share_within":1.0),
         .red (sunk 3 cm: blade: 561 frames break the band)                                                (811)
    PASS rig.skater.verbs ("frames_done":1800 "skaters":10 "state_hash":"ee65d6ad51f4b067")               (812)
    PASS rig.skater.verbs.oracle ("rows_compared":5400 "worst_cm":0.54 "share_within":1.0)                (812)
- bash engine/tools/selftest.sh rink.view (22:18): 2 passed, 0 failed: rink.view.show (cases=5 of 5),
  rink.view.hits (cases=6 of 6). FIRST RUN FAILED: rink.view.hits still expected round 3's stream's state hash;
  the case's expected hash was set to the new stream's (the one line changed after the rig.skater run; no rig file).
- The full tier, the style pins, the pack's lint / smoke / bots: NOT RUN (not touched; the Director's rule).
- The whole comparison (ten skaters, 18,000 rows) was run by hand against the oracle's file under .tl/; the gate holds
  5,400 of those rows (skaters 0, 6, 7), whose worst is 0.54 cm: the two rows over 1 cm are not among them.

CHANGED FILES
New: engine/rigs/skater/tl_rig_skater_whip.gd, tl_rig_skater_falls.gd, tl_rig_skater_contact.gd (the contact);
     engine/cores/rink/view/hit_read.gd, hit_read_case.gd.
Changed: engine/rigs/skater/tl_rig_skater.gd (the contact's entries, set_rink, the tick order), tl_rig_skater_anim.gd
     (the hold layer, the whip), tl_rig_skater_slot.gd (loops, rate, length, stop), tl_rig_skater_body.gd (below K7's
     lines: the mesh's world yaw and shift, the actor's place, the head socket's turn), tl_rig_skater_puck.gd (one
     call's arguments), review/skater_defects.gd (tables), review/oracle_gym.json, review/oracle_verbs.json (made again);
     engine/cores/rink/view/verb_gym.gd (every bus event, the hit read, the puck, the hold in the hand),
     verbs.stream.json (a new recording: seed 2), skater_pawn.gd (+ set_figure_dilation, the header);
     engine/tools/skater/driver_oracle.py (puck actor, sockets read, the world's clock), verb_sheets.py (contact verbs);
     engine/tools/selftest.d/812-skater-verbs.sh (+ rink.view.hits); engine/rigs/RIGS.md (the skater's section).
No contract, no rule table, no pack file and no file outside the lane's folders was edited. No git command wrote.

BEHAVIOUR CHANGES
- TLRigSkater now SHOWS every contact call (they only counted before): a pack that draws through the pawn gets
  falls, checks and reactions without a change. `NOT_PORTED_CALLS` is empty.
- TLRigSkaterAnim.play_slot: a sixth argument `loops` came before `trigger`.
- socket_transform(&"head_socket") is turned against the bone (its origin is unchanged).
- The figure looks at the puck only when it is told where it is (`set_puck`): lane K3's match should call it each
  frame with the puck show's point (verb_gym.gd shows how); the human's figure is told not to look by the show.
- verbs.stream.json is another match than round 3's (seed 2).

DEVIATIONS (from thirdjam; earlier ones stand): in ROUND-4.md (set_rink from the cartridge; the trip, dive, slide,
wipe, bonk branches; the dead miss timer; the re-time on the figure only; bUpRun as thirdjam's own).

WHAT IS NOT KNOWN OR NOT DONE
- The owner has not seen any of it. I looked at two crops (16 pairs); 27 sheets and the film I did not look through.
- Two rows over 1 cm (1.6 and 1.3 cm, one frame each, the puck socket of a bot): cause not found.
- The wall rules of the falls: the oracle's world has no rink (thirdjam's RinkActor::Build wants a cartridge's game
  config, which Python cannot make), so both figures ran them on zeros. With the cartridge's rink (our game mode)
  they are not compared.
- A held brace (more than a frame), a pin, the trip: not in the tracked run (pins: compared by hand on round 3's stream).
- The hit read and the show object: thirdjam's ported tests and running, not Unreal.
- A dilation above 1 (the re-time) is one large tick in ours; three occurred and the rows agree.
- The fork's cost figures are from its own timed copies of evaluate; the poses of those copies were not checked.
- Machine: two GPU crashes of my Unreal at start (reruns clean); one oracle run was killed by me (my own process).

FOR K1: nothing new needed. Still: human_pass_target; the per-skater carrier reach.
FOR K3: in a match call, per sim frame after the show's after_pawns: `hits.step_sim(snap, pawns, core.last_human_input())`
  (hits = preload("res://cores/rink/view/hit_read.gd").new(); hits.skater_speed = game.skater.speed); deliver ALL
  four bus events (knockdown, check, lift, deke) to every figure; `fig.set_rink(Vector3(length_m * 50, width_m * 50,
  corner_radius_m * 100))` once; `fig.set_puck(...)` each frame before `fig.tick()`. verb_gym.gd is the working example.
FOR K7: tl_rig_skater_body.gd changed only below line 135 and in socket_transform.

QUESTIONS FOR THE DIRECTOR
1. The last family (abilities and weapons, dash, dive, slide tackle, celebrations, the boost glow): next, or first a
   run with a held brace and a pin and the two unexplained rows?
2. The three cheap cuts (about 0.25 ms of 2.2) change bits of the pose at 1e-7: take them now with the goldens made
   again, or leave the figure as measured until a native blend is decided?

WHAT THE DIRECTOR SHOULD LOOK AT (all under docs/shifts/2026-11-24-night/lanes/K2-figure/media/)
- r4_run_three.mp4                     the whole segment, the human followed: thirdjam left, ours right (30 s)
- r4_crop_knockdown_f1128_f1200.jpg    the human checked down, lying, getting up; the puck on the ice (every ninth frame)
- r4_crop_check_f0138_f0156.jpg        the human's body check with its wind-up
- r4_knockdown_f1135_three.jpg, r4_check_f0140_three.jpg       the same, whole sheets
- r4_crosscheck_f0427_three.jpg, r4_crosscheck_hold_f0435_three.jpg, r4_whiff_cross_f0763_three.jpg   the cross-check
- r4_hit_reaction_f0101_three.jpg      a hit taken standing
- r4_shot_slap_f0552_three.jpg         a charged shot, now with the puck

THE NEXT THREE THINGS: in ROUND-4.md ("Next").
