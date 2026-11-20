FRAME-FABLE: REPORT (night of 20 Nov 2026, the toy-diorama duel, pillar "frame", arm Fable 5.2)
Worktree .claude/worktrees/n20-frame-fable, branch diorama-frame-fable, on diorama-base 781d32b. Nothing committed (the
Director lands). State at the end: every gate the brief names is green on the frozen tree except
the whole full tier, where the kernel selftest step was stopped at its 30 minute limit (run alone it gives 329 passed,
0 failed); the worktree runs, the exe is built and checked, no process of mine is left.

WHAT I BUILT, AND WHY IT READS AS A DIORAMA
A cel drawing is held together by its line. A model on a table is held together by light: where a thing stands on
another it is dark, the lamp is warm and low, the backdrop is a painted board, and a lens that close cannot keep
everything sharp. So the frame drops the drawn contour under the diorama style and builds those four things. All of it
is keyed in engine/style/style_diorama.json; a key that is absent means the classic behaviour, and style.json has none
of the keys.

1. Sky: a painted board and cotton puffs (engine/style/shaders/sky_diorama.gdshader, key sky.shader).
   - The board: violet to pink to orange, a wide warm wash on the sun's side, short horizontal brush strokes. The
     strokes are noise of the view direction, so they are fixed to the backdrop and never crawl.
   - The clouds: each is a clump of seven balls with a flattened base. A ball is a height field, so every cloud pixel
     has a normal: it is lit from the sun's side, warmed from below, darker in the folds between balls, and its edge
     is frayed by fine noise. They hang in three rows over the horizon and do not move (a backdrop is painted once;
     sky.cloud_drift > 0 moves them).
   - The vertical seam is gone, measured: the clouds live in cells with a whole number of columns round the horizon.
     Case style.frame_seam looks across azimuth pi: the classic sky jumps 6.6 times the 90th percentile of all
     columns there (the cut), the diorama sky 0.12 times.
2. Light: a low orange sun with a size.
   - sun.color #ffb878, elevation 24 degrees, energy 1.0: the road and the timber glow orange as on the board.
   - sun.angular 0.5 degrees with sun.soft_quality 3: the engine's penumbra search. A shadow is tight at the post that
     casts it and softens with distance. (How much of that softness reaches the picture is in "what still does not
     read", item 1: the toon material cuts it into two steps.)
3. Contact shade in place of the ink line (engine/style/shaders/ink_post_diorama.gdshader, key ink.shader).
   - Tight contact shade (0.4 m) where boots, posts, cones and scaffold feet meet the ground; a wide soft shade (1.4 m)
     in corners and under things; a soft dark seam in concave creases. No contour.
   - It is a smooth gradient over the picture in a warm plum (ink.ao_color), not the classic two flat steps.
   - 32 depth taps on two spirals, turned per pixel by a fixed screen pattern. With one fixed spiral a thin fence post
     threw a row of sharp copies of itself on the ground (seen on the first road still, fixed). The pattern does not
     change between frames.
4. Grade: a photograph of a model under a warm lamp (engine/style/shaders/grade_diorama.gdshader, key grade.shader).
   - No paper, no fibre, no print grain. The dark end is pulled to warm plum, a soft S curve, vibrance, a round vignette.
   - grade.green_keep 0.34: the orange sun turns grass mustard; where green leads red and blue is low, red is taken
     down, so grass and pines stay green while the road stays orange. The road, timber, the yellow sign, skin, clouds
     and sky are outside that hue range (checked on the parkour, seed_wall and seed_drive stills).
5. The lens: tilt-shift depth of field with a rule for play (engine/style/frame/tl_style_frame.gd, key env.lens).
   One node under the style rig looks, every physics frame, at the camera the viewport draws with:
   a. A camera that follows a subject (TLChaseCam, TLOrbitCam, the visitor's camera: anything with `target`, or the
      meta `tl_lens_subject`) focuses on the subject. Nearer than 0.18 x the focus distance is fully blurred, the blur
      is gone by 0.6 x; behind him it starts at 2 x the focus distance plus 22 m, so what he runs towards next stays
      sharp, and it grows over 600 m, so the crane and the mesas keep their silhouettes.
   b. It is scaled down by the subject's speed (full to 9 m/s, none from 15: a car at speed), by the camera's distance
      (full to 14 m, none from 26: an overview), and by the camera's own say (meta `tl_lens`, 0..1).
   c. FLIGHT: the visitor's camera says 0 while he flies (engine/kernel/world/terrain/crown_camera.gd eases it over
      half a second and back after landing). A flyer reads the whole land: nothing is blurred.
   d. HOCKEY OVERVIEW and every other fixed view of a game (TLCameras.add_view) has no subject: never blurred.
   e. A camera that is neither (the world's crane, a review scene) is a presentation: looking down on the land by more
      than 25 degrees it gets the photographer's band (sharp in a level band, blurred to the top and bottom edge, drawn
      by the grade shader); looking level it blurs only what is within 2 m of the lens and the backdrop from 100 m on.
   The rule is a case: style.frame_lens drives the node with seven cameras and reads what it decides.
   The HUD is not blurred or graded (it is drawn above both layers; see the parkour and hockey stills).

