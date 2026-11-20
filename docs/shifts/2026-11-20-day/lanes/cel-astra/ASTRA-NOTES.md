# Cel-astra · 20 November 2026

## Round 5

### Fence casts on the road

I measured the right-hand edge of the left rail's cast on the west road. In the joined build the near edge broke into dark and lit flecks. A hard filter with radius 0.3 removed the flecks but left a regular staircase. On the joined 40° sun, the best cut in the 72-setting sweep used the highest directional PCF quality, radius 1.0 and a shorter first cascade. It gives each nearby shadow texel a smaller footprint. The cel material still cuts the filtered light at its original threshold. [Native release crops](stills/r5-fence.jpg)

The crisp sun now sets `filter_quality = 5`, `shadow_blur = 1.0` and `shadow_splits = [0.027, 0.07, 0.22]`. The split distances are 6.345, 16.45 and 51.7 m and the last cascade reaches 235 m. A rig switching styles restores its previous splits. The sun is still `#ffe4a6` at energy 1.17, elevation 40° and bearing 176°, with linear exposure 0.93. The two soles still meet their cast.

I normalized the red channel in each scanline between its local shade and lit road. The three columns below give RMS displacement of the half-light edge from a fitted quadratic, its median 10–90% width, and the number of extra dark-to-light crossings at 50%. All distances are native 1080p pixels. The near span is 120 scanlines and the middle span is 117.

| Capture and span | Joined RMS / width / extras | Shadow change alone | Delivery |
|---|---:|---:|---:|
| Shot 51, middle | 0.97 / 2.06 / 3 | 0.59 / 1.74 / 0 | **0.58 / 1.72 / 0** |
| Shot 51, near | 1.34 / 2.61 / 20 | 0.36 / 1.40 / 0 | **0.36 / 1.53 / 0** |
| Playable, middle | 1.02 / 1.68 / 3 | 0.63 / 1.74 / 0 | **0.64 / 1.72 / 0** |
| Playable, near | 1.24 / 2.62 / 19 | 0.35 / 1.45 / 0 | **0.35 / 1.53 / 0** |

I then walked 4.16 m forward in both exported builds. All 61 camera and player poses matched. Excluding rows where a post or road marking obscured the edge left 6,804 paired middle rows over 61 frames and 3,370 near rows over 58 frames. Median middle-frame RMS fell from 1.00 to 0.65 px and near-frame RMS from 0.62 to 0.36 px. In the near span the median number of extra crossings per 100 measured rows fell from 19.36 to zero. The moving-edge overlay and measurements are in `fence-walk-tracked.jpg` and `fence-walk-scores.txt`.

### Still sharpness and grass in motion

I repeated the joined tour, flight and visitor capture with the distance history enabled and disabled. In 07 the centre Laplacian variance was 2,361.7 on and 2,362.3 off. In 51 it was 758.7 and 759.0. In 24 the camera was still flying. Its centre measured 647.1 on and 795.7 off, and its middle band measured 790.3 and 957.7. The difference matters when judging these three frames together.

On the same frozen parkour view I then changed the screen-space filter alone. Centre variance was 2,438 with FXAA and history on, and 2,446 with it off. SMAA measured 3,411 and 3,426. The frozen visitor gave 756 with FXAA and 853 with SMAA in either history state. The official 07 centre value near 3,500 quoted in the brief belongs to the earlier `.tl/op-r3` set. The verified `.tl/op-r3v` value is 2,345. Using the same joined worktree for both passes avoids that ambiguity.

The native viewport uses 4× MSAA and SMAA with engine TAA off. The distant compositor uses a maximum history weight of 0.86. At a partially covered edge it samples motion from the foreground side, protects nearby paint using neighbouring depths, and tests the four previous depth samples under a reprojected silhouette. This matters because the resolved MSAA buffers average covered and uncovered samples. An 8 m rail with one-quarter coverage reported approximately 31 m and only one-quarter of its motion. At a sky boundary the adjoining blade now supplies velocity. A stationary pixel uses its current colour.

Fast camera translation needs less history even where distant objects have small screen-space velocities. The mix starts decreasing at 0.12 m of camera travel per rendered frame and reaches 45% of its usual weight at 0.65 m. This leaves the 0.015° pan and the 0.075 m walking step at full strength. Existing checks still reject camera cuts and changes of lens.

| Official 1920 × 1080 luma Laplacian variance | Centre, joined → delivery | Middle band, joined → delivery | Near band, joined → delivery |
|---|---:|---:|---:|
| 07 parkour road | 2,361.7 → **3,241.3** | 2,573.4 → **3,488.2** | 463.7 → 485.2 |
| 24 flight bluff | 647.1 → **733.9** | 790.3 → **886.2** | 17.6 → 19.1 |
| 51 visitor road | 758.7 → **752.8** | 1,168.8 → **1,546.6** | 457.2 → 309.0 |

The visitor centre stays within 1% of the joined shot. Of the lost squared edge energy in its near band, 74% comes from the leftmost 600 pixels, where the near fence crosses the frame. The near-rail fixture measured zero pixel change from temporal filtering. [Native parkour, flight and visitor crops](stills/r5-sharpness.jpg)

I also froze the playable west-road camera and village at tick 1180. For each shadow setting I compared native 4× MSAA with a 3840 × 2160, 8× MSAA reference, area-averaged to 1080p. History was disabled for every plate. In rows 800–1023, above the control legend, mean absolute luma error fell from 0.695 with joined shadows and FXAA to 0.563 with the new shadows and FXAA. Switching that last plate to SMAA gave 0.573. Across the left 600 pixels of those rows the three errors were 0.930, 0.826 and 0.837. The new shadow setting accounts for most of the improvement in this frozen comparison. See `frozen-road/` and `frozen-road-scene-scores.txt`.

On the matched flight scene, leaving the history at full strength during translation produced centre variance 522 in shot 24. With the travel adjustment it measures 734. At tick 723, the 3200 × 1800, 8× MSAA reference reduced to 1080p measures 632. Delivery has more edge energy than that reference. Across 30 consecutive flight poses, mean absolute centre image error nevertheless falls from 1.419 with joined AA to 1.323 with delivery. The middle-band error falls from 1.785 to 1.665 and the middle-band frame-change error from 2.190 to 2.114. Raw middle-band changes over 24 increase from 7.78% to 8.64%. The near-band frame-change error rises from 0.360 to 0.408. `flight-series-scores.txt` contains all three crops.

The sweep uses 27 poses at 0.015° intervals. It compares the native output to a 3840 × 2160, 8× MSAA plate reduced with Lanczos. A second reference with the village tuft mesh hidden identifies its pixels. The fine mask takes connected components of at least two pixels with a bounding box no larger than 16 × 16 px in x750–1189, y300–389. Each comparison uses the union of the two consecutive masks. [Native grass crops and supersampled reference](stills/r5-grass.jpg)

| Fine grass during the pan | Pixels sampled per transition | Image MAE, joined AA → Round 5 | Frame-change MAE, joined AA → Round 5 | Changes over 24 luma levels |
|---|---:|---:|---:|---:|
| Village road | 1,117 | 12.76 → 12.21 | 11.07 → 8.89 | 8.82% → 4.06% |
| Same geometry isolated against sky | 673 | 21.48 → 20.25 | 23.99 → 17.00 | 26.18% → 9.45% |

MAE is mean absolute error against the supersampled reference, in display luma levels. The isolated plate is a stress test. The normal village measurement includes its terrain, trees and rails. Large changes still occur on the thinnest blades. The local `.tl/astra-r5/grass-pan-compare.mp4` plays both sequences at 15 fps for inspection.

