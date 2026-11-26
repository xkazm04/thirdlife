extends RefCounted
## WP1 (spark world-sandbox, M1): the sparse block store of the Home. A cell is 1 m, world-anchored, `Vector3i`; a block
## is one int `code` (bits 0-4 shape, 5-9 mat, 10-11 rot, 12 flip; contracts/BUILD.md). Cells are kept per mesh
## SECTION (a `sec` x `sec` m column, 16 m by default, inside the 96 m chunk: a section is what one rebuild redraws), as
## Dictionary section-local index -> code. Chunk counts are kept beside them for the caps and the saved records.
## Nothing here reads the clock, a random generator or the scene: it is data, and the same ops give the same store.

const CHUNK := 96                 # metres; the Home's collider chunk (home/hook.gd CHUNK), the saved record's unit
const Y_MIN := -16
const Y_MAX := 111                # inclusive: 128 cells
const LEVELS := 128
const CAP_CHUNK := 32768
const CAP_HOME := 400000

## Shapes and materials: ids are fixed and never reused (contracts/BUILD.md).
const CUBE := 1
const SLAB := 2
const STAIR := 3
const RAMP := 4
const POST := 5
const WINDOW := 6
const ROOF := 7
const FENCE := 8
const SHAPE_NAMES := {1: "cube", 2: "slab", 3: "stair", 4: "ramp", 5: "post", 6: "window", 7: "roof", 8: "fence"}
const GLASS := 10
const MAT_KEYS := {1: "stone", 2: "stone_dark", 3: "plank", 4: "wood_dark", 5: "roof", 6: "roof_slate", 7: "concrete",
	8: "rock_warm", 9: "white", 10: "glass"}

var sec := 16                     # section size in metres (divides CHUNK): 16, 32, 48 or 96
var cap_chunk := CAP_CHUNK
var cap_home := CAP_HOME
var sections := {}                # Vector2i section -> Dictionary (section-local index -> code)
var counts := {}                  # Vector2i chunk -> blocks in it
var total := 0
var dirty := {}                   # Vector2i section -> true: its mesh (and its chunk's collider) must be rebuilt


func _init(section_m := 16) -> void:
	assert(CHUNK % section_m == 0)
	sec = section_m


# ------------------------------------------------------------------ codes
static func code(shape: int, mat: int, rot := 0, flip := false) -> int:
	return (shape & 31) | ((mat & 31) << 5) | ((rot & 3) << 10) | ((1 if flip else 0) << 12)


static func shape_of(c: int) -> int:
	return c & 31


static func mat_of(c: int) -> int:
	return (c >> 5) & 31


static func rot_of(c: int) -> int:
	return (c >> 10) & 3


static func flip_of(c: int) -> bool:
	return ((c >> 12) & 1) == 1


## The palette key a block is drawn in (TLStyle).
static func mat_key(mat: int) -> String:
	return str(MAT_KEYS.get(mat, "white"))


# ------------------------------------------------------------------ grid
static func chunk_of(cell: Vector3i) -> Vector2i:
	return Vector2i(floori(cell.x / float(CHUNK)), floori(cell.z / float(CHUNK)))


func section_of(cell: Vector3i) -> Vector2i:
	return Vector2i(floori(cell.x / float(sec)), floori(cell.z / float(sec)))


func chunk_of_section(s: Vector2i) -> Vector2i:
	var per := CHUNK / sec
	return Vector2i(floori(s.x / float(per)), floori(s.y / float(per)))


static func in_range(cell: Vector3i) -> bool:
	return cell.y >= Y_MIN and cell.y <= Y_MAX


func _index(cell: Vector3i, s: Vector2i) -> int:
	return (cell.x - s.x * sec) + sec * ((cell.z - s.y * sec) + sec * (cell.y - Y_MIN))


## The cell of a section-local index.
func cell_of(s: Vector2i, idx: int) -> Vector3i:
	var lx := idx % sec
	var rest := idx / sec
	return Vector3i(s.x * sec + lx, rest / sec + Y_MIN, s.y * sec + rest % sec)


# ------------------------------------------------------------------ read / write
func get_code(cell: Vector3i) -> int:
	var s := section_of(cell)
	var d: Variant = sections.get(s)
	if d == null:
		return 0
	return int((d as Dictionary).get(_index(cell, s), 0))


