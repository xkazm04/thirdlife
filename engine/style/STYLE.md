# Style (`TLStyle`, kernelApi 0.1)

The whole look is data: `style.json` (golden hour) and `style_overcast.json`. Swapping the file changes palette, sun,
toon bands, fog, sky, ink and grade with no code change. All state is static: **no autoload, no project setting**
(the 16 global shader parameters are added at run time by `TLStyle`).

```gdscript
var notes: PackedStringArray = TLStyle.load_style("res://style/style_overcast.json")   # optional: style.json loads itself on first use
TLStyle.install(world_root)                 # Sun, WorldEnvironment (painted sky), InkPost, Grade under one `TLStyleRig` child; idempotent
TLStyle.material(&"grass")                  # THE palette material (the same ShaderMaterial for every toon key)
TLStyle.material(&"glass")                  # special materials: glass, water, holo, fx_add, fx_mix
TLStyle.palette()                           # PackedStringArray of palette keys
TLStyle.set_headless(true)                  # normally detected from the display server
```

- `load_style` returns messages. A line starting with `clamped: ` is a note (a value was outside its looked-at range
  and was clamped: the file is applied). Any other line is an error and the file is **not** applied: the previous
  style stays. Unknown sections and unknown `mat` keys are errors. `TLStyle.check(dict)` validates without applying.
- To swap the look at run time: `TLStyle.load_style(other)` then `TLStyle.install(host)` again. Meshes need no
  rebuild as long as both files have the same palette keys in the same order (the two shipped files do): a mesh
  stores the palette **column** of each face, and the colour is read from a lookup texture built from the file.
- `install(host, {"ink": false, "grade": false})` leaves the post-process passes out (for measurements).
- Extras used by the kit: `TLStyle.color(key)`, `TLStyle.num(section, key, default)`, `TLStyle.has_key(key)`,
  `TLStyle.material_instance(key)` (a private copy of a special material), `TLStyle.push(section, material)`.
- `tl_style_fx.gd` (`TLStyleFx`): lane-B particle and glow helpers (`sparks`, `dust_burst`, `smoke`, `nitro_trail`,
  `tyre_dust`, `glow`). They create `CPUParticles3D`, which run on the engine's clock: visual only, never state.
  `TLStyleFx.preset(name, {life_frames, one_shot, direction, scale, color})` is the in-style effect for each kernel
  `TLVfx` preset (`TLStyleFx.preset_names()`); the kernel calls it, a pack calls `TLVfx`.

**For a pack author: you call none of this.** The kernel installs the style in windowed runs and asks it for
materials. The three seams the kernel uses (added in WP5):
- `TLStyle.flat_material(color, metal = 0.0)`: the toon look in one flat colour, for geometry `TLMesh` did not build
  (the box or sphere behind `TLBodies.make(..., {"color": ...})` and `TLBall`). One material per colour.
- `TLStyle.ground(y = 0.0, key = "", half = 2000.0)`: a very large flat ground in a palette colour (`env.ground_key`
  in the style file, else `grass`), visual only. The kernel adds it when a pack built no kit ground.
- The environment's ambient light is the mean of `toon.amb_sky` and `toon.amb_ground` times `env.plain_ambient`
  (default 1.0). Every style shader ignores it (they are `ambient_light_disabled` or `unshaded` and bring their own),
  so it only lights materials the style did not make: a `StandardMaterial3D` is readable, though it has no bands and
  no drawn surface. The right fix for such a material is not to make it.

## HUD · Split Ticket

The HUD takes its shapes from race bibs and printed timing slips. A numbered tab identifies the stage.
The next move gets its own clipped paper ticket. The split sits on ink. Its previous best and the signed
difference share a line directly beneath it. The checkpoint count leads the row of filled and open punches.
The controls legend wraps into short rows so a player can place the next move at bottom centre. The finish docket
sets the stage, split and personal best in aligned columns and marks the total with a perforation.

`hud/stock.gd` owns the paper, ink, accent, accent text, timing marker and gain colours for Signal red,
Relay blue and Night meet. The shared Archivo variable face uses condensed heavy cuts for the action and
tabular figures for time. Its OFL licence travels with the font in `hud/`. Text widgets use the same
typeface and inks. A plate has a registration stripe, and an empty label leaves the course clear.

Judge size in a native 1280 × 720 capture. At Regular size, aim for at least 16 pixels of visible digit height
for the split comparison and checkpoint count, and 12 pixels of capital height for their captions and keycaps.
Free and bound labels respect the pack's `TLHud.font_size` at this resolution.

`hud/ticket.gd` draws the instruments on a 1280 × 720 design surface. `hud/sheet.gd` fits it uniformly
to the available screen, stacks instruments at each occupied anchor, and holds the edge in place as
text wraps. The creator uses the same sheet, with author-supplied sample readings over a course still.
The default margin is 22 units horizontally and 19 vertically. In the village the HUD also clears
the build tag above and leave-game hint below, while preserving the size of the type. The player's three widget sizes are
0.82×, 1× and 1.22×. The kernel API's TLHud section documents the two pack-local data files.

## Headless
Under `--headless` (or after `set_headless(true)`): no shader is loaded, no texture is built, no global shader
parameter is touched, `install` adds an empty `TLStyleRig` node, and `material(key)` returns one shared
`ShaderMaterial` with no shader (it answers `set_shader_parameter`). Palette queries, `load_style` and validation
work as usual, so parts and layouts build identically.

