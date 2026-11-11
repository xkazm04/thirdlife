extends RefCounted
## P1. The supervisor of a world (moved out of host.gd, which may not grow). `h` is the host.
## No global class name is used.

const STARVED_RETRIES: int = 2

var h: Node


func _remove(path: String) -> void:
	h.call("_remove", path)


func _intify(v: Variant) -> Variant:
	return h.call("_intify", v)


## P1. The supervisor of a world. A world holds many packs in one process; a runaway `_pack_tick` blocks that process's
## only thread and GDScript cannot be interrupted, so the world's own guard (guard.gd, processor time) ends the process and
## leaves a trip record. This supervisor then runs the world again WITHOUT that pack (it stays unloaded and is reported
## `tripped`): the packs share nothing, so every other pack's hash is what it is alone, and the run goes to its end.
## A run the machine starved (reason "starved") is run again as it was, at most STARVED_RETRIES times. The lines the
## child printed are relayed as they are, with an event line per trip and `trips` / `restarts` on the world line.
func run() -> void:
	var engine_dir: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var base: String = OS.get_user_data_dir() + "/tl_tmp"
	DirAccess.make_dir_recursive_absolute(base)
	base += "/world%d" % OS.get_process_id()
	var dead: PackedStringArray = PackedStringArray()
	var trips: Array = []
	var starved: int = 0
	var restarts: int = 0
	var code: int = 1
	var lines: PackedStringArray = PackedStringArray()
	for attempt: int in 12:
		var trip_path: String = base + ".trip.json"
		var log_path: String = base + ".log"
		_remove(trip_path)
		_remove(log_path)
		var args: PackedStringArray = PackedStringArray()
		if DisplayServer.get_name() == "headless":
			args.append("--headless")
		args.append_array(["--fixed-fps", "60", "--log-file", log_path, "--path", engine_dir, "res://kernel/host/host.tscn", "--"])
		args.append_array(OS.get_cmdline_user_args())
		args.append_array(["--child=true", "--trip=" + trip_path])
		if not dead.is_empty():
			args.append("--dead=" + ",".join(dead))
		var pid: int = OS.create_process(OS.get_executable_path(), args)
		if pid <= 0:
			print(JSON.stringify({"schema": "tl.world/1", "kind": "world", "errors": ["could not start the world process"]}, "", false))
			h.get_tree().quit(2)
			return
		while OS.is_process_running(pid):
			OS.delay_msec(50)
		code = OS.get_process_exit_code(pid)
		if not FileAccess.file_exists(trip_path):
			# the engine finishes writing its log file a moment after the process has ended: wait for the closing line
			var text: String = ""
			for wait: int in 100:
				text = FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(log_path) else ""
				if text.contains("[tl] world done") or text.contains("[tl] world refused"):
					break
				OS.delay_msec(50)
			lines = text.split("\n")
		if not FileAccess.file_exists(trip_path):
			break
		var rec: Variant = JSON.parse_string(FileAccess.get_file_as_string(trip_path))
		_remove(trip_path)
		if typeof(rec) != TYPE_DICTIONARY:
			break
		var reason: String = str((rec as Dictionary).get("reason", ""))
		if reason == "starved" and starved < STARVED_RETRIES:
			starved += 1
			restarts += 1
			print("[tl] the machine starved the world (%s); run again (%d of %d)" % [JSON.stringify(rec, "", false), starved, STARVED_RETRIES])
			continue
		var info: Dictionary = (rec as Dictionary).get("info", {})
		var idx: int = int(info.get("pack", -1))
		(rec as Dictionary)["restart"] = restarts + 1
		trips.append(_intify(rec))
		restarts += 1
		if idx < 0 or dead.has(str(idx)):
			code = 1
			break
		dead.append(str(idx))
		print("[tl] pack %d ran away (%s); the world runs again without it" % [idx, JSON.stringify(rec, "", false)])
	for t: Variant in trips:
		print(JSON.stringify({"schema": "tl.world/1", "kind": "event", "e": "pack_tripped", "record": t}, "", false))
	var shown: int = 0
	for line_raw: String in lines:
		var line: String = line_raw.strip_edges(false, true)
		if line.is_empty() or line.begins_with("Godot Engine v"):
			continue
		if line.begins_with("{\"schema\":\"tl.world/1\",\"kind\":\"world\"") and (not trips.is_empty() or restarts > 0):
			line = line.substr(0, line.length() - 1) + ",\"trips\":" + JSON.stringify(trips, "", false) + ",\"restarts\":%d}" % restarts
		print(line)
		shown += 1
	_remove(base + ".log")
	h.get_tree().quit(1 if (code == 0 and not trips.is_empty()) else code)
