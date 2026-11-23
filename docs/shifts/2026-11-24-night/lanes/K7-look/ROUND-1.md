# K7 look, round 1: thirdjam's skater material on our figure (23 Nov 2026)

## What stands

- **A port, not a look-alike.** thirdjam's two skater masters on its clay tier are written node by node into ONE new
  shader, `engine/style/shaders/body_felt.gdshader`: `M_SkaterTB1Jersey` (jersey, trim, pads: vertex-colour base, felt
  mottle, darkening, hem band, clay and fibre normals, rim, fill, felt sheen, the number and the crest) and the clay
  branch of `M_Toon` (skin, helmet, gloves, skates, blade, stick). Each block names the custom node it ports. The look
  collection is the running game's (Clay 1, ClayBump 2.0, FeltRim 1.4, ClayFill 0.15, ClayTile 25, LookTint 1 / 0.94 /
  0.84: lane K6's export). No existing shader or style file is touched.
- **The entry:** `TLStyleFelt` (`engine/style/tl_style_felt.gd`): `material(params)`, `set_params`, `set_rig`. The three
  textures of the look in `engine/style/felt/`.
- **The figure's look:** `TLRigSkaterLook` (`engine/rigs/skater/look/`): `felt` (the default) and `cel` (lane K2's flat
  cel as it was). Per slot it carries thirdjam's own material instance values; a selftest holds the 75 it carries to the
  Unreal editor's report of the instances. Number atlas and the two crests beside it.
- **Number and crest**: [SetNumber] and [SetTeam] of thirdjam's driver now reach the material: tens and ones on the back
  patch (dark ink, lane SK20's form), the team's crest on the chest. The ten skaters of a match read 7 13 42 4 5 and
  9 21 88 14 15.
- **Face, trim, skin, tear:** all four were products of flat cel and the ink pass. The felt look draws no ink (thirdjam's
  clay tier has no outline): the mouth is the mesh's own thin line, the trim is cream in light and in shade, there is no
  toon highlight to read as a tear.
- **Light:** the figure is lit by thirdjam's own rig by the numbers (18 spot lights, exposure, Unreal's film curve),
  the same arithmetic as lane K6's hall shaders, so figure and hall stand in one light. With no rig given it falls back
  to the installed style's sun.
- **Proof tooling:** `look/look_gym.tscn` (ours) and `tools/look_reference.py` (thirdjam's own figure in Unreal, dressed
  as the game dresses it, same seven cameras: four close, three in the game's frame), `tools/look_pairs.py`.
  Two Unreal runs: the first died before its first shot (the GPU device was lost while my own Godot window was
  rendering beside it); the second gave 16 of 16 shots fresh (the pose guard of lane K2) and the editor closed itself.

## What I looked at, and what my eye rejects

Looked at: `media/r1_pair_blue_close.jpg`, `r1_pair_orange_close.jpg` (four angles), `r1_pair_blue_zoom.jpg`,
`r1_pair_orange_zoom.jpg` (front, back, three-quarter at twice the size), `r1_pair_game_distance.jpg`,
`r1_pair_far_end.jpg`, `r1_running_game_vs_ours.jpg`, `r1_same_camera_same_place_game_over_ours.jpg`,
`r1_ten_skaters_felt.jpg`, `r1_ten_game_camera_felt_over_cel.jpg`, `r1_both_looks_for_the_owner.jpg`.

It reads as thirdjam's figure now. What still differs:

1. **Top surfaces are darker than the running game's.** Same camera, same place on the rink as the game's still
   (frame 5360, the 7 at rink 12.09 / -21.49): jersey back game #121242, ours #10163f; pants #0b0505 / #0b090a;
   shoulder #16174a / #181f50; but the helmet #181746 / #111639 (ours about a fifth darker) and the patch #c5a373 /
   #a6875d (a sixth darker). The game's figure has a softer, lighter top. My reading: light that is not the 18 spots
   (the sky light's capture of the lit hall, bounce off the ice). Not ported; `sky_fill` is in the shader at zero.
2. **Orange, measured at the rink's centre, is darker and redder than the game's orange skaters** (ours #8f2f15 to
   #a84625, the game's 88 and 21 #a94921 to #c35527). They stood elsewhere on the ice and where is not known, so this
   is not a like-for-like figure; the blue one, which is, agrees. Open.
3. **The close render of thirdjam is not the game's colour.** Its scene capture is far more saturated than the game
   (jersey #040b61 against the game's #131444). The close pairs judge structure; colour is judged against the game.
4. **Rim and self-shadow.** thirdjam's close render has a broader, paler fuzz along the silhouette and darker hollows
   under the arm and the chin (its four key lights cast shadows). Ours is flatter: no light of the rig is shadowed.
5. **The number is blacker and sharper than the game's** at the game camera. The game draws at 72.8 % and its
   upscaler softens a moving figure (thirdjam's lane SK20); ours is drawn at full size. Not a defect, but a 21 or an 88
   reads heavier.
6. **The cel variant is as it was**: blank patch, no crest, and under the hall light its skin goes grey. It is the
   "before", selectable, not a second finished look.
7. Under the fallback (an outdoor style's sun) the nose blows out to pale pink.
8. The gym is not the hall: an outdoor sky behind the figure and the style's hard blue shadow on the kit's ice.

No defect of shape, of the number or of the crest in any pair I looked at.

**Not looked at:** motion. There is no film this round. thirdjam samples its clay and fibre grain by the skinned
position, so the grain slides over a limb as it bends, and ours does the same; whether that reads as it does in the
game is unjudged. Also unjudged: the figure inside lane K6's hall (not on this branch), the exported game, a figure in
a world plot (`tl_plot`).

## Deviations

1. No light of the rig is shadowed on the figure (thirdjam: four key spots with shadows, source radius 60 cm).
2. No sky light and no bounce (thirdjam: sky light 0.35, a real-time capture). The dome alone would add about 4 % of
   the direct light at the centre; what the capture sees of the lit hall is not known.
3. The film curve is lane K6's port (per channel in sRGB; Unreal's working space, red modifier, glow and blue
   correction are not ported), with K6's tone gain 6.0 and the post volume's colour gains. I tried Unreal's working
   space (AP1) on top: it moved the orange away from the game's and the blue not at all, so it is not in.
4. Bloom, the upscaler at 72.8 %, screen-space reflections: not ported. Specular 0.25 is not drawn (the rig's lights
   have no specular).
5. Only the clay tier: the night and broadcast gates, M_Toon's Construct, Board and Wear parts are not ported (every
   skater instance has them off). JerseyDeco's planar box is not ported (every shipped instance uses UV0).
6. The pose before skinning is carried in a copy of the mesh made at run time (CUSTOM0, CUSTOM2); lane K2's baked mesh
   is untouched.
7. The colour is drawn after the style's ink pass with a depth pre-pass, so that no ink line lies on the figure.
8. Kernel API 1.19 -> 1.20 (two new classes); the generated index and contract regenerated.
9. The clay normal maps are in the tree twice (`engine/style/felt/` here, `engine/cores/rink/arena/tex/` in lane K6's):
   style may not reach into a core.

## Next (round 2)

1. In lane K6's hall, through one shared include: pairs at K6's camera spots with the figure where the game's stood;
   settle the indirect light from those stills.
2. Film: a skating figure in felt beside thirdjam's, ten at the game camera; the grain on moving limbs, shimmer far away.
3. The cel variant: the number and the crest on it, or drop it.
