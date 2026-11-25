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
const CpuClock: GDScript = preload("res://kernel/host/cpuclock.gd")
const StateHash: GDScript = preload("res://kernel/host/statehash.gd")
const Session: GDScript = preload("res://kernel/runner/session.gd")   # P7: the input record (tl.input/1), replay, --devices
const PackLife = preload("res://kernel/runner/pack_life.gd")   # the lifecycle this worker shares with a world's holder
const Trace: GDScript = preload("res://kernel/runner/trace.gd")   # the hash trace, and the determinism locator's stops

const TICK_LIMIT_MS: int = 250          # RUNNER.md: one _pack_tick or _bot_tick
const SETUP_LIMIT_MS: int = 10000       # kernel addition: generators, _pack_setup, _pack_start, _bot_setup, teardown
const MAX_ERRORS: int = 20              # RUNNER.md: more than this trips the watchdog
const HARD_NODE_CAP: int = 50000        # runaway spawning (ten times the V3 budget)
const HARD_MEMORY_CAP: int = 4 * 1024 * 1024 * 1024
const CENSUS_EVERY: int = 10
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
var life: PackLife                       # the pack's lifecycle (runner/pack_life.gd): context, load, frame, census, verdict
var hash_trace: Array = []
var trace: RefCounted                    # runner/trace.gd: samples hash_trace; host/diverge.gd may stop the run at a frame
var frame_usec: PackedInt64Array = PackedInt64Array()
var tick_ms_max: float = 0.0
var _last_frame_usec: int = 0

var _wd_thread: Thread
var _wd_mutex: Mutex = Mutex.new()
var _wd_start: int = 0
var _wd_limit: int = 0
var _wd_phase: String = ""
var _wd_frame: int = -1
var _wd_stop: bool = false
var _wd_tripped: bool = false
var cpu: RefCounted                      # P1: processor time of this process (kernel/host/cpuclock.gd)
var session: RefCounted                  # P7: this run's input record, kept or fed back (kernel/runner/session.gd)
var _cut: bool = false                   # the run ended inside its last frame, before the physics step (a bot that was done)
var strip_count: int = 0                 # L1 21 Nov: capture --strip=<count>x<step>; 0 = a still
var strip_step: int = 0
var strip_at: int = 0                    # the first strip frame (--frame); the run goes on to its last one
var strip_images: Array[Image] = []
var _grabbing: bool = false              # a strip image is being drawn (the tree is paused): this node does not tick


func start(options: Dictionary) -> void:
	opts = options
	mode = str(opts.get("mode", "smoke"))
	result_path = str(opts.get("result", ""))
	pack_dir = Manifest.resolve_dir(str(opts.get("pack", "")))
	if str(opts.get("mode", "smoke")) == "play" and not pack_dir.is_empty():
		var fence_errors: Array = (load("res://kernel/runner/lint.gd") as GDScript).run(pack_dir)["errors"]
		if not fence_errors.is_empty():
			print("[tl] play refused: lint did not pass (%d finding(s)); first: %s" % [fence_errors.size(), str(fence_errors[0])])
			get_tree().quit(1)
			return
	frames_target = int(opts.get("frames", 3600))
	if mode == "play":
		frames_target = int(opts.get("frames", 1 << 40))   # interactive: until Esc or the window closes (--frames: a scripted session)
	if mode == "capture" and not str(opts.get("strip", "")).is_empty():   # the host checked the text (2..16 x 1..60)
		strip_count = str(opts["strip"]).get_slice("x", 0).to_int()
		strip_step = str(opts["strip"]).get_slice("x", 1).to_int()
		strip_at = frames_target
		frames_target += strip_step * (strip_count - 1)
	trace = Trace.new(opts)
	session = Session.new()
	session.call("begin", self)        # P7: --record, --input (mode replay: seed and length come from the record), --devices
	print("[tl] worker start: mode=%s" % mode)
	process_physics_priority = -100000
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(false)
	logger = LoggerScript.new()
	logger.pack_dir = pack_dir
	OS.add_logger(logger)
	cpu = CpuClock.new()
	cpu.call("start", OS.get_process_id())
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
	life = PackLife.new()
	life.load_errors = load_errors
	life.warnings = warnings
	life.on_begin = func(phase: String) -> void: _guard_begin(phase, TICK_LIMIT_MS if phase.ends_with("_tick") else SETUP_LIMIT_MS)
	life.on_end = func(_phase: String) -> bool: return _guard_end()
	ctx = life.make_context(self, m, pack_dir, int(opts.get("seed", 1)), frames_target, mode)
	TLContext.current = ctx        # one pack in this process: it stays "the pack being called" for the whole run
	pack_node = life.make_scene()
	life.make_io(mode == "play")
	if not bool(session.call("attach", ctx)):
		return false
	TLStandin.prepare_style(ctx.headless)
	if not ctx.headless:
		TLStandin.install_look(self)
	get_tree().node_added.connect(_on_node_added)
	if not life.load_entry():
		return false
	entry = life.entry
	if not ctx.headless:
		TLStandin.install_default_ground(self, ctx.root)   # WP5: a pack with no kit ground still gets a floor (visual only)
	life.find_idle_scripts()
	if mode == "bot" or (mode == "capture" and opts.has("test")):
		if not life.load_bot(str(opts.get("test", ""))):
			return false
		bot = life.bot
	return true


