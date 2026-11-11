extends Node
## P11. The visitor's input is a record. A person who walks a world (kernel/world/draw/view.gd, `--live`) reaches it
## through ONE TLInput of the world's own, sampled once per world tick; everything below that line (where he goes,
## where he looks, who is on stage, when the world ends) reads only that input. So a visit can be written as a
## `tl.input/1` record (`--record=<file>`) and fed back (`--input=<file>`): the visitor walks the same path and every
## pack ends with the same hash. Later a second player's keys can arrive here from another machine.
##
##   actions  forward W, back S, left A, right D (sidestep), run Shift, enter E, leave Q, quit Esc, and the pointer
##            (TLInput.LOOK_X / LOOK_Y: pixels the mouse moved while it was captured, this tick)
##   record   `pack` is the walk's name, `mode` "play", `max_frames` the walk's ticks, `length` the samples taken.
##            A game played on stage is a record of its own (the same schema, that pack's own frames):
##            `<record>.<plot>.<n>.json` for the n-th time the person was on that plot's stage.
##   devices  `--devices=<file>` (tests): [[tick, "key", "<Key>", 1|0], [tick, "move", dx, dy], [tick, "shot", "<name>", 0],
##            [tick, "mark", "<name>", 0]] (a mark prints where he is at that tick, before its move)
##            raw events put into the engine's input path at a world tick (Input.parse_input_event), as a person makes them.
## Above the sampling line: `_input` (mouse motion while captured), the device script and the mouse capture.

const Session: GDScript = preload("res://kernel/runner/session.gd")
const ACTIONS: Array = [[&"forward", KEY_W], [&"back", KEY_S], [&"left", KEY_A], [&"right", KEY_D], [&"run", KEY_SHIFT],
	[&"enter", KEY_E], [&"leave", KEY_Q], [&"quit", KEY_ESCAPE]]
const LOOK_DEG_PER_PX: float = 0.15     # 600 px of mouse = 90 degrees
const PITCH_MIN_DEG: float = -10.0      # the camera's elevation above the visitor's head: he stays in the picture
const PITCH_MAX_DEG: float = 60.0
const WALK_MPS: float = 4.5
const RUN_MPS: float = 9.0
const GATE_OUT_M: float = 5.0           # after Q he stands this far outside the plot's radius, at its gate
const PATH_EVERY: int = 300             # a `visit_path` line every this many ticks

var input: TLInput = null
var view: Node = null
var world: Node = null
var devices: bool = false               # a person's devices are read (not a replay)
var record_path: String = ""
var replay: Dictionary = {}
var _rec: Variant = null
var _mouse: Vector2 = Vector2.ZERO
var _script: Dictionary = {}            # tick -> [[kind, a, b], ...]
var _stage_rec: Array = []              # [plot index, TLInput, frames list or null, visit number]
var _visits: Dictionary = {}            # plot id -> times on stage
var _stage_feeds: Dictionary = {}       # "<plot id>.<n>" -> record (replay)
var _ticks: int = 0
var _captured: bool = false
var shots: Array = []                   # [tick, name] asked by the device script


## `opts`: the viewer's options (record, input, devices). Returns "" or why the visit cannot start.
func setup(v: Node, opts: Dictionary) -> String:
	name = "TLVisit"
	view = v
	world = v.get("world")
	input = TLInput.new()
	input.name = "VisitorInput"
	add_child(input)
	for a: Array in ACTIONS:
		input.declare(a[0], [a[1]])
	if opts.has("input"):
		var r: Dictionary = Session.call("read", str(opts["input"]))
		if not bool(r["ok"]):
			return str(r["error"])
		replay = r["record"]
		input._feed(replay["frames"])
		var base: String = str(opts["input"]).trim_suffix(".json")
		for f: String in DirAccess.get_files_at(base.get_base_dir()):
			var full: String = base.get_base_dir() + "/" + f
			if full.begins_with(base + ".") and f.ends_with(".json") and full != str(opts["input"]):
				var sr: Dictionary = Session.call("read", full)
				if bool(sr["ok"]):
					_stage_feeds[full.trim_prefix(base + ".").trim_suffix(".json")] = sr["record"]
	else:
		devices = true
		input.accept_devices = true
	if opts.has("record"):
		record_path = str(opts["record"])
		_rec = input._record()
	if opts.has("devices"):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(opts["devices"])))
		for e: Variant in (j if typeof(j) == TYPE_ARRAY else []):
			if typeof(e) == TYPE_ARRAY and (e as Array).size() == 4:
				var t: int = int(e[0])
				if not _script.has(t):
					_script[t] = []
				(_script[t] as Array).append([str(e[1]), e[2], e[3]])
				if str(e[1]) == "shot":
					shots.append({"t": t, "e": "shot", "name": str(e[2])})
	return ""


