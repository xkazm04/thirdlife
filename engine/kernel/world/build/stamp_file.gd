extends RefCounted
## M3 (spark world-sandbox, 26 Nov 2026): stamps, `tl.stamp/1` (contracts/BUILD.md): a box of blocks and pieces saved to
## be placed again. Static functions; no state.
##   {"schema":"tl.stamp/1", "name":"<title>", "size":[w,h,d],
##    "blocks":[[x,y,z,code], ...],      relative to the box's low corner, sorted by z, x, y
##    "pieces":[{"at":[x,y,z], "part", "params"?, "rot", "seed"}, ...]}    sorted by at (z, x, y)
## `blocks` and `pieces` are left out when empty (one of them is not). A piece is in a stamp when its anchor and its whole
## footprint are in the box. Placing at cell `at` with `r` quarter turns: every relative cell is turned about +y in the
## box (the blocks' rot rule: r = 1 turns -z to -x) and moved to `at`, `r` is added to every block's and piece's rot,
## and the whole is ONE batch of place and put ops (one undo).
## Files: user://home/stamps/<slug>.json (written whole); shared as an item of kind `stamp`, tier data
## (docs/SHARING.md): `stamp.json` + `item.json` in a `.tlitem` (export_item / import_item, kernel/share/item.gd).

const Blocks := preload("res://kernel/world/build/blocks.gd")
const BlocksLayer := preload("res://kernel/world/build/blocks_layer.gd")
const PiecesLayer := preload("res://kernel/world/build/pieces_layer.gd")
const Catalog := preload("res://kernel/world/build/piece_catalog.gd")
const OpUtil := preload("res://kernel/world/build/op_util.gd")
const Item := preload("res://kernel/share/item.gd")
const Zip := preload("res://kernel/share/tlzip.gd")
const SCHEMA := "tl.stamp/1"
const KEYS := ["schema", "name", "size", "blocks", "pieces"]
const SIDE_MAX := 128                   # home_build.gd REGION_MAX
const NAME_MAX := 60
const FILE := "stamp.json"


## The stamp of the cell box `lo`..`hi` (inclusive) of the Home `build` (home_build.gd), called `name`. Returns
## {"ok", "reason", "stamp", "left_out"} (left_out: pieces anchored in the box whose footprint leaves it).
static func from_region(build: RefCounted, lo: Vector3i, hi: Vector3i, name: String) -> Dictionary:
	var reg: Dictionary = build.read_region(lo, hi)
	if reg.has("error"):
		return {"ok": false, "reason": str(reg.error), "stamp": {}, "left_out": 0}
	var blocks := []
	for b: Array in reg.get("blocks", []):
		blocks.append([int(b[0]) - lo.x, int(b[1]) - lo.y, int(b[2]) - lo.z, int(b[3])])
	var pieces := []
	var left := 0
	var layer: RefCounted = build.layer("pieces")
	for p: Dictionary in reg.get("pieces", []):
		var r: Dictionary = layer.pieces.get(OpUtil.cell(p.at), {})
		var plo: Vector3i = r.get("lo", lo)
		var phi: Vector3i = r.get("hi", hi)
		if plo.x < lo.x or plo.y < lo.y or plo.z < lo.z or phi.x > hi.x or phi.y > hi.y or phi.z > hi.z:
			left += 1
			continue
		var q := p.duplicate(true)
		q.at = [int(p.at[0]) - lo.x, int(p.at[1]) - lo.y, int(p.at[2]) - lo.z]
		pieces.append(q)
	var size := hi - lo + Vector3i.ONE
	var doc := {"schema": SCHEMA, "name": name, "size": [size.x, size.y, size.z]}
	if not blocks.is_empty():
		doc["blocks"] = blocks
	if not pieces.is_empty():
		doc["pieces"] = pieces
	if blocks.is_empty() and pieces.is_empty():
		return {"ok": false, "reason": "the box holds nothing to stamp", "stamp": {}, "left_out": left}
	return {"ok": true, "reason": "", "stamp": doc, "left_out": left}


