extends SceneTree
## Exercise the site's ordinary worker mesh and tagged physics bodies with a headless rendering driver.

const Draw := preload("res://kernel/world/site/draw.gd")
const Space := preload("res://kernel/world/terrain/world_space.gd")

class SiteView:
	extends RefCounted
	var view := {"stage": "pad", "title": "Test", "arrived": false, "radius": 32.0,
		"job_state": "running", "packages": [], "total": 0, "built": 0}
	func view_of(_lot: int) -> Dictionary:
		return view

class Ground:
	extends RefCounted
	func gy(x: float, z: float) -> float:
		return 3.0 + 0.02 * x - 0.01 * z

func _initialize() -> void:
	measure.call_deferred()

func measure() -> void:
	TLStyle.set_headless(false)
	var land := Node3D.new()
	root.add_child(land)
	var space := Space.new()
	land.set_meta(&"tl_space", space)
	land.set_meta(&"tl_terrain", Ground.new())
	land.tree_exiting.connect(space.free_all)
	var model := SiteView.new()
	var site := Draw.make(model, 0, Vector3(5, 3, -12), 32.0, Vector2.RIGHT)
	site.road_half_m = 5.0
	land.add_child(site)
	for arrived: bool in [false, true]:
		model.view.arrived = arrived
		model.view.radius = 20.0 if arrived else 32.0
		# Wait for the first build (including a refit) and for its worker mesh to be displayed.
		while site.radius != model.view.radius or not site.has_node("Parts/site_rails") or not site._tasks.is_empty() or (arrived and not site.has_node("Parts/site_arrived")):
			await physics_frame
		var rail := site.get_node("Parts/site_rails") as MeshInstance3D
		var gate_z := float(model.view.radius) + 3.6
		var length := 4.8 if arrived else 7.68
		var end_x := 6.0 + length
		var mesh := rail.mesh.get_aabb()
		assert(absf(mesh.position.x + end_x) < 0.15 and absf(mesh.end.x - end_x) < 0.15, "rail length")
		assert(absf(mesh.position.z - (gate_z - 0.5 if arrived else gate_z)) < 0.15, "rail gate line")
		assert(absf(mesh.end.z - (33.0 if arrived else gate_z)) < 0.15, "path back to the plot gate")
		assert(site.find_child("site_fence", true, false) == null, "round fence mesh")
		assert(space._bodies.size() == (4 if arrived else 3), "expected just two rails and the arch pillars or crane")
		var sides := []
		for body: RID in space._bodies:
			var shape := PhysicsServer3D.body_get_shape(body, 0)
			if PhysicsServer3D.shape_get_type(shape) != PhysicsServer3D.SHAPE_CONCAVE_POLYGON:
				continue
			var faces: PackedVector3Array = PhysicsServer3D.shape_get_data(shape).faces
			assert(faces.size() == 6, "one wall per rail")
			var a: Vector3 = site.transform.affine_inverse() * faces[0]
			var b: Vector3 = site.transform.affine_inverse() * faces[1]
			assert(is_equal_approx(absf(a.x), 6.0) and is_equal_approx(b.x, signf(a.x) * end_x), "rail endpoints")
			assert(is_equal_approx(a.z, gate_z) and is_equal_approx(b.z, gate_z), "collider gate line")
			assert(is_equal_approx(faces[0].y, land.get_meta(&"tl_terrain").gy(faces[0].x, faces[0].z)), "rail foot")
			assert((faces[2] - faces[1]).is_equal_approx(Vector3.UP * 1.2), "rail wall height")
			sides.append(signf(a.x))
		sides.sort()
		assert(sides == [-1.0, 1.0], "one wall on each side of the entrance")
	land.free()
	print("SITE RAILS OK")
	quit(0)
