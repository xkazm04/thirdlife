# Lane L: the figure (look and animation): status

(final report goes on top when the lane ends)

## Log

### 09:28 start
Read common.md, laws.md, lane-L.md, RIGS.md, tl_rig_node.gd, tl_rig_biped.gd, tl_rig_biped_mesh.gd, toon.gdshader, ink_post.gdshader,
look.sh, review.gd, visitor.gd (rig use, camera 8.5 m back / 3.6 m up / look 1.7 m / fov 60).
Worktree had no `.godot` class cache: `godot --headless --import` once (5 s).

### 09:36 baseline measured (BEFORE, shipped rig)
Old meter (`look.sh slip`, foot socket under 3 cm and moving back against the body) and a new stricter meter added to
`engine/rigs/review/review.gd` (`contact`: six sole points, heel / ball / toe tip of each boot; a point on the floor two frames
running should not move; per frame the worst point counts; also frames with nothing on the floor and the lowest point).

| speed m/s | old meter mean / max | contact mean / max | frames with a sole point on the floor (of 339) | lowest point |
|---|---|---|---|---|
| 1.0 | 0.297 / 0.740 | 1.243 / 3.207 | 339 | -0.032 (3 cm through the floor) |
| 2.0 | 0.610 / 1.496 | 2.433 / 6.429 | 339 | -0.031 |
| 4.5 | 0.751 / 1.087 | 0.941 / 1.725 | 152 (112 with nothing on the floor) | -0.003 |
| 6.0 | 0.994 / 1.457 | 2.450 / 15.430 | 152 | -0.003 |
| 9.0 | 2.264 / 4.599 | 2.494 / 5.028 | 126 | -0.003 |
| 4.5 sidestep (dir 90) | 3.280 / 3.294 | 6.528 / 7.482 | 152 | |
| 4.5 backward (dir 180) | 2.935 / 3.110 | 9.159 / 10.142 | 152 | |

Scout's facts confirmed by figure: the feet skate at every speed, worst sideways and backward (the gait reads speed only).

### 09:38 before clips
`docs/reports/walker-feel/stills/before/*.mp4` (+ `_strip.png`): side 1.4 / 2.0 / 4.5 / 9.0, behind (visitor camera) 4.5 / 9.0 / turn,
sidestep, backward, close-ups. Same set is re-run after each package (scratch `capset.sh`, cameras and frames fixed).

## Plan for L1 (decided 09:40)
Feet planted by construction, not by tuning an amplitude: the gait is foot paths, the legs are solved (two-bone IK, exact).
A stance foot's anchor is integrated against `velocity_local` each tick, so it stands still on the floor at any speed,
direction and acceleration; cadence, duty and stride come from the speed; the pelvis height follows what the legs can reach.
Sidestep and backward: travel direction from `velocity_local`, pelvis turned part of the way, feet travel along the real direction.

### 10:00 L1 gait built and measured (feet plant)
New `engine/rigs/tl_rig_biped_gait.gd` (`TLRigBipedGait`, 270 lines: split out because `tl arch` size-ratchet caps a file at 600 lines);
`tl_rig_biped.gd` `_advance` / `_loco_pose` / `_gait_pose` use it. `amp_override` kept (API v1 forbids removing it), no effect now.

AFTER, same commands (`bash engine/tools/look.sh slip <v> walk`, `RIG_ARGS="--dir=90"` for the sidestep):

| speed m/s | contact mean / max (before) | contact mean / max (after) | old meter mean / max (after) | lowest point |
|---|---|---|---|---|
| 1.0 | 1.243 / 3.207 | 0.036 / 0.527 | 0.016 / 0.113 | 0.000 |
| 2.0 | 2.433 / 6.429 | 0.029 / 0.343 | 0.035 / 0.402 | 0.000 |
| 4.5 | 0.941 / 1.725 | 0.067 / 1.203 | 0.365 / 3.351 | 0.000 |
| 6.0 | 2.450 / 15.430 | 0.070 / 1.187 | 0.486 / 4.497 | 0.000 |
| 9.0 | 2.494 / 5.028 | 0.097 / 1.307 | 0.983 / 6.706 | 0.000 |
| 4.5 sidestep | 6.528 / 7.482 | 0.066 / 1.170 | | |
| 4.5 backward | 9.159 / 10.142 | 0.058 / 1.646 | | |
| 4.5 turning 60 deg/s | 0.955 / 1.986 | 0.068 / 1.304 | | |

