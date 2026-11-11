extends RefCounted
## N6: starts Foreman command lines for the panel, as detached `node` processes, and says whether one is alive.
## The panel never builds anything itself; whatever happens is read back from the job directory.

var jobs_root: String = ""
var cli_path: String = ""          # <repo>/foreman/dist/cli.js
var runner_path: String = ""       # ui/foreman_run.mjs
var node_exe: String = "node"
var node_version: String = ""
var available: bool = false
var problem: String = ""           # why not, in one line
var dry: bool = false              # captures: never start anything
var flags: Dictionary = {}         # per command: {"new": [...], "plan": [...], "run": [...], "change": [...], "resume": [...]}
var flags_name: String = ""
var dry_steps: Array = []          # dry: what would have been started, newest last (for the selftest)
var started: Array = []            # everything this door started: {pid, key, label, log, t0, done, code, error}

var _pid_cache: Dictionary = {}    # pid -> {alive, at}
var _n: int = 0


func setup(root: String, opts: Dictionary = {}) -> void:
	jobs_root = root
	dry = bool(opts.get("dry", false))
	runner_path = ProjectSettings.globalize_path("res://ui/foreman_run.mjs")
	cli_path = str(opts.get("cli", ""))
	if cli_path.is_empty() and OS.has_environment("TL_FOREMAN_CLI"):
		cli_path = OS.get_environment("TL_FOREMAN_CLI")
	if cli_path.is_empty():
		cli_path = find_cli(ProjectSettings.globalize_path("res://"))
	if OS.has_environment("TL_NODE") and not OS.get_environment("TL_NODE").is_empty():
		node_exe = OS.get_environment("TL_NODE")
	if opts.has("node"):
		node_exe = str(opts["node"])
	if opts.get("flags", null) is Dictionary:
		flags = opts["flags"]
	flags_name = str(opts.get("flags_name", ""))
	check()


## Walks up from the engine directory to the repository that holds foreman/dist/cli.js.
static func find_cli(from_dir: String) -> String:
	var d: String = from_dir.trim_suffix("/")
	for i: int in 8:
		var c: String = d.path_join("foreman/dist/cli.js")
		if FileAccess.file_exists(c):
			return c
		var up: String = d.get_base_dir()
		if up == d or up.is_empty():
			break
		d = up
	return ""


## Looks again whether the Foreman can be started. Cheap enough to call when the player presses a button.
func check() -> bool:
	available = false
	problem = ""
	if cli_path.is_empty() or not FileAccess.file_exists(cli_path):
		problem = "Foreman not found (%s)" % ("no foreman/dist/cli.js above the engine" if cli_path.is_empty() else cli_path)
		return false
	if node_version.is_empty():
		var out: Array = []
		var code: int = OS.execute(node_exe, PackedStringArray(["--version"]), out, true)
		if code != 0 or out.is_empty() or not str(out[0]).strip_edges().begins_with("v"):
			problem = "Node not found (\"%s --version\" did not answer): the Foreman cannot be started" % node_exe
			return false
		node_version = str(out[0]).strip_edges()
	if flags.is_empty():
		problem = "No Foreman settings (adapter, limits) were given to the panel"
		return false
	available = true
	return true


func _flags(cmd: String) -> Array:
	var f: Variant = flags.get(cmd, flags.get("run", []) if cmd in ["resume", "change"] else [])
	return (f as Array).duplicate() if f is Array else []


static func clean_text(text: String) -> String:
	# one argument on a Windows command line: no line breaks, no double quotes
	return text.replace("\r", " ").replace("\n", " ").replace("\"", "'").strip_edges()


func _start(key: String, label: String, steps: Array) -> String:
	if dry:
		dry_steps.append(steps)
		return "captures only: nothing is started"
	if not check():
		return problem
	_n += 1
	var log_dir: String = jobs_root.path_join("_ui_logs")
	DirAccess.make_dir_recursive_absolute(log_dir)
	var log: String = log_dir.path_join("%d-%03d-%s.log" % [int(Time.get_unix_time_from_system()), _n, label])
	var args: PackedStringArray = PackedStringArray([runner_path, "--log", log, "--cli", cli_path, "--"])
	for i: int in steps.size():
		if i > 0:
			args.append(";;")
		for a: Variant in steps[i]:
			args.append(str(a))
	var pid: int = OS.create_process(node_exe, args)
	if pid <= 0:
		return "the Foreman could not be started (node did not start)"
	started.append({"pid": pid, "key": key, "label": label, "log": log, "t0": Time.get_unix_time_from_system(), "done": false, "code": -1, "error": ""})
	return ""


func new_game(sentence: String) -> String:
	var s: String = clean_text(sentence)
	if s.is_empty():
		return "describe the game first"
	return _start("new:" + s, "new", [["new", s, "--site", jobs_root] + _flags("new")])


func approve(job_dir: String) -> String:
	return _start(job_dir, "approve", [["approve", job_dir], ["plan", job_dir] + _flags("plan"), ["run", job_dir] + _flags("run")])


