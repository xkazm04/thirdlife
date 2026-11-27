extends RefCounted
## M2 (spark world-sandbox): the `land` layer of the edit log: the ops `land` (heights on the 3 m lattice) and `paint`
## (the ground material of 3 m cells), contracts/BUILD.md "More operations", saved as tl.build/2 `land` and `paint`.
## The edits are a sparse store (land_store.gd) OVER the Home's own ground (land_ground.gd: the valley's drawn mesh;
## flat ground at 0 for a builder without a valley); valley.gd `height` is never changed.
##   land_mesh.gd     an edited chunk drawn by its own 3 m mesh, the valley's cells there hidden; its collider triangles
##                    replace the valley's in home/hook.gd (`chunk_faces`)
##   land_scatter.gd  trees, rushes and hedges follow the ground or are hidden; trunks likewise (`trunk_foot`)
##   land_protect.gd  where land and paint are refused (an "area" rule of protect.gd), with the reason
## Edits change the store at once; drawing, colliders and scatter follow in `step`, a chunk at a time (frames).
## Heights in a record are absolute cm (`from_cm`, `to_cm`); a vertex set back to the ground's own height has no entry.
## A brush stroke is one op (tools/sculpt_tool.gd, tools/paint_tool.gd): `stroke_begin`, live `stroke_set` /
## `stroke_paint`, then `stroke_end` gives the op (each vertex's height at its first touch and its last) and puts the
## store back, and the tool applies the op through the log (one batch, one undo). Interface: BUILD.md "Layers".

const OpUtil := preload("res://kernel/world/build/op_util.gd")
const LandStore := preload("res://kernel/world/build/land_store.gd")
const LandGround := preload("res://kernel/world/build/land_ground.gd")
const LandMesh := preload("res://kernel/world/build/land_mesh.gd")
const LandScatter := preload("res://kernel/world/build/land_scatter.gd")
const LandProtect := preload("res://kernel/world/build/land_protect.gd")
const LAND_KEYS := ["v", "op", "verts", "author", "batch"]
const PAINT_KEYS := ["v", "op", "cells", "author", "batch"]
const PAINTS := ["grass", "grass_dark", "grass_dry", "dirt", "sand", "stone", "rock_warm", "cliff", "valley"]
const LATTICE := 3                      # metres between land vertices; a paint cell is LATTICE square
const IJ_MAX := 100000                  # |i|, |j|: the op's bound (the valley refuses beyond its extent: "outside the Home")
const CM_MAX := 100000                  # |height| in cm (1 km)
const LIMIT_CM := 2400                  # a vertex stays within 24 m of the ground's own height
const PER_STEP := 4                     # chunks redrawn per `step` at the default budget (4): a brush's 2 x 2

var id := "land"
var ctx: Dictionary
var store: RefCounted = LandStore.new()
var g: RefCounted = null                # land_ground.gd, made on first need (the valley is built by then)
var mesh: RefCounted = null             # land_mesh.gd (null: nothing drawn: flat ground, or a scratch copy)
var scatter: RefCounted = null
var guard: RefCounted = null            # land_protect.gd
var scratch := false                    # a preview's copy: no mesh, no hook, no scatter
var dirty := {}                         # Vector2i chunk -> Rect2: where its mesh must be worked out again (`step`)
var bodies := {}                        # Vector2i chunk -> true: its body and scatter follow (`step`), oldest first
var stats := {"rebuilt": 0, "mesh_usec": [], "body_usec": [], "moved": 0, "hidden": 0}    # each mesh redraw, each body + scatter
var _stroke := {}                       # {"kind": "land" | "paint", "from": {Vector2i: cm or name}}


## `ctx`: home_build.gd's context (BUILD.md "Layers": blocks, protect, space, root, seed, home).
func _init(c: Dictionary) -> void:
	ctx = c


func ops() -> PackedStringArray:
	return PackedStringArray(["land", "paint"])


## The op kinds the LLM may write for this layer (command_ask.gd `ops_now`, BUILD.md "Layers"): land, paint.
func offers() -> Array:
	return ["land", "paint"]


