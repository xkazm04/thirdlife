extends Node
## The host: the only door into the engine (contracts/RUNNER.md).
##
##   <godot> [--headless] --path <engine> res://kernel/host/host.tscn -- <verb> --pack=<dir> [options] --report=<file>
##
## This process is the SUPERVISOR. `lint` runs here (text only). Every verb that executes pack code starts a WORKER:
## the same executable and scene with `-- worker ...` (kernel/runner/worker.gd), one fresh process per run. Reasons:
##   * a runaway script cannot be interrupted from inside its own thread; the worker's watchdog thread writes the
##     result and ends the worker, and the supervisor still produces a report and exit code 3;
##   * script errors are caught twice: by a custom Logger inside the worker (file and line), and by the supervisor
##     reading the worker's engine log for "SCRIPT ERROR" lines the Logger could not have seen;
##   * `invariants` compares two runs that share nothing, not even a process.
## No global class name is used in this file, manifest.gd or lint.gd, so the supervisor works before the class cache
## exists; it refreshes the cache (`--import`) itself when kernel scripts are newer than it.

const Manifest: GDScript = preload("res://kernel/runner/manifest.gd")
const Lint: GDScript = preload("res://kernel/runner/lint.gd")

const LEVELS: Dictionary = {"lint": "V1", "smoke": "V2", "invariants": "V3", "bot": "V4", "capture": "V5"}
const OPTIONS: Dictionary = {
	"lint": ["pack", "report"],
	"smoke": ["pack", "report", "seed", "frames"],
	"invariants": ["pack", "report", "seed", "frames", "bot-frames"],   # --bot-frames: budget of the bot replays (WP5)
	"bot": ["pack", "report", "seed", "frames", "test"],
	"capture": ["pack", "report", "seed", "cam", "frame", "out", "res", "test"],   # --test: kernel extension, see API.md
}
const BUDGET_FRAME_MS_P99: float = 8.0
const BUDGET_NODES: int = 5000
const BUDGET_BODIES: int = 600
const RELAY_LINES: int = 120

var verb: String = ""
var opts: Dictionary = {}
var report: Dictionary = {}
var pack_dir: String = ""
var _t0: int = 0
var _runs: int = 0
var engine_start_crashes: int = 0
var _entry_file: String = ""
var _test_file: String = ""
var render_driver: String = "default"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var bad_args: PackedStringArray = PackedStringArray()
	for a: String in args:
		if a.begins_with("--"):
			var eq: int = a.find("=")
			if eq < 0:
				opts[a.substr(2)] = "true"
			else:
				opts[a.substr(2, eq - 2)] = a.substr(eq + 1)
		elif verb.is_empty():
			verb = a
		else:
			bad_args.append(a)
	if verb == "worker":
		var w: Node = (load("res://kernel/runner/worker.gd") as GDScript).new()
		w.name = "Worker"
		add_child(w)
		w.call("start", opts)
		return
	_t0 = Time.get_ticks_msec()
	_supervise(bad_args)