The reference itself changes by more than 24 levels on 10.09% of fine village samples and 24.02% of isolated samples. A lower flip count can therefore include suppressed real movement. I compared image error and frame-change error as well. At 4× MSAA, raising the history weight from 0.86 to 0.92 brought the skyline frame-change error from 17.00 to 16.87 but worsened image error from 20.25 to 21.88. With 8× MSAA at weight 0.86 the fine village errors improved slightly (image 11.86, frame change 8.81), while the skyline errors rose to 21.26 and 17.20. I kept 4× and 0.86. The four sampling trials are in `tune-grass-*-fine.txt`.

I also drove the exported game through a 61-frame walk and a 61-frame pan. Camera and player poses, stage and field of view matched the two native builds and the 3200 × 1800, 8× MSAA reference at every logged frame. The table gives mean absolute error in the *change* between consecutive frames for fixed screen regions. The distant-tuft window improves in both routes. Walking also improves the fence region, while a slow pan increases the fence error from 2.243 to 2.400. The regional measurements are in `ready-ref-walk.log` and `ready-ref-pan.log`.

| Playable route | Distant tufts | Fence | Middle band | Near band |
|---|---:|---:|---:|---:|
| Walk, joined AA → delivery | 2.898 → 2.723 | 2.690 → 2.591 | 1.908 → 1.877 | 1.017 → 0.972 |
| Pan, joined AA → delivery | 1.144 → 1.077 | 2.243 → 2.400 | 1.316 → 1.327 | 0.437 → 0.465 |

I repeated cel-fable's `crawl.sh` on the joined and delivery trees. In its 106-frame rig review, the thin-member horizon band fell from 2.702 to 2.321 mean luma change, with flips over 24 falling from 1.706% to 1.131%. The kit-floor flips rose from 0.062% to 0.075%. In its 291-frame village sequence the far band's mean change fell from 1.030 to 0.815, while large changes rose from 0.692% to 0.819%. Near-ground flips measured 0.156% and 0.155%. This broad far band contains the scaffold, trees and terrain as well as grass. Logs and clips are in `surface-joined/` and `surface-delivery/`.

### Sky beside board 2

The western clouds have broader domes, uneven shoulders, a flat underside with a narrow violet line and slanting lavender facets. The banks pick up peach from the painted sun. The local cloud families vary the larger shoulder, the length of the shelf and the second fold. The open sky blends peach through rose into violet. [Joined frame and delivery beside board 2](stills/r5-sky.jpg)

The authored sky pigments are `horizon #ffbd84`, `mid #e177a7`, `upper #9a82ce`, `cloud #ffda9f` and `cloud_shade #dfa5c3`. I sampled 20 clear board rows from y=10 to 200 and the corresponding normalized rows in two columns of the game's clear-sky plate. Combined RGB RMS error fell from 8.76 to 3.29 levels. At board rows 10, 70, 130 and 190 the RGB medians were (176,117,199), (204,127,182), (233,146,157) and (252,171,138). The delivery column at x=1388 measured (179,117,198), (209,131,177), (231,148,158) and (249,171,137).

The upper 32% of the west-road image contains seven connected cream regions larger than 0.09% of the frame, up from four in the joined image. Board 2 has seven at the same threshold. Above the right-hand bluff, the main cream region occupies 15.0% of frame width, against 13.4% on the board. Its median RGB is (253,213,150), against (253,214,155). The small central cloud now has clear sky above the mesa. The near tree still obscures more of the left bank than in the board composition.

### Verification and handoff

The final fast gate passed all five steps, including 12 architecture checks and 229 devx tests. With `TL_STYLE=crisp`, the lane's `check --tier full --only world,packs,kit.selftest` passed world 8/8, packs 48/48 and kit selftests 95/95. Neither gate needed a retry. The previously blocked pixel test ran to completion. Its line included `PASS style.frame.pixels (west_p99=1 nearby=1 cloud_samples=2176 ... flight_delta=0 ...)`.

| Selftest filter | Final summary |
|---|---|
| `rig.` | `selftest: 14 passed, 0 failed` |
| `moves.` | `selftest: 14 passed, 0 failed` |
| `flight.` | `selftest: 13 passed, 0 failed` |
| `wings` | `selftest: 2 passed, 0 failed` |
| `character.` | `selftest: 2 passed, 0 failed` |
| `style.` | `selftest: 10 passed, 0 failed` |
| `cel.` | `selftest: 4 passed, 0 failed` |

The cel frame fixture reported `CEL_SHADOW splits=(0.027, 0.07, 0.22) restored=(0.1, 0.2, 0.5)`, `CEL_MOTION near_delta=0 rest_delta=0 distant_step_rms=29.7056457702067 -> 10.9912251933076`, and `CEL_CONTOURS both_edges_px=[6, 4, 2] gap_delta=0`. On the sky, `west_p99=0 neighbour=10 cream=3796 lavender=1989`. The material guard gave `protected_delta=0`. The exported-AA fixture now expects `crisp=msaa=4,ss=smaa,taa=0` to follow the selected viewport filter. The wardrobe test passed for 12 wardrobes, 8,420–9,988 triangles, 29 bones and 20 clips. Full test lines are in `ready-test-*.log`.

I also started an unfiltered `check --tier full`. Its repository-wide kernel selftest reached the runner's 30-minute limit at 18:30:58 without completing. I stopped this additional run after it advanced to packs to release the machine for operator verification. It has no overall verdict. The completed lane run and the additional run have separate logs, `ready-full.log` and `ready-full-unfiltered.log`.

All 48 pack reports agree with the round-1 archive on result and frame count, including all 46 state hashes. I also ran all eight world games from a pristine archive of integration commit `5e4b5c8` under each style. All eight hashes, frame counts and world-versus-alone verdicts match delivery under the **same** style. Classic also matches the eight archived round-1 rows. The kit example already has a style-dependent hash at frame 332. Joined crisp and delivery crisp both give `326a337efb7371a2`. Joined classic, delivery classic and the round-1 archive give `ca698e71d34d1021`. The kit bot includes the visible stride in its state. Its reported leg swing is 0.5626 in crisp and 0.8838 in classic. The other numeric bot results agree. This corrects Round 4's description of that cross-style comparison. See `ready-hashes.log`.

The release tour on the RTX 4090 measured 1.488 ms GPU in crisp and 1.225 ms in classic (1.21×). The median frame times were 2.715 and 2.734 ms, with 346 and 371 draw calls. Both `tour6 --no-record` runs passed. The machine was busy during both, so these timings are local observations.

To isolate the frame changes I froze the playable west road at tick 1180, disabled VSync and panned the same view through five configurations in three orders. Each configuration had 30 warmup frames and 120 timed frames per order. The median of the three GPU medians was 1.348 ms for the joined frame, 1.372 with the new cascades and shadow filter, 1.375 with the new sky, 1.401 with SMAA and 1.400 with the delivery history. The total increase was 0.052 ms. The three SMAA and delivery timing ranges overlap. A separate sampling comparison measured 1.402 ms at 4× MSAA and 1.574 at 8×. The two 1080p RGBA16F history images use 31.6 MiB per view. The raw samples are in `frozen-gpu-uncapped/console.log` and `sampling-gpu-uncapped/console.log`.

I inspected all 27 native captures in each style. All 18 reproducible classic views match the round-1 pixels exactly. In the other nine, 0.0067%–0.9063% of pixels differed by more than one RGB level. The earlier classic repeat comparison reached 2.3685% in this group. The contact sheet pairs 11 views, including both figure poses, both games and the road. The road-to-flight movie contains 1,401 frames at 1920 × 1080 and 60 fps (23.35 seconds). Its frame count and duration match the source recording. [Board and paired views](contact-sheet.jpg) · [Road walk and flight](clip.mp4)

