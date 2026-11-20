extends MeshInstance3D
## Opt-in optics for the active view. A camera's own attributes take precedence.
var optics := CameraAttributesPractical.new()
var aperture := ShaderMaterial.new()
var settings: Dictionary
var last_subject := Vector2.INF
var distant_only := false

func configure(world: WorldEnvironment, options: Dictionary) -> void:
	settings = options
	distant_only = options.has("far_start")
	if mesh == null:
		TLStyle._screen_quad(self, aperture, -101)
	if distant_only:
		aperture.shader = preload("res://style/shaders/dof_distant.gdshader")
		aperture.set_shader_parameter(&"transition_m", maxf(0.1, options.get("far_transition", 150.0)))
		aperture.set_shader_parameter(&"strength", clampf(options.get("strength", 0.2), 0.0, 1.0))
		optics.dof_blur_near_enabled = false
		optics.dof_blur_far_enabled = false
	else:
		aperture.shader = preload("res://style/shaders/dof_tilt.gdshader")
		aperture.set_shader_parameter(&"tilt", tan(deg_to_rad(clampf(options.get("tilt_deg", 0.0), -60.0, 60.0))))
		for key: String in ["near_px", "far_px", "vista_near"]:
			aperture.set_shader_parameter(key, maxf(0.0, options.get(key, 0.0)))
	world.camera_attributes = optics
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 80 # Read the finished camera pose, including the parkour skyline turn.
	last_subject = Vector2.INF
	if is_inside_tree():
		_process(0.0)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	# A zero depth requests deep focus across the entire play space.
	var subject := Vector2(-1.0, 0.0)
	if camera != null and camera.has_method(&"_miniature_focus"):
		subject = camera.call(&"_miniature_focus")
	var depth := subject.x
	var scenic := depth < 0.0 and (distant_only or float(settings.get("vista_near", 0.0)) > 0.0)
	visible = (depth > 0.0 or scenic) and camera != null and camera.attributes == null
	if subject.distance_squared_to(last_subject) < 0.000225 and signf(depth) == signf(last_subject.x):
		return
	last_subject = subject
	if distant_only:
		# A long camera arm can carry the subject beyond the usual clear interval.
		var start := maxf(settings["far_start"], depth + maxf(3.5, depth*0.55))
		aperture.set_shader_parameter(&"start_m", start)
		return
	optics.dof_blur_near_enabled = depth > 0.0
	optics.dof_blur_far_enabled = depth != 0.0
	if depth == 0.0:
		return
	aperture.set_shader_parameter(&"subject", subject)
	if depth < 0.0:
		optics.dof_blur_far_distance = settings.get("vista_far", 98.0)
		optics.dof_blur_far_transition = settings.get("vista_transition", 160.0)
		optics.dof_blur_amount = settings.get("vista_amount", 0.0)
		return
	# Keep the whole figure and the next foothold inside the clear interval.
	var near_edge := maxf(0.05, depth - maxf(1.25, depth*0.24))
	optics.dof_blur_near_distance = near_edge
	optics.dof_blur_near_transition = maxf(0.4, near_edge*0.74)
	optics.dof_blur_far_distance = depth + maxf(3.5, depth*0.55)
	optics.dof_blur_far_transition = maxf(20.0, depth*4.5)
	optics.dof_blur_amount = settings.get("amount", 0.0)
