FRAME, ASTRA ARM: REPORT (night of 20 Nov 2026, the toy-diorama duel)
Operator: Opus. Designer and builder: GPT 6.2 Astra via Codex (session 01a1f5ef-3455-7dd3-96e3-5c0094ca6799).
Worktree: .claude/worktrees/n20-frame-astra, branch diorama-frame-astra, on diorama-base 781d32b. Nothing committed.
What ships: Astra's round 2, verified by the operator from a snapshot of the tree and then restored into the
worktree (md5 of every file under engine/, devx/ and the lane folder equal to the snapshot).

ROUNDS
- r1 (23:31-00:52, 610k tokens). Astra got COMMON.md and the PILLARS frame section verbatim and the target boards.
  It built the cotton sky, the contact-shadow ink pass, the tilted miniature lens with camera focus hooks, and the
  warm low sun.
- r2 (01:38-03:06, 1.08M tokens in total). I passed back one measured failure and the lens figures. The failure: a
  hard-edged violet rectangle on the diorama hockey rink at f1500, x 383-693, y 397-651, RGB (173,154,224) against
  open ice (255,220,199). Astra traced it to the west scoreboard's shadow under the low sun. Overhead fixed play
  cameras now use short soft contact shadows. The lens now follows the aim point and the camera pitch. The cotton
  folds are broader.
- r3 (03:08-03:52) was stopped by me, and its files are not shipped. Each windowed capture was then waiting about
  10 minutes for the machine-wide window lock that six arms share. An r3 tree could not have had its own full shot
  set, clip and exe before 05:45, and Astra's own captures competed for the same lock. Its unverified work (an
  ink_post_penumbra shader, case 573 and style edits) is kept in .tl/r3-unverified/ in the worktree.

