# Layout contract (lane B, pass 4)

A layout is one JSON file, `data/layout.json` (name `main`) or `data/layout_<name>.json` (run with `--layout=<name>`).
The scene is assembled from it and from nothing else; the look comes from `data/style.json`. This file lists **every key
a layout may use**. A key that is not listed here is an **error** (`tools/g.sh validate <name>`), not an ignored extra.
The machine form of this contract is the schema table in `tools/validate.gd`; change both together.

## World conventions
- Metres, Y up, forward is -Z. `[x, z]` is a ground position (the height comes from the terrain); `[x, y, z]` is a
  position whose height **you** give (the part is not snapped to the ground: put a `pads` entry of the same height under it).
- The avatar always starts at `(0, 0, 0)` facing -Z, so the ridge must pass under the origin. The play test walks it 20 m
  forward (-Z) and expects it to end below y = -8, so the valley must begin within about 20 m in front of the origin.
- Terrain = valley floor at about y = -14 (rolling by about +-3 m) + one ridge (y about 0) + flat pads + mesas.
  The near terrain is x -224..192, z -288..128: everything you place must be inside it (mesas, the river and waterfalls
  may lie further out, up to +-2600 m). The road flattens a corridor to its own height (10 m road, blends out at 20 m
  from the centre line); the river digs a channel to y = -16.2 (water surface y = -15.2, 11 m wide).
- Order of terrain rules: valley, ridge, pads, road corridor, river channel, mesas. A later rule wins, so **a mesa on top
  of the road, the arena or a house buries it** (the validator rejects a mesa that touches the circuit or the arena).
- Angles are degrees, yaw about Y, counter-clockwise seen from above. Yaw 0 = the part's long axis along X.
- The hero camera stands near the origin and looks towards -Z: the arena is expected at the upper left (negative x,
  z about -75), the circuit at the right, a house at the lower right. That is a convention of the cameras, not a rule.

## Top level
| Key | Type | Default | Range | What it does |
|---|---|---|---|---|
| `name` | string | required | | printed in the `[world]` line; a layout whose name is not `main` must bring its own cameras |
| `seed` | whole number | 7 | 0..1000000 | terrain noise and forest pattern |
| `ridge` | object | required | | the ridge the avatar stands on (below) |
| `pads` | list | required (may be `[]`) | | flat circular terraces (below) |
| `mesas` | list | `[]` | | flat-topped cliffs: skyline, buttes, hills (below) |
| `waterfalls` | list | `[]` | | falls down a mesa face (below); needs at least one mesa |
| `river` | list of `[x, z]` | none (no river) | 2 or more points, up to +-2600 | open spline, water ribbon 11 m wide in a dug channel |
| `circuit` | object | required | | the race loop, the barrier wall and the two cars (below) |
| `arena` | object | required | | the one rink with stands, roof ribs, scaffolds and bots (below) |
| `cranes` | list | `[]` | 0..8 entries | tower cranes (below) |
| `house` | object | none | | one house (below) |
| `houses` | list of house objects | `[]` | 0..12 | more houses; `house` and `houses` may both be present |
| `hero_tree` | `[x, z]` | none | near terrain | the one large broadleaf tree; the avatar cannot walk through it |
| `hero_rocks` | list of `[x, z, size, squash, seed]` | required, at least 2 | size 0.3..6, squash 0.2..1.5 | boulders that block the avatar. The play test walks the avatar into the **second** one, so it must be reachable on the ridge within about 12 m of the origin. This is also the only way to place a single rock anywhere else (along the track, in a yard) |
| `clear` | list of `[x0, x1, z0, z1]` | `[]` | x0 < x1, z0 < z1 | boxes in which no pine or broadleaf tree grows (sight lines) |
| `forest` | object | `{}` | | forest density and extra pine belts (below) |
| `props` | list | `[]` | 0..400 | dressing placed from the kit (below) |
| `cams` | object: camera name -> camera | `{}` | | named cameras (below) |

## `ridge`
| Key | Type | Default | Range | What it does |
|---|---|---|---|---|
| `a`, `b` | `[x, z]` | required | near terrain | the two ends of the ridge centre line; ground within 20 m of the segment is at y about 0 |
| `fall` | number | 17 | 2..60 | metres over which the ridge drops to the valley; 8 reads as a cliff, 25 as a hillside |
| `ramps` | list of `{c, w, fall}` | `[]` | | places where the cliff relaxes into a walkable slope |
| `ramps[].c` | `[x, z]` | required | near terrain | centre of the ramp |
| `ramps[].w` | number | 14 | 4..60 | width of the ramp |
| `ramps[].fall` | number | 24 | 8..80 | the `fall` used inside the ramp |

