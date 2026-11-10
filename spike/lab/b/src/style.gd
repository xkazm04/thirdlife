extends Node
## Style as data. Loads data/style.json (or data/style_<name>.json via --style=<name>) and exposes it:
##  - global shader parameters (g_*) that every toon/ink/water shader reads (lighting bands, ambient, haze),
##  - push(section, material): copies a JSON section onto a ShaderMaterial (key == uniform name),
##  - apply_world(env, sun): sun, fog, tonemap, glow,
##  - material(key): the cached toon ShaderMaterial for a palette key.
## Nothing else in the code base hard-codes a colour of the look.

const TOON: Shader = preload("res://shaders/toon.gdshader")
const GLASS: Shader = preload("res://shaders/glass.gdshader")
const WATER: Shader = preload("res://shaders/water.gdshader")

## material classes of the drawn surface language (toon.gdshader surface_detail)
const CLASSES: Dictionary = {"none": 0, "wood": 1, "concrete": 2, "steel": 3, "tarmac": 4, "ground": 5, "rock": 6, "roof": 7, "fabric": 8, "masonry": 9}
var data: Dictionary = {}
var style_name: String = "golden"
var _mats: Dictionary = {}
var _ghost: Dictionary = {}
var user_args: Dictionary = {}
var _index: Dictionary = {}      # palette key -> column in the palette lookup texture (0 = unknown key, magenta)
var _lut: ImageTexture
var _pal_mat: ShaderMaterial     # THE material: every toon surface in the world uses it
var single: bool = true          # --permat: one material and one surface per palette key again (measurement switch)


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		user_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var sn: String = String(user_args.get("style", ""))
	var path: String = "res://data/style.json" if sn == "" else "res://data/style_%s.json" % sn
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("style file missing: " + path)
		return
	data = JSON.parse_string(f.get_as_text())
	style_name = String(data.get("name", sn))
	single = not user_args.has("permat")
	_clamp_ranges()
	_register_globals()
	_build_lut()


## A bad style file must not be able to break the look: numeric parameters are clamped to ranges that were looked at.
const RANGES: Dictionary = {
	"fog.density": [0.0, 0.004], "fog.height_density": [0.0, 0.008], "fog.sun_scatter": [0.0, 0.6], "fog.aerial": [0.0, 1.0],
	"sun.elev": [4.0, 80.0], "sun.energy": [0.2, 2.0], "sun.shadow_max": [60.0, 500.0], "sun.shadow_blur": [0.0, 6.0],
	"toon.shade_k": [0.2, 0.85], "toon.amb_energy": [0.0, 1.2], "toon.hatch": [0.0, 0.35], "toon.band_soft": [0.005, 0.2], "toon.mottle": [0.0, 0.3], "toon.rim_k": [0.0, 1.0], "toon.shade_grad": [0.0, 1.0], "toon.bounce_k": [0.0, 1.2],
	"lights.window": [0.0, 6.0], "lights.mast": [0.0, 6.0], "lights.pool_outer": [0.005, 0.5], "lights.pool_inner": [0.02, 0.9], "lights.pool_soft": [0.002, 0.3],
	"ink.outer_px": [0.0, 4.0], "ink.inner_px": [0.0, 2.5], "ink.inner_alpha": [0.0, 1.0],
	"grade.sat": [0.6, 1.4], "grade.contrast": [0.85, 1.25], "grade.vignette": [0.0, 0.5], "grade.grain": [0.0, 0.05], "grade.paper": [0.0, 0.06], "grade.split": [0.0, 0.3],
	"lights.pool_smooth": [0.0, 1.0], "detail.strata": [0.0, 1.0], "detail.strata_m": [0.5, 12.0], "detail.strata_tone": [0.0, 0.6], "detail.strata_crack": [0.0, 1.0],
	"detail.k": [0.0, 1.6], "detail.macro": [0.0, 2.5], "detail.dark": [0.25, 0.9], "env.exposure": [0.6, 1.6], "env.glow": [0.0, 1.2],
}


