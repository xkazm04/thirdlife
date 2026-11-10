extends Node
## The sim worker: one process, one pack, one run. Started by the supervisor (host.gd) as a child process with
## `-- worker --mode=<smoke|bot|capture> --pack=... --result=<file>`. It loads the pack, runs a counted number of
## physics frames and writes a result file the supervisor turns into the tl.verify/1 report.
##
## Order inside one physics frame f (this node runs before every other node):
##   ctx.frame = f -> bot._bot_tick(f) -> ctx.input latches -> entry._pack_tick(f) -> kernel primitives and the rest
##   of the tree -> the physics step. A run of N frames ticks f = 0..N-1 and hashes the state after step N-1.

const LoggerScript: GDScript = preload("res://kernel/runner/logger.gd")
const Manifest: GDScript = preload("res://kernel/runner/manifest.gd")

const TICK_LIMIT_MS: int = 250          # RUNNER.md: one _pack_tick or _bot_tick
const SETUP_LIMIT_MS: int = 10000       # kernel addition: generators, _pack_setup, _pack_start, _bot_setup, teardown
const MAX_ERRORS: int = 20              # RUNNER.md: more than this trips the watchdog
const HARD_NODE_CAP: int = 50000        # runaway spawning (ten times the V3 budget)
const HARD_MEMORY_CAP: int = 4 * 1024 * 1024 * 1024
const CENSUS_EVERY: int = 10
const HASH_TRACE_EVERY: int = 300
const BELOW_Y: float = -50.0
const ORPHAN_AFTER_S: float = 60.0

var opts: Dictionary = {}
var mode: String = "smoke"
var pack_dir: String = ""
var result_path: String = ""
var frames_target: int = 3600
var ctx: TLContext
var logger: Object
var pack_node: Node3D
var entry: Node
var bot: Node
var frame: int = 0
var started: bool = false
var finished: bool = false
var loaded: bool = false
var load_errors: Array = []
var warnings: Array = []                 # WP5: things that fail nothing but that a builder should read
var watchdog: Dictionary = {}
var bot_info: Dictionary = {}
var capture_info: Dictionary = {}
var entities_max: int = 0
var bodies_max: int = 0
var below: Dictionary = {}
var below_count: int = 0
var hash_trace: Array = []
var frame_usec: PackedInt64Array = PackedInt64Array()
var tick_ms_max: float = 0.0
var _last_frame_usec: int = 0
var _has_tick: bool = false

var _wd_thread: Thread
var _wd_mutex: Mutex = Mutex.new()
var _wd_start: int = 0
var _wd_limit: int = 0
var _wd_phase: String = ""
var _wd_frame: int = -1
var _wd_stop: bool = false
var _wd_tripped: bool = false


func start(options: Dictionary) -> void:
	opts = options
	mode = str(opts.get("mode", "smoke"))
	result_path = str(opts.get("result", ""))
	pack_dir = Manifest.resolve_dir(str(opts.get("pack", "")))
	frames_target = int(opts.get("frames", 3600))
	if mode == "play":
		frames_target = 1 << 40        # interactive: until Esc or the window closes
	print("[tl] worker start: mode=%s" % mode)
	process_physics_priority = -100000
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(false)
	logger = LoggerScript.new()
	logger.pack_dir = pack_dir
	OS.add_logger(logger)
	_wd_thread = Thread.new()
	_wd_thread.start(_wd_run)
	loaded = _load_pack()
	if not loaded:
		_end_run()
		return
	_last_frame_usec = Time.get_ticks_usec()
	set_physics_process(true)


# ------------------------------------------------------------------------------------------------------ loading
func _load_fail(file: String, message: String) -> bool:
	load_errors.append({"kind": "load", "file": file, "message": message})
	return false


