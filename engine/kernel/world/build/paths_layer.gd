extends RefCounted
## M5 (spark world-sandbox, lane P): the `paths` layer of the edit log: the ops `path` and `unpath` of splines draped
## on the ground (contracts/BUILD.md "Milestone 5"), saved as tl.build/3 `paths`. Interface: BUILD.md "Layers".
##   path_shape.gd   a path's spline, sampled every metre, and the index of segments ("how far from path k")
##   path_mesh.gd    the drawing: one mesh per 96 m chunk a path crosses, a ribbon in the terrain material (a plank path:
##                   a boardwalk), and the hologram of a path (the tool's ghost, `preview_node`)
##   path_grade.gd   the grading the path tool writes as a land op in the same batch (not part of the path op)
## A path is refused where the ground is protected (protect.gd `refusal_area(rect, "path")` along its samples: the
## village, game lots, lanes, the river band, structures, blocks, pieces), never because the visitor stands on it (it
## has no collider). `unpath` names the whole path it removes. Ids are positive and unique; `next_id` is the next free
## one. The drawing follows the ground: when the land changes under a path (a stroke ends, an undo), its chunks are
## drawn again (`_watch_land`). Meshes follow the store in `step`, one chunk per frame at the default budget.

const OpUtil := preload("res://kernel/world/build/op_util.gd")
const PathShape := preload("res://kernel/world/build/path_shape.gd")
const PathMesh := preload("res://kernel/world/build/path_mesh.gd")
const KEYS := ["v", "op", "id", "pts", "width_cm", "paint", "author", "batch"]
const ORDER := ["v", "op", "id", "pts", "width_cm", "paint"]
const SAVED := ["id", "pts", "width_cm", "paint"]
const PAINTS := ["dirt", "sand", "stone", "rock_warm", "grass_dry", "plank"]
const PTS_MIN := 2
const PTS_MAX := 64
const GAP_MIN_CM := 100
const GAP_MAX_CM := 4800
const WIDTH_MIN_CM := 150
const WIDTH_MAX_CM := 800
const XZ_MAX_CM := 10000000              # |x|, |z| in cm (100 km)
const REACH := 1.0                       # metres past the half width the index answers (`covers` margins)
const ASK_EVERY := 3                     # samples (metres) per protection ask along a path
const VERTS := 120                       # ribbon vertices made per frame at the default budget (about 2.5 ms)

var id := "paths"
var ctx: Dictionary
var scratch := false                     # a preview's copy: no drawing
var paths := {}                          # id -> record {"id", "pts", "width_cm", "paint"} (ints, the saved form)
var info := {}                           # id -> {"rec", "sm", "h", "plank", "secs", "rows", "chunks"}
var index: RefCounted = PathShape.Index.new()
var by_chunk := {}                       # Vector2i -> {id: true}
var dirty := {}                          # Vector2i -> true: its mesh is drawn again in `step`
var drawn := {}                          # Vector2i -> {"nodes": [MeshInstance3D], "tris", "verts", "hash"}
var stats := {"rebuilt": 0, "usec": [], "step_usec": [], "land_checks": 0}   # usec: a chunk's mesh in all; step_usec: each frame's drawing
var root: Node3D = null                  # "HomePaths" (made on the first draw)
var mesher: RefCounted = null            # path_mesh.gd
var _job := {}                           # the chunk being drawn (path_mesh.gd `job_of`), {} none
var _land_mark := []
var _land_sig := {}


## `ctx`: home_build.gd's context (BUILD.md "Layers": blocks, protect, space, root, seed, home).
func _init(c: Dictionary) -> void:
	ctx = c


func ops() -> PackedStringArray:
	return PackedStringArray(["path", "unpath"])


## The op kinds the LLM may write for this layer (command_ask.gd `ops_now`).
func offers() -> Array:
	return ["path", "unpath"]


func _home() -> RefCounted:
	return (ctx.home as WeakRef).get_ref() if ctx.get("home") is WeakRef else null


func _land() -> RefCounted:
	var h := _home()
	return h.call("layer", "land") if h != null else null


func _mesher() -> RefCounted:
	if mesher == null:
		var h := _home()
		var plants: RefCounted = h.call("layer", "plants") if h != null else null
		var land := _land()
		var growth: RefCounted = plants if plants != null and plants.has_method("uv_at") else (land if land != null and land.has_method("uv_at") else null)
		mesher = PathMesh.new(land, growth)
	return mesher