Reading the two meters: the contact meter asks "a sole point that is on the floor in two frames running: did it move?" (what the
eye calls skating); it fell 14 to 150 times. Its remaining max is the single tick in which a foot leaves the floor. The old meter
counts a foot as planted from the frame it ARRIVES under 3 cm, so on a gait with a flight phase it samples the landing frame's
approach (one sample per stride, 3 to 6 m/s) and reads worse at 4.5+ than its own stance-only figure: with the landing frame
excluded the old meter's stance reading was 0.006 to 0.03 at every speed (run at 09:45 before feet landed mid-tick). I report it, I do not trust it for a run.

By eye (sheets in `stills/after2/g_*.png`, consecutive frames, same camera as `stills/before/`):
- 1.4 m/s reads as a walk (heel strike, flat stance, heel lift, arm swing); 2.0 a brisk walk.
- **4.5 m/s is a jog / easy run, not a walk**: a walk at 4.5 would need 7.6 steps a second with these legs (duty 0.55, reach 0.75 m). It has a
  flight phase (duty 0.30, cadence 1.52 cycles/s = 3 steps/s, stride 0.89 m). 9.0 is a sprint (2.35 cycles/s, heel to the seat, deep lean).
- sidestep: the pelvis and legs turn 54 degrees to the travel side, chest and head keep facing forward, feet travel sideways; backward: he
  backpedals (leans back a little, toes land first). Switch between the two at 100 / 80 degrees (hysteresis).
- stop from 4.5: stands where the feet are, one or two settling steps bring the feet under him; turning on the spot: he steps round
  (a standing foot keeps its place while the body turns; `g_turn_inplace.png`).

### 10:07 L1 closed, L2 built (the new moves)
- `tl check --tier fast --changed`: PASS arch 12/12, cards 3/3. `tl arch` first failed on three things, all fixed in my files:
  size-ratchet (600 lines a file) -> gait and moves live in `engine/rigs/biped/tl_rig_biped_gait.gd` (274 lines) and
  `engine/rigs/biped/tl_rig_biped_moves.gd` (161 lines); api-v1 (removed `amp_override`) -> kept, no effect; api-v1 additions
  (a `play` / `set_locomotion` override and two new classes would have needed KERNEL_API 1.6) -> two private hooks in `TLRigNode`
  (`_blend_of`, `_locomotion_changes`) and the helper classes sit in a subfolder the API index does not read: **no public API change**,
  `docs/generated/API-V1.json` unchanged at 1.5. `docs/generated/API-INDEX.md` and `REPORTS.md` regenerated (`tl arch --index`).
- Selftest: one closed block at the end of `engine/tools/selftest.sh`: `rig.feet_plant` (sole slide mean under 0.2 m/s at 4.5, 9.0, sidestep,
  backward, 1.4; a run that prints nothing fails) and `rig.moves` (five clips added; a run with a jump keeps its feet). Both PASS:
  `4.5 m/s dir 0 = 0.067, 9.0 = 0.097, 4.5 dir 90 = 0.066, 4.5 dir 180 = 0.057, 1.4 = 0.025`; jump run 0.204.
- ex_kit bot: passed, `walk_speed 2.3`, `leg_swing 0.88`; ex_walker bot: passed, `walk_speed 2.3`.
- `carry` (seed_wall): with `set_locomotion` running the legs are now the gait's (planted); without it the authored walk in place.
- L2 clips (`rig.clips()` now ends `... work, jump, land, slide, slope_slide, air`):
  - `jump` 0.30 s one shot: push with pointed toes and arms low behind, arms thrown up, ends in the rising pose.
  - air pose from `velocity_local.y`: rise (knee up, arms up) above +4 m/s, apex (tuck, arms out) at 0, fall (legs reach down, arms wide,
    eyes down) below -5 m/s; eased in over 5 ticks, out over 3. Also a clip `air`.
  - `land` 0.45 s: the gait's legs (feet planted, he runs on) under a crouch scaled by the fall speed the rig saw itself (last
    `velocity_local.y` while not grounded): 12 cm at 4 m/s .. 40 cm with arms out at 14 m/s; blend at most 4 frames.
  - `slide` holds: low on the left hip, right leg ahead, left hand trailing, right arm up. `slope_slide` loops (so it can keep
    balancing; `play(&"")` ends it): surf stance, arms wide and working.
  - Videos: `stills/moves/jump_side.mp4`, `land_three.mp4`, `slide_side.mp4`, `slope_three.mp4` (+ sheets `g_*.png`), by
    `look.sh clip rig:<jump|air|land|slide|slope_slide>`. Looked at each sheet: all read as the move at first sight.