## `pads[]`
| Key | Type | Default | Range | What it does |
|---|---|---|---|---|
| `c` | `[x, z]` | required | near terrain | centre |
| `r` | number | required | 2..120 | radius that is fully flat |
| `blend` | number | required | 1..80 | width of the slope from the pad to the surrounding ground |
| `h` | number | required | -20..10 | height of the pad |
| `dirt` | true / false | false | | paints the pad as a dirt yard instead of grass |

## `mesas[]`
| Key | Type | Default | Range | What it does |
|---|---|---|---|---|
| `c` | `[x, z]` | required | +-2600 | centre |
| `r` | number | required | 5..300 | radius of the flat top |
| `h` | number | required | 5..200 | height of the top above the valley floor (top is at y = -14 + h) |
| `blend` | number | 20 | 1..100 | width of the flank; small = cliff, large = hill |
| `noise` | number | 14 | 0..40 | how ragged the outline is, in metres |

## `waterfalls[]`
| Key | Type | Default | Range | What it does |
|---|---|---|---|---|
| `p` | `[x, z]` | required | +-2600 | a point on a mesa top; the fall starts where the ground first drops 2 m from here |
| `to` | `[x, z]` | required | +-2600 | a point towards the pool; only the direction is used |
| `w` | number | 9 | 1..40 | width |

## `circuit`
| Key | Type | Default | Range | What it does |
|---|---|---|---|---|
| `cps` | list of `[x, z]` | required | 4..60 points, 6 m or more apart, loop of 120 m or more | control points of the closed loop, in driving order |
| `y` | number | -12 | -20..5 | mean height of the road (it rolls by about +-1.7 m) |
| `wall_at` | `[x, z]` | required | within 25 m of the loop | the barrier wall stands on the road edge nearest to this point, on the side the point is on |
| `wall_blocks` | whole number | 12 | 3..60, at most 60 % of the loop | blocks in the wall (2.46 m each); `crumble` breaks the middle ones |
| `car_a` | number | 5.0 | -500..500 | start of car A (blue), metres along the loop past the wall centre |
| `car_b` | number | -9.0 | -500..500 | start of car B (red, nitro), same measure |

## `arena`
Positions inside the arena (`scaffolds[].p`, `bots[].p`) are **arena-local**: origin at the rink centre, x along the rink,
rotated with `yaw`. The stands are on the local -Z long side. Roof ribs span the rink across Z and stand in a row along X.
| Key | Type | Default | Range | What it does |
|---|---|---|---|---|
| `c` | `[x, y, z]` | required | near terrain, y -20..10 | rink centre and ice height; put a `pads` entry of the same `h` under it (radius about 0.75 x rink length) |
| `yaw` | number | 0 | -360..360 | turns the whole arena |
| `rink` | `[length, width, corner radius]` | required | 10..120, 8..60, 0..width / 2 | ice sheet with boards, glass, goals and markings |
| `rows` | whole number | 10 | 0..20 | rows of the stands; 0 = no stands |
| `ribs` | whole number | required | 0..16 | roof arch ribs; 0 = open-air rink |
| `built` | whole number | required | 0..`ribs` | ribs 1..built (from the -X end) are steel; the rest are cyan holograms that `site_advance` builds one by one |
| `rib_dx` | number | required | 3..20 | spacing of the ribs along X (required even with `ribs` 0) |
| `rib_off` | number | 0 | -5..5 | shifts the row of ribs along X, in units of `rib_dx` |
| `apex` | number | 14 | 4..40 | height of the rib apex above the ice |
| `scaffolds` | list | `[]` | | scaffold towers |
| `scaffolds[].p` | `[x, z]` arena-local | required | | corner of the scaffold; it runs along local +X and is 1.3 m deep. The rib feet stand at local z = +-(rink width / 2 + 2.5), so z = width / 2 + 1.5 puts a scaffold against the ribs. A scaffold stands at the arena height `c.y`, not on the terrain: outside the arena pad it needs its own pad of the same height |
| `scaffolds[].yaw` | number | 0 | -360..360 | |
| `scaffolds[].bays` | whole number | required | 1..8 | bays of 2.4 m |
| `scaffolds[].levels` | whole number | required | 1..6 | levels of 2.0 m |
| `scaffolds[].decks` | list of whole numbers | required | each 1..`levels` | which levels carry a plank deck |
| `bots` | list | `[]` | 0..40 | builder bots |
| `bots[].p` | `[x, y, z]` arena-local | required | within 60 m of the rink | y is the height above the ice: 0 on the ground, 2.12 / 4.12 / 6.12 on scaffold deck 1 / 2 / 3 |
| `bots[].yaw` | number | 0 | -360..360 | |
| `bots[].state` | `"idle"` or `"work"` | `"idle"` | | `work` = welding with sparks and a light |
| `bots[].mobile` | true / false | false | | a mobile bot walks to the rib being built on `site_advance` and back |