# ------------------------------------------------------------------------------------------------- supervisor
func _supervise(bad_args: PackedStringArray) -> void:
	report = {"schema": "tl.verify/1", "verb": verb, "level": str(LEVELS.get(verb, "V0")), "kernelApi": Manifest.KERNEL_API,
		"ok": false, "outcome": "not_run", "checks": [], "errors": []}
	if not LEVELS.has(verb):
		return _not_run("engine", "unknown verb '%s'; verbs: lint, smoke, invariants, bot, capture" % verb)
	if not bad_args.is_empty():
		return _not_run("engine", "unexpected argument(s): %s (options are --name=value)" % " ".join(bad_args))
	for k: String in opts.keys():
		if not (OPTIONS[verb] as Array).has(k):
			return _not_run("engine", "unknown option --%s for '%s' (allowed: %s)" % [k, verb, ", ".join(PackedStringArray(OPTIONS[verb]))])
	for k: String in ["seed", "frames", "frame", "bot-frames"]:
		if opts.has(k) and not str(opts[k]).is_valid_int():
			return _not_run("engine", "--%s must be an integer" % k)
	for k: String in ["report", "out", "pack"]:
		if opts.has(k):
			opts[k] = _win_path(str(opts[k]))
	if opts.has("report") and not str(opts["report"]).is_absolute_path():
		return _not_run("engine", "--report must be an absolute file path")
	if not opts.has("pack"):
		return _not_run("engine", "--pack=<dir> is required")
	pack_dir = Manifest.resolve_dir(str(opts["pack"]))
	if pack_dir.is_empty():
		return _not_run("load", "pack directory not found: %s" % str(opts["pack"]))

	if verb == "lint":
		var lr: Dictionary = Lint.run(pack_dir)
		_set_pack(lr["manifest"])
		report["checks"] = lr["checks"]
		report["errors"] = lr["errors"]
		report["composability"] = lr["composability"]
		return _finish_by_checks()

	var mres: Dictionary = Manifest.read(pack_dir)
	_set_pack(mres["manifest"])
	if not mres["ok"]:
		(report["errors"] as Array).append_array(mres["errors"])
		return _not_run("load", "the manifest is not valid; run lint")
	var seed_value: int = int(opts.get("seed", "1"))
	_entry_file = str((mres["manifest"] as Dictionary)["entry"])
	_test_file = str(opts.get("test", ((mres["manifest"] as Dictionary)["tests"] as Array)[0]))
	report["seed"] = seed_value
	var imp: String = _ensure_import()
	if not imp.is_empty():
		return _not_run("engine", imp)

	match verb:
		"smoke":
			var frames: int = int(opts.get("frames", "3600"))
			report["frames"] = frames
			var run: Dictionary = await _run_worker("smoke", {"seed": seed_value, "frames": frames}, "")
			if _smoke_checks(run, frames):
				report["metrics"] = _metrics(run)
			_finish_by_checks()
		"invariants":
			var frames: int = int(opts.get("frames", "3600"))
			report["frames"] = frames
			var a: Dictionary = await _run_worker("smoke", {"seed": seed_value, "frames": frames}, "")
			if not _smoke_checks(a, frames):
				return _finish_by_checks()
			var b: Dictionary = await _run_worker("smoke", {"seed": seed_value, "frames": frames}, "")
			if not _smoke_checks(b, frames, true):
				return _finish_by_checks()
			_invariant_checks(a["result"], b["result"])
			# RUNNER.md (amended 2026-11-10, second round): the idle run presses nothing, so it cannot see
			# non-determinism that needs input. Replay the pack's first bot twice with the same seed and compare.
			var bot_test: String = str(((mres["manifest"] as Dictionary)["tests"] as Array)[0])
			var bot_frames: int = int(opts.get("bot-frames", "36000"))
			_test_file = bot_test
			var bot_opts: Dictionary = {"seed": seed_value, "frames": bot_frames, "test": bot_test}
			var ba: Dictionary = await _run_worker("bot", bot_opts, "")
			if not _smoke_checks(ba, bot_frames, true, " (bot run)", true):
				_check("invariants.bot_deterministic", false, "the bot run of %s could not be used; see errors" % bot_test)
				return _finish_by_checks()
			var bb: Dictionary = await _run_worker("bot", bot_opts, "")
			if not _smoke_checks(bb, bot_frames, true, " (second bot run)"):
				_check("invariants.bot_deterministic", false, "the second bot run of %s could not be used; see errors" % bot_test)
				return _finish_by_checks()
			_bot_determinism_check(bot_test, ba["result"], bb["result"])
			_finish_by_checks()
		"bot":
			var frames: int = int(opts.get("frames", "36000"))
			report["frames"] = frames
			var tests: Array = (mres["manifest"] as Dictionary)["tests"]
			var test: String = str(opts.get("test", tests[0]))
			var run: Dictionary = await _run_worker("bot", {"seed": seed_value, "frames": frames, "test": test}, "")
			if _smoke_checks(run, frames):
				report["metrics"] = _metrics(run)
			var res: Dictionary = run.get("result", {})
			var bot: Dictionary = res.get("bot", {})
			if not bot.is_empty():
				report["bot"] = bot
				report["frames"] = int(bot.get("frames", frames))
				var done: bool = bool(bot.get("done", false))
				var bres: Dictionary = bot.get("result", {})
				_check("bot.completed", done, "done at frame %d" % int(bot.get("frames", 0)) if done else "frame_budget: not done within %d frames" % frames)
				if not done:
					_error("bot", test, "frame_budget: the bot was not done within %d frames" % frames)
				_check("bot.ok", done and bool(bres.get("ok", false)), str(bres.get("summary", "")))
				if done and not bool(bres.get("ok", false)):
					_error("bot", test, "the bot finished with ok = false: %s" % str(bres.get("summary", "")))
			else:
				_check("bot.completed", false, "the bot did not run")
				_check("bot.ok", false, "the bot did not run")
			_finish_by_checks()
		"capture":
			var at: int = int(opts.get("frame", "120"))
			report["frames"] = at
			var cams: Array = (mres["manifest"] as Dictionary).get("cameras", [])
			if not opts.has("cam") and cams.is_empty():
				return _not_run("engine", "--cam=<name> is required (the manifest lists no cameras)")
			var cam: String = str(opts.get("cam", cams[0] if not cams.is_empty() else ""))
			if not opts.has("out") or not str(opts["out"]).is_absolute_path():
				return _not_run("engine", "--out=<file.png> is required and must be an absolute path")
			var res_text: String = str(opts.get("res", "1920x1080"))
			if res_text.split("x").size() != 2 or not res_text.get_slice("x", 0).is_valid_int() or not res_text.get_slice("x", 1).is_valid_int():
				return _not_run("engine", "--res must look like 1920x1080")
			if FileAccess.file_exists(str(opts["out"])):
				DirAccess.remove_absolute(str(opts["out"]))
			var extra: Dictionary = {"seed": seed_value, "frames": at, "cam": cam, "out": str(opts["out"])}
			if opts.has("test"):
				extra["test"] = str(opts["test"])      # a bot plays up to the captured frame
			var run: Dictionary = await _run_worker("capture", extra, res_text)
			_smoke_checks(run, at)
			var res: Dictionary = run.get("result", {})
			var cap: Dictionary = res.get("capture", {})
			var written: bool = not cap.is_empty() and FileAccess.file_exists(str(opts["out"]))
			if written:
				report["capture"] = cap
			var how: String = "rendering driver: %s" % render_driver
			if engine_start_crashes > 0:
				how += "; the engine crashed %d time(s) while opening its window before this run" % engine_start_crashes
			_check("capture.written", written, "%s, %dx%d at frame %d (%s)" % [str(cap.get("file", "")), int(cap.get("width", 0)), int(cap.get("height", 0)), int(cap.get("frame", 0)), how] if written else "no image was written (%s)" % how)
			_finish_by_checks()