func _load_pack() -> bool:
	if pack_dir.is_empty():
		return _load_fail("", "pack directory not found: " + str(opts.get("pack", "")))
	var mres: Dictionary = Manifest.read(pack_dir)
	if not mres["ok"]:
		load_errors.append_array(mres["errors"])
		return false
	var m: Dictionary = mres["manifest"]
	for e: String in TLLaws.load_tables():
		load_errors.append({"kind": "engine", "file": "res://kernel/data", "message": e})
	ctx = TLContext.new()
	TLContext.current = ctx
	ctx.manifest = m
	ctx.pack_dir = pack_dir
	ctx.pack_id = str(m["id"])
	ctx.seed = int(opts.get("seed", 1))
	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = ctx.seed
	ctx.max_frames = frames_target
	ctx.headless = DisplayServer.get_name() == "headless"
	ctx.mode = mode
	pack_node = Node3D.new()
	pack_node.name = "TLPack"
	add_child(pack_node)
	ctx.root = Node3D.new()
	ctx.root.name = "World"
	pack_node.add_child(ctx.root)
	ctx.input = TLInput.new()
	ctx.input.name = "TLInput"
	ctx.input.accept_devices = mode == "play"
	add_child(ctx.input)
	ctx.cameras = TLCameras.new()
	ctx.cameras.name = "TLCameras"
	add_child(ctx.cameras)
	TLStandin.prepare_style(ctx.headless)
	if not ctx.headless:
		TLStandin.install_look(self)
	get_tree().node_added.connect(_on_node_added)

	for gen: String in m["assets"]:
		var gs: GDScript = _load_script(gen)
		if gs == null:
			return false
		if not _script_has(gs, "generate"):
			return _load_fail(gen, "an asset generator needs `static func generate(ctx) -> void`")
		_guard_begin("generate " + gen, SETUP_LIMIT_MS)
		gs.call("generate", ctx)
		_guard_end()
	var es: GDScript = _load_script(str(m["entry"]))
	if es == null:
		return false
	var inst: Variant = es.new()
	if not (inst is Node):
		return _load_fail(str(m["entry"]), "the entry script must extend Node")
	entry = inst
	entry.name = "Entry"
	for need: String in ["_pack_setup", "_pack_start"]:
		if not entry.has_method(need):
			entry.free()
			entry = null
			return _load_fail(str(m["entry"]), "the entry script has no %s()" % need)
	_has_tick = entry.has_method("_pack_tick")
	ctx._entry = entry
	pack_node.add_child(entry)
	_guard_begin("_pack_setup", SETUP_LIMIT_MS)
	entry.call("_pack_setup", ctx)
	_guard_end()
	TLLaws.apply_tree(pack_node)
	if not ctx.headless:
		TLStandin.install_default_ground(self, ctx.root)   # WP5: a pack with no kit ground still gets a floor (visual only)
	_find_idle_scripts(pack_node)

	if mode == "bot" or (mode == "capture" and opts.has("test")):
		var test: String = str(opts.get("test", ""))
		if not (m["tests"] as Array).has(test):
			return _load_fail(test, "--test must be one of the manifest's tests: %s" % ", ".join(PackedStringArray(m["tests"])))
		var bs: GDScript = _load_script(test)
		if bs == null:
			return false
		var binst: Variant = bs.new()
		if not (binst is Node):
			return _load_fail(test, "a bot script must extend Node")
		bot = binst
		bot.name = "Bot"
		for need: String in ["_bot_setup", "_bot_tick", "_bot_done", "_bot_result"]:
			if not bot.has_method(need):
				bot.free()
				bot = null
				return _load_fail(test, "the bot script has no %s()" % need)
		add_child(bot)
		_guard_begin("_bot_setup", SETUP_LIMIT_MS)
		bot.call("_bot_setup", ctx)
		_guard_end()
	return true


