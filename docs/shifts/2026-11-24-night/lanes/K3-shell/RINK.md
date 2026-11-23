# K3 shell: the gym's rink against thirdjam's (round 2)

thirdjam HEAD 8dc713c6. `C` = `Game/Content/Cartridges/hockey.regular.cartridge.json` (copied verbatim to
`engine/packs/hokej/data/`), `RA` = `Game/Source/JamGame/Private/RinkActor.cpp`, `RAh` = `.../Public/RinkActor.h`,
`JC` = `Game/Source/JamCore/Public/JamCartridge.h`, `AP` = `tools/blender/arena/arena.py` (the goal meshes RinkActor
loads, RA:1110-1121 in the t5 build). Ours = `engine/packs/hokej/gen/tj_rink.gd`. Rink frame: x along, y across, metres;
Godot (x, up, y). Round 2 drew the boards and the goals ourselves (they were the kit's in round 1); the kit gives only
the ice sheet.

| Measure | thirdjam (file:line) | thirdjam value | ours | equal |
|---|---|---|---|---|
| outline: length, width, corner | C:116-118, RA:416-432 | 90 x 45 m, corners 3.75 m, 12 segments a corner | `outline()`, the same function | yes |
| ice top | RA:444-456 | z = 0 | the kit `rink` part's ice (no boards, glass, markings, goals, apron), lowered 0.05 m: 0 | yes |
| ice colour | RA:467 (0.80, 0.86, 0.92) under B's `MI_Ice_Night`; the film: mauve grey, median sRGB (158, 140, 150) near, (182, 168, 180) far | | the kit's `ice` key in the hall's shade: light blue (129, 169, 209) | no (DEVIATION 2) |
| boards | RAh:60, RAh:62, RA:470-490 | 1.2 m high, 0.2 m thick outward of the outline, flat top | the same, palette `boards` | yes |
| kick plate | RAh:66-67, RA:491-495, RA:550 | 0.25 m high, 2 cm proud, yellow (0.85, 0.72, 0.12) | the same, palette `yellow` | yes |
| trim | RA:506-518 | a 10 cm emissive strip on the board top's inner edge, team colours by half | none | no (visual) |
| glass, rail, stanchions | RAh:61, RAh:68, RA:520-552 | 0.9 m glass, a dark rail, posts every 3.6 m | none | no (DEVIATION 1) |
| goal line | JC:43, RA:600-610 | x = +-41, 6 cm | the same | yes |
| centre line, blue lines, centre circle | RA:603, RA:611-613 | x = 0 and +-15, 30 cm; circle r 4.5 to 4.6 m | the same | yes |
| faceoff circles, hash marks, dots | RA:622-634 | (+-35, +-7) r 4.5 m, 12 cm; hashes at c +- 0.85 from r 4.5 to 5.1; dots r 0.3 there and at (+-13.5, +-7) | the same | yes |
| crease, trapezoid, centre dot | RA:636-647 | half disc r 1.8; w/2 + 1.35 to + 2.25; r 0.15 | the same | yes |
| paint height | RA:604 | 0.6 cm | 0.6 cm | yes |
| line paint of the shipped look | RA:458-466, RA:661-665 | B's `MI_Ice_Night` paints centre, blue, goal lines, centre circle (binary asset) | RinkActor's own widths | unknown (DEVIATION 6) |
| goal opening | C:121, JC:37, AP:559-567 | 4.0 x 0.61 m: posts' inner faces at +-2.0, crossbar's underside at 0.61 | the same | yes |
| goal frame | AP:521-580 | posts and crossbar 16 cm; bottom bars, back posts, back bar, braces 11 cm; depth 1.5 m; back frame min(0.9, 0.6 h) = 0.366 m | the same (square bars; AP's clay bars are rounded and thumbed) | yes (shape no) |
| net | AP:601-632 | 3 cm cords in 25 cm cells: top lengthwise and across, back, sides | the same cords | yes |
| around the rink | the level and the rig LR_P3_Clay (stands, roof, lights; binary) | a wooden arena | a plain dark box 6 m from the boards, 16 m high (data/gym.json `hall`), floor `concrete_dark`, walls and ceiling `black` | no (stair step 5) |

The simulation's own rink (the stand-in's boards and nets: `UJamSim::BoardDistance` JamSim.cpp:885-904,
`CollideSkaterStatic` cpp:2211-2296, `SkaterRadius` 0.4) reads the same cartridge: equal by construction.

The goal against the film (`r2_sbs_film.jpg`, frames 6480 and 8670): a low wide red cage with white cords in both;
thirdjam draws exactly the sim's 4 x 0.61 m opening (the arena mesh is chosen and scaled so its opening is the sim's goal
volume, RAh comment at A119), so the low cage is thirdjam's own goal, not an error of ours.
