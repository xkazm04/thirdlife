extends RefCounted
## M4 (spark world-sandbox): the command bar's line to the Foreman. A door (ui/foreman_door.gd) starts
## `foreman world-edit --in <ask> --out <answer>` as a detached node process (the "world_edit" entry of the flags:
## TL_COMMAND_FLAGS=<flags json>, else res://ui/flags/real.json); the answer is a file the tool polls. Why the bar
## cannot ask is the door's `check().problem`, else the result of `foreman probe --adapter <a> --json`, run once per
## session on a thread of its own (it may take seconds: the frame never waits for it) and cached for the session.
## A case hands in a door of its own (dry: nothing is started; it records the step) and no probe runs.

const Door := preload("res://ui/foreman_door.gd")
const FLAGS := "res://ui/flags/real.json"

static var probe_state := ""            # "", "running", "ok", "failed": once per session
static var probe_problem := ""
static var _thread: Thread = null
static var _probe_out := {}

var door: RefCounted = null
var flags_name := ""
var adapter := ""
var problem := ""                       # why the door cannot start the Foreman ("" = it can)
var probing := true                     # false: a case's door, no probe


## `jobs`: the absolute folder the door logs into. `opts`: "door" (a ready door: a case), else the flags are read.
func setup(jobs: String, opts := {}) -> void:
	if opts.get("door") != null:
		door = opts.door
		probing = false
	else:
		var path := OS.get_environment("TL_COMMAND_FLAGS")
		if path.is_empty():
			path = FLAGS
		var f: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		var flags: Dictionary = (f as Dictionary).get("flags", {}) if f is Dictionary else {}
		flags_name = str((f as Dictionary).get("name", "")) if f is Dictionary else ""
		door = Door.new()
		door.setup(jobs, {"flags": flags, "flags_name": flags_name})
	var wf: Variant = (door.get("flags") as Dictionary).get("world_edit")
	if wf is Array:
		var i: int = (wf as Array).find("--adapter")
		adapter = str(wf[i + 1]) if i >= 0 and i + 1 < (wf as Array).size() else ""
	recheck()


## Looks again (the door's check: the Foreman's files, node, the settings).
func recheck() -> void:
	problem = ""
	if bool(door.get("dry")):
		return
	if not bool(door.call("check")):
		problem = str(door.get("problem"))
	elif not (door.get("flags") as Dictionary).has("world_edit"):
		problem = "no \"world_edit\" entry in the Foreman settings (%s)" % flags_name
	elif probing and adapter != "fake" and probe_state == "":
		_start_probe()


## "" when an ask may be sent now, else why not (the door, then the probe). A running probe does not stop an ask.
func refusal() -> String:
	_collect_probe()
	if not problem.is_empty():
		return problem
	if probe_state == "failed":
		return probe_problem
	return ""


## Starts `foreman world-edit` for the ask file. Returns "" or why it did not start.
func ask(ask_path: String, out_path: String) -> String:
	var n: int = (door.get("dry_steps") as Array).size()
	var why := str(door.call("world_edit", ask_path, out_path))
	if bool(door.get("dry")) and (door.get("dry_steps") as Array).size() > n:
		return ""                       # a dry door recorded the step (a case writes the answer)
	return why


## The process for `key` (its ask file) still runs.
func busy(key: String) -> bool:
	if bool(door.get("dry")):
		return true
	door.call("tick")
	return not str(door.call("busy", key)).is_empty()


## What went wrong with the process for `key`, once it ended ("" none known).
func error_of(key: String) -> String:
	return str(door.call("last_error", key))


func _start_probe() -> void:
	var node := str(door.get("node_exe"))
	var cli := str(door.get("cli_path"))
	probe_state = "running"
	_probe_out = {}
	_thread = Thread.new()
	_thread.start(func() -> void:
		var out: Array = []
		var code := OS.execute(node, PackedStringArray([cli, "probe", "--adapter", adapter, "--json"]), out, true)
		_probe_out = {"code": code, "text": "\n".join(out)})


func _collect_probe() -> void:
	if probe_state != "running" or _thread == null or _thread.is_alive():
		return
	_thread.wait_to_finish()
	_thread = null
	var text := str(_probe_out.get("text", ""))
	var j: Variant = JSON.parse_string(text.substr(text.find("[")) if text.find("[") >= 0 else "")
	var first: Variant = (j as Array)[0] if j is Array and not (j as Array).is_empty() else null
	if first is Dictionary and bool((first as Dictionary).get("ok", false)):
		probe_state = "ok"
	else:
		probe_state = "failed"
		var notes: Array = (first as Dictionary).get("notes", []) if first is Dictionary else []
		probe_problem = "the model is not connected (%s): %s" % [adapter,
			"; ".join(notes.map(func(n: Variant) -> String: return str(n))) if not notes.is_empty() else "foreman probe gave no answer"]
	print(JSON.stringify({"schema": "tl.view/1", "kind": "command_probe", "adapter": adapter, "state": probe_state,
		"problem": probe_problem}, "", false))
