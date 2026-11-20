# Round 2 · Astra surfaces

The river has a blue bed beneath a view-dependent sky reflection and broken amber glints. Half-submerged stones use the local heightfield to find the banks. On the bluff, compressed lips, narrow joints and short cracks follow the terracotta layers. The grass has a shorter cut than the crowns, with coarser knots on the pines. The road exposes brighter ochre between darker grains.

## Windowed measurements

These are paired samples of the operator's round-1 captures and the round-2 captures. The bluff and parkour boxes match the operator's coordinates. River, grass, road and pine use my own fixed masks in both rounds. Gradient is the mean sum of absolute horizontal and vertical luminance differences. Grass, road and pine were measured at 1280 × 720. The flight river, bluff and parkour boxes use native 1920 × 1080.

| Surface and measure | Round 1 | Round 2 | Comparison |
|---|---:|---:|---|
| Descent, river interior mean RGB | 184, 155, 124 | 69, 113, 137 | Blue bed visible between peach reflections |
| Descent, river p90/p10 luminance | 1.19 | 2.31 | Same polygon below the bridge |
| Banked bluff, gradient | 3.56 | 7.00 | Classic 6.75 |
| Foreground grass, saturation / gradient | 0.555 / 8.75 | 0.831 / 19.74 | Board 0.85 / 19.3 |
| Road, saturation / value / gradient | 0.589 / 0.712 / 4.96 | 0.751 / 0.879 / 7.83 | Board 0.75 / 0.92 / 9.2 |
| Pine crowns, saturation / gradient | 0.195 / 7.35 | 0.592 / 16.09 | Board 0.58 / 24.0 |
| Parkour frame 520, ground p90/p10 luminance | 1.451 | 2.199 | Classic 1.542 |

Raw images and logs are in `.tl/surfaces/r2/bank/`. Reproduce the measurements with `python .tl/surfaces/r2/measure.py .tl/shots/r1-diorama .tl/surfaces/r2/bank`. The flight uses the existing flight walk and its three selected cameras. The village uses the parkour road and lot bluff road cameras from the fixed blend tour. Road grain and especially pine nap still have less contrast than the board. The landscape retains the frame's graphic outlines.

## Runtime and checks

The four material changes are in `style_diorama.json`, `toon.gdshader`, `handmade.gdshaderinc` and `water_resin.gdshader`. The waterline scatter in `stone_scatter.gd` (and its Godot UID) feeds one instanced mesh through `village_parts.gd`. This uses a separate deterministic seed and the existing placement exclusions. The geometry cache version in `draw_base.gd` is 17. Existing pack palette keys supply all inputs.

- `node devx/bin/tl.mjs check --tier fast` passed 5/5 steps and 248/248 units.
- `bash engine/tools/selftest.sh style.` passed 3/3. `bash engine/tools/selftest.sh surfaces.` passed 1/1. Case 580 now also checks repeatable waterline placement, placement bounds, an absent river and excluded land. Its bank fixture placed 19 stones.
- The parkour orbit capture reached frame 520 with zero script or engine errors. In the supplied shadow crop, the 10th percentile fell from 103.9 to 78.8 and the 90th rose from 150.8 to 173.3.
- With the movie clock fixed and the picture cache disabled, the two classic village PNGs at 1920 × 1080 match the archived diorama-base renders, maximum RGB difference 0/255 on each. The first shortened walk requested two pictures but stopped before the second camera. The comparison uses a retry with both cameras and the complete 100-tick walk.
- The full tier, state hashes, performance and boil are the operator's round-2 gates. The round-1 results below are historical.

# Round 1 · Astra surfaces

The road and parkour course are the quickest places to inspect the materials. Look along the striped beam for paint rubbed through to wood, across the end of a platform for the cross-section of the grain, and around a pine tier for its lighter rolled hem. At the river bend the glint and reflected sky move with the camera over a fixed cast surface. A close wall in raking light shows partial thumb impressions.

## Integration

Existing games select their usual palette keys. All 100 columns keep their order. The diorama opts in with `detail.handmade`. A single palette material still batches kit pieces, and an existing water handle changes shaders on style reload. The pine recipes used for camera clearance and world simulation keep their original geometry. Pine display templates use 720 triangles near the visitor and 260 in the belt and on the mesas for the tested four-tier tree. The original template has 80.

The picture cache uses version 16. Handmade entries include a palette signature because generated terrain and some distant props carry baked vertex colours. Creating a new game with these materials requires zero additional textures, kit calls, export steps or pack fields.

## Verification

Commands below run from the worktree root with `TL_GODOT` set to the supplied Godot 4.7.2 console executable. Raw captures and logs are in `.tl/surfaces/`.

| Check | Result |
| --- | --- |
| `node devx/bin/tl.mjs check --tier fast` | 5/5 steps, 248/248 counted units |
| `node devx/bin/tl.mjs check --tier full --only world,packs,kit.selftest` | 105/105 counted units. World 8/8, packs 2/2 with 48/48 verb runs, kit 95/95. All eight world hash and physics-frame pairs match the baseline table. |
| `bash engine/tools/selftest.sh style.` | 3 passed, 0 failed |
| `bash engine/tools/selftest.sh blend.pigment` | 1 passed. The classic terrain seam measured 7.42/255 at p99.9 across 6,050 pairs, under the 12/255 limit. |
| `bash engine/tools/selftest.sh blend.car_origin` | Revised flock pigment. The first run measured 0.0% green on the live grass. The revised palette measures 99.8% green and 100.0% distant asphalt over 5,500 samples per view, against the same 90% minimum. |
| `bash engine/tools/selftest.sh surfaces.` | 1 passed, 0 failed. Includes palette columns, material reuse, classic → resin → classic reload and repeatable display crowns. |
| `node devx/bin/tl.mjs arch` | 12/12, including API v1 at 43 classes and 658 members |
| `git diff --check` and `git diff --name-only -- engine/packs engine/seeds` | Both clean |
| D3D12 game captures | Parkour orbit frame 520 and hockey arena frame 1500 completed with zero script and engine errors. The runner, red/white beam and playing lines remain readable. |
| `node devx/bin/tl.mjs perf run --scenario tour6 --no-record` | Windowed GPU 1.239 ms classic and 1.266 ms diorama, both **busy**. Observed primitives 1,474,239 and 2,074,787 respectively. Earlier diorama runs measured 1.257?1.272 ms. |
| `node devx/bin/tl.mjs perf run --no-record` | All six scenarios completed, **busy**. Diorama GPU measured 1.271 ms in the six-game tour and 1.334 ms in the thirty-game walk. |

