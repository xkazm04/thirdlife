extends RefCounted
## SEAM M6 (rules and runs): the Home's rules in the visit. build_mode.gd makes one (`play`) and calls `tick(frames)`
## once per physics frame after `build.step()` (priority 150000: after the visit's sample and steer and the visitor's
## step at 100000, so the feet and E are this frame's). Lane P OWNS this file (LANES.md "M6"). Lane P (27 Nov): the
## facade is play_facade.gd (blocks hidden through the blocks layer's mask with a slide, play_doors.gd; launch and
## teleport on the walker body, visitor.gd; the say line, the run clock, the counters, the finish card and the dip,
## play_hud.gd; the zones' looks, play_looks.gd) and `records` is a home_records.gd on the Home's folder.
##
## When the rules run (contracts/BUILD.md "Running"): build mode is off, no game is on stage, and the visitor's feet
## are known. Turning on (a visit starts, build mode goes off, a game leaves the stage) calls rules_run.gd `begin`
## (counters 0, no run, every zone closed, every coin back, the feet now are "where the visit began"); turning off
## (build mode comes on, a game takes the stage, the Home is left) calls `stop` (a run going is dropped, unrecorded;
## every open zone shut at once, no slide: the builder sees the blocks as saved). E is read from the visit's own
## TLInput (`just_pressed(&"enter")`), never from the keyboard, so a replayed visit replays the rules.
##
## E near a game (Director, 27 Nov): when the feet cell is in a zone that a rule triggers `on: use` (and it is not
## taken), E fires `use` and does NOT enter a nearby game: the visit's "enter" request of this frame is taken back from
## the scheduler (kernel/world/tiers.gd `_requests`, answered at the next world tick, before which this runs). Anywhere
## else E behaves as before. Zones cannot be on game plots (protected), so this matters only near a gate.
##
## Falling out of the world during a run (feet below FALL_Y with no ground under them, or below HARD_FALL):
## rules_run.gd `respawn_now()`. Never in a pack's space or state hash: only the Home's build mode makes this.

