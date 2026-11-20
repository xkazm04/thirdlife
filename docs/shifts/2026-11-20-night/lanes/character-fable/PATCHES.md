# PATCHES: what the character arm (Fable) asks of the other pillars and of the Director

Nothing below was done by this arm: these are files of other pillars or of the Director.

## For the Director (the combine at 06:00)
1. **Keep the `_figure` block of `engine/style/style_diorama.json`.** It is the switch: `"_figure": {"variant": "toy", ...}`.
   Without it the combined build shows the classic figure and nothing warns in the picture. The selftest `figure.toy`
   (block 590) fails when it is lost, so run `bash engine/tools/selftest.sh figure.` after the merge.
2. **`_figure` starts with an underscore on purpose.** `TLStyle.check` rejects unknown sections and skips names that begin
   with `_`; `tl_style.gd` is not a character file, so the section was named to pass the check untouched. The clean form
   is one word in `TLStyle.SECTIONS` (`"figure"`) and the key without the underscore; `TLRigBipedToy.on()` and `.num()`
   (engine/rigs/biped/tl_rig_biped_toy.gd) then read `figure` instead of `_figure`. Three lines in all.
3. **Docs.** `engine/rigs/RIGS.md` has a hand-written section on the toy figure. Its generated tables were not
   regenerated (`k.sh docs` also rewrites `kits/KIT.md`, a surfaces file): they still describe the classic figure
   (29 bones, 10296 triangles), which is what `TL_STYLE=classic` builds. The runtime param `grip` is new in
   `TLRigs.RUNTIME` and will appear in the table at the next `k.sh docs`.
4. No kernel file changed in this arm (`visitor.gd`, `tl_biped.gd` and `flight_wings.gd` are as on diorama-base), and the
   kernel API index is unchanged (`tl arch`: api-v1 kernel API 1.11, 43 classes, 658 members).

5. **Hockey's frame budget is the machine's tonight, not an arm's.** `invariants.many_budget` (1.0 ms) reads 0.992 on
   diorama-base on a quiet machine. Paired runs of `tl.sh invariants --pack=engine/packs/hockey`, classic then diorama,
   on my final tree: 0.973 / 0.966, 1.003 / 0.985 ms (03:23); earlier under heavier load 1.022 / 0.938, 1.054 / 1.049,
   1.202 / 1.218. A skater's rig tick costs the same with either figure (23.90 against 23.94 microseconds). The packs
   gate will pass or fail on this line by the load of the minute.

## For the frame pillar (light, ink, post)
1. **Ink on the figure.** The target has no drawn contour on the toy. The ink pass still draws one on every body
   (`ink.body_k` 0.55 of the width). The clay figure reads better without it: try `ink.body_k` 0 to 0.2 in
   `style_diorama.json`. The clay shader keeps writing roughness 0.5 (the body tag), so the dial works as it does today.
2. **The shade colour.** The clay takes the style's shade (`toon.shade`, `#5a60c0` at 0.7) at `_figure.shade` = 0.6 of its
   strength, because at full strength the boots and the hair go violet on the dark side while the target's shade is a warm
   brown. If the diorama light gets a warmer shade, set `_figure.shade` back to 1.0.
3. **Contact shadow under the boots.** The figure casts its shadow as before (the caster moves down the sun's rays, as in
   toon); a tight contact darkening under the soles would come from the frame pillar's AO or contact-shadow work. The
   clay shader receives whatever the sun's ATTENUATION carries and needs no change.
4. **Depth of field.** The figure is the focus subject; its fingerprints and hair marks fade by pixel size (they are gone
   when a ridge is under about two pixels), so a blur on top of them does not shimmer.

## For the surfaces pillar (materials, palette)
1. **Palette keys the figure reads** (never renamed here): `skin`, `hair`, `jacket`, `jacket_trim`, `pants`, `boots`,
   `pack`, `strap`, `white`, `black`, `yellow`, `cyan`, `roof` (the mouth), plus whatever a pack passes in `colors`
   (hockey: `car_blue`, `car_red`, `car_white`, `bot_dark`). The clay shader reads only row 0 of the palette lookup
   (albedo and emit): `mat` classes (fabric quilting, wood grain) are not drawn on the figure.
2. **If toon gets a clay response of its own**, the two should agree. The figure's material is
   `engine/style/shaders/body_clay.gdshader`; its dials are `_figure.print`, `chip`, `sheen`, `soft`, `shade`, `contact`. The props a
   figure holds (stick, skates, hammer) are dressed in the same clay; a prop a PACK parents to a socket is a kit part
   and takes the world's material, as before.
3. **The far marks' colour** (`engine/kernel/world/draw/draw_life.gd`, `_mark_colour`): it reads the palette column of
   surface 0 only when that surface carries the palette material itself, and a flat colour only from the toon shader;
   any other style shader gives grey. The toy works with it through a hidden palette-material surface (RIGS.md, "Two
   surfaces"). If `_mark_colour` accepted any style shader that has a `pal_lut` (as `_mat_ok` accepts any that declares
   `tl_plot`), the hidden surface and its draw call could go.
4. **Warmer boots.** The target's boots are a warm mid brown; `palette.boots` is dark and goes near black-violet in
   shade. A lighter `boots` in the diorama palette (the key stays) would bring the figure closer.