func _on_node_added(n: Node) -> void:
	life.mute_if_pack(n)           # P7: a pack script's own event handlers would read a device past the input record
	if n is CollisionObject3D and n.has_meta(&"tl_material") and not n.has_meta(&"tl_law_applied") and pack_node != null \
			and pack_node.is_ancestor_of(n):
		TLLaws.apply(n as CollisionObject3D)


## P7: a person who closes the window ends the session as Esc does, so that its record (--record) is still written.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and mode == "play" and loaded and not finished:
		_end_run()


# ------------------------------------------------------------------------------------------------------ frames
func _physics_process(_delta: float) -> void:
	if finished or _grabbing:            # PROCESS_MODE_ALWAYS: called while a strip image is drawn in a paused tree
		return
	var now: int = Time.get_ticks_usec()
	if started:
		frame_usec.append(now - _last_frame_usec)   # the whole previous iteration: scripts + physics step
	_last_frame_usec = now
	if not started:
		started = true
		life.start()
	if strip_count > 0 and frame < frames_target and frame >= strip_at and (frame - strip_at) % strip_step == 0 \
			and strip_images.size() == (frame - strip_at) / strip_step:
		_strip_grab()                  # frame `frame` is ticked on the next call, once the image is drawn
		return
	if mode == "play" and bool(session.call("ends_now")):     # Esc, unless the designer panel is open (ui/PATCHES.md 2)
		_end_run()
		return
	# H2b (25 Nov): a still with the HUD on sees its camera from the frame before the grab, so the pack's HUD projects its marks
	# on the ice through that camera (the rink base drew its rings for "follow", then the image came through "top": an ellipse)
	if mode == "capture" and strip_count == 0 and frame == frames_target - 1 and str(opts.get("hud", "off")) == "on" and ctx.cameras.has_view(str(opts.get("cam", ""))):
		ctx.cameras.activate(str(opts.get("cam", "")))
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
	logger.set("frame", frame)
	if not life.tick(frame, true, _pre_sample):       # a call over its limit, or a scripted "close" ended the run
		return
	if logger.call("total_errors") > MAX_ERRORS:
		_trip("script_errors", "more than %d errors; stopped at frame %d" % [MAX_ERRORS, frame])
		return
	if frame % CENSUS_EVERY == 0:
		if not _census():
			return
	if not bool(trace.call("sample", frame, life, hash_trace)):   # only a located re-run (host/diverge.gd) stops here
		_end_run()
		return
	var bot_done: bool = life.bot_done(mode == "bot")
	if bot_done or frame == int(session.get("cut_frame")):      # P7: a replay of such a run stops inside the same frame
		if bot_done:
			_collect_bot(true)
		_cut = true
		frame += 1
		_end_run()
		return
	frame += 1


## P7: the input session's turn inside the frame (after the bot, before the input latches). False: it ended the run.
func _pre_sample(f: int) -> bool:
	session.call("pre_sample", f)
	return not finished


func _collect_bot(done: bool) -> void:
	bot_info = {"test": str(opts.get("test", "")), "done": done, "frames": frame + (1 if done else 0)}
	bot_info["result"] = life.bot_result()