# ------------------------------------------------------------------ ops
## Every key is required on input too (an unpath carries the whole path it removes); v, author and batch may be left
## out when not strict.
func malformed(op: Variant, strict := false) -> String:
	var why := OpUtil.head(op, KEYS)
	if why != "":
		return why
	var d: Dictionary = op
	if not (str(d.get("op")) in ["path", "unpath"]):
		return "op must be \"path\" or \"unpath\""
	for k: String in ["id", "pts", "width_cm", "paint"]:
		if not d.has(k):
			return "%s is missing" % k
	if OpUtil.int_of(d.id) == null or int(d.id) < 1:
		return "id must be a positive integer"
	why = pts_error(d.pts)
	if why != "":
		return why
	if OpUtil.int_of(d.width_cm) == null or int(d.width_cm) < WIDTH_MIN_CM or int(d.width_cm) > WIDTH_MAX_CM:
		return "width_cm must be an integer %d..%d" % [WIDTH_MIN_CM, WIDTH_MAX_CM]
	if typeof(d.paint) != TYPE_STRING or not (str(d.paint) in PAINTS):
		return "paint must be one of %s" % ", ".join(PAINTS)
	return OpUtil.tail(d, strict)


## "" when `pts` is 2-64 points [x_cm, z_cm] of integers, consecutive points 100-4,800 cm apart.
static func pts_error(pts: Variant) -> String:
	if typeof(pts) != TYPE_ARRAY or (pts as Array).size() < PTS_MIN or (pts as Array).size() > PTS_MAX:
		return "pts must be %d-%d points" % [PTS_MIN, PTS_MAX]
	var last := Vector2.ZERO
	var first := true
	for p: Variant in pts:
		if typeof(p) != TYPE_ARRAY or (p as Array).size() != 2 or OpUtil.int_of(p[0]) == null or OpUtil.int_of(p[1]) == null:
			return "pts: every point is [x_cm, z_cm] of integers"
		if absi(int(p[0])) > XZ_MAX_CM or absi(int(p[1])) > XZ_MAX_CM:
			return "pts: [%d, %d] is outside the Home" % [int(p[0]), int(p[1])]
		var here := Vector2(int(p[0]), int(p[1]))
		if not first:
			var gap := here.distance_to(last)
			if gap < GAP_MIN_CM or gap > GAP_MAX_CM:
				return "pts: consecutive points are %d-%d cm apart (%d)" % [GAP_MIN_CM, GAP_MAX_CM, int(gap)]
		last = here
		first = false
	return ""


## The rules: a path's id is free and its ground is not protected; an unpath names a path that is there, as it is.
func can_apply(op: Dictionary) -> String:
	var rec := saved_of(op)
	var n: int = rec.id
	if op.op == "path":
		if paths.has(n):
			return "id %d is taken (the next free id is %d)" % [n, next_id()]
		return refusal_of(rec)
	return _match(rec)


func _match(rec: Dictionary) -> String:
	var n: int = rec.id
	if not paths.has(n):
		return "no path %d" % n
	var have: Dictionary = paths[n]
	for k: String in ["pts", "width_cm", "paint"]:
		if str(have[k]) != str(rec[k]):
			return "path %d is another path (%s)" % [n, k]
	return ""


## Why the ground under path `rec` is protected ("" = it may lie there): protect.gd's areas asked along its samples
## with the half width round each, the visitor left out (a path has no collider; the grading skips him).
func refusal_of(rec: Dictionary) -> String:
	var pr: RefCounted = ctx.get("protect")
	if pr == null:
		return ""
	var sm := PathShape.sample(rec.pts)
	var h := float(rec.width_cm) / 200.0
	var keep: Callable = pr.visitor_at
	pr.visitor_at = Callable(self, "_nowhere")
	var land := _land()
	var p: PackedVector2Array = sm.p
	if land != null:
		land.begin_asking(PathShape.box_of(p, h + 3.0))
	var why := ""
	var n := p.size()
	for i: int in range(0, n, ASK_EVERY):         # one ask per ASK_EVERY samples: the box of them, grown by the half width
		var box := Rect2(p[i], Vector2.ZERO)
		for k: int in range(i + 1, mini(n, i + ASK_EVERY + 1)):
			box = box.expand(p[k])
		why = str(pr.refusal_area(box.grow(h), "path"))
		if why != "":
			break
	if land != null:
		land.end_asking()
	pr.visitor_at = keep
	return why


func _nowhere() -> Vector3:
	return Vector3(1e9, 1e9, 1e9)


## The op as journaled: keys in the contract's order, numbers as ints.
func raw(op: Dictionary) -> Dictionary:
	var rec := saved_of(op)
	return {"v": 1, "op": op.op, "id": rec.id, "pts": rec.pts, "width_cm": rec.width_cm, "paint": rec.paint}


