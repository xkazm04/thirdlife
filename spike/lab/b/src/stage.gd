class_name Stage
extends RefCounted
## Light rig, sky, environment, ink post quad and painterly grade layer. All parameters come from Style (data).

const SKY: Shader = preload("res://shaders/sky.gdshader")
const INK: Shader = preload("res://shaders/ink_post.gdshader")
const GRADE: Shader = preload("res://shaders/grade.gdshader")


static func build(parent: Node3D, with_ink: bool = true, with_grade: bool = true) -> Dictionary:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	parent.add_child(sun)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = SKY
	Style.push("sky", sm)
	sky.sky_material = sm
	env.sky = sky
	Style.apply_world(env, sun)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	we.name = "WorldEnvironment"
	parent.add_child(we)
	var out: Dictionary = {"sun": sun, "env": env, "sky_mat": sm}
	if with_ink:
		var post: MeshInstance3D = MeshInstance3D.new()
		post.name = "InkPost"
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(2, 2)
		post.mesh = q
		var pm: ShaderMaterial = ShaderMaterial.new()
		pm.shader = INK
		pm.render_priority = -100
		Style.push("ink", pm)
		post.material_override = pm
		post.extra_cull_margin = 16384.0
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(post)
		out["ink"] = post
		out["ink_mat"] = pm
	if with_grade:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 1
		layer.name = "Grade"
		var rect: ColorRect = ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gm: ShaderMaterial = ShaderMaterial.new()
		gm.shader = GRADE
		Style.push("grade", gm)
		rect.material = gm
		layer.add_child(rect)
		parent.add_child(layer)
		out["grade"] = layer
	return out
