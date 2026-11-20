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