## The census of the shared core, then this process's own limits: runaway spawning and memory trip the watchdog.
func _census() -> bool:
	var counts: Array = life.census(frame)
	if int(counts[0]) > HARD_NODE_CAP:
		_trip("entity_runaway", "%d nodes under the pack at frame %d" % [int(counts[0]), frame])
		return false
	if frame % 60 == 0 and OS.get_static_memory_usage() > HARD_MEMORY_CAP:
		_trip("memory", "%d MB of static memory at frame %d" % [OS.get_static_memory_usage() / 1048576, frame])
		return false
	return true


# ------------------------------------------------------------------------------------------------------ hashing
## SHA-256 over every physics body under the pack, the canonical form of entry._pack_state(), the seeded generator and
## the input state (kernel/host/statehash.gd, through runner/pack_life.gd).
func _state_hash() -> String:
	return life.state_hash()


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
		var img: Image = await _grab(cam_name)
		if strip_count > 0:
			strip_images.append(img)
			img = _strip_tile()
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var err: Error = img.save_png(out)
		if err != OK:
			load_errors.append({"kind": "engine", "file": out, "message": "could not write the image (error %d)" % err})
		else:
			capture_info = {"cam": cam_name, "frame": strip_at if strip_count > 0 else frame, "file": out,
				"width": img.get_width(), "height": img.get_height()}
	_end_run()


## The view at this physics frame: the tree is paused (no physics step) while the image is drawn. The pack, its input,
## cameras and bot are children of this PROCESS_MODE_ALWAYS node, so they inherit ALWAYS and a paused tree alone does
## not stop their _physics_process: a strip, whose run goes on, makes this node pausable for the grab so that nothing
## of the pack runs. A still keeps the drawing it always had (its run ends here).
func _grab(cam_name: String) -> Image:
	ctx.cameras.activate(cam_name)
	if str(opts.get("hud", "off")) != "on": TLHud.hide_all(ctx)    # captures are of the world, without the HUD (K2: --hud=on keeps it)
	if strip_count > 0:
		process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true        # freeze the sim at exactly this physics frame while the image is drawn
	for i: int in 3:
		await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	return img


## L1 21 Nov: one strip image before frame `frame` is ticked; the run goes on afterwards. A view that cannot be drawn
## (headless, no such camera) ends the run as a still would.
func _strip_grab() -> void:
	if ctx.headless or not ctx.cameras.has_view(str(opts.get("cam", ""))):
		finished = true
		_capture()
		return
	_grabbing = true
	strip_images.append(await _grab(str(opts.get("cam", ""))))
	_last_frame_usec = Time.get_ticks_usec()   # the drawing is not the frame's time
	_grabbing = false


## The strip images at half size, row-major in 4 columns (fewer when there are fewer images).
func _strip_tile() -> Image:
	var tw: int = strip_images[0].get_width() / 2
	var th: int = strip_images[0].get_height() / 2
	var cols: int = mini(4, strip_images.size())
	var fmt: Image.Format = strip_images[0].get_format()
	var tile: Image = Image.create_empty(tw * cols, th * ceili(strip_images.size() / float(cols)), false, fmt)
	tile.fill(Color.BLACK)
	for i: int in strip_images.size():
		var im: Image = strip_images[i]
		if im.get_format() != fmt:
			im.convert(fmt)
		im.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		tile.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	strip_images.clear()
	return tile


# ------------------------------------------------------------------------------------------------------ watchdog
func _guard_begin(phase: String, limit_ms: int) -> void:
	_wd_mutex.lock()
	_wd_phase = phase
	_wd_limit = limit_ms * 1000
	_wd_frame = frame if started else -1
	_wd_start = Time.get_ticks_usec()
	_wd_mutex.unlock()


