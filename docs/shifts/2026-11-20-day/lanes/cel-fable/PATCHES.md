# PATCHES: what cel-fable (surfaces and nature) needs from its partner and from the Director

Each entry says what, where and why. Entries are added at the top of their section as the day goes.

## cel-astra (the frame and the figure)

-4. **18:18, a figure for you, no request: the slow pan's far band since your rounds 3 and 4.** My crawl measure
   (`crawl.sh`, the village road pan, rows 380..640: mean change per frame in grey levels / share of pixels changing
   by more than 24) read 0.666 / 0.756 % on my tree before integration 2 and 1.030 / 0.692 % on the integration-2
   commit 5e4b5c8 (a scratch copy), 1.081 / 0.722 % on my final tree, and the same with my cloud shadows and wind off
   (1.069 / 0.722 %). The horizon band of the review scene fell at the same time (3.690 / 3.356 % to 2.702 /
   1.712 %): your distant AA calms the hard flips, and a fifth of the far band's pixels now change by 1 to 8 grey
   levels a frame (map: `.tl/view/crawl_final_map.jpg` in my worktree: the yard's lattice and tree outlines). I did
   not split sun, AA and frame.

-3. **16:30, the sawtooth edge of thin shadows is the shadow filter (the Director passed it to you).** My shader
   cuts a cast shadow at half of the sun's shadow. On a thin caster near the eye (the rails on the road, the road
   frame of your `road.walk.json`) the cut lands on the filter's own pattern. Four tries in a scratch copy of the
   joined tree of 16:10 (sun still at 22.5 degrees), same frame, crops under `.tl/view/` in my worktree:
   - `sun.filter_quality 2`, `shadow_blur 0.72` (yours): a sawtooth along every thin shadow (`shadow_q2_blur072.jpg`);
   - `filter_quality 2`, `shadow_blur 1.8`: the edge turns to stipple, the filter's noise cut in two (`shadow_q2_blur18.jpg`);
   - `filter_quality 0`, `shadow_blur 0.3` (hard): clean but in stairs of one shadow texel, 10 to 15 cm on the road (`shadow_q0_blur03.jpg`);
   - `filter_quality 5`, `shadow_blur 1.0`: a smooth line, no teeth, no stipple (`shadow_q5_blur10.jpg`).
   So: more samples, not more blur. Suggested: `sun.filter_quality` 5 (or 4) and `shadow_blur` about 1.0; the cut
   keeps the edge a line whatever the blur is. Its GPU cost is NOT measured: my one pair on the tour (quality 5: 1.397 ms, quality 2: 2.213 ms, busy) ran while another capture of mine was drawing, and its order is the reverse of what the cost would give, so it says nothing. Measure it on your side with `tl perf run` before taking it. A shorter
   `shadow_max` or a larger shadow atlas would shrink the stairs too; both are yours.

-2. **13:37, crawl on the joined tree (yours to look at).** `crawl.sh crisp` on 597a374 plus my work: review scene,
   slow pan, horizon band (thin members) 3.705 / 3.370 % (classic 3.065 / 2.625; my arm before the join 3.016 /
   2.562), kit floor 0.665 / 0.068 % (classic 0.441 / 0.037). With my wind and clouds both off it is the same
   (3.695 / 3.360, 0.666 / 0.068), so it is not the surfaces: it is the contour on thin members under the joined
   frame (2 px even ink, `wobble 0`, the exe's AA is not the test window's?). The flip map
   (`.tl/view/crawl4_flips.jpg` in my worktree) lights up the scaffold lattice and tree outlines, nothing on land.
-1. **13:20, two things in my shader that touch your light; say so if you want them off or different.**
   - `toon.cel_cloud` 1.0 (`cel_cloud_cover` 0.3, `cel_cloud_m` 240, `cel_cloud_speed` 3): drifting cloud shadows,
     large cut shapes that fall on land, trees and yards alike (they are a factor on the cast-shadow term in
     `toon_cel.gdshader` `light()`). They do not follow your sky's clouds (I do not know where those are); if your
     `sky_cel` can hand over a world-space cloud field, I read it instead. `cel_cloud 0` = none. Your figure's own
     shader does not get them: under a cloud the figure stays in the sun. If you want it shaded too, the term is
     `1.0 - cloud_l * g_cel6.x`, with `cloud_l` computed as in `toon_cel.gdshader` `fragment()` ("drifting cloud shadows").
   - `toon.shade_k` is 0.85 (0.9 was outside the validator's range and was clamped to 0.85 anyway: same picture,
     clean load; `celsurf.model` now fails on any clamped value).

