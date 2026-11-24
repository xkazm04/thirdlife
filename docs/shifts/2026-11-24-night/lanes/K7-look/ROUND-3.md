# K7 look, round 3: the figures' shadows on the ice, the blue's hue, the edge line (24 Nov 2026)

## 1. How thirdjam makes its shadows (found), and the port

**What thirdjam has** (its rig as the running game holds it, lane K6's export `arena.json`; its skater Blueprint):
- **Four key spot lights cast them**: `Key_P3_Clay_1..4`, 13 m over the rink's long axis at x = -33.75, -11.25, 11.25,
  33.75 m, pointing straight down, 5200 cd, cones 16 / 62 degrees, radius 30 m, source radius 60 cm, virtual shadow
  maps. The other fourteen lights cast none. So a figure throws one shadow a key in reach, away from that key's
  foot: under a key it is short; 10 m from a key's foot a 1.6 m figure's is 1.4 m long; between two keys there are
  two, each taking half of the keys' light. That is the "long" K3 saw, and why length changes across the ice.
- **A contact shade** under every skater (`ContactShadow`, round 2), which the driver widens to 2.2 x 0.95 m, Darkest
  0.75, Flat 0.7, turned along the body, while he is down: the lying man's shadow "as big as he is".
- **A streak towards the camera** under a standing figure is mostly the ice's screen-space reflection of his legs
  (the rig switches it on for the ice), not a shadow. Not ported (lane K6 lists it as not ported).

**What ours had**: the hall summed the rig without shadows and the ice took ONE shadow from the style's sun, which
`TLStyleHall` points straight down: a blob under the feet wherever he stood, nothing beside a lying man.

**The port**:
- `engine/style/tl_style_hall_keys.gd` (new, `TLStyleHallKeys`): the rig's shadow-casting lights as real spot lights
  with shadow maps (4096 px a key). They light nothing (black); `hall_ice.gdshader` reads each one's shadow and takes
  away that key's own share of the rig's light at the point, so the darkness of a shadow is the rig's own numbers.
- The contact shade's lying form (`TLRigSkaterLook.ContactShade`), driven by the driver's own flag (`bShade`, which
  lane K2's falls already keep).
- Open ice is unchanged to the grey level (twelve points in three pictures, with and without).

## 2. Pairs, looked at (the running game | ours before | ours now; whole frame above, the figure below)

Our figures stand where the game's stood: the camera and the human's place are thirdjam's own log of the frame, the
others are placed by the ray through their feet in the still. Poses are picked by eye from the clips.

- `media/r3_shadow_striding_game_before_after.jpg` (frame 1260, 10 m from the first key's foot): thirdjam's long
  shadow to the left; ours before: a blob at the feet; ours now: the same shadow, same side, same length, about as
  dark, a little crisper at its rim.
- `media/r3_shadow_standing_game_before_after.jpg` (frame 1500, the faceoff, midway between two keys): thirdjam's faint
  streak towards the camera and the wingers' sideways shadows; ours now has both. Ours is a little darker and more of
  a shape than thirdjam's under the centre man (theirs is half reflection).
- `media/r3_shadow_lying_game_before_after.jpg` (frame 2400): thirdjam's lying man has a dark edge of shadow along his
  body; ours before had none; ours now has a wide soft shade round him. **Fainter and softer than thirdjam's.**
- `media/r3_match_still_ours.jpg`: the match itself (`tl capture`, the hokej pack, frame 1300): the shadows are in the
  game, not only in the review scene.

What my eye rejects: the lying man's shade is too soft; thirdjam's rims widen with the caster's height (a 60 cm
source) and ours are one width; the streak of reflection is missing. Not looked at: a shadow in motion (no film this
round), a shadow across the boards' foot or a goal, the far end of the rink. In the lying pair our man lies face down and theirs on his back, and his head turned
differently in two runs of the same shot (the clip and the driver's head turn, not this lane's).

## 3. The blue's hue: Unreal's film pipeline, whole

`tools/look_tone_check.py`: thirdjam's own figure's scene-linear colours through (a) the hall's curve as it is and
(b) Unreal 5.9's whole pipeline (ACEScg, gamut expansion, the post volume's grade, blue correction, glow, red
modifier, the curve, back), against the game's still:

| surface | (a) hall_tone | (b) Unreal's | the game |
|---|---|---|---|
| jersey, blue | #0e164a | #141549 | #121242 |
| helmet, blue | #101745 | #161745 | #181746 |
| pants | #0b0605 | #0f0707 | #0b0505 |
| back patch | #be9d67 | #c09b69 | #c5a373 |

The game's blue has red as high as green; the curve alone leaves red at half of green. That was the "bluer shoulder".
Ported as `engine/style/shaders/hall_film.gdshaderinc` (`hall_film`), used by the felt figure. In the hall, the 7 of
frame 5360: jersey #101347 (game #121242, round 2 #111847), helmet #14164e (#181746, was #141c4e), shoulder #1c1e5e
(#16174a, was #1c245f), patch #b09066 (#c5a373, was #ac8f69): `media/r3_colour_ink_7_game_round2_round3.jpg`.
**Hue closed; level not**: the shoulder is still about a quarter too bright and the patch an eighth too dark there.
He stands a metre from the lit boards in that frame; what they throw on him is not in our light.
The hall's own surfaces still go through `hall_tone` (lane K6's): a neutral is the same through both, its saturated
wood and crowd would shift. For K6 to look at and switch, one call a shader.

## 4. The line at the figure's edge

It was the style's ink at the antialiased rim (lane K6 kept the lines near the camera "for the cel figures").
thirdjam draws no contour, and with felt figures nothing in the hall is cel: when the look is felt, the hall's lines
now end at the eye. `media/r3_edge_ink_on_and_off.jpg`. The boards' and goals' lines go with it.

## Cost

Ten striding skaters in the hall at 1280 x 720 (RTX 4090, uncapped, 600 frames, twice each): with the keys GPU
0.74 ms and render CPU 0.60 to 0.63 ms a frame; without 0.58 and 0.39 to 0.46. About 0.3 ms a frame. Atlas 8192 px.
Not measured on a lesser card.

## Deviations (this round)

1. Shadow softness is one filtered width, not the 60 cm source's widening penumbra (the engine's own soft shadows for
   a spot light came out hard and stepped here).
