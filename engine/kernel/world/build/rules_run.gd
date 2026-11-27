extends RefCounted
## SEAM M6 (rules and runs, 27 Nov 2026): the Home's rules running, as pure deterministic logic (contracts/BUILD.md
## "Running"). No scene tree, no clock, no file of its own: it reads the rules layer (rules_layer.gd `zones`, `rules`,
## never writing them), is told the frame, the visitor's feet cell and whether E went down, keeps the run's state and
## calls the facade (rules_facade.gd) for everything that touches the world. Records go through `records`
## (home_records.gd) when the owner gives one. The same layer, the same `begin` and the same `step` inputs give the
## same facade calls in the same order: a run is deterministic.
##
## Each `step(frame, feet_cell, use_down)`:
##   1. the triggers are read: enter / leave (the feet cell's zones against the last frame's; a taken zone fires
##      neither, nor use: a taken coin is gone), use (E went down this frame in the zone), every (frames since `begin`
##      a multiple of N), count (a counter at or above `at`, once per run: once per visit while no run is going),
##      start / finish (a run started / was finished by an effect in the frame before: an event is read as a trigger
##      the next frame, so a rule never answers an effect of its own frame twice);
##   2. every fired rule runs in ascending id, each checking its `if` when it runs, each effect seeing the effects
##      before it in the frame (a counter added by rule 1 holds for rule 2's condition). A rule fires at most once.
## A run: `start` resets counters, closes every open zone and brings every coin back, its respawn is the start zone's
## floor centre (the zone of the starting rule's trigger; with no zone, the feet cell's floor); `checkpoint` moves the
## respawn; `finish` records it (plays counted at start, finishes and the best at finish) and calls `run_finished`.

const Check := preload("res://kernel/world/build/rules_check.gd")
const FEET_LIFT := 0.05                  # metres: feet standing on a block's top read as the cell above it

var layer: RefCounted = null             # rules_layer.gd (read only)
var facade: RefCounted = null            # rules_facade.gd or one extending it
var records: RefCounted = null           # home_records.gd, or null: nothing recorded (best_frames = frames, new_best false)

var on := false                          # `begin` was called and no `stop` since
var frame0 := 0                          # the frame of `begin`
var frame := 0                           # the last frame stepped
var visit_at := Vector3.ZERO             # where this visit (or this spell out of build mode) began: respawn without a run
var running := false
var run_name := ""
var run_frame0 := 0
var respawn := Vector3.ZERO
var counters := {}                       # name -> 0..999 (absent: 0)
var taken := {}                          # zone id -> true
var open := {}                           # zone id -> its box when it opened
var inside := {}                         # zone id -> true: the zones the feet cell was in at the last step
var counted := {}                        # rule id -> true: its count trigger fired in this run (or visit)
var events := {}                         # "start" / "finish" -> true: made in the last frame, read as triggers now
var _next_events := {}
var last_finish := {}                    # {"run", "frames", "best_frames", "new_best"} of the last finish


func _init(rules_layer: RefCounted = null, f: RefCounted = null, recs: RefCounted = null) -> void:
	layer = rules_layer
	facade = f if f != null else (load("res://kernel/world/build/rules_facade.gd") as GDScript).new()
	records = recs


## The cell the feet at `feet` (world metres) stand in: a visitor on a block's top is in the cell above it.
static func feet_cell(feet: Vector3) -> Vector3i:
	return Vector3i((feet + Vector3(0.0, FEET_LIFT, 0.0)).floor())


## A visit begins (the Home is walked, build mode goes off): whatever was going is stopped, every zone is closed,
## every coin is back, counters are 0, no run; `feet` is where the visit began.
func begin(at_frame: int, feet: Vector3) -> void:
	stop("begin")
	on = true
	frame0 = at_frame
	frame = at_frame
	visit_at = feet


## The visit pauses or ends (`why`: "build", "stage", "quit"): a run going is dropped (`run_stopped`, nothing
## recorded), open zones close and taken coins come back (facade calls), and the state is cleared.
func stop(why := "build") -> void:
	if running:
		running = false
		facade.run_stopped(run_name, why)
	_close_all()
	_coins_back()
	counters.clear()
	counted.clear()
	inside.clear()
	events.clear()
	_next_events.clear()
	run_name = ""
	on = false