The unfiltered `node devx/bin/tl.mjs check --tier full` returned exit 1. The kernel step reached its 1,800-second cap after 298 passes and the grass-colour failure above. Hockey's many-pack invariant measured 1.011 ms against 1.0 ms. A separate `--only packs` run subsequently passed 2/2 packs and all 48 verbs. The post-correction `--only world,kit.selftest` run passed 8/8 and 95/95, with zero differences across the eight baseline world rows. The full run also passed seeds 39/39, item 91/91 and UI 166/166. Foreman reported 217 passed and six skipped. The formal performance gate reported **NOT RUN** on a busy machine, including its isolated `--only perf` retry. Both the incomplete kernel step and the overall full-tier result are retained in `full.log`.

For the classic image proof, the comparison engine came from a read-only archive of `diorama-base` at `781d32b`, extracted inside this worktree. Both engines rendered parkour seed 1 with the same fixed movie clock. Pillow found a maximum absolute difference of **0/255** in each RGB channel across 1280 × 720 pixels. The two worker reports also have identical state hashes. Reproduce with `TL_STYLE=classic` for both engine paths. Here `engine` and `out` are absolute paths and each run uses its own output stem.

```bash
"$TL_GODOT" --path "$engine" --resolution 1280x720 --rendering-driver d3d12 \
  --audio-driver Dummy --fixed-fps 60 --write-movie "$out.avi" --quit-after 550 \
  res://kernel/host/host.tscn -- worker --mode=capture "--pack=$engine/packs/parkour" \
  --seed=1 --test=tests/bot_course.gd --frames=520 --cam=orbit --hud=on \
  "--out=$out.png" "--result=$out.json"
```

The earlier wall captures without the shared movie clock differed and were unsuitable for a pixel-exact comparison. The definitive PNGs above are `parkour-classic-base.png` and `classic-release.png`.

Two further 1920 × 1080 comparisons cover the changed village generators. On classic, both the parkour road camera and the camera above the yard matched the archived engine **exactly in every RGB channel**. Both runs used the blend map's seed, road, terrain, scatter and eight games. The reduced walk takes two shots at ticks 55 and 75, uses empty optional job lots, and runs to tick 100. Use `TL_ENGINE_DIR` to select the engine, `TL_PICTURE_CACHE=off`, `TL_WINDOW_ARGS="--write-movie $out.avi"`, and `bash engine/tools/world.sh tour .tl/surfaces/classic-village.walk.json --cost=model --load=block --pictures-only --out-dir="$out"`.

## Movement and visual limits

The village test used the blend map, seed 7, blocked loading and a fixed-position 2.49° pan over 180 ticks, looking from the road toward parkour. `bash engine/tools/look.sh boil <movie.avi> 42 147` measured 106 frames. The supplemental play band used `python engine/rigs/review/boil.py <movie.avi> 42 147 430 900`.

| Image band | Classic mean grey change / pixels flipping >24 | Diorama mean grey change / pixels flipping >24 |
| --- | --- | --- |
| Horizon, rows 200–420 | 4.298 / 3.832% | 4.267 / 4.023% |
| Play area, rows 430–900 | 2.740 / 2.287% | 3.047 / 2.391% |

Boil includes the movement of silhouettes. The play-area flip rate rose 0.104 percentage points. A separate stationary-camera check compared material swatches 105 frames apart. Maximum RGB channel differences were 0/255 on a pine, 1/255 on the clay wall and bush, 2/255 on the flock and painted beam, and 4/255 on resin reflecting the environment. The procedural marks are evaluated in part or village coordinates and filtered at distance.

The fixed blend tour completed with 16/16 pictures and zero script or engine errors on retry and again with the final flock palette. See `village-release.log` and `village-release/07_parkour_road.png`. Two earlier attempts saved all pictures but failed to report completion. Those are failed runs. See `final-tour.log` and `pass1.log`.

The inherited outlines and graphic clouds still dominate some wide shots. The timber and resin photograph well at play distance. Fingerprints need a close surface and angled light. The frame integration request is in [PATCHES.md](PATCHES.md).

## Changed runtime and test files

- `engine/style/style_diorama.json` and `engine/style/tl_style.gd` select and configure materials.
- `engine/style/shaders/toon.gdshader`, `handmade.gdshaderinc`, `material_noise.gdshaderinc` and `water_resin.gdshader` implement the material response. The three new shader resources each have a Godot `.uid` file.
- `engine/kernel/world/terrain/village_parts.gd` builds the displayed felt crowns, bluff layers and road grit.
- `engine/kernel/world/draw/draw_base.gd` and `draw_pictures.gd` version and separate cached pictures.
- `engine/tools/selftest.d/580-surfaces-astra.sh` exercises the style and crown contracts.
