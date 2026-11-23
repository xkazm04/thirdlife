K2 figure: report of round 3 (23 Nov 2026, 20:43 to 21:35)
Worktree C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-figure, on hokej 75844e9, nothing committed.

THE ROUND IN ONE PARAGRAPH
Items 1 and 2 of the round are done and proven; item 3 (contact) is NOT landed. The puck verbs of thirdjam's figure
driver are ported from the Blueprint listing (shots with the wind-up, passes with the held layer, receive, call for
pass, poke, stick lift with the lifter's turn, stick hits, the deke), the game mode's part around the pawns is ported
(hit-stop picks, the shown carrier and where the puck is drawn, the play calls by name), and both run in a new gym:
a 1,800-frame match segment of the real core, five a side with bots, the human from a recorded raw hand, every skater
a pawn and a figure. The same calls were given to ten of thirdjam's own figures in Unreal: 18,000 of 18,000 rows
within 1 cm, worst 0.48 cm. The oracle caught one misreading of mine (which poke stumbles), a missing piece (the
hit-stop's time dilation) and one bit of Unreal's arithmetic (the tick's delta). The contact is a translated draft
outside the engine, never run. Nobody but me has looked at the pictures.

WHAT THE DIRECTOR ASKED FOR ROUND 3, ITEM BY ITEM
1. HitStopFramesFor, HitStopPick and FJamPuckShow in the pawn: MET, beside the pawn rather than in it.
   engine/cores/rink/view/skater_show.gd (594 lines; by a fork of this lane, checked by me through the gym): the
   picks and the routing (JamPawns.cpp:144-232, HokejGameMode.cpp:1753-1775), FJamPuckShow whole (PuckRead.cpp:85-333:
   the shown carrier, the puck on puck_socket with the blend at a change of hands, the goal drop) and its calls by
   name. thirdjam's own tests are ported with their expected values (Jam.Core.Contact.HitStop 17 rows,
   Jam.Core.Contact.HitStopPick 6 cases, Jam.Puck.Show's pure rows): 5 of 5 cases pass, one of them 600 frames of
   the real core ending on K1's proof hash. On the verb run: 5 hit-stops, the puck drawn on a blade on 912 frames.
   NOT compared with Unreal as a unit (there is no oracle of the game mode); its calls reached both figures.
   NOT MET inside it: PlayCallForPass never fires (it needs UJamSim::HumanPassTarget: see "For K1").
2. The puck verbs: MET for carry, tap shot, charged shot (slap), one-timer, tap pass, held pass, receive, poke
   (clean and missed), lift, the carrier's stick-hit reactions, deke, spin. Each occurs in the run as the simulation
   produced it, and each matches thirdjam's own figure. Of them the spin and the one-timer have no take in thirdjam
   (the pawn turns the figure; a one-timer is a PlayShoot), and the sweep (45 in the run) has no call at all.
   Counts on the run (the human / all ten figures): PlayShoot 4 / 5 (3 charged in all), PlayPass 3 / 16 (the human's
   three held; one saucer), PlayReceive 2 / 8, PlayPoke 2 / 4, PlayLift 2 / 5, PlayStickHit 2 / 3, deke 1, spin 2,
   one-timer 1 (a bot). Which of the lift's three sizes played was not counted.
3. Contact: NOT MET. A fork translated the listing's contact entries into GDScript (.tl/scratch/contact/: three
   files, 1,084 lines, and NOTES.txt). It was parsed against stubs only, never run, never compared, and it is not in
   the engine. The contact calls stay stubs that count (`not_ported`): on the run PlayHitReaction 31, SetKnockedDown 7,
   PlayCheck 6, PlayCheckWindup 6, PlayCrossCheck 5, SetBoardPin 5, PlayStumble 1.
4. Driven from the real core with a scripted raw hand and bots, recorded once, replayed: MET.
   engine/cores/rink/view/verb_gym.tscn, verbs.stream.json (1,800 frames, seed 5, pro; recorded by the gym's own hand
   with --record; state hash 25c0b3ac41ee29f5 on every replay).
5. Defect tests over that run at parity: MET (the human's figure; table in ROUND-3.md; counted on our mesh).
6. Looked at in sheets: four of the 18 verb sheets and two crops at full size (slap, held pass, lift, missed poke).
   No pair differs in pose. The other 14 sheets and the film I did not look through. What my eye rejects: ROUND-3.md.

THE NUMBERS
- Ours against thirdjam's own figures, the verb run: frames 1,800, skaters 10, rows 18,000, within 1 cm 18,000,
  worst 0.48 cm (frame 1778, skater 0, puck_socket). Worst cm by skater: 0.48, 0.01, 0.07, 0.09, 0.07, 0.03, 0.07,
  0.15, 0.10, 0.01. The tracked golden holds skaters 0 (the human) and 9 (0.8 MB).
- Round 2's golden after this round's changes: 940 of 940 frames within 1 cm, worst 0.02 cm (unchanged).
- On the way (each an oracle run of 1,800 frames x 10): 84.9 % of rows within 1 cm, worst 344 cm (no hit-stop in the
  oracle, the stumble on the wrong poke); 95.3 %, worst 334 cm (the stumble; unseen figures' sticks); 100 %.
- Left out of BOTH figures' calls because ours cannot answer them yet: the contact calls above and the bus's check
  (50 deliveries) and knockdown (40). So in both pictures a skater the sim knocked down skates on.
- Cost on the verb run: about 2.5 ms a frame for ten figures with their pawns, the bus and the puck show (GDScript,
  headless, a loaded machine; 2.2 to 3.1 ms across runs). Not a budget test.

GATES
All run at 21:30 to 21:33, after the last engine edit (only lane documents and media changed since).
- node devx/bin/tl.mjs check --tier fast: PASS, exit 0: arch [12/12], assets [4/4], cards [3/3], devx.test [229/229],
  foreman.typecheck clean.
- bash engine/tools/selftest.sh rig.skater (blocks 810, 811, 812): 9 passed, 0 failed:
    PASS rig.skater.body, .clips, .ref (27 poses, worst 0.00001 m), .play                         (810)
    PASS rig.skater.driver ("frames_done":940, parity), .oracle ("worst_cm":0.02 "share_within":1.0),
         .red (sunk 3 cm: blade: 597 frames break the band)                                        (811)
    PASS rig.skater.verbs ("frames_done":1800 "skaters":10 "state_hash":"25c0b3ac41ee29f5")       (812)
    PASS rig.skater.verbs.oracle ("rows_compared":3600 "worst_cm":0.48 "share_within":1.0)        (812)
- bash engine/tools/selftest.sh rink.view.show: 1 passed, 0 failed (cases=5 of 5 failed=0)        (812)
- The full tier: NOT RUN (the Director's rule for this round). engine/style and the hokej pack: not touched, not run.
- The whole comparison (ten skaters, 18,000 rows) was run by hand against the oracle's own file under .tl/; the gate
  holds 3,600 of those rows (skaters 0 and 9).
- Block 812 has no red case of its own: its defect measures are block 811's, shown red there.

CHANGED FILES
New:
engine/rigs/skater/tl_rig_skater_puck.gd       TLRigSkaterPuck: the puck verbs (the figure's `takes`)
engine/rigs/skater/tl_rig_skater_slot.gd       TLRigSkaterSlot: the slot's takes and the blend arithmetic (moved out of the
                                               animation file for the size rule; + take ids, custom blend-out trigger, stop all)
engine/rigs/skater/review/oracle_verbs.json    thirdjam's own figures on the verb run (skaters 0 and 9, 0.8 MB)
engine/cores/rink/view/verb_gym.gd, .tscn      the verb gym
engine/cores/rink/view/verbs.stream.json       the recorded raw hand (1,800 frames, 0.47 MB)
engine/cores/rink/view/skater_show.gd          the game mode's part: hit-stop picks, puck show, play calls
engine/cores/rink/view/skater_show_case.gd     its cases (thirdjam's tests ported, 600 frames of the core)
engine/tools/skater/verb_sheets.py             a sheet a verb, and the film
engine/tools/skater/oracle_golden.py           cuts a tracked golden out of an oracle run
engine/tools/selftest.d/812-skater-verbs.sh    rig.skater.verbs / rig.skater.verbs.oracle / rink.view.show
Changed:
engine/rigs/skater/tl_rig_skater.gd            the verbs' entries, OnBusEvent, set_rivals, the lift's turn, the dilation, TICK_S
engine/rigs/skater/tl_rig_skater_anim.gd       the pass layer (LayeredBoneBlend_2), the shot charge (TwoWayBlend_1); extends the slot
engine/rigs/skater/tl_rig_skater_body.gd       the mesh component's own yaw (the lift's turn)
engine/rigs/skater/review/skater_defects.gd    the verb run's parity tables; the gate's wording ("the parity count", as asked)
engine/cores/rink/view/skater_pawn.gd          + show_calls, call_figure, is_hit_stopped, is_told_has_puck, puck_socket_world;
                                               the dilation is recorded among the calls
engine/cores/rink/view/figure_gym.gd           the gate line's wording
engine/tools/skater/driver_oracle.py           every skater of a match, the bus, the dilation, a camera that sees them all
engine/rigs/RIGS.md                            the skater's section
Removed: engine/cores/rink/view/_probe.gd (+ .uid): a scratch probe of mine that round 2 landed by mistake.
NOT MINE TO FIX, FOR THE DIRECTOR: engine/tools/selftest.d/811-skater-driver.sh is still UNTRACKED in this tree
after round 2's landing (git status shows it `??`): rig.skater.driver / .oracle / .red are not in hokej.
No contract, no rule table and no file outside the lane's folders was edited. No git command wrote.

BEHAVIOUR CHANGES
- TLRigSkater.tick(): under a time dilation the figure now ticks on at that share of a tick (it stood still before);
  the tick's delta is the float below 1/60. Round 2's golden holds with both.
- TLRigSkater.SetShotCharge above 0 now shows the wind-up (it only counted before).
- TLRigSkaterAnim.play_slot returns the take's id (it returned a bool); round 2's callers ignored the value.
- skater_pawn.gd: once a show object runs, SetHasPuck follows the SHOWN carrier (the sim's Carrier, kept and
  settled), as in thirdjam, not the state's bHasPuck. Without a show object the pawn behaves as in round 2.

DEVIATIONS (from thirdjam; rounds 1 and 2's stand)
19. The tick's delta is the float below 1/60, as Unreal's fixed-rate session has it (measured, see ROUND-3.md).
20. The event bus reaches the figure through OnBusEvent(Event, bMe, ...); lift and deke only.
21. set_rivals gives the figure the other figures (ChkScan).
22. SetTakeGrace / SetStickLock are not ported: nothing in thirdjam's source calls them.
23. PlayCallForPass is never sent on the real core (no pass target in the snapshot).
24. The show object: carrier reach from the cartridge, the puck's late tick folded into render, the goal drop on
    frames, no log lines (its header lists them).
25. `set_time_dilation` is recorded among the pawn's calls (for the oracle); thirdjam's interface has no such call.
Round 2's deviation 2 stands and now has a face: thirdjam's figure drops its stick correction when nobody renders
it; ours keeps it. In the oracle every figure is rendered every tick, as on the game's screen.

WHAT IS NOT KNOWN OR NOT DONE
- The owner has not seen any of it. I looked at 4 of 18 sheets and 2 crops.
- Contact (item 3): not landed, see above. The draft's own list of likely misreadings is in its NOTES.txt.
- The game mode's hit read is not ported: the whiff calls (PlayWhiff / PlayCheckWhiff on a miss) and the re-time
  of a check (the figure's time dilation set ABOVE 1 for a frame) of AJamHitRead (HitRead.cpp:754-841), which read
  a model of presses and hits of about 570 lines.
- The show object is checked by thirdjam's own ported tests and by running, not against Unreal.
- The pawn is still checked by reading only (both figures are fed by it).
- The stop take and the look at the puck stay uncompared (accepted by the Director in round 2).
- The lift's size (light / plain / heavy by closing speed) reads the other figures: all ten were in the oracle, so
  it is compared, but which sizes occurred was not counted.
- No puck is drawn in the gym's stills or in the oracle's: "the puck on the blade" is the show object's number and
  the socket's height band, not a picture.
- The verb run's hand is the gym's own scripted hand, not a person's.
- The tick-delta finding (19) explains two takes and breaks nothing measured; why Unreal's delta is that float I did
  not find in its source.
- Machine: one oracle run died at start with "GPU crashed or D3D device removed" while other lanes rendered; the
  rerun was clean. I started my Unreal once while another lane's UnrealEditor-Cmd commandlet was still up (I had
  waited for lane K7's editor to end first). I killed one Unreal process, my own (found by its command line).

FOR K1 (rink core)
1. `human_pass_target(human, stick_dir, hold_frames) -> mate index` (UJamSim::HumanPassTarget, JamSim.cpp:3213) on
   RinkCore, or the target in the snapshot's Controls: PlayCallForPass needs it (skater_show.gd `pass_target_of`).
2. The carrier's reach (UJamSim::CarrierReachM, JamSim.cpp:862) per skater would replace the show's own sum from the
   cartridge.
3. Who owns AJamHitRead's model of presses and hits (HitRead.h, HitRead.cpp:70-640)? Its outputs are figure calls
   (whiffs, re-time), its inputs are the human's presses, which the core's glue already reads.
4. set_bot_mode("parked") was not needed this round (the verbs want the bots).

FOR K3 (shell): how to put the figures in the pack
  const SHOW := preload("res://cores/rink/view/skater_show.gd")
  show = SHOW.new(); show.cfg = SHOW.config_of(cartridge_dictionary)       # once; pawns: one skater_pawn.gd a skater
  each sim frame, after core.step() and snap = core.snapshot():
    for ev in snap.Events (Name in knockdown, check, lift, deke): every figure.OnBusEvent(Name, ev.Who == i, ev.Where * 100, ev.Strength, ev.Kind)
    show.step_sim(snap, pawns)                    # BEFORE the pawns: hit-stop, shown carrier, play calls
    pawn.apply_sim_frame(skater, snap.Frame)      # every pawn
    show.after_pawns(snap, pawns)
  each drawn frame: pawn.apply_render(skater, alpha); figure.tick() (once a sim frame); d = show.render(snap, pawns, alpha)
    draw the puck at d["puck"]; the camera's alpha is show.camera_alpha(frame, alpha)
  once: every figure.set_rivals(all_figures); the human's figure.set_human(true).
engine/cores/rink/view/verb_gym.gd does exactly this and is the working example.

FOR K7 (look): this round changed tl_rig_skater.gd outside the material set-up (SetTeam / SetNumber untouched) and
tl_rig_skater_body.gd only below the materials (the mesh's yaw). The fetched textures under .tl/skater-export are kept.

QUESTIONS FOR THE DIRECTOR
1. Contact next from the draft, family by family against the same oracle? That is a full round by this round's measure.
2. The hit read's model (whiffs, re-time): this lane's, or K1's glue with the figure calls handed to the show object?
3. Should the gym and the oracle draw the puck, so that the sheets show it on the blade?

WHAT THE DIRECTOR SHOULD LOOK AT (all under docs/shifts/2026-11-24-night/lanes/K2-figure/media/)
- r3_run_three.mp4                      the whole segment, the human followed: thirdjam's own figure left, ours right (30 s)
- r3_crop_slap_f1482_f1497.jpg          the charged shot at full size: wind-up, the stick overhead, the release
- r3_crop_poke_miss_f0372_f0387.jpg     the missed poke next to a carrier, at full size
- r3_shot_slap_f1495_three.jpg, r3_shot_tap_f1227_three.jpg     the two shots, every third frame, thirdjam above, ours below
- r3_pass_held_f1023_three.jpg, r3_receive_f0308_three.jpg      the held pass (the charge layer, then the snap), a receive
- r3_poke_clean_f1453_three.jpg, r3_poke_miss_f0371_three.jpg   the two pokes
- r3_lift_f1182_three.jpg, r3_stickhit_lifted_f0363_three.jpg   the stick lift, and being lifted
- r3_deke_left_f1004_three.jpg, r3_spin_f1193_three.jpg         the deke, the spin
To run it: godot --path engine --position 0,1440 --resolution 1280x720 res://cores/rink/view/verb_gym.tscn --
--out=<dir> --stills=three:3 [--who=<skater>]      (headless without --stills: the numbers only)

THE NEXT THREE THINGS THIS LANE WOULD DO
1. Contact from the draft: falls, lie loops and get-ups first (they need looping takes, the mesh's world yaw, the
   rink's walls), then hit reactions and stumbles, then checks and the cross-check, each against the oracle.
2. The hit read's whiffs and re-time, when its owner is named.
3. A puck in both pictures.
