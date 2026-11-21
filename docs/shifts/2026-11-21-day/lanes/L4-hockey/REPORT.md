L4b (round 2 of the day, 15:30-16:50; tree = main 4fbf72d + this round, uncommitted). The round-1 report follows below.
================================================================================================================
1. BUDGET [met, measured busy]
   - Profile (headless smoke, pack tick by section, us/frame): pack scripts tree 277-310 vs base 286-340 (no script
     regression). Hot: brain 103-115, keeper.move 26-28, skate 27, look.tick 25, live_input 12, hits 12, fun 11.
   - Variant A/Bs (alternating invariants): the wider contact capsule costs nothing; the figures' clips (body_check,
     cross_check, skate_stop, now played far more often) cost ~0.06 ms headless.
   - Done, all hash-neutral unless said:
     - The figures' clips (hits, skate_stop, shot and pass) and the stick posing are skipped headless as drawing only.
       To keep that honest, no hashed value reads a pose any more: the lying body (item 3) is read from the body, not
       from the rig's head socket. This one did move hashes, because the downed segment changed from "head socket" to
       "feet + 3.1 m".
     - look.tick returns at once headless (HUD plates, key lines, rings).
     - The brain shares one positions list for every skater's separation (TLSteer.separate skips a skater's own point;
       bot_hockey and bot_match hashes equal before and after).
   - Proof (alternating invariants, 3 pairs, against `git show c770f3f:engine/packs/hockey`, labelled busy: other lanes
     on the machine): base 0.997 / 0.961 / 0.956 ms vs tree 0.952 / 0.978 / 0.996 ms p50 (mean 0.971 vs 0.975: parity).
     Before this round the same A/B was 0.971 vs 1.018 (+0.047).
     Final snapshot (.tl/b16 = the tree), after the ladder: base 0.984 / 1.007 / 0.993 vs tree 0.971 / 0.985 / 0.986 ms
     (mean 0.995 vs 0.981: the tree is 0.014 ms under base).
   - In the final packs gate run alone: many_budget p50 0.971 ms PASS (p99 1.400).
   - The quiet figure is still the Director's final-list run.
2. BODY CHECK WIND-UP + PULL [met] (JamSim.cpp:1968-2177, JamCartridge.h:461,479).
   - The press winds up 12 frames: thirdjam's 8, set to the body_check clip's hit frame 12 (RIGS.md TIMING).
   - The human is drawn up to 1.0 m toward the man he pressed at (check_pull_m), so the bodies meet as the wind-up ends.
   - A meeting inside the wind-up is the hit, resolved before the bodies touch. The bodies are stepped one after another,
     so the meeting test uses his own speed along the line as well as the closing speed.
   - Then the 12/6-frame window opens as before.
   - Bots press when their man will be in reach as the wind-up ends.
   - tests/bot_windup.gd 20/20: from 1.6 m the hit lands ON frame 12 (0 frames early); from 0.33 m it lands at the
     meeting (9 frames before).
   - Re-derived tests (named in each):
     - bot_check reads the first hit after the press, or none once the window is out (was press+3);
     - bot_contact's matched-glide row glides through the wind-up;
     - crazy_modes plays a too-short Arsenal match once more (seed 1: 3:0 in 1,412 frames, a shield taken but never
       used, after the flow changed).
   - Effect on play: bots land fewer body checks. bot_modes base saw 107 hits before this round and 36 after.