## Style file
Sections: `name`, `sun`, `toon`, `env`, `fog`, `sky`, `ink`, `grade`, `holo`, `water`, `palette`, `mat`, `detail`,
`lights`, `fx`. `palette` is `key -> "#rrggbb"`; a new material is a palette colour plus an optional `mat` entry:
`mat.<key>` = `{class: none|wood|concrete|steel|tarmac|ground|rock|roof|fabric|masonry, dscale, dk, emit, metal,
mottle, no_hatch, ice, dissolve, sway, shader: glass|water, base_a, fres_a}`. The clamp ranges are the `RANGES`
table in `tl_style.gd`.

Rink markings are drawn by the toon shader on any surface whose material has `ice: 1` **and** whose UV carries the
sheet's half length and half width (the `rink` part writes them): each rink draws its own markings in its own space,
so any number of rinks of any size and yaw work. UV (0, 0) = plain ice (ponds, `ground_patch` with `surface: ice`).

## Shaders (`style/shaders/`)
`toon` (the one palette material: bands, hatching, drawn surface detail per material class, ice, dissolve, sway),
`ink_post` (outline pass on depth and normals), `grade`, `sky`, `holo`, `glass`, `water`, `fx_add`, `fx_mix`.

## N1 look pass (2026-11-11)
New data keys (all optional; absent = the old behaviour, except where a default is named):
- `ink.near_px`, `bold_near`, `bold_far`: contour width in px (at 1080) up close, and the metres over which it
  falls to `outer_px`. `ink.even` 0..1 damps the width noise. `ink.thin_keep` 0..1: a member narrower than the line
  keeps its colour and gets a hairline (`hair_alpha`) on its lower right side instead of a full contour.
  `ink.inner_near`, `inner_far`: the crease line's own distance rule (full to, gone at; metres).
- `ink.ao_k`, `ao_radius`, `ao_far`, `ao_color`: contact shade drawn by the ink pass (8 depth taps). The engine's SSAO
  was measured and does nothing to the toon shader (it is `ambient_light_disabled` and writes its own light).
- `env.line_aa`: `smaa` (default), `fxaa` or `off`: screen-space smoothing set on the host viewport by `install`.
- `env.dof_far`, `dof_far_transition`, `dof_amount`: far blur for cameras without attributes. Shipped **off** (0):
  at 0.06 and at 0.02 it blurred the far contours that the concept keeps crisp.
- `sky.sun_draw_elev`: degrees above the horizon at which the sun disc and glow are painted; the light itself
  (`sun.elev`) stands higher so that venues are lit and shadows are short.
- Golden style values changed: sun `#ffd9a0` x 1.12 at 21 degrees, shade `#5a60c0` k 0.70, bounce 0.3, grade sat 1.24,
  contrast 1.14, split 0.06, fog `#d9b6a8`, tarmac `#66666e`.

Toon shader, class `ground`: tone patches with a crisp wobbly edge; `ground_marks()` draws tufts (grass only; they
stand upright on screen), pebbles (anywhere), scratches and grit (dirt only), and one drawn edge where grass meets
dirt. Grass or dirt is read from the vertex colour (green above red = grass). The kit's terrain gives ground that is
not steep one colour and one normal per grid vertex, so its triangles no longer show.

`TLStyleFx.squash(visual, amount = 0.25, frames = 18, axis = UP)` and
`TLStyleFx.trail(target, {width, frames, color, offset})`: squash and stretch on a visual node (never a body) and a
fading ribbon behind a moving node. Frame-counted, visual only. A pack cannot reach them yet (there is no `TLVfx`
seam for them): see the N1 report.

## N5b: a world of several packs (kernel/world/draw/DRAW.md)

Three parameters were added for the world's draw layer; a single pack never sets them and is drawn as before.

- `instance uniform vec4 tl_plot` in toon, glass, water, holo, fx_add, fx_mix: xyz = offset (m), w = yaw (rad) of
  the pack's plot relative to the stage pack. Not zero: `vertex()` draws the instance at `plot * MODEL_MATRIX`
  (shadow pass included). World-anchored noise (`wpos`) stays in the pack's own coordinates.
- `instance uniform vec4 tl_clip` in toon: x = plot radius (0 = no cut), y = height of the world's ground at the
  plot edge in pack coordinates, z = width of the band in which the pack's ground is bent to it, w = 1 on terrain
  sheets. Outside the radius an instance is dropped (by its origin) or cut (per fragment, 3 m further out).