In the frontal portrait, five 9 × 9 pixel samples on the chest, sleeve, cheek, trousers and boot stayed within two RGB levels of the operator's Round 4 crisp capture. The chest at (912,611) measured (200,33,30) and the sleeve at (1064,603) measured (181,27,27). Both jacket bands remain red. [Front portrait](stills/42_figure_front_crisp.jpg)

### Files and reproduction

The rendered look comes from `engine/style/style_crisp.json`, `engine/style/cel/style_cel.gd`, `engine/style/cel/distant_aa.gd`, `engine/style/shaders/distant_aa.glsl` and `engine/style/shaders/sky_cel.gdshader`. Regression coverage is in `frame_case.gd`, `distant_aa_case.gd` and the 601/603 cel selftest blocks. The figure and game cameras use the joined integration's rigs and settings. The filter costs no authoring work per new game.

Raw captures, test logs and the Windows release are under `.tl/astra-r5/`. Run `ready/Play-crisp.cmd` to open the measured release with the crisp profile. The PCK SHA-256 is `4477103f69049c64bf8ae1808b801eddf52432b6dd0a23bc160a011c172bab49`.

From the worktree root in PowerShell, these commands remeasure the stored native captures.

```powershell
$lane = 'docs/shifts/2026-11-20-day/lanes/cel-astra'
$r = '.tl/astra-r5'
python "$lane/measure.py" fence "$r/joined-crisp/51_road_visitor.png" "$r/ready-crisp/51_road_visitor.png" "$r/before-west/crisp-board/still.png" "$r/ready-west/crisp-board/still.png"
python "$lane/measure.py" sharp "$r/joined-crisp" "$r/ready-crisp"
python "$lane/measure.py" grass "$r/ready-grass-village" --fine r4 delivery
python "$lane/measure.py" grass "$r/ready-grass-sky" --fine r4 delivery
python "$lane/exe-motion.py" "$r/ready-control-motion/crisp-pan" "$r/ready-motion/crisp-pan"
```

The grass harness boots the village, freezes tick 190 and renders 27 recorded camera angles. An independent skyline rerun reproduced all three delivery measurements to three decimal places. The control project uses the delivery sky and shadow setup with the joined `distant_aa.gd`, `distant_aa.glsl` and joined `env.line_aa`, `env.exe_aa` and `env.distant_aa` values. These commands recreate the skyline comparison in a fresh directory. Omit `--skyline` for the actual road.

```powershell
$out = "$r/recheck-grass-sky"
node "$lane/grass-sweep.mjs" "$r/ready-control-source/engine" $out r4 --skyline
node "$lane/grass-sweep.mjs" engine $out delivery --skyline
node "$lane/grass-sweep.mjs" engine $out --reference --skyline
python "$lane/measure.py" grass $out --fine r4 delivery
```

## Round 4

The visitor’s tree cast now has the blue lift visible in board 2. A thin rail cast shows the same response. The second change steadies distant contours during walking and panning. I kept the camera settings after measuring the visitor at 37% of frame height in the exported game’s village camera. [Cast shadows beside the board](stills/r4-shadow.jpg) · [Matched footage of the fence and visitor](stills/r4-contours.mp4)

### Grass and road shadows

`grade.olive_fill = 0.88` reduces red and green in dark olive paint and fills its blue deficit. It operates on rendered colour, so dark leaves of the same hue also qualify. The sun uses `#ffe4a6` at 1.17, elevation 40°, azimuth 176°. Linear exposure is 0.93 and `grade.plum_density` is 0.88.

| Native 1080p patch | Round 3 RGB | Round 4 RGB | Board 2 reference |
|---|---|---|---|
| 51, tree cast on grass (780,545) | 90,123,11 | **81,107,36** | 80,106,35 and 77,103,35 |
| 51, lit grass (300,600) | 184,186,27 | 184,186,27 | 191,174,22 and 198,178,19 |
| 07, slender fence cast (660,886) | 95,126,9 | **86,108,36** | 80,106,35 |
| 07, adjacent lit grass (662,866) | 192,191,25 | 192,191,25 | 191,174,22 |
| 51, boot cast on road (1300,1010) | 117,73,71 | 117,73,71 | 124,79,74 |
| 51, lit road (700,1000) | 241,148,70 | 241,148,70 | 247,149,69 |

Shot 51 uses 7 × 7 medians. The operator’s other two tree boxes at (700,580) and (600,425) give (76,101,35) and (83,107,36). Both cross a cast edge. The interior at (780,545) has zero channel standard deviation. Shot 07 uses 5 × 5 medians. Its slender cast keeps 45% of the red and 57% of the green in the adjacent grass. Blue rises from 25 to 36. On the board it rises from 22 to 35. The lighter paint inside the tree area at (640,560) stays (165,173,26). The broad tree crown and the expanse of sunlit grass still dominate shot 51. Surface and layout measurements are in the [handoff to cel-fable](PATCHES.md).

### Which camera the owner sees

The village uses the visitor’s `TLChaseCam`, with a 60° FOV. Its 8.5 m authored ground arm is scaled by 0.51 and the crisp ground lift is 0.63 m. The west-facing board pose has a 4.335 m horizontal arm. On the normal boot path I froze the scene and compared a visible figure to the same rig in shadows-only mode, then repeated the visible capture. This keeps the cast in both plates. At 1920 × 1080 the visible figure spans 397 px at spawn (36.8%), 408 px walking east at tick 160 (37.8%) and 400 px looking west at tick 1180 (37.0%). The operator measured 36.6% in fixed shot 51 and about 37% on the board.

Parkour enters its own `TLOrbitCam`, with a 5.5 m arm and a 55° base FOV. Its skyline preset can widen to 59°. The blue runner in the HUD-on official frame 520 spans rows 376–717 inclusive, 342 px or 31.7%. That difference is specific to the game view. The village framing already matches the board. [Four views with figure-height measurements](stills/r4-framing.jpg)

### Distant contours in motion

Crisp now uses `env.distant_aa = 0.76` with native 4× MSAA and FXAA. A 3D compositor effect reprojects the previous frame using surface motion vectors. The mix rises from zero at 8 m to full strength at 24 m. A five-tap cubic sample and a clamp to the current pixel and its four neighbours preserve thin edges. Depth disagreement, fast motion and camera cuts reject history. The sky and foreground bypass the mix, and the HUD draws afterward. Explicit `TL_EXE_AA` profiles take precedence. Each active native 1080p view uses two RGBA16F images, about 31.6 MiB per eye. Content authors have no per-game setup.

The two profiles below ran on the **same Windows release** at 1920 × 1080 on D3D12. Both used 4× MSAA, FXAA and engine TAA off. Each route has 61 consecutive poses at ticks 100–160, with matching player, stage, camera, look direction and FOV. The pan advances 0.015° per tick and the walker covers 4.5 m. Each entry gives the percentage of pixels changing by more than 24 luma levels across 60 transitions. The fence crop is x1080–1449, y310–469.

| Route and profile | Mid, rows 300–619 | Fence | Near, rows 700–1039 | Figure crop |
|---|---:|---:|---:|---:|
| Pan, history off | 1.315% | 2.597% | 0.232% | 0.492% |
| Pan, delivery | **0.912%** | **1.864%** | 0.229% | 0.491% |
| Walk, history off | 3.238% | 3.583% | 2.502% | 7.230% |
| Walk, delivery | **2.838%** | **2.578%** | 2.502% | 7.228% |