WHAT WAS BUILT AND WHY IT READS AS DIORAMA (all behind keys in style_diorama.json; absent key = today's behaviour)
- Sky (env.cotton_sky -> shaders/sky_cotton.gdshader): a painted rose and apricot sunset backdrop with brush
  marks (sky.brush 0.26). 27 hand-placed groups of cotton or wool tufts, each with a cream crown, a warm underside
  and a soft fold roll. The painted sun disc sits beside the mesas (sun_draw_elev 6, sun_draw_yaw 34). Each tuft
  has its own tangent frame, so there is no longitude seam.
- Light (sun): a low, warm, raking key light: elev 23 deg, azim -91, colour #ffcb98, energy 1.24. It has a finite
  angular size (0.65 deg) and soft-shadow filter quality 5 for a broad penumbra. A live switch back to classic
  restores the project's filter.
- Contact shadows (env.contact_only -> shaders/ink_post_contact.gdshader): a short-range depth-and-normal pass
  that grounds boots, posts and scaffold feet in a cocoa contact shade (ink.ao_color #382a35, ao_k 0.78,
  ao_radius 0.7 m, ao_far 85 m). Overhead fixed play views (cameras within 20 deg of straight down) swap the
  directional shadow for a short soft tabletop contact (ink.tabletop_reach 3.6 m, tabletop_opacity 0.47). The
  ink contour of classic is not drawn in diorama: the board has no outlines.
- Grade: a gentle miniature grade: a split towards warm highlights and cool violet shadows, sat 1.105, contrast
  1.135, vignette 0.13, grain 0.004, linear tonemap at exposure 0.89, and lower fog and aerial haze.
- Tilt-shift (env.miniature_lens -> TLStyleFx.MiniatureLens + shaders/dof_tilt.gdshader, camera hooks
  _miniature_focus in tl_chase_cam, tl_orbit_cam, crown_camera and tl_cameras):
  - A grounded chase, orbit or visitor camera keeps a focus plane through the actor's look point, tilted -15 deg
    against the tabletop and corrected for camera pitch. The figure and the next foothold stay sharp; the near
    rail and the far meadow soften (near_px 5.0, far_px 1.5 at 1080p, amount 0.023).
  - Flight: the active target's flight state turns both blur ranges and the tilted pass off. It is deep focus;
    the grounded setting returns on landing.
  - Named fixed play cameras (the hockey arena) are deep focus, and the HUD-measured skater never pulls focus.
  - Untracked scenic and review cameras get only low foreground softness within 27 m and a far fall-off from
    125 m (transition 180 m, amount 0.013).
  - A camera with its own attributes keeps its own focus.
  - How the camera mode is decided: by the active camera's type and target state, every render frame. There are
    no per-game settings.

RULES, EACH WITH ITS EVIDENCE
1. No pack file changes.
   - git diff touches nothing under engine/packs, engine/seeds, contracts/ or engine/style/style.json (0 files).
   - The palette keeps its 100 columns, the same keys in the same order with the same values. The changed sections
     of style_diorama.json are sun, env, fog, sky, ink and grade only.
   - Kernel API: the additions are presentation methods on the cameras (_miniature_focus, an inner FixedPlayView
     class in TLCameras); every v1 signature is kept. tl arch PASS 12/12, which includes api-v1.
2. Today's look stays exact (TL_STYLE=classic). I captured classic before Astra's first edit (git status clean
   before and after the capture) and classic again on the final r2 tree.
   - Measured run-to-run noise first: 13 shots are bit-exact between runs (tour pictures 11-16, flight frames 420
     and 900, parkour f520 and four rig images). The other 10 move with live games, up to 237/255 in under 3% of
     pixels, even between two classic runs of the same tree.
   - Result: all 13 bit-exact shots are 0/255 different before vs after. The noisy ones stay within their noise:
     hockey f1500 151/255 in 0.010% of pixels, against 0.013% between two pristine runs.
3. No game's state hash moves. I gated a pristine archive of diorama-base (.tl/opbase, its own class cache) and
   then the r2 tree.
   - Base: PASS world 8/8 and PASS packs 2/2 (48/48 verb runs).
   - r2 tree: PASS world 8/8, PASS kit.selftest 95/95, and all 56 rows (46 pack verb hashes with frame counts plus
     8 world hashes) are identical to the base.
   - packs reported FAIL on one timing check only: hockey invariants.many_budget p50 1.026 ms against the 1.0 ms
     budget, at machine load 16. Right after, I ran hockey invariants alternately on base and r2, three times
     each: base 0.972 / 0.990 / 0.955 ms, r2 0.992 / 0.970 / 0.949 ms, all PASS. The failure is machine load, not
     this change. A gate step that fails is still not a PASS: the packs step needs a re-run on a quiet machine.
4. Cache keys: no geometry generator (kit, terrain, crowns) changed, so PIC_VERSION is not bumped.
5. Performance (perf.tour6, windowed, machine busy, not recorded): gpu 1.500 ms diorama vs 1.199 ms classic, +25%.
   - first_frame 1287 vs 861 ms: the sky radiance bake at 512 / quality.
   - draw calls 370 vs 371, primitives 1.51M vs 1.41M.
   - Astra saw one earlier busy pair at 2.915 vs 1.347 ms, a doubling, which it did not reproduce; my pair did
     not reproduce it either. Treat it as a finding to re-measure on a quiet machine.

OTHER MEASURED CLAIMS
- Cloud seam gone. In the flight frames, the column x=959 jumps by more than 6/255 in 40.1% (f700) and 54.3%
  (f900) of sky rows in classic, and in 3.0% and 11.6-13.2% in diorama (the residue is cloud or mesa edges).
  Crops: .tl/r1/seam_crops.jpg.
- Lens against a no-lens control: the same diorama style with env.miniature_lens removed. Detail is the mean
  |laplacian| of luma per third of the frame.
  - Parkour f520 orbit, r2: runner band 0.94-0.95, near band bottom-centre 0.56, far top-centre 0.48.
  - Hockey arena: 1.00 everywhere (deep focus).
  - In r1 the near band stayed at 1.00; r2 fixed that.
- Flight in the clip is sharp: a full-resolution crop at clip frame 1300 shows crisp grass dots on the near bluff
  (.tl/r2/f1300_crop.jpg).
- Hockey after the r2 fix: the rectangle is gone (selftest style.frame.rink: west (255,221,201), east
  (254,217,197)). The skaters' long cast shadows are mostly gone too: blue-violet shadow pixels on the ice are
  178k in classic and 36.5k in diorama. Judge whether the rink reads too flat.

GATES (operator runs on the r2 tree)
- check --tier fast: PASS arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck clean.
- check --tier full --only world,packs,kit.selftest:
  - PASS world 8/8 and PASS kit.selftest 95/95.
  - FAIL packs: 47 of 48 verb runs passed. The one failure is the hockey many_budget timing under load 16; see
    rule 3 for the A/B.
- selftest style.: 7/7 PASS (walker.ink, first_reject, switch, frame.focus, frame.rig, frame.pixels, frame.rink).
  The frame block is 570-572.
- export.sh build: PASS export.build: tag 781d32b 2026-11-20 03:55.
- export.sh check: PASS export.check. Same hashes as the editor binary, the village shows, it obeys W and Esc,
  and nothing is left running.
- check --tier full (every step, r2 tree, 04:08-05:00, machine busy): exit 1, so not a pass.
  - PASS: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck, foreman.test 223/223 (217 pass,
    6 skipped), kit.selftest 95/95, seeds 39/39, item.selftest 91/91, ui.selftest 166/166, world 8/8.
  - FAIL kernel.selftest: 84 of 85 units completed and passed, 0 failed. The run was killed at the 1800 s timeout
    with one unit not run. That is a stopped run, not a pass. The frame cases (570-572) passed separately in
    selftest style. 7/7.
  - FAIL packs: again only the hockey many_budget timing, p50 1.260 ms at use 96%.
  - NOT RUN perf: machine BUSY (use 96%).
  - Before landing, re-run kernel.selftest, packs and perf on a quiet machine.

DELIVERABLES (lane folder docs/shifts/2026-11-20-night/lanes/frame-astra/)
- contact-sheet.jpg: board 4 beside the diorama village road, then 11 classic|diorama pairs: village road, from
  above, the parkour plot from the road, the bluff from the road, flight climb, over the village, along the bluff,
  parkour run f520, hockey rink f1500, character close-up, character three-quarter.
- stills/: the 22 single JPGs of those pairs.
- clip.mp4: 22.85 s, 1280x720, windowed, diorama default.
  - The walker runs west on the village road with the parkour yard beside him and stops at the yard's fence and
    sign, facing the yard.
  - He runs back east, takes off, climbs to 25 m, flies north and turns east along the bluff edge.
  - Plots are walled: walking into the yard means entering the game (E), so the clip stops at the fence.
  - Reproduce: world.sh visit-test .tl/clip/frame_clip.walk.json --devices=.tl/clip/frame_clip.devices.json with
    TL_WINDOW_ARGS=--write-movie.
- exe: C:/Users/kazda/kiro/third-life/dist/arms/frame-astra/ThirdLife/ThirdLife.exe (tag 781d32b 2026-11-20
  03:55; BUILD.txt commit text "diorama-frame-astra: Astra r2 frame (uncommitted on 781d32b)").
- Astra's own notes: ASTRA-NOTES.md (settings, per-camera table, its measurements) and PATCHES.md.

CHANGED FILES
- Modified: engine/style/style_diorama.json (sections sun, env, fog, sky, ink, grade), engine/style/tl_style.gd
  (install: sky, lens, contact pass, shadow filter), engine/style/tl_style_fx.gd (MiniatureLens),
  engine/kernel/api/tl_cameras.gd (FixedPlayView, _subject_focus), engine/kernel/api/tl_chase_cam.gd,
  engine/kernel/api/tl_orbit_cam.gd, engine/kernel/world/terrain/crown_camera.gd (the _miniature_focus hooks).
  7 files, +239 / -110.
- New: engine/style/shaders/sky_cotton.gdshader, ink_post_contact.gdshader and dof_tilt.gdshader, each with its
  .uid; engine/tools/selftest.d/570-frame.sh, 571-frame-pixels.sh and 572-frame-rink.sh; the lane folder.
- engine/kernel/API.md is not updated: the camera additions are underscore presentation hooks, not public API.
  The Director may want a line.

PATCHES.md (what other pillars should do, from Astra)
- Surfaces:
  - The lavender bands in long road-height shadows come from the toon light function: it multiplies wrapped
    diffuse by ATTENUATION before the narrow paint bands. Shape the diffuse first, then blend ambient to lit
    paint with continuous shadow attenuation.
  - The diagonal hatch shows across cast shadows, cuffs and the sign face; felt nap, brush or grain in the
    material would give scale.
  - Do not double the sunset colour, contact shade, exposure or softness in a material: the frame supplies them.
- Character: the boots stay in the sharp interval during the walk. The lens needs no figure tags or sockets.

WHAT STILL DOES NOT READ AS DIORAMA (honest)
- The road and tour cameras frame the figure small. The board's big foreground figure with the yard right beside
  the road is a framing that no camera in the shot set has; the parkour yard sits across an open field.
- Grass, pines, rocks and timber are still the toon materials: smooth meadow patches, faceted rocks and pines,
  hatching, lavender shadow bands. This is the surfaces pillar's ground.
- In flight the painted backdrop stays put while the tufts move, so the clouds read as mounted tufts.
- Hockey from above loses most of its cast shadows (see the figure above). It reads cleaner but flatter.
- The diorama is still a filter on today's world, not yet "a miniature made by hand". Without felt and clay
  surfaces the frame alone gets the light and the mood of board 4, not its materials.

COST PER NEW GAME: unchanged. No pack asset, palette key, camera declaration or authoring step is needed. Focus,
the overhead contact and the flight deep focus are chosen from the camera type and the target state.

QUESTIONS FOR THE DIRECTOR
1. The packs step fails only on the hockey many_budget timing under load. Re-run --only packs on a quiet machine
   before landing.
2. Merging with a surfaces arm: the overhead contact pass replaces the directional shadow for top-down fixed
   cameras. Check that this still holds with the new materials.
3. r3 was stopped unverified (.tl/r3-unverified/). If the morning has a quiet machine, its penumbra pass is the
   next thing to verify.

NEXT THREE THINGS THIS LANE WOULD DO
1. A visitor camera framing closer to board 4 (a larger figure, the yard beside the road), as a lens-side option.
2. Verify the r3 penumbra pass (soft shadow edges) with the full shot set.
3. Parallax or slow drift for the painted backdrop in flight, so the tufts stop reading as mounted.
