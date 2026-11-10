# Layout contract: `tl.layout/1`

A layout is one JSON object that describes a whole venue. `TLKit.validate_layout(layout)` checks it without building;
`TLKit.build_layout(layout, parent)` builds it under `parent` and returns
`{ok, errors[], nodes{id: Node3D}, root, cams{name: {pos, look, fov}}, spawn: Transform3D, terrain, triangles}`.
The machine form of this contract is the schema table in `kits/tl_kit_layout.gd`; change both together.
Command line: `tools/k.sh validate [file.json ...]` (exit code 1 on failure).

Rules that hold everywhere:
- **Unknown keys are errors**, at every level. The error names the allowed keys.
- **Keys starting with `_` are comments** at every level (`"_note": "..."`).
- **Lists, not singletons.** Every venue part is a list; the lists may be empty or absent.
- **Absent value = omit the key.** Never `null`.
- Every `props[]` entry is a **kit part**: `kind` is any `TLKit.list()` kind and `params` is checked by
  `TLKit.validate(kind, params)`. A new kit part is usable in layouts with no schema change.
- Every `actors[]` entry is a **rig**: `params` is checked by `TLRigs.validate(rig, params)`.
- `id`s are unique across the whole layout; they are the keys of the returned `nodes`. Parts without an `id` get one
  (`<kind><n>`). Children are addressed with a dot: `rink_a.rink`, `rink_a.rib3`, `rink_a.bot2`, `wall.block4`.

## World conventions
- Metres, Y up, forward is -Z. `[x, z]` is a position on the ground (the height comes from the terrain, or 0 without
  terrain); `[x, y, z]` is a position whose height you give.
- Angles are degrees, yaw about Y, counter-clockwise seen from above. Yaw 0 = the part's long axis along X.
  Rigs (actors) face -Z at yaw 0.
- With a `terrain`: valley floor at `base_y` (default -14, rolling by about +-3 m), ridges, flat pads, mesas. The near
  terrain is x -224..192, z -288..128 (4 m cells, with collision); everything placed by `p` must be inside it.
  Order of terrain rules: valley, ridges, pads, road corridors, river channels, mesas. A later rule wins, so a mesa on
  top of a circuit or an arena buries it (the validator rejects that).
- Without a `terrain` key the ground is y = 0 and there is **no ground at all**: bring `ground_patch` props.

## Top level
| Key | Type | Default | What it does |
|---|---|---|---|
| `schema` | `"tl.layout/1"` | required | |
| `name` | string | required | root node is `Layout_<name>` |
| `seed` | whole number 0..1000000 | 7 | terrain noise and forest pattern |
| `spawn` | `{p: [x, z], yaw}` | `{p: [0, 0]}` | where the avatar starts; returned as `spawn` (the layout places nobody there) |
| `terrain` | object | none | below |
| `rivers` | list | `[]` | `{id, points: [[x, z], ...], width 3..60 (11), y (base_y - 1.2)}`: open spline, water ribbon in a dug channel |
| `waterfalls` | list | `[]` | `{p: [x, z] on a mesa top, to: [x, z] towards the pool, w 1..40 (9)}`; needs `terrain.mesas` |
| `circuits` | list (max 8) | `[]` | below |
| `walls` | list (max 16) | `[]` | below; fracturable |
| `arenas` | list (max 8) | `[]` | below |
| `cranes` | list (max 8) | `[]` | `{id, p: [x, z], h 10..80 (35), jib 8..60 (30), yaw, trolley 0.1..1 (0.55)}` |
| `houses` | list (max 24) | `[]` | `{id, p: [x, y, z], yaw, frame (true), ext_side -1 or 1 (1), params: {house part params}}`; needs a pad of the same height |
| `ponds` | list (max 16) | `[]` | `{id, p: [x, z] or [x, y, z], yaw, rx 2..120, rz 2..120, surface "ice" or "water" ("ice")}`; needs a flat pad |
| `trees` | list (max 200) | `[]` | single trees with trunk collision: `{id, p: [x, z], species "pine", "broadleaf" or "hero", height 2..25 (9), seed}` |
| `rocks` | list (max 200) | `[]` | single boulders with collision: `{id, p: [x, z], size 0.2..6 (1), squash 0.2..1.5 (0.7), seed}` |
| `forest` | object | `{}` | `{scatter (true), density 0..4 (1), edges: [[x0, x1, z0, z1, pines 0..1200], ...], clear: [[x0, x1, z0, z1], ...]}`; `clear` boxes keep tall trees out of sight lines; needs terrain |
| `props` | list (max 600) | `[]` | below |
| `actors` | list (max 64) | `[]` | below |
| `cams` | object | `{}` | `"<name>": {pos: [x, y, z], look: [x, y, z], fov 10..100}`, all three required |

