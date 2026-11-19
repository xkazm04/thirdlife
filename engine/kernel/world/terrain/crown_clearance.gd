extends RefCounted
## Exact raw foliage for the few trees within one camera arm during a clearance repair.
## Keep one bounded neighbourhood per visitor; no raw-body copies in the walker's space.
const GAP := 0.501
var space := RID()
var copies := {}
var range_shape := SphereShape3D.new()
var range_query := PhysicsShapeQueryParameters3D.new()
var point := PhysicsPointQueryParameters3D.new()
var sphere := SphereShape3D.new()
var probe := PhysicsShapeQueryParameters3D.new()
var ray := PhysicsRayQueryParameters3D.new()
var at_head := []
var part_count := 0


func _init() -> void:
	range_query.shape = range_shape
	range_query.collision_mask = 4
	sphere.radius = GAP
	probe.shape = sphere


func prepare(st: PhysicsDirectSpaceState3D, crowns: Dictionary, head: Vector3, length: float) -> void:
	if not space.is_valid():
		space = PhysicsServer3D.space_create()
	range_shape.radius = length + GAP
	range_query.transform.origin = head
	var seen := {}
	for hit in st.intersect_shape(range_query, 5 * crowns.size()):
		var rid: RID = hit.rid
		if not crowns.has(rid) or seen.has(rid):
			continue
		seen[rid] = true
		if copies.has(rid):
			continue
		var tree: Array = crowns[rid]
		var xf: Transform3D = tree[1].affine_inverse()
		var body := PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis(), xf.origin))
		var shapes := []
		for vertices: PackedVector3Array in tree[0].parts:
			var hull := ConvexPolygonShape3D.new()
			hull.margin = 0.0
			hull.points = Transform3D(xf.basis, Vector3.ZERO) * vertices
			PhysicsServer3D.body_add_shape(body, hull.get_rid())
			shapes.append(hull)
		PhysicsServer3D.body_set_space(body, space)
		copies[rid] = [body, shapes]
	for rid: RID in copies.keys():
		if not seen.has(rid):
			PhysicsServer3D.free_rid(copies[rid][0])
			copies.erase(rid)
	var raw := PhysicsServer3D.space_get_direct_state(space)
	var ignore: Array[RID] = []
	point.position = head
	for hit in raw.intersect_point(point):
		ignore.append(hit.rid)
	ray.from = head
	ray.exclude = ignore
	probe.exclude = ignore
	probe.transform.origin = head
	part_count = 0
	for entry: Array in copies.values():
		part_count += entry[1].size()
	at_head = raw.intersect_shape(probe, maxi(part_count, 1))


## Furthest clear pull on an arm already clipped to solid walls. The sightline ends
## at the first raw leaf. A sphere touches a convex part along one continuous interval.
## Skip exactly the blocked interval (to 0.1 mm) so a thin clear gap still counts.
func reach(dir: Vector3, limit: float) -> float:
	var raw := PhysicsServer3D.space_get_direct_state(space)
	ray.to = ray.from + dir * limit
	var hit := raw.intersect_ray(ray)
	if not hit.is_empty():
		limit = ray.from.distance_to(hit.position)
	while limit >= 0.01:
		probe.transform.origin = ray.from + dir * limit
		var hits := raw.intersect_shape(probe, 1)
		if hits.is_empty():
			return limit
		for start: Dictionary in at_head:
			if start.rid == hits[0].rid and start.shape == hits[0].shape:
				return -1.0
		if limit == 0.01:
			break
		# The head is outside this part. Find the near edge of this contact, then
		# check there against all the other parts before accepting it.
		var outside := 0.0
		var inside := limit
		while inside - outside > 0.0001:
			var middle := (inside + outside) * 0.5
			probe.transform.origin = ray.from + dir * middle
			var touches := false
			for contact in raw.intersect_shape(probe, part_count):
				if contact.rid == hits[0].rid and contact.shape == hits[0].shape:
					touches = true
					break
			if touches:
				inside = middle
			else:
				outside = middle
		limit = maxf(0.01, outside)
	return -1.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for entry: Array in copies.values():
			PhysicsServer3D.free_rid(entry[0])
		if space.is_valid():
			PhysicsServer3D.free_rid(space)
