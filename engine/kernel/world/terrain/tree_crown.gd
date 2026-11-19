extends RefCounted
## One kit tree recipe before TLMesh merges its palette surfaces. A cone or blob is one
## connected triangle component. Keep its vertices and reuse them for every instance.
const PADDING := 0.24  # metres; plus the visitor camera's 0.30 m sphere, including cast tolerance
var parts: Array[PackedVector3Array] = []
var growth: Array[PackedVector3Array] = []
var hull_planes: Array = []
var baked := {}


func _init(mesh: TLMesh) -> void:
	for key: String in ["pine", "pine_light", "leaf", "leaf_light"]:
		if not mesh.surfs.has(key):
			continue
		var triangles: PackedVector3Array = mesh.surfs[key].v
		var connected := {}
		for i in range(0, triangles.size(), 3):
			for j in 3:
				var v := triangles[i + j]
				if not connected.has(v):
					connected[v] = []
				connected[v].append(triangles[i + (j + 1) % 3])
		for v: Vector3 in connected.keys():
			if not connected.has(v):
				continue
			var pending := [v]
			var points := PackedVector3Array()
			while not pending.is_empty():
				var p: Vector3 = pending.pop_back()
				if connected.has(p):
					points.append(p)
					pending.append_array(connected[p])
					connected.erase(p)
			_add_part(points)


func _add_part(points: PackedVector3Array) -> void:
	var hull := ConvexPolygonShape3D.new()
	hull.margin = 0.0
	hull.points = points
	# The native convex hull triangulation also fills the small dents in kit blobs.
	var faces := hull.get_debug_mesh().get_faces()
	var centre := Vector3.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	var planes: Array[Plane] = []
	var normals := {}
	for i in range(0, faces.size(), 3):
		var plane := Plane(faces[i], faces[i + 1], faces[i + 2])
		if plane.distance_to(centre) > 0.0:
			plane = -plane
		planes.append(plane)
		for j in 3:
			var v := faces[i + j]
			if not normals.has(v):
				normals[v] = []
			normals[v].append(plane.normal)
	var vertices := PackedVector3Array()
	var offsets := PackedVector3Array()
	for v: Vector3 in normals:
		var radial := (v - centre).normalized()
		var cosine := 1.0
		for normal: Vector3 in normals[v]:
			cosine = minf(cosine, radial.dot(normal))
		# Move each supporting face out by at least one unit along its normal.
		vertices.append(v)
		offsets.append(radial / cosine)
	parts.append(vertices)
	growth.append(offsets)
	hull_planes.append(planes)


func contains(p: Vector3) -> bool:
	for planes: Array in hull_planes:
		var inside := true
		for face: Plane in planes:
			if face.distance_to(p) > 0.0:
				inside = false
				break
		if inside:
			return true
	return false


func crosses(a: Vector3, b: Vector3) -> bool:
	for planes: Array in hull_planes:
		if not Geometry3D.segment_intersects_convex(a, b, planes).is_empty():
			return true
	return false


func shapes(basis: Basis) -> Array:
	if baked.has(basis):
		return baked[basis]
	var padded: Array[ConvexPolygonShape3D] = []
	var scale := basis.get_scale().abs()
	var pad := PADDING / minf(scale.x, minf(scale.y, scale.z))
	for i in parts.size():
		var vertices := PackedVector3Array()
		for j in parts[i].size():
			vertices.append(basis * (parts[i][j] + growth[i][j] * pad))
		var hull := ConvexPolygonShape3D.new()
		hull.margin = 0.0
		hull.points = vertices
		padded.append(hull)
	baked[basis] = padded
	return padded