The fence loses 28% of its large transitions on both routes. The tradeoff is visible in mid-distance spatial detail. Pan Laplacian variance goes from 874 to 734 there and from 701 to 699 near the camera. Walking values go from 901 to 751 and from 606 to 605. The figure crop retains its edge energy on both routes. Fine grass against the horizon still flickers during movement. [Side-by-side pan and walk](stills/r4-contours.mp4)

For a reference that includes real motion, I rendered both routes on the same release at 3200 × 1800, with 8× MSAA, and area-downsampled to 1080p. All 61 logged poses agree. Against this reference, mean absolute mid-band image error falls from 2.201 to 1.991 luma levels in the pan and from 2.250 to 2.176 in the walk. Mean absolute error in the **change between frames** falls from 1.437 to 1.199 in the pan and from 1.816 to 1.624 walking. The lower flip rate comes with closer agreement to the higher-resolution motion. Per-crop results are in `shipping-ref-pan.txt` and `shipping-ref-walk.txt`.

On the busy RTX 4090, the windowed six-game tour reported 1.245 ms GPU for delivery crisp (410 draw calls, frame p50 2.543 ms). The round’s opening classic control measured 1.236 ms (276 calls, frame p50 2.795 ms). Both used `perf run --scenario tour6 --no-record`. A frozen 1080p road trial isolated the passes on the same scene. With 30 warm-up draws and 100 measured draws per block, the median of three block medians was 1.242 ms with both new effects off, 1.241 ms with the grade and 1.313 ms with grade and history. The measured history increment was 0.072 ms. That trial preceded the teardown repair, which caches the effect’s object ID for cleanup. GPU data are in `road_timing2/run.log`.

Two later classic tour requests timed out waiting for the shared test window. The 1.236 ms figure is from the completed opening control in `perf-classic.log`.

### Verification

`check --tier fast` passed all five gates, including 12/12 architecture rules and 229/229 devx tests. `check --tier full --only world,packs,kit.selftest` passed twice. The final run completed kit 95/95, packs 48/48 and world 8/8, with zero retries. All 48 pack reports match the reference in outcome and frame count, including all 46 state hashes. All eight world hashes, counts and results match the round-1 base. Logs are `shipping-fast.log`, `shipping-full.log` and `shipping-hashes.txt`.

I repeated the game gates with `TL_STYLE=crisp` explicitly set. Packs again completed 48/48 and world 8/8, with zero retries. All 46 pack hashes and eight world rows match the base. See `crisp-game-gates.log` and `crisp-game-hashes.txt`.

The frame fixture reported `CEL_FILL olive=55670d->506220 protected_delta=0`, `CEL_MOTION near_delta=0 distant_step_rms=27.2400928 -> 20.9473391` and `CEL_CONTOURS both_edges_px=[6, 4, 2] gap_delta=0`. The motion test sweeps equally wide rail cards at 8, 65 and 180 m through subpixel rotations. The nearest card is identical in both passes.

Both styles produced all 27 native stills. Against `.tl/r0/classic`, the 18 reproducible classic frames are pixel-identical. In the nine historically variable frames, 0.0102%–0.9482% of pixels differed by more than 1/255. Fixed visitor shot 51 retains the round-3 spatial detail. Its centre-crop luma Laplacian variance goes from 521.8 to 531.1 and its near crop from 121.1 to 122.5. Raw tables are `shipping-classic-diff.txt`, `final-sharp.txt` and `r3r4-sharp.txt`. [Board and 11 classic/crisp pairs](contact-sheet.jpg)

The continuous take follows the road to the bridge, then flies over the bluff. It contains 1,401 frames at 1920 × 1080 and 60 fps, lasting 23.35 s. [Road-to-flight clip](clip.mp4)

| Selftest filter | Final selftest line |
|---|---|
| `rig.` | `selftest: 14 passed, 0 failed` |
| `moves.` | `selftest: 14 passed, 0 failed` |
| `wings` | `selftest: 2 passed, 0 failed` |
| `flight.` | `selftest: 13 passed, 0 failed` |
| `character.` | `selftest: 1 passed, 1 failed` |

On the shipping source, `flight.replay` returned the same position on tick 240 with a difference of 0.000 m. `flight.dust` observed both puffs at the feet and freed them on time. Both exercise world teardown.

Across the individually exercised cases, `style.` has nine passes and one failure, and `cel.` has two passes and two failures. The case-by-case log mapping is in `constituent-verdicts.txt`. At the 16:05 handoff the whole-filter repeat was waiting on the shared window. Its log destinations are `verified-style.log` and `verified-cel.log`.

The two outstanding clean-load assertions share the partner-owned `toon.shade_k = 0.90` setting. The release logs the clamp to 0.85. The wardrobe fixture reports `wardrobes=12 tris=8420..9988 bones=29 clips=20 height=2.0 radius=0.3 grip_m=0.00000/0.00000 errors=["crisp load"]`. The boot fixture reports `CEL_EXE_AA ok=false fallback=msaa=2,taa=1 crisp=msaa=4,ss=fxaa,taa=0 override=ss=off,msaa=8`. The observed AA selections agree with all three expected profiles. Cel-fable has the authored-value correction in [PATCHES.md](PATCHES.md).

### Reproduction

The style keys live in `engine/style/style_crisp.json`. `tl_style.gd` registers their ranges and `cel/style_cel.gd` installs the grade and compositor. The new runtime files are `engine/style/cel/distant_aa.gd` and `engine/style/shaders/distant_aa.glsl`. The colour correction lives in `engine/style/shaders/grade.gdshader`. The frame fixture calls `engine/style/cel/distant_aa_case.gd` for the rail sweep.

Raw captures and logs are under `.tl/astra-r4/`. The release is `shipping/ThirdLife.exe`, with PCK SHA-256 `9b21ccc67c2d6ebe0380da620add18651c8ad895951c74a59065f728d66e8f26`. From the worktree root in PowerShell, the following records both profiles and samples the principal cast.

```powershell
$lane = 'docs/shifts/2026-11-20-day/lanes/cel-astra'
$round = '.tl/astra-r4'
node "$lane/exe-motion.mjs" "$round/shipping/ThirdLife.exe" "$round/recheck-motion" crisp fxaa
python "$lane/exe-motion.py" "$round/recheck-motion/fxaa-pan" "$round/recheck-motion/crisp-pan"
python "$lane/exe-motion.py" "$round/recheck-motion/fxaa-walk" "$round/recheck-motion/crisp-walk"
python "$lane/measure.py" rgb "$round/final-crisp/51_road_visitor.png" 3 780,545 300,600 1300,1010 700,1000
```

## Round 3

Crisp now ships 4× MSAA with FXAA and TAA off. The eastward walk exposes two different problems. Distant rails and grass flicker as they cross pixels. A broad, regular stripe pattern on the road shoulder was directional shadow acne. Changing the screen-space AA helped the first. Changing the light removed the repeated pattern on the road. [Matched release footage](stills/r3-exe-motion.mp4) · [Native road evidence](stills/r3-road-shadow.jpg)

### Motion through the exported game

The same Windows release opened its regular village, rendered at 1920 × 1080 on D3D12 and advanced at 60 fixed physics ticks per in-game second. Each profile recorded 61 consecutive RGB8 frames, ticks 100–160. The walker moved 4.50 m. In the second route the stationary visitor panned 0.015° per tick. The recorded camera, direction, player, FOV and stage match at every logged tick in each comparison. Output values are mean absolute Rec.709 luma change in 8-bit levels, percentage changing by more than 24 levels, and spatial luma Laplacian variance. Each averages 60 transitions. The mid band covers rows 300–619 and the near band 700–1039. Real silhouette motion contributes to the change metric. Watch the thin flags, rails and grass in the slow pan.