## "" when `d` is a well-formed tl.stamp/1, else the first thing wrong with it.
static func validate(d: Variant) -> String:
	if typeof(d) != TYPE_DICTIONARY:
		return "a stamp is a JSON object"
	for k: Variant in d:
		if not KEYS.has(k):
			return "unknown key '%s'" % str(k)
	if str(d.get("schema", "")) != SCHEMA:
		return "schema must be \"%s\"" % SCHEMA
	if typeof(d.get("name")) != TYPE_STRING or str(d.name).strip_edges().is_empty() or str(d.name).length() > NAME_MAX:
		return "name must be a title of 1 to %d characters" % NAME_MAX
	var sz: Variant = d.get("size")
	if typeof(sz) != TYPE_ARRAY or (sz as Array).size() != 3:
		return "size must be [w, h, d]"
	for q: Variant in sz:
		if OpUtil.int_of(q) == null or int(q) < 1 or int(q) > SIDE_MAX:
			return "size: every side is 1..%d cells" % SIDE_MAX
	var size := Vector3i(int(sz[0]), int(sz[1]), int(sz[2]))
	var n := 0
	var last := Vector3i(0, 0, -1)
	if d.has("blocks"):
		if typeof(d.blocks) != TYPE_ARRAY or (d.blocks as Array).is_empty():
			return "blocks must be a non-empty list (left out when empty)"
		for b: Variant in d.blocks:
			if typeof(b) != TYPE_ARRAY or (b as Array).size() != 4:
				return "blocks: every entry is [x, y, z, code]"
			for q: Variant in b:
				if OpUtil.int_of(q) == null:
					return "blocks: every entry holds four integers"
			var c := Vector3i(int(b[0]), int(b[1]), int(b[2]))
			if not _inside(c, size):
				return "blocks: %s is outside the size" % str(c)
			if not _after(last, c):
				return "blocks: %s is not after %s (sorted by z, x, y, each cell once)" % [str(c), str(last)]
			last = c
			var why := BlocksLayer.check_op(BlocksLayer.record("place", c, int(b[3])))
			if why == "" and BlocksLayer.code_of(BlocksLayer.record("place", c, int(b[3]))) != int(b[3]):
				why = "code %d is not a block" % int(b[3])
			if why != "":
				return "blocks: %s at %s" % [why, str(c)]
			n += 1
	if d.has("pieces"):
		if typeof(d.pieces) != TYPE_ARRAY or (d.pieces as Array).is_empty():
			return "pieces must be a non-empty list (left out when empty)"
		var check: RefCounted = PiecesLayer.new({}, true)
		last = Vector3i(0, 0, -1)
		for p: Variant in d.pieces:
			if typeof(p) != TYPE_DICTIONARY:
				return "pieces: every entry is an object"
			for k: Variant in p:
				if not PiecesLayer.SAVED.has(k):
					return "pieces: unknown key '%s'" % str(k)
			var op: Dictionary = (p as Dictionary).duplicate()
			op["op"] = "put"
			var why: String = check.malformed(op)
			if why == "" and not op.has("seed"):
				why = "seed is missing"
			if why != "":
				return "pieces: " + why
			var c := OpUtil.cell(op.at)
			if not _inside(c, size):
				return "pieces: %s is outside the size" % str(c)
			if not _after(last, c):
				return "pieces: %s is not after %s (sorted by z, x, y, one per cell)" % [str(c), str(last)]
			last = c
			n += 1
	return "" if n > 0 else "a stamp holds at least one block or piece"


