extends RefCounted
## M5 lane W (spark world-sandbox): the `water` layer of the edit log: still water over 3 m land cells (the paint
## grid), contracts/BUILD.md "Milestone 5". `flood` sets the surface of cells [i, j] to an absolute level in cm,
## `drain` removes it and names the level it removes (undo needs no lookup). A cell holds at most one level: a flood
## refuses a cell that holds water (the pour tool drains the old body first, in the same batch). Saved as tl.build/3
## `water`. Water follows no later sculpt: a land op under water leaves the level as it is, and land under water stays
## editable. The input op `pour` (an LLM answer's "fill from this cell") is expanded into one flood op by
## `expand_input`, computed as the pour tool computes it (water_fill.gd).
##   water_store.gd    the cells and their levels; the file part
##   water_fill.gd     the pour's fill: a priority flood on the land lattice up to just under the spill level
##   water_mesh.gd     one TLMesh per 96 m chunk in the still-water look (TLStyle "water", the depth shore), the ghost
##   water_scatter.gd  valley trees and reeds standing in the water hidden, and back when it is drained (a fallback)
## Refusals of a flood (and a pour), per cell, short: "water there already at [i, j]", "spills into the river" (the
## land layer's river band, or a cell the river's ribbon reaches whose bed lies below the river: the ribbon would show
## in it), "spills: <the protected area's reason>" (village, game lot, lane, authored structure, outside the Home);
## blocks and the visitor do not stop water (a post may stand in a pond; a person may stand in the hollow he fills).
## The pour adds: "no hollow here: dig one first", "spills: too big" (2,048 cells). Interface: BUILD.md "Layers".

const OpUtil := preload("res://kernel/world/build/op_util.gd")
const StubLayer := preload("res://kernel/world/build/stub_layer.gd")
const WaterStore := preload("res://kernel/world/build/water_store.gd")
const WaterFill := preload("res://kernel/world/build/water_fill.gd")
const WaterMesh := preload("res://kernel/world/build/water_mesh.gd")
const WaterScatter := preload("res://kernel/world/build/water_scatter.gd")
const KEYS := ["v", "op", "cells", "author", "batch"]
const ORDER := ["v", "op", "cells"]
const POUR_KEYS := ["v", "op", "at", "author", "batch"]
const CM_MAX := 100000                   # |level| in cm
const LATTICE := 3
const RIBBON_HALF := 157.0               # m: the river ribbon's widest half width (home/places.gd `river`: 136 x 1.15)
const RIBBON_STEP := 6.0                 # m between the river line's samples when a cell's distance is measured
const ALLOWED := ["blocks", "too close"]  # area reasons that do not stop water
const PER_STEP := 2                      # chunks redrawn per `step` at the default budget (4)

var id := "water"
var ctx: Dictionary
var store: RefCounted = WaterStore.new()
var mesh: RefCounted = null              # water_mesh.gd (null: nothing drawn: no root, or a scratch copy)
var scatter: RefCounted = null
var scratch := false
var dirty := {}                          # Vector2i chunk -> true: its mesh and scatter follow in `step`
var stats := {"fills": 0, "fill_usec": [], "check_usec": [], "hidden": 0, "shown": 0}
var _made := false
var _land: RefCounted = null


## `ctx`: home_build.gd's context (BUILD.md "Layers": blocks, protect, space, root, seed, home). An empty one (a test
## layer borrowing the checks) works too.
func _init(c: Dictionary) -> void:
	ctx = c


func ops() -> PackedStringArray:
	return PackedStringArray(["flood", "drain"])


## The op kinds the LLM may write for this layer (command_ask.gd `ops_now`): the model pours, the exe floods.
func offers() -> Array:
	return ["pour", "drain"]


## The land layer (read only), or null. Looked up once (the builder's layers do not change after it is made).
func land() -> RefCounted:
	if _land == null:
		var h: Variant = ctx.get("home")
		var b: Variant = (h as WeakRef).get_ref() if h is WeakRef else null
		_land = (b as RefCounted).call("layer", "land") if b is RefCounted else null
	return _land


## Lattice vertex `v`'s height now, in cm (the land layer's; 0 without one).
func vertex_cm(v: Vector2i) -> int:
	var l := land()
	return int(l.cm_at(v)) if l != null else 0