- `uniform int tl_hole_n`, `uniform vec4 tl_holes[32]` in toon: only on the world ground's own material; the plots
  are cut out of it (xy = centre in the ground's part-local x and z, z = radius).

A new style shader that packs can reach must declare `instance uniform vec4 tl_plot` and apply it in `vertex()`,
or the draw layer treats its geometry as foreign and mirrors it (correct place, per-frame cost, no plot cut).


## P3 look pass (second pass, with motion)
- Sky: clouds are drawn clumps on the dome (azimuth, elevation) with flat bases and bumpy tops, three flat tones from the slope towards the sun, an ink contour on the
  shade side. Style keys (section `sky`): `cloud`, `cloud_shade`, `cloud_cover` (0..1 share of cells with a cloud), `cloud_scale` (clumps per radian), `cloud_high`
  (raises them), `cloud_puff` (size), `cloud_line` (contour strength), `cloud_ink`. The gradient reaches mauve and blue sooner, and the horizon is gold, not pink.
- Far cliffs and mesas (palette class `rock`): drawn strata at any distance: bands of world height (`detail.strata_m` x 2) with a tone each, ink seams that stay at least
  one pixel wide, vertical streaks, warm light on the sun side. `palette.cliff` is a purple grey.
- Grass: broad soft patches from a warm olive-yellow to a cool blue-green in two scales (in `toon.gdshader`, ground class, grass only); the N1 crisp patch edge is soft.
- Ink: `outer_px` 4.0, `near_px` 4.8, `bold_far` 140, `thin_near` 60, `thin_far` 220, `outer_far` 0.7: contours at 30 to 120 m keep their weight.
- Light: `toon.rim2` / `toon.rim2_k` = a cool rim on the side that faces away from the sun (global `g_rim2`); `toon.bounce_k` 0.42.
- Effects (`TLStyleFx.preset`): dust and smoke are larger and more opaque; sparks, nitro flame and goal flash grow in over their first frames instead of appearing at full size.

## Bodies that move (walker-feel, 18 Nov 2026)
Shading anchored to the world or to the screen crawls over whatever moves through it. Measured on the walking figure
(frozen pose, rigid camera, 4.5 m/s: mean change per frame 1.20 of 255 on his back, floor of the meter 0.31): the sun's
shadow map on himself (about 40 %), the world-anchored mottle (about 25 %), amplified by ink and grade. So:

- `instance uniform vec2 tl_body` in `toon` (zero on everything that is not a rig; `TLRigs` sets it on every mesh of a rig).
  `x = 1`: the mottle is read in the part's own space; the hatching is drawn ON the body (strokes in each part's own
  space; the spacing follows the distance in octaves so the strokes stay near `toon.hatch_px` pixels); the two rim lights
  are drawn only where the surface curves (a flat face at a grazing angle lit up whole: the sole of a boot kicked up
  behind flashed blue); `ROUGHNESS` is written as 0.5 (the toon light never reads it), which marks a body in the
  normal-roughness buffer for the ink pass.
  `y` = metres the body's shadow CASTER is moved down the sun's rays (`vertex()`, shadow pass only; nothing below 0.2 m
  above the instance's origin, in full from about 0.6 m): the shadow on flat ground is the same, and no part of the body
  shadows another. Shade from the world still falls on it. A rig sets 0.6 x scale (biped, bot), 0 (vehicle).
  Limit: on ground that rises steeply away from the sun the lower part of the shadow can thin out.
- `ink.body_k` (default 1.0 in the shader, 0.55 in both shipped styles): the contour width on a body as a share of the
  width anywhere else; the contour's screen wobble is 30 % there. The contour is drawn inside a silhouette, so on a
  figure 170 px tall the full width left a dark blob. `ink.body_dbg` 1 paints what the pass takes for a body.
- On a body pixel, an inner-ring tap with roughness at least 0.8 can see the ground or a wall behind the rig.
  Its depth gap adds contour weight, starting at 4 cm and reaching full strength at 12 cm. The crease taps already
  read this roughness and depth. The wide ring and thin-member classification still use the grazing-weighted depth test.
  At tick 310 of the village bank approach, the share of the figure's inner boundary carrying half-strength silhouette
  ink rose from 45.2 % to 94.8 %. On the running figure's frozen rear silhouette, mean frame change fell from 3.24
  to 2.85 grey levels over 50 frame pairs.
- After: 0.43 on his back at 4.5 m/s, 0.62 at 9 m/s (was 1.20 and 1.68). Measure again: `look.sh clip rig:run:4.5:0:behind
  out.mp4 130` with `RIG_ARGS="--freeze-at=90"` (add `--no-body=1` for the old shading) and difference the frames inside
  the figure.
- Palette: `pants` is denim blue `#4d5a8c` (was a purple that merged with the ink), `pack` canvas tan `#c2975a`.

## Terrain crests

The toon shader writes roughness 0.9 for the ground material class. The silhouette brush keeps its original tap
positions and full weight. At terrain pixels with less than 65% brush weight, a second decision checks the ground
one inner-ring radius above and below the texel centre. A receding upper tap beyond twice the lower reciprocal-depth
slope adds a crest stroke. Its original 65% response curve levels off at 55% brush weight (0.528 near-field opacity).
Reciprocal depth varies linearly across a projected plane, so a continuous slope adds none.

Where all three texels carry the ground tag, the brush also checks its original vertical taps at the wide radius.
If those taps see a receding ridge beyond twice the foreground reciprocal-depth slope, the brush keeps its soft
flank there, even when the inner taps both land below the ridge. On a grazing plane, brush weights through 0.375
drop out and weights from 0.6 keep their full strength. The wide test reuses the brush's depth reads. The centred
inner test reuses its original samples when they land in the required texels. A mismatch costs three depth and
two normal/roughness reads.

## Thin members far away (walker-feel, lane T's item L1)
Lane T measured that the shimmer of the picture sits on the far fences, scaffolds and trees and comes from the ink pass.
Measured here on a slow pan (a quarter of a pixel a frame over rail and mesh fences, scaffolds, a crane and trees at 15 to
70 m; `look.sh boil`): share of pixels in the horizon band that flip by more than 24 grey levels in one frame, and the mean
change per frame.

| ink variant | flips % | mean |
|---|---|---|
| no ink at all (the floor: the geometry's own aliasing) | 0.54 | 1.66 |
| shipped before (`thin_keep` 1: hairline on thin members) | 3.17 | 3.37 |
| width noise and wobble anchored to the world instead of the screen (T's proposal) | 3.22 | 3.40 |
| no width noise, no wobble at all | 3.08 | 3.32 |
| no hairline on wires (members under 2 px) | 3.31 | 3.47 |
| thin members get no ink at all | 3.17 | 3.42 |
| `thin_keep` 0 (every thin member a full black contour: the look N1 removed) | 2.50 | 3.02 |
| thin decided from three rings (`thin_rings` 1) | 3.03 | 3.27 |
| **three rings + far thin members toned evenly (`thin_tone` 0.55 from 15 to 45 m): shipped now** | **2.63** | **3.06** |

Reading: the noise is not the cause, and neither is the ink on the thin members themselves. The flips are pixels that change
CLASS from frame to frame: "thin member: keeps its colour, one hairline" against "edge: full contour". In a lattice the two
taps of the wide ring land on the next bar or miss it as the picture moves by a fraction of a pixel, and low over ground
seen at a grazing angle the background is only a few per cent further than the bar, right at the depth threshold. The
ink is drawn per pixel on a depth buffer that is not multisampled, at full contrast, so every change of class is a dash
that appears or goes. What helps is to make the two classes look alike where the members are a pixel or two wide:
- `ink.thin_rings` 1: a member is also thin when both opposite taps of the half-width ring or of the inner ring see the
  background (8 more depth taps a pixel);
- `ink.thin_tone` (0.55), `thin_tone_near` (15 m), `thin_tone_far` (45 m): from there on a thin member is toned evenly
  with that much ink in place of the one-sided hairline (which cannot be drawn on a 2 px bar anyway). Nearer than
  `thin_tone_near` nothing changes: "coloured bars with one dark side".
Gain: 17 % fewer flips, 9 % less change per frame, on top of whatever antialiasing the window has (measured with the
style's SMAA only, no TAA). It is a part, not a cure: the cure is ink that knows sub-pixel coverage (edge taps on a
multisampled depth, or the contour drawn as geometry), which is a look pass of its own.
All four keys are optional; absent = the old behaviour.

## The diorama material model (night of 20 Nov 2026, surfaces)

`style_diorama.json` (the default of the diorama branch; `TL_STYLE=classic` loads `style.json`) names a material model.
A style file without these keys gets the shader files as they are and the same lookup texture: today's look cannot
move (selftest `surf.classic_source`: toon.gdshader without its `TL_DIORAMA` branches is byte for byte the old file).

| Key | What it does (absent = today) |
|---|---|
| `toon.model` = `"diorama"` | toon.gdshader is compiled with `TL_DIORAMA` defined: one smooth ramp from shade to sun (`band_lo` .. `band_hi`) instead of bands, no hatch, and every class is a handmade material. The marks are heights in the part's own space (land: the world's), turned into a normal for the light only. The prepass normal and the ROUGHNESS tags are untouched, so the ink pass sees what it saw. |
| `mat.<key>.gloss` 0..1 | matte clay .. wet paint: a sun highlight and the sky standing in the surface. `toon.gloss` is the value of a key that names none. |
| `mat.<key>.fuzz` 0..1 | felt: light caught where the surface turns from the eye, no highlight. |
| `mat.<key>.chip` 0..1 | painted: brush strokes along the part, and chips that show `toon.chip_color`, first at the edges of a box. |
| `mat.<key>.class` `clay`, `felt` | two more classes. A key with no class is clay (thumb dents, fingerprints up close). The old classes keep their names and are redrawn: wood (boards, grain), concrete (cast, pitted), steel (painted, a parting line), tarmac, ground (felt laid on clay, pebbles pressed in, clay slabs where steep), rock (slabs), roof, fabric (stitched), masonry. |
| `detail.bump`, `bump_near`, `bump_far` | strength of the relief and the distance over which it fades (m). |
| `detail.bevel` (m) | the soft edge of a box face. `TLMesh.box` writes where each vertex is on its face into UV2 (kits/tl_mesh_bake.gd); the shader rolls the last `bevel` metres of the face over by 45 degrees, so two faces end on one normal. |
| `detail.round` 0..1 | a `blob` and the side of a `cyl` carry the round thing's own normal in UV2: lit as round (pines, logs, posts, rocks, bushes), and the tone a blob's facets were given apart is mostly taken back. Geometry, collision and `content_hash` are unchanged. |
| `detail.chip`, `toon.sheen`, `toon.sky_refl`, `toon.spec`, `toon.wax` | global strengths: chips, felt sheen, sky in gloss, sun highlight, the warm turn from sun to shade of modelling clay. |
| `water.model` = `"resin"` | the river is water_resin.gdshader: nothing flows; combed ripples stand still in the world and mirror the sky and the sun. `sky_top`, `bed`, `gloss`, `ripple`, `foam`. |
| `water.shore` (m) > 0 | the resin reads the depth of its bed (compiled with `TL_SHORE`): the bed shows through the shallows, a meniscus at the bank. It is then drawn after the solid world, so a pass that reads depth sees the bed. 0 = a solid surface, the bank from the ribbon's width. |

Rules that keep it still (the walker-feel lesson): every mark has a wavelength and is faded before a pixel is half of it
(`keep()`); land is filtered by the mean of its two footprints (it is seen at a grazing angle); noise corners come from
an integer hash (a float hash of a far cell rounds differently on its two sides: a grid in every gloss); where the lit
normal turns faster than the pixels can follow, the gloss is spread instead of sparkling.
Measured with `look.sh boil` (mean change per frame in grey levels / share of pixels that change by more than 24;
lane script `docs/shifts/2026-11-20-night/lanes/surfaces-fable/crawl.sh`):

| clip, band | classic | diorama (ink as on the base) | diorama with ink and paper off |
|---|---|---|---|
| review scene, slow pan, horizon (thin members) | 3.065 / 2.625 % | 2.804 / 2.471 % | 1.243 / 0.286 % |
| review scene, slow pan, kit floor | 0.441 / 0.037 % | 0.547 / 0.037 % | 0.431 / 0.006 % |
| village road, slow pan, far land and yard | 0.485 / 0.523 % | 0.524 / 0.464 % | 0.322 / 0.176 % |
| village road, slow pan, near land | 0.040 / 0.000 % | 0.166 / 0.003 % | 0.159 / 0.003 % |
| village road, camera still, near land | 0.000 / 0.000 % | 0.000 / 0.000 % | 0.000 / 0.000 % |

Reading: nothing boils on a still camera; under the pan the textured land changes by a sixth of a grey level a frame
where the flat land of today changed by a twenty-fifth, and 3 pixels in 100 000 flip. The ink is what boils: with it
off the horizon band falls from 2.5 % of flipping pixels to 0.3 %.

`engine/style/dio/style_dio.gd` holds the code a model needs (shader variants, the globals `g_dio` .. `g_dio5`); it is
not part of the indexed API. `style_surfaces.json` is the diorama file with ink and paper off, a judging aid of that night.

## The cel material model (day of 20 Nov 2026, surfaces)

`style_crisp.json` (`TL_STYLE=crisp`) names the cel model. It lives in files of its own: `shaders/toon_cel.gdshader`
(it began as toon.gdshader without its `TL_DIORAMA` branches and keeps every kernel hook of it), `shaders/water_cel.gdshader`
and `cel/cel_surfaces.gd` (the globals `g_cel` .. `g_cel3`, `g_land0` .. `g_land7`). toon.gdshader, water.gdshader and
style.json are not touched (selftest `celsurf.classic_files`: their sha256 as on the base), so today's look cannot move.

| Key | What it does (absent = today) |
|---|---|
| `toon.model` = `"cel"` | the palette material is toon_cel.gdshader: flat bands (lit, shade, deep), each edge one pixel soft at any distance (`band_soft` is not read: a fixed softness is a gradient metres wide where land turns slowly); no hatching; class tones are flat per plank, panel, plate and course (no stains or streaks). |
| `toon.cel_shadow` 0..0.5 | a cast shadow is cut at half of the sun's shadow, this far to either side: its edge is a line however the shadow map was filtered, and it falls to the shade band, never to the deep one. |
| `toon.cel_chroma` | chroma the shade gives back to the paint (0 = a plain multiply): grass stays green and a red jacket red in the shade. |
| `toon.cel_deep` | the band of a form turned fully away, as a factor of the shade (1 = two bands only). |
| `toon.cel_top`, `cel_top_k` | a lump (bush, crown, rock) has one more flat shape where it faces the sun squarely: from this much of the light, this much lighter. |
| `toon.cel_rim` 0..1 | the rim lights as a cut shape instead of a gradient (with `rim_k`, `rim2_k` 0 there is none). |
| `detail.round` 0..1 | a `blob` and the side of a `cyl` are drawn with the round thing's own normal (TLMesh UV2), in the prepass too: one terminator, and the ink pass draws the outline of the lump, not a crease on every facet. A blob's facet tones are mostly taken back. |
| `detail.edge` | a painted highlight along the edges of a box face (TLMesh UV2), drawn where the face is in the sun; none on a member thinner than about 5 cm. |
| `detail.land_wobble`, `land_bias` | the land is painted by numbers: its blended pigment is snapped to the nearest of eight palette paints (`grass`, `grass_dark`, `grass_dry`, `dirt`, `sand`, `rock`, `cliff`, `rock_warm`), the edge between two fields wobbles by `land_wobble` and is one pixel soft. `land_bias` {paint: number} lets a paint win more or less ground. Rock never wins on level ground and earth never on a steep face; a pigment that is none of the paints is left as it is. |
| `detail.verge_m` | where grass meets earth the grass side is one tone darker for this width (the cut of the turf beside a road). |
| `detail.marks_m`, `marks_far`, `patch`, `flowers` | scale of the tufts (grass only) and pebbles (earth only), and the distance at which they end (far land is flat colour, not a field of dots); light flat patches on earth and meadow; handfuls of flat dots (cream, yellow, pink) in the meadow, gone before they are smaller than a pixel. The meadow's patches are the `grass_dry` paint (the warm olive of the board's sunlit fields) against the green; the road has light and damp patches of 2 to 8 m and a darker rim along the turf. A tuft points away from the eye along the ground at its own place (it stands upright anywhere on the screen, and does not turn when the eye turns), and is drawn longer on the ground the lower the eye looks along it (as it is at 44 degrees and steeper, up to 2.6 times, never beyond the room of its own cell): painted on the ground, it would lie flat for a low eye. Where a slope shows the ground longer than level ground would (a bank that faces the eye), the tuft is drawn that much shorter (down to 0.4), so tufts are one size on the screen across rolling land. |
| `detail.land_flat` 0..1, `land_dead` 0..0.6 | level land is lit as flatter than it is (`land_flat`), and land that leans less than `land_dead` (the sine of the lean) is lit as level: the small waves of a meadow give no islands of shade (a cut band on a bumpy normal is a field of shards), while a hill's far flank still turns to the shade band whole. |
| `toon.cel_wind` (m), `mat.<key>.sway` < 0 | a scattered tree leans in the wind as one thing: nothing at its foot, `cel_wind` metres at 10 m, the phase from where it stands. It moves the keys whose `sway` is negative (pine, leaf, trunk), and only an instance with a place of its own; the shadow moves with it. |
| `detail.pine_teeth` | teeth round the skirt of a pine tier (a cone of a key with negative `sway`), cut in the fragment, so the tree's shadow and its drawn outline are toothed too; a tooth narrower than three pixels is not cut. No geometry changes. |
| `toon.cel_rock_shade` [r, g, b] | what the shade is multiplied by on rock (class rock and rock fields of the land; cast blocks and masonry take half): a blue shade light on pink rock is violet, the board's bluffs are mauve. |
| `toon.cel_cloud` 0..1, `cel_cloud_m`, `cel_cloud_speed`, `cel_cloud_cover` | drifting cloud shadows: round flat shapes in the world's plane, one in some cells of `cel_cloud_m` metres (`cel_cloud_cover` = the share of cells that carry one; a shape is 0.4 to 0.65 of a cell across and longer along the wind), moving at `cel_cloud_speed` m/s; they fall on everything alike and are cut like any cast shadow, one pixel soft. 0 = none. |
| `detail.sign_out` (m) | a plot's gate marker (flag and sign) stands this far before the plot's own fence instead of in its line (village_parts.gd `edge_geometry`, `marker_out`); since 21 Nov the marker is solid for the visitor where it stands (one box, `marker_solid`), the fence and its wall stay. Absent = in the fence's line, as ever. |
| `detail.road_rails` (m) | a row of rails along both sides of the main road, this far from its edge (`kernel/world/terrain/road_rails.gd`, one function called from landscape.gd); since 21 Nov a wall in the visitor's space over every drawn stretch (no pack sees it); gaps on the spur's side at every spur mouth, at the bridge, at plots and lots, 9 m round every plot's gate, and one open span in nine. Absent = today's landscape. The picture cache key carries the key (pic_salt.gd). |
| `detail.tree_shade` | the grass under every scattered tree and bush is a field of the dark grass paint with a cut, wobbly edge: `kernel/world/terrain/tree_shade.gd` stamps where they stand into a one-byte map (1.5 m a texel) on the terrain's own material, the value is the blob's radius as a share of the crown's. No node, no geometry. Absent = no map. |
| `detail.strata*` | rock fields and cliffs carry flat strata in world height in two alternating tones, each edge one pixel soft; mesas the same at any distance. `strata_tone` is the contrast. `strata_cream` 0..1: about one stratum in four is a cream bed, painted in `light()`: cream where the sun is on it, the same rock one tone lighter in the shade. |
| `water.model` = `"cel"` | water_cel.gdshader: two flat blues (channel, shallows), light streaks that lie along the flow and drift with it (`streak`, `flow`), a few large flat shapes of sky (`sky`, `sky_k`), a foam line (`foam`), and the sun's road (`glade`): cream dashes where the eye looks towards the sun. The shapes of sky stand in the water only for a grazing eye (none from above). The streaks are drawn in metres across the ribbon taken back from `TLKitRoad.river_ribbon`'s own rule (two triangles a segment, a swelling width; uniform `seg_m` 4 = the landscape's river), because a line of constant UV.y on that ribbon is a zigzag. |
| `water.shore` (m) > 0, `water.priority` | the water reads the depth of its bed: the waterline is where the land really meets it, and round every pier. It is then drawn after the solid world; `priority` -110 puts it before the ink pass (-100), so drawn contours lie over the water. |

Level land takes the ambient of level ground, no bounce and no rim: a smooth function of a rolling normal is a
gradient across the meadow, and cel land is flat fields. Cliffs keep their own.

Does it crawl? Measured as the diorama model was (`look.sh boil`: mean change per frame in grey levels / share of
pixels that change by more than 24 in one frame; 1920x1080, x264 crf 4; lane script
`docs/shifts/2026-11-20-day/lanes/cel-fable/crawl.sh`), both styles with the base's ink and grade:

| clip, band | classic | crisp cel |
|---|---|---|
| review scene, slow pan, horizon (thin members) | 3.065 / 2.625 % | 2.797 / 2.320 % |
| review scene, slow pan, kit floor | 0.441 / 0.037 % | 0.469 / 0.038 % |
| village road, slow pan, far land and yard | 0.485 / 0.523 % | 0.452 / 0.492 % |
| village road, slow pan, near land | 0.040 / 0.000 % | 0.022 / 0.001 % |

Why it holds: a field's edge, a band's edge and a mark's edge are each one pixel soft by the screen's own
derivatives; the wobble of a paint edge and every mark are anchored in the world and faded before they are finer than
a pixel; a cast shadow is cut, not blurred, so its edge is as steady as the shadow map under it. The first run after
a change of the shader text compiles for about a second (seen as one long frame); after that it is cached.

The picture cache (kernel/world/draw) stores vertex colours, and a kit terrain bakes palette paints into them: its key
carries those paints when they are not the paints of style.json (`kernel/world/draw/pic_salt.gd`), so a style with
other land paints has its own pictures and today's key is unchanged.

## Felt and clay for a figure (`TLStyleFelt`, hockey port lane K7, 23-24 Nov 2026)

A new entry beside the palette material, in files of its own: `tl_style_felt.gd`, `shaders/body_felt.gdshader`, the
look's three textures in `felt/` (thirdjam's `T_Felt_Fibre`, `T_Clay_Thumb_N`, `T_Clay_Dent_N`). No existing shader or
style file is touched (selftest `look.skater.shaders_kept`). It is thirdjam's two skater masters on its clay look tier,
node by node: `M_SkaterTB1Jersey` (felt: mottle, fibre bump, hem band, sheen, the jersey number from a 5 x 2 atlas and the
team crest) and the clay branch of `M_Toon` (thumb dents, rim, fill); the shader's header names each node it ports.

```gdscript
TLStyleFelt.set_rig(lights, exposure, gain, gain_shadows)    # optional: the hall's spot lights (TLStyleArena.set_rig's shape)
var m: ShaderMaterial = TLStyleFelt.material({"team_colour": Color(0.02, 0.1, 0.55), "felt_mix": 1.0, "vcol_mix": 1.0,
	"number_on": 2.0, "number_tens": 4.0, "number_ones": 2.0, "number_atlas": atlas})   # keys: TLStyleFelt.KEYS
TLStyleFelt.set_params(m, {"number_ones": 7.0})              # a number or a colour that changes later
```
- Keys are thirdjam's material parameters in snake case; colours are linear; unknown keys are errors (null). Headless:
  one shared material with no shader.
- **The mesh must carry** `CUSTOM0.xyz` = the vertex before skinning (m), `CUSTOM2.xyz` = its normal before skinning,
  `CUSTOM1` = thirdjam's vertex colour (r felt mask, g a number per panel, b an edge mask), `UV` = thirdjam's UV0.
  `TLRigSkaterLook.look_mesh` makes that copy of the baked skater.
- **Light.** With a rig (`set_rig`): each spot light by its candela, cone and radius, a surface shows (base x lux / PI +
  what it emits) x exposure through Unreal's film curve, as lane K6's hall shaders do (the same uniforms and the same
  arithmetic as `hall_rig.gdshaderinc`; to be one include once both are on one branch). Without one: the installed
  style's sun and its two ambients. The picture is written as emission; the figure takes no shadow, and casts its own.
- **No ink.** The colour is drawn after the style's ink pass (render priority -90 against the pass's -100) and covers
  the contour the pass drew inside the figure; the depth pre-pass keeps the figure in the depth buffer and in the shadow
  maps. thirdjam's clay tier draws no outline.
