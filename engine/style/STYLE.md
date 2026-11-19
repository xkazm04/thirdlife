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