func _make() -> void:
	if _made:
		return
	_made = true
	var r: Variant = ctx.get("root")
	if scratch or not (r is Node3D) or not is_instance_valid(r):
		return
	mesh = WaterMesh.new(r)
	var l := land()
	if l != null and not l.ground().flat():
		scatter = WaterScatter.new(l, (r as Node3D).get_parent() as Node3D)


# ------------------------------------------------------------------ ops
## Well-formed (keys, cells [i, j, level_cm] of integers, no cell twice, at most 2,048). Not strict (an op handed to
## `apply`): v, author and batch may be left out.
func malformed(op: Variant, strict := false) -> String:
	var why := OpUtil.head(op, KEYS)
	if why != "":
		return why
	var d: Dictionary = op
	if not (str(d.get("op")) in ["flood", "drain"]):
		return "op must be \"flood\" or \"drain\""
	why = StubLayer.cells_error(d.get("cells"), 3, _level_error, WaterFill.CAP)
	if why != "":
		return why
	return OpUtil.tail(d, strict)


func _level_error(e: Array) -> String:
	if OpUtil.int_of(e[2]) == null:
		return "cells: a level is integer cm"
	return "cells: a level is within %d cm" % CM_MAX if absi(int(e[2])) > CM_MAX else ""


## The rules: a flood's cells are dry now and lie where water may stand; a drain's cells hold the level it names.
func can_apply(op: Dictionary) -> String:
	var why := fits(op)
	if why != "" or op.op != "flood":
		return why
	var cells := []
	for e: Array in op.cells:
		cells.append(Vector2i(int(e[0]), int(e[1])))
	return refusal_cells(cells)


func fits(rec: Dictionary) -> String:
	for e: Array in rec.cells:
		var c := Vector2i(int(e[0]), int(e[1]))
		if rec.op == "flood" and store.has(c):
			return "water there already at [%d, %d]" % [c.x, c.y]
		if rec.op == "drain" and (not store.has(c) or store.level(c) != int(e[2])):
			return "cells: [%d, %d] holds %s, not %d cm" % [c.x, c.y, "no water" if not store.has(c) else "%d cm" % store.level(c), int(e[2])]
	return ""


## The op as journaled: keys in the contract's order, numbers as ints.
func raw(op: Dictionary) -> Dictionary:
	var list := []
	for e: Array in op.cells:
		list.append([int(e[0]), int(e[1]), int(e[2])])
	return {"v": 1, "op": op.op, "cells": list}


func apply(rec: Dictionary) -> void:
	for e: Array in rec.cells:
		var c := Vector2i(int(e[0]), int(e[1]))
		if rec.op == "flood":
			store.levels[c] = int(e[2])
		else:
			store.levels.erase(c)
		_touch(c)


func invert(rec: Dictionary) -> Dictionary:
	var out := OpUtil.ordered(rec, ORDER)
	out["op"] = "drain" if rec.op == "flood" else "flood"
	return out


## The cells' columns over the whole height range.
func dirty_regions(rec: Dictionary) -> Array:
	var out := []
	for e: Array in rec.cells:
		out.append(AABB(Vector3(int(e[0]) * LATTICE, -16.0, int(e[1]) * LATTICE), Vector3(LATTICE, 128.0, LATTICE)))
	return out


# ------------------------------------------------------------------ where water may stand
## Why water may not stand in `cells` (Vector2i): "" or the first reason. The cells' bounding box is asked once; only
## when it is refused is every cell asked (a box near a lot can be refused where none of its cells is).
func refusal_cells(cells: Array) -> String:
	if cells.is_empty():
		return ""
	var t0 := Time.get_ticks_usec()
	var box := Rect2(Vector2(cells[0]) * LATTICE, Vector2.ONE * LATTICE)
	for c: Vector2i in cells:
		box = box.expand(Vector2(c + Vector2i.ONE) * LATTICE).expand(Vector2(c) * LATTICE)
	var why := _refusal(box, true)
	if why != "":
		why = ""
		for c: Vector2i in cells:
			why = _refusal(Rect2(Vector2(c) * LATTICE, Vector2.ONE * LATTICE), false, c)
			if why != "":
				break
	_note("check_usec", Time.get_ticks_usec() - t0)
	return why


