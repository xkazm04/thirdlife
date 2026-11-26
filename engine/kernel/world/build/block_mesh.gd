extends RefCounted
## WP1: draws and collides the Home's blocks. A section (blocks.gd `sec`, 16 m by default) is meshed on its own: one
## MeshInstance3D (one toon surface in TLStyle's palette material; its child "Glass" holds the glass) and one ConcavePolygonShape3D of
## the same triangles, so what the visitor stands on is what is drawn. A chunk (96 m) has ONE static body in the
## visitor's WorldSpace (tag "home blocks", layer 1), holding the shapes of its non-empty sections; it is made when the
## chunk gets its first block and dropped with its last. Never a pack's space, never a state hash.
##
## A rebuild reads the section and a border of two cells round it (joined forms read neighbours, hidden faces read the
## neighbour's form) from a dense grid, walks the section's cells in index order and appends each block's arrays
## (shapes.gd), leaving out the faces its neighbours cover. Same store, same arrays, same hash.

const Blocks := preload("res://kernel/world/build/blocks.gd")
const Shapes := preload("res://kernel/world/build/shapes.gd")
const Collider := preload("res://kernel/world/land/chunk_collider.gd")
const BORDER := 2
const TAG := "home blocks"
const STAT := "block_faces"

var store: RefCounted                   # blocks.gd
var holder: Node3D                      # parent of the section meshes (null: arrays and shapes only)
var ws: Object                          # the visitor's WorldSpace (null: no colliders)
var meshes := {}                        # section -> MeshInstance3D
var shapes := {}                        # section -> ConcavePolygonShape3D
var tris := {}                          # section -> triangles
var hashes := {}                        # section -> SHA-1 of its vertex arrays
var bodies := {}                        # chunk -> {"body": RID, "faces": int, "stat": STAT} (chunk_collider.gd drop)
var counters := {"sections": 0, "chunks": 0, "section_usec": [], "section_at": [], "chunk_usec": []}
var keep_times := false                 # record every rebuild's wall-clock usec (measured and reported, never decided on)


func _init(blocks: RefCounted, parent: Node3D, space: Object) -> void:
	store = blocks
	holder = parent
	ws = space


## Rebuilds at most `budget` dirty sections (sorted, so the order never depends on the edits), then refreshes the
## bodies of the chunks they lie in. Returns how many sections were rebuilt.
func step(budget: int) -> int:
	var ids: Array = Blocks.sorted_ids(store.dirty)
	var done := 0
	var chunks := {}
	for s: Vector2i in ids:
		if done >= budget:
			break
		store.dirty.erase(s)
		rebuild(s)
		chunks[store.chunk_of_section(s)] = true
		done += 1
	for ch: Vector2i in Blocks.sorted_ids(chunks):
		refresh_body(ch)
	return done


func pending() -> int:
	return store.dirty.size()


