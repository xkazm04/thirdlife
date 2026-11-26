extends RefCounted
## M2 (spark world-sandbox): the Home's own ground as the land layer reads it, read only. In the Home it is the valley's
## drawn mesh (home/ground.gd, built by home/hook.gd `grow`): heights, colours, normals and shading codes are the mesh's
## own, interpolated on its triangles, so an edited chunk that has no edit at a point looks and collides as the valley
## does there. A builder without a valley (a case, a scratch Home) stands on FLAT ground at height 0 and draws nothing.
##
## The render partition: a valley cell (12 m near the village, 48 m beyond +-1536 m) belongs to the 96 m chunk its
## centre lies in (as home/hook.gd `faces` makes the colliders). Chunk C's cells form the rectangle `rect(C)` on the
## valley's grid lines, which is what an edited chunk's 3 m mesh replaces (land_mesh.gd).

const CHUNK := 96.0
const LATTICE := 3.0

var hook: RefCounted = null              # home/hook.gd (null: flat ground)
var ground: RefCounted = null            # home/ground.gd
var valley: RefCounted = null            # home/valley.gd
var xs := PackedFloat32Array()
var zs := PackedFloat32Array()
var n := 0
var col_chunk := PackedInt32Array()      # valley column i -> the chunk x its centre lies in
var row_chunk := PackedInt32Array()
var cols := {}                           # chunk x -> Vector2i(first column, last column)
var rows := {}
var border := Rect2()
var terrain_code := 1                    # CUSTOM0.w of land painted by numbers (ground.gd `code`)
var _pigment := {}                       # paint name -> linear colour


## `h`: home/hook.gd, or null for flat ground.
func _init(h: RefCounted = null) -> void:
	hook = h
	if h == null or h.get("ground") == null:
		hook = null
		return
	ground = h.ground
	valley = ground.get("land")
	xs = ground.xs
	zs = ground.zs
	n = xs.size()
	border = h.border
	terrain_code = 1 + 16 * TLStyle.index("terrain")
	col_chunk = _partition(xs, cols)
	row_chunk = _partition(zs, rows)


static func _partition(axis: PackedFloat32Array, ranges: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(axis.size() - 1)
	for i: int in axis.size() - 1:
		var c := floori((axis[i] + axis[i + 1]) * 0.5 / CHUNK)
		out[i] = c
		if not ranges.has(c):
			ranges[c] = Vector2i(i, i)
		else:
			ranges[c] = Vector2i((ranges[c] as Vector2i).x, i)
	return out


func flat() -> bool:
	return hook == null


# ------------------------------------------------------------------ the partition
## The cell rectangle of chunk `id`: Vector4i(first column, last column, first row, last row), or (0, -1, 0, -1).
func cells_of(id: Vector2i) -> Vector4i:
	if flat() or not cols.has(id.x) or not rows.has(id.y):
		return Vector4i(0, -1, 0, -1)
	var c: Vector2i = cols[id.x]
	var r: Vector2i = rows[id.y]
	return Vector4i(c.x, c.y, r.x, r.y)


## Chunk `id`'s drawn rectangle in metres (its cells' outer grid lines; on flat ground the chunk's own square).
func rect_of(id: Vector2i) -> Rect2:
	if flat():
		return Rect2(Vector2(id) * CHUNK, Vector2.ONE * CHUNK)
	var c := cells_of(id)
	if c.y < c.x or c.w < c.z:
		return Rect2(Vector2(id) * CHUNK, Vector2.ZERO)
	return Rect2(xs[c.x], zs[c.z], xs[c.y + 1] - xs[c.x], zs[c.w + 1] - zs[c.z])


func col_of(x: float) -> int:
	return clampi(xs.bsearch(x) - 1, 0, n - 2)


func row_of(z: float) -> int:
	return clampi(zs.bsearch(z) - 1, 0, zs.size() - 2)


## The chunks whose drawn rectangle or 96 m square meets the open box `lo`..`hi` (metres): [Vector2i min, max].
func chunks_meeting(lo: Vector2, hi: Vector2) -> Array:
	var e := 0.001
	var a := Vector2i(floori((lo.x + e) / CHUNK), floori((lo.y + e) / CHUNK))
	var b := Vector2i(floori((hi.x - e) / CHUNK), floori((hi.y - e) / CHUNK))
	if not flat():
		a = Vector2i(mini(a.x, col_chunk[col_of(lo.x + e)]), mini(a.y, row_chunk[row_of(lo.y + e)]))
		b = Vector2i(maxi(b.x, col_chunk[col_of(hi.x - e)]), maxi(b.y, row_chunk[row_of(hi.y - e)]))
	return [a, b]


## True when the valley cell (i, j) is the village's (not drawn by the valley: ground.gd skips it).
func village_cell(i: int, j: int) -> bool:
	return border.has_point(Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5))


