extends RefCounted
## Crisp frame settings and the higher light used on a fixed overhead board.

class OverheadKey extends Node:
	var sun: DirectionalLight3D
	var overhead_pitch := 0.0
	var normal_pitch := 0.0

	func _process(_delta: float) -> void:
		var cam := get_viewport().get_camera_3d()
		var plan: bool = cam != null and cam.has_method(&"_miniature_tabletop") and cam.call(&"_miniature_tabletop")
		var pitch := overhead_pitch if plan else normal_pitch
		if not is_equal_approx(sun.rotation.x,pitch):
			sun.rotation.x = pitch


static func configure_sun(sun: DirectionalLight3D, settings: Dictionary) -> void:
	var key := sun.get_node_or_null("OverheadKey") as OverheadKey
	if not settings.has("overhead_elev"):
		if key != null:
			key.free()
		return
	if key == null:
		key = OverheadKey.new()
		key.name = "OverheadKey"
		key.sun = sun
		key.process_mode = Node.PROCESS_MODE_ALWAYS
		key.process_priority = 80
		sun.add_child(key)
	key.normal_pitch = -deg_to_rad(float(settings.elev))
	key.overhead_pitch = -deg_to_rad(float(settings.overhead_elev))
	if key.is_inside_tree():
		key._process(0.0)


static func install_grade(rig: Node, enabled: bool, settings: Dictionary, shaders: Dictionary) -> void:
	var layer := rig.get_node_or_null("Grade") as CanvasLayer
	if not enabled:
		if layer != null:
			layer.free()
		return
	if layer == null:
		layer = CanvasLayer.new()
		layer.layer = 1
		layer.name = "Grade"
		var rect := ColorRect.new()
		rect.name = "Rect"
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.material = ShaderMaterial.new()
		layer.add_child(rect)
		rig.add_child(layer)
	var grade := (layer.get_node("Rect") as ColorRect).material as ShaderMaterial
	var cel := settings.has("plum_density") or settings.has("edge_contrast")
	grade.shader = preload("res://style/dio/style_dio.gd").variant("grade","TL_CEL_GRADE" if cel else "",shaders)
	if cel:
		grade.set_shader_parameter(&"plum_density",settings.get("plum_density",0.0))
		grade.set_shader_parameter(&"edge_contrast",settings.get("edge_contrast",0.0))
	TLStyle.push("grade",grade)


static func check(d: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if d.has("figure") and d.figure not in [{}, {"model":"cel"}]:
		errors.append("figure expects an optional model named 'cel'")
	var env: Variant = d.get("env")
	if not env is Dictionary:
		return errors
	if env.has("cel_sky") and not env.cel_sky is bool:
		errors.append("env.cel_sky must be a boolean")
	if env.has("exe_aa"):
		var seen := PackedStringArray()
		var spec: Variant = env.exe_aa
		if not spec is String or spec.is_empty():
			errors.append("env.exe_aa expects an antialiasing specification")
		else:
			for part: String in spec.split(","):
				var key := part.get_slice("=",0)
				if part not in ["msaa=0","msaa=2","msaa=4","msaa=8","ss=off","ss=fxaa","ss=smaa","taa=0","taa=1"] or key in seen:
					errors.append("invalid or duplicate env.exe_aa option '%s'" % part)
				seen.append(key)
	if not env.has("visitor_frame"):
		return errors
	if not env.visitor_frame is Dictionary:
		errors.append("env.visitor_frame must be an object")
		return errors
	for key: String in env.visitor_frame:
		var value: Variant = env.visitor_frame[key]
		if key not in ["arm","lift"]:
			errors.append("unknown env.visitor_frame key '%s'" % key)
		elif not value is float and not value is int:
			errors.append("env.visitor_frame.%s must be a number" % key)
		elif value > 1.0 or value < (.45 if key == "arm" else 0.0):
			errors.append("env.visitor_frame.%s is outside its range" % key)
	return errors
