extends "res://kernel/runner/worker.gd"
## P8 spike, the comparison: the same pack in ONE process (the unchanged worker), measured with the same instruments
## as the two-process run: processor time per frame, the frame period, and the key-to-picture delay.
##
##   --latency=<n> --key=right,left --watch=Paddle_player   n presses, each timed from the physics tick that sets the
##                                                          key to the drawn frame in which the watched node moved

const Wire: GDScript = preload("res://kernel/proc/proc_wire.gd")

var _cpu0: float = -1.0
var _frames0: int = 0
var _t0_usec: int = 0
var _period_us: Array = []
var _last_process_usec: int = 0
var _ended: bool = false
var _ready_ms: int = 0              # engine start to "pack loaded"
var _lat_n: int = 0
var _lat_keys: PackedStringArray = PackedStringArray()
var _lat_watch: Node3D = null
var _lat_clock: int = 0
var _lat_armed: bool = false
var _lat_key_frame: int = 0
var _lat_key_usec: int = 0
var _lat_p0: Vector3 = Vector3.ZERO
var _lat_frames: Array = []
var _lat_ms: Array = []
var _lat_held: String = ""


func start(options: Dictionary) -> void:
	super.start(options)
	if not loaded:
		return
	_lat_n = int(options.get("latency", 0))
	_lat_keys = str(options.get("key", "right,left")).split(",")
	if _lat_n > 0:
		_lat_watch = pack_node.find_child(str(options.get("watch", "Paddle_player")), true, false) as Node3D
	_ready_ms = Time.get_ticks_msec()
	set_process(true)


func _physics_process(delta: float) -> void:
	if finished:
		return
	if _cpu0 < 0.0:
		cpu.call("wait_settled")
		_cpu0 = float(cpu.call("_read"))
		_frames0 = Engine.get_process_frames()
		_t0_usec = Time.get_ticks_usec()
	if _lat_n > 0 and _lat_watch != null:
		_lat_clock += 1
		var phase: int = _lat_clock % 90
		if phase == 30 and _lat_frames.size() < _lat_n and not _lat_armed:
			_lat_held = _lat_keys[_lat_frames.size() % _lat_keys.size()]
			ctx.input.press(StringName(_lat_held))
			_lat_armed = true
			_lat_key_frame = Engine.get_process_frames()
			_lat_key_usec = Time.get_ticks_usec()
			_lat_p0 = _lat_watch.position
		elif phase == 50 and not _lat_held.is_empty():
			ctx.input.release(StringName(_lat_held))
			_lat_held = ""
		if _lat_frames.size() >= _lat_n and _lat_held.is_empty():
			_end_run()
			return
	super._physics_process(delta)


func _process(_delta: float) -> void:
	if finished:
		return
	var now: int = Time.get_ticks_usec()
	if _last_process_usec > 0:
		_period_us.append(now - _last_process_usec)
	_last_process_usec = now
	if _lat_armed and _lat_watch != null and _lat_watch.position.distance_to(_lat_p0) > 0.0001:
		_lat_armed = false
		_lat_frames.append(Engine.get_process_frames() - _lat_key_frame)
		_lat_ms.append(float(Time.get_ticks_usec() - _lat_key_usec) / 1000.0)


func _end_run() -> void:
	if _ended:
		return
	_ended = true
	var fig: Dictionary = {"proc": 1, "role": "solo", "mem_peak_mb": snappedf(float(OS.get_static_memory_peak_usage()) / 1048576.0, 0.1), "ready_ms": _ready_ms, "pack": ctx.pack_id if ctx != null else "", "mode": mode, "frames": frame,
		"window": DisplayServer.get_name() != "headless"}
	if loaded:
		fig["state_hash"] = _state_hash()
		var sorted: PackedInt64Array = frame_usec.duplicate()
		sorted.sort()
		fig["frame_ms"] = {"p50": _percentile(sorted, 0.5), "p99": _percentile(sorted, 0.99)}
		fig["frame_period_ms"] = {"p50": float(Wire.call("pct", _period_us, 0.5)) / 1000.0, "p99": float(Wire.call("pct", _period_us, 0.99)) / 1000.0,
			"max": float(Wire.call("pct", _period_us, 1.0)) / 1000.0}
		var drawn: int = Engine.get_process_frames() - _frames0
		fig["frames_drawn"] = drawn
		if _cpu0 >= 0.0 and frame > 0:
			var used: float = float(cpu.call("_read")) - _cpu0
			fig["cpu_ms_per_frame"] = Wire.call("r3", used / float(frame))
			fig["wall_ms_per_frame"] = Wire.call("r3", float(Time.get_ticks_usec() - _t0_usec) / 1000.0 / float(frame))
		if _lat_n > 0:
			fig["key_to_picture"] = {"samples": _lat_frames.size(), "frames": _lat_frames, "frames_mean": Wire.call("r3", Wire.call("mean", _lat_frames)),
				"ms_mean": Wire.call("r3", Wire.call("mean", _lat_ms)), "ms_max": Wire.call("pct", _lat_ms, 1.0), "watch_found": _lat_watch != null}
	print(JSON.stringify(fig, "", false))
	super._end_run()