func _refusal(rect: Rect2, coarse: bool, cell := Vector2i.ZERO) -> String:
	var v: RefCounted = _valley()
	if v != null and _near_ribbon(v, rect) and (coarse or _bed_cm(cell) < roundi(float(v.level(rect.get_center().y)) * 100.0) + 5):
		return "spills into the river"
	var pr: Variant = ctx.get("protect")
	if pr == null:
		return ""
	return spill_reason(str((pr as RefCounted).refusal_area(rect, "flood")))


## A protected area's reason as a flood's: "" for those that do not stop water.
static func spill_reason(why: String) -> String:
	if why == "" or ALLOWED.has(why):
		return ""
	return "spills into the river" if why == "river" else "spills: " + why


func _bed_cm(c: Vector2i) -> int:
	var lo := 1 << 30
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		lo = mini(lo, vertex_cm(c + o))
	return lo


## The valley (home/valley.gd) under the land layer, or null on flat ground.
func _valley() -> RefCounted:
	var l := land()
	if l == null:
		return null
	var g: RefCounted = l.ground()
	return null if g.flat() else g.valley


## True when the river's ribbon (home/places.gd: the water plane at valley.gd `level(z)`, RIBBON_HALF m either side
## of the river's line at its widest) reaches `rect`: the line sampled every RIBBON_STEP m along z.
static func _near_ribbon(v: RefCounted, rect: Rect2) -> bool:
	var reach := RIBBON_HALF * 1.4 + RIBBON_STEP
	var z := rect.position.y - reach
	while z <= rect.end.y + reach:
		var rx: float = v.river_x(z)
		var gx := maxf(0.0, maxf(rect.position.x - rx, rx - rect.end.x))
		var gz := maxf(0.0, maxf(rect.position.y - z, z - rect.end.y))
		if gx * gx + gz * gz < RIBBON_HALF * RIBBON_HALF:
			return true
		z += RIBBON_STEP
	return false


## The protect.gd "area" rule this layer adds: a flood is refused where the river's ribbon would show over its bed
## (the band the land layer's 71 m "river" does not cover). Land, paint and the rest are never refused for water.
func add_rules(protect: RefCounted) -> void:
	protect.add_rule(Callable(self, "area_rule"), "area")


func area_rule(rect: Rect2, what: String) -> String:
	if what != "flood":
		return ""
	var v: RefCounted = _valley()
	if v == null or not _near_ribbon(v, rect):
		return ""
	var c := Vector2i(floori(rect.position.x / LATTICE), floori(rect.position.y / LATTICE))
	return "river" if _bed_cm(c) < roundi(float(v.level(rect.get_center().y)) * 100.0) + 5 else ""


# ------------------------------------------------------------------ the pour
## The fill a pour into 3 m cell `cell` makes now, `lower_cm` under the highest level: water_fill.gd `fill`'s result
## with its reason, then the protected areas and the river asked of its cells.
func plan(cell: Vector2i, lower_cm := 0) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var f: Dictionary = WaterFill.fill(Callable(self, "vertex_cm"), cell, lower_cm)
	if str(f.reason) == "":
		f.reason = refusal_cells(f.cells)
	f["usec"] = Time.get_ticks_usec() - t0
	stats.fills += 1
	_note("fill_usec", int(f.usec))
	return f


## Keeps the last 256 figures of `key` (a session aims thousands of times).
func _note(key: String, usec: int) -> void:
	var a: Array = stats[key]
	a.append(usec)
	if a.size() > 256:
		a.pop_front()


## The flood op of a fill (cells sorted by j, then i).
static func flood_op(f: Dictionary) -> Dictionary:
	var list := []
	for c: Vector2i in f.cells:
		list.append([c.x, c.y, int(f.level)])
	return {"op": "flood", "cells": list}


