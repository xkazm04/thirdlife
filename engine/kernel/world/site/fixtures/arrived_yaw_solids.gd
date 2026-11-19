extends SceneTree

const Pack := preload("res://kernel/world/pack.gd")
const Space := preload("res://kernel/world/terrain/world_space.gd")
const Site := preload("res://kernel/world/site.gd")
const Terrain := preload("res://kernel/world/terrain/village_terrain.gd")
const PACK_DIR := "res://kernel/world/site/fixtures/arrive/promoted/example.bounce@0.1.0"
const WALL := Vector3(8, 0.5, 1.5) # long, thin wall of the promoted game's pellet bin
const FLOOR := [Vector3(27, 1, -2), Vector3(28, 1, 2), Vector3(30, 1, -2)]
const RADIUS := 30.0
const RIM := 4.0
const BAND := 6.0


func _initialize() -> void:
	measure.call_deferred()


func ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))


func check_pad() -> void:
	var walk := {"landscape": {"cell_m": 2, "margin_m": 20}, "plots": [
		{"origin": [0, 0, 0], "footprint": {"size_m": [20, 20]}},
		{"origin": [350, 0, 170], "site_lot": 0, "yaw": -30, "radius": 6, "footprint": {"size_m": [40, 12]}}]}
	var actual = Site._base_terrain(walk, Callable())
	# Extreme corners of the two pads, before the clearance, landscape margin and 2 m grid.
	var lo := Vector2(-10, -10)
	var hi := Vector2(350 + 10 * sqrt(3.0) + 3, 170 + 10 + 3 * sqrt(3.0))
	var start := ((lo - Vector2.ONE * 30.5) / 2).floor() * 2
	var end := ((hi + Vector2.ONE * 30.5) / 2).ceil() * 2
	var reference := Terrain.new(7, Rect2(start, end - start), 2)
	reference.centre = (lo + hi) / 2
	assert(actual.centre.is_equal_approx(reference.centre))
	assert(Vector2(actual.x1(), actual.z1()) == end)
	assert(is_equal_approx(actual.base_h(350, 170), reference.base_h(350, 170)))


func measure() -> void:
	check_pad()
	var pack := Pack.new()
	root.add_child(pack)
	assert(pack.load_pack(PACK_DIR, {"seed": 1}))
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(PackedVector3Array(FLOOR))
	collider.shape = shape
	floor_body.add_child(collider)
	pack.ctx.root.add_child(floor_body)
	for body: CollisionObject3D in pack.find_children("*", "CollisionObject3D", true, false):
		pack.adopt(body)

	# Editor +30: independently specified village axes; +X lands towards +Z.
	var x := Vector3(sqrt(3.0) / 2.0, 0, 0.5)
	var z := x.cross(Vector3.UP)
	var origin := Vector3(43, 7, -19)
	var plot := Transform3D(Basis(Vector3.UP, deg_to_rad(-30.0)), origin)
	var expected_wall := origin + x * WALL.x + Vector3.UP * WALL.y + z * WALL.z
	var floor_centre := Vector3.ZERO
	for v: Vector3 in FLOOR:
		var t := clampf((Vector2(v.x, v.z).length() - (RADIUS - BAND)) / BAND, 0.0, 1.0)
		var h := lerpf(v.y, RIM, t * t * (3.0 - 2.0 * t))
		floor_centre += (origin + x * v.x + Vector3.UP * h + z * v.z) / 3.0
	for sliced: bool in [false, true]:
		var visitor := Space.new()
		if sliced:
			visitor.finish() # as in a village which was already built before promotion
			var job := visitor.begin_pack(pack, plot, RADIUS, RIM, BAND)
			while not visitor.step_pack(job, 0):
				await physics_frame
		else:
			visitor.add_pack(pack, plot, RADIUS, RIM, BAND)
			visitor.finish()
		await physics_frame
		var state := PhysicsServer3D.space_get_direct_state(visitor.space)
		var wall := ray(state, expected_wall + z, expected_wall)
		assert(not wall.is_empty() and wall.normal.dot(z) > 0.999, "village wall normal")
		assert(wall.position.distance_to(expected_wall + z * 0.1) < 0.01, "village wall position")
		var old := origin + WALL
		assert(ray(state, old + Vector3.UP, old).is_empty(), "former village location")
		var floor_hit := ray(state, floor_centre + Vector3.UP * 5, floor_centre - Vector3.UP * 5)
		assert(not floor_hit.is_empty() and floor_hit.position.distance_to(floor_centre) < 0.01, "turned rim height")

		var own := TLContext.space_state_of(pack.ctx.root, pack.ctx)
		var original := ray(own, WALL + Vector3.BACK, WALL)
		assert(not original.is_empty() and original.normal.dot(Vector3.BACK) > 0.999, "pack-local bin wall")
		assert(original.position.distance_to(WALL + Vector3.BACK * 0.1) < 0.01)
		assert(ray(own, expected_wall + z, expected_wall).is_empty(), "village copy leaked into the pack")
		var local_floor: Vector3 = (FLOOR[0] + FLOOR[1] + FLOOR[2]) / 3.0
		var flat := ray(own, local_floor + Vector3.UP * 5, local_floor - Vector3.UP * 5)
		assert(not flat.is_empty() and flat.position.distance_to(local_floor) < 0.01, "pack-local floor")
		visitor.free_all()
	for child in pack.get_children():
		child.free()
	pack.release_space()
	pack.free()
	print("SITE ARRIVED YAW SOLIDS OK")
	quit()
