K8 balance: report, round 3b (25 Nov 2026, 02:11-04:00). Landable round 3b.

Nobody has played hockey.thirdlife. Every figure is a hand's (the planning hand of epoch k8-4, or thirdjam's scripted
playtester as the second opinion), never a person's. Nothing here says the game is fun.

IN SHORT
Round 3b changed nothing in the game: no source, patch, cartridge or rules file (the Director: keep the matrix's cells
valid; no pro step; do not touch the hokej data files). It finished the 200-seed matrix (50 cells on hockey.thirdlife, both
ablation arms), the reference columns on hockey.regular (the planning hand's ladder at 200 seeds; its single verbs at 60),
the T7 verdicts, and folded the tables into HOCKEY-BALANCE.md, OWNER.md and the lane's tables/.
Three things it showed that the owner's page now says:
1. Five verbs are shown to matter (the shot, the charged shot, the stop, the sprint, the body check); six show no worth
   alone; the pass and the deke cost the hand that uses them.
2. MY HAND'S CALIBRATION IS OFF. At 200 seeds its regular setting wins 85.0 % (+-2.5) at pro on hockey.regular (I fitted it
   at 40 seeds to 77.5 and checked it at 60: 78.3; thirdjam's own regular hand wins 75.5). So the "84 % at pro, outside
   the 60-80 band" is the instrument's level, not the cartridge's: the same hand wins 85 on thirdjam and 84 on the Third
   Life cut. Pro did not get easier, and my earlier "the kept rules made pro easier (78 to 88)" is withdrawn.
3. ALL-STAR GOT EASIER: 50.0 to 66.5 % for the regular planning hand, 77.5 to 88.0 for the good. Not attributed to one
   change (the cut already stood at 65 % after round 2's rules, 60 seeds, before E11 touched all-star's legs).

1. THE FINAL MATRIX (hockey.thirdlife beside hockey.regular; the same hand, the same seeds)
  WINS, per cent (+- one standard error), 200 seeds a cell unless said
  hand, level                       hockey.regular            hockey.thirdlife          
  planning novice, rookie           98.0 ±1.0                 92.0 ±1.9                 
  planning novice, pro              49.5 ±3.5                 55.5 ±3.5                 
  planning novice, all_star         23.5 ±3.0                 22.5 ±3.0                 
  planning regular, rookie          100.0 ±0.0                99.5 ±0.5                 
  planning regular, pro             85.0 ±2.5                 84.0 ±2.6                 
  planning regular, all_star        50.0 ±3.5                 66.5 ±3.3                 
  planning good, rookie             100.0 ±0.0                100.0 ±0.0                
  planning good, pro                95.5 ±1.5                 95.5 ±1.5                 
  planning good, all_star           77.5 ±3.0                 88.0 ±2.3                 
  the idle hand, rookie             60.5 ±3.5                 23.5 ±3.0                 
  the idle hand, pro                9.5 ±2.1                  9.0 ±2.0                  
  the idle hand, all_star           5.5 ±1.6                  6.0 ±1.7                  
  thirdjam's novice, rookie         97.5 (PLAY)               89.5 ±2.2                 
  thirdjam's novice, pro            24.5 (PLAY)               15.0 ±2.5                 
  thirdjam's novice, all_star       10.5 (PLAY)               11.5 ±2.3                 
  thirdjam's regular, rookie        100 (PLAY)                98.5 ±0.9                 
  thirdjam's regular, pro           75.5 (PLAY)               68.5 ±3.3                 
  thirdjam's regular, all_star      39.5 (PLAY)               48.0 ±3.5                 
  thirdjam's good, rookie           100 (PLAY)                100.0 ±0.0                
  thirdjam's good, pro              76 (PLAY)                 75.5 ±3.0                 
  thirdjam's good, all_star         53.5 (PLAY)               56.0 ±3.5                 

  THE REGULAR PLANNING HAND AT PRO, the play itself
  figure                            hockey.regular            hockey.thirdlife          
  goals for / against a minute      1.631 / 0.682             1.582 / 0.713             
  goals walked over the line (strict), share of his side's7.4 %                     0 %                       
  a carry, seconds; share lost to an opponent0.7; 40.4 %               0.79; 45.5 %              
  takes straight off a carrier: with a key / with none, a minute3.85 / 0.61               4.3 / 0.2                 
  passes a minute; share that reach a mate4.35; 56.7 %              3.47; 60.9 %              
  of those: lost first / back to him / a mate's shot / a goal51.7 / 36.4 / 9.8 / 4.7 % 49.4 / 34.6 / 12.4 / 3.4 %
  one-timers a match                0.08                      0.06                      
  knockdowns a match; seconds on the ice3.54; 7.16                3.76; 4.64                
  changes of side a minute; puck loose28.35; 32.9 %             28.12; 32.2 %             
  share of play time sprinting; his mean speed22.3 %; 9.43 m/s          22.6 %; 9.41 m/s          
  a match, seconds                  111.3                     115.4                     

  THE REGULAR PLANNING HAND AT PRO WITHOUT ONE VERB: wins in points against the full hand, paired (+- one standard error)
    x = out of its menu and keys (it re-plans; leans toward "costs nothing"); k = still pressed, never heard (leans toward "vital")
  without                           thirdlife, x (200 seeds)  thirdlife, k (200 seeds)  regular, x (60 seeds)     
  shoot                             -56.5 ±4.0 *              -                         -11.7 ±7.2                
  charge                            -10.0 ±3.9 *              -9.5 ±3.9 *               -5.0 ±7.3                 
  tap                               -1.5 ±3.1                 -2.5 ±3.0                 +0.0 ±4.8                 
  onetimer                          +3.5 ±2.2                 +0.5 ±1.1                 +0.0 ±3.4                 
  deke                              +6.5 ±2.3 *               +1.5 ±2.5                 +5.0 ±4.4                 
  pass                              +5.0 ±3.1                 +6.0 ±3.2                 +16.7 ±6.4 *              
  sprint                            -9.5 ±4.1 *               -3.5 ±3.8                 +0.0 ±5.8                 
  stop                              -10.0 ±4.0 *              -5.0 ±4.0                 +0.0 ±7.9                 
  shield                            -2.5 ±3.6                 -6.0 ±3.6                 +5.0 ±7.7                 
  spin                              +2.0 ±3.2                 +3.0 ±3.4                 +0.0 ±7.1                 
  poke                              +3.5 ±3.1                 -4.0 ±3.1                 +6.7 ±6.7                 
  lift                              +0.5 ±3.6                 -2.5 ±3.4                 +3.3 ±7.1                 
  check                             -5.5 ±3.6                 -9.0 ±3.8 *               +3.3 ±7.9                 
  brace                             +2.0 ±3.4                 -0.5 ±3.1                 +3.3 ±7.1                 

  thirdjam's regular hand at pro on hockey.thirdlife: 68.5 ±3.3; without the pass 71.0 ±3.2; without any shot 20.5 ±2.9.

    T7 VERDICTS (re-planning arm / dead-key arm, points of wins, 200 seeds)
      carries the game            every shot: -56.5 +-4.0
      matters                     charged shot -10.0 / -9.5; stop -10.0 / -5.0; sprint -9.5 / -3.5; body check -5.5 / -9.0
                                  (two standard errors in at least one arm, the same sign in the other)
      leans to mattering          far-side carry -2.5 / -6.0 (+-3.6)
      no worth shown, alone       tap shot -1.5 / -2.5; stick lift +0.5 / -2.5; poke +3.5 / -4.0; brace +2.0 / -0.5;
                                  spin +2.0 / +3.0; one-timer +3.5 / +0.5
      costs the hand that uses it pass +5.0 / +6.0 (+-3.2); deke +6.5 / +1.5 (+-2.4)
      wins alone                  none (skating alone wins 7 %: round 2's matrix, 60 seeds)

  On the reference column of the single verbs (hockey.regular, 60 seeds, the re-planning arm): without any shot the hand
  loses 11.7 points on thirdjam (+-7.2) and 56.5 on the Third Life cut; without the pass it wins 16.7 more on thirdjam
  (+-6.4) and 5.0 more on the cut. The shot became the way to score; the pass costs a third of what it did, and still costs.

2. THE T7 VERDICTS, AND WHAT I WOULD DO WITH THEM (nothing was changed)
- A verb "matters" only when one arm shows two standard errors and the other agrees in sign: each arm leans (a planner
  that re-plans toward "costs nothing", the dead key still pressed toward "vital").
- The sprint and the stop, invisible at round 2's 60 seeds, are clear at 200 (-9.5 and -10.0 in the re-planning arm).
- The lift, the poke and the body check do one job and hide each other: alone only the check shows (-9.0 with the key
  dead). Their worth as a group was not measured: the first cell to add.
- The deke is the one verb I would cut next: dead in thirdjam by PLAY, worth nothing with the key dead (+1.5), and the hand
  does better without it in its menu (+6.5 +-2.3). The spin shows nothing in either arm: the second candidate.
- The one-timer is dead because the pass is; it is the genre's signature goal (CASES) and stays, tied to T3.
- The brace shows nothing in either arm (+2.0 / -0.5). The owner asked for it by name (R-0064): kept, his to judge.

3. TARGETS AT THE END OF THE NIGHT (HOCKEY-BALANCE.md section 12, "After round 3b")
  T1 no walked goals: MET (0 % of his side's goals; 7.4 % on hockey.regular for the same hand).
  T2 the shot is how you score: MET (-56.5 points without it; thirdjam's scripted hand 68.5 to 20.5 %).
  T3 passes arrive and pay: NOT MET, kept in the table. 60.9 % reach a mate (65 asked); the pass costs the hand 5 to 6
     points in both arms; of the passes that arrive 49 % are lost first by the mate. The mates' skill: next campaign.
  T4 a carry skill can keep: NOT MET. 0.79 s, 45.5 % lost (hockey.regular: 0.70 s, 40.4 %).
  T5 no take without a key: NEARLY. 0.20 a minute straight off a carrier (hockey.regular 0.61); gym 0 of 12.
  T6 knockdowns and time on the ice at pro: seconds MET (4.6 s; hockey.regular 7.2), count NOT (3.8; 3 asked).
  T7 every kept verb matters: PARTLY (the verdicts above).
  T8 the ladder: idle at rookie MET (23.5 %; 60.5 on hockey.regular); spread MET at pro (55.5 / 84 / 95.5) and all-star
     (22.5 / 66.5 / 88); the regular planning hand at pro 84.0 %: OUTSIDE the 60-80 band, and 85.0 % on hockey.regular (the
     hand's calibration, point 2 above); all-star easier than thirdjam's.
  T9 no level harder by legs: MET by construction.
  T10 pace: HELD (a pro match 115 s; hockey.regular 111 s).

4. THE STEP I WOULD TAKE NEXT (the Director asked me to name it; none of it was done)
  a. Fit the planning hand again at 200 seeds or more, its regular setting to thirdjam's 75.5 % on hockey.regular. Only then
     can "60-80 % at pro" be read. Every comparison between the two cuts in this report holds regardless (same hand, same
     seeds, both sides).
  b. If pro is then still above the band: pro's stick (the poke at once, as all-star's): six pro cells.
  c. Give all-star its difficulty back by play (its hunt and its stick cadence, not its legs).
  d. Cut the deke, decide the spin, measure the lift + poke + check as a group.
  e. The mates' hands, for the pass (next campaign, per the Director).

ACCEPTANCE (the brief's final criteria)
- The final matrix on hockey.thirdlife, each figure beside hockey.regular's: DONE (200 seeds; the reference single-verb
  column at 60).
  - no kept verb is dead by the planning hand: NOT MET. Six verbs show no worth alone; the pass and the deke cost.
  - no verb wins alone: MET (skating alone 7 %, round 2's matrix; no single verb's removal is worth more than the shot's).
  - passes pay: NOT MET.
  - walk-in goals are gone or deliberate: MET (gone).
  - the hands spread at every level: MET at pro and all-star; at rookie only the novice is apart (92 / 99.5 / 100).
- HOCKEY-BALANCE.md, the hand's validation, the ledger (13 entries: 8 kept, 5 rejected): MET in earlier rounds, unchanged.
- rink.sh balance still reproduces the hockey.regular baseline exactly: MET (GATES).
- node devx/bin/tl.mjs check --tier fast passes: MET (GATES).

GATES (run at the end of 3b, on the tree as it will be landed: only documents and tables changed since 3a)
PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (126 s)
PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (129 s)
PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (209 s)
fast exit 0
PASS  arch                            1090 ms  [12/12] 12 rules (+0 vs last green)
PASS  assets                             3 ms  [4/4] 4 checks passed (+0 vs last green)
PASS  cards                            261 ms  [3/3] 5 cards, schema ok (+0 vs last green)
PASS  devx.test                       7350 ms  [229/229] 229 pass, 0 fail across 17 files (+0 vs last green)
PASS  foreman.typecheck               3258 ms  tsc --noEmit clean
  The three balance lines are, in order: rink.sh balance (the reference runner, hockey.regular, K4's baseline);
  rink.sh balance-thirdlife --parity (the four-patch tree, every switch off); rink.sh balance-thirdlife (hockey.thirdlife
  against its own baseline of 3a). The matrix runs themselves: "PASS  arm hockey.thirdlife: 50 cells x 200 seeds",
  "PASS  arm hockey.regular: 12 cells x 200 seeds", "PASS  arm hockey.regular: 17 cells x 60 seeds".
No full tier (the Director runs it). This lane draws nothing (campaign rule 3 does not apply).

CHANGED FILES (since the landing of round 3a): documents and tables only
  docs/design/HOCKEY-BALANCE.md (section 12: "After round 3b")
  docs/shifts/2026-11-24-night/lanes/K8-balance/OWNER.md (the ladder at 200 seeds on both cuts; which keys earn their place)
  docs/shifts/2026-11-24-night/lanes/K8-balance/ROUND-3.md (section 6), STANDUP.md, REPORT.txt
  docs/shifts/2026-11-24-night/lanes/K8-balance/tables/final_thirdlife.epoch-k8-4.json, final_regular-ladder.epoch-k8-4.json,
    final_regular-ablate.epoch-k8-4.json
Not touched: any source, patch, cartridge, rules file, baseline; engine/packs/hokej/data; native/thirdjam*; contracts/*.

BEHAVIOUR CHANGES: none in 3b.

DEVIATIONS
1. The reference single-verb column is 60 seeds and the re-planning arm only (the thirdlife columns are 200, both arms).
2. No group ablation (lift + poke + check together) and no "skating only" cell at 200 seeds: round 2's 60-seed figure is
   quoted where needed.
3. The planning hand's calibration was found off at the very end (above): the tables are not re-run with a re-fitted hand.
4. Raw output: the arms of the final matrix are kept under .tl/k8/arms (381f2ccef8fc: hockey.thirdlife, 50 cells x 200;
   e3ce47233901: hockey.regular) as the next round's "before"; the 60-seed arms of decided experiments were deleted.

QUESTIONS FOR THE DIRECTOR
1. The hand's calibration: should the next round fit it again at 200 seeds before anything else is read against a band?
   I would. It does not change any verdict of kept / rejected in the ledger (those are paired, same hand both sides).
2. OWNER.md now says all-star is easier than thirdjam's and that my measuring hand is stronger than meant. Both are for
   the morning verdict as they stand.

IF THIS LANE WENT ON: section 4, in that order.
