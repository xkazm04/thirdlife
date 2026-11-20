SURFACES, FABLE ARM: REPORT (night of 20 Nov 2026, the toy-diorama duel)
Worktree .claude/worktrees/n20-surfaces-fable, branch diorama-surfaces-fable, on diorama-base 781d32b. Nothing committed
(no git that writes). State: done. The gates are green on their last run (05:08); the packs step was red in 3 of
its 7 runs tonight on one wall-clock budget that diorama-base fails too on a loaded machine (see GATES).
All figures below were taken on the tree as it stands. "busy" = five other arms loaded the machine all night.

HOW TO LOOK (two minutes)
- contact-sheet.jpg: board 4 beside this arm's road frame, then every shot as classic | diorama | preview.
  contact-sheet-pairs.jpg: classic | diorama only, larger. stills/: the same 26 shots as 1280x720 JPG per style,
  and stills/exe/: one picture of the exported exe under each of the three styles.
- "diorama" = this arm as it is. The ink and the paper are the frame pillar's and are untouched, so it is clay with
  a drawn contour. "preview" = the same tree with the frame's ink and paper off (PATCHES.md, frame 1 and 2): the
  surfaces as they are meant to be seen after the merge. It is a style file of its own (TL_STYLE=surfaces), never a
  retouched picture.