- Cost: ten skaters before the game camera at 1280 x 720 draw in the same time in felt and in flat cel (whole frame
  1.0 to 1.1 ms either way on this machine, 0.8 ms with the ten hidden; `look_gym.tscn --mode=cost`).


## A hall: `TLStyleHall`, `TLStyleArena` (hockey port, 23-24 Nov 2026)

Two entries a game played indoors asks for; neither changes a shader or a style file that existed.

- `TLStyleHall.apply(anchor, {color, energy, shadows})` (lane K3): the installed style's sun becomes a light from the
  roof (straight down), the fog is switched off. `TLStyleHall.clear(anchor)` gives the style back.
- `TLStyleArena` (lane K6): the surfaces of a hall ported from another engine, lit by that hall's own rig by the
  numbers. `set_rig(lights, exposure, gain, gain_shadows)` takes up to 24 spot lights (position, direction, colour,
  candela, radius, cone); every hall material sums them per fragment (`shaders/hall_rig.gdshaderinc`, no shadow, no
  engine light node) and shows the result through Unreal's film curve (`hall_tone`). The picture is written as
  emission, so the style's sun adds nothing to it; the ink and grade passes run over it.
  - `surface({...})` (`hall_surface.gdshader`): wood (world triplanar grain, a warm wash rising from the floor, a
    spill outside the boards) and painted clay pieces (bands by height, board panels with joints, a felt band, wear,
    a dented or thumbed normal, a felt sheen).
  - `ice({...})` (`hall_ice.gdshader`): an ice sheet with painted lines under the surface, scratches, snow at the
    boards, the lamps' sheen. It takes the style sun's shadow for the share of the lights that cast shadows.
  - `crowd({...})` (`hall_crowd.gdshader`): vertex-coloured figures with per-instance values and a cheering pose
    (`set_cheer(plus, minus, seconds)`); `bulb({...})` (`hall_bulb.gdshader`): a lamp's bulb.
  - `post(anchor, opt)`: the installed grade and ink passes as a hall wears them, read from the hall look's own
    file `style/hall_post.json` (`grade`: no plum wash, no split toning, thirdjam's saturation, contrast and vignette;
    `ink`: the contour gone by a given distance); `opt` sets values on top of the file ({} = as it is). `TLStyleHall.clear` restores
    the style's own. `post_file()` returns the file's two sections.
  - `tone(colour, gain, gain_shadows)`: the same film curve in GDScript, for the light handed to the toon materials.
  - `set_glow(material, emit)`: a `surface` material's own light changed in place (lane K6 round 3: thirdjam's goal
    lamps flashing; any other material is left alone).
  Colours are linear numbers of the source material. Headless: one shared material with no shader.