## The Home's ground under this layer: the valley of the landscape `root` hangs under (its meta "tl_home"), else flat.
func ground() -> RefCounted:
	if g != null:
		return g
	var r: Variant = ctx.get("root")
	var land: Node3D = (r as Node3D).get_parent() as Node3D if r is Node3D and is_instance_valid(r) else null
	var hook: RefCounted = land.get_meta(&"tl_home") if land != null and land.has_meta(&"tl_home") else null
	g = LandGround.new(hook)
	guard = LandProtect.new(g, ctx.get("blocks"), ctx.get("protect"), land)
	guard.height_at = Callable(self, "height_at")
	if not scratch and not g.flat():
		mesh = LandMesh.new(g, store, land)
		scatter = LandScatter.new(g, land)
		scatter.home = ctx.get("home")
		hook.land = weakref(self)
	return g


# ------------------------------------------------------------------ ops
## Well-formed (contract keys, types, ranges, paint names, no vertex or cell twice). Not strict (an op handed to
## `apply`): a land vertex may be [i, j, to_cm], and the layer fills from_cm in (`raw`).
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
		var three: bool = land and not strict and typeof(e) == TYPE_ARRAY and (e as Array).size() == 3
		if typeof(e) != TYPE_ARRAY or ((e as Array).size() != 4 and not three):
			return "%s: every entry is [i, j, %s]" % [key, "from_cm, to_cm" if land else "\"<from>\", \"<to>\""]
		var a: Array = e
		for q: int in 2:
			if OpUtil.int_of(a[q]) == null or absi(int(a[q])) > IJ_MAX:
				return "%s: i and j must be integers within %d" % [key, IJ_MAX]
		var ij := Vector2i(int(a[0]), int(a[1]))
		if seen.has(ij):
			return "%s: [%d, %d] is named twice" % [key, ij.x, ij.y]
		seen[ij] = true
		for q: int in range(2, a.size()):
			if land and (OpUtil.int_of(a[q]) == null or absi(int(a[q])) > CM_MAX):
				return "verts: heights are integer cm within %d" % CM_MAX
			if not land and (typeof(a[q]) != TYPE_STRING or not PAINTS.has(a[q])):
				return "cells: '%s' is not a paint (%s)" % [str(a[q]), ", ".join(PAINTS)]
	return OpUtil.tail(d, strict)


## The rules: every entry starts where the ground is now (when it names from), stays within 24 m of the ground's own
## height, and lies outside the protected areas (land_protect.gd and every other "area" rule). One entry refused
## refuses the op (a stroke's tool leaves refused vertices out before it applies).
func can_apply(op: Dictionary) -> String:
	ground()
	var land: bool = op.op == "land"
	var list: Array = op.verts if land else op.cells
	var box := _box(list)
	if guard != null:
		guard.begin_batch(box)
	var why := ""
	for e: Array in list:
		var v := Vector2i(int(e[0]), int(e[1]))
		if land:
			why = _from_check(v, int(e[2]) if e.size() == 4 else null, cm_at(v))
			if why == "":
				why = limit_refusal(v, int(e[e.size() - 1]))
			if why == "":
				why = water_refusal(v, int(e[e.size() - 1]))
		elif str(e[2]) != store.paint_at(v):
			why = "cells: [%d, %d] is '%s', not '%s'" % [v.x, v.y, store.paint_at(v), str(e[2])]
		if why == "":
			why = refusal(v, op.op)
		if why != "":
			break
	if guard != null:
		guard.end_batch()
	return why


static func _from_check(v: Vector2i, from: Variant, now: int) -> String:
	if from != null and int(from) != now:
		return "verts: [%d, %d] is at %d cm, not %d" % [v.x, v.y, now, int(from)]
	return ""


## Why vertex (land) or cell (paint) `v` may not be changed now: the protected areas ("" = it may).
func refusal(v: Vector2i, what: String) -> String:
	var pr: RefCounted = ctx.get("protect")
	if pr == null:
		return ""
	var r := Rect2(v.x * LATTICE - LATTICE, v.y * LATTICE - LATTICE, 2 * LATTICE, 2 * LATTICE) if what == "land" \
		else Rect2(v.x * LATTICE, v.y * LATTICE, LATTICE, LATTICE)
	return str(pr.refusal_area(r, what))


