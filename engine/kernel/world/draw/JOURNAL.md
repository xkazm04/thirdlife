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
