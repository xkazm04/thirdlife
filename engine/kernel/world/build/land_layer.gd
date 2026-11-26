extends RefCounted
## SEAM stub of the `land` layer (spark world-sandbox M2 fills it): the ops `land` (height deltas on the 3 m lattice)
## and `paint` (the ground material of 3 m cells), contracts/BUILD.md "More operations". The stub checks both ops
## strictly against the contract (keys, types, ranges, paint names, duplicates) and refuses to apply them with the
## reason NOT_YET; it saves nothing and loads only an absent or empty `land` / `paint`. M2 replaces the bodies of
## this file (and adds files of its own); the interface is BUILD.md "Layers", the lane's files are LANES.md.

const OpUtil := preload("res://kernel/world/build/op_util.gd")
const NOT_YET := "not built yet (M2)"
const LAND_KEYS := ["v", "op", "verts", "author", "batch"]
const PAINT_KEYS := ["v", "op", "cells", "author", "batch"]
const PAINTS := ["grass", "grass_dark", "grass_dry", "dirt", "sand", "stone", "rock_warm", "cliff", "valley"]
const LATTICE := 3                      # metres between land vertices; a paint cell is LATTICE square
const IJ_MAX := 100000                  # |i|, |j| (300 km): the stub's bound, M2 may narrow it
const CM_MAX := 100000                  # |height| in cm (1 km)

var id := "land"
var ctx: Dictionary


## `ctx`: home_build.gd's context (BUILD.md "Layers": blocks, protect, space, root, seed, home).
func _init(c: Dictionary) -> void:
	ctx = c


func ops() -> PackedStringArray:
	return PackedStringArray(["land", "paint"])


func malformed(op: Variant, strict := false) -> String:
	if typeof(op) != TYPE_DICTIONARY:
		return "an operation is a JSON object"
	var land: bool = (op as Dictionary).get("op") == "land"
	var why := OpUtil.head(op, LAND_KEYS if land else PAINT_KEYS)
	if why != "":
		return why
	var d: Dictionary = op
	var key := "verts" if land else "cells"
	if typeof(d.get(key)) != TYPE_ARRAY or (d[key] as Array).is_empty():
		return "%s must be a non-empty list" % key
	var seen := {}
	for e: Variant in d[key]:
		if typeof(e) != TYPE_ARRAY or (e as Array).size() != 4:
			return "%s: every entry is [i, j, %s]" % [key, "from_cm, to_cm" if land else "\"<from>\", \"<to>\""]
		var a: Array = e
		for q: int in 2:
			if OpUtil.int_of(a[q]) == null or absi(int(a[q])) > IJ_MAX:
				return "%s: i and j must be integers within %d" % [key, IJ_MAX]
		var ij := Vector2i(int(a[0]), int(a[1]))
		if seen.has(ij):
			return "%s: [%d, %d] is named twice" % [key, ij.x, ij.y]
		seen[ij] = true
		for q: int in [2, 3]:
			if land and (OpUtil.int_of(a[q]) == null or absi(int(a[q])) > CM_MAX):
				return "verts: heights are integer cm within %d" % CM_MAX
			if not land and (typeof(a[q]) != TYPE_STRING or not PAINTS.has(a[q])):
				return "cells: '%s' is not a paint (%s)" % [str(a[q]), ", ".join(PAINTS)]
	return OpUtil.tail(d, strict)


func can_apply(_op: Dictionary) -> String:
	return NOT_YET


func fits(_rec: Dictionary) -> String:
	return NOT_YET


## The op as journaled: keys in the contract's order, numbers as ints.
func raw(op: Dictionary) -> Dictionary:
	var key := "verts" if op.op == "land" else "cells"
	var list := []
	for e: Array in op[key]:
		list.append([int(e[0]), int(e[1]), int(e[2]) if key == "verts" else e[2], int(e[3]) if key == "verts" else e[3]])
	return {"v": 1, "op": op.op, key: list}


func apply(_rec: Dictionary) -> void:
	pass


## The inverse: every entry's from and to swapped (a land op's heights, a paint op's names).
func invert(rec: Dictionary) -> Dictionary:
	var key := "verts" if rec.op == "land" else "cells"
	var list := []
	for e: Array in rec[key]:
		list.append([e[0], e[1], e[3], e[2]])
	return {"v": 1, "op": rec.op, key: list}


## World boxes the op changes: the cells round a vertex (a vertex moves the four 3 m cells it is a corner of), or the
## painted cell, over the whole height range.
func dirty_regions(rec: Dictionary) -> Array:
	var out := []
	var land: bool = rec.op == "land"
	for e: Array in rec.verts if land else rec.cells:
		var x := float(int(e[0]) * LATTICE - (LATTICE if land else 0))
		var z := float(int(e[1]) * LATTICE - (LATTICE if land else 0))
		var w := float(LATTICE * (2 if land else 1))
		out.append(AABB(Vector3(x, -16.0, z), Vector3(w, 128.0, w)))
	return out


# ------------------------------------------------------------------ files (tl.build/2 `land`, `paint`)
func save_part() -> Dictionary:
	return {}


func load_part(doc: Dictionary) -> String:
	for k: String in ["land", "paint"]:
		if not doc.has(k):
			continue
		if typeof(doc[k]) != TYPE_DICTIONARY:
			return "%s must be an object" % k
		if not (doc[k] as Dictionary).is_empty():
			return "%s: %s" % [k, NOT_YET]
	return ""


func clear() -> void:
	pass


func size() -> int:
	return 0


func content_hash() -> String:
	return ""


# ------------------------------------------------------------------ drawing, copies, reads
func step(_budget: int) -> int:
	return 0


func pending() -> int:
	return 0


func copy() -> RefCounted:
	return (get_script() as GDScript).new(ctx)


## M2 adds the ground heights, paints and refused columns of the box here (M4's ask reads them).
func read_region(_lo: Vector3i, _hi: Vector3i) -> Dictionary:
	return {}


func free_all() -> void:
	pass
