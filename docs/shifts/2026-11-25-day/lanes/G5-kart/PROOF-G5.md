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
