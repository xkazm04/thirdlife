extends Node
## P11. The visitor's input is a record. A person who walks a world (kernel/world/draw/view.gd, `--live`) reaches it
## through ONE TLInput of the world's own, sampled once per world tick; everything below that line (where he goes,
## where he looks, who is on stage, when the world ends) reads only that input. So a visit can be written as a
## `tl.input/1` record (`--record=<file>`) and fed back (`--input=<file>`): the visitor walks the same path and every
## pack ends with the same hash. Later a second player's keys can arrive here from another machine.
##
##   actions  forward W, back S, left A, right D, run Shift, jump/mantle/release Space, run slide/grip drop C, fly F (Space climbs, C descends), enter E, leave Q, quit Esc, and the pointer
##            (TLInput.LOOK_X / LOOK_Y: pixels the mouse moved while it was captured, this tick)
##   record   `pack` is the walk's name, `mode` "play", `max_frames` the walk's ticks, `length` the samples taken.
##            A game played on stage is a record of its own (the same schema, that pack's own frames):
##            `<record>.<plot>.<n>.json` for the n-th time the person was on that plot's stage.
##   devices  `--devices=<file>` (tests): [[tick, "key", "<Key>", 1|0], [tick, "move", dx, dy], [tick, "shot", "<name>", 0],
##            [tick, "mark", "<name>", 0], [tick, "trace", <frames>, 0]] (a mark prints where he is at that tick, before
##            its move; a trace prints, for that many DRAWN frames, where the figure and the camera are drawn: kind
##            `visitor_frame`, the proof that they move between ticks when frames outrun ticks)
##            raw events put into the engine's input path at a world tick (Input.parse_input_event), as a person makes them.
## Above the sampling line: `_input` (mouse motion while captured), the device script and the mouse capture.

const Session: GDScript = preload("res://kernel/runner/session.gd")
const ACTIONS: Array = [[&"forward", KEY_W], [&"back", KEY_S], [&"left", KEY_A], [&"right", KEY_D], [&"run", KEY_SHIFT],
	[&"enter", KEY_E], [&"leave", KEY_Q], [&"quit", KEY_ESCAPE], [&"jump", KEY_SPACE], [&"slide", KEY_C], [&"fly", KEY_F]]
const LOOK_DEG_PER_PX: float = 0.15     # 600 px of mouse = 90 degrees
const PITCH_MIN_DEG: float = -10.0      # the camera's elevation above the visitor's head: he stays in the picture
const PITCH_MAX_DEG: float = 60.0
const WalkerBody = preload("res://kernel/world/terrain/world_body.gd")
const WALK_MPS: float = WalkerBody.WALK_MPS
const RUN_MPS: float = WalkerBody.RUN_MPS
const GATE_OUT_M: float = 5.0           # after Q he stands this far outside the plot's radius, at its gate
const PATH_EVERY: int = 300             # a `visit_path` line every this many ticks
## Lane walker (19 Nov): what A and D do is the owner's question, so both answers sit behind TL_AD_KEYS (absent: as before).
##   (absent) or face   A and D move him sideways along the view; the figure turns toward where he walks (walker-feel M)
##   sidestep           the same move, but the figure keeps facing where the camera looks: a sidestep (S: a backward walk)
##   turn               A and D turn him and the view TURN_DEG_PER_TICK a tick (the mouse still looks); W and S as before
## A record is replayed with the value it was made with.
const TURN_DEG_PER_TICK: float = 2.5    # 150 degrees a second
var ad_keys: String = OS.get_environment("TL_AD_KEYS")

var input: TLInput = null
var view: Node = null
var world: Node = null
var devices: bool = false               # a person's devices are read (not a replay)
var record_path: String = ""
var replay: Dictionary = {}
var _rec: Variant = null
var _mouse: Vector2 = Vector2.ZERO
var _script: Dictionary = {}            # tick -> [[kind, a, b], ...]
var _stage_rec: Array = []              # [plot index, TLInput, frames list or null, visit number, samples taken when last seen]
var _leaving: Callable = Callable()     # D2: connected to the recorded stage input's tree_exiting
var _visits: Dictionary = {}            # plot id -> times on stage
var _stage_feeds: Dictionary = {}       # "<plot id>.<n>" -> record (replay)
var _ticks: int = 0
var _captured: bool = false
var shots: Array = []                   # [tick, name] asked by the device script
var _held: Dictionary = {}              # walker-feel round 2: keys the device script holds down (keycode -> true)


