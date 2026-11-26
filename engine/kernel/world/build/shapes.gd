extends RefCounted
## WP1: the shape table and auto-join of the Home's 1 m blocks.
##
## Every shape is made in a canonical frame (the cell is the unit cube 0..1, a stair, ramp or roof rises toward -z),
## then flipped (y -> 1 - y) and turned `rot` quarter turns about +y (rot 0 rises toward -z, 1 toward -x, 2 toward +z,
## 3 toward +x: FACING). Its polygons are tagged with the cell face they lie on (0 +x, 1 -x, 2 +y, 3 -y, 4 +z, 5 -z;
## 6 = inside the cell), and every polygon on a cell face carries a coverage MASK: 8 x 8 sample points on that face,
## one bit each. A polygon is hidden when the neighbour's opaque coverage of the touching face holds every one of its
## bits: a cube hides a slab's side, two slabs hide each other, a stair's side meets a stair's side, a fence rail end
## meets a fence rail end or a wall. Glass (a window's pane) covers nothing.
##
## Joined forms are derived from the neighbours when a section is meshed, never stored (contracts/BUILD.md):
##   stair, ramp, roof   0 straight, 1 outer-left, 2 outer-right, 3 inner-left, 4 inner-right, from a same-shape,
##                       same-flip neighbour behind (outer) or in front (inner) that faces across (the rule of
##                       Minecraft's stairs: a corner is not made when the third neighbour already continues the run)
##   fence               bit per side (+x, -x, +z, -z): a fence or post there, or a full opaque face
##   post                bit per side with a fence there (a rail stub meets the fence's rail); posts stack (their
##                       end faces hide each other)
## The table key is shape | rot << 5 | flip << 7 | form << 8 (rot is 0 for shapes it does not change).

const Blocks := preload("res://kernel/world/build/blocks.gd")
const DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const FACING_D := [5, 1, 4, 0]          # rot -> the DIRS index of its high side (-z, -x, +z, +x)
const HORIZONTAL := [0, 1, 4, 5]        # the DIRS a fence's bits name, in bit order
const INSIDE := 6
const FULL := -1                        # every one of the 64 samples
const GRAIN := 1                        # TLMesh grain axis (y) for every block face
const STEPS := 4                        # a stair's steps per cell: 0.25 m risers, 0.25 m treads (45 degrees)
## A stair COLLIDES as a 45-degree wedge of its own form (the ramp's): the visitor's walkers (world_space.gd `walk`,
## world_body.gd `drive`) climb slopes up to 55 degrees but stop at a vertical riser, even a 0.125 m one at walking
## speed (their round foot meets the edge and reads it as steep; build_case.gd build.walk, measured 26 Nov 2026, and
## PATCHES-WP1.md). The drawn treads lie on or up to 0.25 m over that plane (over it at a nosing, on it at an inner
## corner): the feet sink into the drawn step by at most a riser.
const STAIR_RISE := 0.0

static var _geo := {}                   # key -> {"polys": [[points, glass, side, mask]], "side": PackedInt64Array(6)}
static var _emit := {}                  # key | mat << 12 -> Entry


## What one block emits, per cell face (0..5) and inside (6), in Godot's winding (TLMesh.tri), ready to append.
class Entry:
	var v: Array = []                   # per side: PackedVector3Array of opaque triangles (cell-local)
	var n: Array = []
	var cu: Array = []                  # CUSTOM0: cell-local xyz + (face axis + 4 * grain + 16 * palette column)
	var gv: Array = []                  # the same for glass
	var gn: Array = []
	var gcu: Array = []
	var cv: Array = []                  # per side: the collider's triangles, opaque and glass, counter-clockwise seen
	                                    # from outside (the physics reads the winding: hook.gd `facing_up`)
	var cover: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0])   # all polygons' masks on each face, OR'd
	var polys: Array = []               # per side: [[mask, v, n, cu, glass, cv]] for a partly hidden face
	var tris := 0


# ------------------------------------------------------------------ keys and forms
static func key_of(c: int, form: int) -> int:
	var s := Blocks.shape_of(c)
	var turns := Blocks.rot_of(c) if s in [Blocks.STAIR, Blocks.RAMP, Blocks.ROOF, Blocks.WINDOW] else 0
	var flip := 1 if Blocks.flip_of(c) and s in [Blocks.STAIR, Blocks.RAMP, Blocks.ROOF] else 0
	return s | (turns << 5) | (flip << 7) | (form << 8)


