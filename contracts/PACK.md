# Pack contract (kernelApi 1.0)

A **pack** is one game or one reusable bundle: the unit of build, verification, promotion and rollback. A game is one
pack. The Foreman's **packages** are slices of a pack with disjoint file scopes (see `JOB.md`).

## Layout

```
<pack_dir>/
  pack.json        manifest (schema: contracts/pack.schema.json)
  scripts/         GDScript; scripts/<entry> is the entry script
  data/            JSON only: laws, tuning, layouts, rules. Data first, script second.
  gen/             asset generators: GDScript that builds kit parts or meshes at load time
  assets/          build outputs only (may be empty); never hand-made files
  tests/           bots and invariants; every pack ships at least one bot
  examples/        optional small usage examples
```

A pack may live anywhere on disk (a build workspace) or under `res://packs/<id>/` (promoted) or `res://seeds/<id>/`
(seed). The kernel loads it from the directory it is given.

## Manifest `pack.json`

| Key | Type | Required | Meaning |
|---|---|---|---|
| `id` | string, `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$` | yes | namespaced id, for example `seed.paddle`, `game.hockey` |
| `version` | string, semver | yes | pack version |
| `kernelApi` | string, `major.minor`, `"1.0"` today | yes | the kernel API the pack was built against. The pack runs when its major equals the kernel's and its minor is not greater. `"0.1"` is the name this surface had before it was frozen and is read as `"1.0"`. Anything else is a schema error that says which side is ahead. |
| `title` | string | yes | shown on the site and in logs |
| `capabilities` | string[] from the list below | yes | what the pack asks the kernel for; using an undeclared one is a V1 failure |
| `entry` | string, path under `scripts/` | yes | entry script |
| `assets` | string[] of paths under `gen/` | yes (may be `[]`) | asset generators, run before `entry` |
| `tests` | string[] of paths under `tests/` | yes, at least one | bot scripts |
| `requires` | string[] of pack ids | no | other promoted packs this one needs |
| `cameras` | string[] | no | named capture views the pack provides (for V5) |

Capabilities: `physics`, `input`, `ui`, `audio`, `vfx`, `camera`, `rules`, `ai`, `spawn`, `fracture`, `vehicle`,
`biped`, `ball`, `kit`, `style`.

## Scripts

Duck-typed, no base class required and **no `class_name`** in pack scripts.

Entry script (a `Node` script):

| Method | When |
|---|---|
| `_pack_setup(ctx) -> void` | once, after asset generators; build the scene under `ctx.root`, register rules |
| `_pack_start() -> void` | once, when the sim starts (frame 0) |
| `_pack_tick(frame: int) -> void` | every physics frame (optional) |
| `_pack_state() -> Dictionary` | optional; game state to fold into `state_hash` and to show bots (scores, lap, clock) |
| `_pack_teardown() -> void` | once (optional) |

Asset generator (`gen/*.gd`): `static func generate(ctx) -> void`.

Bot (`tests/*.gd`, a `Node` script): `_bot_setup(ctx) -> void`, `_bot_tick(frame: int) -> void`,
`_bot_done() -> bool`, `_bot_result() -> Dictionary` with at least `{"ok": bool, "summary": String}` plus any numbers.
A bot drives the game **only through input actions and the kernel API**, the same door a player uses, and decides
`ok` from game state. A bot must finish within the frame budget the runner gives it (`ctx.max_frames`).

`ctx` is the kernel's context object. Its members are WP1's to define and document in `engine/kernel/API.md`; these
names are fixed here because other packages rely on them: `ctx.root` (Node3D the pack builds under), `ctx.rng`
(seeded `RandomNumberGenerator`), `ctx.seed` (int), `ctx.frame` (int), `ctx.max_frames` (int), `ctx.pack_dir` (String),
`ctx.pack_id` (String), `ctx.headless` (bool).

## The fence (V1 lint; a guardrail against mistakes, not a security boundary)

Pack scripts must not contain, anywhere: `class_name`, `@tool`, `OS.`, `FileAccess`, `DirAccess`, `ResourceSaver`,
`ProjectSettings.`, `Engine.get_singleton`, `ClassDB.`, `HTTPRequest`, `HTTPClient`, `StreamPeer`, `TCPServer`,
`UDPServer`, `PacketPeer`, `WebSocketPeer`, `ENetConnection`, `Thread`, `Mutex`, `Semaphore`, `JavaScriptBridge`,
`Expression`, `GDScript.new`, `str_to_var`, `bytes_to_var`, `get_tree().root`, `change_scene`, `get_tree().quit`,
`Time.get_ticks`, `Time.get_unix`, `WorkerThreadPool`, `randf(`, `randi(`, `randomize(` and every other door to the
global generator (`randf_range(`, `randi_range(`, `randfn(`, `.shuffle(`, `.pick_random(`; use `ctx.rng`), and `load(`/`preload(` of any path
that is not inside the pack, `res://kits/`, `res://rigs/`, `res://style/` or `res://kernel/api/`.

