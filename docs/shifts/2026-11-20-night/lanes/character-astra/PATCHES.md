# Character Astra integration

The shared frame still draws a dark contour across the crown, cuffs and boot rolls. For the combined review, compare the road close-up with the frame arm's softer outline and warm side light. Keep the camera's focal plane on the runner through the parkour jump. The body shader already supplies the pigment, wear, fingerprint relief and response to light.

The picture cache can keep its current version for this arm. `_collect_standin` in `engine/kernel/world/draw/draw_pictures.gd` drops meshes with a skin or moving parent. The changed generator builds only the skinned biped.

For the character sheet, `RIG_ARGS=--backpack=0` selects the village walker's bare back in the review scene. The ordinary walking review still shows the optional satchel. Compare the front, rear, moving three-quarter view and the two hockey colours.
