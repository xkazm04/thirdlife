extends SceneTree
# K3 round 3 proof: the FJamInput stream the pack sent to the human's skater (bot_match_hand's result, metrics.raw.inputs),
# fed straight into a fresh RinkCore (no shell, no camera, no keys), must give the core hash the pack's run reported, frame
# for frame (metrics.raw.hashes). Proves the shell drives thirdjam's core with exactly the input it reports.
#   godot --headless --path engine --script <this file> -- --report=<bot report.json> [--difficulty=pro] [--seed=1]
func _init() -> void:
	var rep := ""; var diff := "pro"; var seed := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="): rep = a.substr(9)
		elif a.begins_with("--difficulty="): diff = a.substr(13)
		elif a.begins_with("--seed="): seed = int(a.substr(7))
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(rep))
	var raw: Dictionary = d["bot"]["result"]["metrics"]["raw"]
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	var err: String = core.load_cartridge(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://packs/hokej/data/hockey.regular.cartridge.json")))
	if err != "": print("FAIL  core replay: ", err); quit(2); return
	core.set_difficulty(diff); core.set_human_mode("input"); core.reset(seed)
	var first := -1; var n := 0
	for i in raw["inputs"].size():
		var o: Dictionary = {}
		var src: Dictionary = raw["inputs"][i]
		for k in src:
			var v = src[k]
			if v is Array: o[k] = Vector2(float(v[0]) / 1125899906842624.0, float(v[1]) / 1125899906842624.0)   # the pack's EXACT (2^50)
			elif k.begins_with("b"): o[k] = int(v) != 0
			else: o[k] = v
		core.set_human_input(o)
		core.step()
		n += 1
		if core.state_hash_hex() != String(raw["hashes"][i]) and first < 0: first = i + 1
	if first < 0: print("PASS  core replay: %d frames, the core's hash equals the pack's on every frame (last %s)" % [n, core.state_hash_hex()])
	else: print("FAIL  core replay: first differing frame %d of %d" % [first, n])
	quit(0 if first < 0 else 1)
