# N5b journal (drawing the world)

Resume point. Newest entry last. Times are CEST from `date`.

- 01:55 start. Read the brief, N2-MANY.md, world.gd, pack.gd, host.gd (windowed spawn), tl_style.gd, all style
  shaders, tl_cameras.gd, tl_hud.gd, the concept picture.
- 02:12 plan: `kernel/world/draw/view.gd` (+ view.tscn, own main scene, because host.gd is not mine) creates N2's
  world node, never passes `--at` to it (packs stay at their own origin), and owns a draw layer `draw.gd` with both
  mechanisms switchable (`--mech=a|b`): A = `instance uniform vec4 tl_plot` in every style shader, B = mirror
  instances through RenderingServer (same base RID, own transform). Lights are mirrored in both.
- 02:02 (correction: the plan entry above was written at 01:59, not 02:12.) Shaders: `instance uniform vec4 tl_plot`
  in toon, glass, water, holo, fx_add, fx_mix. draw.gd (both mechanisms), view.gd + view.tscn, tools/view.sh.
  First run hung: no class cache in the copy (the viewer is its own main scene), parse errors, idle window.
  view.sh now imports when .godot is missing, logs to a file, and ends ITS OWN processes after TL_VIEW_TIMEOUT
  (found by a per-run tag on the command line).
- 02:08 first picture, two packs (drive stage, paddle 80 m east): candidate A right on the first run: place, sun
  shadows, ink, multimesh trees, smoke particles, only the stage HUD. captures/t1_a.png.
- 02:11 A/aabb, A/margin and B give the same picture (t2_*.png). Per-frame cost of the draw layer for ONE non-stage
  seed pack (245 visuals): A/aabb 0.33 ms, B 0.43 ms, A/margin 0.01 ms: a GDScript loop over every visual is the
  cost, not the server calls. Wall frame time is useless right now: 270 ms per frame in three of four runs, the
  single-pack run included (window occluded or GPU busy from other sessions), 2.1 ms in the fourth.
  Decision so far: A, with cull "auto" (still instances get a box once, moving ones are never culled, slow watch).
- NOTE the seeds bring their own landscape (terrain, forest, cliff, hundreds of metres): at 80 m they overlap.
- 02:13 five plots at 80 m: the mechanism is right, the PICTURE is not: every seed brings its own landscape (416 m
  near terrain, forest, mesas), so the neighbours' trees stood on the paddle court (t3_from_paddle.png).
  -> `tl_clip` in toon.gdshader: each pack is cut to its plot (instance origin outside the radius: dropped in
  vertex(); terrain: fragment discard 3 m further). The drive circuit alone is 114 m long: plots cannot be 80 m
  apart; radii 64/40/38/40/30, centres 100-110 m apart.
- 02:18 `view.sh check` (realtime, no fixed step, so it stays bounded when frames take 270 ms):
  PASS, 5 of 5 hashes equal to headless (drive 36635c04 @3516, paddle cadd1cd9 @6776, wall 6366b88f @1221,
  ex_kit 16db2bf1 @332, ex_walker 8d1831dc @371), 0 gate leaks, 0 wrong-pack calls, 0 errors.
- 02:20 rigs (skinned) in a non-stage pack right: t5_walker_close.png.
- 02:24 landscape: world ground = TLStyle.ground with its own material and holes at the plots (`tl_holes`); each
  pack is lifted so that the median height of its terrain at the plot edge is the world's ground, and the last 9 m
  of its ground are bent to that height in vertex() (tl_clip.y, .z). Drive lies in a hollow (its rim is 7.6 m above
  the track), wall and paddle on low mounds. Packs without terrain (ex_kit, ex_walker): no hole, no lift.
- 02:28 gates started in the background on the files of that minute: tl.sh selftest 73 passed 0 failed, k.sh
  selftest 86 passed 0 failed; tl.sh seeds 18 passed, 6 failed, all six a 250 ms watchdog stall in a HEADLESS verb
  (drive smoke/invariants, wall invariants/bot) while three of my own jobs ran beside them. Re-run alone at the end.
- 02:30 stand-ins (item 4): merged mesh per far pack; first version lost every vertex (packed arrays inside a
  Dictionary are copied on access: now a small class); then kept 259 k unused vertices (now compacted).
  far_off.png / far_all.png / far_full_vs_standin_x3.png: lines alike at 200 m and 500 m.