| Release viewport | Walk mid | Walk near | Pan mid | Pan near |
|---|---:|---:|---:|---:|
| Literal old override, inherited FXAA | 2.291 / 2.358% / 299.5 | 1.789 / 2.162% / 496.2 | 0.761 / 0.325% / 299.5 | 0.177 / 0.139% / 549.0 |
| Historical 2x MSAA, SMAA, TAA | 2.390 / 2.490% / 352.2 | 1.811 / 2.189% / 497.5 | 0.823 / 0.450% / 379.0 | 0.195 / 0.163% / 554.0 |
| Previous crisp 4x MSAA, SMAA | 3.001 / 3.619% / 1234.9 | 1.986 / 2.391% / 616.0 | 1.359 / 1.698% / 1176.8 | 0.252 / 0.300% / 700.4 |
| Delivery 4x MSAA, FXAA | 2.765 / 3.181% / 891.3 | 1.901 / 2.323% / 603.1 | 1.186 / 1.309% / 866.8 | 0.226 / 0.231% / 698.4 |

The literal old override only sets MSAA and TAA. On the new style it inherits FXAA. The historical viewport also used SMAA, so the second control pins that explicitly. The clip compares the historical viewport, the previous crisp viewport and the new default on the same delivery binary. It repeats each 1-second route at real time, then shows the same frames at half speed.

Against prior crisp, large mid-band changes fall 12.1% on the walk and 22.9% on the pan. Historical TAA is calmer on the pan at 0.450% flips. FXAA retains 2.53× the historical walking edge energy and 2.29× in the pan. Thin rails and trees keep a readable edge. A slow sweep still reveals flicker in subpixel detail.

On the earlier joined build, moving from 4× to 8× with FXAA moved the pan’s mid-band flips from 1.360% to 1.274%. I kept 4×. In a separate trial, an area-downsampled 3200 × 1800, 8× MSAA release capture gave a reference for true movement. The mid-band walk’s mean temporal residual was 2.019 for historical TAA, 1.944 for prior crisp and 1.825 for FXAA. In the pan it was 1.166, 1.533 and 1.446 respectively. A further spatial filter tested on raw FXAA footage reduced pan flips by about 0.05 percentage points while losing 14% of the edge energy. The shipped grade keeps its existing five-tap sharpen.

### Board 2, the joined picture and the release

The six board medians are the Director’s supplied samples. Both game columns use the Director’s exact boxes in the 1920 × 1080 visitor-road shot, including the old shadow coordinates.

| Native patch | Board 2 | Joined crisp | Delivery crisp |
|---|---|---|---|
| Lit road | 249,150,68 | 241,149,70 | 241,148,70 |
| Road in tree cast | 112,69,77 | 119,74,72 | 118,73,72 |
| Lit grass | 200,182,22 | 182,185,27 | 182,185,27 |
| Original grass-shadow coordinates | 80,104,35 | 90,121,11 | 184,186,27 |
| Upper sky | 178,117,199 | 185,112,199 | 179,116,199 |
| Sky above far hills | 253,177,138 | 254,178,137 | 254,178,137 |

The new key moves the tree cast off the original grass box. On its interior at x745–784, y566–580 the grass is (90,123,11). Part of the original road box now includes the edge. Inside the road cast at x1110–1159, y612–635 the channel standard deviations are (0.64,0.50,0.85). The lit-road values are (0.48,0.42,0.45). The biggest colour gap in these ground samples is the 24 levels of missing blue in shaded grass.

[Board, joined and delivery visitor](stills/r3-board.jpg) · [All fixed cameras](contact-sheet.jpg) · [Continuous road-to-flight take](clip.mp4)

The joined release exposed a separate diagonal pattern on the sloped road shoulder in the eastward walk. At tick 160, a 160-pixel horizontal scan at x450–609/y875 had 35 adjacent luma changes over 24 levels. The 365 × 265 shoulder crop at x325–689/y740–1004 had 10,390 of 96,360 such vertical pairs. Switching AA alone left 5,888 pairs. With the delivery light and the previous crisp AA, 299 remained. With the delivery AA, **259 pairs remained (0.269%)**, including ordinary pebble and paint boundaries. The delivery scanline had two transitions. In a separate frozen control, removing directional casting reduced 10,425 crop transitions to 335. Ordinary depth-bias changes had little effect. Geometric normal bias and sun pitch removed the repeated diagonals. The comparison still shows the cast attached to the boot.

The west-facing playable release stops 0.06 m from the official visitor position. The near vegetation differs between the two captures. The HUD also crosses the Director’s original near-road box. Three interior samples from native tick 1180 measure the actual paint. Lit road at x680–779/y990–1019 is (241,148,70), channel SD (0.36,0.49,0.50). The boot cast at x1120–1179/y981–997 is (118,73,72), SD (0,0,0). The thin tree cast at x930–948/y469–472 is (118,74,73), SD (0.41,0.39,0.00). Both west-road casts are flat in the playable window and the walking shoulder has lost its false hatch.

The soft-edged patch under the big tree in shot 51 survived independent removal of ink, AO, directional casts, local lights, scatter, ground marks and the terrain patch control. A single grass pigment in a private terrain-shader control made the patch and its neighbour the same RGB. At (645,590) and (745,590) the original values were (165,173,26) and (186,188,27). In the one-paint control both were (186,188,27). A separate frozen-road control with plum density zero turned the road cast from (119,74,72) to (128,103,60). I kept the 0.88 plum separation. Ink AO is zero to keep the hand and leather paint clean. Fog sun scatter is zero. The yellow glow is local to the painted sky. [Surface measurements for cel-fable](PATCHES.md)

### Figure and light

At board scale the boot gap on row 643 is 20 pixels in the painting, 5.3 in the joined frame and 18.7 in the delivery. The rightmost and lowest pixels of the connected cast to the right of the boot are (963,711) on the board. The joined cast crosses both frame edges. The delivery cast bounds end at native (1512,1065), or (1008,710) at board scale. A frozen study of twelve pitch/bearing combinations kept ordinary road and grass swatches stable while moving the shadow tip. A 29° key still extended to x1145 at board scale. At 40° the right edge is 45 pixels to the right of the target and the bottom edge is one pixel above it. Within the rightmost three native columns, the median tip height is y682 on the delivery and y702 on the board, both at board scale. The painted tip is about 20 pixels lower.

| Figure median | Board 2 | Joined | Delivery |
|---|---|---|---|
| Coat | 199,26,29 | 180,30,32 | 200,33,30 |
| Hair | 115,46,16 | 122,39,28 | 116,47,14 |
| Jeans | 46,52,118 | 47,32,125 | 41,43,120 |
| Boot | 113,48,16 | 99,35,46 | 110,47,14 |

The board coat, hair, jeans and boot rectangles begin at (610,514), (605,440), (602,582) and (594,641) and end, exclusively, at (655,553), (664,472), (623,619) and (624,655). The equivalent native game crops are x918–1003/y765–833, x915–1007/y664–707, x919–946/y867–912 and x905–939/y949–973. The jeans crop includes the stance change.

The graduated sky’s upper pigment is `#a479ca`. The aureole uses `#ffeb69`, the disc radius is 0.026 radians and its yaw offset is 52.5°. Its draw elevation stays 9.8°. Linear tonemapping and exposure 0.93 retain the palette fit to the `#ffe4a6` key at energy 1.17. The directional light uses elevation 40°, azimuth 176°, normal bias 2.8 and depth bias 0.043. The fixed overhead sports camera selects its existing 39° lighting. The runtime frame fixture found 168 exposed pale-disc samples, 3,416 cream and 1,497 lavender cloud samples. At 8, 65 and 180 m the ink remained 3, 2 and 1 pixels per rail edge. The gap between the rails changed by zero levels.

