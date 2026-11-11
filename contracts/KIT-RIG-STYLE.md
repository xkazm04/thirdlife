# Kit, rig and style contract (kernelApi 0.1)

WP2 implements this in `kitlab/{kits,rigs,style}/` (later `engine/{kits,rigs,style}/`, same `res://` paths). The kernel
(WP1) and packs (WP4 onward) consume it. The seam is **duck-typed**: the names below are the contract; there is no
shared base class. WP1 must run without WP2 present (it ships plain stand-ins that answer the same methods).

The look is lane B of Phase A (inked low-poly, flat-band toon, painterly sky and grade), accepted by the owner on
2026-11-10. Source to port from: `spike/lab/b/` (read `README.md`, `KIT.md`, `LAYOUT.md`, the four pass reports).
Everything is generated from GDScript at load time. No Blender, no imported asset, no hand-made file.

## Material ids (the law table's keys; fixed here so both sides agree)

`ice`, `concrete`, `steel`, `wood`, `rubber`, `asphalt`, `grass`, `dirt`, `glass`, `plastic`, `snow`, `water`, `stone`,
`fabric`.

The kernel owns the table (`res://kernel/data/materials.json`, schema `tl.materials/1`, with the pairwise overrides in `res://kernel/data/surfaces.json`, schema `tl.surfaces/1`: density, friction, restitution, hardness, flammability,
sound set, breaks-into). The kit only **tags**: every collision body a kit part returns has metadata `tl_material` set
to one of these ids. The kernel turns the tag into physics properties and contact sounds.

## Kit: `TLKit` (static functions)

| Function | Returns |
|---|---|
| `TLKit.list() -> PackedStringArray` | every part kind |
| `TLKit.spec(kind: String) -> Dictionary` | `{params: {<name>: {type, default, min, max, enum, doc}}, material: <id>, fracturable: bool, doc}`; absent members omitted |
| `TLKit.validate(kind: String, params: Dictionary) -> PackedStringArray` | readable errors; empty when valid; unknown params are errors |
| `TLKit.build(kind: String, params: Dictionary) -> Node3D` | the part |
| `TLKit.build_layout(layout: Dictionary, parent: Node3D) -> Dictionary` | builds a whole venue from layout data; returns `{ok, errors[], nodes: {<id>: Node3D}}` |
| `TLKit.validate_layout(layout: Dictionary) -> PackedStringArray` | schema and sanity errors without building |

A built part is a `Node3D` with metadata `tl_kind`, `tl_params`, and:
- visual `MeshInstance3D` children (materials from `TLStyle`);
- zero or more `StaticBody3D` children with `CollisionShape3D`s and metadata `tl_material`;
- for a fracturable part, a child named `Intact` (visual + static body) and a child named `Pieces` (hidden, one
  `MeshInstance3D` per piece, each with metadata `tl_shape` = a `ConvexPolygonShape3D`, `tl_material`, `tl_mass_hint`).
  The kernel's fracture primitive hides `Intact`, turns `Pieces` into rigid bodies, and bakes them when they sleep.
  The kit never creates rigid bodies.
- for a part the game moves (`puck`, `ball`, `paddle`), **no body at all**: the root carries metadata
  `tl_dynamic: true`, `tl_shape` (a `Shape3D`), `tl_shape_offset` (Vector3), `tl_material`, `tl_mass_hint`, and the
  kernel creates the body. *(Amended 2026-11-10 after WP2.)*

Same kind and params give a byte-identical mesh (`TLKit.hash(node) -> String` for the test). Parts take a `seed` param
where they have variation; they never call global random functions.

Minimum parts for v0.1: `ground_patch`, `road_spline`, `kerb`, `barrier_wall` (fracturable), `rink` (boards, glass,
ice sheet, markings, goals as options), `stands`, `arch_rib`, `scaffold`, `crane`, `house`, `tree`, `rock`, `fence`,
`light_mast`, `sign`, `flag`, `scoreboard`, `tyre_stack`, `watch_tower`, `pond`, `bridge`, `lumber`, `pallet`, `cone`,
`goal`, `puck`, `ball`, `paddle`, `crate` (fracturable).

**Layout schema** (`tl.layout/1`): the lane-B layout grown up per the owner's approved changes: lists, not singletons
(`arenas[]`, `houses[]`, `circuits[]`, `cranes[]`, `ponds[]`, `walls[]`), unknown keys are errors, keys starting with
`_` are comments. Document it in `kitlab/kits/LAYOUT.md` with a stated list of what a layout cannot express.

## Rigs: `TLRigs.build(family: String, params: Dictionary) -> Node3D`

Families: `biped`, `vehicle`, `bot`. A rig is **visual only**: the kernel's controllers own the physics body and
parent the rig under it. Every rig node answers:

| Member | Meaning |
|---|---|
| `family: StringName` | `&"biped"`, `&"vehicle"` or `&"bot"` |
| `metrics() -> Dictionary` | sizes the controller needs. Biped and bot: `height`, `radius`, `eye_height`. Vehicle: `wheelbase`, `track`, `wheel_radius`, `ride_height`, `length`, `width`, `mass_hint` |
| `clips() -> PackedStringArray` | clip names this rig can play |
| `play(clip: StringName, blend: float = 0.15) -> void` | start a clip; looping is a property of the clip |
| `set_locomotion(velocity_local: Vector3, grounded: bool) -> void` | called every frame; the rig picks and blends idle, walk, run or skate by speed and by `mode` |
| `set_param(name: StringName, value: Variant) -> void` | see below |
| `socket(name: StringName) -> Node3D` | attachment points; `null` if absent |
| `tick(frame: int) -> void` | advance animation by one physics frame; the rig never reads the wall clock |

