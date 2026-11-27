extends RefCounted
## M5 lane L (spark world-sandbox): the `plants` layer of the edit log: the op `plant`, the growth of 3 m land cells
## (contracts/BUILD.md "Milestone 5": `meadow`, `flowers`, `tall_grass`, or `valley` for the ground's own growth), saved
## as tl.build/3 `plants` (per chunk, (cell, id) int32 pairs, ids 1 meadow, 2 flowers, 3 tall_grass, as paint's). The
## growth is drawn by the ground's shader, never by instances: the land layer's mesh pulls the cell's colour toward its
## green and writes its density into the mesh's UV (land_mesh.gd), which toon_cel.gdshader reads (more and taller tufts,
## more flowers). A plant op opens its chunk as paint does (land_layer.gd `chunk_open`, `touch_growth`). Trees and
## bushes are `put` ops of the pieces layer (the plant tool's scatter slots, plant_scatter.gd). Refused where paint is
## (the land layer's "area" rule, `what` "plant"), except where the visitor stands: growth moves nothing.
## A brush stroke is one op (tools/plant_tool.gd): `stroke_begin`, live `stroke_grow`, `stroke_end` gives the op.
## Interface: BUILD.md "Layers".

const OpUtil := preload("res://kernel/world/build/op_util.gd")
const StubLayer := preload("res://kernel/world/build/stub_layer.gd")
const LandStore := preload("res://kernel/world/build/land_store.gd")
const KEYS := ["v", "op", "cells", "author", "batch"]
const ORDER := ["v", "op", "cells"]
const GROWTHS := ["meadow", "flowers", "tall_grass", "valley"]
const IDS := ["meadow", "flowers", "tall_grass"]        # id = index + 1 (the file)
const LATTICE := 3
const TINTS := ["valley", "grass", "neon_pink", "grass_dark"]   # the ghost's tint per id (0: cleared, red)

var id := "plants"
var ctx: Dictionary
var cells := {}                          # Vector2i -> id 1..3; "valley" (the ground's own growth) is no entry
var scratch := false                     # a preview's copy: it touches no land layer
var _stroke := {}                        # Vector2i -> the growth at the stroke's first touch


func _init(c: Dictionary) -> void:
	ctx = c


func ops() -> PackedStringArray:
	return PackedStringArray(["plant"])


## The op kinds the LLM may write for this layer (command_ask.gd `ops_now`): plant.
func offers() -> Array:
	return ["plant"]


static func growth_id(name: String) -> int:
	return IDS.find(name) + 1


static func growth_name(gid: int) -> String:
	return IDS[gid - 1] if gid >= 1 and gid <= IDS.size() else "valley"


func growth_at(c: Vector2i) -> String:
	return growth_name(int(cells.get(c, 0)))


# ------------------------------------------------------------------ ops
func malformed(op: Variant, strict := false) -> String:
	var why := OpUtil.head(op, KEYS)
	if why != "":
		return why
	var d: Dictionary = op
	if str(d.get("op")) != "plant":
		return "op must be \"plant\""
	why = StubLayer.cells_error(d.get("cells"), 4, _growth_error)
	if why != "":
		return why
	return OpUtil.tail(d, strict)


func _growth_error(e: Array) -> String:
	for g: Variant in [e[2], e[3]]:
		if typeof(g) != TYPE_STRING or not (str(g) in GROWTHS):
			return "cells: '%s' is not a growth (%s)" % [str(g), ", ".join(GROWTHS)]
	return ""


## Every cell starts where its growth is now, and lies outside the protected areas (every "area" rule, `what` "plant").
func can_apply(op: Dictionary) -> String:
	var why := fits(op)
	if why != "":
		return why
	var land: RefCounted = _land()
	if land != null:
		land.begin_asking(_box(op.cells))
	for e: Array in op.cells:
		why = refusal(Vector2i(int(e[0]), int(e[1])))
		if why != "":
			break
	if land != null:
		land.end_asking()
	return why


## Why cell `c` may not take growth now ("" = it may): the protected areas, as paint.
func refusal(c: Vector2i) -> String:
	var pr: RefCounted = ctx.get("protect")
	return str(pr.refusal_area(Rect2(c.x * LATTICE, c.y * LATTICE, LATTICE, LATTICE), "plant")) if pr != null else ""


func fits(rec: Dictionary) -> String:
	for e: Array in rec.cells:
		var c := Vector2i(int(e[0]), int(e[1]))
		if str(e[2]) != growth_at(c):
			return "cells: [%d, %d] is '%s', not '%s'" % [c.x, c.y, growth_at(c), str(e[2])]
	return ""


func raw(op: Dictionary) -> Dictionary:
	var list := []
	for e: Array in op.cells:
		list.append([int(e[0]), int(e[1]), str(e[2]), str(e[3])])
	return {"v": 1, "op": "plant", "cells": list}


func apply(rec: Dictionary) -> void:
	for e: Array in rec.cells:
		_put_growth(Vector2i(int(e[0]), int(e[1])), str(e[3]))