## `cranes[]`
| Key | Type | Default | Range | What it does |
|---|---|---|---|---|
| `p` | `[x, z]` | required | near terrain | foot of the tower (the avatar cannot walk through it) |
| `h` | number | 35 | 10..80 | tower height |
| `jib` | number | 30 | 8..60 | jib length |
| `yaw` | number | 0 | -360..360 | direction of the jib |
| `trolley` | number | 0.55 | 0.1..1.0 | where the hoist and its swinging load hang, as a fraction of the jib |

## `house` and `houses[]`
| Key | Type | Default | Range | What it does |
|---|---|---|---|---|
| `p` | `[x, y, z]` | required | near terrain, y -20..10 | floor position; needs a pad of the same height (radius 8..13) |
| `yaw` | number | 0 | -360..360 | |
| `ext_side` | -1 or 1 | 1 | | which end of the house the half-built timber-frame extension stands on |
| `frame` | true / false | true | | false = no timber-frame extension |

## `forest`
| Key | Type | Default | Range | What it does |
|---|---|---|---|---|
| `density` | number | 1 | 0..4 | multiplies the pine count of the noise-placed forest |
| `edges` | list of `[x0, x1, z0, z1, pines]` | `[]` | x0 < x1, z0 < z1, pines 0..1200 | boxes filled densely with pines (they ignore `clear`) |

## `props[]`
Every prop is `{"k": kind, placement, "yaw": degrees, "a": [arguments]}`. Placement is **exactly one** of
`"p": [x, z]` (world, on the ground) or `"s": metres along the circuit` with optional `"side"` (-1 or 1, default 1 = right
of the driving direction) and `"off"` (0..60, default 8.2, metres from the centre line; the road edge is at 5, the kerb
ends at about 6). With `s`, yaw 0 faces along the road. Kinds `fence`, `site_fence`, `pond`, `bridge` need `p`.

| Kind | Arguments `a` | What it is |
|---|---|---|
| `lumber` | `[length 0.5..8, width 0.3..4, layers 1..10]` all required | stack of timber |
| `pallet` | `[rows 1..6]` optional, default 3 | pallet of blocks |
| `barricade` | none | striped road barricade, 1.9 m |
| `cone` | none | traffic cone |
| `fence` | `[end x, end z]` required | wooden rail fence from `p` to the end point |
| `site_fence` | `[end x, end z]` required | mesh site fence from `p` to the end point |
| `sign` | `[palette key]` optional, default `sign` | board on two posts |
| `flag` | `[height 2..20, palette key]` optional, default 7, `flag_a` | flag pole |
| `light_mast` | `[height 4..30]` optional, default 14 | floodlight mast with a warm light pool; blocks the avatar |
| `cabin` | none | site cabin; blocks the avatar |
| `scoreboard` | none | scoreboard on legs |
| `tyres` | `[columns 1..20]` optional, default 5 | tyre barrier |
| `marshal` | none | raised marshal post with roof, ladder and flag (3.75 m) |
| `entrance` | none | arena entrance portal |
| `watch_tower` | `[height 4..20]` optional, default 9 | timber watch tower with a roofed platform, ladder and flag; blocks the avatar (added in pass 4 after layout D asked for one) |
| `pond` | `[half size x 2..120, half size z 2..120, palette key]` first two required, default key `pond_ice` | flat irregular sheet on the ground (frozen pond, puddle, paving). It needs a flat pad under it. With the key `water` it is still water with a sand shore (a small lake; added in pass 4 after layout D asked for one); the key `ice` shows stray lines of the one rink's markings (layout D found this) |
| `bridge` | `[length 6..80, width 2..14, spans 1..8]` optional, default 26, 4.6, 3 | humpback stone bridge at river level; `p` on the river |
| `stones` | `[count 1..12]` required | row of dressed stone blocks |

