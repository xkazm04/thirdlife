# Walker R3 · silhouette ink

On the village bank, 284 of 629 walker boundary pixels carried half-strength silhouette ink before the change. The same frame now has 596. At the nearby review wall the count rose from 56 to 601 of 629. The production change uses the roughness and depth already fetched on the inner ring. A tap on a non-body surface behind a tagged body starts adding ink at 4 cm of separation and reaches full weight at 12 cm.

[Full-size crops with measured boundary pixels](comparison.jpg)

## Coverage

Godot 4.7.2, D3D12 Forward+, 1920×1080, 60 physics ticks/s, golden style. Review samples use the running pose at tick 75 and the existing behind, three and side cameras. The added vertical wall starts 0.65 m beyond the rig origin along the horizontal camera sight line. Its clearance from the actual skin varies by pixel. The village samples follow the input prefixes of `wf_feel` to tick 310 and `wf_bluff` to tick 120, with model cost, blocking pack loads and synchronous landscape edges.

Each percentage pair is **before → after**. The bins measure the difference in camera-space depth at the same pixel with the rig present and hidden. The logs include the denominator for every cell.

| View | Boundary pixels | All | Gap <0.5 m | 0.5 to <2 m | ≥2 m |
|---|---:|---:|---:|---:|---:|
| Rear, floor | 629 | 65.18 → 95.23 | 0.00 → 68.00 | 41.33 → 98.67 | 86.14 → 99.01 |
| Rear, wall | 629 | 8.90 → 95.55 | 6.88 → 90.22 | 10.48 → 99.72 | empty |
| Three-quarter, floor | 1281 | 65.57 → 91.73 | 5.66 → 55.19 | 37.89 → 100.00 | 91.84 → 98.60 |
| Three-quarter, wall | 1281 | 14.13 → 92.58 | 5.47 → 80.77 | 19.57 → 100.00 | empty |
| Side, floor | 1404 | 74.57 → 90.95 | 0.00 → 43.05 | 34.21 → 98.42 | 92.38 → 96.43 |
| Side, wall | 1403 | 14.54 → 93.51 | 9.60 → 81.42 | 17.10 → 99.78 | empty |
| Village bank | 629 | 45.15 → 94.75 | 2.59 → 75.00 | 35.90 → 99.68 | 84.08 → 98.51 |
| Village bluff | 616 | 87.82 → 93.99 | 6.45 → 32.26 | 27.59 → 100.00 | 95.50 → 97.12 |

The probe saves the production picture first. For measurement only, an in-memory copy of the production shader outputs the body tag, the thresholded outer line after thin-member suppression and fading (`0.96 * outer >= 0.5`), and the centre grazing factor. It disables grade, glow, depth of field and screen-space AA for these binary outputs. The figure mask uses body-tag pixels where hiding only the target rig changes the tag or reveals greater depth. A boundary pixel has at least one of four neighbours outside that mask. This excludes crease ink, contact shade, naturally dark clothing and other rigs. Depth is quantized to centimetres and saturates at 40.95 m, beyond the last bin boundary for these cameras. All ten front and hidden depth image pairs matched byte-for-byte across the change.

The original rule starts responding at a relative depth jump of 25% when the grazing factor is 0.1 and reaches full tap weight at 50%. At the wall, the original rule covered **0 of 251** rear boundary pixels with grazing factor ≤0.20. The tagged rule covers **250 of 251**. At the village bank the same stratum improved from **16 to 189 of 190**. The remaining gaps cluster near contact. At the bluff, ten of the 31 boundary pixels under 0.5 m now carry ink.

### Plane-prediction experiment

The alternate inner ring projects the centre plane onto each tapped texel's view ray and tests tap depth beyond that intersection. It retains the old depth edge, requires a receding tap, discards invalid ray intersections and uses the same 4–12 cm ramp. It runs only in the windowed probe.