## A hall's key lights' shadows (`TLStyleHallKeys`) and Unreal's whole film pipeline (hockey port lane K7, round 3)

- `tl_style_hall_keys.gd`: the lights of a rig that cast shadows (thirdjam: four spots 13 m over the rink's long axis)
  as real spot lights with shadow maps. They light nothing (black); `shaders/hall_ice.gdshader` reads each one's
  shadow in its `light()` (the lines marked K7) and takes away that key's own share of the rig's light there, so a
  figure throws one shadow a key, away from that key's foot: short under a key, long between two and near the boards.
  `TLStyleHallKeys.install(anchor, lights, opt)`, `receive(mesh_instance)`, `count(anchor)`, `clear(anchor)`.
  It sets the anchor viewport's positional shadow atlas (8192 px, every quadrant one map: 4096 px a key) and the
  renderer's soft shadow filter for spot lights, and gives both back on `clear`. Since round 4 the rim is the light's
  source radius through the engine's soft shadows (hard at the caster's foot, wider with its height), and a key's map
  covers 56 degrees, not the light's 62 (finer texels; beyond the map that key's light is not shadowed). Cost with
  ten striding skaters at 1280 x 720: GPU 0.80 ms a frame against 0.58 without, render CPU 0.43 to 0.47 against 0.35
  to 0.37 (RTX 4090).
  What was learnt on the way: a cull mask of one layer on such a light stops the engine re-drawing its shadow map for
  a figure on another layer; the engine's own quadrant cut (1 / 4 / 16 / 64) changes a light's map size with the
  camera; `spot_angle_attenuation` is the exponent of (1 - rim), so near 0 = no fall-off inside the cone.