func _clamp_ranges() -> void:
	for key: String in RANGES:
		var kv: PackedStringArray = key.split(".")
		if not data.has(kv[0]) or not (data[kv[0]] as Dictionary).has(kv[1]):
			continue
		var v: float = float(data[kv[0]][kv[1]])
		var c: float = clampf(v, float(RANGES[key][0]), float(RANGES[key][1]))
		if not is_equal_approx(v, c):
			print("[style] %s = %s is outside %s: clamped to %s" % [key, v, RANGES[key], c])
			data[kv[0]][kv[1]] = c


func col(hex: String) -> Color:
	return Color(hex)


func lin(hex: String) -> Color:
	return Color(hex).srgb_to_linear()


func _g(gname: String, v: Variant) -> void:
	if _ghost.has(gname):
		RenderingServer.global_shader_parameter_set(gname, v)
	else:
		RenderingServer.global_shader_parameter_add(gname, RenderingServer.GLOBAL_VAR_TYPE_VEC4, v)
		_ghost[gname] = true


func _v4(c: Color, a: float) -> Vector4:
	return Vector4(c.r, c.g, c.b, a)


func _register_globals() -> void:
	var t: Dictionary = data["toon"]
	var sun: Dictionary = data["sun"]
	_g("g_sun", _v4(lin(sun["color"]), float(sun["energy"])))
	_g("g_shade", _v4(lin(t["shade"]), float(t["shade_k"])))
	_g("g_bands", Vector4(t["band_hi"], t["band_lo"], t["band_soft"], t["wrap"]))
	_g("g_amb_sky", _v4(lin(t["amb_sky"]), float(t["amb_energy"])))
	_g("g_amb_gnd", _v4(lin(t["amb_ground"]), 1.0))
	_g("g_hatch", Vector4(t["hatch"], t["hatch_px"], t["hatch_fade_near"], t["hatch_fade_far"]))
	_g("g_rim", _v4(lin(t["rim"]), float(t["rim_k"])))
	_g("g_mottle", Vector4(t["mottle"], 0, 0, 0))
	_g("g_shade2", _v4(lin(String(t.get("shade_ground", t["shade"]))), float(t.get("shade_grad", 0.0))))
	_g("g_bounce", _v4(lin(String(t.get("bounce", "#000000"))), float(t.get("bounce_k", 0.0))))
	var sd: Vector3 = Basis.from_euler(Vector3(deg_to_rad(-float(sun["elev"])), deg_to_rad(180.0 - float(sun["azim"])), 0.0)).z
	_g("g_sun_dir", Vector4(sd.x, sd.y, sd.z, 0.0))
	var lt: Dictionary = data.get("lights", {})
	_g("g_pool", Vector4(float(lt.get("pool_outer", 0.05)), float(lt.get("pool_inner", 0.3)), float(lt.get("pool_soft", 0.03)), float(lt.get("pool_smooth", 0.35))))   # pass 4: w = share of smooth falloff
	var fg: Dictionary = data["fog"]
	_g("g_haze", _v4(lin(fg["color"]), float(fg["density"])))
	var dt: Dictionary = data.get("detail", {})
	_g("g_detail", Vector4(float(dt.get("k", 1.0)), float(dt.get("fade_near", 45.0)), float(dt.get("fade_far", 170.0)), float(dt.get("dark", 0.5))))
	_g("g_strata", Vector4(float(dt.get("strata", 0.0)), float(dt.get("strata_m", 3.0)), float(dt.get("strata_tone", 0.2)), float(dt.get("strata_crack", 0.5))))   # pass 4: drawn strata on cliff faces
	_g("g_detail2", Vector4(float(dt.get("macro", 0.0)), float(dt.get("macro_near", 20.0)), float(dt.get("macro_far", 90.0)), float(dt.get("tone_end", 400.0))))


## Copies data[section] onto the material: key == shader uniform name; "#rrggbb" strings become Colors.
func push(section: String, m: ShaderMaterial) -> void:
	var s: Dictionary = data.get(section, {})
	for k: String in s:
		var v: Variant = s[k]
		if v is String and String(v).begins_with("#"):
			m.set_shader_parameter(k, Color(v))
		else:
			m.set_shader_parameter(k, v)