3. DOWNED-BODY RADIUS [met] (JamCartridge.h:416-422; JamSim.cpp:2467-2487).
   - A lying man is the segment from his feet 3.1 m along his facing (measured on the fall clip; TLHit.down v1 falls
     forward, so the direction follows the falls experiment when it lands). It is 0.6 m thick.
   - A skater on his feet is moved out (at most 0.3 m plus this frame's step a frame, to one side when he lies on the
     hitter's line), and the speed he had into it is taken off.
   - tests/bot_downed.gd 20/20: after the 15-frame fall, the standing skater's capsule edge stays 0.45 m or more off the
     lying centre line (closest +0.15 m beyond that), and he gets past.
   - bot_contact's held cross-check row now steers round the man it floored to reach the second opponent.
4. L5 CHECK (Director): skate.gd resets every field skater's speed and acceleration each frame, so the boost (x1.5 on top)
   cannot compound. It was not reset while a skater is down; it is now. crazy_pickups also asserts the boost's 20.7 at
   its last frame.

GATES (this round, the final snapshot .tl/b16 = the tree)
- packs (TL_GATE_PACKS_DIR, run alone): PASS 53 of 53 verb runs (2 new bots: bot_windup, bot_downed); many_budget 0.971 ms.
- world PASS 8/8, world = alone (hockey 83bcd2ed6136227d@2450). Fast tier PASS (arch 12/12, devx 229/229).
- selftest filter "hockey": 30/30 (block 680 now replays bot_windup and bot_downed too).
- 20/20 seeds: bot_windup, bot_downed, bot_contact, bot_check, crazy_shield, crazy_hipcheck; crazy_modes 5/5.
- LADDER: all 15 cells complete, 300 of 300 runs. Scripted TLHand profiles, not a person.
  | level    | newcomer      | regular      | sharp        | perfect       | idle |
  | rookie   | 17/20         | 19/20        | 20/20        | 20/20         | 0/20 |
  | pro      | 3/20          | 14/20        | 15/20        | 20/20         | 0/20 |
  | all-star | 4/20          | 8/20         | 13/20        | 18/20         | 0/20 |
  - The idle hand wins nothing.
  - Hands keep their order at every level.
  - Pro newcomer fell from 8 to 3 of 20.
  - The idle hand now lies down 6-16 % of frames (bots time their checks on a standing man); the playing hands lie down
    1-2.7 % (was ~0.8).

STRAY WRITES INTO MAIN (found)
- One command backgrounded a whole line, `cd <tree> && ... &`, and its next line appended to a relative `docs/...` path.
  That append ran in the session's default cwd, which is the main checkout. Every write now uses an absolute path
  inside the tree.

L4b FILES: hits.gd, skate.gd, rink_api.gd, look.gd, ai/brain.gd, data/{tuning,drills}.json, pack.json, README.md (rules
3 and 8, test table, known limits), tests/bot_windup.gd and bot_downed.gd (new), tests/{bot_check,bot_contact,
crazy_modes,crazy_pickups}.gd, engine/tools/selftest.d/680-hockey-mechanics.sh.

NEXT: a person's play session of the wind-up and pull; whether the bots' lower hit rate (107 -> 36 in bot_modes) wants a
bot check pull (thirdjam BotCheckPullM, 0 there); the lying direction when the falls arm lands.

L4 hockey-mechanics: REPORT (shift 2026-11-21-day; worktree n21d-hockey, branch n21d-hockey on main 5b89bdf + uncommitted work)
Director: Opus (this lane). Builder: GPT 6.2 Astra through codex, 4 rounds. Everything below was re-run by the director
unless it says "Astra's". The tree also carries L5's crazy-mode hunks (the Director asked for one tested hockey tree).

OUTCOME AGAINST THE ACCEPTANCE
------------------------------
Thirdjam's six mechanics, in the order a player feels them, each with its thirdjam line in the code and in the README
section "Contact and skating (thirdjam port)":

1. Puck on the blade [met, one number scaled]. JamSim.cpp:1478-1545 (StepStick, sweep shield), 4160-4177 (carry assist),
   JamCartridge.h:159,182-189,187,295.
   - The puck rides at the blade point along the aim (no aim: 24.1 deg right, half reach), closes 60 % of the gap a frame
     (thirdjam carry_assist 0.6), x0.75 when not sprinting; a sweep faster than 6 deg/frame shields it 12 frames (6
     sprinting) from pokes.
   - DECISION (director, in a window): thirdjam's 1.2 m is for its 0.4 m body. Our figure is 4.4 m tall (body 0.66 m at
     scale 2.2); at a literal 1.2 m the puck was hidden under the chest (clips/before_blade_1.2m_hidden.jpg). The rule is
     scaled to the figure: (0.66 + 1.98) x 0.75 = 1.98 m walking, 2.64 m sprinting (was 3.03 m always). There it sits at
     the drawn blade (clips/after_blade_scaled_1.98m.jpg). The brief's "within 1.3 m" became "within 2.05 m" in
     bot_carry_turn for that reason.
   - stick_yaw (L2): the drawn blade is steered onto the puck in a closed loop on the rig's stick_blade socket (half the
     bearing gap a frame, clamp -1.2..2.0). The open-loop "bearing - rest" from RIGS.md was 60-90 deg off in a window
     because the rest bearing moves with the skate pose. clips/final_skate.mp4, preview_L2_stick_yaw_carry_strip.jpg.
   - bot_carry_turn 20/20: kept through a turn and both sweeps, 1.980 m walking / 2.640 m sprinting, shields 12/6.
