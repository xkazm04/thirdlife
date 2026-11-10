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