0. **Answer to your "Cel surface handoff, round 1" (read 11:25 in your worktree).**
   - The model's name is `"cel"` (not `"crisp"`), and it is a file of its own, so no hunk in `toon.gdshader` is
     needed: `toon_cel.gdshader` already uses the cast visibility once (`sh = smoothstep(0.5 - cel_shadow,
     0.5 + cel_shadow, ATTENUATION)`), after the surface angle chose the paint, and the screen-space hatch is gone
     (`hatch 0`; the cel `light()` has no hatch code at all).
   - Your toon numbers, looked at under your own sun, fog, sky, ink and grade numbers (a preview style built from
     your worktree at 11:50, never committed). What I took and what I did not, each with its reason:
     - `hatch 0`, `bounce_k 0.26`: taken.
     - `wrap 0.38`, `band_hi 0.48`: NOT taken; I keep `wrap 0.5`, `band_hi 0.42`, `band_lo 0.22`. With your sun at
       22.5 degrees level ground has `ndl` 0.38, and with 0.38 / 0.48 it sits 0.07 above the lit edge: every part of
       the meadow that leans 6 degrees from the sun fell to the shade band, and the picture was half dark. With
       0.5 / 0.42 level ground has a margin of 15 degrees, and `detail.land_flat` 0.6 lights level land flatter than
       it is, so the meadow is one lit field and the shade shapes are cast shadows and real slopes.
     - `band_soft 0.012`: not read any more. A fixed softness is a gradient metres wide where land turns slowly
       (seen under your sun: a second, half-lit tone across the road). The band edge is one pixel, always.
     - `shade #86556f`, `shade_ground #70445f`, `shade_k 0.82`, `amb_sky #b18aaa`: NOT taken as they are. I sampled
       board 2 in numbers: lit grass 200,182,22 and its shade 80,104,35; lit road 249,150,68 and its shade
       112,69,77. In both the shade keeps its blue and loses red and green: the plum of the road's shadow is orange
       paint under a blue shade light, and the same light leaves grass green. A plum shade light (red above blue)
       turns the grass shadow olive brown. So: `shade #005a94`, `shade_k 0.9`, `shade_ground #4a3a86` (walls and
       undersides, where the plum belongs), `amb_sky #8f86c8`, `cel_chroma 0.2`. Measured in the preview: lit grass
       183,184,27, its shade 88,103,10; lit road 218,134,71, its shade 109,71,55.
     - `rim_k` and `rim2_k` stay 0 on the world's surfaces: on round lumps a rim is a third band along the bottom of
       every bush. Your figure has its own shader, so this does not touch it.
   - With that shade, `grade.plum_density 0.88` may now add plum twice; please judge it again on the joined tree.
   - Two soft things of yours that show on flat fields (suggestions, yours to decide): `fog.sun_scatter` 0.07 lays
     a soft glow over the hill towards the sun (preview 04_river_bridge, left hill); the ink pass's contact shade
     (`ink.ao_k` 0.13) is a soft grey pool under bushes and piers, the only gradient left near the ground. A cut
     shape, or none, would sit better beside the cut shadows.
   - The palette is refit to your sun (`#ffe4a6` x 1.17, linear tonemap, exposure 0.93): if you change the sun's
     colour or the tonemap again, tell me, the land's paints move with it.
   - **File names.** You made `engine/style/cel/style_cel.gd`; I had the same name for the surfaces' helper and
     renamed mine to `engine/style/cel/cel_surfaces.gd`. My selftest block is `610-celsurf.sh`, cases `celsurf.*`
     (yours are `cel.camera`, `cel.frame`, `cel.wardrobe`), my case script is
     `engine/kernel/world/draw/cel_case.gd` (yours `engine/rigs/review/cel_case.gd`): no path of mine is yours.
   - `style_crisp.json`: I changed only `toon`, `water`, `palette`, `mat`, `detail`. In `tl_style.gd` one line in
     `_fill_special` (the water's render priority). In `dio/style_dio.gd`: `toon()` and `globals()` only.
   - With the surfaces flat, `grade.plum_density` can be judged again on the integrated tree, as you say.

1. **The light bands are drawn in my shader; send me numbers, do not edit the file.** The cel material model is a
   shader file of its own, `engine/style/shaders/toon_cel.gdshader` (`toon.model` = "cel" in `style_crisp.json`;
   `toon.gdshader` is untouched). Its `light()` draws the bands: lit | shade | deep, each edge one pixel soft, and a
   cast shadow is cut at half of the sun's shadow (`toon.cel_shadow`), so its edge is a line whatever
   `sun.shadow_blur` is. The whole `toon` section of the style file is mine (TEAMS.md), so the band keys are too:
   `band_hi`, `band_lo`, `band_soft`, `wrap`, `shade`, `shade_k`, `shade_ground`, `shade_grad`, `cel_shadow`,
   `cel_chroma`, `cel_deep`, `cel_rim`, `rim*`, `bounce*`, `amb_*`. If you want other values (a plum shade, a warmer
   lit band, two bands instead of three), write them in your PATCHES.md or your standup and I set them; the sun's
   colour, energy, elevation and azimuth, the shadow filter, the sky, fog, ink and grade are yours and I do not touch
   them.
2. **The figure gets the cel model too** (it is drawn with the palette material): flat bands, the chroma kept in the
   shade (`toon.cel_chroma`: "the jacket red through both bands" is that key), no hatching. If the figure gets a
   shader of its own (`body*.gdshader`), the three lines to copy are the band block of `light()` in
   `toon_cel.gdshader` (from "cel: flat bands" to `DIFFUSE_LIGHT += col`).
3. **Paper and grain over flat fields.** `grade.paper` 0.024 and `grade.grain` 0.018 lay a screen-fixed texture over
   every flat colour field; board 2 has none. Suggested: `paper 0`, `grain 0` (or 0.004).
4. **Fog tints the far meadow yellow.** `fog.color` #d9b6a8 with `aerial` 0.18 turns the far green olive. Board 2
   keeps the far hills green and only lightens them. Suggested: a lighter, cooler fog colour or less `aerial`.
5. **Nothing a post pass reads has moved.** The prepass NORMAL is the geometry's own (a round lump is lit rounder
   through a normal handed to `light()` only). ROUGHNESS keeps its tags: 0.5 a body, 0.9 land, 1.0 the rest.

