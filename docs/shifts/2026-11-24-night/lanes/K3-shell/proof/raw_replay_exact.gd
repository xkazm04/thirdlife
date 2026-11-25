extends SceneTree
# K3 round 5: the pack's raw device stream (pack_raw_stream.json, as rawtrace_compare.py writes it) into a fresh RinkCore in raw
# mode, comparing EXACTLY, frame by frame, the FJamInput the glue makes (last_human_input) and the core hash with the pack's own
# (the bot report's metrics.raw.inputs, x 2^50 integers, and metrics.raw.hashes). Prints the first frame where either differs.
#   godot --headless --path engine --script <this file> -- --stream=<pack_raw_stream.json> --report=<bot report.json>
const E: float = 1125899906842624.0
func _init() -> void:
	var sp := ""; var rp := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stream="): sp = a.substr(9)
		elif a.begins_with("--report="): rp = a.substr(9)
	var stream: Array = JSON.parse_string(FileAccess.get_file_as_string(sp))
	var raw: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(rp)) as Dictionary)["bot"]["result"]["metrics"]["raw"]
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	core.load_cartridge(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://packs/hokej/data/hockey.regular.cartridge.json")))
	core.set_difficulty("pro"); core.set_human_mode("raw"); core.reset(1)
	var first_in := -1; var first_hash := -1; var what := ""
	for i in stream.size():
		var e: Dictionary = stream[i]; var r := {}
		for k in e:
			var v = e[k]
			if k == "Down" or k == "Pressed": r[k] = PackedStringArray(v)
			elif v is Array: r[k] = Vector2(float(v[0]), float(v[1]))
			else: r[k] = v
		core.set_raw_input(r)
		core.step()
		var got: Dictionary = core.last_human_input()
		var want: Dictionary = raw["inputs"][i]
		if first_in < 0:
			for k in want:
				var w = want[k]; var g = got.get(k)
				var same: bool = (g is Vector2 and w is Array and int((g as Vector2).x * E) == int(w[0]) and int((g as Vector2).y * E) == int(w[1])) or (g is bool and int(w) == (1 if g else 0)) or (not (g is Vector2) and not (g is bool) and g == w)
				if not same:
					first_in = i + 1; what = "%s: core %s, pack %s" % [k, str(g), str(w)]; break
		if first_hash < 0 and core.state_hash_hex() != String(raw["hashes"][i]): first_hash = i + 1
		if first_in >= 0 and first_hash >= 0: break
	print("EXACT first input difference: %d (%s); first hash difference: %d" % [first_in, what, first_hash])
	quit(0)
