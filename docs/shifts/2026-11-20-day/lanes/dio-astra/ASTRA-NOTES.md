# Dio-Astra

## Round 1

The foreground rail, its shadow and the road grit now resolve at native 1080p. The character stays in focus throughout the walk from the parkour yard to the river. See the [board and live frames](round-1/contact-sheet.jpg), [27-second walk and flight](round-1/clip.mp4) and [full-resolution diorama stills](round-1/stills/diorama).

### Optics

The inherited clay rig failed to compile on the starting tree. I renamed its face-sculpting helper to resolve the collision with the mesh builder and captured a fresh control with the figure present and the original lighting and optics. The tour driver's fixed 07 looks across the course from a crane. The visitor view in the sheet and film uses the same village and a supported closer chase camera. Its lower viewpoint puts the figure, its shadow and the road in the same frame as the board.

The old lens applied a near blur in scenic views and a tilted focal plane in chase views. The scenic blur spread colour across both the pebbles and the rail shadow. The new lens leaves the first 105 m clear. Beyond that, four immediate neighbours on the same surface gradually contribute up to 20% at 295 m. Depth rejection keeps a bright sky or distant wall from bleeding into a wire. A long camera arm extends the clear interval around its target. Flight and game cameras requesting deep focus, and cameras with their own attributes, retain their own view. Older styles can still request the tracked tilt prescription.

The operator's luma Laplacian variance on the 16 named 1920x1080 tour PNGs follows. Each column is a geometric mean over the same fixed bands. The middle row isolates the lens at the original lighting. Changing the light moves the shadows and changes the band scores even when the focus plane is identical.

| Capture | Far | Mid | Near ground | Whole |
|---|---:|---:|---:|---:|
| Repaired base, old tilt | 135.33 | 97.65 | 18.90 | 74.78 |
| Far-only lens, original light | 146.11 | 105.13 | 58.50 | 99.21 |
| Round 1, raking light and clay | 167.69 | 110.50 | 50.46 | 101.01 |

On fixed 07 the near score was 15.0 on the control, 206.4 with the isolated lens change and 119.0 in the final lighting. The corresponding 01 values were 12.5, 180.1 and 95.0. Fixed 11 measured 14.3, 179.4 and 91.8. The sheet uses identical light for the two native-size rail crops. A fully clear pinhole gave means of 149.36, 105.72 and 58.55 at the original light. The retained far accent costs little detail against that control.

The 1080p stripe fixture compares the same two-pixel stripes with and without the lens. At 2, 8, 55, 195 and 360 m the contrast ratios were 1.000, 1.000, 1.000, 0.951 and 0.901. The wire over a second surface had a maximum difference of 0/255. It also checks a distant tracked subject and camera overrides.

### Light and clay

I turned the physical key southwest and lowered it to 23 degrees. On the westbound road the shadow now connects to the boots and travels toward screen right, as on the board. The sun on the painted backdrop keeps a separate bearing. Smaller rolls of cotton, a lighter face and two shallow folds give the clouds a visible underside. Fine, direction-anchored variation softens their contour at display resolution. One tuft that touched the central mesa in fixed 07 now clears its silhouette. The sky still uses a 512-pixel radiance cube. The mean RGB of the brightest 2% in the top 30% of 07 went from (253, 216, 157) to (253, 227, 156), against (252, 228, 169) on the board. The brightest 10% went from (248, 188, 120) to (240, 194, 132), against (250, 207, 149). The broad highlight still has less cream than the reference.

With the same review pose and light, the jacket and hair now pick up directional tool flats. The second crown fingerprint breaks the uniform finish when the figure turns. The pockets, cuffs, chipped paint, soles and rolled hair pieces came from the previous sculpt. In the fixed rear review, mean absolute luma change was 1.3 grey levels on the coat panel and 2.9 on the crown. The crown crop gained edge variance from 6.3 to 8.2. The shared material adds no body geometry or draw surface. The twelve wardrobes remain at 9,888–11,788 triangles with 29 bones, 20 clips, a 2.0 m body and 0.3 m radius. The hang, bar and stick palm errors all measured 0.00000 m.

### Runtime and ownership

