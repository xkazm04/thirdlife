extends RefCounted
## Independent clearance oracle. Read the actual MultiMesh and its palette column from CUSTOM0
## (TLMesh merges the toon materials), before looking at any camera collision result.
const GROUPS := ["WorldPines0", "WorldPines1", "WorldPines2", "WorldBroadleaf", "WorldRoadTrees",
	"WorldBelt0", "WorldBelt1", "WorldMesaPines"]

var space := PhysicsServer3D.space_create()
var bodies: Array[RID] = []
var shapes: Array[Shape3D] = []
var point := PhysicsPointQueryParameters3D.new()
var probe := PhysicsShapeQueryParameters3D.new()


func _init() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	probe.shape = sphere


func parts_of(mesh: Mesh) -> Array[PackedVector3Array]:
	var leaves: Array[int] = []
	for key: String in ["pine", "pine_light", "leaf", "leaf_light"]:
		leaves.append(TLStyle.index(key))
	var neighbours := {}
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var palette: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
		for i in range(0, points.size(), 3):
			if int(palette[4 * i + 3]) / 16 not in leaves:
				continue
			for j in 3:
				var a := points[i + j]
				if not neighbours.has(a):
					neighbours[a] = []
				neighbours[a].append(points[i + (j + 1) % 3])
	var parts: Array[PackedVector3Array] = []
	for start: Vector3 in neighbours.keys():
		if not neighbours.has(start):
			continue
		var vertices := PackedVector3Array()
		var pending := [start]
		while not pending.is_empty():
			var next: Vector3 = pending.pop_back()
			if neighbours.has(next):
				vertices.append(next)
				pending.append_array(neighbours[next])
				neighbours.erase(next)
		parts.append(vertices)
	return parts


func place(parts: Array[PackedVector3Array], xf: Transform3D) -> void:
	var body := PhysicsServer3D.body_create()
	bodies.append(body)
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis(), xf.origin))
	for part in parts:
		var shape := ConvexPolygonShape3D.new()
		shape.margin = 0.0
		shape.points = Transform3D(xf.basis, Vector3.ZERO) * part
		shapes.append(shape)
		PhysicsServer3D.body_add_shape(body, shape.get_rid())
	PhysicsServer3D.body_set_space(body, space)


func inside(at: Vector3) -> bool:
	point.position = at
	return not PhysicsServer3D.space_get_direct_state(space).intersect_point(point, 1).is_empty()


func near_crown(at: Vector3) -> bool:
	probe.transform.origin = at
	return not PhysicsServer3D.space_get_direct_state(space).intersect_shape(probe, 1).is_empty()


func close() -> void:
	for body in bodies:
		PhysicsServer3D.free_rid(body)
	PhysicsServer3D.free_rid(space)
