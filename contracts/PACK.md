# Pack contract (kernelApi 0.1)

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
| `kernelApi` | string, `"0.1"` | yes | kernel API the pack was built against; the loader refuses a mismatch in the major.minor |
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