The tour uses 4x MSAA and SMAA. The real boot scene sets 2x MSAA, SMAA and TAA on frame two. On the same walking pose the latter reduced the far score from 216.9 to 36.6 and mid from 109.4 to 23.5. It also reduced temporal variation. The Director assigned style-selected boot AA to dio-astra for round 2. The current round uses the existing environment override. A second walk with 210 extra stationary startup ticks reproduced the mid-distance difference (24.8 vs 108.9). See the [handoff](PATCHES.md) and [boot crops](round-1/stills/evidence/boot-aa.jpg).

The required windowed tour6 perf run measured 1.515 ms GPU p50 for the final diorama and 1.233 ms for classic on the shared RTX 4090, a 1.23x ratio. Both runs flagged the machine busy. The original 16-shot control measured 1.612 ms and the first raking-light candidate 1.504 ms. The final 16-shot picture run reported 23.505 ms GPU and 275.209 ms frame p50 under contention; the separate tour6 run supplies the comparable figure. Isolating the optics under the old light gave 1.422 ms for the pinhole, 1.498 ms for native far DOF and 1.502 ms for the chosen depth-aware lens. These are separate busy-machine readings. A 1024-pixel sky cube raised texture memory from 521.26 to 933.76 MiB on the same sky fixture. I kept the smaller cube. New games pick up the frame and wardrobe through existing style and rig calls, with zero new pack-specific configuration.

The edited style sections are `sun`, `env`, `sky` and `grade`. All 100 palette names, order and values match the base. The project render settings, packs, seeds and contracts match the base. The API check reports kernel 1.11, 43 classes and 658 members.

### Files and reproduction

- `engine/rigs/biped/clay_biped.gd` and `engine/style/shaders/body_clay.gdshader` contain the sculpt-helper repair and the clay finish.
- `engine/style/style_diorama.json`, `engine/style/shaders/sky_cotton.gdshader`, `engine/style/shaders/dof_distant.gdshader`, `engine/style/dio/miniature_lens.gd` and `engine/style/tl_style_fx.gd` contain the frame, its style values and the existing lens entry point. The two new Godot resources carry their import UIDs.
- `engine/tools/selftest.d/620-diorama-aperture.sh` exercises the production lens. Existing cases 570 and 571 now explicitly supply their original tilt settings. Their original near-rail and pitch assertions and thresholds remain in force.
- Use the lane's `shotset.sh` with `diorama` or `classic`. The raw controls, render logs, walk and input fixtures are in `.tl/astra-r1/`. The optical comparisons use `control/`, `pinhole/`, `far-native/` and `far-surface/`; the moving pose comparison uses `boot-*/`.

### Classic pixel proof

All 26 classic frames match the repaired base at maximum RGB channel difference **0/255**. This covers 16 village views, six flight views, both games with HUD and both figure close-ups. I compared decoded full-resolution PNGs before making the [classic JPGs](round-1/stills/classic).

The ordinary independent runs were noisy. Against the operator's archive, 11/26 were bit-exact. Two independent baseline sets also measured 11/26 exact, including changes to the lighting under the parkour platform and isolated ice particles beside the skates. Using the same warmed cache made fixed 07 match at every pixel. For the complete comparison I ran the same camera and bot inputs with a shared cache, fixed 60 Hz, global presentation seed 620 and fixed particle seeds in both processes. Both figure review pictures already matched through the ordinary capture tool. The game seed stayed at 1, and both capture workers reported matching state hashes.

The measurement-only scene-tree hook is `.tl/astra-r1/seeded-view.gd`. It seeds the global RNG, sets `use_fixed_seed = true` and `seed = 620` as particle emitters enter the tree, and loads the normal host. The source projects are the operator's repaired archive and this worktree. The paired captures are `.tl/astra-r1/classic-seeded-{base,current}/`, with the normal figure pair in `.tl/base_classic/` and `.tl/astra-r1/classic-final/`. Per-frame maxima and counts above 1/255 are in `.tl/astra-r1/classic-parity-delivery.json`. This harness only supplies repeatable capture inputs.

### Remaining gaps