2. Brake by reversing + first-step burst [met]. JamSim.cpp:1302-1335, 1378-1412; JamCartridge.h:90-125; JamSim.h:499-504.
   - Input > 120 deg against the velocity: 26 m/s^2 hard stop, no thrust while turning, skate_stop clip + ice spray;
     pivot under 0.5 m/s; burst x1.8 accel for 20 frames after an own stop, a 60-deg cut in 10 frames or 6 rest frames.
     Bots use it (same skate layer: scripts/skate.gd).
   - bot_reverse_stop 20/20: 7.998 m/s to still in 17 frames over 1.063 m (thirdjam: 8 m/s in 19 frames); burst 3.44 vs
     1.98 m/s at 10 frames (1.74x); red's chaser bursts 22-46 frames in an 1,800-frame bot match on every seed.
3. Stability contact model [met]. JamSim.cpp:2523-2785; JamCartridge.h:377-540.
   - impulse = mass x (closing + 1.5 lunge / 3.0 thrust); stability = mass x 6 x brace (front 1.5, side 5, a cross-check
     to the chest ignores it) x speed (to 0.85) x sprint 0.7 x full charge 0.8 x unseen 0.8; ratio < 0.4 bump, < 1
     stumble (TLHit.react, puck loose from 0.7), >= 1 down 60..150 frames (TLHit.down with from_dir); momentum given; the
     attacker pays (recoil); boards x1.25; the carrier cannot hit; 120-frame grace after a get-up.
   - Every hit goes through TLHit.react / TLHit.down with from_dir (hits.gd, and L5's shotgun/hip check).
   - bot_contact 20/20 (13 rows): braced side-on man vs a sprinter: bump ratio 0.383 and the attacker recoils; head-on at
     full speed: ratio 3.43, down 150 frames; same way same speed: dv 0.000 m/s; front cross-check on a standing man:
     ratio 1.16, down 67 frames; standing-front ladder 1/2.75/4.5/6.25/8 m/s = bump/stumble/stumble/stumble/knockdown
     (monotone); side 8 m/s = bump (the brace); the carrier's press does nothing; grace: a bump at ratio 0.54.
   - Figures overlapping at contact (owner's slop list, Director's note): the contact capsule is now the drawn body
     (radius 0.879 m measured on the rig, contact_body_scale 2.93, rig still drawn at 2.2; reaches from the radii).
     Closest standing centres after each of the 13 hits: 1.321 m before -> 1.759 m after (same instrumented bot).
4. The cross-check that hits [met; holdable; bots use it]. JamSim.cpp:1742-1845, 1946-1972; JamCartridge.h:450-488.
   - A tap winds up 10 frames (thirdjam 8: changed so the shove lands on L2b's cross_check clip hit frame 10), 12 for bots
     (their clip starts 2 frames late for the same reason), live 10 frames more. Held >= 10 frames: braced, no sprint, top
     speed x0.9, turns x0.7, one momentum hit on the first body met, spent until release; a braced man hit by a faster one
     is at x0.75 stability. Bots tap it when a body check cannot land. Shown by the cross_check clip, never a rectangle
     (clips/final_cross_check_moment.jpg).
5. Sprint with stamina [met]. JamSim.cpp:1266-1300, 1338-1346; JamCartridge.h:67,70,80-85; JamSim.h:505.
   - Free skater x1.15 always, sprint +15 %, 180 frames to drain, 360 to refill; the carrier x0.92 with +8 % capped at 0.97
     of a defender's sprint; HUD bar bottom centre; bots never sprint.
   - bot_sprint 20/20: 10.578 m/s free sprint, 180/360 frames, carrier 7.946 m/s, a defender catches him from 6 m in
     122 frames.
6. Hold-to-charge shot, flat [met]. JamSim.cpp:2786-2895; JamCartridge.h:320-321,340.
   - Fires on release: tap (<= 4 frames) 18 m/s, 30 frames 26 m/s; one-timer kept (the larger of charge and x1.35);
     a charge dies with the puck. bot_charge 20/20: 18 / 18 / 19.33 / 22 / 26 / 26 / one-timer 24.3 m/s.
7. Found in the ladder and fixed: the idle hand won rookie seed 6 1:0 because red's goalie passed out from a blade 1.1 m
   behind him, inside his own net (my carry geometry). A goalie now holds the puck on the ice side of his body; seed 6 is
   0:0.

Not met / partly met:
- Body check timing vs L2b's clip: the check resolves when the bodies meet inside its window (12 frames human, 6 bot)
  from the press, while body_check shows its hit at frame 12. Aligning it means thirdjam's check wind-up (8) and pull
  (CheckPullM 1.0, JamCartridge.h:461-480) plus re-derived drills: not done today.
- The floored man falls forward (TLHit.down v1 ignores from_dir; L3's arms replace the body) and lies under the hitter.
- p50 <= 1.0 ms QUIET: not measurable today (the machine was never quiet). Busy A/B says the final tree costs +0.04 to
  +0.10 ms over base (~4-10 %); at base's ~0.92 ms quiet that is 0.96-1.01 ms: at the budget, not safely under it.
  The per-frame costs added today: the skate layer (cached in round 3), the blade follow, the wider capsules.

GATES (director's runs)
-----------------------
- Packs (tl check --tier full --only packs, TL_GATE_PACKS_DIR on the final snapshot .tl/r15 = the tree's pack): hockey
  50 of 51 verb runs PASS (lint, smoke, 48 bots incl. 5 new L4 bots and 6 L5 crazy bots); the one red is
  invariants.many_budget p50 1.342 ms on a busy machine (determinism c624b8117ae4dea9 twice, p99 2.313 ms ok, bot
  determinism 04a3d135@4736 ok). Base on the same machine this morning: 39 of 40 with the same red (p50 1.368 busy).
  Parkour not re-run by me (no L4 change touches it; it was 21/21 in the base run).
- Perf A/B, busy, alternating invariants (.tl/ab.sh), base .tl/base vs tree:
  round 1 +0.14 ms (fixed in round 3); round 3 1.068 vs 1.048 (parity); joined tree with stick_yaw on 1.069 vs 1.117
  (+0.05, +4.5 %); final tree, two sets after the ladder: base 1.017/0.998/1.028 vs 1.108/1.083/1.143 (+0.10), then with stick posing skipped headless (drawing only, nothing hashed reads it; hashes checked equal) base 1.211/1.071/1.090 vs 1.068/1.233/1.205 (+0.04; run-to-run noise is +-0.15). Base is ~0.92 ms quiet (spark), so quiet ~0.96 is the estimate, NOT a measurement.
- World (tl check --tier full --only world): PASS 8/8, world = alone (hockey 04a3d13576ffc288@4736).
- Fast tier: PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck).
- Selftest filter "hockey": 24/24 PASS (hunt2.hockey_* 3, hockeyfun.* 6, hockeymech.* 15 = block 680: carry_turn,
  reverse_stop, contact, sprint, charge each bot record = replay hash).
- 20 of 20 seeds (director's reruns): bot_carry_turn, bot_reverse_stop, bot_contact (final), bot_check (final),
  bot_sprint, bot_charge; crazy_shotgun, crazy_hipcheck, crazy_shield, crazy_slowpuck, crazy_pickups; crazy_modes 5/5.

LADDER (tl ladder --pack <final snapshot> --seeds 20; hands = TLHand profiles, bots' figures, not a person)
------
All 15 cells complete, 300 of 300 runs (final snapshot .tl/r15, 15:15):
| level    | newcomer      | regular       | sharp         | perfect       | idle |
| rookie   | 18/20 (90 %)  | 20/20 (100 %) | 20/20 (100 %) | 20/20 (100 %) | 0/20 |
| pro      | 8/20 (40 %)   | 12/20 (60 %)  | 16/20 (80 %)  | 20/20 (100 %) | 0/20 |
| all-star | 5/20 (25 %)   | 7/20 (35 %)   | 10/20 (50 %)  | 17/20 (85 %)  | 0/20 |
The idle hand wins nothing at any level (after the goalie fix: before it, rookie idle was 1/20). Against 16 Nov's table
the order of hands holds; all-star regular dropped from 50 to 35 % and pro newcomer rose from 25 to 40 % (20 seeds: the
intervals overlap). The goals go up with the hand, not the stats.

CHANGED FILES (engine/packs/hockey unless said)
-------------
L4: scripts/{main,player (new),skate (new),rink_api,hits,state,drills,intro,dial}.gd, scripts/ai/brain.gd,
scripts/fun/fun.gd, data/{tuning,drills,ai}.json, data/levels/{rookie,pro,allstar}.json, pack.json, README.md,
tests/bot_{carry_turn,reverse_stop,contact,sprint,charge}.gd (new), tests/rink_bot.gd (new shared base), tests/bot_check.gd
(rewritten for the model) and the input-timing updates of bot_{aim,buttons,fun,goalie,hockey,intro,reach,hand_*,ladder_*};
engine/tools/selftest.d/680-hockey-mechanics.sh (new).
L5 (copied from n21d-crazy as they are, ~14:00): scripts/{abilities,boosts,modes,look}.gd, scripts/fx/neon.gd,
gen/{crazy,neon}_hook.gd, data/boosts.json, data/modes/{arsenal,shotgun,glow}.json, tests/crazy_*.gd; engine/style/*.json
(L5's approved append-only glow keys, applied as L5's diff). L5's main/state/hits/tuning/pack/README hunks re-done in my
rewritten files.
Adapted in L5's files for the joined rules (each named in a comment): abilities.gd hip check reaches by hits.check_gap and
pushes the puck 2.0 m/s (the old key is gone), its bot moves go through skate.want; boosts.gd speed boost multiplies the
frame's skate_accel; data/boosts.json shot_line moves b0 (the blade is 1.24 m out now) and the rush press is at frame 58
(wider bodies meet sooner); tests: crazy_shield samples speed at 61, crazy_slowpuck/crazy_pickups read the shot one frame
later (fires on release), crazy_pickups expects the free-skater base 9.2/13.8 (x1.15).

BEHAVIOUR CHANGES THAT MOVE HASHES
----------------------------------
Every hockey hash moved: new declared drill actions (TLInput hashes action names), the blade carry and the puck's place
in the node order, the skate layer (burst, stop, x1.15 free speed, stamina), the contact model and the wider contact
body, the shot on release, and L5's ability action declared lazily. Base modes stay hash-equal between L5-on and
L5-off code paths (crazy is inert outside its modes; L5's claim, its tests pass here).

ASTRA
-----
Round 1 241,309 tokens; round 2 215,858; round 3 263,451; round 4 171,574: total 892,192 (budget ~800 k: 92 k over).

FOR THE OWNER (how to look)
---------------------------
node devx/bin/tl.mjs play hockey : W A S D (reverse to stop hard, then push), Shift sprint (bar bottom centre), mouse
aims the stick (watch the drawn blade follow), left button: shoot (hold to charge) / cross-check without the puck
(hold to skate in with it), right button: pass / body check. Clips: lanes/L4-hockey/clips/final_*.mp4.

QUESTIONS FOR THE DIRECTOR
--------------------------
1. Contract? none touched. engine/style changed only by L5's approved append-only hunk.
2. The body check's wind-up + pull (thirdjam) to sit on L2b's hit frame: next lane?
3. L5's files in n21d-crazy were last changed 13:25; at 14:45 they differ from this tree only by my named adaptations. If L5 changes them again, re-copy and re-run the crazy tests.

NEXT THREE
----------
1. Body check wind-up 8 + pull 1.0 m (thirdjam) aligned to body_check's hit frame 12; re-derive the drills.
2. Downed-body radius (thirdjam DownedRadiusM): standing skaters go round a lying man instead of over him.
3. A person's play session (his hand is the bar): the stop-and-go, the sweep shield and the held cross-check felt by hand.
