# Third Life kernel API (kernelApi 0.1)

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
| `TLLaws.material(id) -> Dictionary` | one row; an unknown id is an error and answers with concrete |
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
| tuning | `walk_speed` 2.3, `run_speed` 6.0, `accel` 28, `turn_rate` 10, `skate_speed` 9.5, `skate_accel` 6.5, `skate_lateral_grip` 2.2, `skate_turn_rate` 2.8, `skate_brake` 9, `jump_speed` 4.5, `body_mass` 80, `push_strength` 1, `sole_material` rubber, `blade_material` steel |

Walking: velocity moves toward the intent at `accel` x grip, where grip is the pair law of `sole_material` and the
surface under the feet (walking on ice is slow to start and stop). Skating: thrust along the facing, the facing
turns toward the intent at `skate_turn_rate`, sideways slip dies slowly (`skate_lateral_grip`), and the glide
decelerates by the pair law of `blade_material` and the surface (steel on ice 0.015: a long glide). It pushes dynamic
bodies it runs into (a puck, a ball, a crate) and reports the impact to `TLDamage`.

```gdscript
var skater: TLBiped = TLBiped.create({"mode": "skate", "position": Vector3(0, 0.05, 0)})
ctx.root.add_child(skater)
func _pack_tick(_frame: int) -> void:
    skater.drive_from_input(ctx.input, {"left": &"left", "right": &"right", "forward": &"up", "back": &"down", "brake": &"stop"})
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
| `wheel_surface: PackedStringArray`, `wheel_grounded: Array`, `wheel_compression`, `nitro_charge` (0..1), `nitro_active` | |
| signals `nitro_started()`, `nitro_ended()`; `contact: TLContact` (`contact.hit` for crashes) | |
| tuning | `engine_force` 9000 N, `brake_force` 16000 N, `top_speed` 42 m/s, `reverse_speed` 9, `max_steer_degrees` 30, `min_steer_degrees` 8, `lateral_grip` 1, `suspension_travel` 0.3, `suspension_damping` 0.55, `nitro_force` 9000 N, `nitro_frames` 150, `nitro_recharge_frames` 900, `drive` (`&"rear"`, `&"front"`, `&"all"`), `tyre_material` rubber, `body_material` steel, `air_drag`, `rolling_resistance`, `anti_roll` |

Each wheel takes its grip from the surface under it: pair law of `tyre_material` and that surface (untagged ground
counts as 0.9). Measured in `ex_car`: braking from 14 m/s takes 10.1 m on asphalt and 96 m on ice.

## 8. `TLInput` (capability `input`), reached as `ctx.input`

One door for the player, for bots and for replays. Values are latched once per frame.

| Member | Meaning |
|---|---|
| `declare(action: StringName, keys: Array = [])` | declare before use; `keys` are physical key codes (`KEY_W`, `KEY_SPACE`) for interactive play |
| `strength(action) -> float`, `pressed(action)`, `just_pressed(action)`, `just_released(action)` | reading |
| `axis(negative, positive) -> float`, `vector(left, right, up, down) -> Vector2` | y = down - up, as `Input.get_vector` |
| `press(action, value = 1.0)`, `release(action)`, `tap(action, frames = 1)`, `set_axis(negative, positive, value)`, `release_all()` | **injection**: what a bot calls in `_bot_tick` |
| signals `action_pressed(action)`, `action_released(action)`; `declared() -> PackedStringArray` | |

Real keys are read only in interactive play (`tools/tl.sh play`); verify runs ignore every device, so a stray key
press cannot change a result. Using an undeclared action is an error. AI opponents do not need actions: give them
intents directly (`biped.move()`, `vehicle.set_controls()`).

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
| `ctx.cameras.chase(target, opts = {}, view = &"chase") -> TLChaseCam` | follows from behind. Options `distance` (7), `height` (3), `look_height` (1), `stiffness` (0.12: how fast the heading turns), `follow` (0.3: how fast the place catches up), `aim` (0.5: how fast the point looked at catches up), `use_velocity`, `fov` (**58**) |
| `ctx.cameras.orbit(target, opts = {}, view = &"orbit") -> TLOrbitCam` | yaw free, **pitch held to 30..60 degrees**, distance to a range. Options `yaw`, `pitch`, `distance`, `distance_min`, `distance_max`, `look_height`, `yaw_rate`, `pitch_rate`, `zoom_rate`, `fov` (**50**), `smooth` (0.25: share of the remaining way the drawn camera covers each frame; 1 = rigid) |
| `ctx.cameras.activate(name) -> bool`, `views()`, `has_view(name)`, `view(name) -> Camera3D`, `active` | the first view registered is active until you say otherwise |
| `ctx.cameras.frame(subject, fill = 0.35, view = &"")` | places a view (default: the active one) so that `subject` covers `fill` of the frame height. A chase camera keeps its angle and changes `distance` and `height`; an orbit camera changes `distance` (and widens its range to hold it); a fixed view moves along its line of sight and looks at the subject's centre. Call it in `_pack_setup` after the camera was made and the subject is in the tree. It also names the subject as the view's main actor |
| `ctx.cameras.subject_px(subject) -> float` | how much of the frame height `subject` covers now in the active view: the height of the screen rectangle around its visible meshes, clipped to the frame; 0 when off screen or behind the camera. 0.08 is a small actor, 0.2 a clear one, 0.35 a portrait |
| `ctx.cameras.set_subject(view, subject)`, `subject_of(view) -> Node3D` | names the main actor of a view without moving it (a fixed view that must keep a whole court in sight) |
| `ctx.cameras.shake(amount, frames)` | impact shake on the active view: `amount` metres at the lens (0.05 a tap, 0.3 a crash), fading over `frames` physics frames. A stronger shake still running is kept |
| `TLOrbitCam.orbit_by(yaw_deg, pitch_deg)`, `zoom_by(metres)`, `bind_actions(input, {yaw_left, yaw_right, pitch_up, pitch_down, zoom_in, zoom_out})`, `yaw_basis() -> Basis` | in interactive play it also takes right-button mouse drag and the wheel |
| `TLChaseCam.snap()`, `TLOrbitCam.snap()` | puts the camera where it wants to be at once (after a teleport, a cut, or a change of `distance`) |

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

**`TLHud`** (a `CanvasLayer`; stand-in look): `TLHud.create()`, `add_score(rules, side, anchor, caption = "")`,
`add_clock(rules, anchor)`, `add_speed(callable, unit, anchor)`, `add_label(id, text, anchor)`,
`add_bound(id, callable, anchor)`, `set_text(id, text)`, `text_of(id)`. Anchors `top_left top top_right left center
right bottom_left bottom bottom_right`. Captures hide the HUD. Widget ids for `text_of` / `set_text`: `score_<side>`,
`clock`, `speed`, and the id you gave to `add_label` or `add_bound`.

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

## 16. Running and verifying

```
bash engine/tools/tl.sh lint       --pack=<dir>
bash engine/tools/tl.sh smoke      --pack=<dir> [--seed=1] [--frames=3600]
bash engine/tools/tl.sh invariants --pack=<dir> [--seed=1] [--frames=3600] [--bot-frames=36000]
bash engine/tools/tl.sh bot        --pack=<dir> [--test=tests/x.gd] [--seed=1] [--frames=36000]
bash engine/tools/tl.sh capture    --pack=<dir> --cam=<name> --out=<abs.png> [--frame=120] [--res=1920x1080] [--test=tests/x.gd]
bash engine/tools/tl.sh play       --pack=<dir>          (a window and real keys; Esc quits; not a verify verb)
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
- warnings: the `smoke.loads` detail ends with `WARNING: ...` when a pack script sits on a node but never runs (it
  was attached with `set_script` after `add_child`, or switched its own processing off). A warning fails nothing;