## WP5. A pack script on a node in the tree that defines `_process` or `_physics_process` while the node is not
## processing never runs: the usual cause is `set_script` after `add_child` (the engine switches processing on only
## when a node becomes ready). It fails nothing; the supervisor shows it in the `smoke.loads` detail.
func _find_idle_scripts(n: Node) -> void:
	var sc: Script = n.get_script() as Script
	if sc is GDScript and n != entry and n.is_inside_tree() and sc.resource_path.begins_with(pack_dir) and warnings.size() < 8:
		var idle: PackedStringArray = PackedStringArray()
		if _script_has(sc as GDScript, "_physics_process") and not n.is_physics_processing():
			idle.append("_physics_process")
		if _script_has(sc as GDScript, "_process") and not n.is_processing():
			idle.append("_process")
		if not idle.is_empty():
			var text: String = "%s on node '%s' never runs (%s is off): call set_script before add_child, or do the work in _pack_tick" % [
				sc.resource_path.trim_prefix(pack_dir).trim_prefix("/"), str(pack_node.get_path_to(n)), ", ".join(idle)]
			warnings.append(text)
			print("[tl] warning: " + text)
	for c: Node in n.get_children():
		_find_idle_scripts(c)


func _load_script(rel: String) -> GDScript:
	var full: String = pack_dir + "/" + rel
	if not FileAccess.file_exists(full):
		_load_fail(rel, "file not found")
		return null
	var s: GDScript = load(full) as GDScript
	if s == null or not s.can_instantiate():
		_load_fail(rel, "the script did not load (parse error; see the script_error entries)")
		return null
	return s


func _script_has(s: GDScript, method: String) -> bool:
	for mi: Dictionary in s.get_script_method_list():
		if mi["name"] == method:
			return true
	return false


func _on_node_added(n: Node) -> void:
	if n is CollisionObject3D and n.has_meta(&"tl_material") and not n.has_meta(&"tl_law_applied") and pack_node != null \
			and pack_node.is_ancestor_of(n):
		TLLaws.apply(n as CollisionObject3D)


# ------------------------------------------------------------------------------------------------------ frames
func _physics_process(_delta: float) -> void:
	if finished:
		return
	var now: int = Time.get_ticks_usec()
	if started:
		frame_usec.append(now - _last_frame_usec)   # the whole previous iteration: scripts + physics step
	_last_frame_usec = now
	if not started:
		started = true
		_guard_begin("_pack_start", SETUP_LIMIT_MS)
		entry.call("_pack_start")
		_guard_end()
	if mode == "play" and Input.is_physical_key_pressed(KEY_ESCAPE):
		_end_run()
		return
	if frame >= frames_target:
		if mode == "bot":
			# contracts/RUNNER.md (amended 2026-11-10): a bot that is not done within its frame budget is a failed
			# check (exit 1), not a watchdog stop: collect what it has and end the run normally.
			_collect_bot(false)
			_end_run()
		elif mode == "capture":
			finished = true
			_capture()
		else:
			_end_run()
		return
	ctx.frame = frame
	logger.set("frame", frame)
	if bot != null:
		_guard_begin("_bot_tick", TICK_LIMIT_MS)
		bot.call("_bot_tick", frame)
		if not _guard_end():
			return
	ctx.input._sample()
	if _has_tick:
		_guard_begin("_pack_tick", TICK_LIMIT_MS)
		entry.call("_pack_tick", frame)
		if not _guard_end():
			return
	if logger.call("total_errors") > MAX_ERRORS:
		_trip("script_errors", "more than %d errors; stopped at frame %d" % [MAX_ERRORS, frame])
		return
	if frame % CENSUS_EVERY == 0:
		if not _census():
			return
	if frame % HASH_TRACE_EVERY == 0:
		hash_trace.append([frame, _state_hash().substr(0, 16)])
	if bot != null and mode == "bot" and bool(bot.call("_bot_done")):
		_collect_bot(true)
		frame += 1
		_end_run()
		return
	frame += 1


