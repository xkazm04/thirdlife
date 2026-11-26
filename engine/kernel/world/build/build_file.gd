extends RefCounted
## WP1: the saved Home (tl.build/1, contracts/BUILD.md). A directory (the exe's is user://home) holds
##   build.json    {"v":1,"seed":<Home seed>,"rev":<int>,"chunks":{"<cx>,<cz>":"<base64>"}}, keys in that order; a
##                 chunk's value is the base64 of its little-endian int32 pairs (chunk-local cell, code) sorted by cell,
##                 the cell lx + 96 * (lz + 96 * (y + 16)) (blocks.gd `chunk_pairs`); empty chunks are left out
##   edits.jsonl   the tl.edit/1 operations since the last compaction, one per line (edit_log.gd writes them)
## `save` compacts: build.json is written whole (temporary file, read back and compared, the old one kept as
## build.json.prev, rename: PlotFile.save's pattern) and edits.jsonl starts empty. `load` reads build.json, then
## replays edits.jsonl. Unknown keys are errors.

const Blocks := preload("res://kernel/world/build/blocks.gd")
const BUILD := "build.json"
const EDITS := "edits.jsonl"
const KEYS := ["v", "seed", "rev", "chunks"]


static func text_of(store: RefCounted, home_seed: int, rev: int) -> String:
	var parts := PackedStringArray()
	for ch: Vector2i in Blocks.sorted_ids(store.counts):
		var pairs: PackedInt32Array = store.chunk_pairs(ch)
		parts.append("%s:%s" % [JSON.stringify("%d,%d" % [ch.x, ch.y]), JSON.stringify(Marshalls.raw_to_base64(pairs.to_byte_array()))])
	return "{\"v\":1,\"seed\":%d,\"rev\":%d,\"chunks\":{%s}}\n" % [home_seed, rev, ",".join(parts)]


## Writes `dir`/build.json and empties `dir`/edits.jsonl. Returns "" or what went wrong (the files there are then
## untouched).
static func save(dir: String, store: RefCounted, home_seed: int, rev: int) -> String:
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK and not DirAccess.dir_exists_absolute(dir):
		return "cannot make %s (error %d)" % [dir, err]
	var path := dir.path_join(BUILD)
	var text := text_of(store, home_seed, rev)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()]
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(tmp) != text:
		DirAccess.remove_absolute(tmp)
		return "the temporary file %s did not read back whole; the build file was not touched" % tmp
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".prev")
	err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		return "could not rename %s to %s (error %d); the build file was not touched" % [tmp, path, err]
	var e := FileAccess.open(dir.path_join(EDITS), FileAccess.WRITE)
	if e == null:
		return "saved %s, but cannot empty %s (error %d)" % [path, EDITS, FileAccess.get_open_error()]
	e.close()
	return ""


## Reads `dir` into `store` (emptied first) and replays the journal through `edits_log` (edit_log.gd). Returns {"ok",
## "reason", "rev", "blocks", "replayed", "bad": [[line number, why], ...]}. No build.json: an empty Home (ok, rev 0).
## A build.json that is not well-formed, or whose seed is not `home_seed`, is refused and the store stays empty.
static func load_into(dir: String, store: RefCounted, edits_log: RefCounted, home_seed: int) -> Dictionary:
	store.clear()
	var out := {"ok": true, "reason": "", "rev": 0, "blocks": 0, "replayed": 0, "bad": []}
	var path := dir.path_join(BUILD)
	if FileAccess.file_exists(path):
		var why := _read(FileAccess.get_file_as_string(path), store, home_seed, out)
		if why != "":
			store.clear()
			out.ok = false
			out.reason = "%s: %s" % [path, why]
			return out
	out.blocks = store.total
	var edits := dir.path_join(EDITS)
	if FileAccess.file_exists(edits):
		var n := 0
		for raw: String in FileAccess.get_file_as_string(edits).split("\n"):
			n += 1
			if raw.strip_edges() == "":
				continue
			var json := JSON.new()
			var why := "not JSON" if json.parse(raw) != OK else str(edits_log.call("replay", json.data))
			if why == "":
				out.replayed += 1
			else:
				(out.bad as Array).append([n, why])
	return out


static func _read(text: String, store: RefCounted, home_seed: int, out: Dictionary) -> String:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return "not a JSON object"
	var d: Dictionary = json.data
	for k: Variant in d:
		if not KEYS.has(k):
			return "unknown key '%s'" % str(k)
	for k: String in KEYS:
		if not d.has(k):
			return "%s is missing" % k
	if typeof(d.v) != TYPE_FLOAT or int(d.v) != 1:
		return "v must be 1"
	if int(d.seed) != home_seed:
		return "seed %d is not this Home's (%d)" % [int(d.seed), home_seed]
	out.rev = int(d.rev)
	if typeof(d.chunks) != TYPE_DICTIONARY:
		return "chunks must be an object"
	for key: Variant in d.chunks:
		var xy := str(key).split(",")
		if xy.size() != 2 or not xy[0].is_valid_int() or not xy[1].is_valid_int() or typeof(d.chunks[key]) != TYPE_STRING:
			return "chunk %s is not \"<cx>,<cz>\": \"<base64>\"" % str(key)
		var ch := Vector2i(int(xy[0]), int(xy[1]))
		var pairs := Marshalls.base64_to_raw(str(d.chunks[key])).to_int32_array()
		if pairs.size() % 2 != 0:
			return "chunk %s holds an odd number of int32s" % str(key)
		for i: int in range(0, pairs.size(), 2):
			var local := pairs[i]
			if local < 0 or local >= Blocks.CHUNK * Blocks.CHUNK * Blocks.LEVELS:
				return "chunk %s: cell %d is outside the chunk" % [str(key), local]
			var cell := Blocks.pair_cell(ch, local)
			var c := pairs[i + 1]
			if Blocks.shape_of(c) < 1 or Blocks.shape_of(c) > 8 or Blocks.mat_of(c) < 1 or Blocks.mat_of(c) > 10 or c >> 13 != 0:
				return "chunk %s: code %d at %s is not a block" % [str(key), c, str(cell)]
			if not store.put(cell, c):
				return "chunk %s: %s at %s" % [str(key), store.refusal(cell), str(cell)]
	return ""
