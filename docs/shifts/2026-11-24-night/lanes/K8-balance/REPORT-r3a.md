K8 balance: report, round 3a (24 Nov 23:45 - 25 Nov 02:05). Landable round 3a.

ROUND 3 IS SPLIT ON THE DIRECTOR'S WORD (01:52). 3a (this report): every experiment decided, the level table, the cartridge,
the owner's page, the note for lane E2, the closing gates, and the 200-seed LADDER (its 21 cells are in). 3b: the rest of
the 200-seed matrix (the planning hand at pro without each verb, both arms: 29 cells) and the reference columns. That run
started at 00:54 at 6 processes and is still going in the background (32 of 50 cells started at 01:55); it changes no
source, cartridge or rules file, only tables. Its markers: .tl/k8/final3.txt (M1DONE, M2DONE, ALLDONE); its tables:
.tl/k8/final-thirdlife.json, final-regular-ladder.json, final-regular-ablate.json; to render: node .tl/k8/render_final.mjs.
Please do not edit engine/cores/rink/lab/experiments/run.mjs or cells.mjs in this worktree until ALLDONE (the chain
starts two more node runs from them).

Nobody has played hockey.thirdlife. Every figure is a hand's (the planning hand of epoch k8-4, or thirdjam's scripted
playtester as the second opinion), never a person's. Nothing here says the game is fun.

IN SHORT
hockey.thirdlife is thirdjam with four rule switches (three rules), two cartridge numbers and a level table. Kept this
round: the first hit only staggers you (E07), rookie plays for the net (E09), all-star has the human's legs (E11), pro
presses (E12). Rejected: the give-and-go (E08: the puck did not come back more often) and pro finishing like all-star (E10:
it made pro easier). The pass still does not pay and the player's own carry is as short as thirdjam's: said plainly in the
owner's page. The 200-seed ladder is in section 3; the rest of the matrix is round 3b.

What the owner would feel in the first minute (one line per change kept this round; all seven are in OWNER.md):
- E07: the hit that used to flatten you the instant you touched the puck now only staggers you: you lose the puck and half
  your speed, and you are still on your skates.
- E09: at rookie the other side now shoots: from the slot, with a wind-up you can see, wide of the corner as often as not,
  and now and then one of them lifts your stick. Stand still and you lose; play and you win.
- E11: at all-star nobody out-skates you any more by having faster legs. They still hunt you from across the ice, lift
  your stick twice as often as pro does, and sprint whenever their bar lets them, as you can.
- E12: at pro they come at you from further off and their sticks are back on yours a second after a miss.

