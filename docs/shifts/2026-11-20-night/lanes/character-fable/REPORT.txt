REPORT: character-fable (Fable 5.2 builds directly), night of 20 Nov 2026, the toy-diorama duel
Worktree .claude/worktrees/n20-character-fable, branch diorama-character-fable (from diorama-base 781d32b). Nothing committed.

STATE: done. The worktree is the final tree: the exe, the clip, the stills and every gate line below are of it.
Two gate lines are not PASS and need reading with care (section 3):
- `packs` failed at 03:20, passed at 04:03 and failed at 04:53 on the same tree, each time on one wall-clock line (hockey's
  frame budget), which the classic figure fails and passes alike tonight. Every state hash is as on diorama-base.
- The whole full tier (04:11 to 05:06) ended exit 1: kernel.selftest was killed at its 30-minute limit with 97 of 98
  units done (97 passed, 0 failed) while it queued for the machine's window lock; perf said NOT RUN (machine BUSY).
  A stopped run is not a pass. The six selftest families the brief names ran to the end separately and passed.

1. WHAT I BUILT, AND WHY IT READS AS DIORAMA
Route: the code-built figure, refined. No Blender, no imported mesh. Why: the target figure is separate rigid lumps of
clay, which is exactly what a rigid-weighted code figure is; every game keeps getting its character from one
TLBiped.create call with palette colours, helmets and props; nothing new enters the asset pipeline; and a still of ten
posed figures costs 15 seconds, so I could judge by eye about thirty times tonight.

The figure (engine/rigs/biped/tl_rig_biped_toy.gd, tl_rig_biped_clay.gd), chosen by the style:
  "_figure": {"variant": "toy"} in style_diorama.json. An absent key builds today's figure, untouched.
- The classic skeleton, joint for joint (29 bones, same names): the gait, the grips, the sockets and the wings fit unchanged.
- Chunky inside the same 2.0 m: a large round head that sits in a rolled collar, a short flared jacket with two
  buttons, thick sleeves, bare mitten hands, cream cuffs at the wrists, wide trouser legs rolled into a cream cuff over
  short bulbous boots, legs apart. The lumps of a limb sit a little outside its joints (arm 2 cm, leg 4 cm), so the toy
  is broad on a skeleton that is not.
- Every piece is its own closed smooth lump (ball, loft through rounded sections, rolled ring), displaced by a low
  noise of a few millimetres; pieces overlap like pressed clay and bend at ball-like joints.
- Sculpted hair: a cap, lobes at the back and the sides, a swept fringe, two buns on the crown (the larger rides the
  `Hair` bone), combed straight back with a tool.
- Skaters: a domed helmet in the team colour with a white stripe, ear guards and a brim, white hem and collar, the
  number patch; gloves in the `boots` colour. Backpack, stick, skates and hammer are dressed in the same clay.
- Contact tone: where two lumps press together the clay is darker (under the collar, sleeve against trunk, between hair
  lobes), baked per vertex from the lumps as spheres.

