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
## M6 round 2, lane T (27 Nov 2026), contracts/BUILD.md "Courses travel": `tl.stamp/2` adds `zones` (the zones whose box
## lies wholly in the stamp box, relative cells, ids local to the stamp: 1, 2, ...) and `rules` (the rules naming only
## those zones, renumbered 1, 2, ..., their references rewritten). A stamp with neither is `tl.stamp/1`, byte for byte as
## before. Placing turns and moves each zone box with the blocks (corners turned, then sorted) and adds the zone and
## rule ops to the same batch (`ops`); `placed_ops` gives them the Home's next free ids (rules_layer.gd `renumber`).
## The share code (`code_of`, `from_code`): "TL1-" + URL-safe base64 without padding of the deflate-compressed UTF-8
## of `text_of` (Godot's COMPRESSION_DEFLATE: a zlib stream, RFC 1950); at most 65,536 characters; read as hostile.

const Blocks := preload("res://kernel/world/build/blocks.gd")
const BlocksLayer := preload("res://kernel/world/build/blocks_layer.gd")
const PiecesLayer := preload("res://kernel/world/build/pieces_layer.gd")
const Catalog := preload("res://kernel/world/build/piece_catalog.gd")
const OpUtil := preload("res://kernel/world/build/op_util.gd")
const Item := preload("res://kernel/share/item.gd")
const Zip := preload("res://kernel/share/tlzip.gd")
const Check := preload("res://kernel/world/build/rules_check.gd")
const SCHEMA := "tl.stamp/1"
const SCHEMA_V2 := "tl.stamp/2"
const KEYS := ["schema", "name", "size", "blocks", "pieces", "zones", "rules"]
const KEYS_V1 := ["schema", "name", "size", "blocks", "pieces"]
const CODE_PREFIX := "TL1-"
const CODE_MAX := 65536                 # characters of a share code
const UNPACK_MAX := 8 << 20             # bytes a share code may inflate to
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
	var course := course_of(build.layer("rules"), lo, hi)
	for k: String in ["zones", "rules"]:
		if course.has(k):
			doc[k] = course[k]
			doc["schema"] = SCHEMA_V2
	if blocks.is_empty() and pieces.is_empty() and not course.has("zones"):
		return {"ok": false, "reason": "the box holds nothing to stamp", "stamp": {}, "left_out": left}
	return {"ok": true, "reason": "", "stamp": doc, "left_out": left}


## The stamp's `zones` and `rules` of the cell box lo..hi from rules layer `rl` (rules_layer.gd): the zones wholly in
## the box (relative boxes, ids 1, 2, ... in the Home's id order) and the rules naming only those zones (ids 1, 2, ...,
## their zone references rewritten); each key omitted when empty.
static func course_of(rl: RefCounted, lo: Vector3i, hi: Vector3i) -> Dictionary:
	var out := {}
	if rl == null:
		return out
	var zmap := {}
	var zs := []
	var zones: Dictionary = rl.get("zones")
	var ids: Array = zones.keys()
	ids.sort()
	for zid: int in ids:
		var b: Array = zones[zid].box
		var a := OpUtil.cell(b[0])
		var c := OpUtil.cell(b[1])
		if a.x < lo.x or a.y < lo.y or a.z < lo.z or c.x > hi.x or c.y > hi.y or c.z > hi.z:
			continue
		zmap[zid] = zs.size() + 1
		var z := (zones[zid] as Dictionary).duplicate(true)
		z["id"] = zs.size() + 1
		z["box"] = [[a.x - lo.x, a.y - lo.y, a.z - lo.z], [c.x - lo.x, c.y - lo.y, c.z - lo.z]]
		zs.append(Check.zone_of(z))
	var rs := []
	var rules: Dictionary = rl.get("rules")
	ids = rules.keys()
	ids.sort()
	for rid: int in ids:
		var named := Check.zones_named(rules[rid])
		if named.is_empty() or not named.all(func(z: int) -> bool: return zmap.has(z)):
			continue
		var r := (rules[rid] as Dictionary).duplicate(true)
		r["id"] = rs.size() + 1
		_refs_to(r, zmap)
		rs.append(Check.rule_of(r))
	if not zs.is_empty():
		out["zones"] = zs
	if not rs.is_empty():
		out["rules"] = rs
	return out