Reading the pack's own `data/` goes through the kernel (`ctx` gives a JSON reader). Size limits (V1): one script at
most 600 lines, the pack at most 6,000 lines of GDScript, `data/` at most 2 MB.

## Composability figures (reported by lint for every pack, never a pass/fail)

- `gdscript_lines`: non-blank, non-comment lines under `scripts/`, `gen/` and `tests/`, each counted separately.
- `kit_parts_added`: generators under `gen/` that build geometry not obtained from `TLKit`.
- `bypasses[]`: places where a pack script does by hand what a kernel primitive exists for. Each entry is
  `{primitive, file, line, pattern}`. Minimum patterns: creating `RigidBody3D`, `CharacterBody3D`, `VehicleBody3D`,
  `Area3D`, `Camera3D`, `AudioStreamPlayer*`, `Timer`, `GPUParticles3D`/`CPUParticles3D` with `.new()`; calling
  `apply_impulse`/`apply_force`/`move_and_slide` directly; an `_input`/`_unhandled_input` handler; a hand-rolled score
  or clock when the pack declares `rules`.

## Amendments of 2026-11-10, second round (after WP4)

- `README.md` is allowed at the pack root (optional). It and `pack.json` are the only files there.
- A game need not use `ctx.rng`. "A different seed gives a different hash" is not a gate; "the same seed gives the
  same hash" is.

## Amendments of 2026-11-11 (night plan): optional manifest fields

`kernelApi` was `0.1` then; it is `1.0` since P7 (2026-11-11). All five fields are optional; a pack that leaves one out behaves as before. The runner
validates their shape (`engine/kernel/runner/manifest.gd`).

| Field | Shape | Meaning | Read by |
|---|---|---|---|
| `footprint` | `{"size_m": [x, z], "height_m": h}` | the ground the pack needs, centred on its origin, in metres | the world mode, when it gives the pack a plot |
| `params` | `[{"name", "file", "path", "min", "max", "step", "label"}]` | values a player may change without a build: `file` is a JSON file under `data/`, `path` a dotted path in it | the designer panel's sliders |
| `on_leave` | `"bot"`, `"pause"` or `"end"` | what the game does when the player walks out of its plot | the world scheduler |
| `subject` | a node name under the pack's `World` | the thing a picture of this game is about | capture (`subject_frac` metric), camera framing |
| `moments` | `[{"name", "frame"}]` or `[{"name", "event"}]` | the frames worth a picture | capture, at milestones |

The single list of runner verbs and options is `engine/kernel/runner/verbs.json` (`tl.verbs/1`). `RUNNER.md` describes
them; the file is what tools read.

A shareable item's card (`item.json`, `tl.item/1`) and package (`.tlitem`) are specified in `docs/SHARING.md`.

### The fence after N4 (2026-11-11)

- Lint reads every `.gd` file of a pack wherever it sits, and refuses any file that is neither a script nor inert
  (`.json`, `.md`, `.txt`, `.png`, `.jpg`, `.jpeg`, `.webp`, each checked against its bytes). The same table decides
  an item's tier (`docs/SHARING.md`).
- Allowed at the pack root besides `pack.json` and `README.md`: `item.json`; a `preview/` folder for pictures.
- Newly refused: reflection (`call`, `callv`, `call_deferred`, `Callable(`, `.set`, `set_script` and kin), the tree
  above the pack (`get_tree`, `get_parent`, `get_root`, `get_window`, `get_viewport`, absolute or `..` node paths),
  the engine's servers and devices (`Input`, `Engine`, `DisplayServer`, `RenderingServer`, `PhysicsServer3D`,
  `AudioServer`, `Performance`), resource, archive, network, multiplayer and crypto classes, a `load(` whose argument
  is not one whole literal. `OS`, `ProjectSettings` and `ClassDB` now match as bare words. The list with the bad pack
  that proves each rule: `engine/kernel/share/SHARE.md` section 6.
- `tl.sh play` lints first. Starting the worker directly still skips lint.
- This is a guardrail against accidents, not a security boundary: `SHARE.md` section 1 lists what stays reachable.

### Added with the core run (2026-11-11)

- A pack's tracked dynamic bodies are updated by one kernel pass per tick, in the order the bodies entered the
  tree. Do not rely on a per-body `TLContact` callback. A body that needs no surface laws and no hit signals
  should be made with `track = false`.
- Budgets (`contracts/RUNNER.md`, amendments of 2026-11-11): a game on stage may cost 4 ms a frame at the 99th
  percentile; as one of many, 1 ms at the median with a target of 0.5 ms.
- In a world a pack stands on a level pad at its plot's height and the world's ground meets its rim. A copy of
  its static colliders is made in the world's own physics space for the visitor; the pack's bodies are never
  touched. A pack whose own ground is a hollow is not walkable from outside yet.

