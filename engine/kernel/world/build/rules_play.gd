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
const PlayGhost := preload("res://kernel/world/build/play_ghost.gd")
const GHOST_KEY := KEY_G                 # round 2: hides / shows the best run's ghost for the rest of the visit
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
var ghost: RefCounted = null             # play_ghost.gd: the best run's ghost (recorded while a run goes, played on a restart)
var ghost_key: Callable                  # () -> bool, a case's G; else the keyboard (a display toggle, not a rule input)
var ghost_error := ""                    # why the run's ghost file was not read at its start ("" read, "none" no file)
var ghost_write_error := ""              # why the last new best's ghost was not written ("" written)
var _g_was := false
const CAM_FAR := 0.38                    # round 2: during a run the camera's arm is this much longer ...
const CAM_UP := 0.6                      # ... and it looks this many metres higher (eased in and out over CAM_FRAMES)
const CAM_FRAMES := 45
const STRETCH_FRAMES := 14               # a launch: the figure stretched up and thin, easing back
var cam_k := 0.0                         # 0 the person's camera .. 1 the run's
var _cam_base: Array = []                # [arm, look height] of the visitor's camera before any run
var _stretch_at := -1000
var _feet := Vector3.ZERO


func _init(h: Node) -> void:
	host = h
	facade = PlayFacade.new(self)
	var b: Variant = host.get("build") if host != null else null
	doors = PlayDoors.new(b as RefCounted if b is RefCounted else null)
	looks = PlayLooks.new((b as RefCounted).get("root") if b is RefCounted else null)
	run = RulesRun.new(_rules(), facade, records)
	ghost = PlayGhost.new()


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
		ghost.call("set_shown", true)                  # every visit starts with the ghost shown
		run.begin(at_frame, feet as Vector3)
		running = true
		_show(true)
	if run.layer != null and int(looks.get("revision")) != int(run.layer.get("revision")):
		looks.sync(run.layer)
		_ground_looks()
	var cell := RulesRun.feet_cell(feet as Vector3)
	var use := use_down()
	if use and uses_here(cell):
		claim_enter()
	_feet = feet as Vector3
	_ghost_key()
	ghost.call("play_tick")                                       # frame n of the kept track beside frame n of this run
	run.step(at_frame, cell, use)
	if bool(run.get("running")):
		var v := visitor_node()
		var rg: Variant = v.get("rig") if v != null else null
		ghost.call("record", int(run.call("state").frames), _feet, float(v.get("face_yaw")) if v != null else 0.0,
			str((rg as Node).get("clip")) if rg is Node else "")
	if bool(run.get("running")) and out_of_world(feet as Vector3):
		falls += 1
		run.respawn_now()
	doors.tick(at_frame)
	looks.tick(at_frame)
	_hud_tick(at_frame)
	_feel_tick(at_frame)
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
	_feel_reset()
	ghost.call("play_stop")
	ghost.set("recording", false)
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


## A pad or a flag stands on what is under it: a zone's floor cell can hold the terrain's surface (an LLM's start pad
## on grass at y 2 where the ground is 2.7 m): the look is lifted onto the ground found in its box (the visitor's space).
func _ground_looks() -> void:
	var v := visitor_node()
	var sp: Variant = v.get("space") if v != null else null
	if not (sp is Object):
		return
	var zones: Dictionary = run.layer.get("zones")
	var nodes: Dictionary = looks.get("nodes")
	for z: int in nodes:
		var n: Node3D = nodes[z]
		if str(looks.get("looks")[z]) == "coin" or not zones.has(z):
			continue
		var top := float(zones[z].box[1][1]) + 1.0
		var g := float((sp as Object).call("ground_at", n.position.x, n.position.z, top))
		if not is_nan(g) and g > n.position.y and g < top:
			n.position.y = g + 0.01