## Rewrites rule `r`'s zone references (its trigger's and its effects') through `zmap` (old id -> new id).
static func _refs_to(r: Dictionary, zmap: Dictionary) -> void:
	var w: Dictionary = r.when
	if w.has("zone") and zmap.has(int(w.zone)):
		w["zone"] = zmap[int(w.zone)]
	for e: Dictionary in r.do:
		if e.has("zone") and zmap.has(int(e.zone)):
			e["zone"] = zmap[int(e.zone)]


## "" when `d` is a well-formed tl.stamp/1, else the first thing wrong with it.
static func validate(d: Variant) -> String:
	if typeof(d) != TYPE_DICTIONARY:
		return "a stamp is a JSON object"
	var v2 := str((d as Dictionary).get("schema", "")) == SCHEMA_V2
	for k: Variant in d:
		if not (KEYS if v2 else KEYS_V1).has(k):
			return "unknown key '%s'" % str(k)
	if str(d.get("schema", "")) != SCHEMA and not v2:
		return "schema must be \"%s\" or \"%s\"" % [SCHEMA, SCHEMA_V2]
	if v2 and not d.has("zones") and not d.has("rules"):
		return "a %s holds zones or rules (without them it is %s)" % [SCHEMA_V2, SCHEMA]
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
	if v2:
		var why := course_error(d, size)
		if why != "":
			return why
		n += (d.get("zones", []) as Array).size()
	return "" if n > 0 else "a stamp holds at least one block or piece"


## "" when the `zones` and `rules` of stamp `d` (a box of `size`) are well formed: each entry exactly its saved keys
## (rules_check.gd), ids 1.. unique and ascending, every zone box in the size, every rule naming at least one zone and
## only the stamp's zones, at most 512 of each and 8 counters.
static func course_error(d: Dictionary, size: Vector3i) -> String:
	var have := {}
	var counters := {}
	for key: String in ["zones", "rules"]:
		if not d.has(key):
			continue
		var list: Variant = d[key]
		if typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
			return "%s must be a non-empty list (left out when empty)" % key
		if (list as Array).size() > (Check.ZONES_MAX if key == "zones" else Check.RULES_MAX):
			return "%s: too many" % key
		var keys: Array = Check.ZONE_SAVED if key == "zones" else Check.RULE_SAVED
		var last := 0
		for e: Variant in list:
			if typeof(e) != TYPE_DICTIONARY:
				return "%s: every entry is an object" % key
			for k: Variant in e:
				if not keys.has(k):
					return "%s: unknown key '%s'" % [key, str(k)]
			var op := (e as Dictionary).duplicate(true)
			op["op"] = "zone" if key == "zones" else "rule"
			var why := Check.malformed(op)
			if why != "":
				return "%s: %s" % [key, why]
			if int(op.id) <= last:
				return "%s: ids are unique and ascending (%d after %d)" % [key, int(op.id), last]
			last = int(op.id)
			if key == "zones":
				var b: Array = op.box
				if not _inside(OpUtil.cell(b[0]), size) or not _inside(OpUtil.cell(b[1]), size):
					return "zones: zone %d is outside the size" % last
				have[last] = true
			else:
				var r := Check.rule_of(op)
				var named := Check.zones_named(r)
				if named.is_empty():
					return "rules: rule %d names no zone (a stamp carries only rules of its zones)" % last
				for z: int in named:
					if not have.has(z):
						return "rules: rule %d names zone %d, which is not in the stamp" % [last, z]
				for c: String in Check.counters_of(r):
					counters[c] = true
				if counters.size() > Check.COUNTERS_MAX:
					return "rules: more than %d counters" % Check.COUNTERS_MAX
	return ""


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
	for z: Dictionary in d.get("zones", []):
		var a := turn_cell(OpUtil.cell(z.box[0]), size, r)
		var b := turn_cell(OpUtil.cell(z.box[1]), size, r)
		var lo := at + Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
		var hi := at + Vector3i(maxi(a.x, b.x), maxi(a.y, b.y), maxi(a.z, b.z))
		var op := {"v": 1, "op": "zone", "id": int(z.id), "box": [[lo.x, lo.y, lo.z], [hi.x, hi.y, hi.z]], "look": str(z.look)}
		if z.has("name"):
			op["name"] = str(z.name)
		out.append(op)
	for rr: Dictionary in d.get("rules", []):
		var op := {"v": 1, "op": "rule"}
		op.merge(Check.rule_of(rr), true)
		out.append(op)
	return out