## Amendments of 2026-11-11 (core run, P7): the simulation contract
A game reaches the engine through the kernel API and its recorded input, nothing else.

**API version.** `docs/generated/API-V1.json` (`tl.api/1`: `{schema, version, note, classes: {<Class>: {file, extends, consts[], signals[], props[], funcs[]}}}`) is generated from the sources and is the contract of the version in `engine/kernel/runner/manifest.gd`. Removing or changing a listed member needs a new major. Adding one needs a new minor; a method that gains parameters with defaults at its end is an addition. Names starting with `_` are not part of it. `tl arch` rule `api-v1` enforces this and names the member.

**Input record `tl.input/1`.** `{"schema", "pack", "seed", "mode", "max_frames", "length", "end", "frames": [[frame, "action", value], ...]}`. All eight keys are required; unknown keys are errors. `frames` has one entry per action whose value was not zero in a frame, in frame order. `length` is the frames ticked. `end` is `"step"` (stopped after the last frame's physics step) or `"tick"` (stopped inside the last frame: a bot that was done). `mode` and `max_frames` are what `ctx` told the pack.

**Input values** are multiples of 0.001, rounded when latched. The pointer is three kernel actions declared in every pack: `tl.look_x`, `tl.look_y` (pixels of a right-button drag in the frame) and `tl.zoom` (wheel notches, + is out).

**State hash** covers every physics body under the pack, `_pack_state()`, the seeded generator (seed and state) and the input state (every action's value in this frame and the one before).

**Fence, added.** Refused: `InputEvent*` subclasses, `_gui_input` / `_unhandled_key_input` / `_shortcut_input` handlers, `set_process_input`, mouse positions, controls that take clicks or keys, `accept_devices`; `func _process(`, `Timer`, `create_tween` / `Tween` / `AnimationPlayer`, `get_process_delta_time`; `get_world_3d`, `ctx.holder`, `get_nodes_in_group`, `TLContext.current`, any `_` member of `ctx`, `ctx.input` or `ctx.cameras`. `Timer.new()` was a counted bypass and is now refused. An `_input` / `_unhandled_input` handler is still a counted bypass and never runs: the kernel switches it off.

## Amendments of 2026-11-11 (core run, P5 and P6): a pack in a world

**Loading (P5).**

- In a world your pack is built by a queue, nearest games first, and may arrive some ticks after the world started. Until then your plot shows its pad.
- You are not ticked before you are there, and your tick count starts at 0 when you arrive. Nothing in a pack may depend on the world's tick.
- The venue you build with `TLKit.build_layout(ctx.read_json(...), ctx.root)` is built ahead on another thread when the layout file lies under `data/` and you pass it on unchanged. A layout you change in code first is built in your `_pack_setup` as before, and costs the visitor a frame.
- Everything else in `_pack_setup` still runs on the main thread: keep it small.
- A world may replace your pack by a fresh copy of its directory at any tick (`reload`). What `_pack_save` returns is handed to `_pack_load`; nothing else survives. Keep no state in `static var`.

**At a distance (P6).** Beyond the sideline a pack is drawn as a merged picture of its static venue plus signs of life. Every body that is not static and not frozen, and every rig, is drawn as a box in its main colour, moved when the pack ticks. Up to two standing smoke emitters and four lights are kept. Anything shorter than 2.5 m is not drawn from the sideline on, anything shorter than 5 m or thinner than 0.1 m from about 270 m on. What a far visitor must see has to be tall, large or moving.

**The scoreboard (P6).** A kit `scoreboard` shows fixed digits. In a world, when the pack has a `TLRules`, the world draws the first two sides of `rules.scores` (0 to 9) over it at every distance.

## Amendments of 2026-11-11 (core run, round 3: P11, P12, P13)

**Input handlers (P11).** `func _input` and `func _unhandled_input` in a pack are fence errors, no longer counted
bypasses. The kernel still switches any pack script's event handlers off, in a single run and in a world. Packs and
the Foreman write `"kernelApi": "1.0"`; `"0.1"` is still read as 1.0.

**The hash in a world (P11).** A pack in a world at its own origin is hashed by the runner's hash code and hashes as
`smoke` or `bot` hashes it alone after the same number of its own ticks.

**Arriving (P12).**

- Nothing a pack author writes changes.
- The rigs and kit parts a `_pack_setup` makes are built ahead on a worker from the pack's second arrival on a
  machine on. A build call whose parameters differ from the recorded ones is built in the setup as before.
- A reload sees changed `.gd` files as well as changed data.
- In a window, a game the visitor walks into is there when he arrives; if it was not ready, it is built at once and
  that frame is long.

**At a distance (P13).** Beyond the sideline a pack's moving bodies are drawn as marks that move smoothly between
the pack's ticks, one tick interval behind the game; a pack whose moving bodies are mostly rigs shows slim figures.
A far game's pictures are kept on disk by its directory's content.
