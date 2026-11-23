H2 build 1: the behaviour sheet (BEHAVIOUR-BOTS.md section 4) built into the house hockey, worktree d23-bots, branch
d23-bots (from main f1659f1). Stays on a branch until the owner says so. Nobody has played it with a hand.

OUTCOME AGAINST THE BUILD ORDER
1. Section 4.1, all 18 lines, and 4.2's deletions: built (BUILD.md "What was built": line -> file). Deleted: the mates'
   shooting ban (assisted(), assist_frames), the 8 m hold and the turn-away at their net, feed_bonus, the back-pass and
   corner own-goal guard, the single 60-frame stick grace (now by level 60 / 6 / 0). The idle hand's guard is the feed by
   level (0.6 / 0.4 / 0.2), not benched mates.
2. Proof: the probe re-run, 20 seeds a cell, nine cells, before / after / thirdjam table in BUILD.md; window clip
   bots_after_pro_regular_s1.mp4 (22 s) and bots_before_after_pro.jpg in the lane folder. Lines that did not reach their
   target are listed in BUILD.md "Not reached" (spread, pinned end, feed count, all-star shots, completion, poke ladder,
   all-star forecheck, idle 0.0-0.1, speed and sprint unmeasured).
3. Tests: two expectations moved, each with its line (bot_own_net: line 10; bot_modes CAP 9000 -> 18600, the rules' own
   300 s end: lines 1-14). Two failures were fixed in the game instead (bot_hockey_ai, bot_reach). Ladder figures
   reported, not tuned back; no ladder bound is a win share, so none changed.

KEY FIGURES (before -> after; thirdjam)
- Two of one side within 5 m of the puck: blue 30-38 % -> 15-21 %, red 24-30 % -> 14-28 % (15-22 %).
- Four or more within 5 m of the puck: 15-18 % -> 5-8 % (6-11 %).
- The human's mates' shots a minute: 0.0-0.3 -> 0.6-1.1 (0.8-1.1).
- Same-frame re-pass (rookie all-AI): 62 % -> 0 %. Passes completed over 6 m: 14-24 % -> 45-55 %.
- Standing 2 s+: 0.1-1.1 -> 0.0-0.1 a minute. Puck loose 29-39 % -> 38-51 % (51-68 %).
- Forecheck two or more (regular hand): 91 / 95 / 98 % -> 55 / 73 / 75 % (65 / 77 / 84).
- Hit rate (asked): checks + cross-checks tried a minute 3.8 / 9.4 / 10 -> 3.6 / 10 / 11 (4.5 / 11 / 11); rookie
  cross-checks 0.8-1.3 -> 0.
- Wins of 20, regular hand: 19 / 11 / 6 -> 18 / 13 / 5; newcomer 16 / 6 / 0 -> 16 / 8 / 4.

GATES
- tl check --tier fast (11:50): PASS arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck.
- tl check --tier full --only packs (12:05): FAIL, verb runs 128 of 129: every hockey bot (56), lint, smoke, duel and
  parkour passed; hockey invariants failed only invariants.many_budget (frame p50 1.419 ms, budget 1.0). Same minute,
  same machine (CPU 94-100 % from other sessions): main's pack 1.376 / 1.384 ms, the build 1.386 / 1.426 ms (about +3 %).
  The check already failed on the night's integration tree n23-int (1.265 ms) and others; last pass in the logs
  n22-int (0.979 ms, 22 Nov). Not loosened. Needs a quiet machine and the Director's call.

CHANGED FILES
engine/packs/hockey/scripts/ai/brain.gd, carrier.gd, roles.gd; data/ai.json; data/levels/rookie.json, pro.json,
allstar.json; tests/bot_own_net.gd, tests/bot_modes.gd; README.md (the AI paragraphs, "Your mates set you up");
docs/shifts/2026-11-23-day/lanes/H2-bots/BUILD.md, STANDUP.md, REPORT.txt, bots_after_pro_regular_s1.mp4,
bots_before_after_pro.jpg.

FOR H1 / THE DIRECTOR
- If H1's route A scales hit speed thresholds by 0.727, the bots' closing speeds in data/levels/*.json (6 / 2 / 2,
  cross 99 / 1.0 / 0.25) and ai.json (check_min_closing_blue 8, cross_min_closing 1.5) should scale the same way.
- Bots now sprint through skate.pace; the poke ladder and pass completion are limited by poke.gd's odds and carry.gd's
  catch (H1's files).
- Merge note: H1 edits other files of the same pack; this lane touched only the files above (README overlap possible).

WHAT THE OWNER SHOULD LOOK AT
- Play pro this evening; watch for the knot round the puck (smaller), mates going to the net and shooting, rookie at
  full pace. bots_before_after_pro.jpg shows the same seed before and after.

NEXT THREE
1. A speed / sprint counter in the probe (lines 6, 16 are unmeasured).
2. All-star's shot count and the poke ladder (lines 7, 11), with H1's poke odds.
3. Read the ladder through the owner's own hand after tonight, not through TLHand.
