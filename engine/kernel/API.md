# Third Life kernel API (kernelApi 1.16)

**Version 1.16 (major 1 frozen by P7 on 2026-11-11; minors are additions).** The version is the `KERNEL_API` constant of
`kernel/runner/manifest.gd`. Every class, method, signal, property and constant a pack may use is written down by a
machine in `docs/generated/API-V1.json` and `tl arch` guards it: section 22. `"kernelApi": "1.16"` in `pack.json` (any
`"1.x"` up to 1.16 runs; `"0.1"`, the name the 1.0 surface had before, still runs).

What a pack may use. A pack is a directory (`contracts/PACK.md`); the kernel loads it, runs it at a fixed 60 physics
frames per second and verifies it (`contracts/RUNNER.md`). Everything a pack needs is a global class starting with
`TL` (no `load` or `preload` needed) plus the `ctx` object. If something you need is not here, it is a **kernel gap**:
say so in your report instead of working around it (each workaround is counted by lint as a bypass).

## 0. Start here (half a page; the rest is reference)

1. **Copy the nearest seed.** `engine/seeds/seed_paddle` (ball, goals, score, AI), `seed_drive` (car, laps, road),
   `seed_wall` (walker, throw, break, time limit). `engine/seeds/README.md` says how a pack is put together. Start
   from a seed's `pack.json`, `data/`, `scripts/main.gd` and bot, not from an empty file.
2. **The venue is data, built by the kit.** Write one `tl.layout/1` file (`res://kits/LAYOUT.md`) and call
   `TLKit.build_layout(ctx.read_json("venue.json"), ctx.root)`: a `terrain` with one flat `pads[]` entry gives
   ground with collision, forest and mountains; `props[]` places kit parts. Declare the capability `kit`.
3. **Objects are kit parts before they are boxes.** `TLKit.build(kind, params)` (the list with every parameter is in
   `res://kits/KIT.md`): `ground_patch`, `barrier_wall`, `crate`, `fence`, `lumber`, `pallet`, `cone`, `tyre_stack`,
   `rink`, `goal`, `house`, `tree`, `rock`, `sign`, `flag`, `scoreboard`, and `ball`, `puck`, `paddle` for
   `TLBall.create({"part": ...})` / `TLBodies.from_part(...)`. Only for a shape no part gives (a ramp, a rail, a
   chute) use `TLBodies.make(shape, dims, material_id, {"color": Color(...)})`; never a bare `BoxMesh` of your own.
4. **Never make a material, a light, a sky or an environment.** No `StandardMaterial3D.new()`, no
   `DirectionalLight3D`, no `WorldEnvironment`. The kernel gives every body it makes the style's inked toon material
   from its material id, or from the `color` option when you want another colour; the style brings sun, sky, ambient,
   and a default ground to the horizon when you built none (visual only: things still fall without your own floor).
   Lint lists each hand-made material, light, environment, mesh and `MeshInstance3D` in `bypasses[]`.
5. **A script goes on a node before the node goes into the tree**: `node.set_script(s)` first, `add_child(node)`
   second. Attached afterwards, its `_ready` and `_physics_process` never run and nothing tells you except a
   warning in the `smoke.loads` detail. Better still: keep logic in `_pack_tick` and call plain helper objects.
6. **Run the verbs in this order after every change**: `lint` (bypasses should be `[]`), `smoke`, `bot`,
   `invariants` (the idle run twice and your first bot twice: the same seed must give the same hash), then
   `capture --test=<bot>` and **look at the picture**. Commands are in section 16.
7. **A bot plays through `ctx.input` and reads `ctx.pack_state()` only** (section 15). Put what it needs in
   `_pack_state()`. Randomness is `ctx.rng`; time is `frame`.

Worked examples, all verified by `tools/tl.sh selftest`, are in `kernel/examples/`:

| Example pack | Shows |
|---|---|
| `pack_min` | the smallest valid pack: data, a generator, bodies, one input action, one capture view, one bot |
| `ex_slide` | friction from the law tables, measured (ice against asphalt, with and without pairwise overrides) |
| `ex_bounce` | `TLBall` restitution from the law tables, `TLSpawner`, `TLTrigger`, `TLRules` score to win |
| `ex_shuffle` | the puck kind of `TLBall`: 30 m/s against a thin rail and through a thin trigger, `hold` and `release` |
| `ex_wall` | `TLBall`, contact damage by hardness, `TLFracture` (wake, sleep, bake) |
| `ex_walker` | `TLBiped` walk, run and skate, pushing a crate, checkpoints and a lap in `TLRules`, `TLOrbitCam` |
| `ex_pointer` | the aim (`ctx.input.declare_aim`): a stick that turns to the point on the ice under the cursor; its bot drives the aim with `set_aim` |
| `ex_held` | a skater on a held, shaken `TLBall` steps off it at his own speed: a held ball is never a moving floor (K2) |
| `ex_pointer_hand` | `TLHand` moves the aim as a person's cursor: a jumping, sliding target, a shot after each jump, one bot per profile (K4) |
| `ex_hud` | `TLHud` plates, lines centred inside a plate, a bottom label that grows upwards, over a kit rink from the play camera (K5) |
| `ex_held_big` | a puck shot from under a still 2.2-scaled skater carries him nowhere: no ball, held or loose, is a floor (K3) |
| `ex_down` | `TLBiped.down` / `shove` / `stumble` with a key held through them, and two pairs of 2.2-scaled figures meeting with today's body and with `body_scale` (K2) |
| `ex_car` | `TLVehicle` driven by input actions, nitro, grip per surface, `TLChaseCam`, AI with `TLSteer`, `TLHud`, `TLVfx`, `TLAudio` |
| `ex_kit` | the kit and the rigs under the kernel: a `TLKit` ball on a `TLKit` ice patch, a `barrier_wall` and a `crate` through `TLFracture`, `TLBiped` and `TLVehicle` on the real `TLRigs` rigs, and the stand-in rigs given by hand |
| `bad_*` | one deliberately bad pack per failure the runner detects |

**Before you write a line: the fence.** Lint refuses `get_tree()`, `get_parent()`, `Input.`, `.call(`, `.set(`,
`set_script`, `call_deferred`, absolute or `..` node paths, and any file in the pack that is not a `.gd` script or plain
data. Section 16 says what to write instead. Run `lint` first and often: it takes a second.

## 1. Lifecycle and the order inside a frame

```
load:   pack.json checked -> law tables loaded -> each gen/*.gd: generate(ctx) -> entry script instanced
        -> entry._pack_setup(ctx) -> (bot runs only: bot._bot_setup(ctx))
frame 0: entry._pack_start()
every physics frame f = 0, 1, 2, ...:
        ctx.frame = f
        bot._bot_tick(f)            (bot runs only; the bot presses and releases actions here)
        ctx.input latches           (pressed / just_pressed are now fixed for this frame)
        entry._pack_tick(f)         (optional)
        kernel primitives and every other node (_physics_process), in tree order
        the physics step
end:    entry._pack_teardown()      (optional)
```

- Time is `ctx.frame`. There is no wall clock in a pack; 60 frames are one second (`ctx.seconds()`, `ctx.frames()`).
- Do game logic in `_pack_tick` or in signal handlers, never in `_process` (it is not counted and not deterministic).
- The entry script is a `Node` named `Entry`; build the scene under `ctx.root` (a `Node3D`), not under the entry.
- A generator (`gen/*.gd`) runs before the entry exists: it may add nodes under `ctx.root` or leave data in
  `ctx.root.set_meta(...)`, but it cannot dress what `_pack_setup` builds later. If it adds a node with a script,
  `set_script` comes **before** `add_child` (afterwards the script never runs; the runner warns).
- A run of N frames ticks f = 0..N-1. `state_hash` is taken after the last physics step.
- Limits (the watchdog): one `_pack_tick` or `_bot_tick` may take at most 250 ms; `generate`, `_pack_setup`,
  `_pack_start`, `_bot_setup`, `_pack_teardown` at most 10 s each; more than 20 errors stop the run; more than 50,000
  nodes or 4 GB stop the run. V3 budgets: nothing with a physics body below y = -50, at most 5,000 nodes and 600
  physics bodies under the pack, frame time p99 at most 8 ms headless.
- **Any** error Godot prints fails V2: a GDScript runtime error, a parse error, `push_error`, an engine error caused
  by a pack call. Warnings do not.

## 2. `ctx` (class `TLContext`), always available