## Why vertex `v` may not be at `cm`: more than 24 m from the ground's own height ("" = it may).
func limit_refusal(v: Vector2i, cm: int) -> String:
	var base: int = ground().base_cm(v)
	if absi(cm - base) > LIMIT_CM:
		return "height limit (24 m from the ground's own %.1f m)" % (base / 100.0)
	return ""


## Why vertex `v` may not go down to `cm`: under the river's water ribbon there (land_protect.gd; "" = it may).
func water_refusal(v: Vector2i, cm: int) -> String:
	ground()
	return str(guard.water_refusal(v, cm, cm_at(v))) if guard != null else ""


func fits(rec: Dictionary) -> String:
	ground()
	var land: bool = rec.op == "land"
	for e: Array in rec.verts if land else rec.cells:
		var v := Vector2i(int(e[0]), int(e[1]))
		var why := _from_check(v, int(e[2]), cm_at(v)) if land else ("" if str(e[2]) == store.paint_at(v) else "cells: [%d, %d] is '%s', not '%s'" % [v.x, v.y, store.paint_at(v), str(e[2])])
		if why != "":
			return why
	return ""


## The op as journaled: keys in the contract's order, numbers as ints, from_cm filled in for [i, j, to_cm].
func raw(op: Dictionary) -> Dictionary:
	var land: bool = op.op == "land"
	var key := "verts" if land else "cells"
	var list := []
	for e: Array in op[key]:
		var v := Vector2i(int(e[0]), int(e[1]))
		if land:
			list.append([v.x, v.y, int(e[2]) if e.size() == 4 else cm_at(v), int(e[e.size() - 1])])
		else:
			list.append([v.x, v.y, e[2], e[3]])
	return {"v": 1, "op": op.op, key: list}


func apply(rec: Dictionary) -> void:
	ground()
	if rec.op == "land":
		for e: Array in rec.verts:
			var v := Vector2i(int(e[0]), int(e[1]))
			store.set_cm(v, int(e[3]), g.base_cm(v))
			_touch_vertex(v)
	else:
		for e: Array in rec.cells:
			var c := Vector2i(int(e[0]), int(e[1]))
			store.set_paint(c, str(e[3]))
			_touch_cell(c)


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


## The ground every entry's area lies in (a vertex's four cells, or a cell): the blocks' columns are read once for it.
static func _box(list: Array) -> Rect2:
	var box := Rect2()
	for k: int in list.size():
		var r := Rect2(int(list[k][0]) * LATTICE - LATTICE, int(list[k][1]) * LATTICE - LATTICE, 3 * LATTICE, 3 * LATTICE)
		box = r if k == 0 else box.merge(r)
	return box


# ------------------------------------------------------------------ heights
## The height of vertex `v` now, in cm (the ground's own where nobody moved it).
func cm_at(v: Vector2i) -> int:
	return int(store.heights[v]) if store.heights.has(v) else ground().base_cm(v)


## How far the ground at (x, z) is from its own height: the lattice deltas on the lattice's triangles (metres).
func delta_at(x: float, z: float) -> float:
	if store.heights.is_empty():
		return 0.0
	var li := floori(x / LATTICE)
	var lj := floori(z / LATTICE)
	var u := x / LATTICE - li
	var w := z / LATTICE - lj
	var a := _d(Vector2i(li, lj))
	var c := _d(Vector2i(li + 1, lj + 1))
	if u >= w:
		var b := _d(Vector2i(li + 1, lj))
		return a + (b - a) * u + (c - b) * w
	var d := _d(Vector2i(li, lj + 1))
	return a + (c - d) * u + (d - a) * w


func _d(v: Vector2i) -> float:
	if not store.heights.has(v):
		return 0.0
	return float(store.heights[v]) / 100.0 - ground().y(v.x * LATTICE, v.y * LATTICE)


## M3's reader (and home/hook.gd `ground_y`): the ground's height at (x, z) with every edit, the surface the edited
## chunks draw (their own mesh differs from it by the triangles' split only, millimetres where the valley's 12 m
## creases cross a 3 m cell).
func height_at(x: float, z: float) -> float:
	return ground().y(x, z) + delta_at(x, z)