## `opts`: the viewer's options (record, input, devices). Returns "" or why the visit cannot start.
func setup(v: Node, opts: Dictionary) -> String:
	name = "TLVisit"
	view = v
	world = v.get("world")
	var visitor: Node = v.get("visitor")
	if visitor != null and visitor.has_signal("flight_step"):
		visitor.connect("flight_step", _fly_gate)
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
		var in_path: String = str(opts["input"]).replace("\\", "/")     # hunt2 B4: a Windows path (backslashes) found no stage records
		var base: String = in_path.trim_suffix(".json")
		for f: String in DirAccess.get_files_at(base.get_base_dir()):
			var full: String = base.get_base_dir() + "/" + f
			if full.begins_with(base + ".") and f.ends_with(".json") and full != in_path:
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
		if _looks():
			_mouse += (event as InputEventMouseMotion).relative
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not devices or not is_inside_tree():
		return
	var want: bool = int(view.get("stage")) < 0 and get_window().has_focus() and _script.is_empty() and _looks()
	if want != _captured:
		_captured = want
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if want else Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _captured:
		_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## The sampling line, once per world tick: the device script's events of this tick, the pointer, then the latch.
func sample(tick: int) -> void:
	# T-PATCHES M4: the engine lets go of every pressed key when another window takes the focus; a key the device
	# script still holds is pressed again here (a person's own keys are the person's: only scripted ones)
	for k: Variant in _held.keys():
		if not Input.is_physical_key_pressed(int(k)):
			var again: InputEventKey = InputEventKey.new()
			again.keycode = int(k)
			again.physical_keycode = int(k)
			again.pressed = true
			Input.parse_input_event(again)
	for e: Array in _script.get(tick, []):
		match str(e[0]):
			"key":
				var ev: InputEventKey = InputEventKey.new()
				ev.keycode = OS.find_keycode_from_string(str(e[1]))
				ev.physical_keycode = ev.keycode
				ev.pressed = int(e[2]) != 0
				Input.parse_input_event(ev)
				if ev.pressed:
					_held[ev.keycode] = true
				else:
					_held.erase(ev.keycode)
			"move":
				var mv: InputEventMouseMotion = InputEventMouseMotion.new()
				mv.relative = Vector2(float(e[1]), float(e[2]))
				Input.parse_input_event(mv)
			"mark":
				print_path(tick, str(e[1]))
			"trace":
				(view.get("visitor") as Node).set("trace_frames", int(e[1]))
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
		if vis.get("space") != null:
			vis.call("wish", Vector3.ZERO, false, false)     # walker-feel: on stage the walker's keys are not his
		# K8: on stage a key the game declared is the game's: Q leaves only a game that does not use Q; Esc always leaves
		if input.just_pressed(&"quit") or (input.just_pressed(&"leave") and not stage_uses_key(KEY_Q)):
			sched.call("request", "leave")
		return
	if input.just_pressed(&"quit") and _building() == null:     # WP2: Esc in build mode leaves build mode, never the walk
		# the walk ends at the next tick: every pack still running is finished and hashed (world.gd `_walk_tick`)
		print("[visit] the visitor quit at tick %d" % tick)
		world.set("walk_ticks", int(world.get("tick")))
		return
	if input.just_pressed(&"enter") and vis.get("flying") != true and _building() == null:
		sched.call("request", "enter")
	var toggle_fly := input.just_pressed(&"fly")
	var in_flight: bool = (vis.get("flying") == true) != toggle_fly
	var turn_keys := ad_keys == "turn" and not in_flight
	var key_turn: float = input.axis(&"left", &"right") * deg_to_rad(TURN_DEG_PER_TICK) if turn_keys else 0.0
	vis.call("turn", input.strength(TLInput.LOOK_X) * deg_to_rad(LOOK_DEG_PER_PX) + key_turn, input.strength(TLInput.LOOK_Y) * deg_to_rad(LOOK_DEG_PER_PX),
		deg_to_rad(PITCH_MIN_DEG), deg_to_rad(PITCH_MAX_DEG))
	if vis.get("face_view") != null:
		vis.set("face_view", ad_keys == "sidestep")
	var yaw: float = float(vis.get("look_yaw"))
	var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var side: float = 0.0 if turn_keys else input.axis(&"left", &"right")
	var move: Vector3 = fwd * input.axis(&"back", &"forward") + right * side
	var pace: float = RUN_MPS if input.pressed(&"run") else WALK_MPS
	if in_flight:
		var forward_share := maxf(0.0, move.normalized().dot(fwd))
		pace = RUN_MPS * lerpf(1.0, WalkerBody.FLY_SCALE, forward_share)
	# walker-feel: the body has weight (visitor.gd `wish`, world_space.gd `drive`): it eases toward this velocity
	var want: Vector3 = move.normalized() * pace if move.length() > 0.01 else Vector3.ZERO
	if vis.get("space") != null:
		vis.call("wish", want, input.just_pressed(&"jump") and not in_flight and not toggle_fly,
			input.just_pressed(&"slide") and not in_flight and not toggle_fly, toggle_fly, input.axis(&"slide", &"jump"))
	elif move.length() > 0.01:
		world.set("player_pos", (world.get("player_pos") as Vector3) + want / 60.0)
	if tick % PATH_EVERY == 0:
		print_path(tick)