## The ops a hand pour into `cell` makes: {"ops": [drain of the water the fill covers, if any; the flood], "fill",
## "reason"}. The same fill as the water there already gives the reason "water there already".
func pour_ops(cell: Vector2i, lower_cm := 0) -> Dictionary:
	var f := plan(cell, lower_cm)
	if str(f.reason) != "":
		return {"ops": [], "fill": f, "reason": f.reason}
	var old := {}
	for c: Vector2i in f.cells:
		if store.has(c) and not old.has(c):
			for b: Vector2i in body_at(c):
				old[b] = store.level(b)
	if old.size() == (f.cells as Array).size() and (f.cells as Array).all(func(c: Vector2i) -> bool: return old.has(c) and int(old[c]) == int(f.level)):
		return {"ops": [], "fill": f, "reason": "water there already"}
	var ops := []
	if not old.is_empty():
		var keys: Array = old.keys()
		keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
		ops.append({"op": "drain", "cells": keys.map(func(c: Vector2i) -> Array: return [c.x, c.y, int(old[c])])})
	ops.append(flood_op(f))
	return {"ops": ops, "fill": f, "reason": ""}


## The body of water holding cell `c`: its 4-connected cells of the same level, sorted by j then i ([] when dry).
func body_at(c: Vector2i) -> Array:
	if not store.has(c):
		return []
	var lv: int = store.level(c)
	var seen := {c: true}
	var todo := [c]
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + o
			if not seen.has(q) and store.has(q) and store.level(q) == lv:
				seen[q] = true
				todo.append(q)
	var out: Array = seen.keys()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


## The drain op of the body holding `c` ({} when dry).
func drain_op(c: Vector2i) -> Dictionary:
	var cells := body_at(c)
	if cells.is_empty():
		return {}
	return {"op": "drain", "cells": cells.map(func(b: Vector2i) -> Array: return [b.x, b.y, store.level(b)])}


## An input op (`{"op": "pour", "at": [x, y, z]}`) as the ops it stands for (home_build.gd `expand_input`): {"ops":
## [the flood]} or {"error"}. The fill is the hand pour's at full height; a pour over water there is refused.
func expand_input(op: Dictionary) -> Dictionary:
	var why := OpUtil.head(op, POUR_KEYS)
	if why == "" and op.get("op") != "pour":
		why = "op must be \"pour\""
	if why == "":
		why = OpUtil.cell_error(op.get("at"))
	if why == "":
		why = OpUtil.tail(op, false)
	if why != "":
		return {"error": why}
	var at := OpUtil.cell(op.at)
	var f := plan(Vector2i(floori(at.x / float(LATTICE)), floori(at.z / float(LATTICE))))
	if str(f.reason) != "":
		return {"error": str(f.reason)}
	for c: Vector2i in f.cells:
		if store.has(c):
			return {"error": "water there already: drain it first"}
	return {"ops": [flood_op(f)]}


# ------------------------------------------------------------------ reads
## The water in the cell box `lo`..`hi`, shaped as the ask's `water` key: [{"y": <cell y of the surface:
## floori(level_cm / 100.0), the rule command_ask.gd uses for the river (PATCHES-C C2)>, "runs":
## [[z, x0, x1], ...]}, ...] sorted by y, runs by z then x0. A 1 m column is water where its cell holds a level over
## the ground at the column's middle (in a water column the ask's `ground` is the bed) and the surface's cell y lies
## in the box. [] when there is none.
func water_runs(lo: Vector3i, hi: Vector3i) -> Array:
	var l := land()
	var by_y := {}
	for c: Vector2i in store.levels:
		var x0 := maxi(c.x * LATTICE, lo.x)
		var x1 := mini(c.x * LATTICE + LATTICE - 1, hi.x)
		var z0 := maxi(c.y * LATTICE, lo.z)
		var z1 := mini(c.y * LATTICE + LATTICE - 1, hi.z)
		var lv: float = store.level(c) / 100.0
		var y := floori(lv)
		if x0 > x1 or z0 > z1 or y < lo.y or y > hi.y:
			continue
		if not by_y.has(y):
			by_y[y] = {}
		for z: int in range(z0, z1 + 1):
			for x: int in range(x0, x1 + 1):
				if l == null or float(l.height_at(x + 0.5, z + 0.5)) < lv:
					by_y[y][Vector2i(x, z)] = true
	var ys: Array = by_y.keys()
	ys.sort()
	var out := []
	for y: int in ys:
		var cols: Array = (by_y[y] as Dictionary).keys()
		if cols.is_empty():
			continue
		cols.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
		var runs := []
		for p: Vector2i in cols:
			var last: Array = runs[runs.size() - 1] if not runs.is_empty() else []
			if not last.is_empty() and int(last[0]) == p.y and int(last[2]) == p.x - 1:
				last[2] = p.x
			else:
				runs.append([p.y, p.x, p.x])
		out.append({"y": y, "runs": runs})
	return out