func _win_path(p: String) -> String:
	# Git Bash style /c/Users/... -> C:/Users/...
	var q: String = p.replace("\\", "/")
	if q.length() >= 3 and q[0] == "/" and q[2] == "/" and q[1].to_lower() >= "a" and q[1].to_lower() <= "z":
		return q[1].to_upper() + ":" + q.substr(2)
	return q


func _set_pack(m: Dictionary) -> void:
	if typeof(m.get("id")) == TYPE_STRING:
		report["pack"] = m["id"]
	if typeof(m.get("version")) == TYPE_STRING:
		report["packVersion"] = m["version"]


func _check(id: String, ok: bool, detail: String) -> void:
	(report["checks"] as Array).append({"id": id, "ok": ok, "detail": detail})


func _error(kind: String, file: String, message: String, line: int = -1) -> void:
	var e: Dictionary = {"kind": kind}
	if not file.is_empty():
		e["file"] = file
	if line >= 0:
		e["line"] = line
	e["message"] = message
	(report["errors"] as Array).append(e)


func _not_run(kind: String, message: String) -> void:
	_error(kind, "", message)
	report["ok"] = false
	report["outcome"] = "not_run"
	_finish(2)


func _finish_by_checks() -> void:
	if report.get("outcome") == "watchdog":
		report["ok"] = false
		return _finish(3)
	if report.get("outcome") == "engine_failed":
		report["ok"] = false
		report["outcome"] = "not_run"
		return _finish(2)
	var ok: bool = true
	for c: Dictionary in report["checks"]:
		ok = ok and bool(c["ok"])
	report["ok"] = ok
	report["outcome"] = "passed" if ok else "failed"
	_finish(0 if ok else 1)