static func _same(nc: int, shape: int, flip: bool) -> bool:
	return nc != 0 and Blocks.shape_of(nc) == shape and Blocks.flip_of(nc) == flip


## The table key of the block at `gi` in a dense grid (`off`: the index step of each of DIRS). 0 = empty. Reads cells
## up to one away (two for a fence asking a neighbour's face); the caller's grid has a border of two.
static func key_at(grid: PackedInt32Array, gi: int, off: PackedInt32Array) -> int:
	var c := grid[gi]
	if c == 0:
		return 0
	var shape := Blocks.shape_of(c)
	var form := 0
	if shape == Blocks.STAIR or shape == Blocks.RAMP or shape == Blocks.ROOF:
		var rot := Blocks.rot_of(c)
		var flip := Blocks.flip_of(c)
		var behind := grid[gi + off[FACING_D[rot]]]
		if _same(behind, shape, flip):
			var g := Blocks.rot_of(behind)
			if (g + rot) % 2 == 1:
				var beside := grid[gi + off[FACING_D[(g + 2) % 4]]]
				if not (_same(beside, shape, flip) and Blocks.rot_of(beside) == rot):
					form = 1 if g == (rot + 1) % 4 else 2
		if form == 0:
			var front := grid[gi + off[FACING_D[(rot + 2) % 4]]]
			if _same(front, shape, flip):
				var g := Blocks.rot_of(front)
				if (g + rot) % 2 == 1:
					var beside := grid[gi + off[FACING_D[g]]]
					if not (_same(beside, shape, flip) and Blocks.rot_of(beside) == rot):
						form = 3 if g == (rot + 1) % 4 else 4
	elif shape == Blocks.FENCE or shape == Blocks.POST:
		for b: int in 4:
			var d: int = HORIZONTAL[b]
			var nc := grid[gi + off[d]]
			if nc == 0:
				continue
			var ns := Blocks.shape_of(nc)
			if ns == Blocks.FENCE or (ns == Blocks.POST and shape == Blocks.FENCE):
				form |= 1 << b
			elif shape == Blocks.FENCE and ns != Blocks.POST and side_mask(key_at(grid, gi + off[d], off), d ^ 1) == FULL:
				form |= 1 << b
	return key_of(c, form)


## The opaque coverage of face `side` of the block with table key `key`.
static func side_mask(key: int, side: int) -> int:
	return (_info(key).side as PackedInt64Array)[side]


# ------------------------------------------------------------------ geometry
static func _info(key: int) -> Dictionary:
	if _geo.has(key):
		return _geo[key]
	var shape := key & 31
	var rot := (key >> 5) & 3
	var flip := ((key >> 7) & 1) == 1
	var form := (key >> 8) & 15
	var raw: Array = _canonical(shape, form)
	var polys := []
	var side := PackedInt64Array([0, 0, 0, 0, 0, 0])
	for p: Array in raw:
		var pts: Array = p[0]
		var out: Array = []
		for q: Vector3 in pts:
			if flip:
				q.y = 1.0 - q.y
			for t: int in rot:
				q = Vector3(q.z, q.y, 1.0 - q.x)
			out.append(Vector3(snappedf(q.x, 1.0 / 4096.0), snappedf(q.y, 1.0 / 4096.0), snappedf(q.z, 1.0 / 4096.0)))
		if flip:
			out.reverse()
		var s := _side_of(out)
		var m := _mask(out, s) if s != INSIDE else 0
		polys.append([out, bool(p[1]), s, m])
		if s != INSIDE and not bool(p[1]):
			side[s] = side[s] | m
	var info := {"polys": polys, "side": side, "col": []}
	if shape == Blocks.STAIR:
		var col := []
		_wedge(col, form, STAIR_RISE)
		for p: Array in col:
			var out: Array = []
			for q: Vector3 in p[0]:
				if flip:
					q.y = 1.0 - q.y
				for t: int in rot:
					q = Vector3(q.z, q.y, 1.0 - q.x)
				out.append(Vector3(snappedf(q.x, 1.0 / 4096.0), snappedf(q.y, 1.0 / 4096.0), snappedf(q.z, 1.0 / 4096.0)))
			if flip:
				out.reverse()
			(info.col as Array).append(out)
	_geo[key] = info
	return info


