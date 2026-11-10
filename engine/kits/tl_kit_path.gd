class_name TLKitPath
extends RefCounted
## Kit part: a planar Catmull-Rom path (closed or open) resampled at even spacing, with a spatial hash for
## nearest-point queries. Used for the race circuit and the river; `ys` holds the per-sample height.

var closed: bool = true
var pts: PackedVector2Array = PackedVector2Array()
var tang: PackedVector2Array = PackedVector2Array()
var ys: PackedFloat32Array = PackedFloat32Array()
var s: PackedFloat32Array = PackedFloat32Array()
var length: float = 0.0
var spacing: float = 2.0
var _grid: Dictionary = {}
const CELL: float = 16.0


func _init(cps: Array, closed_: bool = true, spacing_: float = 2.0) -> void:
	closed = closed_
	spacing = spacing_
	var n: int = cps.size()
	var dense: PackedVector2Array = PackedVector2Array()
	var segs: int = n if closed else n - 1
	for i: int in segs:
		var p0: Vector2 = cps[(i - 1 + n) % n] if (closed or i > 0) else cps[0]
		var p1: Vector2 = cps[i]
		var p2: Vector2 = cps[(i + 1) % n]
		var p3: Vector2 = cps[(i + 2) % n] if (closed or i + 2 < n) else cps[n - 1]
		for k: int in 48:
			var t: float = float(k) / 48.0
			dense.append(_cr(p0, p1, p2, p3, t))
	if not closed:
		dense.append(cps[n - 1])
	# even resample
	var acc: float = 0.0
	var out: PackedVector2Array = PackedVector2Array()
	out.append(dense[0])
	var m: int = dense.size() + (1 if closed else 0)
	for i: int in range(1, m):
		var a: Vector2 = dense[(i - 1) % dense.size()]
		var b: Vector2 = dense[i % dense.size()]
		var seg: float = a.distance_to(b)
		while acc + seg >= spacing:
			var f: float = (spacing - acc) / seg
			a = a.lerp(b, f)
			out.append(a)
			seg = a.distance_to(b)
			acc = 0.0
		acc += seg
	if closed and out.size() > 2 and out[0].distance_to(out[out.size() - 1]) < spacing * 0.5:
		out.remove_at(out.size() - 1)
	pts = out
	var cnt: int = pts.size()
	tang.resize(cnt)
	s.resize(cnt)
	ys.resize(cnt)
	var cum: float = 0.0
	for i: int in cnt:
		var a: Vector2 = pts[(i - 1 + cnt) % cnt] if (closed or i > 0) else pts[0]
		var b: Vector2 = pts[(i + 1) % cnt] if (closed or i < cnt - 1) else pts[cnt - 1]
		tang[i] = (b - a).normalized()
		s[i] = cum
		cum += pts[i].distance_to(pts[(i + 1) % cnt]) if (closed or i < cnt - 1) else 0.0
		var key: Vector2i = Vector2i(floori(pts[i].x / CELL), floori(pts[i].y / CELL))
		if not _grid.has(key):
			_grid[key] = []
		(_grid[key] as Array).append(i)
	length = cum


static func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func count() -> int:
	return pts.size()


func set_heights(fn: Callable) -> void:
	for i: int in pts.size():
		ys[i] = float(fn.call(s[i], pts[i]))


## Nearest path sample to (x, z): returns Vector3(distance, y, sample index).
func query(x: float, z: float, reach: int = 2) -> Vector3:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best: float = 1e9
	var bi: int = -1
	for dx: int in range(-reach, reach + 1):
		for dz: int in range(-reach, reach + 1):
			var key: Vector2i = Vector2i(cx + dx, cz + dz)
			if not _grid.has(key):
				continue
			for i: int in (_grid[key] as Array):
				var d: float = (pts[i].x - x) * (pts[i].x - x) + (pts[i].y - z) * (pts[i].y - z)
				if d < best:
					best = d
					bi = i
	if bi < 0:
		return Vector3(1e9, 0.0, -1.0)
	# refine on the two adjacent segments
	var n: int = pts.size()
	var p: Vector2 = Vector2(x, z)
	var bd: float = 1e9
	var by: float = ys[bi]
	for off: int in [-1, 0]:
		var i0: int = bi + off
		var i1: int = bi + off + 1
		if closed:
			i0 = (i0 + n) % n
			i1 = i1 % n
		elif i0 < 0 or i1 >= n:
			continue
		var a: Vector2 = pts[i0]
		var b: Vector2 = pts[i1]
		var ab: Vector2 = b - a
		var tt: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var d: float = p.distance_to(a + ab * tt)
		if d < bd:
			bd = d
			by = lerpf(ys[i0], ys[i1], tt)
	return Vector3(bd, by, float(bi))


func idx(i: int) -> int:
	var n: int = pts.size()
	return ((i % n) + n) % n if closed else clampi(i, 0, n - 1)


## Sample at arc length u (wraps on closed paths): returns {pos: Vector3, tan: Vector3, i: int}.
func at(u: float) -> Dictionary:
	var L: float = length
	if closed:
		u = fposmod(u, L)
	else:
		u = clampf(u, 0.0, L)
	var i: int = clampi(int(u / spacing), 0, pts.size() - 1)
	var i1: int = idx(i + 1)
	var f: float = clampf((u - s[i]) / maxf(spacing, 1e-4), 0.0, 1.0)
	var p: Vector2 = pts[i].lerp(pts[i1], f)
	var y: float = lerpf(ys[i], ys[i1], f)
	var t2: Vector2 = tang[i].lerp(tang[i1], f).normalized()
	return {"pos": Vector3(p.x, y, p.y), "tan": Vector3(t2.x, 0.0, t2.y), "i": i}


## Signed turn (radians per metre) at sample i, + = turning left seen from above (-Z forward).
func curvature(i: int) -> float:
	var a: Vector2 = tang[idx(i - 2)]
	var b: Vector2 = tang[idx(i + 2)]
	var ang: float = atan2(a.x * b.y - a.y * b.x, a.dot(b))
	return -ang / (4.0 * spacing)