## A path's saved form from an op or a file entry: {"id", "pts", "width_cm", "paint"}, numbers as ints.
static func saved_of(op: Dictionary) -> Dictionary:
	var pts := []
	for q: Variant in op.pts:
		pts.append([int(q[0]), int(q[1])])
	return {"id": int(op.id), "pts": pts, "width_cm": int(op.width_cm), "paint": str(op.paint)}


func fits(rec: Dictionary) -> String:
	var r := saved_of(rec)
	if rec.op == "path":
		return "id %d is taken" % r.id if paths.has(r.id) else ""
	return _match(r)


func apply(rec: Dictionary) -> void:
	var r := saved_of(rec)
	if rec.op == "path":
		_add(r)
	else:
		_take(int(r.id))


func invert(rec: Dictionary) -> Dictionary:
	var out := OpUtil.ordered(rec, ORDER)
	out["op"] = "unpath" if rec.op == "path" else "path"
	return out


## The world box the path lies in (its samples grown by the half width and the edge), over the whole height range.
func dirty_regions(rec: Dictionary) -> Array:
	var r := saved_of(rec)
	var sm := PathShape.sample(r.pts)
	var b := PathShape.box_of(sm.p, float(r.width_cm) / 200.0 + PathMesh.EDGE)
	return [AABB(Vector3(b.position.x, -16.0, b.position.y), Vector3(b.size.x, 128.0, b.size.y))]


func next_id() -> int:
	var n := 0
	for k: int in paths:
		n = maxi(n, k)
	return n + 1


# ------------------------------------------------------------------ the store
func _add(r: Dictionary) -> void:
	var n: int = r.id
	paths[n] = r
	var sm := PathShape.sample(r.pts)
	var h := float(r.width_cm) / 200.0
	var plank: bool = PathMesh.SLABS.has(r.paint)          # a slab (plank, stone), not the terrain
	var secs: Array = PathMesh.sections(sm, h, plank)
	var chunks := {}
	for j: int in secs.size() - 1:
		chunks[PathMesh.chunk_of(((secs[j][0] as Vector2) + (secs[j + 1][0] as Vector2)) * 0.5)] = true
	info[n] = {"rec": r, "sm": sm, "h": h, "plank": plank, "secs": secs, "rows": PathMesh.rows(h, plank), "chunks": chunks.keys(),
		"ext": PathMesh.ext_of(h, plank), "n": (sm.p as PackedVector2Array).size()}
	index.add(n, sm.p, h + REACH)
	for c: Vector2i in chunks:
		if not by_chunk.has(c):
			by_chunk[c] = {}
		(by_chunk[c] as Dictionary)[n] = true
	_touch(n)


func _take(n: int) -> void:
	if not paths.has(n):
		return
	_touch(n)
	for c: Vector2i in info[n].chunks:
		if by_chunk.has(c):
			(by_chunk[c] as Dictionary).erase(n)
			if (by_chunk[c] as Dictionary).is_empty():
				by_chunk.erase(c)
	index.take(n)
	paths.erase(n)
	info.erase(n)


## Path `n`'s chunks are drawn again, and so are the chunks of every path whose field reaches into its area (a crossing).
func _touch(n: int) -> void:
	if scratch or not info.has(n):
		return
	for c: Vector2i in info[n].chunks:
		dirty[c] = true
	var box := PathShape.box_of(info[n].sm.p, float(info[n].h) + PathMesh.EDGE + REACH)
	for k: int in info:
		if k != n and PathShape.box_of(info[k].sm.p, float(info[k].h) + PathMesh.EDGE).intersects(box):
			for c: Vector2i in info[k].chunks:
				dirty[c] = true


## The path whose paint lies under (x, z) (the highest id where two do), or 0.
func path_at(x: float, z: float) -> int:
	var near: Dictionary = index.near(Vector2(x, z))
	var best := 0
	for k: int in near:
		if float(near[k][0]) <= float(info[k].h) and k > best:
			best = k
	return best


## True when (x, z) is on a path or within `margin` metres of its edge (margin at most REACH).
func covers(x: float, z: float, margin := 0.0) -> bool:
	var near: Dictionary = index.near(Vector2(x, z))
	for k: int in near:
		if float(near[k][0]) <= float(info[k].h) + minf(margin, REACH):
			return true
	return false