## Why `cell` cannot take one more block here ("" = it can): the store's own limits (range, occupancy, caps).
func refusal(cell: Vector3i) -> String:
	if not in_range(cell):
		return "out of range (y %d..%d)" % [Y_MIN, Y_MAX]
	if get_code(cell) != 0:
		return "occupied"
	if int(counts.get(chunk_of(cell), 0)) >= cap_chunk:
		return "chunk full"
	if total >= cap_home:
		return "home full"
	return ""


## Puts `c` in an empty cell. Returns false (nothing changed) when `refusal` says no.
func put(cell: Vector3i, c: int) -> bool:
	if c == 0 or refusal(cell) != "":
		return false
	var s := section_of(cell)
	if not sections.has(s):
		sections[s] = {}
	(sections[s] as Dictionary)[_index(cell, s)] = c
	var ch := chunk_of(cell)
	counts[ch] = int(counts.get(ch, 0)) + 1
	total += 1
	_touch(cell)
	return true


## Empties a cell. Returns the code that was there (0 = it was empty; nothing changed).
func take(cell: Vector3i) -> int:
	var s := section_of(cell)
	var d: Variant = sections.get(s)
	if d == null:
		return 0
	var idx := _index(cell, s)
	var was := int((d as Dictionary).get(idx, 0))
	if was == 0:
		return 0
	(d as Dictionary).erase(idx)
	if (d as Dictionary).is_empty():
		sections.erase(s)
	var ch := chunk_of(cell)
	counts[ch] = int(counts[ch]) - 1
	if int(counts[ch]) == 0:
		counts.erase(ch)
	total -= 1
	_touch(cell)
	return was


## A cell's mesh depends on its neighbours up to two cells away horizontally (a stair's corner form reads its
## neighbours, and a neighbour's hidden faces read that form): every section that box touches is dirty.
func _touch(cell: Vector3i) -> void:
	var a := section_of(cell - Vector3i(2, 0, 2))
	var b := section_of(cell + Vector3i(2, 0, 2))
	for sz in range(a.y, b.y + 1):
		for sx in range(a.x, b.x + 1):
			dirty[Vector2i(sx, sz)] = true


func clear() -> void:
	for s: Vector2i in sections.keys():
		dirty[s] = true
	sections.clear()
	counts.clear()
	total = 0


## Section ids, sorted (z then x): the order every walk over the store uses, so the result never depends on the
## order the cells were put in.
static func sorted_ids(d: Dictionary) -> Array:
	var ids: Array = d.keys()
	ids.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return ids


# ------------------------------------------------------------------ chunk records (tl.build/1)
## A chunk's blocks as (chunk-local cell, code) int32 pairs sorted by cell. The chunk-local cell is
## lx + 96 * (lz + 96 * (y + 16)), lx and lz in 0..95 (BUILD.md).
func chunk_pairs(ch: Vector2i) -> PackedInt32Array:
	var cells := {}
	var per := CHUNK / sec
	for sz in range(ch.y * per, ch.y * per + per):
		for sx in range(ch.x * per, ch.x * per + per):
			var s := Vector2i(sx, sz)
			var d: Variant = sections.get(s)
			if d == null:
				continue
			for idx: int in (d as Dictionary):
				var c := cell_of(s, idx)
				cells[(c.x - ch.x * CHUNK) + CHUNK * ((c.z - ch.y * CHUNK) + CHUNK * (c.y - Y_MIN))] = (d as Dictionary)[idx]
	var keys: Array = cells.keys()
	keys.sort()
	var out := PackedInt32Array()
	out.resize(keys.size() * 2)
	for i: int in keys.size():
		out[i * 2] = keys[i]
		out[i * 2 + 1] = cells[keys[i]]
	return out


static func pair_cell(ch: Vector2i, local: int) -> Vector3i:
	return Vector3i(ch.x * CHUNK + local % CHUNK, local / (CHUNK * CHUNK) + Y_MIN, ch.y * CHUNK + (local / CHUNK) % CHUNK)


## SHA-1 over every chunk's pairs (chunks sorted): the identity of what is built, whatever order it was built in.
func content_hash() -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA1)
	for ch: Vector2i in sorted_ids(counts):
		hc.update(("%d,%d;" % [ch.x, ch.y]).to_utf8_buffer())
		hc.update(chunk_pairs(ch).to_byte_array())
	return hc.finish().hex_encode()
