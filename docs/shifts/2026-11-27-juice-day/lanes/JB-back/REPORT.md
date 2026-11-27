JB-back REPORT: the hand juice sent back to Create as one sentence each (27 Nov 2026, 10:11-13:35)

Tree C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield (branch d27-back; fast-forwarded by the Director to
main 658eb637 with lane T's items 1-6 before the shield and Arsenal sentences). Opus, playing the person on the editor
path: every change went through engine/ui/foreman_run.mjs with the real.json change flags (claude-cli, Sonnet, paid).
Full proof: PROOF-JB-back.md; the sentences: SENTENCES.md.

ANSWER
- Yes, mostly. One sentence naming the hand juice brought each game most of the way to its hand version. The one
  allowed follow-up closed the biggest gap that was left in each.
- Robots:
  - v0.1.7 (one sentence, 33 min, one core round, 3.17M in): the hammer head glows; the reach ring;
    BONK!/KA-BONK!!; the camera punches, and follows you when you are launched; robots bounce off the walls; bots
    smash loose balls at goal and pass away from a raised hammer.
  - v0.1.8 (follow-up, 32 min, 1.01M in): the ring shows under every robot, and hit robots fly 3.5-5.0 m (hand
    3.7-5.4).
- Shield wall:
  - v0.1.8 (one sentence, 58 min, 3.71M in): the lane of rings; BOWLED!/BRACED!/SLAM! in the middle of the screen;
    a drawn leap with the camera rising; F/C ready buttons. T's rivals routing gave the crew bots their part with no
    second sentence.
  - v0.1.9 (follow-up, 51 min, 3.68M in): bots charge 12 / 11 / 6 times a minute (hand 14 / 15 / 6); the charge lane
    is wider and the throw higher; the rivals turn their shields to a charge.
- Arsenal:
  - v0.1.24 (one sentence, 27 min, 2.06M in): METEOR in the hint, the burning blade, the fire ring, the fireball,
    METEOR! and FLOORED!.
  - v0.1.25 (follow-up, 20 min, 2.60M in): no meteor off the opening faceoff (the first meteor now comes at frame
    333 / 706 / 397, was 92); METEOR on the plate; its own net bag and glass panes.
- Still short of the hand versions:
  - shield braces are rare (0-2 a minute, hand 3-6), and a charge floors 1-7 men a minute (hand 8-10);
  - the Arsenal net and glass were built but not seen: no meteor goal in my window takes;
  - rink bots cannot use or block the meteor (C++).

ACCEPTANCE
- All three games, each with:
  - the sentences: met (SENTENCES.md, 768 / 798 / 743 characters, plus one follow-up each: 443 / 426 / 392);
  - clips: met (clips/, 10 clips of 20 s or less, 960 wide, editor on top and the hand version underneath);
  - checklists against the hand versions: met (PROOF, one table per game);
  - pack paths and menu titles: met (below).
- Steps per game:
  - played both versions in a window: met;
  - one sentence: met;
  - sent the way Create does: met;
  - judged with clips, a checklist, bots' uses a minute, 3600 headless frames with 0 script errors and the same
    hash twice: met for every version;
  - one follow-up each: met.
- Arsenal's net and glass not seen on screen: NOT met. The part is built (the builder's note) but no meteor goal
  landed in my takes.
- Shield and Arsenal were sent only after the Director's fast-forward to T's fixes: met (sent 11:32).

MENU ROWS (the Director copies the packs to proof-games and adds the rows)
- Robot soccer:
  C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.8
  "Robot soccer: sledgehammer v0.1.8 (made in Create from one juice sentence)"
- Shield wall:
  C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/shield-wall-3-v-20261125-1-jb/promoted/game.shield_wall_3_v@0.1.9
  "Shield wall: charge and slam v0.1.9 (made in Create from one juice sentence)"
- Arsenal hockey:
  C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/three-against-three-hockey-20261125-1/promoted/game.three_against_three_hockey@0.1.25
  "Arsenal hockey: meteor slapshot v0.1.25 (made in Create from one juice sentence)"