const RulesRun := preload("res://kernel/world/build/rules_run.gd")
const RulesFacade := preload("res://kernel/world/build/rules_facade.gd")
const PlayFacade := preload("res://kernel/world/build/play_facade.gd")
const PlayDoors := preload("res://kernel/world/build/play_doors.gd")
const PlayLooks := preload("res://kernel/world/build/play_looks.gd")
const PlayHud := preload("res://kernel/world/build/play_hud.gd")
const HomeRecords := preload("res://kernel/world/build/home_records.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const FALL_Y := Blocks.Y_MIN - 8.0       # metres: below the block grid ...
const HARD_FALL := -200.0                # ... with nothing under him, or this far down whatever is under him

var host: Node = null                    # build_mode.gd
var run: RefCounted = null               # rules_run.gd
var facade: RefCounted = null            # play_facade.gd (a case may put its own in, before the first tick)
var records: RefCounted = null           # home_records.gd on the Home's folder, made once the folder is known
var records_error := ""                  # why the records file could not be read (then it is never written over)
var running := false                     # the rules run now (begin called, no stop since)
var why_off := "build"                   # why they last stopped
var ticks := 0                           # frames stepped (figures)
var frame := 0                           # the frame of the tick going (the facade reads it)
var doors: RefCounted = null             # play_doors.gd
var looks: RefCounted = null             # play_looks.gd
var hud: Node = null                     # play_hud.gd (made on the first tick that runs the rules)
var visitor: Node3D = null               # a case's visitor; else the view's (build_mode.gd `_visitor`)
var use_at: Callable                     # () -> bool, a case's E; else the visit's TLInput
var sched: Object = null                 # a case's scheduler (kernel/world/tiers.gd); else the view's world's
var claimed := 0                         # E presses kept from entering a game (figures)
var falls := 0                           # respawns after falling out of the world (figures)
var _use_zones := {}                     # zone id -> true: zones some rule triggers `on: use`
var _use_rev := -1


func _init(h: Node) -> void:
	host = h
	facade = PlayFacade.new(self)
	var b: Variant = host.get("build") if host != null else null
	doors = PlayDoors.new(b as RefCounted if b is RefCounted else null)
	looks = PlayLooks.new((b as RefCounted).get("root") if b is RefCounted else null)
	run = RulesRun.new(_rules(), facade, records)


func _rules() -> RefCounted:
	var b: Variant = host.get("build") if host != null else null
	return (b as RefCounted).call("layer", "rules") if b is RefCounted else null


## One physics frame (build_mode.gd `_physics_process`).
func tick(at_frame: int) -> void:
	frame = at_frame
	var feet: Variant = feet_now()
	var off := _off_reason(feet)
	if off != "":
		if running:
			stop(off)
		doors.tick(at_frame)
		return
	_records()
	if not running:
		run.layer = _rules()
		run.facade = facade
		run.records = records
		doors.clear()
		run.begin(at_frame, feet as Vector3)
		running = true
		_show(true)
	looks.sync(run.layer)
	var cell := RulesRun.feet_cell(feet as Vector3)
	var use := use_down()
	if use and uses_here(cell):
		claim_enter()
	run.step(at_frame, cell, use)
	if bool(run.get("running")) and out_of_world(feet as Vector3):
		falls += 1
		run.respawn_now()
	doors.tick(at_frame)
	looks.tick(at_frame)
	_hud_tick(at_frame)
	ticks += 1


## "" while the rules may run, else why not: "build" (build mode is on), "stage" (a game is on stage), "nobody" (no
## visitor's feet are known).
func _off_reason(feet: Variant) -> String:
	if host == null or bool(host.get("active")):
		return "build"
	if int(host.call("_stage")) >= 0:
		return "stage"
	if not (feet is Vector3):
		return "nobody"
	return ""


func stop(why: String) -> void:
	if running:
		if "instant" in facade:
			facade.set("instant", true)
		run.stop(why)
		if "instant" in facade:
			facade.set("instant", false)
	doors.clear()
	running = false
	why_off = why
	_show(false)


## The visitor's feet (build_mode.gd `feet_at` in a case, else the view's visitor), or null.
func feet_now() -> Variant:
	var fa: Callable = host.get("feet_at")
	if fa.is_valid():
		return fa.call()
	var v: Node3D = host.call("_visitor")
	return v.get("feet") if v != null else null


func visitor_node() -> Node3D:
	if visitor != null and is_instance_valid(visitor):
		return visitor
	return host.call("_visitor") as Node3D if host != null else null


## E went down this frame: the visit's TLInput (kernel/runner/visit.gd ACTIONS `enter`), sampled before this frame.
func use_down() -> bool:
	if use_at.is_valid():
		return bool(use_at.call())
	var view: Variant = host.get("_view")
	var visit: Variant = (view as Node).get("visit") if view is Node else null
	var input: Variant = (visit as Node).get("input") if visit is Node else null
	return input is TLInput and (input as TLInput).just_pressed(&"enter")


## True when the cell is in a zone some rule triggers `on: use` and that zone is not taken.
func uses_here(cell: Vector3i) -> bool:
	var l: RefCounted = run.layer
	if l == null:
		return false
	if int(l.get("revision")) != _use_rev:
		_use_rev = int(l.get("revision"))
		_use_zones.clear()
		var rules: Dictionary = l.get("rules")
		for id: int in rules:
			var w: Dictionary = rules[id].when
			if str(w.on) == "use":
				_use_zones[int(w.zone)] = true
	for z: int in l.call("zones_at", cell):
		if _use_zones.has(z) and not bool(run.call("is_taken", z)):
			return true
	return false


## E is the rules' this frame: the visit's "enter" request of this frame is taken back (kernel/world/tiers.gd answers
## requests at the next world tick). Returns how many.
func claim_enter() -> int:
	var s: Object = sched
	if s == null:
		var view: Variant = host.get("_view") if host != null else null
		var world: Variant = (view as Node).get("world") if view is Node else null
		s = (world as Object).get("sched") if world is Object else null
	if s == null:
		return 0
	var asks: Variant = s.get("_requests")
	if not (asks is Array):
		return 0
	var n := 0
	for i: int in range((asks as Array).size() - 1, -1, -1):
		var a: Dictionary = (asks as Array)[i]
		if str(a.get("e", "")) == "enter" and int(a.get("t", 0)) == -1:
			(asks as Array).remove_at(i)
			n += 1
	claimed += n
	return n


## Out of the world: below FALL_Y with no ground under him (the visitor's space), or below HARD_FALL.
func out_of_world(feet: Vector3) -> bool:
	if feet.y < HARD_FALL:
		return true
	if feet.y >= FALL_Y:
		return false
	var v := visitor_node()
	var sp: Variant = v.get("space") if v != null else null
	if sp is Object:
		return is_nan(float((sp as Object).call("ground_at", feet.x, feet.z, feet.y + 0.5)))
	return true


func _records() -> void:
	if records != null or host == null:
		return
	var d := str(host.get("dir"))
	if d.is_empty():
		return
	records = HomeRecords.new(d)
	records_error = str(records.call("load"))
	if records_error != "":
		push_warning("[rules] the run records in %s could not be read (%s): nothing is recorded there" % [d, records_error])
	run.records = records


func _show(on: bool) -> void:
	looks.set_visible(on)
	if hud != null:
		if not on:
			hud.call("stopped")
		hud.call("show_hud", on)


func _hud_tick(at_frame: int) -> void:
	if hud == null and host != null and host.is_inside_tree():
		hud = PlayHud.new()
		host.add_child(hud)
	if hud != null:
		var l: RefCounted = run.layer
		hud.call("tick", at_frame, run.call("state"), l.call("counters") if l != null else [])


## A run was finished: confetti at his feet (play_facade.gd `run_finished`).
func finish_fx() -> void:
	var v := visitor_node()
	if v != null:
		burst("confetti", (v.get("feet") as Vector3) + Vector3(0, 1.6, 0), 0.8, 150)


## A one-shot TLStyleFx preset at `at` (world, under the looks' holder), freed `frames` physics frames later.
func burst(preset: String, at: Vector3, size: float, frames: int) -> void:
	var root: Variant = looks.get("holder")
	if not (root is Node3D):
		return
	var p: CPUParticles3D = TLStyleFx.preset(preset, {"scale": size, "life_frames": mini(frames, 90)})
	if p != null:
		p.position = at
		(root as Node3D).add_child(p)
		(looks.get("fx") as Array).append([p, frame + frames])
