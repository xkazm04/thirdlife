# dio-astra: PATCHES (for the Director and the partner arm)

## For the Director, 10:47: a defect on d20-base (all four arms start from it)
`engine/rigs/biped/clay_biped.gd` (Astra's clay figure, merged in 37772a6) declares `func _face(helmet: bool)`, which
collides with the inherited Array `TLMesh._face` in `engine/kits/tl_mesh.gd`. ClayBiped extends ClayForm, which extends TLMesh. GDScript refuses the file
("Parse Error: Member "_face" is not a function"), so no biped compiles: the review close-ups show no figure, the
parkour and hockey captures stop on the watchdog (21 / 72 script errors), and the world step's alone runs give no hash
(your d20-base `st-rig.` 1/14 and `full3` world 4/8, packs 0/2 come from this).
Fix in this tree (two lines, a rename only): `_face(helmet)` -> `_sculpt_face(helmet)` at line 43 and the declaration
at line 178. The cel arms carry the same defect.

### Builder verification of the rig fix

With the rename all 12 wardrobes build, the stage views contain the biped, and both game captures finish. The repaired base archive also supplies the classic and optical controls for this round.

## For the Director | export AA

The Director assigned style-selected boot AA to dio-astra as the first item of round 2. The explicit `TL_EXE_AA` override takes precedence, and an absent style key keeps `msaa=2,taa=1`. For the round 1 build, `TL_EXE_AA=msaa=4,ss=smaa,taa=0` selects the measured diorama setting. The legacy inked look has a separately measured reason for temporal AA.

On a 1920x1080 D3D12 RTX 4090, I drove the same walk in the real boot scene. Each capture reported the same physics frame (173), and the trace camera and player positions matched. Luma Laplacian variance on the full-size frame and GPU p50 from each boot run follow. The last column measures movement across 51 half-size frames, 125-175. It is the median per-frame mean absolute second temporal difference of luma in the horizon, rows 100-209, columns 96-863. A higher number includes both motion and shimmer.

| Boot AA | Far | Middle | GPU p50, busy | Horizon motion |
|---|---:|---:|---:|---:|
| Shipping 2x MSAA + SMAA + TAA | 36.6 | 23.5 | 1.794 ms | 1.130 |
| 4x MSAA + SMAA | 216.9 | 109.4 | 2.574 ms | 1.291 |
| 8x MSAA + SMAA | 213.9 | 108.6 | 3.606 ms | 1.175 |

The 4x frame resolves the road grit and tree trunks behind the player. In a static junction crop (x 815-1084, y 404-505), the same luma metric goes from 9.5 to 94.4. In the road-edge crop (x 980-1359, y 785-944) it goes from 4.3 to 25.4. On this walk 8x buys a little more temporal stability, at another 1.03 ms for similar spatial detail. The boot window carries HUD text in the bottom band, so I used the far and middle bands for the decision. Full images, 51-frame sequences and boot logs are under `.tl/astra-r1/boot-{shipping,msaa4,msaa8}/`. See the unscaled crops in [the boot comparison](stills/evidence/boot-aa.jpg).

A second walk on the delivered sky gave the village an additional 210 stationary frames to load before applying the same input. At captured frame 383, shipping AA measured 43.5 far and 24.8 middle. The proposed 4x setting measured 199.9 and 108.9. Both the matching road crop and this later capture support the export choice. The raw pair is in `.tl/astra-r1/boot-final-{shipping,msaa4}/`.

## For dio-fable | the road and riverbank after the lens repair

At 07 the foreground pebbles and fence shadow now resolve separately. At the visitor's feet the dirt still has diagonal repeated marks, and the meadow shows long parallel grooves. At the riverbank the deciduous crown and bush are broad angular sheets. The board has separate flock tufts, a few larger irregular stones and varied crowns at those same scales. Please judge your surfaces in the westbound yard and riverbank views at native size. The booth, crane, river and hills in these captures use your inherited surfaces.

## Round 2 integration | boot AA delivered

The diorama boot now reads `env.exe_aa` and uses 4× MSAA plus SMAA. `TL_EXE_AA` takes priority, and classic keeps its prior settings. On the same boot walk, far and middle edge energy increased 4.60× and 4.42×. Horizon motion increased from 0.607 to 1.229 luma levels. The three uncaptured walks per build gave GPU medians of 2.462 and 2.497 ms on the shared machine. The frozen-frame and capture-on measurements are in the [round 2 notes](ASTRA-NOTES.md#round-2). The [native boot crops](stills/evidence/boot-window-round-2.jpg) show the effect on the distant rail and road.


## For dio-fable | Round 3

The new studio key is `#ffb987` at 1.83 energy, 18° elevation and −122° azimuth. Keep the lit meadow gold-olive and the pines distinctly greener. These are proposed source dyes for your next render.

| Key | Joined | Proposed |
|---|---|---|
| `palette.grass` | `#7e9a3e` | `#a3b057` |
| `palette.grass_dark` | `#4a7836` | `#496c36` |
| `palette.grass_dry` | `#98a848` | `#b4be63` |
| `palette.pine` | `#385c34` | `#405d31` |
| `palette.pine_light` | `#517c40` | `#758945` |
| `water.sky` | `#ffc59a` | `#f8b786` |
| `water.sky_top` | `#8a78c8` | `#634d69` |
| `water.cloud` | `#ffe2b4` | `#ffeeb9` |

The grass and dry-felt proposals add red and blue to the lit nap. They leave green above red in the source dye because `toon.gdshader` uses that difference to identify felt. The rendered key already puts red above green. Use 01 and 07 for sunlit grass and 13 to check the backlit bank. The pine proposal brings up the sunward tier while keeping the underside green. These five dyes are estimates awaiting a material render.

The three river values come from a 1024×512 linear HDR bake of the actual cotton sky. I rendered a second panorama with the tufts hidden, sampled bare sky at 0–3° and 45–60° elevation, trimmed the lowest and highest 10% of luminance in each band, then converted each linear mean to sRGB. For the broad cloud face I took texels at 4–57° whose linear luma exceeded the bare sky by 0.16, then averaged the 65th–90th percentile. The resin shader interpolates its two sky stops by reflected elevation and mixes in 20% shallow-water colour before the reflection is applied. The proposed values belong in its source-colour uniforms. The bakes are in `.tl/astra-r3/radiance/`.


**Measured dye response.** RGB values below use the brightest 40% and darkest 15% of yellow-olive pixels in rows 300–719 at 1280×720, reselecting the groups in each frame as the shadows move. The board filter includes some ochre road. The operator's board swatches are 206, 162, 56 in light and 67, 62, 18 in shade. Our implementation of the mask measured 205, 160, 54 and 67, 62, 18.

| View | Joined lit / shade | Round 3 lit / shade |
|---|---|---|
| 01 Walker road | 150,155,34 / 97,110,29 | 181,159,34 / 82,80,20 |
| 07 Parkour road | 144,151,35 / 92,101,26 | 168,149,34 / 65,62,16 |
| 13 River road | 132,137,26 / 73,79,18 | 103,90,18 / 54,51,11 |

At 07 the shadow is within two levels of the board in every channel. The lit nap still needs roughly +38 red, +13 green and +22 blue. Keep 13 as the check against overly dark backlit felt. A polygon inside the near left pine at 13 averaged 57,71,32 joined and 46,51,21 delivered. Its lightest 30% averaged 57,60,24 delivered. Two board pines averaged 73,79,33 and 76,83,35, with lit tiers at 133,123,52 and 145,133,54. The board's trees face the key differently. Compare that separation on a sunward face in 01 before changing both pine colours again.

## For dio-fable | Round 5 grade

I am keeping the grass hue in your dye. The joined 01 and 07 lit-felt samples already sit at about 43 to 45 degrees and reach median values of 0.95 and 0.87. My grade work changes the response to light across materials, rolls off the brightest sunlit surfaces and opens the riverbank shadows. Your slope-and-sun dye can supply the deeper greens in hollows. Please judge the combined result on the 01 and 07 lit patches and the 13 bank.

The first round 5 trial uses the same peach key, raised from 18° to 30° and turned from −122° to −106°. Sun energy is 1.67, exposure 0.75, shadow opacity 0.78. The print grade applies 0.16 local contrast and 0.10 highlight gain. The split tone is weaker at 0.026. The separate sky exposure multiplier is 1.12. These choices apply to felt, timber, paint and road together.

With integration-2 surfaces in the standard tour, lit grass in 01 measured H 42.9°, S 0.76, V 0.75. In 07 it measured H 44.3°, S 0.74, V 0.70. Channel clipping fell from 23.85% to 2.28% in 01 and from 25.83% to 4.11% in 07. The board’s hand-picked sunlit patches are H 41–43°, V 0.54–0.74. In 13 the darkest 15% of the bank are RGB 85/69/22, up from 63/51/15. The board’s corresponding shade is 97/51/19. These are the pre-dye readings for comparison when both arms land.

At 17:25 the operator found a 77-level ground spread in both 01 and 07, below the board's 122. I am restoring directional shade and highlight separation in the frame grade. The grass dye still belongs to Fable.

The revised light is peach at 28° elevation and −92° azimuth, with 0.93 shadow opacity. Exposure stays at 0.75. The print curve expands the middle of the luminance range, keeps headroom on saturated highlights, and adds warm fill where a wide neighbourhood is in shade. A density adjustment holds bright coloured midtones down. It scales all three colour channels together. Fable can judge the hollow dye against these settings using the lit meadow, the broad bank and the narrow fence shadow.

Final pre-dye readings from the native tour are H 42.8° / V .80 in 01 and H 43.9° / V .72 in 07. Clipping is 4.07% and 4.88%, respectively. The lower-half spreads are 120.9 and 124.4, versus 122.4 on the board. The 13 bank is 62/114/166 at p5/p50/p95. The frame leaves 01 about six brightness points above the brightest board meadow swatch. The 07 swatch already falls inside its reference range.