# ------------------------------------------------------------------ drawing
## Draws the dirty chunks, about VERTS vertices per 4 of `budget` per frame (a chunk's mesh is made over as many frames
## as it needs and shown whole when it is done; the old one stays until then); everything for a flush's budget.
## Returns the chunks finished. The land under the paths is looked at first (`_watch_land`).
func step(budget: int) -> int:
	_watch_land()
	if dirty.is_empty() and _job.is_empty():
		return 0
	if scratch:
		dirty.clear()
		_job = {}
		return 0
	var most: int = 1 << 30 if budget >= 1 << 16 else maxi(1, budget / 4) * VERTS
	var done := 0
	var s0 := Time.get_ticks_usec()
	while most > 0 and (not dirty.is_empty() or not _job.is_empty()):
		if not _job.is_empty() and dirty.has(_job.chunk):
			_job = {}                            # changed again while it was being made: start it over
		if _job.is_empty():
			var ids: Array = dirty.keys()
			ids.sort()
			var c: Vector2i = ids[0]
			dirty.erase(c)
			var on: Array = (by_chunk.get(c, {}) as Dictionary).keys()
			on.sort()
			_job = PathMesh.job_of(c, on, info)
			_job["usec"] = 0
		var t0 := Time.get_ticks_usec()
		var k0: int = _job.k
		var verts0: int = (_job.pos as PackedVector3Array).size()
		var finished: bool = _mesher().run(_job, info, index, most)
		most -= maxi(1, (_job.pos as PackedVector3Array).size() - verts0 + int(_job.k) - k0)
		_job.usec = int(_job.usec) + Time.get_ticks_usec() - t0
		if not finished:
			break
		_install(_job)
		_job = {}
		done += 1
	if budget < 1 << 16:
		(stats.step_usec as Array).append(Time.get_ticks_usec() - s0)
	return done


func pending() -> int:
	return dirty.size() + (0 if _job.is_empty() else 1)


## A finished job's meshes replace its chunk's.
func _install(job: Dictionary) -> void:
	var c: Vector2i = job.chunk
	var t0 := Time.get_ticks_usec()
	_drop(c)
	var arrays: Dictionary = PathMesh.result(job)
	if int(arrays.tris) == 0:
		return
	var entry := {"nodes": [], "tris": int(arrays.tris), "verts": int(arrays.verts), "hash": PathMesh.hash_of(arrays)}
	var parent: Node3D = _root()
	if parent != null:
		for mi: MeshInstance3D in PathMesh.instances(c, arrays):
			parent.add_child(mi)
			(entry.nodes as Array).append(mi)
	drawn[c] = entry
	stats.rebuilt += 1
	(stats.usec as Array).append(int(job.usec) + Time.get_ticks_usec() - t0)


func _drop(c: Vector2i) -> void:
	if not drawn.has(c):
		return
	for n: Variant in drawn[c].nodes:
		if is_instance_valid(n):
			(n as Node).queue_free()
	drawn.erase(c)


## "HomePaths" under the landscape the blocks' root hangs under (null: nothing is drawn, the arrays are still made).
func _root() -> Node3D:
	if root != null and is_instance_valid(root):
		return root
	var r: Variant = ctx.get("root")
	var land: Node3D = (r as Node3D).get_parent() as Node3D if r is Node3D and is_instance_valid(r) else null
	if land == null:
		return null
	root = Node3D.new()
	root.name = "HomePaths"
	land.add_child(root)
	return root


## The land under the paths changed (a sculpt stroke ended, a land op, an undo): the chunks whose ground changed are
## drawn again. Asked once per frame, only when the land's own counters moved (it redrew a chunk, or its size
## changed) and no stroke is live (the ribbon follows at the stroke's end, not every frame of it).
func _watch_land() -> void:
	if scratch or info.is_empty():
		return
	var land := _land()
	if land == null:
		return
	if land.has_method("stroking") and bool(land.call("stroking")):
		return
	var st: Variant = land.get("stats")
	var mark := [int((st as Dictionary).get("rebuilt", 0)) if st is Dictionary else 0, int(land.call("size"))]
	if mark == _land_mark:
		return
	_land_mark = mark
	stats.land_checks += 1
	var sig := _land_sigs(land)
	for c: Vector2i in by_chunk:
		if int(sig.get(c, 0)) != int(_land_sig.get(c, 0)):
			dirty[c] = true
	_land_sig = sig