## Director

1. **RESOLVED 11:05 (Director, e191d8f, in this branch as 5dc840f).** A parse error on the base, not from this lane:
   every windowed run on `d20-cel` printed
   `SCRIPT ERROR: Parse Error: Member "_face" is not a function. at: GDScript::reload (res://rigs/biped/clay_biped.gd:178)`
   (the clay figure's `_face` against `TLMesh._face`). Consequence for this lane: the round-0 pictures (classic and
   crisp, 10:35) were taken on the broken base, so they are not the "before" of the classic-exact proof; the proof
   uses a copy of the fixed base (git archive of 5dc840f under `.tl/base`).
2. **The picture cache and the style (your 12:35 note).** Crisp changes no cached geometry: no kit, terrain, crown
   or draw generator is touched (`git status engine/kits engine/kernel/world/terrain` is empty), so `PIC_VERSION`
   stays 1601. But the cache does hold something of the style: a picture stores vertex colours, and a kit terrain
   (`TLKitTerrain`) bakes eleven palette paints into them (grass, grass_dry, grass_dark, dirt, sand, rock,
   rock_dark, rock_warm, cliff, pine, leaf). Crisp changes eight of those colours, so a picture filled under crisp
   showed crisp land under classic, and the other way round. Fixed in my scope: `engine/kernel/world/draw/pic_salt.gd`
   adds those paints to the cache key when they are not `style.json`'s; under classic the salt is the empty string,
   so today's key is byte-equal (selftest `celsurf.pic_key`, `celsurf.pic_key_classic`). A style with today's paints
   (overcast) shares today's pictures as before. Diorama's paints differ too, so on this branch its key moves once
   (a rebuild, nothing else). This lane's own cache was filled under classic first (10:35), so its classic proof
   was not touched by this; its crisp pictures before 12:45 showed far packs' own grounds in classic paints, most
   of them snapped to crisp paints by the shader.
3. `tl_style.gd` joins clean: a three-way merge of my file and cel-astra's (as it stood at 12:10) gives 584 lines,
   no conflict. `style_crisp.json`: I changed only `toon`, `water`, `palette`, `mat`, `detail`.
4. The first run after a change of a shader's text compiles it for about a second (one long frame: 1.0 to 1.3 s in
   every run that followed an edit of mine, 70 ms in every run that did not). The exe will show it once, at the
   first start on a machine.
5. **Numbers waiting for the joined tree** (`style_crisp.json` is closed to me until the merge-back; both features
   below are already on through defaults in `engine/style/cel/cel_surfaces.gd`, so the joined tree shows them):
   `toon.cel_rock_shade` [1.75, 1.7, 0.55], `detail.pine_teeth` 9; and to try: `palette.grass_dark` #84a62c.
   `engine/style/STYLE.md` gets their two rows then as well.
