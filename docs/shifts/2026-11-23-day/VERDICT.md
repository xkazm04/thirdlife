# Day of 23 Nov 2026: verdict (the hockey teardown repeated on behaviour, and built)

**The owner, ~09:10** (verbatim in PLAN.md): the first teardown was the visual side; "the core of gameplay design is in
behavior ... Please do repeat it". Person gate: yes. Design lines: labelled. Robot soccer once hockey shows we can design.

## On main (pushed)
- **H3 person gate** (624fb73; JOB.md a9f7477): a run-through job always waits for a person after its first (greybox)
  phase. foreman 325 tests, 0 fail (re-run by the Director). Open: a plan without phases has no person stop.
- **H1 hand teardown** (5d07c50, f1659f1): `docs/research/hockey-teardown/BEHAVIOUR-HAND.md`: movement, hits, stick and
  puck as measured step responses and frame timelines in both games; a behaviour sheet (19 shared rows, routes A and B).
- **H2 bots teardown** (2e33922, 22f9aa4): `BEHAVIOUR-BOTS.md`: aggressivity and play per level in both games, the
  sandbox (seams, 11 toys ranked), an 18-line behaviour sheet and the bot-metric rules to delete.
- **METHOD 8a** (6106c56): behaviour first, the measured sheet. The editor's prompts do not enforce it yet.

## On branch `d23-hockey` (7c7c996; NOT on main: the owner's word lands it)
The hockey behaviour pass: H1's rows S1-S17 with route A (our body and rink), H2's 18 bot lines, then the combination
(hit thresholds in route A's scale; the bots' stick as a ladder by level). Tables before / after / thirdjam:
`lanes/H1-hand/BUILD.md`, `lanes/H2-bots/BUILD.md`, `lanes/H2-bots/INTEGRATION.md` (on the branch).
- **Gates on the branch:** fast tier PASS; hockey's 56 bot tests pass; world 8/8 = alone; export built and
  `export.sh check` PASS. **FAIL: hockey `invariants.many_budget`** 1.31 ms against 1.0 on a busy machine (main's pack
  1.07 ms back to back; the branch is 7-16 % slower, mostly the hand build). Not read quietly; not loosened.
- **Missed targets:** pass completion 83-93 % (target 60-75 %); the mates' shots at pro / all-star 0.41 / 0.36 a
  minute; side spread 7.1-8.8 m (9); all-star harder (regular hand 19 / 10 / 1 wins of 20); body widths a second
  unchanged by route A (5.2 against thirdjam's 15.8).
- **Open bug:** a skater re-placed right after a hit stands 0.2-0.35 m off his mark (cause not found).
- **The exe:** `.claude/worktrees/n23-int/dist/PLAY-LATEST.cmd` (build 7c7c996). Start at rookie.
- No person has played it. Every figure is a scripted hand or bots alone.

## Your answers
1. After playing: does the branch go to main, and what are the three worst things you felt?
2. Body size: keep our body and rink (built), or life-size bodies on a 90 x 45 m rink with thirdjam's numbers (breaks
   the arena art, the camera, the bots' distances, about fifteen tests)?
3. The sandbox: the first three toys proposed are a stat layer with rocket skates (engine work, an item contract),
   sumo pads, a glue blade. Build order, or not yet?

## Route scoreboard
Opus solo, research then build by the same agent (H1, H2): held; the agent that measured built from its own sheet and
proved it with its own probes. One round-1 figure (the puck "glued", 24.8 against 0.3) was a trace artifact, found and
corrected by the lane while building.

## Next
The owner's hand on the exe; then his worst three; a quiet reading of the frame budget before any landing.