## `ops` with the zones and rules given the Home's next free ids and the rules' references rewritten to them (rules
## layer `renumber`, as an LLM answer's): the ops to apply as one batch. {"ops", "refused"}.
static func placed_ops(build: RefCounted, d: Dictionary, at: Vector3i, r: int) -> Dictionary:
	var raw := ops(d, at, r)
	var rl: RefCounted = build.layer("rules") if build != null else null
	if rl == null or not (d.has("zones") or d.has("rules")):
		return {"ops": raw, "refused": []}
	return rl.renumber(raw)


## The stamp's text: keys in the contract's order, one line.
static func text_of(d: Dictionary) -> String:
	var parts := PackedStringArray()
	for k: String in (KEYS if str(d.get("schema", "")) == SCHEMA_V2 else KEYS_V1):
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
	var out := {"schema": SCHEMA_V2 if str(d.get("schema", "")) == SCHEMA_V2 else SCHEMA, "name": str(d.name), "size": (d.size as Array).map(func(q: Variant) -> int: return int(q))}
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
	if d.has("zones"):
		out["zones"] = (d.zones as Array).map(func(z: Dictionary) -> Dictionary: return Check.zone_of(z))
	if d.has("rules"):
		out["rules"] = (d.rules as Array).map(func(r: Dictionary) -> Dictionary: return Check.rule_of(r))
	return out


## A stamp file read back (list's `stamp` entries come from JSON): integers restored.
static func normal(d: Dictionary) -> Dictionary:
	return _ints(d)


# ------------------------------------------------------------------ the share code
## Stamp `d` as one line: "TL1-" + URL-safe base64 (no padding) of the deflate-compressed UTF-8 of its text.
static func code_of(d: Dictionary) -> String:
	var raw := text_of(d).strip_edges().to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	return CODE_PREFIX + Marshalls.raw_to_base64(packed).replace("+", "-").replace("/", "_").replace("=", "")


## A share code read as hostile input: its length, prefix, alphabet, the stream, the JSON, then the stamp as a stamp
## file is checked. Returns {"ok", "reason", "stamp"}.
static func from_code(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t.length() > CODE_MAX:
		return _no("the code is %d characters (at most %d)" % [t.length(), CODE_MAX])
	if not t.begins_with(CODE_PREFIX):
		return _no("a share code begins with %s" % CODE_PREFIX)
	var b := t.substr(CODE_PREFIX.length())
	if b.is_empty() or b.length() % 4 == 1:
		return _no("the code is cut short")
	for i: int in b.length():
		var u := b.unicode_at(i)
		if not ((u >= 65 and u <= 90) or (u >= 97 and u <= 122) or (u >= 48 and u <= 57) or u == 45 or u == 95):
			return _no("the code holds '%s', not a base64url letter" % b[i])
	var std := b.replace("-", "+").replace("_", "/")
	while std.length() % 4 != 0:
		std += "="
	var packed := Marshalls.base64_to_raw(std)
	if packed.is_empty():
		return _no("the code is not base64")
	# a zlib header (RFC 1950: method 8, window <= 32 KB, no preset dictionary, the check bits) before the engine is
	# asked: it logs an error line for a stream it cannot inflate
	if packed.size() < 6 or (packed[0] & 0x0F) != 8 or (packed[0] >> 4) > 7 or (int(packed[0]) * 256 + int(packed[1])) % 31 != 0 			or (packed[1] & 0x20) != 0:
		return _no("the code does not unpack (not a deflate stream)")
	var raw := packed.decompress_dynamic(UNPACK_MAX, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return _no("the code does not unpack (not a deflate stream, or over %d bytes)" % UNPACK_MAX)
	var j := JSON.new()
	if j.parse(raw.get_string_from_utf8()) != OK:
		return _no("the code holds no JSON (%s)" % j.get_error_message())
	var why := validate(j.data)
	if why != "":
		return _no(why)
	return {"ok": true, "reason": "", "stamp": _ints(j.data)}


static func _no(why: String) -> Dictionary:
	return {"ok": false, "reason": why, "stamp": {}}
