extends SceneTree

const World := preload("res://kernel/world/world.gd")
const View := preload("res://kernel/world/draw/view.gd")
const Draw := preload("res://kernel/world/draw/draw.gd")
const Visitor := preload("res://kernel/world/visitor.gd")
const Visit := preload("res://kernel/runner/visit.gd")


func _initialize() -> void:
	measure.call_deferred()


func marker(holder: Node3D, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.5, 1, 0.4)
	m.mesh = box
	m.position = at
	m.material_override = TLStyle.material(&"white")
	holder.add_child(m)
	return m


# Read the plot offset actually installed on a live mesh (toon.gdshader's tl_plot_mat).
func drawn(m: MeshInstance3D) -> Vector3:
	var offset: Variant = m.get_instance_shader_parameter(&"tl_plot")
	if offset == null:
		return m.global_position
	return Vector3(offset.x, offset.y, offset.z) + m.global_position.rotated(Vector3.UP, offset.w)


func measure() -> void:
	var host := Node.new()
	root.add_child(host)
	var view := View.new()
	host.add_child(view)
	view.set_process(false)
	view.set_physics_process(false)
	var world := World.new()
	view.world = world
	view.add_child(world)
	world.quit_on_end = false
	world.start({"walk": OS.get_cmdline_user_args()[0], "load": "step"})
	while world.tick < 60 and not world._ended:
		await physics_frame
	assert(world.packs.size() == 2 and world.site.report()[0].arrived_at == 38)
	assert(world.packs[0].loaded and world.packs[1].loaded and world.plot_defs[1].yaw == -30.0)
	TLStyle.set_headless(false)
	for def: Dictionary in world.plot_defs:
		view.plots.append(Transform3D(Basis(Vector3.UP, deg_to_rad(def.yaw)), def.origin))
	for plot: Dictionary in world.walk.plots:
		view.radii.append(plot.radius)
	var other: Transform3D = view.plots[0]
	var site: Transform3D = view.plots[1]
	var local := Vector3(10, 2, -3)
	var site_marker := marker(world.packs[1], local)
	var other_marker := marker(world.packs[0], Vector3(-3, 1, 5))
	var cam: Camera3D = world.packs[1].ctx.cameras.active
	var camera_frame := cam.global_transform
	view.landscape = Node3D.new()
	view.add_child(view.landscape)
	view.visitor = Visitor.new()
	view.landscape.add_child(view.visitor)
	view.visitor.setup(site.origin)
	view.visit = Visit.new()
	view.add_child(view.visit)
	assert(view.visit.setup(view, {}).is_empty())
	view.draw = Draw.new()
	view.add_child(view.draw)
	view.draw.setup(world, view.plots, view.radii, [0.0, 0.0], -1)

	view._set_stage(-1)
	assert(drawn(site_marker).is_equal_approx(site * local), "visitor's marker")
	view._set_stage(1)
	assert(root.get_camera_3d() == cam and cam.global_transform.is_equal_approx(camera_frame), "pack-local camera")
	assert(drawn(site_marker).is_equal_approx(local) and world.packs[1].bot_off)
	assert(drawn(other_marker).is_equal_approx(site.affine_inverse() * other * other_marker.position), "other plot on stage")
	assert(view.landscape.transform.is_equal_approx(site.affine_inverse()))
	view._set_stage(-1)
	assert(root.get_camera_3d() == view.visitor.cam and not world.packs[1].bot_off)
	assert(drawn(site_marker).is_equal_approx(site * local) and drawn(other_marker).is_equal_approx(other * other_marker.position))
	# The road in this walk runs due east at z=34. Leave through the southern gate, facing +Z.
	var feet: Vector3 = view.visitor.feet
	assert(Vector2(feet.x, feet.z).is_equal_approx(Vector2(site.origin.x, site.origin.z + view.radii[1] + 5)))
	assert(Vector3.FORWARD.rotated(Vector3.UP, view.visitor.look_yaw).is_equal_approx(Vector3.BACK))
	view.draw.clear()
	await world.ended
	assert(world.exit_code == 0 and world.tick == 100)
	print("SITE ARRIVED YAW STAGE OK")
	quit()
