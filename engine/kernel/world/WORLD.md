# N7: one world you can walk through

> **Owner's rulings of 2026-11-11, after the night's build.** (1) A far game may run as slow as one sixteenth of real
> time and no slower (`slice.max` 16). (2) A far game does not have to be shown in full: the next work on distance is to
> learn what to abstract and what to hide without destroying the view. Today's stand-in (one merged still mesh, no
> moving parts) is a first guess, not the answer. (3) In a world the land between venues belongs to the world; a pack
> brings a venue, not a landscape. (4) The automatic next round is paused; starting and engaging in games is a chapter
> of its own.

> **P4 (11 November, morning): the land has height and the visitor has a body.** The world's ground is a heightfield
> (`terrain/village_terrain.gd`): rolling land, a ring of hills, a bluff with a cliff face, a low valley with a river
> and two ponds. Every plot stands on a flat pad of its own height with a bank and a kerb round it; roads follow the
> land with a spur and a gate to every plot; a bridge crosses the river; trees, rocks and bushes follow the land. The
> visitor is a capsule in a physics space that belongs to the world (`terrain/world_space.gd`): he walks on the terrain,
> stands on a plot's own ground inside the plot, and stops at fences, trees, rocks, walls and rails. Sections "Relief"
> and "The visitor's body" below; `PATCHES-P4.md` has what is left for files that are not P4's.

Tonight's four pieces in one process and one window: many packs alive, each in its own physics space (N2,
`BENCH.md`); a scheduler that gives each pack ticks by tier (N5a, `TIERS.md`); a drawing layer that shows every pack
at its plot (N5b, `draw/DRAW.md`); the look (N1). This page says how they are joined, how a walk and a tour are
written, what a pack author must know, and what is not built.

```
bash tools/world.sh tour tour --out-dir=<abs dir>       # window, numbered pictures, tier log, hash table, PASS / FAIL
bash tools/world.sh tour tour --headless                # the same world without a window (the selftest case world.tour)
bash tools/world.sh tour tour_views --out-dir=<abs dir> --pictures-only    # the three crane pictures
bash tools/world.sh visit tour                          # a person walks it: W S along the view, A D step aside, the mouse looks, Shift runs, E enters, Q leaves, Esc quits (P11)
```

## How the pieces fit

| who | file | what it owns |
|---|---|---|
| the host | `kernel/host/host.gd`, mode `world-view` | starts the windowed world like every other mode (options in `kernel/runner/verbs.json`) |
| the world host | `kernel/world/world.gd`, `pack.gd` | the packs, their spaces, the world tick, the walk script, the world log; signals `plot_event` and `ended` |
| the scheduler | `kernel/world/tiers.gd`, `tiers.json` | every decision about who ticks, as events: `tier`, `slice`, `speed`, `leave`, `return`, `over`, `restart`, `refused` |
| the viewer | `kernel/world/draw/view.gd` | the window: listens to the world host, tells the draw layer, owns the stage switch, the cameras and the pictures |
| the draw layer | `kernel/world/draw/draw.gd` | every pack at its plot (shader offset), the plot cut, the stand-ins; never touches simulation |
| the landscape | `kernel/world/landscape.gd`, `terrain/` | the heightfield, pads, roads, river, bridge, plot edges, scatter, mesas, haze: built once, visual; and the visitor's collider (`terrain/world_space.gd`) |
| the visitor | `kernel/world/visitor.gd` | a biped rig, a chase camera and a BODY (a capsule in the world's own physics space); where he stands is drawn from the body |

One world tick, in order: the world host asks the scheduler for this tick's events (`decide`, or the log's events in
a replay) and applies them; each `tier` event is handed on as `plot_event` at that same tick boundary, so **the event
that changes a plot's ticks is the event that changes how it is drawn**; then the due packs are ticked; then the
viewer moves the visitor and takes a picture if the walk names one.