## The drawn surface's height (an edited chunk's own triangles, else the valley's): what colliders and the eye see.
func drawn_height_at(x: float, z: float) -> float:
	ground()
	if mesh != null:
		for id: Vector2i in mesh.chunks:
			var y: float = mesh.y_at(id, x, z)
			if not is_nan(y):
				return y
	return g.y(x, z)


## home/hook.gd: where a trunk standing at `foot` stands now (it moves with the ground), or null (its tree is hidden).
func trunk_foot(foot: Vector3) -> Variant:
	var d := delta_at(foot.x, foot.z)
	if absf(d) > LandScatter.HIDE or (scatter != null and scatter.wet(foot.x, foot.z)):
		return null
	return foot + Vector3(0.0, d, 0.0)


# ------------------------------------------------------------------ strokes (the tools)
func stroke_begin(kind: String) -> void:
	ground()
	_stroke = {"kind": kind, "from": {}}


func stroking() -> bool:
	return not _stroke.is_empty()


## Sets vertex `v` to `cm` live (not journaled); the stroke remembers where it was at its first touch.
func stroke_set(v: Vector2i, cm: int) -> void:
	var from: Dictionary = _stroke.from
	if not from.has(v):
		from[v] = cm_at(v)
	store.set_cm(v, cm, g.base_cm(v))
	_touch_vertex(v)


func stroke_paint(c: Vector2i, name: String) -> void:
	var from: Dictionary = _stroke.from
	if not from.has(c):
		from[c] = store.paint_at(c)
	store.set_paint(c, name)
	_touch_cell(c)


## Ends the stroke: the store goes back to where it was, and the op is returned ({} when nothing changed): each
## entry from its first touch to its last value, sorted by j then i; entries the rules refuse now are left out.
func stroke_end() -> Dictionary:
	if _stroke.is_empty():
		return {}
	var kind: String = _stroke.kind
	var from: Dictionary = _stroke.from
	_stroke = {}
	var keys: Array = from.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var list := []
	for v: Vector2i in keys:
		if kind == "land":
			var to := cm_at(v)
			store.set_cm(v, int(from[v]), g.base_cm(v))
			_touch_vertex(v)
			if to != int(from[v]):
				list.append([v.x, v.y, int(from[v]), to])
		else:
			var to: String = store.paint_at(v)
			store.set_paint(v, str(from[v]))
			_touch_cell(v)
			if to != str(from[v]):
				list.append([v.x, v.y, str(from[v]), to])
	if list.is_empty():
		return {}
	if guard != null:
		guard.begin_batch(_box(list))
	list = list.filter(func(e: Array) -> bool: return refusal(Vector2i(e[0], e[1]), kind) == "")
	if guard != null:
		guard.end_batch()
	return {} if list.is_empty() else {"op": kind, ("verts" if kind == "land" else "cells"): list, "author": "hand"}


## A tool asks many vertices at once: the blocks' columns of `rect` are read once until `end_asking`.
func begin_asking(rect: Rect2) -> void:
	ground()
	if guard != null:
		guard.begin_batch(rect)


func end_asking() -> void:
	if guard != null:
		guard.end_batch()


# ------------------------------------------------------------------ dirty chunks, drawing
func _touch_vertex(v: Vector2i) -> void:
	_mark(Vector2(v.x * LATTICE - LATTICE, v.y * LATTICE - LATTICE), Vector2(v.x * LATTICE + LATTICE, v.y * LATTICE + LATTICE))


func _touch_cell(c: Vector2i) -> void:
	_mark(Vector2(c.x * LATTICE - LATTICE, c.y * LATTICE - LATTICE), Vector2(c.x * LATTICE + 2 * LATTICE, c.y * LATTICE + 2 * LATTICE))


## The chunks the box `lo`..`hi` meets get it added to what they must redraw.
func _mark(lo: Vector2, hi: Vector2) -> void:
	if mesh == null:
		return
	var r: Array = g.chunks_meeting(lo, hi)
	var box := Rect2(lo, hi - lo)
	for z: int in range((r[0] as Vector2i).y, (r[1] as Vector2i).y + 1):
		for x: int in range((r[0] as Vector2i).x, (r[1] as Vector2i).x + 1):
			var id := Vector2i(x, z)
			dirty[id] = (dirty[id] as Rect2).merge(box) if dirty.has(id) else box