## False when the call ran over its limit (the run is being stopped). P1: the limit counts processor time; a call that ran
## over it in wall time only was starved by the machine: noted in cpu.stalls, the run goes on.
func _guard_end() -> bool:
	var now: int = Time.get_ticks_usec()
	_wd_mutex.lock()
	var started_at: int = _wd_start
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
		var used: float = float(cpu.call("used_ms", started_at, now))
		var wall_ms: float = float(elapsed) / 1000.0
		if used >= 0.0 and used * 1000.0 < float(limit):
			cpu.call("note_stall", phase, frame if started else -1, wall_ms, used)
			return true
		if used < 0.0 and not bool(cpu.get("gave_up")):
			cpu.call("note_stall", phase, frame if started else -1, wall_ms, -1.0)      # the helper is still starting: no judgement yet
			return true
		_trip("tick_timeout", "%s took %d ms (limit %d ms)%s" % [phase, elapsed / 1000, limit / 1000,
			(", %d ms of it processor time" % int(used)) if used >= 0.0 else " of wall time (no process-time source on this machine)"], phase)
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
				cpu.call("stop")
				OS.kill(OS.get_process_id())
				return
		_wd_mutex.lock()
		var stop: bool = _wd_stop
		var g_start: int = _wd_start
		var phase: String = _wd_phase
		var limit: int = _wd_limit
		var at_frame: int = _wd_frame
		_wd_mutex.unlock()
		if stop:
			return
		var now: int = Time.get_ticks_usec()
		var v: Dictionary = cpu.call("verdict", g_start, now, limit, phase) if g_start != 0 else {}   # P1: processor time decides (cpuclock.gd)
		if v.is_empty():
			continue
		var reason: String = str(v["reason"])
		var used: float = float(v["used"])
		var detail: String = str(v["detail"])
		var wall: int = now - g_start
		_wd_mutex.lock()
		if _wd_start == g_start:
			_wd_tripped = true       # the main thread is still inside the call: it has not returned
		else:
			reason = ""              # the call returned meanwhile
		_wd_mutex.unlock()
		if reason.is_empty():
			continue
		# the main thread is stuck inside pack code: write the result from here and end the process
		var wd: Dictionary = {"reason": reason, "phase": phase, "frame": at_frame, "detail": detail, "wall_ms": wall / 1000}
		if used >= 0.0:
			wd["cpu_ms"] = int(used)
		var res: Dictionary = {"loaded": at_frame >= 0, "frames_run": maxi(at_frame, 0), "load_errors": [], "watchdog": wd}
		res.merge(logger.call("snapshot"))
		_store(res)
		cpu.call("stop")
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
	var parts: Dictionary = {}       # P7: the hash by what it covers, for the day two runs differ (result file only)
	if loaded:
		_census()
		state_hash = _state_hash()
		parts = {"bodies_and_state": life.state_hash(true).substr(0, 16),
			"rng_state": str(ctx.rng.state), "input_frames": int(ctx.input.get("_ticks"))}
		pack_state = life.pack_state()
		life.teardown()
	var sorted: PackedInt64Array = frame_usec.duplicate()
	sorted.sort()
	var res: Dictionary = {"loaded": loaded, "frames_run": frame, "load_errors": load_errors}
	if not watchdog.is_empty():
		res["watchdog"] = watchdog
	res.merge(logger.call("snapshot"))
	var metrics: Dictionary = {}
	if loaded:
		metrics = {"state_hash": state_hash, "frame_ms_p50": _percentile(sorted, 0.5), "frame_ms_p99": _percentile(sorted, 0.99),
			"entities_max": life.entities_max, "bodies_max": life.bodies_max, "tick_ms_max": snappedf(tick_ms_max, 0.001)}
	res["metrics"] = metrics
	var starved: Dictionary = cpu.call("starved_summary")
	if not starved.is_empty():
		res["starved"] = starved
	if opts.has("series"):         # P1: every frame's time, for the supervisor's best-of-runs budget
		res["frame_us"] = Array(frame_usec)
	res["hash_trace"] = hash_trace
	if not parts.is_empty():
		res["hash_parts"] = parts
	if not (trace.get("found") as Dictionary).is_empty():
		res["diverge"] = trace.get("found")
	if not warnings.is_empty():
		res["warnings"] = warnings
	res["below_count"] = life.below_count if life != null else 0
	if life != null and not life.below.is_empty():
		res["below"] = life.below
	if pack_state != null:
		res["pack_state"] = pack_state
	if not bot_info.is_empty():
		res["bot"] = bot_info
	if not capture_info.is_empty():
		res["capture"] = capture_info
	var rec_info: Dictionary = session.call("finish", frame, _cut) if loaded else {}
	if not rec_info.is_empty():
		res["record"] = rec_info
	_store(res)
	_wd_mutex.lock()
	_wd_stop = true
	_wd_mutex.unlock()
	_wd_thread.wait_to_finish()
	cpu.call("stop")
	print("[tl] worker done: mode=%s frames=%d" % [mode, frame])
	get_tree().quit(0)
