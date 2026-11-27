extends RefCounted
## SEAM M6 (rules and runs): what the Home's rules do to the world, as rules_run.gd calls it (LANES.md "M6", the facade).
## This base does nothing: it is what the seam wires into the visit (rules_play.gd) until lane P's facade replaces it,
## and what a case's recording facade extends. Every method is called from rules_run.gd `step`/`begin`/`stop`, in the
## order the effects run (time is frames: nothing here may read a clock or decide on one). The runtime keeps the run's
## state; the facade only makes the world show it.

## Zone `zone_id`'s blocks stop (open) or start again (closed) being drawn and colliding. `box` is the zone's
## [[x0, y0, z0], [x1, y1, z1]] (inclusive cells) as it was when it opened, so closing needs no lookup. Opening never
## changes the saved blocks. Called only when the state changes.
func set_open(_zone_id: int, _box: Array, _open: bool) -> void:
	pass


## Zone `zone_id`'s look (a coin) is hidden (`taken` true) or back (false: a run restarts, the visit ends).
func look_taken(_zone_id: int, _taken: bool) -> void:
	pass


## The visitor's velocity becomes `up_cm` cm/s up and `fwd_cm` cm/s forward along his facing (a jump pad).
func launch(_up_cm: int, _fwd_cm: int) -> void:
	pass


## The visitor's feet are put at `at` (world metres: a zone's floor centre, the run's respawn, where the visit began).
func teleport(_at: Vector3) -> void:
	pass


## A line of 1-60 printable characters on the screen for `frames` physics frames (a later line replaces it).
func say(_text: String, _frames: int) -> void:
	pass


## The run `run_name` started (or restarted) at physics frame `frame`: its clock is 0 now (the HUD reads
## rules_run.gd `state()` every frame for the time).
func run_started(_run_name: String, _frame: int) -> void:
	pass


## The run `run_name` was finished in `frames` physics frames; `best_frames` is the best now (this one when it is a
## new best); `new_best` is true when this finish is the best (the first finish of a run name is). The finish card.
func run_finished(_run_name: String, _frames: int, _best_frames: int, _new_best: bool) -> void:
	pass


## The run `run_name` ended without a finish (`why`: "build" build mode came on, "stage" a game took the stage,
## "quit", "begin"): nothing is recorded; the clock goes away.
func run_stopped(_run_name: String, _why: String) -> void:
	pass