func _finish(code: int) -> void:
	report["durationMs"] = Time.get_ticks_msec() - _t0     # information only; no check reads the wall clock
	var ordered: Dictionary = {}
	for k: String in ["schema", "verb", "level", "pack", "packVersion", "kernelApi", "ok", "outcome", "seed", "frames",
			"durationMs", "checks", "metrics", "errors", "composability", "bot", "capture"]:
		if report.has(k):
			ordered[k] = report[k]
	var text: String = JSON.stringify(ordered, "", false)
	if opts.has("report") and str(opts["report"]).is_absolute_path():
		DirAccess.make_dir_recursive_absolute(str(opts["report"]).get_base_dir())
		var f: FileAccess = FileAccess.open(str(opts["report"]), FileAccess.WRITE)
		if f != null:
			f.store_string(text + "\n")
			f.close()
		else:
			printerr("[tl] could not write the report to %s" % str(opts["report"]))
	print(text)
	get_tree().quit(code)


# ------------------------------------------------------------------------------------------------- class cache
func _newest_script(dir: String) -> int:
	var newest: int = 0
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return 0
	if d.file_exists(".gdignore"):
		return 0
	for f: String in d.get_files():
		if f.get_extension() == "gd":
			newest = maxi(newest, FileAccess.get_modified_time(dir + "/" + f))
	for s: String in d.get_directories():
		if not s.begins_with("."):
			newest = maxi(newest, _newest_script(dir + "/" + s))
	return newest


## Global classes (TLBall, ...) are resolved through .godot/global_script_class_cache.cfg. Refresh it when it is
## missing or older than a script. Returns "" or an error.
func _ensure_import() -> String:
	var engine_dir: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var cache: String = engine_dir + "/.godot/global_script_class_cache.cfg"
	var fresh: bool = FileAccess.file_exists(cache)
	if fresh:
		var newest: int = 0
		for sub: String in ["kernel", "kits", "rigs", "style"]:
			newest = maxi(newest, _newest_script(engine_dir + "/" + sub))
		fresh = FileAccess.get_modified_time(cache) >= newest
	if fresh:
		return ""
	var out: Array = []
	OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", engine_dir, "--import"]), out, true)
	print("[tl] class cache refreshed (--import)")
	if not FileAccess.file_exists(cache):
		return "could not build the class cache (godot --import failed)"
	var cf: FileAccess = FileAccess.open(cache, FileAccess.READ_WRITE)   # touch: an unchanged cache keeps its old time
	if cf != null:
		var body: String = cf.get_as_text()
		cf.seek(0)
		cf.store_string(body)
		cf.close()
	return ""


# ------------------------------------------------------------------------------------------------- worker runs
func _tmp_base() -> String:
	if opts.has("report") and str(opts["report"]).is_absolute_path():
		DirAccess.make_dir_recursive_absolute(str(opts["report"]).get_base_dir())
		return "%s.tmp%d" % [str(opts["report"]), OS.get_process_id()]
	var dir: String = OS.get_user_data_dir() + "/tl_tmp"
	DirAccess.make_dir_recursive_absolute(dir)
	return "%s/run%d" % [dir, OS.get_process_id()]


## Starts one worker process and waits for it. Returns {result: Dictionary, exit_code, has_result, log_script_errors}.
## A worker that dies before its first line (seen here as a graphics driver crash while a window opens under GPU
## load from other processes) never ran any pack code; it is started again, at most START_ATTEMPTS times in all.
func _run_worker(mode: String, extra: Dictionary, window_res: String) -> Dictionary:
	var run: Dictionary = {}
	# windowed runs use Direct3D 12 (contracts/RUNNER.md, amended 2026-11-10): one backend for every image, and it
	# did not show the Vulkan start crash. TL_RENDER_DRIVERS overrides the order, for example "vulkan,d3d12".
	var drivers: PackedStringArray = PackedStringArray(["d3d12", "d3d12", "d3d12"])
	if OS.has_environment("TL_RENDER_DRIVERS") and not OS.get_environment("TL_RENDER_DRIVERS").is_empty():
		drivers = OS.get_environment("TL_RENDER_DRIVERS").split(",")
	if window_res.is_empty():
		drivers = PackedStringArray(["default", "default", "default"])
	for attempt: int in drivers.size():
		render_driver = drivers[attempt].strip_edges()
		run = await _run_worker_once(mode, extra, window_res, render_driver)
		if run["has_result"] or run["started"] or run.has("spawn_failed"):
			break
		engine_start_crashes += 1
		print("[tl] the worker crashed before it started (exit code %d, driver %s); attempt %d of %d" % [int(run["exit_code"]), render_driver, attempt + 1, drivers.size()])
	return run