The near-field smear has gone. The sharper view exposes long repeated grooves in the meadow and coarse angular faces in bushes and the riverbank crown. The board's road also has fewer, larger irregular stones, and its mesas carry more visible relief. Those surface details are in the [partner handoff](PATCHES.md). From this arm, the broad cloud highlights still need more cream, and the clay grain is easiest to see in the close-up. At integration, judge the boot override in motion on the joined surfaces before changing either the light or the character again.

### Verification

| Gate or artifact | Result |
|---|---|
| `tl check --tier fast` | PASS, five steps. Architecture 12/12 and devx 229/229. |
| `tl check --tier full --only world,packs,kit.selftest` | PASS. Kit 95/95, pack verbs 48/48 across two games, world 8/8. |
| State comparison | All 46 emitted full pack hashes and all 48 frame records match both the repaired control and the operator's repaired archive. The world-versus-alone log, including all eight tick counts and hash rows, is byte-identical to the repaired control. |
| Style, rig and movement | PASS, style 8/8 including new case 620, rig 14/14, moves 14/14, flight 13/13, wings 2/2 and character 1/1. |
| Games and stills | Both HUD captures finished, parkour at frame 520 and hockey at frame 1500. All 26 final diorama and all 26 matching classic captures decoded. |
| Film | One continuous windowed input replay at 60 simulation ticks/s, encoded at 1920x1080, 30 fps, 27.03 s. The visitor walks to the river, summons the wings and flies over the bluff. |

The gate receipts are `.tl/astra-r1/release-fast.log`, `release-full.log`, `style-delivery.log`, `rig.log`, `moves.log`, `flight.log`, `wings-delivery.log` and `character.log`. The two perf records are `perf-delivery.log` and `perf-classic.log`. The raw final stills are in `final/` and the live route in `film-final/`.

A separate unfiltered `tl check --tier full` was still running its pack tests at the round 1 handoff. Its aggregate exit status was pending. Output goes to `.tl/astra-r1/all-full.log`; the completed round-specific full gate is `release-full.log`.

## Round 2

The diorama boot window now uses 4× MSAA and SMAA. In the village walk, the distant timber rails and the outlines of individual pines stay distinct at 1080p. The moving horizon also shows more shimmer. The [contact sheet](contact-sheet.jpg) puts the board beside the visitor, and the [boot comparison](stills/evidence/boot-window-round-2.jpg) shows both AA settings at native pixel scale.

### Boot AA and its cost

`engine/boot/boot.gd` reads `TL_EXE_AA` first. When it is empty, the boot reads `env.exe_aa` from the active style on physics frame two. The diorama value in `engine/style/style_diorama.json` is `msaa=4,ss=smaa,taa=0`. An absent key selects the existing `msaa=2,taa=1` prescription. That prescription preserves the screen-space filter the style installed. A normal classic boot therefore still applies 2× MSAA, SMAA and TAA.

| Windowed boot measurement | Round 1 | Round 2 |
|---|---:|---:|
| Far-band luma Laplacian variance | 43.46 | 200.09 |
| Mid-band luma Laplacian variance | 24.78 | 109.48 |
| Horizon motion, in luma levels | 0.607 | 1.229 |
| GPU p50 with frame capture, ms | 2.487 | 3.121 |
| GPU p50 without capture, ms | 2.462 | 2.497 |

Each entry is the median of three runs per build. Both used the real `res://boot/boot.tscn` window at 1920×1080, D3D12, fixed 60 Hz, with the style and AA environment overrides cleared. The camera and player traces agree across all six recorded walks. The input was `245:+W;416:-W`. The still landed on frame 383, and all six raw sequences reproduce its nearest-neighbour half-size image exactly. The far and middle bands use the operator’s standard crops. Horizon motion is the median spatial mean of the absolute second temporal difference of luma over 51 frames, 335–385, in half-size columns 96–863 and rows 100–209. It includes both scene motion and shimmer.

Far and mid edge energy rose **4.60× and 4.42×**. Switching the final build back with `TL_EXE_AA=msaa=2,taa=1` returned 43.48 far, 24.85 mid and 0.609 horizon motion. With TAA off, 2× MSAA measured 1.324 horizon motion and 8× measured 1.110. I kept 4× to match the diorama tour and reduce the crawling visible at 2×. On the earlier round 1 boot walk, 8× cost another 1.03 ms over 4×.