2. The shadow's darkness between tone-mapped "all keys" and "no keys" is shared out by each key's luminance share
   (exact for one key, an approximation where two overlap).
3. Shadow maps of 4096 px over a 136 degree cone (about 1.6 cm a texel under a key): thirdjam's are virtual shadow maps.
4. The ice's reflection of the figures is not ported.
5. The keys act on the game's viewport (shadow atlas size and quadrants, the renderer's spot shadow filter).
6. The film pipeline's saturation and contrast are left to the screen grade (where the hall has them), not in ACEScg.
7. The felt figure and the hall's surfaces go through two film functions until lane K6 switches.
8. The hall's ink is ended when the look is felt (lane K6's HALL_INK was a choice of ours, not thirdjam's).

## Files of other lanes touched (marked "K7")

- `engine/style/shaders/hall_ice.gdshader` (K6): one uniform (`key_shadows`), one header line, the `light()` function
  (the directional branch gated, a new spot-light branch between "K7 begin" and "K7 end").
- `engine/cores/rink/arena/rink_arena.gd` (K6): in `light()` the lines between "K7 begin" and "K7 end" (the keys, the
  receive, the ink); in `rig_lights()` one key added (`source_radius_m`, marked K7).
- `engine/cores/rink/arena/review/figure_view.gd` (mine, in K6's folder): `--keys`, `--ink`, `--keyopt`, `--cost`,
  `--check=shadow`, `"down"` in a shot.
- Nothing of lane K2's driver.

## Gates

- selftest `look.skater` 8 of 8 (new: `.shadow`, and `.shadow_red`: the same check fails with the keys off);
  `core.rink.arena` 5 of 5; the two classic pins pass.
- selftest `rig.skater`: 8 passed, **2 failed** (`rig.skater.verbs.oracle`, `.pin`). Not this round's: a clean export of
  HEAD f9d2db9 with none of my edits fails the same two with the same figures.
- fast tier: `arch` fails on the new class `TLStyleHallKeys` (it waits for its kernel number) and the three devx tests
  that mirror it; assets, cards, foreman pass. Full tier not run.

