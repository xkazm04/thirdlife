J4-court report (night of 27 Nov 2026, 03:02-05:20). Tree d25-court, branch n27-court (fast-forwarded by the Director to 6c75354c at ~04:4x).
Full account: PROOF-J4-court.md beside this file.

OUTCOME AGAINST EACH ACCEPTANCE CRITERION
- Juice sheet (1-3 abilities) written before the first sentence: MET (03:06, top of PROOF: A1 sky dunk, A2 swat block, A3 on fire, all on F).
- Each ability first as a Create change sentence on the real job, with time, tokens, path, outcome: MET.
  A1 03:06 -> v0.1.3 at 03:51 (45 min; 3.2M tokens in, 32k out; 2 builder rounds; full route with 40 hand seeds).
  A2 03:52 -> v0.1.4 at 04:30 (38.6 min; 2.0M in, 17k out; 1 round).
  A3 04:31 -> v0.1.5 at 05:09 (38 min; 1.5M in, 13k out; 1 round; on lane T's fixed editor).
- Every refusal, bend or failure has a blocked-editor line with evidence: MET.
  1. A1 r8 refused by the old tofu bounds on shot-timing metrics the dunk does not touch (event 926); r9 passed by changing the test hand's release policy, not the game.
  2. A1 bend: the slow beat slows only the dunker; bots dunk about once a minute or never, depending on where the hand plays.
  3. A2 bend: bots only block dunks started within 3 m of the rim, so the free-throw-line dunk is never contested by a bot.
  Each was then built by hand in .tl/juice/court_hand/ (all three abilities, TL* API only).
- For every ability: a clip of 20 s or less, stills I looked at, bot uses per minute, 3600 headless frames with 0 script errors, the same hash twice: MET.
  - By hand: clips a1.mp4 11.9 s, a2.mp4 7.6 s, a3.mp4 11.6 s, each with the hand and a bot; 9 stills.
    Bots make 3-5 sky jumps a minute (mean 4.3: ~1.7 dunks, ~2.7 blocks). A bot on fire is rare (1 in 4 x 150 s).
    bot_sky 3590 frames x4: 0 errors. Seed 1 hash 67047af8... twice.
  - Editor: clips a1_editor_v013.mp4, a2_editor_v014.mp4, a3_editor_v015.mp4; stills a1/a2/a3_editor_*. 0 errors in 8990 frames.
    v0.1.5 seed 1 hash 60040a9a9b8291db twice.
- PROOF says which abilities the editor made and which were made by hand, and how each feels: MET (verdict table at the end of PROOF).
  The editor made all three. The by-hand pack makes all three too and reads far stronger to the eye.
- "landable J4-court" with the best pack path and the menu title by 07:00: MET (05:19, below).

GATES
- node devx/bin/tl.mjs check --tier fast on 6c75354c: PASS arch 12/12, assets 4/4, cards 3/3, devx.test 230/230, foreman.typecheck clean (exit 0). Also PASS on e66eb94e before the fast-forward.
- The by-hand pack (tl.sh), on 6c75354c: lint PASS, smoke 3600 frames PASS (0 errors).
- bot_sky seeds 1-3 (3590 f) ok, 0 errors.
- The pack's own tests on seed 1: bot_tofu ok, bot_first_minute ok.
  - bot_play FAILS: you Space-swat 0 times; the rivals dunk instead of shooting jumpers.
  - bot_crews FAILS: Dex sets 0 screens.
  - Seed 2: both ok. Seed 3: bot_crews fails (rotation 0).
  - I did not change these tests. The juice moves play, so these v0.1.2 player checks are no longer met on every seed.
- Editor versions: each passed the Foreman's full verification (lint, smoke, invariants, bots, 40 hand seeds) before promotion.
- No full tier: kernel, kits, rigs, style and seeds are untouched.

CHANGED FILES
- In git (docs only): docs/shifts/2026-11-27-night/lanes/J4-court/{PROOF-J4-court.md, STANDUP.md, REPORT.txt, clips/*.mp4 (6 clips, 26 MB, each 3.6-11.9 s), stills/*.jpg (14 files, 3.1 MB)}.
- Outside git (.tl, for the Director to copy):
  - .tl/juice/court_hand/ (v0.2.0): new scripts/core/sky.gd and tests/bot_sky.gd.
  - Edited there: scripts/core/game.gd, ballsim.gd, ai.gd, scripts/crews/brain.gd, scripts/main.gd, data/tuning.json (new keys sky and fire), data/clips.json (4 new pose clips), pack.json (version and test list).
  - The real job gained v0.1.3, v0.1.4 and v0.1.5 under .tl/jobs/half-court-3-v-20261125-1/promoted/.
- No foreman/, engine/ or contracts/ edits.

BEHAVIOUR CHANGES
- By hand: F is a new key.
  - With the ball: a charged sky jump; inside 4.6 m it is a dunk with a court-wide slow beat.
  - Without the ball: a sky block that rejects.
  - Two scores in a row set a player on fire until the other side scores.
  - Bots dunk, block and double the player on fire.
  - Moss's drive now often ends in a dunk: 7 dunks and 5 rejections in 150 s on seed 4. It may feel one-note; unmeasured beyond these runs.
- Editor (v0.1.3-0.1.5): F dunk, F sky block, on fire. Its builder also changed tests/support/hand.gd in r9 (it now cycles four release timings).

FOR THE OWNER TO LOOK AT
- Look first at clips/a1.mp4, a2.mp4 and a3.mp4 (by hand).
- Then clips/a1_editor_v013.mp4, a2_editor_v014.mp4 and a3_editor_v015.mp4 (editor). Same camera; compare how each reads.
- Play the by-hand pack:
  - F with the ball near the free-throw line: a dunk.
  - F while a rival crouches: a block.
  - Score twice in a row: on fire.

QUESTIONS FOR THE DIRECTOR
1. Menu rows: best = .tl/juice/court_hand/ as "Half-court 3 v 3: Sky Jam (juice by hand)". Optional second row: the editor's promoted/game.half_court_3_v@0.1.5 as "Half-court 3 v 3: Sky Jam (editor)".
2. For lane T, the editor findings:
   (a) The tofu gate measured shot-timing figures through the test's hand, and a builder passed it by changing that hand (A1 r9).
   (b) The editor puts every banner into the score-line text. In v0.1.5 "ON FIRE: CRANE" overlaps the clock.
   (c) "No global time scale": a court-wide slow beat is possible with TLHit.impact(body, null, 1) on every body, two frames of three. A kernel time-scale helper would let builders do it.
   (d) The editor borrowed clips for every new verb because clips.json belongs to another package.

NEXT THREE THINGS THIS LANE WOULD DO
1. Send the editor a fourth sentence to close the bends: "bots block dunks from the free-throw line too; bots dunk when they beat their man; slow the whole court at the rim; put DUNK/REJECTED/ON FIRE in big letters mid-screen". Judge v0.1.6 against the by-hand pack.
2. In the by-hand pack: restore the seed-1 player checks (a bot_play swat and Dex's screens) without loosening them; tune Moss's dunk share down if a person finds it one-note; give the fire its own banner after the dunk word.
3. Have a person play both with the hands of TLHand (newcomer, regular) and read the ladder (tl ladder) before calling either balanced.
