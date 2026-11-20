# PATCHES: what the surfaces pillar (Fable arm) needs from the other pillars and from the Director

The frame and character entries name files of other pillars that this arm did not touch; each says what to change
and why. The Director entries are about landing this arm.

## frame

1. **Take the ink off, or down to a hairline, in `style_diorama.json` `ink`.** Board 4 has no drawn contour. The
   surfaces now carry their own form: box edges are soft, the felt sheet has a cut edge the sun catches, slabs have
   pressed joints. A 4 px black contour on top reads as a drawing of clay, not as clay. The values used for every
   picture marked "preview" in this lane:
   `outer_px 0, inner_px 0, inner_alpha 0, near_px 0, hair_alpha 0, thin_tone 0`.
   Keep `ao_k` (the contact shade): it is the only contact darkening the picture has, and board 4 asks for more of it,
   not less. A softer, wider contact shade under posts and feet would serve the surfaces better than the present
   blue-violet patches (`ao_color` towards a warm dark, a larger `ao_radius`).
2. **Take the paper off in `grade`** (`paper 0`, `grain` about 0.006). Paper fibre over felt and clay is a second,
   screen-fixed texture: it swims against the object-anchored marks when the camera moves.
3. **Keep the sun low.** The marks are relief, not ink: they read through the light. At `sun.elev` 21 flat ground gets
   36 % of the sun's cosine, which is where a thumb dent shows best. Above about 40 degrees the land goes flat again.
4. **Depth of field and the river.** With `water.shore` > 0 the resin is drawn after the solid world (it reads the
   depth of its bed), so a pass that reads depth sees the bed, not the surface. The two are a metre or two apart,
   so a blur by depth is nearly the same for both. If the ink stays on, set `water.shore` to 0: an outline that falls on
   the water would otherwise be covered by it.
5. **Nothing a post pass reads has moved.** The prepass NORMAL is the geometry's own (the marks tilt only the normal
   the light sees, handed from fragment() to light()). ROUGHNESS keeps its tags: 0.5 a body, 0.9 land, 1.0 the rest.
6. `toon` is the surfaces pillar's section and it changed: `hatch 0`, softer `shade`, `band_hi`/`band_lo` are now the
   two ends of one smooth ramp (0.78 / 0.06). If the frame arm moved `toon` keys too, take the surfaces values for
   `model, hatch, band_hi, band_lo, mottle, gloss, sheen, sky_refl, spec, chip_color, wax` and the frame's for the
   rest (`shade`, `shade_k`, `shade_ground`, `amb_sky`, `rim_k`, `rim2_k` were only softened here: 6 values a light
   pass may own).
7. The river from the air: far off at a grazing angle the resin is half a mirror of the horizon colour (`water.sky`,
   peach tonight) and turns grey-lilac. A sky pass that changes the horizon should set `water.sky` and
   `water.sky_top` to its own two colours.

## character

1. The figure already gets the model: it is drawn with the palette material, so jacket, trousers, hair and boots are
   painted clay with thumb dents, the quilting of `fabric` is stitched instead of inked, and box-built parts have
   soft edges. Nothing to do for that.
2. Per-key controls are in the lookup texture, row 3: `gloss`, `fuzz`, `chip` under `mat.<key>` of
   `style_diorama.json`. Suggested for the figure (not set by this arm, the figure is the character pillar's):
   `jacket: chip 0.4`, `boots: chip 0.5, gloss 0.3`, `hair: gloss 0.25`, `jacket_trim: class felt, fuzz 0.5`.
3. If the figure gets a shader of its own (`body*.gdshader`), the globals `g_dio` .. `g_dio5` and the functions
   `dio_surface`, `dio_flock`, `gn2`, `keep` of toon.gdshader are the pieces to share, so the figure and the world keep one clay.

## Director

1. **`PIC_VERSION` is 1601 in this arm on purpose.** The picture cache is shared by every checkout of this machine
   (`<user data>/tl_cache/pictures`, key = pack content + plot + `PIC_VERSION`, not the engine's code). Two arms
   that both count 15 up to 16 with different meshes would serve each other's pictures. On landing pick one number
   no arm used tonight. Before 00:05 this arm wrote 22 pictures under 16 into the shared cache and removed them
   again (listed in REPORT.txt).
2. **`engine/style/style_surfaces.json` is a judging aid, not a style to keep.** It is `style_diorama.json` with
   entries 1 and 2 of "frame" above applied, so the exe of this arm can be looked at as the surfaces are meant to
   be seen: `TL_STYLE=surfaces` (dist/arms/surfaces-fable/PLAY-SURFACES-PREVIEW.cmd). Delete it when the frame
   arm's ink and grade are merged. It is a copy: a change to `style_diorama.json` does not reach it.
3. **Merging `style_diorama.json`.** This arm changed only `toon`, `water`, `palette`, `mat`, `detail` (and nothing
   in the others, checked by script against diorama-base). `palette` keeps its 100 keys in their order.
4. **The tour of COMMON.md is not repeatable on a loaded machine**: without `--load=block` the packs arrive when
   they can, and two runs of one tree showed different mesas and bushes. The stills of this lane use `--load=block`.
5. `docs/generated` was not regenerated (no API member was added: `tl arch` api-v1 PASS, 43 classes, 658 members).
