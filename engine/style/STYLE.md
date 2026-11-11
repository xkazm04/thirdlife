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