| tier | ticks | drawing |
|---|---|---|
| `stage` | every world tick | zero offset (the world is re-based on its plot), its own camera, its HUD, its input |
| `sideline` | every world tick | in full at its plot (`tl_plot` in the style shaders) |
| `backdrop` | one tick in `slice` | its stand-in mesh (one merged still mesh, built the first time it is needed) |
| `ledger` | none: not in memory | its stand-in, built just before the pack is unloaded |

**While the visitor walks nobody is on stage** (`draw.set_stage(-1)`): every pack is drawn at its plot in world
coordinates, every HUD is hidden, the picture is the visitor's chase camera. `enter` (he must stand inside the plot)
puts that plot on stage: the world is re-based on it once, the pack's active view becomes the viewport's camera, its
HUD is shown, the visitor's rig is hidden. `leave` hands the picture back. In a scripted run the stage pack is played
by its bot, as before and after, so its inputs are the same as alone.

**A game that ended by itself** stays over. (N7 built a next round: such a game, when not on stage, is built again
from its seed `restart_pause_ticks` after it ended or after the visitor left it. The owner paused that idea on
2026-11-11: `tiers.json` ships 0, and how games start and how a player engages with them will be designed as a chapter
of its own. A walk may still set the key under its `tiers` to exercise the path.) A rebuilt pack gets its first tick on the NEXT
tick boundary (`rest_until` in tiers.gd): its nodes entered the tree inside a physics frame, the scene tree would not
tick them in it, and the first tick would be half a tick. This was a real difference tonight (three of six hashes)
and it also covered N5a's return from `ledger` and from `on_leave: end`, which use the same rebuild.

**Scenery.** `scenery = "plot"` is now the default of the world host in every mode (`--scenery=full` brings a pack's
own far terrain and forest back). A plot's size comes from the walk's `footprint`, else from `footprint` in
`pack.json`, else 40 x 40 m; its drawn radius is the walk's `radius`, else half the footprint's shorter side.

## The walk and the tour (`tl.walk/1`, `kernel/world/walks/tour.json`)

N5a's format (TIERS.md) plus:

