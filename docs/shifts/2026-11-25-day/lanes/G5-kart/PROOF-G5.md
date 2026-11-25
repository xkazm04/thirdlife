# G5 proof: Bumper-kart football from scratch through Create (day of 25 Nov 2026)

Tree `.claude/worktrees/d25-kart` (branch d25-kart, main 2c2a16f: H1, H1b-H1e). Jobs root `.tl/jobs/`. Every step went
through `engine/ui/foreman_run.mjs` in the order of `engine/ui/foreman_door.gd` (Create's door: new; react... approve,
plan, run; quality / phase; change) with the flags of `engine/ui/flags/real.json` (claude-cli, sonnet, subscription max).
Logs in `.tl/jobs/_ui_logs/`. No code edited. Times are local (CET; the job log is UTC, one hour behind).

Targets: `docs/shifts/2026-11-24-night/concepts/bumper_kart_football_concept.jpg` and `..._screenshot.jpg`: round
fairground tubs on fat black rubber rings, kids in striped helmets, pennants; red-and-cream against mint; a huge
stitched blue-and-cream ball; a wooden deck under a green iron pavilion with striped awnings, sea and a pier at sunset;
a TV score board 2 00:46 1; A BUMP / B BRAKE. hokej is the right third of each `*_vs_target_hokej.jpg` (E5's strip,
row 3, col 4); the left third is the target screenshot.

How I look: there is no keyboard here, so "play" is the pack's own hands (`tests/bot_hand_perfect.gd`, later
`bot_hand_newcomer.gd` when the teams package adds it) and its tofu bot, headless for the figures, then the same bots
filmed in a window with the follow camera `play` (the pack declares no other camera, so no wide view): 16 frames one
second apart from frame 600 (`--strip=16x60`, HUD on) and a still at frame 1500.

## 0. The sentence and the cards (17:03 to 17:16)

Typed in Create (Standard, not "Build straight through"):
> bumper-kart football: 3 v 3 fairground bumper karts bump and spin each other and push a huge stitched ball into the
> goals, on a seaside pier pavilion at sunset