## WP2 (spark world-sandbox): the Home's build mode (kernel/world/build/build_mode.gd, the landscape's meta
## "tl_build_mode") while it is on, else null. It frees the cursor, and E and Esc are its own then.
func _building() -> Node:
	var land: Variant = view.get("landscape")
	var bm: Variant = (land as Node).get_meta(&"tl_build_mode", null) if land is Node else null
	return bm if is_instance_valid(bm) and bm is Node and bool((bm as Node).get("active")) else null


## The mouse looks (captured): not in build mode, or in build mode while its look is held (MMB or Alt).
func _looks() -> bool:
	var bm: Node = _building()
	return bm == null or bool(bm.get("looking"))


## K8. True while a game is on stage and it declared an action on the physical key `keycode` (its own TLInput's
## declarations: the host never reads the game's devices for this). Such a key is the game's, not the host's.
func stage_uses_key(keycode: int) -> bool:
	if _stage_rec.size() < 2 or not is_instance_valid(_stage_rec[1]):
		return false
	return bool((_stage_rec[1] as TLInput).call("_declares_key", keycode))


## K8. The keys hint for the game on stage: "Esc  leave the game" when the game uses Q, else "Q or Esc  leave the game".
func stage_hint() -> String:
	return "Esc  leave the game" if stage_uses_key(KEY_Q) else "Q or Esc  leave the game"


func print_path(tick: int, mark: String = "") -> void:
	var vis: Node3D = view.get("visitor")
	var f: Vector3 = vis.get("feet")
	var line: Dictionary = {"schema": "tl.view/1", "kind": "visit_path", "tick": tick, "feet": [snappedf(f.x, 0.001), snappedf(f.y, 0.001), snappedf(f.z, 0.001)],
		"yaw_deg": snappedf(rad_to_deg(float(vis.get("look_yaw"))), 0.01), "pitch_deg": snappedf(rad_to_deg(float(vis.get("look_pitch"))), 0.01),
		"stage": int(view.get("stage")), "mark": mark}
	# walker-feel: how high the camera stands over the ground under it, and the body's mode (a mark only)
	var sp: RefCounted = vis.get("space")
	var cam: Camera3D = vis.get("cam")
	if not mark.is_empty() and sp != null and cam != null and int(view.get("stage")) < 0:
		var c: Vector3 = cam.global_position
		var g: float = sp.call("ground_at", c.x, c.z, c.y + 60.0)
		if not is_nan(g):
			line["cam_over_ground_m"] = snappedf(c.y - g, 0.01)
		line["body"] = str(vis.get("mode"))
		var pq: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
		pq.position = c
		pq.collision_mask = 4                          # a tree's crown (world_space CANOPY)
		line["cam_in_crown"] = not PhysicsServer3D.space_get_direct_state(sp.get("space")).intersect_point(pq, 1).is_empty()
	print(JSON.stringify(line, "", false))


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
	# D10: the hand-over. What the bot injected (TLInput.press holds until release) is let go here, or the person's
	# game keeps the bot's held press (the drive bot's gas) with no key down. Only on stage with a person: bot-mode
	# runs never come here, so their hashes are untouched.
	c.input.release_all()
	if devices:
		c.input.accept_devices = true
		_stage_rec = [now, c.input, c.input._record() if not record_path.is_empty() else null, key, int(c.input.get("_ticks"))]
		if _stage_rec[2] != null:
			_leaving = _on_stage_input_leaving.bind(c.input)
			c.input.tree_exiting.connect(_leaving)
	else:
		var fr: Array = (_stage_feeds[key] as Dictionary)["frames"] if _stage_feeds.has(key) else []
		c.input._feed(fr)
		_stage_rec = [now, c.input, null, key, int(c.input.get("_ticks"))]