static func _inside(c: Vector3i, size: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.z >= 0 and c.x < size.x and c.y < size.y and c.z < size.z


static func _after(a: Vector3i, b: Vector3i) -> bool:
	return b.z > a.z or (b.z == a.z and (b.x > a.x or (b.x == a.x and b.y > a.y)))


## Relative cell `c` of a box of `size` turned `r` quarter turns about +y (in the turned box, which is [d, h, w] for an
## odd r): r 1 maps (x, z) to (z, w - 1 - x), so a step toward -z becomes a step toward -x, as a block's rot.
static func turn_cell(c: Vector3i, size: Vector3i, r: int) -> Vector3i:
	match posmod(r, 4):
		1: return Vector3i(c.z, c.y, size.x - 1 - c.x)
		2: return Vector3i(size.x - 1 - c.x, c.y, size.z - 1 - c.z)
		3: return Vector3i(size.z - 1 - c.z, c.y, c.x)
	return c


static func turned_size(size: Vector3i, r: int) -> Vector3i:
	return Vector3i(size.z, size.y, size.x) if posmod(r, 2) == 1 else size


## The place and put ops that set stamp `d` down with its turned box's low corner at `at`, turned `r`.
static func ops(d: Dictionary, at: Vector3i, r: int) -> Array:
	var size := Vector3i(int(d.size[0]), int(d.size[1]), int(d.size[2]))
	var out := []
	for b: Array in d.get("blocks", []):
		var c: int = int(b[3])
		var cell := at + turn_cell(Vector3i(int(b[0]), int(b[1]), int(b[2])), size, r)
		var turned := Blocks.code(Blocks.shape_of(c), Blocks.mat_of(c), (Blocks.rot_of(c) + r) % 4, Blocks.flip_of(c))
		out.append(BlocksLayer.record("place", cell, turned))
	for p: Dictionary in d.get("pieces", []):
		var cell := at + turn_cell(OpUtil.cell(p.at), size, r)
		var op := {"v": 1, "op": "put", "at": [cell.x, cell.y, cell.z], "part": str(p.part)}
		if p.has("params"):
			op["params"] = (p.params as Dictionary).duplicate(true)
		op["rot"] = (int(p.rot) + r) % 4
		op["seed"] = int(p.seed)
		out.append(op)
	return out


## The stamp's text: keys in the contract's order, one line.
static func text_of(d: Dictionary) -> String:
	var parts := PackedStringArray()
	for k: String in KEYS:
		if d.has(k):
			parts.append("%s:%s" % [JSON.stringify(k), JSON.stringify(d[k], "", false)])
	return "{%s}\n" % ",".join(parts)


## "stamp-3" of "Stamp 3": lower case letters, digits and dashes.
static func slug_of(name: String) -> String:
	var out := ""
	for ch: String in name.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "-"
	while out.contains("--"):
		out = out.replace("--", "-")
	out = out.trim_prefix("-").trim_suffix("-")
	return out if out != "" else "stamp"


## The saved stamps of `dir` (the stamps folder): [{"slug", "path", "stamp"}] sorted by slug; unreadable files are
## listed in `bad` ([[file, why]]).
static func list(dir: String) -> Dictionary:
	var out := []
	var bad := []
	var da := DirAccess.open(dir)
	if da == null:
		return {"stamps": out, "bad": bad}
	var names: Array = Array(da.get_files())
	names.sort()
	for f: String in names:
		if f.get_extension() != "json":
			continue
		var j := JSON.new()
		var path := dir.path_join(f)
		if j.parse(FileAccess.get_file_as_string(path)) != OK:
			bad.append([f, "not JSON"])
			continue
		var why := validate(j.data)
		if why != "":
			bad.append([f, why])
			continue
		out.append({"slug": f.get_basename(), "path": path, "stamp": _ints(j.data)})
	return {"stamps": out, "bad": bad}


## Writes stamp `d` to `dir`/<slug>.json, a new slug when that one is taken by other bytes. Returns {"ok", "reason", "path"}.
static func save(dir: String, d: Dictionary) -> Dictionary:
	var why := validate(d)
	if why != "":
		return {"ok": false, "reason": why, "path": ""}
	DirAccess.make_dir_recursive_absolute(dir)
	var text := text_of(d)
	var slug := slug_of(str(d.name))
	var path := dir.path_join(slug + ".json")
	var k := 2
	while FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) != text:
		path = dir.path_join("%s-%d.json" % [slug, k])
		k += 1
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return {"ok": false, "reason": "cannot write %s (error %d)" % [path, FileAccess.get_open_error()], "path": ""}
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(path + ".tmp") != text:
		return {"ok": false, "reason": "%s did not read back whole" % path, "path": ""}
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(path + ".tmp", path)
	return {"ok": true, "reason": "", "path": path}


## The next free default name: "Stamp N" with N one more than the stamps there.
static func next_name(dir: String) -> String:
	var have := {}
	for s: Dictionary in list(dir).stamps:
		have[str(s.stamp.name)] = true
	var n := 1
	while have.has("Stamp %d" % n):
		n += 1
	return "Stamp %d" % n