## One physics frame of the visit (see the file's head). `use_down`: E went down this frame (an edge, not held).
func step(at_frame: int, feet: Vector3i, use_down: bool) -> void:
	if not on:
		return
	frame = at_frame
	if layer == null or (layer.get("rules") as Dictionary).is_empty():
		inside.clear()
		return
	var zones: Dictionary = layer.get("zones")
	var rules: Dictionary = layer.get("rules")
	var here := {}
	for z: int in zones:
		if Check.box_has(zones[z].box, feet):
			here[z] = true
	events = _next_events
	_next_events = {}
	var since := frame - frame0
	var ids: Array = rules.keys()
	ids.sort()
	var fired := []
	for rid: int in ids:
		var w: Dictionary = rules[rid].when
		var go := false
		match str(w.on):
			"enter":
				go = here.has(int(w.zone)) and not inside.has(int(w.zone)) and not taken.has(int(w.zone))
			"leave":
				go = inside.has(int(w.zone)) and not here.has(int(w.zone)) and not taken.has(int(w.zone))
			"use":
				go = use_down and here.has(int(w.zone)) and not taken.has(int(w.zone))
			"every":
				go = since > 0 and since % int(w.frames) == 0
			"count":
				go = int(counters.get(str(w.counter), 0)) >= int(w.at) and not counted.has(rid)
				if go:
					counted[rid] = true
			"start", "finish":
				go = events.has(str(w.on))
		if go:
			fired.append(rid)
	inside = here
	for rid: int in fired:
		var r: Dictionary = rules[rid]
		if _holds(r.get("if", [])):
			for e: Dictionary in r.do:
				_effect(e, r, feet)


func _holds(conds: Array) -> bool:
	for c: Dictionary in conds:
		if c.has("running"):
			if bool(c.running) != running:
				return false
			continue
		var v := int(counters.get(str(c.counter), 0))
		if (c.has("min") and v < int(c.min)) or (c.has("max") and v > int(c.max)):
			return false
	return true


func _effect(e: Dictionary, r: Dictionary, feet: Vector3i) -> void:
	var zones: Dictionary = layer.get("zones")
	var zid := int(e.get("zone", 0))
	var box: Array = zones[zid].box if zones.has(zid) else []
	match str(e.do):
		"start":
			_start(str(e.run), r, feet)
		"checkpoint":
			if running and not box.is_empty():
				respawn = Check.floor_centre(box)
		"finish":
			_finish()
		"respawn":
			facade.teleport(respawn if running else visit_at)
		"add":
			counters[str(e.counter)] = clampi(int(counters.get(str(e.counter), 0)) + int(e.by), 0, Check.COUNTER_MAX)
		"take":
			if not box.is_empty() and not taken.has(zid):
				taken[zid] = true
				facade.look_taken(zid, true)
		"open":
			_set_open(zid, box, true)
		"close":
			_set_open(zid, box, false)
		"toggle":
			_set_open(zid, box, not open.has(zid))
		"launch":
			facade.launch(int(e.up_cm), int(e.fwd_cm))
		"teleport":
			if not box.is_empty():
				facade.teleport(Check.floor_centre(box))
		"say":
			facade.say(str(e.text), int(e.frames))


func _start(name: String, r: Dictionary, feet: Vector3i) -> void:
	_close_all()
	_coins_back()
	counters.clear()
	counted.clear()
	running = true
	run_name = name
	run_frame0 = frame
	var zones: Dictionary = layer.get("zones")
	var w: Dictionary = r.when
	if w.has("zone") and zones.has(int(w.zone)):
		respawn = Check.floor_centre(zones[int(w.zone)].box)
	else:
		respawn = Vector3(feet.x + 0.5, feet.y, feet.z + 0.5)
	if records != null:
		records.started(name)
	facade.run_started(name, frame)
	_next_events["start"] = true


func _finish() -> void:
	if not running:
		return
	var frames := frame - run_frame0
	var res := {"best_frames": frames, "new_best": false}
	if records != null:
		res = records.finished(run_name, frames)
	running = false
	last_finish = {"run": run_name, "frames": frames, "best_frames": int(res.best_frames), "new_best": bool(res.new_best)}
	facade.run_finished(run_name, frames, int(res.best_frames), bool(res.new_best))
	_next_events["finish"] = true


func _set_open(zid: int, box: Array, want: bool) -> void:
	if box.is_empty() or open.has(zid) == want:
		return
	if want:
		open[zid] = box.duplicate(true)
	else:
		open.erase(zid)
	facade.set_open(zid, box, want)


func _close_all() -> void:
	var ids: Array = open.keys()
	ids.sort()
	for z: int in ids:
		var box: Array = open[z]
		open.erase(z)
		facade.set_open(z, box, false)


func _coins_back() -> void:
	var ids: Array = taken.keys()
	ids.sort()
	taken.clear()
	for z: int in ids:
		facade.look_taken(z, false)


## Puts the visitor at the run's respawn (or where the visit began): lane P calls it when he falls out of the world.
func respawn_now() -> void:
	if on:
		facade.teleport(respawn if running else visit_at)


## What the HUD reads every frame: {"on", "running", "run", "frames" (the run's clock), "counters", "respawn"}.
func state() -> Dictionary:
	return {"on": on, "running": running, "run": run_name, "frames": frame - run_frame0 if running else 0,
		"counters": counters.duplicate(), "respawn": respawn}


func is_open(zone_id: int) -> bool:
	return open.has(zone_id)


func is_taken(zone_id: int) -> bool:
	return taken.has(zone_id)