- One-sentence-only versions, optional rows, in the same job folders:
  - robots promoted/game.robot_soccer_3_v@0.1.7
  - shield promoted/game.shield_wall_3_v@0.1.8
  - Arsenal promoted/game.three_against_three_hockey@0.1.24
- The pack ids are the same as the existing rows' ids (game.robot_soccer_3_v, game.shield_wall_3_v,
  game.three_against_three_hockey).
- Job copies:
  - robots and Arsenal keep their names, copied from d25-robot and d25-arsenal;
  - shield is shield-wall-3-v-20261125-1-jb, copied from J19's job in this tree;
  - the originals are untouched.

GATES
- tl check --tier fast (12:43, tree = main 658eb637 + my docs): PASS 5/5. arch 12/12, assets 4/4, cards 3/3,
  devx.test 230/230, foreman.typecheck clean.
- No code changed by this lane: docs and .tl/ only. Full tier not needed.
- foreman rebuilt after the fast-forward: npm run build, exit 0.
- Class cache not re-imported. The fast-forward changed no class_name script (engine/ui/create two files, cards
  JSON), and jobs were running Godot on the engine at the time. Say if you want it run.

CHANGED FILES (all untracked, in the lane folder)
- docs/shifts/2026-11-27-juice-day/lanes/JB-back/:
  - PROOF-JB-back.md
  - SENTENCES.md
  - STANDUP.md
  - REPORT.txt
  - clips/*.mp4 (10)
  - stills/*.jpg (24)
- No engine/, foreman/ or contracts/ edit.

FINDINGS FOR THE DIRECTOR AND LANE T (detail in PROOF, "What T's fixes did today")
1. The NOT DONE hand-off duplicates the rivals routing.
   - In shield wall, crew got both the rivals' part and core's NOT DONE for the same change.
   - So it ran a second round that found its work already done, twice: crew r7 (0.71M in) and crew r9 (0.57M in).
2. A hand-off can reach the wrong owner.
   - Arsenal's faceoff lock went from harbour to the cartridge, which has no key for it.
   - The base owns the file harbour named, and harbour's own scripts/main.gd could do it. It did, in r17, after the
     follow-up.
3. A NOT DONE with no owner (Arsenal's net and glass in r16) stays a note.
4. The rivals' copy of a sentence lost a sentence: event 869, "... before he lands. : a rival ...".
5. "merge crew 7 files" / "merge rally 8 files" is logged when the builder wrote nothing and the pack is byte-equal.
6. shield crew r6 changed its own test's scripted captain to use the moves less often, so a mashing check passes. It
   said so; T's freeze does not cover that crew test.
7. The editor reads literally:
   - "up to a second in the air at full charge" gave long flights only at full charge;
   - "a ring shows its reach" while "I charge" gave a ring only under me.
   - A follow-up fixed both.
8. The shield editor version passes bot_call: the first call at frame 420, two floored. Last night's hand version
   fails it (ask 5 of the night verdict).
9. Three window runs ended with a kernel SCRIPT ERROR at worker.gd:387 (_wd_run). It is the watchdog thread's mutex
   at --quit-after shutdown, not the packs.

FOR THE OWNER'S EYE
- Play the three menu rows above and their "(juice by hand)" rows.
- Keys:
  - robots: hold F and let go;
  - shield: F to charge, C to slam;
  - Arsenal: F lights the stick, hold shoot to wind up.
- Arsenal: score a meteor to see whether the new net bag and glass read from the follow camera.
- Arsenal: one take showed the camera dipping behind my own net with a big pale pane at the edge of the frame
  (stills/arsenal_ed0125_s2_f1820.jpg). I did not check whether that pane is one of the new ones.

NEXT THREE THINGS THIS LANE WOULD DO
1. Film a meteor goal on v0.1.25: a hand that scores, read from the harbour's meteor_goal mark. Judge the net bag and
   glass by eye.
2. Shield: a sentence about braces ("bracing bots stand still with the shield up when a charge lane points at
   them"), measured on braced charges a minute against the hand's 3-6.
3. Send the merged-hand-off finding (1) and the wrong-owner finding (2) to T as tests, with these two jobs as the
   cases.

======================================================================================================================
ROUND 2 (Director's second round, 13:29-14:30)

OUTCOME
1. Arsenal v0.1.25 meteor goal on film: met.
   - How: a film copy whose blind hand fires from closer in (F within 19 m, a full wind-up from 15 m) scores a meteor
     goal on seeds 1-4. Its window take of seed 1 scores at about frame 508.
   - Clip: clips/arsenal_v0125_meteor_goal.mp4.
   - The net bag reads as a solid white block popping out behind the goal for about 12 frames, not as a net bulging.
   - The glass: a pale see-through band over the end boards; I cannot see it move at the follow camera's distance.
   - The pale pane of round 1 IS one of the new panes. A copy with the panes off filmed the same seed: identical frame
     at 1820 without the pale rectangle (stills/arsenal_ed0125_s2_f1820_panes_vs_nopanes.jpg). When the camera swings
     behind my own net, the new glass lies across the view: a defect of v0.1.25.
2. Shield wall braces: one sentence (446 chars, 13:29:49) -> v0.1.10 promoted 14:10:23 (40.6 min, 2.98M in).
   - Men floored by a charge a minute: 7 / 5 / 9 (hand 10 / 9 / 8; v0.1.9 3 / 7 / 1). Near the target.
   - Braced charges a minute: 0 / 1 / 2 (hand 5 / 6 / 3). Not met; none on screen in my take.
   - 0 script errors; seed 1 098f54b9de09e943 twice.
   - Crew got core's NOT DONE after it had already done the work: the third duplicate hand-off today (crew r11).
3. Robots: one sentence (439 chars, 13:57:13) -> v0.1.9 promoted 14:26:44 (29.5 min, 0.78M in).
   - A quick tap now says BONK! (the word followed the launch force, so every hit was KA-BONK!!; core found that bug).
   - Fat yellow comic words with an outline, hanging at the spot; thick bright reach rings.
   - Drawing only: the same hashes as v0.1.8.
   - By eye on a par with the hand version.

MENU ROWS (new)
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/shield-wall-3-v-20261125-1-jb/promoted/game.shield_wall_3_v@0.1.10
  "Shield wall: charge and slam v0.1.10 (made in Create from juice sentences)"
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.9
  "Robot soccer: sledgehammer v0.1.9 (made in Create from juice sentences)"
- Arsenal: no new version.

GATES
- tl check --tier fast at 14:28: PASS 5/5. arch 12/12, assets 4/4, cards 3/3, devx.test 230/230, foreman.typecheck
  clean.
- Every new version: 3600 headless frames on seeds 1-3, 0 script errors, seed 1 twice with the same hash. The promoted
  packs are file for file the ones measured.
- No code changed by this lane. Docs and .tl/ only.

NEW FILES (lane folder, untracked)
- clips:
  - arsenal_v0125_meteor_goal.mp4 (0.6 MB);
  - shield_v0110_vs_hand.mp4 (640 wide, 4.4 MB);
  - robot_v019_vs_hand.mp4 (640 wide, 2.7 MB).
- stills:
  - arsenal_g_s1_goal_f470-602, arsenal_g_s1_net_crops, arsenal_g_s1_panes_vs_nopanes,
    arsenal_ed0125_s2_f1820_panes_vs_nopanes;
  - shield_ed0110_overview;
  - robot_ed019_my_f56-144, robot_ed019_f200_f200-332.
- PROOF-JB-back.md sections 4-6, SENTENCES.md round 2, STANDUP.md.
- Film copies (.tl/jb only, never the jobs):
  - arsenal/ed0125g: the scoring hand;
  - arsenal/ed0125_nopane and ed0125g_nopane: the panes off.

FOR THE DIRECTOR AND T
- Shield braces: a third sentence would likely need to name the cause a person sees. Men are rarely facing a charge
  with the shield up when it arrives; the builders set 38-40 % brace chances, but the measured braces stay at 0-2 a
  minute.
- Arsenal: one sentence would ask for a net of cords pushed back (not a white box), glass that flexes visibly, and no
  glass between the camera and the ice.
- The duplicate NOT DONE hand-off (crew r7, r9, r11) is now 3 of 3 shield sentences that named the rivals.

NEXT THREE
1. Arsenal: the net, glass and camera sentence above, judged on the same scoring film copy (seed 1, the goal at about
   frame 508).
2. Shield: a braces sentence in a person's words about what is seen: men turn to face a charger and raise the shield
   when the lane rings appear.
3. A hand test for the editor's shield that counts braces from the BRACED! event, so the hand and editor counts are
   the same instrument.

======================================================================================================================
ROUND 3 (14:29-15:10; tree at main d311514b with T's items 7-16, foreman rebuilt before sending)

OUTCOME
1. Arsenal: one sentence (456 chars, 14:36:14) -> v0.1.26, promoted 14:53:18 (17.1 min, 0.89M in). Drawing only:
   the hashes are the same as v0.1.25's.
   - Net: met. A bag of white cords with its own red frame is driven back and swings. From the camera it looks like a
     second goal frame behind the first, but it reads as the net going back.
   - Glass in front of the camera: met. The round-1 frame (seed 2, 1820) is now clear.
   - Glass that visibly flexes: NOT met.
     - harbour hides the panes whenever the human is within 12 m of that end board, and the scorer of a meteor goal is
       always that close.
     - So in my goal take there is no glass at all; the wobble never shows.
2. Shield: one sentence (476 chars, 14:35:36) -> v0.1.11, promoted 15:07:39 (32.1 min, 1.79M in).
   - Braces counted from the BRACED! word on screen: a new counting test on my film copies only
     (.tl/jb/shield/tests_jb/bot_braced_count.gd, read-only, hashes unchanged).
   - Six seeds, a minute:
     - BRACED!: 1.8 (v0.1.10 1.2; hand 4.8);
     - BOWLED! words: 4.5 (v0.1.10 6.7; hand 7.0).
   - Braces rose but stay under half the hand's, and bowling fell: the brace came at bowling's cost.
   - On screen (seed 2, about frame 560): BRACED! in gold, gold sparks, the charger thrown back.
   - 0 script errors; seed 1 647ec68124850340 twice.
3. The crew duplicate: crew ran one round (r12).
   - But this sentence did not trigger the rivals routing; only core's NOT DONE went to crew.
   - So T's "join the queued round" was not exercised, and I cannot say from this that the duplicate is gone.
   - To test it: a sentence that names the rivals and also makes core say NOT DONE for crew.

MENU ROWS (new)
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/three-against-three-hockey-20261125-1/promoted/game.three_against_three_hockey@0.1.26
  "Arsenal hockey: meteor slapshot v0.1.26 (made in Create from juice sentences)"
- C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/shield-wall-3-v-20261125-1-jb/promoted/game.shield_wall_3_v@0.1.11
  "Shield wall: charge and slam v0.1.11 (made in Create from juice sentences)"

GATES
- tl check --tier fast at 15:09: PASS 5/5. arch 12/12, assets 4/4, cards 3/3, devx.test 230/230, foreman.typecheck
  clean.
- Every new version: 3600 headless frames per seed, 0 script errors, seed 1 twice with the same hash. The promoted
  packs are file for file the ones measured.
- No code changed by this lane: docs and .tl/ only. The counting test lives on film copies.

NEW FILES (lane folder)
- clips:
  - arsenal_v0126_meteor_goal.mp4 (0.5 MB);
  - shield_v0111_braced.mp4 (0.9 MB);
  - shield_v0111_vs_hand.mp4 (640 wide, 4.7 MB).
- stills:
  - arsenal_g6_goal_f470-650, arsenal_g6_net_crops, arsenal_g6_glass_strip, arsenal_ed0126_s2_f1820;
  - shield_ed0111_braced_f528-616, shield_ed0111_s2_overview.
- bot_braced_count.gd: a copy of the counting test, for the record; it lives on film copies only.
- PROOF-JB-back.md sections 7-8, SENTENCES.md round 3, STANDUP.md.

NEXT THREE
1. Arsenal: "show the glass wobble even when I am close; only keep it out of the line between the camera and the ice"
   (one sentence), judged on the same scoring copy.
2. Shield: a sentence for the charge to bowl as before while the braces stay (both at once), measured with
   bot_braced_count over six seeds.
3. A sentence built to exercise T's queued-round join (names the rivals and triggers core's NOT DONE for crew), to
   prove the duplicate gone.