## chunk -> an order-free sum over the land's entries whose ground reaches the chunk's ribbons (a vertex moves the
## ground 3 m round it; a ribbon reaches 5.1 m past its chunk at most: 8.1 m, rounded up to 9).
func _land_sigs(land: RefCounted) -> Dictionary:
	var sig := {}
	var st: RefCounted = land.get("store")
	if st == null:
		return sig
	for pass_k: int in 2:
		var d: Dictionary = st.heights if pass_k == 0 else st.paints
		for v: Vector2i in d:
			var x := v.x * 3.0
			var z := v.y * 3.0
			var mix := ((v.x * 73856093) ^ (v.y * 19349663) ^ (int(d[v]) * 83492791 + pass_k)) & 0x3fffffff
			for cz: int in range(floori((z - 9.0) / 96.0), floori((z + 9.0) / 96.0) + 1):
				for cx: int in range(floori((x - 9.0) / 96.0), floori((x + 9.0) / 96.0) + 1):
					var c := Vector2i(cx, cz)
					if by_chunk.has(c):
						sig[c] = int(sig.get(c, 0)) + mix
	return sig


## Drawing figures (the case): {"chunks", "tris", "verts", "hashes": {chunk: hash}}.
func figures() -> Dictionary:
	var t := 0
	var v := 0
	var hs := {}
	for c: Vector2i in drawn:
		t += int(drawn[c].tris)
		v += int(drawn[c].verts)
		hs[c] = drawn[c].hash
	return {"chunks": drawn.size(), "tris": t, "verts": v, "hashes": hs}


# ------------------------------------------------------------------ files (tl.build/3 `paths`)
func sorted() -> Array:
	var ids: Array = paths.keys()
	ids.sort()
	return ids.map(func(k: int) -> Dictionary: return (paths[k] as Dictionary).duplicate(true))


func save_part() -> Dictionary:
	return {} if paths.is_empty() else {"paths": sorted()}


## Reads `paths` (absent or empty: no paths): every entry exactly {id, pts, width_cm, paint}, well-formed, ids unique.
func load_part(doc: Dictionary) -> String:
	if not doc.has("paths"):
		return ""
	var list: Variant = doc.paths
	if typeof(list) != TYPE_ARRAY:
		return "paths must be a list"
	var seen := {}
	var recs := []
	for e: Variant in list:
		if typeof(e) != TYPE_DICTIONARY:
			return "paths: every entry is an object"
		for k: Variant in e:
			if not SAVED.has(k):
				return "paths: unknown key '%s'" % str(k)
		var op := (e as Dictionary).duplicate(true)
		op["op"] = "path"
		var why := malformed(op)
		if why != "":
			return "paths: %s" % why
		var r := saved_of(op)
		if seen.has(r.id):
			return "paths: id %d is named twice" % r.id
		seen[r.id] = true
		recs.append(r)
	for r: Dictionary in recs:
		_add(r)
	return ""


func clear() -> void:
	for n: int in paths.keys():
		_take(n)


func size() -> int:
	return paths.size()


func content_hash() -> String:
	return "" if paths.is_empty() else JSON.stringify(sorted(), "", false).sha256_text()


# ------------------------------------------------------------------ copies, reads, the ghost
func copy() -> RefCounted:
	var c: RefCounted = (get_script() as GDScript).new(ctx)
	c.scratch = true
	for n: int in paths:
		c._add((paths[n] as Dictionary).duplicate(true))
	return c


## The ask reads no paths yet (contracts/BUILD.md names no `paths` key of the ask; PATCHES-P.md).
func read_region(_lo: Vector3i, _hi: Vector3i) -> Dictionary:
	return {}


## The ghost of this layer's part of a dry run: the paths `scratch` has that the Home has not (or has otherwise) in
## holo, the paths it took away in red; null when none changed.
func preview_node(sc: Variant) -> Node3D:
	if not (sc is RefCounted) or (sc as RefCounted).get("paths") == null:
		return null
	var after: Dictionary = (sc as RefCounted).get("paths")
	var node := Node3D.new()
	node.name = "PathsGhost"
	for n: int in after:
		if not paths.has(n) or str(paths[n]) != str(after[n]):
			node.add_child(ghost_of(after[n], false))
	for n: int in paths:
		if not after.has(n):
			node.add_child(ghost_of(paths[n], true))
	if node.get_child_count() == 0:
		node.free()
		return null
	return node


## The hologram of path record `r` (red: refused or removed).
func ghost_of(r: Dictionary, red: bool) -> MeshInstance3D:
	var sm := PathShape.sample(r.pts)
	return _mesher().ghost(sm.p, float(r.width_cm) / 200.0, red, "PathGhost %d" % int(r.id))


func free_all() -> void:
	_job = {}
	for c: Vector2i in drawn.keys():
		_drop(c)
	if root != null and is_instance_valid(root):
		root.queue_free()
	root = null
