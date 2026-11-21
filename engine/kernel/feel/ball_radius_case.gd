extends SceneTree
## Standalone physics probe. The vertical rays see the top of the resized
## puck or the concrete underneath, so the outside ray also controls the test.
var balls: Array[TLBall] = []
var floor_body: StaticBody3D


func _initialize() -> void:
	_run.call_deferred()


func _bounds(ball: TLBall) -> AABB:
	var total := AABB()
	var first := true
	for m: MeshInstance3D in ball.find_children("*", "MeshInstance3D", true, false):
		var box := (ball.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		total = box if first else total.merge(box)
		first = false
	return total


func _run() -> void:
	floor_body = TLBodies.ground(Vector2(12, 10), "concrete")
	root.add_child(floor_body)
	var options := [{"kind": "puck", "planar": true}, {"kind": "ball"},
		{"part": TLKit.build("puck", {}), "planar": true}]
	for i in options.size():
		var b := TLBall.create(options[i])
		b.position = Vector3(i * 2, 0.18, 0)
		root.add_child(b)
		balls.append(b)
	await physics_frame
	var ok := true
	for b: TLBall in balls:
		var original := _bounds(b).size
		var mass_before := b.mass
		var ratio := 0.3 / b.radius
		b.set_radius(0.3)
		var shape_node := b.find_children("*", "CollisionShape3D", true, false)[0] as CollisionShape3D
		var shape_radius: float = shape_node.shape.radius
		var size := _bounds(b).size
		var want := original * Vector3(ratio, ratio if b.kind == &"ball" else 1.0, ratio)
		ok = ok and is_equal_approx(shape_radius, 0.3) and is_equal_approx(b.mass, mass_before)
		ok = ok and size.is_equal_approx(want) and absf(size.x - 0.6) < 0.02 and absf(size.z - 0.6) < 0.02
		print("RADIUS ", b.kind, " shape=", shape_radius, " mesh=", size, " mass=", mass_before, " -> ", b.mass)
	for i in 120:
		await physics_frame
	var puck: TLBall = balls[0]
	var space := puck.get_world_3d().direct_space_state
	var hits: Array = []
	for offset: float in [0.25, 0.32]:
		var xz := Vector3(puck.position.x + offset, 0, puck.position.z)
		var ray := PhysicsRayQueryParameters3D.create(xz + Vector3.UP, xz + Vector3.DOWN)
		hits.append(space.intersect_ray(ray).get("collider"))
	var resting := absf(puck.position.y - puck.height * 0.5) < 0.012 and puck.linear_velocity.length() < 0.02
	ok = ok and resting and hits[0] == puck and hits[1] == floor_body
	print("RADIUS ok=", ok, " bodies=", balls.size(), " resting=", resting,
		" inside_hit=", hits[0] == puck, " outside_floor=", hits[1] == floor_body)
	quit(0 if ok else 1)