With capture running, the difference between GPU medians was **+0.634 ms**. Without image readback it was **+0.035 ms**. The uncaptured ranges overlap at 2.168–3.480 ms before and 1.661–2.541 ms after. The machine was busy. Twelve within-process comparisons at the frozen walking pose gave a median paired difference of -0.425 ms, with individual differences of both signs. The measurements establish the sharpness and temporal tradeoff much more precisely than the runtime cost. The separate windowed `tour6` returned GPU p50 4.115 ms and flagged 93% machine use. The 16-view picture run reported 1.511 ms.

### Clay at chase distance

I pressed two tapered folds into the back of the coat, swept a wider tool mark across the nape and added a cuff crease on each trouser leg. Small broken patches of paint expose the shoulder and one thigh. The marks follow the sculpt in bind space and fade as their projected size falls. All of the changes live in `engine/style/shaders/body_clay.gdshader`, with no additional mesh, texture or draw surface. New games using the clay biped inherit the finish automatically.

I compared two depths against round 1 on the same pose and light. On the native 8.5 m chase crop, 550 pixels changed by at least five luma levels with the lighter press and 830 with the selected press. The coat-panel 95th-percentile change was 4.55 and 9.60 levels, respectively. Three interleaved 60-frame GPU samples of the review pose gave 0.804 → 0.812 ms at chase distance and 0.964 → 0.971 ms close up.

The broad cloud highlight still falls short of the board. I tried three lighter cloud palettes on the tour, yard and bluff sightlines. The tour sky fixture’s brightest 2% already averaged RGB (253, 227, 168), close to the board’s (252, 228, 169). The trials pushed blue to 186–194 and cooled the sunlit tops. I kept the round 1 sky. In the actual parkour-road frame, the brightest 10% still averages (240, 194, 132) against the board’s (250, 207, 149).

### Classic and release gates

All **26 classic stills** match the repaired base at **0/255 maximum RGB difference**. The paired runs use global and particle seed 620, a shared warmed cache, blocking loads and identical camera and bot inputs. The parkour and hockey capture-worker hashes also match at frames 520 and 1500. A separate classic boot comparison on frame 383 matched all **2,073,600 pixels**. For the boot proof I used the built-in deterministic step loader. The two construction-site games entered on ticks 8 and 9 on both builds. Both boots loaded ten packs, reported zero gate leaks and exited 0. In ordinary asynchronous boots the sites entered on different ticks and changed a small area of the distant image. An earlier forced-block boot also matched pixels but reported eight startup gate leaks on both builds.

| Check | Result |
|---|---|
| Fast | PASS 5/5, including architecture 12/12 and devx 229/229 |
| Selected full gate | PASS. Kit 95/95, pack verbs 48/48 across both games, world 8/8 |
| Simulation parity | All 46 emitted hashes and all 48 pack frame records match the repaired controls. The eight-game world-versus-alone log is byte-identical. |
| Named selftests | PASS. Style 9/9, rig 14/14, moves 14/14, flight 13/13, wings 2/2 and character 1/1 |
| Integration media | 26 diorama and 26 classic frames at 1080p. The continuous 27.03 s walk and flight contains 811 frames at 30 fps. |

The new case `engine/tools/selftest.d/621-boot-style-aa.sh` exercises the production frame-two AA selection for diorama, an explicit override and classic fallback. The complete round 2 production diff against round 1 is the boot AA selection, the diorama’s AA key and the clay shader. The project render settings, palettes, pack files, seeds and kernel contracts match round 1.

Raw PNGs, traces, fixtures and receipts are under `.tl/astra-r2/`. The boot evidence is in `pair-{1,2,3}-{before,after}/`, the uncaptured timings in `timing-{a,b,c}-{before,after}/` and the frozen comparison in `frozen-delivery.log`. The classic pixel ledgers are `classic-parity.json` and `classic-boot-parity.json`. Gate receipts are `delivery-fast.log`, `selected.log` and the six `delivery-<filter>.log` files. [Diorama stills](stills/diorama) · [Classic stills](stills/classic) · [Walk to the river and flight over the bluff](clip.mp4).


## Round 3

The control is the joined diorama at `1070eea`, where the new felt, clay, pine and wood surfaces are already active. Its source key was `#ffdcad`, energy 1.24, elevation 23°, azimuth −133°. The −67° setting in the round 2 notes describes the earlier arm.