The crown now steps down from one broad amber lock into a smooth umber nape. The cuffs sit above open hands with visible thumbs. The cut of the jacket has a dark hem and a shoulder seam. Boot and hair have two paint faces. Cloth keeps three red levels. The six fixture swatches were `#b51b1b`, `#b61b1b`, `#ca211e`, `#ca211e`, `#ea3b22`, `#e83a22`. A standing cel ankle sits 0.168 m from the centre. The shared gait default is 0.115 m and the forward running track still converges to 0.09 m. Across 12 wardrobes the rig measured 8,420–9,988 triangles, 29 bones, 20 clips, height 2.0 m, radius 0.3 m and bar/stick grip error 0.00000/0.00000 m.

### Gates, cost and reproduction

Fast passed 5/5, including arch 12/12 and devx 229/229. Selected full passed all three steps with zero retries. The last lines were `PASS kit.selftest [95/95]`, `PASS packs ... verb runs 48 of 48` and `PASS world [8/8]`. All 48 pack statuses and frame counts, 46 state hashes and eight world hash/count rows match the baseline.

| Selftest filter | Run | Passed | Failed | Affected case |
|---|---:|---:|---:|---|
| style. | 10 | 9 | 1 | style.cel.exe_aa |
| rig. | 14 | 14 | 0 | Complete |
| cel. | 4 | 2 | 2 | character.cel.wardrobe, style.cel.exe_aa |
| moves. | 14 | 14 | 0 | Complete |
| flight. | 13 | 13 | 0 | Complete |
| wings | 2 | 2 | 0 | Complete |
| character. | 2 | 1 | 1 | character.cel.wardrobe |

The joined tree authors `toon.shade_k = 0.90`. The shared validator renders it at 0.85 and reports a clamp. The same two clean-load assertions appear under multiple filters. In a private engine copy with only the authoring correction, both original fixtures returned `PASS character.cel.wardrobe` and `PASS style.cel.exe_aa`. The latter verified the classic fallback, crisp profile, environment override and invalid requests. Cel-fable owns the edit. An earlier style pixel test timed out waiting for the shared window lock. Its final run passed. An initial SMAA pan produced empty frame and log files. The repeat supplied all 61 ticks and matched the other profiles. Only complete runs enter the comparisons.

The full shot sets contain 27 native images each. All **18 reproducible classic shots match `.tl/r0/classic` exactly**, maximum channel error 0/255. The other nine historically variable shots had 0.0079–2.8769% of pixels differing by more than 1/255. Flight climb was largest at 2.8769%, above the recorded base-to-base 2.3685%. An independent second delivery flight gave 2.3043% against the base and 0.6025% against the first delivery climb. Both flights reproduced the three deterministic flight stills exactly. The capture directories are `delivery-classic` and `delivery-crisp`. The classic set uses the 21 standard nonflight shots and all six shots from one separately locked repeat of the standard flight.

Across the 27 pairs, the centre-crop spatial variance is 0.763–1.760× classic and falls below classic in four views. The near band falls below classic in 18. Shot 10’s near field is 63.0 → 5.2 and shot 13’s centre is 391.6 → 298.6. Flat paint, removed hatching and the spatial AA all affect this metric. The visitor road rises from 403.1 to 521.8 in the centre (1.29×) and from 22.4 to 121.1 near the feet (5.41×). All individual crop and pixel-difference results are in `delivery-sharp.txt` and `delivery-classic-diff.txt`.

The two deliberate test expectation changes are the normal-camera sun restoration angle in `engine/style/cel/frame_case.gd` and the release AA string in `engine/tools/selftest.d/603-cel-exe-aa.sh`. The tests still check the overhead camera, fallback, environment override, invalid requests, native scale, colour bands, sun-disc bounds and ink separation.

Production edits are in `engine/style/style_crisp.json`, `engine/style/shaders/{sky_cel,body_cel}.gdshader`, and `engine/rigs/biped/{cel_biped,cel_rig,clay_form,tl_rig_biped_gait}.gd`. The two fixtures above reflect the art changes. Per-game authoring cost is zero. The sky reuses its existing material, the figure uses its existing hull pass and disabling contact shade skips its neighbourhood samples. The API, pack data, seeds and partner’s surface implementation keep their original interfaces.

On the shared RTX 4090, the windowed six-game tour measured 1.140 ms GPU for crisp and 1.332 ms for classic (0.86×). Both runs used the same scenario, size and driver under shared-machine load. The raw timing records are `delivery-perf-crisp.log` and `delivery-perf-classic.log`. An earlier classic benchmark timed out waiting for the window lock. In a frozen visitor-road timing experiment the identical shipping setup ranged from 1.255 to 2.722 ms across three controls. That spread limits attribution of a per-pass GPU cost. The 0.13 contact-shade sample measured 3.151 ms between shipping controls of 2.722 and 2.554 ms.

Run the following from the worktree. The measured release package is `delivery/ThirdLife.pck`, SHA-256 `b58d1075c0b2006a10e35a66c5ae840a29e1c1fe2e938cd01afbaf3af59ab4a4`. Use new capture directory names for each replay. The board capture uses normal movement from spawn. The raw sequences, release, gates, per-shot differences and scripts for the frozen controls are under `.tl/astra-r3/`.

```powershell
$lane = 'docs/shifts/2026-11-20-day/lanes/cel-astra'
$r = '.tl/astra-r3'
node "$lane/exe-motion.mjs" "$r/delivery/ThirdLife.exe" "$r/replay" old old-smaa smaa crisp
node "$lane/exe-motion.mjs" "$r/delivery/ThirdLife.exe" "$r/replay-board" --board crisp
foreach ($route in 'walk','pan') {
    python "$lane/exe-motion.py" "$r/replay/old-$route" "$r/replay/old-smaa-$route" "$r/replay/smaa-$route" "$r/replay/crisp-$route"
}
python "$lane/measure.py" shoulder "$r/motion/crisp-walk/still.png" "$r/replay/crisp-walk/still.png"
```

The largest remaining frame gap is temporal stability at distant rails and thin grass. The largest composition difference is the near tree crossing the board’s open skyline and obscuring the distant mesas. The three follow-ups are to measure the contribution of distant ink versus the underlying geometry in the slow pan, check the shortened cast on more meadow slopes, and compare cel-fable’s next shaded bluff and grass paints against the fixed swatches.

## Round 2

The exported game reads the new `env.exe_aa` key in `engine/style/style_crisp.json`. Crisp selects 4× MSAA, SMAA and TAA off. `TL_EXE_AA` takes precedence. An absent key retains `msaa=2,taa=1`. Boot selects the profile at frame two and `style_cel.gd` validates it.

| Final release window, native 1080p | Previous AA | Crisp AA | Gain |
| --- | ---: | ---: | ---: |
| Standing | 665.85 | 1,577.43 | 2.37× |
| Walking | 432.84 | 1,557.26 | 3.60× |

These are luma Laplacian variances across rows 300–619 of frame 162 in `ThirdLife.exe` on D3D12. Three six-run series gave 2.36–2.37× standing and 3.59–3.60× walking. [Native crop comparison](stills/r2-exe-aa.jpg) · [Replay script](exe-aa.mjs)

The road sun peeks under the upper-left cloud. Existing `sky` controls set `sun_draw_yaw` to 41.8°, `sun_draw_elev` to 9.8° and `disc_r` to 0.032 radians. Its exposed disc has **4,453 pixels** above 235 on all three channels, up from zero. The horizon’s 15 × 15 median at (1421,227) moved from `#eb979e` to `#fbab8c` against the board’s `#fdb18a`. Six cloud profiles vary the crowns, tails and lavender folds. The two complete upper silhouettes in shot 21 overlap by 62% after size normalization and best mirror alignment, down from 82–87% across the three round-one silhouettes. [Board comparison](stills/r2-sky.jpg) · [Final 23.35 s clip](clip.mp4)

