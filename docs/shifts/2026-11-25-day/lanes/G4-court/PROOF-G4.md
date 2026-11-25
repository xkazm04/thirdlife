# G4 proof: Half-court 3 v 3 from scratch through the editor (day of 25 Nov 2026)

Tree `.claude/worktrees/d25-court` (branch d25-court, at 39d3f7b until the Director's fast-forward). Jobs root
`.tl/jobs/`. Every step went through `engine/ui/foreman_run.mjs` in the command order of `engine/ui/foreman_door.gd`
(Create's door) with the flags of `engine/ui/flags/real.json` (claude-cli, sonnet, --max-packages 4, --round-limit 4,
--parallel 2, tokens_per_hour 4000000). Billing: subscription (claude.ai max); token figures are what the ledger counts.
Times are wall clock (CET). Raw PNGs stay in `.tl/g4/` and the job's `captures/`; JPGs beside this file in `stills/`.

How I looked: `tl.sh capture --cam=play|side --hud=on --test=tests/bot_play.gd --strip=16x60 --frame=600` (16 frames a
second apart, 10 s to 25 s of a match) and one full still at frame 1800, in a window, on a snapshot of the job's
`pack/`. hokej beside it: E5's `hokej_strip.jpg` (night of 24-25 Nov). The target: the night's
`concepts/half_court_concept.jpg` and `half_court_screenshot.jpg`.

## The sentence and the cards

12:40, typed in Create: "Half-court 3 v 3 street basketball under old brick viaduct arches in autumn: dribble, arc
your shots at one hoop, block shots and set screens for your teammates". Standard creativity, no run-through
(Create's defaults).

Design: 13 min, 7 generate calls (concept, designer x4, review x2; the review said `revise` twice: hook 0.61-0.65,
fit 0.47-0.55), 341k in / 104k out. It chose candidate 1 of 5 ("You run the half-court with two mates", likelihood
0.85): what I asked for. Pitch: "Run street ball: dribble, screen mates free, arc jumpers, swat shots under autumn
arches." Seven cards: Set Screens, The Spring (twist: +25 % speed after a screen), Arc And Swat, Quarry Crew (named
rivals with tells), See The Swat (a camera that swings 45 degrees on shots), Autumn Arches, Race To 21 (FIBA 3x3).
The rules text is long and specific (13 new animation clips, frame data for every verb, a teaching first minute).

What I did as a person (12:54): dropped The Spring ("I just want plain street ball, no speed boost off screens");
kept the camera with "keep the camera steady behind me like a TV game, no swinging"; kept the arches with "like my
picture: tall brick viaduct arches behind the hoop, yellow autumn trees, a chain fence, blue court with an orange key;
yellow team against plum team". Build.

## Plan and phase 1 (tofu)

Plan (3.5 min, card.team_possession, the hockey pack as template): 4 packages, 3 phases.
| package | phase | scope |
|---|---|---|
| court_core | 1 tofu | main.gd, scripts/core/**, tuning, venue, 4 tests |
| bodies_first_minute | 1 tofu | 13 own clips, builds, teaching first minute |
| crews_stakes | 2 crews | Dex and Moss (3 v 3), rivals' tells, tiers, comeback |
| viaduct_art | 3 viaduct | the arches, trees, fence, blue court, orange key |

So the game is 2 v 2 until phase 2 and has no look of my picture until phase 3.

What happened (12:57 to 14:48, 111 min of running):
- court_core, 4 rounds, 4.7M tokens in, then **failed**:
  - r1 lost to `invariants.many_budget`: frame p50 1.048 ms against 1.0 on a machine at 60-65 % CPU;
  - r2 and r3 failed its own `bot_tofu` bounds;
  - r4 failed only `possession_median_f` 234 against a bound of 240 frames.
- Replan (1.7 min): court_exchange, a fresh builder from scratch with the same contract plus a POSSESSION paragraph.
  - r1 failed lint.
  - r2 promoted. Its own `bot_tofu` said ok while `pressure_waves` was 0 (wants >= 2) and `scrum_share` 0.453 (limit
    0.3). The builder wrote it plainly: "`bot_tofu`'s ok only requires one match and 3 verbs used; it does not enforce
    the metric bounds". The route trusted the test's ok.
- bodies_first_minute: r1 lost to `many_budget` again (p50 1.097 ms); r2 promoted.
- The critic at blockout said NOT ok (silhouette 0.45, readability 0.3, fun_promise 0.1, feel 0.05, slop 0). Its
  reading is right: bodies merge, a screen is "a pile of two to four bodies sliding into each other", there is no
  hit-stop, and the rivals are recoloured.
  - It also listed "70 house contact rows your pack does not have": hockey's `hits.board_bonus`, `hits.check_cone_deg`
    and so on, held against a basketball pack.
  - Revise round 1: thrown away by `many_budget` (the third clock loss).
  - Revise round 2: thrown away because the pack's `bot_tofu` failed after the merge.
- 14:48: **paused: quality** (milestone blockout still NOT ok after revise round 2). In all, 128 min of wall time,
  16.0M tokens in (14.1M cache reads), 442k out, weighted 3.77M.

What a person sees at the hold (`stills/hold1_play_strip.jpg`, `hold1_side_strip.jpg`, `hold1_play_f1800.jpg`,
`compare_hold1.jpg` = target | hokej | this):
- Yellow against plum (my note was obeyed), on a plum slab of a court in orange dirt and pine forest. The hoop stands
  at the baseline. The arc is dashed chalk.
- 2 v 2, four figures with the same toy-kid body and backpack: you tell them apart by jacket colour only.
- The camera does not stay steady: it turns with the player, so the court spins between seconds, which is what I asked
  it not to do. The side camera is a low sideline view with the court half out of frame.
- The ball is a small orange disc. It rolls off the court onto the dirt and play goes on; I saw no out of bounds.
- Bodies bunch into knots near the ball. I can read no screen and no block. Shots go up, but I cannot see makes from
  misses.
- Score after 24 s: 2 to 1.
- Would I play again? No. It is a ball and four kids walking into each other, and the view keeps turning.

Gap to the target, in three lines:
1. No 3 v 3 and no team play: bodies pile up, and a screen or a block does not read.
2. The camera turns. The target is a steady broadcast three-quarter view looking at the hoop.
3. No viaduct arches, trees, fence or blue court with an orange key (that is phase 3).

## The quality card and phase 1's verdict

15:04, on Create's quality card I chose "play it as it is" (`quality accept`, then `resume`: 1 s). The job then
stopped at the phase 1 (tofu) verdict. I waited 15:05-15:47 for the Director's fast-forward (d82e96c, foreman
rebuilt: the H1, H1b, H1c and H2 editor fixes). At 15:48 I passed phase 1: a person would, since 3 v 3 and the look
are still to come.

## Phase 2 (crews: 3 v 3): stopped on the frame budget

From 15:48 to 16:47, crews_stakes ran 5 builder rounds (8.9M tokens in). None merged. Every round failed one check:
`invariants.many_budget`, frame p50 at most 1.0 ms.
- Measured: 1.18 to 1.52 ms with six figures.
- The builder measured 1.15 ms with the package left out (four figures on the merged core). So the pack already ran
  over the budget before phase 2 began.
- H1b's machine-busy wait worked as designed: it waited twice, then saw "machine not shown busy" and failed the round
  for real.

What a person met in Create, in order:
1. A question at 16:07: "should the Foreman assign a performance fix to the core and bodies packages (per-figure
   update cost), or change the budget for this six-actor game?" I answered in words: "Six players is the game, keep
   all six. Make it run fast enough: fix the per-figure cost in the core and the bodies."
2. At 16:12 the builder asked to widen its scope to `scripts/core/**`, `scripts/main.gd` and `scripts/bodies/**`. I
   pressed Create's chip "Yes, let it".
   - The chip sent a change request whose only words were "Yes, let it change what it needs.", with no scope.
   - A 6-min round changed nothing.
   - The builder then asked: "Which change did 'Yes, let it change what it needs' approve (please quote the question
     it answers)?"
3. At 16:19 I answered in words: "Yes, the frame-time failure. You may change scripts/main.gd, scripts/core and
   scripts/bodies."
   - The builder made the fix there: cached clip poses at half-frame steps, backpacks off.
   - The Foreman **dropped those files** ("dropped out-of-scope files"), so a person's yes does not widen a scope.
   - The same happened in round 4.
4. At 16:46 the builder asked: "The remaining cost appears to come from six engine figures, which I found no
   pack-level setting to reduce. Should the budget for this pack be raised, the engine's biped and rig tick be made
   cheaper, or may I spend a round on a lower-rate animation driver in the pack?" I answered: try the lower-rate
   driver.

The root cause, read in `engine/kernel/host/invariants.gd` `budget_class()`:
- A Create job's pack lies outside the engine's tree, so it is judged as "one of many" (p50 at most 1.0 ms), not
  "solo" (8.0 ms).
- Yet Create's Add to menu plays it alone, as a dungeon.
- The house hockey's base measured 3.5 ms p50 on the night of 24-25 Nov.

So no six-walker game made in Create can pass. No builder can fix it inside its scope, and no person can answer the
question.

The Director ruled at 16:50: a game made in Create is a dungeon and gets the solo budget; H2c implements it. At 16:51
I stopped my own resume of 16:47 (the foreman pid 9704 and its builder, both started by my door), so that no further
round went to the old budget. The job waits for H2c with its answer recorded; `foreman status` says "Continue with:
foreman resume".

What a person would see of 3 v 3: crews_stakes's workspace as the round-5 builder left it (unmerged, with its
out-of-scope edits), filmed the same way (`stills/ws3v3_play_strip.jpg`, `ws3v3_side_strip.jpg`,
`ws3v3_play_f1800.jpg`, `compare_ws3v3.jpg` = target | hokej | this):
- Six figures now, three yellow and three plum. They still share one toy-kid body, and some still wear backpacks.
- Four or five of them pile into one knot around the ball, a scrum rather than spacing.
- The ball leaves the court onto the dirt and play goes on.
- The camera still turns with you, so the hoop swings from the left of the frame to the right within seconds. The
  side camera is a low sideline view with figures in the near foreground.
- Score 3 to 1 after 29 s, and nothing tells me who scored or how.
- I see no screen and no block.
- Would I play again? No. It looks like the hockey base's skaters gathered round a puck, on a court, with a hoop.

Gap to the target, in three lines (unchanged since phase 1):
1. The bodies do not play basketball: they pile up, a screen or block does not read, and the ball leaves the court.
2. The camera turns. The target is a steady three-quarter broadcast view.
3. No arches, trees, fence, or blue court with an orange key (phase 3, not yet built).

## Cost so far (`tl ledger`, TL_SITE_DIR=.tl/jobs)

At 16:46: 246 min wall time, 229 min running, 5 packages, 16 rounds, 26.4M tokens in (23.6M cache reads), 555k out,
weighted 5.69M, 1 replan, 2 critic rounds. No v0.1.0 yet, so no change box yet.

## Where the iterations stop converging (so far)

Not yet at the change box. The route stopped converging before a first version, for four reasons.
- **The engine's rule:** a 1.0 ms budget that a 3 v 3 of the engine's own figures cannot meet. This is the hard stop.
  The Director's ruling and H2c address it.
- **The editor's route:**
  - A person is asked engineering questions (budget, scope, rig tick).
  - The "Yes, let it" chip and a written yes do not widen a scope.
  - The critic held a basketball blockout for want of hockey contact rows.
  - Three builder rounds were lost to a clock on a loaded machine before H1b.
- **The builders:** two cores were written from scratch (court_core failed on its own bound by 6 frames; court_exchange
  was rewritten whole). Their self-reports are honest (each lists what it did not do). A builder's own tofu test said
  ok while its metrics were out of the planner's bounds.
- **The critic:** its reading of what it sees is right (piles, no hit-stop, recoloured kids, a turning camera). But its
  two revise rounds were thrown away by the budget and by the tofu test after the merge, so nothing it said changed
  the game.

## Round 2 (18:22-20:42): with H2c the build goes through, then the hand check throws it away

- **18:23 resume, and a foreign run.** My resume went through a scratchpad `door.sh` that another lane (d25-kart) had
  overwritten. So d25-kart's foreman (2c2a16f, without H2c) verified crews_stakes r5 on the old 1.0 ms budget, failed
  it and started r6 (events 264-271). I stopped my process after about 4 min and moved my scripts into
  `d25-court/.tl/g4/`.
  - All 44 events from 272 on are in my own door log.
  - The foreign r6 builder had about 100 s in `ws/crews_stakes` before I stopped it. My r6 builder then worked in the
    same workspace. Every file merged at event 293 passed my foreman's checks.
- **18:28 Continue (my foreman).** crews_stakes r6 (the lower-rate pose driver: poses every 2 frames) passed
  invariants under the solo budget and merged at 18:40. The Foreman noted "scope widened for this change, on the
  person's answer" (H1f).
  - Greybox critic NOT ok: "six identical toy figures ... I cannot find the ball ... all six collapse into one knot
    under the hoop".
  - Revise round r5 on court_exchange was refused: the Foreman now judges tofu bounds itself (H1e).
  - Phase 2 paused at 18:55.
- **Phase 2 as a person** (`stills/p2_*`): 3 v 3, six identical kids in a knot, the ball off the court, the camera
  turning. I would not play again. I passed it, to reach v0.1.0 and put behaviour in the change box.
- **Phase 3:**
  - The greybox critic's revise 2 on crews_stakes merged.
  - viaduct_art was built in 4.5 min and merged at 19:18.
  - art_pass critic NOT ok twice. Both revise rounds were again driven partly by "48 house contact row(s) your pack
    does not have: hits.body_window ..." (hockey rows, after H1e).
  - Revise 2 merged plum jerseys on the rivals.
  - Two more quality holds (greybox, then art_pass). I answered both with "play it as it is".
- **Final verification** (19:52-20:42):
  - lint, smoke, invariants and 6 bots: ok.
  - The card's hand checks: 20 seeds of the newcomer hand and 20 of the perfect hand. The perfect hand wins 16 : 7; the
    newcomer wins **7 of 20**, and the card asks at least 13.
  - crews_stakes got a round (r9: rivals' tier-1 shot timing error 8 -> 18 frames). Its merge was refused because the
    pack's tofu failed after it.
  - The Foreman re-ran the same 40 hand seeds on unchanged files, got the same 7 of 20 (the game is deterministic), and
    at 20:42 set **job failed: "hand check of card.team_possession failed, nothing promoted"**.

**What a person sees now.** Create's failed screen, "This build stopped", whose one button is **Try again**: the same
sentence from scratch.
- No version was promoted, so there is no Play, no Add to menu and no change box.
- After 8 hours (482 min wall time, 465 running), 22 builder rounds, 6 critic rounds, 34.3M tokens in (30.5M cache
  reads), 684k out, weighted 7.52M, the person has nothing to play.

**The game that was thrown away** (`stills/v010_*`, the job's last `pack/`, filmed the same way;
`stills/compare_v010.jpg` = target | hokej | this):
- **Look: the first real step toward the target.**
  - Blue court with an orange key and a dashed arc.
  - Three tall arches behind the hoop, grey stone rather than brick.
  - A metal fence, orange leaf piles, a row of block-figure onlookers, benches and bins.
  - Yellow against plum.
  - Still missing: the brick colour, the autumn-yellow trees (they are green and lime), and the river.
- **Behaviour: unchanged since phase 1.**
  - Six identical toy kids with backpacks crowd into one knot in the key (3 of them at 00:29).
  - The play camera still turns with you, so the arches swing from frame to frame. The side view puts heads in the
    near foreground.
  - The ball still leaves the court.
  - I can read no screen and no block. The HUD says "SPACE: SWAT AS THEY RISE" most of the time.
  - Score 5 : 1 after 29 s.
- **Would I play again?** It is the first version I would open twice for the look, but no: there is nothing to do
  with the ball that I can see working.

Gap to the target, in three lines:
1. **Behaviour.** No spacing, no readable dribble, shot, screen or block. Six bodies in a knot, and the ball off the
   court.
2. **Camera.** It turns with you, against my note on the card (H1f checks camera notes, but no change round reached
   it).
3. **Look.** Grey arches instead of brick, green trees instead of yellow, cloned kids instead of six distinct players.

## Where the iterations stop converging (after round 2)

They never reached the change box. After 8 hours, the route ends on a rule a person cannot see or answer.
- **The card's hand check is a gate on the first promotion.**
  - When the newcomer hand loses (7 of 20 against 13), nothing is promoted. The job fails and Create offers only "Try
    again" from scratch.
  - So a 3 v 3 that is too hard for a newcomer is thrown away whole, instead of reaching the person as v0.1.0 with "too
    hard for a newcomer" as a note for the first change.
  - The re-check loop re-ran the same deterministic 40 seeds on unchanged files.
- **The critic** still sends revise rounds for hockey contact rows at art_pass after H1e (events 412, 443).
- **The builders.** Each round says honestly what it did not do. They never fixed the core behaviour (spacing, ball
  bounds, a fixed camera), and no critic round or hold made them try: each revise went to whichever package the critic
  named, mostly for look items.
- **The engine:** solved for this job by H2c (the solo budget).

## Round 3 (20:44-21:41): Resume, v0.1.0, the menu and one behaviour change

- **The failed card** (H1i) now reads: "Every part was built, but the last check plays your game with a bot hand, and
  that check failed. Nothing was released." It offers **Resume** ("keeps the work so far") beside Try again.
- **20:45: I pressed Resume** (`resume --retry-failed` with the run flags).
  - It first re-ran the whole final verification on unchanged files: 17 min, and the same newcomer 7 of 20.
  - Then it sent crews_stakes back for one round (r10, 8.7 min, 2.3M tokens in): rival guard gap at tier 1, and a
    match cap of 180 -> 150 s so three matches fit the tofu check.
  - r10 merged.
- **The final check passed** (`foreman status`, hand check #4): newcomer **20 of 20** (at least 13), perfect 20 of 20.
  The tier-1 rivals went from too hard to never winning.
- **21:34: v0.1.0 promoted** (`promoted/game.half_court_3_v`).
  - Whole job: 534 min wall time, 517 running, 23 rounds, 6 critic rounds, 36.6M tokens in (32.6M cache reads), 707k
    out, weighted 7.89M.
- **Added to the menu** as Create does (`Dungeons.add_user` row: pack, title, job) in my tree's own list,
  `.tl/menu/dungeons.user.json`, for the Director to copy out. The person's real `user://` list was not touched.
- **v0.1.0 as a person** (`stills/v010_promoted_play_strip.jpg`, `v010_promoted_play_f1800.jpg`,
  `compare_v010_promoted.jpg` = target | hokej | this):
  - **Look:** the same as the last pack. A blue court with an orange key, three grey arches behind the hoop, a fence,
    leaf piles, onlookers, yellow against plum.
  - **Behaviour:** a little more spread. In some seconds four players stand apart and two wait on the wings, but most
    seconds still show a knot of 3-4 in the key.
  - The camera still turns with you.
  - The kids are still clones with backpacks.
  - Crew 3 : 1 after 29 s.
  - Would I play again? Not yet. It finally looks like a street court, but it still plays like a crowd round a ball.
- **Change 1, behaviour**, sent through Create's change box at 21:38: "Spread the players out like real 3 on 3: only
  the ball carrier and their defender near the ball, the others on the wings and corners, never all six in one knot
  under the hoop".
  - It waits for room (the machine was at 76-90 % CPU) and then starts detached through my own door.
  - Its result is for the next round.

Gap to the target, in three lines:
1. **Behaviour:** knots in the key, no readable screen or block.
2. **Camera:** turning (the second change to send).
3. **Look:** grey arches instead of brick, green trees, cloned kids.

**Finding of this round:** each Resume costs a full re-check of unchanged files before the send-back (17 min here).
On a deterministic game, that re-check cannot change the answer.

## Round 4 (22:00-): change 1 (spacing) -> v0.1.1, then change 2 (camera)

**Change 1**, typed in the change box at 21:38: "Spread the players out like real 3 on 3: only the ball carrier and
their defender near the ball, the others on the wings and corners, never all six in one knot under the hoop".
- It started at 21:56, when there was room on the machine.
- The Planner named crews_stakes in 6 s (4k tokens in).
- crews_stakes r11 took 5.5 min (1.28M tokens in). Every bot off the ball now follows one spacing rule
  (`scripts/crews/brain.gd`). The five off-ball spots moved wider, `crews.spots` [[-6,2.2],[6,2.2],[-5.2,8.6],
  [5.2,8.6],[0,10]] -> [[-6.5,1.8],[6.5,1.8],[-5.8,6.8],[5.8,6.8],[0,9.8]], and `keep_from_ball` went 4.0 -> 4.8 m
  (13 more keys in its note).
- Merged at 22:07. The final check passed: hand check #5, newcomer 19 of 20, perfect 20 of 20.
- **v0.1.1 promoted at 22:26.** 30 min from request to promotion, of which 17 min was the final verification's
  40 hand seeds.
- The editor's "what changed" note shows the person the request, the builder's words and the files.

**v0.1.1 as a person, beside v0.1.0** (`stills/strips_v010_vs_v011.jpg`: v0.1.0 left, v0.1.1 right, the same bot
and the same seconds; `stills/v011_play_strip.jpg`, `v011_play_f1800.jpg`; `stills/compare_target_v010_v011.jpg` =
target | v0.1.0 | v0.1.1).
- **Is the knot gone? Not gone, but rarer.** By my count of 16 seconds (one tile a second):
  - v0.1.0 shows three or more players in one clump near the ball in about 9 of the 16 tiles;
  - v0.1.1 shows it in about 4-5 of the 16.
  - More seconds show two players on the wings and one in a corner.
  - A knot of 3-4 still forms under the hoop on a drive or a rebound.
  - This is my eye on stills, not a measured figure. The builder reported no scrum figure for v0.1.1.
- New in the frame at 00:29: the carrier and her defender stand on the dark apron behind the baseline, under the
  hoop, with the ball. The ball still goes out of bounds and play goes on.
- The camera still turns with you. That is change 2.
- **Would I play again?** Closer: for the first time the floor shows a shape (wings, corners, a ball side). But it is
  still not a game I'd replay, because I cannot see a screen or a block land, and the view keeps turning.

Gap to the target, in three lines:
1. **Behaviour:** knots rarer but still there, the ball out of bounds, no readable screen or block.
2. **Camera:** turns (change 2, sent).
3. **Look:** grey arches, green trees, cloned kids.

**Change 2**, sent at 22:28: "Keep the camera steady like a TV broadcast: high behind the half-court, always looking
at the hoop; it may slide sideways with me but it never turns or swings". At 22:33 it was still waiting for room
(the machine at 97-100 % CPU).

**Change 2 (camera)**: it started at 22:41, when there was room.
- The Planner gave it to court_exchange, which owns `main.gd`.
- court_exchange r7 took 7.7 min (1.6M tokens in). The `play` camera now sits fixed at height 8 and depth 19, looks at
  the hoop end, and slides sideways at most 3 m with you. It never turns.
- The builder also changed more than the camera:
  - Spacing in the core AI: `ai.space` 7.2 -> 7.6, `ai.wide_gap` 0.8 -> 1.2.
  - The tofu test's own input policy (`tests/support/hand.gd`): shot timing now rotates perfect, early and late,
    dropping "good", and the wait before shooting went 150 -> 125 frames. That is a test changing how it plays in
    order to pass its bounds; it says so in its note.
- Merged at 22:53. Hand check #6: newcomer 18 of 20, perfect 20 of 20.
- **v0.1.2 promoted at 23:18.** 37 min from start to promotion; 17 of them were the 40 hand seeds again.

**v0.1.2 as a person** (`stills/v012_play_strip.jpg`, `v012_play_f1800.jpg`; `stills/compare_target_hokej_v010_v012.jpg`
= target and hokej on top, v0.1.0 and v0.1.2 below). This is the first version that reads as basketball.
- **The camera is the change you feel most.** A steady high three-quarter view of the whole half-court: the three
  arches and the hoop at the top of the frame, the court laid out below. It is the target's framing, and it stays put
  for all 16 seconds.
- **Spacing:** with the whole court visible, the floor has a shape. Two players on the left wing, one on the right
  wing, the carrier and her defender in a corner. In 16 seconds I see at most a pair or three near the ball, and no
  six-in-the-key knot. The camera change also pushed the AI wider.
- **"You"** is now a clear green ring.
- **Still missing:**
  - The kids are clones with backpacks and small at this distance.
  - I cannot see a screen or a block land, and the "SPACE: SWAT AS THEY RISE" hint is the only sign of a defensive
    verb.
  - The ball is a small orange dot; at 00:29 it flies off beyond the baseline into the crowd.
  - Grey arches, green trees.
- **Would I play again?** For the first time, maybe: it looks and moves like a street court seen on TV. But one press
  does not show me a dribble, a screen or a block, and that is what would bring me back.

Gap to the target, in three lines:
1. **Behaviour:** verbs unreadable. No visible screen, swat or dribble bounce; the ball goes out and play goes on.
2. **Bodies:** six cloned toy kids with backpacks, small. The target has six distinct players in jerseys.
3. **Look:** grey arches instead of brick, green trees instead of yellow, no river.

**The menu:** the row in `.tl/menu/dungeons.user.json` now points to `promoted/game.half_court_3_v@0.1.2`. That is what
Create's `_follow_menu_row` does: a game in the menu plays its newest version.

**Job totals** (`tl ledger`): 638 min wall time, 621 running, 25 builder rounds, 6 critic rounds, 39.5M tokens in
(35.3M cache reads), 749k out, weighted 8.44M. The two changes together: about 2.9M tokens in, about 67 min, two
builder rounds.

## The answer so far: can a person reach hokej's quality through the editor alone?

Not today, but the last two hours show where it can converge.
- **It took 9 hours and four editor fixes to reach a first version.** Each block was something a person could not see
  or answer:
  - the "one of many" frame budget;
  - the critic judging basketball by hockey rows;
  - a scope that a person's yes could not widen;
  - a hand check that threw away the whole job.
  Each was fixed by H1 or H2 (with the Director's rulings) during the day, not by anything a person could do in Create.
- **Once a version existed, the change box converged fast and visibly.** Two sentences, about 30 min each, turned
  "a crowd round a ball under a spinning camera" into a steady broadcast view of a spaced half-court, the target's
  composition.
- **Where it still does not converge:**
  - The verbs (screen, swat, dribble) and distinct bodies. No change round asked for them yet.
  - All 40 hand seeds re-run on every change: 17 min of each 30-37 min.
  - A builder that edits a test's input policy as part of a camera change, without the person asking.
- **Against hokej:** hokej has readable contact (wind-up, hit-stop, falls), a HUD with the controls, and distinct
  skaters in kits. v0.1.2 has the court and the camera, but none of the exchange yet.