# ------------------------------------------------------------------ sharing (an item of kind stamp)
## The item's files: stamp.json and its card (kernel/share/item.gd build_card, kind stamp). {"ok", "reason", "files"}.
static func item_files(d: Dictionary) -> Dictionary:
	var why := validate(d)
	if why != "":
		return {"ok": false, "reason": why, "files": {}}
	var files := {FILE: text_of(d).to_utf8_buffer()}
	var made: Dictionary = Item.build_card(files, {"kind": "stamp", "title": str(d.name),
		"summary": "A Third Life Home build: %d blocks, %d pieces." % [(d.get("blocks", []) as Array).size(), (d.get("pieces", []) as Array).size()]})
	if not bool(made.ok):
		return {"ok": false, "reason": "; ".join(PackedStringArray(made.errors)), "files": {}}
	files[Item.CARD] = Item.card_text(made.card).to_utf8_buffer()
	return {"ok": true, "reason": "", "files": files}


## Writes stamp `d` as a .tlitem at `path`. Returns {"ok", "reason", "bytes"}.
static func export_item(d: Dictionary, path: String) -> Dictionary:
	var it := item_files(d)
	if not bool(it.ok):
		return {"ok": false, "reason": it.reason, "bytes": 0}
	var built: Dictionary = Zip.build(it.files)
	if not bool(built.ok):
		return {"ok": false, "reason": str(built.error), "bytes": 0}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "reason": "cannot write %s (error %d)" % [path, FileAccess.get_open_error()], "bytes": 0}
	f.store_buffer(built.bytes)
	f.close()
	return {"ok": true, "reason": "", "bytes": (built.bytes as PackedByteArray).size()}


## Reads a .tlitem as hostile input: the archive, the card (item.gd `check`: hash, tier), kind stamp and tier data, only
## stamp.json and the card (and preview pictures), the stamp valid. Returns {"ok", "reason", "stamp"}.
static func import_item(path: String) -> Dictionary:
	var rd: Dictionary = Item.read_archive(path)
	if not bool(rd.ok):
		return {"ok": false, "reason": "; ".join(PackedStringArray(rd.errors)), "stamp": {}}
	var files: Dictionary = rd.files
	var ck: Dictionary = Item.check(files)
	if not bool(ck.ok):
		var all: Array = (ck.errors as Array) + (ck.mismatches as Array)
		return {"ok": false, "reason": str(all[0]) if not all.is_empty() else "the item does not check", "stamp": {}}
	if str(ck.card.kind) != "stamp" or str(ck.card.tier) != "data":
		return {"ok": false, "reason": "a %s item (%s), not a stamp" % [str(ck.card.kind), str(ck.card.tier)], "stamp": {}}
	for p: String in files:
		if p != FILE and p != Item.CARD and not p.begins_with("preview/"):
			return {"ok": false, "reason": "a stamp item holds only stamp.json and its card, not '%s'" % p, "stamp": {}}
	if not files.has(FILE):
		return {"ok": false, "reason": "the item holds no stamp.json", "stamp": {}}
	var j := JSON.new()
	if j.parse((files[FILE] as PackedByteArray).get_string_from_utf8()) != OK:
		return {"ok": false, "reason": "stamp.json is not JSON", "stamp": {}}
	var why := validate(j.data)
	if why != "":
		return {"ok": false, "reason": "stamp.json: " + why, "stamp": {}}
	return {"ok": true, "reason": "", "stamp": _ints(j.data)}


## A stamp read from JSON with its numbers back to integers (JSON gives floats), so it writes the bytes it was read from.
static func _ints(d: Dictionary) -> Dictionary:
	var out := {"schema": SCHEMA, "name": str(d.name), "size": (d.size as Array).map(func(q: Variant) -> int: return int(q))}
	if d.has("blocks"):
		out["blocks"] = (d.blocks as Array).map(func(b: Array) -> Array: return b.map(func(q: Variant) -> int: return int(q)))
	if d.has("pieces"):
		var ps := []
		for p: Dictionary in d.pieces:
			var q := {"at": (p.at as Array).map(func(v: Variant) -> int: return int(v)), "part": str(p.part)}
			var tp: Dictionary = Catalog.trimmed(str(p.part), p.get("params", {}))
			if not tp.is_empty():
				q["params"] = tp
			q["rot"] = int(p.rot)
			q["seed"] = int(p.seed)
			ps.append(q)
		out["pieces"] = ps
	return out


## A stamp file read back (list's `stamp` entries come from JSON): integers restored.
static func normal(d: Dictionary) -> Dictionary:
	return _ints(d)