- `shaders/hall_film.gdshaderinc`: `hall_film(x)`, Unreal 5.9's film pipeline whole (to ACEScg, gamut expansion, the post
  volume's gains, blue correction, the glow and red modifier, the curve, back to sRGB), beside `hall_tone` (the curve
  alone on sRGB primaries). `body_felt.gdshader` uses it (`film_whole` 1); the hall's own shaders still use `hall_tone`.
  A neutral grey is the same through both; a saturated blue comes out with red as high as green, as in the game.
- The contact shade (`TLStyleFelt.contact_material`) has two forms on the skater (standing, lying): RIGS.md.

## Time of day (`day`, lane DN, 27 Nov 2026)

A style may carry a `day` section: how `dawn`, `dusk` and `night` differ from the style's own values, which are noon
(`day/style_day.gd`; only `style_crisp.json` has one). Each phase names a few keys of `sun` (color, energy, elev, azim),
`toon` (shade, shade_k, shade_ground, amb_sky, amb_ground, amb_energy, bounce, bounce_k, rim2, rim2_k), `fog` (color,
density, height_density), `sky` (the painted sky's colours, glow, disc, clouds, sun_draw_elev), `water` (deep, shallow,
sky, stripe, foam), `grade` (shadows, highlights, sat, split, contrast, lift, plum_density, olive_fill), `env`
(exposure), and `lamps` (how strongly the kit's lamps burn; noon is 0). Unknown keys are errors; an absent key is noon's.

Not pack API (TLStyle's public surface is unchanged); the kernel's Home preloads `res://style/day/style_day.gd`:

```gdscript
Day.has_day()                        # the loaded style has a day section
Day.day_look(t)                      # the look at clock t (0..1 of a day: 0 midnight, 0.25 dawn, 0.5 noon, 0.75 dusk)
Day.apply_day(anchor, look)          # onto the installed rig and the globals; headless or no rig: nothing (0)
```

- At t = 0.5 the look is the style's own values key for key, and the globals it writes are byte for byte those install
  wrote (selftest `home.daynight.noon`; in a window `day_case.gd --mode=window`). The colours hold the night's from 0.80
  to 0.20 and noon's from 0.375 to 0.625; the sun keeps moving all day (dawn's azimuth and elevation, noon's, dusk's).
- At the two blue hours (0.225, 0.775) the lit band takes the shade's colour (flat light) and the light turns from the
  sun to the moon (highest at midnight) or back, so the swap is never seen. The light never goes below 4 degrees.
- Values only: no shader and no new global. `TLStyle.install(host)` (or `load_style` of the same file) gives the
  style's own look back. The Home's clock (`kernel/world/home/day_cycle.gd`) is its only caller.

