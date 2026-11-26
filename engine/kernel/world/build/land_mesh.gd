extends RefCounted
## M2 (spark world-sandbox): the drawing and the collider triangles of EDITED chunks. A chunk with an edit near it
## (land_layer.gd `chunk_open`) is drawn by a mesh of its own over its rectangle of valley cells (land_ground.gd
## `rect_of`, the cells home/hook.gd's collider takes for that chunk), and those valley cells are hidden in the valley's
## one mesh (home/ground.gd `hide_cells`). The mesh's grid lines are the 3 m lattice's AND the valley's own grid lines
## inside the rectangle, so:
##   - its rim lies on valley grid lines, and every valley vertex on the rim is a vertex of it with the valley's own
##     height: where the neighbour is the valley, the rim is the valley's edge (the extra lattice points on it lie on
##     that edge's line: no crack, measured in land_case.gd `land.seam`);
##   - where the neighbour is edited too, both compute the shared rim from the same function at the same points.
## The surface is the valley's (land_ground.gd `attrs`) plus the delta field D: the lattice deltas (a vertex's height
## minus the ground's own) interpolated on the lattice's triangles. D is 0 within 3 m of a chunk that is not edited, so
## an edit never reaches a rim the valley meets. Paint adds a colour delta the same way (each painted cell gives a
## quarter of (paint - ground colour) to its four corners): the cel shader takes the nearest land paint per fragment,
## so painted cells read as fields of the paint. Normals are the valley's tilted by D's gradient (central differences
## on the lattice, the same at a rim for both sides). Only drawn under a parent (`root`); colliders: `faces`.

const LandGround := preload("res://kernel/world/build/land_ground.gd")
const L := 3.0
const EPS := 0.001                       # metres: lattice and valley lines closer than this are one line

var g: RefCounted                        # land_ground.gd
var store: RefCounted                    # land_store.gd
var root: Node3D = null                  # "HomeLand" (null: nothing drawn, faces still made)
var chunks := {}                         # Vector2i -> state (see `_open`)
var counters := {"rebuilt": 0, "opened": 0, "closed": 0, "valley_cells_hidden": 0}


func _init(ground: RefCounted, s: RefCounted, parent: Node3D) -> void:
	g = ground
	store = s
	if parent != null:
		root = Node3D.new()
		root.name = "HomeLand"
		parent.add_child(root)


## Chunk `id` drawn as it is now (`open`: it has an edit near it) or given back to the valley. `box` (metres): where
## the store changed since its last draw (only the grid vertices there are worked out again); none: everywhere.
## Returns usec spent.
func draw(id: Vector2i, open: bool, box: Variant = null) -> int:
	var t0 := Time.get_ticks_usec()
	if not open:
		_close(id)
		return Time.get_ticks_usec() - t0
	if not chunks.has(id):
		if not _open(id):
			return Time.get_ticks_usec() - t0
		box = null
	_fill(chunks[id], box)
	counters.rebuilt += 1
	return Time.get_ticks_usec() - t0


func faces(id: Vector2i) -> PackedVector3Array:
	return (chunks[id] as Dictionary).faces if chunks.has(id) else PackedVector3Array()


func is_open(id: Vector2i) -> bool:
	return chunks.has(id)


## The drawn surface's height at (x, z) in an open chunk (its own triangles), or NAN outside every open chunk.
func y_at(id: Vector2i, x: float, z: float) -> float:
	if not chunks.has(id):
		return NAN
	var s: Dictionary = chunks[id]
	var X: PackedFloat32Array = s.X
	var Z: PackedFloat32Array = s.Z
	if x < X[0] or x > X[X.size() - 1] or z < Z[0] or z > Z[Z.size() - 1]:
		return NAN
	var p := clampi(X.bsearch(x) - 1, 0, X.size() - 2)
	var q := clampi(Z.bsearch(z) - 1, 0, Z.size() - 2)
	var u := (x - X[p]) / (X[p + 1] - X[p])
	var v := (z - Z[q]) / (Z[q + 1] - Z[q])
	var nx := X.size()
	var ys: PackedFloat32Array = s.ys
	var k := q * nx + p
	var a := ys[k]
	var b := ys[k + 1]
	var c := ys[k + nx + 1]
	var d := ys[k + nx]
	return a + (b - a) * u + (c - b) * v if u >= v else a + (c - d) * u + (d - a) * v


