# Lane B kit: part list and parameters

Every asset in the scene is produced at load time by a GDScript generator on top of `src/mk.gd` (MeshKit).
There are no authored meshes, no textures and no imported files. A part is a function with parameters; the
scene (`src/world.gd`, `src/sim.gd`) only calls parts with numbers taken from `SCENE.md`.

## MeshKit primitives (`src/mk.gd`)
| Primitive | Parameters | Used for |
|---|---|---|
| `box` / `boxm` | size or min/max, palette key, tint, chamfer | almost everything; the chamfer is the "bevelled kit primitive" look |
| `bar` | point a, point b, width, height | beams, braces, rails, lattice members |
| `hull` | point list | wedges, car body, roof slabs, curb blocks (convex hull, faceted) |
| `prism` / `cyl` / `cyl_between` | polygon or radius, height, segments, top scale | columns, cones, pines, wheels, trunks |
| `blob` | radii, subdivision, jitter, per-facet value variation | rocks, foliage, bushes, dust puffs |
| `loft` / `sweep` | rings or path + profile | arch ribs (writes UV.x along the part for the dissolve) |
| transform stack, `bone`, `skinned`, `mats`, `uv_fixed` | | rigid skinning, per-surface material override, constant UV |

## Kit parts
| Part (file) | Parameters | Output | Reusable for |
|---|---|---|---|
| `Path` (path.gd) | control points, closed, spacing, height fn | resampled spline + nearest query | any circuit, river, road, fence line |
| `Terrain` (terrain.gd) | seed, ridge segment, pads[{c,r,blend,h,dirt}], road, river | near mesh (4 m), far mesh (32 m), height query, collision patch | any valley / plateau layout |
| `KitRoad.build` | path, half_w, curb_w, curb_h, curb_seg | tarmac ribbon (5 tone strips) + red/white curbs | any circuit or street |
| `KitRoad.river_ribbon` | path, half_w | water ribbon with flow UVs | rivers, canals |
| `KitArena.rink` | L, W, corner r, glass_h, goals | ice + apron + boards + kick plate + glass + posts + goals | any rink size (markings come from shader uniforms rink_c / rink_s) |
| `KitArena.stands` | L, W, rows, row depth, rise | raked tiers, seats, aisles, rear wall, columns | any stand length / height |
| `KitArena.rib_mesh` | span, apex, exponent p, purlin length, keys | arch rib + purlins, UV.x 0..1 foot to foot | any hall section; `build` instance uniform converts hologram <-> built |
| `KitSite.crane` | height, mast, jib, counter | Tower + Slew(Jib, Hoist(Load)) nodes | any tower crane |
| `KitSite.lattice` | a, b, side, bay | square lattice mast | masts, pylons, towers |
| `KitSite.scaffold` | bays, levels, bay w/d, level h, deck levels | scaffold with decks, rails, braces, ladder | any facade length / height |
| `KitSite.add_lumber / add_pallet / add_barricade / add_cone / add_fence / add_ladder` | position, size, yaw | props appended into one mesh | site and yard dressing |
| `KitHouse.house` | w, d, wall_h, roof rise | footing, log walls, shingled gable roof, chimney, windows, porch | cabins of other sizes |
| `KitHouse.frame` | w, d, h, rise | timber frame (posts, beams, rafters) | any "under construction" timber building |
| `KitNature.pine / broadleaf / hero_tree / rock / bush / grass_tuft` | seed, size, tiers | MultiMesh templates | forests, scatter |
| `KitWall.block` | w, h, d, nx, ny, nz, taper, jitter, seed | merged intact mesh + per-chunk meshes and convex points | any breakable block or wall panel |
| `KitCar.build` | body key, stripe key, spoiler | Body, 4 wheel pivots, Nitro node | vehicle rig; colour variants are data |
| `Rig.skeleton / clip / assemble / attach` | bone table, pose function | Skeleton3D, Animation clips, AnimationPlayer | every skinned kit character |
| `KitBiped.build` | tablet, look{palette keys per part} | biped on Godot humanoid bone names; clips idle, walk, run | player, NPCs (other colours = data) |
| `KitBot.build` | | small bot; clips idle, work, walk; ToolTip mount | builder agents |
| `Fx.sparks / dust_burst / smoke / nitro_trail / tyre_dust` | amount, radius | CPUParticles3D (inked puff meshes or additive quads) | any effect of the same family |

One-offs (not parametric): the hero tree shape, the avatar's face and hair layout, the scene layout table in
`world.gd` / `sim.gd` (positions from SCENE.md), the movie shot list.

## Standard rigs
- Biped: Hips, Spine, Chest, Neck, Head, Left/Right UpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot (17 bones,
  identity rest rotations, no Shoulder/Toes bones). Faces -Z, anatomical left is -X.
- Bot: Hips, Spine, Head, Left/Right UpperArm, LowerArm, UpperLeg, LowerLeg (11 bones).
- Vehicle: Body, WheelFL/FR/RL/RR (steer pivot) / Spin, Nitro.

