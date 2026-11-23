H2 bots: hockey behaviour teardown, the bots and the sandbox. Shift 2026-11-23-day. Opus solo, research only.
Deliverable: docs/research/hockey-teardown/BEHAVIOUR-BOTS.md (round 1 landed 2e33922; round 2 in this tree).

OUTCOME AGAINST ACCEPTANCE
- Every row has two measured numbers or says plainly why not: met. thirdjam's all-AI cells have no pass or shot-distance
  counts (its commandlet does not report them): those cells say n/a and the text says why. Section 4's targets are
  thirdjam's measured figures moved to our box, marked as targets, not measurements.
- Aggressivity and ability per level for both games: met (rookie / pro / all-star; all-AI, newcomer/novice and regular hands;
  20 seeds a cell; thirdjam's pokes and cross-checks by side from 3 rendered matches a level).
- The sandbox names, for each game, the exact files to touch to add one toy, and ranks 8-12 toys: met (3.1, 3.2: file:line
  lists; 3.4: 11 toys ranked, first three named).
- Section 4 gives numbers and rules a builder could apply without asking: met (18 lines, each with file/key, present value,
  target or replacement, type data / pack code, and the figure it moves now -> target; 4.2 the rules to delete with risks;
  [m] marks what H1's scale or speed change would need re-derived).
- Nothing under engine/, foreman/, contracts/ or devx/ changed: met (only the ignored foreman/node_modules from npm ci, so
  foreman.typecheck runs). tl check --tier fast passes.

GATES
- node devx/bin/tl.mjs check --tier fast (10:26): PASS arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck.

CHANGED FILES (this tree)
- docs/research/hockey-teardown/BEHAVIOUR-BOTS.md (sections 0 rewritten for both rounds, 3, 4, 5 added)
- docs/shifts/2026-11-23-day/lanes/H2-bots/STANDUP.md, REPORT.txt
- (round 1, landed) media/bots_aggr.jpg, media/bots_play.jpg, probes/bots_* (13 instruments)

FINDINGS (short)
- Our bots press and hit as much as thirdjam's; the difference is a pile (4+ within 5 m 15-18 % vs 6-11 %), short safe
  passes (86-94 % vs 48-60 %), one-touch ping-pong (62 %), mates who never shoot (0-0.3 vs 0.8-1.1 a minute), standing
  bots, no sprint, and a level ladder made of slowness instead of clumsiness. Most trace to rules written for a bot metric
  or the idle-hand ladder.
- Sandbox: thirdjam's data-only effect layer ("x multiply + add" on speed, mass, reach, puck, ice) makes a new boost one
  JSON; ours needs about eight files of code per toy kind and cannot touch friction. Neither AI understands toys; ours gives
  toys to bots through abilities.gd, outside the hockey brain.
- First three toys: the stat layer with rocket skates as its first item; sumo pads (mass); glue blade (sticky puck).

WHAT THE OWNER SHOULD LOOK AT
- media/bots_aggr.jpg and media/bots_play.jpg (one frame a second, thirdjam above, ours below, both at pro with each game's
  own hand): the knot round the puck is visible in every frame of ours.
- Section 0 and section 4.1 lines 1-5.

QUESTIONS FOR THE DIRECTOR
1. The sandbox's stat layer (3.3.1) is kernel work and wants an item schema in contracts/: who owns it, and is a "modifier
   stack on TLBiped / TLBall" the right shape?
2. Section 4 line 1 reverses N3's decision (keep-off rules reverted for red's hit rate, 4fcdf37). The owner's earlier
   ruling was "keep the body-check rate": confirm the pile matters more, or keep hits and accept line 1's trade.
3. Lane H1 may change body scale or speeds: section 4's [m] numbers must then be re-derived; better to land H1's box first.

NEXT THREE THINGS THIS LANE WOULD DO
1. Apply section 4's seven data lines in a pack copy and re-run the nine cells (about 20 minutes) to show which figures move.
2. Add a speed counter to the probe (share of time above half top speed, thirdjam's own measure) and measure both games.
3. Film the pile before and after lines 1-2 in a window, as a person meets it.

DISK
- Freed: the thirdjam runtime copy (1.2 GB), its per-frame traces (about 1.3 GB), clip AVIs. Kept summaries. C: 34 GB free.
