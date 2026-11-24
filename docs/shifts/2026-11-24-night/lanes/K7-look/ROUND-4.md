# K7 look, round 4: tighter shadows, shadows in motion, the puck's halo; two things measured and not built (24 Nov 2026)

## 1. The lying man's shade, and every shadow's rim

thirdjam's dark edge along a lying man is the key lights' own shadow of a low body: hard, because the caster touches
the ice. Round 3's rim was one filtered width, which washed a 20 cm shadow out. Now:
- **The rim is the light's source radius** (thirdjam: 60 cm) through the engine's soft shadows: hard at the caster's
  foot, wider with its height. Round 3 found these stepped; the cause was the map's texel size.
- **A key's shadow map covers 56 degrees, not the light's 62**: past 55 degrees a key gives under a twentieth of its
  light at its foot, and the narrower map has texels of 0.94 cm instead of 1.6. Outside the map that key's light is
  simply not shadowed (`hall_ice.gdshader`, the lines marked K7 round 4). Open ice is unchanged to the grey level
  (six points a picture, three pictures, the far corners among them: difference 0).
- `media/r4_shadows_game_round3_round4.jpg` (the game | round 3 | round 4, twice the size): **lying**: a tight dark
  edge under the legs and the arm now, as thirdjam's; **striding**: the same shadow, harder at the skates, soft at the
  head; **standing**: ours is still darker and more of a shape than thirdjam's faint streak.
- What my eye rejects: at twice the size a fine stair still shows on the striding shadow's upper rim; at the game's
  own size I do not see it. The standing shadow at the faceoff is darker than thirdjam's.

## 2. Shadows in motion

`media/r4_film_shadows_in_motion.mp4` (4 s, six figures, one lying, the game camera's height and pitch; ours alone).
Looked at as stills: `media/r4_film_shadows_every_20_frames.jpg` (twelve frames across the take) and
`media/r4_film_12_frames_in_a_row.jpg` (twelve drawn frames in a row on one skater). In those the shadow stays at the
skates, turns and lengthens with the stride, and nothing pops or swims. Not compared frame by frame with thirdjam's
film; the mp4 itself I cannot watch.
`media/r4_match_stills_ours_halo_and_shadows.jpg`: two frames of the match itself (the hokej pack, its own camera).

## 3. The puck's halo: a tone question, settled

thirdjam's `MI_Trim_PuckHalo` is M_Trim with Emissive 18 and TeamColour (0.75, 1.0, 0.15). Through the hall's exposure
and the film curve that is #f7fbdd, near white (`tools/look_tone_check.py`'s functions; the curve alone and Unreal's
whole pipeline agree here, #f8fad9 and #f7fbdd). Ours was the palette's emissive lime drawn outside that curve:
yellow-green. Now the hall dresses the halo disc with thirdjam's numbers through its own emissive surface
(`rink_arena.gd` `light()`, K7 lines). The halo's brightest pixels: ours in the match now #ebedd0; thirdjam's in
lane K3's still (r10_puck_faceoff.jpg, its right half) #e7eac2; ours before, in the same still, #e9f567.
Not verified: ClayGlowMul and the base tint of that instance (it is not in the export; the master's are used).

## 4. The ice's reflection of the figures: measured, not built

`media/r4_thirdjam_ice_reflection_close.jpg`. Under a figure thirdjam's ice shows a faint, noisy smear. Measured
against the ice beside it (frame 1500, two wingers, one far skater): it changes the ice by **2 to 9 per cent** in
linear light, darker where the black pants mirror, a little redder under the far orange jersey. Round 3's "half of
what reads as shadow at the faceoff" was mine and wrong: the streak there is the two key shadows, which ours has.
Not built this round. It cannot be had from the engine's screen-space reflections (the felt figures are drawn after the
copy of the screen a reflection would read). A way that would work: the figure drawn a second time, mirrored and laid
flat on the ice along the eye's ray, a tenth as strong, fading with height. One more shader and a second mesh a figure
for a tenth of a difference: the Director's call.

## 5. The boards' bounce: not built, and why

The gap it was to close is at the 7 of frame 5360: back patch an eighth too dark, left shoulder a quarter too bright.
The patch looks up and back; the boards are 1.2 m high and beside him: they cannot light it. The shoulder that is too
bright is the one away from the boards. So the boards' bounce would move neither the right way.
What I think the comparison is worth: one box a surface, on two figures in different poses (ours a clip's key picked
by eye), read to a few grey levels. A quarter either way on a shoulder is inside that. To do better the two figures
must stand in one pose: lane K2's oracle can pose thirdjam's own figure; in the game's own window it needs a stopped
frame with the pose logged.

## Cost

Ten striding skaters in the hall, 1280 x 720, RTX 4090, 600 frames, twice each: GPU 0.80 ms a frame with the keys
against 0.58 without; render CPU 0.43 to 0.47 against 0.35 to 0.37. (Round 3: 0.74 against 0.58.)

## Deviations (this round)

1. A key's shadow map stops at 56 degrees; thirdjam's lights shadow to 62 (under a twentieth of the light there).
2. The source's size is given as diameter x 4 (the engine takes a light's size against its range, and the range is
   four times the light's own): 4 and 12 were looked at, 8 kept. Not derived from the engine's source.
3. The halo's ClayGlowMul and base tint are the master's, not read from the instance.
4. The reflection in the ice and any bounce off the boards: not ported.

## Files of other lanes touched (marked "K7", round 4)

- `engine/style/shaders/hall_ice.gdshader` (K6): one uniform (`key_cone_cos`); at the end of `fragment()` a block
  between "K7 begin (round 4)" and "K7 end"; in `light()` the chosen key's share is zero outside the map's cone.
- `engine/cores/rink/arena/rink_arena.gd` (K6): in `light()`, inside the K7 block, the halo's material (eight lines).
- `engine/cores/rink/arena/review/figure_view.gd` (mine): `--film`, `size_k` and `cone_deg` in `--keyopt`.
- Nothing of lanes K2's or K3's (the halo is dressed from the hall's side; the pack's files are as they were).

## Gates

selftest `look.skater` 8 of 8, `rig.skater` 11 of 11 (the two that failed on f9d2db9 pass on b1ea774), `core.rink.arena`
5 of 5, the two classic pins; `tl check --tier fast` exit 0, 5 of 5 steps (no new public member: `tl arch` passes).
Full tier not run.
