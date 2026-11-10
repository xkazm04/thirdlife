class_name TLKitWall
extends RefCounted
## Kit part: pre-fractured barrier block. At BUILD time the block is cut into irregular convex slabs: a seeded
## Voronoi partition of the box (each cell = intersection of the box planes and the bisector planes to the other seeds).
## The intact block is a clean bevelled box; `crumble` swaps it for one RigidBody3D per slab. Outer faces keep the barrier
## colour, fracture faces show the darker core, and the bigger slabs carry exposed rebar. No runtime slicing.
## Params: w, h, d, cells (number of slabs), seed, tint.


static func _cell(planes: Array) -> Array:
	# planes: [normal, d] with inside = n.x <= d. Returns the cell's vertices (brute-force triple intersections).
	var pts: Array = []
	var n: int = planes.size()
	for i: int in n:
		for j: int in range(i + 1, n):
			for k: int in range(j + 1, n):
				var a: Vector3 = planes[i][0]
				var b: Vector3 = planes[j][0]
				var c: Vector3 = planes[k][0]
				var det: float = a.dot(b.cross(c))
				if absf(det) < 1e-6:
					continue
				var x: Vector3 = (b.cross(c) * float(planes[i][1]) + c.cross(a) * float(planes[j][1]) + a.cross(b) * float(planes[k][1])) / det
				var ok: bool = true
				for pl: Array in planes:
					if (pl[0] as Vector3).dot(x) > float(pl[1]) + 1e-4:
						ok = false
						break
				if not ok:
					continue
				var dup: bool = false
				for q: Vector3 in pts:
					if q.distance_squared_to(x) < 1e-6:
						dup = true
						break
				if not dup:
					pts.append(x)
	return pts


## Returns {chunks: [{mesh: ArrayMesh, pts: PackedVector3Array, centre: Vector3}]}.
static func block(w: float = 2.4, h: float = 1.0, d: float = 0.8, cells: int = 8, seed_: int = 1, tint: float = 1.0, key_out: String = "barrier", key_in: String = "barrier_dark", rebar: bool = true) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_
	var col: Color = Color(tint, tint, tint)
	var box: Array = [[Vector3.RIGHT, w * 0.5], [Vector3.LEFT, w * 0.5], [Vector3.UP, h], [Vector3.DOWN, 0.0], [Vector3.BACK, d * 0.5], [Vector3.FORWARD, d * 0.5]]
	# seeds: uneven on purpose so a few slabs are large and some are small shards
	var seeds: Array = []
	for i: int in cells:
		var fx: float = pow(rng.randf(), 0.8) * (1.0 if i % 2 == 0 else -1.0)
		seeds.append(Vector3(fx * w * 0.48, rng.randf_range(0.08, 0.92) * h, rng.randf_range(-0.42, 0.42) * d))
	var chunks: Array = []
	var is_outer: Callable = func(n: Vector3, dd: float) -> String:
		for b: Array in box:
			if n.dot(b[0]) > 0.999 and absf(dd - float(b[1])) < 0.02:
				return key_out
		return key_in
	for i: int in cells:
		var planes: Array = box.duplicate()
		for j: int in cells:
			if j == i:
				continue
			var nrm: Vector3 = ((seeds[j] as Vector3) - (seeds[i] as Vector3)).normalized()
			var mid: Vector3 = ((seeds[j] as Vector3) + (seeds[i] as Vector3)) * 0.5
			planes.append([nrm, nrm.dot(mid)])
		var pts: Array = _cell(planes)
		if pts.size() < 4:
			continue
		var cen: Vector3 = Vector3.ZERO
		for p: Vector3 in pts:
			cen += p
		cen /= float(pts.size())
		# re-centre on the centroid and shrink a hair so slabs separate cleanly
		var local: PackedVector3Array = PackedVector3Array()
		var ext: Vector3 = Vector3.ZERO
		for p: Vector3 in pts:
			local.append((p - cen) * 0.985)
			ext = ext.max((p - cen).abs())
		var m: TLMesh = TLMesh.new(seed_ + i)
		m.hull(Array(local), key_out, col, func(n: Vector3, dd: float) -> String: return is_outer.call(n, (dd / 0.985) + n.dot(cen)))
		if rebar and ext.x > 0.32 and ext.y > 0.18:
			for r: int in 2:
				var ry: float = (float(r) - 0.5) * ext.y * 0.7
				m.bar(Vector3(-ext.x * 1.18, ry, (0.5 - float(r)) * ext.z * 0.6), Vector3(ext.x * 1.18, ry, (0.5 - float(r)) * ext.z * 0.6), 0.035, 0.035, "rebar")
		chunks.append({"mesh": m.build("chunk"), "pts": local, "centre": cen})
	return {"chunks": chunks}