## Above the line: what the mouse did while it was captured (a game on stage reads the pointer through its own input).
func _input(event: InputEvent) -> void:
	if devices and int(view.get("stage")) < 0 and event is InputEventMouseMotion:
		_mouse += (event as InputEventMouseMotion).relative
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not devices or not is_inside_tree():
		return
	var want: bool = int(view.get("stage")) < 0 and get_window().has_focus() and _script.is_empty()
	if want != _captured:
		_captured = want
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if want else Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _captured:
		_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## The sampling line, once per world tick: the device script's events of this tick, the pointer, then the latch.
func sample(tick: int) -> void:
	for e: Array in _script.get(tick, []):
		match str(e[0]):
			"key":
				var ev: InputEventKey = InputEventKey.new()
				ev.keycode = OS.find_keycode_from_string(str(e[1]))
				ev.physical_keycode = ev.keycode
				ev.pressed = int(e[2]) != 0
				Input.parse_input_event(ev)
			"move":
				var mv: InputEventMouseMotion = InputEventMouseMotion.new()
				mv.relative = Vector2(float(e[1]), float(e[2]))
				Input.parse_input_event(mv)
			"mark":
				print_path(tick, str(e[1]))
	Input.flush_buffered_events()
	if devices and _mouse != Vector2.ZERO:
		input.press(TLInput.LOOK_X, _mouse.x)
		input.press(TLInput.LOOK_Y, _mouse.y)
	_mouse = Vector2.ZERO
	input._sample()
	_ticks += 1


## Below the line: where he goes and looks, enter, leave, quit. Reads `input` only.
func steer(tick: int) -> void:
	var sched: RefCounted = world.get("sched")
	var vis: Node3D = view.get("visitor")
	if int(view.get("stage")) >= 0:
		if input.just_pressed(&"leave") or input.just_pressed(&"quit"):
			sched.call("request", "leave")
		return
	if input.just_pressed(&"quit"):
		# the walk ends at the next tick: every pack still running is finished and hashed (world.gd `_walk_tick`)
		print("[visit] the visitor quit at tick %d" % tick)
		world.set("walk_ticks", int(world.get("tick")))
		return
	if input.just_pressed(&"enter"):
		sched.call("request", "enter")
	vis.call("turn", input.strength(TLInput.LOOK_X) * deg_to_rad(LOOK_DEG_PER_PX), input.strength(TLInput.LOOK_Y) * deg_to_rad(LOOK_DEG_PER_PX),
		deg_to_rad(PITCH_MIN_DEG), deg_to_rad(PITCH_MAX_DEG))
	var yaw: float = float(vis.get("look_yaw"))
	var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var move: Vector3 = fwd * input.axis(&"back", &"forward") + right * input.axis(&"left", &"right")
	if move.length() > 0.01:
		var pace: float = RUN_MPS if input.pressed(&"run") else WALK_MPS
		world.set("player_pos", (world.get("player_pos") as Vector3) + move.normalized() * pace / 60.0)
	if tick % PATH_EVERY == 0:
		print_path(tick)


func print_path(tick: int, mark: String = "") -> void:
	var vis: Node3D = view.get("visitor")
	var f: Vector3 = vis.get("feet")
	print(JSON.stringify({"schema": "tl.view/1", "kind": "visit_path", "tick": tick, "feet": [snappedf(f.x, 0.01), snappedf(f.y, 0.01), snappedf(f.z, 0.01)],
		"yaw_deg": snappedf(rad_to_deg(float(vis.get("look_yaw"))), 0.01), "pitch_deg": snappedf(rad_to_deg(float(vis.get("look_pitch"))), 0.01),
		"stage": int(view.get("stage")), "mark": mark}, "", false))


