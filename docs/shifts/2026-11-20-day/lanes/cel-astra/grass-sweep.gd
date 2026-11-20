extends SceneTree
## Native and supersampled crops of the same 27 village camera poses.
## TL_CEL_EVIDENCE is the output directory. TL_GRASS_REFERENCE=1 records
## ref and ref-mask. TL_GRASS_SKYLINE=1 isolates the village's actual tufts.
const Cel := preload("res://style/cel/style_cel.gd")
var camera: Camera3D
var start: Transform3D
var output: String


func _initialize() -> void:
	_run.call_deferred()


func _sweep(name_: String, scale_: int) -> Error:
	var dest := output.path_join(name_)
	if DirAccess.dir_exists_absolute(dest):
		push_error("Grass plate directory already exists: " + dest)
		return ERR_ALREADY_EXISTS
	var error := DirAccess.make_dir_recursive_absolute(dest)
	if error != OK:
		return error
	root.size = Vector2i(1920,1080) * scale_
	camera.global_transform = start
	for i in 12:
		await RenderingServer.frame_post_draw
	for i in 27:
		camera.global_transform = Transform3D(start.basis.rotated(Vector3.UP,deg_to_rad(.015*i)),start.origin)
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		if scale_ > 1:
			frame.resize(1920,1080,Image.INTERPOLATE_LANCZOS)
		error = frame.get_region(Rect2i(0,230,1920,440)).save_png(dest.path_join("%02d.png" % i))
		if error != OK:
			push_error("Could not save grass plate %s, frame %d" % [dest,i])
			return error
	return OK


func _run() -> void:
	output = OS.get_environment("TL_CEL_EVIDENCE")
	if output.is_empty():
		push_error("Set TL_CEL_EVIDENCE to a fresh output directory")
		quit(1)
		return
	var boot := preload("res://boot/boot.tscn").instantiate()
	root.add_child(boot)
	current_scene = boot
	while int(boot.get("_frame")) < 190:
		await physics_frame
	paused = true
	Engine.time_scale = 0.0
	for node: Node in boot.find_children("*","Node",true,false):
		node.set_process(false)
		node.set_physics_process(false)
	var original := root.get_camera_3d()
	start = original.global_transform
	camera = Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.fov = original.fov
	camera.far = original.far
	camera.near = original.near
	boot.add_child(camera)
	camera.global_transform = start
	camera.make_current()
	var grass := boot.find_child("WorldTufts",true,false) as MultiMeshInstance3D
	if grass == null or grass.multimesh == null or grass.multimesh.instance_count == 0:
		push_error("The village has no grass instances to measure")
		boot.call("_end_world")
		quit(1)
		return
	if OS.get_environment("TL_GRASS_SKYLINE") == "1":
		var ink := boot.find_child("InkPost",true,false)
		for mesh: GeometryInstance3D in boot.find_children("*","GeometryInstance3D",true,false):
			if mesh != grass and mesh != ink:
				mesh.hide()
	var error: Error
	if OS.get_environment("TL_GRASS_REFERENCE") == "1":
		Cel.configure_distant_aa(boot.find_child("WorldEnvironment",true,false),0.0)
		root.msaa_3d = Viewport.MSAA_8X
		root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		error = await _sweep("ref",2)
		if error == OK:
			grass.hide()
			error = await _sweep("ref-mask",2)
	else:
		var profile := OS.get_environment("TL_GRASS_PROFILE")
		error = await _sweep(profile if not profile.is_empty() else "delivery",1)
	if error == OK:
		print("GRASS_SWEEP_OK")
	Engine.time_scale = 1.0
	paused = false
	boot.call("_end_world")
	quit(0 if error == OK else 1)