## The palette lookup texture: one column per palette key, 4 rows of per-material values (see toon.gdshader).
func _build_lut() -> void:
	var pal: Dictionary = data["palette"]
	var keys: Array = pal.keys()
	var img: Image = Image.create(keys.size() + 1, 4, false, Image.FORMAT_RGBAF)
	img.set_pixel(0, 0, Color(1, 0, 1, 0))
	img.set_pixel(0, 1, Color(0, -1, 0, 1))
	img.set_pixel(0, 2, Color(1, 0, 0, 0))
	img.set_pixel(0, 3, Color(0, 0, 0, 0))
	for i: int in keys.size():
		var key: String = keys[i]
		_index[key] = i + 1
		var ov: Dictionary = data["mat"].get(key, {})
		var c: Color = Color(String(pal[key])).srgb_to_linear()
		img.set_pixel(i + 1, 0, Color(c.r, c.g, c.b, float(ov.get("emit", 0.0))))
		img.set_pixel(i + 1, 1, Color(float(ov.get("metal", 0.0)), float(ov.get("mottle", -1.0)), float(CLASSES.get(String(ov.get("class", "none")), 0)), float(ov.get("dscale", 1.0))))
		img.set_pixel(i + 1, 2, Color(float(ov.get("dk", 1.0)), float(ov.get("no_hatch", 0.0)), float(ov.get("ice", 0.0)), float(ov.get("dissolve", 0.0))))
		img.set_pixel(i + 1, 3, Color(float(ov.get("sway", 0.0)), 0, 0, 0))
	_lut = ImageTexture.create_from_image(img)


func index(key: String) -> int:
	return int(_index.get(key, 0))


func is_toon(key: String) -> bool:
	return String((data["mat"].get(key, {}) as Dictionary).get("shader", "toon")) == "toon"


func _new_toon() -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter(&"pal_lut", _lut)
	return m


## The material for a palette key. Every toon key returns the SAME ShaderMaterial (its values come from the lookup
## texture through the vertex channel); only glass and water are materials of their own.
func material(key: String) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	var m: ShaderMaterial
	if is_toon(key):
		if single:
			if _pal_mat == null:
				_pal_mat = _new_toon()
			m = _pal_mat
		else:
			m = _new_toon()
	else:
		var ov: Dictionary = data["mat"].get(key, {})
		var sh: String = String(ov.get("shader", "toon"))
		m = ShaderMaterial.new()
		m.shader = GLASS if sh == "glass" else WATER
		if sh == "water":
			push("water", m)
		m.set_shader_parameter(&"albedo", Color(String(data["palette"].get(key, "#ff00ff"))))
		for k: String in ov:
			if k != "shader":
				m.set_shader_parameter(k, ov[k])
	_mats[key] = m
	return m


func apply_world(env: Environment, sun: DirectionalLight3D) -> void:
	var s: Dictionary = data["sun"]
	sun.light_color = Color(s["color"])
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-float(s["elev"]), 180.0 - float(s["azim"]), 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if int(user_args.get("splits", s.get("splits", 4))) == 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = float(s["shadow_max"])
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = float(s["shadow_blur"])
	sun.shadow_bias = float(s["shadow_bias"])
	sun.shadow_normal_bias = 1.4
	sun.light_angular_distance = 0.0
	var e: Dictionary = data["env"]
	env.tonemap_mode = {"linear": Environment.TONE_MAPPER_LINEAR, "filmic": Environment.TONE_MAPPER_FILMIC,
		"aces": Environment.TONE_MAPPER_ACES, "reinhard": Environment.TONE_MAPPER_REINHARDT}.get(e["tonemap"], 0)
	env.tonemap_exposure = float(e["exposure"])
	env.tonemap_white = float(e["white"])
	env.glow_enabled = float(e["glow"]) > 0.0
	env.glow_intensity = float(e["glow"])
	env.glow_hdr_threshold = float(e["glow_threshold"])
	env.glow_bloom = float(e["glow_bloom"])
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	var f: Dictionary = data["fog"]
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(f["color"])
	env.fog_density = float(f["density"])
	env.fog_sun_scatter = float(f["sun_scatter"])
	env.fog_aerial_perspective = float(f["aerial"])
	env.fog_sky_affect = float(f["sky_affect"])
	env.fog_height = float(f["height"])
	env.fog_height_density = float(f["height_density"])
	env.volumetric_fog_enabled = false