**Verification.** Fast 5/5, world 8/8, packs 48/48, kit 95/95. All 46 pack hashes and eight world hashes match the corrected base. Selftests passed style 10/10, rig 14/14, cel 4/4, moves 14/14, flight 13/13, character 2/2 and wings 2/2. All **18 reproducible classic shots were bit-identical**. The other nine differed by more than 1/255 over 0.0067–0.9626% of pixels. In matched-tag classic release windows the base-to-final difference was 0.26–0.33%, within base-to-base variation of 0.20–0.39%. Raw evidence is in `.tl/astra-r2/`.

The six flagged near-ground crops remain below classic. The largest difference is shot 24, 108.8 to 45.4. Its left half accounts for 66% of the lost near-crop edge energy and includes a large hatched cast shadow in classic. The visitor road’s near crop rose from 22.4 to 78.8. [Surface handoff](PATCHES.md)

One extra probe saved its image and then exited with Windows code `0xC0000005` during its scheduled tick-180 shutdown. All 12 subsequent tick-180 controls and both complete tick-300 series exited normally. The cause remains unverified.

## Round 1

**Start with the visitor road.** On board 2, the runner occupies about 37% of the frame height. The starting game gave him about 20%. A nearer ground camera, a raised collar and the dark seam above the trousers make his walking pose readable at that scale. The low sun comes from the left and throws his boot shadow across the road to the right. The horizon stays in focus when he takes off. [Contact sheet](contact-sheet.jpg) · [Visitor road](stills/51_road_visitor_crisp.jpg) · [Road-to-flight clip](clip.mp4)

## The frame

- The painted sky uses an analytic silhouette for each cloud, cream tops and a single lavender paint for the underside and overlapping lobes. Three rings at different elevations wrap around the village. The gradient stays clear between clusters. Sampling the same westward aim with clouds on and off found 4,382 cream and 1,840 lavender samples among 6,481 changed samples. At the longitude join the 99th-percentile adjacent-column difference was 17/255, against 20/255 at a nearby control column. The sampling grid takes every third pixel of a 960 × 540 frame.
- A 22.5° warm key gives the character a long contact shadow. A gentle plum separation affects darker, low-chroma colours. The figure's own directional shader uses surface angle for three paint levels and shadow visibility for the cast. Six measured red coat swatches, from shaded to sunward, were `#b31d20`, `#b41d20`, `#d03020`, `#d03020`, `#ea3b22` and `#e83a22`. This measurement is specific to the figure. The terrain still uses the partner's original light ramps.
- The figure gets an expanded back-face pass that follows skinning and the plot transform. Its maximum width is 2.35 pixels at the 1080p reference size, capped at 11 mm in world space. Rails and beams use the existing depth/normal outline. The native rail fixture holds each rail at 16 projected pixels wide and compares it with ink on and off over 50 rows. At 8, 65 and 180 m the measured ink per edge was **3, 2 and 1 pixels**, respectively. The eight inner pixels sampled in the gap between the rails had zero change.
- A fixed overhead game camera selects a 39° key. At the outdoor angle the scoreboard threw a rectangular shadow across the lower rink. A tested 70° angle clipped the ice highlights and weakened the blue lines. At 39°, the open ice near the top and bottom measured RGB (251,238,208) and (252,240,210). A lower blue-line sample measured (146,167,198). Skaters retain individual cast shadows.
- Crisp uses native render scale, four-sample MSAA, linear tonemapping and deep focus. The final grade sharpens a transition inside the range of its five source texels. This limits light and dark halos.

## The figure and camera

The sculpt retains the biped skeleton, animation clips, sockets and wardrobe options. The walking jacket has a raised collar, shoulder yoke, waistband and exposed cuffs. Two offset hair locks break up the head silhouette. A tapered nose joins the cheek, a bent thumb reads at the cuff, and trouser turn-ups separate the boots. The idle hand brushes the pocket during the existing glance. Hockey uses its helmet, padded gloves and team sweater. [Front](stills/42_figure_front_crisp.jpg) · [Back](stills/41_figure_back_crisp.jpg) · [Hockey](stills/32_hockey_rink_crisp.jpg)

The camera shortens its arm and lifts its aim before the existing crown and obstacle checks. Its grounded eye is 4.335 m behind and 3.299 m above the visitor, looking at 2.33 m. Over 24 physics ticks it returns to the ordinary flight view, 8.5 m behind and 3.6 m above. The largest eye step in the stationary takeoff fixture was 0.174 m. Landing and a live switch to classic restored the expected positions.

In the delivered visitor still, the crown starts around row 588 and the lowest boot reaches row 987. The runner occupies about **400/1080 pixels, or 37.0%**. Classic was about 218/1080, or 20.2%. On native pixels, a 15 × 15 boot-shadow sample centred at (1250,1030) measured median RGB (128,71,97), against (220,152,80) on lit road at (1320,965).

## Sharpness on the fixed shot set

The operator's luma Laplacian variance on the 1920 × 1080 PNGs gave the following classic → crisp values. The centre crop covers x 660–1260 and y 320–860. Near covers all columns below y 800. See `.tl/astra-r1/official-sharp.txt` for all four crops of all 27 shots.

| Shot | Centre | Near |
| --- | ---: | ---: |
| Visitor road | 403.1 → 741.6 | 22.4 → 78.8 |
| Parkour from the road | 2402.1 → 3852.5 | 118.2 → 170.9 |
| River lot | 391.6 → 509.4 | 25.6 → 103.1 |
| Flight over the bluff | 687.4 → 1161.4 | 110.4 → 91.0 |
| Figure front | 492.3 → 647.6 | 99.8 → 150.5 |
| Figure back | 446.1 → 436.9 | 95.5 → 158.2 |

The changed composition and broad areas of flat paint affect whole-crop variance. To isolate sharpening, I also froze the same cel pose, camera, light and geometry and toggled only `grade.edge_contrast`. The centre rose from 541.1 to 685.9 and the near crop from 162.9 to 216.8. Across 85 scanlines of the left sleeve silhouette (rows 540–624), the median 10–90% luma transition tightened from 1.58 to 1.53 horizontal pixels.

## Controls and implementation

All opt-ins are in `engine/style/style_crisp.json`. Select with `TL_STYLE=crisp`.

| Key introduced in the crisp file | Round-one value | Implementation |
| --- | --- | --- |
| `figure.model` | `"cel"` | `engine/rigs/tl_rigs.gd` selects the cel rig and keys the prebuild queue by model. |
| `env.cel_sky` | `true` | `engine/style/tl_style.gd` selects `shaders/sky_cel.gdshader`. |
| `env.visitor_frame.arm` | 0.51 | Grounded chase offset multiplier in `engine/kernel/world/terrain/crown_camera.gd`. |
| `env.visitor_frame.lift` | 0.63 m | Raises both eye and aim. The base anchor hook is in `engine/kernel/api/tl_chase_cam.gd`. |
| `sun.overhead_elev` | 39° | `engine/style/cel/style_cel.gd` reads the active camera's existing overhead-view signal and restores the road pitch when it leaves. |
| `sun.filter_quality` | 2 | Existing shadow-filter control, enabled here for the cel key. |
| `sky.sun_draw_yaw` | 37° | Rotates the painted disc around the physical sun bearing. Disc elevation is 6.2°. |
| `grade.plum_density` | 0.88 | Shadow colour separation in `engine/style/shaders/grade.gdshader`. |
| `grade.edge_contrast` | 0.34 | Four-neighbour edge adjustment in the same grade pass. |

