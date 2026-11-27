extends RefCounted
## WP1 + SEAM: the saved Home (tl.build/1, /2, /3 and, since the M6 seam, /4, contracts/BUILD.md). A directory (the exe's is user://home) holds
##   build.json    {"v":1,"seed":<Home seed>,"rev":<int>,"chunks":{"<cx>,<cz>":"<base64>"}}, keys in that order; a
##                 chunk's value is the base64 of its little-endian int32 pairs (chunk-local cell, code) sorted by cell,
##                 the cell lx + 96 * (lz + 96 * (y + 16)) (blocks.gd `chunk_pairs`); empty chunks are left out.
##                 tl.build/2 is the same with "v":2 and, after "chunks", the layers' keys "land", "paint", "pieces";
##                 tl.build/3 adds "water", "paths", "plants" after them, tl.build/4 (M6) "zones", "rules" after those
##                 (each key only when not empty), in that order
##   edits.jsonl   the tl.edit/1 operations since the last compaction, one per line (edit_log.gd writes them)
## Every layer (BUILD.md "Layers") saves its own keys (`save_part`) and reads them back (`load_part`). The file is
## written at the lowest version that holds every key a layer saves (KEY_V), so a Home of blocks only is v1 byte for
## byte as M1 wrote it. Every op kind names the version it needs (OP_V); `mark_v` raises a file's version (its content
## unchanged) before the log journals the first op of a higher one. A reader refuses a version above MAX_V and never
## overwrites that file (the owner saves only after a load that was ok).
## `save` compacts: build.json is written whole (temporary file, read back and compared, the old one kept as
## build.json.prev, rename: PlotFile.save's pattern) and edits.jsonl starts empty. `load` reads build.json, then
## replays edits.jsonl. Unknown keys are errors.

const BUILD := "build.json"
const EDITS := "edits.jsonl"
const KEYS := ["v", "seed", "rev", "chunks"]                                    # tl.build/1
const KEYS_V2 := ["v", "seed", "rev", "chunks", "land", "paint", "pieces"]      # tl.build/2
const KEYS_V3 := ["v", "seed", "rev", "chunks", "land", "paint", "pieces", "water", "paths", "plants"]   # tl.build/3
const KEYS_V4 := ["v", "seed", "rev", "chunks", "land", "paint", "pieces", "water", "paths", "plants", "zones", "rules"]   # tl.build/4 (M6)
const KEYS_OF := {1: KEYS, 2: KEYS_V2, 3: KEYS_V3, 4: KEYS_V4}
const MAX_V := 4                         # the highest version this exe reads and writes
## The version each saved key needs.
const KEY_V := {"chunks": 1, "land": 2, "paint": 2, "pieces": 2, "water": 3, "paths": 3, "plants": 3, "zones": 4, "rules": 4}
## The version each op kind needs in the journal (contracts/BUILD.md "Every operation kind names the file version it
## needs"). An op kind not named here needs MAX_V.
const OP_V := {"place": 1, "remove": 1, "land": 2, "paint": 2, "put": 2, "lift": 2,
	"flood": 3, "drain": 3, "path": 3, "unpath": 3, "plant": 3, "zone": 4, "unzone": 4, "rule": 4, "unrule": 4}


## The file version a journal line of op kind `op` needs.
static func version_of(op: String) -> int:
	return int(OP_V.get(op, MAX_V))


## The build file's text for `layers` and its version: {"text", "v"}. A key no version names is left out (and said).
static func text_of(layers: Array, home_seed: int, rev: int) -> Dictionary:
	var parts := {}
	for l: RefCounted in layers:
		var p: Dictionary = l.save_part()
		for k: Variant in p:
			parts[k] = p[k]
	var v := 1
	for k: Variant in parts:
		if not KEY_V.has(k):
			push_error("build_file: a layer saves the key '%s', which no tl.build version has; it is not written" % str(k))
			continue
		v = maxi(v, int(KEY_V[k]))
	var text := "{\"v\":%d,\"seed\":%d,\"rev\":%d" % [v, home_seed, rev]
	for k: String in (KEYS_OF[MAX_V] as Array).slice(3):
		if parts.has(k):
			text += ",%s:%s" % [JSON.stringify(k), JSON.stringify(parts[k], "", false)]
	return {"text": text + "}\n", "v": v}