## [triangles, vertices, the identity of the mesh's arrays] of an open chunk.
func figures(id: Vector2i) -> Array:
	if not chunks.has(id):
		return [0, 0, ""]
	var s: Dictionary = chunks[id]
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	for a: Variant in [s.pos, s.col, s.cus, s.idx]:
		h.update(a.to_byte_array())
	return [(s.idx as PackedInt32Array).size() / 3, (s.pos as PackedVector3Array).size(), h.finish().hex_encode()]


func free_all() -> void:
	for id: Vector2i in chunks.keys():
		_close(id)
	if root != null:
		root.queue_free()
		root = null


# ------------------------------------------------------------------ open / close
func _open(id: Vector2i) -> bool:
	var r: Rect2 = g.rect_of(id)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return false
	var cells: Vector4i = g.cells_of(id)
	var X := _lines(r.position.x, r.end.x, g.xs, cells.x, cells.y + 1)
	var Z := _lines(r.position.y, r.end.y, g.zs, cells.z, cells.w + 1)
	var nx := X.size()
	var nz := Z.size()
	var by := PackedFloat32Array()
	var bc := PackedColorArray()
	var bn := PackedVector3Array()
	var bk := PackedInt32Array()
	by.resize(nx * nz)
	bc.resize(nx * nz)
	bn.resize(nx * nz)
	bk.resize(nx * nz)
	for q: int in nz:
		for p: int in nx:
			var k := q * nx + p
			var at: Array = g.attrs(X[p], Z[q])
			by[k] = g.y(X[p], Z[q])
			bc[k] = at[1]
			bn[k] = at[2]
			bk[k] = at[3]
	var idx := PackedInt32Array()
	var slot := PackedInt32Array()          # sub-cell q * (nx - 1) + p -> its first index in idx (and faces), -1 skipped
	slot.resize((nx - 1) * (nz - 1))
	slot.fill(-1)
	for q: int in nz - 1:
		for p: int in nx - 1:
			if not g.flat() and g.village_cell(g.col_of((X[p] + X[p + 1]) * 0.5), g.row_of((Z[q] + Z[q + 1]) * 0.5)):
				continue
			var k := q * nx + p
			slot[q * (nx - 1) + p] = idx.size()
			idx.append_array([k, k + 1, k + nx + 1, k, k + nx + 1, k + nx])
	var pos := PackedVector3Array()
	var cus := PackedFloat32Array()
	pos.resize(nx * nz)
	cus.resize(nx * nz * 4)
	var faces := PackedVector3Array()
	faces.resize(idx.size())
	var s := {"id": id, "X": X, "Z": Z, "cells": cells, "by": by, "bc": bc, "bn": bn, "bk": bk, "idx": idx, "slot": slot,
		"ys": by.duplicate(), "nrm": bn.duplicate(), "col": bc.duplicate(), "code": bk.duplicate(), "pos": pos, "cus": cus,
		"faces": faces, "mi": null, "mesh": null}
	if root != null:
		var mi := MeshInstance3D.new()
		mi.name = "Land %d,%d" % [id.x, id.y]
		var m := ArrayMesh.new()
		mi.mesh = m
		root.add_child(mi)
		s.mi = mi
		s.mesh = m
	chunks[id] = s
	if not g.flat():
		counters.valley_cells_hidden += int(g.ground.hide_cells(cells.x, cells.y, cells.z, cells.w, true))
	counters.opened += 1
	return true


func _close(id: Vector2i) -> void:
	if not chunks.has(id):
		return
	var s: Dictionary = chunks[id]
	if s.mi != null and is_instance_valid(s.mi):
		(s.mi as Node).queue_free()
	var cells: Vector4i = s.cells
	if not g.flat():
		counters.valley_cells_hidden -= int(g.ground.hide_cells(cells.x, cells.y, cells.z, cells.w, false))
	chunks.erase(id)
	counters.closed += 1