func _collect_bot(done: bool) -> void:
	bot_info = {"test": str(opts.get("test", "")), "done": done, "frames": frame + (1 if done else 0)}
	_guard_begin("_bot_result", SETUP_LIMIT_MS)
	var r: Variant = bot.call("_bot_result")
	_guard_end()
	if typeof(r) == TYPE_DICTIONARY and typeof((r as Dictionary).get("ok")) == TYPE_BOOL and typeof((r as Dictionary).get("summary")) == TYPE_STRING:
		bot_info["result"] = _plain(r)
	else:
		bot_info["result"] = {"ok": false, "summary": "_bot_result() did not return {ok: bool, summary: String}"}
		load_errors.append({"kind": "bot", "file": str(opts.get("test", "")), "message": "_bot_result() must return a Dictionary with ok (bool) and summary (String)"})


## Counts nodes and bodies, looks for bodies below the ground budget, applies laws to bodies tagged late.
func _census() -> bool:
	var counts: Array = [0, 0]
	_census_node(pack_node, counts)
	entities_max = maxi(entities_max, int(counts[0]))
	bodies_max = maxi(bodies_max, int(counts[1]))
	if int(counts[0]) > HARD_NODE_CAP:
		_trip("entity_runaway", "%d nodes under the pack at frame %d" % [int(counts[0]), frame])
		return false
	if frame % 60 == 0 and OS.get_static_memory_usage() > HARD_MEMORY_CAP:
		_trip("memory", "%d MB of static memory at frame %d" % [OS.get_static_memory_usage() / 1048576, frame])
		return false
	return true


func _census_node(n: Node, counts: Array) -> void:
	counts[0] = int(counts[0]) + 1
	if n is PhysicsBody3D:
		counts[1] = int(counts[1]) + 1
		var y: float = (n as PhysicsBody3D).global_position.y
		if y < BELOW_Y:
			below_count += 1
			if below.is_empty():
				below = {"node": str(pack_node.get_path_to(n)), "frame": frame, "y": snappedf(y, 0.01)}
		if n.has_meta(&"tl_material") and not n.has_meta(&"tl_law_applied"):
			TLLaws.apply(n as CollisionObject3D)
	for c: Node in n.get_children():
		_census_node(c, counts)


# ------------------------------------------------------------------------------------------------------ hashing
func _q(v: float) -> int:
	return int(round(v * 1000.0))


func _put_v3(buf: StreamPeerBuffer, v: Vector3) -> void:
	buf.put_64(_q(v.x))
	buf.put_64(_q(v.y))
	buf.put_64(_q(v.z))


func _hash_node(n: Node, buf: StreamPeerBuffer) -> void:
	if n is PhysicsBody3D:
		var t: Transform3D = (n as PhysicsBody3D).global_transform
		_put_v3(buf, t.origin)
		var qt: Quaternion = t.basis.orthonormalized().get_rotation_quaternion()
		if qt.w < 0.0:
			qt = -qt
		buf.put_64(_q(qt.x))
		buf.put_64(_q(qt.y))
		buf.put_64(_q(qt.z))
		buf.put_64(_q(qt.w))
		if n is RigidBody3D:
			_put_v3(buf, (n as RigidBody3D).linear_velocity)
			_put_v3(buf, (n as RigidBody3D).angular_velocity)
		elif n is CharacterBody3D:
			_put_v3(buf, (n as CharacterBody3D).velocity)
	for c: Node in n.get_children():
		_hash_node(c, buf)


## SHA-256 over every physics body under the pack (position, rotation, velocities; quantised to 0.001) in tree
## order, followed by the canonical form of entry._pack_state().
func _state_hash() -> String:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	if pack_node != null:
		_hash_node(pack_node, buf)
	if entry != null and entry.has_method("_pack_state"):
		buf.put_data(_canon(entry.call("_pack_state")).to_utf8_buffer())
	var hc: HashingContext = HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	if buf.get_size() > 0:
		hc.update(buf.data_array)
	return hc.finish().hex_encode()


