# N7: one world you can walk through

> **Owner's rulings of 2026-11-11, after the night's build.** (1) A far game may run as slow as one sixteenth of real
> time and no slower (`slice.max` 16). (2) A far game does not have to be shown in full: the next work on distance is to
> learn what to abstract and what to hide without destroying the view. Today's stand-in (one merged still mesh, no
> moving parts) is a first guess, not the answer. (3) In a world the land between venues belongs to the world; a pack
> brings a venue, not a landscape. (4) The automatic next round is paused; starting and engaging in games is a chapter
> of its own.

Tonight's four pieces in one process and one window: many packs alive, each in its own physics space (N2,
`BENCH.md`); a scheduler that gives each pack ticks by tier (N5a, `TIERS.md`); a drawing layer that shows every pack
at its plot (N5b, `draw/DRAW.md`); the look (N1). This page says how they are joined, how a walk and a tour are
written, what a pack author must know, and what is not built.

```
bash tools/world.sh tour tour --out-dir=<abs dir>       # window, numbered pictures, tier log, hash table, PASS / FAIL
bash tools/world.sh tour tour --headless                # the same world without a window (the selftest case world.tour)
bash tools/world.sh tour tour_views --out-dir=<abs dir> --pictures-only    # the three crane pictures
bash tools/world.sh visit tour                          # a person walks it (WASD, E, Q / Esc). Not run by any test.
```

## How the pieces fit

| who | file | what it owns |
|---|---|---|
| the host | `kernel/host/host.gd`, mode `world-view` | starts the windowed world like every other mode (options in `kernel/runner/verbs.json`) |
| the world host | `kernel/world/world.gd`, `pack.gd` | the packs, their spaces, the world tick, the walk script, the world log; signals `plot_event` and `ended` |
| the scheduler | `kernel/world/tiers.gd`, `tiers.json` | every decision about who ticks, as events: `tier`, `slice`, `speed`, `leave`, `return`, `over`, `restart`, `refused` |
| the viewer | `kernel/world/draw/view.gd` | the window: listens to the world host, tells the draw layer, owns the stage switch, the cameras and the pictures |
| the draw layer | `kernel/world/draw/draw.gd` | every pack at its plot (shader offset), the plot cut, the stand-ins; never touches simulation |
| the landscape | `kernel/world/landscape.gd` | ground, road, plot edges, scatter, mesas, haze: built once, visual only |
| the visitor | `kernel/world/visitor.gd` | a biped rig and a chase camera at the world's `player_pos`: visual only, no body |

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
| `"landscape"` | `seed`, `road_half_m`, `trees`, `broadleaf`, `rocks`, `bushes`, `belt`, `patches`, `tufts`, `mesas`, `haze` (factor on the style's fog, 0.4), `fence`, `gates`, `spurs`, `lots` (`[{"at": [x, z], "radius": m}]`: fenced building sites with a crane, a scaffold and stacked timber, no game on them yet) |
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
- **You bring a venue, not a landscape.** In a world your layout is built without its far terrain and its scattered
  forest. The world draws the ground, the road to your gate, a ring of worn ground and a fence 3.6 m outside your
  radius, the trees and the mesas. Declare `footprint` in `pack.json`; no seed or example does yet, so tonight's
  radii are in the walk script.
- **A big flat floor of your own reads as a disc from above** (`ex_car`): it is cut to your radius like everything.
- **Far away you are a still picture and run slower** (TIERS.md, DRAW.md): the stand-in is taken when you are first
  far and is kept across your rounds.

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

## The pictures (`kernel/world/captures/`, all looked at)

| file | what it shows |
|---|---|
| `world_overview.png` | the village from a low hill at tick 133: a building lot with a crane, the track, the paddle court in front, the wall yard's crane, the kit yard and the car floor, mesas, the low sun |
| `world_vs_concept.png` | the concept (`spike/lab/ref/B_toon_ink.png`) and `world_overview.png` side by side |
| `far_and_near.png` | tick 63: the walker room 45 m away drawn in full (`sideline`), the track 150 m away as its stand-in (`backdrop`), the visitor on the road between them |
| `world_from_above.jpg` | the same world from a crane 120 m up |
| `tour/01` .. `10_*.jpg` | the tour's ten frames (JPEG copies; `world.sh tour` writes PNG) and `tour/world_log.json` |
| `check_from_paddle.jpg` | `view.sh check` through the host mode: the paddle court as the stage pack |

## Not built, not verified

- **No person has walked it.** `world.sh visit` (WASD, E, Q / Esc, the stage pack's bot switched off and its input
  opened to the devices) is written and has never been run: no interactive window was opened.
- The visitor has no body: he walks through fences, trees and buildings, and stands at y = 0 while a pack's own
  ground dips or rises inside its plot (he hovers at the track's rim). There is no collision between the world and
  a pack by design (separate spaces).
- The ground is flat; there are no hills, no water, no bridge. Mesas are stacked prisms.
- Plots are circles, placed by hand in the walk script; yaw on plots is still not used (the sun is not turned).
- `ledger` drawing (stand-in only) was run once in a window with a tiers file that unloads plots beyond 70 m
  (`world.sh tour tour --tiers=<file with backdrop_m 70>`): PASS, five packs unloaded and three built again, the
  pictures looked at and not kept. The tour itself keeps every pack in memory, and no selftest case draws a ledger.
- A rebuild from the seed blocks the world for its loading time (0.1 to 0.7 s for these packs under load).
- A stand-in is not rebuilt when its pack changes, and shows no moving part.
- The stage pack's HUD is on crane pictures taken while it is on stage.
- No watchdog in the world host; a world file does not yet keep `visitor` state.
