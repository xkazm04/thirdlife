# The kit (`TLKit`, kernelApi 0.1)

Everything is generated from GDScript at load time: no imported asset, no hand-made file. The look is lane B of
Phase A (inked low-poly, flat-band toon); the generators are ported from `spike/lab/b/src/`.
This directory, `rigs/` and `style/` reference nothing outside themselves: move the three together.

```gdscript
TLKit.list()                              # PackedStringArray of part kinds
TLKit.spec("rink")                        # {params: {name: {type, default, min, max, enum, doc}}, material, fracturable, doc}
TLKit.validate("rink", {"length": 40})    # PackedStringArray of readable errors; empty = valid; unknown params are errors
var part: Node3D = TLKit.build("rink", {"length": 40, "width": 20})   # null + push_error when the params are invalid
TLKit.hash(part)                          # same kind and params -> same string (meshes, transforms, collision, tags)
TLKit.triangles(part)                     # triangle count from the generators (works headless)
TLKit.validate_layout(d) / TLKit.build_layout(d, parent)              # see LAYOUT.md
```
No set-up call is needed: the style file is loaded on first use. A part has no position param: set `part.transform`.

**In a pack** (declare the capability `kit`): build the venue with one `TLKit.build_layout(ctx.read_json("venue.json"),
ctx.root)` call (`LAYOUT.md`; its `props[]` are these parts), and single objects with
`ctx.root.add_child(TLKit.build(kind, params))`. Look in the table below before you make a box: a floor is a
`ground_patch`, a wall a `barrier_wall`, a box a `crate`, planks `lumber`, a ball `ball`. A static part needs nothing
more (the kernel gives its bodies friction and bounce); `ball`, `puck` and `paddle` go to `TLBall.create({"part": p})`
or `TLBodies.from_part(p)`; `barrier_wall` and `crate` to `TLFracture.attach(p)`. Only for a shape no part gives use
`TLBodies.make(shape, dims, material_id, {"color": ...})`: the kernel gives it the same toon material. Never create a
`StandardMaterial3D`, a light or an environment in a pack.

## Node convention of a built part
- Root `Node3D` named after the kind, metadata `tl_kind` (String) and `tl_params` (Dictionary: defaults + yours).
- Visuals: `MeshInstance3D` children (materials from `TLStyle`; under `--headless` a stub material).
  Every mesh carries metadata `tl_hash` (SHA-1 of the generated vertex data) and `tl_tris`.
- Collision: zero or more `StaticBody3D` children, each with `CollisionShape3D`s and metadata `tl_material`
  (one of the 14 material ids of the contract). One part can have several bodies with different tags
  (the rink: `Ice` ice, `Apron` concrete, `Boards` plastic, `Glass` glass, and two `goal` child parts).
