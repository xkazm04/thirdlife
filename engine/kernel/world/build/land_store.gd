extends RefCounted
## M2 (spark world-sandbox): the land layer's data, the sparse store of what a person or an LLM did to the Home's
## ground (contracts/BUILD.md "More operations", `tl.build/2` `land` and `paint`). Nothing here reads the scene, the
## clock or a random generator: the same ops give the same store.
##   heights   lattice vertex [i, j] (world (3i, 3j)) -> its height in integer cm, kept only where it differs from the
##             ground's own height (setting a vertex back to that height removes it)
##   paints    3 m cell [i, j] (3i..3i+3, 3j..3j+3) -> paint id 1..8 (contract order); the ground's own material
##             ("valley") is no entry
## The file keys group both per chunk `(floor(i / 32), floor(j / 32))`, local index `(i - 32 cx) + 32 (j - 32 cz)`, as
## little-endian int32 pairs (local, value) sorted by local, base64, chunks sorted z then x (as the blocks' records).

const PAINTS := ["grass", "grass_dark", "grass_dry", "dirt", "sand", "stone", "rock_warm", "cliff"]   # id = index + 1
const VALLEY := "valley"
const PER := 32                          # lattice vertices (and paint cells) per chunk side
const CM_MAX := 100000

var heights := {}                        # Vector2i -> int cm
var paints := {}                         # Vector2i -> int id 1..8


static func paint_id(name: String) -> int:
	return PAINTS.find(name) + 1


static func paint_name(pid: int) -> String:
	return PAINTS[pid - 1] if pid >= 1 and pid <= PAINTS.size() else VALLEY


static func chunk_of(v: Vector2i) -> Vector2i:
	return Vector2i(floori(v.x / float(PER)), floori(v.y / float(PER)))


static func local_of(v: Vector2i, ch: Vector2i) -> int:
	return (v.x - PER * ch.x) + PER * (v.y - PER * ch.y)


func size() -> int:
	return heights.size() + paints.size()


func clear() -> void:
	heights.clear()
	paints.clear()


func paint_at(c: Vector2i) -> String:
	return paint_name(int(paints.get(c, 0)))


## Sets a vertex to `cm`; `base_cm` is the ground's own height there (no entry is kept for it).
func set_cm(v: Vector2i, cm: int, base_cm: int) -> void:
	if cm == base_cm:
		heights.erase(v)
	else:
		heights[v] = cm


func set_paint(c: Vector2i, name: String) -> void:
	var pid := paint_id(name)
	if pid <= 0:
		paints.erase(c)
	else:
		paints[c] = pid


func duplicate_store() -> RefCounted:
	var s: RefCounted = (get_script() as GDScript).new()
	s.heights = heights.duplicate()
	s.paints = paints.duplicate()
	return s


## The identity of what is saved: the two file parts as they would be written.
func content_hash() -> String:
	if heights.is_empty() and paints.is_empty():
		return ""
	return (JSON.stringify(records(heights)) + JSON.stringify(records(paints))).sha256_text()


# ------------------------------------------------------------------ files
## `{"<cx>,<cz>": base64}` of one dictionary (heights or paints), `{}` when it is empty. Keys in z, then x order.
static func records(d: Dictionary) -> Dictionary:
	var per := {}
	for v: Vector2i in d:
		var ch := chunk_of(v)
		if not per.has(ch):
			per[ch] = []
		(per[ch] as Array).append([local_of(v, ch), int(d[v])])
	var ids: Array = per.keys()
	ids.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var out := {}
	for ch: Vector2i in ids:
		var rows: Array = per[ch]
		rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
		var pairs := PackedInt32Array()
		for r: Array in rows:
			pairs.append(int(r[0]))
			pairs.append(int(r[1]))
		out["%d,%d" % [ch.x, ch.y]] = Marshalls.raw_to_base64(pairs.to_byte_array())
	return out


## Reads one file part into `into` (Vector2i -> value). `paint`: values are ids 1..8, else cm within CM_MAX.
## Returns "" or what is wrong.
static func read_records(part: Variant, key: String, paint: bool, into: Dictionary) -> String:
	if typeof(part) != TYPE_DICTIONARY:
		return "%s must be an object" % key
	for k: Variant in part:
		var f := str(k).split(",")
		if f.size() != 2 or not f[0].is_valid_int() or not f[1].is_valid_int():
			return "%s: '%s' is not a chunk \"<cx>,<cz>\"" % [key, str(k)]
		var ch := Vector2i(int(f[0]), int(f[1]))
		if "%d,%d" % [ch.x, ch.y] != str(k):
			return "%s: '%s' is not a chunk \"<cx>,<cz>\"" % [key, str(k)]
		if typeof(part[k]) != TYPE_STRING:
			return "%s %s: a record is a base64 string" % [key, str(k)]
		var raw := Marshalls.base64_to_raw(str(part[k]))
		if raw.size() == 0 or raw.size() % 8 != 0:
			return "%s %s: not (index, value) int32 pairs" % [key, str(k)]
		var pairs := raw.to_int32_array()
		var last := -1
		for p: int in range(0, pairs.size(), 2):
			var local: int = pairs[p]
			var value: int = pairs[p + 1]
			if local <= last or local < 0 or local >= PER * PER:
				return "%s %s: indices must rise within 0..%d" % [key, str(k), PER * PER - 1]
			last = local
			if paint and (value < 1 or value > PAINTS.size()):
				return "%s %s: paint id %d is not 1..%d" % [key, str(k), value, PAINTS.size()]
			if not paint and absi(value) > CM_MAX:
				return "%s %s: height %d cm is beyond %d" % [key, str(k), value, CM_MAX]
			into[Vector2i(ch.x * PER + local % PER, ch.y * PER + local / PER)] = value
	return ""