## The arrays a block of table key `key` and material `mat` appends.
static func entry(key: int, mat: int) -> Entry:
	var ek := key | (mat << 12)
	if _emit.has(ek):
		return _emit[ek]
	var e := Entry.new()
	for s: int in 7:
		e.v.append(PackedVector3Array()); e.n.append(PackedVector3Array()); e.cu.append(PackedFloat32Array())
		e.gv.append(PackedVector3Array()); e.gn.append(PackedVector3Array()); e.gcu.append(PackedFloat32Array())
		e.polys.append([])
		e.cv.append(PackedVector3Array())
	var col := 16.0 * float(TLStyle.index(Blocks.mat_key(mat)))
	var glass_col := 16.0 * float(TLStyle.index("glass"))
	var info: Dictionary = _info(key)
	var has_col := not (info.col as Array).is_empty()
	if has_col:
		var ck := PackedVector3Array()
		for pts: Array in info.col:
			for i: int in range(1, pts.size() - 1):
				ck.append_array(PackedVector3Array([pts[0], pts[i], pts[i + 1]]))
		e.cv[INSIDE] = ck
	for p: Array in info.polys:
		var pts: Array = p[0]
		var glass: bool = p[1]
		var s: int = p[2]
		var nrm := _normal(pts)
		var a := absf(nrm.x)
		var b := absf(nrm.y)
		var ax := 0 if a >= b and a >= absf(nrm.z) else (1 if b >= absf(nrm.z) else 2)
		var w := float(ax + 4 * GRAIN) + (glass_col if glass else col)
		var pv := PackedVector3Array()
		var pn := PackedVector3Array()
		var pc := PackedFloat32Array()
		var pk := PackedVector3Array()
		for i: int in range(1, pts.size() - 1):
			for q: Vector3 in [pts[0], pts[i + 1], pts[i]]:      # CCW outside -> Godot's winding (TLMesh.tri)
				pv.append(q)
				pn.append(nrm)
				pc.append_array(PackedFloat32Array([q.x, q.y, q.z, w]))
			pk.append_array(PackedVector3Array([pts[0], pts[i], pts[i + 1]]))
		e.tris += pv.size() / 3
		# packed arrays are values: take them out, append, put them back
		var lv: Array = e.gv if glass else e.v
		var ln: Array = e.gn if glass else e.n
		var lc: Array = e.gcu if glass else e.cu
		var av: PackedVector3Array = lv[s]
		var an: PackedVector3Array = ln[s]
		var ac: PackedFloat32Array = lc[s]
		av.append_array(pv)
		an.append_array(pn)
		ac.append_array(pc)
		lv[s] = av
		ln[s] = an
		lc[s] = ac
		if not has_col:
			var ak: PackedVector3Array = e.cv[s]
			ak.append_array(pk)
			e.cv[s] = ak
		else:
			pk = PackedVector3Array()
		if s != INSIDE:
			e.cover[s] = e.cover[s] | int(p[3])
			(e.polys[s] as Array).append([int(p[3]), pv, pn, pc, glass, pk])
	_emit[ek] = e
	return e


static func _normal(pts: Array) -> Vector3:
	var n := Vector3.ZERO
	for i: int in pts.size():
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		n += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
	return n.normalized()


static func _side_of(pts: Array) -> int:
	var n := _normal(pts)
	for s: int in 6:
		var axis := s / 2
		var at := 1.0 if s % 2 == 0 else 0.0
		var on := true
		for q: Vector3 in pts:
			on = on and absf(q[axis] - at) < 1e-4
		if on and n[axis] * (1.0 if s % 2 == 0 else -1.0) > 0.5:
			return s
	return INSIDE


## 8 x 8 samples at the centres of an eighth grid on the face's plane (u, v): x faces (z, y), y faces (x, z), z faces
## (x, y). A sample on the polygon's edge counts as covered.
static func _mask(pts: Array, s: int) -> int:
	var axis := s / 2
	var ua := 2 if axis == 0 else 0
	var va := 1 if axis != 1 else 2
	var poly := PackedVector2Array()
	for q: Vector3 in pts:
		poly.append(Vector2(q[ua], q[va]))
	var m := 0
	for j: int in 8:
		for i: int in 8:
			if _inside(poly, Vector2((i + 0.5) / 8.0, (j + 0.5) / 8.0)):
				m |= 1 << (i + 8 * j)
	return m


