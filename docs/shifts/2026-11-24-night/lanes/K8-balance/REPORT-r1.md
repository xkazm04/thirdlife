K8 balance: report, round 1 (23 Nov 2026, 21:00-23:00; closed on resume, 24 Nov 21:05). Landable round 1.

RESUME NOTE (24 Nov 20:50). The lane stopped on a usage limit at about 23:00 on 23 Nov, with every experiment of the round
finished and the closing gate chain running (it ended by itself at 22:59, all PASS). The Opus stand-in left NOTHING in
this tree: no file in the worktree (.tl included) is newer than 23 Nov 22:59 and git status shows only this lane's files,
so there was nothing of its to keep or discard. On resume: the whole gate chain was run again on the unchanged tree (the
lines under GATES are that run), the one untraced figure of E01b was traced, one wrong cell of the design doc's target
table was corrected (T3, planning hand without the pass on hockey.regular: +8 points, not -3).

Nobody has played hockey.thirdlife. Every figure is a hand's (thirdjam's scripted playtester, or this lane's planning
hand), never a person's. Nothing here says the game is fun.

IN SHORT
The design is written (docs/design/HOCKEY-BALANCE.md), the planning hand is built and believed for stated reasons, the
thirdlife variant builds from patches on a copy and is proven equal to thirdjam with every switch off, the ledger runs,
and three experiments are in it. hockey.thirdlife today is thirdjam with ONE rule changed: a goal must leave a blade (the
walk-in goal is gone). The first try at the pass (a faster tap for everyone) completed more passes and broke the ladder,
so it was rejected: the pass is still unrepaired.

What the owner would feel in the first minute (one line per kept change):
- E01b: a breakaway now ends with a press. Glide the puck at the net and it stops on the goal line and lies there; tap
  shoot (a tap is enough) and it is in. The opponents cannot walk it in on you either.

OUTCOME AGAINST THE ACCEPTANCE

1. HOCKEY-BALANCE.md exists; every later change cites its target; rulings quoted: MET.
   Fantasy, six pillars (each with the owner's words by R number, a proven game, a measured fault, what it rules out), the
   tempo frame (no skater or shot speed moves; five ratios may), the target matrix for all 19 verbs, targets T1-T10 with
   thirdjam's figure by both kinds of hand, five cuts decided before any number (the brake key, the ability key, the
   saucer as a verb of its own, the walk-in goal, the take with no key), three questions for the owner. E01, E01b and E02
   each name their pillar, targets and tempo ratio in the ledger.