Palette keys are the keys of `palette` in `data/style.json`; a key that does not exist is an error.

## `cams`
`"<name>": {"pos": [x, y, z], "look": [x, y, z], "fov": 20..90}`, all three required. The capture interface uses
`hero`, `site`, `track`, `crumble`, `avatar` (plus `map`, `avatar_front`, `avatar_back`, `avatar_side`, `face`, `bot`).
A camera missing from the layout falls back to `data/cams.json`, which holds the **main** layout's views; therefore a
layout whose name is not `main` must define `hero`, `site`, `track` and `crumble` (the avatar cameras can be inherited,
the avatar is always at the origin). Keep `pos` above the ground: the validator does not know the terrain height.

## What the validator checks
Unknown keys at every level, types, ranges, required keys, list lengths, prop kinds, prop arguments, palette keys,
positions inside the near terrain, `built` <= `ribs`, deck levels <= `levels`, bots given in world instead of arena-local
coordinates, control points too close together, a loop that is too short, a wall that is too far from the loop or too
long for it, a mesa that touches the circuit or the arena, a waterfall without a mesa, and the four cameras.
It does **not** build the terrain, so it cannot tell that a camera is under ground, that a house stands on a slope
without a pad, that two parts overlap, or that the play-test walk is blocked.

## What a layout cannot express (each needs code today)
Venue
- **More than one arena.** There is one `arena` object: one rink, one stand, one row of ribs. Two rinks side by side
  cannot be written. (The rink markings are also a single global of the one toon material.)
- **Which side the stands are on** (always local -Z), a stand on both sides, stand row depth and rise.
- **Which ribs are holograms**: always the last `ribs - built`, at the +X end. A hologram in the middle, or a hologram of
  anything that is not a roof rib (a wall, a stand, a house, a scaffold), cannot be written.
- Rib shape and span (the span follows the rink width), board and glass height, goals on or off.
- Scaffold bay width, depth and level height; cross-bracing; a ladder position.
- Crane mast width, counter-jib length, the kind of load, whether the load swings.
Circuit
- **Road width** (10 m), kerb width, **banking**, the height profile (two fixed sine waves around `y`), an open road that
  is not a loop, a second circuit, a pit lane, where the start line is.
- **Car count** (two), car colours, speeds, lanes.
- One wall only; block size, its distance from the road, and that `crumble` breaks the middle.
Actors
- **Bots that skate or follow a path**: a bot stands (`idle`), welds (`work`) or, if `mobile`, walks to the rib under
  construction. Bot size, colours (they cycle by index) and tools are fixed.
- The avatar's start position and heading, its look, a second character.
Buildings and props
- House size and design (8 x 5.6 m log cabin), the size of the timber frame, chimney smoke on or off.
- **A kit part that does not exist**: there is no hut, pier, boat, grandstand, tent, tunnel or gate other than
  the kinds listed under `props`. A prop has no scale, no colour (except `sign`, `flag`, `pond`), no height offset
  (always on the ground, so nothing can be put on a scaffold deck or a roof) and no stacking.
- Collision: blocking circles come only with ribs' footings, cranes, light masts, cabins, houses, the hero tree and
  hero rocks. A fence, the boards, a scaffold or the barrier wall do not stop the avatar, and a layout cannot declare one.
Land and water
- **A real lake or the sea.** Water exists as the river ribbon (fixed width, fixed level y = -15.2) and as the flat `pond`
  sheet prop (with the `water` key: still water and a sand rim). The sheet lies ON a flat pad: there is no basin, no depth,
  no water level key, no island, and its outline is a fixed wobbly ellipse.
- The valley floor height (-14), the ridge height (0) and half-width (20 m), a second ridge, a hill that the road climbs
  (the road flattens its own corridor), a tunnel, a cut.
- Nature counts and species: pines are placed by noise (`forest.density`, `forest.edges`, `clear` are the only handles);
  broadleaf trees (60), rocks (165), bushes (90) and grass tufts (4500) are constants; single trees or rocks cannot be
  placed except the one `hero_tree` and the `hero_rocks`.
Camera, time, events
- Time of day, weather and light are style files, not layout. Light pools exist only at light masts and houses.
- A camera is position, target and field of view: no path, no depth of field. The movie shot list (hero, site, track,
  avatar and their times) and the play-test script are fixed.