- `metrics.tick_ms_max`, and `metrics.state_hash_b` when two runs differ;
- `bot` without `--test` runs the first test of the manifest;
- `capture --test=<bot>`: a bot plays up to the captured frame (without it the capture shows the game with no input);
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
- **HUD and audio are stand-ins**: plain labels, synthesised tones, no style applied. (VFX presets are drawn by the
  style layer since WP5.)
- **Input**: keys only for the player (no gamepad, no mouse actions except the orbit camera in play), no rebinding.
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
  pack (the kernel's own `TLContact` is, and asks `TLContext.of`). Keep the default priority.
- **Not in a world yet**: the watchdog thread (a runaway `_pack_tick` hangs the whole world), windowed play and
  capture (one camera, one HUD on screen). `on_leave` and `footprint` are read by the scheduled world: section 20.

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
- **Scenery.** A world may load you with `scenery = "plot"` (`ctx.scenery`): a `tl.layout/1` file read through
  `ctx.read_json` then comes with `forest.scatter` and `terrain.far` off. Do not look scenery nodes up by name.
- **`TLVfx.squash` and `TLVfx.trail`** (section 13) are new; lint's `composability` now also reports
  `kit_parts_used`, `kit_kinds_used`, `kit_build_calls` and `world_coordinates` (how often your scripts read
  `global_position`, `global_transform`, `to_global(` or `look_at(`: each is a place that breaks when a pack is not
  simulated at its own origin). Figures, never findings.

Commands: `world.sh walk <script> [--log=<file>] [--cost=model|measured]`, `world.sh replay <log>`,
`world.sh proof <script>`, `world.sh save <file> --packs=...`, `world.sh load <file>`. Formats: a walk script is
`tl.walk/1` (`kernel/world/walks/*.json`), a world log `tl.worldlog/1`, a world file `tl.world/1` (TIERS.md).