## Round 2, the run's feel: while a run goes the camera eases back and up (CAM_FAR, CAM_UP) so a wall or a pad ahead
## is seen over his shoulder, and eases back to the person's when it ends; a launch stretches the figure for a moment.
## Through the visitor's own camera arm (visitor.gd `_cam_dist`, `_cam_look_h`, read by its `_place_cam`): PATCHES-P6 E3.
func _feel_tick(at_frame: int) -> void:
	var v := visitor_node()
	if v == null or v.get("_cam_dist") == null:
		return
	if _cam_base.is_empty():
		_cam_base = [float(v.get("_cam_dist")), float(v.get("_cam_look_h"))]
	var want := 1.0 if bool(run.get("running")) else 0.0
	cam_k = move_toward(cam_k, want, 1.0 / CAM_FRAMES)
	var e := cam_k * cam_k * (3.0 - 2.0 * cam_k)
	v.set("_cam_dist", float(_cam_base[0]) * (1.0 + CAM_FAR * e))
	v.set("_cam_look_h", float(_cam_base[1]) + CAM_UP * e)
	var k := float(at_frame - _stretch_at) / STRETCH_FRAMES
	if k >= 0.0 and k <= 1.0:
		var a := 1.0 - k
		v.scale = Vector3(1.0 - 0.12 * a, 1.0 + 0.22 * a, 1.0 - 0.12 * a)
	elif v.scale != Vector3.ONE and k > 1.0:
		v.scale = Vector3.ONE


func _feel_reset() -> void:
	var v := visitor_node()
	if v != null and not _cam_base.is_empty():
		v.set("_cam_dist", float(_cam_base[0]))
		v.set("_cam_look_h", float(_cam_base[1]))
		v.scale = Vector3.ONE
	cam_k = 0.0
	_stretch_at = -1000


## A launch went off (play_facade.gd `launch`): the pad under him kicks, he stretches.
func launched() -> void:
	_stretch_at = frame
	var l: RefCounted = run.layer
	if l != null:
		looks.call("kick", l.call("zones_at", RulesRun.feet_cell(_feet)), frame)


## G went down (a case's `ghost_key`, else the keyboard): the ghost hidden or shown for the rest of the visit.
func _ghost_key() -> void:
	var down := bool(ghost_key.call()) if ghost_key.is_valid() else Input.is_physical_key_pressed(GHOST_KEY)
	if down and not _g_was:
		ghost.call("set_shown", not bool(ghost.get("shown")))
		print(JSON.stringify({"schema": "tl.view/1", "kind": "rules", "what": "ghost_shown", "frame": frame, "shown": ghost.get("shown")}, "", false))
	_g_was = down


## A run started (play_facade.gd `run_started`): record it from frame 0; its best's ghost, if one is kept, walks too.
func ghost_start(run_name: String) -> void:
	ghost.call("record_start")
	var d := str(host.get("dir")) if host != null else ""
	ghost.call("play_stop")
	if d == "":
		return
	var r: Dictionary = PlayGhost.read(PlayGhost.path_of(d, run_name))
	ghost_error = str(r.get("error", ""))
	if r.has("ghost"):
		ghost.call("play_start", looks.get("holder"), r.ghost)
	elif ghost_error != "none":
		push_warning("[rules] the ghost of '%s' was not read: %s" % [run_name, ghost_error])


## A run finished: on a new best its path replaces the kept ghost. The ghost already walking goes on to its end.
func ghost_finish(run_name: String, frames: int, new_best: bool) -> void:
	var v := visitor_node()
	var rg: Variant = v.get("rig") if v != null else null
	ghost.call("record", frames, _feet, float(v.get("face_yaw")) if v != null else 0.0, str((rg as Node).get("clip")) if rg is Node else "")
	var doc: Dictionary = ghost.call("doc_of", run_name, frames)
	var d := str(host.get("dir")) if host != null else ""
	if not new_best or doc.is_empty() or d == "":
		return
	ghost_write_error = PlayGhost.write(d, doc)
	if ghost_write_error != "":
		push_warning("[rules] the ghost of '%s' was not written: %s" % [run_name, ghost_write_error])


## A run finished: confetti at his feet (play_facade.gd `run_finished`).
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