static func _canon(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return "%.4f" % float(v)
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return "\"" + str(v) + "\""
		TYPE_VECTOR2:
			return "[%.4f,%.4f]" % [v.x, v.y]
		TYPE_VECTOR3:
			return "[%.4f,%.4f,%.4f]" % [v.x, v.y, v.z]
		TYPE_DICTIONARY:
			var keys: Array = []
			for k: Variant in (v as Dictionary).keys():
				keys.append(str(k))
			keys.sort()
			var by_name: Dictionary = {}
			for k: Variant in (v as Dictionary).keys():
				by_name[str(k)] = (v as Dictionary)[k]
			var parts: PackedStringArray = PackedStringArray()
			for k: String in keys:
				parts.append("\"" + k + "\":" + _canon(by_name[k]))
			return "{" + ",".join(parts) + "}"
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			var items: PackedStringArray = PackedStringArray()
			for item: Variant in v:
				items.append(_canon(item))
			return "[" + ",".join(items) + "]"
	return "\"<" + type_string(typeof(v)) + ">\""


## A JSON-safe copy of a pack-provided value (vectors become arrays, objects become their type name).
static func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return v
		TYPE_FLOAT:
			return snappedf(float(v), 0.0001)
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(v)
		TYPE_VECTOR2:
			return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001)]
		TYPE_VECTOR3:
			return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k: Variant in (v as Dictionary).keys():
				d[str(k)] = _plain((v as Dictionary)[k])
			return d
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			var a: Array = []
			for item: Variant in v:
				a.append(_plain(item))
			return a
	return "<" + type_string(typeof(v)) + ">"


# ------------------------------------------------------------------------------------------------------ capture
func _capture() -> void:
	var cam_name: String = str(opts.get("cam", ""))
	var out: String = str(opts.get("out", ""))
	if ctx.headless:
		load_errors.append({"kind": "engine", "file": "", "message": "capture needs a window (the worker was started headless)"})
	elif not ctx.cameras.has_view(cam_name):
		load_errors.append({"kind": "load", "file": str(ctx.manifest["entry"]),
			"message": "no camera view '%s'; the pack registered: %s" % [cam_name, ", ".join(ctx.cameras.views())]})
	else:
		ctx.cameras.activate(cam_name)
		TLHud.hide_all()                # captures are of the world, without the HUD
		get_tree().paused = true        # freeze the sim at exactly this physics frame while the image is drawn
		for i: int in 3:
			await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var err: Error = img.save_png(out)
		if err != OK:
			load_errors.append({"kind": "engine", "file": out, "message": "could not write the image (error %d)" % err})
		else:
			capture_info = {"cam": cam_name, "frame": frame, "file": out, "width": img.get_width(), "height": img.get_height()}
		get_tree().paused = false
	_end_run()


# ------------------------------------------------------------------------------------------------------ watchdog
func _guard_begin(phase: String, limit_ms: int) -> void:
	_wd_mutex.lock()
	_wd_phase = phase
	_wd_limit = limit_ms * 1000
	_wd_frame = frame if started else -1
	_wd_start = Time.get_ticks_usec()
	_wd_mutex.unlock()


## False when the call ran over its limit (the run is being stopped).
func _guard_end() -> bool:
	var now: int = Time.get_ticks_usec()
	_wd_mutex.lock()
	var elapsed: int = now - _wd_start
	var limit: int = _wd_limit
	var phase: String = _wd_phase
	var tripped: bool = _wd_tripped
	_wd_start = 0
	_wd_mutex.unlock()
	if tripped:
		while true:                    # the watchdog thread is writing the result and ending the process
			OS.delay_msec(50)
	if phase.ends_with("_tick"):
		tick_ms_max = maxf(tick_ms_max, float(elapsed) / 1000.0)
	if elapsed > limit:
		_trip("tick_timeout", "%s took %d ms (limit %d ms)" % [phase, elapsed / 1000, limit / 1000], phase)
		return false
	return true