static func _inside(poly: PackedVector2Array, p: Vector2) -> bool:
	var sign := 0.0
	for i: int in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var c := (b - a).cross(p - a)
		if absf(c) < 1e-6:
			continue
		if sign == 0.0:
			sign = signf(c)
		elif signf(c) != sign:
			return false
	return true


# ------------------------------------------------------------------ canonical shapes (rise toward -z)
static func _canonical(shape: int, form: int) -> Array:
	var out := []
	match shape:
		Blocks.CUBE:
			_subvox(out, [true, true, true, true, true, true, true, true])
		Blocks.SLAB:
			_subvox(out, [true, true, true, true, false, false, false, false])
		Blocks.STAIR:
			_steps(out, form)
		Blocks.RAMP, Blocks.ROOF:
			_wedge(out, form, 0.0)
		Blocks.POST:
			_box(out, Vector3(0.375, 0.0, 0.375), Vector3(0.625, 1.0, 0.625), 0)
			_rails(out, form, 0.375, 0.625)
		Blocks.FENCE:
			_box(out, Vector3(0.4, 0.0, 0.4), Vector3(0.6, 1.0, 0.6), 0)
			_rails(out, form, 0.4, 0.6)
		Blocks.WINDOW:
			var t0 := 0.4375
			var t1 := 0.5625
			_box(out, Vector3(0.0, 0.0, t0), Vector3(1.0, 0.125, t1), 0)
			_box(out, Vector3(0.0, 0.875, t0), Vector3(1.0, 1.0, t1), 0)
			_box(out, Vector3(0.0, 0.125, t0), Vector3(0.125, 0.875, t1), (1 << 2) | (1 << 3))
			_box(out, Vector3(0.875, 0.125, t0), Vector3(1.0, 0.875, t1), (1 << 2) | (1 << 3))
			var pane := [Vector3(0.125, 0.125, 0.5), Vector3(0.875, 0.125, 0.5), Vector3(0.875, 0.875, 0.5), Vector3(0.125, 0.875, 0.5)]
			_add(out, pane, Vector3(0, 0, 1), true)
			_add(out, pane, Vector3(0, 0, -1), true)
	return out


## A polygon, turned so its normal agrees with `hint`; points that repeat are dropped, a polygon of no area is skipped.
static func _add(out: Array, pts: Array, hint: Vector3, glass := false) -> void:
	var clean: Array = []
	for q: Vector3 in pts:
		if clean.is_empty() or (clean[clean.size() - 1] as Vector3).distance_to(q) > 1e-5:
			clean.append(q)
	if clean.size() > 1 and (clean[0] as Vector3).distance_to(clean[clean.size() - 1]) < 1e-5:
		clean.pop_back()
	if clean.size() < 3:
		return
	var n := _normal(clean)
	if n.length_squared() < 0.5:
		return
	if n.dot(hint) < 0.0:
		clean.reverse()
	out.append([clean, glass])


## A rectangle on the plane `axis` = `at`, spanning (u0..u1, v0..v1) on the two other axes in order.
static func _rect(out: Array, axis: int, at: float, u0: float, u1: float, v0: float, v1: float, hint: Vector3) -> void:
	var ua := (axis + 1) % 3
	var va := (axis + 2) % 3
	var pts := []
	for uv: Vector2 in [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]:
		var q := Vector3.ZERO
		q[axis] = at
		q[ua] = uv.x
		q[va] = uv.y
		pts.append(q)
	_add(out, pts, hint)


## A box, `skip`: bits of the DIRS faces not to emit (they lie against another part).
static func _box(out: Array, mn: Vector3, mx: Vector3, skip: int) -> void:
	for d: int in 6:
		if skip & (1 << d):
			continue
		var axis := d / 2
		var ua := (axis + 1) % 3
		var va := (axis + 2) % 3
		_rect(out, axis, mx[axis] if d % 2 == 0 else mn[axis], mn[ua], mx[ua], mn[va], mx[va], Vector3(DIRS[d]))