## Its keys for home_build.gd `read_region` (the ask's `layers`; PATCHES-C C3): {"water_cells": [[i, j, level_cm], ...]}
## for the 3 m cells whose columns meet the box, sorted by j then i, so an LLM `drain` names a measured level; {} when
## there is none.
func read_region(lo: Vector3i, hi: Vector3i) -> Dictionary:
	var out := []
	for c: Vector2i in store.levels:
		if c.x * LATTICE + LATTICE - 1 >= lo.x and c.x * LATTICE <= hi.x and c.y * LATTICE + LATTICE - 1 >= lo.z and c.y * LATTICE <= hi.z:
			out.append([c.x, c.y, store.level(c)])
	if out.is_empty():
		return {}
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0]))
	return {"water_cells": out}


## True when a thing standing at (x, y, z) stands in water: its 3 m cell holds a level more than `wet` m above y
## (PATCHES-W.md W1: what land_scatter.gd and `trunk_foot` would ask).
func wet_at(x: float, y: float, z: float, wet := 0.05) -> bool:
	var c := Vector2i(floori(x / LATTICE), floori(z / LATTICE))
	return store.has(c) and store.level(c) / 100.0 > y + wet


## The ghost of this layer's part of a dry run: the cells the scratch copy floods or re-levels in holo, those it
## drains in red (water_mesh.gd `ghost`); null when it changes nothing.
func preview_node(sc: Variant) -> Node3D:
	if not (sc is RefCounted) or (sc as RefCounted).get("store") == null:
		return null
	var other: Dictionary = (sc as RefCounted).get("store").levels
	var added := {}
	var removed := {}
	for c: Vector2i in other:
		if not store.has(c) or store.level(c) != int(other[c]):
			added[c] = int(other[c])
	for c: Vector2i in store.levels:
		if not other.has(c):
			removed[c] = store.level(c)
	return WaterMesh.ghost(added, removed)


# ------------------------------------------------------------------ drawing
## The chunks round cell `c` (its own and those its ring reaches) redraw in `step`.
func _touch(c: Vector2i) -> void:
	if scratch:
		return
	for o: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		dirty[WaterStore.chunk_of(c + o)] = true


## Redraws at most PER_STEP dirty chunks (all of them for a flush's budget): the mesh, then the scatter standing in it.
func step(budget: int) -> int:
	_make()
	if scatter != null:
		scatter.keep()
	if dirty.is_empty():
		return 0
	if mesh == null:
		dirty.clear()
		return 0
	var ids: Array = dirty.keys()
	ids.sort()
	var count: int = ids.size() if budget >= 1 << 16 else maxi(1, budget * PER_STEP / 4)
	var h := Callable(self, "vertex_cm")
	for ch: Vector2i in ids.slice(0, count):
		dirty.erase(ch)
		mesh.draw(ch, store.levels, h)
		if scatter != null:
			var r: Array = scatter.update(ch, store.levels)
			stats.hidden += int(r[0])
			stats.shown += int(r[1])
	return mini(count, ids.size())


func pending() -> int:
	return dirty.size()


# ------------------------------------------------------------------ files (tl.build/3 `water`)
func save_part() -> Dictionary:
	return {} if store.levels.is_empty() else {"water": WaterStore.records(store.levels)}


func load_part(doc: Dictionary) -> String:
	if not doc.has("water"):
		return ""
	var into := {}
	var why := WaterStore.read_records(doc.water, into)
	if why != "":
		return why
	for c: Vector2i in into:
		store.levels[c] = int(into[c])
		_touch(c)
	return ""


func clear() -> void:
	for c: Vector2i in store.levels:
		_touch(c)
	store.clear()


func size() -> int:
	return store.size()


func content_hash() -> String:
	return store.content_hash()


func copy() -> RefCounted:
	var c: RefCounted = (get_script() as GDScript).new(ctx)
	c.scratch = true
	c.store = store.duplicate_store()
	return c


func free_all() -> void:
	if scatter != null:
		scatter.restore()
	if mesh != null:
		mesh.free_all()
	mesh = null
	scatter = null
	_made = true                         # the builder is leaving: nothing is drawn again