1. THE EXPERIMENTS (engine/cores/rink/lab/experiments/LEDGER.md; 60 seeds a cell; wins paired match for match)
  E07 KEPT      game.contact.take_shield_frames 30 (thirdjam's own rule, lane A177, shipped at 0). Knockdowns a match,
                planning hand at pro 4.9 to 4.4 / 4.5 to 3.6 / 2.9 to 2.7 (novice / regular / good); seconds on the ice
                6.3 to 5.5 / 5.7 to 4.5 / 3.7 to 3.4; thirdjam's regular hand 7.6 to 5.7 knockdowns. Wins inside the noise.
  E08 REJECTED  the give-and-go: a patch to the brain's copy (0005) + mate.hk_give_go_frames_tl=120. Completed passes
                that came back first: 35.5 to 35.0 % (regular planning hand), 39.3 to 33.3 (novice), 34.2 to 24.8 (good);
                lost first by the mate 49.6 to 52.5 %. The patch is out of the series (kept under experiments/rejected/).
  E09 KEPT      levels.rookie: the opponents shoot from inside 17.5 m with a wind-up and lift a stick every 150 frames.
                The idle hand 65 to 28.3 % (-36.7 +-7.5); thirdjam's novice 98.3 to 86.7 % (R-0029's own figure for
                rookie: 85 %); planning novice 100 to 91.7; regular and good still 100, by less and later.
  E10 REJECTED  levels.pro: charged shot, deke, pass under pressure (all-star's switches). Pro got EASIER: goals against
                a minute 0.62 to 0.44 (regular planning hand); thirdjam's novice 16.7 to 40 %, regular 60 to 75.
  E11 KEPT      levels.all_star: red_skill 0.87 (speed_scale x red_skill = 1.0; 1.035 before). The opponents' mean speed
                1.07 to 1.06 of the human's (the rest is sprinting under the same bar rule: play, not legs). Wins inside
                the noise in five of six cells (the good planning hand 76.7 to 90.0, +13.3 +-6.9).
  E12 KEPT      levels.pro: hunt from 16 m (11), lift again after 60 frames (90). Regular planning hand 88.3 to 81.7 %
                (-6.7 +-6.7), novice 58.3 to 50.0, good 93.3 to 91.7; thirdjam's good 78.3 to 68.3; seconds on the ice
                4.5 to 4.7 (T6's 5 s holds).
  Level experiments ran on their own level's cells only: a level's tune cannot touch another level's matches.

2. A TARGET CORRECTED
T9 said "the opponents' mean speed within 5 % of the human's". Mean speed in play is not legs (all-star's opponents have
his top speed exactly and average 1.06 of his speed because they sprint whenever their bar allows). T9 now reads: every
level's opponents have the human's own top speed, acceleration and sprint rule. Met by construction at all three levels.

3. THE 200-SEED LADDER (round 3a) AND WHAT IS STILL RUNNING (round 3b)
  Wins, per cent, hockey.thirdlife, 200 seeds a cell (+- one standard error; at 84 % it is 2.6, at 50 % 3.5):
                              rookie    pro      all-star
    the hand that never moves  23.5      9.0      6.0        (thirdjam, PLAY: 60.5 / 9.5 / 5.5)
    planning hand, novice      92.0     55.5     22.5        (thirdjam, same hand, 60 seeds: 98.3 / 50.0 / -)
    planning hand, regular     99.5     84.0     66.5        (thirdjam, same hand, 60 seeds: - / 78.3 / 60.0)
    planning hand, good       100.0     95.5     88.0        (thirdjam, same hand, 60 seeds: - / 91.7 / -)
    thirdjam's novice          89.5     15.0     11.5        (thirdjam, PLAY: 97.5 / 24.5 / 10.5)
    thirdjam's regular         98.5     68.5     48.0        (thirdjam, PLAY: 100 / 75.5 / 39.5)
    thirdjam's good           100.0     75.5     56.0        (thirdjam, PLAY: 100 / 76.0 / 53.5)
  The regular planning hand at pro: a carry 0.79 s, 45.8 % lost to an opponent; 61 % of its passes reach a mate; 3.8
  knockdowns and 4.7 s on the ice a match; one-timers 0.06 a match; a match 116 s.
  What it says: rookie is no longer won without the player (23.5 %, T8's 25); the hands spread at pro (55.5 / 84 / 95.5)
  and at all-star (22.5 / 66.5 / 88); at rookie only the novice is apart (92 / 99.5 / 100). THE REGULAR PLANNING HAND AT PRO
  IS AT 84.0 % (+-2.6): ABOVE THE 60-80 BAND I WAS ASKED TO HOLD, by 4 points. thirdjam's own regular hand is inside it
  (68.5 %). I did not push pro further tonight because the matrix was already measuring this cartridge; the next step is
  written (E12's notes: pro's poke at once, as all-star's) and is six pro cells, about ten minutes: the Director's call
  whether it goes into 3b.
  Round 3b, not finished: the planning hand at pro without each verb, both arms. Five cells of the re-planning arm are
  complete at 200 seeds (paired against the full hand's 84 %): without the sprint -9.5 +-4.1, without the stop -10.0 +-4.0
  (both now clearly matter), without the far-side carry -2.5 +-3.6, without the one-timer +3.5 +-2.2, without the pass
  +5.0 +-3.2 (the pass still costs the hand a little). Without any shot: -56 +-4 at 173 of 200 seeds. Nothing is concluded
  from the unfinished cells.

4. FOR LANE E2: THE PLANNING HAND'S SHORT LADDER INSIDE rink.sh check-cartridge
Written out in docs/shifts/2026-11-24-night/lanes/K8-balance/CHECK-CARTRIDGE-NOTE.md. In short:
- Six cells at pro, 16 seeds each (about 3 minutes on 6 processes): the idle hand; the planning hand at novice / regular /
  good; the regular hand with every shot taken away; skating only. Each with -plancheck.
- FAIL only on gross defects (16 seeds see nothing finer than about 25 points): a stopped run; more than a quarter of
  matches reaching the 10-minute stop; the idle hand winning half or more; skating alone winning a third or more; the hand
  without the scoring verb within 15 points of the full hand; the good setting below the novice by more than a goal a match.
- PRINT, never pass on: the three settings' wins and goal difference, pace, a carry, passes that arrive, seconds on the
  ice, and the intents the regular hand never chose.
- The trap: the hand is valid only where its copies of the game are exact. Its look-ahead steps a copy of the sim with
  rule hooks, zones and effects unbound. A generated cartridge with pickups, effects, zones or hooks will show
  clone_mismatch above 0: the check must then say "planning hand NOT VALID for this cartridge" and fall back to thirdjam's
  scripted hands, not pass. Cloning the systems with the sim (FJamSystems) is the known gap; not done.
- No win band, no verdict on fun, no single-verb verdict at that size.

5. THE CARTRIDGE AND THE OWNER'S PAGE
- engine/cores/rink/native/content/Cartridges/hockey.thirdlife.cartridge.json: hockey.regular plus game.contact
  { down_frames_min 40, down_frames_max 90, take_shield_frames 30 }.
- hockey.thirdlife.rules.json: rules { net_carry_wall, carry_holds_body, over_top_decel_mps2 4, sprint_restart_share 0.25 };
  levels { rookie, pro, all_star } (thirdjam's own tune keys). NEW for lane K1: "levels" is no longer empty: the glue must
  append levels[level] through thirdjam's ApplyDifficultyTune after the level's profile, or the exe plays round 2's levels.
- docs/shifts/2026-11-24-night/lanes/K8-balance/OWNER.md: what changed and what he will feel (seven lines), what was cut,
  what was thrown away, the ladder beside thirdjam's, what is still weak, three questions.

TARGETS AT THE END (HOCKEY-BALANCE.md section 12)
  T1 no walked goals: MET (by rule; strict count 0).
  T2 the shot is how you score: MET (-48 points at 60 seeds; -56 so far at 200).
  T3 passes arrive and pay: NOT MET. 61 % reach a mate (65 asked); the pass costs the hand 5 points (+-3.2); half of the
     passes that arrive are lost by the mate. Three tries rejected (E02, E06, E08).
  T4 a carry skill can keep: NOT MET. 0.79 s and 46 % lost (thirdjam 0.72 s, 41 %); 1.5 s and 25 % asked.
  T5 no take without a key: NEARLY (gym 0 of 12; matches 0.27 a minute, mostly point-blank blocks).
  T6 knockdowns and time on the ice at pro: seconds MET (4.7 s; 5 asked), count NOT (3.8; 3 asked).
  T7 every kept verb matters: OPEN until 3b. So far at 200 seeds: the shot, the sprint and the stop do.
  T8 the ladder: idle at rookie MET (23.5 %); spread MET at pro and all-star, at rookie only the novice is apart; the
     regular planning hand at pro 84 %: ABOVE the band (60-80).
  T9 (as corrected) every level's opponents have the human's legs: MET by construction.
  T10 pace: HELD (a pro match 116 s for the regular hand).

ACCEPTANCE (the brief's)
- HOCKEY-BALANCE.md exists; every change cites its target; rulings quoted: MET.
- The planning hand rediscovers at least three of PLAY.md's findings unprompted: MET in round 1, re-read through the
  repaired hand in round 2.
- Every kept change has its ledger entry with before / after by both kinds of hand; rejected ones too: MET (13 entries:
  8 kept, 5 rejected).
- The final matrix on hockey.thirdlife: "no kept verb is dead by the planning hand; no verb wins alone; passes pay;
  walk-in goals are gone or deliberate; the hands spread at every level; each figure beside hockey.regular's":
  PARTLY, and the rest is 3b. Walk-in goals: gone. The hands spread: at pro and all-star yes, at rookie the novice only.
  No verb wins alone: skating alone wins 7 % (round 2's matrix). Passes pay: NO. No kept verb dead: OPEN (3b: both arms at
  200 seeds). Each figure beside hockey.regular's: the ladder yes (the planning hand's reference column at 60 seeds until
  3b's 200); the single-verb column in 3b.
- rink.sh balance still reproduces the hockey.regular baseline exactly: MET.
  PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (123 s)
- node devx/bin/tl.mjs check --tier fast passes: MET (exit 0, 5 of 5 steps).

GATES
All from the closing run of 25 Nov 00:41-00:53, after the last edit to any source, cartridge or rules file (the 200-seed
matrix ran after it and changes nothing but tables):
PASS  rink lab-build: engine/cores/rink/lab/bin/rinklab.exe
PASS  thirdlife tree: up to date (4 patches)        (rebuilt from scratch when 0005 was removed: "4 patches applied")
PASS  rink lab-build-thirdlife: engine/cores/rink/lab/bin/rinklab-thirdlife.exe
PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (123 s)
      rink.sh balance: the reference runner, hockey.regular, K4's baseline
PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (126 s)
      rink.sh balance-thirdlife --parity: the four-patch tree, every switch off, hockey.regular, K4's baseline
      (also PASS with five patches while 0005 was in the series: the brain patch with its key at 0 is thirdjam)
PASS  balance baseline written: 12 cells x 50 seeds, 43 gym probes (203 s)
      rink.sh balance-thirdlife --update: deliberate (E07 and the three levels). 21 of 43 gym probes identical to the
      reference's (top speeds, 30 m times, stops, passes, shots).
PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (205 s)
      rink.sh balance-thirdlife: hockey.thirdlife against that new baseline (a second full run: deterministic)
-plancheck: 0 of 22,630 frames differ on hockey.thirdlife (3 pro matches with the final cartridge).
PASS  arch            [12/12] 12 rules (+0 vs last green)
PASS  assets          [4/4] 4 checks passed (+0 vs last green)
PASS  cards           [3/3] 5 cards, schema ok (+0 vs last green)
PASS  devx.test       [229/229] 229 pass, 0 fail across 17 files (+0 vs last green)
PASS  foreman.typecheck  tsc --noEmit clean
      node devx/bin/tl.mjs check --tier fast: exit 0
No full tier (the Director runs it). This lane draws nothing (campaign rule 3 does not apply).

CHANGED FILES (since the landing of round 2)
New: engine/cores/rink/lab/experiments/E07.json .. E12.json, experiments/rejected/0005-give-and-go.patch;
  docs/shifts/2026-11-24-night/lanes/K8-balance/ROUND-3.md, OWNER.md, CHECK-CARTRIDGE-NOTE.md, REPORT.txt, tables/final_*.json.
Changed: native/content/Cartridges/hockey.thirdlife.cartridge.json (take_shield_frames), hockey.thirdlife.rules.json (levels);
  lab/balance.thirdlife.baseline.json (deliberate: --update); lab/rinklab.cpp (-plankeep); lab/experiments/run.mjs (the
  dead-key arm, cell sets), LEDGER.md; docs/design/HOCKEY-BALANCE.md (sections 11, 12); STANDUP.md.
Not touched: native/thirdjam*, the shim, the glue, native/SConstruct, the pack, anything drawn, contracts/*. The patch
series is 0001-0004, byte for byte as landed in round 2.

BEHAVIOUR CHANGES
hockey.regular: none (600 of 600 hashes on both runners; 43 gym probes).
hockey.thirdlife: the take shield and the three levels' tunes. No test expectation moved; the thirdlife baseline was
rewritten on purpose.

DEVIATIONS (beyond rounds 1 and 2; ROUND-3.md section 5)
1. game.contact.take_shield_frames 30; the sidecar's levels carry three tune strings.
2. Patch 0005 was written, proven neutral with its switch off (parity, 600 of 600), measured, rejected and moved out of
   the series.
3. The lab gained -plankeep and two cell sets.
4. The reference column of the final matrix: hockey.regular's ladder at 200 seeds; its single-verb ablation at 60 seeds.
5. My worktree is hk-balance; the session's working directory moved to hk-int during the round. Every command of mine
   used hk-balance by absolute path; nothing was written in hk-int.

QUESTIONS FOR THE DIRECTOR
1. The pass: three tries rejected (E02 speed, E06 the mates' coin, E08 the give-and-go). The evidence points at the mates'
   skill with the puck (they are thirdjam's plainest bots at every level and lose half the passes that reach them), which
   is a larger piece of work in the brain's copy than this lane did. Is that the next lane's, or is T3 dropped for this cut?
2. The sidecar's levels are live now: lane K1's glue must apply them (section 5), or the exe does not play this round.
3. The owner's three questions are in OWNER.md, ready for the morning verdict.

IF THIS LANE WENT ON (the next three things)
1. The mates' hands: a far-side carry and a quicker release for the human's mates, measured by what follows a completed
   pass (lost first: 50 % today).
2. The poke's own ground (reach against the lift's range), then the single-verb verdicts again with both arms.
3. The planning hand valid on cartridges with effects and zones (clone FJamSystems with the sim), so the editor's check
   can use it on generated games.