func _run_worker_once(mode: String, extra: Dictionary, window_res: String, driver: String) -> Dictionary:
	_runs += 1
	var base: String = "%s.%d" % [_tmp_base(), _runs]
	var result_path: String = base + ".result.json"
	var log_path: String = base + ".log"
	var alive_path: String = base + ".alive"      # touched while this supervisor lives; an orphaned worker ends itself
	_touch(alive_path)
	var engine_dir: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var args: PackedStringArray = PackedStringArray()
	if window_res.is_empty():
		args.append("--headless")
	else:
		args.append_array(["--position", "0,1440", "--resolution", window_res])
		if driver != "default" and not driver.is_empty():
			args.append_array(["--rendering-driver", driver])
	args.append_array(["--fixed-fps", "60", "--log-file", log_path, "--path", engine_dir, "res://kernel/host/host.tscn",
		"--", "worker", "--mode=" + mode, "--pack=" + pack_dir, "--result=" + result_path, "--alive=" + alive_path])
	for k: String in extra.keys():
		args.append("--%s=%s" % [k, str(extra[k])])
	var pid: int = OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		return {"result": {}, "exit_code": -1, "has_result": false, "started": false, "spawn_failed": true}
	var grace: int = 0
	var polls: int = 0
	while OS.is_process_running(pid):
		OS.delay_msec(10)
		await get_tree().process_frame
		polls += 1
		if polls % 200 == 0:
			_touch(alive_path)
		if FileAccess.file_exists(result_path):
			grace += 1
			if grace > 600:        # the result is written but the process lingers: end it (not a check)
				OS.kill(pid)
				break
	var code: int = OS.get_process_exit_code(pid)
	_remove(alive_path)
	var result: Dictionary = {}
	var has_result: bool = false
	if FileAccess.file_exists(result_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(result_path))
		if typeof(parsed) == TYPE_DICTIONARY:
			result = _intify(parsed)
			has_result = true
		_remove(result_path)
	var log_text: String = ""
	if FileAccess.file_exists(log_path):
		log_text = FileAccess.get_file_as_string(log_path)
		_remove(log_path)
	var lines: PackedStringArray = log_text.split("\n")
	var unlogged: PackedStringArray = PackedStringArray()
	var shown: int = 0
	var worker_started: bool = false
	for i: int in lines.size():
		var line: String = lines[i].strip_edges(false, true)
		if line.begins_with("[tl] worker done"):
			break
		if line.begins_with("[tl] worker start"):
			worker_started = true
			continue
		if line.begins_with("SCRIPT ERROR:"):
			var where: String = lines[i + 1].strip_edges() if i + 1 < lines.size() else ""
			unlogged.append(line + " " + where)
		if not line.is_empty() and not line.begins_with("Godot Engine v") and shown < RELAY_LINES:
			print("[worker %d] %s" % [_runs, line])
			shown += 1
	return {"result": result, "exit_code": code, "has_result": has_result, "started": worker_started, "log_script_errors": unlogged}


## Removes a temporary file; a process that was just ended may hold its log for a moment longer.
func _remove(path: String) -> void:
	for attempt: int in 50:
		if not FileAccess.file_exists(path) or DirAccess.remove_absolute(path) == OK:
			return
		OS.delay_msec(20)