- 02:34 BUG seen in rim_close.png and in the 500 m stand-in: the rim bend sheared a house and a crane (meshes merged
  in pack coordinates were bent per vertex like terrain). Fixed: only terrain sheets (wide flat meshes, found by the
  draw layer, flagged in tl_clip.w) are bent per vertex; instances with their own origin move as a whole; merged
  meshes are left alone. Stand-in: the bend is baked per source instance.
- 02:37 final pictures world_*.png (one process, five stages); yaw_0_vs_90.png: yaw of a non-stage pack is right;
  foreign.png: bad_bypass's StandardMaterial3D part is counted (foreign 1) and mirrored to its plot.
- 02:40 single pack against look/after: paddle byte-identical, drive PSNR 116 dB, wall 54.6 dB (shader clock).
- 02:43 second `view.sh check` (stage wall, stand-ins auto): PASS 5 of 5, same hashes.
- 02:44 stand-ins now keep flat-colour toon materials (kernel boxes) as extra surfaces: ex_walker's room was
  missing at a distance. A frozen RigidBody3D counts as standing still. standin_full_vs_standin_near.png.
- 02:45 cost bench again, alone (cost2), then seeds gate alone, then both selftests on the final files.
  Wall-clock frame times flip between about 4 ms and 270 ms per frame from run to run, also with nothing else of
  mine running: something outside this session (GPU benchmark, other windows at 0,1440).
- 02:48 FOUND the 270 ms frames: my own fault. The very first viewer run (02:05, before the class cache existed)
  left an idle Godot window at 0,1440 (parse errors, no script, so it never quit; the old view.sh retried and I
  stopped only one of the pairs). Whenever that window lay above a new one, the new one was throttled to about
  270 ms a frame; a test window at 1920,1440 ran at 1.7 ms while one at 0,1440 ran at 270 ms. Both processes
  (pids 101656, 74348, command line with my t1_a.png) stopped at 02:48. It may have slowed other sessions' windows
  at 0,1440 between 02:05 and 02:48 as well. Every frame time before 02:48 that reads about 270 ms is this, not
  the draw layer. Cost bench started again (cost3), then seeds, then both selftests.
- 02:51 cost3 (quiet, the table in DRAW.md section 5). 02:53 tl.sh seeds alone: 24 passed, 0 failed, seed hashes
  bc93a9a4 / b9adbb19 / da4bdc3f. 02:55 on the final files: tl.sh selftest 73 passed 0 failed, k.sh selftest 86
  passed 0 failed.
- 02:56 A against B re-measured on a quiet window (DRAW.md section 1): A/auto 0.023 ms, A/aabb 0.111, A/margin
  0.008, B 0.149 ms per frame for one non-stage seed pack. B is 6.5 times A, not the 10 ms a frame for 24 packs
  that the busy figures of 02:10 suggested (3.4 ms). The plot cut is what decides for A.
- 02:57 third `view.sh check` started on the final files (stage drive, stand-ins auto). DRAW.md sections 10 (pack
  author), STYLE.md note on the three new shader parameters. PATCHES.md: 7 entries, none applied.
  Resume point if cut off: read DRAW.md section 9 (limits); nothing is half-done in the code.
- 02:59 third `view.sh check` on the final files: PASS, 5 of 5, same hashes at the same ticks. far_off / far_all /
  far_full_vs_standin_x3 re-shot with the final code (crane straight in the stand-in). Done; report follows.

## P6 (11 November 2026): what a far game shows, and the land at a distance

Brief: `briefs/BRIEF-P6-FAR.md`. Start 13:22. Resume point at the end of this section.

