extends Logger
## P9. Everything the exe prints, and every engine error and warning, in one file beside the exe
## (`ThirdLife-last-run.log`, written anew on every start by a person). boot.gd registers it with `OS.add_logger`.
## Why: the engine's own log is `user://logs/godot.log`, the user folder is shared with every other engine process on
## the machine (the project's name decides it), and five other processes rotate a log away within seconds.
## Called from any thread: every write holds the mutex.

var _f: FileAccess = null
var _mutex: Mutex = Mutex.new()


func open(path: String) -> bool:
	_f = FileAccess.open(path, FileAccess.WRITE)
	if _f == null:
		return false
	_f.store_line("Third Life, started %s (%s)" % [Time.get_datetime_string_from_system(false, true), OS.get_executable_path()])
	_f.flush()
	return true


func _log_message(message: String, _error: bool) -> void:
	_mutex.lock()
	if _f != null:
		_f.store_string(message)
		_f.flush()
	_mutex.unlock()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, _script_backtraces: Array) -> void:
	_mutex.lock()
	if _f != null:
		var kind: String = "WARNING" if error_type == ERROR_TYPE_WARNING else ("SCRIPT ERROR" if error_type == ERROR_TYPE_SCRIPT else "ERROR")
		_f.store_line("%s: %s" % [kind, rationale if not rationale.is_empty() else code])
		_f.store_line("   at: %s (%s:%d)" % [function, file, line])
		_f.flush()
	_mutex.unlock()