Biped: Godot humanoid bone names (`Hips`, `Spine`, `Chest`, `UpperChest`, `Neck`, `Head`, `LeftShoulder`,
`LeftUpperArm`, `LeftLowerArm`, `LeftHand`, `LeftUpperLeg`, `LeftLowerLeg`, `LeftFoot`, `LeftToes` and the `Right`
set). Clips required for v0.1: `idle`, `walk`, `run`, `skate`, `skate_stop`, `shoot`, `pass`, `cheer`, `fall`,
`carry`, `work`. Params: `mode` (`&"walk"` or `&"skate"`), `look_at` (Vector3, world), `expression` (`&"happy"`,
`&"focus"`, `&"blink"`), `lean` (float, -1..1), `stick` (bool: show a hockey stick in `hand_r`), `colors`
(Dictionary of palette keys). Sockets: `hand_r`, `hand_l`, `head`, `back`, `foot_r`, `foot_l`, `stick_blade`. Clips are procedural
(code-driven poses and curves), deterministic, and blend.

Vehicle: params `steer` (-1..1), `throttle` (0..1), `brake` (0..1), `wheel_spin` (rad/s), `suspension` (4 floats,
metres of compression, order FL FR RL RR), `nitro` (0..1), `colors`. Sockets: `exhaust_l`, `exhaust_r`, `driver`.
Clips: `idle`. Bot: clips `idle`, `walk`, `work`, `carry`, `weld`; params `colors`, `beacon` (bool), `look_at`; socket `carry`.

Build params common to all: `seed`, `scale`, `colors`. `TLRigs.spec(family)` and `TLRigs.validate(family, params)`
mirror the kit functions.

## Style: `TLStyle` (static functions)

| Function | Meaning |
|---|---|
| `TLStyle.load_style(path: String = "res://style/style.json") -> PackedStringArray` | loads and validates. Entries starting with `clamped: ` are notes (the file is applied); any other entry is an error (the file is not applied) |
| `TLStyle.install(host: Node) -> void` | adds sky, sun, environment, grade and ink post-process under `host`; idempotent |
| `TLStyle.material(key: StringName) -> Material` | the one shared palette material, or the special ones (`glass`, `water`, `holo`, `fx_add`, `fx_mix`) |
| `TLStyle.palette() -> PackedStringArray` | palette keys |
| `TLStyle.set_headless(on: bool) -> void` | in headless runs no shader, texture or viewport work is done and every function still succeeds |

Style files: `res://style/style.json` (golden) and `res://style/style_overcast.json`. Swapping the file changes the
whole look with no code change. No autoload: all state is static, so the kernel's `project.godot` needs no entry for it.

## Effects and time

Visual-only effects (particles, shader `TIME` for ice shine and grass sway) may run on the engine clock, provided they
are skipped headless and never enter `state_hash`. A `capture` is therefore not pixel-identical between runs. Any effect
that carries game meaning goes through the kernel. *(Amended 2026-11-10 after WP2.)*

## Headless

Everything here must work under `--headless` (the verifier runs headless): geometry and collision are built, materials
may be skipped, nothing touches the GPU, nothing errors.

## Budgets (linted by `kitlab/tools`)

Biped at most 12,000 triangles and 30 bones; bot at most 3,000; vehicle at most 8,000; a venue layout at most
600,000 triangles and 400 draw calls at 1440p.

## Amendments of 2026-11-10, second round (after WP4)

- **Vehicle `steer`** on the rig is -1..1 with + = left. `TLVehicle.set_controls` takes + = right and converts.
- **Materials made outside the kit.** A body the kernel makes for a pack from a material id and a `color`
  (`TLBodies.make`, stand-ins) gets a style material from `TLStyle.material` when the style is installed, so pack-made
  geometry is lit like kit geometry. A pack never has to create a `StandardMaterial3D` to get the look.
- **Effects.** `TLVfx` presets render through the style layer's effects when the style is installed.
- Recorded kit gaps, not built: layout `markers[]` (`{id, p | on, yaw, r}`) for game places, and a `loose` parameter
  that makes a small prop dynamic.

### Added with the core run (2026-11-11, P3): rig parameters, style keys, camera defaults

Rigs, section "biped":
> Params added in P3: `prop` (`auto` | `none` | `stick` | `hammer`, default `auto`: the hockey stick in skate mode, nothing in walk mode; `stick = true` is the
> same as `prop = stick`) and `headgear` (`auto` | `none` | `helmet`, default `auto`: in skate mode a helmet in the `top` colour with a white stripe, a white hem band
> and a white number patch on the back; hair in walk mode). Metrics (`height`, `radius`, `eye_height`) and clip durations are unchanged;
> `triangles` grows by about 350 in skate mode.
> The walk and run locomotion blend scales the swing of legs and arms with the ground speed (0.62 at walking speed to 0.78 at a run) so that a planted foot
> stands still on the floor; the named clips `walk`, `run` and `carry` played with `play()` keep their authored swing.
Style, section "toon": optional `rim2` (colour) and `rim2_k` (0..1): a cool rim on the side facing away from the sun (global `g_rim2`).
Style, section "sky": optional `cloud_puff` (size of a cloud clump, 1), `cloud_line` (0..1, contour on the shade side) and `cloud_ink` (colour); `cloud`, `cloud_shade`,
`cloud_cover`, `cloud_scale`, `cloud_high` keep their names and now drive drawn clumps on the dome instead of streaks.
Cameras: `TLChaseCam` defaults are now `follow` 0.18, `aim` 0.3, `stiffness` 0.07 (were 0.3, 0.5, 0.12). `TL_LOOK_CAM=<file>` writes one line per frame
(`[cam] f= p= d=`) of the active camera for motion review.