### Grazing felt and the walking camera

The diorama requests 16× anisotropic sampling on each viewport. The first application saves that viewport's original value. A live switch restores it, including on independently configured previews. The 16-view tour isolates this change with the joined light and compositor settings. Native far / mid / near Laplacian variance rose from 232.8 / 224.7 / 204.3 to 234.5 / 235.2 / 207.0. In frame 07, the oblique felt patch at x 1250–1550, y 530–655 rose from 420.3 to 454.3.

On a moving boot camera, 16× alone raised horizon variation. The shipped Forward+ effect reprojects the previous view with Godot's motion vectors and integrates up to nine depth-tested samples around the reprojected point. The weights stay centred on the original ray. At rest the footprint collapses to the native sample, with at most 58% older colour per step. In motion the footprint widens and the upper bound rises to 84%. History begins at 24 m and reaches full weight at 44 m. It fades as the camera travels from 0.15 to 0.40 m between rendered poses. Fast flight draws the passing ground from the current frame. Abrupt camera cuts, projection changes, newly uncovered surfaces and large screen-space shifts take fresh colour. The near visitor, HUD and full-resolution source retain their own samples. Hardware MSAA and SMAA still run. A caller's explicit `TL_EXE_AA` selects the requested hardware or temporal mode directly. The resolve also yields to stock TAA and FSR2.

The two RGBA16F colour/depth histories occupy 31.6 MiB at 1920×1080. Forward+ also supplies velocity. One compute dispatch reads and writes the active scene. The material recipes, kernel and game APIs require no additional authoring per pack.


### Light and colour

The lower key is `#ffb987` at 1.83 energy, 18° elevation and −122° azimuth. On level ground a vertical object's geometric shadow is 3.08 times its height, 31% longer than at 23°. An angular size of 1.1° softens the penumbra. The contact colour is `#422e25`, with radius 0.82. I kept the low painted sun on the mural at its integration bearing while turning the studio light across the meadow.

The upper backing is `#93647d`, the middle is `#d9958b`, and the tufts use `#ffe5b1` against `#c2917b`. A wrap of 0.70 carries warm light across the broad face of each roll while retaining the recess between rolls. The grade uses a small surrounding patch of the screen to set the local light and shade. Darker felt retains more of its individual fibre contrast. This keeps the brighter road and harder-lit timber from amplifying every grain in the texture.


At 1280×720, the Director's lower-half luma percentiles and upper-cloud sample give the following comparison. The cloud column is the mean RGB of the brightest 5% in rows 0–249.

| View | Ground p5 / p50 / p95 | p95 − p5 | Cloud RGB | Full-frame RGB |
|---|---|---:|---|---|
| Board 4 | 59 / 133 / 181 | 122 | 252, 216, 160 | 180, 116, 65 |
| Joined 07 | 89 / 129 / 159 | 70 | 245, 210, 145 | 167, 127, 69 |
| Round 3 07 | 57 / 122 / 176 | 120 | 254, 225, 161 | 177, 123, 65 |
| Joined 01 | 102 / 129 / 155 | 53 | 243, 212, 158 | 161, 131, 72 |
| Round 3 01 | 81 / 135 / 178 | 97 | 252, 224, 167 | 180, 131, 70 |

At 07 the broad highlight is still nine green levels brighter than the board. In 13 the camera faces the backlit riverbank. Its lit grass sample reads 103, 90, 18, substantially darker than the board's sunlit meadow. The partner handoff gives source dyes, pine samples and three measured river colours. [For dio-fable](PATCHES.md#for-dio-fable--round-3)

### Playback cost

Three uncaptured 420-tick Windows export walks per build alternated the joined and delivered binaries at 1080p D3D12. GPU p50 readings were 3.128 / 3.741 / 3.471 ms joined and 3.495 / 3.829 / 3.756 ms delivered. The medians were **3.471 and 3.756 ms**, a 0.285 ms increase. All six walks used the same warm geometry and camera input.

