extends SceneTree
## Validator (tools/k.sh validate): style files and tl.layout/1 files. Headless.
##   no args            both style files + every kits_lab/layouts/*.json whose name does not start with `broken`
##   <file.json> ...    the given files (a style file is recognised by its `palette` key); paths relative to the project
## Prints one `[validate] OK <file>` line per good file, or the errors (one per line) and `[validate] FAIL <file>`.
## Exit code 1 when any file fails.


func _initialize() -> void:
	var files: PackedStringArray = PackedStringArray()
	for a: String in OS.get_cmdline_user_args():
		files.append(a)
	if files.is_empty():
		files.append("res://style/style.json")
		files.append("res://style/style_overcast.json")
		var dir: DirAccess = DirAccess.open("res://kits_lab/layouts")
		var names: PackedStringArray = dir.get_files() if dir != null else PackedStringArray()
		names.sort()
		for f: String in names:
			if f.ends_with(".json") and not f.begins_with("broken"):
				files.append("res://kits_lab/layouts/" + f)
	var failed: int = 0
	for f: String in files:
		var path: String = f if (f.begins_with("res://") or f.is_absolute_path()) else "res://" + f
		if not FileAccess.file_exists(path):
			print("[validate] FAIL %s: file not found" % f)
			failed += 1
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (parsed is Dictionary):
			print("[validate] FAIL %s: not valid JSON (an object is expected)" % f)
			failed += 1
			continue
		var errs: PackedStringArray
		var kind: String = "layout"
		if (parsed as Dictionary).has("palette"):
			kind = "style"
			errs = TLStyle.check(parsed)
		else:
			errs = TLKit.validate_layout(parsed)
		var hard: int = 0
		for e: String in errs:
			if e.begins_with("clamped: "):
				print("[validate]   note  %s" % e)
			else:
				print("[validate]   error %s" % e)
				hard += 1
		if hard > 0:
			print("[validate] FAIL %s (%s): %d error%s" % [f, kind, hard, "" if hard == 1 else "s"])
			failed += 1
		else:
			print("[validate] OK %s (%s)" % [f, kind])
	print("[validate] %d file%s, %d failed" % [files.size(), "" if files.size() == 1 else "s", failed])
	quit(1 if failed > 0 else 0)
