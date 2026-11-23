# K7 look, round 2: the light question, film, the contact shade, and the figure in lane K6's hall

## 1. Where the light on thirdjam's figure comes from: measured, and it is not indirect light

`tools/look_light_probe.py`: thirdjam's own figure in Unreal under its rig, drawn five times with the scene's light
taken away piece by piece (A as it is, B no sky light, C no Lumen, D neither, E neither and no shadows), read in
scene-linear units from the HDR scene colour, with two grey cards (albedo 0.5) beside it. `tools/look_light_read.py`
reads the same boxes in ours (`look_gym --linear=0.1`: the shader's value before the film curve).
4 of 4 shots fresh. The whole table: `media/r2_light_probe.txt`.

| What | thirdjam, spots alone (E) | thirdjam, everything (A) | ours |
|---|---|---|---|
| grey card on the ice, as the rig's own numbers predict: 1.788 / 1.199 / 0.733 | 1.797 / 1.203 / 0.734 | 1.836 / 1.227 / 0.750 | (not drawn) |
| back patch (blue 7) | 1.719 / 1.031 / 0.477 | 1.852 / 1.094 / 0.508 | 1.812 / 1.095 / 0.513 |
| jersey back, blue | 0.051 / 0.090 / 0.422 | 0.053 / 0.094 / 0.434 | 0.052 / 0.097 / 0.452 |
| helmet, blue | 0.055 / 0.092 / 0.389 | 0.059 / 0.096 / 0.398 | 0.056 / 0.097 / 0.395 |
| pants | 0.047 / 0.037 / 0.042 | 0.050 / 0.038 / 0.043 | 0.048 / 0.037 / 0.044 |
| cheek | 1.047 / 0.508 / 0.258 | 1.074 / 0.516 / 0.266 | 1.119 / 0.545 / 0.273 |
| jersey back, orange | 1.008 / 0.156 / 0.039 | 1.062 / 0.164 / 0.039 | 1.095 / 0.176 / 0.044 |
| helmet, orange | 1.086 / 0.172 / 0.039 | 1.133 / 0.180 / 0.039 | 1.095 / 0.176 / 0.044 |

What it says:
- **The rig and the units are right.** The card reads what the 18 spots' numbers predict, within half a per cent.
- **The material port is right in the source's own units.** Ours stands within about 9 % of thirdjam's figure on every
  surface read, mostly within 3 %, and where it differs ours is the brighter.
- **Indirect light is small in this render.** The sky light adds 2 to 4.5 %. Switching Lumen off changes nothing at all
  (C equals A to three decimals), so either a scene capture draws no Lumen light or the switch does not reach it:
  the probe cannot say what Lumen adds in the game's own window.
- **So the helmet and patch gap against the running game (round 1) is not explained by this, and I ported nothing.**
  In linear units ours is already about as bright as thirdjam's figure with all its light (within 4 %). The gap is between Unreal's scene
  capture and Unreal's game window (the film curve as we have it, bloom, the upscaler, perhaps Lumen there), which is
  lane K6's tone question as much as mine. The way to settle it is two stills of the running game, Lumen on and off.
- (Section 5 overturns the conclusion for the game's own window: read on.)

## 2. Film

- `media/r2_film_stride_three_blue.mp4`, `r2_film_stride_back_blue.mp4`, `r2_film_stride_back_orange.mp4`: the Stride
  clip, all 59 keys, thirdjam's own render left, ours right, four loops at speed and two at a quarter (11.6 s each;
  177 of 177 reference shots fresh, 59 of 59 keys paired in each film).
- `media/r2_film_ten_near_to_far.mp4`: ten felt skaters striding away from the game camera at 7 m/s, near to the far
  end (7 s), under the rig in the look gym.
- **What I can and cannot say:** I looked at four frame pairs of the three-quarter film and three frames of the ten
  film as stills. In those the poses and the surface agree; the numbers read in the near frame and not in the two
  farther ones, where the figures are two colours with a pale patch. I cannot watch a film: whether the grain slides on a bending limb
  and whether the far figures shimmer is for an eye on the mp4s. Not judged by me.
- The films are in the look gym, not in the match: the match on this branch lights the figures by the fallback until
  `TLStyleFelt.set_rig` is called beside lane K6's rig.

## 3. The contact shade under the figure

- Ported: thirdjam's `ContactShadow` component (the played world, lane K6's export: the engine's 1 m plane scaled
  0.5 x 0.7, 3 cm before the mesh's origin, 0.4 cm over the ice, no shadow) with its material `M_SkaterContact`
  (multiplies what is under it: 1 at the rim, Darkest 0.45 in the middle), as `style/shaders/body_contact.gdshader`,
  `TLStyleFelt.contact_material`, and a child of the figure made by `TLRigSkaterLook` (felt only).
- On the look gym's ice the style's hard blue shadow covers it; it is judged on lane K6's ice in section 4.
- The lying figure's wider shade (scale 2.2 x 0.95, Darkest 0.75, Flat 0.7, turned along the body) waits for the
  falls in lane K2's driver.

## 4. In lane K6's hall (second half, after be548e5)

- **One include.** `body_felt.gdshader` includes `hall_rig.gdshaderinc` and has no rig sum or film curve of its own.
- **The clay normal maps once**, in `engine/style/felt/`. The two copies under `engine/cores/rink/arena/tex/` are
  deleted (byte-equal); `rink_arena.gd` `_texture` falls back to the style's folder for a name it does not hold.
- **The rig reaches the figures:** `rink_arena.gd` line 79, `TLStyleFelt.set_rig(r["lights"], r["exposure"], r["gain"],
  r["gain_shadows"])`. The sky light is not handed on (2 to 4.5 %, section 1; deviation 6).
- **A view for it:** `engine/cores/rink/arena/review/figure_view.tscn`: the hall, felt figures where a still of the
  game had them, that still's camera. `media/r2_hall_game_over_ours_f5360.jpg` (the game above, ours below; only
  the 7 stands where the game's stood, from the camera log; the other three are placed by eye and are off).
- **The contact shade on K6's ice:** a soft dark patch at the feet in both (`media/r2_hall_7_game_ours_without_and_
  with_floor.jpg`); the ice under the feet reads #9d8994 in the game and #98888d in ours. I see no difference worth a
  change. Judged on one still, one skater, standing.

## 5. The game's own window, Lumen on and off: indirect light IS there, and it is the ice

Two runs of thirdjam's build with the same scripted hand (lane K3's command), the second with
`r.DynamicGlobalIlluminationMethod 0` (the log confirms it took), 53 stills at the same frames.
`media/r2_game_lumen_on_over_off.jpg` (frame 1260). On the figures, in display-linear terms, Lumen multiplies:
the helmet by 1.5 to 1.7, the jersey's side by 1.5 to 1.75, the pants by 1.7 to 1.9, the orange jersey by 1.4 to 1.6,
skin in shade by 3, the back patch by 1.07 to 1.27; the ice itself by 1.01 to 1.05.
So section 1's reading was the capture's, not the game's: a scene capture draws no Lumen light, the game's window does,
and it lands on the faces that look sideways and down. Round 1's guess was right after all, and my "not the cause"
of the first half was wrong for the game.

**Ported as the ice's first bounce.** The ice is taken as a wide matte sheet under the same rig, a face of normal n
has it in (1 - n.y) / 2 of its sky: `floor_bounce` in the shader, `TLStyleFelt.set_floor(albedo)`, given the ice's
own body colour by `rink_arena.gd` (thirdjam's `ClayIceBody` 0.32 / 0.42 / 0.97; the game's ice with Lumen off,
taken back through the film curve, gives 0.31 / 0.39 / 0.82 for the same thing). No number of mine in it.

Same camera, same place, the 7 of frame 5360:

| | the game | ours without | ours with the floor |
|---|---|---|---|
| helmet | #181746 | #101534 | #141c4e |
| patch | #c5a373 | #a7875e | #ac8f69 |
| jersey back | #121242 | #10163e | #111847 |
| shoulder | #16174a | #1a2050 | #1c245f |
| pants | #0b0505 | #0b0909 | #0d0a0c |

The helmet's gap mostly closes; the patch's hardly does (it still reads an eighth darker); the shoulder, which was
already a little bright and blue, is more so. Better by my eye on the whole, not parity. It is one bounce off a flat
sheet: the boards, the other figures and the light's colour after the ice are not in it.

## What my eye rejects in the hall

1. The patch is still darker than the game's, and the shoulders are bluer.
2. A thin dark line shows along the skates and the stick hand of ours close up: the style's ink at the figure's edge
   (lane K6's hall keeps the ink pass near the camera). thirdjam has none.
3. Ours is sharper than the game everywhere (the game draws at 72.8 % and upscales).
4. Only one skater stands where the game's stood; I have no positions for the others.

## Deviations added this round

1. The contact shade is made by the look (a child of the skeleton), not by the driver; only the standing form.
2. Kernel API 1.23 -> 1.24 (two methods on TLStyleFelt).
3. Selftest `look.skater.shaders_kept` now leaves the look's own two shaders out of "must equal HEAD": in round 1 they
   were untracked and the case could not see them; once tracked it failed on my own edit to my own file.
4. The floor's bounce stands in for Lumen: one bounce off a flat sheet of the ice's body colour.
5. Two of lane K6's files are edited: `rink_arena.gd` (the set_rig line, the set_floor lines after it, two lines in
   `_texture`), and its two clay normal maps are removed from `arena/tex/`. A new review scene sits in its `review/`.
6. The set_rig line passes four arguments, not `r["sky"]`: taking the rig's sky dictionary would change the signature
   of a 1.23 method (`tl arch` calls that a change, not an addition), and the sky light is not drawn anyway.
7. Three new TLStyleFelt methods wait for a kernel number (1.27): `contact_material`, `set_review_linear`, `set_floor`.