A separate alternating series held the delivered build and light fixed. Bypassing the horizon pass measured 4.719 / 5.616 / 4.757 ms. Enabling it measured 4.448 / 4.636 / 4.698 ms. The small reversal between the two medians is inside the variation across runs. The GPU work added by the effect is one native-resolution dispatch and the renderer's velocity pass. It also retains 31.6 MiB of history at 1080p. The grade reads one mipmapped screen sample to estimate local illumination. The 16x setting uses the existing material textures and mip chains. The new cloud diffuse term runs during the sky radiance bake.

The independent windowed `perf.tour6` run reported **2.778 ms** on the delivery, against 2.193 ms joined and 2.701 ms classic in this session. All three reported **BUSY**. The operator's earlier joined figure was 2.339 ms. The delivered measurement was 27% above the same-session joined figure, within the twofold frame budget. These readings describe this RTX 4090 under the measured load.

### Reproducing the moving comparison

Both native Windows builds start their normal `res://boot/boot.tscn` and use the same warm diorama cache. I exported the joined source and the arm separately with `bash engine/tools/export.sh build --no-warm --out <directory>/ThirdLife`. The walk uses D3D12 at 1920×1080 and fixed 60 Hz. It presses W at frame 245, releases it at 416 and exits at 420. The EXE writes 51 consecutive RGB frames, 335 through 385, plus the camera, look direction, FOV and player position for each frame. The frame-383 full-resolution PNG reproduces raw frame 48 exactly when sampled on odd pixels in both axes.

Horizon motion is the median mean absolute second temporal difference of luma in the 960×540 recordings, x 96–863 and y 100–209. It includes legitimate motion of scenery as well as shimmer. Far and mid sharpness use the operator's 3×3 luma Laplacian on the original 1920×1080 still. Camera, player and scenery probes are checked before comparing. A cold build measured eight pack rims and drew 457 far trees. The warm control and delivery both reused all eight rims and drew the same 460 far trees. Only the warm pair enters the comparison.

To repeat the walk from this worktree, the capture runner is `.tl/astra-r3/exe.mjs` and the frame verifier is `.tl/astra-r3/motion.py`. A second pass with `TL_EXE_AA=msaa=4,ss=smaa,taa=0` uses the same light, anisotropy and hardware AA and bypasses the horizon compositor. The motion clip plays the matched view three times at real speed and twice at half speed. The upper panels show the walk. The lower strips reproduce the measured band pixel for pixel. [Walking comparison](stills/evidence/walking-horizon-round-3.mp4)


| Exported walk, native frame 383 | Horizon motion ↓ | Far edge energy | Mid edge energy |
|---|---:|---:|---:|
| Joined light and original sampling | 1.443 | 237.71 | 268.48 |
| Joined light, 16× and the walking resolve | 0.992 | 210.77 | 274.36 |
| Round 3 light, 16×, hardware AA only | 2.004 | 406.52 | 361.43 |
| Round 3 delivered | **1.306** | **293.28** | **359.65** |

With the final light held fixed, the resolve cut horizon variation by 34.8%. Against the joined executable, the delivered walk reduced motion by 9.5% and raised far and mid edge energy by 23.4% and 34.0%. Lighting also changes edge energy. The fixed joined-light control shows the sampling tradeoff directly: motion fell by 31.3%, far energy fell by 11.3%, and mid energy rose by 2.2%. On the pre-integration surfaces round 2 measured 1.229, so the delivered walk remains slightly above that older reading. [Matched native boot crops](stills/evidence/boot-window-round-3.jpg)

Raw runs are `matched-joined-1`, `release-optics3`, `release-handoff-raw` and `release-handoff` under `.tl/astra-r3/`. The deliverable export is `export-handoff/ThirdLife/ThirdLife.exe`. The 51 camera/player pose records match across all four runs. The moving views share the same light-independent geometry probes and use 4× MSAA, SMAA and native resolution.


### Classic and gates

The matched fixed-base and final classic captures used the same exclusively classic picture cache and deterministic presentation seeds. All 16 tour views, six flight views, two running games and two figure close-ups matched pixel for pixel at 1920×1080. The maximum absolute channel difference was 0/255. The two HUD-on games kept their fixed-base state hashes. A separate classic-only boot cache gave identical camera/player traces and zero changed pixels across all 2,073,600 pixels of frame 383. Both warm boot runs completed 420 ticks with zero script errors, engine errors, gate leaks or wrong-pack calls.

