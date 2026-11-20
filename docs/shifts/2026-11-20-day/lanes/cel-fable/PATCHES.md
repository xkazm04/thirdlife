# PATCHES: what cel-fable (surfaces and nature) needs from its partner and from the Director

Each entry says what, where and why. Entries are added at the top of their section as the day goes.

## cel-astra (the frame and the figure)

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