## Pass 2 additions
| Part (file) | Parameters | Notes |
|---|---|---|
| `World` + layout file (world.gd, data/layout*.json) | ridge, pads, mesas, waterfalls, river, circuit (cps, wall_at, car offsets), arena (c, yaw, rink, rows, ribs, built, rib_dx, apex, scaffolds[], bots[]), cranes[], house (p, yaw), props[], clear[], hero_tree, hero_rocks, cams | the whole scene is data; `--layout=alt` is a second scene with no code change |
| props dispatcher (world.gd `_build_props`) | `{"k": kind, "p": [x, z]}` or `{"k": kind, "s": metres along circuit, "side", "off"}`, `yaw`, `a` | kinds: lumber, pallet, barricade, cone, fence, site_fence, sign, flag, light_mast, cabin, scoreboard, tyres, marshal, entrance, stones |
| `KitSite.add_site_fence / add_sign / add_flag / add_light_mast / add_cabin / add_scoreboard / add_tyres / add_marshal_post / add_entrance` | position, yaw, size or colour key | site and circuit dressing |
| `KitWall.block` (rewritten) | w, h, d, cells, seed, tint | seeded Voronoi pre-fracture: irregular convex slabs, core faces, rebar |
| `Terrain.mesas` | c, r, h | flat-topped cliffs for the skyline |
| `KitBot.build(look)` | body key, hat key | colourways are data; hard hat, beacon mount |
| `KitBiped` | 21 bones: + Left/Right Shoulder, Left/Right Toes, Backpack, Hair | secondary motion keys in idle / walk / run |
| `MK.merge` | [[mesh, transform]...] | static merge and rubble bake, keeps the part-local detail channel |
| material classes (toon.gdshader `surface_detail`) | class, dscale, dk per material; global detail block | drawn surface language mapped in part-local space (MeshKit CUSTOM0), no UVs |
| `Fx.glow` | palette key | additive billboard for beacons and weld flashes |

## Pass 3 additions
| Part (file) | Parameters | Notes |
|---|---|---|
| `MK.rbox` | size, key, tint, radius, offset, arc steps | rounded box with smooth normals (an inner box inflated by a sphere): moulded toy forms, no facet creases in the ink pass; used by the avatar, bots (body, head, feet) and the car roof |
| `MK.capsule` | a, b, radius, key, tint, segments, cap rings, end radius | limbs, thumbs, bedroll, car bumpers, bot arms and legs |
| `KitBiped.set_face(root, mood, blink)` | mood 0 focused .. 1 happy, blink 0..1 | face bones LeftEye, RightEye, Brows, MouthCorners (not touched by the body clips); the player blinks every 3.4 s and is focused while running |
| `KitSite.add_bridge` (prop `bridge`) | position, yaw, length, width, spans | humpback stone arch bridge with ramps and parapets |
| `KitSite.add_pond` (prop `pond`) | position, half sizes, palette key | flat irregular sheet (frozen pond) |
| waterfall (world.gd, layout `waterfalls`) | p on a cliff top, `to` towards the pool, width | lip and foot found by marching the terrain; strands in two flat tones + foam |
| `Terrain` | `ridge.fall`, `mesas[].blend / noise` | a cliff edge instead of a slope; small near buttes |
| site light (world.gd) | per `light_mast` prop | shadowless spot, energy from style `lights.mast`; drawn by the toon shader as a two-band pool |
| palette lookup (style.gd, toon.gdshader, mk.gd) | `palette` + `mat` in style.json | one material and one surface for all toon keys; MeshKit writes the palette column into CUSTOM0.w |
| `KitRoad.build` (extended) | | painted edge lines, a start / finish checker, skid marks where the curvature is high, darker tyre lanes |
| ridge ramp (terrain.gd, layout `ridge.ramps`) | c, w, fall | a stretch where the cliff relaxes into a walkable grass slope |
| `Sim.rewind_cars(secs)` | | timed captures (`--t`) show the cars at their layout positions at capture time |
| fabric class (toon.gdshader class 8) | `dk`, `dscale` per material | quilted bands across the part with dashed stitch seams |

Biped rig, pass 3: 25 bones (the 21 of pass 2 + LeftEye, RightEye, Brows, MouthCorners). Humanoid bone names unchanged.

## Pass 4 additions
| Part (file) | Parameters | Notes |
|---|---|---|
| layout contract (`LAYOUT.md`, `tools/validate.gd`) | every layout key with type, default, range | unknown keys are errors; `tools/g.sh validate <name>` |
| strata (toon.gdshader, ground class) | style `detail.strata`, `strata_m`, `strata_tone`, `strata_crack` | steep terrain facets carry drawn rock layers in world height: a tone per layer, ink seams, cracks |
| light pool (toon.gdshader `light()`) | style `lights.pool_outer / pool_inner / pool_soft / pool_smooth` | three soft bands, the outermost starting at zero light: no disc edge |
| `KitRoad.build` (extended) | | skid marks on every bend (two pairs), concrete apron + drain slots behind both kerbs, gravel trap on the outside of bends |
| `KitBiped` face | | eyes, blush discs, capsule brows and a one-piece smile laid on the curved head surface; new bone `Glints` (26 bones) |

No new prop kind was added in pass 4: the denser hero is the pass-3 kit placed by layout data (18 bots, 3 cranes, 8 scaffolds, 86 props, 17 placed rocks; pass 3 had 10, 2, 4, 42 and 4).
