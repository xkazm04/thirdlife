extends "res://kernel/world/build/rules_facade.gd"
## Lane P (M6 rules and runs, 27 Nov 2026): what the Home's rules do to the world, in the real visit (LANES.md "M6",
## the facade). rules_run.gd calls it; it never decides on a clock and holds its owner (rules_play.gd) by a WeakRef
## only. Each effect goes to the part that shows it:
##   set_open      play_doors.gd (the blocks layer's mask, a slide in frames)
##   look_taken    play_looks.gd (a coin flies away / comes back)
##   launch        visitor.gd `launch` (the body's velocity, his jump pose)
##   teleport      visitor.gd `put(at, yaw, false)` (his feet there, the camera snapped behind him) and the HUD's dip
##   say, run_*    play_hud.gd (the say line, the run pill and its clock, the finish card)
## `calls` keeps the last calls (for a case and for figures).

var play: WeakRef = null                 # rules_play.gd
var instant := false                     # rules_play.gd sets it while it stops the rules (build mode, the end of a visit)
var calls := []                          # the last 64 calls: [name, args...]
var launched := 0
var teleports := 0


func _init(p: RefCounted = null) -> void:
	play = weakref(p) if p != null else null


func _p() -> RefCounted:
	return play.get_ref() as RefCounted if play != null else null


func _log(c: Array) -> void:
	calls.append(c)
	if calls.size() > 64:
		calls.pop_front()


## One `tl.view/1` line of kind `rules` per run event, launch and teleport (never per frame): the exe's log says what
## the rules did and when.
func _print(what: String, extra: Dictionary) -> void:
	var p := _p()
	var d := {"schema": "tl.view/1", "kind": "rules", "what": what, "frame": int(p.get("frame")) if p != null else -1}
	d.merge(extra)
	print(JSON.stringify(d, "", false))


func set_open(zone_id: int, box: Array, open: bool) -> void:
	_log(["set_open", zone_id, open])
	var p := _p()
	if p != null and p.get("doors") != null:
		p.get("doors").call("set_open", zone_id, box, open, int(p.get("frame")), instant)


func look_taken(zone_id: int, taken: bool) -> void:
	_log(["look_taken", zone_id, taken])
	var p := _p()
	if p != null and p.get("looks") != null:
		p.get("looks").call("taken", zone_id, taken, int(p.get("frame")))


## Up `up_cm` cm/s and `fwd_cm` cm/s along where the figure faces (visitor.gd `face_yaw`), replacing his velocity.
func launch(up_cm: int, fwd_cm: int) -> void:
	_log(["launch", up_cm, fwd_cm])
	var v: Node3D = _visitor()
	if v == null:
		return
	var yaw := float(v.get("face_yaw"))
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	if v.call("launch", fwd * (fwd_cm / 100.0) + Vector3.UP * (up_cm / 100.0)):
		launched += 1
	_print("launch", {"up_cm": up_cm, "fwd_cm": fwd_cm, "feet": str(v.get("feet"))})
	var p := _p()
	if p != null:
		p.call("burst", "dust", v.get("feet") as Vector3, 1.2, 60)       # the pad's kick: a puff where he left it
		p.call("launched")


## His feet to `at`, facing where the camera looks now (so the view does not swing round), the screen dipping.
func teleport(at: Vector3) -> void:
	_log(["teleport", at])
	var v: Node3D = _visitor()
	if v == null:
		return
	var was: Vector3 = v.get("feet")
	v.call("put", at, float(v.get("look_yaw")), false)
	teleports += 1
	_print("teleport", {"from": str(was), "to": str(v.get("feet"))})
	var h := _hud()
	if h != null:
		h.call("dip")


func say(text: String, frames: int) -> void:
	_log(["say", text, frames])
	var h := _hud()
	if h != null:
		h.call("say", text, frames)


func run_started(run_name: String, frame: int) -> void:
	_log(["run_started", run_name, frame])
	_print("run_started", {"run": run_name})
	var h := _hud()
	var p := _p()
	var recs: Variant = p.get("records") if p != null else null
	var was: Dictionary = (recs as RefCounted).call("of", run_name) if recs is RefCounted else {}
	if h != null:
		h.call("started", run_name, int(was.get("best_frames", 0)))
	if p != null:
		p.call("ghost_start", run_name)


func run_finished(run_name: String, frames: int, best_frames: int, new_best: bool) -> void:
	_log(["run_finished", run_name, frames, best_frames, new_best])
	_print("run_finished", {"run": run_name, "frames": frames, "best_frames": best_frames, "new_best": new_best})
	var h := _hud()
	if h != null:
		h.call("finished", run_name, frames, best_frames, new_best)
	var p := _p()
	if p != null:
		p.call("ghost_finish", run_name, frames, new_best)
		p.call("finish_fx")


func run_stopped(run_name: String, why: String) -> void:
	_log(["run_stopped", run_name, why])
	_print("run_stopped", {"run": run_name, "why": why})
	var p := _p()
	if p != null:
		p.get("ghost").call("play_stop")
	var h := _hud()
	if h != null:
		h.call("stopped")


func _visitor() -> Node3D:
	var p := _p()
	return p.call("visitor_node") as Node3D if p != null else null


func _hud() -> Node:
	var p := _p()
	var h: Variant = p.get("hud") if p != null else null
	return h if h is Node and is_instance_valid(h) else null