| key | meaning |
|---|---|
| `"visitor": true` | the stage follows `enter` / `leave`, not the player's position; next rounds are possible (off while `restart_pause_ticks` is 0) |
| `"events"` | `{"t": 990, "e": "enter"}` (the plot he stands in; `"plot": "<id>"` names one), `{"t": 1440, "e": "leave"}`, `{"t": 1200, "e": "shot", "name": "on_stage_drive"}`, `{"t": 100, "e": "shot", "name": "overview", "cam": "crane", "from": [x, y, z], "to": [x, y, z]}` |
| `"plots"[i]."radius"` | metres: the circle the pack is cut to and drawn in |
| `"road"` | `[[x, z], ...]`: control points of the main road; every plot gets a spur and a gate |
| `"landscape"` | `seed`, `road_half_m`, `trees`, `broadleaf`, `rocks`, `bushes`, `belt`, `tufts`, `mesas`, `haze` (factor on the style's fog, 0.4), `fence`, `gates`, `spurs`, `lots` (`[{"at": [x, z], "radius": m, "h": pad height}]`: fenced building sites with a crane, a scaffold and stacked timber, no game on them yet; no `h` = the land's own height there), P4: `pad_h` (per plot, the height of its pad: the SAME number as the plot's `origin` y, see PATCHES-P4 1), `river` (`{"path": [[x, z], ...], "half_m", "pond_m", "depth_m"}`: a river that ends in a pond at each end), `margin_m` (the heightfield reaches this far beyond the plots, roads and river), `cell_m` (3), `rim_band` (9: must equal the draw layer's), P13: `soft_patches` (150: low patches of worn earth, darker grass and meadows; their own random generator), `edges_now` (false: build the pad edges in the frame instead of on a worker, to measure; `TL_LAND_NOW=1` does the same) |
| `"plots"[i]."origin"` | `[x, y, z]`: P4: `y` is the height of the plot's PAD in the world (the draw layer lifts the pack by its own rim on top of it) |
| `"visitor_probe"` | P4: a list of `{"name", "from": [x, z], "to": [x, z], "expect": "stop" or "pass"}` (and the element `"auto"`: a tree, a rock and the bridge's rail): the visitor's body is put at `from`, sent at `to`, and one `tl.view/1` line of kind `visitor_probe` says where it ended and what stopped it |
| `"visitor_cam"` | options of the chase camera (`distance`, `height`, `look_height`, `fov`) |

A request that cannot be met is an event too (`refused`, with `why`): an `enter` outside every plot, a `leave` with
nobody on stage. A shot without `cam` is whatever the player sees: the visitor's camera, or the stage game's own.
A picture is saved three frames after its tick; a shot must lie 10 ticks before the end of the walk.

`world.sh tour` prints: the tier log (one line per event), one line per pack (own ticks, hash, tiers seen), the
world line (tick times, gate leaks, wrong-pack calls, errors), one line per picture, and the table **hash in the
tour = alone for the same number of its own ticks = replay of the world log**. The numbered pictures and
`world_log.json` are in `--out-dir`. "Alone" is a fresh headless process per pack (`world.sh run --mode=bot`).

## What a pack author must know

- Sections 19 to 21 of `kernel/API.md` and `draw/DRAW.md` section 10 still hold; nothing in a pack changes.
- **Your game is entered and left.** `ctx.on_stage` is false while you load (N5b patch 1) and while nobody is in
  your plot; your HUD is made hidden (patch 2) and your views do not take the camera. When the visitor enters, your
  ACTIVE view (`ctx.cameras.active`, the first one you registered unless you activated another) becomes the picture.
  Register the view a player should play in first.
- **Your game starts again by itself.** When your game is over (your bot is done) and nobody is in your plot, the
  world builds you again from your seed 3 seconds later: `_pack_setup`, `_pack_start`, tick 0. Nothing is carried
  over (not even `_pack_save` data). Do not keep state in `static var`: the script is the same object in the next
  round.
- **Your plot has a height.** P4: the world puts your plot on a flat pad at its own height (a bank and a kerb round it;
  the ground of the world meets your ground at the same height at your rim, so there is no seam and no step). Your
  rim height is measured as before and lifted on top of the pad. Standing on a pad is a rim, not a floor: a pack
  whose own ground is a hollow (the drive seed, 7.6 m deep) has its rim ground bent over 9 m, which is 40 to 60
  degrees at the steepest: the visitor's body stops at the top of it (see "The visitor's body").
- **You bring a venue, not a landscape.** In a world your layout is built without its far terrain and its scattered
  forest. The world draws the ground, the road to your gate, a ring of worn ground and a fence 3.6 m outside your
  radius, the trees and the mesas. Declare `footprint` in `pack.json`; no seed or example does yet, so tonight's
  radii are in the walk script.
- **A big flat floor of your own reads as a disc from above** (`ex_car`): it is cut to your radius like everything.
- **Far away you are a still picture and run slower** (TIERS.md, DRAW.md): the stand-in is taken when you are first
  far and is kept across your rounds.

## Relief (P4)

`terrain/village_terrain.gd` is one heightfield for the village, built once by `landscape.gd` (3 m cell, 696 x 612 m in
the tour, 47,765 vertices, one indexed mesh with smooth normals, one surface of the palette key `terrain`: the style's
ground class, so it has the tufts, pebbles and the drawn strata on steep faces like every pack's ground). Roads and the
river are STAMPED into the grid (every sample of a path marks the vertices round it; the kit's way, a path query per
vertex, would have cost 18 s). What is in it:

| thing | how |
|---|---|
| land | simplex noise (4 m and 1 m amplitude), a ring of hills 24 m high from 300 m out, the border pulled down to the far plain's level |
| a bluff | a 9.5 m step with a cliff face behind the northern venues (z about -205), a plateau on top |
| pads | `pad_h` per plot: a flat disc of radius plot + 10.5 m at the plot's height, a bank round it (width 0.7 x height difference when cut into the land, 1.1 x when filled up, at least 3.5 m), a stone kerb at the lip wherever the bank falls or rises more than 0.9 m |
| roads | the main road follows the land (the land's height along it, smoothed twice over 20 m); a spur from every plot's gate climbs from the pad's height to the road's; the ground is graded flat across the road (corridor 3 m + 9 m blend) |
| water | `river`: a valley 5 m under the land round the river (36 m wide), a channel, the style's water material along it, a pond at each end |
| bridge | where the main road is within 17 m of the river: a deck on the road's own profile, rails, three piers; the road strips stop under it |
| scatter | trees stand on convex ground (tree lines on ridges), rocks on steep ground, none within the pad of a plot, on a road, in the river or on ground steeper than 17 to 19 degrees; 120 pines, 40 broadleaf, 46 rocks, 90 bushes, a belt of 180 on the hills (fewer than N7's 150 / 46 / 60 / 110 / 260) |

Where the plots stand moved (the pads need room and the roads a margin): the tour's plots are 100 m apart in two rows
either side of a road at z = 0 (`tour.json`). The dirt ring, the fence and the gate stand on the pad at its height;
the pack's ground meets the pad at the same height (the world's ground used to lie 6 cm under it and the ring 3.6 cm
over it: that step was the black rim line of last night's pictures 04 and 06).

## The visitor's body (P4)

What was chosen, and why. A pack's bodies live in a space of its own and must stay untouched; the visitor belongs to no
game. So the WORLD owns a physics space (`PhysicsServer3D`, no nodes) and puts only static things in it, built once
with the landscape:

* the terrain's triangles (88,812; a triangle is left out where a plot's own ground carries him instead);
* a wall (thin quads, 3 m high) along every plot's fence, with the gate left open; trunks of trees and tall rocks
  (cylinders); the lots' cranes, scaffolds and timber piles; the bridge's deck, rails and piers;
* for every plot a COPY of the pack's static colliders (`add_pack`): the shapes are shared (a shape belongs to no
  space), the bodies are new bodies in this space, clipped to the plot's circle, bent at the rim exactly as the draw
  layer bends the ground, moved to the plot's place and height. Only `StaticBody3D` (the venue's ground, walls,
  stands); nothing a pack moves is copied. The pack's own bodies are not touched, and nothing in the pack's space
  can see the visitor.

His body is a kinematic capsule (0.35 m radius, 1.8 m) in that space, moved by the engine's own `test_motion`: it
lifts by a step (0.55 m), slides along what it meets, follows the ground down, and refuses a move that ends on a slope
steeper than 55 degrees. The space is not stepped (nothing in it moves; queries work).

Scripted and live. The scheduler still reads the scripted position (`player_pos`) and `world.tour` still proves
the same things (the body changes where the visitor is DRAWN, never what a pack is given). The body follows the script
position (at most 0.3 m per tick) and cannot pass an obstacle, so a script that walks him through a fence leaves him
at the fence; the `tl.view/1` line of kind `visitor` at the end of a walk says how many ticks he was held back
(`blocked_ticks`) and how far from the script he ended (`end_dev_m`). When a person walks (`--live`), the body decides and
`player_pos` is set from it. The tour's script was adjusted where it walked into things: the wall yard's gate is at x
126, the drive's rim at (0, -26).

Proof, `world.sh tour visitor_walk --out-dir=<abs dir> --pictures-only` (probes, no window needed for the result): the
paddle plot's fence from outside and from inside (stops 0.34 m short of it: his radius), its gate (passes), the bluff's
cliff face (stopped by slope 34 m short of the target), a tree, a tall rock and the bridge's rail (stopped by them), the
road's verge (passes): 8 of 8 as expected. In the tour (script adjusted as said): 0 blocked ticks, and he ends at the script's last position (`end_dev_m` 0.0).

Limits. A pack's static colliders are copied when the world is built: a wall a pack removes later is still there for
the visitor. A pack's ground is a bowl he cannot walk into where it is steeper than 55 degrees (the drive seed's rim).
Bushes, grass, flags and small rocks are walk-through. No jump, no swimming (the river is 1 m deep and he wades it).
The world's space is built by the landscape, so a world without a window has no visitor.