## True when an edit lies within 3 m of chunk `id`'s drawn rectangle: a moved vertex whose four cells reach into it,
## or a painted cell whose corners do. Such a chunk is drawn by its own mesh.
func chunk_open(id: Vector2i) -> bool:
	var r: Rect2 = ground().rect_of(id)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return false
	var i0 := floori(r.position.x / LATTICE - 1.0) + 1
	var i1 := ceili(r.end.x / LATTICE + 1.0) - 1
	var j0 := floori(r.position.y / LATTICE - 1.0) + 1
	var j1 := ceili(r.end.y / LATTICE + 1.0) - 1
	if not store.heights.is_empty():
		for j: int in range(j0, j1 + 1):
			for i: int in range(i0, i1 + 1):
				if store.heights.has(Vector2i(i, j)):
					return true
	# a painted or planted cell reaches the vertices one cell before it to two after it (land_mesh.gd: the blur)
	var grown := growth()
	for d: Dictionary in [store.paints, grown]:
		if d.is_empty():
			continue
		for j: int in range(j0 - 2, j1 + 2):
			for i: int in range(i0 - 2, i1 + 2):
				if d.has(Vector2i(i, j)):
					return true
	return false


## M5: the plants layer's growth per 3 m cell (Vector2i -> id 1 meadow, 2 flowers, 3 tall grass), read only; {} without
## one. The land mesh draws it (land_mesh.gd: the UV density and the green), so a plant op opens its chunk as paint does.
func growth() -> Dictionary:
	var h: Variant = ctx.get("home")
	var home: RefCounted = (h as WeakRef).get_ref() if h is WeakRef else null
	var pl: RefCounted = home.call("layer", "plants") if home != null else null
	var cells: Variant = pl.get("cells") if pl != null else null
	return cells if cells is Dictionary else {}


## M5 (lane W): chunk `chunk`'s scatter and trunks are asked again in `step` (after a flood or a drain).
func refresh_scatter(chunk: Vector2i) -> void:
	bodies[chunk] = true


## M5: the plants layer changed the growth of cell `c`: its chunk(s) redraw in `step`.
func touch_growth(c: Vector2i) -> void:
	_touch_cell(c)


## Redraws at most PER_STEP dirty chunks' meshes (only where they changed), then their bodies and scatter: at most one
## body a frame while a stroke is live (the oldest first: a body takes longer than a mesh, and the cursor ray meets the
## body), PER_STEP otherwise; all of it when `budget` is a flush's. Returns the chunks redrawn.
func step(budget: int) -> int:
	if dirty.is_empty() and bodies.is_empty():
		return 0
	if mesh == null:
		dirty.clear()
		bodies.clear()
		return 0
	var all := budget >= 1 << 16
	mesh.growth = growth()
	var ids: Array = dirty.keys()
	ids.sort()
	var count: int = ids.size() if all else maxi(1, budget * PER_STEP / 4)
	var done := 0
	for chunk: Vector2i in ids.slice(0, count):
		var box: Rect2 = dirty[chunk]
		dirty.erase(chunk)
		var t0 := Time.get_ticks_usec()
		mesh.draw(chunk, chunk_open(chunk), box)
		(stats.mesh_usec as Array).append(Time.get_ticks_usec() - t0)
		if not bodies.has(chunk):
			bodies[chunk] = true
		stats.rebuilt += 1
		done += 1
	var n: int = bodies.size() if all else (1 if stroking() else PER_STEP)
	for chunk: Vector2i in bodies.keys().slice(0, n):
		bodies.erase(chunk)
		var t0 := Time.get_ticks_usec()
		g.hook.refresh(chunk)
		var sc: Array = scatter.update(chunk, Callable(self, "delta_at"))
		stats.moved += int(sc[0])
		stats.hidden += int(sc[1])
		(stats.body_usec as Array).append(Time.get_ticks_usec() - t0)
	return done


func pending() -> int:
	return dirty.size() + bodies.size()


## The collider triangles of chunk `id` when it is edited (home/hook.gd `faces`), else empty (the valley's).
func chunk_faces(chunk: Vector2i) -> PackedVector3Array:
	return mesh.faces(chunk) if mesh != null else PackedVector3Array()