## For a job that is approved or planned but has no Foreman (it died, or the brief was approved elsewhere).
func resume(job_dir: String, has_plan: bool, started_before: bool) -> String:
	var steps: Array = []
	if not has_plan:
		steps.append(["plan", job_dir] + _flags("plan"))
	steps.append([("resume" if started_before else "run"), job_dir] + _flags("resume" if started_before else "run"))
	return _start(job_dir, "resume", steps)


func discard(job_dir: String) -> String:
	return _start(job_dir, "discard", [["cancel", job_dir, "--reason", "discarded by the player"]])


func answer(job_dir: String, package: String, text: String, change_package: String) -> String:
	var t: String = clean_text(text)
	if t.is_empty():
		return "write the answer first"
	var a: Array = ["answer", job_dir, package, t]
	if not change_package.is_empty():
		a.append_array(["--change", change_package])
	return _start(job_dir, "answer", [a, ["resume", job_dir] + _flags("resume")])


func change(job_dir: String, text: String) -> String:
	var t: String = clean_text(text)
	if t.is_empty():
		return "say what should be different first"
	return _start(job_dir, "change", [["change", job_dir, t] + _flags("change")])


## Looks at what this door started. Returns true when something ended since the last call.
func tick() -> bool:
	var changed: bool = false
	for s: Dictionary in started:
		if bool(s["done"]) or OS.is_process_running(int(s["pid"])):
			continue
		s["done"] = true
		s["code"] = OS.get_process_exit_code(int(s["pid"]))
		var tail: Dictionary = _log_tail(str(s["log"]))
		if not bool(tail["ok"]):
			s["error"] = "%s did not work: %s" % [str(tail["step"]) if not str(tail["step"]).is_empty() else str(s["label"]), str(tail["line"])]
		changed = true
	return changed


static func _log_tail(log: String) -> Dictionary:
	var out: Dictionary = {"ok": true, "step": "", "line": ""}
	if not FileAccess.file_exists(log):
		return {"ok": false, "step": "", "line": "the Foreman wrote nothing (it did not start)"}
	var lines: PackedStringArray = FileAccess.get_file_as_string(log).split("\n")
	var last_text: String = ""
	for raw: String in lines:
		var line: String = raw.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("[door] end "):
			out["ok"] = line.ends_with(" ok")
			out["step"] = line.get_slice("step=", 1).get_slice(" ", 0)
		elif not line.begins_with("[door]"):
			last_text = line
	out["line"] = last_text.substr(0, 200)
	return out


## The process this door started for a job and that still runs: its label, or "".
func busy(key: String) -> String:
	for s: Dictionary in started:
		if s["key"] == key and not bool(s["done"]):
			return str(s["label"])
	return ""


func busy_new() -> Array:
	var out: Array = []
	for s: Dictionary in started:
		if str(s["key"]).begins_with("new:") and not bool(s["done"]):
			out.append(str(s["key"]).substr(4))
	return out


## The last thing that went wrong for a job (or for "new:" requests when key is "new"), or "".
func last_error(key: String) -> String:
	for i: int in range(started.size() - 1, -1, -1):
		var s: Dictionary = started[i]
		var hit: bool = s["key"] == key or (key == "new" and str(s["key"]).begins_with("new:"))
		if hit:
			return str(s["error"]) if bool(s["done"]) else ""
	return ""


## Is the process with this pid alive? Our own children are asked directly; a foreign pid (a Foreman started from a
## terminal) through the system's process list, at most once every 4 seconds per pid.
func pid_alive(pid: int) -> bool:
	if pid <= 0:
		return false
	for s: Dictionary in started:
		if int(s["pid"]) == pid:
			return OS.is_process_running(pid)
	var now: float = Time.get_unix_time_from_system()
	if _pid_cache.has(pid) and now - float(_pid_cache[pid]["at"]) < 4.0:
		return bool(_pid_cache[pid]["alive"])
	var alive: bool = false
	if OS.get_name() == "Windows":
		var out: Array = []
		OS.execute("tasklist", PackedStringArray(["/FI", "PID eq %d" % pid, "/NH", "/FO", "CSV"]), out, true)
		alive = not out.is_empty() and str(out[0]).contains("\"%d\"" % pid)
	else:
		alive = OS.execute("kill", PackedStringArray(["-0", str(pid)])) == 0
	_pid_cache[pid] = {"alive": alive, "at": now}
	return alive


## Is a Foreman working on this job right now? Either one this door started, or the holder of the job's lock.
func foreman_alive(job_dir: String, lock_pid: int) -> bool:
	if not busy(job_dir).is_empty():
		return true
	return pid_alive(lock_pid)


func pids_running() -> PackedInt32Array:
	var out: PackedInt32Array = []
	for s: Dictionary in started:
		if not bool(s["done"]) and OS.is_process_running(int(s["pid"])):
			out.append(int(s["pid"]))
	return out