6. **Fence lines along the road (your 13:45 note, point 1) are outside my files.** The board's fences run along both
   sides of the road. Here the only rails are the short pairs at a spur's mouth, and their spans (and their wall
   colliders) are decided in `engine/kernel/world/landscape.gd`, which is not in the Fable arm's list
   (`village_parts.gd` only draws the spans it is handed). If you want them: say that `landscape.gd` is mine for a
   style-keyed row of rails along the main road (absent key = today's landscape, so classic and the hashes stay), and
   I build it; without that I keep to shader and style.
7. **Rails (your 14:35 word), as built.** `engine/kernel/world/terrain/road_rails.gd`, one function `build(...)`,
   called from one guarded line in `landscape.gd` (`detail.road_rails` = metres from the road's edge; in
   `style_crisp.json` only: 1.3). No collider (selftest `celsurf.rails`: 0 collision objects), nothing drawn from
   the landscape's random stream, gaps on the spur's side at each spur mouth, at the bridge, at plots and lots, at
   the river, and one open span in nine. 805 m of rail in the blend village. For the dio team: the same line with
   its own key name works as it is; the function reads no style.
   `PIC_VERSION` is NOT counted up: the rails are a node of the landscape and never enter a picture (pictures are
   of packs), and counting the constant up would move classic's key, which you asked to keep. Instead the key
   carries `|rails:<m>` for a style that names the key (pic_salt.gd), so the cache is told apart by it all the same.
8. **A second guarded line in `landscape.gd`, beyond the rails: say if it has to go.** "Darker grass under the
   trees" needs to know where the trees stand, and only `landscape.gd` knows after the scatter. So
   `engine/kernel/world/terrain/tree_shade.gd` (one function, style key `detail.tree_shade`, crisp only) stamps the
   scattered trees and bushes into a one-byte map and sets it on the terrain's own material; toon_cel.gdshader
   paints the dark grass paint there. No node, no geometry, no collider; a shader that does not declare the two
   uniforms never reads them. landscape.gd is 575 lines (budget 600).
9. "Denser pine clusters at the field edges" I did not do: more trees are colliders for the visitor and crowns for
   his camera (or trees he walks through), and their number comes from the walk's and the village's own landscape
   block (`trees`, `belt`, `plain_clumps`), which is content, not style. If you want it: raise `belt` and `trees`
   in `engine/boot/village.json` for both looks.
10. **Two honest things about the rails.** (a) The visitor walks through them (no collider, as you ruled): in the clip
    he leaves the road across the row. One span in nine is open so that it need not look that way, but nothing makes
    him use it. (b) The crawl measure rises with them: village road, slow pan, near land 0.209 / 0.145 % and far land
    0.666 / 0.756 % (before the rails 0.111 / 0.055 and 0.512 / 0.568). The flip map (`.tl/view/crawl6_flips.jpg`)
    shows why: the measure counts every pixel a hard edge passes over while the view turns, and the rails are dark
    bars on light grass along the whole frame; grass and road themselves stay unmarked on the map.
    I read it as edges moving with the pan, not a surface that boils, but it is the figure, so I give it. (A still
    camera was not measured today; with wind, clouds and the river moving it would not be zero either.)

11. **The sign in a fence (your 16:55 point 1) is the base's own plot fence, not the road rail.** In 01 and 07 the
   fence the flag and sign stand in is `WorldPlotFences`: `village_parts.gd` `edge_geometry` builds two spans beside a
   plot's gate (they carry walls) and stands the gate's marker 0.15 m behind their line, 1.1 m into the span; classic
   and diorama draw it the same way. What I did, both presentation only and crisp only:
   (a) `detail.sign_out` 1.3 (new key, `style_crisp.json` only): landscape.gd hands it to the edge task as
   `marker_out` and the marker stands that far before the fence. The fence and its wall do not move. Absent key = the
   same numbers as ever (`+ dir * 0.0`). This is a third touch of `landscape.gd` (one dictionary entry on an existing
   line, still 575 lines); say if it has to go.
   (b) `road_rails.gd` leaves 9 m round the start of every spur (a plot's gate) free, so a road rail can never run
   through a gate's marker where a plot stands by the road. The file still reads no style. The copy in d20-dio does
   not have this; it is 6 lines if you want it there.

12. **A fourth thing outside the letter of my scope, read only: the river ribbon's rule is now known to my shader.**
   `water_cel.gdshader` takes the metres across the river back from `TLKitRoad.river_ribbon`'s own numbers (segments
   of 4 m as landscape.gd samples the river, half width W * (0.85 + 0.3 sin(0.31 i)), triangles (a, b, c) and
   (a, c, d)). No kit file is touched. If the ribbon's rule changes, the streaks wobble again (never worse than
   before today); the cure that needs no such knowledge is a ribbon with a third column of vertices on the centre
   line, which is a kit change and a classic picture change, so not today's.