| Gate on the delivered source | Passed |
|---|---|
| Fast | 5/5 steps, including architecture 12/12 and devx 229/229 |
| Filtered full | Kit 95/95, pack verbs 48/48, world 8/8 |
| Named selftests | Style 11/11, rig 14/14, moves 14/14, flight 13/13, wings 2/2, character 1/1 |
| Boot, games and performance | Release export built and walked, parkour frame 520 and hockey frame 1500 captured, windowed tour6 passed |

All 48 pack frame counts and 46 emitted state hashes match the repaired base. The complete world result log is byte-identical. Test 622 checks viewport-local 16× and restoration of independent 2× and 8× settings. Test 623 measures a near/far contrast swing of 41/39 levels with the effect bypassed and 41/2 with it active. Both its 45 m/s flight sample and its 700 m camera cut match fresh renders at 0/255. Test 620 retains full contrast at 2, 8 and 55 m, with a zero-difference wire silhouette.

Only `sun`, `env`, `sky`, `ink` and `grade` changed in the shared JSON. The protected material sections match the joined file byte for byte. Project rendering settings, packs, seeds, kernel, kits, rigs and contracts match the joined revision. The release and test receipts are under `.tl/astra-r3/`, including `handoff-*.log`, `handoff-hashes-proof.txt`, `classic-handoff-parity.json` and `classic-boot-parity.json`.


### Delivered pictures

The table uses the operator's native 1080p bands and geometric means. The flight set contains six actual visitor frames over the bluff.

| Set | Joined far / mid / near | Round 3 far / mid / near |
|---|---|---|
| 16 village tour views | 232.8 / 224.7 / 204.3 | **361.6 / 333.4 / 277.5** |
| 6 flight views | 252.5 / 221.3 / 225.4 | **460.9 / 372.7 / 340.7** |

A trial that reused the walking history at full flight speed measured only 126.4 in the near band of the six flight views. Fading history with camera displacement brought that band back to 340.7. In the visitor film's ridge crossing, the bottom-ground crop rose from 21.5 in that trial to 247.9. This let the flight camera keep the detail in the passing ground while preserving the lower horizon motion on foot.

The 26 published diorama frames combine the standard shotset's tour and flight captures in `handoff-scenery` with its two game and two figure captures in `handoff-shots`. All 26 source PNGs are collected in `handoff-gallery`. An independent complete 26-shot invocation also finished in `handoff-shots`. Its flight bands measured 460.8 / 372.9 / 340.7. The 26 classic controls are in `classic-handoff`. The village film runs 27.03 seconds at 1920×1080 and 30 fps, following the live visitor from the yard to the river and into flight. [Contact sheet](contact-sheet.jpg) · [Diorama stills](stills/diorama) · [Classic stills](stills/classic) · [Village film](clip.mp4)

## Round 4

The clay visitor keeps its two raised crown rolls, red standing collar and chipped cuffs. I lifted the low point of the nape, turned a flatter face into the upper roll, and softened the groove at the end of the curl. A shallow thumbprint now crosses the left side of the nape. Its ridges travel with the head and fade when the camera can no longer resolve them.

The broad hair surface carries a matte ochre wash. The separate rolls carry a burnished finish, with darker pigment where they join the scalp. Both catch a broad reflection tied to the direction and energy of the village light. The vermilion adjustment follows the garment's existing red pigment, so a pack can still supply its own colours. These changes use the existing mesh, material and palette lookup. The production edits for this round are `engine/rigs/biped/clay_form.gd`, `engine/rigs/biped/clay_biped.gd` and `engine/style/shaders/body_clay.gdshader`.

The first yard trial produced the requested amber crests, but a turn beside the river exposed a much larger golden patch on the side of the head. In that trial, 84% of the side patch reached 250 or above in the red channel. I checked both camera angles before selecting the finish.

### How the crops were measured

The board is the original 1280 × 720 JPEG. Both visitor photographs are 1920 × 1080 at yard tick 23. I used the four rectangles in the brief. Hair includes every pixel in its rectangle. The jacket mask selects pixels with R > 40, R > 1.4G and R > 1.5B. Luma uses 0.299R + 0.587G + 0.114B on the displayed eight-bit values. This reproduces the operator's board and round 3 numbers. I also sampled each crown roll inside its outline and the centre of the coat separately, since the wide rectangles include some road.

