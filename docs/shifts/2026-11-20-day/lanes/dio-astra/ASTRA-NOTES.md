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