| Member | Meaning |
|---|---|
| `ctx.root: Node3D` | build the scene under this node |
| `ctx.rng: RandomNumberGenerator` | seeded from `--seed`; the only randomness a pack may use |
| `ctx.seed: int`, `ctx.frame: int`, `ctx.max_frames: int` | the run's seed, the current frame, the frame budget |
| `ctx.pack_dir: String`, `ctx.pack_id: String`, `ctx.manifest: Dictionary` | where and what the pack is |
| `ctx.headless: bool` | true in verify runs: skip purely visual work (the kernel's own primitives already do) |
| `ctx.mode: String` | `"smoke"`, `"bot"`, `"capture"` or `"play"` |
| `ctx.input: TLInput` | named actions (capability `input`) |
| `ctx.cameras: TLCameras` | views and cameras (capability `camera`) |
| `ctx.read_json(rel) -> Variant` | reads `<pack>/data/<rel>`; `null` and an error when missing or invalid |
| `ctx.load_script(rel) -> GDScript` | loads another script of the pack, wherever the pack lives: `ctx.load_script("scripts/ai.gd").new()` |
| `ctx.pack_state() -> Dictionary` | the entry's `_pack_state()`; **this is how a bot reads the game** |
| `ctx.has_capability(cap) -> bool` | whether pack.json declares it |
| `ctx.seconds(frames) -> float`, `ctx.frames(seconds) -> int` | conversions at 60 Hz |
| `ctx.pick(array) -> Variant`, `ctx.shuffle(array)` | seeded replacements for `pick_random()` and `shuffle()` |
| `ctx.info(text)` | a log line tagged with pack id and frame |

```gdscript
func _pack_setup(ctx) -> void:
    var tuning: Dictionary = ctx.read_json("tuning.json")           # <pack>/data/tuning.json
    var x: float = ctx.rng.randf_range(-2.0, 2.0)                   # never randf()
    ctx.root.add_child(TLBodies.ground(Vector2(40, 20), "concrete"))
```

A pack script may `preload("other.gd")` (a path relative to itself) or use `ctx.load_script("scripts/other.gd")`.
It may not load anything outside the pack except `res://kits/`, `res://rigs/`, `res://style/`, `res://kernel/api/`.

## 3. Laws: `TLLaws` and the data files (capability `physics`)

`res://kernel/data/materials.json`: one row per material id (`ice`, `concrete`, `steel`, `wood`, `rubber`, `asphalt`,
`grass`, `dirt`, `glass`, `plastic`, `snow`, `water`, `stone`, `fabric`) with columns `density` (kg/m3), `friction`,
`restitution`, `hardness` (0..10), `flammability` (0..1), `sound` (contact sound set), `breaks_into` (material id);
plus `impulse_per_hardness` (N*s). `res://kernel/data/surfaces.json`: **surface rules**, pairwise overrides of
friction and restitution (for example rubber on ice 0.10 and 0.30). Both are read-only for packs.

**Pair law.** friction = the lower of the two materials; restitution = the two added up, at most 1; unless
`surfaces.json` has a row for the pair. A collision body with metadata `tl_material` gets its friction and
restitution from the table automatically (at the end of `_pack_setup`, and when it enters the tree later).
Bodies with a `TLContact` (everything dynamic from `TLBodies.make`, every `TLBall`, every `TLVehicle` chassis) and
the controllers (`TLVehicle` wheels, `TLBiped` feet) also follow the pairwise overrides, from the first touch.
A plain tagged body without a tracker gets the default pair law only. Measured in `ex_slide` and `ex_bounce`.

| Function | Meaning |
|---|---|
| `TLLaws.ids() -> PackedStringArray`, `TLLaws.has(id)` | the material ids |
| `TLLaws.material(id) -> Dictionary` | a copy of one row (editing it changes no law); an unknown id is an error and answers with concrete |
| `TLLaws.pair(a, b) -> Dictionary` | `{friction, restitution, override}` for two materials |
| `TLLaws.material_of(node) -> String` | the tag of a collider, `""` when untagged |
| `TLLaws.apply(body, id = "")` | tags a body and sets its physics from the table (for bodies you did not get from the kernel or the kit) |
| `TLLaws.apply_tree(root) -> int` | the same for everything tagged under a node |
| `TLLaws.volume_of(body) -> float` | m3 of its collision shapes (mass = density x volume) |
| `TLLaws.impact_threshold(id) -> float` | N*s a body of this material takes before damage: hardness x `impulse_per_hardness` |
| `TLLaws.surface_under(node, from, depth, exclude = [], down = Vector3.DOWN) -> Dictionary` | `{hit, material, position, normal, collider, distance}` below a point |

```gdscript
var grip: float = TLLaws.pair("rubber", "ice")["friction"]          # 0.1
var under: Dictionary = TLLaws.surface_under(ctx.root, ball.global_position, 1.0, [ball.get_rid()])
```

The project sets linear damping to 0: nothing slows down except by the laws. Give a ball air drag with its `drag` option.

## 4. Bodies, triggers, contacts, damage (capability `physics`)

### `TLBodies` (static)

| Function | Meaning |
|---|---|
| `TLBodies.make(shape, dims, material, opts = {}) -> PhysicsBody3D` | a static body, or a dynamic one with `dynamic = true`. `shape`: `&"box"` (Vector3 size), `&"sphere"` (radius), `&"cylinder"` / `&"capsule"` (Vector2(radius, height)). Options: `dynamic`, `mass` (kg; default density x volume, so a solid 0.8 m wooden cube weighs 333 kg), `position`, `rotation_degrees`, `color`, `visual` (bool), `name`, `ccd`, `track` (bool, default true: attach a `TLContact`), `layer`, `mask`, `group`, `lock` (dynamic bodies: world axes it may not move along or turn about, any of `"x" "y" "z" "rx" "ry" "rz"`). Unknown options are errors |
| `TLBodies.ground(size: Vector2, material, top_y = 0.0, center = Vector3.ZERO) -> StaticBody3D` | a flat floor, 1 m thick, its top at `top_y` |
| `TLBodies.trigger(shape, dims, opts = {}) -> TLTrigger` | a trigger volume. Shapes box, sphere, cylinder. Options: `position`, `rotation_degrees`, `name`, `group_filter` |
| `TLBodies.from_part(part, opts = {}) -> RigidBody3D` | the dynamic body for a kit part the game moves (a `paddle`): the kit returns such parts with no body and metadata `tl_dynamic`, `tl_shape`, `tl_shape_offset`, `tl_material`, `tl_mass_hint`; the part becomes the body's visual child. Options `mass`, `material`, `position`, `rotation_degrees`, `name`, `ccd`, `track`, `layer`, `mask`, `group`, `lock`. `TLBodies.is_dynamic_part(node)` tells whether a node is one |
| `TLBodies.drive(body, velocity: Vector3, max_accel = 80.0)` | a body moved under control (a paddle, a bat, a platform): steers its velocity toward `velocity` with at most `max_accel` m/s2; call it every frame. With `lock` the body keeps to its rail: a paddle sliding along z is `{"lock": ["x", "y", "rx", "ry", "rz"]}` |
| `TLBodies.push(body, impulse: Vector3, at_world = null)` | a one-off impulse in N*s on a dynamic body: the kernel's door instead of `apply_impulse` |
| `TLBodies.contact(body) -> TLContact` | the body's contact tracker (attached on demand) |

**Look.** The visual of a body from `make` (and of a `TLBall` without a `part`) wears the style's toon material:
the colour of its material id (wood brown, ice pale blue, steel grey, rubber near-black ...) or the `color` option.
It is lit, banded and inked like kit geometry; do not replace its `material_override` with a material of your own.
Before you reach for `make`, check `res://kits/KIT.md` for a part (`crate`, `barrier_wall`, `lumber`, `ground_patch`).

```gdscript
var crate: PhysicsBody3D = TLBodies.make(&"box", Vector3(1, 1, 1), "wood", {"dynamic": true, "mass": 20.0, "position": Vector3(0, 3, 0)})
ctx.root.add_child(crate)
TLBodies.push(crate, Vector3(crate.mass * 2.0, 0, 0))               # 2 m/s to the +x
```

### `TLTrigger` (an `Area3D`)

Signals `entered(body)`, `left(body)`. Members `group_filter: StringName`, `enter_count: int`, `inside() -> Array`,
`has_inside(body) -> bool`. A `TLBall` that crosses the whole volume within one physics step (a puck at 30 m/s is
0.5 m per frame) is still reported, from the path of its last step; `entered` and `left` then arrive together.
Other small fast bodies can skip a trigger thinner than their step: make it deeper. A trigger also reports static bodies that overlap it at the start: filter by body or by
group in your handler. Do not free or re-parent bodies inside the handler; set a flag and act in `_pack_tick`.

```gdscript
var goal: TLTrigger = TLBodies.trigger(&"box", Vector3(2, 1.2, 0.5), {"position": Vector3(0, 0.6, -30), "group_filter": "pucks"})
ctx.root.add_child(goal)
goal.entered.connect(func(_body: Node3D) -> void: rules.add_score("home"))
```

### `TLContact` (a child node of a dynamic body)

Signal `hit(other: Node, impulse: float, speed: float)` (impulse in N*s, an estimate from masses and closing speed).
Members `material`, `surface` (material id it touches or is about to touch), `min_hit_speed` (default 0.5 m/s).
It also keeps the body on the pair law (section 3) and plays the contact sound when the pack declares `audio`.

**How it is ticked (P2).** A `TLContact` has no per-tick script of its own. A pack has ONE tracker (`TLContact.Tracker`,
a node the kernel puts under the pack's `TLPack` node the first time a contact is made in the pack; do not touch it)
that visits every tracked body once per physics frame, at process priority 100 (after every default-priority node,
before the physics step), in the order the bodies entered the tree. For each awake body it reads the velocity, takes
the tagged surface it touches from the engine's contact signals, and casts a ray (the look-ahead that makes the first
touch right) when the body has moved about 15 % of its size since the last cast; a fast body (a puck) casts every
frame. A sleeping body costs two reads. Consequences for a pack: keep using `TLBodies.make`, `TLBodies.contact(body)` and
`TLBall`; a body made with `track = false` costs the physics engine only (no contact monitoring, no law lookup beyond
the table value it was given), which is the thing to use for scenery that moves and never needs the pair overrides.
Cost on the reference machine, one pack, bodies awake: 300 bodies about 1.2 ms a tick, 600 about 2.4 ms (was 3.8 and 7.4).

### `TLDamage`

`TLDamage.attach(target, {hp = 100.0, threshold = <N*s>}) -> TLDamage`. Signals `damaged(amount, by, hp_left)`,
`broken(by)`. Members `hp`, `max_hp`, `threshold` (0 = from the material's hardness), `is_broken`, `last_impulse`.
`hurt(amount, by = null)` takes health directly. `TLDamage.of(collider)` finds the one a collider belongs to.
Law: an impact of impulse J above the threshold T does `100 x (J - T) / T` points. Impacts are reported by anything
with a `TLContact`, and by a `TLBiped` running into something.

```gdscript
var d: TLDamage = TLDamage.attach(crate, {"hp": 60.0})
d.broken.connect(func(_by: Node) -> void: crate_broken = true)       # free it in _pack_tick, not here
```

## 5. `TLBall` (capability `ball`): a ball or a puck

`TLBall.create(opts) -> TLBall` (a `RigidBody3D`). Options: `kind` (`&"ball"` sphere, `&"puck"` flat cylinder),
`radius` (default 0.11; puck 0.038), `height` (puck, 0.025), `material` (default rubber), `mass`, `position`,
`planar` (bool: stays flat, for a puck), `max_speed`, `color`, `name`, `group`, `drag`, and **`part`**: a kit part
in the dynamic-prop convention (`TLKit.build("puck", {...})` or `"ball"`: a visual with metadata and no body). The
ball then takes its shape, material and mass from the part and wears it; without `part` it uses its own plain shape.

| Member | Meaning |
|---|---|
| `shoot(impulse: Vector3)` | hit it: N*s |
| `shoot_at(target: Vector3, speed)` | send it toward a world point at a speed |
| `place(at: Vector3)` | put it somewhere at rest (a face-off, a reset) |
| `hold(holder: Node3D, offset = Vector3.ZERO)`, `release(velocity = Vector3.ZERO)`, `holder() -> Node3D` | carry it with a node (a stick blade, a hand socket), then let go with a velocity: possession, a pass, a shot |
| `speed()`, `is_moving()`, `surface()` | m/s; above 0.05 m/s; material id under it |
| signals `bounced(other, speed)`, `stopped()`, `held(holder)`, `released(holder)` | hit something; came to rest; picked up; let go |
| `contact: TLContact`, `max_speed`, `radius`, `material_id` | |
| `set_max_gain(per_frame, floor_speed = 0.0)`, `set_velocity(v)` (1.16) | H1: no contact launches the ball past max(last speed, floor_speed) + per_frame a frame; game-set velocities are never cut (section 6, "H1") |
| `set_radius(r: float)` (1.13) | K8: a new radius now (the hockey big puck): the shape and the drawn ball or puck follow (a kit part's visual is scaled, x and z for a puck); height, mass, material and motion are kept |

```gdscript
var puck: TLBall = TLBall.create({"kind": &"puck", "material": "rubber", "planar": true, "position": Vector3(0, 0.02, 0), "group": "pucks"})
ctx.root.add_child(puck)
puck.shoot_at(Vector3(0, 0.02, -30), 25.0)
# with the kit installed: TLBall.create({"part": TLKit.build("puck", {}), "planar": true, "group": "pucks"})
```

## 6. `TLBiped` (capability `biped`): walk, run, skate

`TLBiped.create(opts) -> TLBiped` (a `CharacterBody3D`, origin at the feet, facing -z). Options: `rig` (a rig node;
default `TLRigs.build("biped")` when installed, else the stand-in), `rig_params`, `mode` (`&"walk"` or `&"skate"`),
`position`, `facing` (radians), `name`, `group`, and every tuning member below.

| Member | Meaning |
|---|---|
| `move(direction: Vector3, run = false)` | the intent for this frame: world direction, length 0..1; call every frame; zero stops |
| `brake(on = true)`, `jump()`, `set_mode(mode)`, `place(at, facing = 0.0)` | |
| `drive_from_input(input, map, view = Basis.IDENTITY)` | reads actions: map keys `left right forward back` and optionally `run brake jump`; `view` makes it camera-relative (`orbit_cam.yaw_basis()`) |
| `forward() -> Vector3`, `speed() -> float`, `surface: String`, `grounded: bool`, `rig: Node3D` | |
| signals `mode_changed(mode)`, `pushed(body, impulse)` | |
| `down(frames: int)`, `is_down() -> bool`, `down_frames_left() -> int`, signals `downed()`, `got_up()` | **K2: a figure on the ground.** He lies `frames` frames, then rises over `get_up_frames` (24); all that time `move`, `brake`, `jump` are ignored and he slides to a stop with the brake on. The TLRigs biped plays its `fall` clip (holds, flat on the front) and blends back to its locomotion while he rises; a rig without a fall clip (the kernel's stand-in capsule) is tipped flat and tipped back. `down` while down keeps the longer time; while rising he goes down again. In the state hash while down |
| `shove(impulse: Vector3)` | moves him without a fall: `impulse` (N s) / `body_mass` is added to his velocity, also while down |
| `stumble(frames: int, lean: float = 0.7)`, `is_stumbling() -> bool` | a short loss of control: a third of the intent reaches the legs, no brake, the rig leans to the side (`lean` -1 left .. 1 right, fading out). TLRigs biped: a side lean of the whole locomotion pose; the stand-in: nothing visible. Ignored while down |
| `TLHit.react(who: TLBiped, from_dir: Vector3, strength: float)`, `TLHit.down(who: TLBiped, frames: int, from_dir := Vector3.ZERO)` (1.12) | **K7: how a figure takes a hit**, one call for every pack so the look of a hit can change without changing packs. `from_dir` points from the victim toward where the blow came from (world; zero = unknown); `strength` about 0.3 a tap, 0.7 solid, 1.2+ big. v1 stand-in: `react` = `stumble(8 + 10*strength)` from 0.4 up, leaning away from a side blow, nothing below 0.4; `down` = `down(frames)` (direction not yet shown). The falls experiment of 21 Nov replaces the bodies; the signatures stay. Use these instead of calling `stumble`/`down` for a hit |
| `set_body_scale(scale: float)`, `body_radius() -> float`; create option `body_scale` | **K2: the body follows the figure.** The capsule is the rig's metrics (radius 0.3, height 2.0 for the TLRigs biped at scale 1) times the scale; give it the scale you give the rig (`rig.scale`). Default 1: the body every pack had |
| tuning | `get_up_frames` 24, `walk_speed` 2.3, `run_speed` 6.0, `accel` 28, `turn_rate` 10, `skate_speed` 9.5, `skate_accel` 6.5, `skate_lateral_grip` 2.2, `skate_turn_rate` 2.8, `skate_brake` 9, `jump_speed` 4.5, `body_mass` 80, `push_strength` 1, `sole_material` rubber, `blade_material` steel |

Walking: velocity moves toward the intent at `accel` x grip, where grip is the pair law of `sole_material` and the
surface under the feet (walking on ice is slow to start and stop). Skating: thrust along the facing, the facing
turns toward the intent at `skate_turn_rate`, sideways slip dies slowly (`skate_lateral_grip`), and the glide
decelerates by the pair law of `blade_material` and the surface (steel on ice 0.015: a long glide). It pushes dynamic
bodies it runs into (a puck, a ball, a crate) and reports the impact to `TLDamage`.

**A held ball is never a floor (K2).** A ball held with `TLBall.hold` is moved by its holder every frame; standing on
it, a biped would be carried by it and, leaving it, thrown at its speed (`CharacterBody3D` adds a platform's velocity
on leaving). A biped whose feet touch a held ball (asked only when the floor under him moves) neither follows its
motion nor takes its velocity when he steps off; his own `platform_floor_layers` and `platform_on_leave` come back
when he stands on anything else. Measured in `ex_held`: 15.0 m/s after stepping off a shaken held ball before, 9.5
(his own `skate_speed`) after. **K3: any ball, held or loose.** A puck released, shot or poked from under a skater is a
moving floor too, and a big body finds it more often (the round bottom of a 0.66 m capsule rests on a 0.025 m puck up to
0.18 m from its centre; 0.12 m for 0.3 m). In one sentence for a pack author: *no `TLBall` ever carries or launches a
biped, so a pack needs no `platform_on_leave` line of its own.* Measured in `ex_held_big`: a puck shot at 25 m/s from
under a still skater with `body_scale` 2.2 carried him 61 m before, 0 m after; in the hockey pack (its own
`platform_on_leave` line removed) one skater left the rink at 28.8 m/s on seed 4 of `bot_match` before, none on seeds 1
to 6 after.

**Two bodies that close in one step (K3): the true guarantee.** A biped's body never rests inside another's: pushing
into each other they settle about 0.01 m outside the sum of their radii. But two bipeds that close on each other in
the same physics step can overlap **for that one step** by up to the smaller of the two distances they moved in it
(each one's speed / 60, shoves and lunges included: 0.115 m for two skaters at 6.9 m/s), because within one step each
body's motion is tested against where the other stood at the start of the step (both take the whole gap). The next
step pushes them apart. Measured: two `body_scale` 2.2 skaters closing at 7 m/s each come to 1.264 m (1.320 m of radii)
for one step, then 1.364, then rest at 1.330; the hockey pack's closest approach on 6 seeds, 1.219 to 1.248 m, fits
the bound. Read "shoulder to shoulder" as true from the step after contact on.

```gdscript
var skater: TLBiped = TLBiped.create({"mode": "skate", "position": Vector3(0, 0.05, 0)})
ctx.root.add_child(skater)
func _pack_tick(_frame: int) -> void:
    skater.drive_from_input(ctx.input, {"left": &"left", "right": &"right", "forward": &"up", "back": &"down", "brake": &"stop"})
```

### Walker feel (addition in 1.8)

Pass `{"feel": &"walker"}` to `TLBiped.create` for the village visitor's fixed-tick controller.
It walks at 4.5 m/s, runs at 9 m/s, and shares the visitor's jump, acceleration, air control,
buffered and coyote jumps, step and 55-degree slope limit. Call `slide()` or supply a `slide` action
to `drive_from_input`. A grounded run slide carries momentum and lowers the collision capsule
from `WALKER_HEIGHT` (1.8 m) to `WALKER_SLIDE_HEIGHT` (0.84 m) at body scale 1.
The body stands once there is headroom. `walker_motion()` reports `ground`, `air`, `slide` or
`slope` after the physics step. `place()` clears the walker's motion for a restart.
Walk and skate packs keep their original controller by default.

### Flight (addition in 1.9)

Walker-feel bipeds can call `fly(true)` to take off and `fly(false)` to end flight and fall. Since the evening of 19 Nov
a walker-feel biped with a back socket summons the visitor's wings on take-off (`kernel/world/flight_wings.gd`, drawn in
36 ticks, no take-off delay); landing folds and dismisses them, and ending flight in the air dismisses them during the
fall. Presentation only. A walker-feel biped is built without the rig's backpack unless the pack sets
`rig_params.backpack`.
After the physics step, `is_flying()` reports flight and `walker_motion()` returns `fly` while airborne under power.
Call `move(direction)` to cruise and `climb(v)` each tick for vertical intent from -1 to 1.
The `fly_scale` option defaults to 5.0 times run speed. Flight eases into turns and glides to a hover on release.
It sweeps against solids and crowns and limits altitude to 120 m over ground. Descending onto walkable ground lands.
Optional `drive_from_input` keys are `fly` (toggle on press), `climb` and `descend` (held).
Forward input cruises at 45 m/s by default. Sideways and backward input travel at run speed.

### Ledges and bars (addition in 1.10)

Pass `{"feel": &"walker", "moves": [&"ledge", &"bar"]}` to `TLBiped.create`. Each move is optional.
The village visitor has both. `walker_motion()` also reports `hang`, `mantle` and `bar`.
Catch from the air by approaching a steep face whose walkable lip is 2.0 to 2.8 m above the feet.
The full capsule needs room to stand on top. The hands hang at the lip, 1.6 m above the feet.
Use `jump()` or move into the wall to mantle in 28 physics ticks. If a sweep is obstructed, the walker
falls from the last safe position. Use `slide()` or move away to drop. The hang holds its position along the edge.

Call `TLBiped.mark_bar(body: CollisionObject3D)` on a `StaticBody3D` before the plot is copied.
It sets the `tl_bar` metadata. A cylinder or capsule collision shape's transformed local Y axis is the bar,
bounded by the shape's ends. Lay it horizontally for a playground swing. A visitor can catch the copied
collider even after the source pack is unloaded. An airborne walker catches within 0.35 m of the axis
at hands height 2.2 m. Move across the bar to pump. `jump()` releases with tangential speed plus
2 m/s up, and `slide()` drops with tangential speed. Re-catching the same grip takes 20 clear ticks.
Existing jump and slide actions in `drive_from_input` also operate these moves.

The visitor, shared walker body and `TLBiped` expose read-only rig hooks including `ledge_top` and `wall_normal` in world space during
`hang` and `mantle`, `mantle_progress` (0 to 1), and `bar_point`, `bar_axis`, `bar_theta`
(radians) and `bar_omega` (rad/s) during `bar`. The optional clip names are `hang`, `mantle` and `swing`.
The kernel's biped rig has those three clips. With it, `TLBiped` (and the visitor) pose the figure for you: on a bar
the whole rig turns about the bar by `bar_theta` with its hands on the bar and faces across the bar; on a ledge it
faces the wall and hangs 0.4 m (x body scale) lower so the raised hands meet the lip; after a release or a drop it
turns upright in about 12 ticks.
`mark_bar` also puts the body in the group `tl_bar`: a `TLChaseCam` (and the visitor's camera, which also knows the
village's copied bars) leaves marked bars out of its avoidance, so walking under a bar or swinging on one does not lift,
pull or cut the camera. Keep the player's own body out of the camera's `avoid_mask` as before.
The village visitor's hard swing ends softly: pumping adds no energy once the swing would pass 85 degrees, and energy
above that (a fast entry) is bled off, so it peaks near 85 degrees instead of stopping dead at the 100 degree limit. A
pack biped keeps the plain swing (it stops at 100 degrees), so a pack tuned to it (parkour's Skyline) is unchanged.

### Falls arm A (21 Nov, experiment)

`TLHit.react` snaps the upper body away from the blow. Strength sets the size of the flinch, and a hit of 0.4 or
more also triggers the usual stumble. `TLHit.down` uses the dominant front, back or side direction. With an unknown
direction, including a plain `biped.down(frames)`, the figure falls along its horizontal velocity above 0.5 m/s
and forward at lower speeds. The standard biped rises from its landing pose within the pack's `get_up_frames`.
Rigs with only the original fall clip still use it, and the stand-in capsule still tips.

### K8 feel kit: hit-stop, mutual reactions, the pushbox (addition in 1.13)

Every contact of a duel changes BOTH fighters (`docs/research/DUEL-PLAYBOOK.md` sections 2 and 6.3). One call per
contact; each freezes both bodies in hit-stop, then gives each side his reaction. Frames are physics frames (60 Hz).

| Call | Hit-stop | Defender / victim | Attacker |
|---|---|---|---|
| `TLHit.hit(attacker, victim, heavy := false, counter := false, tune := {})` | 5 / 9 (+2 counter) | `hitstun` 18 / 40 (+10 counter), knocked 0.25 / 0.6 m, the directional `hit_<side>` flinch; knocked into a wall: `wallsplat` 40 (hit-stop 8, him alone); on the ground: no contact | the hit-stop only |
| `TLHit.blocked(attacker, defender, heavy := false, tune := {})` | 3 / 6 | `blockstun` 14 / 18, pushed 0.35 / 0.5 m on his guard (`block_stun`) | light: recoils 0.15 m; heavy: `recoil` 40, 0.3 m back (`recoil`) |
| `TLHit.parried(attacker, defender, heavy := false, tune := {})` | 10 | `recover` 8 | `parried` 52 / 36, weapon knocked away (`parried`), 0.2 m back |
| `TLHit.clash(a, b, a_heavy := false, b_heavy := false, tune := {})` | 8 | same class: both `rebound` 20 (heavy against heavy 30), 0.3 m apart each (`recoil`); heavy against light: the light one takes `TLHit.hit(heavy_one, light_one, true)` (hit-stop 9) | |
| `TLHit.guard_break(attacker, defender, tune := {})` | 6 (12 at a wall) | `guardbroken` 30, shoved 1.0 m (`guard_broken`); a `StaticBody3D` within `TLHit.WALL_REACH` (1.2 m) behind him: `wallsplat` 60, slammed back onto it over the 3 frames after the hit-stop; a wall met during the shove: `wallsplat` 60 | the hit-stop only |
| `TLHit.wall_splat(victim, wall_normal, attacker := null, frames := 60, tune := {})` | 12 (8 without an attacker) | turned with his back to the wall, `wallsplat` (`wall_splat`) | |
| `TLHit.impact(attacker, victim, frames) -> int` | `frames`, clamped to `TLHit.STOP_CAP` (20) | the hit-stop only; either side may be null | |

- Every contact returns `{contact, stop, attacker, attacker_frames, defender, defender_frames}`: the stun each side is in
  now (`&""` = none) and its frames. `tune` overrides `stop`, `frames` (the defender's), `attacker_frames`, `push` and
  `recoil` (metres); an unknown key is an error.
- **Hit-stop:** for its frames the body does not move, its rig does not tick (the pose holds), its down, stumble and
  stun counters hold, and `move`, `brake`, `jump` are ignored; velocity is kept and resumes after. The struck body's rig
  shakes along the blow (drawing only). The rest of the world goes on. **A pack holds its own counters** of a frozen
  fighter (a windup, an AI timer) with `TLHit.stop_left(b) > 0`. A longer hit-stop still running is kept.
- **With `react` and `down`:** calls of one frame stack. `impact` then `TLHit.react` or `TLHit.down` freezes first; the
  flinch or the fall plays when the freeze ends. `TLHit.down` ends a stun and its push (a knockdown wins); a hit-stop
  still running keeps running.
- **A stun** counts from the frame its hit-stop ends. While it runs no intent reaches the legs (the brake is on); the
  horizontal velocity is zeroed when it starts, and the push-back travels over 4 to 10 frames (`move_and_collide`: a wall
  stops it). The reaction clips are the rig's (`engine/rigs/RIGS.md`, "Reaction clips"), sized to the stun; a rig without
  them (the stand-in) shows nothing, and the stun still runs.
- `TLHit.stop_left(who)`, `TLHit.stun_of(who) -> StringName` (`&""`, `hitstun`, `blockstun`, `recoil`, `parried`,
  `recover`, `rebound`, `guardbroken`, `wallsplat`), `TLHit.stun_left(who)`, `TLHit.busy_left(who)` (hit-stop + stun +
  lying and rising: the frames until he can act; frame advantage = `busy_left(defender) - busy_left(attacker)` minus the
  attacker's own recovery), `TLHit.clear(who)` (ends all three: a round restart).
- **Pushbox (opt-in per body):** `TLHit.pushbox(who, on := true, radius := -1.0)`; -1 = `body_radius() + 0.02`. Bodies of
  one pack in its pushbox never end a physics frame overlapping: after every other node, each overlapping pair is pushed
  apart by half the penetration each, in the order they joined (walls still stop them); a body in hit-stop does not move,
  a stunned or downed body does not push back (one that stands free walks him along). `TLHit.pushbox_gap(who)` is the
  smallest centre distance minus the radii over the pack's pairs (>= 0: nothing overlaps; INF with fewer than two).
  Without it, the 1.0 guarantee of section 6 stands (two bodies closing in one step overlap for that step).
- **Determinism:** no randomness, no clock. A biped that never took a K8 contact and never joined a pushbox hashes
  exactly as before; while a hit-stop, stun or push runs it is in the state hash (the `down` text of the biped).
- **Skating body checks:** `hit` and `guard_break` stop the victim dead. For a check that should carry momentum use
  `TLHit.impact` + `TLHit.react` / `TLHit.down` + `shove`, or `tune.push`.
- The lab: `kernel/examples/ex_feel_lab` (every contact of the table between two figures; its bot asserts both change).

### E1 rig clip timing (addition in 1.14)

A fight game times its moves by a frame table (a wind-up of 18 to 54 frames on a 16 to 30 frame clip). The biped plays a
rig clip on a frame timeline, so the pack no longer writes the rig's clip time itself.

| Member | Meaning |
|---|---|
| `play_clip(clip: StringName, timing: Array = [], blend: float = 0.034)` | plays `clip` (`&""` = back to locomotion). `timing` is a list of `[frame, clip frame]` knots: frames counted from this call (the tick after it is frame 1), starting at 0 and rising; the clip frame is linear between knots. `[]` = the clip's own pace, as after the last knot. A timeline that does not rise is an error and plays nothing |
| `set_clip_speed(speed: float)` | the clip playing now runs at `speed` clip frames per tick (1 = as authored, 0.5 = half, 0 = held) until another clip plays |
| `clip_now() -> StringName`, `clip_frame() -> float` | the rig clip now (`&""` = locomotion) and its time in frames |

- A hit-stop (K8) holds the timeline together with the pose; it resumes where it stood.
- A kernel reaction (`TLHit.*` playing `block_stun`, `hit_<side>`, a fall) takes the rig over and ends the timeline.
- The rig shows at least clip frame 1 on the first tick after a play (the rig advances a whole frame per tick).
- Drawing only: nothing here reaches physics or the state hash. The stand-in rig has no clips: the calls do nothing.

```gdscript
# a duel heavy: the 30-frame clip stretched over a 37-frame wind-up and chop, then its recovery
fighter.play_clip(&"strike_heavy", [[0, 0.0], [24, 8.0], [30, 10.0], [37, 14.4], [65, 30.0]])
```

### E2b-E4 swing trail, HUD colour and tags (addition in 1.15)

Show the path of a fighter's weapon and place a teaching cue above the fighter in the pack's active view.

| Member | Meaning |
|---|---|
| `TLHit.swing_trail(who: TLBiped, weight: float = 0.5, frames: int = 30, opts: Dictionary = {}) -> Node3D` | Draw one ribbon for `frames` physics frames. Hit-stop holds its lifetime and path. A new call replaces that fighter's previous ribbon. The kernel frees it when its time is up. |
| `TLHud.set_color(id: StringName, color: Variant) -> void` | Set a label or tag to a `Color` or a style palette key (`String` or `StringName`). An empty key restores the current theme's paper. A missing widget or unknown key reports an error. |
| `TLHud.add_tag(id: StringName, node: Node3D, text: String = "", offset: Vector3 = Vector3(0, 2.3, 0)) -> void` | Centre a label just above the screen point of `node.global_transform * offset` in `ctx.cameras.active`. The tag hides behind the camera, outside the viewport, when the target goes away, or when its HUD is hidden. |

- The ribbon uses the `vfx` capability. It follows `opts.node` (a weapon tip) or the rig's `opts.socket`. The default is `stick_blade` when available, then `hand_r`. `opts.offset` is in the followed node's local space.
- Weight is clamped to 0..1. Width rises linearly from 0.12 to 0.36 metres, and the path keeps 5 to 12 samples, rounded to the nearest whole frame. Override these with `opts.width` and `opts.keep`. The ribbon renderer clamps the sample count to 2..120. `opts.color` accepts a Color or palette key and defaults to `"white"`.
- The call returns the ribbon, or null if the target or style layer is unavailable or the requested lifetime is zero or less. With style installed a headless run can measure the ribbon's lifetime. These drawing calls add no physics or state-hash inputs.
- Tags share widget ids, text, colour and plates with ordinary labels. They sit outside the anchor stacks. Explicit colours survive `configure_widgets` and theme changes. After a reset the widget follows the theme's paper. Palette keys require the style layer. Direct colours and paper reset also work in a kernel-only install.
- The lab in `kernel/examples/ex_swing_lab` measures a light swing, a heavy swing and a heavy blocked swing.

```gdscript
fighter.play_clip(&"strike_heavy")
TLHit.swing_trail(fighter, 1.0, 40)
hud.add_tag(&"cue", fighter, "HEAVY")
hud.set_color(&"cue", &"car_red")
```

### H1 a ball no contact can launch (addition in 1.16)

A puck squeezed between two skaters, or run into by a body, can leave at a speed nobody shot it with (hockey: 27 m/s
out of a face-off, an own goal for an idle hand). A ball can refuse any speed the game did not give it.

| Member | Meaning |
|---|---|
| `set_max_gain(per_frame: float, floor_speed: float = 0.0)` | from now on a contact may raise the planar speed by at most `per_frame` m/s a frame over max(the speed a frame before, `floor_speed`). A faster gain is cut back at the start of the next frame (the ball has moved one step at it). 0 = off, the default |
| `set_velocity(v: Vector3)` | sets the velocity as the game's own: never cut |

- A velocity the game gives is never cut: `shoot`, `shoot_at`, `release`, `place` and `set_velocity` declare it. A raw
  `linear_velocity = ...` write is not declared and is cut like a contact: use `set_velocity`.
- A held ball is not limited. The vertical speed is never touched. Off by default: a ball without the call is the ball
  it always was (no state hash moves).
- Measured (block 719): a 60 kg block slid at 24 m/s into a resting puck sends it off at 28.8 m/s; with
  `set_max_gain(4, 10)` it leaves at 14, 18, then 22 m/s.

```gdscript
puck.set_max_gain(4.0, 10.0)      # hockey's pinch rule: no contact adds more than 4 m/s a frame over max(last, 10)
puck.set_velocity(pass_dir * 14.0)  # a pass the game makes
```

## 7. `TLVehicle` (capability `vehicle`): raycast wheels

`TLVehicle.create(opts) -> TLVehicle` (a `RigidBody3D`, origin on the ground under the middle, forward -z, wheel order
FL FR RL RR). Sizes come from the rig's `metrics()` (`wheelbase track wheel_radius ride_height length width
mass_hint`). Options: `rig`, `rig_params`, `position`, `facing`, `name`, `group`, and every tuning member below.

| Member | Meaning |
|---|---|
| `set_controls(steer, throttle, brake = 0.0, nitro = false)` | the driver's intent: steer -1 left .. 1 right, throttle -1 reverse .. 1, brake 0..1; holds until the next call |
| `drive_from_input(input, map)` | reads actions: map keys `left right gas brake` and optionally `reverse nitro` |
| `forward()`, `forward_speed()`, `speed()`, `speed_kmh()`, `grounded_wheels()`, `place(at, facing = 0.0)` | |
| `wheel_surface: PackedStringArray`, `wheel_grounded: Array`, `wheel_compression`, `nitro_charge` (0..1; a tick burns only on at least half a tick of charge), `nitro_active` | |
| signals `nitro_started()`, `nitro_ended()`; `contact: TLContact` (`contact.hit` for crashes) | |
| tuning | `engine_force` 9000 N, `brake_force` 16000 N, `top_speed` 42 m/s, `reverse_speed` 9, `max_steer_degrees` 30, `min_steer_degrees` 8, `lateral_grip` 1, `suspension_travel` 0.3, `suspension_damping` 0.55, `nitro_force` 9000 N, `nitro_frames` 150, `nitro_recharge_frames` 900, `drive` (`&"rear"`, `&"front"`, `&"all"`), `tyre_material` rubber, `body_material` steel, `air_drag`, `rolling_resistance`, `anti_roll` |

Each wheel takes its grip from the surface under it: pair law of `tyre_material` and that surface (untagged ground
counts as 0.9). Measured in `ex_car`: braking from 14 m/s takes 10.1 m on asphalt and 96 m on ice.

## 8. `TLInput` (capability `input`), reached as `ctx.input`

One door for the player, for bots and for replays. Values are latched once per frame, and **the latch is the
record**: what a game read in a session can be written as a `tl.input/1` file and fed back (section 22). A value is a
multiple of 0.001 (`TLInput.STEP`): `press(&"left", 0.4567)` reads back as `0.457`.

| Member | Meaning |
|---|---|
| `declare(action: StringName, keys: Array = [], buttons: Array = [])` | declare before use; `keys` are physical key codes (`KEY_W`, `KEY_SPACE`) for interactive play; K2: `buttons` are mouse buttons (`MOUSE_BUTTON_LEFT`, `_RIGHT`, `_MIDDLE`) that press the action too (`declare(&"shoot", [KEY_SPACE], [MOUSE_BUTTON_LEFT])`): read, recorded and replayed as a key, never by the pack; a bot presses the action as before |
| `strength(action) -> float`, `pressed(action)`, `just_pressed(action)`, `just_released(action)` | reading |
| `axis(negative, positive) -> float`, `vector(left, right, up, down) -> Vector2` | y = down - up, as `Input.get_vector` |
| `press(action, value = 1.0)`, `release(action)`, `tap(action, frames = 1)`, `set_axis(negative, positive, value)`, `release_all()` | **injection**: what a bot calls in `_bot_tick` |
| signals `action_pressed(action)`, `action_released(action)`; `declared() -> PackedStringArray` | |
| `TLInput.LOOK_X`, `TLInput.LOOK_Y`, `TLInput.ZOOM` | **the pointer**: three actions the kernel declares in every pack. `strength()` gives the pixels of a right-button drag in this frame (x to the right, y down) and the wheel notches (+ is out); any value, each lasts one frame. A bot injects them with `press(TLInput.LOOK_X, 12.0)`. `TLOrbitCam` reads them by itself |
| `keys_taken() -> bool` | true while a text field has the keyboard (the designer panel): the game gets no key then |
| `declare_aim(action: StringName, height: float = 0.0, reach: float = 200.0)` | **the aim** (K1): an action whose value is a point, where the cursor meets the ground plane y = `height` through the camera on screen, at most `reach` metres from the camera. Declare it again to change height or reach; a name is either an action or an aim; a name with `@` is an error for both (it names the record entries `<aim>@x`, `<aim>@z`) |
| `aim_valid(action) -> bool`, `aim(action) -> Vector3` | this frame's aim: valid while the cursor is over the window and its ray meets the plane in front of the camera within `reach` (or a bot set it); the point lies on the plane, x and z multiples of `STEP`. Invalid: `aim()` is `Vector3.ZERO` |
| `aim_direction(action, from: Vector3, fallback: Vector3 = Vector3.ZERO) -> Vector3` | the unit vector on the plane (y = 0) from `from` (a body's position) to the aim. When the aim is invalid or within `TLInput.AIM_DEAD` (0.05 m) of `from` on the plane, the cursor sitting on the figure, it returns `fallback` flattened and normalised (`Vector3.ZERO` when that has no length): pass the figure's facing and it keeps it. Never a division by zero |
| `set_aim(action, point: Vector3)`, `clear_aim(action)` | **injection** of the aim: a bot's point (its y ignored) holds until `clear_aim` and wins over the cursor; `release_all()` clears aims too |

Real keys and the mouse are read only in interactive play (`tools/tl.sh play`); verify runs ignore every device, so a
stray key press cannot change a result. A pack never reads a device itself: no `Input`, no `InputEvent`, no
`_input` handler (the kernel switches a pack script's event handlers off), no mouse position: where the cursor
points is an aim (`declare_aim`), a world position the kernel resolves. Using an undeclared action is an error. AI opponents do not need actions: give them
intents directly (`biped.move()`, `vehicle.set_controls()`). A bot that should press as a person does (late, in
taps of human length, on keys instead of an analog axis) presses through `TLHand` (section 15).

**The aim and determinism.** An aim is latched with the other actions, once per physics frame, after the bot's tick
and before the pack's tick. Its point comes from, in this order: a fed record (`replay`: the record alone decides); a
bot's `set_aim`; in interactive play the cursor, through the camera on screen (`Viewport.get_camera_3d()`) with the
pose that camera has at that physics frame (chase and orbit cameras move in `_physics_process`) and its lens without
the shake's `h_offset` / `v_offset` (the aim does not shake); otherwise it is invalid. So a verify run without a bot
reads the aim invalid on every frame, never a stale or random point. In the state hash an aim is its validity and
its x and z from the first frame it was valid (K2: an aim never pointed adds nothing, so a keyboard run of a pack
that declares an aim hashes as if it had none). In a record (section 22) a
frame's valid aim is three entries: `[f, "<aim>", 1]`, `[f, "<aim>@x", x]`, `[f, "<aim>@z", z]`, the last two left out
when 0; that, the resolved point, is all a session needs to replay its aim: not the cursor's pixels, the window's
size or the camera. Example: `examples/ex_pointer` (a stick that turns to the aim; its bot drives the aim round a
square, onto the figure and away).

## 9. `TLRules` (capability `rules`): score, clock, periods, laps, win conditions

`TLRules.create(config) -> TLRules` (a `Node`; add it under `ctx.root`). Config keys (usually from `data/`):
`sides` (string[]), `periods`, `period_seconds`, `intermission_seconds`, `score_to_win`, `laps_to_win`,
`checkpoints` (per lap), `sudden_death`, `time_limit_seconds`. Unknown keys are errors.
States: `&"idle"` -> `&"running"` <-> `&"paused"` / `&"intermission"` -> `&"over"`.

| Member | Meaning |
|---|---|
| `start()`, `pause()`, `resume()`, `finish(winner = "", reason = "called")` | |
| `add_score(side, points = 1)`, `score(side) -> int`, `leader() -> String` | `score_to_win` ends the game; in sudden death the next score does |
| `standings() -> PackedStringArray` | sides in race order: laps, then checkpoints of this lap, then score |
| `pass_checkpoint(who, index) -> bool`, `complete_lap(who)` | checkpoints count only in order; the last one completes a lap; `laps_to_win` ends the game |
| `seconds_left()`, `seconds_played()`, `clock_text() -> "MM:SS"`, `is_running()`, `is_over()` | |
| `snapshot() -> Dictionary` | `{state, period, clock_frames, total_frames, scores, laps, winner, reason}`: return it (or merge it) in `_pack_state()` |
| signals | `state_changed(from, to)`, `score_changed(side, score)`, `period_started(n)`, `period_ended(n)`, `checkpoint_passed(who, index)`, `lap_completed(who, lap, lap_frames)`, `finished(winner, reason)` (reason `score`, `laps`, `time`, `called`; winner `""` is a draw) |
| data | `state`, `sides`, `scores`, `laps`, `period`, `periods`, `clock_frames`, `total_frames`, `winner`, `reason`, `next_checkpoint`, `last_lap_frames`, `best_lap_frames` |

```gdscript
rules = TLRules.create({"sides": ["home", "away"], "periods": 3, "period_seconds": 60, "intermission_seconds": 5})
ctx.root.add_child(rules)
rules.finished.connect(func(winner: String, reason: String) -> void: ctx.info("%s wins by %s" % [winner, reason]))
func _pack_start() -> void: rules.start()
func _pack_state() -> Dictionary: return rules.snapshot()
```

A score or clock variable of your own, while the pack declares `rules`, is counted as a bypass.

## 10. `TLSpawner` (capability `spawn`)

`TLSpawner.create(factory: Callable, opts) -> TLSpawner` (a `Node3D`; things spawn as its siblings). The factory
returns a new `Node3D`. Options: `points` (Vector3[], local), `every_frames` (0 = manual), `max_alive`, `max_total`,
`jitter` (Vector3, from `ctx.rng`), `lifetime_frames`, `kill_below_y` (default -40), `order` (`&"cycle"`,
`&"random"`), `active`, `start_delay_frames`, `name`. Members `spawn_now() -> Node3D`, `alive() -> Array`, `clear()`,
`total`. Signals `spawned(node)`, `despawned(node)`.

## 11. `TLFracture` (capability `fracture`)

For a part in the kit's `Intact` / `Pieces` convention (`contracts/KIT-RIG-STYLE.md`):
`TLFracture.attach(part, {hp = 100.0, threshold, bake = "static", max_awake_frames = 900, kick = 0.6, scatter = 0.6})`.
It attaches a `TLDamage` to `Intact`; when the health is gone it hides `Intact`, wakes each piece as a rigid body
(shape, mass and material from the piece's metadata), and when all sleep (or after `max_awake_frames`) bakes them:
`"static"` (static bodies, still collide), `"remove"` (freed) or `"none"`. Members `state` (`&"intact"`,
`&"broken"`, `&"settled"`), `damage: TLDamage`, `pieces: Array`, `awake_count()`, `break_now(push, at, by)`.
Signals `broke(by)`, `settled(frames)`. Without the kit, `TLStandin.fracturable_wall(size, nx, ny, material)` makes
a part in the same convention from boxes.

## 12. Cameras (capability `camera`), reached as `ctx.cameras`

| Member | Meaning |
|---|---|
| `ctx.cameras.add_view(name, position, target, fov = 60.0) -> Camera3D` | a fixed named view; `capture --cam=<name>` renders it. List the names in pack.json `cameras` |
| `ctx.cameras.chase(target, opts = {}, view = &"chase") -> TLChaseCam` | follows from behind. Options `distance` (7), `height` (3), `look_height` (1), `stiffness` (0.12: how fast the heading turns), `follow` (0.3: how fast the place catches up), `aim` (0.5: how fast the point looked at catches up), `use_velocity` (behind the last direction of travel, measured over 2 cm however slow, kept at rest; the facing until he has moved or after `snap()`), `fov` (**58**); 1.6 (opt-in, all off by default): `avoid_space` (a physics space RID, its bodies in the coordinates of the camera's parent: the camera never enters what it holds, except a body that holds the point looked at itself), `avoid_margin`, `avoid_mask`, `avoid_out`, `avoid_min` (margin and min in metres whatever the parent's scale), `anchor_follow`, `anchor_follow_y`; read-only `avoid_pull`, `avoid_lift` |
| `ctx.cameras.orbit(target, opts = {}, view = &"orbit") -> TLOrbitCam` | yaw free, **pitch held to 30..60 degrees**, distance to a range. Options `yaw`, `pitch`, `distance`, `distance_min`, `distance_max`, `look_height`, `yaw_rate`, `pitch_rate`, `zoom_rate`, `fov` (**50**), `smooth` (0.25: share of the remaining way the drawn camera covers each frame; 1 = rigid) |
| `ctx.cameras.activate(name) -> bool`, `views()`, `has_view(name)`, `view(name) -> Camera3D`, `active` | the first view registered is active until you say otherwise |
| `ctx.cameras.frame(subject, fill = 0.35, view = &"")` | places a view (default: the active one) so that `subject` covers `fill` of the frame height. A chase camera keeps its angle and changes `distance` and `height`; an orbit camera changes `distance` (and widens its range to hold it); a fixed view moves along its line of sight and looks at the subject's centre. Call it in `_pack_setup` after the camera was made and the subject is in the tree. It also names the subject as the view's main actor |
| `ctx.cameras.subject_px(subject) -> float` | how much of the frame height `subject` covers now in the active view: the height of the screen rectangle around its visible meshes, clipped to the frame; 0 when off screen or behind the camera. 0.08 is a small actor, 0.2 a clear one, 0.35 a portrait |
| `ctx.cameras.set_subject(view, subject)`, `subject_of(view) -> Node3D` | names the main actor of a view without moving it (a fixed view that must keep a whole court in sight) |
| `ctx.cameras.shake(amount, frames)` | impact shake on the active view: `amount` metres at the lens (0.05 a tap, 0.3 a crash), fading over `frames` physics frames. A stronger shake still running is kept |
| `TLOrbitCam.orbit_by(yaw_deg, pitch_deg)`, `zoom_by(metres)`, `bind_actions(input, {yaw_left, yaw_right, pitch_up, pitch_down, zoom_in, zoom_out})`, `yaw_basis() -> Basis` | the camera on screen also turns with the pointer actions of `ctx.input` (`TLInput.LOOK_X`, `LOOK_Y`, `ZOOM`: right-button drag, 0.2 degrees of yaw and 0.15 of pitch per pixel; the wheel, 0.4 m per notch). They are input like any key: latched per frame, recorded, replayed |
| `ctx.cameras.fade_occluders(on = true, opts = {})`, `faded() -> Array` (1.13) | **K8 occluder fade**: scenery between the play camera and its subjects fades, so a pillar never hides the rival. Options `view` (default the active view), `subjects` (a list: give both duellists; default the view's subject, else the chase or orbit target), `alpha` (0.3 remains), `frames` (8 to fade out and back), `max_size` (12 m: a larger mesh, the ground or a layout's merged statics, never fades). Rays in the pack's own space each physics frame; an occluder is a static or rigid body (not a biped, not a ball) and its kit part's meshes fade through `GeometryInstance3D.transparency`. Off until turned on. Props merged by `TLKit.build_layout` cannot fade one by one: build a pillar meant to fade with `TLKit.build` or `TLBodies.make`. In a world of several packs the draw layer's copies do not fade (yet). `faded()`: the occluding bodies of the last frame |
| `TLChaseCam.snap()`, `TLOrbitCam.snap()` | puts the camera where it wants to be at once (after a teleport, a cut, or a change of `distance`); a chase camera stands behind the target's facing at that moment |

**Everything here is visual only.** `frame`, `shake`, `follow`, `aim` and `smooth` move or offset cameras; none of them
reads or writes simulation state, uses a clock or draws a random number, so a pack's state hash is the same with and
without them. `TLOrbitCam.yaw`, `pitch`, `distance` and `yaw_basis()` are the raw values the pack set: only the drawn
camera is eased, so camera-relative movement (`drive_from_input(..., cam.yaw_basis())`) is exactly what it was.
`shake` offsets the lens (`h_offset`, `v_offset`), not the camera's place.

**Lens.** A chase camera is 58 degrees and an orbit camera 50 by default (they were the engine's 75, which made every
actor small and bent the edges). Pass `fov` to change it. Frame the main actor of the play camera at 0.2 to 0.3 of the
frame height; a fixed view that shows a whole court should still keep its main actor at 0.08 or more.

**Measuring.** `TL_LOOK_PX=1` in the environment makes `TLCameras` print
`[look] px view=<name> frame=<n> h=<share of frame height> w=<width in frame heights>` every 30 frames for every view
that has a main actor. `bash engine/tools/look.sh px [frames]` runs each seed's bot and prints min / median / max.

Example (the three seeds):

```gdscript
cam = ctx.cameras.orbit(player, tune["camera"], &"player")
ctx.cameras.frame(player, 0.26)                       # seed_wall: the walker covers a quarter of the frame height
ctx.cameras.chase(car, {"distance": 8.5, "height": 3.0, "look_height": 1.1, "fov": 58.0})
ctx.cameras.frame(car, 0.2)                           # seed_drive
ctx.cameras.set_subject(&"court", paddles["player"])  # seed_paddle: a fixed view of the whole court
ctx.cameras.shake(0.12, 14)                           # when a block breaks
```

## 13. Helpers: `TLSteer` (capability `ai`), `TLHud` (`ui`), `TLVfx` (`vfx`), `TLAudio` (`audio`)

**`TLSteer`** (static, pure functions in the ground plane; they return directions, they move nothing):
`seek(from, target)`, `arrive(from, target, slow_radius = 2.0)`, `flee(from, threat)`,
`intercept_point(from, speed, target, target_velocity, max_lead_frames = 120)`, `pursue(...)`, `evade(...)`,
`avoid(from, heading, obstacles: [{position, radius}], look_ahead = 6.0, own_radius = 0.5)`,
`separate(from, others: Vector3[], radius = 1.5)`, `steer_toward(heading, wanted, gain = 2.0) -> -1..1`,
`keep_lane(from, heading, path: PackedVector3Array, look_ahead = 6.0, closed = false) -> {target, direction, steer, offset, index, progress}`,
`wander(rng, memory: Dictionary, jitter = 0.3)`.

```gdscript
var lane: Dictionary = TLSteer.keep_lane(car.global_position, car.forward(), path, 9.0, true)
car.set_controls(lane["steer"], 1.0 if car.forward_speed() < 20.0 else 0.0)
defender.move(TLSteer.pursue(defender.global_position, defender.speed(), puck.global_position, puck.linear_velocity))
```

**`TLHud`** is a per-pack `CanvasLayer` with the Split Ticket house style. Existing calls keep their signatures and
their text values. `TLHud.create()` registers the layer with its pack. Captures include it with `--hud=on`.

- `add_score(rules, side, anchor, caption = "")`, `add_clock(rules, anchor)` and `add_speed(callable, unit, anchor)`
  bind live readouts. Their ids are `score_<side>`, `clock` and `speed`.
- `add_label(id, text, anchor)`, `add_bound(id, callable, anchor)`, `set_text(id, text)` and `text_of(id)` work with
  free text. Bound sources continue to refresh in physics order, including off stage.
- `set_plate(id, on = true)` toggles a backing on a text widget. Scores, clocks and speed start plated.
  `set_align(id, align)` aligns lines inside a label (`left`, `center`, `right`). Text on a shared anchor stacks
  by its measured size. Empty text takes no space. The first bottom label keeps its bottom edge.
- (1.15) `add_tag(id, node, text = "", offset = Vector3(0, 2.3, 0))` follows a point in the pack's active view. `set_color(id, color)` colours a tag or anchored text widget, and `set_color(id, &"")` restores theme paper. `remove_widget(id)` removes either kind.
- The nine anchors are `top_left`, `top`, `top_right`, `left`, `center`, `right`, `bottom_left`, `bottom` and `bottom_right`.

**Editable instruments (1.11).** A pack opts into the creator's HUD workshop with two ordinary pack data files.

```gdscript
var ready := hud.configure_widgets(ctx.read_json("hud-widgets.json"), ctx.read_json("hud.json"))
if ready:
    hud.set_readout(&"next", {"value": "Jump the gap"})
    hud.set_phase(&"run")
```

`configure_widgets(catalog, layout) -> bool` validates both files before replacing the instruments. A bad file logs
an error and keeps the previous configuration. `set_readout(id, reading)` updates one instrument. An empty dictionary
clears it. `set_phase(phase)` shows the `run` or `finish` set. These calls only change the drawing.
Kernel-only installations retain the ordinary text widgets. Requesting editable instruments there returns false
and reports the missing HUD style module.

- `data/hud-widgets.json` is the author's array of instruments. Each has a unique ASCII identifier `id`, player-facing
  `title`, `form`, default `anchor` and `sample` reading for the workbench. Optional `phase` is `run` (default),
  `finish` or `both`. An optional `finish_sample` supplies a distinct example on the finish screen.
- `data/hud.json` holds the player's optional `theme` and `widgets` override list. An empty object uses house defaults.
  Each override has one declared `id` and may set `visible` (boolean), `anchor` and `size` (`small`, `regular`, `large`).
  Themes are `signal`, `relay` and `night`. Unknown keys, unknown ids, duplicates, invalid types and unknown choices
  produce errors in the game and editor.
- Example layout: `{"theme":"relay","widgets":[{"id":"next","anchor":"bottom","size":"large"}]}`.
  See `packs/parkour/data/hud-widgets.json` for a complete catalogue.

| Form | Reading fields |
|---|---|
| `bib` | `value` (bib number text), `name` (stage name) |
| `cue` | `value` (action text) |
| `split` | `name` (live or completed split caption), `value`, `best`, `delta` (signed comparison text, empty to omit) |
| `timer` | `value`, `best` (formatted times) |
| `progress` | `done`, `total` (whole counts with `0 <= done <= total` and `total >= 1`) |
| `results` | `name`, `value`, `best`, `rows` (array of three-string rows: stage, split, best) |
| `keys` | `pairs` (array of two-string rows: key, action) |

**`TLVfx`** also has two motion helpers that sit on the style layer (N5a; they do nothing when it is absent):
`TLVfx.squash(visual, amount = 0.25, frames = 18, axis = Vector3.UP)` (squash and stretch on a VISUAL node, never a
body) and `TLVfx.trail(target, opts) -> Node3D` (a fading ribbon behind a node; `width`, `frames`, `color`, `offset`;
free the returned node to stop it).

**`TLVfx`** (presets; nothing is drawn headless): `TLVfx.burst(preset, position, parent, opts)`,
`TLVfx.attach(preset, node, opts) -> Node3D` (continuous; `stop()` it), `TLVfx.presets()`. Presets: `dust`, `sparks`,
`smoke`, `ice_spray`, `debris`, `nitro_flame`, `confetti`, `splash`, `goal_flash`. Options `direction`, `scale`, `color`.
With the style installed each preset is drawn by the style layer (`TLStyleFx.preset`: soft round puffs in palette
colours, additive sparks and flames, inked chips for debris); without it by plain stand-in particles. An effect lasts
the same number of frames either way. Fire effects on events that mean something, not on every contact.

**`TLAudio`** (presets with stand-in synthesised tones; silent headless, but every call is recorded):
`TLAudio.play(preset, position = null, volume_db = 0.0)`, `TLAudio.count(preset) -> int`, `TLAudio.events`,
`TLAudio.presets()`. Presets: `whistle`, `horn`, `beep`, `cheer`, `engine`, `nitro`, `skate`, `score`, `break`, and
`hit_<sound set>` for every material. Contact sounds play by themselves when the pack declares `audio`.

## 14. Kits, rigs, style, and the stand-ins

`TLKit`, `TLRigs` and `TLStyle` (capabilities `kit`, `style`) are documented in `res://kits/KIT.md`,
`res://kits/LAYOUT.md`, `res://rigs/RIGS.md`, `res://style/STYLE.md` and `contracts/KIT-RIG-STYLE.md`. They are
installed in this engine (since WP4), so by default:

- every `StaticBody3D` of a kit part or a layout (tagged `tl_material`) gets its friction and restitution from the
  law table when it enters the tree under `ctx.root`; you call nothing;
- a kit part the game moves (`ball`, `puck`, `paddle`) has no body: hand it to `TLBall.create({"part": ...})` or
  `TLBodies.from_part(part)`; a fracturable part (`barrier_wall`, `crate`, a layout's `walls[]`) goes to
  `TLFracture.attach(part)`; every other part is static scenery you only position (`part.position`, no param);
- `TLBiped.create()` and `TLVehicle.create()` build the real rig (`rig_params` are `TLRigs` build params, for
  example `{"colors": {"top": "car_blue"}}`); sizes, mass and wheel positions come from the rig's `metrics()`.
  The biped rig is 2.0 m tall with a 0.3 m radius; the car is 4.4 x 1.86 m and 1,150 kg;
- the controller steers with + = right; the rig contract counts + = left; the controller converts. If you call
  `rig.set_param(&"steer", ...)` yourself, use the rig's sign;
- windowed runs (`capture`, `play`) get the lane-B look from `TLStyle.install`; headless runs build the same
  geometry and collision with stub materials. A pack never calls `TLStyle.install` itself;
- everything the kernel draws for you (`TLBodies.make`, `TLBall`, stand-ins) wears the style's toon material in its
  material's or your `color` (`TLStyle.flat_material`). A material you make yourself (`StandardMaterial3D`) is lit by
  the style's sun and a plain ambient, but gets no bands and no drawn surface: do not make one;
- when the pack built no kit ground (no layout, no `ground_patch`), windowed runs put the style's default ground
  just under the pack's lowest visual. It is a picture, not a floor: it has no collision and is not in the state.

**A mesh asset in the house look (1.7, D2):** `TLKitAsset.build(abs_path) -> Node3D` reads a `.glb` / `.gltf` of
`assets/<owner>/` (contracts/ASSETS.md) and draws it like a kit part: each glTF material NAME is a palette key, every
triangle is emitted again through `TLMesh` with the style's one toon material (bands, ink, palette); the file's own
materials are never used. Every glTF node keeps its name and local transform (moving parts stay separate). Visual
only, no body. `res://kits/tl_kit_asset.gd`. Where a pack's own assets are found at run time is not settled yet (the
world's landmarks resolve paths against the repository: `kernel/world/terrain/landmarks.gd`).

`ctx.root` has no ground to stand on: bring a `ground_patch` (or a layout with a terrain) or everything falls.

The kernel also runs without them: a controller given no rig asks `TLRigs` when it is
installed and otherwise builds `TLStandinRig` (a capsule, or a box on four wheels) which answers the whole rig table.
`TLStandin.rig(family, params)` (real rig when installed), `TLStandin.standin_rig(family, params)` (always the plain
one), `TLStandin.check_rig(node) -> PackedStringArray`, `TLStandin.ext("TLKit")` (the
script of an optional class, or null with one log line), `TLStandin.fracturable_wall(...)`,
`TLStandin.dynamic_part(kind, radius, height, material, mass_hint)` (a stand-in for a kit puck, ball or block in the
dynamic-prop convention), `TLStandin.material_for(material_id)`. Kit parts tag their bodies with `tl_material`; the
kernel applies the laws. A socket a rig does not have is `null`: `TLVfx.attach` and `TLBall.hold` callers should
expect that (`TLVfx.attach(preset, null)` returns null and does nothing).
A controller talks to its rig only once both are in the scene tree (the mode in `_ready`, `tick` and
`set_locomotion` from the physics frame), because a skeleton posed outside the tree stops updating. If you call a
rig yourself (`rig.play(&"cheer")`), do it after the controller was added under `ctx.root`.

## 15. Writing a bot (`tests/*.gd`)

```gdscript
extends Node
var ctx
var done: bool = false

func _bot_setup(c) -> void:
    ctx = c

func _bot_tick(frame: int) -> void:
    var s: Dictionary = ctx.pack_state()                 # read the game
    ctx.input.set_axis(&"left", &"right", 0.3)           # play it through the same actions a player has
    if frame % 120 == 0:
        ctx.input.tap(&"shoot")
    done = s.get("state", "") == "over"

func _bot_done() -> bool:
    return done

func _bot_result() -> Dictionary:
    var s: Dictionary = ctx.pack_state()
    return {"ok": done and s["winner"] != "", "summary": "final %s" % str(s["scores"]), "frames": ctx.frame}
```

Decide `ok` from game state, and put the numbers that prove it in the result. A bot that is not done within
`--frames` fails: `bot.completed` false, outcome `failed`, exit code 1 (`_bot_result()` is still collected and shown).

### `TLHand` (capability `input`): a person's hand for a bot

A bot that presses `ctx.input` directly is a perfect hand: every press on the frame it is decided, any analog value,
no tap shorter than one frame, never away. What it measures holds for nobody. `TLHand` sits between a bot's decisions
and `ctx.input` and presses the way a person does. The bot keeps its decisions; it hands them over as intents and calls
`tick()` as the last line of `_bot_tick`.

```gdscript
var hand: TLHand

func _bot_setup(c) -> void:
    ctx = c
    hand = TLHand.create(ctx, "regular")                 # "perfect", "sharp", "regular", "newcomer"

func _bot_tick(_frame: int) -> void:
    var s: Dictionary = ctx.pack_state()
    hand.set_axis(&"left", &"right", wanted)             # intents, as often as you like
    if s["puck_free"]:
        hand.tap(&"shoot")
    hand.tick()                                          # last: the hand acts on what is due
```

| Member | Meaning |
|---|---|
| `TLHand.create(ctx, profile = "regular", overrides = {}) -> TLHand` | a hand; `overrides` replaces profile numbers (keys of the table below) and takes `stream` (an int: a second hand in the same run draws its own numbers); an unknown profile or key is an error |
| `TLHand.PROFILES`, `TLHand.profiles() -> PackedStringArray`, `TLHand.ON`, `TLHand.OFF` | the profiles as data; a wished strength of at least `ON` (0.35) presses a key, which stays wished until the strength falls below `OFF` (0.15) |
| `profile: String`, `params: Dictionary`, `is_perfect() -> bool` | which hand, its numbers as used |
| `press(action, value = 1.0)`, `release(action)`, `tap(action, frames = 1)`, `set_axis(negative, positive, value)`, `release_all()` | intents, named as `ctx.input`'s injection |
| `steer(left, right, up, down, direction: Vector2)` | a direction (x right, y down) on four keys: quantised to 8 ways, a turn lets go of the old key late |
| `set_aim(action, point: Vector3)`, `clear_aim(action)` | **K4: the aim through a person's hand.** Where the bot wants to point an aim (a declared `ctx.input.declare_aim`); call it every tick it points (a moving target: every tick). `perfect`: straight to `ctx.input.set_aim` on the same tick (a ported bot keeps its hash: `ex_pointer`). A person's profile moves the game's aim as a cursor: a target that jumped more than `aim_jump` (1 m) is followed only `aim_lag` frames later (the cursor stays meanwhile); then the cursor travels at most `aim_speed` m/s on the ground and slows near its goal (it closes `aim_settle` of the rest each second); the goal is the target plus a miss drawn per target (up to `aim_miss` m, any side); a target moving on without jumping is tracked with no new reaction; during a lapse the cursor holds still. `clear_aim` takes the cursor away at the hand's next look. A mouse button needs nothing: it is a key of a declared action (`declare(&"shoot", [KEY_SPACE], [MOUSE_BUTTON_LEFT])`) and the hand presses the action |
| `tick()` | the last line of `_bot_tick`: the hand sees this frame's intents (unless it is away) and presses or releases what is due |
| `stats() -> Dictionary` | the proof that the hand ran, for `_bot_result()`: `decisions` (reactions), `mean_reaction_frames`, `stops` (feed-forward releases), `presses`, `releases`, `taps`, `lengthened` (a release postponed to a person's tap length), `sticks` (held through a change), `held_late_frames`, `overshoots`, `lapses`, `lapse_frames`, `intents`, `aims`, `profile`; K4: `taps_lost` (taps the bot asked for while the hand was away in a lapse: never pressed), `aim_targets` (new targets the cursor reacted to), `aim_lag_frames`, `mean_aim_lag_frames` |

What the hand does, per frame, under every profile but `perfect`:
- **one decision, one reaction.** Everything the bot's intents changed since the hand last looked is one decision.
  When a key is to go down (a start, or a turn) the decision is a reaction to something new: it is pressed `reaction`
  frames later (one draw for all of it). A stop of a movement the hand made itself is feed-forward, as a person's is:
  the key comes up `release_late` frames late, without a reaction. (Measured on `seed_paddle`: with every stop a full
  reaction late, the bot's per-frame servo on its own paddle became a delayed on/off loop that oscillated, and a
  `regular` hand lost 9 of 10 games against a rival a person beats.) A change is never pressed before one already queued.
- **keys, not an analog axis.** `set_axis(-1..1)` becomes one key down or none (`ON` / `OFF`), `steer` one of 8 ways.
- **human lengths.** A press lasts at least a `tap` (4 to 9 frames). A stop is let go `release_late` frames late; a
  turn (one key of a pair or of W A S D goes down while another goes up) lets go of the old key `overshoot` frames
  late instead, and the opposite key of a pair (left and right, up and down) goes down only once the old one is up:
  a person does not hold both. With `stick_chance` a key stays down `stick` frames more: the button still held when
  the situation changed.
- **attention.** `lapses_per_minute` times a minute on average the hand is away for `lapse` frames: intents made then
  are not seen (a tap is lost; a held wish is seen when it comes back).

| Profile | reaction | tap | release_late | stick_chance, stick | overshoot | lapses / min, lapse | aim_lag, aim_miss, aim_speed, aim_settle (K4) |
|---|---|---|---|---|---|---|---|
| `perfect` | 0 (the call goes straight to `ctx.input`) | as asked | 0 | 0 | 0 | 0 | 0 (the wanted point, same tick) |
| `sharp` | 4..7 | 4..6 | 0..2 | 0.02, 6..12 | 1..3 | 1, 8..15 | 4..8, 0.15 m, 40 m/s, 12 /s |
| `regular` | 8..13 | 5..8 | 2..6 | 0.05, 10..24 | 3..7 | 3, 15..30 | 8..16, 0.3 m, 25 m/s, 8 /s |
| `newcomer` | 14..23 | 6..9 | 4..10 | 0.12, 18..40 | 6..12 | 6, 24..48 | 14..26, 0.6 m, 15 m/s, 5 /s |

Why these numbers (frames at 60 Hz): a person's simple visual reaction is 200 to 250 ms (12 to 15 frames) and a choice
under pressure is longer; somebody new to a game reads the screen first (about 300 ms: `newcomer` centres on 18), a
player who knows the game anticipates part of it (about 170 ms: `regular` 10), a sharp player reacts on cues before the
event (about 85 ms: `sharp` 5). A finger's quickest deliberate tap on a keyboard is 60 to 150 ms, so 4 to 9 frames.
The late release and the overshoot are a quarter to a half of the reaction (letting go is quicker than deciding); the
stick and lapse numbers are guesses to be tuned against recorded sessions (`tl.sh play --record`), and are said to be.

The cursor (K4) is reasoning, not a measurement on a person. A cursor's reaction to a new target is the same visual
reaction as a key's, a little shorter for a sharp eye (`aim_lag` as above). Speed: under the hockey camera (52 m up,
fov 55) the screen spans about 54 m of ice, and a mouse flick across half a screen takes a practised hand about half a
second (about 50 m/s at its peak), a regular one most of a second, a newcomer longer: 40, 25, 15 m/s. The slowing near
the target is the corrective phase of a pointing movement (Fitts): the cursor closes 12, 8 or 5 of the remaining
distance per second, so the last few centimetres take a sharp hand about 0.1 s and a newcomer about 0.3 s. The miss is
where a person stops pointing; up to 0.15, 0.3 or 0.6 m on the ice, about 3 to 12 pixels at 1080 lines. Measured on
`ex_pointer_hand` (20 jumping, sliding targets, a shot 40 frames after each jump, seeds 1 to 10; mean aim error at
the shot; mean frames from a jump until the cursor is within 0.6 m): perfect 200 of 200 hits, 0.050 m, 2.0 frames;
sharp 197 of 198, 0.261 m, 26.1; regular 124 of 194, 1.042 m, 47.2; newcomer 43 of 193, 3.445 m, 75.8 (the shots that
are missing are taps lost to a lapse: 2, 6, 7).

Determinism: the hand draws from its own generator, seeded from `ctx.seed`, the profile and `stream`; it never draws
from `ctx.rng`, so the game's own seeded choices are the same under every hand. Same pack, seed, frames and profile
give the same `state_hash`. `perfect` draws nothing: a bot ported onto `TLHand.create(ctx, "perfect")` keeps its
result and its hash (`seed_paddle/tests/bot_win.gd`, seeds 1 to 10). Scaffold a bot on the hand with
`node devx/bin/tl.mjs new bot <name> --pack <dir> --hand regular`. When to read a result through a hand:
`engine/seeds/README.md`, "A bot is not a person".

## 16. Running and verifying

```
bash engine/tools/tl.sh lint       --pack=<dir>
bash engine/tools/tl.sh smoke      --pack=<dir> [--seed=1] [--frames=3600]
bash engine/tools/tl.sh invariants --pack=<dir> [--seed=1] [--frames=3600] [--bot-frames=36000]
bash engine/tools/tl.sh bot        --pack=<dir> [--test=tests/x.gd] [--seed=1] [--frames=36000] [--record=<file.json>]
bash engine/tools/tl.sh replay     --pack=<dir> --input=<file.json> [--record=<file.json>]   (a recorded session again; section 22)
bash engine/tools/tl.sh capture    --pack=<dir> --cam=<name> --out=<abs.png> [--frame=120] [--res=1920x1080] [--test=tests/x.gd] [--hud=off|on]
bash engine/tools/tl.sh play       --pack=<dir> [--record=<file.json>]   (a window and real keys; Esc quits; not a verify verb)
bash engine/tools/tl.sh selftest   [filter]
bash engine/tools/tl.sh seeds      [filter | sheet]      (every verb on the three seed packs in engine/seeds/)
```

Three complete small games to learn from are in `engine/seeds/` (start with `engine/seeds/README.md`).

The report (`tl.verify/1`) is the last line of stdout and the file given with `--report`. Exit codes: 0 passed,
1 a check failed, 2 could not run, 3 watchdog. `TL_QUIET=1` prints only the report line.

What the kernel adds to `contracts/RUNNER.md` (all additive):

- check `smoke.no_engine_errors`: errors Godot printed that have no pack script on the stack (kind `engine`);
- `invariants` and `bot` and `capture` also carry the four `smoke.*` checks of their run;
- `invariants` is four runs: the idle run twice (`invariants.determinism`, the budgets), then the manifest's **first
  bot twice** with the same seed (`invariants.bot_deterministic`: same `state_hash` after the same number of frames;
  error kind `determinism` with the bot's file). `--bot-frames` is the budget of each bot run (default 36000); a bot
  that is not done by then is still compared at that frame. Metrics `bot_state_hash`, `bot_frames`, and
  `bot_state_hash_b` when the two differ. A game that is only random once somebody plays it fails here;
- when two runs of one seed differ (`invariants.determinism` or `invariants.bot_deterministic` fails), the check's
  detail and the `determinism` error name **the first frame that differs and the first parts of the state that
  differ**: `first difference at frame 437: body World/Crate`, or `at frame 200: _pack_state.flips` (parts: `body
  <path under TLPack>` in tree order, `_pack_state.<key>`, `rng`, `input`; three named, the rest counted). A frame's
  hash is taken after the pack's calls of that frame, before its physics step: frame F is the frame whose
  `_pack_tick` (or bot tick, or the step before it) made the difference. Only a failing check pays for it: three more
  runs of the same verb and seed (`kernel/host/diverge.gd`, never counted toward a budget). When those runs do not
  differ, the detail keeps the sampled window (`at or before frame 600`) and says `not reproduced in the located re-run`;
- warnings: the `smoke.loads` detail ends with `WARNING: ...` when a pack script sits on a node but never runs (it
  was attached with `set_script` after `add_child`, or switched its own processing off). A warning fails nothing;
- `metrics.tick_ms_max`, and `metrics.state_hash_b` when two runs differ;
- `bot` without `--test` runs the first test of the manifest;
- `capture --test=<bot>`: a bot plays up to the captured frame (without it the capture shows the game with no input);
- `capture --hud=on` (K2): the still includes the pack's HUD (TLHud); by default (`off`) a capture is of the world alone;
- a bot that is not done within the frame budget: `bot.completed` false, an error of kind `bot` starting with
  `frame_budget:`, outcome `failed`, exit code 1 (exit code 3 is only for a run the watchdog had to stop);
- fence, beyond the contract's list: `randf_range(`, `randi_range(`, `randfn(`, `.shuffle(`, `.pick_random(`,
  `WorkerThreadPool` (other doors to the global random generator and to threads).
- **fence, since N4 (2026-11-11): lint reads every `.gd` in the pack wherever it sits, and refuses any file that is
  neither a script nor inert** (inert: `.json`, `.md`, `.txt`, `.png`, `.jpg`, `.jpeg`, `.webp`). No scene, resource,
  shader or library file in a pack. It also refuses, with a file and a line each:
  - reaching things by name: `.call(`, `.callv(`, `call_deferred`, `call_group`, `Callable(`, `.set(`,
    `set_deferred`, `set_indexed`, `set_script`, `.script =`. **Write instead:** call the method directly; assign the
    property directly (`node.speed = 3.0`, `d[k] = v`); make a helper with `ctx.load_script("scripts/x.gd").new()` and
    set its fields; run a lambda by passing it where it is used, not through `.call()`;
  - the tree above the pack: `get_tree` (any use, so no `create_timer`), `get_parent`, `get_root`, `get_window`,
    `get_viewport`, and any node path that is absolute, holds `..` or is not one plain literal. **Write instead:**
    keep the nodes you make in variables; count frames in `_pack_tick` for a delay; use `ctx.root` and `ctx.cameras`;
  - the engine's own servers and devices: `Input` and `InputMap` (use `ctx.input`), `Engine`, `OS`, `Time`,
    `DisplayServer`, `RenderingServer`, `PhysicsServer3D`, `AudioServer`, `Performance`, `ResourceLoader`,
    `PackedScene`, file, archive, network, multiplayer and crypto classes;
  - `load(` with anything but one whole literal path inside the pack or under `res://kits/`, `res://rigs/`,
    `res://style/`, `res://kernel/api/`.
  The full list with the reason for each rule: `res://kernel/share/SHARE.md`, section 6.
- `tl.sh play` runs lint first and refuses a pack that fails it.

**Bypasses** (`composability.bypasses[]`, each `{primitive, file, line, pattern}`; a figure, never a pass/fail, and it
should be `[]`): making `RigidBody3D`, `CharacterBody3D`, `VehicleBody3D`, `Area3D`, `Camera3D`, `AudioStreamPlayer*`,
`Timer` or particles with `.new()`; `apply_impulse`, `apply_force`, `move_and_slide`; an `_input` handler; a score or
clock variable while `rules` is declared; and, primitive `style`, any `StandardMaterial3D.new()`,
`ShaderMaterial.new()`, `ORMMaterial3D.new()`, `DirectionalLight3D.new()`, `OmniLight3D.new()`, `SpotLight3D.new()`,
`WorldEnvironment.new()`, `Environment.new()` (in `scripts/`, `gen/`, `tests/`); and, primitive `kit`, any
`BoxMesh.new()` or other `*Mesh.new()` and `MeshInstance3D.new()` in `scripts/` or `tests/` (geometry built in a
generator under `gen/` is counted once, in `kit_parts_added`).

Lint reads text only (comments and string contents are blanked first) and reports a file and a line for each
finding. A capability counts as used when a script names one of its classes (`TLBall` -> `ball`, `TLBodies`,
`TLTrigger`, `TLLaws`, `TLContact`, `TLDamage` -> `physics`, `.input` -> `input`, `.cameras`, `TLChaseCam`,
`TLOrbitCam` -> `camera`, and so on); the kernel also checks at run time.

## 17. What the kernel does not do yet

- **No real sandbox.** The fence is lint plus a watchdog; a pack script runs in the engine's process. `kernel/share/SHARE.md` section 1 lists
  what stays reachable. A scripted item from another player must not be installed until an isolation boundary
  exists (`docs/SHARING.md`).
- **Pairwise restitution between two tracked dynamic bodies** (ball against ball) uses the default pair law; the
  overrides apply against static and untracked bodies. A tracked body touching two surfaces at once follows one:
  the pair with the lower friction (the alphabetically first id on a tie), so the choice is the same in every run.
- **The frame-time budget and the 250 ms tick limit read a clock** (they cannot be counted in frames); everything
  else is frame-counted. Under heavy machine load the frame budget can be pessimistic; the better of two runs is judged.
- **Vehicles**: four wheels only, no gears, no differential, no drift model beyond the friction circle; wheels are
  rays (no kerb climbing by wheel shape). No two-wheelers, no boats, no aircraft.
- **Bipeds**: a capsule with intent-based movement; no ragdoll, no IK, no stairs handling beyond floor snap, no
  climbing or swimming. Skating has no backward skating or crossovers, and "stick handling" is plain pushing.
- **Balls**: no spin model beyond what the physics engine gives (no Magnus effect), no "possession" helper.
- **Rules**: one clock; no penalties, fouls, substitutions, tie-break ladders, or tournament structure.
- **AI**: steering helpers only; no path-finding (no navmesh), no behaviour trees, no team tactics.
- **Fracture**: needs a pre-fractured part; no run-time cutting; `bake = "mesh"` (one merged mesh) is not built.
- **Flammability, sound sets beyond contact hits, `breaks_into`** are in the table but nothing reads them yet
  (`breaks_into` is not used by fracture: pieces carry their own material tag).
- **HUD and audio are stand-ins**: plain labels (with an optional plate, K5), synthesised tones, no style applied. (VFX presets are drawn by the
  style layer since WP5.)
- **Input**: keys, the orbit camera's drag and wheel, and aims (the point on a ground plane under the cursor,
  `declare_aim`) for the player; mouse buttons as keys of a declared action (K2); no gamepad, no rebinding.
- **`requires`** in the manifest is checked for shape only; packs that need other packs are not loaded together.
- **Saving, networking**: none. **More than one pack per process**: only through the world host (section 19),
  headless, without the watchdog; the verify verbs still run one pack per process.
- **Class cache**: the runner refreshes it (`--import`) when kernel, kit, rig or style scripts change; two runners
  doing that at the same moment in one engine directory is untested.

## 18. How the runner works (for whoever spawns it)

- **Two processes.** The process you start is the supervisor (`kernel/host/host.gd`). `lint` runs in it (text only).
  Every verb that executes pack code starts a worker: the same executable and scene with `-- worker ...`
  (`kernel/runner/worker.gd`), one fresh process per run, with `--fixed-fps 60` so one loop iteration is exactly one
  physics frame at full speed. `invariants` is two workers.
- **Script errors** are caught twice. Inside the worker a `Logger` subclass registered with `OS.add_logger()` receives
  every error with file, line and the GDScript backtrace (so an engine error is attributed to the pack line that
  caused it). The supervisor also reads the worker's engine log (`--log-file`) and fails the run if it holds a
  `SCRIPT ERROR` the Logger never counted (for example one raised before the Logger existed).
- **Runaway scripts.** A thread in the worker watches each call into pack code; when one does not return in time it
  writes the result and ends the worker process. The supervisor then reports outcome `watchdog`, exit code 3.
- **Temporary files** live beside the report: `<report>.tmp<pid>.<n>.{result.json,log,alive}`; they are removed
  before the supervisor exits. Without `--report` they go to the engine's user data directory.
- **Windows for `capture`.** The supervisor itself may run `--headless`; it opens the worker's window at
  `--position 0,1440`. Windowed workers use Direct3D 12 (`--rendering-driver d3d12`; the
  project setting says the same for `play`), so every image comes from one backend. A worker that dies before its
  first line (seen on this machine as a graphics driver crash while a Vulkan window opened under GPU load) is started
  again, three attempts in all. `TL_RENDER_DRIVERS` (a comma list, for example `vulkan,d3d12`) overrides the order. The `capture.written` detail names the driver used.
- **Class cache.** The supervisor runs `godot --import` by itself when `.godot/global_script_class_cache.cfg` is
  missing or older than a script under `kernel/`, `kits/`, `rigs/` or `style/`.
- **If you kill the supervisor**, its worker ends by itself within about a minute (it watches a file the supervisor
  keeps fresh) or when its frames are done, whichever is first.
- Environment: `TL_GODOT`, `TL_ENGINE_DIR` (used by `tools/tl.sh`), `TL_RENDER_DRIVERS`, `TL_QUIET`, `TL_SELFTEST_DIR`.

## 19. A world of several packs (N2)

`bash tools/world.sh run --packs=<a>,<b>,...` runs several packs in ONE process (`kernel/world/world.gd`, one holder
per pack: `kernel/world/pack.gd`). It is a host mode, not a verify verb: it prints `tl.world/1` lines (one per pack
with its state hash, one for the world), no `tl.verify/1` report. Its options are in `kernel/runner/verbs.json`
under `modes`. `world.sh same` is the check that every pack hashes together as it does alone; `world.sh bench`
writes `kernel/world/BENCH.md`.

What a pack author has to know:

- **Nothing changes in a pack that follows this document.** The three seeds and the examples run unchanged, with
  the same hashes, alone and together.
- **A pack has its own clock.** `frame` and `ctx.frame` count the ticks the pack has had, not the world's. The
  kernel may give a pack fewer ticks than the world has (one in N, or none for a while); the pack then runs the
  same game, later. Do not read any other clock.
- **A pack has its own physics space**, its own input record (`ctx.input`), generator (`ctx.rng`), HUD layers,
  sound record (`TLAudio.events`, `TLAudio.count`) and ball group. Another pack cannot see or touch them, and two
  packs may stand on the same coordinates without meeting.
- **Stay in pack coordinates.** Build under `ctx.root`, place with `position`. A pack is simulated at its own
  origin today; code that reads `global_position` or passes a literal position to a call that wants a world
  position works only while that holds (see `kernel/world/BENCH.md`, test 5).
- **`TLContext.current` is "the pack the kernel is calling right now"**, not "the pack of the process". It is set
  during `_pack_setup`, `_pack_start`, `_pack_tick`, the bot's calls, while the scene tree ticks the pack's nodes
  (`_physics_process`, `_process`), and while a kernel primitive hands you a signal (`TLTrigger.entered`,
  `TLContact.hit`, `TLBall.bounced`, `TLDamage.broken`, `TLRules` signals). In a world it is null everywhere else:
  in a signal you connected yourself to a raw engine node (an `Area3D` or a `Timer` of your own, both bypasses), a
  static kernel call such as `TLAudio.play` has no pack and is recorded for nobody. Kernel code uses
  `TLContext.of(node)`.
- **Engine nodes that query physics by themselves** (`RayCast3D`, `ShapeCast3D`, `SpringArm3D`) and
  `get_world_3d().direct_space_state` look into the viewport's default space, where a world keeps no pack: they
  find nothing. Ask the kernel (`TLLaws.surface_under`, a `TLTrigger`); kernel code uses
  `TLContext.space_state_of(node)`. Joints were not tried in a world. No seed, example, kit or rig uses any of them.
- **A node of yours with a `process_physics_priority` other than 0** is ticked outside the bracket that names your
  pack (the kernel's own contact pass, `TLContact.Tracker`, is, and asks `TLContext.of`). Keep the default priority.
- **Not in a world yet**: the watchdog thread (a runaway `_pack_tick` hangs the whole world). `on_leave` and
  `footprint` are read by the scheduled world: section 20. A world in a window, with one camera and one HUD on
  screen at a time: section 21.
- **N7: `scenery = "plot"` is the default of the world host** in every mode (`world.sh run`, `walk`, `tour`, the
  viewer): your layout is built without its far terrain and scattered forest. `--scenery=full` brings them back.
  State hashes are the same either way (scenery has no body).

## 20. A world with a clock: tiers, `on_leave`, save and load (N5a)

`bash tools/world.sh walk <script>` runs a SCHEDULED world: every pack stands on a plot (`origin`, `footprint`), the
player's position comes from the script, and the scheduler (`kernel/world/tiers.gd`, thresholds in
`kernel/world/tiers.json`) decides every world tick which packs get it. The model, the proof and the numbers are in
`kernel/world/TIERS.md`. What a pack author has to know:

- **Your game is never switched off, but it may run slower.** `stage` (the player is in your plot) and `sideline`
  (near) get every world tick; `backdrop` (far) gets one tick in `slice` (2 to 30); when the whole world is too
  heavy every pack gets fewer ticks, equally. Each tick you get is a full 1/60 s step. You see only your own tick
  count (`frame`), as section 19 says; a game that is slowed plays exactly the same game, later.
- **`on_leave`** in `pack.json` says what happens when the player walks out of your plot: `"bot"` (your first test
  takes the player's side; the default, because every pack has a test), `"pause"` (the game holds: no ticks until
  the player is back) or `"end"` (the run ends there; when the player returns the pack is built again from its seed).
- **`footprint`** (`{"size_m": [x, z], "height_m": h}`) is your plot, centred on your origin. Without it the world
  assumes 40 x 40 m. The player is "inside" when he stands on it; he has left when he is 2 m outside it.
- **`_pack_save() -> Dictionary` and `_pack_load(data: Dictionary)`** (both optional, both or neither). A world file
  (`world.sh save`, `tl.world/1`) and the `ledger` tier (a pack that is not in memory) keep of your game only: its
  seed, its tick count, a summary (phase, score and clock of your `TLRules`, if you have one) and what `_pack_save`
  returns (plain data: numbers, strings, arrays, dictionaries). On the way back the pack is BUILT AGAIN FROM ITS
  SEED: bodies, positions and velocities start as on the first tick. Then `_pack_start()` is called, then
  `_pack_load(data)`. Without the two functions the game simply starts again. `kernel/examples/ex_bounce` is the
  example (the score survives, the balls do not).
- **Scenery.** A world loads you with `scenery = "plot"` (`ctx.scenery`; the default since N7): a `tl.layout/1`
  file read through `ctx.read_json` then comes with `forest.scatter` and `terrain.far` off. Do not look scenery
  nodes up by name.
- **N7: a pack that is built again** (back from `ledger`, after `on_leave: end`, for its next round) gets its first
  tick one world tick after it was built. You cannot see this: your own tick count starts at 0 as always.
- **`TLVfx.squash` and `TLVfx.trail`** (section 13) are new; lint's `composability` now also reports
  `kit_parts_used`, `kit_kinds_used`, `kit_build_calls` and `world_coordinates` (how often your scripts read
  `global_position`, `global_transform`, `to_global(` or `look_at(`: each is a place that breaks when a pack is not
  simulated at its own origin). Figures, never findings.

Commands: `world.sh walk <script> [--log=<file>] [--cost=model|measured]`, `world.sh replay <log>`,
`world.sh proof <script>`, `world.sh save <file> --packs=...`, `world.sh load <file>`. Formats: a walk script is
`tl.walk/1` (`kernel/world/walks/*.json`), a world log `tl.worldlog/1`, a world file `tl.world/1` (TIERS.md).

## 21. One world you can walk through: the visitor, entering and leaving, next rounds (N7)

`bash tools/world.sh tour <walk> --out-dir=<abs dir>` runs a scheduled world in a window (host mode `world-view`,
`kernel/world/draw/view.gd`): every pack on its plot in one landscape, a visitor who walks between them, numbered
pictures, and the proof that every pack's state hash equals the same pack alone and the replay of the world log.
`--headless` is the same world without the window. `kernel/world/WORLD.md` has the whole picture and the walk format.
What a pack author has to know:

- **The player is a visitor first.** While he walks the world nobody is on stage: no pack's camera, no pack's HUD,
  no pack's input. Near packs run at full rate and are drawn in full; far ones run slower and are drawn as their
  stand-in (sections 19, 20; `kernel/world/draw/DRAW.md`).
- **Entering.** The visitor stands in your plot and presses E (a walk script: `{"t": N, "e": "enter"}`). From that
  world tick `ctx.on_stage` is true, your HUD layers are visible and your active view (`ctx.cameras.active`: the
  first view you registered, unless you activated another) is the picture. Before that, and from your very first
  line of `_pack_setup`, `ctx.on_stage` is false and a HUD you make is created hidden: do not set `visible` on a
  `TLHud` yourself, and do not make a camera current yourself (`Camera3D.current`, `make_current`): the kernel does.
- **Leaving.** Q or Esc (`{"t": N, "e": "leave"}`): the picture goes back to the visitor and your `on_leave` applies
  (section 20). In a scripted run your bot plays before, during and after the visit, so a visit changes nothing in
  your game. When a person plays, your bot waits while he is in and takes over again when he leaves (`on_leave:
  "bot"`); this path has not been run by anyone yet.
- **Next round (paused by the owner on 2026-11-11: `restart_pause_ticks` ships as 0, a finished game stays over).**
  When the key is set, a game that is over with nobody in its plot is built again from its seed after that many world
  ticks: `_pack_setup`, `_pack_start`, tick 0, nothing carried over. On stage a finished game waits until the player leaves. Keep no state in `static var`.
- **Your plot.** Declare `"footprint": {"size_m": [x, z]}` in `pack.json`. You are cut to the circle inside it; the
  world draws its own ground, a road to your gate and a fence around you. Keep what matters inside, and leave the
  outer 9 m to your ground (it is bent to meet the world's).

Commands: `world.sh tour <walk> --out-dir=<abs dir> [--pictures-only]`, `world.sh tour <walk> --headless`,
`world.sh visit <walk>`; `tools/view.sh shot / check` (pictures of a world of packs, every pack ticked every frame)
start the same host mode.

## 22. The contract: API version 1, the input record, the state hash (P7)

A game reaches the engine through two things only: the kernel API of this file, and its input as the kernel latched
it. Both are written down so that a game's code can later run somewhere else (another thread, another process,
another machine) without the game being rewritten.

**API version.** `kernelApi` in `pack.json` is `major.minor`. A pack runs when its major equals the kernel's and its
minor is not greater. `"0.1"` is the name this surface had before it was frozen and is read as `"1.0"`. Anything else
is refused by lint and by every verb with a sentence that says why (`kernelApi '2.0' cannot run on this kernel, which
offers API <KERNEL_API>: the pack was built for major version 2 and this kernel is major version 1 ...`).
`docs/generated/API-V1.json` lists every public class of `kernel/api`, the kit, the rigs and the style:
what it extends, its methods with their full signatures, signals, properties and constants. `node devx/bin/tl.mjs arch`
(rule `api-v1`) fails when one of them is removed or changed while the major is the same, and names it; an addition
(a new member, or parameters with defaults at the end of a method) needs a new minor. `tl arch --index` regenerates
the file and refuses to write over a break. Names that start with `_` are the kernel's side and no part of the contract.

**1.8 addition.** TLBiped accepts walker feel and a slide action. Section 6 describes the shared visitor controller and its collision heights.

**The input record, `tl.input/1`.**
```
{"schema": "tl.input/1", "pack": "seed.paddle", "seed": 1, "mode": "bot", "max_frames": 36000,
 "length": 4486, "end": "tick", "frames": [[110, "left", 1], [111, "left", 1], [112, "left", 0.42], ...]}
```
`frames` has one entry for every action whose value was not zero in a frame, in frame order (a key held for a second
is sixty entries; the pointer is `tl.look_x`, `tl.look_y`, `tl.zoom`; a valid aim is `"<aim>"` with 1 and its point as
`"<aim>@x"`, `"<aim>@z"`, section 8). `length` is the number of frames the session
ticked; `end` is `"step"` when it stopped after the physics step of its last frame (play, Esc) and `"tick"` when it
stopped inside its last frame (a bot that said it was done); `mode` and `max_frames` are what `ctx.mode` and
`ctx.max_frames` were, and a replay sets them again. All eight keys are required, unknown keys are errors.
- `tl.sh play --pack=<dir> --record=<file>` writes a person's session; `tl.sh bot --pack=<dir> --record=<file>` a bot's.
- `tl.sh replay --pack=<dir> --input=<file>` runs it again without a window: the record's samples and nothing else
  (no bot is loaded, no device is read), the record's seed and length. A `tl.verify/1` report: the V2 checks,
  `replay.complete`, and `metrics.state_hash`, which is the hash of the recorded session. `--record` writes the
  replay's own input, which is the same file.
- For tests there is a scripted session without a window: `tl.sh play --pack=<dir> --headless --frames=N
  --devices=<file> [--record=<file>] [--result=<file>]`, where the devices file is a JSON list of
  `[frame, kind, a, b]`: `key` (name, 1 or 0), `button` (`left`, `right`, `middle`; 1 or 0; K2), `drag` (dx, dy with the right button), `wheel` (1 out, -1 in),
  `field` (1: a text field takes the keyboard, 0: gives it back), `panel` (1: the designer panel is open), `close`
  (the window's close button). The events go through the engine's own input path.
- A session ends with Esc or when the window is closed; the record is written either way.

**The state hash** covers every physics body under the pack, `_pack_state()`, the seeded generator (`ctx.rng`: seed
and state) and the input state (every action's value in this frame and the one before; each aim's validity and point). Two runs that look alike and
would differ in their next random number, or in a key that is held, do not hash alike. (The world's own hash of a
pack, `kernel/world/pack.gd`, does not cover the generator and the input yet: `kernel/api/PATCHES-P7.md`.) The
worker's result file (`--result`) also has `hash_parts`: the bodies-and-state hash alone, the generator's state and
the number of input frames, for the day two runs differ and one wants to know in what.

**The fence follows the seam** (lint, since P7): besides everything in section 16, a pack may not
- read a device past `ctx.input`: `InputEventKey` and its siblings, `_gui_input` / `_unhandled_key_input` /
  `_shortcut_input` handlers, `set_process_input`, mouse positions, controls that take clicks or keys (`Button.new()`,
  `LineEdit.new()`, ...), `accept_devices`. (`_input` and `_unhandled_input` handlers are still counted as bypasses,
  as the pack contract says, and the kernel switches them off: they never run.)
- take time from anywhere but the tick count: `func _process(` (it runs once per drawn picture), `Timer`,
  `create_tween` / `Tween`, `AnimationPlayer`, `get_process_delta_time`.
- reach another pack or the kernel's side: `get_world_3d()`, `ctx.holder`, `get_nodes_in_group`, `TLContext.current`,
  any member of `ctx`, `ctx.input` or `ctx.cameras` whose name starts with `_`.

**Keys and the panel.** While a `LineEdit` or `TextEdit` has focus, the game gets no key (`ctx.input.keys_taken()`);
Esc does not end an interactive run while a `CanvasLayer` named `TLDesigner` is visible under the worker.

## 23. Dungeons: one pack alone in the game's own process (L4, night of 21 Nov)

Nothing a pack calls changed: no class, no member, no `ctx` field was added (kernel API stays 1.11). What is new is a
driver beside the worker, so a pack can be a **dungeon**: entered from the exe's main menu, or opened by
`--dungeon=<pack dir>`, with the world unloaded and the pack's own camera, HUD and look on the screen.

- `kernel/dungeon/dungeon.gd` (no class_name) drives `runner/pack_life.gd` in the worker's order, in mode `"play"`
  (`ctx.mode == "play"`, `ctx.on_stage == true`, devices on, no bot). So a pack sees exactly what `tl play` gives it,
  and a counted run (`--frames=N`) hashes as `worker --mode=play --frames=N` of the same seed (selftest 640,
  `dungeon.hash_alone`; `export.sh check` step 1b in the exe). It lints first (a pack outside the fence is refused),
  counts script errors with the runner's logger (more than 20 stop it), and has no watchdog thread.
- Esc belongs to the dungeon: it opens the pause card (Resume, Leave) and pauses the tree (the physics too). As in a
  world, where Esc leaves the game, a pack should not put an action on Esc.
- `kernel/dungeon/dungeons.gd`: the list `engine/boot/dungeons.json` (`tl.dungeons/1`: `{pack, title, look?}`; `look`
  is a `TL_STYLE` name), `resolve`, `look_path`, and the launch seam `launch(<pack dir>)` (a second game process that
  opens that folder as a dungeon; its "Back to Create" ends it).
- `kernel/dungeon/look_ui.gd`: the crisp 2D look of the menu and the cards (colours read from `style/style_crisp.json`).
- L4b: `kernel/dungeon/watch.gd`, the dungeon's watchdog: the worker's limits (a tick 250 ms, a setup call 10 s, of
  processor time, `kernel/host/cpuclock.gd` `verdict`) through PackLife's `on_begin` / `on_end`. A runaway ends the
  process after it starts the card process on its record (`boot.tscn -- --tripped=<record>`). A pack meets the same
  limits in a dungeon as in `tl.sh smoke` or `bot`.
- L4b: `PackLife.load_steps()` returns `load_entry`'s load as separate steps (each asset generator, then the entry);
  `load_entry()` runs them in one go, as before. A driver that draws frames between them keeps the pack's nodes from
  running and the physics server off until the last step (the dungeon does).

## 24. Game cores: `ctx.cores` (class `TLCores`, addition in 1.18)

A core is a reference game's own simulation compiled whole into the engine (`engine/cores/<id>/`), stepped by a pack
frame by frame. The pack keeps the keys and the drawing; the core keeps the rules, the bodies and the bots. The one
core today is `rink`: thirdjam's hockey (JamCore, compiled unchanged; `engine/cores/rink/SNAPSHOT.md` is its interface).

| Member | Does |
|---|---|
| `ctx.cores.open(id, cartridge = "") -> Object` | the core `id` as an object (`"rink"`: a `RinkCore`). `cartridge`: a file under the pack's `data/`, loaded into the core as text. Null and an error when the id is unknown, the core is not built (the error names the build command), or the cartridge does not load |
| `ctx.cores.state() -> Dictionary` | `{"<id>": {"hash": 16 hex digits, "frame": int, "score": [a, b]}}` for every core the pack opened (`"<id>#2"` for a second one). Return it from `_pack_state()` (or put it under a key of it): the core's own state hash then enters the run's `state_hash`, so the determinism laws hold for what the core simulates |

```gdscript
var rink

func _pack_setup(c) -> void:
	ctx = c
	rink = ctx.cores.open("rink", "hockey.regular.cartridge.json")
	rink.set_difficulty("pro")
	rink.set_human_mode("input")       # the human's skater reads set_human_input; the rest are the core's bots
	rink.reset(ctx.seed)

func _pack_tick(_f: int) -> void:
	rink.set_human_input({"Move": ctx.input.vector(&"left", &"right", &"down", &"up"), "bSprint": ctx.input.pressed(&"sprint")})
	rink.step()

func _pack_state() -> Dictionary:
	return ctx.cores.state()
```

- `ctx.cores: TLCores` (1.18) belongs in the table of section 2 (the Director adds the row at the merge).
- No capability: `ctx.cores` is always there. A pack never loads an extension and never names a core's class.
- The core steps only when the pack calls `step()`: one call per `_pack_tick` keeps it on the kernel's frames.
- What the core's methods are and every field of its per-frame `snapshot()`: `engine/cores/rink/SNAPSHOT.md`.
- Proof that the same seed and input give the same hash through the runner (two bot runs, a replay of the record, a
  window replayed headless): selftest `800-rink-core.sh`; the probe pack `engine/cores/rink/test_pack`.
