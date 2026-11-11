extends RefCounted
## The files of a world, moved out of world.gd and pack.gd (P5: neither may grow): the hash of a pack directory and
## the world file (tl.world/1). No global class name is used here.


## SHA-256 over the pack's files (relative path and bytes, sorted): tells a world file that the pack changed.
static func dir_hash(dir: String) -> String:
	var files: PackedStringArray = PackedStringArray()
	list_files(dir, "", files)
	files.sort()
	var hc: HashingContext = HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	for rel: String in files:
		hc.update(rel.to_utf8_buffer())
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(dir + "/" + rel)
		if not bytes.is_empty():
			hc.update(bytes)
	return hc.finish().hex_encode()


static func list_files(dir: String, rel: String, out: PackedStringArray) -> void:
	var d: DirAccess = DirAccess.open(dir + ("/" + rel if not rel.is_empty() else ""))
	if d == null:
		return
	for f: String in d.get_files():
		if not f.ends_with(".uid") and not f.ends_with(".import"):
			out.append(rel + "/" + f if not rel.is_empty() else f)
	for sub: String in d.get_directories():
		if not sub.begins_with("."):
			list_files(dir, rel + "/" + sub if not rel.is_empty() else sub, out)


## Writes the world file whole to a temporary file, reads it back, keeps the revision before it as `<file>.prev`
## and renames. Returns "" or what went wrong (the file that was there is then untouched).
static func save(w: Node, path: String, records: Array) -> String:
	var opts: Dictionary = w.get("opts")
	var walk: Dictionary = w.get("walk")
	var world_in: Dictionary = w.get("world_in")
	var sched: RefCounted = w.get("sched")
	var player_pos: Vector3 = w.get("player_pos")
	var rev: int = 0
	var name_: String = str(opts.get("name", walk.get("name", world_in.get("name", "world"))))
	if FileAccess.file_exists(path):
		var json: JSON = JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and typeof(json.data) == TYPE_DICTIONARY:
			rev = int((json.data as Dictionary).get("rev", 0))
			if not opts.has("name"):
				name_ = str((json.data as Dictionary).get("name", name_))
		else:
			return "the world file at %s is not readable JSON; it was not overwritten (move it away first)" % path
	elif not world_in.is_empty():
		rev = int(world_in.get("rev", 0))
	var stage_id: String = ""
	if sched != null and int(sched.get("stage")) >= 0:
		stage_id = str(((sched.get("plots") as Array)[int(sched.get("stage"))] as Dictionary)["id"])
	elif not world_in.is_empty() and typeof(world_in.get("player")) == TYPE_DICTIONARY:
		stage_id = str((world_in["player"] as Dictionary).get("plot", ""))
	var doc: Dictionary = {"schema": "tl.world/1", "name": name_, "rev": rev + 1,
		"device": OS.get_environment("COMPUTERNAME") if OS.has_environment("COMPUTERNAME") else OS.get_name(),
		"seed": int(opts.get("seed", world_in.get("seed", 1))), "plots": records,
		"player": {"plot": stage_id, "position": [player_pos.x, player_pos.y, player_pos.z]}}
	var text: String = JSON.stringify(doc, "  ") + "\n"
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()]
	f.store_string(text)
	f.close()
	var back: JSON = JSON.new()
	if FileAccess.get_file_as_string(tmp) != text or back.parse(text) != OK:
		DirAccess.remove_absolute(tmp)
		return "the temporary file %s did not read back whole; the world file was not touched" % tmp
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".prev")
	var err: int = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		return "could not rename %s to %s (error %d); the world file was not touched" % [tmp, path, err]
	print("[tl] world saved: %s rev %d, %d plot(s)" % [path, rev + 1, records.size()])
	return ""