THE HARD RULES, EACH WITH ITS EVIDENCE
1. No pack file changes, v1 API kept: MET.
   - git status: three tracked files modified (engine/style/tl_style.gd +4 lines, engine/style/style_diorama.json,
     engine/kernel/world/terrain/crown_camera.gd +11 lines); nothing under engine/packs/** or engine/seeds/**.
   - tl arch: PASS 12/12 rules; api-v1 "kernel API 1.11: 43 classes, 658 members"; api-index-fresh PASS.
     No public member was added. (My first placement, engine/style/tl_style_frame.gd, FAILED api-v1 as "new class":
     every .gd directly in engine/style is public surface. The script now lives in engine/style/frame/.)
   - Palette: the same 100 keys in the same order (case style.frame_keys). In style_diorama.json only the sections
     sun, env, fog, sky, ink and grade differ from diorama-base; name, toon, holo, water, palette, mat, detail,
     lights and fx are identical (compared key by key against `git show diorama-base:...`).
2. Classic stays exact: MET. The same shots under TL_STYLE=classic before any change (23:35) and on the frozen tree:
   - 24 pictures compared pixel by pixel (16 tour shots, parkour frame 520, hockey frame 1500, two review close-ups,
     four frames of the flight movie): 16 are bit-identical (max difference 0), among them 11 of the 16 tour shots,
     the parkour run, both close-ups and two flight frames.
   - The other 8 differ in 118 to 2,296 pixels (0.006 to 0.111 % of the picture), and every differing pixel lies on
     a game's plot where something moves: the walker plot's court and strip with its figures (five tour shots), a
     second court's figures (one of those tour shots and one flight frame), a venue on the far horizon (one flight
     frame), and specks beside two hockey skaters. I marked the differing cells on all eight and looked;
     classic-proof.jpg shows three of them as before | after | mask.
   - Control: two classic runs of the SAME tree (00:15 and 00:25) differ from each other in the same shots by the
     same kind of amount (6 of 18 pictures, 82 to 3,182 pixels, the same boxes), and one of those runs matched the
     baseline in 16 of 18. My reading: the games on the plots arrive from the world's build queue a tick earlier
     or later from run to run, and hockey draws a few specks beside its skaters that are not seeded. I did not
     trace either to its line of code; what is measured is that two runs of one tree differ exactly this way.
   - So: outside those spots every pixel is identical before and after: sky, clouds, land, shadows, ink, grade. The table is
     .tl/n20/classic_proof.txt (raw PNGs under .tl/n20/classic0 and .tl/n20/final_c in the worktree).
   Case style.frame_rig (windowed) holds it from now on: classic installs sky / ink_post / grade, no lens node, a sun
   without size, no camera attributes; and again after the diorama was installed on the same host.
3. No game's state hash moves: MET.
   - tl check --tier full --only world: PASS [8/8] "8 games: world = alone", on the frozen tree, with the same line as
     the first run of the night and as the line recorded on main yesterday (docs/shifts/2026-11-19-day/lanes/editor/
     REPORT-round4.md): seed.drive a2940a1735bc2b72@3441, seed.wall d5aea03b46c33ee6@1220, seed.paddle
     dff1a390470352e7@4486, example.walker f1c7b53757c34040@371, example.kit ca698e71d34d1021@332, example.car
     3a459d0fe25e7853@1872, game.ice_hockey_three_against a29dcdf02a16dd1c@4186, game.parkour f7abac006a45bd43@988.
   - Against a pristine copy of diorama-base (git archive of engine/ and assets/ into .tl/n20/base, its own class
     cache): the state hashes of the 8 games of boot/games.json, smoke and bot, seed 1, are identical, 16 of 16 lines
     (.tl/n20/hash_base.txt against hash_mine_final2.txt; run at 00:25, 01:41 and, on the frozen tree, 04:24).
   - The exe check runs 10 games (the 8 and two site games) 4000 world ticks in the editor binary, the exe and a
     copied exe: 10 of 10 "same".
   - Why it cannot move: the style rig is not built headless, the lens node never exists there, and the one kernel
     edit (crown_camera.gd) writes a meta on a camera.
4. Cache keys: not applicable. No geometry generator was touched (kit, terrain, crowns); PIC_VERSION is unchanged.
5. Performance:
   Windowed, `node devx/bin/tl.mjs perf run --scenario tour6 --no-record`, 1920x1080, RTX 4090. The machine was BUSY in
   every run (the tool's own word: use 61 to 100 %; the other arms were shooting too), so nothing was recorded in
   the ledger and these are busy figures:
   - classic   gpu_ms 1.212, 1.212, 1.202
   - diorama   gpu_ms 1.825, 1.757, 1.817, and one run at 3.349 (one tour of the shot set also read 3.18)
   That is +0.6 ms (+50 %) in the usual run: not a doubling. The two high readings ARE a finding and I cannot explain
   them: the perf one came at 87 % machine use, and classic never showed one (three perf runs and two tours at 1.23).
   The shot-set tours of the night read 1.47 and 1.49 before the shade pass got its 32 taps, then 1.83 and that
   3.18. It needs a quiet machine before anyone concludes anything from it.
   Where the 0.6 ms goes (a scratch style with one part switched off, one busy run each): without the contact shade
   pass 1.387; without the lens 1.736; with a sun without size 1.722; with the classic sky shader 1.812. So the shade
   pass is about 0.4 ms and the rest about 0.2 ms. The lens and the penumbra are inside the noise in this scenario; I
   did not check how many of tour6's frames follow a subject, so the depth of field's cost in play is not separated
   here. frame_ms_p50 went from 2.85 to 3.14 in the first pair of runs (simulation and drawing).
   All of this is one RTX 4090. The shade pass (32 depth taps a pixel) and the depth of field are per-pixel work and
   will weigh more on a small GPU; that was not measured.

GATES
All on the frozen tree (last engine edit 02:04, a shader comment) unless a time says otherwise.
1. node devx/bin/tl.mjs check --tier fast (02:11, and again as the last thing at 05:13): PASS, 5 of 5 steps.
     PASS arch [12/12] 12 rules; PASS assets [4/4]; PASS cards [3/3] 4 cards;
     PASS devx.test [229/229] 229 pass, 0 fail across 17 files; PASS foreman.typecheck (tsc --noEmit clean)
2. node devx/bin/tl.mjs check --tier full --only world,packs,kit.selftest: run four times in the night.
     00:20  PASS world [8/8]; PASS packs [2/2] found 2, completed 2, verb runs 48 of 48; PASS kit.selftest [95/95]
     01:05  PASS world [8/8]; PASS kit.selftest [95/95];
            FAIL packs [1/2] verb runs 47 of 48: hockey invariants.many_budget: frame p50 1.070 ms (budget 1.0 ms)
     01:30  (packs alone) FAIL packs [1/2], the same check: frame p50 1.084 ms
     02:40  PASS world [8/8]; PASS packs [2/2] found 2, completed 2, verb runs 48 of 48; PASS kit.selftest [95/95]
            (this is the run on the frozen tree; its world and packs lines are the same text as at 00:20)
   The check that failed twice is a wall-clock budget of the headless simulation (no style is built there). While it
   failed I ran that one verb alone on the pristine copy of diorama-base and on my tree, twice each, alternating:
   base 0.968 and 0.974 ms, mine 0.930 and 0.942 ms, against the budget of 1.0. Hockey sits at the edge of that budget
   on this machine tonight with or without my change; inside the gate, beside its other verbs, it tipped over twice.
   Two FAILs are two FAILs: I report them and do not count them as passes.
3. bash engine/tools/selftest.sh style. (02:52): 7 passed, 0 failed. My block 570 is four of them:
     PASS style.frame_keys  classic has 0 of 6 frame keys; diorama names 3 shader files, all there; 0 messages;
                            21 lens keys, all known; palette order kept (100 keys)
     PASS style.frame_lens  subject at 8 m: gain 1.00 focus 8.0 m; camera says 0: 0.00; subject at 30 m/s: 0.00;
                            40 m away: 0.00; game view: 0 and band 0; crane looking down 60 deg: band 8.0 px,
                            depth 0.00; at 8 deg: band 0.0, still depth 1.00; named subject at 5 m: focus 5.1
     PASS style.frame_rig   classic: sky ink_post grade lens=no sun=0.0 attrs=no | diorama: sky_diorama
                            ink_post_diorama grade_diorama lens=yes sun=0.5 attrs=yes | classic again: as before
     PASS style.frame_seam  middle column against the 90th percentile of the others: classic 6.6 x (the cut),
                            diorama 0.12 x
   (keys and lens run headless; rig and seam need a picture and take the machine's window lock.)
4. bash engine/tools/export.sh --commit 781d32b --out .../dist/arms/frame-fable/ThirdLife: PASS export.build: tag
   781d32b 2026-11-20 03:16. export.sh check: PASS export.check: build '781d32b 2026-11-20 03:16'.
5. node devx/bin/tl.mjs check --tier full (the whole tier), 03:12 to 04:20: FAIL (exit 1), because one step was
   stopped. 12 steps PASS, 1 NOT RUN, 1 FAIL:
     PASS arch [12/12]; PASS assets [4/4]; PASS cards [3/3]; PASS devx.test [229/229]; PASS foreman.typecheck;
     PASS foreman.test [223/223] 217 pass, 0 fail, 6 skipped; PASS kit.selftest [95/95];
     PASS packs [2/2] found 2, completed 2, verb runs 48 of 48; PASS seeds [39/39]; PASS item.selftest [91/91];
     PASS ui.selftest [166/166]; PASS world [8/8]
     NOT RUN perf: could not run: machine BUSY (use 71 %, probe 0.938): measured but not judged and not recorded
     FAIL kernel.selftest [81/82]: completed 81 of 82 units found; selftest: 0 failed, 81 passed; timed out after
          1800 s and was killed
   A stopped run is not a pass. Nothing failed inside it; it ran out of its 30 minutes.
   So I ran the suite by itself with a time stamp on every line (bash engine/tools/selftest.sh, .tl/n20/
   selftest_all.txt), 04:22 to 05:12 on the frozen tree: "selftest: 329 passed, 0 failed". It took 50 minutes on
   tonight's machine, against the gate's limit of 30. In that run case 82 is world.tour, a windowed proof that waits
   for the machine's window lock; that is the case the gate was in when it was stopped. My block is the last of the
   suite and its four cases are among the 329.
   What I can and cannot say: every case of the kernel selftest passes on this tree when the run is not stopped; the
   gate step kernel.selftest itself did NOT pass tonight, and I have no run of it on diorama-base under the same load
   to compare its duration with.
6. selftest rig.: the character pillar's gate; I did not run it on its own.
7. perf: see rule 5 above. `tl perf run` PASSed every time but recorded nothing (machine BUSY): that is a figure, not
   a gate result.

DELIVERABLES (docs/shifts/2026-11-20-night/lanes/frame-fable/)
- contact-sheet.jpg: the target board beside my best village frame, then the fixed shot set as classic | diorama pairs
  (village from the road and from above, on the road and at the parkour yard in play, the flight over the bluff, the
  parkour run, the hockey rink, seed_wall and seed_drive, the character close-ups), then four stills "with PATCHES".
- stills/: the same frames as single JPGs (classic_*, diorama_*, patched_*).
- best-frame.jpg: the frame beside the board on the sheet at full size (frame 400 of the clip: the parkour yard gate).
- classic-proof.jpg: three of the boxes in which classic before and after differ, with the mask of differing pixels.
- clip.mp4: 20.0 s, 1280x720, 60 fps, 1201 frames, 14.8 MB (clip-strip.jpg: eight frames of it). He walks the
  village road, runs, turns into the parkour yard, takes off at its edge, flies over the yard and north-east to the
  bluff, then east along it. Recorded in a
  window with the movie writer: world.sh visit-test frame_clip.walk.json --devices=frame_clip.devices.json (both in the
  lane folder). A take-off inside a plot is put back at the plot's gate (the flight lane's rule), so he takes off at
  the yard's edge and crosses it above 12 m.
- The exe: C:/Users/kazda/kiro/third-life/dist/arms/frame-fable/ThirdLife/ThirdLife.exe (PLAY-LATEST.cmd beside it).
  PASS export.build: tag 781d32b 2026-11-20 03:16 (built from the frozen tree; --commit 781d32b is HEAD, my changes
  are uncommitted on top of it). PASS export.check: 10 of 10 games the same hash in the editor binary, the exe and
  the copied exe; the exe shows the village (stills/exe_first_frame.jpg is that picture), obeys W and Esc and leaves
  no process. The check's own note: "E and Q: NOT SHOWN (no game came on stage ...). Not counted."
- PATCHES.md and PATCHES.toon.json: what the other pillars should do.
- STANDUP.md, this report, frame_clip.walk.json, frame_clip.devices.json.
How the shots were made: the tour (world.sh tour blend_views.walk.json --pictures-only), the flight (world.sh
visit-test wf_flight.json --devices=clip.devices.json with TL_WINDOW_ARGS=--write-movie, frames 30 and 660), tl.sh
capture for parkour (bot_course, orbit, frame 520, 1280x720, hud on) and hockey (bot_hockey, arena, frame 1500), and
rigs/review/review.tscn (--view=vclose walking, --view=three standing, frame 120 of a movie). Raw frames and movies
are under .tl/n20/ in the worktree.

CHANGED FILES
Modified (3):
- engine/style/tl_style.gd: +4 lines. A preload of the frame script and one call at the end of install().
- engine/style/style_diorama.json: the sun, env, fog, sky, ink and grade sections (values, and the new keys
  sun.angular, sun.soft_quality, env.lens, sky.shader and the cloud / brush keys, ink.shader and the shade keys,
  grade.shader, shadow_tint, light_tint, tint, green_keep).
- engine/kernel/world/terrain/crown_camera.gd: +11 lines. The visitor's camera tells the lens 0 in flight (a meta).
New (6, plus the .uid file the engine writes beside each):
- engine/style/frame/tl_style_frame.gd: which shader a layer uses, the sun's size, the lens node. Its header is the
  reference for every key.
- engine/style/shaders/sky_diorama.gdshader, ink_post_diorama.gdshader, grade_diorama.gdshader.
- engine/style/cases/frame_case.gd and engine/tools/selftest.d/570-frame-diorama.sh: four cases.
Not touched: toon.gdshader, the palette, any kit, rig, pack, seed, contract, tl_chase_cam.gd, tl_orbit_cam.gd,
tl_cameras.gd (the lens reads the `target` those cameras already have; no hook was needed in them).

BEHAVIOUR CHANGES (diorama style only; classic has none)
- No ink contour. Thin members (fences, lattices) are plain coloured bars with shade at their feet.
- Depth of field in views that follow a subject; a band blur on the world's crane when it looks down.
- The sky does not drift.
- The visitor's camera carries the meta `tl_lens` (1 on foot, 0 in flight). Nothing reads it under classic.
- No test expectation was moved and no test was loosened.

COST PER NEW GAME
Unchanged: none. A game still names palette keys, places kit parts and makes its character and cameras through the
same calls. It gets the sky, the light, the contact shade and the grade without knowing. The lens decides from the
camera the game already made: a chase or orbit camera is focused on its target, a fixed view is left sharp. A game
that wants no blur on a following camera writes one line, `cam.set_meta(&"tl_lens", 0.0)`; none of the eight games
needed it. Nothing a builder makes today (faceted code primitives) has to change shape for this frame.

WHAT STILL DOES NOT READ AS DIORAMA (honest)
1. Shadows are not soft yet in this worktree. The sun's penumbra is there, but the toon material cuts the light into
   two bands 0.03 wide, so a far shadow shows a dark core and one lighter fringe instead of a gradient. The cure is one
   value in the section I do not own (toon.band_soft): PATCHES.md item 1. The "with PATCHES" stills show the result.
2. The hatch in every shade and the blue-violet shade colour are still cel drawing (toon section: PATCHES 2 and 3).
   The grade warms the dark end, but a saturated blue shadow on grey tarmac stays blue (seed_drive still).
3. Surfaces are flat faceted colour. Board 4's light rakes across felt, grain and fingerprints; here it has nothing to
   rake across. That is the surfaces pillar. The contact shade reads the normal buffer, so it will follow whatever
   relief they write.
4. Grass: the road now measures #d38632 against the board's #e9873c, but my lit grass (#93a827 to #a49c24) is greener
   and lighter than the board's olive-brown (#9f7720 to #b27d24 near the camera). The pigment is too light for the
   orange sun; the grade's green_keep holds it green rather than letting it go mustard (PATCHES 4).
5. The contact shade is screen space. It has no source outside the picture, reaches 1.4 m (the ground under a
   platform 1.5 m up gets little), puts a dark smudge under tall grass tufts close to the camera, and is finely
   dithered (visible when a still is enlarged 4 x; not at 1 : 1). There is no blur pass behind it.
6. The clouds are painted on the dome. They have no parallax in flight, cast no shadow and never come nearer.
7. The crane's band is a screen blur without depth: a tall thing that crosses the band's edge blurs at its top
   although it stands at the sharp distance (the crane tower in tour shot 16).
8. The level crane shots ("village from the road") have no near blur: the lens does not know what such a camera looks
   at. Board 4's blurred near rail appears only where a subject is followed (the road and yard frames, the exe).
9. The review scene's close-up gets no tilt-shift either, for the same reason (PATCHES 8: one line in review.gd).
10. Hockey from the arena camera is, by the rule, the least "miniature" view: no lens, purple-blue shadows on the ice.
11. Nobody has played it. Every frame here is from scripts and bots; the exe was started by the check, not by a hand.

QUESTIONS FOR THE DIRECTOR
1. If the surfaces arm that wins did not soften the toon bands, do you apply PATCHES.toon.json (five values) on top of
   it? Without them the frame's soft shadow does not show.
2. Should the tour's crane shots focus on their `to` point (a few lines in view.gd and one more meta in the frame
   script, PATCHES 10) so that "village from the road" stills also get the near blur?
3. The packs gate failed twice on a wall-clock budget while six arms loaded the machine (see GATES). Is that budget
   meant to hold on a loaded machine?

THE NEXT THREE THINGS THIS LANE WOULD DO
1. A blur pass behind the contact shade (a compositor effect): no dither, a wider reach, shade under platforms.
2. Cotton clouds as real puffs hung over the table edge (a handful of meshes), so they have parallax in flight and
   drop soft shadows on the land; the painted board stays behind them.
3. A focus hint for cameras without a subject (`ctx.cameras.focus(view, point)`, a kernel API minor) so that a
   game's fixed view and the world's crane can opt in to the lens at a chosen distance.
