# LANES: who may edit what in `engine/kernel/world/build/` (M6 rules and runs, three lanes in parallel)

Written by the M6 seam (lane S6, 27 Nov 2026, day shift; the M5 table it replaces is in git at e3b1ccc8). Three lanes
work at the same time in three worktrees branched from the seam and land one by one: **P** play (the rules in the
visit), **T** tool (the Rules hand tool), **C** LLM (the ask, the Foreman, the space check). The wire formats are
`contracts/BUILD.md` "Milestone 6" (no lane edits a contract; a question goes to its report). The seam's interfaces
are below, each with its owning file and its exact signature: a lane builds against these and nothing else of another
lane. A lane edits only the files it OWNS below and adds NEW files only under its own prefix. If a lane needs a change
to a file it does not own, it writes the change in its `PATCHES-P6.md` / `PATCHES-T6.md` / `PATCHES-C6.md` and the
Director makes it.

## Frozen (the seam's; no lane edits them)

Everything frozen in M5 (`edit_log.gd`, `build_file.gd`, `home_build.gd`, `build_mode.gd`, `hotbar.gd`, `protect.gd`,
`op_util.gd`, `block_mesh.gd` (P: see its row), `ghost.gd`, `preview_mesh.gd`, `build_devices.gd`, `blocks.gd`,
`shapes.gd`, `blocks_layer.gd` (P: see its row), `stub_layer.gd`, `seam_lists.gd`, `seam_case.gd`, `seam_v3.gd`,
`case_util.gd`, `build_case.gd`, `build_mode_case.gd`, `tools/stub_tool.gd`, `tools/blocks_tool.gd`, `BUILD.md`,
`LANES.md`, every earlier `PATCHES-*.md`, selftest blocks 752-754 and 758), and the M6 seam: `rules_check.gd`,
`rules_layer.gd` (T: its `preview_node` only), `rules_run.gd`, `rules_facade.gd`, `home_records.gd`, `rules_case.gd`,
`rules_case_run.gd`, `engine/tools/selftest.d/773-home-rules-seam.sh`.

Every lane keeps **752-767 and 773** green (`bash engine/tools/selftest.sh home.`), `tl check --tier fast`, and the
`world` gate (`tl check --tier full --only world`: 9/9 hashes as main: the rules live only in the Home's build mode,
never in a pack's space or hash). 754 and 757 read their lists from `seam_lists.gd` (`rules` is a layer, `zone`,
`unzone`, `rule`, `unrule` its ops, `rules` a tool between plants and command); 754 `seam.tools` tells the stub tool
from T's by its base script, so T replacing the stub changes no case as long as its info line is not empty.

## The seam's interfaces (what the lanes build on)

### The data: `rules_layer.gd` (layer id `rules`; `build.layer("rules")`, read only outside the seam)

```gdscript
var zones: Dictionary            # id -> {"id": int, "box": [[x0, y0, z0], [x1, y1, z1]], "look": "none|pad|coin|flag", "name"?: String}
var rules: Dictionary            # id -> {"id": int, "when": {...}, "if"?: [...], "do": [...]}   (the saved forms, ints)
var revision: int                # +1 per applied record or clear (a drawer redraws when it moves)
func next_zone_id() -> int
func next_rule_id() -> int
func counters() -> Array         # the counters the rules use, sorted
func zones_at(c: Vector3i) -> Array          # zone ids whose box holds cell c, ascending
func names() -> Dictionary                   # zone id -> name (zones that have one)
func describe(n: int) -> String              # rule n as a line ("when you enter Door: open Door"); "" if none
func offers() -> Array                       # ["zone", "unzone", "rule", "unrule"]
func read_region(lo: Vector3i, hi: Vector3i) -> Dictionary   # {"zones"?, "rules"?}: the ask's shapes, each omitted when none
func room() -> Dictionary                    # {"zones_left": int, "rules_left": int, "counters": [String]}
func ask_part(lo: Vector3i, hi: Vector3i) -> Dictionary      # read_region + {"rules_room": room()}: the ask's M6 keys
func renumber(ops: Array) -> Dictionary      # {"ops", "refused": [[i, why]]}: an answer's ids made free (home_build.expand_input calls it)
func preview_node(sc: Variant) -> Node3D     # T OWNS this one method (the seam returns null)
```