## The rails of a fence or the stubs of a post toward each side in `bits` (+x, -x, +z, -z), from the post's faces at
## `p0`/`p1` to the cell's face; the end against the post is not emitted.
static func _rails(out: Array, bits: int, p0: float, p1: float) -> void:
	for y: Vector2 in [Vector2(0.35, 0.5), Vector2(0.7, 0.85)]:
		if bits & 1:
			_box(out, Vector3(p1, y.x, 0.45), Vector3(1.0, y.y, 0.55), 1 << 1)
		if bits & 2:
			_box(out, Vector3(0.0, y.x, 0.45), Vector3(p0, y.y, 0.55), 1 << 0)
		if bits & 4:
			_box(out, Vector3(0.45, y.x, p1), Vector3(0.55, y.y, 1.0), 1 << 5)
		if bits & 8:
			_box(out, Vector3(0.45, y.x, 0.0), Vector3(0.55, y.y, p0), 1 << 4)


## A solid of 2 x 2 x 2 half cells (`occ` index x + 2 z + 4 y), its outer faces merged per half-cell plane.
static func _subvox(out: Array, occ: Array) -> void:
	for d: int in 6:
		var axis := d / 2
		var pos := d % 2 == 0
		var ua := (axis + 1) % 3
		var va := (axis + 2) % 3
		for layer: int in 2:
			var cells := {}
			for v: int in 2:
				for u: int in 2:
					var c := [0, 0, 0]
					c[axis] = layer
					c[ua] = u
					c[va] = v
					if not occ[c[0] + 2 * c[2] + 4 * c[1]]:
						continue
					var nb := layer + (1 if pos else -1)
					if nb >= 0 and nb <= 1:
						c[axis] = nb
						if occ[c[0] + 2 * c[2] + 4 * c[1]]:
							continue
					cells[Vector2i(u, v)] = true
			var at := (layer + (1 if pos else 0)) * 0.5
			for r: Rect2i in _merge(cells):
				_rect(out, axis, at, r.position.x * 0.5, r.end.x * 0.5, r.position.y * 0.5, r.end.y * 0.5, Vector3(DIRS[d]))


## Half-cell faces of one plane as few rectangles: whole, then rows, then columns, then single.
static func _merge(cells: Dictionary) -> Array:
	if cells.size() == 4:
		return [Rect2i(0, 0, 2, 2)]
	var out := []
	var used := {}
	for v: int in 2:
		if cells.has(Vector2i(0, v)) and cells.has(Vector2i(1, v)):
			out.append(Rect2i(0, v, 2, 1))
			used[Vector2i(0, v)] = true
			used[Vector2i(1, v)] = true
	for u: int in 2:
		var a := Vector2i(u, 0)
		var b := Vector2i(u, 1)
		if cells.has(a) and cells.has(b) and not used.has(a) and not used.has(b):
			out.append(Rect2i(u, 0, 1, 2))
			used[a] = true
			used[b] = true
	for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		if cells.has(k) and not used.has(k):
			out.append(Rect2i(k.x, k.y, 1, 1))
	return out


