# N7: one world you can walk through

> **Owner's rulings of 2026-11-11, after the night's build.** (1) A far game may run as slow as one sixteenth of real
> time and no slower (`slice.max` 16). (2) A far game does not have to be shown in full: the next work on distance is to
> learn what to abstract and what to hide without destroying the view. Today's stand-in (one merged still mesh, no
> moving parts) is a first guess, not the answer. (3) In a world the land between venues belongs to the world; a pack
> brings a venue, not a landscape. (4) The automatic next round is paused; starting and engaging in games is a chapter
> of its own.

> **P4 (11 November, morning): the land has height and the visitor has a body.** The world's ground is a heightfield
> (`terrain/village_terrain.gd`): rolling land, a ring of hills, a bluff with a cliff face, a low valley with a river
> and two ponds. Every plot stands on a flat pad of its own height graded into the surrounding land; roads follow the
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
| `"landscape"` | `seed`, `road_half_m`, `trees`, `broadleaf`, `rocks`, `bushes`, `belt`, `tufts`, `mesas`, `haze` (factor on the style's fog, 0.4), `fence`, `gates`, `spurs`, `lots` (`[{"at": [x, z], "radius": m, "h": pad height}]`: work yards with a crane, a scaffold and stacked timber, no game on them yet; no `h` = the land's own height there), P4: `pad_h` (per plot, the height of its pad: the SAME number as the plot's `origin` y, see PATCHES-P4 1), `river` (`{"path": [[x, z], ...], "half_m", "pond_m", "depth_m"}`: a river that ends in a pond at each end), `margin_m` (the heightfield reaches this far beyond the plots, roads and river), `cell_m` (3), `rim_band` (optional width override in metres, shared by rendering and collision), P13: `soft_patches` (150: low patches of worn earth, darker grass and meadows; their own random generator), `edges_now` (false: build the pad edges in the frame instead of on a worker, to measure; `TL_LAND_NOW=1` does the same) |
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
- **Your plot has a height.** P4: the world puts your plot on a flat pad at its own height. The grade follows the rotated footprint.
  The village aligns your ground to the pad using the median height of terrain vertices around the clip.
  Deck-only venues use the median of their wide sheets. The draw layer and visitor collider bend the outer quarter-radius (9 to 16 m by default)
  to that height. Pack walls and props near the clip can still stop someone approaching from that side.
- **You bring a venue, not a landscape.** In a world your layout is built without its far terrain and its scattered
  forest. The world draws the ground, the worn spur, short entrance rails, trees and mesas.
  Declare `footprint` in `pack.json`; a walk can also supply the size, radius and yaw. The tour takes its
  radii from the walk script.
- **The live plot cut uses each mesh's origin.** At the car lot the asphalt box is centred outside the plot, so the visitor sees grass. The distant tour picture merges the overlapping floor into a mesh centred on the plot. Its visible asphalt takes village grass at the edge.
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
| pads | Each plot's `footprint.size_m` and yaw set the flat floor. The rounded corners grade into the heightfield over 20 to 66 m according to the elevation difference. The grade eases at both ends, including where roads cross it. The triangles supporting the game through radius + 3 m stay flat. Floors without their own terrain retain their 6 cm sink. |
| roads | the main road follows the land (the land's height along it, smoothed twice over 20 m); a spur from every plot's gate climbs from the pad's height to the road's; the ground is graded flat across the road (corridor 3 m + 9 m blend) |
| water | `river`: a valley 5 m under the land round the river (36 m wide), a channel, the style's water material along it, a pond at each end |
| bridge | where the main road is within 17 m of the river over at least three of its 2 m samples (a road that only ends there gets none): a deck on the road's own profile, rails, three piers above the painted roadbed |
| scatter | trees stand on convex ground (tree lines on ridges), rocks on steep ground, none within the pad of a plot, on a road, in the river or on ground steeper than 17 to 19 degrees; 120 pines, 40 broadleaf, 46 rocks, 90 bushes, a belt of 180 on the hills (fewer than N7's 150 / 46 / 60 / 110 / 260) |

Where the plots stand moved (the pads need room and the roads a margin): the tour's plots are 100 m apart in two rows
either side of a road at z = 0 (`tour.json`). Short rails and one pennant beside the sign mark each village entrance. A live site supplies its own markers.
The main road, spurs, crane yards and meadow patches are painted into the heightfield. A spur narrows as it runs into its plot.
Only the small flowers stand above their meadow. The village material uses integer noise-corner values so neighbouring patches
of painted light meet continuously. The lighting bands, hatching and depth-based crest strokes still follow the original 3 m mesh. Grass returns around offset strips of worn ground on each game's terrain, sampling the village colours and grass detail in
village coordinates. The live mesh and its cached pictures use the same colour map.

## The visitor's body (P4)

What was chosen, and why. A pack's bodies live in a space of its own and must stay untouched; the visitor belongs to no
game. So the WORLD owns a physics space (`PhysicsServer3D`, no nodes) and puts only static things in it, built once
with the landscape:

* the terrain's triangles (88,812; a triangle is left out where a plot's own ground carries him instead; until that
  game's colliders are in, those triangles stay as the plot's pad and are taken out then: bugfix-37 D3);
* a wall matching each 1.2 m entrance rail, with the gate and the flanks open; trunks of trees and tall rocks
  (cylinders); the lots' cranes, scaffolds and timber piles; the bridge's deck, rails and piers;
* (night of 21 Nov 2026, lane L1: crisp cel's things are solid) the road's rails of a style with `detail.road_rails`
  (`terrain/road_rails.gd`: one wall per drawn stretch, 1.25 m from each post's foot, tag `rail`; every open span is
  open here too: the one in nine, the spur mouths, the bridge, the river, 9 m round a plot's gate, wherever a plot or
  lot reaches the row); each plot's and lot's gate marker, its sign and flag where `detail.sign_out` stands them
  (`village_parts.gd marker_solid`: one 1.5 x 1.9 x 0.38 m box, tag `sign`); every bush he cannot step over (1.1 x
  its radius x scale tall, at least 0.6 m: a cylinder of 0.75 x radius x scale, tag `bush`), except one whose cylinder
  would reach onto a road (the scatter lets a roadside bush lean over the verge: solid, it narrowed the road and was a
  block beside the rails he could stand on); a construction site's
  sign and plan board stand on solid posts (site/draw.gd `_posts`; he walks under the boards);
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
the visitor. Authored obstacles can stop a crossing, and slopes above 55 degrees can make the visitor slide.
Grass, small bushes (under 0.6 m) and small rocks are walk-through; since 21 Nov a bush he cannot step over, the road's
rails and the gate's sign and flag stop him (a jump of 1.0 m does not clear a 1.25 m rail). None of these is in any
pack's space: no state hash can move by them. Proof: `tools/selftest.d/620-harden.sh` (`harden.*`, headless, the exe's
village under crisp, and the compact village of walks/wf_feel.json): 193 and 199 places along the drawn rails stop him, the 19 open spans let him through, 10 gate markers
and 50 bushes stop him, kit parts copied as a game's colliders stop him or let him through as drawn, and the spawn and
every plot's gate (where Q puts him) are clear of every collider. The probe `road_verge_walk` of
`walks/visitor_walk.json` walks at z = -4, the row of rails under crisp: it is stopped by `rail` there now (classic
has no rails). No swimming (the river is 1 m deep and he wades it).
The world's space is built by the landscape, so a world without a window has no visitor.

### A person's body has weight (walker-feel, 18 Nov 2026)

When a person walks (`--live`, a record replayed), `walk()` is no longer used for him: kernel/runner/visit.gd hands the
visitor a WISH each tick (the velocity he asks for, and whether Space or C went down) and `world_space.gd drive()`
moves the body by velocity. Every number counts ticks at 60 Hz (constants at the head of drive()):

| | |
|---|---|
| ground | accel 34 m/s^2 (rest to 4.5 m/s in 8 ticks, 4.5 to 9.0 in 8), decel 42 m/s^2 (9 to 0 in 13 ticks, 0.89 m); a key tapped from rest is held 9 ticks (a 6-tick tap moves 0.62 m: a step); a biped brake cancels the held step, including when downed. The standing capsule holds still on a bank. Pushing straight into a wall stops him at its face |
| pad swap | when a game's walkable floor replaces the pad through his feet, the standing visitor rises onto it on the first tick if he fits and the lift is within one step (0.55 m) |
| narrow V | when two steep walls together stop his descent, he can stand, jump and walk along the channel, including over triangle seams. Downhill travel along the crease continues while he is sliding |
| down | a step down of 0.35 m is followed; more is a FALL (gravity 24 m/s^2, at most 40 m/s); the capsule's round foot on an edge is told from a slope by a ray under its middle |
| jump | Space: 6.93 m/s up, 0.94 m high, 33 ticks in the air on flat ground; coyote 6 ticks after walking off an edge, a press kept 8 ticks after the tick it went down (pressed up to 8 ticks before landing it jumps on the landing tick); from a slope too, pushed 4.5 m/s away from the face (out of a steep pit, never up a steep bank by hopping) |
| steep | ground steeper than 55 degrees: walking up into it is refused (a wall, as before); walking down onto it, landing on it, or being put at rest on it starts a SLOPE SLIDE: gravity along the slope, friction 3 m/s^2, at most 14 m/s, steering 4 m/s^2 across it, until he stands on walkable ground |
| run slide | C while grounded and faster than 6 m/s: his speed is kept and decays by 7 m/s^2, a little steering, ends below 2.6 m/s or after 70 ticks (from 9 m/s: 54 ticks, 5.3 m; a plain stop takes 0.97 m); with W held he runs on |

The figure turns toward his travel (a share of 0.22 of the remaining turn per tick); the camera follows the mouse only.
A and D are no longer a sidestep with the face to the camera: the biped rig reads speed, not direction, so a sidestep
showed its forward cycle sliding sideways. Lane walker (19 Nov): the gait now steps sideways and backward, and what A and D
do is the owner's question, so `TL_AD_KEYS` picks it (kernel/runner/visit.gd): absent or `face` as above; `sidestep` the figure
keeps facing where the camera looks (A, D and S step sideways and back); `turn` A and D turn him and the view 150 degrees a
second. A record replays with the value it was made with. The rig hears `set_locomotion(velocity in its own axes, grounded)` every tick
and the clips `jump`, `land`, `slide` (held), `slope_slide` (held) and `&""` at a slide's end (also when a game goes on stage during a slide, and on `put`), each only if `rig.clips()`
has it. A scripted walk (a tour) still uses `walk()` and the scripted position: nothing a pack is given changed.

The camera (`TLChaseCam`, opt-in options, a pack's camera is unchanged): it orbits a smoothed anchor (0.45 of the way
per tick across, 0.18 in height: a jump or a landing is eased, a mouse turn keeps the distance exact) and never enters
the world's space: a sphere of 0.3 m is cast from the point looked at (1.7 m over his feet) to the wanted place; it
stands where the sphere stops (pulled in at once, back out by 0.12 of the way per tick); when that is nearer than
2.5 m it is first swung up round the point looked at (10 degree steps, at most 80 degrees over the horizon) so over an
edge it looks down at him. Near plane 0.05 m. Round 2: trees' crowns are in the world's space too, for the camera only (collision layer 4, a
cylinder of 1.9 s from 2.2 s to 8.0 s over the foot, s = the tree's scale): the body, the probes and `ground_at` ask
layer 1 and pass under them as before; the visitor's camera asks 1 | 4, so a crown between him and the camera pulls
the camera in front of it (`walk.canopy`: the view through a crown in 221 of 360 ticks before, 0 after). Physics interpolation is on (`project.godot`): between two ticks the
figure and the camera are drawn where they are between them; `put`, `setup` and `snap` reset it after a teleport.

Proof: `tl.sh selftest walk.` (headless, kernel/world/walks/walk_case.gd: idle on banks of 20, 35, 50 degrees for 600
ticks moves him 0.0000 m; jump; ledge; steep bank; pace; run slide; the camera over a hill) and the scripted windows
`world.sh visit-test wf_feel --devices=<walks>/wf_feel.devices.json` and `wf_bluff` (the bank, the camera, a jump, a
run slide; the bluff's face: before, he crept down it at 3.5 m/s with no key held; now he slides down and stops).

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

## S: the construction site (engine-world-next, 17-18 November)

A lot of the village shows a Foreman job being built, from that job's own log, and the promoted game ARRIVES on it
(vision layer L5, docs/FEASIBILITY.md). Files: `site.gd` (the model, owned by the world host), `site/log.gd` (the log
read and folded), `site/draw.gd` (the look, built by the landscape), `site/fixtures/` (a failed job, a promoted job
with its game, the selftest walk), `walks/site.json` (one still per stage). Selftest cases `site.*`.

**Walk, block `landscape`, per lot** (all optional; unknown keys are errors; absent = today's decorative lot):

| key | meaning |
|---|---|
| `job` | a job directory (contracts/JOB.md), relative to the repository root or absolute. Only `job.jsonl` and `promoted/` are read; nothing is written there. No `job.jsonl`: a plain lot and a warning (`[site] warning: ...`) |
| `replay` | `{"ticks_per_event": N}`: the log is shown one event every N world ticks (deterministic: walks, stills, tests). Without it the site is LIVE: the file's size is looked at once every 60 world ticks and the whole lines that are new are read (a torn last line waits) |

**What it shows** (the log's own words; the states are the log's): no `job_created` yet: the fenced pad; the job's
title on a sign outside the fence by the gate; `plan_set`: one bay per package in the plan's order; each bay by its
last `package_state` (`queued` waiting: a slab and timber; `running` building: walls and a scaffold; `verifying`
checking: higher walls, a full scaffold, a beacon; `blocked` on hold: barricades; `promoted` built: a finished house
with a flag; `failed`: low walls behind red barricades); a package merged before and opened again keeps its house and
gets a scaffold; a package stands finished while it has merged files (`merge.files` add, `merge.removed` take away:
the Foreman's restore after a change that was not made, `files: []` with `removed`, takes a bay back down); the sign says "N of M built"; a crane turns to the bay being built. A job whose last `job_state` is
`failed` or `cancelled` and that promoted nothing: "This game could not be finished." A promotion: the scaffold comes
down, the sign says "Ready. Walk in and press E to play.", the game stands on the lot.

**Arrival.** With a build queue (tiers `load.mode` auto, queue, step or wait) a site lot whose log is there is a plot
of the world from the start, appended after the walk's plots: id `site_<lot index>`, radius = the lot's, origin =
the lot's `at` and `h` (give a site lot its `h`: without it the plot's origin is at height 0), footprint 2r x 2r. The
plot is HELD until the log's last `promoted` event names a pack under `promoted/`: its holder has no manifest (the
queue never builds it) and its size is negative for the scheduler (nobody stands in it, it is not entered). On the
promotion the holder takes the pack's manifest, the plot gets its size back, and the queue builds it like any other
arrival (`built` in the world log; a replay does the same). A later promotion is a `reload` from the new directory.
`block` mode: no plot is reserved (warning); the lot stays plain. The site is presentation and never in a hash; the
arrived game hashes as alone (`site.arrival`: tour = alone = replay). Its report: one line `[site] {json}` at the
world's end (stage, events read, packages, stage ticks, reads and their time).

**Measured** (17 Nov, machine busy): live mode in the village check (4000 ticks, the 11 Nov hockey log of 331 events,
116 KB): 67 looks at the file, 23.9 ms in all, most of it the first read; the selftest's live job: 7 looks, 1.57 ms.
The 11 Nov hockey game (built against the 0.1 kernel) loads on today's kernel: smoke 600 frames, 0 errors; its rink
(60 x 30 m, apron 3.5) fits a lot of radius 40 (half-diagonal 38.3 m).

**S2 (18 Nov).** The scaffold is solid: `site/draw.gd` puts one box per bay (slab, walls or house, scaffold; its
height by the package's state) and one for the crane's foot into the visitor's space under the tag `site <lot>`,
rebuilt when the view changes, and takes them all away when the game arrives (`terrain/world_space.gd`
`remove_tag`, the space's only removal). A walk's `visitor_probe` entry may carry `t` (a world tick; entries in
order): it is run then (selftest `site.solid`). The exe follows a running job: `-- --site-job=<abs job dir>`
(docs/EXE.md). Arrival time measured (S2.md): the worker starts the promoted game's preparation within 1 ms of the
release and the game is attached on the next tick after it (hockey: 611-615 ms, against 663-695 ms to load it
alone); a test window runs unpaced (about 740 ticks a second), so the same 0.6 s read as 450 to 510 ticks.

**B2 (night of 21 Nov 2026, lane L1): the site fence follows the footprint.** The round fence went on 19 Nov (editor
round 2) and the yard stood open; the owner's pick of 20 Nov is a fence on the footprint. While the game is being
built, `site/draw.gd _hoarding` fences the square of the lot's pad (landscape.gd pads a site plot with its footprint, 2r
x 2r turned by the player's yaw), 1 m inside its edge, in the construction frame, open for 7 m where the line from the
centre to the gate meets it: the timber rail fence of the plots' entrances (`TLKitSite.add_fence`, 1.2 m, built on a
worker once per size and yaw) and one 1.2 m box per straight stretch in the visitor's space (tag `site <lot>`). When
the game arrives it comes down with the scaffold. The site's sign and plan board stand on solid posts (`_posts`); he
walks under the boards. Proof: `harden.site_fence` (unturned and turned 30 degrees: stopped from behind, in through the
gate along the path), `harden.site_sign`, `site.no_ring` and `site.editor_yaw` (body counts named there).
**S3 (18 Nov).** The lot fits its game: when the log already names a promoted game (a finished job, a replay), the
site plot's radius is the half-diagonal of that pack's `footprint` + 4 m (at least 12, at most the walk's radius; a
pack without a footprint keeps the walk's radius; a job that promoted nothing yet too). The packages are listed on
a board "The plan" beside the sign (state word and title, by state colour); the bays carry no text. When the game
arrives an entrance arch with its title stands over the gate, with flags and two light masts.
**S4 (18 Nov).** Any game fits, any time. Once the arrived game is built the site measures it (site.gd `_measure`:
the farthest ground distance from the plot's centre of what it drew; the meshes are listed on the main thread, their
vertices read on a worker) and the lot takes that radius (ceil, at least 12, at most the plot's); the measured
extent decides over a declared `footprint`, which only sizes the lot before the game is built. The landscape no
longer fences a site plot: site/draw.gd draws the fence at the lot's current radius (solid, gate open 4 m each
side) and a path in from the plot's gate; the meshes that depend only on the size (fence, arch, masts) are built on
a worker once per size, so a refit costs the frame about 1.2 ms. Measured: crates 18.1 m (declared 12 x 32 m),
hockey of 11 Nov 40.3 m (declared none). Selftest `site.refit`.
**S5 (18 Nov).** One ring per site: a measured extent is kept in the world's cache (`site_extent.json` in
PlotFile.cache_dir(), keyed by the promoted pack's content, shipped in the exe's cache like rims and far pictures);
a world that finds it starts the lot, and so the landscape's pad, bank and worn ring, at that size. The scheduler's
footprint stays the one read from files, so ticks and hashes never depend on a cache. A live refit still moves only
the fence and dressing (the pad is in the terrain mesh, built once). Selftest `site.ring`.
**Not built:** the site does not show `question`, `milestone` captures or comments; a live site does not see a job
directory that appears after the world started.
## Dungeons: the second world (L4, night of 21 Nov)

The owner's two-worlds principle: the main world is the sandbox (the village, its plots, its construction sites); a
**dungeon** is a standalone game level with its own mechanics, untouched by the main world and not touching it. Entered
from the main menu, it is its own scene: the world is not loaded while it runs, and the avatar, camera, HUD and look are
the dungeon's.

**What a dungeon is in the engine.** A dungeon is one pack alone, in the game's own process: `engine/kernel/dungeon/
dungeon.gd` drives the same lifecycle core the lone worker and a world's holder drive (`kernel/runner/pack_life.gd`), in
the worker's frame order, in mode `play`. The gate law "a game in a world plays as it does alone" has a third side now:
a game in a dungeon plays as it does alone too. A counted dungeon (`-- --dungeon=<dir> --frames=N`) hashes as
`worker --mode=play --frames=N` (selftest 640 `dungeon.hash_alone`: hockey, parkour, the paddle court; the exe and the
editor binary agree, `export.sh check` step 1b).

**Physics.** The pack runs in the viewport's default space (as alone; no world exists to share it with), with the
project's global gravity and the kernel's laws (`TLLaws` on every body, as alone). A dungeon "adopts the law of physics
of the main world" by construction: the same kernel, the same tables. What a pack builds inside it is its own.

**Look.** A dungeon names its look in `engine/boot/dungeons.json` (`look`: a `TL_STYLE` name, crisp, classic, diorama,
overcast); without it, the default. `TLStyle` is process-wide and static, so the dungeon loads its style file on entry
and loads the default again on leaving (`TLStyle.load_style`); the sun, sky and post of the look are installed under
the dungeon's own node and freed with it.

**Avatar, camera, HUD.** No visitor: the walker is not loaded. The pack's player is the body; its `TLCameras` views and
its `TLHud` layers are the screen. Hockey shows its own start panel (level, mode), its rink camera and its score line.

**Entering and leaving.**
- From the main menu: Dungeons, pick one. A load screen with the title (half a second, then the load in steps under a moving bar, L4b),
  then the game. Esc: the pause card (Resume, Leave), the tree and the physics paused. Leave: the pack's teardown,
  every node of the pack freed, the default look back, the menu.
- From a second process (Create's "Try it", lane L3): `kernel/dungeon/dungeons.gd` `launch(<job dir>/pack)` starts the
  running executable with `-- --dungeon=<dir>`; its card says "Back to Create" and ends that process.
- World and dungeon never coexist: World's Esc returns to the menu (the world and its viewer freed, its logger
  removed), and a dungeon is opened from the menu.

**Leaks, measured.** Three round trips menu -> World -> menu -> dungeon -> menu (selftest 640 `dungeon.trips`
headless; the same in a window with scripted keys): after the first round trip nothing grows (nodes and resources
equal, objects +10 of 2000, static memory +0.1 MB, video memory +0.25 MB in the window). The first world and the first
dungeon leave caches behind (scripts, shaders, the shadow atlas). The three worlds' games hash alike, and the dungeon
between them hashes as alone each time: a dungeon leaves nothing in the process that changes the world after it.

**The watchdog (L4b).** The runner's own rule, reused: every call into the pack is watched from a thread with the
worker's limits of processor time (`kernel/dungeon/watch.gd` over `kernel/host/cpuclock.gd`). A runaway step ends the
process, which first starts the game again on a trip record: the person meets a card "<title> was stopped by the
watchdog" with Leave. More than 20 script errors stop the dungeon in place under the same kind of card.

**What a dungeon does not have yet.** No input record; a pack cannot yet declare its own avatar, its look or its menu card (a proposal for `pack.json` is in
the L4 report); no in-process switch from Create (Try it is a second process); no sharing of a dungeon with a friend.