- **Design: 11.4 min** (concept 1 call, designer 3 calls, review 2, both "revise": hook 0.8/0.76, fit 0.5/0.55), about
  444k tokens in. Candidate 1 of 5 (0.85), template `arcade_sport` (Rocket League 3v3 + NHL '94 + Simple Soccer).
- Pitch: "I'm the pier's meanest bumper driver: three on three, spinning rivals to hammer the huge ball home."
- **6 cards**: Mean Bumper Kart, Spinning Bats (twist: a spun rival becomes a bat that fires the ball at 20 m/s),
  Giant Stitched Ball (pinned to your nose, hockey-style carry), Ghost Train Crew (Bertha, Nell, Vic, each with a
  tell), High Chase Camera, Beat The Sunset (first to 3, 180 s).
- The pitch screen now shows the estimate (H1b): 8 parts, 420 min, 6 M tokens. G2's defect is fixed.
- As a person, looking at my picture: kept the kart ("a round fairground tub on a fat black rubber ring, a kid driver in
  a striped crash helmet, a little pennant on a pole; my team red and cream stripes, theirs mint green"); **dropped
  Spinning Bats** ("no bat trick, I just want to bump karts and push the big ball myself"); **chose Never Held** for
  the ball ("a huge heavy ball that rolls and bounces off the karts; you steer it by pushing and bumping it, never
  carry it"); **dropped the crew** ("one rival team in mint green with the same karts as mine"); kept the camera
  ("behind and above my kart, looking down the deck to the far goal; steady, no swinging") and the sunset rule
  ("a big score board at the top, red score, clock, mint score, like a TV game"). Build it.

## 1. Plan and phase 1, the tofu (17:16 to 18:07)

- Plan 4.3 min (115k in): `card.team_possession`, 4 packages, 4 phases: core (tofu: 1 v 1), teams (3 v 3, bots, boost
  pads), show (TV board, end card), look (sunset pier, painted tubs). The core contract opens with "Player decisions
  win over card and brief: NO spin bat, NEVER carried (no TLBall.hold, spring or anchor), NO named rivals." The
  decisions arrived.
- core r1 (6.7 min) and r2 (3.8 min) were refused by H1e's tofu gate: `possession_median_f` 107, then 196, against
  the plan's 240-600 frames (and skill_spread / skill_variants in r1). The builder's answer to the bound was to make
  the rival passive: "mint_1 now holds goal-side for 330 frames before attacking the ball again". r3 merged (the gate
  yields after two rounds, by design). Frame p50 0.35 ms (1 v 1), so no budget trouble here.
- Blockout critic NOT ok twice. Its reading is right (I looked at its captures): the goal is a thin tall sliver drawn
  over my own kart, there is no wind-up or hit-stop on a bump, the karts are boxes. It still sent **49 house-hockey
  contact rows** for the builder to add (hits.body_window, stand_brace, sprint_stability...) and waived 21 as
  hockey's own; the builder ignored them ("this design uses its own contact table"). Revise r4 merged; revise r5
  was spent on the tofu bound (`lead_change_share` 0) and thrown away.
- **Paused: quality at 17:53**, 37 min after Build and 50 min after the sentence (G2: 89 min to its first hold).

**What I saw at the hold** (`stills/p1_tofu_strip.jpg`, `p1_hand_strip.jpg`, `p1_vs_target_hokej.jpg`):
- A red box kart in a yellow ring and one mint box kart, each with a pennant, on orange floorboards. The camera sits
  so low and close that the frame is floorboards: no goal, no wall, no sky. The ball comes and goes at the top edge.
- The bump does read: the mint kart turns away, its driver and flag swing. My kart shows no wind-up.
- The perfect hand: 1027 frames, 5 touches, 1 spin, a goal. The tofu bot: 3 matches, 3:0, 3:1, 3:2.
- Would I play again? No: I cannot see where I am going.

On Create's quality card I pressed **Change it**:
> I only see floorboards. Lift the camera and look down the deck from behind my kart, so I always see the far goal,
> the side walls and the other karts, like my picture. Make the goals wide and low with a net, in team colours, with
> a goal line on the floor.

- The Planner routed it to core in 4 s. core r6 (5.8 min, 2.0M in) did it: camera back 8 -> 15, up 7 -> 14, fov 54,
  pitched down the deck. **The tofu gate refused it** for `possession_median_f` 211, a figure my change did not touch.
  r7 (2.2 min) changed only `bot.jockey_f` 420 -> 480 (the rival waits longer still) and merged. 14 min for the change.
- Phase tofu done at 18:07, 51 min after Build. 9.9M tokens in so far (8.5M cache reads), 300k out.

**What I saw after the change** (`stills/p1b_tofu_strip.jpg`, `p1b_vs_target_hokej.jpg`):
- Now it is a place: a long plank deck between dark walls, a wide low goal with a net at the far end, a peach sky.
- Bumps between the red and mint karts spin the mint kart; the ball rolls off when pushed.
- But the karts are now small toys on a 72 m deck for two, and the ball is no bigger than a kart: nothing "huge".
- Would I play again? Not yet: one rival on a huge empty deck. I passed the phase, since 3 v 3 comes next.

Gap to the target, three lines:
1. The ball: kart-sized and plain cream; the target's is a huge stitched blue-and-cream ball taller than a driver.
2. The karts: boxes with a block for a driver; the target's are round tubs on rubber rings with kids in helmets.
3. The place: orange planks and a peach sky; the target is a green iron pavilion with awnings, the sea and a pier.

## 2. Phases 2 to 4: teams, show, look (18:08 to v0.1.0)

- **teams** (3 v 3, utility bots, boost pads): merged r1 in 6 min. Frame p50 **0.64 ms with six karts**: kart bodies
  are cheap (cylinders, no rigs), so the 1.0 ms "one of many" budget that stopped G4's six walkers never bit here.
- What I saw with the newcomer hand (`stills/p2_teams_strip.jpg`, `p2_vs_target_hokej.jpg`): six small box karts on
  a long plank deck, yellow boost pads, a goal with confetti after 13 s. A red teammate drives cut by the bottom edge.
  The hand **won 3:0 in 5,511 frames (92 s)**, 37 touches, shots red 13 against mint 2: the rivals hardly threaten.
- **show** (TV board, stakes, end card): merged r1 in 4.8 min. `stills/p3_show_still.jpg`: a score board RED 1 | 2:43 |
  0 MINT and a ROOKIE ribbon, the layout of my picture.
- The greybox critic (after show) said what I see: "ramming a rival does nothing ... the two stay pressed together",
  kill line 2 seen, ball not huge, karts are "boxy flat-topped mowers". Its revise (core r8, 6.7 min) was **thrown
  away by the tofu bound** (lead_change_share 0.25, close_rounds 0) and the phase paused on the old core.
- Passing the show phase ran the greybox critic again; its revise (core r9) stopped on a **builder question to me**:
  "The ball changes sides about every half second, far quicker than the 4 seconds the check asks for. Should I (A)
  let a kart briefly hold the ball, (B) give the last striker a protected window, or (C) keep the ball fully loose and
  have the possession target dropped?" I answered as the person who chose "Never Held": **C**. The builder did
  (possession 30 frames) and **the Foreman threw the round away for that same bound**. A person's answer cannot lift
  a plan bound.
- **look**: r1 (5.2 min) merged: round striped tubs with pennants, a big stitched ball, a sunset deck (the art_pass
  critic's words; style_consistency 0.82). Its critic: "his bump barely does anything visible ... the two bodies
  stack into one column". look r2 (6.2 min) merged; core r10 (the critic's last revise) running.
- The ledger under-counts: when a builder's claude session ends with a second result after a background-task
  notification, the Foreman keeps only that last segment (core r8: 365 tokens out logged, 30,705 used, $1.03), and
  the builder's own note is lost ("as listed in my report above").
- core r10 (the art_pass critic's last revise, 5.3 min: camera punch on a hit, more) was again **thrown away by the
  possession bound** (30 frames, as I had answered). Phase pier done, **job paused for my verdict at 19:05**: 2 h 2 min
  from the sentence, 1 h 49 min of runs. Ledger so far (under-counted, see above): 15.0M tokens in (13.1M cache
  reads), 390k out.

**What I saw at the pier phase** (`stills/p4_pier_vs_target_hokej.jpg`, newcomer hand, frame 1500):
- The biggest single step toward the target: a blue sea, a pier with iron arches and bunting on both sides, red-white
  boards round the deck, round striped tubs with pennants, a red-and-cream stitched ball, the TV score board.
- Still small toys far from the camera; the ball is about one kart across, not "huge"; no pavilion roof, no sunset
  sky (the sky is plain blue); the karts read as tubs only up close.
- Behaviour unchanged since phase 2: three critic revises on the bump (r8, r9, r10) were all thrown away by the
  possession bound, so the bump still reads as one kart leaning on another.

Paused for the Director's fast-forward (H2c) before I pass the phase to v0.1.0.

## 3. To v0.1.0: the job failed, nothing promoted (19:09 to 19:34)

After the Director's fast-forward (main 3874e38: H2c, H1f, H1g, foreman rebuilt) I passed the pier phase as a person.
- Passing it **re-ran the greybox and the art_pass critics** (4 min); the Foreman's own note: "the look changed, part
  of the play did not". The job held on quality a fourth time. I accepted ("play it as it is").
- The final verification then played the hands over 20 seeds and found a real fault: `tests/bot_hand_perfect.gd`
  reports no boolean `won`. It sent the fault back to core. **core r11 fixed it** (4.1 min: the perfect hand now plays
  through `TLHand` "perfect" on the teams bot), and **the round was thrown away by the possession bound** (30 frames
  against 240-600: the same bound my answer C had asked to drop).
- The final check met the same fault again and the job ended: **"hand check of card.team_possession failed, nothing
  promoted"** at 19:34, 2 h 31 min from the sentence. Ledger (under-counted): 39 calls, 15.7M tokens in (13.6M
  cache reads), 411k out.
- What Create shows a person now: "This build stopped" and one button, **Try again**, which starts a new game from the
  sentence. There is no v0.1.0, so no Play, no Add to menu and no change box. The four change rounds cannot start.

The bound's path, from the start to the end:
1. Card: `card.team_possession` brings hockey's carry figure, possession_median_f 240-600 frames.
2. I chose "Never Held" on the ball card. The plan honoured it in words ("NEVER carried") and kept the bound.
3. core r1-r2 failed on it; the builders made the rival passive to stretch possession (waits 330, then 480 frames).
4. My camera change lost one round to it.
5. Three critic revises on the bump (r8, r9, r10) were thrown away by it.
6. A builder asked me; I answered "drop it"; the Foreman threw that round away by it.
7. The first version's own hand-test fix (r11) was thrown away by it, and the job failed.

## Where it stops converging (round 2)

- **The editor's route**, not the engine and not the builders. The builders did what was asked each time (camera,
  answer C, the hand fix); the engine ran six karts at 0.64 ms; the critic read the frames correctly every time. One
  plan bound, copied from a hockey card and not lifted by the person's card choice or answer, threw away every core
  round from 17:51 on and then the first version itself.
- **Compared with G2 and G4:** design honoured my choices, routing was right in 4 s, the estimate shows, the budget
  did not bite, and phases came fast (first hold at 50 min against G2's 89). But G2 reached v0.1.0 and I did not:
  H1e's tofu gate, which G4 asked for, applies a bound the person cannot reach or lift, so on this game today's
  editor ends worse than G2's.

## 4. Resumed by the Director's ruling (from 19:50)

**A person in Create could not have done this.** Create's failed card ("This build stopped") offers only "Try again",
which starts a new game from the sentence and throws away 2 h 31 min of work. The Director ruled (19:40) that this job
be resumed with `foreman resume <job> --retry-failed` after H1h (a person's answer or card choice lifts the plan bound;
a phase pass closes the milestone; the ledger sums every segment) landed and my tree's foreman was rebuilt (main
816b996). The editor's follow-up: a failed game should offer "Resume with the fix" and keep the work.
- 19:48 `resume --retry-failed` re-ran the final checks on the unchanged pack and failed at the same hand check at
  19:55 (7 min): a hand failure is sent back once per promotion or change request (`handcheck.ts` sendBackHands), and
  no package was "failed" for `--retry-failed` to retry. Core r11's fix stayed unmerged.
- 20:00 Director's ruling: my first change round goes in as `foreman change` on the failed job (a change request
  re-arms the hand send-back). **A person in Create had no path here either**: the failed card shows no change box,
  only "Try again". (H1i's "Resume" item: a resume must re-open the package whose test failed the hand check.)

## 5. Change 1 (behaviour: the bump) -> v0.1.0 (20:00 to 20:26)

Typed as a change on the failed job (the Director's path; a person in Create has none):
> When I bump a kart it has to feel like a real bumper car hit: a short freeze on contact, both karts jolt apart with
> a bang and sparks, and the kart I hit whirls round fast, its driver and flag whipping, before it drives on. Right
> now it looks like one kart leaning on another.

- Accepted on the failed job; the Planner routed it to core in 4 s. core r12 (6.5 min, 1.24M in): sparks and a
  metal clang on every hard contact, camera punch on hits (`camera.punch` 0.33 -> 0.45), the perfect hand rebuilt on
  the teams bot (the hand fix r11 had made).
- **H1h worked**: "[foreman] plan bound lifted, not judged: possession_median_f ... on your answer to core's question
  (event 216)". The round merged. Dependents re-verified (11 min), the final check and the hand checks over 20 seeds
  passed: **newcomer 16 of 20 wins, perfect 17 of 20**, median match about 5,500 frames (92 s).
- **v0.1.0 promoted at 20:26**: 3 h 23 min from the sentence (about 2 h 20 min of it running; 40 min waiting for
  rulings and fixes). Ledger: 41 calls, 16.9M tokens in (14.7M cache reads), 424k out (H1h sums every segment from
  here on; earlier rounds stay under-counted).
- **Added to the menu** with the function Create's Add to menu calls (`Dungeons.add_user`), into this tree's own
  list `.tl/g5-menu/dungeons.user.json` (not the owner's): pack
  `.tl/jobs/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3`, read back ok.

**What I saw** (`stills/p4_vs_v010_bump_2f.jpg`: the tofu bot's first bump, 2 frames a tile, before the change left,
v0.1.0 right; `v010_bump_2f_rows34.jpg` the contact enlarged; `v010_strip_play.jpg`, `v010_vs_target_hokej.jpg`):
- **The bump shows.** Before: my kart drives into the mint tub and the two sit stacked. Now: the camera punches in,
  white sparks fly at the contact, the mint tub turns away with its pennant whipping round and its driver thrown,
  and the two karts come apart. It is the first bump I would want to do again.
- The match reads as a game: a sunset sky over the sea, pier arches, stands, bunting, red-white boards, the TV
  board RED | 2:47 | MINT with a ROOKIE ribbon, a 3-2-1 kick-off count, a big "GOAL! OWN GOAL - RED SCORES" card,
  "Mint got there first" callouts.
- Still small: six tubs on a long deck seen from high and far; the ball is a brown striped sack about one kart
  across. My newcomer hand wins 16 of 20 and nearly as often as the perfect hand (17): the rivals do not threaten.

**As a person**: for the first time I would play it again, to bump a rival and see it spin. Not five times yet: the
ball is small and the other team rarely comes at me.

Gap to the target, three lines:
1. The ball: kart-sized brown stripes; the target's is a huge blue-and-cream stitched ball taller than the drivers.
2. Scale: tubs are toys far down a long deck; in the target they fill the frame with kids' faces and helmets.
3. The rivals: a newcomer wins 16 of 20; the target's mint drivers come at you with gritted teeth.

## 6. Change 2 (behaviour: the huge ball) -> v0.1.1 (20:31 to 21:24)

> The ball must be huge, like in my picture: about twice as tall as a kart, and heavy. One kart only nudges it and it
> rolls on slowly; a hard bump or a boost ram sends it rolling far; it bounces off the karts and the walls with
> weight. Right now it is the size of a kart and zips about like a light ball.

- Routed to core in 3 s. core r13 (6.6 min): ball radius 1.2 -> 1.8 m (3.6 m across), mass ratio 0.25 -> 0.5,
  top speed 30 -> 26, a shared push (`push_share` 0.5) and wall/kart squash. The possession bound was lifted on my
  answer again, as noted before the merge.
- The final hand check then found the **newcomer winning only 11 of 20** (the card asks at least 13) and sent it to
  teams, which made the Rookie rivals bump less often (`bump_cool_scale` 2.2): a change I did not ask for, made to
  meet a floor I never see. v0.1.1 promoted at 21:24, **53 min after I sent the words**, of which about 40 min were
  re-verification of all four packages and two runs of 40 hand matches.
- Hands over 20 seeds: **newcomer 14 of 20, perfect 20 of 20; median match 9,761 frames (2.7 min, was 1.5)**.

**What I saw** (`stills/v011_strip_play.jpg`, `v011_vs_target_hokej.jpg`): the ball is now plainly bigger than the
tubs, a stitched cream-and-brown ball about twice their height; my kart pushes it ahead of itself. But in this strip
two goals fall in the first 11 s, the second straight after a kick-off, and the ball in front of my kart hides it
from the chase camera.

**As a person**: the ball is now the thing on the pitch; pushing it feels like the game. The kick-off goals are cheap.

## 7. Change 3 (behaviour: rivals that attack) -> v0.1.2 (21:56 to 22:27)

> The mint team should come at me like real bumper car rivals: when I am at the ball, a mint kart charges in and
> bumps me off it, two of them press me together, and they shoot hard at my goal. Right now they hang back, I am
> hardly ever hit, and I win nearly every match without trying.

(32 min waiting for room on the machine before I could send it.)
- Routed to **teams** in 6 s (the utility bots), the right package. teams r3 (5.7 min): a hunt behaviour (when I am
  within 7 m of the ball, up to two mint karts within 34 m target me, from any side), a rest after each landed blow
  (100/60/40 frames by tier), mint shoots 1.35 x as eagerly and boost-rams a lined-up ball; Rookie cool-downs back
  from 2.2 to 1.5. The builder's note is plain words and reached the log whole.
- v0.1.2 promoted at 22:27, **31 min after sending**. Hands over 20 seeds: **newcomer 15 of 20, perfect 17 of 19**,
  median match 10,220 frames (2.8 min). My newcomer match on seed 1: won 3:0 in 6,317 frames, **hit 10 times
  (6.4 a minute)**, 47 touches.

**What I saw** (`stills/v012_strip_play.jpg`): from 2:50 the mint karts come for me: two press my kart at the ball,
my kart is thrown and spins out, a three-kart scrum with sparks forms at the goal mouth; "Mint got there first"
callouts. The score holds at 1:0 through the middle of the strip where v0.1.1 was 2:0 by 2:49.

**As a person**: now there is a fight for the ball. I would play this again. The perfect hand losing 2 of 19 says the
rivals can win now; a newcomer still wins 3 in 4 at Rookie, because the card's floor wants it so.

## 8. Change 4 (the look: the sunset pavilion) -> v0.1.3 (22:41 to 23:07)

> Make it look like my picture: the deck under a green iron pavilion roof with red-and-white striped awnings and warm
> hanging lamps, a pink and gold sunset over the sea with the pier lights behind, the ball in blue and cream stitched
> panels, and kids in red-and-cream or mint striped crash helmets sitting in the tubs, big enough to see.

- Routed to **look** in 3 s. look r3 (5.0 min): side and far-end pavilion roofs with striped awnings and lamp posts
  (nothing over the deck: "the play camera looks down from 14 m, a roof overhead would hide play"), a pink-gold sky,
  ball panels cream and blue (#2d62b0), drivers about 1.5 x bigger (helmet 0.36 -> 0.56 m) with striped helmets in
  team colours. The builder says plainly what it did not do: the sunset strip is narrow because the camera is not its
  package; the pennants are now below the 3.6 m ball; light masts poke through the new roofs.
- v0.1.3 promoted at 23:07, **26 min after sending**. Hands over 20 seeds: newcomer 15 of 20, perfect 18 of 20,
  median match 10,220 frames (2.8 min). The menu row moved to v0.1.3 (`Dungeons.add_user`, read back ok).

**What I saw** (`stills/v013_vs_target_hokej.jpg`, the Foreman's own `v013_promotion_f8850.jpg`):
- The palette and props are my picture's now: red-and-white striped awnings, lamp posts, bunting, a Ferris wheel, a
  pink-violet sky, a blue-and-cream stitched ball, mint and red kids in striped helmets, the TV board.
- Still not the target's framing: the camera is high and far, so the kids are small; the target's is low behind my
  kart with the tubs filling the frame. On a mint goal the camera sat behind my own goal net, and MATCH POINT is
  drawn over the ROOKIE ribbon.
- The promotion picture caught a 2:2 match at 0:50 with MINT SCORES: a close game.

**As a person**: this is a game I would show someone and play again. Not yet hokej: the view is far, the karts small.

Gap to the target, three lines:
1. The view: high and far; the target is low behind my kart with tubs and kids large in frame.
2. The pavilion: roofs at the sides and far end only, the sea seen as a strip; the target is under the roof, sea all round.
3. Small things: pennants below the ball, MATCH POINT over ROOKIE, the camera behind its own goal net on a mint goal.

## Where the iterations converge, and where they stop (round 3)

| version | what I asked | package | send -> promoted | newcomer / perfect (20 seeds) | median match |
|---|---|---|---|---|---|
| v0.1.0 | the bump (after the failed job) | core | 26 min | 16 / 17 | 1.5 min |
| v0.1.1 | the huge heavy ball | core (+ teams for the floor) | 53 min | 14 / 20 | 2.7 min |
| v0.1.2 | rivals that attack | teams | 31 min | 15 / 17 of 19 | 2.8 min |
| v0.1.3 | the sunset pavilion look | look | 26 min | 15 / 18 | 2.8 min |

- **Once the person can steer, it converges.** Every change went to the right package in 3-6 s, every builder did the
  thing I asked in 5-7 min, and each showed on film. The four changes moved the game further toward the target than
  the whole two-and-a-half hours of critic rounds before v0.1.0, which changed no behaviour at all.
- **Where it stopped converging, before v0.1.0, it was the editor's route**: one hockey plan bound (possession
  240-600 frames) that neither my card choice nor my answer could lift threw away every core round from 17:51 and
  then the first version itself (job failed 19:34). H1h fixed it; the Director had to resume the job by a path a
  person in Create does not have.
- **What a change costs now is mostly verification**: 5-7 min of building, then 15-40 min of re-verifying every
  package and 40 hand matches per promotion (twice when the card's newcomer floor sends it back).
- **Compared with G2 and G4**: design, routing, the estimate, the budget and the change box are better today. G2 also
  reached a moving change in 19 min. Today's editor ended worse than G2's only through that one bound, and better
  than G2's once it was lifted.
- **Is it hokej's quality?** Not yet. Its contact now reads (sparks, spin, camera punch) and rivals press; it has a
  real place. It lacks hokej's close view of bodies, and a newcomer still wins 3 of 4 at Rookie by the card's floor.