## `terrain`
| Key | Type | Default | Range | What it does |
|---|---|---|---|---|
| `base_y` | number | -14 | -60..20 | valley floor height |
| `far` | true / false | true | | the far mesh with the mountain backdrop (out to +-2560 m) |
| `ridges[]` | list (max 8) | `[]` | | raised walkable land: `{a: [x, z], b: [x, z], fall 2..60 (17), half_w 4..80 (20), h -20..40 (0), ramps: [{c: [x, z], w 4..60 (14), fall 8..80 (24)}]}`. Ground within `half_w` of the segment a-b is at `h`; `fall` = metres over which it drops (8 reads as a cliff, 25 as a hillside); a ramp relaxes the cliff into a walkable slope |
| `pads[]` | list (max 64) | `[]` | | flat circular terraces: `{c: [x, z], r 2..160, blend 1..80, h -40..40, dirt (false)}`, the first four required |
| `mesas[]` | list (max 32) | `[]` | | flat-topped cliffs: `{c: [x, z], r 5..300, h 5..200 above base_y, blend 1..100 (20), noise 0..40 (14)}` |

## `circuits[]`
| Key | Type | Default | Range | What it does |
|---|---|---|---|---|
| `id` | string | required | | referenced by `walls[].circuit` and `on.circuit` |
| `points` | list of `[x, z]` | required | 4..60 points, 6 m or more apart, 120 m or more in all | control points in driving order |
| `closed` | true / false | true | | a loop, or an open road |
| `y` | number | -12 with terrain, 0 without | -40..30 | mean road height |
| `roll` | number | 1 with terrain, 0 without | 0..3 | how much the road rolls around `y` (1 = about +-1.7 m) |
| `half_width` | number | 5 | 1.5..12 | half the tarmac width; the terrain corridor follows it |
| `kerb_width` | number | 1.2 | 0..3 | 0 = no kerbs |

The node `nodes[id]` carries the collision body (tag `asphalt`) and the metadata `tl_length`, `tl_half_width` and
`tl_centre_line` (PackedVector3Array, one sample every 2 m): what a racing rule or an AI driver needs.

## `walls[]`
Exactly one of: `circuit` + `at` (the wall follows the road edge nearest to the point `at`, on the side `at` is on,
one `barrier_wall` block of 2.46 m per step, addressed `id.block<n>`), or `p` + `yaw` (one straight `barrier_wall`
part, at most 40 blocks). `blocks` 1..60 (12), `seed`. Every block is fracturable (`Intact` / `Pieces`).

## `arenas[]`
Positions inside an arena (`scaffolds[].p`, `bots[].p`) are **arena-local**: origin at the rink centre, x along the
rink, rotated with `yaw`.
| Key | Type | Default | What it does |
|---|---|---|---|
| `id` | string | required | `nodes[id]` is the arena root; children `id.rink`, `id.stands_n` / `id.stands_s`, `id.rib<n>`, `id.scaffold<n>`, `id.bot<n>` |
| `c` | `[x, y, z]` | required | rink centre and ice height; put a pad of the same `h` under it |
| `yaw` | number | 0 | turns the whole arena |
| `rink` | object | `{}` | **params of the `rink` kit part** (length, width, corner_r, boards, glass, glass_h, markings, goals, apron) |
| `stands[]` | list (max 2) | `[]` | `{side: -1 or 1, rows 1..20 (10), row_depth, rise}`; side -1 = local -Z long side, 1 = local +Z |
| `ribs` | object | none | `{count 0..16, built 0..count (count), dx 3..20, off -5..5 (0), apex 4..40 (14), exponent 1.2..6 (2.6), holograms: [1-based rib numbers]}`. Ribs 1..built are steel; the rest, and any listed in `holograms`, are cyan holograms (not yet built, no collision). The span follows the rink width |
| `scaffolds[]` | list (max 32) | `[]` | `{p: [x, z] local, yaw, bays 1..8, levels 1..6, decks: [levels], bay_w, bay_d, level_h}`. It stands at the arena height, not on the terrain |
| `bots[]` | list (max 40) | `[]` | `{p: [x, y, z] local (y above the ice: 2.12 / 4.12 / 6.12 on scaffold deck 1 / 2 / 3 at the default level height), yaw, clip "idle", "walk", "work", "carry" or "weld" ("idle"), params: {bot rig params}}` |