# ------------------------------------------------------------------ files (tl.build/2 `land`, `paint`)
func save_part() -> Dictionary:
	var out := {}
	if not store.heights.is_empty():
		out["land"] = LandStore.records(store.heights)
	if not store.paints.is_empty():
		out["paint"] = LandStore.records(store.paints)
	return out


func load_part(doc: Dictionary) -> String:
	var h := {}
	var p := {}
	for k: String in ["land", "paint"]:
		if doc.has(k):
			var why := LandStore.read_records(doc[k], k, k == "paint", h if k == "land" else p)
			if why != "":
				return why
	ground()
	for v: Vector2i in h:
		store.set_cm(v, int(h[v]), g.base_cm(v))
		_touch_vertex(v)
	for c: Vector2i in p:
		store.paints[c] = int(p[c])
		_touch_cell(c)
	return ""


func clear() -> void:
	for v: Vector2i in store.heights:
		_touch_vertex(v)
	for c: Vector2i in store.paints:
		_touch_cell(c)
	store.clear()


func size() -> int:
	return store.size()


func content_hash() -> String:
	return store.content_hash()


# ------------------------------------------------------------------ copies, reads
func copy() -> RefCounted:
	var c: RefCounted = (get_script() as GDScript).new(ctx)
	c.scratch = true
	c.g = ground()
	c.guard = guard
	c.store = store.duplicate_store()
	return c


## M5: its part of a dry run's ghost (land_ghost.gd `of_land`): what the ops sculpt and paint; null when nothing.
func preview_node(s: Variant) -> Node3D:
	if not (s is RefCounted) or not bool((s as RefCounted).get("scratch")):
		return null
	return (load("res://kernel/world/build/land_ghost.gd") as GDScript).call("of_land", self, s)


## M4's ask: the lattice heights (cm) of the vertices over the box's columns, the painted cells, and the vertices the
## rules refuse now with the reason: {"ground": [[i, j, cm], ...], "paint": [[i, j, "<paint>"], ...],
## "ground_refused": [[i, j, "<reason>"], ...]}, each sorted by j, then i.
func read_region(lo: Vector3i, hi: Vector3i) -> Dictionary:
	ground()
	var i0 := ceili(lo.x / float(LATTICE))
	var i1 := floori((hi.x + 1) / float(LATTICE))
	var j0 := ceili(lo.z / float(LATTICE))
	var j1 := floori((hi.z + 1) / float(LATTICE))
	var heights := []
	var refused := []
	begin_asking(Rect2(i0 * LATTICE - LATTICE, j0 * LATTICE - LATTICE, (i1 - i0 + 2) * LATTICE, (j1 - j0 + 2) * LATTICE))
	for j: int in range(j0, j1 + 1):
		for i: int in range(i0, i1 + 1):
			var v := Vector2i(i, j)
			heights.append([i, j, cm_at(v)])
			var why := refusal(v, "land")
			if why != "":
				refused.append([i, j, why])
	end_asking()
	var paint := []
	for j: int in range(floori(lo.z / float(LATTICE)), floori(hi.z / float(LATTICE)) + 1):
		for i: int in range(floori(lo.x / float(LATTICE)), floori(hi.x / float(LATTICE)) + 1):
			if store.paints.has(Vector2i(i, j)):
				paint.append([i, j, store.paint_at(Vector2i(i, j))])
	return {"ground": heights, "paint": paint, "ground_refused": refused}


## The protect.gd "area" rule this layer adds (BUILD.md "Layers" `add_rules`).
func add_rules(protect: RefCounted) -> void:
	protect.add_rule(Callable(self, "area_rule"), "area")


func area_rule(rect: Rect2, what: String) -> String:
	ground()
	return str(guard.rule(rect, what)) if guard != null else ""


func free_all() -> void:
	if mesh == null:
		return
	var open: Array = mesh.chunks.keys()
	mesh.free_all()
	if scatter != null:
		scatter.restore()
	var hook: RefCounted = g.hook
	if hook != null and hook.get("land") != null and (hook.land as WeakRef).get_ref() == self:
		hook.land = null
		for chunk: Vector2i in open:
			hook.refresh(chunk)
	mesh = null
