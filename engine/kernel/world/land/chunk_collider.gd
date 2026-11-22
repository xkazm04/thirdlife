extends RefCounted
## Exact village faces and the centred, fixed-diagonal heightfield for fixed-split land.

static func faces(t, rect: Rect2i, skip: Callable) -> PackedVector3Array:
	# P13: the same triangles in the same order as P4's loop, without an Array per cell, and `skip` asked only for
	# cells near a plot whose own ground carries the visitor (`t.skip_near`: centres and radii; empty = ask everywhere)
	var faces: PackedVector3Array = PackedVector3Array()
	faces.resize(rect.get_area() * 6)
	var n: int = 0
	var heights: PackedFloat32Array = t.heights
	var pitch: int = t.nx + 1
	var x0: float = t.x0
	var z0: float = t.z0
	var cell: float = t.cell
	var ground_y: float = t.GROUND_Y
	var regions: PackedVector3Array = t.skip_near
	var alternate: bool = not t.fixed_chunks.has(rect.position / 32)
	var ask_everywhere := skip.is_valid() and regions.is_empty()
	for j: int in range(rect.position.y, rect.end.y):
		var za := z0 + float(j) * cell
		for i: int in range(rect.position.x, rect.end.x):
			var xa := x0 + float(i) * cell
			var k := j * pitch + i
			var a := Vector3(xa, heights[k] + ground_y, za)
			var b := Vector3(xa + cell, heights[k + 1] + ground_y, za)
			var c := Vector3(xa + cell, heights[k + pitch + 1] + ground_y, za + cell)
			var d := Vector3(xa, heights[k + pitch] + ground_y, za + cell)
			var ask := ask_everywhere
			for q in regions:
				if absf(xa + cell * 0.5 - q.x) < q.z + cell and absf(za + cell * 0.5 - q.y) < q.z + cell:
					ask = true
					break
			var even := alternate and ((i + j) & 1) == 0
			var t0a: Vector3 = a
			var t0b: Vector3 = b
			var t0c: Vector3 = c if even else d
			var t1a: Vector3 = a if even else b
			var t1b: Vector3 = c
			var t1c: Vector3 = d
			if not ask or not bool(skip.call((t0a.x + t0b.x + t0c.x) / 3.0, (t0a.z + t0b.z + t0c.z) / 3.0)):
				faces[n] = t0a
				faces[n + 1] = t0c
				faces[n + 2] = t0b
				n += 3
			if not ask or not bool(skip.call((t1a.x + t1b.x + t1c.x) / 3.0, (t1a.z + t1b.z + t1c.z) / 3.0)):
				faces[n] = t1a
				faces[n + 1] = t1c
				faces[n + 2] = t1b
				n += 3
	faces.resize(n)
	return faces


## `tag` and `stat`: the body's tag in the space and the stats key its faces count under (D1: the Home's chunks are
## "home ground" / "home_faces", so the village's terrain bodies and face total stay what they were).
static func build(t, rect: Rect2i, triangles: PackedVector3Array, kind: String, ws, tag := "terrain", stat := "faces") -> Dictionary:
	var shape: Shape3D
	var transform := Transform3D.IDENTITY
	var count := 0
	if kind == "heightmap":
		var heightmap := HeightMapShape3D.new()
		heightmap.map_width = rect.size.x + 1
		heightmap.map_depth = rect.size.y + 1
		var data := PackedFloat32Array()
		for j in range(rect.position.y, rect.end.y + 1):
			var start: int = j * (t.nx + 1) + rect.position.x
			data.append_array(t.heights.slice(start, start + heightmap.map_width))
		heightmap.map_data = data
		shape = heightmap
		var centre := Vector2(rect.position) + Vector2(rect.size) * 0.5
		transform.origin = Vector3(t.x0 + centre.x * t.cell, t.GROUND_Y, t.z0 + centre.y * t.cell)
		transform.basis = Basis.from_scale(Vector3(t.cell, 1.0, t.cell))
	else:
		var concave := ConcavePolygonShape3D.new()
		concave.backface_collision = true
		if not triangles.is_empty():
			concave.set_faces(triangles)
		count = triangles.size() / 3
		shape = concave
	var previous: String = ws.tag
	ws.tag = tag
	var body: RID = ws._static(shape, transform)
	ws.tag = previous
	ws.stats[stat] = int(ws.stats.get(stat, 0)) + count
	return {"body": body, "shape": shape, "faces": count, "stat": stat}


static func drop(collider: Dictionary, ws) -> void:
	var body: RID = collider.body
	ws._bodies.erase(body)
	ws._tags.erase(body)
	PhysicsServer3D.free_rid(body)
	ws.stats.bodies -= 1
	ws.stats[collider.get("stat", "faces")] -= collider.faces