## Writes `dir`/build.json from `text` and empties `dir`/edits.jsonl. Returns "" or what went wrong (the files there are
## then untouched).
static func save(dir: String, text: String) -> String:
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK and not DirAccess.dir_exists_absolute(dir):
		return "cannot make %s (error %d)" % [dir, err]
	var path := dir.path_join(BUILD)
	var why := _write_whole(path, text)
	if why != "":
		return why
	var e := FileAccess.open(dir.path_join(EDITS), FileAccess.WRITE)
	if e == null:
		return "saved %s, but cannot empty %s (error %d)" % [path, EDITS, FileAccess.get_open_error()]
	e.close()
	return ""


static func _write_whole(path: String, text: String) -> String:
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
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		return "could not rename %s to %s (error %d); the build file was not touched" % [tmp, path, err]
	return ""


## Makes `dir`/build.json tl.build/`n` with its content unchanged (its journal stays valid): a file of a lower version
## gets "v":n, no file becomes an empty Home of version n and rev 0, a file of version n or higher is left alone.
## Returns "" or what went wrong.
static func mark_v(dir: String, home_seed: int, n: int) -> String:
	var path := dir.path_join(BUILD)
	if not FileAccess.file_exists(path):
		var err := DirAccess.make_dir_recursive_absolute(dir)
		if err != OK and not DirAccess.dir_exists_absolute(dir):
			return "cannot make %s (error %d)" % [dir, err]
		return _write_whole(path, "{\"v\":%d,\"seed\":%d,\"rev\":0,\"chunks\":{}}\n" % [n, home_seed])
	var text := FileAccess.get_file_as_string(path)
	var was := 0
	for k: int in range(1, MAX_V + 1):
		if text.begins_with("{\"v\":%d," % k):
			was = k
	if was == 0:
		return "%s is not a build file this exe wrote" % path
	if was >= n:
		return ""
	return _write_whole(path, ("{\"v\":%d," % n) + text.substr(("{\"v\":%d," % was).length()))


## M2-M4's name: `mark_v(dir, home_seed, 2)`.
static func mark_v2(dir: String, home_seed: int) -> String:
	return mark_v(dir, home_seed, 2)


## Reads `dir` into `layers` (each emptied first) and replays the journal through `edits_log` (edit_log.gd). Returns
## {"ok", "reason", "v", "rev", "blocks", "replayed", "bad": [[line number, why], ...]}. No build.json: an empty Home
## (ok, v 0, rev 0). A build.json that is not well-formed, whose version is above `max_v` (MAX_V; a case passes a lower
## one to stand for an older exe), or whose seed is not `home_seed`, is refused and every layer stays empty.
static func load_into(dir: String, layers: Array, edits_log: RefCounted, home_seed: int, max_v := MAX_V) -> Dictionary:
	for l: RefCounted in layers:
		l.clear()
	var out := {"ok": true, "reason": "", "v": 0, "rev": 0, "blocks": 0, "replayed": 0, "bad": []}
	var path := dir.path_join(BUILD)
	if FileAccess.file_exists(path):
		var why := _read(FileAccess.get_file_as_string(path), layers, home_seed, out, max_v)
		if why != "":
			for l: RefCounted in layers:
				l.clear()
			out.ok = false
			out.reason = "%s: %s" % [path, why]
			return out
	for l: RefCounted in layers:
		if l.get("id") == "blocks":
			out.blocks = l.size()
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


static func _read(text: String, layers: Array, home_seed: int, out: Dictionary, max_v := MAX_V) -> String:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return "not a JSON object"
	var d: Dictionary = json.data
	var v := int(d.v) if typeof(d.get("v")) == TYPE_FLOAT and float(d.v) == floorf(float(d.v)) and absf(float(d.v)) < 1e6 else 0
	if v > maxi(1, max_v):
		return "tl.build/%d is newer than this exe reads (1..%d); it is left as it is" % [v, max_v]
	var keys: Array = KEYS_OF.get(v, KEYS)
	for k: Variant in d:
		if not keys.has(k):
			return "unknown key '%s'" % str(k)
	for k: String in KEYS:
		if not d.has(k):
			return "%s is missing" % k
	if v < 1:
		return "v must be 1..%d" % max_v
	if int(d.seed) != home_seed:
		return "seed %d is not this Home's (%d)" % [int(d.seed), home_seed]
	out.v = v
	out.rev = int(d.rev)
	for l: RefCounted in layers:
		var why := str(l.load_part(d))
		if why != "":
			return why
	return ""
