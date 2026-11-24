K8 balance: report, round 2 (24 Nov 2026, 21:10-23:45). Landable round 2.

Nobody has played hockey.thirdlife. Every figure is a hand's (the planning hand, or thirdjam's scripted playtester as the
second opinion), never a person's. Nothing here says the game is fun.

IN SHORT
hockey.thirdlife is now thirdjam with three rules changed and one cartridge number. Kept this round: a carried puck stays
with its carrier through a body's touch (E03), a knockdown lasts about a second (E04), nobody glides faster than he can
skate and Shift is a real spend (E05). Rejected: the mates' pass share (E06: it changed almost nothing). The take with no
key was confirmed both ways before it was patched, and round 1's guess at its cause was wrong. I found a defect in my own
planning hand (it pressed its poke, lift and check a third to two thirds of a second late), repaired it and fitted it
again; two earlier "findings" (keys that cost their user) were that defect, and nothing is cut on them. What the round did
NOT buy: the player's own carry is as short as in thirdjam (0.79 s), the pass still does not pay, knockdowns a match went
up. Those are the levels' and the mates' work: round 3.

What the owner would feel in the first minute (one line per change kept this round):
- E03: skating into a man who has the puck no longer gives it to you: you bounce off him and he still has it. Press the
  stick lift (or poke, or hit him) and it is yours. Your mates stop losing the puck to a bump the moment you pass to them.
- E04: when you are knocked down you are back on your skates in about a second, not two. You still lose the puck and your
  place; you no longer watch the play leave.
- E05: Shift is a spend now: when the bar is empty you are back at skating pace within half a second, and it must fill a
  quarter before it answers again. And when you pick the puck up at full speed you feel yourself slow to carrying pace: a
  man chasing you will catch you, so move it.

1. THE TAKE WITH NO KEY: CONFIRMED BOTH WAYS (ROUND-2.md section 1)
Round 1's guess (the bodies' bounce throws the carrier's velocity) was WRONG: the puck changes hands one or two frames
before the bodies touch, and the carrier's velocity does not move on that frame. The cause, in thirdjam's own code: the
attacker's body meets the puck on the carrier's blade; BlockCarried (JamSim.cpp:3867) pushes it out of that body and takes
out its motion into him; the puck then moves at the closing speed against its own carrier; RidingCarrier's 4 m/s test
(JamSim.cpp:853) calls it loose; the human's ring (R-0069) or a bot's pickup arc takes it on that frame.
  rinklab probe -which=take, 30 scenes, nobody presses anything:
    head on (fast and slow): the human at a bot 4 of 4 taken; a bot at the human's mate 4 of 4; a bot at the human 0 of 4
    (his own ring takes it back). From the side, from behind, passing 1.3 m wide: 0 of 18.
  Both ways: with patch 0003's switch the same 12 head-on scenes are 0 of 12; and under thirdjam's own rule, when the
  bodies do not touch (the stick and the ring pass over the puck), 0 of 6.
So the leak was one-sided: the human won pucks by skating into carriers, the opposing bots won them from his mates the same
way, nobody won them from him. In matches (a take counted when the puck rode with an opponent at the end of one frame and
is the human's at the end of the next, no stick or hit key of his in the 30 frames before): 1.23 a minute to 0.33 (old
hand, 30 seeds); 0.60 to 0.27 (repaired hand, 60 seeds). Seven traced: four are the carrier's own shot blocked at point
blank, one a puck at shot speed, two a puck squeezed between bodies. About 0.1 a minute is left that I cannot call a block.

