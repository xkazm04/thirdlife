# Operator measurements on the integration-2 tree (8968ffe), for round 5

Shots: `.tl/j2/dio/` (tour + figure, 1920x1080), taken 16:28-16:45.

## Sharpness (tour, geometric mean of 16; `python .tl/sharp.py .tl/v4/dio .tl/j2/dio`)
far 361.6 -> 471.1, mid 333.4 -> 467.2, near 277.5 -> 506.5 (dio-fable's r3-r5 surfaces on your r4 frame).

## Channel clipping (frames scaled to 1280x720)
Share of pixels with any channel >= 250 / share with luma >= 235:

| | 07_parkour_road | 01_walker_road |
|---|---|---|
| board 4 | 8.5 % / 0.11 % | - |
| joined i1 (`.tl/j1/dio`) | 4.3 % / 0.10 % | 1.0 % / 0.43 % |
| your r4 (`.tl/v4/dio`) | 21.0 % / 0.29 % | 16.0 % / 0.50 % |
| joined i2 (`.tl/j2/dio`) | 25.7 % / 0.28 % | 23.6 % / 0.49 % |

The clipped channel is red, in the sunlit road, the meadow and the scaffold. In 07 the scaffold block (x 1100-1700,
y 300-560) averages (211,148,74) on i2 and (192,137,65) on r4; by eye on i2 the orange scaffold reads pale cream-yellow
against the board's saturated timber.

## Process note
`shotset.sh` was edited at 16:38 while my run of it was executing; bash read the changed file mid-run and stopped
with a syntax error at line 38 (my tour and figure shots had finished). Please do not edit a script while it may be
running; put a changed copy beside it instead.

## The Director, 16:55, verbatim
"By eye beside board 4, the frame's biggest gap is now the grade:
(1) The whole frame is sepia/ochre. The grass reads mustard where the board reads green with golden light on it.
Measure lit grass hue on 01 and 07 against the board's sunlit meadow: the board keeps the greens green and puts the
warmth in the light and the highlights.
(2) The sky has streaky brush-like texture over the purple and reads muddy brown-violet near the horizon. The board's
sky is a clean warm gradient behind cotton clouds.
(3) Shadows on 13 are near-black olive, so lift the shadow floor.
dio-fable's slope-and-sun dye (deep greens in hollows) lands this round. Coordinate through PATCHES so you don't both
correct the same yellow."

## Operator measurements for those three (1280x720)
1. **Grass.** Board sunlit meadow, hand-picked grass patches (median HSV): left meadow x 200-300 y 400-450:
   mean (185,144,34), H 43, S 0.82, V 0.74; far meadow x 620-720 y 250-285: (166,126,44), H 43, S 0.74, V 0.68;
   right strip x 1000-1100 y 600-650: (162,114,30), H 41, S 0.82, V 0.63; left foreground x 40-160 y 600-680:
   (139,103,23), H 42, S 0.83, V 0.54.
   Ours, lit grass (brightest 40 % of olive pixels, rows 360-720): i2 01 (241,192,55) H 44 S 0.78 **V 0.95**;
   i2 07 (225,181,57) H 45 S 0.76 **V 0.87**; i2 13 (164,126,35) H 42 S 0.79 V 0.64. (i1, before the new key and
   flock: 01 (152,155,39) H 62, 07 (147,152,38) H 65.)
   So the hue and saturation of our lit grass now match the board's (about 43); the value is well above it (0.87-0.95
   against 0.54-0.74), and the red channel clips (any channel >= 250 in 24-26 % of the frame, board 8.5 %).
2. **Sky.** Laplacian variance of luma in rows 5-120: board 63.8; i2 07 101.2; i2 01 18.3. Mean RGB of those rows:
   board (190,129,126), 07 (186,125,115), 01 (168,117,114).
3. **Shadows in 13.** Darkest 15 % of rows 400-720: ours (63,51,15), lower-half luma p5/p50 50/78; board darkest 15 %
   (97,51,19), a warm brown.

## 17:25 operator check of your r5 trial (`.tl/astra-r5/gallery/`), 1280x720, rows 360-720
| | luma p5 / p50 / p95 | spread | mean saturation | frame mean RGB | any channel >= 250 |
|---|---|---|---|---|---|
| board | 59 / 133 / 181 | 122 | 0.76 | (180,116,65) | 8.5 % |
| i2 07 | 63 / 158 / 193 | 129 | 0.74 | (198,137,73) | 25.7 % |
| r5 07 | 85 / 136 / 162 | **77** | 0.73 | (185,126,74) | 4.0 % |
| i2 01 | 82 / 169 / 201 | 118 | 0.75 | (204,146,78) | 23.6 % |
| r5 01 | 87 / 136 / 164 | **77** | 0.74 | (181,131,80) | 2.2 % |
| i2 13 | 50 / 79 / 157 | 107 | 0.78 | (144,104,54) | 5.0 % |
| r5 13 | 68 / 118 / 153 | 85 | 0.77 | (160,119,63) | 0.9 % |

The clipping is gone and the medians now sit on the board's (136 vs 133), but the lower-half spread fell back from
118-129 to 77 (the board keeps 122: p95 181 with only 8.5 % clipped, p5 59). By eye, r5 07 reads softer and flatter
than i2 07, with the long raking shadows weaker. The Director's integration-1 note was "the light reads flat and even
over the meadow, without the board's warm raking light and the long soft shadows".