- 13:26 first tour run in this worktree left an idle window: no class cache yet (`TLContext` not found in view.gd,
  the same trap as N5b's 02:05). Stopped my own two processes by their tag (`tlworld_58881_14995`), built the cache
  with `--headless --import`, went on. Lost four minutes.
- 13:27 `landscape.gd` / `village_terrain.gd`: cfg key `relief` (scale of the land's own height; 0 = flat study
  ground). `draw/far_study.mjs`: writes the study walks (3 games, 24 crane shots: eye and rise at 50, 150, 300,
  600 m from the plot edge) and builds the sheets with ffmpeg.
- 13:32 the study, before: `captures/p6/study/before_full/`, `before_still/`, sheets `before_<game>.jpg`. Looked at
  all three sheets and four native crops. Findings: (1) beyond 150 m full and stand-in are the same picture at
  screen size; (2) what is missing in the stand-in and SEEN at 50 to 150 m: skaters, cars, chimney smoke; (3) the
  kit scoreboard shows "3 : 2" in every game at every distance, full or stand-in: it is a prop with fixed digits,
  nobody could ever read who is winning from it; (4) from the eye on flat land a venue is a strip on the horizon
  and only its tall forms read; from a rise the plan reads (oval, white ice, blue seats, the pad ring) out to 600 m.
- 13:41 draw.gd: two pictures of a far pack instead of one ("mid", "far"), built in one walk; marks (one
  multimesh per pack, a box per moving body in its colour, moved when the pack ticks); a copy of the pack's smoke;
  the 4 strongest lights; the real score over every kit scoreboard, at every distance. `TL_DRAW_PICTURE` forces a
  picture; "still" is N5b's stand-in, kept for comparison.
- 13:43 first look: marks were boxes twice a skater's size (rest pose with arms out and a stick). Figures now get a
  slim upright box. 13:46 boards not found: the search stopped at the hidden holder. Fixed.
- 13:48 the far picture of the drive seed had lost its track, barn and trees: its merged static mesh is 114 m wide,
  so it counts as a "sheet" and the coarse grid ate it. The grid is now only for the kit's terrain (`Terrain*`).
- 13:50 score boards stay in the far picture too (one score at every distance).
- 13:51 village before the land changes: `captures/p6/land_before/`.
- 13:55 land: worn ring of a pad 2 to 8 m wide by noise, a rock edge on the side away from the gate (337 rocks
  in the tour's world, fence 1888 m -> 1390 m), irregular lots, a grass foot and pines under and on every mesa,
  pine clumps on the far plain (472 far trees), 44 trees and 70 bushes along the roads. Own generator (`rng6`), so
  the scatter of P4 stands where it stood. `captures/p6/land_after/`.
- 13:56 started: `world.sh tour tour --headless`, then `view.sh check` with the three seeds and the hockey game.
- 13:57 `world.sh tour tour --headless`: PASS, six of six "same" (walk = alone = replay).
- 14:00 `view.sh check` (drive, paddle, wall, hockey; stage paddle, stand-ins auto at 60 m): PASS. Seed hashes are
  N5b's (36635c04 at 3516, cadd1cd9 at 6776, 6366b88f at 1221); hockey 5af10fbc23df0d76 at 4888, drawn = headless.
- 14:01 `draw/FAR.md` (study table, rules, what is built), `PATCHES-P6.md` (4 entries), DRAW.md head note and
  sections 9, 10. Started `draw/far_cost.sh` (12 runs: 6, 12, 30 packs x near, still, mid, far).
  Resume point: after the cost runs fill FAR.md section 4 from `captures/p6/cost/`; then final study run
  (`after_auto`), sheets `after_<game>_<eye|rise>.jpg`, `eye_walk.json` pictures, `overview_vs_concept.jpg`,
  `tl perf run --scenario tour6 --no-record`, `tl check --tier full`.
- 14:04 MEASURED, and a premise of mine was wrong: the far picture of a seed has 12,922 triangles against 13,072
  for the middle one. The terrain is not where the triangles are (784 of 13,072 in `scenery = "plot"`); they are in
  the venue's merged static mesh, 6 instances, so a size rule per instance drops nothing (0 dropped at 2.5 m for
  the paddle seed) and the coarse ground saves 150 triangles. What the far picture saved so far is its shadow pass
  (171,938 -> 142,932 primitives in the frame at 6 packs) and draw calls (80 -> 54). Next: a rule per TRIANGLE for
  the far picture (thin members under 0.1 m, detail under 0.4 m), measured again; withdrawn if the sheets get worse.
- 14:05 `tl check --tier fast --changed`: FAIL arch, size ratchet: draw.gd 1262 lines, may not grow past its 745.
  Split the layer into four files that extend one another (draw_base < draw_pictures < draw_life < draw.gd: 166,
  304, 411, 420 lines); no line of logic changed by the split (a script did it by function name).
- 14:06 cost run 1 (`captures/p6/cost/cost_run1.txt`): 6 / 12 / 30 packs, near 493 / 953 / 2344 draw calls,
  middle 80 / 111 / 225, far 54 / 59 / 109.
- 14:07 the rule per triangle for the far picture is in (`far_thin` 0.1 m, `far_small` 0.4 m). Study run again on
  the split files: 24 of 24 pictures, no error; sheets `study/after_<game>_<eye|rise>.jpg` looked at (hockey, paddle,
  drive from the rise; hockey from the eye before the rule): the far pictures still read as the venue.
- 14:11 started: far cost again (run 2), `eye_walk.json`, `tour_views` on the final code.
- 14:12 cost run 2 (far rows after the rule per triangle): paddle seed's far picture 13,072 -> 4,487 triangles,
  wall seed 13,704 -> 3,592; frame primitives at 6 / 12 / 30 packs 124,635 / 97,357 / 130,065 (middle: 171,938 /
  182,492 / 273,394). The rule stays. FAR.md section 4 has the table and what it does not prove (the milliseconds).
- 14:16 `captures/p6/eye/` (the visitor's eye and a rise: walker near, drive and paddle middle, wall and car far).
- 14:17 `tl perf run --scenario tour6 --no-record`: machine BUSY, not recorded; 288 draw calls, 2,237,536
  primitives against the ledger's 249 and 1,911,582. The 337 pad rocks in four shadow cascades were most of it:
  their shadow and the road bushes' is off. 14:20 again: 280 draw calls, 1,977,056 primitives (+3.4 %).
- 14:18 my `--import` (for the new scripts' uid files) had written 100 `.import` files beside my pictures: deleted,
  `captures/p6/.gdignore` added. Frames converted to JPEG (202 MB of PNG is not for a commit).
- 14:21 `tl check --tier full` started. Resume point: read its result; then the report. Nothing is half-done in
  the code. Not done: style (item 3 through shaders), softer ground patches, a more compact village.
- 14:23 landscape.gd had grown to 634 lines (the size rule allows 600): the three P6 loops (road trees and bushes,
  plain clumps, the rocks of a fence span) moved to `terrain/village_parts.gd` as `road_side`, `plain_clumps`,
  `edge_rocks`, same order of random draws; landscape.gd 597 lines. The gate that was running then is stale.
- 14:24 started on the final files: `tour_views` into `captures/p6/land_check/` (must equal `land_after/`), then
  `view.sh check` again. Then `tl check --tier full` once more.
- 14:27 `view.sh check` on the final files: PASS, the same four hashes at the same ticks (36635c04, cadd1cd9,
  6366b88f, hockey 5af10fbc), 0 gate leaks, 0 script errors, 0 engine errors. `tour_views` after the move drew the
  same counts as before it (273 / 254 / 216 draw calls; 1,983,049 / 2,032,393 / 1,202,245 primitives).
- 14:28 `tl check --tier fast` (all files): PASS (arch 8 rules, assets, cards, devx.test 123, foreman.typecheck).
- 14:30 `world.sh tour tour --headless` on the final files: PASS, six of six "same".
- 14:31 started the windowed tour with its proof and the `ledger` walk in a window (the draw layer's tier, rebuild
  and forget paths with the new pictures). The full gate started 14:20 is still running; three other full gates
  of other builders run on this machine at the same time.
- 14:32 windowed `world.sh tour tour --out-dir=<scratch>` on the final files: 10 of 10 pictures, 4 stage changes,
  PASS (six of six "same": walk = alone = replay), no script or engine error. `world.sh tour ledger` in a window
  (a pack goes to the ledger and its nodes are freed while its pictures stay): PASS.
- 14:40 the full gate started 14:20 ended: FAIL arch (landscape.gd 634 lines, fixed at 14:23) and devx.test
  2 of 123 (the two tests that run `tl arch` on the real tree: the same cause); PASS foreman.typecheck,
  foreman.test 158, kernel.selftest 81 cases, kit.selftest 87, seeds 24 cases, perf (machine BUSY: measured, not
  judged), assets, cards; item.selftest and ui.selftest SKIPPED (need the main checkout's site/). It took 20 minutes
  with three other full gates running on the machine.
- 14:40 full gate started again on the final files (log in the session's scratch). Report next.
  Resume point: nothing is half-done. If cut off: read the gate's result, write the report from this section.
- 15:00 `tl check --tier full` on the final files: ok true. arch, assets, cards, devx.test 123, foreman.typecheck,
  foreman.test 158, kernel.selftest 81 cases, kit.selftest 87, seeds 24 cases PASS; perf measured but not judged
  (machine BUSY, use 100 %); item.selftest and ui.selftest SKIPPED (they need the main checkout's site/). 20 minutes.
  P6 is done; the report is the final message. Nothing is half-done.