2. THE EXPERIMENTS (engine/cores/rink/lab/experiments/LEDGER.md; 60 seeds a cell; wins paired match for match)
  E03 KEPT      carry_holds_body (patch 0003). Gym 12 of 12 to 0 of 12. The planning hand's passes that reach a mate 56.7 to
                67.3 % at pro; it is knocked down 4.5 to 3.7 times a match. Price: planning novice at pro 65 to 43.3 %
                (-21.7 +-8.6), regular 85 to 81.7, good 93.3 to 96.7; all-star regular 66.7 to 55 (-11.7 +-9.2); thirdjam's
                regular at pro 63.3 to 53.3 (-10 +-8.5).
  E04 KEPT      game.contact.down_frames_min / max 60 / 150 to 40 / 90. Seconds on the ice a match, planning hand at pro:
                10.7 to 6.1 / 7.3 to 5.3 / 6.0 to 3.5 (novice / regular / good). Knockdowns a match not down (3.7 to 4.3).
                Wins inside the noise; one scripted cell at two standard errors (thirdjam's novice at pro 20 to 8.3 %).
  E05 KEPT      over_top_decel_mps2 4 and sprint_restart_share 0.25 (patch 0004). Probe: a sprint's 14.55 m/s is 12.65
                within 28 frames of the bar running out (thirdjam: 14.55 for seconds); a puck picked up at 12.65 m/s is
                carried at 10.57 after 30 frames (thirdjam: 12.57); easing the stick glides as before. Found on the way:
                in thirdjam a held sprint key on an empty bar sprints again every other frame (290 sprint frames of 401
                on a 180-frame bar), so the bar never ends a held sprint. Wins: planning regular at pro 78.3 to 91.7
                (+13.3 +-6.5), all-star 63.3 to 51.7 (-11.7 +-8.6); no cell broke.
  E06 REJECTED  mate.pass_to_human 0.8 at every level (thirdjam 0.6 / 0.4 / 0.2). It changed almost nothing: for thirdjam's
                regular hand at pro all 60 matches ended as before; of the planning hand's completed passes 36.4 % came
                back before and 35.5 % after. The share is rarely what decides.
E03, E04 and E05 were read through the hand BEFORE its repair. Their rule-level evidence (gym, probes, strict counts,
seconds on the ice) does not depend on the hand. Their statements about single verbs ("the lift is now worth 10 points",
"the sprint now costs 11.7 to lose", "the body check costs its user") did not survive the repaired hand and are withdrawn;
the ledger entries say so.

3. A DEFECT IN MY OWN HAND, REPAIRED (ROUND-2.md sections 3-4)
The planning hand held the FIRST press of its poke, lift and check back by 20, 30 and 40 frames. It chose the body check
13 times a minute and pressed it 0.3 times. Repaired (and a spent brace is let go). The repaired hand won 93 % at pro on
hockey.regular with round 1's limits, so the same one number was fitted again there (eight settings, 40 seeds each): it
now sees the game 467 / 367 / 233 ms late and decides every 0.67 / 0.5 / 0.27 s. On hockey.regular, 60 seeds: 50 / 78.3 /
91.7 % at pro (thirdjam's regular hand: 75.5), 60 % at all-star (regular), 98.3 % at rookie (novice). Round 1's unprompted
findings read again through it and stand (walked goals 0.40 of 2.13 a match; a carry 0.72 s, 41 % lost; 0.60 takes a
minute with no key; one-timers 0.07 a match; rookie won by the novice). One new reading: of its completed passes 55 % are
followed first by an opponent carrying the puck, 39 % come back, 5 % become a mate's shot.

4. THE MID-ROUND MATRIX (after three kept changes; repaired hand; 60 seeds; ROUND-2.md section 5)
                                         hockey.regular     hockey.thirdlife
  planning hand at pro, nov / reg / good   50 / 78.3 / 91.7   46.7 / 83.3 / 96.7 %
  ... at all-star                          - / 60 / -         23.3 / 65 / 86.7 %
  ... at rookie                            98.3 / - / -       100 / 100 / 100 %
  regular at pro: walked goals (strict)    0.40 a match (K4)  0
  ... a carry; lost to an opponent         0.72 s; 40.8 %     0.79 s; 45.7 %
  ... takes with no key, a minute          0.60               0.27
  ... passes that reach a mate             57.6 %             54.6 %
  ... of those: lost / back / shot / goal  55 / 39 / 5 / 4 %  49 / 36 / 12 / 2 %
  ... knockdowns; seconds on the ice       2.9; 5.8 s         4.5; 5.7 s
  thirdjam's hands at pro, nov / reg / good  24.5 / 75.5 / 76 (PLAY)   18.3 / 60 / 85 %
  the idle hand at rookie                  60.5 % (PLAY)      61.7 %
The planning hand (regular, pro, 83.3 %) without one verb, paired: everything but skating -75.0 (+-5.8); every shot -48.2
(+-8.1); the charged shot -6.7 (+-5.8); far-side carry -3.3; stop -1.7; brace 0.0; tap shot, pass, body check +1.7 each;
one-timer, spin +3.3; draw +5.0; sprint, deke +6.7; poke +8.3 (+-4.9); stick lift +11.7 (+-5.9).
How to read it: only the shot is established. Sixty seeds cannot see one verb (+-5 to 8; one of sixteen at two standard
errors is chance). And a planner's ablation LEANS toward "costs nothing": thirteen of sixteen removals come out at zero or
above, because a noisy chooser does a little better with fewer near-equal options, whatever was removed. Round 3 reads the
other arm beside it (the key dead but still pressed: it leans the other way) at 200 seeds.

5. THE KEYS THAT "COST THEIR USER": REPAIRED THE INSTRUMENT, CUT NOTHING
With the repaired hand: the brace 0.0, the body check +1.7, the tap shot +1.7 (round 1: +13.3 and +11.7; under E03: +8).
thirdjam's scripted hand agrees (check 0.0, brace -3.3 at pro). It was my hand. Kept; not shown to matter either (T7 is
open until the 200-seed matrix). The poke from the front was not touched: the lift does its job at arm's length; a round-3
candidate after the levels.

TARGETS AFTER ROUND 2 (planning hand, regular, pro; HOCKEY-BALANCE.md section 12)
  T1 met (0 walked goals). T2 met (-48 points without the shot). T3 not met (55 % reach a mate; the pass is worth nothing
  to the hand; half of the arrived passes are lost by the mate). T4 not met (a carry 0.79 s, 46 % lost). T5 nearly (0.27 a
  minute, mostly blocked shots; gym 0 of 12). T6 half (5.7 s on the ice; 4.5 knockdowns, not 3). T7 open. T8: spread at pro
  and all-star met; regular at pro 83 % (band 60-80); rookie 100 / 100 / 100 and idle 62 %: not met. T9 untouched (opponents'
  mean speed 0.90 / 1.01 / 1.08 of the human's). T10 held.

ACCEPTANCE (the brief's, per round)
- Every change cites its target; rulings quoted: MET (E03-E06 in the ledger; R-0048, R-0049, R-0041, R-0045, R-0067).
- Every kept change has its ledger entry with before / after by both kinds of hand; rejected ones too: MET (7 entries).
- No change kept on a hunch, none that breaks a target it did not aim at: MET, with one thing said plainly: the ladder
  moved (regular at pro above the band) and is the level table's to set (round 3), as agreed after round 1.
- After every three kept changes the whole matrix runs again: DONE as a 33-cell matrix at 60 seeds (not the 51-cell
  matrix at 200: that is round 3's).
- rink.sh balance reproduces the hockey.regular baseline exactly: MET.
  PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (157 s)
- tl check --tier fast: MET (exit 0, 5 of 5 steps).

GATES
All from the closing run of 24 Nov 23:27-23:39, after the last edit to any source:
PASS  rink lab-build: engine/cores/rink/lab/bin/rinklab.exe
PASS  thirdlife tree: up to date (4 patches)        (from scratch earlier in the round: "4 patches applied", 3 files differ)
PASS  rink lab-build-thirdlife: engine/cores/rink/lab/bin/rinklab-thirdlife.exe
PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (157 s)
      rink.sh balance: the reference runner, hockey.regular, K4's baseline
PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (154 s)
      rink.sh balance-thirdlife --parity: the tree with FOUR patches, every switch off, hockey.regular, K4's baseline
      (also PASS after patch 0003 alone and after 0003 + 0004, earlier in the round)
PASS  balance baseline written: 12 cells x 50 seeds, 43 gym probes (207 s)
      rink.sh balance-thirdlife --update: deliberate (three kept changes). Beside the reference's: 21 of 43 gym probes are
      identical (top speeds, 30 m times, every stop, every pass and shot); 22 moved: all eight hit / poke / lift / no-key
      scenes (the puck no longer changes hands on the way in: "no key, head on" 20 of 21 taken becomes 0 of 21; a check
      lands 16 of 21, was 15), the carrier and chase scenes (he no longer starts above his top) and the sprint scenes that
      run past the bar. thirdjam's regular hand at pro 76 to 66 %, without shots 68 to 14 % (50 seeds).
PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (204 s)
      rink.sh balance-thirdlife: hockey.thirdlife against that new baseline (a second full run: deterministic)
-plancheck (the repaired hand's copies of the sim, with TlHeldBy and TlRider in the state): 0 of 19,454 frames differ on
      hockey.thirdlife (3 pro matches), 0 of 10,357 on hockey.regular (2).
PASS  arch            [12/12] 12 rules (+0 vs last green)
PASS  assets          [4/4] 4 checks passed (+0 vs last green)
PASS  cards           [3/3] 5 cards, schema ok (+0 vs last green)
PASS  devx.test       [229/229] 229 pass, 0 fail across 17 files (+0 vs last green)
PASS  foreman.typecheck  tsc --noEmit clean
      node devx/bin/tl.mjs check --tier fast: exit 0
No full tier (the Director runs it). This lane draws nothing (campaign rule 3 does not apply).

CHANGED FILES (since the landing of round 1)
New: engine/cores/rink/native/patches-thirdlife/0003-carry-holds-body.patch, 0004-over-top-decel.patch;
  engine/cores/rink/lab/experiments/E03.json, E04.json, E05.json, E06.json;
  docs/shifts/2026-11-24-night/lanes/K8-balance/ROUND-2.md, REPORT.txt, tables/mid_matrix...json, tables/plan_calibration...json.
Changed: engine/cores/rink/native/content/Cartridges/hockey.thirdlife.cartridge.json (game.contact.down_frames_min / max),
  hockey.thirdlife.rules.json (three rule keys); engine/cores/rink/lab/balance.thirdlife.baseline.json (deliberate: --update);
  lab_plan.cpp (the hand's repair and limits); lab_gym.cpp/.h and rinklab.cpp (rinklab probe -which=take|speed);
  lab_filter.cpp/.h and cells.mjs (three read-only counters); experiments/run.mjs (epoch, two cell sets), LEDGER.md;
  docs/design/HOCKEY-BALANCE.md (the hand's repair in section 7, lines in 11, round 2 in 12); STANDUP.md.
Not touched: native/thirdjam*, the shim, the glue, native/SConstruct, the pack, anything drawn, contracts/*.
Patches 0001 and 0002 are byte for byte as landed.

BEHAVIOUR CHANGES
hockey.regular: none (600 of 600 hashes on both runners; 43 gym probes).
hockey.thirdlife: the three rules and the knockdown number above. No test expectation moved; the thirdlife baseline was
rewritten on purpose (its gym probes: see GATES).

FOR LANE K1 (the cartridge switch)
Rule keys the sidecar now carries (all through the patches' own TlSetRule; unknown key = error):
  net_carry_wall (bool, 0002), carry_holds_body (bool, 0003), over_top_decel_mps2 (number 0..60, 0004),
  sprint_restart_share (number 0..1, 0004). "levels" is still empty.
New sim state behind switches: FJamPuckState::TlHeldBy (0002), TlRider (0003): hashed only while their switch is on; a
snapshot or a lockstep checkpoint of the thirdlife variant must carry both.
hockey.thirdlife.cartridge.json now has a game.contact object (thirdjam's own keys).

DEVIATIONS (beyond round 1's list; ROUND-2.md section 8)
1. The rules and the number above (each off / thirdjam's value in hockey.regular).
2. The planning hand was changed and fitted again mid-campaign; arms are tagged by epoch (k8-4 now); no older cell is
   reused; the raw arm kept after round 1 was of the old epoch and was deleted.
3. rinklab gained "probe" (this lane's scenes; rink.sh balance's gym lines are unchanged) and three counters.
4. The mid-round matrix is 33 cells at 60 seeds.
5. Two backgrounded command lines of mine began with cd (against the lane rule); they ran in the right place and harmed
   nothing; the rest of the round used absolute paths.

QUESTIONS FOR THE DIRECTOR
1. The pass through the mates needs a patch to the brain's copy in the thirdlife tree (JamAICore.cpp: what a mate does in
   the first second after the human's pass, when he looks for the human again): a level number does not do it (E06).
   thirdjam's AI files stay byte for byte; the patch has its own switch. Agreed as round 3's way?
2. The levels: T4 and T6 hang on how fast pro's bots press a stick or a hit (reaction 0 frames at every level). Round 3
   will set per-level numbers in the sidecar's "levels" (thirdjam's own tune keys) and patch only what a number cannot say.
   The owner called pro "fine": I will hold the planning hand's regular setting at pro inside 60-80 % and say what moved.
3. Machine: under the other lanes' load the 33-cell matrix took 25 minutes at 8 processes; the 200-seed matrix of round 3
   will take 1.5 to 2 hours. Raw output: deleted, except the arm of hockey.thirdlife as it stands (.tl/k8/arms/b588ecd3dd0e,
   33 cells x 60 seeds, epoch k8-4): round 3's "before".

THE NEXT THREE THINGS (round 3)
1. The level table: per-level reaction and press numbers so a level is harder by play (T4, T6, T8 at rookie, T9), the
   regular planning hand held at 60-80 % at pro.
2. The pass through the mates as a brain patch (T3), then the poke's own ground.
3. The whole matrix at 200 seeds with both ablation arms (the planner's, and the dead key still pressed), the cartridge,
   and the page for the owner: what changed, why, what he will feel, what was cut, what is still weak.