## The grid lines from `a` to `b`: the valley's lines axis[i0..i1] and the lattice lines between them.
static func _lines(a: float, b: float, axis: PackedFloat32Array, i0: int, i1: int) -> PackedFloat32Array:
	var all := PackedFloat32Array()
	if axis.is_empty():
		for k: int in range(roundi(a / L), roundi(b / L) + 1):
			all.append(k * L)
		return all
	var valley_lines := axis.slice(i0, i1 + 1)
	var k := ceili(a / L)
	var vi := 0
	while vi < valley_lines.size():                 # the last valley line is b: every lattice line below it comes first
		var lat := k * L
		var val := valley_lines[vi]
		if lat < b - EPS and lat < val - EPS:
			if lat > a + EPS:
				all.append(lat)
			k += 1
		else:
			all.append(val)
			vi += 1
			if absf(lat - val) <= EPS:
				k += 1
	return all


# ------------------------------------------------------------------ the surface now
## Works out the chunk's grid vertices in `box` (grown by a lattice cell: a vertex's normal reads its neighbours'
## deltas), or all of them (the first fill, or no box): D and the colour delta on the lattice under them, then each
## vertex as the valley's plus those; the collider triangles over them; then the mesh is uploaded whole.
func _fill(s: Dictionary, box: Variant) -> void:
	var X: PackedFloat32Array = s.X
	var Z: PackedFloat32Array = s.Z
	var nx := X.size()
	var nz := Z.size()
	var p0 := 0
	var p1 := nx - 1
	var q0 := 0
	var q1 := nz - 1
	if box is Rect2 and bool(s.get("filled", false)):
		var bb: Rect2 = (box as Rect2).grow(L)
		p0 = clampi(X.bsearch(bb.position.x) - 1, 0, nx - 1)
		p1 = clampi(X.bsearch(bb.end.x), 0, nx - 1)
		q0 = clampi(Z.bsearch(bb.position.y) - 1, 0, nz - 1)
		q1 = clampi(Z.bsearch(bb.end.y), 0, nz - 1)
	# the lattice under those vertices, two vertices of margin (their cells' corners, and those corners' neighbours)
	var i0 := floori(X[p0] / L) - 2
	var j0 := floori(Z[q0] / L) - 2
	var w := floori(X[p1] / L) + 3 - i0 + 1
	var h := floori(Z[q1] / L) + 3 - j0 + 1
	var dd := PackedFloat32Array()
	dd.resize(w * h)
	var fp := PackedFloat32Array()
	fp.resize(w * h)
	var dc := PackedColorArray()
	dc.resize(w * h)
	if not store.heights.is_empty():
		for j: int in h:
			for i: int in w:
				var v := Vector2i(i0 + i, j0 + j)
				if store.heights.has(v):
					dd[j * w + i] = float(store.heights[v]) / 100.0 - g.y(v.x * L, v.y * L)
	if not store.paints.is_empty():
		var corner_col := {}
		for j: int in h - 1:
			for i: int in w - 1:
				var c := Vector2i(i0 + i, j0 + j)
				if not store.paints.has(c):
					continue
				var name: String = store.paint_at(c)
				for o: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i.ONE]:
					var vk := (j + o.y) * w + (i + o.x)
					var vx := (c.x + o.x) * L
					var vz := (c.y + o.y) * L
					if not corner_col.has(vk):
						corner_col[vk] = g.attrs(vx, vz)[1]
					dc[vk] += (g.pigment(name, vx, vz) - (corner_col[vk] as Color)) * 0.25
					fp[vk] += 0.25
	# per lattice vertex: an edit at it or a neighbour (`near`), and D's gradient (central differences)
	var near := PackedByteArray()
	near.resize(w * h)
	var gx := PackedFloat32Array()
	gx.resize(w * h)
	var gz := PackedFloat32Array()
	gz.resize(w * h)
	for j: int in range(1, h - 1):
		for i: int in range(1, w - 1):
			var k := j * w + i
			if dd[k] != 0.0 or dd[k - 1] != 0.0 or dd[k + 1] != 0.0 or dd[k - w] != 0.0 or dd[k + w] != 0.0:
				near[k] = 1
				gx[k] = (dd[k + 1] - dd[k - 1]) / (2.0 * L)
				gz[k] = (dd[k + w] - dd[k - w]) / (2.0 * L)
	var by: PackedFloat32Array = s.by
	var bc: PackedColorArray = s.bc
	var bn: PackedVector3Array = s.bn
	var bk: PackedInt32Array = s.bk
	var ys: PackedFloat32Array = s.ys
	var nrm: PackedVector3Array = s.nrm
	var col: PackedColorArray = s.col
	var code: PackedInt32Array = s.code
	var pos: PackedVector3Array = s.pos
	var cus: PackedFloat32Array = s.cus
	for q: int in range(q0, q1 + 1):
		var z := Z[q]
		var lj := clampi(floori(z / L), j0 + 1, j0 + h - 3)
		var v := z / L - lj
		var rj := lj - j0
		for p: int in range(p0, p1 + 1):
			var x := X[p]
			var li := clampi(floori(x / L), i0 + 1, i0 + w - 3)
			var u := x / L - li
			var ka := rj * w + li - i0
			# the lattice triangle's corners and weights (the valley's split: the diagonal a..c)
			var k1 := ka + 1 if u >= v else ka + w + 1
			var k2 := ka + w + 1 if u >= v else ka + w
			var w0 := 1.0 - u if u >= v else 1.0 - v
			var w1 := u - v if u >= v else u
			var w2 := v if u >= v else v - u
			var k := q * nx + p
			if near[ka] != 0 or near[k1] != 0 or near[k2] != 0:
				ys[k] = by[k] + w0 * dd[ka] + w1 * dd[k1] + w2 * dd[k2]
				var b := bn[k]
				var b_y := maxf(b.y, 0.05)
				nrm[k] = Vector3(b.x / b_y - (w0 * gx[ka] + w1 * gx[k1] + w2 * gx[k2]), 1.0, b.z / b_y - (w0 * gz[ka] + w1 * gz[k1] + w2 * gz[k2])).normalized()
			else:
				ys[k] = by[k]
				nrm[k] = bn[k]
			if w0 * fp[ka] + w1 * fp[k1] + w2 * fp[k2] > 0.0:
				var c := bc[k] + dc[ka] * w0 + dc[k1] * w1 + dc[k2] * w2
				col[k] = Color(maxf(c.r, 0.0), maxf(c.g, 0.0), maxf(c.b, 0.0), 1.0)
				code[k] = g.terrain_code
			else:
				col[k] = bc[k]
				code[k] = bk[k]
			pos[k] = Vector3(x, ys[k], z)
			cus[k * 4] = x
			cus[k * 4 + 1] = ys[k]
			cus[k * 4 + 2] = z
			cus[k * 4 + 3] = code[k]
	var idx: PackedInt32Array = s.idx
	var slot: PackedInt32Array = s.slot
	var tri: PackedVector3Array = s.faces
	for q: int in range(maxi(0, q0 - 1), mini(nz - 2, q1) + 1):
		for p: int in range(maxi(0, p0 - 1), mini(nx - 2, p1) + 1):
			var t := slot[q * (nx - 1) + p]
			if t < 0:
				continue
			# the drawn split, wound up (home/hook.gd `faces`): a c b, a d c
			tri[t] = pos[idx[t]]
			tri[t + 1] = pos[idx[t + 2]]
			tri[t + 2] = pos[idx[t + 1]]
			tri[t + 3] = pos[idx[t + 3]]
			tri[t + 4] = pos[idx[t + 5]]
			tri[t + 5] = pos[idx[t + 4]]
	s.ys = ys
	s.nrm = nrm
	s.col = col
	s.code = code
	s.pos = pos
	s.cus = cus
	s.faces = tri
	s.filled = true
	if s.mesh != null:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_INDEX] = idx
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_CUSTOM0] = cus
		arr[Mesh.ARRAY_NORMAL] = nrm
		var uv := PackedVector2Array()
		uv.resize(pos.size())
		arr[Mesh.ARRAY_TEX_UV] = uv
		var m: ArrayMesh = s.mesh
		m.clear_surfaces()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		m.surface_set_material(0, TLStyle.material("terrain"))
