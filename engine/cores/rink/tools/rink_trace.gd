extends SceneTree
# thirdjam's tournament commandlet run inside Godot through the RinkCore extension (engine/tools/rink.sh gdtrace).
#   godot --headless --path engine --script res://cores/rink/tools/rink_trace.gd -- --content=<dir> [--out=<file>] -cartridge=... -seeds=1-10 ...
# Prints every log line the commandlet writes as "RINKLOG <line>" (or, with --out=, writes the LogJamAI Display lines to that file:
# Godot's print is too slow for 100k-line traces), then "RINKEXIT <code>"; quits with the commandlet's code.

func _init() -> void:
	if not ClassDB.class_exists("RinkCore"):
		print("RINKEXIT 2 (RinkCore is not registered: the extension did not load)")
		quit(2)
		return
	var content := ""
	var out := ""
	var params: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--content="):
			content = a.substr(10)
		elif a.begins_with("--out="):
			out = a.substr(6)
		else:
			params.append(a)
	var lines: PackedStringArray = ClassDB.class_call_static("RinkCore", "run_tournament", content, " ".join(params))
	var code := 2
	var f: FileAccess = FileAccess.open(out, FileAccess.WRITE) if out != "" else null
	var prefix := "LogJamAI: Display: "
	for l in lines:
		if l.begins_with("RINKEXIT "):
			code = int(l.substr(9))
		elif f != null:
			if l.begins_with(prefix):
				f.store_string(l.substr(prefix.length()) + "
")
		else:
			print("RINKLOG ", l)
	if f != null:
		f.close()
	print("RINKEXIT ", code, " tree=", ClassDB.class_call_static("RinkCore", "source_tree"))
	quit(code)