## D2: the game on stage is rebuilt from its seed (world.gd `_rebuild` frees the holder's children in the tree): the
## samples its input took are read while it still exists, so the record's `length` is the ticks sampled.
func _on_stage_input_leaving(inp: TLInput) -> void:
	if not _stage_rec.is_empty() and _stage_rec[1] == inp:
		_stage_rec[4] = int(inp.get("_ticks"))


func _close_stage_record(holders: Array) -> void:
	if _stage_rec.is_empty():
		return
	var alive: bool = is_instance_valid(_stage_rec[1])
	if alive and _leaving.is_valid() and (_stage_rec[1] as TLInput).tree_exiting.is_connected(_leaving):
		(_stage_rec[1] as TLInput).tree_exiting.disconnect(_leaving)
	_leaving = Callable()
	if _stage_rec[2] == null or record_path.is_empty():
		_stage_rec = []
		return
	var frames: Array = _stage_rec[2]
	# D2: `length` is the samples taken (header), never the count of the sparse rows. The input alive: its own count.
	# Rebuilt on stage (its next round; walker-feel round 2: typing a freed input was a SCRIPT ERROR): the count read
	# as it left the tree, and never below the last recorded frame + 1 (the session writer rejects a frame >= length).
	var length: int = int((_stage_rec[1] as TLInput).get("_ticks")) if alive else int(_stage_rec[4])
	if not frames.is_empty():
		length = maxi(length, int(frames[frames.size() - 1][0]) + 1)
	if alive:
		(_stage_rec[1] as TLInput).set("_rec", null)
	var h: Variant = holders[int(_stage_rec[0])]
	var hv: bool = is_instance_valid(h)
	var m: Dictionary = (h as Node).get("manifest") if hv else {}
	var out: String = record_path.trim_suffix(".json") + "." + str(_stage_rec[3]) + ".json"
	var err: String = Session.call("write", out, {"schema": Session.SCHEMA, "pack": str(m.get("id", "")),
		"seed": int((h as Node).get("seed_value")) if hv else 1, "mode": "play",
		"max_frames": int((h as Node).get("frames_target")) if hv else length, "length": length, "end": "step", "frames": frames})
	if not err.is_empty():
		# D2: a stage record that could not be written is said, never dropped in silence
		push_error("[visit] the stage record %s was not written: %s" % [out, err])
		print("[visit] " + err)
	_stage_rec = []


## The flight sweep just finished. Use the same gate and facing as leaving the stage.
func _fly_gate() -> void:
	var vis: Node3D = view.get("visitor")
	var feet: Vector3 = vis.get("feet")
	var plots: Array = view.get("plots")
	var radii: Array = view.get("radii")
	for i in mini(plots.size(), radii.size()):
		var delta := feet - (plots[i] as Transform3D).origin
		if delta.y < 12.0 and Vector2(delta.x, delta.z).length() < float(radii[i]):
			_to_gate(i, plots, radii, "visit_fly_gate")
			return


## After Q: outside the plot at its gate (the side that faces the road), facing away from the venue.
func _to_gate(i: int, plots: Array, radii: Array, kind: String = "visit_left") -> void:
	var o: Vector3 = (plots[i] as Transform3D).origin
	var g: Vector2 = _gate_dir(Vector2(o.x, o.z))
	var at: Vector3 = Vector3(o.x + g.x * (float(radii[i]) + GATE_OUT_M), 0.0, o.z + g.y * (float(radii[i]) + GATE_OUT_M))
	var vis: Node3D = view.get("visitor")
	vis.call("put", at, atan2(-g.x, -g.y))
	world.set("player_pos", Vector3(at.x, 0.0, at.z))
	var f: Vector3 = vis.get("feet")
	var gap: float = Vector2(f.x - o.x, f.z - o.z).length() - float(radii[i])
	print(JSON.stringify({"schema": "tl.view/1", "kind": kind, "tick": int(world.get("tick")), "plot": i, "feet": [snappedf(f.x, 0.01), snappedf(f.y, 0.01), snappedf(f.z, 0.01)],
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
