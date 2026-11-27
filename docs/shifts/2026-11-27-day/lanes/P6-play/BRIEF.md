# Lane P (M6 play): the rules come alive in the visit

Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-m6-p`, branch `d27-m6-p`, from the seam 6690ad32 (branch d27-m6). Opus. Time box ~4 h. Selftest blocks: `774-home-rules-play.sh` (replace the seam's stub) and 779-781.
**Read `../M6-COMMON.md` (this folder's parent) first**, then `engine/kernel/world/build/LANES.md` (your row "P: play" is the authority on your files), the head of `rules_run.gd`, `rules_facade.gd`, `rules_play.gd`, `home_records.gd`.

## Goal
A person visiting the Home plays what the rules make, and it feels like a game, not a debug overlay.
1. **The facade in the real visit**: feet cell, E (use), open zones hide their blocks AND their collision (make `block_mesh.gd` leave `masked` cells out of the section mesh and the chunk body; no mask = byte-identical, 752 stays green), with a short open/close in frames (a slide or a fade, not a pop); `launch` (a jump pad that feels like one: the body's velocity, the figure's jump pose); `teleport` and respawn (a short fade, the camera kept sane); falling below the world during a run calls `run.respawn_now()`.
2. **The run HUD**: the run's name and clock (mm:ss.cc from frames), the counters a rule uses (icon + count), the `say` line; the finish card in the dungeon results card's look (`engine/kernel/dungeon/results_card.gd`, read only): name, time, best, "new best"; records through `home_records.gd`.
3. **Zone looks in play**: `pad` (a glowing cel disc; tinted by role when it is the zone of a start / checkpoint / finish effect), `coin` (a turning token, gone when taken, back on restart), `flag` (pole + cloth: the finish); through `TLStyle` palette keys and kit parts, never hand-made materials; cheap (MultiMesh or a few nodes; measure). Give `play_looks.gd` `static func look_of(zone: Dictionary) -> Node3D` (lane T may use it after you land).
4. **E decision (Director)**: when the feet cell is in a zone that some rule triggers `on: use`, E fires `use` and does NOT enter a nearby game; otherwise E behaves as today. Zones cannot be on game plots (protected), so this only matters near a gate.

## The seam's hand-offs you build on (quoted from LANES.md; nothing else of another lane)
```gdscript
# rules_facade.gd: your facade `extends "res://kernel/world/build/rules_facade.gd"` and overrides exactly:
func set_open(zone_id: int, box: Array, open: bool) -> void      # hide / show the zone's blocks and their collision
func look_taken(zone_id: int, taken: bool) -> void               # a coin hidden / back
func launch(up_cm: int, fwd_cm: int) -> void                     # velocity up and along his facing, cm/s
func teleport(at: Vector3) -> void                               # feet to `at` (world m)
func say(text: String, frames: int) -> void                      # the say line for `frames` physics frames
func run_started(run_name: String, frame: int) -> void           # the clock starts (reads state().frames)
func run_finished(run_name: String, frames: int, best_frames: int, new_best: bool) -> void   # the finish card
func run_stopped(run_name: String, why: String) -> void          # the clock goes, nothing recorded
# A facade never holds the runtime strongly (hold a WeakRef, as rules_case_run.gd's Rec does) and never decides on a clock.
# rules_run.gd
func state() -> Dictionary     # {"on", "running", "run", "frames" (the run's clock), "counters", "respawn"}: the HUD, every frame
func is_open(zone_id: int) -> bool
func is_taken(zone_id: int) -> bool
func respawn_now() -> void     # falling out of the world during a run
var last_finish: Dictionary    # {"run", "frames", "best_frames", "new_best"}
# blocks_layer.gd (the seam's API, your drawing)
func set_mask(key: int, lo: Vector3i, hi: Vector3i, hidden: bool) -> void   # key = zone id; marks the sections dirty
func masked(cell: Vector3i) -> bool
func clear_masks() -> void
# home_records.gd
HomeRecords.new(dir: String); func load() -> String; func started(name: String) -> String
func finished(name: String, frames: int) -> Dictionary   # {"plays", "finishes", "best_frames", "new_best", "error"}
func of(name: String) -> Dictionary
```
Outside the build folder you may edit `engine/kernel/world/visitor.gd` only for launch (its `vel`) and teleport (`put(at, yaw)`), each edit listed in `PATCHES-P6.md`; the world gate stays 9/9.

## Acceptance
- `774-home-rules-play.sh` -> `HOME rules-play ok` (headless: a scripted walk through a small course: start -> coin -> door (use) -> launch -> checkpoint -> fall -> respawn -> finish; records written; HUD state; an open door's blocks are passable, then solid again; the E rule above; no mask = 752 byte-identical).
- The exe (a window): build a 6-block-high tower course (by the op path or a fixture Home): a start pad, 3 coins, a door that opens on use, a jump pad and a finish flag; play it twice. Captures `p6-start.jpg`, `p6-pad.jpg`, `p6-door.jpg`, `p6-finish-card.jpg`, a clip `p6-run.mp4` (≤ 30 s) in `docs/shifts/2026-11-27-day/lanes/P6-play/`. Frame p50/p99 during the run. Judge honestly: does it feel like a game?
- Gates per M6-COMMON.
