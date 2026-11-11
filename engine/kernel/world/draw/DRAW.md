# N5b: drawing a world of many packs

**N7:** the viewer is now the host mode `world-view` (same options; `tools/view.sh` starts it), the draw layer takes
`set_stage(-1)` (nobody on stage), `set_tier(i, tier)` (the scheduler's tier decides full or stand-in),
`forget_nodes(i)` and `replace_holder(i, holder)` (a pack built again from its seed), and the world's ground moved to
`kernel/world/landscape.gd`. A world host now loads packs with `scenery = "plot"` unless `--scenery=full` is given,
so the pictures of this document (taken with full scenery) show more pack-owned trees than a run today.
`kernel/world/WORLD.md` is the page for the joined world.

Every pack of a world is simulated at the origin of its own physics space (N2: placed even 64 m away its results
change). This directory draws them standing apart in one landscape, in one picture, without touching the simulation.

| file | what it is |
|---|---|
| `draw.gd` | the draw layer: plots, the stage rule, both offset mechanisms, culling, the plot cut, far stand-ins |
| `view.gd`, `view.tscn` | the viewer: N2's world host + the draw layer + the world's ground + a crane camera + pictures |
| `../../../tools/view.sh` | `shot` (one or more pictures) and `check` (state hashes with drawing on against headless) |
| `PATCHES.md` | patches to files that are not mine (none applied) |
| `captures/` | every picture named below |
| `../../../style/shaders/*.gdshader` | `tl_plot` in toon, glass, water, holo, fx_add, fx_mix; `tl_clip` and `tl_holes` in toon |

```
bash tools/view.sh shot --packs=seed_drive,seed_paddle,seed_wall,ex_kit,ex_walker \
     --at=0:0:0,110:0:0,-110:0:0,0:0:105,0:0:-100 --radius=64,40,38,40,30 \
     --stage=0 --cam=overview --frame=240 --out=<abs png> \
     "--also=1:baseline:<abs png>;2:yard:<abs png>"          # more pictures from the same process, stage re-based
bash tools/view.sh check --packs=... --at=... --radius=...    # item 3: hashes with drawing on = headless hashes
```

## 1. The mechanism kept: candidate A (offset in the shaders), with mirrors for what is not style geometry

**A.** Every style shader has `instance uniform vec4 tl_plot` (xyz = offset in metres, w = yaw in radians). When it is
not zero, `vertex()` replaces the model-view matrix by `VIEW_MATRIX * plot * MODEL_MATRIX` (and the normal matrix
likewise). The draw layer sets it once on each `GeometryInstance3D` of a pack when the pack is placed
(`set_instance_shader_parameter`), and again only when the stage changes. Nothing is done per tick. When it is zero
(a single pack, the stage pack) the branch is not taken and the engine's own matrices are used: a single-pack
capture is unchanged (section 7).

**B** was built as far as the comparison needed and is still selectable (`--mech=b`): one `RenderingServer` instance
per visual with the same base RID (mesh, multimesh, light) at `rel * node.global_transform`, the node's own instance
hidden on the server (`instance_set_visible`, so the node's `visible` is untouched), moved nodes re-sent in
`_process`. A uses the same code for what a shader cannot move (section 3).

### The measurement

Two packs, drive on stage, paddle 80 m east (245 visuals and 5 lights in the non-stage pack), whole packs (no plot
cut), crane view, 1920x1080. Figures of 02:55 on a quiet window, median of 120 frames; pictures of the same four
set-ups from 02:10: `captures/t2_a_aabb.png`, `t2_a_margin.png`, `t2_b.png` (and `t2_one.png`, the drive alone).

| | picture | draw calls | primitives | whole frame | draw layer, per frame, for the one non-stage pack |
|---|---|---|---|---|---|
| A, kept (`--cull=auto`) | same | 169 | 1,865,342 | 1.551 ms | 0.023 ms |
| A, a box per instance refreshed every frame (`--cull=aabb`) | same | 163 | 1,863,454 | 1.591 ms | 0.111 ms |
| A, never culled (`--cull=margin`) | same | 181 | 1,941,518 | 1.547 ms | 0.008 ms |
| B, mirror instances | same | 165 | 1,971,454 | 1.664 ms | 0.149 ms |

The same four at 02:10, on a busier machine (see the note under the cost table): 0.325 ms (A/aabb), 0.010 ms
(A/margin), 0.426 ms (B). The order is the same; the quiet figures are the ones to use.

In worlds: A kept, five plots, four non-stage packs: 0.12 to 0.15 ms for all four at 02:37 (busy); 12 packs in
full 0.18 ms, 24 packs in full 0.39 to 0.43 ms at 02:50 (quiet): about 0.017 ms a pack.

The pictures are the same picture: positions, sun shadows, ink lines, multimesh trees, chimney smoke. What differs
is the price of following a pack. The server calls are not the cost; the GDScript loop over every visual of every
non-stage pack is (0.6 microseconds per visual per frame, quiet). B has to run that loop, because a mirror stands
still unless it is told: 0.149 ms a pack against 0.023 ms, so 23 non-stage packs in full would cost about 3.4 ms a
frame under B and 0.4 ms (measured) under A. That is a real difference, not a decisive one by itself: B is affordable
for a dozen near packs.

The reason that decides came out of the picture, not the timing: **a pack must be cut to its plot** (section 4), and the cut
works in the pack's own coordinates. In A the shader has them (`MODEL_MATRIX` is still the pack's own). In B the
plot is inside the mirror's model matrix, so the shader would have to be given the plot anyway to undo it: B is then
A with a per-tick loop on top. `--mech=b` therefore draws whole packs, far scenery included.

What B does better: engine culling is exact with no help, and anything with a render instance moves, style or not.

### Culling under A (settled: `--cull=auto`)

The engine culls, for the camera and for every shadow cascade, with the instance's box at the place where the pack
is simulated, which is around the stage pack's origin for every pack. Without help a neighbour vanishes as soon as
the camera turns away from the stage's origin.

- An instance that stands still gets `custom_aabb` = `T^-1 * rel * T * box`, once. With no yaw between the two plots
  this depends on the node's rotation only, so a node that slides keeps a right box.
- An instance under a moving body (`PhysicsBody3D` that is not a `StaticBody3D`), under a `Skeleton3D`, or a
  particle emitter is never culled (`extra_cull_margin = 16384`). In the five-plot world these are the cars, balls,
  paddles, bricks and rigs: few and small.
- A slow watch (24 instances per pack per frame, round-robin) moves any "still" instance that a script turned after
  all into the never-culled class. In the five-plot world it promoted 30 (flags, the crane's load).
- Shadows: the shadow pass runs the same `vertex()`, so shadows fall at the plot (every picture). Never-culled
  instances are submitted to all four cascades.

## 2. The stage rule

The stage pack is drawn at zero offset: its own cameras, its HUD and the player's precision are native. Every other
pack is drawn at `rel_i = plot_stage^-1 * plot_i`; the landscape node (ground, crane camera) is a plain node with the
transform `plot_stage^-1`; a far stand-in is drawn through `tl_plot` like the pack it stands for.
`draw.set_stage(i)` re-bases everything once: instance uniforms and boxes, `ctx.on_stage`, HUD visibility. The
viewer's `--also=<stage>:<cam>:<png>;..` takes further pictures from other stage packs in the same process, three
frames after each re-base (`captures/world_from_*.png` are one process).

Only the stage pack's HUD is shown (hidden on `set_stage`, and polled each frame for HUDs made later: PATCHES 2).
Only the stage pack's views take the viewport camera (`ctx.on_stage`, N2's patch 2; PATCHES 1).

## 3. What does not move with a pack under A, and what was done

| thing | what happens | state |
|---|---|---|
| lights (`OmniLight3D`, `SpotLight3D`) | mirrored (B's code): a second server instance of the same light at the plot, the node's own hidden on the server; colour, energy and range are shared because the base RID is shared; followed in `_process` (5 to 14 per pack: cheap) | right in the pictures: lit windows and floodlights of non-stage packs (`captures/rim_close.png`, `world_from_seed_drive.png`) |
| a pack's own material (`StandardMaterial3D`, own shader), default material, labels, sprites | the instance is mirrored as a whole, so it stands at its plot; counted (`draw.adopted.foreign` in the `tl.view/1` line). It is not cut to the plot, not in the far stand-in, and costs one comparison per frame | see section 8 for the test |
| particles (`CPUParticles3D` with the style's fx materials) | `fx_add` / `fx_mix` move their billboard through `tl_plot`; never culled | chimney smoke of non-stage packs is at the chimney (`t1_a.png`, `rim_close.png`) |
| skinned rigs | the skeleton is applied before `vertex()`; never culled | right: `captures/t5_walker_close.png` (walker and skater of a non-stage pack, with shadows) |
| glass, water, hologram shaders | `tl_plot` added to all three | compiled and drawn without error in `ex_kit` as a non-stage pack; no close picture was looked at |
| ink pass, grade, sky, sun | screen space or world-wide: untouched, drawn once | lines on non-stage packs in every picture |
| world-anchored noise in the shaders (`wpos`: mottle, strata, ice streaks, sway phase) | deliberately stays in the pack's own coordinates: a pack looks the same at any plot and on stage; two copies of one pack look identical | by design |
| the sun for a stage pack with yaw | NOT done: the rig is not turned with the world, so a yawed stage pack would see the sun from another side than its neighbours do | limit; every picture uses yaw 0 for stage packs |
| `GPUParticles3D`, decals, fog volumes, reflection probes, `VisibleOnScreenNotifier3D` | mirrored as generic visuals (decal, fog, probe) or untested | not verified: no pack uses them |

## 4. A premise that was wrong: "five plots 80 m apart", and what a plot has to be

Every seed brings its own landscape: a 416 m terrain sheet, a far sheet out to 2.5 km with mesas, a forest. Drawn
80 m apart, the mechanism is right and the picture is wrong: the neighbours' trees stand on the paddle court and
`ex_kit`'s floor lies over the track (`captures/t3_overview.png`, `t3_from_paddle.png`). And the drive seed's
circuit alone is 114 m long.

So a plot is a circle of a given radius around the pack's origin (`--radius`, per pack; chosen by eye tonight:
64 / 40 / 38 / 40 / 30 m, centres 100 to 110 m apart), and the draw layer cuts every pack to it, the stage pack
included (`instance uniform vec4 tl_clip` in toon.gdshader):

- an instance whose origin lies outside the radius (a tree of the forest multimesh, a far prop) is dropped in
  `vertex()`; a large mesh is cut 3 m further out in `fragment()`;
- the pack is lifted so that the median height of its terrain at the plot edge is the height of the world's ground,
  and the last 9 m of its terrain sheets are bent to exactly that height in `vertex()`; what stands on the terrain
  with an origin of its own follows by the height of that origin. No step where a plot ends
  (`captures/rim_close.png`). A mesh merged in pack coordinates is not bent (bending it sheared a house and a crane);
- the world's ground is one `TLStyle.ground` sheet with its own material of the same shader and palette, with the
  plots cut out of it (`tl_holes`, up to 32), so a venue that lies lower than its rim is not buried: the drive seed
  lies in a hollow 7.6 m deep, the wall yard on a 2 m mound;
- a pack with no terrain of its own (`ex_kit`, `ex_walker`) gets no hole and no lift: the world's ground runs under it.

The sky, the sun and the ground are drawn once. Far scenery (hills, a road between venues, a forest between plots)
is not drawn at all yet: the plain is flat and empty.

## 5. Far packs: stand-ins

When a pack is placed far (`--standins=auto`: beyond `--far` metres from the camera, with a 15 % margin both ways so
it does not flicker; `--standins=all`), its holder is hidden (`visible = false` on the kernel's holder node: drawing
only) and one merged mesh is shown instead. It is built once, from the pack's own visuals at that moment
(`draw.gd`, `_build_standin`): surfaces that use the palette material, palette columns, vertex colours and
part-local coordinates kept, so it is drawn by the same material with the same drawn surface detail; triangles
outside the plot dropped; the bent rim baked in. Flat-colour toon materials (the kernel's boxes: the walls and floors of `ex_walker` and `ex_kit`) go into a
surface of their own each. Dropped: instances shorter than 1.2 m (`standin_min`), everything under a moving body or a
skeleton, particles, lights, glass, foreign materials. Full pack against stand-in from 50 to 130 m:
`captures/standin_full_vs_standin_near.png` (buildings, crane, slabs, shadows and lines alike; the bots, balls and
loose pieces are missing). A far pack costs no per-frame work
in the draw layer.

Seed paddle: 86,446 source triangles (terrain included) to 13,072, 39,216 vertices, built in 110 ms; seed wall:
87,774 to 14,360 in 110 ms. Most of the reduction is the plot cut; inside the plot only small parts are dropped
(4,500 multimesh instances: grass, pebbles). There is no decimation.

Ink lines at 200 m and 500 m, full pack against stand-in, same camera, enlarged three times:
`captures/far_full_vs_standin_x3.png` (from `far_off.png`, `far_all.png`). At 200 m the lines are the same on both
(contours on trees, masts, stand). At 500 m the ink has thinned to hairlines on both in the same way (the ink pass
fades with distance by design). For that view (stage `ex_walker`, two far packs) the frame is 177 draw
calls and 1,617,504 primitives in full, 30 and 110,618 with the two as stand-ins. Along the bent rim of the 200 m plot
both versions show a row of small ink marks (section 9).

### Cost (item 4)

Packs on a 140 m grid, cycling `seed_drive, seed_paddle, seed_wall, ex_kit, ex_walker, ex_car` (radii 64/40/38/40/30/40),
every pack played by its bot, mechanism A, `--cull=auto`, 1920x1080, Direct3D 12, RTX 4090 / Ryzen 7 7800X3D.
"full" = every pack drawn in full; "stand-ins" = `--standins=auto --far=200` (packs beyond 200 m of the camera as
stand-ins). Two cameras: the crane over the whole grid (far from everything, so nearly every pack is a stand-in) and
the stage pack's own chase camera (pack 0, a corner of the grid). Frame time is the wall time of one whole frame,
median of 40 frames, **simulation of every pack included** (a world of 24 packs ticks 24 packs); render CPU and GPU
are the engine's own measurements of the viewport. Draw calls, primitives and objects are the engine's totals for
the frame, shadow passes included.

| packs | camera | drawn | far packs | draw calls | primitives | objects | frame ms | render CPU ms | render GPU ms | draw layer ms |
|---|---|---|---|---|---|---|---|---|---|---|
| 6 | crane | full | 0 | 394 | 1,757,942 | 614 | 3.396 | 0.382 | 1.258 | 0.095 |
| 6 | crane | stand-ins | 3 | 202 | 788,680 | 393 | 3.356 | 0.335 | 0.903 | 0.039 |
| 6 | stage chase | full | 0 | 463 | 3,185,956 | 683 | 3.129 | 0.371 | 1.592 | 0.076 |
| 6 | stage chase | stand-ins | 3 | 266 | 2,213,734 | 459 | 2.975 | 0.303 | 1.385 | 0.045 |
| 12 | crane | full | 0 | 732 | 3,051,914 | 1,010 | 5.833 | 0.617 | 1.807 | 0.186 |
| 12 | crane | stand-ins | 11 | 65 | 524,434 | 238 | 4.697 | 0.27 | 0.879 | 0.009 |
| 12 | stage chase | full | 0 | 876 | 5,803,000 | 1,152 | 5.461 | 0.577 | 2.16 | 0.177 |
| 12 | stage chase | stand-ins | 9 | 206 | 2,225,128 | 384 | 5.216 | 0.356 | 1.395 | 0.039 |
| 24 | crane | full | 0 | 1,338 | 4,347,862 | 1,732 | 10.449 | 0.943 | 2.649 | 0.429 |
| 24 | crane | stand-ins | 23 | 62 | 418,358 | 235 | 9.141 | 0.365 | 0.906 | 0.016 |
| 24 | stage chase | full | 0 | 1,587 | 8,693,256 | 1,975 | 10.114 | 0.984 | 2.779 | 0.389 |
| 24 | stage chase | stand-ins | 21 | 262 | 2,325,614 | 467 | 9.654 | 0.498 | 1.46 | 0.058 |

Pictures: `captures/cost_<packs>_<off|auto>_<overview|chase>.png`. Taken at 02:49 to 02:51 with no other job of mine
running; other sessions were using the machine.

Read: stand-ins cut draw calls by 1.7 to 22 times and primitives by 1.4 to 10 times, and the draw layer's own work to
almost nothing; what is left in the frame time is mostly the simulation of the packs, which a stand-in does not stop
(pausing a far pack is the scheduler's decision: N5a). From the stage camera the stage pack and its near neighbours
dominate, which is the point of the stage rule.

**The frame times before 02:48 are not valid.** An idle viewer window of my own, left at 0,1440 by the very first
failed run (02:05), throttled every later window at that position to about 270 ms a frame whenever it lay above it
(a test window at 1920,1440 ran at 1.7 ms while one at 0,1440 ran at 270 ms; the journal has the story). Draw calls,
primitives and pictures were not affected. Section 1 gives the draw-layer figures both ways: re-measured at 02:55 on
a quiet window, and as first taken at 02:10.

## 6. Simulation is untouched (item 3)

`bash tools/view.sh check` runs the packs headless (`world.sh run --mode=bot --frames=36000`) and windowed with the
draw layer on until every bot has ended, and compares the state hash of every pack.

| pack | headless (`world.sh run --mode=bot`) | drawn, run 1 (stage paddle, cam court) | drawn, run 2 (stage wall, cam yard, stand-ins auto at 150 m) |
|---|---|---|---|
| seed_drive | 36635c049bc6acd8 at tick 3516 | same | same |
| seed_paddle | cadd1cd9fffac7b1 at tick 6776 | same | same |
| seed_wall | 6366b88f838e3e78 at tick 1221 | same | same |
| ex_kit | 16db2bf1a53a1798 at tick 332 | same | same |
| ex_walker | 8d1831dc62dfe91a at tick 371 | same | same |

A third run at 02:57 on the final files (stage drive, cam chase, stand-ins auto at 150 m): the same five hashes at
the same ticks. All three runs: 0 gate leaks, 0 wrong-pack calls, 0 script errors, 0 engine errors; `PASS view.check`.
Run 1 was taken at 02:18 (plot cut in, before the rim and the ground holes), run 2 at 02:37 (before the last stand-in
change). Pictures taken during the runs: `captures/check_from_paddle.png`, `check_from_wall.png`,
`check_from_drive.png`. The bot hashes of the three seeds are the ones in N2's report.

`check` runs the window without `--fixed-fps` (`TL_VIEW_REALTIME=1`): a pack's hash depends on its own tick count
only, and a frame that takes 270 ms on the busy machine is then followed by up to 8 physics ticks instead of one, so
the run to the end of the longest bot (6776 ticks) stays bounded.

What the draw layer writes on a pack's nodes, all of it drawing state: `set_instance_shader_parameter` (`tl_plot`,
`tl_clip`), `custom_aabb`, `extra_cull_margin`, the metas `tl_draw` and `tl_clip`, `visible` of the kernel's holder
node and of HUD layers, `ctx.on_stage`. It adds no node to a pack and moves none.

## 7. A single pack looks as it did

One frame per seed through `tl.sh capture` (`tools/look.sh one`), against `look/after/`:

| capture | against `look/after/` |
|---|---|
| paddle, `court`, frame 400 | byte-identical |
| drive, `chase`, frame 110 | PSNR 116 dB (a handful of pixels one step apart) |
| wall, `yard`, frame 330 | PSNR 54.6 dB; looked at: the same picture (dust puffs and the swaying grass are driven by the shader clock, which is wall time) |

`tl_plot` and `tl_clip` are zero there and both branches in `vertex()` are skipped; `tl_hole_n` is 0 and its loop
runs no iteration. The one line that every toon fragment now executes is the test `tl_clip.x > 0.0`.

## 8. A pack with a material of its own

No seed and no example uses one (`foreign: 0` in every `tl.view/1` line of the five-plot world). Tested with the
kernel's own bad pack: `--packs=ex_walker,bad_bypass,ex_car --mode=smoke`, `bad_bypass` 40 m east of the stage.
The draw layer reported `"foreign":1,"foreign_names":["World/.../HandMadePart"],"mirrors":1`, and in
`captures/foreign.png` the part lies at its plot, not at the stage pack's origin. One instance, one picture: that
is all the evidence for the foreign path.

Yaw of a non-stage pack: `captures/yaw_0_vs_90.png` (same camera, paddle at yaw 0 and at yaw 90): the venue is
turned as a whole, and its shadows still fall the way the world's sun says.

## 9. Limits

- Wall-clock frame times were taken on a machine shared with other sessions; see the note under the cost table.
- The plot is a circle and its radius is a number given by hand. Nothing in a pack says how much of its scene is
  the venue (PATCHES 6). A venue wider than its plot is cut.
- A pack's whole terrain and forest are still submitted and run through `vertex()`; only the fragments are saved.
  The five-plot world draws 2.6 to 3.3 million primitives from a stage camera, most of them cut away. The kit should
  build no far sheet and no forest beyond the plot when a pack is built for a world.
- Something merged in pack coordinates that stands in the 9 m band at the plot edge floats or sinks by the amount
  the terrain under it was bent. Choose the radius beyond the venue.
- Seen from far at a grazing angle, small ink marks appear along the bent rim of a plot (`far_off.png`, at the
  left plot): the bend makes small steep faces where the terrain was uneven.
- Stand-ins: no moving parts, no lights, no particles, no decimation; the stand-in is not rebuilt when the pack
  changes (a wall that was knocked down stands again at a distance).
- A hidden far pack has `is_visible_in_tree() == false` on all its nodes; pack code that reads it would see that.
- Lights of non-stage packs are followed once per drawn frame, not per tick.
- The world host has no watchdog and quits the process when its last pack ends (PATCHES 3).
- Not looked at: yaw on the stage pack (the sun is not turned), `GPUParticles3D`, decals, glass and water close up,
  shadow quality beyond the style's 300 m shadow distance, more than 32 plots with terrain (the hole list is 32 long).

## 10. What a pack author must know

- Nothing changes for a pack that follows API.md: build under `ctx.root`, place with `position`, take every material
  from the style (`TLStyle.material`, the kit, `TLBodies`, `TLStyleFx`). Such a pack is drawn at its plot by the
  shaders, with its shadows, lines, rigs, particles and lights, and its state hash does not change.
- Your pack is a venue, not a landscape. In a world it is cut to a circle around its origin; your terrain beyond it,
  your forest and your cliffs are not drawn, and the world draws its own ground. Keep everything that matters well
  inside the radius, and keep 9 m free at the edge (your ground is bent there to meet the world's).
- A material of your own is drawn at the right place, but it is not cut to the plot, it is missing from the far
  stand-in, and it costs the world work on every frame. It is counted.
- At a distance your pack is one merged still picture of itself, taken when it was first far: no moving parts, no
  lights, no particles. Do not put the one thing a far visitor should see on a moving body.
- Do not use instance shader parameters, node metas or `custom_aabb` named `tl_plot`, `tl_clip`, `tl_draw`: the world
  writes them on your visuals. Do not read `visible` of your own nodes to decide game state: a far pack is hidden.
- Your HUD and your cameras are shown only while the player is in your pack.
