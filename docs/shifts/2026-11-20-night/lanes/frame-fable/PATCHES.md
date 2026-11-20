# frame-fable: what the other pillars should do (nothing here is applied in this worktree)

The frame pillar owns sky, light, post and lens. What it wants most for the diorama lives in a section it does not
own (`toon`). Each is a value in `engine/style/style_diorama.json`; none is a code change. `PATCHES.toon.json` beside this file
holds the same values as data, and the contact sheet's row "with PATCHES" was taken with them applied to a scratch copy
of the style file (`TL_STYLE=<name>`), never to `style_diorama.json`.

## surfaces (section `toon`)

1. **`toon.band_soft` 0.03 -> 0.2 (or a smooth ramp in the diorama branch of toon.gdshader).**
   The sun now has a size (`sun.angular` 0.5 degrees): a shadow is tight at the post that casts it and softens with
   distance. The toon shader then cuts that soft edge back into two hard steps (`band_hi`, `band_lo`, each 0.03 wide),
   so in this worktree a far shadow shows as a dark core with one lighter fringe, not as a gradient. With `band_soft`
   0.2 the penumbra reads as the soft shadow of board 4. This is the one patch the frame needs most.
2. **`toon.hatch` 0.2 -> 0.0.** The diagonal hatch in every shade is a drawing mark. With the contour gone (this pillar
   replaced the ink pass by contact shade) the hatch is the last thing that says "drawn" in a frame.
3. **`toon.shade` `#5a60c0` -> a warm plum (for example `#6a4470`), `toon.shade_ground` likewise, `toon.rim2_k` 0.6 -> 0.2.**
   The grade already pulls the dark end warm (`grade.shadow_tint`), but a blue-violet shade under an orange sky still
   reads as cel paint. Board 4's shadows are warm brown-plum. With a warm shade in the material the grade's `tint` can
   come down from 0.09 to about 0.05.
   Items 1 to 3 together are `PATCHES.toon.json`: five values.
4. **Grass under the orange sun is too light.** The sun is now the board's orange (`sun.color` `#ffb878`): the road
   measures `#d38632` in the exe's first frame against `#e9873c` on the board. The same sun turns the light grass
   pigment mustard yellow, so the grade takes red back out of the greens (`grade.green_keep` 0.34). Measured (medians
   of grass-only boxes): my lit grass is `#93a827` to `#a49c24`; the board's is darker and browner, `#9f7720` to
   `#b27d24` near the camera and `#645a21` on the left meadow. What is missing is a deeper, darker grass pigment
   (`palette.grass` / the terrain's pigments: surfaces' call; palette keys keep their names and order). With it
   `green_keep` can come down and the grass can take the sun's warmth as the board's does. If surfaces move the
   grass, look at one grass-heavy frame (seed_drive, chase camera) before and after.
5. **A saturated blue shade on grey ground stays blue.** The car's shadow on the tarmac of seed_drive is the clearest
   case (stills/diorama_games_drive.jpg). The grade cannot warm it without also turning blue paint purple; item 3
   (a warm `toon.shade`) fixes it at the source, as the "with PATCHES" stills show.

## surfaces (shader contract the frame relies on)

6. **Keep writing roughness and normals in the prepass** (toon.gdshader writes ROUGHNESS and the normal buffer today).
   `ink_post_diorama.gdshader` reads the normal buffer for the contact shade and the crease seam. A new material shader
   that does not write a normal (an unshaded variant, a custom depth prepass) gets no contact shade under it.
7. **A normal map on clay would be picked up for free**: the contact shade and the seams read the same normal buffer,
   so fingerprints written into NORMAL also show in the creases. No change needed on the frame side.

## character

8. **`engine/rigs/review/review.gd`: name the review camera's subject.** The lens focuses on the subject a camera
   follows: its `target` property, or the meta `tl_lens_subject` (a Node3D). The review scene's camera is a plain
   Camera3D with neither, so it is treated as a presentation camera (a level view gets only a far-backdrop blur, a
   view from above the band). One line in review.gd, `cam.set_meta(&"tl_lens_subject", rig)`, gives a close-up the same
   tilt-shift as in play. The frame side is in place and has a case (style.frame_lens, camera 7).

## Director (not a pillar's file)

9. **`engine/style/STYLE.md`** is not in any pillar's list. The frame keys are documented in the header of
   `engine/style/frame/tl_style_frame.gd`; a paragraph in STYLE.md that points there would help the next reader.
10. **`engine/kernel/world/draw/view.gd` (the world's crane).** The lens treats it as a presentation camera by rule
   (no `target`, not under a TLCameras node): the band when it looks down, a far-backdrop blur when it looks level.
   `overview.set_meta(&"tl_lens", 0.0)` switches both off. To give a tour shot the near blur of board 4 it would have
   to focus on the shot's `to` point: a Node3D placed there and named with `tl_lens_subject` does that today, but the
   reach rule then switches the lens off beyond 26 m, so a shot from farther away also needs its own reach (a few
   lines in view.gd and one more meta in the frame script).
11. **`engine/kernel/API.md`, cameras.** No kernel API member was added, so nothing there is stale. A pack author
    would still want two sentences: under a style with a lens a chase or orbit camera keeps its target in focus and a
    fixed view is never blurred; `cam.set_meta(&"tl_lens", 0.0)` switches the blur off for one camera, and
    `cam.set_meta(&"tl_lens_subject", node)` names a subject for a camera that has no `target`.
12. **The whole look is one style file.** If the owner picks the diorama, nothing has to be "replaced": classic stays
    `TL_STYLE=classic`, and each layer can be switched back on its own by deleting one key (`sky.shader`,
    `ink.shader`, `grade.shader`, `env.lens`, `sun.angular`).
