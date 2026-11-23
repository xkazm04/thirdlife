# K3 shell: the gym's rink against thirdjam's (round 1)

thirdjam HEAD 8dc713c6. `C` = `Game/Content/Cartridges/hockey.regular.cartridge.json` (copied verbatim to
`engine/packs/hokej/data/`), `RA` = `Game/Source/JamGame/Private/RinkActor.cpp`, `RAh` = `.../Public/RinkActor.h`,
`JC` = `Game/Source/JamCore/Public/JamCartridge.h`. Ours = `engine/packs/hokej/gen/tj_rink.gd` (the kit `rink` part for ice
and boards, the markings and nets drawn from RinkActor's numbers). Rink frame: x along, y across, metres; Godot (x, up, y).

| Measure | thirdjam (file:line) | thirdjam value | ours | equal |
|---|---|---|---|---|
| length, inner face of the boards | C:116 | 90 m | kit part built 90.2 m with its 0.2 m boards centred on its outline: inner face at x = +-45.0 | yes |
| width | C:117 | 45 m | built 45.2 m: inner face at y = +-22.5 | yes |
| corner radius | C:118 | 3.75 m | built 3.85 m: inner face 3.75 m | yes |
| corner arc tessellation | RA:446 `Outline(..., 12, ...)`, RA:416-432 | 12 segments a corner | kit `rrect(..., 7)`: 7 segments (chord sag 2.4 cm against 0.8) | no (visual, 1.6 cm) |
| ice top | RA:444-456 (z = 0) | 0 | kit ice top 0.05, part lowered 0.05: 0 | yes |
| board height | RAh:60 | 1.2 m | kit boards to 1.12 m plus a steel cap to 1.2 m | yes (top) |
| board thickness | RAh:62 | 0.2 m | kit slab 0.2 m (cap 0.28 m: 4 cm proud each side) | yes (cap no) |
| glass | RAh:61 | 0.9 m over the boards | **none** (DEVIATION 1) | no |
| kick plate | RAh:66-67, RA:491-495 | 0.25 m high, 2 cm proud, yellow (0.85, 0.72, 0.12) | kit `boards_kick`: 0.29 m, flush, red | no (visual) |
| stanchions | RAh:68, RA:526-549 | every 3.6 m, 5 cm square, board top to 2.14 m | none (the kit's go with its glass) | no |
| goal line | JC:43, RA:600-610 | x = +-(L/2 - 4) = +-41, 6 cm (Strip half width 3 cm) | x = +-41, 6 cm | yes |
| centre line | RA:603 | x = 0, 30 cm | same | yes |
| blue lines | RA:611-612 | x = +-L/6 = +-15, 30 cm | same | yes |
| centre circle | RA:613 | r 4.5 to 4.6 m, blue | same | yes |
| end-zone faceoff circles | RA:622-631 | centres (+-(GL - 6), +-min(7, 0.3 W)) = (+-35, +-7), r 4.5 m, 12 cm line | same | yes |
| hash marks | RA:632-633 | 4 a circle, x = c +- 0.85, from r 4.5 to 5.1, 12 cm | same | yes |
| faceoff dots | RA:630, RA:634 | r 0.3 m at the circles and at (+-(L/6 - 1.5), +-7) = (+-13.5, +-7) | same | yes |
| crease | RA:636-640 | half disc r 1.8 m on the goal line facing the centre, blue fill, 12 cm red rim | same | yes |
| trapezoid | RA:641-644 | goal w/2 + 1.35 m at the goal line to + 2.25 m at the end boards, 12 cm | same | yes |
| centre dot | RA:647 | r 0.15 m | same | yes |
| paint height | RA:604 | 0.6 cm over the ice | 0.6 cm | yes |
| line paint of the shipped look | RA:458-466, RA:661-665 | device B's `MI_Ice_Night` paints centre, blue and goal lines and the centre circle itself (A's sections 0 and 1 hidden); its widths are in a binary asset | A's own widths (30 cm, 6 cm) | unknown (DEVIATION 5) |
| goal opening | C:121, JC:37 | 4.0 m wide, 0.61 m high | same | yes |
| net depth | JamSim.h:506 | 1.5 m behind the goal line | same | yes |
| net frame | RAh:69, RA:850-860 | 14 cm bars: posts, crossbar, side and back bottom bars; back frame at min(0.9, 0.61 x 0.9 / 1.5) = 0.366 m | same | yes |
| netting | RA:864-867 | a net-mesh material on four quads (see-through) | cords 1.8 cm every 0.25 m on the same four faces | no (DEVIATION 4) |
| arena: benches, penalty boxes, scorer's table, goal lights, board caps, stands, roof, lights | RA:880-1090, the level | present | not built (stair step 5); the kit part adds a 3.5 m concrete apron, the style its sky and ground | no |

The simulation's own rink (the stand-in law's boards and nets: `UJamSim::BoardDistance` JamSim.cpp:885-904,
`CollideSkaterStatic` cpp:2211-2296, `SkaterRadius` 0.4) uses the cartridge's 90 x 45 x 3.75 and the nets 4 x 1.5 at
x = +-41: equal by construction (it reads the same cartridge file).
