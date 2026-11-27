extends RefCounted
## M5 (spark world-sandbox, lane P): the shape of a path, without state of the Home. A path op's control points
## (`pts`, world cm) become a Catmull-Rom spline resampled every STEP metres (TLKitPath, as the valley's lanes are,
## home/places.gd `roads`), ending exactly on the last control point. Its samples are what the ribbon is drawn through
## (path_mesh.gd), what the grading levels (path_grade.gd) and what the protection is asked along (paths_layer.gd).
## `Index` is a grid of sample segments of many paths for "how far is (x, z) from path k" (the ribbon's colour field,
## the remove slot, the scatter's "not on a path").

const STEP := 1.0                        # metres between samples
const CELL := 8.0                        # metres: the index's grid


## The samples of control points `pts` ([[x_cm, z_cm], ...]): {"p": PackedVector2Array (metres), "t": tangents,
## "len": metres along the spline}. Two points give a straight line.
static func sample(pts: Array, step := STEP) -> Dictionary:
	var cps := []
	for q: Variant in pts:
		cps.append(Vector2(float(q[0]), float(q[1])) / 100.0)
	var kp := TLKitPath.new(cps, false, step)
	var p: PackedVector2Array = kp.pts.duplicate()
	var t: PackedVector2Array = kp.tang.duplicate()
	var last: Vector2 = cps[cps.size() - 1]
	if p.is_empty() or p[p.size() - 1].distance_to(last) > step * 0.25:
		var before: Vector2 = p[p.size() - 1] if not p.is_empty() else (cps[0] as Vector2)
		p.append(last)
		t.append((last - before).normalized() if last != before else (t[t.size() - 1] if not t.is_empty() else Vector2.RIGHT))
	elif p.size() > 0:
		p[p.size() - 1] = last
	if p.size() == 1:                        # cannot happen for points 1 m apart; kept whole for safety
		p.append(last + Vector2(step, 0.0))
		t.append(Vector2.RIGHT)
	var n := p.size()
	if n >= 2:                               # the end tangents along the end segments (TLKitPath's are half-steps)
		t[0] = (p[1] - p[0]).normalized()
		t[n - 1] = (p[n - 1] - p[n - 2]).normalized()
	var length := 0.0
	for i: int in range(1, n):
		length += p[i].distance_to(p[i - 1])
	return {"p": p, "t": t, "len": length}


## The world box (x, z metres) of samples `p` grown by `r`.
static func box_of(p: PackedVector2Array, r: float) -> Rect2:
	var b := Rect2(p[0], Vector2.ZERO)
	for q: Vector2 in p:
		b = b.expand(q)
	return b.grow(r)


## [distance, segment index, t along it] from `q` to the polyline `p` over segments `segs` (all when empty).
static func nearest(p: PackedVector2Array, q: Vector2, segs: Array = []) -> Array:
	return PathShapeNearest.of(p, q, segs if not segs.is_empty() else range(p.size() - 1))


## A grid of the segments of many paths: cell -> {id: [segment index, ...]}.
class Index:
	var cells := {}                      # Vector2i -> {id: Array of segment indices}
	var of := {}                         # id -> [samples PackedVector2Array, half-width + reach]

	## Adds path `id`'s samples; `reach` metres round each segment are indexed (its half width and the margin asked).
	func add(id: int, p: PackedVector2Array, reach: float) -> void:
		of[id] = [p, reach]
		for i: int in p.size() - 1:
			var b := Rect2(p[i], Vector2.ZERO).expand(p[i + 1]).grow(reach)
			for cz: int in range(floori(b.position.y / CELL), floori(b.end.y / CELL) + 1):
				for cx: int in range(floori(b.position.x / CELL), floori(b.end.x / CELL) + 1):
					var k := Vector2i(cx, cz)
					if not cells.has(k):
						cells[k] = {}
					var d: Dictionary = cells[k]
					if not d.has(id):
						d[id] = []
					(d[id] as Array).append(i)

	func take(id: int) -> void:
		if not of.has(id):
			return
		var p: PackedVector2Array = of[id][0]
		var reach: float = of[id][1]
		of.erase(id)
		var b := Rect2(p[0], Vector2.ZERO)
		for q: Vector2 in p:
			b = b.expand(q)
		b = b.grow(reach)
		for cz: int in range(floori(b.position.y / CELL), floori(b.end.y / CELL) + 1):
			for cx: int in range(floori(b.position.x / CELL), floori(b.end.x / CELL) + 1):
				var k := Vector2i(cx, cz)
				if cells.has(k):
					(cells[k] as Dictionary).erase(id)
					if (cells[k] as Dictionary).is_empty():
						cells.erase(k)

	func clear() -> void:
		cells.clear()
		of.clear()

	## {id: [distance, segment, t]} for every path indexed within its reach of `q` (the reach it was added with).
	## `own` (an id) is measured over `own_segs` only, when given (a ribbon's own path near its own section).
	func near(q: Vector2, own := 0, own_segs: Array = []) -> Dictionary:
		var out := {}
		var d: Variant = cells.get(Vector2i(floori(q.x / CELL), floori(q.y / CELL)))
		if own > 0 and not own_segs.is_empty() and of.has(own):
			var r0: Array = PathShapeNearest.of(of[own][0], q, own_segs)
			if float(r0[0]) <= float(of[own][1]):
				out[own] = r0
		if d == null:
			return out
		for id: int in d:
			if id == own and not own_segs.is_empty():
				continue
			var r: Array = PathShapeNearest.of(of[id][0], q, d[id])
			if float(r[0]) <= float(of[id][1]):
				out[id] = r
		return out


## (an inner class cannot call its script's static funcs by the script's name without a preload cycle)
class PathShapeNearest:
	static func of(p: PackedVector2Array, q: Vector2, segs: Array) -> Array:
		var best := INF
		var bi := 0
		var bt := 0.0
		for i: int in segs:
			var a := p[i]
			var ab := p[i + 1] - a
			var l2 := ab.length_squared()
			var u := clampf((q - a).dot(ab) / l2, 0.0, 1.0) if l2 > 1e-9 else 0.0
			var dd := q.distance_to(a + ab * u)
			if dd < best:
				best = dd
				bi = i
				bt = u
		return [best, bi, bt]