# ------------------------------------------------------------------ one section
func rebuild(s: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	var arr: Dictionary = arrays(s)
	counters.sections += 1
	if arr.is_empty():
		tris.erase(s)
		hashes.erase(s)
		shapes.erase(s)
		if meshes.has(s):
			(meshes[s] as Node).queue_free()
			meshes.erase(s)
	else:
		tris[s] = arr.tris
		hashes[s] = arr.hash
		var faces: PackedVector3Array = arr.col
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		shapes[s] = shape
		if holder != null:
			_draw(s, arr)
	if keep_times:
		(counters.section_usec as Array).append(Time.get_ticks_usec() - t0)
		(counters.section_at as Array).append(s)


## The section's triangles: {"v", "n", "cu", "gv", "gn", "gcu", "col" (the collider's), "tris", "hash"} in section-local metres (x and z from the
## section's corner, y world), or {} when it holds no block.
func arrays(s: Vector2i) -> Dictionary:
	var own: Variant = store.sections.get(s)
	if own == null or (own as Dictionary).is_empty():
		return {}
	var S: int = store.sec
	var cells: Array = (own as Dictionary).keys()
	cells.sort()
	var y0: int = int(cells[0]) / (S * S) - BORDER
	var h: int = int(cells[cells.size() - 1]) / (S * S) - y0 + 1 + BORDER
	var w := S + 2 * BORDER
	var plane := w * w
	var grid := PackedInt32Array()
	grid.resize(plane * h)
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var d: Variant = store.sections.get(s + Vector2i(dx, dz))
			if d == null:
				continue
			var near := dx == 0 and dz == 0
			for idx: int in (d as Dictionary):
				var gx := idx % S + dx * S + BORDER
				var rest := idx / S
				var gz := rest % S + dz * S + BORDER
				var gy := rest / S - y0
				if near or (gx >= 0 and gx < w and gz >= 0 and gz < w and gy >= 0 and gy < h):
					grid[gx + w * (gz + w * gy)] = (d as Dictionary)[idx]
	var off := PackedInt32Array([1, -1, plane, -plane, w, -w])
	var keys := PackedInt32Array()
	keys.resize(grid.size())
	keys.fill(-1)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var cu := PackedFloat32Array()
	var gv := PackedVector3Array()
	var gn := PackedVector3Array()
	var gcu := PackedFloat32Array()
	var col := PackedVector3Array()
	for idx: int in cells:
		var lx: int = idx % S
		var rest: int = idx / S
		var lz: int = rest % S
		var ly: int = rest / S
		var gi := (lx + BORDER) + w * ((lz + BORDER) + w * (ly - y0))
		var c := grid[gi]
		var e: Shapes.Entry = Shapes.entry(_key(grid, keys, gi, off), Blocks.mat_of(c))
		var o := Transform3D(Basis.IDENTITY, Vector3(lx, ly + Blocks.Y_MIN, lz))
		for side: int in 7:
			var nm := 0
			if side < 6 and e.cover[side] != 0:
				var ni := gi + off[side]
				if grid[ni] != 0:
					nm = Shapes.side_mask(_key(grid, keys, ni, off), side ^ 1)
					if nm != 0 and (e.cover[side] & ~nm) == 0:
						continue                      # the neighbour covers this whole face
			if nm != 0:
				for p: Array in e.polys[side]:
					if (int(p[0]) & ~nm) == 0:
						continue
					if p[4]:
						gv.append_array(o * (p[1] as PackedVector3Array)); gn.append_array(p[2]); gcu.append_array(p[3])
					else:
						v.append_array(o * (p[1] as PackedVector3Array)); n.append_array(p[2]); cu.append_array(p[3])
					col.append_array(o * (p[5] as PackedVector3Array))
				continue
			var ek: PackedVector3Array = e.cv[side]
			if not ek.is_empty():
				col.append_array(o * ek)
			var ev: PackedVector3Array = e.v[side]
			if not ev.is_empty():
				v.append_array(o * ev); n.append_array(e.n[side]); cu.append_array(e.cu[side])
			var egv: PackedVector3Array = e.gv[side]
			if not egv.is_empty():
				gv.append_array(o * egv); gn.append_array(e.gn[side]); gcu.append_array(e.gcu[side])
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA1)
	for part: PackedByteArray in [v.to_byte_array(), cu.to_byte_array(), gv.to_byte_array(), gcu.to_byte_array()]:
		hc.update(part if not part.is_empty() else PackedByteArray([0]))
	return {"v": v, "n": n, "cu": cu, "gv": gv, "gn": gn, "gcu": gcu, "col": col, "tris": (v.size() + gv.size()) / 3,
		"hash": hc.finish().hex_encode()}


func _key(grid: PackedInt32Array, keys: PackedInt32Array, gi: int, off: PackedInt32Array) -> int:
	var k := keys[gi]
	if k < 0:
		k = Shapes.key_at(grid, gi, off)
		keys[gi] = k
	return k


