extends SceneTree
## Compare the displayed meshes and the shapes actually registered in the visitor's space.

const Site := preload("res://kernel/world/site.gd")
const Draw := preload("res://kernel/world/site/draw.gd")
const Space := preload("res://kernel/world/terrain/world_space.gd")
const CENTRE := Vector3(5, 3, -12)

class TestWorld:
	extends Node
	signal ended(bad: bool)
	var jobs = null
	var sched = null

class Ground:
	extends RefCounted
	func gy(x: float, z: float) -> float:
		return 3.0 + 0.02 * x - 0.01 * z

func _initialize() -> void:
	measure.call_deferred()

func capture(model: RefCounted, lot: int) -> Dictionary:
	var land := Node3D.new()
	root.add_child(land)
	var space := Space.new()
	land.set_meta(&"tl_space", space)
	land.set_meta(&"tl_terrain", Ground.new())
	land.tree_exiting.connect(space.free_all)
	var site := Draw.make(model, lot, CENTRE, 32.0, Vector2.RIGHT)
	land.add_child(site)
	site.set_process(false)  # sample the crane before it slews
	var view: Dictionary = model.view_of(lot)
	site._build(view)
	site.wait_meshes()  # 21 Nov L6: the worker meshes, waited for (it counted frames for them: 502 ran out of frames when busy)
	site._build(view)
	var visual := {}
	for mesh: MeshInstance3D in site.find_children("*", "MeshInstance3D", true, false):
		var surfaces := []
		for i in mesh.mesh.get_surface_count():
			surfaces.append(mesh.mesh.surface_get_arrays(i))
		visual[str(mesh.name)] = [mesh.global_transform, var_to_bytes(surfaces).hex_encode().sha256_text()]
	for label: Label3D in site.find_children("*", "Label3D", true, false):
		visual[label.text] = label.global_transform
	var boxes := []
	var walls := []
	for body: RID in space._bodies:
		var shape := PhysicsServer3D.body_get_shape(body, 0)
		var data: Variant = PhysicsServer3D.shape_get_data(shape)
		if PhysicsServer3D.shape_get_type(shape) == PhysicsServer3D.SHAPE_BOX:
			boxes.append([PhysicsServer3D.body_get_shape_transform(body, 0), data * 2.0])
		else:
			walls.append(data.faces)
	land.free()
	return {"visual": visual, "boxes": boxes, "walls": walls}

func measure() -> void:
	TLStyle.set_headless(false)
	var host := TestWorld.new()
	var model := Site.new()
	var lots := []
	for source: String in ["legacy", "zero", "job", "draft"]:
		lots.append({"at": [5.0, -12.0], "h": 3, "radius": 32, "job": OS.get_cmdline_user_args()[0].path_join(source)})
	model.setup(host, {"landscape": {"lots": lots}})
	model.tick(0)
	var legacy := await capture(model, 0)
	var zero := await capture(model, 1)
	print("Zero-yaw mesh and shape digest ", var_to_bytes(zero).hex_encode().sha256_text())
	assert(legacy == zero, "zero yaw must exactly reproduce every legacy mesh, label, box and rail")
	var turned := await capture(model, 2)
	assert(turned == await capture(model, 2), "repeat build")
	assert(turned == await capture(model, 3), "draft and job give identical placement")
	var reports := model.report()
	assert(not reports[0].has("yaw_deg") and not reports[1].has("yaw_deg"))
	assert(reports[2].yaw_deg == 30 and reports[3].yaw_deg == 30)
	var gate := Transform3D(Basis(Vector3.UP, PI / 2), CENTRE)
	# Independent reference: editor +X turns toward +Z on its X/Z map.
	var axis := Vector3(sqrt(3.0) * 0.5, 0, 0.5)
	var footprint := Transform3D(Basis(axis, Vector3.UP, axis.cross(Vector3.UP)), CENTRE)
	var centres := [Vector3(22.5, 3, -11.84), Vector3(-13, 1.7, -2.84), Vector3(0, 0.6, -2.84), Vector3(13, 0.6, -2.84)]
	# 21 Nov L1: after the crane and three bays come the four posts of the sign and the plan board (draw.gd `_posts`) and
	# the five stretches of the site fence on the footprint (B2, draw.gd `hoarding`); before: 4 boxes
	assert(legacy.boxes.size() == 13 and turned.boxes.size() == 13, "boxes: crane, 3 bays, 4 posts, 5 fence stretches")
	for i in centres.size():
		var size := Vector3(4, 6, 4) if i == 0 else Vector3(12.2, 3.4 if i == 1 else 1.2, 10.6)
		for pair: Array in [[legacy, gate], [turned, footprint]]:
			var box: Array = pair[0].boxes[i]
			var expected: Transform3D = pair[1].translated_local(centres[i])
			assert(box[0].is_equal_approx(expected) and box[1].is_equal_approx(size), "crane or bay box %d" % i)
	assert(turned.walls.size() == 2 and turned.walls == legacy.walls)
	for key: String in ["site_sign", "site_rails", "Bounce court", "0 of 3 built"]:
		assert(turned.visual[key] == legacy.visual[key], "entrance moved: " + key)
	for key: String in ["site_bays", "Tower", "site_plan"]:
		var drawn: Transform3D = turned.visual[key][0]
		assert(drawn.basis.is_equal_approx(footprint.basis), "mesh axis: " + key)
	for key: String in ["site_bays", "Tower"]:
		assert(turned.visual[key][1] == legacy.visual[key][1], "mesh geometry: " + key)
	var board: Transform3D = turned.visual["The plan"]
	assert(board.is_equal_approx(footprint.translated_local(Vector3(0, 5.21, -19.0))), "plan board on the turned lot")
	assert(turned.visual.Tower[0].origin.is_equal_approx(footprint * Vector3(22.5, 0, -11.84)))
	for lot: int in [0, 2]:
		model.sites[lot].arrived_dir = "promoted/fixture"
		model.sites[lot].radius = 20.0
	var arrived := await capture(model, 0)
	assert(arrived.visual.has("site_arrived") and arrived.boxes.size() == 4 and arrived.walls.size() == 2)     # 21 Nov L1: two pillars and the sign's two posts (before: 2); no site fence once the game is here
	assert(arrived == await capture(model, 2), "refitted gate path, arch, masts and pillars")
	host.free()
	print("SITE EDITOR YAW OK")
	quit(0)