The material (engine/style/shaders/body_clay.gdshader): toon's contract with the world (palette lookup, tl_plot, tl_clip,
tl_body, roughness 0.5 as the ink pass's body tag), another response: a soft terminator with a warm band, a weak broad
sheen, uneven pigment, combed marks on the hair, chipped paint where the vertex alpha says paint wears (hem, cuffs,
boot edges, a few flakes anywhere), and fingerprints: a few thumb presses, each an oval pad of shallow loop ridges
laid in the surface (large, because the toy is a miniature: ridges 19 mm apart in game metres; gone before a ridge is
under four pixels). All of it is anchored to the piece's rest pose, so nothing crawls in motion.
  The Director's observation at 03:05 was right: my first fingerprints were whorls cut by spheres in space, so a sleeve
  or a trouser leg sliced them into rings round the limb, like contour lines. They are now laid in the tangent plane of
  the piece's rest normal (the mesh carries it in UV) and there are few of them: the close-ups on the sheet are the new
  ones (one pad on the belly, one on the back, sleeves and legs clean). At play distance no print is drawn at all (the
  figure is about 230 pixels tall from the visitor's camera; a ridge would be 2 pixels): I checked crops of the clip's
  frames at native size and saw chips, cuffs and form only.

How it moves (engine/rigs/biped/tl_rig_biped_feel.gd; the bare-headed toy only; all frame-counted and deterministic):
- Secondary motion: the bun is a damped spring on the head's and the body's acceleration (18 degrees at most in a run,
  jump and stop; at rest again within 90 ticks), and the large head wobbles a few degrees on its peg.
- Squash and stretch about the soles: 7.6 % stretch at a take-off, 6.3 % squash at a landing from an 8.5 m/s jump,
  settled in two beats.
- Hands that meet what they grab: on a ledge or a bar both arms are solved onto the edge. Wrist to the ledge's edge
  0.304 m before, 0.075 m now (the palm is 0.075 m from the wrist: it lies on the edge); bar 0.273 m before, 0.093 m
  (village visitor) and 0.076 m (a pack's TLBiped) now. When the edge is beyond the arms the whole figure is drawn to it.
- A pleasing idle: a slow sway of the trunk, breath in the shoulders, a look to one side and then the other every six
  seconds, over the classic planted feet. Walking, the head rolls with the step and the arms swing wider.
- "Smoother transitions between run, jump and land": the pose blends themselves are the classic ones (the landing's
  4-frame blend was a decision of the walker-feel night); what softens them is the stretch, the squash and the
  follow-through of bun and head. I did not retime the clips.

2. THE RULES, EACH WITH ITS EVIDENCE
Rule 1, no pack file changes, API v1 kept: git status shows no file under engine/packs or engine/seeds and no kernel
  file. `tl arch`: PASS 12/12, api-v1 "kernel API 1.11: 43 classes, 658 members", api-index-fresh PASS. No palette key
  added, renamed or reordered.
Rule 2, classic stays exact:
  - The character sheet of ten posed figures (walker front, three-quarter, side, back, run, backpack, cheer, blue
    skater, red skater, hang) under TL_STYLE=classic, captured before any rig code changed and again on the final
    tree (04:10): max difference 0 over 2,073,600 pixels (identical, not merely within 1/255).
  - figure.classic: 29 bones, 10296 triangles with the backpack (the figures of RIGS.md), no feel layer, scale 1
    throughout a run, jump and stop.
  - Game shots under classic, my capture at 00:09 against the final tree: parkour frame 520 and frame 987 identical
    (0 of 921,600 pixels differ). Hockey frame 1500: 103 pixels differ (largest step 42/255); two captures of the same
    tree differ by 176 pixels (the ice spray near the skaters is not the same picture twice), so that is the shot's own
    noise. The 00:09 capture already had my rig code in it, so the true before/after is the sheet above; against the
    Director's reference JPGs the final classic frames differ by 2.6/255 (parkour) and 1.7/255 (hockey) on average,
    which is JPEG compression.
Rule 3, no state hash moves: `tl check --tier full --only world,packs,kit.selftest` on the final tree, against the same
  command run on diorama-base before the first edit (23:35):
  - world: PASS [8/8], all 8 hashes equal: seed.drive a2940a1735bc2b72, seed.wall d5aea03b46c33ee6, seed.paddle
    dff1a390470352e7, example.walker f1c7b53757c34040, example.kit ca698e71d34d1021, example.car 3a459d0fe25e7853,
    game.ice_hockey_three_against a29dcdf02a16dd1c, game.parkour f7abac006a45bd43.
  - packs: 46 of 46 verb logs that carry a state hash have the hash and frame count of diorama-base (hockey and
    parkour), in both runs of the gate on the final tree. One run is FAIL (47 of 48, one wall-clock check), one is
    PASS (48 of 48): see section 3.
  The gate caught one real thing on the way: example.kit reads a leg bone of its walker into its state, and my first
  idle shifted the weight through the legs, so its hash moved (b7c90f55 against ca698e71). The toy's legs are now the
  classic gait's bone for bone and the hash is back. Presentation is not isolated from state in that example.
Rule 4, cache keys: no geometry generator of kit, terrain or crowns changed; PIC_VERSION is untouched.
Rule 5, performance: `tl perf run --scenario tour6 --no-record`, windowed, machine busy (20 to 32 Godot processes of
  the six arms), three alternating pairs between 03:00 and 03:10: gpu_ms classic 1.193, 1.653, 1.644; diorama 1.200,
  1.244, 1.209. Draw calls 371 classic, 379 diorama (one small extra surface per figure, see 6). No doubling. One single
  run earlier read 2.772 for diorama against 1.263 for classic two minutes apart: that was the machine, the pairs do
  not repeat it. The third diorama run has the final shader; the first two had the earlier fingerprint term.
  Rig tick cost, headless, 12 figures, best of 25 runs, 5 alternating pairs: skater 23.90 us classic, 23.94 us toy;
  walker 35.2 us classic, 41.7 us toy (the feel layer, about 7 us). Mesh build: classic about 62 ms for every figure;
  toy about 250 ms for the first figure of a variant (with its contact tone), about 80 ms for another colouring, about
  4 ms for every later figure of a look (equal looks share one mesh: ten skaters are two meshes).

The character rails:
- TLBiped.create unchanged: engine/kernel/api/tl_biped.gd, world/visitor.gd and flight_wings.gd are byte for byte as
  on diorama-base. The rig asks the controller above it what its hands hold (duck-typed: ledge_top, wall_normal,
  mantle_progress, bar_point, bar_axis), so no kernel line was needed.
- Clip and bone names kept, sockets kept: figure.toy checks the 29 bone names, the 20 clip names and the 7 sockets on the
  walker, the walker with a backpack, the skater and the hammer.
- metrics(): height 2.0, radius 0.3, eye_height 1.765 (figure.toy and figure.classic).
- Budget: 9812 triangles (walker), 10920 (with the backpack), 9112 (skater); limit 12000. 29 bones; limit 30.
  I had a 30th bone for the bun at first: the kit example's bot pins 29, so the bun rides `Hair` and the count stays.
- Selftests on the final tree: figure. 4/4, rig. 14/14, moves. 14/14, flight. 13/13, wings 2/2, style. 3/3 (section 3).
- Every game still works, shown in the shot set: hockey skaters (helmet, stick, team colours), the parkour runner (the
  pack's blue jacket), the village walker, the summoned wings on the bare back (same flight, same frames).

3. THE GATES (final tree)
All on the final tree (the tree of the exe, the clip and the stills), 03:08 to 04:10, machine busy (19 to 32 Godot
processes of the six arms; a windowed selftest waited up to 15 minutes for the machine's window lock). The fast tier
was run again at 04:10 with the docs and the lane folder in place: the same five PASS lines.
node devx/bin/tl.mjs check --tier fast
  PASS  arch               [12/12] 12 rules
  PASS  assets             [4/4] 4 checks passed
  PASS  cards              [3/3] 4 cards, schema ok
  PASS  devx.test          [229/229] 229 pass, 0 fail across 17 files
  PASS  foreman.typecheck  tsc --noEmit clean
node devx/bin/tl.mjs check --tier full --only world,packs,kit.selftest
  PASS  kit.selftest       [95/95] 95 cases passed
  PASS  world              [8/8] 8 games: world = alone, the 8 hashes of diorama-base
  FAIL  packs              [1/2] completed 1 of 2 units found; found 2, completed 1; verb runs 47 of 48; FAILED hockey:
                           invariants: invariants.many_budget: frame p50 1.060 ms (budget 1.0 ms for one of many)
  This FAIL is not a pass and I do not call it one. What it is: a wall-clock frame budget that diorama-base meets
  at 0.992 ms on a quiet machine (my baseline run at 23:35: PASS packs [2/2], 48 of 48). Tonight it fails with either
  figure. Paired runs of `tl.sh invariants --pack=engine/packs/hockey`, classic then diorama, same minute:
    01:27  1.022 FAIL / 0.938 PASS     1.054 FAIL / 1.049 FAIL     1.202 FAIL / 1.218 FAIL
    03:23  0.973 PASS / 0.966 PASS     1.003 FAIL / 0.985 PASS     (final tree)
  The hockey invariants run's state hash is ccf763f6d72f720a, as on diorama-base. I first made it worse (the feel layer
  cost a skater 3.5 us a tick): that is why skaters have no feel layer and tick at 23.94 us against classic's 23.90.
  The same gate again, same tree, 03:54 to 04:03:
  PASS  packs              [2/2] found 2, completed 2; verb runs 48 of 48 (hockey bot:bot_hockey a29dcdf02a16dd1c@4186,
                           bot_hockey_regular 28d668ebc65abf8e@1530, bot_hockey_newcomer d67aaf3b906ed96a@2946, ...);
                           many_budget 0.946 ms; 46 of 46 hashes as on diorama-base.
  So: FAIL, PASS and (in the whole full tier at 04:53, 1.112 ms) FAIL on one tree. The Director's combined gate will
  meet the same coin.
bash engine/tools/selftest.sh <family>
  figure.  4 passed, 0 failed   (new block 590)
    PASS figure.toy      figure=toy 9812 tris/29 bones, pack 10920/29, skate 9112/29, hammer 10920/29,
                         bun_max_deg=18.1 bun_end_deg=0.09 stretch=-0.076 squash=0.063
    PASS figure.classic  figure=classic 9604/29, pack 10296/29, skate 9556/29, hammer 10296/29
    PASS figure.grip     wrist to the line: MOVESPOSE edge 0.075 m, bar 0.093 m; BIPEDGRIP edge 0.075 m, bar 0.076 m
    PASS figure.clay     tl_plot, tl_clip, tl_body, the ink body tag, the palette lookup; the diorama style asks for
                         the toy, the classic one does not
  rig.     14 passed, 0 failed  (kit.bot, rig.biped_walks_and_skates walk 2.3 m/s leg swing 0.8838 skate 9.4976,
                                 rig.feet_plant sole slide 0.025 to 0.097 m/s, rig.moves, 7 bugfix cases, 2 slide cases)
  moves.   14 passed, 0 failed  (moves.pose hands_to_edge_m and moves.biped_grip hands_to_lip_m now 0.075)
  flight.  13 passed, 0 failed  (flight.wings parts=17 tris=1236, flight.wings_summon, flight.replay delta 0.000 m)
  wings    2 passed, 0 failed
  style.   3 passed, 0 failed   (style.switch: unset -> style_diorama.json, TL_STYLE=classic -> style.json)
node devx/bin/tl.mjs check --tier full   (whole, 04:11 to 05:06, exit 1)
  PASS  arch [12/12], assets [4/4], cards [3/3], devx.test [229/229], foreman.typecheck
  PASS  foreman.test       [223/223] 217 pass, 0 fail, 6 skipped
  FAIL  kernel.selftest    [97/98] completed 97 of 98 units found; selftest: 0 failed, 97 passed; timed out after 1800 s
                           and was killed (exit 2: spawnSync bash ETIMEDOUT)
        A stopped run, not a pass. Its windowed cases wait for the one window lock of the machine, which six arms
        shared; my own runs of single families waited up to 15 minutes for it. What it did complete has no failure.
        The families of the brief ran to the end on this tree (above): figure., rig., moves., flight., wings, style.
  PASS  kit.selftest       [95/95] 95 cases passed
  FAIL  packs              [1/2] verb runs 47 of 48; hockey invariants.many_budget: frame p50 1.112 ms (budget 1.0 ms);
                           46 of 46 hashes as on diorama-base (the third run of this gate on this tree: FAIL, PASS, FAIL)
  NOT RUN  perf            could not run: machine BUSY (use 89%, probe 0.875): perf measured but NOT judged
  PASS  seeds              [39/39] 39 cases passed
  PASS  item.selftest      [91/91] 91 cases passed
  PASS  ui.selftest        [166/166] 166 cases passed
  PASS  world              [8/8] 8 games: world = alone, the 8 hashes of diorama-base
  For the Director: kernel.selftest needs a run on a quiet machine before the merge is called green.
bash engine/tools/export.sh ... : PASS export.build, PASS export.check (section 4).

4. DELIVERABLES (docs/shifts/2026-11-20-night/lanes/character-fable/)
- contact-sheet.jpg: the target board beside the toy on the village road, then eleven classic | diorama pairs (the
  walker at play distance, village from the road and from above, flight take-off and over the bluff, parkour at frames
  520 and 987, hockey at 1500, close-up from behind and from the front, the character sheet of ten poses).
- stills/: every single frame as JPG (classic_*, diorama_*).
- clip.mp4: 28.2 s, 1280x720, 60 fps, 19 MB, windowed, recorded on the final tree. He walks the village road, runs
  into the parkour yard (the pack's bot is running the course there), stops, looks round, jumps on the spot, runs back
  to the road, summons the wings, flies west along the road, north up the river and east along the bluff.
  A flight has to start and stay outside a game's plot (a plot lands him at its gate), so he leaves the yard before
  the take-off. clip.walk.json and clip.devices.json reproduce it:
  `world.sh visit-test <lane>/clip.walk.json --devices=<lane>/clip.devices.json` with TL_WINDOW_ARGS="--write-movie <avi>".
  clip-strip.jpg is 18 frames of it.
- clip-feel.mp4: 16 s, 1280x720, windowed, the review scene (engine/rigs/review), the toy with its backpack: 5.5 s of
  standing (the sway, the look to one side), then a run, a jump, the landing and a stop seen from the side, then the
  same from the visitor's camera. It is there for the bun, the head, the stretch and the squash: the village clip
  shows them from 8.5 m.
- exe: C:/Users/kazda/kiro/third-life/dist/arms/character-fable/ThirdLife/ThirdLife.exe (PLAY-LATEST.cmd beside the
  folder starts it). PASS export.build: tag 781d32b 2026-11-20 03:09.
  PASS export.check: build '781d32b 2026-11-20 03:09'; the exe runs the same games to the same hashes as the editor
  binary, shows the village, obeys W and Esc, and leaves nothing behind. Built from the final tree.
- PATCHES.md, STANDUP.md, this report.
How to look: the exe, or `bash engine/tools/world.sh visit compact_village` (F flies outside a game's plot); the
  character sheet: Godot ... res://rigs/review/review.tscn -- --sheet=<abs png> --sheet-set=line|back|front|run
  (TL_STYLE=classic for today's figure in the same poses).

5. CHANGED FILES
New:      engine/rigs/biped/tl_rig_biped_toy.gd (the figure's layout, the switch, the shared mesh per look)
          engine/rigs/biped/tl_rig_biped_clay.gd (the clay forms and the contact tone)
          engine/rigs/biped/tl_rig_biped_feel.gd (springs, squash, hand solve, idle)
          engine/rigs/review/figure_case.gd, engine/tools/selftest.d/590-figure.sh (figure.toy, .classic, .grip, .clay)
          engine/style/shaders/body_clay.gdshader
          (+ the .uid files Godot wrote beside the four .gd and the shader)
Changed:  engine/rigs/tl_rig_biped.gd (+2 lines net, 599 of its 600-line budget: the switch and four one-line hooks)
          engine/rigs/tl_rig_node.gd (attach a built mesh; bone index and rest rotation looked up once: same values)
          engine/rigs/tl_rigs.gd (the runtime param `grip` in RUNTIME's text)
          engine/rigs/review/review.gd (the character sheet: --sheet, --sheet-set, --cam)
          engine/rigs/RIGS.md (a section on the toy figure)
          engine/style/style_diorama.json (the `_figure` block, 8 lines: the only edit outside the character files)
Not touched: every kernel file, every pack, every seed, tl_style.gd, toon.gdshader, the kit, contracts.

6. BEHAVIOUR CHANGES, AND TWO THINGS THE OWNER SHOULD KNOW
- Under the diorama style every TLRigs biped is the toy. Under classic nothing changes.
- A new runtime rig param `grip` ({at, along} or null). No pack needs it: unset, the toy reads its controller.
- No test expectation was moved and no test was loosened. Block 590 is new (4 cases).
- The toy's mesh has two surfaces. The world's far tier draws a distant figure as a small mark and takes its colour
  from surface 0 of the figure's largest mesh, and only if that surface carries the style's palette material
  (kernel/world/draw/draw_life.gd). A figure all in clay would have been a grey mark. So surface 0 is a 5 cm lump of
  the jacket's (or the team's) colour inside the chest on the palette material, and surface 1 is the figure in clay.
  A far toy is a mark in its jacket's colour. Cost: one draw call per figure. Seen by eye: the next point.
- In my first diorama village stills from the crane cameras the walker plot had no figures on its pad, where the
  classic stills had two. That was not the figure: the world log says the walker pack was built at tick 8 in the classic
  tour (00:07, quiet machine) and at tick 354 in the diorama tour (02:10, 20 Godot processes), after the shots at ticks
  200 and 305. The build queue runs on the wall clock, the shots on ticks. I ran both tours again back to back (03:50 and
  04:03): the packs arrived before the shots in both, and the stills on the sheet are from that pair. The walker
  plot's two far figures are there in both; the classic marks are dark brown, the toy's are its jacket's red (stills/
  classic_01_walker_road.jpg, diorama_01_walker_road.jpg, the two _08_parkour_above.jpg). So the hidden surface does
  what it is for. If a pack with figures seems to arrive late in the diorama exe, look at the first build of a toy
  variant (250 ms against 62 ms, on the queue's worker thread: measured there at 257 ms walker, 251 ms skater, 5 ms
  for a repeat; classic 81, 67 and 67 ms) before looking anywhere else.

7. WHAT STILL DOES NOT READ AS DIORAMA (honest)
- Proportions. The target is about 2.4 heads tall with legs a third of its height; mine is about 3 heads tall with
  long legs, because the skeleton (hips at 0.98 m, 0.84 m legs) is a rail: the gait, the ledge reach and the wings are
  built on it. A truly squat toy needs a second skeleton and a gait retuned for short legs: a lane of its own.
- The ink contour is still drawn round the figure and the world's shade is violet with hatching: both are other
  pillars' (PATCHES.md asks for ink.body_k near 0 and a warmer shade). In my stills the toy stands in today's world.
- No contact darkening under the boots (frame pillar: AO or contact shadows).
- The collar and the cuffs are rigid: 29 bones leaves none for them. Only the bun and the head have secondary motion.
- The contact tone is baked in the rest pose: with an arm raised, the trunk keeps the shade the hanging arm pressed
  into it. It is faint (strength 1.5) but it is there in the cheer and hang poses.
- Skaters got the look but not the feel: no springs, no squash, and the left hand on the stick is still posed by
  angles. I built the stick solve and took it out: it costs a skeleton update per skater per frame, and hockey's frame
  budget has nothing to spare (section 3).
- Fingerprints and hair marks fade out at gameplay distance by design; from the visitor's camera the clay reads
  through form, chips, cuffs and the soft terminator only.
- Hands are bare skin (the target's hands are the colour of its ears); boots are the palette's dark brown and go
  violet-black in shade, where the target's are a warm mid brown (palette: surfaces pillar).
- I judged motion from frame strips, not from watching the clip play: I cannot see video. The owner's eye on clip.mp4
  is the first real judgement of the feel. One thing I saw in the clip's frames and could not place: faint pale
  streaks on the ground just under the boots while he walks away from the camera. I recorded the same
  walk under classic to see: the classic figure has the same streaks in the same frames. They are the world's, not the
  figure's (the play-distance pair on the contact sheet shows both).

8. COST PER NEW GAME
Unchanged: a game still writes TLBiped.create({...}) and names palette keys in rig_params.colors. It gets the toy under
the diorama style without a line. First build of a look is slower (250 ms once per variant, on the build queue's
thread), every further figure of a look is faster (4 ms against 62 ms).

9. QUESTIONS FOR THE DIRECTOR
1. `_figure` or `figure`? See PATCHES.md, Director 2: one word in TLStyle.SECTIONS makes it a proper section.
2. Hockey's invariants.many_budget is at 0.99 of its 1.0 ms budget on diorama-base on a quiet machine and over it under
   load with either figure. Is the budget or the pack the thing to fix? Neither is mine.
3. A second, squat skeleton for the diorama (short legs, big head) is the next real step for this pillar. Wanted?
4. draw_life.gd's mark colour knows the palette material only. My hidden surface works with it; a line there that
   accepts any style shader with a palette lookup would let it go (PATCHES.md, surfaces).

10. THE NEXT THREE THINGS THIS LANE WOULD DO
1. A squat skeleton variant with its own gait tables and grip reach, behind the same style key.
2. The left hand on the stick with hand-written forward kinematics (no skeleton update), and a cheap skater squash.
3. A collar and cuff follow-through without bones (a vertex-shader lag keyed to the piece), and contact tone that
   follows the arms (two bakes blended by the upper arm's angle).