func _touch(path: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("1")
		f.close()


## JSON has one number type; whole numbers read back from the worker become ints again.
func _intify(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if float(v) == floor(float(v)) and absf(float(v)) < 9.0e15 else v
		TYPE_DICTIONARY:
			for k: Variant in (v as Dictionary).keys():
				(v as Dictionary)[k] = _intify((v as Dictionary)[k])
		TYPE_ARRAY:
			for i: int in (v as Array).size():
				(v as Array)[i] = _intify((v as Array)[i])
	return v


## Adds the V2 checks for one worker run. Returns false when the run cannot be used any further.
func _smoke_checks(run: Dictionary, frames: int, second: bool = false, second_tag: String = " (second run)", list_errors: bool = false) -> bool:
	var res: Dictionary = run["result"]
	if not run["has_result"]:
		_error("engine", "", "the sim worker ended without a result (exit code %d)%s" % [int(run["exit_code"]),
			"; could not start the process" if run.has("spawn_failed") else ""])
		for line: String in run.get("log_script_errors", PackedStringArray()):
			_error("script_error", "", line)
		report["outcome"] = "engine_failed"
		return false
	var tag: String = second_tag if second else ""
	var load_errors: Array = res.get("load_errors", [])
	var loaded: bool = bool(res.get("loaded", false)) and load_errors.is_empty()
	var errs: Array = res.get("errors", [])
	var n_script: int = int(res.get("script_errors", 0))
	var n_engine: int = int(res.get("engine_errors", 0))
	var from_log: PackedStringArray = run.get("log_script_errors", PackedStringArray())
	if not second or list_errors:   # list_errors: a later run that executes code the first did not (the bot replay)
		for e: Dictionary in load_errors:
			_error(str(e.get("kind", "load")), str(e.get("file", "")), str(e.get("message", "")), int(e.get("line", -1)))
		for e: Dictionary in errs:
			var msg: String = str(e.get("message", ""))
			var notes: PackedStringArray = PackedStringArray()
			if e.has("frame"):
				notes.append("frame %d" % int(e["frame"]))
			if int(e.get("count", 1)) > 1:
				notes.append("%d times" % int(e["count"]))
			if not notes.is_empty():
				msg += " [%s]" % ", ".join(notes)
			_error(str(e.get("kind", "script_error")), str(e.get("file", "")), msg, int(e.get("line", -1)))
		if from_log.size() > 0 and n_script == 0:
			# the engine printed script errors the in-process Logger never saw (for example before it was registered)
			for line: String in from_log:
				_error("script_error", "", "from the engine log: " + line)
	if from_log.size() > 0 and n_script == 0:
		n_script = from_log.size()
	var warn_text: String = ""
	if not second:
		for w: Variant in res.get("warnings", []):
			warn_text += "; WARNING: " + str(w)
	if not second or not loaded:
		_check("smoke.loads", loaded, ("pack loaded" + warn_text if loaded else "the pack did not load: %s" % (str((load_errors[0] as Dictionary).get("message", "")) if not load_errors.is_empty() else "see errors")) + tag)
	if not second or n_script > 0:
		_check("smoke.no_script_errors", n_script == 0, "%d errors in %d frames%s" % [n_script, int(res.get("frames_run", 0)), tag])
	if not second or n_engine > 0:
		_check("smoke.no_engine_errors", n_engine == 0, "%d engine errors%s" % [n_engine, tag])
	var wd: Dictionary = res.get("watchdog", {})
	if not second or not wd.is_empty():
		_check("smoke.watchdog", wd.is_empty(), ("no trip in %d frames" % int(res.get("frames_run", 0)) if wd.is_empty() else "%s: %s" % [str(wd.get("reason", "")), str(wd.get("detail", ""))]) + tag)
	if not wd.is_empty():
		# name the script that was running: the entry, a generator or the bot
		var phase: String = str(wd.get("phase", ""))
		var where: String = ""
		if phase.begins_with("generate "):
			where = phase.substr(9)
		elif phase.begins_with("_bot") or str(wd.get("reason", "")) == "frame_budget":
			where = _test_file
		elif phase.begins_with("_pack"):
			where = _entry_file
		_error("watchdog", where, "%s: %s (frame %d)" % [str(wd.get("reason", "")), str(wd.get("detail", "")), int(wd.get("frame", 0))])
		report["outcome"] = "watchdog"
		if res.has("bot"):
			report["bot"] = res["bot"]
		return false
	return loaded


func _metrics(run: Dictionary) -> Dictionary:
	var m: Dictionary = (run["result"] as Dictionary).get("metrics", {})
	var out: Dictionary = {}
	for k: String in ["state_hash", "frame_ms_p50", "frame_ms_p99", "entities_max", "bodies_max", "tick_ms_max"]:
		if m.has(k):
			out[k] = int(m[k]) if k.ends_with("_max") and k != "tick_ms_max" else m[k]
	return out


func _invariant_checks(a: Dictionary, b: Dictionary) -> void:
	var ma: Dictionary = a.get("metrics", {})
	var mb: Dictionary = b.get("metrics", {})
	var ha: String = str(ma.get("state_hash", ""))
	var hb: String = str(mb.get("state_hash", ""))
	var same: bool = not ha.is_empty() and ha == hb
	var detail: String = "two runs, seed %d, %d frames: %s" % [int(report["seed"]), int(report["frames"]), ha.substr(0, 16)]
	if not same:
		var ta: Array = a.get("hash_trace", [])
		var tb: Array = b.get("hash_trace", [])
		var where: String = "after the last sampled frame"
		for i: int in mini(ta.size(), tb.size()):
			if str((ta[i] as Array)[1]) != str((tb[i] as Array)[1]):
				where = "at or before frame %d" % int((ta[i] as Array)[0])
				break
		detail = "state_hash differs between two runs with seed %d (%s vs %s); first difference %s" % [int(report["seed"]), ha.substr(0, 16), hb.substr(0, 16), where]
		_error("determinism", "", detail)
	_check("invariants.determinism", same, detail)
	var below: int = int(a.get("below_count", 0)) + int(b.get("below_count", 0))
	var bd: Dictionary = a.get("below", b.get("below", {}))
	var below_detail: String = "no physics body below y = -50"
	if below > 0:
		below_detail = "body '%s' at y = %s at frame %d" % [str(bd.get("node", "")), str(bd.get("y", "")), int(bd.get("frame", 0))]
		_error("budget", "", "a physics body fell below y = -50: " + below_detail)
	_check("invariants.below_ground", below == 0, below_detail)
	# frame time is the one budget that reads a clock (the contract's 8 ms); the better of the two runs is judged
	var p99: float = minf(float(ma.get("frame_ms_p99", 0.0)), float(mb.get("frame_ms_p99", 0.0)))
	if p99 > BUDGET_FRAME_MS_P99:
		_error("budget", "", "frame p99 %.2f ms is over the %.0f ms budget" % [p99, BUDGET_FRAME_MS_P99])
	_check("invariants.frame_budget", p99 <= BUDGET_FRAME_MS_P99, "frame p99 %.3f ms (budget %.0f ms; scripts + physics step, headless, better of two runs)" % [p99, BUDGET_FRAME_MS_P99])
	var nodes: int = maxi(int(ma.get("entities_max", 0)), int(mb.get("entities_max", 0)))
	var bodies: int = maxi(int(ma.get("bodies_max", 0)), int(mb.get("bodies_max", 0)))
	var ent_ok: bool = nodes <= BUDGET_NODES and bodies <= BUDGET_BODIES
	if not ent_ok:
		_error("budget", "", "%d nodes (budget %d), %d physics bodies (budget %d)" % [nodes, BUDGET_NODES, bodies, BUDGET_BODIES])
	_check("invariants.entity_budget", ent_ok, "%d nodes (budget %d), %d physics bodies (budget %d)" % [nodes, BUDGET_NODES, bodies, BUDGET_BODIES])
	var metrics: Dictionary = {"state_hash": ha, "frame_ms_p50": ma.get("frame_ms_p50", 0.0), "frame_ms_p99": p99,
		"entities_max": nodes, "bodies_max": bodies}
	if not same:
		metrics["state_hash_b"] = hb
	report["metrics"] = metrics


## WP5: two bot runs of one test with one seed must end in the same state after the same number of frames.
func _bot_determinism_check(test: String, a: Dictionary, b: Dictionary) -> void:
	var ha: String = str((a.get("metrics", {}) as Dictionary).get("state_hash", ""))
	var hb: String = str((b.get("metrics", {}) as Dictionary).get("state_hash", ""))
	var fa: int = int(a.get("frames_run", 0))
	var fb: int = int(b.get("frames_run", 0))
	var same: bool = not ha.is_empty() and ha == hb and fa == fb
	var detail: String = "bot %s twice, seed %d: %s after %d frames" % [test, int(report["seed"]), ha.substr(0, 16), fa]
	if not same:
		var ta: Array = a.get("hash_trace", [])
		var tb: Array = b.get("hash_trace", [])
		var where: String = "after the last sampled frame"
		for i: int in mini(ta.size(), tb.size()):
			if str((ta[i] as Array)[1]) != str((tb[i] as Array)[1]):
				where = "at or before frame %d" % int((ta[i] as Array)[0])
				break
		detail = "two bot runs of %s with seed %d differ: %s after %d frames vs %s after %d frames; first difference %s" % [
			test, int(report["seed"]), ha.substr(0, 16), fa, hb.substr(0, 16), fb, where]
		_error("determinism", test, detail)
	_check("invariants.bot_deterministic", same, detail)
	var metrics: Dictionary = report.get("metrics", {})
	metrics["bot_state_hash"] = ha
	metrics["bot_frames"] = fa
	if not same:
		metrics["bot_state_hash_b"] = hb
	report["metrics"] = metrics