Ops go through `build.apply(op_or_batch)` like every layer (one batch, one undo). The shapes, limits and refusal
reasons are `rules_check.gd` (static): `malformed(op, strict)`, `describe(rule: Dictionary, names: Dictionary) -> String`,
`floor_centre(box: Array) -> Vector3`, `box_has(box: Array, c: Vector3i) -> bool`, `zones_named(rule) -> Array`,
`counters_of(rule) -> Array`, `zone_of(d)`, `rule_of(d)` (canonical forms), and the constants `LOOKS`, `TRIGGERS`,
`EFFECTS`, `SIDE_MAX` 64, `ZONES_MAX` / `RULES_MAX` 512, `COUNTERS_MAX` 8, `DO_MAX` 8, `IF_MAX` 8, `NAME_MAX` 24,
`TEXT_MAX` 60. Zones are refused in protected areas by `protect.gd` `refusal_box(lo: Vector3i, hi: Vector3i) -> String`
(the blocks' reasons, never the visitor).

### The runtime: `rules_run.gd` (pure; frames only; no tree, no clock)

```gdscript
RulesRun.new(rules_layer: RefCounted, facade: RefCounted, records: RefCounted = null)
static func feet_cell(feet: Vector3) -> Vector3i          # floor(feet + 5 cm up): standing on a block reads the cell above it
func begin(at_frame: int, feet: Vector3) -> void           # a visit begins / build mode off: closed, coins back, counters 0, no run
func stop(why := "build") -> void                          # build mode on, a game on stage, quit: a run is dropped unrecorded
func step(at_frame: int, feet: Vector3i, use_down: bool) -> void   # once per physics frame; use_down = E went down this frame
func respawn_now() -> void                                 # P: falling out of the world during a run
func state() -> Dictionary     # {"on", "running", "run", "frames" (the run's clock), "counters", "respawn"}: the HUD, every frame
func is_open(zone_id: int) -> bool
func is_taken(zone_id: int) -> bool
var last_finish: Dictionary    # {"run", "frames", "best_frames", "new_best"}
```

The order of a frame, the one-frame delay of `start` / `finish` / `count` triggers, "a taken zone fires no enter,
leave or use", the respawn rules: the head of `rules_run.gd` (and REPORT questions Q1-Q3).

### The facade: `rules_facade.gd` (the interface P implements; the seam's base does nothing)

P's facade `extends "res://kernel/world/build/rules_facade.gd"` and overrides, exactly:

```gdscript
func set_open(zone_id: int, box: Array, open: bool) -> void      # hide / show the zone's blocks and their collision
func look_taken(zone_id: int, taken: bool) -> void               # a coin hidden / back
func launch(up_cm: int, fwd_cm: int) -> void                     # velocity up and along his facing, cm/s
func teleport(at: Vector3) -> void                               # feet to `at` (world m)
func say(text: String, frames: int) -> void                      # the say line for `frames` physics frames
func run_started(run_name: String, frame: int) -> void           # the clock starts (reads state().frames)
func run_finished(run_name: String, frames: int, best_frames: int, new_best: bool) -> void   # the finish card
func run_stopped(run_name: String, why: String) -> void          # the clock goes, nothing recorded
```

A facade never holds the runtime strongly (the runtime holds the facade: hold a `WeakRef`, as `rules_case_run.gd`'s
`Rec` does), and it never decides on a clock.

### The records: `home_records.gd` (`tl.records/1`)

```gdscript
HomeRecords.new(dir: String)       # the Home's folder (build_mode.gd `dir`); "" = nothing written
func load() -> String              # "" or why refused (then `blocked` and never written over)
func started(name: String) -> String
func finished(name: String, frames: int) -> Dictionary   # {"plays", "finishes", "best_frames", "new_best", "error"}
func of(name: String) -> Dictionary                       # {"plays", "finishes", "best_frames"?} or {}
func save() -> String
```

### The blocks layer's mask (`blocks_layer.gd`, the M6 section at its end)

```gdscript
func set_mask(key: int, lo: Vector3i, hi: Vector3i, hidden: bool) -> void   # key = zone id; marks the sections dirty
func masked(cell: Vector3i) -> bool
func clear_masks() -> void
var masks: Dictionary              # key -> [lo, hi]
```

The seam keeps the boxes and marks the sections; it does not yet leave masked cells out of the mesh (P does).

### The wiring in the visit (`build_mode.gd`, frozen; `rules_play.gd`, P's)

`build_mode.gd` makes `play = RulesPlay.new(self)` in `_ready` and calls `play.tick(frames)` in `_physics_process`
right after `build.step()` (priority 150000: after the visit's sample and steer at 100000), and `play.stop("quit")` on
exit. `rules_play.gd` `tick(frame: int)`: off while build mode is on (`"build"`), a game is on stage (`"stage"`) or
no feet are known (`"nobody"`), each turning-off calling `run.stop(why)`; each turning-on `run.begin(frame, feet)`
with `run.layer = build.layer("rules")`, `run.facade = facade`, `run.records = records`; then
`run.step(frame, RulesRun.feet_cell(feet), use_down())`. E is the visit's TLInput `just_pressed(&"enter")`
(`kernel/runner/visit.gd` ACTIONS), never the raw key, so a replayed visit replays the rules.

## P: play (the rules in the real visit)

- **Owns:** `rules_play.gd` (the facade in the visit and its `records`; keep `tick`'s on/off rules and E from the
  visit's input), new files `play_*.gd` (the facade, the say line, the run clock HUD, the finish card in the results
  card's look, the zone looks pad / coin / flag in the cel style through `TLStyle` / kit parts, never hand-made
  materials), `blocks_layer.gd` only its M6 mask section, `block_mesh.gd` only to leave masked cells out of the
  section mesh and the chunk body (752 stays green: no mask, no change), `PATCHES-P6.md`,
  `engine/tools/selftest.d/774-home-rules-play.sh` (replace the stub).
- **Outside this folder:** `engine/kernel/world/visitor.gd` only for launch (its `vel`) and teleport (`put(at, yaw)`)
  if the facade cannot do them through what is there: list each edit in `PATCHES-P6.md`; the world gate stays 9/9.
  `engine/kernel/dungeon/results_card.gd` and `look_ui.gd` are read, never edited (the card's look is reused).
- **Gives the others:** nothing they wait on. A zone look maker `play_looks.gd`
  `static func look_of(zone: Dictionary) -> Node3D` that T may call once P has landed (T never waits for it).
- **Must not touch:** the layer, the runtime, the tool, the command files. Falling out of the world during a run:
  `run.respawn_now()`. E near a game's gate both enters the game and fires `use`: say in the report what wins.

## T: tool (the Rules hand tool)

- **Owns:** `tools/rules_tool.gd` (replace the stub: the tool interface of BUILD.md "Tools"), `rules_layer.gd`
  `preview_node(sc) -> Node3D` only (the zones and rules an answer or a preset adds in holo, those it removes in red;
  `null` when none changed; it is shown by the command tool through `home_build.preview_nodes`), new files
  `rules_tool_*.gd` and `zone_draw.gd` (zones visible in build mode: box outlines and the look's icon, in
  `TLStyle.material("holo")`), the presets (start, checkpoint, finish, coin, door, jump pad, hazard, message: each one
  batch of `zone` + `rule` ops built with `next_zone_id` / `next_rule_id`), the rule list read with `describe`,
  `PATCHES-T6.md`, `engine/tools/selftest.d/775-home-rules-tool.sh` (replace the stub).
- **Outside this folder:** none.
- **Gives the others:** `preview_node` (C's ghost shows it with no change on C's side).
- **Keys:** the tool takes no key the host has (B, Esc, T, Enter, Ctrl+Z / Y) and not E (the visit's use key).

## C: LLM (the ask, the Foreman, the space check)

- **Owns:** every `command_*.gd` (the ask's top-level `zones`, `rules` from `ask_part(lo, hi)` and `rules_room`,
  moving them out of `ask.layers` where `home_build.read_region` puts them today; the M6 ops in the prompt facts;
  the answer's counts naming zones and rules), `tools/command_tool.gd` (the space check shown with the ghost before
  accept: it never refuses), new files `command_*.gd` (e.g. `command_space.gd`: floating blocks, a pad or flag with no
  floor, a coin inside a solid block, a finish unreachable from its start over standable cells: walking, steps of at
  most 0.55 m, jumps of at most 1.2 m up and 4 m across), `COMMAND.md`, `PATCHES-C6.md`, its own selftest block (ask
  the Director: the seam holds 773-775). The note line may use `rules_check.gd` `describe`.
- **Outside this folder:** `foreman/src/world_edit*.ts` and their tests, `foreman/prompts/world_edit*` (the seam
  added only the wire names `zone`, `unzone`, `rule`, `unrule` in `ASK_OPS`, the answer schema's keys `box`, `look`,
  `name`, `when`, `if`, `do`, the ask schema's optional `zones`, `rules`, `rules_room`, and shape-only checks: C writes
  the prompt's rules and the full checks), the `world-edit` line of `foreman/src/cli.ts`. Only C edits foreman.
- **Reads, never writes:** `rules_layer.gd` (`ask_part`, `zones`, `rules`, `renumber` through
  `home_build.expand_input`), `home_build.preview` / `preview_nodes`.

## Hand-offs between the lanes

| From | To | What | Signature | File (owner) |
|---|---|---|---|---|
| seam | P | the effects | the 8 facade methods above | `rules_facade.gd` (seam) |
| seam | P | the run's state, respawn | `state()`, `is_open`, `is_taken`, `respawn_now()`, `last_finish` | `rules_run.gd` (seam) |
| seam | P | hiding blocks | `set_mask(key, lo, hi, hidden)`, `masked(cell)`, `clear_masks()` | `blocks_layer.gd` (seam's API, P's drawing) |
| seam | P | records | `HomeRecords.new(dir)`, `load`, `started`, `finished`, `of` | `home_records.gd` (seam) |
| seam | T | ids, lines, zones | `next_zone_id()`, `next_rule_id()`, `describe(n)`, `zones_at(c)`, `names()`, `counters()`, `revision` | `rules_layer.gd` (seam) |
| seam | C | the ask's keys | `ask_part(lo, hi) -> {"zones"?, "rules"?, "rules_room"}` | `rules_layer.gd` (seam) |
| seam | C | answer ids | `home_build.expand_input(ops)` (calls `renumber`) | `home_build.gd` (seam) |
| T | C | the rules ghost | `preview_node(sc: Variant) -> Node3D` | `rules_layer.gd` (T, that method) |
| P | T | the zone looks (optional) | `static func look_of(zone: Dictionary) -> Node3D` | `play_looks.gd` (P) |

## Landing

One lane at a time onto the seam's branch: its own block green, 752-767 and 773 green, `tl check --tier fast`, the
world gate 9/9. A lane that finds the seam wrong (a missing hook, a wrong reason) stops and reports it; it does not
patch a frozen file.
