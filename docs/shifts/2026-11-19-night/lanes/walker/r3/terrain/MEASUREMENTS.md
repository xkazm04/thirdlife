# Terrain silhouettes on the bank and bluff

The revised shader restores the bold bluff skyline and shoulder ridge. All 36,076 terrain pixels that HEAD drew at opacity 0.9 or higher across the four views still reach 0.9. On the bluff walk, coverage at 5–15% depth gaps went from 0/82 in HEAD to 80/82 in 3b and stays at 80/82. The moving bluff now flips more often than HEAD. The bank and the STYLE.md thin-member pan match HEAD.

[Production images and measured crest locations](crest-comparison.jpg) · [Full-size stills](../../stills/)

## Opacity on the original strong stroke

HEAD is `c8b88fc683b057c5523c883efd07ffc84c95ae2e`. The probe loads the HEAD post and toon shaders from Git, the reviewed 3b post shader from [its snapshot](r3b-reviewed.gdshader.txt), and the revised shaders from the worktree. In each view the selection is fixed by HEAD. Hiding the actual terrain mesh must expose at least 2 cm of additional depth. The HEAD shader must report `0.96 * outer >= 0.9` after distance fade, before quantization. A second channel encodes continuous outer opacity in 8 bits for the means. Creases, contact shade, framebuffer AA and grading are excluded from this diagnostic. The comparison sheet uses the production beauty render with its ordinary AA and grade.

| HEAD-selected terrain | Pixels | HEAD mean | 3b mean | Revised mean | Revised still ≥0.9 |
|---|---:|---:|---:|---:|---:|
| Bank approach, tick 310 | 7,463 | 0.9593 | 0.7391 | 0.9593 | 100% |
| Bluff walk, tick 120 | 11,638 | 0.9579 | 0.6298 | 0.9579 | 100% |
| Bluff shoulder | 7,898 | 0.9596 | 0.6955 | 0.9596 | 100% |
| Flat control, whole view including far edge | 9,077 | 0.9575 | 0.5467 | 0.9575 | 100% |

Within the director's bluff crop, the same 1,668 pixels read 0.9605 / 0.6224 / 0.9605. Within the shoulder crop, the same 1,138 pixels read 0.9597 / 0.6990 / 0.9597. Removing only the cap left whole-view means of 0.8142, 0.8471 and 0.8986 on the bank, bluff and shoulder. Restoring the original brush sampling positions was also necessary. [Per-view and crop measurements](strong.txt)

## Crest coverage

Each cell gives covered pixel counts for **HEAD / 3b / revised**, followed by the common denominator. A covered pixel carries outer opacity of at least 0.5. The four gap bands use the increase in camera-space depth to the pixel above, divided by foreground depth.

| View | 1–<5% | 5–<15% | 15–<50% | ≥50% | All |
|---|---:|---:|---:|---:|---:|
| Bank | 1 / 17 / 20 of 31 | 6 / 59 / 60 of 64 | 13 / 45 / 45 of 47 | 13 / 18 / 17 of 18 | 33 / 139 / 142 of 160 |
| Bluff | 0 / 21 / 21 of 30 | 0 / 80 / 80 of 82 | 108 / 132 / 132 of 132 | 709 / 812 / 813 of 813 | 817 / 1,045 / 1,046 of 1,057 |
| Shoulder | 2 / 22 / 22 of 35 | 33 / 299 / 299 of 299 | 35 / 175 / 176 of 179 | 344 / 373 / 372 of 373 | 414 / 869 / 869 of 886 |

Four consecutive vertical pixels must all belong to terrain. The foreground pixel must be within 80 m, the pixel above it at least 25 cm and 1% farther away and within 500 m. The reciprocal-depth jump must exceed three times the local slope on both sides. This selects land against land independently of ink and includes no sky. Median foreground depths in the 5–15% band were 21.9 m on the bank, 19.0 m on the bluff and 28.8 m at the shoulder. All 66 depth frames and all 66 terrain-removal frames were byte-identical across versions. [HEAD census](head.txt) · [3b census](r3b.txt) · [Revised census](after.txt)

## Motion and cost

Each cell gives **mean absolute grey-level change / percentage of pixels changing by more than 24**. Each walk contributed 32 frames and 31 adjacent pairs. The broad sample uses x=48–847, y=555–974, with terrain ownership required in both frames. The smaller 240×90 lossless clips start at (288,615) on the bank and (48,615) on the bluff. Every pixel in those clips was terrain in every frame.