func _wd_run() -> void:
	var alive: String = str(opts.get("alive", ""))
	var beats: int = 0
	while true:
		OS.delay_msec(20)
		beats += 1
		if not alive.is_empty() and beats % 250 == 0:
			# the supervisor rewrites this file every few seconds while it lives. Gone or a minute stale means the
			# supervisor was killed by its caller: do not linger as an orphan. (Housekeeping, not a check.)
			if not FileAccess.file_exists(alive) or Time.get_unix_time_from_system() - float(FileAccess.get_modified_time(alive)) > ORPHAN_AFTER_S:
				OS.kill(OS.get_process_id())
				return
		_wd_mutex.lock()
		var stop: bool = _wd_stop
		var over: bool = _wd_start != 0 and Time.get_ticks_usec() - _wd_start > _wd_limit
		var phase: String = _wd_phase
		var limit: int = _wd_limit
		var at_frame: int = _wd_frame
		if over:
			_wd_tripped = true
		_wd_mutex.unlock()
		if stop:
			return
		if over:
			# the main thread is stuck inside pack code: write the result from here and end the process
			var res: Dictionary = {"loaded": at_frame >= 0, "frames_run": maxi(at_frame, 0), "load_errors": [],
				"watchdog": {"reason": "tick_timeout", "phase": phase, "frame": at_frame,
					"detail": "%s did not return within %d ms (runaway script); the process was stopped" % [phase, limit / 1000]}}
			res.merge(logger.call("snapshot"))
			_store(res)
			OS.kill(OS.get_process_id())
			return


func _trip(reason: String, detail: String, phase: String = "") -> void:
	if not watchdog.is_empty():
		return
	watchdog = {"reason": reason, "frame": frame, "detail": detail}
	if not phase.is_empty():
		watchdog["phase"] = phase
	_end_run()


# ------------------------------------------------------------------------------------------------------ result
func _store(res: Dictionary) -> void:
	if result_path.is_empty():
		return
	var f: FileAccess = FileAccess.open(result_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(res, "", false))
		f.close()


func _percentile(sorted: PackedInt64Array, p: float) -> float:
	if sorted.is_empty():
		return 0.0
	var idx: int = clampi(int(ceil(p * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return snappedf(float(sorted[idx]) / 1000.0, 0.001)


func _end_run() -> void:
	finished = true
	set_physics_process(false)
	var state_hash: String = ""
	var pack_state: Variant = null
	if loaded:
		_census()
		state_hash = _state_hash()
		if entry != null and entry.has_method("_pack_state"):
			pack_state = _plain(entry.call("_pack_state"))
		if entry != null and entry.has_method("_pack_teardown"):
			_guard_begin("_pack_teardown", SETUP_LIMIT_MS)
			entry.call("_pack_teardown")
			_guard_end()
	var sorted: PackedInt64Array = frame_usec.duplicate()
	sorted.sort()
	var res: Dictionary = {"loaded": loaded, "frames_run": frame, "load_errors": load_errors}
	if not watchdog.is_empty():
		res["watchdog"] = watchdog
	res.merge(logger.call("snapshot"))
	var metrics: Dictionary = {}
	if loaded:
		metrics = {"state_hash": state_hash, "frame_ms_p50": _percentile(sorted, 0.5), "frame_ms_p99": _percentile(sorted, 0.99),
			"entities_max": entities_max, "bodies_max": bodies_max, "tick_ms_max": snappedf(tick_ms_max, 0.001)}
	res["metrics"] = metrics
	res["hash_trace"] = hash_trace
	if not warnings.is_empty():
		res["warnings"] = warnings
	res["below_count"] = below_count
	if not below.is_empty():
		res["below"] = below
	if pack_state != null:
		res["pack_state"] = pack_state
	if not bot_info.is_empty():
		res["bot"] = bot_info
	if not capture_info.is_empty():
		res["capture"] = capture_info
	_store(res)
	_wd_mutex.lock()
	_wd_stop = true
	_wd_mutex.unlock()
	_wd_thread.wait_to_finish()
	print("[tl] worker done: mode=%s frames=%d" % [mode, frame])
	get_tree().quit(0)