# ------------------------------------------------------------------ the ground's own surface
## [k0, k1, k2, w0, w1, w2]: the valley vertices of the drawn triangle under (x, z) and their weights (ground.gd's
## split: the diagonal from (i, j) to (i + 1, j + 1)). The cell is ground.gd `y`'s, so points on a grid line shared by
## two chunks are computed the same way by both.
func weights(x: float, z: float) -> Array:
	var i := col_of(x)
	var j := row_of(z)
	var u := (x - xs[i]) / (xs[i + 1] - xs[i])
	var v := (z - zs[j]) / (zs[j + 1] - zs[j])
	var k := j * n + i
	if u >= v:
		return [k, k + 1, k + n + 1, 1.0 - u, u - v, v]
	return [k, k + n + 1, k + n, 1.0 - v, u, v - u]


## The ground's own height at (x, z): the valley's drawn triangles (0 on flat ground). Inside the village rectangle the
## village terrain's (ground.gd `y`).
func y(x: float, z: float) -> float:
	if flat():
		return 0.0
	if border.has_point(Vector2(x, z)):
		return ground.y(x, z)
	var w := weights(x, z)
	var vv: PackedVector3Array = ground.vertices
	return float(w[3]) * vv[w[0]].y + float(w[4]) * vv[w[1]].y + float(w[5]) * vv[w[2]].y


## The ground's own height of lattice vertex `v` in cm (what `from_cm` is when nobody has moved it).
func base_cm(v: Vector2i) -> int:
	return roundi(y(v.x * LATTICE, v.y * LATTICE) * 100.0)


## [y, colour, normal, code] of the valley's drawn surface at (x, z) (colour and normal interpolated as the GPU does;
## the code is the nearest corner's).
func attrs(x: float, z: float) -> Array:
	if flat():
		return [0.0, Color(0.3, 0.5, 0.2), Vector3.UP, terrain_code]
	var w := weights(x, z)
	var vv: PackedVector3Array = ground.vertices
	var cc: PackedColorArray = ground.colors
	var nn: PackedVector3Array = ground.normals
	var w0: float = w[3]
	var w1: float = w[4]
	var w2: float = w[5]
	var k0: int = w[0]
	var k1: int = w[1]
	var k2: int = w[2]
	var top := k0 if w0 >= w1 and w0 >= w2 else (k1 if w1 >= w2 else k2)
	return [w0 * vv[k0].y + w1 * vv[k1].y + w2 * vv[k2].y, cc[k0] * w0 + cc[k1] * w1 + cc[k2] * w2,
		(nn[k0] * w0 + nn[k1] * w1 + nn[k2] * w2).normalized(), int((ground.custom as PackedFloat32Array)[top * 4 + 3])]


## A paint's colour at (x, z), as ground.gd colours the valley (the palette key in linear light, the valley's mottle).
func pigment(name: String, x: float, z: float) -> Color:
	if not _pigment.has(name):
		_pigment[name] = TLStyle.color(name).srgb_to_linear() if TLStyle.has_key(name) else Color(0.5, 0.5, 0.5)
	var c: Color = _pigment[name]
	if valley != null:
		c *= 0.94 + 0.06 * (valley.noise as FastNoiseLite).get_noise_2d(x + 130.0, z)
	c.a = 1.0
	return c