## A stair of STEPS steps as a height field on an STEPS x STEPS grid of columns: straight, the step index is the
## column's distance from the high side (-z); an outer corner takes the larger of its distances from the two high
## sides, an inner corner the smaller. Tops of equal height merge into rectangles, walls into runs.
static func _steps(out: Array, form: int) -> void:
	var n := STEPS
	var hh := []
	for j: int in n:
		var row := []
		for i: int in n:
			var k := j
			match form:
				1: k = maxi(i, j)
				2: k = maxi(n - 1 - i, j)
				3: k = mini(i, j)
				4: k = mini(n - 1 - i, j)
			row.append(n - k)
		hh.append(row)
	var unit := 1.0 / n
	var used := {}
	for j: int in n:
		for i: int in n:
			if used.has(Vector2i(i, j)):
				continue
			var hv: int = hh[j][i]
			var i1 := i
			while i1 + 1 < n and hh[j][i1 + 1] == hv and not used.has(Vector2i(i1 + 1, j)):
				i1 += 1
			var j1 := j
			var grow := true
			while grow and j1 + 1 < n:
				for x: int in range(i, i1 + 1):
					grow = grow and hh[j1 + 1][x] == hv and not used.has(Vector2i(x, j1 + 1))
				if grow:
					j1 += 1
			for y: int in range(j, j1 + 1):
				for x: int in range(i, i1 + 1):
					used[Vector2i(x, y)] = true
			_rect(out, 1, hv * unit, (j) * unit, (j1 + 1) * unit, i * unit, (i1 + 1) * unit, Vector3.UP)
	_rect(out, 1, 0.0, 0.0, 1.0, 0.0, 1.0, Vector3.DOWN)
	# walls across x (planes x = i / n) and across z (planes z = j / n): from the lower column (or the outside, 0) up
	for axis: int in [0, 2]:
		for line: int in range(0, n + 1):
			var run := []                               # [from, to, lo, hi, facing +1/-1] merged along the line
			for t: int in n:
				var a: int = 0 if line == 0 else (hh[t][line - 1] if axis == 0 else hh[line - 1][t])
				var b: int = 0 if line == n else (hh[t][line] if axis == 0 else hh[line][t])
				if a == b:
					continue
				var seg := [t, t + 1, mini(a, b), maxi(a, b), 1 if a > b else -1]
				if not run.is_empty() and run[run.size() - 1][1] == t and run[run.size() - 1][2] == seg[2] and run[run.size() - 1][3] == seg[3] and run[run.size() - 1][4] == seg[4]:
					run[run.size() - 1][1] = t + 1
				else:
					run.append(seg)
			for r: Array in run:
				var face := Vector3.ZERO
				face[axis] = float(r[4])
				if axis == 0:
					_rect(out, 0, line * unit, r[2] * unit, r[3] * unit, r[0] * unit, r[1] * unit, face)
				else:
					_rect(out, 2, line * unit, r[0] * unit, r[1] * unit, r[2] * unit, r[3] * unit, face)


## A 45-degree wedge (ramp, roof): its top is the height h(x, z) over the cell, h = 1 - z straight, the lower of two
## slopes at an outer corner (a hip), the higher at an inner corner (a valley). Each top is two planar triangles split
## along the diagonal its crease runs on.
static func _wedge(out: Array, form: int, rise: float) -> void:
	var h := func(x: float, z: float) -> float:
		var y := 1.0 - z
		match form:
			1: y = minf(1.0 - z, 1.0 - x)
			2: y = minf(1.0 - z, x)
			3: y = maxf(1.0 - z, 1.0 - x)
			4: y = maxf(1.0 - z, x)
		return clampf(y + rise, 0.0, 1.0)
	var p := func(x: float, z: float) -> Vector3: return Vector3(x, h.call(x, z), z)
	var b := func(x: float, z: float) -> Vector3: return Vector3(x, 0.0, z)
	if form == 2 or form == 4:
		_add(out, [p.call(1.0, 0.0), p.call(0.0, 0.0), p.call(0.0, 1.0)], Vector3.UP)
		_add(out, [p.call(1.0, 0.0), p.call(0.0, 1.0), p.call(1.0, 1.0)], Vector3.UP)
	else:
		_add(out, [p.call(0.0, 0.0), p.call(0.0, 1.0), p.call(1.0, 1.0)], Vector3.UP)
		_add(out, [p.call(0.0, 0.0), p.call(1.0, 1.0), p.call(1.0, 0.0)], Vector3.UP)
	_add(out, [b.call(0.0, 0.0), b.call(0.0, 1.0), p.call(0.0, 1.0), p.call(0.0, 0.0)], Vector3.LEFT)
	_add(out, [b.call(1.0, 0.0), p.call(1.0, 0.0), p.call(1.0, 1.0), b.call(1.0, 1.0)], Vector3.RIGHT)
	_add(out, [b.call(0.0, 0.0), p.call(0.0, 0.0), p.call(1.0, 0.0), b.call(1.0, 0.0)], Vector3.FORWARD)
	_add(out, [b.call(0.0, 1.0), b.call(1.0, 1.0), p.call(1.0, 1.0), p.call(0.0, 1.0)], Vector3.BACK)
	_add(out, [b.call(0.0, 0.0), b.call(1.0, 0.0), b.call(1.0, 1.0), b.call(0.0, 1.0)], Vector3.DOWN)
