# Cel-astra · 20 November 2026

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