The outdoor sun uses `#ffe4a6`, energy 1.17 and azimuth −173°. Shadow distance is 235 m, blur 0.72 and bias 0.043. The sky runs from `#714cad` through `#af75bb` and `#e892a5` to `#ffd08f`. Clouds use `#ffdda0` and `#d69cc0`. Exposure is 0.93, glow zero, fog density 0.00032 and outline ink `#251525`. Grain and paper are zero. All other retuned controls remain visible in the small section-level diff of the style file.

The new sculpt and idle are in `engine/rigs/biped/cel_biped.gd` and `cel_rig.gd`. Small overrides in `clay_biped.gd`, `clay_form.gd` and `clay_rig.gd` share the skeleton, wardrobe and grip construction. `body_cel.gdshader`, `body_cel_outline.gdshader`, `body_cel_plot.gdshaderinc` and `style/cel/body_outline.tres` implement the paint, hull and placement. `engine/rigs/review/cel_case.gd`, `engine/style/cel/frame_case.gd`, `contour_case.gd` and selftests 600–602 cover the figure, GPU frame, line widths and visitor camera. The three cases are selectable together with `bash engine/tools/selftest.sh cel.`.

## Runtime and adoption

The look is built once in the renderer and rig factory. A game requests its usual biped or installs its usual style rig. Per-game authoring cost is zero. At runtime each visible cel biped adds a hull pass and uses 8,484–9,988 indexed triangles across the 12 tested wardrobes, including the tool geometry counted by the fixture. Each has 29 bones, 20 clips, a 2 m gameplay height and a 0.3 m radius. Bar and stick grip errors both rounded to 0.00000 m. The API, pack content, seeds, palette column order and geometry cache version are unchanged.

The native 1920 × 1080 review scene was frozen at frame 45, looking at the runner and cones from the front. Three passes in different orders gave a median GPU time of 0.519 ms with the complete look. Switching off one feature at a time measured 0.335 ms without the existing world ink pass, 0.512 ms without cloud painting, 0.515 ms without the body hull and 0.515 ms without edge sharpening. Zeroing plum density gave 0.519 ms, below the precision of this experiment. These figures apply to the close-up. The 0.184 ms ink time includes the whole depth/normal pass already used by classic. Raw samples and exact frozen frames are in `.tl/astra-r1/bench/`.

The windowed six-game tour on the RTX 4090 measured **1.011 ms GPU for crisp and 1.256 ms for classic** (0.80×). Frame medians were 2.484 and 2.982 ms respectively. Both profiler records say `quiet=false` on this shared machine. In the frozen close-up, a second experiment switched just the body between cel, classic and hidden. Their GPU medians were 0.518, 0.521 and 0.505 ms. This isolates roughly 0.013 ms for a visible cel biped in that shot. Raw runs are in `perf-crisp.log`, `perf-classic.log` and `bench-rig/bench.log` under the round directory.

## Moving shot

The clip is one continuous windowed take, 1,401 frames at 1920 × 1080 and 60 fps, or 23.35 seconds. The visitor walks west, runs down the road, summons the wings at the river bridge and banks north before turning towards the bluff and village. At tick 840 the camera was 4.07 m above the ground, then 30.01 m at tick 980 and 42.0 m at tick 1260. The first take went under a bridge support. In the delivered take the input releases the run earlier and the camera clears the deck during takeoff. The input recording is `.tl/astra-r1/film2/route.devices.json` with the lane's `road.walk.json`.

## Regression evidence

The starting branch `d966639` declared a clay sculpt method with the same name as the inherited `TLMesh._face` member. Its pristine gate completed two of 48 pack verbs and four of eight world comparisons. Renaming the two private method references to `_sculpt_face` fixes the parse. The Director independently identified the same repair in `e191d8f`. I compared against a separate base copy with this repair. Across both packs, all 46 full SHA-256 values and their frame counts matched. The other two verbs are lints. All eight world tick/hash rows matched the reference, including kit `ca698e71d34d1021@332` and parkour `f7abac006a45bd43@988`. Raw evidence is in `reference-gate.log`, `reference/.tl/gate-packs/` and the worktree's `.tl/gate-packs/`.

| Final fast check or round fixture | Result |
| --- | --- |
| `check --tier fast` | PASS 5/5. Architecture 12/12, assets 4/4, cards 3/3, devx 229/229, foreman typecheck clean. |
| `check --tier full --only world,packs,kit.selftest` | PASS. World 8/8, packs 2/2 with all 48 verbs, kit 95/95. Final run in `last-selected.log`, zero retries. |
| `selftest.sh style.` | 9 passed, 0 failed, including inherited diorama pixel and rink checks |
| `selftest.sh moves.` | 14 passed, 0 failed |
| `selftest.sh rig.` | 14 passed, 0 failed |
| `selftest.sh character.` | 2 passed, 0 failed |
| `selftest.sh flight.` | 13 passed, 0 failed, including flight replay, pose, wings and dust |
| `selftest.sh wings` | 2 passed, 0 failed, including the 36-tick summon and dismiss |
| `selftest.sh cel.` | 3 passed, 0 failed |

The new case lines were `PASS character.cel.wardrobe`, `PASS style.cel.frame` and `PASS style.cel.camera`. Their measured quantities are above. The final shader and script import completed successfully. The shared `tl_style.gd` is 583 lines against the 600-line limit. The final fast gate, style suite, cel block and digest comparison are in `last-fast.log`, `style-complete.log`, `cel-complete.log` and `hash-audit.txt`, respectively. An earlier smoke run overlapped an edit and failed to load the style. Both subsequent selected runs passed in full.

**Classic pixels.** All 18 shots the operator found reproducible were bit-identical to the corrected base, including the visitor road, both close-ups, parkour, flight cruise and the second bluff view. The other nine are the same live-game/streaming shots that varied between base runs. Pixels differing by more than 1/255 ranged from 0.0083% (rink) to 2.3057% (climb). Full-frame equality is unverified in those nine. The complete result is in `official-classic-diff.txt`. An isolated reference initially omitted the external `assets/engine/wings.glb`, making the old flights appear wingless. Restoring the original asset reproduced exact flight shots 22, 24 and 25. Both production styles show the wings.

## Reproduction and remaining work

Run the lane's `shotset.sh` once per style with an absolute output directory. Use `measure.py sharp` on the two PNG directories for native sharpness, and `measure.py diff` for classic preservation. The JPGs and H.264 clip are for viewing. All measurements use engine output. Raw stills, gates and experiments are under `.tl/astra-r1/`.

The operator's 11:35 standup assigns exported-window antialiasing and its `TL_EXE_AA` override to the round-two brief. Round-one sharpness and GPU evidence comes from the windowed engine. A final repeat of the fixed parkour shot on the delivery tree reproduced the official classic and crisp PNGs with maximum channel difference zero.

1. Integrate the cel-fable scenery and compare the turf, beam and tree casts with the same camera and key. The inherited hatch remains visible on the road. The third isolated trial removed it and measured RGB (115,63,81) in the boot cast, against the board's (112,69,78). [Exact partner patch](PATCHES.md) · [Paired surface study](stills/road-shadow-proposal.jpg)
2. The runner is recognizable from behind. The crown still reads as two similarly sized lumps and the review face has a stronger cheek division than the board suggests. Refine these in the integrated light and watch the close-up through the full idle.
3. The current cloud groups repeat a similar set of internal cuts on a long pan. Give several individual banks distinct top silhouettes and larger empty intervals after reviewing both integrated road bearings.