## `props[]`
`{"id", "kind", placement, "yaw", "params": {...}}`. Placement is **exactly one** of
- `"p": [x, z]` (on the ground) or `"p": [x, y, z]` (your height: on a scaffold deck, a roof, the ice), or
- `"on": {"circuit": id, "s": metres along the circuit | "near": [x, z] (+ "ds": metres past the nearest point),
  "side": -1 or 1 (1 = right of the driving direction), "off": 0..60 (8.2; the road edge is at `half_width`)}`.
  With `on`, yaw 0 faces along the road.

`kind` is any kit part (see `KIT.md` for the kinds and their params). A `fence` may give `"to": [x, z]` instead of
a length: it runs from `p` to that point and follows the slope. A part tagged dynamic (`puck`, `ball`, `paddle`)
is placed as a visual with its `tl_shape`; the kernel turns it into a body.

## `actors[]`
`{"id" (required), "rig": "biped" | "vehicle" | "bot", placement as for props, "yaw", "clip", "params": {rig build params}}`.
A layout only **places and poses** a rig (first frame of `clip`); it never moves it. Movement belongs to controllers.

## What the validator checks
Unknown keys at every level, types, ranges, required keys, list lengths, enum values, unique ids, prop kinds and
prop params (through `TLKit.validate`), rig families and params (through `TLRigs.validate`), palette keys, exactly
one placement, circuit ids referenced by walls and `on`, positions inside the near terrain, `built <= count`,
hologram rib numbers, deck levels <= `levels`, bots given in world instead of arena-local coordinates, control points
too close together, a circuit that is too short, a mesa that touches a circuit or an arena, a waterfall without a
mesa, and camera shape.
It does **not** build the terrain, so it cannot tell that a camera is under ground, that a house stands on a slope
without a pad, that two parts overlap, or that a prop given by `[x, y, z]` floats.

## What a layout cannot express (each needs code today)
Venue
- A rink that is not a rounded rectangle; a stand at the short ends; a stand that is not as long as the rink.
- A hologram of anything that is not a roof rib (a wall, a stand, a house). Rib span and footing size.
- Per-crane mast width, counter-jib length and load; whether the load swings (a crane is posed, not animated).
Circuit
- **Banking**, a height profile of your own (only `y` and the fixed two-sine `roll`), a junction, a pit lane that
  branches off, the start line position (it is at s = 0, the first control point), a tunnel or a cut.
- Kerbs on one side only; a road surface other than tarmac.
Actors and behaviour
- **Anything that moves or reacts**: a bot that walks a path, a skater that skates, a car that drives, a crane that
  slews. Layouts are static; `actors[].clip` is one pose. Hooks are the returned `nodes` and the rig API.
- Team, role, AI or controller of an actor. Actor grouping.
Buildings and props
- **A kit part that does not exist** (hut, pier, boat, tent, tunnel, bench, dugout, penalty box, start gantry).
  Adding a part = a spec row + a builder branch in `kits/`; then it is a valid `kind` at once.
- Non-uniform scale or a tint of a whole part (a part has only the params its spec lists).
- A part parented to another part (a flag on a watch tower roof moves only if you compute its `[x, y, z]`).
- A trigger volume, a spawn list, a checkpoint: those are rules, not venue (kernel work).
Land and water
- **A real lake or the sea**: water is the river ribbon and the flat `pond` sheet (no basin, no depth, no island).
- A road that climbs a hill it does not flatten; an overhang; a cave; terrain outside the 416 m near square with
  collision. More than the two species of scattered trees; scattered rocks, bushes and grass counts are constants.
- Snow or ice as a terrain surface (only grass, dry grass, dirt pads, sand river banks, rock on steep faces).
Camera, time, light
- Time of day, weather and light are style files, not layout. Light pools exist only at `light_mast` and `house`.
- A camera is position, target and field of view: no path, no depth of field.
