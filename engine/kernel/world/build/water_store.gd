extends RefCounted
## M5 lane W (spark world-sandbox): the water layer's data, the still water a person or an LLM poured in the Home
## (contracts/BUILD.md "Milestone 5", `tl.build/3` `water`). Nothing here reads the scene, the clock or a random
## generator: the same ops give the same store.
##   levels   3 m cell [i, j] (3i..3i+3, 3j..3j+3) -> the absolute height of its surface in integer cm. A cell holds at
##            most one level. A body of water is the 4-connected cells of one level (water_layer.gd `body_at`).
## The file key groups the cells per chunk `(floor(i / 32), floor(j / 32))`, local index `(i - 32 cx) + 32 (j - 32 cz)`,
## as little-endian int32 pairs (local, level_cm) sorted by local, base64, chunks sorted z then x: as `paint`
## (land_store.gd, whose writer this copies so the two lanes' files stay independent).

const PER := 32                          # cells per chunk side (a 96 m chunk of 3 m cells)
const CM_MAX := 100000

var levels := {}                         # Vector2i -> int cm


static func chunk_of(c: Vector2i) -> Vector2i:
	return Vector2i(floori(c.x / float(PER)), floori(c.y / float(PER)))


static func local_of(c: Vector2i, ch: Vector2i) -> int:
	return (c.x - PER * ch.x) + PER * (c.y - PER * ch.y)


func size() -> int:
	return levels.size()


func clear() -> void:
	levels.clear()


func has(c: Vector2i) -> bool:
	return levels.has(c)


func level(c: Vector2i) -> int:
	return int(levels.get(c, 0))


func duplicate_store() -> RefCounted:
	var s: RefCounted = (get_script() as GDScript).new()
	s.levels = levels.duplicate()
	return s


## The identity of what is saved: the file part as it would be written ("" when empty).
func content_hash() -> String:
	return "" if levels.is_empty() else JSON.stringify(records(levels)).sha256_text()


## The cells of chunk `ch` (file chunks: 32 x 32 cells, the 96 m render chunk).
func cells_in(ch: Vector2i) -> Array:
	var out := []
	for c: Vector2i in levels:
		if chunk_of(c) == ch:
			out.append(c)
	return out


# ------------------------------------------------------------------ files
## `{"<cx>,<cz>": base64}` of `d` (Vector2i -> int), `{}` when it is empty. Keys in z, then x order.
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


## Reads the file part `water` into `into` (Vector2i -> cm). Returns "" or what is wrong.
static func read_records(part: Variant, into: Dictionary) -> String:
	if typeof(part) != TYPE_DICTIONARY:
		return "water must be an object"
	for k: Variant in part:
		var f := str(k).split(",")
		if f.size() != 2 or not f[0].is_valid_int() or not f[1].is_valid_int():
			return "water: '%s' is not a chunk \"<cx>,<cz>\"" % str(k)
		var ch := Vector2i(int(f[0]), int(f[1]))
		if "%d,%d" % [ch.x, ch.y] != str(k):
			return "water: '%s' is not a chunk \"<cx>,<cz>\"" % str(k)
		if typeof(part[k]) != TYPE_STRING:
			return "water %s: a record is a base64 string" % str(k)
		var raw := Marshalls.base64_to_raw(str(part[k]))
		if raw.size() == 0 or raw.size() % 8 != 0:
			return "water %s: not (index, level) int32 pairs" % str(k)
		var pairs := raw.to_int32_array()
		var last := -1
		for p: int in range(0, pairs.size(), 2):
			var local: int = pairs[p]
			if local <= last or local < 0 or local >= PER * PER:
				return "water %s: indices must rise within 0..%d" % [str(k), PER * PER - 1]
			last = local
			if absi(pairs[p + 1]) > CM_MAX:
				return "water %s: level %d cm is beyond %d" % [str(k), pairs[p + 1], CM_MAX]
			into[Vector2i(ch.x * PER + local % PER, ch.y * PER + local / PER)] = pairs[p + 1]
	return ""
