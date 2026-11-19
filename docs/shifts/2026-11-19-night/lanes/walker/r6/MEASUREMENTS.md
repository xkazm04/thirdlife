# Bluff terrain crawl

The selected shader brings the 32-frame bluff band from **2.217% to 1.987% flips**, below the 2.010% target. Mean absolute grey change falls from 1.823 to 1.821. The bank band stays at 1.322% flips and 1.103 mean. The STYLE.md thin pan stays at 2.625% and 3.065 mean.

## Reproduction

Godot 4.7.2, D3D12 Forward+, 1920×1080, fixed 60 Hz. The starting shader is the r3c shader at `16534db`. The historical reference uses the ink and toon shaders at `c8b88fc`. All 31 lines of each fresh `measure.py` census matched the corresponding r3 record. The 32-frame bank and bluff bands, the four strong-stroke means, the flat control and the 106-frame thin pan also reproduced at the precision reported in r3c.

Each terrain band measures 669,600 adjacent pixel pairs (240×90 pixels across 31 transitions), with terrain ownership checked in every frame. The near-crest sample contains 253,180 pairs within three pixels of an independently detected land-against-land crest. A flip exceeds 24 grey levels. Crest coverage counts outer opacity ≥0.5 at the final view. The flat control counts **any** nonzero 8-bit outer opacity on the grazing plane from 8 to 80 m.

## Shader trials

Run each row with `python "$R/trial.py" NAME` from the worktree root, using the name in the first column. The coverage columns count the same 5–15% depth-gap pixels in every row.

| Name | Change from r3c | Bluff flips % | Bluff mean | Near-crest flips % | Bluff /82 | Shoulder /299 | Bank /64 |
|---|---|---:|---:|---:|---:|---:|---:|
| `head` | Historical pre-crest reference | 2.010 | 1.822 | 8.80441 | 0 | 33 | 6 |
| `baseline` | r3c | 2.217 | 1.823 | 9.54459 | 80 | 299 | 60 |
| `wide` | Inner transition ends at 0.050 (was 0.020) | 2.223 | 1.825 | 9.75235 | 68 | 252 | 60 |
| `lighter` | Scale the full inner-crest response by 0.55 (was 0.65) | 2.200 | 1.820 | 9.41860 | 80 | 298 | 60 |
| `wide_flank` | Preserve the original brush flank when its two wide taps detect a ridge | 2.006 | 1.825 | 8.78189 | 80 | 299 | 60 |
| `wide_wash` | Also give the wide ridge a 0.35 stroke of its own | 1.971 | 1.850 | 8.57453 | 80 | 299 | 60 |
| `one_tap` | Use the upper wide tap and extrapolate the inner foreground slope | 2.005 | 1.824 | 8.78110 | 80 | 299 | 60 |
| `light_flank` | Two-tap flank and 0.55 across the inner response | 1.990 | 1.822 | 8.64563 | 80 | 298 | 60 |
| **`crest_cap`** | **Two-tap flank and a 0.55 ceiling on the original inner response** | **1.987** | **1.821** | **8.62351** | **80** | **299** | **60** |

The wide brush sometimes crosses a ridge while both inner taps still see foreground. Preserving the existing soft stroke at those pixels accounts for most of the improvement. The two wide depths and their centre already belong to the same brush sample. Limiting only the peak of the added crest stroke preserves the original ramp at small gaps. Adding a separate wide stroke gave the lowest flip count but raised mean change to 1.850.

## Before and after

| Measure | r3c | Selected |
|---|---:|---:|
| Bluff band flips / 669,600 pairs | 14,844 | 13,307 |
| Near-crest flips / 253,180 pairs | 24,165 | 21,833 |
| Near-crest mean grey change | 6.2191 | 5.8489 |
| All bluff terrain pairs, flips % / mean | 0.90880 / 1.1995 | 0.86582 / 1.1889 |
| Flat grazing pixels with any nonzero outer opacity | 0 / 279,300 | 0 / 279,300 |
| Strong opacity on bank / bluff / shoulder / plane | 0.9593 / 0.9579 / 0.9596 / 0.9575 | 0.9593 / 0.9579 / 0.9596 / 0.9575 |
| Base texture reads without / with contact shade | 35 / 44 | 35 / 44 |
| Additional reads when the inner profile needs fresh texels | 5 | 5 |

