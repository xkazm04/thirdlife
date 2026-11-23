extends SceneTree
# Rink core: the reference trace of a RECORDED per-frame raw human input stream (lane K3's proof). The stream is a JSON list,
# one entry per frame, each what RinkCore.set_raw_input takes (Vector2 values as [x, y] lists). The core runs thirdjam's
# regular match in human mode "raw" (GAMEMODE.md) and writes one line per frame:
#   f=<frame after the step> hash=<core state hash> score=<a>:<b> carrier=<i> in=<the FJamInput the human's skater got>
# The same stream, seed and difficulty give the same lines every time (selftest rink.rawhand checks the determinism).
#   godot --headless --path engine --script res://cores/rink/tools/rink_rawtrace.gd -- --stream=<file.json> --out=<file.txt>
#         [--seed=1] [--difficulty=pro] [--cartridge=<path to a cartridge json>]
#   ... -- --write-sample=<file.json> [--frames=3600]   writes the scripted hand of rink_rawhand.gd as a stream file
const Hand := preload("res://cores/rink/tools/rink_hand.gd")


func _v(x: Variant) -> Variant:
	if typeof(x) == TYPE_ARRAY and (x as Array).size() == 2:
		return Vector2(float(x[0]), float(x[1]))
	return x


func _flags(d: Dictionary) -> String:
	var on: PackedStringArray = []
	for k in d.keys():
		if typeof(d[k]) == TYPE_BOOL and d[k]:
			on.append(str(k).substr(1))
	var m: Vector2 = d["Move"]
	var st: Vector2 = d["Stick"]
	return "move=%.4f,%.4f stick=%.4f,%.4f %s" % [m.x, m.y, st.x, st.y, "+".join(on)]


func _init() -> void:
	var stream_path := ""
	var out_path := ""
	var sample := ""
	var seed := 1
	var frames := 3600
	var difficulty := "pro"
	var cart := ProjectSettings.globalize_path("res://cores/rink/native/content/Cartridges/hockey.regular.cartridge.json")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stream="): stream_path = a.substr(9)
		elif a.begins_with("--out="): out_path = a.substr(6)
		elif a.begins_with("--write-sample="): sample = a.substr(15)
		elif a.begins_with("--seed="): seed = int(a.substr(7))
		elif a.begins_with("--frames="): frames = int(a.substr(9))
		elif a.begins_with("--difficulty="): difficulty = a.substr(13)
		elif a.begins_with("--cartridge="): cart = a.substr(12)
	if not ClassDB.class_exists("RinkCore"):
		print("RAWTRACE FAIL RinkCore is not registered")
		quit(2)
		return
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	var err: String = core.load_cartridge(FileAccess.get_file_as_string(cart))
	if err != "":
		print("RAWTRACE FAIL cartridge: ", err)
		quit(2)
		return
	core.set_difficulty(difficulty)
	core.set_human_mode("raw")
	core.reset(seed)
	if sample != "":
		# the scripted hand of rink_rawhand.gd, recorded as it is fed (it reads the snapshot, so it is recorded while it plays)
		var list: Array = []
		var s: Dictionary = core.snapshot()
		for f in frames:
			var r: Dictionary = Hand.raw_at(f, s)
			var e := {}
			for k in r.keys():
				e[k] = [r[k].x, r[k].y] if typeof(r[k]) == TYPE_VECTOR2 else (Array(r[k]) if typeof(r[k]) == TYPE_PACKED_STRING_ARRAY else r[k])
			list.append(e)
			core.set_raw_input(r)
			if not core.step():
				break
			s = core.snapshot()
		var fw := FileAccess.open(sample, FileAccess.WRITE)
		fw.store_string(JSON.stringify(list))
		fw.close()
		print("RAWTRACE sample frames=%d hash=%s -> %s" % [list.size(), core.state_hash_hex(), sample])
		quit(0)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(stream_path))
	if typeof(parsed) != TYPE_ARRAY:
		print("RAWTRACE FAIL --stream is not a JSON list: ", stream_path)
		quit(2)
		return
	var lines: PackedStringArray = []
	for entry in parsed:
		var raw := {}
		for k in (entry as Dictionary).keys():
			var v: Variant = entry[k]
			if k == "Down" or k == "Pressed":
				raw[k] = PackedStringArray(v)
			else:
				raw[k] = _v(v)
		core.set_raw_input(raw)
		core.step()   # false once the match is over: the line is still written (one line per stream entry, the state unchanged)
		var s: Dictionary = core.snapshot()
		lines.append("f=%d hash=%s score=%d:%d carrier=%d in=%s" % [int(s["Frame"]), core.state_hash_hex(), int(s["Score"][0]), int(s["Score"][1]),
			int(s["Carrier"]), _flags(core.last_human_input())])
	if out_path != "":
		var fo := FileAccess.open(out_path, FileAccess.WRITE)
		fo.store_string("\n".join(lines) + "\n")
		fo.close()
	else:
		for l in lines:
			print(l)
	print("RAWTRACE done frames=%d hash=%s" % [lines.size(), core.state_hash_hex()])
	quit(0)