## The stage changes from `was` to `now` (-1: nobody). A person plays the game on stage: its bot waits and its input
## comes from the devices (recorded) or from the record of that visit (replay).
func stage(was: int, now: int, holders: Array, plots: Array, radii: Array) -> void:
	if was >= 0 and was != now:
		var h: Node = holders[was]
		h.set("bot_off", false)
		var ctx: TLContext = h.get("ctx")
		if ctx != null and ctx.input != null:
			ctx.input.accept_devices = false
			ctx.input.set("_play", null)
		_close_stage_record(holders)
		if now < 0:
			_to_gate(was, plots, radii)
	if now < 0:
		return
	var hn: Node = holders[now]
	hn.set("bot_off", true)
	var c: TLContext = hn.get("ctx")
	if c == null or c.input == null:
		return
	if not _stage_rec.is_empty() and _stage_rec[1] == c.input:
		return                                   # the same game, told again (a rebuilt holder says it twice)
	_close_stage_record(holders)
	var id: String = str(((world.get("plot_defs") as Array)[now] as Dictionary)["id"])
	_visits[id] = int(_visits.get(id, 0)) + 1
	var key: String = "%s.%d" % [id, int(_visits[id])]
	if devices:
		c.input.accept_devices = true
		_stage_rec = [now, c.input, c.input._record() if not record_path.is_empty() else null, key]
	else:
		var fr: Array = (_stage_feeds[key] as Dictionary)["frames"] if _stage_feeds.has(key) else []
		c.input._feed(fr)
		_stage_rec = [now, c.input, null, key]


func _close_stage_record(holders: Array) -> void:
	if _stage_rec.is_empty():
		return
	var inp: TLInput = _stage_rec[1]
	if is_instance_valid(inp) and _stage_rec[2] != null:
		inp.set("_rec", null)
		var h: Node = holders[int(_stage_rec[0])]
		var m: Dictionary = h.get("manifest")
		var err: String = Session.call("write", record_path.trim_suffix(".json") + "." + str(_stage_rec[3]) + ".json", {"schema": Session.SCHEMA,
			"pack": str(m.get("id", "")), "seed": int(h.get("seed_value")), "mode": "play", "max_frames": int(h.get("frames_target")),
			"length": int(inp.get("_ticks")), "end": "step", "frames": _stage_rec[2]})
		if not err.is_empty():
			print("[visit] " + err)
	_stage_rec = []


## After Q: outside the plot at its gate (the side that faces the road), facing away from the venue.
func _to_gate(i: int, plots: Array, radii: Array) -> void:
	var o: Vector3 = (plots[i] as Transform3D).origin
	var g: Vector2 = _gate_dir(Vector2(o.x, o.z))
	var at: Vector3 = Vector3(o.x + g.x * (float(radii[i]) + GATE_OUT_M), 0.0, o.z + g.y * (float(radii[i]) + GATE_OUT_M))
	var vis: Node3D = view.get("visitor")
	vis.call("put", at, atan2(-g.x, -g.y))
	world.set("player_pos", Vector3(at.x, 0.0, at.z))
	var f: Vector3 = vis.get("feet")
	var gap: float = Vector2(f.x - o.x, f.z - o.z).length() - float(radii[i])
	print(JSON.stringify({"schema": "tl.view/1", "kind": "visit_left", "tick": int(world.get("tick")), "plot": i, "feet": [snappedf(f.x, 0.01), snappedf(f.y, 0.01), snappedf(f.z, 0.01)],
		"outside_edge_m": snappedf(gap, 0.01), "gate": [snappedf(g.x, 0.001), snappedf(g.y, 0.001)], "yaw_deg": snappedf(rad_to_deg(float(vis.get("look_yaw"))), 0.01)}, "", false))


## The direction from a plot's centre to the nearest point of the walk's road (the landscape puts the gate there).
func _gate_dir(c: Vector2) -> Vector2:
	var road: Array = (world.get("walk") as Dictionary).get("road", [])
	var best: Vector2 = Vector2.ZERO
	var bd: float = INF
	for k: int in range(road.size() - 1):
		var a: Vector2 = Vector2(float(road[k][0]), float(road[k][1]))
		var b: Vector2 = Vector2(float(road[k + 1][0]), float(road[k + 1][1]))
		var p: Vector2 = Geometry2D.get_closest_point_to_segment(c, a, b)
		if p.distance_to(c) < bd:
			bd = p.distance_to(c)
			best = p
	return (best - c).normalized() if bd < INF and bd > 0.01 else Vector2(0.0, 1.0)


## The world ended: the records are written.
func finish() -> void:
	_close_stage_record(world.get("packs"))
	if devices and _captured:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print_path(int(world.get("tick")))
	if record_path.is_empty() or _rec == null:
		return
	var walk: Dictionary = world.get("walk")
	var err: String = Session.call("write", record_path, {"schema": Session.SCHEMA, "pack": str(walk.get("name", "walk")), "seed": 1,
		"mode": "play", "max_frames": int(world.get("walk_ticks")), "length": _ticks, "end": "step", "frames": _rec})
	print(JSON.stringify({"schema": "tl.view/1", "kind": "visit_record", "out": record_path, "ok": err.is_empty(), "length": _ticks, "error": err}, "", false))