2. The planning hand rediscovers at least three of PLAY.md's findings on hockey.regular unprompted: MET (six, and two more
   by ablation), with three contradictions reported.
   The hand: engine/cores/rink/lab/lab_plan.{h,cpp}; rinklab match ... -plan=novice|regular|good. No script: every third of
   a second it rolls the real simulation forward under up to eighteen plain intents and plays the best. It never reads the
   bots' brain. Limits: sees 300 / 233 / 167 ms late, decides every 0.5 / 0.33 / 0.2 s, misjudges by up to 0.15 / 0.08 /
   0.04 goals, aims 10 / 5 / 2 degrees off, 3 / 5 / 8 presses a second. Calibrated on ONE number (regular at pro: 77 %
   against thirdjam's regular hand's 75.5 %). Its copies of the sim are exact: -plancheck, 0 of 10,847 frames of hockey.regular and 0 of
   25,383 frames of hockey.thirdlife (4 pro matches) hashed differently from the match.
   Found unprompted, regular setting at pro, 100 seeds (tables/plan_ladder.hockey.regular.seeds1-100.json):
     - the walk-in goal: 0.33 of its 2.27 goals a match (PLAY: 0.54 of 2.02);
     - the take with no key: 4.4 a minute of its 8.3 takes off a carrier (PLAY: gym, 20 of 20);
     - the puck never settles: a carry 0.68 s, 38 % of carries lost to an opponent (PLAY: 0.82 s, 39 %);
     - time on the ice: 4.0 knockdowns and 8.0 s a match (PLAY: 5.6 and 11.2 s);
     - the one-timer that never comes: 0.22 a match (PLAY: 0.1-0.3);
     - rookie won by anybody: 99 / 100 / 100 % (PLAY: 97.5 / 100 / 100).
   By its own ablation (60 seeds, paired with its full hand; tables/plan_ablation.hockey.regular.pro.seeds1-60.json):
     - the pass does not pay: without it +8.3 points of wins (+-6.8; PLAY: +9);
     - dead keys: deke, spin, one-timer, poke, body check each inside +-5 points; and two keys COST the hand that presses
       them: the tap shot (+11.7 without it, +-5.4) and the brace (+13.3, +-5.6).
   Contradictions (so these were the script's, not the game's):
     - "at pro skill stops showing above the regular hand": its three settings win 55 / 77 / 97 % at pro and 29 / 69 / 77 %
       at all-star (thirdjam's hands: 24.5 / 75.5 / 76 and 10.5 / 39.5 / 53.5);
     - "38 % of passes complete": it completes 58 % at the same rate of passing (5.3 a minute);
     - "the sprint and the stop carry the game" (-12, -13 for the script): the planning hand loses nothing measurable
       without either (-1.7 +-8): a hand that re-plans goes round a missing verb.
   Why it cannot be believed further: it keeps pressing two keys that cost it and keeps passing (it does not learn); at 60
   seeds a verb worth less than about 15 points is invisible; it moves like a stick, not like eight keys; it cannot signal.

3. Every kept change has its ledger entry with before / after tables by both kinds of hand; rejected ones too: MET.
   engine/cores/rink/lab/experiments/LEDGER.md (generated from E01.json, E01b.json, E02.json), 60 seeds a cell, 14-16 cells
   an experiment, every paired difference with its standard error.
     E01  REJECTED  the goal line closed while the puck rides with its carrier: leaked (walked goals halved, not gone).
     E01b KEPT      the goal line closed to a held puck (held until shot, passed, or touched by another). T1: 0 goals
                    without a release in every full-hand cell, both sides (before: 18 % of thirdjam's regular hand's
                    side's goals at pro). T2: without any shot thirdjam's hand loses 35 points of wins at pro and the
                    planning hand 58 (before: 8 and 8). Price: thirdjam's regular hand, which cannot re-plan, 75 -> 63.3 %
                    at pro (-11.7, 2.4 standard errors); the planning hand 76.7 -> 85 % (+8.3 +-6.0). Matches 5-10 %
                    longer. Still dead after it: the deke. In thirdjam's hand's no-shot cell 3 of 226 goals were an opposing
                    defender's stick knocking the puck off the goal line into his own net (traced): by the rule, not
                    a leak.
     E02  REJECTED  game.pass.power.arrive_mps 8 -> 12.5 (a 15 m tap in 45 frames instead of 63). Passes completed
                    36.8 -> 56.2 % (thirdjam's hand) and 56.7 -> 64.6 % (planning hand), but every bot passes faster too:
                    all-star 38.3 -> 6.7 % and 66.7 -> 26.7 %, the planning novice at pro -26.7, and without the pass the
                    planning hand still won more (83.3 against 71.7 %). A target it did not aim at broke (T8).

4. The final matrix on hockey.thirdlife: NOT DUE (round 3). Where the targets stand: T1 met, T2 met, T3 not met (passes
   37 % and 57 %; without the pass thirdjam's hand wins 23 points more), T4-T7 and T9 untouched, T8 moved by E01b (above),
   T10 held.

5. rink.sh balance still reproduces the hockey.regular baseline exactly: MET.
   PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (201 s)   [24 Nov]
   Run five times in the round (after each rebuild of the lab and on resume): PASS each time; the parity run five times too. git status shows nothing under
   native/thirdjam, native/thirdjam-t5, the shim, the glue, native/src or contracts/.

6. node devx/bin/tl.mjs check --tier fast passes: MET (exit 0, 5 of 5 steps).

GATES
All from the run of 24 Nov 20:52-21:03 on the unchanged tree:
PASS  rink lab-build: engine/cores/rink/lab/bin/rinklab.exe
PASS  thirdlife tree: 2 patches applied to a copy of native/thirdjam (3 files differ)   [from scratch]
PASS  rink lab-build-thirdlife: engine/cores/rink/lab/bin/rinklab-thirdlife.exe
PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (201 s)
      rink.sh balance: the reference runner, hockey.regular, K4's baseline
PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (177 s)
      rink.sh balance-thirdlife --parity: the PATCHED tree, hockey.regular, K4's baseline: every switch off = thirdjam
PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (226 s)
      rink.sh balance-thirdlife: hockey.thirdlife against its own baseline (lab/balance.thirdlife.baseline.json). Beside
      the reference's: 43 of 43 gym probes identical (the tempo map did not move), 0 of 12 cells with equal hashes (the
      rule is live in every match); thirdjam's regular hand at pro 76 -> 64 %, without shots 68 -> 30 % (50 seeds).
PASS  arch            [12/12] 12 rules (+0 vs last green)
PASS  assets          [4/4] 4 checks passed (+0 vs last green)
PASS  cards           [3/3] 5 cards, schema ok (+0 vs last green)
PASS  devx.test       [229/229] 229 pass, 0 fail across 17 files (+0 vs last green)
PASS  foreman.typecheck  tsc --noEmit clean
      node devx/bin/tl.mjs check --tier fast: exit 0. (First run of the round: NOT RUN, exit 2, foreman/node_modules
      missing in the new worktree; npm ci in foreman/, then PASS.)
-plancheck: 0 mismatches (figures under acceptance 2).
No full tier (the Director runs it). Rule 3 of the campaign (frames beside the reference's) does not apply: this lane
draws nothing.

CHANGED FILES
New:
  docs/design/HOCKEY-BALANCE.md
  engine/cores/rink/lab/lab_plan.h, lab_plan.cpp                the planning hand
  engine/cores/rink/lab/lab_rules.h, lab_rules.cpp              the rules sidecar reader (lab's)
  engine/cores/rink/lab/thirdlife-tree.sh                       native/thirdjam + patches -> .tl/rink-thirdlife/src
  engine/cores/rink/lab/experiments/run.mjs, E01.json, E01b.json, E02.json, LEDGER.md
  engine/cores/rink/lab/balance.thirdlife.baseline.json         hockey.thirdlife's own change detector
  engine/cores/rink/native/patches-thirdlife/0001-tl-rules-block.patch, 0002-net-carry-wall.patch
  engine/cores/rink/native/content/Cartridges/hockey.thirdlife.cartridge.json, hockey.thirdlife.rules.json
  docs/shifts/2026-11-24-night/lanes/K8-balance/STANDUP.md, ROUND-1.md, REPORT.txt, tables/*.json
Changed (K4's lab; additions, the default path unchanged):
  engine/cores/rink/lab/SConstruct (variant=thirdlife, two new sources), rinklab.cpp (-plan, -plancheck, -tl, -tune,
  -debuggoals), lab_filter.h/.cpp (the planning hand's seat; read-only counters: goals by how they crossed the line, takes
  with and without a key), lab_gym.h/.cpp (reads the sidecar), cells.mjs (planning-hand cells, cfg for runner / content /
  cartridge, five more figures), balance.mjs (--exe, --cartridge, --baseline), engine/tools/rink.sh (the block
  lab-build-thirdlife / lab-thirdlife / balance-thirdlife, before the *) arm as K4's is).
Not touched: native/thirdjam*, the shim, the glue, native/SConstruct, the pack, anything drawn, contracts/*.

BEHAVIOUR CHANGES
hockey.regular: none (600 of 600 hashes on both runners).
hockey.thirdlife (new; not wired into the shipped core): a puck that rides with a skater, or that he has held and not
shot or passed, cannot cross either goal line; a shot, a pass, a deflection, a rebound and a puck off a defender score as
before.
No test expectation moved.

DEVIATIONS (campaign rule 1)
1. hockey.thirdlife's rule net_carry_wall (patch 0002): deliberate, ledger E01b. thirdjam itself has this rule for the
   defending side at its own net (game.puck.net.own_wall, JamSim.cpp OwnNetWall); the patch extends it.
2. The patched tree adds FJamGameConfig::Tl (the switches) and FJamPuckState::TlHeldBy (hashed only while its switch is
   on) to a COPY of thirdjam; native/thirdjam is byte for byte.
3. The planning hand is not thirdjam's instrument; its sim copies have rule hooks, zones and effects unbound (neither
   cartridge has any; -plancheck); it moves with a free direction, never signals, and was calibrated once.
4. The rules sidecar <cartridge>.rules.json is a file thirdjam does not have (thirdjam's schema is embedded in its source
   and rejects unknown keys).
5. Screens are 60 seeds a cell (PLAY: 200).
6. K4's observer and scripts gained counters and options (listed above); with none given they are K4's.
7. foreman/node_modules installed in this worktree by npm ci (git-ignored) so the fast gate could run: it was NOT RUN
   (exit 2) before that.
8. Five lab files are CRLF in the index; my first edits wrote them LF (whole-file diffs); restored to CRLF, the diff is
   189 lines added, 25 removed across the nine changed files.

HOW THE SHIPPED CORE COULD SELECT THE VARIANT (proposal; lane K1 owns native/ and the build)
- Build ONE core from the patched tree. With every switch off it is thirdjam: this lane's proof is 600 of 600 match
  hashes and 43 gym probes (rink.sh balance-thirdlife --parity); K1's stronger proof (the 611,543-line trace compare
  against the Unreal build) should be re-run on the patched tree before it replaces the plain one.
- The glue, where it loads <name>.cartridge.json, looks for <name>.rules.json beside it: for each key under "rules" it
  calls the patches' own TlSetRule(Cart->Game.Tl, key, value) (false = unknown key = an error) before the sim is built;
  for the level it appends "levels"[level] to the resolved AI params through thirdjam's ApplyDifficultyTune. No sidecar =
  thirdjam. The lab's reader is 100 lines (lab_rules.cpp) and can be lifted.
- Not done here: nothing under native/ but the patch files and the two cartridge files was written.

FOR THE OWNER TO LOOK AT
Nothing can be played yet (the variant is a lab build). To read: docs/design/HOCKEY-BALANCE.md sections 1-3 (the fantasy
and the pillars), 8 (the cuts), 10 (three questions), 12 (where it stands). To see a match's goals as lines:
  bash engine/tools/rink.sh lab-thirdlife match -cartridge=hockey.thirdlife -seeds=1-1 -difficulty=pro -plan=regular -debuggoals

QUESTIONS FOR THE DIRECTOR
1. The owner's three (HOCKEY-BALANCE.md section 10): massacre or event at all-star (R-0041 against R-0049); should a
   breakaway end with a press; is pro the level he judged.
2. Which hand sets the ladder? E01b costs thirdjam's scripted regular hand 11.7 points at pro because it skates at the
   line by habit, and gains the planning hand 8. R-0060 says both columns are reported and the owner says which player he
   is; R-0047 says the ladder was "fine for me". Round 3 will hold thirdjam's hand's pro figure unless told otherwise.
3. The pass in a one-skater game: NHL '94 makes the pass pay by moving the player to the receiver; the owner bound the
   camera to one skater (R-0038). This lane will work on the mates instead (what they do with a pass, how often it comes
   back). If control switching is wanted, it is a camera and controls question for K3 and for him.
4. Two-file cartridges (cartridge + rules sidecar) and the patch series are new shapes: contract wording is the
   Director's. Should hockey.thirdlife.cartridge.json live in native/content beside thirdjam's own files (as the brief
   says), or in a folder of ours?
5. Cut keys (brake, ability) and a cue when the puck stops on the goal line are the shell's (K3). No technical drawing
   (R-0069, R-0070): a sound, or the figure. Not this lane's to build.
6. Compute: a screen is about 6 minutes of 8 processes an arm; the round-3 matrix at 200 seeds is about an hour.
7. Raw output: deleted, except one arm kept on purpose under .tl/k8/arms/10d81b3280af (hockey.thirdlife as it stands,
   16 cells x 60 seeds, 7 MB): it is round 2's "before" and saves a re-run. Delete it if the tree is cleaned.

THE NEXT THREE THINGS (round 2)
1. The take with no key (P1, T5): the gym shows it 20 of 21 head on; the cause looks like the bodies' bounce throwing the
   carrier's velocity so the puck stops riding with him (JamSim.cpp CollideSkaters, RidingCarrier's 4 m/s). One patch,
   gym first, then the ledger.
2. The carry and the hits (T4, T6): knockdown seconds (a cartridge number), the poke from the front, the sprint that
   outlives its bar; then the keys that cost their user (tap shot, brace): repair or cut.
3. The pass again, by the right doors: the human's own tap alone, then what the mates do with a pass; the bots' read of
   a pass goes to the level table (round 3).
