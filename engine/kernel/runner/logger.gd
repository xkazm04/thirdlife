extends Logger
## Captures every error Godot would only print (GDScript runtime errors, parse errors, push_error, engine errors)
## with file and line. Registered with OS.add_logger() in the sim worker. May be called from any thread.

const MAX_KEPT: int = 60

var pack_dir: String = ""          # absolute, forward slashes, no trailing slash
var _mutex: Mutex = Mutex.new()
var _entries: Array = []           # distinct errors, capped at MAX_KEPT
var _seen: Dictionary = {}
var _script_errors: int = 0
var _engine_errors: int = 0
var _warnings: int = 0
var frame: int = -1                # set by the worker; -1 while loading


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, script_backtraces: Array) -> void:
	if error_type == ERROR_TYPE_WARNING:
		_mutex.lock()
		_warnings += 1
		_mutex.unlock()
		return
	if error_type == ERROR_TYPE_SHADER:
		return
	var message: String = rationale if not rationale.is_empty() else code
	if error_type == ERROR_TYPE_ERROR and message.begins_with("Failed to load script"):
		return      # the engine's echo of a parse error that was already reported with its file and line
	var where_file: String = file
	var where_line: int = line
	var has_script_frame: bool = error_type == ERROR_TYPE_SCRIPT
	var pack_frame: bool = _in_pack(file)
	if not pack_frame:
		for bt: ScriptBacktrace in script_backtraces:
			for i: int in bt.get_frame_count():
				has_script_frame = true
				if _in_pack(bt.get_frame_file(i)):
					if error_type == ERROR_TYPE_SCRIPT:
						message += " (raised at %s:%d)" % [file, line]
					where_file = bt.get_frame_file(i)
					where_line = bt.get_frame_line(i)
					pack_frame = true
					break
			if pack_frame:
				break
	if error_type != ERROR_TYPE_SCRIPT and not pack_frame:
		# an engine or kernel error with no pack frame on the stack: keep the first script frame for the reader
		for bt: ScriptBacktrace in script_backtraces:
			if bt.get_frame_count() > 0:
				where_file = bt.get_frame_file(0)
				where_line = bt.get_frame_line(0)
				break
	var kind: String = "script_error" if (error_type == ERROR_TYPE_SCRIPT or pack_frame) else "engine"
	var rel: String = _relative(where_file)
	var key: String = "%s|%s|%d|%s" % [kind, rel, where_line, message]
	_mutex.lock()
	if kind == "script_error":
		_script_errors += 1
	else:
		_engine_errors += 1
	if _seen.has(key):
		_seen[key] = int(_seen[key]) + 1
	else:
		_seen[key] = 1
		if _entries.size() < MAX_KEPT:
			var e: Dictionary = {"kind": kind, "file": rel, "line": where_line, "message": message, "function": function}
			if frame >= 0:
				e["frame"] = frame
			e["_key"] = key
			_entries.append(e)
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func _norm(p: String) -> String:
	return p.replace("\\", "/")


func _in_pack(file: String) -> bool:
	if pack_dir.is_empty():
		return false
	var f: String = _norm(file)
	if f.begins_with("res://"):
		f = ProjectSettings.globalize_path(f)
	return f.to_lower().begins_with(pack_dir.to_lower() + "/")


func _relative(file: String) -> String:
	var f: String = _norm(file)
	if _in_pack(f):
		if f.begins_with("res://"):
			f = ProjectSettings.globalize_path(f)
		return f.substr(pack_dir.length() + 1)
	return f


## Thread-safe copy: {errors: [...], script_errors, engine_errors, warnings}. `count` is added to repeated errors.
func snapshot() -> Dictionary:
	_mutex.lock()
	var out: Array = []
	for e: Dictionary in _entries:
		var c: Dictionary = e.duplicate()
		var n: int = int(_seen.get(c["_key"], 1))
		c.erase("_key")
		if n > 1:
			c["count"] = n
		out.append(c)
	var res: Dictionary = {"errors": out, "script_errors": _script_errors, "engine_errors": _engine_errors, "warnings": _warnings}
	_mutex.unlock()
	return res


func total_errors() -> int:
	_mutex.lock()
	var n: int = _script_errors + _engine_errors
	_mutex.unlock()
	return n