## What it costs (11 November, 03:40 to 04:05, other jobs running on the machine: figures under load)

Six games (`seed_drive`, `seed_wall`, `seed_paddle`, `ex_walker`, `ex_kit`, `ex_car`), 2900 world ticks, cost model,
at most two or three games at full rate at a time, the rest on a slice of 2.

| | world tick p50 | mean | p99 |
|---|---|---|---|
| headless (simulation only; the kernel's own calls into the packs: 0.55 ms p50) | 1.69 ms | 2.35 ms | 3.02 ms |
| window, 1920x1080 (simulation and drawing, the whole frame) | 2.69 ms | 5.69 ms | 10.26 ms |

Per picture the frame was 2.4 to 3.0 ms (6.8 ms on the first, while stand-ins were still being built), 141 to 508
draw calls, 0.88 to 1.67 million primitives; render CPU 0.35 ms, GPU 1.2 ms (medians over the run). The mean is above
the median because a rebuild from the seed (9 in the tour: the longest tick was 433 ms headless) and the first
stand-in of a pack happen inside one tick. The landscape is built once in 0.36 to 0.74 s (six runs): 150 pines and
46 broadleaf trees between the plots, 260 pines in the belt, 60 rocks, 110 bushes, 1600 tufts, 90 patches, 18 mesas,
two lots, about 1.9 km of fence in one mesh; trees, rocks, bushes and tufts are 10 multimeshes.

One windowed run of four printed an engine warning with the trace `CreateJob (modules/jolt_physics/spaces/
jolt_job_system.cpp:123)`; its text was not kept (the tool now prints `WARNING` lines too). Engine errors were 0 and
all six hashes were the same in that run. It did not come back.

### P4: what relief and a body cost (11 November, 11:00 to 11:30, three other builders and other jobs on the machine: figures under load)

Before = the main checkout's engine and tour script of this morning, after = this branch's, same machine, same half hour.

| | before | after |
|---|---|---|
| headless tick (p50 / mean / p99 / worst), 2900 ticks, 6 games | 1.29 / 1.47 / 2.34 / 389 ms | 1.35 / 1.56 / 2.69 / 513 ms |
| window, whole frame (median over the tour) | 3.13 ms | 2.45 ms (p99 9.3 ms, worst 921 ms) |
| window, render CPU / GPU medians | 0.45 / 1.18 ms | 0.34 / 1.23 ms |
| draw calls / primitives at the ten pictures | 159 to 454 / 0.9 to 1.6 M | 99 to 245 / 1.3 to 1.9 M |
| landscape build (once) | 0.88 s | 1.38 s: terrain 0.34 s, colliders 0.32 s, the rest (roads, fences, scatter, mesas) 0.72 s |

The simulation is not touched (the headless tick is the same within the noise: the plots stand elsewhere, so tiers
change at other ticks). The one cost that is new is the landscape's build, 0.5 s more than N7's 0.9 s, once; 47,765
terrain vertices (one draw call) and 88,812 collider triangles (a space that is not stepped). The worst frame (0.9 s)
is a game built again from its seed (the wall yard on `enter`) inside one frame, as in N7; the "before" run was
throttled to 270 ms a frame for its last 1400 frames by another builder's window at the same screen position, so only
its median is comparable. The body costs about 5 `test_motion` calls a tick (not measurable against the frame).

## The pictures (`kernel/world/captures/`, all looked at)
P4's are in `captures/p4/` (JPEG; `world.sh` writes PNG): `overview.jpg` and `vs_concept.jpg` (the concept and the
overview side by side), `tour/01` .. `10_*.jpg` (the tour's ten frames again, from the run whose proof passed),
`views/` (`slope_venue_above`, `slope_down_to_road`, `rim_venue_below` (the visitor at the lip of the drive's hollow,
the track below him), `stage_looking_out` (from the drive on stage, out at the bluff), `bridge_close`,
`valley_from_bridge`, `overview_high`, `standing_on_the_road`). N7's pictures follow.



| file | what it shows |
|---|---|
| `world_overview.png` | the village from a low hill at tick 133: a building lot with a crane, the track, the paddle court in front, the wall yard's crane, the kit yard and the car floor, mesas, the low sun |
| `world_vs_concept.png` | the concept (`spike/lab/ref/B_toon_ink.png`) and `world_overview.png` side by side |
| `far_and_near.png` | tick 63: the walker room 45 m away drawn in full (`sideline`), the track 150 m away as its stand-in (`backdrop`), the visitor on the road between them |
| `world_from_above.jpg` | the same world from a crane 120 m up |
| `tour/01` .. `10_*.jpg` | the tour's ten frames (JPEG copies; `world.sh tour` writes PNG) and `tour/world_log.json` |
| `check_from_paddle.jpg` | `view.sh check` through the host mode: the paddle court as the stage pack |

## Loading and far pictures (round 2 of the core run, 2026-11-11)

What the loading package (P5) and the far-games package (P6) added to the walk, the world line, the log and
the viewer's line. Reports: `docs/reports/P5-LOADING.md`, `docs/reports/P6-FAR.md`; details in `TIERS.md`
(section P5) and `draw/FAR.md`.

- **tl.walk/1:**
  - `events` may hold `{"t": <world tick>, "e": "reload", "plot": "<plot id>"}`: the plot's pack is replaced by a freshly loaded copy of its directory; what `_pack_save` returns is handed to the new copy.
  - `edits`: `[[<world tick>, "<file>", "<replacement file>"]]`, a test instrument.
  - `tiers.load`: `{"mode": "auto" | "queue" | "step" | "wait" | "block", "budget_ms": <number>}`.
- **tl.world/1 and tl.worldlog/1:**
  - Event `{"t": N, "e": "built", "plot": id}`: the pack was attached at this tick boundary; its first tick is N + 1.
  - The log's `tiers.load.mode` is the mode the run used.
  - The world line has `load`: `mode`, `budget_ms`, `built`, `never_built`, `waited_ms`, `in_ticks_ms`, `first_built_ms`, `six_built_ms`, `all_built_ms`, `attach_ms_p50`, `attach_ms_max`, `prepare_ms_p50`, `prepare_ms_max`, and `arrivals` as `[plot, tick, ms since the world started, prepare ms, attach ms, layouts built ahead and not used]`.
  - `load_ms` includes `in_ticks_ms`.
- **tl.view/1, tour line:** `frame_ms_p99_all`, `frame_ms_max_all`, `frames`, `frames_over_16_7_ms`, `slow_frames` ([world tick, ms], at most 40), `first_frame_ms`, `view_ready_ms`, `world_to_first_frame_ms`, `first_two_frames_ms`, `rims_measured`.
- **tl.perf/1:** metrics `first_frame_ms` and `six_built_ms`; scenario `walk30`.
- **Kit:** `TLKit.build_layout_ahead(layout) -> String` and `TLKit.drop_layout_ahead(key) -> bool` belong to the kernel's loader; a pack has no use for them.

**tiers schema:** optional `picture_far_m` (number > 0) and `margin_m.picture` (number >= 0); drawing only, never read by `decide()`.

**Walk schema, block `landscape`:** optional `relief`, `pad_rocks`, `road_trees`, `road_bushes`, `plain_clumps`.

### What a pack author must know about loading (P5)

- In a world your pack is built by a queue, nearest games first, and may arrive some ticks after the world started. Until then your plot shows its pad.
- You are not ticked before you are there, and your tick count starts at 0 when you arrive. Nothing in a pack may depend on the world's tick.
- The venue you build with `TLKit.build_layout(ctx.read_json(...), ctx.root)` is built ahead on another thread when the layout file lies under `data/` and you pass it on unchanged. A layout you change in code first is built in your `_pack_setup` as before, and costs the visitor a frame.
- Everything else in `_pack_setup` still runs on the main thread: keep it small.
- A world may replace your pack by a fresh copy of its directory at any tick (`reload`). What `_pack_save` returns is handed to `_pack_load`; nothing else survives. Keep no state in `static var`.

### What changed for a pack author (P12)

- Nothing you write changes. Rigs (`TLRigs.build`, also through `TLBiped.create` and `TLVehicle`) and kit parts
  (`TLKit.build`) your `_pack_setup` makes are built ahead on another thread from the second arrival of your pack on a
  machine on: the world remembers which calls your setup made and with which params. A call with params that differ
  from last time is built in your setup as before.
- A reload sees a changed `.gd` too: the entry script and every script it loads through `ctx.load_script` are taken as
  they are on disk at the reload.
- In a window, a game the visitor walks into (or that a walk event puts on stage) is there when he arrives, even if
  its preparation is not finished: the world builds it at once, and that frame is long.
- tl.world/1, world line `load` (queue mode): `forced`, `forced_ms`, `forced_list` as `[plot, world tick, ms, "stage" | "end"]`.

## Not built, not verified

- P11 (PATCHES-P11 8): `world.sh visit tour`, a person walks it: W S along the view, A D step aside, the mouse looks,
  Shift runs, E enters, Q leaves, Esc quits (kernel/runner/visit.gd; scripted and replayed by `world.sh visit-test` /
  `visit-proof`). No person has yet walked it for long: the keys are proven by scripts.
- P4, what is still wrong against the concept: the plots are still discs (a rink on a terrace is a round terrace); a
  bank is a smooth slope with a stone kerb at its lip, not a retaining wall or a cut rock face (the only real cliff is the
  bluff and the valley's walls); the far plain beyond the heightfield is flat and the mesas still stand on it like stacked
  prisms (the ring of hills hides them from inside the village, not from a crane); no cabin on a rise, no rock faces
  between venues but the bluff; the river is one river with no falls; the venue ground that a pack brings (the drive's
  bowl, the car's flat floor) is still the pack's.
- Plots are circles, placed by hand in the walk script; yaw on plots is still not used (the sun is not turned).
- `ledger` drawing (stand-in only) was run once in a window with a tiers file that unloads plots beyond 70 m
  (`world.sh tour tour --tiers=<file with backdrop_m 70>`): PASS, five packs unloaded and three built again, the
  pictures looked at and not kept. The tour itself keeps every pack in memory, and no selftest case draws a ledger.
- A rebuild from the seed blocks the world for its loading time (0.1 to 0.7 s for these packs under load).
- A stand-in is not rebuilt when its pack changes, and shows no moving part.
- The stage pack's HUD is on crane pictures taken while it is on stage.
- No watchdog in the world host; a world file does not yet keep `visitor` state.

## P14: an arrival in a window

- The colliders of a pack that arrives while the world is drawn are copied into the visitor's space in slices of
  2 ms a frame, nearest plot first (terrain/world_space.gd `begin_pack` / `step_pack`, draw/view_seam.gd). The rule:
  before the visitor takes a step, every plot whose edge is within 10 m of him has all its colliders (copied whole at
  once if it must be). Running at 9 m/s he needs 66 ticks for 10 m; a seed's whole copy takes 5 ms, three slices.
- The draw layer adopts an arrived holder on the next tick, not in the arrival's own frame; the holder is hidden
  until then (drawing only). A plot on stage is adopted at once.
- The caches (rims, far pictures, rig recipes) live in `PlotFile.cache_dir()` (`<user dir>/tl_cache`, or
  TL_CACHE_DIR); every key is a pack directory's content. The exe ships the caches of its games (docs/EXE.md).