## WP2 round 2: the glass is drawn by a MeshInstance3D of its own, a child of the section's ("Glass"). One instance
## holding a toon surface and a glass surface drew every pane 1 m off along +x: instance uniforms are numbered per
## shader in declaration order, and toon's slot 0 is `build` (1.0), which glass.gdshader read as its `tl_plot` (slot 0):
## an offset of (1, 0, 0). Measured in the exe (PATCHES-WP2 B4); a pane on the toon material sat in its frame.
func _draw(s: Vector2i, arr: Dictionary) -> void:
	var mesh := ArrayMesh.new()
	_surface(mesh, arr.v, arr.n, arr.cu, TLStyle.material("white"))
	var gmesh := ArrayMesh.new()
	_surface(gmesh, arr.gv, arr.gn, arr.gcu, TLStyle.material("glass"))
	var mi: MeshInstance3D = meshes.get(s)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Blocks_%d_%d" % [s.x, s.y]
		mi.position = Vector3(s.x * store.sec, 0.0, s.y * store.sec)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var g := MeshInstance3D.new()
		g.name = "Glass"
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(g)
		holder.add_child(mi)
		meshes[s] = mi
	mi.mesh = mesh
	(mi.get_node("Glass") as MeshInstance3D).mesh = gmesh if gmesh.get_surface_count() > 0 else null


static func _surface(mesh: ArrayMesh, v: PackedVector3Array, n: PackedVector3Array, cu: PackedFloat32Array, mat: Material) -> void:
	if v.is_empty():
		return
	var col := PackedColorArray()
	col.resize(v.size())
	col.fill(Color.WHITE)
	var uv := PackedVector2Array()
	uv.resize(v.size())
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_CUSTOM0] = cu
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


# ------------------------------------------------------------------ one chunk's body
## The chunk's static body holds the shape of every non-empty section in it (sorted); none left: the body goes.
func refresh_body(ch: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	counters.chunks += 1
	if ws == null:
		return
	var per: int = Blocks.CHUNK / store.sec
	var parts := []
	var faces := 0
	for sz in range(ch.y * per, ch.y * per + per):
		for sx in range(ch.x * per, ch.x * per + per):
			var s := Vector2i(sx, sz)
			if shapes.has(s):
				parts.append([shapes[s], Transform3D(Basis.IDENTITY, Vector3(sx * store.sec, 0.0, sz * store.sec))])
				faces += int(tris[s])
	if parts.is_empty():
		if bodies.has(ch):
			Collider.drop(bodies[ch], ws)
			bodies.erase(ch)
	else:
		if not bodies.has(ch):
			var was: String = ws.get("tag")
			ws.set("tag", TAG)
			var rid: RID = ws.call("_static", parts[0][0], parts[0][1])
			ws.set("tag", was)
			bodies[ch] = {"body": rid, "faces": 0, "stat": STAT}
		var b: Dictionary = bodies[ch]
		PhysicsServer3D.body_clear_shapes(b.body)
		for p: Array in parts:
			PhysicsServer3D.body_add_shape(b.body, (p[0] as Shape3D).get_rid(), p[1])
		var stats: Dictionary = ws.get("stats")
		stats[STAT] = int(stats.get(STAT, 0)) + faces - int(b.faces)
		b.faces = faces
	if keep_times:
		(counters.chunk_usec as Array).append(Time.get_ticks_usec() - t0)


## The chunk's triangles and its mesh hash (SHA-1 over its sections' hashes, sorted): the identity of what is drawn.
func chunk_figures(ch: Vector2i) -> Dictionary:
	var per: int = Blocks.CHUNK / store.sec
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA1)
	var count := 0
	for sz in range(ch.y * per, ch.y * per + per):
		for sx in range(ch.x * per, ch.x * per + per):
			var s := Vector2i(sx, sz)
			if hashes.has(s):
				hc.update(("%d,%d:%s;" % [sx, sz, hashes[s]]).to_utf8_buffer())
				count += int(tris[s])
	return {"tris": count, "hash": hc.finish().hex_encode()}


## Everything this mesher made, gone (the meshes freed, the bodies dropped from the space).
func free_all() -> void:
	for s: Vector2i in meshes:
		(meshes[s] as Node).queue_free()
	meshes.clear()
	if ws != null:
		for ch: Vector2i in bodies:
			Collider.drop(bodies[ch], ws)
	bodies.clear()
	shapes.clear()
	tris.clear()
	hashes.clear()
