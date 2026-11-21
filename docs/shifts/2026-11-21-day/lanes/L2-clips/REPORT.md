L2 fight-clips: REPORT (shift 2026-11-21-day; worktree .claude/worktrees/n21d-clips, branch n21d-clips, base df58f0b)
==========================================================================================================

Outcome: LANDABLE. Eight fight clips and stick_yaw on the biped, a timing table in RIGS.md, a move lab, block 660.
No existing pose, hash or kernel API member moved. Nothing committed (the Director lands).

ACCEPTANCE
----------
1. No existing hash moves: MET.
   - Pose level (strongest evidence): fight_golden.txt holds the pose hashes of all 20 existing biped clips, walk and
     skate, under classic / crisp (cel) / diorama (clay), written on the BASE tree (two base runs identical). On this
     tree all 120 runs match, and match again with stick_yaw = 0 set every tick (rig.fight.golden PASS runs=120).
   - Gate, full tier on this tree vs the same steps on the base tree (same worktree, both runs on a busy machine):
       kit.selftest  103/103  (base 95/95; +8 = the eight new clips, each "120 frames, finite, deterministic")
       world         8/8, the 8 world = alone hashes IDENTICAL to base (seed.drive a2940a1735bc2b72@3441, seed.wall
                     636b30026a88c5ae@1220, seed.paddle dff1a390470352e7@4486, example.walker f1c7b53757c34040@371,
                     example.kit ca698e71d34d1021@332, example.car 3a459d0fe25e7853@1872,
                     game.ice_hockey_three_against 3b372f91ecfe4c79@6751, game.parkour ...: same detail string)
       seeds         39/39 (base 39/39)
       packs         FAIL 1/2 units, verb runs 60 of 61, on base AND here, the same single failure: hockey
                     invariants.many_budget, a wall-clock frame budget (p50 1.140 ms here, 1.388 ms on base, budget 1.0).
                     Busy machine (perf probe: use 65 %): not evidence either way. Everything else in packs passed.
   - Other steps of the full tier on this tree: ui.selftest 195/195, foreman.test 250/250 (244 pass, 6 skipped),
     devx.test 229/229, arch 12/12, assets 4/4, cards 3/3, typecheck clean.
     NOT a pass (busy machine, stopped runs): kernel.selftest completed 81 of 82 units, 0 failed, then the gate's
     1800 s cap killed it; item.selftest 59 of 60 units, 0 failed, then the 600 s cap; perf NOT RUN (machine BUSY,
     use 65 %). An uncapped kernel run was crawling (82 cases in 45 min under the other lanes' load); I stopped it (my
     own process) and ran every kernel case that builds or poses the biped instead, by filter:
       rig. 18/18, character. 2/2, moves. 14/14, walker. 8/8, flight.pose 1/1, blend.shoulder 1/1 = 44/44 PASS, 0 FAIL
     (rig.feet_plant, rig.moves, rig.bugfix.* 7, rig.walker.slide_*, the four rig.fight.*, character.clay/cel, moves.*,
     walker.*). The Director's merge-time full tier on a quiet machine is still owed for kernel / item / perf.
   - Block 660: 4/4 PASS (rig.fight.clips, rig.fight.golden, rig.fight.yaw, rig.fight.cross).
   - Fast gate: PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck clean).
2. Move-lab sheet and clip + hockey stick sheet in the lane folder: MET. lanes/L2-clips/lab/:
   - r1_*, r2_*, r3_*, r4_* : stills sheets per tuning round (4 rounds), crisp look. fight_game = third-person arena
     camera 11 m away (figure about 140 px tall at 720p: game scale); fight_close / fight_side = the same frames close up
     for judging the pose; hockey_hockey = the hockey pack's own broadcast camera (100.7 m up, fov 20; tiles upscaled
     x3 nearest, figure about 40 px at 720p); hockey_chase = the hockey chase camera.
   - clip_fight.mp4 (15 s): all eight clips replayed side by side at game scale; clip_hockey.mp4 (15 s): a skater with a
     stick doing cross_check and body_check against an opponent, and stick_yaw sweeping.
3. RIGS.md has the timing table: MET ("Fight clips": frames, anticipation, active, recovery, control returns, ends,
   upper, what it is; plus the stick_yaw section). Block 660 holds the table, TLRigBipedFight.TIMING and the registered
   clip lengths together.
4. Kernel API untouched: MET. No engine/kernel file changed; no public member added (api-v1 and api-index-fresh pass).
   stick_yaw is a runtime param (`rig.set_param(&"stick_yaw", radians)`, like lean and look_at), not a new property:
   a public `var stick_yaw` on TLRigBiped would have been a kernel API addition (API-V1.json lists TLRigBiped).