| Sample | HEAD | 3b | Revised |
|---|---:|---:|---:|
| Bank, terrain-only boil | 1.103 / 1.322 | 1.102 / 1.322 | 1.103 / 1.322 |
| Bluff, terrain-only boil | 1.822 / 2.010 | 1.170 / 0.202 | 1.823 / 2.217 |
| Bank, all terrain-owned pairs | 1.1066 / 0.90869 | 1.1056 / 0.90624 | 1.1066 / 0.90869 |
| Bluff, all terrain-owned pairs | 1.1498 / 0.80623 | 1.1132 / 0.65069 | 1.1995 / 0.90880 |
| Bluff, within three pixels of a measured crest | 5.6499 / 8.80441 | 3.5088 / 1.10791 | 6.2191 / 9.54459 |
| STYLE.md thin-member pan, frames 40–145 | 3.065 / 2.625 | 3.065 / 2.625 | 3.065 / 2.625 |

The near-crest sample contains the same 253,180 pixel pairs in all three versions. The flips there number 22,291 / 2,805 / 24,165. Hiding the post pass leaves 15. The bank's lower crop contains no measured crest pairs. The screenshot samples the bank higher in the frame. Additional coverage introduces more visible moving edges on the bluff. These fixed-screen measurements include movement of the stroke with the camera.

I also tried feathering the stroke. Three extra foreground depth samples reduced near-crest flips to 8.86839%, with mean change 5.9517. HEAD measured 8.80441% and 5.6499. A screen-derivative variant reached 8.55913% flips, but mean change rose to 6.2006 and 56 flat-control pixels picked up ink. Neither variant met all three controls.

| Control or texture reads | HEAD | 3b | Revised |
|---|---:|---:|---:|
| Flat grazing pixels with any measurable ink, 8–80 m | 6,344 / 279,300 | 0 / 279,300 | 0 / 279,300 |
| Largest flat-control opacity, in 8-bit codes | 87 | 0 | 0 |
| Flat grazing pixels at ≥0.5 | 0 | 0 | 0 |
| Base post reads per pixel, without / with contact shade | 35 / 44 | 35 / 44 | 35 / 44 |
| Additional reads if the crest needs fresh texels | 0 | 0 | 5 |

The 3b cap and its changed sampling positions affected established silhouettes. The revised rule keeps the original positions and brush weight. A weak terrain pixel checks an independently centred vertical profile for a crest. It can reuse the existing taps when both profiles address the same texels. Otherwise it reads three depths and two normal/roughness values. The extra branch ran on 39.16% of the bank, 33.45% of the bluff and 34.43% of the shoulder full-screen renders, averaging 1.958, 1.672 and 1.722 extra taps per screen pixel. The flat grazing test excludes the plane's distant edge. [Geometry, control and reads](verification.txt)

## Reproduce from the worktree root in Git Bash

```bash
T=docs/shifts/2026-11-19-night/lanes/walker/r3/terrain
for s in head r3b after; do
  python "$T/capture.py" "$s" bank && python "$T/capture.py" "$s" bluff || exit 1
  python "$T/measure.py" "$s" && python "$T/band.py" "$s" || exit 1
done
python "$T/strong.py"
python "$T/verify.py"
python "$T/comparison.py"

# Saved HEAD and reviewed 3b captures of the same 150-frame pan
bash engine/tools/look.sh boil "$T/../before/thin.mp4" 40 145
bash engine/tools/look.sh boil "$T/captures/after-thin.mp4" 40 145
CLIP_RES=1920x1080 CLIP_CRF=4 RIG_ARGS=--thin=1 bash engine/tools/look.sh clip rig:idle:0:0.83:behind "$T/captures/strong-thin.mp4" 150
bash engine/tools/look.sh boil "$T/captures/strong-thin.mp4" 40 145

bash engine/tools/selftest.sh style.walker.ink
node devx/bin/tl.mjs check --tier fast
```

The windowed checks used Godot 4.7.2, Forward+ D3D12, 1920×1080 and fixed physics ticks. Block 390 evaluates the production scalar expressions on synthetic depth profiles. Its full-strength terrain case failed on 3b with `expected 1.0 got 0.65` and `INK_CORE completed=11 failed=1`. The revised shader completed all 11 cases with zero failures. Fast tier completed 5/5 steps and 244/244 units. [Red on reviewed 3b](r3c-red.txt) · [Green on revised](r3c-green.txt) · [Fast checks](fast.txt)