- clip.mp4 (the arm as it is) and clip-preview.mp4 (ink off): 16.85 s each, 1280x720, the same scripted visit.
- The exe: dist/arms/surfaces-fable/PLAY-LATEST.cmd (as it is), PLAY-SURFACES-PREVIEW.cmd (ink off),
  PLAY-CLASSIC.cmd (today's look, the same exe).

WHAT I BUILT, AND WHY IT READS AS A DIORAMA

One idea carries the pillar: every surface says what it is made of and that a hand made it, and it says so through
the light, not through a drawn line. Six things were built.

1. A material model beside the toon model, in the same shader file. `toon.model` = "diorama" in style_diorama.json
   compiles engine/style/shaders/toon.gdshader with TL_DIORAMA defined. One smooth ramp from shade to sun replaces
   the bands and the hatch. Every material class became a handmade material whose marks are HEIGHTS in the part's
   own space (land: the world's), turned into a normal for the light only:
   - clay (any key with no class): thumb dents, and fingerprint whorls that appear within a few metres;
   - wood: boards with a pressed joint, grain along the board, a tone per board; no joint down the middle of a post;
   - cast blocks (concrete): pitted, a tone per pour; painted metal and plastic (steel): smooth, a parting line;
   - rock, bluffs, mesas: slabs of clay pressed one on another, each slab rolled (its rim catches the sky, its foot
     turns away), knife marks along the slab, at any distance;
   - masonry, roof, tarmac, fabric (the quilting of the jacket is stitched, not inked).
2. Felt. Land is a sheet of felt laid on clay: flocking of short fibres lying three ways (no single direction, so
   it is neither a woven rug nor motion blur), a pile that catches light at grazing angles, a cut edge the low sun
   catches where grass meets road, and the dye of the sheet taken back at that cut so nothing looks sprayed. Pines,
   bushes, crowns and flags are felt (class `felt`, `fuzz`). The road is clay with crumbs and pebbles pressed in.
3. Soft edges, without one new triangle. A `TLMesh.box` now says in UV2 where each vertex is on its face and how
   large the face is; the shader rolls the last 7 cm of a face over by 45 degrees (`detail.bevel`), so two faces
   end on one normal and a block reads as rolled clay or sanded wood. A scaffold tube becomes a tube.
4. Round lumps, without one new triangle. A `blob` and the side of a `cyl` carry the round thing's own normal in the
   same channel; the shader lights them as round (`detail.round`) and takes back most of the tone each facet of a
   blob was given apart. Pine tiers, logs, posts, rocks, bushes and crowns read as one piece each.
5. Paint. `gloss` (a sun highlight and the sky standing in the surface), `chip` (brush strokes along the part, and
   chips that show the primer, first at the edges of a box): the striped beam, kerbs, signs, boards, cones. `wax`:
   the warm turn from sun to shade of modelling clay.
6. A resin river (engine/style/shaders/water_resin.gdshader, `water.model` = "resin"). Nothing flows. Combed ripples
   stand still in the world; the sky and the low sun stand in them and move as the eye moves, which is what resin
   does. With `water.shore` it reads the depth of its bed: the clay bank shows through the shallows, with a
   meniscus and dry-brushed foam at the waterline. It is never more than half a mirror, so it stays a river from
   the air.

Geometry, collision, physics and every pack are untouched: the facets are still there for the ink pass and for the
hashes; only the normal the light sees, and the albedo, changed.

THE GOALS OF THE PILLAR
- Clay and painted plastic for kit, buildings and bluffs, with fingerprint and tool-mark detail: MET (stills
  31_parkour_run, 07_parkour_road, 41_figure_closeup preview: whorls on the collar; mesas in every frame).
- Felt pines and bushes: MET in light and texture, NOT in silhouette (see "what still does not read").
- Grass as felt or flocking: MET (51_road_visitor, 13_lot_river_road).
- Wood grain with uneven paint, e.g. the striped beam: MET for grain, brush strokes and chips; the stripes' own
  edges are geometry and stay straight.
- Glossy resin water: MET (08_parkour_above, 14_lot_river_above, the clip at 13 s).
- Chipped paint at edges: MET on boxes (the beam, the red kerb of the platform), not on cylinders.
- Detail anchored in the world or the object, and it does not crawl: MET, measured (below).

THE HARD RULES, EACH WITH ITS EVIDENCE

1. No pack file changes; the kernel API keeps every v1 signature.
   - `git status --short engine/packs engine/seeds contracts`: empty.
   - `tl arch` api-v1: PASS, "kernel API 1.11: 43 classes, 658 members" (no member added: the helpers are
     engine/style/dio/style_dio.gd and engine/kits/tl_mesh_bake.gd, outside the indexed surface, reached through
     private constants); api-index-fresh PASS without regenerating docs/generated.
   - Palette: 100 keys, same names, same order as diorama-base (compared by script); 14 colours changed, none added.
   - Kit hashes: `TLMesh.content_hash` of a box, a rotated bar and a cylinder is c1a5ae1f297fb32f498f84cbeed5126cddc30809
     on a copy of diorama-base and on this tree (selftest surf.edges); UV2 is not hashed. kit.selftest 95/95.
2. Today's look stays exact (TL_STYLE=classic).
   - By construction: selftest surf.classic_source takes every TL_DIORAMA branch out of toon.gdshader and gets, byte
     for byte, the file of diorama-base (sha256 e3aad816ec7178361b08bf8da2a419fd7f8fe719eef8852aa70d476420f8c20f,
     558 lines; 407 more lines are diorama's). style.json, style_overcast.json and water.gdshader are not touched.
     surf.model_classic: under TL_STYLE=classic no key of the model is present, so TLStyle hands out the shader
     files as they are and the same lookup texture (row 3 gets 0 where it had 0).
   - By picture: the 16 pictures of the village tour under classic, a copy of diorama-base (git archive of HEAD,
     run from .tl/base) against this final tree, same command, 1920x1080 PNG, compared pixel by pixel:
       11 of 16 are identical bit for bit (max difference 0): 01, 05, 06, 07, 08, 11, 12, 13, 14, 15, 16.
       5 show a pack with something moving in it (02 walker above, 03 and 04 drive, 09 and 10 paddle) and differ
       in 0.03 to 0.95 % of their pixels. Two runs of diorama-base itself differ in the same 5, by the same
       amounts, and agree in the same 11:
         picture            base vs this tree (px over 1/255)   base vs base again
         02_walker_above    0.041 %                             0.037 %
         03_drive_road      0.125 %                             0.117 %
         04_drive_above     0.033 %                             0.032 %
         09_paddle_road     0.954 %                             0.903 %
         10_paddle_above    0.050 %                             0.052 %
       Taken with --load=block: with the queue of the command in COMMON.md the packs arrive when the machine lets
       them and the landscape itself comes out different from run to run tonight (seen: other mesas and bushes in
       two runs of the same tree), so that command cannot carry a pixel proof. A first pass at 00:23 gave the same
       result (the same 11 identical).
       Raw pictures: .tl/proof/base1, base2, after (PNG, not committed); the measure is .tl/cmp.py (max and mean
       difference per picture).
3. No game's state hash moves.
   - `check --tier full --only world,packs,kit.selftest`: PASS world [8/8] in all seven runs, and all 8 hashes are
     those of `world.sh alone` on a copy of diorama-base (compared line by line): seed.drive a2940a1735bc2b72@3441,
     seed.wall d5aea03b46c33ee6@1220, seed.paddle dff1a390470352e7@4486, example.walker f1c7b53757c34040@371,
     example.kit ca698e71d34d1021@332, example.car 3a459d0fe25e7853@1872, game.ice_hockey_three_against
     a29dcdf02a16dd1c@4186, game.parkour f7abac006a45bd43@988. The packs step printed the same bot hashes in
     its four green runs (hockey bot_hockey a29dcdf02a16dd1c@4186 and so on); its three red runs are a time budget,
     not a hash (GATES).
   - The exe: export.check PASS, 10 games to the same hashes in the editor binary, the exe and the exe moved.
4. Cache keys: PIC_VERSION 15 -> 1601 (draw_base.gd). Pictures now carry UV2. 1601 and not 16 on purpose: the
   picture cache is shared by every checkout of this machine and keyed by pack content and PIC_VERSION, not by the
   engine's code, so two arms that both count up to 16 would serve each other's pictures. PATCHES.md, Director 1.
   What I did wrong first: from 23:52 to 00:05 this arm ran with 16 and the shared cache and wrote 22 pictures
   there. I removed exactly those 22 files (by their write times; the list is at the end) and from then on kept the
   cache in the worktree (TL_CACHE_DIR=.tl/cache). The exe ships its own cache; started, it copies 1601 keys only.
5. Performance, windowed GPU: +3 % (1.26 against 1.23 ms). Render gpu ms of the 16-picture village tour,
   1920x1080 window, RTX 4090, busy:
     Alternating runs on the final tree, same walk, same command (--load=block), minutes apart:
       03:08  classic   3.168 ms   (frame p50 7.156 ms: another arm's window was heavy at that minute)
       03:15  diorama   1.377 ms
       03:18  classic   1.404 ms
       03:20  diorama   1.380 ms
       03:38  classic   1.375 ms
       03:43  diorama   1.411 ms
     Median of three: classic 1.404 ms, diorama 1.380 ms.
     The quiet hour, before the other arms' final runs:
       00:10  classic, copy of diorama-base   1.298 and 1.284 ms (two runs)
       00:23  classic, this tree              1.303 ms
       00:04 to 00:21  diorama of that hour   1.291 to 1.411 ms (5 runs of my 8-picture walk of the same village)
     Reading: under that load the model's cost is below what the counter can tell apart (1.38 against 1.40 ms).
     The figure follows the other arms' load (1.3 to 3.8 ms for one and the same tree tonight), not the style.
     Kit lab, main layout at 2560x1440 (k.sh stats), classic and diorama alike: 239 draw calls, 1 667 300 primitives
     in the frame, 488 736 triangles built: no geometry was added.
   No doubling: the cost is a few per cent at most.
   `node devx/bin/tl.mjs perf run --scenario tour6 --no-record` (the windowed six-pack tour; not recorded, so the
   ledger is untouched), each time "# machine BUSY ...; not recorded", so measured and not judged:
     03:49  classic   PASS perf.tour6: gpu_ms 1.866, frame_ms_p50 4.859 (use 75 %)
     03:59  diorama   FAIL perf.tour6: "no world line in the tour output" after 616 s (use 84 %): no measurement.
                      Why that window did not report I do not know; the scenario keeps no log.
     04:02  diorama   PASS perf.tour6: gpu_ms 1.271, frame_ms_p50 3.087 (use 94 %; the same command, 77 s)
   The scenario's own command four more times with the log kept (world.sh tour tour --pictures-only), when the
   machine was quieter; all four ended by themselves, 10 of 10 pictures, exit 0:
     04:08  diorama   gpu 1.269 ms, frame p50 3.185 ms
     04:13  classic   gpu 1.231 ms, frame p50 3.141 ms
     04:16  diorama   gpu 1.260 ms, frame p50 3.423 ms
     04:18  classic   gpu 1.231 ms, frame p50 3.075 ms
   That is the cleanest pair of the night: the diorama model costs 0.03 ms of GPU a frame at 1920x1080 (+3 %).

DOES THE DETAIL CRAWL (engine/tools/look.sh boil; lane script crawl.sh; mean change per frame in grey levels / share
of pixels that change by more than 24 in one frame; 1920x1080, x264 crf 4)

 clip, band                                        classic           diorama           preview (ink off)
 review scene, slow pan, horizon (thin members)    3.065 / 2.625 %   2.804 / 2.471 %   1.243 / 0.286 %
 review scene, slow pan, kit floor                 0.441 / 0.037 %   0.547 / 0.037 %   0.431 / 0.006 %
 village road, slow pan, far land and yard         0.485 / 0.523 %   0.524 / 0.464 %   0.322 / 0.176 %
 village road, slow pan, near land                 0.040 / 0.000 %   0.166 / 0.003 %   0.159 / 0.003 %
 village road, camera still, near land             0.000 / 0.000 %   0.000 / 0.000 %   0.000 / 0.000 %

 Reading: nothing boils on a still camera. Under the pan the textured land changes by a sixth of a grey level a
 frame where today's flat land changed by a twenty-fifth, and 3 pixels in 100 000 flip: that is texture moving with
 the pan, not noise. The rest is on par with classic or below it. The ink is what boils: with it off the horizon
 band falls from 2.5 % of flipping pixels to 0.3 %.
 Why it holds: every mark has a wavelength and is faded before a pixel is half of it; land is filtered by the mean
 of its two footprints; noise corners come from an integer hash (a float hash far from the origin disagrees with
 itself across a cell line: seen as a grid in the river); gloss is spread where the lit normal turns faster than
 the pixels; soft edges and board joints have exact slopes (a slope from screen derivatives is one value per 2 x 2
 pixels and breaks a thin highlight into dashes that run along it: seen, fixed).
 The classic clips are of 01:02, the diorama and preview clips of 02:00 to 02:12 on the final shader (classic's
 branch of the shader did not change in between: surf.classic_source).

GATES (final tree; green on the last run, and packs was red in 3 of 7: read that paragraph)
- node devx/bin/tl.mjs check --tier fast (04:59): PASS arch [12/12], PASS assets [4/4], PASS cards [3/3],
  PASS devx.test [229/229], PASS foreman.typecheck.
- node devx/bin/tl.mjs check --tier full --only world,packs,kit.selftest, run seven times tonight:
    00:54  PASS kit.selftest [95/95]  PASS packs [2/2] 48 of 48  PASS world [8/8]
    01:54  PASS kit.selftest [95/95]  PASS packs [2/2] 48 of 48  PASS world [8/8]
    02:57  (inside the whole tier)    FAIL packs [1/2] 47 of 48  PASS world [8/8]
    03:11  PASS kit.selftest [95/95]  PASS packs [2/2] 48 of 48  PASS world [8/8]
    04:36  PASS kit.selftest [95/95]  FAIL packs [1/2] 47 of 48  PASS world [8/8]
    04:58  PASS kit.selftest [95/95]  FAIL packs [1/2] 47 of 48  PASS world [8/8]
    05:08  PASS kit.selftest [95/95]  PASS packs [2/2] 48 of 48  PASS world [8/8]   <- the last run
  world: the same 8 hashes every time. kit.selftest: 95 of 95 every time.
  packs, all three failures, the same single check: "FAILED hockey: invariants ... invariants.many_budget: frame
  p50 1.078 ms" (02:57), "1.037 ms" (04:36), "1.011 ms" (04:58) "(budget 1.0 ms for one of many)". It is a
  wall-clock budget of the headless frame, and tonight hockey sits on it WITHOUT my work:
  `tl.sh invariants --pack=engine/packs/hockey` run 8 times on this tree and 8 times on a copy of diorama-base,
  alternating, 04:37 to 04:47, the machine loaded:
    copy of diorama-base   median 1.054 ms (0.949 .. 1.204), 5 of 8 over the budget
    this tree              median 1.096 ms (0.932 .. 1.251), 6 of 8 over the budget
  The two overlap; no code of mine runs in a headless frame (the style is a stub there; hockey builds its meshes
  once, at setup). So I read it as the machine, not the lane: the step is green when the machine lets it be
  (4 of 7), and a run on a quiet machine should settle it. (Between 03:11 and 04:36 the tree changed by two
  comment lines in draw_base.gd; the 04:58 and 05:08 runs were made with all my other work stopped, the other
  arms still on.)
- bash engine/tools/selftest.sh style. (04:36): 3 passed, 0 failed (style.walker.ink, style.first_reject,
  style.switch).
- bash engine/tools/selftest.sh surf. (04:36; my block 580): 5 passed, 0 failed (surf.classic_source, surf.model,
  surf.model_classic, surf.edges, surf.keys).
- export.sh: PASS export.build: tag 781d32b 2026-11-20 02:27. export.sh check: PASS export.check (its own note:
  "E and Q: NOT SHOWN (no game came on stage) ... Not counted", as that check words it). After the export only
  STYLE.md and two comment lines in draw_base.gd changed.
- node devx/bin/tl.mjs check --tier full (the whole tier, once, 02:20 to 02:57, the machine at 85 %): exit 1, NOT
  green. 11 steps PASS: arch [12/12], assets [4/4], cards [3/3], devx.test [229/229], foreman.typecheck,
  foreman.test [223/223] (217 pass, 6 skipped), kit.selftest [95/95], seeds [39/39], item.selftest [91/91],
  ui.selftest [166/166], world [8/8]. The other three:
  - FAIL kernel.selftest [84/85]: "completed 84 of 85 units found; selftest: 0 failed, 84 passed; timed out after
    1800 s and was killed". A stopped run, not a pass. The suite's windowed cases wait for the same window lock as
    everything else tonight.
    The same suite run alone afterwards, with no limit (bash engine/tools/selftest.sh, 03:11 to 04:48: 97 minutes,
    nearly all of it waiting for the window lock): "selftest: 330 passed, 0 failed". All 85 blocks, mine included
    (325 cases without my 5; that 325 is by subtraction, I did not run the suite on diorama-base). So nothing in
    the suite fails on this tree, and the gate step still stands as FAIL until it fits its 1800 s on a quiet machine.
  - FAIL packs [1/2]: the hockey time budget, as above (1.078 ms against 1.0), while the same run's perf step called
    the machine BUSY.
  - NOT RUN perf: "could not run: machine BUSY (use 85%, probe 0.928): perf measured but NOT judged and not recorded".

CHANGED FILES
 engine/style/shaders/toon.gdshader         +407: the TL_DIORAMA branches (classic branches untouched, proven)
 engine/style/shaders/water_resin.gdshader  new: the resin river (TL_SHORE variant inside)
 engine/style/style_diorama.json            toon, water, palette (14 colours), mat (49 keys), detail; nothing else
 engine/style/style_surfaces.json           new: a judging aid (diorama + ink and paper off); PATCHES.md Director 2
 engine/style/tl_style.gd                   +15 -3: classes clay and felt, mat keys gloss/fuzz/chip, lookup row 3,
                                            shader variants through dio/style_dio.gd; 574 lines (budget 600)
 engine/style/dio/style_dio.gd              new: shader variants and the globals g_dio .. g_dio5
 engine/style/STYLE.md                      +42: "The diorama material model" (keys, rules, the crawl table)
 engine/kits/tl_mesh.gd                     box faces and round things marked; merge moved out; 642 lines (was 660)
 engine/kits/tl_mesh_bake.gd                new: the UV2 records (box face, lump, turned side) and the merge
 engine/kernel/world/draw/draw_pictures.gd  +6: pictures keep UV2
 engine/kernel/world/draw/draw_base.gd      PIC_VERSION 1601
 engine/kernel/world/draw/surf_case.gd      new: the headless cases of block 580
 engine/tools/selftest.d/580-surf.sh        new: 5 cases
 Lane folder: REPORT.txt, STANDUP.md, PATCHES.md, contact-sheet.jpg, contact-sheet-pairs.jpg, stills/ (classic,
 diorama, preview: 26 JPG each; exe: 3 JPG), clip.mp4, clip-preview.mp4, a strip of each, and the scripts and walks
 that made them (shotset.sh, crawl.sh, sheet.py, surf_clip.*, surf_pan.*, flight_shots.devices.json).
 About 43 MB (stills 12, the two clips 26, sheets and strips 6).
 Not changed: any pack, any seed, any contract, docs/generated, the sky, sun, env, fog, ink, grade and lights
 sections, tl_style_fx.gd, the cameras, the rigs.

BEHAVIOUR CHANGES (all presentation; none under TL_STYLE=classic)
- TLMesh meshes with a box, blob or cyl have one more vertex channel (UV2, 8 bytes a vertex, lazy: a mesh without
  them has none). Classic never reads it. Pictures (stand-ins) always carry it.
- With `water.shore` > 0 the river is drawn after the solid world (PATCHES.md frame 4).
- `toon.band_hi` / `band_lo` mean the two ends of one ramp under the diorama model (0.78 / 0.06).
- No test expectation moved.

PATCHES.md (what another pillar should do): frame: ink off or hairline, paper off, keep the sun low, the river and
depth, nothing a post pass reads has moved, which toon keys are mine; character: the figure already gets the model,
per-key controls, what to share if it gets a shader of its own; Director: PIC_VERSION, style_surfaces.json, how to
merge the style file, the tour's load mode.

WHAT STILL DOES NOT READ AS A DIORAMA (honest)

1. With the base's ink on (this arm's default, the frame pillar's section) the picture is a DRAWING of clay: a 4 px
   contour and creases on every facet. The surfaces are built to be seen without it (PATCHES.md, frame 1). Every
   "preview" picture, clip-preview.mp4 and PLAY-SURFACES-PREVIEW.cmd show that; the default exe does not.
2. Nothing sits on the ground. There is no contact shade worth the name (the ink pass's blue patches under posts
   are the only one, and they are the frame's). Board 4 lives on it. Posts, feet and blocks float a little.
3. The silhouettes are still low-poly. A lump is LIT as round, but its outline is the polygon it was: mesas are
   prisms, a pine tier has 7 sides, a bush has corners. Felt has no fibre at its edge.
4. Fingerprints fade in from 9 m and are whole within 3 m only (the ridges are 1.8 cm apart at world scale). At
   play distance clay is told by thumb dents, soft edges and the waxy turn, which is quieter than board 4's.
5. Land beyond about 70 m is flat tone: the marks are faded before they would alias. With the frame's depth of
   field that is right; without it the far meadow is plain.
6. The stripes of the beam are geometry: their edges are straight. The brush strokes and chips are inside each stripe.
7. Chips gather at the edges of boxes only; cylinders and lumps wear evenly. A box that passes through another box
   keeps a soft edge and a highlight where the two meet inside (the shader cannot know the edge is hidden).
8. The 3D grass tufts of the village and the facets of bushes keep their own low-poly tone steps (a blob's facet
   tones are taken back by 60 %, not all the way: the kit's own `vary` is its author's choice).
9. The river has no foam where it meets a rock or a pier, and no caustics; the bank shows only where the bed is
   shallow, because it is read from depth. Far off at a grazing angle it is half a mirror of a peach horizon and
   turns grey-lilac (stills 25 and 26 of the flight): it reads as a river by its shape there, not by its colour.
10. Board joints and soft edges have exact slopes; joints of bricks, slab joints of rock and all noise marks still
    take their slope from screen derivatives (one value per 2 x 2 pixels). Up close a brick joint can show it.

COST PER NEW GAME

None added, some removed. A game still names palette keys, places kit parts and calls TLBiped.create. What it gets
without asking: a `box` has soft edges, a `blob` or `cyl` is lit round, a key with no class is clay. Optional and
additive, per palette key in the style file (never in a pack): `gloss`, `fuzz`, `chip`, classes `clay` and `felt`.
A builder who draws his own triangles with `tri` gets today's hard facets, as before. No pack file changed, no
palette key was renamed or reordered (100 keys, same order, checked), the kernel API is the one of diorama-base.

QUESTIONS FOR THE DIRECTOR
1. PIC_VERSION: which number lands (PATCHES.md Director 1), and should the cache key carry the engine's revision so
   this cannot happen between checkouts?
2. Does style_surfaces.json go (my advice) or stay as the way to judge surfaces alone?
3. The window lock: six arms behind one lock made a tour cost 15 to 20 minutes of waiting, the kernel selftest
   suite 97 minutes (its gate step allows 30). Pictures-only tours take no input; a second lock class for them
   would have doubled what every arm could look at.
4. hockey's invariants.many_budget (1.0 ms) is failed by diorama-base itself on a loaded machine (5 of 8 runs
   tonight). Should a wall-clock budget decide a gate while other lanes run, or be judged like perf (NOT RUN when
   BUSY)?

THE NEXT THREE THINGS THIS LANE WOULD DO
1. Contact: a soft, wide contact shade under everything that stands on the land (with the frame arm; from the same
   depth the river already reads), and a darker seat where a box meets a box.
2. Exact slopes for every straight mark and analytic gradients for the noise, so no slope comes from 2 x 2 pixels;
   then fingerprints and fibres can be sharper and nearer to board 4.
3. Silhouettes: a fuzzy rim for felt (pine tiers, crowns), rolled lips for mesa slabs, river foam at rocks and
   piers; all as additions the hashes do not see.

THE 22 PICTURES TAKEN OUT OF THE SHARED CACHE (<user data>/Third Life Engine/tl_cache/pictures, each key as
<key>_mid.res and <key>_far.res, written by this arm between 23:52 and 00:03 under PIC_VERSION 16):
 083c818427d077bf3fe951a007f79e51, fba7c24ce7057f5540b21ed805de7e80, 2ebf1f50230f450d31c3f1efef37e88a,
 288562d658ec6200d08af75f3476ab8b, 9dba9ce1b94ba8bf5704b52122c4548b, 400f8649e756ec7303302f04c49c46b3,
 52307f19a5cd8343a3af966c98ab9b7c, 3a3b9005c6ab0950c763f934200d1802, 9a6ad3711d4ab5ddd711e6c09d3a4f08,
 dcad28f7cc330af1c9fd5c5b4945e091, efde2848a05d4d7e441e8cfbddda5a0f.
