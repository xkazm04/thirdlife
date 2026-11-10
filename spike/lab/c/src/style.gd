class_name Style
extends RefCounted
## Loads data/style.json and turns it into: palette textures, voxel materials, environment, sun.
## Everything that defines the look comes from the JSON; this class is the only reader.

const RAMP_N := 5

var d: Dictionary = {}
var mat_names: Array = []
var pal_tex: ImageTexture
var props_tex: ImageTexture
var sh_opaque: Shader = load("res://shaders/voxel.gdshader")
var sh_trans: Shader = load("res://shaders/voxel_trans.gdshader")
var sh_holo: Shader = load("res://shaders/holo.gdshader")
var _cache: Dictionary = {}


func load_file(path: String) -> void:
	d = JSON.parse_string(FileAccess.get_file_as_string(path))
	var mj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/materials.json"))
	mat_names = []
	for m: Dictionary in mj["materials"]:
		mat_names.append(m["name"])
	_build_palette()


func _build_palette() -> void:
	var n: int = mat_names.size()
	var pal := Image.create(RAMP_N, n, false, Image.FORMAT_RGBAF)
	var pr := Image.create(1, n, false, Image.FORMAT_RGBAF)
	var mats: Dictionary = d["materials"]
	for i in n:
		var m: Dictionary = mats.get(mat_names[i], {})
		var ramp: Array = m.get("ramp", ["#ff00ff"])
		for k in RAMP_N:
			var c := Color.html(ramp[k % ramp.size()])
			pal.set_pixel(k, i, c.srgb_to_linear())
		pr.set_pixel(0, i, Color(m.get("rough", 0.9), m.get("metal", 0.0), float(m.get("emit", 0.0)) / 8.0, m.get("alpha", 1.0)))
	pal_tex = ImageTexture.create_from_image(pal)
	props_tex = ImageTexture.create_from_image(pr)
	_cache.clear()


func voxel_material(vs: float, trans: bool = false, uniq: bool = false) -> ShaderMaterial:
	var key := "%s_%s" % [snappedf(vs, 0.0001), trans]
	if not uniq and _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = sh_trans if trans else sh_opaque
	m.set_shader_parameter(&"pal", pal_tex)
	m.set_shader_parameter(&"props", props_tex)
	m.set_shader_parameter(&"vs", vs)
	var v: Dictionary = d["voxel"]
	m.set_shader_parameter(&"edge_amt", v["edge"])
	m.set_shader_parameter(&"tex_amt", v["tex"])
	m.set_shader_parameter(&"ao_strength", v["ao_strength"])
	m.set_shader_parameter(&"bevel", v["bevel"])
	m.set_shader_parameter(&"ramp_n", float(RAMP_N))
	if not uniq:
		_cache[key] = m
	return m


func holo_material(vs: float, cell_mult: float = 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh_holo
	var h: Dictionary = d["holo"]
	var c := Color.html(h["color"])
	m.set_shader_parameter(&"holo_col", Vector3(c.r, c.g, c.b))
	m.set_shader_parameter(&"edge_gain", h["edge"])
	m.set_shader_parameter(&"fill", h["fill"])
	m.set_shader_parameter(&"scan", h["scan"])
	m.set_shader_parameter(&"vs", vs)
	m.set_shader_parameter(&"cell_mult", cell_mult)
	return m


func color_of(mat: String, k: int = 2) -> Color:
	var ramp: Array = d["materials"][mat]["ramp"]
	return Color.html(ramp[k % ramp.size()])


func apply_light(sun: DirectionalLight3D) -> void:
	var s: Dictionary = d["sun"]
	sun.light_color = Color.html(s["color"])
	sun.light_energy = s["energy"]
	var from: Array = s["dir_from"]
	var dir_from := Vector3(from[0], from[1], from[2]).normalized()
	sun.position = dir_from * 100.0
	sun.look_at_from_position(dir_from * 100.0, Vector3.ZERO, Vector3.UP)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = s["shadow_max"]
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = s["shadow_blur"]
	sun.shadow_normal_bias = 1.4
	sun.shadow_bias = 0.06
	sun.light_angular_distance = 1.2
	sun.light_energy = s["energy"]
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.2
	sun.directional_shadow_split_3 = 0.5


func make_environment(gi: String = "sdfgi", vol: bool = true, ssao: bool = true) -> Environment:
	var e := Environment.new()
	var s: Dictionary = d["sky"]
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color.html(s["top"])
	sm.sky_horizon_color = Color.html(s["horizon"])
	sm.ground_horizon_color = Color.html(s["horizon"]).darkened(0.25)
	sm.ground_bottom_color = Color.html(s["ground"])
	sm.sky_curve = s["curve"]
	sm.sun_angle_max = s["sun_angle_max"]
	sm.sky_energy_multiplier = s["energy"]
	var sky := Sky.new()
	sky.sky_material = sm
	e.sky = sky
	e.background_mode = Environment.BG_SKY
	var a: Dictionary = d["ambient"]
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = a["energy"]
	e.ambient_light_sky_contribution = a["sky_contribution"]
	e.ambient_light_color = Color.html(a["color"])
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var p: Dictionary = d["post"]
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = p["exposure"]
	e.tonemap_white = p["white"]
	e.glow_enabled = p["glow"] > 0.0
	e.glow_intensity = p["glow"]
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = p["glow_threshold"]
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.adjustment_enabled = true
	e.adjustment_saturation = p["saturation"]
	e.adjustment_contrast = p["contrast"]
	if ssao:
		e.ssao_enabled = true
		e.ssao_radius = p["ssao_radius"]
		e.ssao_intensity = p["ssao_intensity"]
		e.ssao_power = 1.6
		e.ssao_detail = 0.6
		e.ssao_light_affect = 0.25
	if p.get("ssil", 0.0) > 0.0 or gi == "ssil":
		e.ssil_enabled = true
		e.ssil_intensity = maxf(p.get("ssil", 0.0), 1.0)
		e.ssil_radius = 5.0
	var f: Dictionary = d["fog"]
	e.fog_enabled = true
	e.fog_light_color = Color.html(f["color"])
	e.fog_density = f["density"]
	e.fog_sun_scatter = f["sun_scatter"]
	e.fog_aerial_perspective = f["aerial"]
	e.fog_sky_affect = 0.6
	if vol:
		e.volumetric_fog_enabled = true
		e.volumetric_fog_density = f["vol_density"]
		e.volumetric_fog_albedo = Color.html(f["vol_albedo"])
		e.volumetric_fog_anisotropy = f["vol_anisotropy"]
		e.volumetric_fog_length = f["vol_length"]
		e.volumetric_fog_detail_spread = 2.0
		e.volumetric_fog_gi_inject = 0.5
		e.volumetric_fog_temporal_reprojection_enabled = true
	if gi == "sdfgi":
		e.sdfgi_enabled = true
		e.sdfgi_use_occlusion = true
		e.sdfgi_cascades = 5
		e.sdfgi_min_cell_size = 0.5
		e.sdfgi_bounce_feedback = 0.5
		e.sdfgi_energy = p["sdfgi_energy"]
		e.sdfgi_read_sky_light = true
		e.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	return e