The final geometry passed the twelve-wardrobe check at 9,888 to 11,788 triangles, 29 bones and 20 clips. The ledge, bar and stick palm errors measured 0.00000 m. Fast passed all five steps. The filtered full gate passed kit 95/95, pack verbs 48/48 and world 8/8. All 48 frame counts and 46 emitted state hashes match the fixed base, and the complete world log is byte-identical. The first round 4 classic run matched the warm fixed base at 0/255 in all 26 images and the boot walk. Its input trace also matched.

The exported Windows game shows the colour change at its ordinary walking distance. At frame 383, in the same 44 by 26 pixel hair patch, luma p5/p95 rose from 44/58 to 59/150. Windowed tour6 passed at 8.315 ms GPU p50 and 0.551 ms render CPU p50. The shared machine was busy and took 72 seconds to draw its first frame. Round 3 recorded 2.778 ms GPU p50 on a busy machine. This run cannot isolate the cost of the finish. [Exported walking frame and detail](stills/evidence/figure-light-round-4.jpg)

### Delivered yard frame

| Native sample | Board 4 | Round 3 | Round 4 |
|---|---:|---:|---:|
| Hair mean RGB | 150 / 67 / 20 | 90 / 37 / 19 | 149 / 64 / 18 |
| Hair luma p5 / p95 | 48 / 171 | 37 / 69 | 47 / 159 |
| Luma p95 inside the left and upper crown rolls | 164 / 171 | 58 / 56 | 172 / 176 |
| Jacket red pixels, mean RGB | 196 / 73 / 35 | 157 / 68 / 37 | 198 / 71 / 38 |
| Jacket red pixels, luma p10 / p90 | 53 / 162 | 44 / 177 | 56 / 178 |
| Centre of the coat, mean RGB | 192 / 28 / 18 | 121 / 28 / 19 | 186 / 29 / 18 |

The whole-hair p95 remains 12 levels below the board, while both rolls now have visible warm highlights above 170. The wider jacket crop still has a brighter upper tail than the reference. The dark backlit river slope at tour stop 13 remains open. [Native visitor photograph](stills/diorama/visit_01_yard.jpg)

The repeat on the delivered source matched all 26 fixed-base classic PNGs at 0/255. The 420-tick boot trace and captured frame also matched exactly. The receipts are `.tl/astra-r4/selected/classic-result.txt` and `classic-boot-result.txt`.

In the delivered broadside river view, 8.5% of the 61 by 27 pixel hair patch reached red 250, down from 83.6% in the first colour trial. The patch now averages RGB 195 / 81 / 18. It sits at (913,608)-(974,635) in the 1080p image. [Native river photograph](stills/diorama/visit_06_river.jpg)

The round 4 named runs passed rig 14/14, moves 14/14, flight 13/13, wings 2/2 and character 1/1. The flight result is the complete `flight.` invocation inside `moves.flight_unchanged`. The shared window lock delayed the final style suite and shotset. Their live receipts are under `.tl/astra-r4/selected/`.

The lane film is 20.63 seconds at 1600 by 900 and 30 fps, weighs 7.85 MB, and shows the final figure from the yard through the flight over the bluff. All 26 classic controls are exact. The fresh diorama shotset had produced 20/26 native images at handoff. The windowed style suite was still running at the cutoff. [Contact sheet](contact-sheet.jpg) and [village film](clip.mp4).

### Verification after handoff

All 26 native diorama stills finished by 16:09. The gallery check verified those 26, the four live visitor photographs and all 26 classic controls. The published film contains 619 frames and weighs 7,851,430 bytes. The two-angle material study still had a live window during the tour6 sample, so the 8.315 ms result includes GPU contention. [Diorama gallery](stills/diorama) and [walking and flight footage](clip.mp4).

The final windowed style suite passed 11/11 at 16:16. The horizon test retained near contrast of 41 and reduced far-frame swing from 39 to 2, with zero flight or cut delta. All requested gates passed before Integration 2. The style receipt is `.tl/astra-r4/selected/style-direct.log`.