- **Fracturable** parts (`barrier_wall`, `crate`): child `Intact` (mesh + static body) and child `Pieces` (hidden;
  one `MeshInstance3D` per piece, positioned at the piece centre, with metadata `tl_shape` = `ConvexPolygonShape3D`
  in the piece's own space, `tl_material`, `tl_mass_hint` in kg). The kit never creates rigid bodies.
- **Dynamic props** (`puck`, `ball`, `paddle`): no body at all. The root carries `tl_dynamic` = true, `tl_shape`
  (a `Shape3D`), `tl_shape_offset` (Vector3: where the shape centre sits in the part), `tl_material`, `tl_mass_hint`.
  The kernel makes the body. (This is an addition to the contract text: see the WP2 report, question 1.)
- Extra tags: `goal` has `tl_mouth` = `{width, height, depth}` (for a goal sensor); `road_spline` has `tl_length`;
  a `pond` with `surface: water` has no body and `tl_material` = `water` on the root.
- Lights (`house`, `light_mast`) are child nodes of the part and are skipped under `--headless`.
- Variation comes only from the `seed` param (a seeded generator inside `TLMesh`); no part calls a global random
  function or reads a clock.

## Adding a part
1. Add a row to `TLKit.PARTS` in `tl_kit.gd`: `"kind": [doc, material id, fracturable, {param: [type, default, min, max, doc]}]`
   (types: float, int, bool, enum, key = palette key, points, ints).
2. Add a branch to `TLKitParts.make` in `tl_kit_parts.gd`: emit geometry with `TLMesh` (`box`, `bar`, `hull`, `prism`,
   `cyl`, `blob`, `rbox`, `capsule`, `loft`, `sweep`; palette keys are the keys of `style/style.json`), then
   `mesh(n, mk)` and a body: `auto_box(n, mk, "wood")`, or `body(n, id)` + `box` / `cyl` / `hull` / `trimesh`,
   or `fracture(...)`, or `dynamic(...)`.
3. `tools/k.sh selftest part` builds it from defaults and from random valid params and checks the convention;
   `tools/k.sh sheet parts` shows it; `tools/k.sh docs` regenerates the tables below.
The part is then a valid `props[].kind` in every layout with no schema change.

## Files
| File | What |
|---|---|
| `tl_kit.gd` | `TLKit`: API, spec table, param validation, hash |
| `tl_kit_parts.gd` | `TLKitParts`: one builder branch per kind, collision helpers, `fracture`, `dynamic` |
| `tl_mesh.gd` | `TLMesh`: the mesh generator toolbox (flat-shaded primitives per palette key, one surface, content hash, merge) |
| `tl_kit_arena.gd`, `tl_kit_site.gd`, `tl_kit_house.gd`, `tl_kit_nature.gd`, `tl_kit_road.gd`, `tl_kit_wall.gd` | lane-B geometry generators the builders call |
| `tl_kit_path.gd`, `tl_kit_terrain.gd` | spline and terrain (layouts only) |
| `tl_kit_layout.gd`, `tl_kit_layout_build.gd`, `LAYOUT.md` | `tl.layout/1` validator, builder and contract |

<!-- generated below: do not edit by hand -->

## Parts (36)

| Kind | Material tag | Fracturable | Triangles (defaults) | Bodies | What it is |
|---|---|---|---|---|---|
| `ground_patch` | grass |  | 12 | Body (grass) | Flat rectangular slab of ground, top at y = 0. The floor of a small venue. |
| `road_spline` | asphalt |  | 3360 | Body (asphalt) | Road ribbon along a spline, with red/white kerbs, edge lines and concrete aprons. |
| `kerb` | concrete |  | 176 | Body (concrete) | Straight red and white kerb along X. |
| `barrier_wall` | concrete | yes | 1614 | Body (concrete) | Concrete barrier wall along X, pre-fractured (Intact / Pieces). |
| `rink` | ice |  | 3192 | Ice (ice), Apron (concrete), Boards (plastic), Glass (glass), Frame (steel), Net (fabric), Frame (steel), Net (fabric) | Ice rink centred on the origin, long axis X, ice surface at y = 0.05. Boards, glass, markings and goals are options. |
| `stands` | concrete |  | 19688 | Body (concrete) | Raked spectator stand along X, rising towards -Z. Its front edge is at z = 0. |
| `arch_rib` | steel |  | 404 | Footings (concrete) | Roof arch rib in the YZ plane (feet at z = +-span), optional purlins towards -X, optional concrete footings. |
| `scaffold` | steel |  | 944 | Decks (wood), Frame (steel) | Scaffold tower: corner at the origin, runs along +X, depth along +Z. |
| `crane` | steel |  | 3168 | Body (steel), Base (concrete) | Tower crane. Children: Tower, Slew (turn it about Y) / Jib, Slew/Hoist (slide along X) / Load. |
| `house` | wood |  | 2236 | Body (wood) | Log cabin with a shingled gable roof, chimney, windows and porch. Centred on the origin, floor at y = 0. |
| `timber_frame` | wood |  | 1316 | Body (wood) | Timber frame of a building under construction (posts, beams, rafters). |
| `tree` | wood |  | 80 | Body (wood) | A tree. Collision is the trunk only. |
| `rock` | stone |  | 160 | Body (stone) | A boulder. |
| `bush` | grass |  | 160 | none | A bush (no collision). |
| `fence` | wood |  | 308 | Body (wood) | Fence from the origin along +X. |
| `light_mast` | steel |  | 1384 | Body (steel) | Floodlight mast with a warm light pool (the light is skipped in headless). |
| `sign` | wood |  | 128 | Body (wood) | Board on two posts. |
| `flag` | steel |  | 72 | Body (steel) | Flag on a pole. |
| `scoreboard` | steel |  | 300 | Body (steel) | Scoreboard on legs. |
| `tyre_stack` | rubber |  | 480 | Body (rubber) | Tyre barrier: columns of stacked tyres along X. |
| `watch_tower` | wood |  | 848 | Body (wood) | Timber watch tower with a roofed platform, ladder and flag. |
| `pond` | ice |  | 22 | Body (ice) | Flat irregular sheet: a frozen pond (collision tag ice) or still water with a sand shore (no collision; tag water on the part). |
| `bridge` | stone |  | 1904 | Body (stone) | Humpback stone arch bridge along X, deck ends at y = 0 above water at y = 0. |
| `lumber` | wood |  | 1080 | Body (wood) | Stack of timber. |
| `pallet` | wood |  | 572 | Body (wood) | Pallet of blocks. |
| `cone` | plastic |  | 100 | Body (plastic) | Traffic cone. |
| `barricade` | wood |  | 576 | Body (wood) | Striped road barricade. |
| `cabin` | steel |  | 620 | Body (steel) | Site cabin. |
| `marshal_post` | wood |  | 280 | Body (wood) | Raised marshal post with roof, ladder and flag. |
| `entrance` | concrete |  | 324 | Body (concrete) | Arena entrance portal. |
| `stones` | stone |  | 176 | Body (stone) | Row of dressed stone blocks. |
| `goal` | steel |  | 492 | Frame (steel), Net (fabric) | Hockey goal: frame at x = 0, opening faces -X, net extends towards +X. Bars are steel, the net is a fabric body. |
| `puck` | rubber |  | 52 | none: dynamic, `tl_shape` on the part | Hockey puck. Dynamic prop: no body; tl_shape, tl_material and tl_mass_hint are on the part node. |
| `ball` | rubber |  | 320 | none: dynamic, `tl_shape` on the part | Ball. Dynamic prop: no body; tl_shape, tl_material and tl_mass_hint are on the part node. |
| `paddle` | plastic |  | 312 | none: dynamic, `tl_shape` on the part | Paddle (bat) for paddle-and-ball games, long axis X. Dynamic prop: no body; tl_shape, tl_material and tl_mass_hint are on the part node. |
| `crate` | wood | yes | 320 | Body (wood) | Wooden crate, pre-fractured (Intact / Pieces). |

## Params per part

### `ground_patch`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `size_x` | float | `40.0` | 1.0..400.0 | length along X (m) |
| `size_z` | float | `40.0` | 1.0..400.0 | length along Z (m) |
| `thickness` | float | `0.5` | 0.1..5.0 | slab thickness below y = 0 (m) |
| `surface` | string | `"grass"` | grass, dirt, concrete, asphalt, ice, snow, stone, wood | what it is made of: sets both the colour and the tl_material tag |

### `road_spline`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `points` | points | `[[-30,0],[0,12],[30,0],[0,-12]]` | at least 2 | control points [x, z] (road at y) or [x, y, z] |
| `closed` | bool | `true` |  | true = a loop |
| `y` | float | `0.0` | -50.0..50.0 | road height when points are [x, z] |
| `half_width` | float | `5.0` | 1.5..12.0 | half the tarmac width (m) |
| `kerb_width` | float | `1.2` | 0.0..3.0 | kerb width; 0 = no kerbs |

### `kerb`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `length` | float | `8.0` | 1.0..100.0 | length along X (m) |
| `width` | float | `1.2` | 0.3..3.0 | width (m) |
| `height` | float | `0.14` | 0.03..0.5 | height (m) |

### `barrier_wall`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `blocks` | int | `4` | 1..40 | number of blocks along X |
| `block_w` | float | `2.4` | 0.8..6.0 | block length (m) |
| `height` | float | `1.0` | 0.4..4.0 | height (m) |
| `depth` | float | `0.8` | 0.2..2.0 | thickness (m) |
| `cells` | int | `8` | 3..16 | pieces per block |
| `seed` | int | `1` | 0..1000000 | fracture pattern |

### `rink`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `length` | float | `60.0` | 10.0..120.0 | length along X (m) |
| `width` | float | `26.0` | 8.0..60.0 | width along Z (m) |
| `corner_r` | float | `8.5` | 0.0..30.0 | corner radius (clamped to width / 2 - 0.5) |
| `boards` | bool | `true` |  | boards with a kick plate (collision tag plastic) |
| `glass` | bool | `true` |  | glass above the boards (needs boards) |
| `glass_h` | float | `2.0` | 0.5..4.0 | glass height (m) |
| `markings` | bool | `true` |  | painted lines, circles and creases |
| `goals` | bool | `true` |  | two goals (child parts GoalA at -X and GoalB at +X) |
| `apron` | float | `3.5` | 0.0..10.0 | concrete apron around the boards (m); 0 = none |

### `stands`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `length` | float | `52.0` | 4.0..120.0 | length along X (m) |
| `rows` | int | `10` | 1..20 | rows of seats |
| `row_depth` | float | `0.95` | 0.6..1.6 | depth of a row (m) |
| `rise` | float | `0.46` | 0.2..0.9 | height of a row (m) |
| `seed` | int | `32` | 0..1000000 | seat tint pattern |

### `arch_rib`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `span` | float | `15.5` | 3.0..40.0 | half span: feet at z = +-span (m) |
| `apex` | float | `14.0` | 3.0..40.0 | apex height (m) |
| `exponent` | float | `2.6` | 1.2..6.0 | arch shape: 2 = parabola, higher = flatter top |
| `purlin_dx` | float | `0.0` | 0.0..20.0 | length of purlins towards -X (the previous rib); 0 = none |
| `footings` | bool | `true` |  | concrete footings (the only collision of the part) |
| `hologram` | bool | `false` |  | true = drawn as a cyan hologram (not yet built); no collision |

### `scaffold`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `bays` | int | `2` | 1..8 | bays along X |
| `levels` | int | `2` | 1..6 | levels |
| `bay_w` | float | `2.4` | 1.2..4.0 | bay width (m) |
| `bay_d` | float | `1.3` | 0.8..3.0 | depth (m) |
| `level_h` | float | `2.0` | 1.6..3.0 | level height (m) |
| `decks` | ints | `[1,2]` | 1..6 | levels that carry a plank deck (entries above `levels` are ignored) |

### `crane`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `height` | float | `35.0` | 10.0..80.0 | tower height (m) |
| `jib` | float | `30.0` | 8.0..60.0 | jib length (m) |
| `counter` | float | `11.0` | 4.0..20.0 | counter-jib length (m) |
| `mast` | float | `2.3` | 1.2..4.0 | mast width (m) |
| `slew` | float | `0.0` | -360.0..360.0 | jib direction (degrees about Y) |
| `trolley` | float | `0.55` | 0.1..1.0 | hoist position as a share of the jib |

### `house`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `width` | float | `8.0` | 4.0..16.0 | length along X (m) |
| `depth` | float | `5.6` | 3.0..12.0 | depth along Z (m) |
| `wall_h` | float | `3.0` | 2.2..6.0 | wall height (m) |
| `roof_rise` | float | `2.7` | 0.8..6.0 | roof rise (m) |
| `lights` | bool | `true` |  | warm window lights (skipped in headless) |

### `timber_frame`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `width` | float | `6.0` | 3.0..16.0 | length along X (m) |
| `depth` | float | `5.6` | 3.0..12.0 | depth along Z (m) |
| `height` | float | `3.0` | 2.2..6.0 | post height (m) |
| `roof_rise` | float | `2.4` | 0.8..6.0 | rafter rise (m) |

### `tree`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `species` | string | `"pine"` | pine, broadleaf, hero | pine, broadleaf, or the one large hero tree |
| `height` | float | `9.0` | 2.0..25.0 | height (m); ignored by `hero` |
| `seed` | int | `100` | 0..1000000 | shape variation |

### `rock`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `size` | float | `1.0` | 0.2..6.0 | radius (m) |
| `squash` | float | `0.7` | 0.2..1.5 | height as a share of the radius |
| `seed` | int | `200` | 0..1000000 | shape variation |

### `bush`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `size` | float | `0.9` | 0.3..3.0 | radius (m) |
| `seed` | int | `300` | 0..1000000 | shape variation |

### `fence`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `length` | float | `8.0` | 1.0..200.0 | length (m) |
| `style` | string | `"rail"` | rail, mesh | rail = wooden rail fence, mesh = steel site fence |

### `light_mast`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `height` | float | `14.0` | 4.0..30.0 | height (m) |
| `light` | bool | `true` |  | add the spot light |

### `sign`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `color` | key | `"sign"` | a palette key | palette key of the board |

### `flag`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `height` | float | `7.0` | 2.0..20.0 | pole height (m) |
| `color` | key | `"flag_a"` | a palette key | palette key of the cloth |

### `scoreboard`
No params.

### `tyre_stack`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `columns` | int | `5` | 1..20 | columns |

### `watch_tower`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `height` | float | `9.0` | 4.0..20.0 | platform height (m) |

### `pond`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `radius_x` | float | `30.0` | 2.0..120.0 | half size along X (m) |
| `radius_z` | float | `20.0` | 2.0..120.0 | half size along Z (m) |
| `surface` | string | `"ice"` | ice, water | ice = frozen (walkable), water = a small lake |

### `bridge`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `length` | float | `26.0` | 6.0..80.0 | length (m) |
| `width` | float | `4.6` | 2.0..14.0 | width (m) |
| `spans` | int | `3` | 1..8 | arches |
| `rise` | float | `4.2` | 1.0..10.0 | hump height (m) |

### `lumber`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `length` | float | `3.2` | 0.5..8.0 | length (m) |
| `width` | float | `1.0` | 0.3..4.0 | width (m) |
| `layers` | int | `6` | 1..10 | layers |
| `seed` | int | `51` | 0..1000000 | board tint variation |

### `pallet`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `rows` | int | `3` | 1..6 | rows of blocks |
| `seed` | int | `52` | 0..1000000 | block tint variation |

### `cone`
No params.

### `barricade`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `width` | float | `1.9` | 1.0..4.0 | width (m) |

### `cabin`
No params.

### `marshal_post`
No params.

### `entrance`
No params.

### `stones`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `count` | int | `4` | 1..12 | blocks |

### `goal`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `width` | float | `1.84` | 1.0..8.0 | opening width (m) |
| `height` | float | `1.22` | 0.8..3.0 | opening height (m) |
| `depth` | float | `1.0` | 0.5..3.0 | net depth (m) |

### `puck`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `radius` | float | `0.038` | 0.02..0.5 | radius (m) |
| `height` | float | `0.0254` | 0.01..0.3 | height (m) |

### `ball`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `radius` | float | `0.11` | 0.03..1.0 | radius (m) |
| `color` | key | `"white"` | a palette key | palette key |

### `paddle`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `length` | float | `1.6` | 0.3..6.0 | length along X (m) |
| `height` | float | `0.3` | 0.1..2.0 | height (m) |
| `depth` | float | `0.3` | 0.1..2.0 | thickness along Z (m) |
| `color` | key | `"car_blue"` | a palette key | palette key |

### `crate`
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `size` | float | `1.0` | 0.3..3.0 | edge length (m) |
| `cells` | int | `6` | 3..12 | pieces |
| `seed` | int | `3` | 0..1000000 | fracture pattern |
