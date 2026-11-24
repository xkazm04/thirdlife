K2 figure: report of round 6 (24 Nov 2026, 20:51 to 21:42; resumed after a usage limit stopped the lane at 23:00 on 23 Nov)
Worktree C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-figure, on hokej f9d2db9, nothing committed.
(This round's notes are in this report; there is no ROUND-6.md.)

THE ROUND IN ONE PARAGRAPH
The three failing gates are explained and green again: K1's round 4 changed how the core reads the devices, so my
recorded hands replayed into other matches; the streams are recorded again on the current core, the goldens made
again through thirdjam's own figures in Unreal, and a stream now names its match so that this failure says its own
name next time. The thrown victim is settled: ours does not miss the throw; the throw is thirdjam's HEAVY fall, played
only for a knockdown of 130 frames or more, and on such a hit the two figures agree to 0.007 cm. The last family
turned out differently than ordered: thirdjam's GAME sends only the goal's celebration, the boost glow and the held
ability's equipment; the dash, the dives, the slide tackle and the weapons are takes its Blueprint has and its game
never calls. The celebration, the equipment state, and (called by us on both figures) the dives, the slide tackle and
the dash are ported and agree with thirdjam's figure. The weapons are not ported. The slide's and the stop's ice spray
are drawn at thirdjam's moments, with our own particles, not thirdjam's.

0. THE FAILING GATES (the Director's first item): CONFIRMED, REPAIRED
- Two-way check: the same stream through the core's binary before 0c9300b (taken from git) and the current one:
    verbs.stream.json      before: 3ba801e4fee31b2b (the golden's match)   now: af496e74ecbfdcba   first differing frame 456
    verbs_pin.stream.json  before: 5e7f0bb6d8a44737                        now: 8cd3f87e795d7cf8   first differing frame 343
  At frame 343 of the pin stream the human's stick input reads -0.2714 before and -0.2713 now: the single-precision
  rounding of the raw values, as the Director said. From there the matches part.
- Repaired: the hands were recorded again on the current core (the gym's own hand, as before), every golden made again
  by the same procedure (thirdjam's own ten figures in Unreal given the same calls), the defect tables measured again.
- So that it cannot pass silently again: a stream file now names the state hash of its match, and the gym fails by
  that name ("the recorded hand replays into another match on this core ...") before any pose is compared; the hit
  read's case reads the stream's own hash instead of a number written in the case.
- One stream now holds what round 5 needed two for: seed 5 has a 22-frame brace, the human pinned for 7 frames, a
  board fall and four knockdowns. verbs_pin.stream.json and oracle_pin.json are removed.

1. THE THROWN VICTIM: SETTLED, NOTHING TO FIX IN THE FIGURE
- thirdjam's fall takes: only the four *_Heavy ones throw him (pelvis up from 73.8 to 88.4 cm at 0.18 s, 45 cm of
  travel; the plain and light ones start at 73.8 and only go down). [KnockDown] picks Heavy when the knockdown lasts
  130 frames or more (FallSize 2), which the sim gives the hardest hits (60 to 150 frames by the hit's ratio).
- The matched pair: verbs_throw.stream.json (seed 7, 420 frames): at frame 142 the human checks a carrier at full
  closing speed (the check event's strength 1.0), the victim (skater 7) is down for 150 frames. thirdjam's figure
  plays Fall_Heavy (read from it); ours the same: over frames 145 to 300 the victim's twelve points agree within
  0.007 cm, the pelvis tops at 88.372 cm in both. Tracked as rig.skater.verbs.throw (420 rows, worst 0.04 cm).
- What lane K3 saw is two different hits (its note says so): a heavy one in thirdjam, a lighter one in ours. In
  rounds 4 and 5 heavy falls were compared in numbers and never looked at; now it is a picture.

2. THE LAST FAMILY: WHAT THE GAME SENDS IS PORTED; THE REST IS THIRDJAM'S UNUSED TAKES
- The cartridge: thirdjam's modes/hockey.mode.arsenal.cartridge.json (the only one with all four abilities: shotgun,
  hip_check, shield, slow_puck, and pickups). The gym runs it with --cartridge or from the stream's own "cartridge".
- THE FINDING: in thirdjam's source at HEAD only three calls of this family reach a figure:
    PlayCelebrate(index)          JamBoostLook::CelebrateGoal, JamPickupActor.cpp:654-679, from DeliverEvents on a goal
    SetBoostEquipped(kind, on)    AJamBoostAura::Sync, JamPickupActor.cpp:564-594, on a change of the held ability
    SetBoost(kind)                the interface's, HokejGameMode.cpp:1696-1703: an effect boost: the jersey's glow
  PlayDash, SetBoostLevel, PlayDiveBlock, PlayDiveBlockFront, PlayDiveBlockHit, PlaySlideTackle, PlaySlideTackleHit,
  SetWeapon, PlayWeapon, PlayWeaponHit and PlayBoostPickup are called in the Blueprint only by SK26Do, its test
  dispatcher, which only SK26Test calls, and no file of thirdjam's source or config names SK26Test or any of them.
  thirdjam's game never plays a dash, a dive, a slide tackle or a weapon on its figure. A 1:1 port of the game has none.
- PORTED AND COMPARED (verbs_toys.stream.json: arsenal, seed 5, 1,330 frames; thirdjam's ten figures):
    the celebration   a goal at frame 783: the scorer's stick raise, his mate's take           the game's own calls
    the equipment     the human holds the shield from frame 261: the prop's state (which of the four, hidden while
                      down) is thirdjam's on 1,330 of 1,330 frames (read from its Blueprint); NO MESH: the four props
                      are not exported, ours shows nothing where thirdjam shows a green disc on the back
    dives, slide tackle, dash   called by US on the human's figure on top of the match (the stream's "toys": nine
                      moments), the same calls to thirdjam's figure: dive block left and right with the puck's hit,
                      slide tackle left and right, the front dive, a tackled man's legs going, a dash broken by a
                      bump and ended into the stride, a dash ended in a skid. thirdjam's figure played Dive_Block_Left,
                      _Right, _Front, Slide_Tackle_Left, _Right, Fall_Legs_Front and the dash's steps 1-2-4-2-3-0 and
                      1-2-5-0 (read from it); ours the same.
  Numbers: 13,292 of 13,300 rows within 1 cm, worst 3.99 cm; the human (who does all of it) worst 0.47 cm. The 8 rows
  over are single frames of other skaters' sticks, thirdjam's own run-to-run noise (round 5).
- The dash runs on Unreal timers; their rules are ported (TimerManager.cpp, cited in tl_rig_skater_dash.gd). It was
  right on its first oracle run, as were the dives.
- NOT PORTED: the weapons (SetWeapon, PlayWeapon, PlayWeaponHit, the carry poses, the keg, the cannon's kick),
  PlayBoostPickup (it needs a carry pose), the dash's skid held on the brake (ported, not in the run), SetBoostLevel
  (ported, not in the run), the effect boost's glow as a picture (the state is kept; which boost covers a skater is
  not in the snapshot: needs K1), the aura's waist ring.

3. THE EFFECTS OFF THE FIGURE'S MOVES: THE MOMENTS ARE THIRDJAM'S, THE PARTICLES ARE OURS
- thirdjam's Blueprint has two Niagara components: SlideFx (on from a knockdown until he is released) and BrakeFx
  (restarted by a stop take, strength = the speed he stopped from / 14). Both moments are ported into the takes.
- Drawn by a new TLRigSkaterFx with the style's own "ice_spray" preset: the slide's while he moves faster than
  1 m/s, the stop's as one burst. DEVIATION, plainly: the two Niagara systems are not exported, so size, colour, count
  and the slide's own emission rule are mine. In the throw's picture thirdjam's dust is a low bluish cloud under the
  body; ours is a few white flakes that hardly show on our pale ice. It is a first version, not a match.

THE NUMBERS (all on the current core)
- verbs.stream.json (seed 5, pro, 1,800 frames, state hash abef5af2b5a27716): rows 18,000, within 1 cm 17,993, worst
  2.60 cm (7 single frames of puck sockets); the golden's skaters 0, 5, 7: worst 0.81 cm.
- verbs_throw (seed 7, 420 frames, 46124e7830ced2a7): rows 4,200, within 1 cm 4,200.
- verbs_toys (arsenal, seed 5, 1,330 frames, e6ac63943fab6577): above.
- Defects at parity (the human, main run, our mesh): blade 9 frames (3.87 cm), a skate 489 of 1,183 skating frames
  (10.47 cm), a joint over 40 degrees 114 frames (175.7), shaft near a leg 5 (3.43 cm), puck socket 1.

GATES
- bash engine/tools/selftest.sh rig.skater (21:30 to 21:36, blocks 810, 811, 812, after the last engine code edit):
  11 passed, 0 failed:
    PASS rig.skater.body, .clips, .ref, .play                                                              (810)
    PASS rig.skater.driver (940 frames, parity), .oracle (worst_cm 0.01, share 1.0), .red (561 frames break) (811)
    PASS rig.skater.verbs ("frames_done":1800 "skaters":10 "state_hash":"abef5af2b5a27716")               (812)
    PASS rig.skater.verbs.oracle ("rows_compared":5400 "worst_cm":0.81 "share_within":1.0)                (812)
    PASS rig.skater.verbs.throw ("rows_compared":420 "worst_cm":0.04)                                     (812)
    PASS rig.skater.verbs.toys ("rows_compared":3990 "worst_cm":2.01 "PlayCelebrate":2 "SetBoostEquipped":1) (812)
- bash engine/tools/selftest.sh rink.view: 2 passed, 0 failed (rink.view.show 5 of 5 cases, rink.view.hits 6 of 6).
- node devx/bin/tl.mjs check --tier fast (21:39, after RIGS.md, the last tracked edit): PASS, exit 0: arch [12/12],
  assets [4/4], cards [3/3], devx.test [229/229], foreman.typecheck clean.
- The new guard shown red: the throw stream with a wrong state hash: FAIL "the recorded hand replays into another
  match on this core (state hash 46124e7830ced2a7, the stream's own 0000000000000000) ...".
- The full tier, the style pins, the pack's checks: NOT RUN (not touched; the Director's rule).
- The ten-skater comparisons (18,000, 4,200 and 13,300 rows) were run by hand against the oracle's files under .tl/;
  the gate holds 5,400 + 420 + 3,990 rows. Blocks 810 and 811 did not need new goldens (their hand is scripted
  FJamInput, not raw devices, and replays to the same match).

CHANGED FILES
New: engine/rigs/skater/tl_rig_skater_toys.gd (celebration, boost, equipment, dives, slide tackle), tl_rig_skater_dash.gd
     (the dash, Unreal's timers), tl_rig_skater_fx.gd (the ice spray); engine/cores/rink/view/boost_look.gd (the
     celebration's and the equipment's callers), verbs_throw.stream.json, verbs_toys.stream.json;
     engine/rigs/skater/review/oracle_throw.json, oracle_toys.json.
Changed: engine/rigs/skater/tl_rig_skater.gd (entries, the timers' step, the fx), tl_rig_skater_whip.gd (three states),
     tl_rig_skater_falls.gd (DiveAdopt, SlidePick, WipePick, BonkPick, SlideFx), tl_rig_skater_slot.gd (a take by id:
     pause, resume, position), review/skater_defects.gd (tables), review/oracle_verbs.json;
     engine/cores/rink/view/verb_gym.gd (--cartridge, the boost look, the stream's state hash and "toys", F in the
     hand), verbs.stream.json (recorded again), hit_read_case.gd (the stream's hash);
     engine/tools/skater/driver_oracle.py (SetBoostEquipped), engine/tools/selftest.d/812-skater-verbs.sh
     (+ .throw, + .toys, - .pin); engine/rigs/RIGS.md.
Removed: engine/cores/rink/view/verbs_pin.stream.json, engine/rigs/skater/review/oracle_pin.json.
No contract, rule table or pack file edited. No git command wrote (git show was used to read the old binary).

BEHAVIOUR CHANGES
- TLRigSkater has new entries: SetBoostEquipped, PlayCelebrate, PlayDiveBlock, PlayDiveBlockFront, PlayDiveBlockHit,
  PlaySlideTackle, PlaySlideTackleHit, PlayDash, EndDash, SetBoostLevel; SetBoost(Kind) now keeps the glow's state.
- A figure in a windowed run makes two particle nodes of its own when it first slides or stops hard.
- verbs.stream.json is another match again; a stream without "state_hash" is not checked for its match.

WHAT IS NOT KNOWN OR NOT DONE
- The owner has not seen any of it. I looked at all eight strips of this round; no pair differs in pose.
  In the skid's strip the skid shows for two tiles only: the sim's own cross-check takes over at frame 1296.
- The weapons and PlayBoostPickup: not ported. The equipment's meshes, the glow, thirdjam's own particles: not exported.
- boost_look.gd (who celebrates, who is told which equipment) is checked by running and by its calls reaching both
  figures; thirdjam's own test of it (JamPickupActor.cpp:683-720) is not ported. The scoring team is read from the
  score's rise (the snapshot has no bNetsSwapped).
- The dash's timers: a call between two ticks counts as thirdjam's game would (the timer waits for the frame's timer
  tick); the oracle makes its calls after the world's tick, a tick earlier, and `set_no_game_mode` takes that rule
  there. So the GAME's rule for a dash's first timer is my reading of TimerManager.cpp, one tick later than what was
  compared. No game calls a dash, so nothing can show which is wanted.
- The toy calls are mine: the sim does not know of them (the human "dives" while the sim skates him on).
- Lane K3's match does not yet call boost_look (goals have no celebration there until it does).

FOR K1: (1) which effect boost covers a skater (UJamEffectSystem::GetBoostKindFor) is not in the snapshot: the
  glow's caller needs it; (2) bNetsSwapped (the celebration's scoring team) would replace my reading from the score;
  (3) a change to how raw input is read changes every recorded hand: the streams now fail by name when it happens.
FOR K3: for the goal's celebration and the equipment, per sim frame:
  boost = preload("res://cores/rink/view/boost_look.gd").new(); boost.abilities = BOOST.abilities_of(cartridge)   (once)
  boost.deliver_events(snap, pawns)   with the bus events, before show.step_sim;   boost.sync(snap, pawns)   after hits.step_sim.
FOR K7: `fig.takes.jersey_emissive` (3.0 boosted, 2.0 not) and `fig.takes.equip_shown()` (prop -> bone) are the
  states the look would draw; the contact shadow under a thrown body is visible in thirdjam's strip.

QUESTIONS FOR THE DIRECTOR
1. The weapons: port them too (poses and carry stances can be compared the same way; their meshes need an export),
   or leave them until the sandbox step names what it wants?
2. The dash, the dives and the slide tackle have no caller in thirdjam's game. Who decides when ours calls them:
   the sandbox step's own rules, on top of thirdjam's sim?
3. The ice spray: export thirdjam's two Niagara systems' parameters and match them, or is the first version enough
   until the owner has seen it?

WHAT THE DIRECTOR SHOULD LOOK AT (all under docs/shifts/2026-11-24-night/lanes/K2-figure/media/)
- r6_throw_side_s7_f0142_f0190.jpg     the heavy check from the side: the victim thrown, thirdjam above, ours below
- r6_throw_dust_s7_f0149_f0170.jpg     the same, larger: thirdjam's dust under the body, ours a few flakes
- r6_celebrate_f0780_f0840.jpg         the scorer's stick raise after a goal
- r6_dive_block_f0297_f0420.jpg        a dive block, the puck's hit, the get-up
- r6_slide_tackle_f0618_f0726.jpg      a slide tackle; thirdjam's shield prop on the back at the end, none on ours
- r6_dash_bump_f0147_f0279.jpg         a dash, a bump, the end into the stride
- r6_dive_front_f1008_f1137.jpg, r6_dash_skid_f1263_f1317.jpg     the front dive; a dash into a skid (short: a cross-check follows)

THE NEXT THREE THINGS: the weapons if wanted; thirdjam's Niagara parameters for the spray; the props' meshes.