THE CLIPS (frames at 60 Hz; table in engine/rigs/RIGS.md "Fight clips")
  clip          frames  anticip  active  control  ends     upper
  strike          16     0-3      3-6     12      returns  yes   light swing, fastest at f4-5, step-in at the hit
  strike_heavy    30     0-10     10-14   26      returns  no    overhead chop: coil peaks f8, held to f10
  block            5     0-0      0-4      4      holds    yes   shield forearm up across the face, braced, low
  roll            24     0-4      4-20    20      returns  no    full forward turn, upside down at f12, low f3-21
  dodge           14     0-2      2-9     11      returns  no    side step + hard lean; side = velocity_local.x at start
  body_check      30     0-7      7-15    24      returns  no    shoulder drive, contact about f12; skate: hockey stance
  cross_check     14     0-6      6-11    11      holds    yes   shaft level across the chest, punched forward, held
  taunt           90     0-0      0-78    60      returns  no    chest out, fist on hip (akimbo), beckons twice
- Every fight clip takes at most a 2-3 frame blend-in (taunt 0.15 s) so the wind-up always shows.
- cross_check with a stick: the right hand turns the shaft level across the chest and the stick slides 0.47 m up through
  the hand so its middle lies between the hands (measured: shaft.y 0.00, hands 0.42-0.46 m apart at 1.26 m, 0.68 m
  ahead, shaft middle 0.04-0.05 m off the hands' middle). Round 2 showed the bar sticking out to one side from the
  broadcast camera; round 3 (centred) reads as a bar across the front into the opponent.
- stick_yaw: radians, + = left, clamped -1.2..+2.0, turns Chest 0.45 / UpperChest 0.55 about the vertical (neck back
  0.55). Blade height change 0.00 m. Blade bearing turns +0.86/-0.87 rad (classic), +0.88/-0.96 (cel, clay) per +-1 rad.
  The blade RESTS out to the right: bearing -0.46 rad classic, -0.98 rad cel/clay, 1.38 m out; hence the longer left
  reach. A pack aims the blade at bearing b with a = b - rest (rest read from socket(&"stick_blade") at yaw 0).
  Cost at 0: one float compare per tick (post_pose returns before touching a bone).

TUNING ROUNDS (judged by eye; sheets kept)
  r1: first pass. Strike read weakly (arm lost in the turn), heavy coil hid the hands behind the head, block looked
      like the guard, body_check did not lead with the shoulder, taunt's akimbo arm was buried in the body.
  r2: bigger strike wind with the off hand kept on guard, longer heavy coil, block = shield arm out + lower stance,
      harder dodge lean, deeper body-check lunge. Hockey sheets added: cross-check bar stuck out to one side.
  r3: cross-check shaft centred between the hands; stick_yaw range widened to +2.0 after seeing the blade rest 56 deg
      right on the cel figure; opponent removed from the yaw row (it hid the blade at +1.2).
  r4: akimbo taunt (forearm swung in to the hip), strike step-in and lean at the hit.

CHANGED FILES (all in engine/rigs/** plus my selftest block)
  new  engine/rigs/biped/tl_rig_biped_fight.gd (+ .uid)  the clips, TIMING, stick_yaw, cross-check grip (372 lines)
  new  engine/rigs/review/move_lab.gd, move_lab.tscn (+ .uid)  the move lab (sheet | clip modes; header has commands)
  new  engine/rigs/review/fight_case.gd (+ .uid), fight_golden.txt  block 660's script and the base-tree golden poses
  new  engine/tools/selftest.d/660-fight-clips.sh
  mod  engine/rigs/tl_rig_biped.gd  (597 lines, unchanged count: +4 hook lines; removed the one-use `_sm` helper, its
       call is now the identical smoothstep)
  mod  engine/rigs/biped/clay_rig.gd  (left hand onto the shaft also during body_check / cross_check)
  mod  engine/rigs/tl_rigs.gd  (doc strings: clips list, runtime stick_yaw)
  mod  engine/rigs/RIGS.md  (Fight clips table, stick_yaw; generated section refreshed by `k.sh docs`)
  lane docs/shifts/2026-11-21-day/lanes/L2-clips/{STANDUP.md, REPORT.txt, lab/*}
  NOT touched: engine/kits/KIT.md: `k.sh docs` rewrites it too (it is stale on base); I restored the tracked text.

BEHAVIOUR CHANGES
  - None for existing clips, packs or hashes (golden 120/120, world hashes identical).
  - RIGS.md generated block now lists fly/hang/mantle/swing and shows triangles 9292 (was a stale 10296).
  - New: eight clips appear in rig.clips(); kit.selftest gains 8 cases (95 -> 103).

QUESTIONS FOR THE DIRECTOR
  1. stick_yaw is a runtime param, not a property (keeps the kernel API at 1.12). If you want `rig.stick_yaw = x`, it is a
     one-line public var + an API minor bump at merge.
  2. Hockey (L4): the blade rests 56 deg to the right on the crisp figure; L4 should aim with a = bearing - rest (RIGS.md).
  3. KIT.md is stale vs `k.sh docs` on base (L6 / Director regenerate it).

NEXT THREE
  1. Mirrored variants where a game needs them (strike from the left hand, dodge to a named side via a param).
  2. A hit-frame marker in TIMING (strike f5, heavy f13, body_check f12) for packs' hit boxes and the falls lab (L3).
  3. Weapon props on hand_r (sword, shield) so strike / block read as armed at game scale in the colosseum.
