# Lane M: changes wanted outside lane M's files (walker-feel, 18 Nov 2026)

## 1. `engine/kernel/world/draw/view.gd` line 391 (`_set_stage`): reset interpolation after the re-base
What: physics interpolation is on (lane M, `project.godot`). `_set_stage` moves the whole landscape (and with it the
drawn games) by a plot's transform in one tick: with interpolation on, that tick's frames between the two ticks draw
everything half way (one tick of smear at every enter and leave). The visitor and his camera reset themselves
(`visitor.put`, `TLChaseCam.snap`), the landscape does not.
Exact change, after `landscape.transform = ... if i >= 0 else Transform3D.IDENTITY`:
```gdscript
	landscape.reset_physics_interpolation()           # walker-feel: a re-base is a teleport, not a move
	if draw != null:
		draw.reset_physics_interpolation()
```
(`Node.reset_physics_interpolation()` reaches the node's children.) Same at line 272 and 289 if those run after the
first drawn frame.

## 2. `engine/boot/boot.gd` line 48 (`KEYS_WALK`, lane T's file): the keys line names the new keys
```gdscript
const KEYS_WALK: String = "W A S D  walk      mouse  look      Shift  run      Space  jump      C  slide (running)      E  enter the game you stand in      Esc  quit"
```
A and D no longer step aside with the face to the camera: he turns toward where he walks (visitor.gd, `FACE_EASE`),
the camera stays where the mouse put it. Line 5's comment likewise.

## 3. `engine/boot/visit_proof.devices.json`: the first run leg ends at tick 1028, not 1157 (`world.sh visit-proof`)
Seen (09:54): with weight the body no longer stalls on the paddle pad's bank (the old `walk()` refused and crawled
there for about 20 m of the leg), so by tick 1157 he is 20 m further east, the turn at 1165 aims him past the drive
plot's gate, E at 1440 finds no game: `FAIL world.visit_proof: no pack hash or no leave` (the two replays still agreed).
Change: the two entries `[1157, "key", "W", 0], [1157, "key", "Shift", 0]` become `[1028, "key", "W", 0], [1028, "key",
"Shift", 0]` (nothing else). Measured with that file (visit-test tour, --cost=model --load=block): at 1158 he stands at
(-21.75, 0.05, 3.72) (P11's table: -22.78, 0.04, -3.48), inside the drive plot at 1411, on stage at 1460, Q leaves at
1700 to (0, -2.52, -21.0), 5.0 m outside, as before. The P11 table's feet at 900 and 1200 change (new body).

## 4. `engine/kernel/world/draw/draw_life.gd` line ~405 (`_draw_marks`, from `_process`): interpolation warning
Seen once in a window run with interpolation on: `WARNING: [Physics interpolation] MultiMesh interpolation is being
triggered from outside physics process, this might lead to issues (possibly benign)` (multimesh_instance_set_transform
from `_draw_marks` <- `_life` <- draw.gd `_process`). The marks are set per drawn frame, so they need no interpolation:
set `physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF` on that MultiMeshInstance3D when it is made.
(Not seen again in the later runs; it is a warning, not an error.)

## 5. Kernel API version (`engine/kernel/runner/manifest.gd`, Director): TLChaseCam gained opt-in members
`anchor_follow`, `anchor_follow_y`, `avoid_space`, `avoid_margin`, `avoid_mask`, `avoid_out`, `avoid_min`, and the read-only
`avoid_pull`, `avoid_lift`. `tl arch` rule api-v1 asks KERNEL_API "1.6" and `node devx/bin/tl.mjs arch --index`
(regenerates docs/generated/API-INDEX.md and REPORTS.md). Not done by lane M (not its files).