The strong mask was selected by the pre-crest shader. It contains 7,463 bank, 11,638 bluff, 7,898 shoulder and 9,077 plane pixels. Every selected pixel retains opacity ≥0.9. The broader all-terrain bluff flips improved over r3c and still exceed the historical 0.80623%. The near-crest mean likewise remains above the historical 5.6499.

The production render matched the selected trial at every motion sample and in all full-frame diagnostics. Of 335 PNGs, 333 were byte-identical. The two differences were outside the motion crop in the final bluff frame, both with ink visible and with ink hidden. Compared with r3c, all 36,076 strong-pixel opacity codes and all 2,103 measured crest coverage decisions across the four gap bands matched pixel for pixel. [Production meter output](readings/after.txt) · [Pixel comparisons and exact flip counts](readings/final-check.txt) · [Thin pan before](baseline-thin.txt) · [Thin pan after](after-thin.txt)

## Regression and gates

The CPU case reads the shader's scalar assignments. With the r3c shader, the wide ridge lost its expected 0.330 brush flank and the inner crest reached 0.624 opacity. The selected shader also covers a shallow gap partway up the original ramp and clears the same wide flank on a projected plane.

```text
FAIL style.walker.ink: Godot exit 1, ink case close terrain crest expected opacity in [0.5, 0.55] got 0.624
INK_CORE completed=14 failed=2
PASS style.walker.ink  (7 body/depth cases, 4 terrain tap profiles, 1 strong silhouette and 2 brush flanks)
INK_CORE completed=14 failed=0
PASS arch             [12/12]
PASS assets           [4/4]
PASS cards            [3/3]
PASS devx.test        [226/226]
PASS foreman.typecheck
```

Fast tier completed 5/5 steps and 245/245 counted units, exit 0. An earlier red-test launch through Python resolved a different Bash and returned 127. The red results above come from the completed Git Bash run. [Red log](red.txt) · [Green log](green.txt) · [Fast gate](fast.txt)

The production edits are `engine/style/shaders/ink_post.gdshader`, `engine/style/STYLE.md`, `engine/rigs/review/walker_ink_case.gd` and `engine/tools/selftest.d/430-walker-ink.sh`.

## Commands and evidence

```bash
R=docs/shifts/2026-11-19-night/lanes/walker/r6
python "$R/trial.py" head baseline
python "$R/trial.py" wide lighter wide_flank wide_wash one_tap light_flank crest_cap
python "$R/trial.py" after
python "$R/confirm.py"

# Run once on the starting shader (s=baseline), once on the selected production shader (s=after).
s=after
CLIP_RES=1920x1080 CLIP_CRF=4 RIG_ARGS=--thin=1 \
  bash engine/tools/look.sh clip rig:idle:0:0.83:behind "$R/raw/$s-thin.mp4" 150
ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames \
  -of csv=p=0 "$R/raw/$s-thin.mp4"
bash engine/tools/look.sh boil "$R/raw/$s-thin.mp4" 40 145

TL_SELFTEST_DIR="$R/raw/green" bash engine/tools/selftest.sh style.walker.ink
node devx/bin/tl.mjs check --tier fast
```

[Trial runner](trial.py) applies shader variants to the review material in memory. [Probe wrapper](probe.py) runs the r3 `capture.py`, `band.py`, `measure.py`, `strong.py` and `verify.py` with r6 output paths, the two pinned reference revisions and the selected comparison labels. The r3 Godot sampling script, device inputs, pixel selection, meter and thresholds are shared by all trials. Each capture must finish all 32 physics ticks and print its completion line.

[Per-trial readings](readings/) contain the meter output, strong-pixel counts, continuous opacity, geometry checks and texture-read counts. Large files are local under `r6/raw/` as `captures/<name>/*.png`, `<name>-{bank,bluff}-band.mkv`, and `{baseline,wide_flank,after}-thin.mp4`. Godot completion logs are `raw/<name>-{bank,bluff}.log`.