## The cells set back: each entry's from and to swapped.
func invert(rec: Dictionary) -> Dictionary:
	return {"v": 1, "op": "plant", "cells": (rec.cells as Array).map(func(e: Array) -> Array: return [e[0], e[1], e[3], e[2]])}


func dirty_regions(rec: Dictionary) -> Array:
	var out := []
	for e: Array in rec.cells:
		out.append(AABB(Vector3(int(e[0]) * LATTICE, -16.0, int(e[1]) * LATTICE), Vector3(LATTICE, 128.0, LATTICE)))
	return out


func _put_growth(c: Vector2i, name: String) -> void:
	var gid := growth_id(name)
	if gid <= 0:
		cells.erase(c)
	else:
		cells[c] = gid
	var land: RefCounted = _land()
	if land != null and not scratch:
		land.touch_growth(c)


func _land() -> RefCounted:
	var h: Variant = ctx.get("home")
	var home: RefCounted = (h as WeakRef).get_ref() if h is WeakRef else null
	return home.call("layer", "land") if home != null else null


static func _box(list: Array) -> Rect2:
	var box := Rect2()
	for k: int in list.size():
		var r := Rect2(int(list[k][0]) * LATTICE - LATTICE, int(list[k][1]) * LATTICE - LATTICE, 3 * LATTICE, 3 * LATTICE)
		box = r if k == 0 else box.merge(r)
	return box


# ------------------------------------------------------------------ strokes (the plant tool)
func stroke_begin() -> void:
	_stroke = {"from": {}}


func stroking() -> bool:
	return not _stroke.is_empty()


## Sets cell `c` to `name` live (not journaled); the stroke remembers its growth at the first touch.
func stroke_grow(c: Vector2i, name: String) -> void:
	var from: Dictionary = _stroke.from
	if not from.has(c):
		from[c] = growth_at(c)
	_put_growth(c, name)


## Ends the stroke: the cells go back to where they were and the op is returned ({} when nothing changed), sorted by j
## then i; cells the rules refuse now are left out.
func stroke_end() -> Dictionary:
	if _stroke.is_empty():
		return {}
	var from: Dictionary = _stroke.from
	_stroke = {}
	var keys: Array = from.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var list := []
	for c: Vector2i in keys:
		var to := growth_at(c)
		_put_growth(c, str(from[c]))
		if to != str(from[c]) and refusal(c) == "":
			list.append([c.x, c.y, str(from[c]), to])
	return {} if list.is_empty() else {"op": "plant", "cells": list, "author": "hand"}


# ------------------------------------------------------------------ files (tl.build/3 `plants`)
func save_part() -> Dictionary:
	return {} if cells.is_empty() else {"plants": LandStore.records(cells)}


func load_part(doc: Dictionary) -> String:
	if not doc.has("plants"):
		return ""
	var into := {}
	var why := LandStore.read_records(doc.plants, "plants", true, into)
	if why != "":
		return why
	for c: Vector2i in into:
		if int(into[c]) > IDS.size():
			return "plants: growth id %d is not 1..%d" % [int(into[c]), IDS.size()]
	for c: Vector2i in into:
		_put_growth(c, growth_name(int(into[c])))
	return ""


func clear() -> void:
	for c: Vector2i in cells.keys():
		_put_growth(c, "valley")
	cells.clear()


func size() -> int:
	return cells.size()


func content_hash() -> String:
	return "" if cells.is_empty() else JSON.stringify(LandStore.records(cells)).sha256_text()


# ------------------------------------------------------------------ drawing, copies, reads
## The drawing is the land layer's (its mesh reads `cells`): nothing to do here.
func step(_budget: int) -> int:
	return 0


func pending() -> int:
	return 0


func copy() -> RefCounted:
	var c: RefCounted = (get_script() as GDScript).new(ctx)
	c.scratch = true
	c.cells = cells.duplicate()
	return c


## The ask reads no growth (its schema names no plants key); {}.
func read_region(_lo: Vector3i, _hi: Vector3i) -> Dictionary:
	return {}


## Its part of a dry run's ghost: the cells whose growth the ops change, each a flat patch on the ground in its green
## (or red where growth is cleared). null when nothing changes.
func preview_node(s: Variant) -> Node3D:
	if not (s is RefCounted) or not bool((s as RefCounted).get("scratch")):
		return null
	var changed := {}
	for c: Vector2i in s.cells:
		if int(cells.get(c, 0)) != int(s.cells[c]):
			changed[c] = TINTS[int(s.cells[c])]
	for c: Vector2i in cells:
		if not (s.cells as Dictionary).has(c):
			changed[c] = TINTS[0]
	if changed.is_empty():
		return null
	var land: RefCounted = _land()
	var ghost: Node3D = (load("res://kernel/world/build/land_ghost.gd") as GDScript).new()
	ghost.call("show_cells", changed, Callable(land, "height_at") if land != null else Callable())
	return ghost


func free_all() -> void:
	pass