- Note for lane M (wire): the rig needs `velocity_local.y` while `grounded` is false for the air pose and for the landing depth; if y is 0
  in the air he shows the apex tuck and every landing is soft.

### 10:18 L3 started: why the shading crawls (measured)
Meter (scratch `crawl.sh`): the review scene with `--freeze-at=90` (the pose stops, he keeps travelling at 4.5 m/s, the `behind` camera
is rigid to him), 1920x1080, CRF 4; mean absolute change per frame (0..255) inside two crops on him (hair + pack, pants).
A frozen figure under a rigid camera should not change at all: whatever changes is shading crawling over him.

| variant (old look, snapshot tree) | hair + pack | pants |
|---|---|---|
| standing still (meter check) | 0.001 | 0.000 |
| shipped, moving 4.5 m/s | 1.250 | 1.391 |
| mottle 0 | 0.991 | 1.129 |
| hatch 0 | 1.231 | 1.335 |
| ink AO 0 | 1.286 | 1.349 |
| ink off | 1.254 | 1.098 |
| grade off | 1.027 | 1.007 |
| sun shadow off | 0.759 | 1.076 |
| sun shadow off + mottle 0 | 0.330 | 0.874 |
| shadow off, mottle 0, ink off, grade off (the meter's floor: codec blocks against the moving floor) | 0.314 | 0.338 |

Causes, by size: (1) **the sun's shadow map on himself**: at 8.5 m he is 170 px tall and his self-shadows are a few shadow texels
wide, they step as he moves through the map (about 40 %); (2) **the painterly mottle is anchored to the world** (`vnoise(wpos)`):
he runs through a field of light and dark patches (about 25 %, most on large flat parts); (3) the ink pass (pants: the crease
lines) and the grade's contrast amplify both. The brief's guess "screen-space hatching" does not show here (the camera is rigid, so
screen-anchored hatching stands still on his body as a whole) but is real for limbs that swing through it: fixed too (below).

Fix in `engine/style/shaders/toon.gdshader`: `instance uniform vec2 tl_body` (zero everywhere else: nothing but rigs changes).
x = 1: mottle is read in the part's own space (travels with the body). y = metres: the body's SHADOW CASTER is moved down the
sun's rays (0 at the feet .. y from 0.5 m up), so the shadow on the ground is the same and no part of him shadows another;
world shade (a wall, a tree) still falls on him. `TLRigs._build_rig` marks every mesh of a rig (biped and bot 0.6 m x scale, vehicle 0).
First figure after (new look, worktree): hair + pack **0.481**, pants **0.390** (floor 0.31 to 0.34).

### 10:28 L3: shading fixed and measured, look refined
Controlled A/B on the SAME tree and look (`--no-body=1` switches the body shading off; frozen pose, rigid camera, 30 frames):

| | hair + pack, 4.5 m/s | pants, 4.5 m/s | hair + pack, 9 m/s | pants, 9 m/s |
|---|---|---|---|---|
| body shading off (as shipped) | 1.197 | 1.035 | 1.683 | 1.131 |
| body shading on | **0.431** | **0.621** | **0.621** | **0.380** |
| meter's floor (everything off) | 0.31 | 0.34 | | |

What the toon shader does for a body now (`tl_body`, set on every rig mesh by `TLRigs._build_rig`; zero = everything else, unchanged):
1. mottle read in the part's own space (it travels with him);
2. shadow caster moved down the sun's rays (nothing below 0.2 m so the shadow still touches the feet, in full from 0.6 m up):
   no self-shadow of head / pack / arms on the body, the ground shadow is the same (checked in `stills/crawl/ab_f110.png`; two
   stronger settings let the shadow go of the feet: a caster near the floor falls inside the shadow bias; rejected by eye);
3. hatching drawn ON the body (strokes in each part's own space, spacing kept near `hatch_px` by distance octaves) instead of on
   the screen: a limb no longer swings through standing strokes;
4. rim lights only where the surface curves: **the sole of a boot kicked up behind flashed bright blue at every stride** (the cool
   rim `rim2` lights a whole flat face at a grazing angle, and it is not multiplied by the albedo). Seen in the zoomed stills, not in the brief.
5. `ROUGHNESS = 0.5` on a body (the toon light never reads it): the ink pass reads it from the normal-roughness buffer and
   draws a body's contour at `ink.body_k` (0.55) of the width, with 30 % of the screen wobble. Reason, by eye: the contour is
   drawn INSIDE a silhouette; at 8.5 m his arm is 15 px wide and a 4.8 px line on both sides left a dark blob. Variants 1.0 / 0.7 /
   0.55 / 0.4 looked at side by side (`stills/ink/ink_k2.png`): 0.55 keeps him inked like the world and lets the colours read.
   This is the outline's share of "jagged / shimmering edges" on the figure; the antialiasing itself is lane T's.

Look (by eye, from behind at 8.5 m and close): pants `#4c405a` (a dark purple that merged with the ink) -> `#4d5a8c` denim blue; pack
`#8c8272` grey -> `#c2975a` canvas tan (both style files); pack shorter and rounder so the jacket shows at the waist; the back of the
hair rounder; legs and boots 9 % thicker (toy legs, not stilts). From behind he is now four clear colour blocks: brown hair, tan pack
with the cyan light, red arms, blue legs, brown boots. Close-ups: `stills/before/look_pair.png` -> `stills/look2/look_pair.png`.

### 10:38 all three packages built; evidence set made; full gate started
- Soles: the boot colour x 0.5 instead of palette `black` (a kicked-up near-black sole was a black square at every stride from behind).
- Biped tick cost (headless, 12000 ticks with turns, jumps and landings, busy machine): 22.0 us before, 37.7 us after
  (the solved legs); two rigs fed the same calls end in the same pose (deterministic), all poses finite.
- Kit lab selftest (`bash engine/tools/k.sh selftest`): 91 passed, 0 failed (86 before + the five new clips, each 120 frames in and
  out of the tree, deterministic).
- Evidence (all under `docs/reports/walker-feel/stills/`, not committed; `docs/reports/walker-feel/L-sheet.jpg` 392 KB is the one sheet):
  - `before/*.mp4` and `after/*.mp4`: the same 13 clips (side 1.4 / 2.0 / 4.5 / 9.0, visitor camera 4.5 / 9.0 / turning / sidestep / backward,
    close-ups), same cameras and frames; `behind_before_after.png`, `side_before_after.png` = consecutive frames before | after.
  - `visit_before/`, `visit_after/` + `visit_pairs.png`: `world.sh visit-test tour` with a device script (W, D, S, Shift+W, mouse turn, stop):
    14 pictures each at the same ticks, as a person meets it in the village.
  - `moves/`: `jump_side.mp4`, `jump_behind.mp4`, `air_side.mp4`, `land_three.mp4`, `slide_side.mp4`, `slope_three.mp4` + `g_*.png` sheets.
  - `crawl/`: `frozen_before.mp4` (pristine tree), `frozen_same_look_no_body.mp4` | `frozen_after.mp4` (A/B, same tree), `ab_f110.png`.
  - `packs_before/`, `packs_after/` + `packs_hockey.png`, `packs_skater.png`, `packs_others.png`: hockey (same frame, same score and clock,
    skaters sane with the thinner contour), skater close, bot, car, seed wall, seed paddle: nothing broken by eye.
- Not done / not attempted: feet on sloping ground (the floor under the gait is the rig's own y = 0 plane; on a slope a foot floats or sinks
  as it did before: needs the ground height from lane M/T); a gate case for the shading crawl (it needs a window and ffmpeg; the
  meter is described in STYLE.md instead).

### 10:58 first full gate run (10:37 to 10:56): 10 steps PASS, arch and devx.test FAIL, fixed
`node devx/bin/tl.mjs check --tier full`, exit 1: PASS assets 4/4, cards 3/3, foreman.typecheck, foreman.test 210/210, kernel.selftest
**171/171** (169 + my two), kit.selftest **91/91** (86 + five clips), packs 1/1 (27 of 27 verb runs), perf 2/2 (machine quiet),
seeds 39/39, item.selftest 91/91, ui.selftest 77/77, world 7/7 (world = alone for all 7 games). FAIL arch (`api-v1`: a constant
`TLRigBipedMesh.SOLE` I had added after the index was made is a public addition; indexes stale) and devx.test 221 of 225 (its four
"real tree is green" cases repeat the arch finding). Fix: the constant is a local variable now (no API change), `tl arch --index`.
`tl check --tier fast` after it: arch 12/12, assets 4/4, cards 3/3, devx.test 225/225, foreman.typecheck: all PASS.
A second full run follows so that one run is green from end to end.

### 11:17 second full gate run (10:58 to 11:16): GREEN, exit 0
`node devx/bin/tl.mjs check --tier full`: arch 12/12, assets 4/4, cards 3/3, devx.test 225/225, foreman.typecheck, foreman.test 210/210,
kernel.selftest 171/171, kit.selftest 91/91, packs 1/1 (verb runs 27 of 27), perf 2/2 (machine quiet: use 9 %, probe 1.001),
seeds 39/39, item.selftest 91/91, ui.selftest 77/77, world 7/7 (world = alone, 7 games). **933 units found and completed** (last
green: 924; +2 kernel.selftest, +5 kit.selftest, +2 from before my lane's base). Log: `stills/gate_full2.log`.
This is the state of L1 + L2 + L3 as built by 10:58.

### 11:17 Director's message (11:13): M and T landed on main; lane T sent two shader items (T-PATCHES.md "To lane L")
- M faces the figure where he walks: the sidestep / backward gait is seen only while he turns into a new direction. Kept (it is
  what makes that turn clean), not polished further.
- M's wire read on main (`visitor.gd` `_drive_step`): `set_locomotion(vel in the figure's axes incl. y, mode == ground or slide)`,
  events jump / land / slide / slope / end_slide -> my clips. Matches what the rig expects (air pose and landing depth read y).
- T's L1 (ink contour breaks up on thin members): taken now, measured with T's flicker formula. T's L2 (near canopies): looked at after L1.

### 11:33 lane T's item L1 (the ink contour breaks up on thin members): measured, a part of it fixed; third full gate started
- New meter: `look.sh boil <clip>` (`engine/rigs/review/boil.py`) on a slow pan (a quarter of a pixel a frame) over a new review
  scene `--thin=1` (rail and mesh fences, scaffolds, a crane, trees at 15 to 70 m): mean change per frame and the share of pixels
  in the horizon band that flip by more than 24 grey levels. T's own formula (second difference under a 2 px pan) was tried
  first on `look.sh clip tour` (mean 6.27) and on this scene (14.5 with ink, 8.0 without): it is dominated by everything that moves
  and did not tell the variants apart; the slow pan does.
- Table of nine variants in `engine/style/STYLE.md` ("Thin members far away"). T's two proposals measured **not better**:
  world-anchored width noise 3.22 % flips against 3.17 % shipped (no noise at all: 3.08 %), fading the hairline of wires 3.31 %.
  Both were built, measured and taken out again. The flip map (`stills/ink/thin/flips_pair.png`) shows where it is: the
  lattices. Cause found: pixels change class between "thin member" and "edge: full contour" from frame to frame.
- Shipped: `ink.thin_rings` 1 (thin decided from three rings) + `ink.thin_tone` 0.55 from 15 to 45 m (far thin members toned
  evenly instead of a hairline): **3.17 % -> 2.63 % flips (-17 %), mean 3.37 -> 3.06 (-9 %)**; no ink at all is 0.54 % / 1.66,
  so most of the shimmer is still there: the cure is an ink pass that knows sub-pixel coverage, a look pass of its own.
  Pack pictures before | after: `stills/packs_after2.png` (hockey, seed wall with its mesh fence, seed drive with its lattice
  tower): no visible change at a glance, nothing broken.
- T's item L2 (near tree canopies are pale flat planes): **not done**. It is not cheap: canopies are palette keys `leaf` /
  `leaf_light` with no flag the shader could key a near dither on (a new `mat` key through `tl_style.gd`, its validation and the
  lookup texture), a dither within 2 m must not touch the ground under a low camera, and the question whether the camera should
  avoid canopies is open with lane M (T's M2).
- Seen on the way (not mine): `look.sh clip` of a host scene (`tour`, `hockey`, seeds) ends with "Segmentation fault" when the engine
  quits after `--write-movie`; the movie is complete. The pristine tree does the same.
- Third full gate run started 11:33 (the ink pass and both style files changed after the green run of 11:16).