| Sample | Original | Plane experiment | Shipped change |
|---|---:|---:|---:|
| Rear wall coverage | 8.90% | 90.94% | 95.55% |
| Village bank coverage | 45.15% | 91.41% | 94.75% |
| False contour pixels on grazing concrete | 0 / 19,600 | 4 / 19,600 | 0 / 19,600 |

The concrete control uses rows 585–654 and columns 820–1099, all at grazing factor ≤0.20. The complete before and after production PNGs of this scene are byte-identical.

## Motion and cost

Each CRF 4 clip has 150 frames. The standard boil meter compares 105 successive pairs from frames 40–145 in rows 200–419. Its grey-level flip threshold is strictly greater than 24. The runner holds the pose from tick 90 while continuing to travel at 4.5 m/s. The fixed figure mask is sampled at tick 100 for the separate subject measurement on frames 95–145.

| Region | Mean change before → after | Flips % before → after |
|---|---:|---:|
| Runner, standard horizon band | 0.727 → 0.727 | 0.081 → 0.081 |
| Runner, 638 frozen outline pixels | 3.236 → 2.846 | 0.596 → 0.348 |
| Runner, 10,311 frozen interior pixels | 0.671 → 0.592 | 0.022 → 0.013 |
| Thin-member pan from STYLE.md | 3.065 → 3.065 | 2.625 → 2.625 |
| Village bluff, standard horizon band | 2.697 → 2.697 | 1.815 → 1.816 |
| Village bluff, matched unencoded band | 1.573911 → 1.573885 | 1.604365 → 1.604347 |

The encoded bluff result rose 0.001 percentage points at the displayed precision. The separate paired run drew both shader versions during each of 106 identical physics ticks before encoding. The subject region changed on every tick. Only 2,305 of 44,774,400 horizon-band pixel observations differed between shaders. Its grey conversion uses rounded full-range RGB luminance. Compare values within each instrument.

With the shipped three-ring style, the source issues 25 depth plus 10 normal/roughness fetches per pixel. Contact shade adds nine depth fetches when active, giving **35 → 35** or **44 → 44**. This counts sampling instructions in the active paths. The new work is scalar arithmetic.

## Reproduce

Run from the worktree root in Git Bash. `capture.py before` can replay the original shader in memory from commit `c8b88fc683b057c5523c883efd07ffc84c95ae2e`. The original measurements and motion clips were taken before the production edit. The wall stills were repeated with the correct concrete colour for a primitive mesh, which gave the same coverage.

```bash
R=docs/shifts/2026-11-19-night/lanes/walker/r3
python "$R/capture.py" before
python "$R/capture.py" after
python "$R/capture.py" plane behind_wall grazing bank
for s in before after plane; do python "$R/coverage.py" "$s"; done
python "$R/details.py"

# Each clips.sh invocation captures the shader currently in the worktree.
# Use the original shader for 'before' and the revised shader for 'after'.
bash "$R/clips.sh" before
bash "$R/clips.sh" after
for s in before after; do
  for c in runner thin bluff; do bash engine/tools/look.sh boil "$R/$s/$c.mp4" 40 145; done
  python "$R/frozen.py" "$s"
done
python "$R/paired.py"
python "$R/taps.py"
node devx/bin/tl.mjs check --tier fast
bash engine/tools/selftest.sh style.walker.ink
```

The exact movie writer and encoder commands are in [clips.sh](clips.sh). Its review commands use `CLIP_RES=1920x1080 CLIP_CRF=4`, `RIG_ARGS=--freeze-at=90` for `rig:run:4.5:0:behind`, and `RIG_ARGS=--thin=1` for `rig:idle:0:0.83:behind`. The bluff movie runs the world to tick 155 with the W input held from tick 30 and retains the first 150 frames.

The headless case evaluates the production shader's scalar inner-ring assignments on supplied depth and roughness samples. On the original shader both close-wall directions returned 0 where 1 was expected. The other five samples passed. The revised shader passes all seven. The windowed captures provide the rendering evidence.
