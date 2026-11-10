class_name TLStyle
extends RefCounted
## The look as data (kernelApi 0.1, contracts/KIT-RIG-STYLE.md). All state is static: no autoload, no project setting.
##   TLStyle.load_style(path)   load + validate a style file (golden: res://style/style.json, overcast: style_overcast.json)
##   TLStyle.install(host)      sky, sun, environment, ink post-process and grade under `host` (idempotent; re-applies after a reload)
##   TLStyle.material(key)      THE palette material for every toon palette key, or a special one (glass, water, holo, fx_add, fx_mix)
##   TLStyle.palette()          palette keys
##   TLStyle.set_headless(on)   headless: no shader, no texture, no viewport work; every function still succeeds
## A style file is loaded lazily on first use, so `TLKit.build(...)` works without any set-up call.
## Ported from spike/lab/b/src/style.gd + stage.gd (lane B, accepted look).

const SHADER_DIR: String = "res://style/shaders/"
const DEFAULT_PATH: String = "res://style/style.json"
const SPECIAL: PackedStringArray = ["glass", "water", "holo", "fx_add", "fx_mix"]
const RIG_NODE: String = "TLStyleRig"
## material classes of the drawn surface language (toon.gdshader surface_detail)
const CLASSES: Dictionary = {"none": 0, "wood": 1, "concrete": 2, "steel": 3, "tarmac": 4, "ground": 5, "rock": 6, "roof": 7, "fabric": 8, "masonry": 9}
const SECTIONS: PackedStringArray = ["name", "sun", "toon", "env", "fog", "sky", "ink", "grade", "holo", "water", "palette", "mat", "detail", "lights", "fx"]
const REQUIRED: PackedStringArray = ["sun", "toon", "env", "fog", "sky", "ink", "grade", "palette", "mat"]
const MAT_KEYS: PackedStringArray = ["class", "dscale", "dk", "emit", "metal", "mottle", "no_hatch", "ice", "dissolve", "sway", "shader", "base_a", "fres_a"]
## Numeric parameters are clamped to ranges that were looked at: a bad style file cannot break the look.
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

static var data: Dictionary = {}
static var style_name: String = ""
static var style_path: String = ""
static var _loaded: bool = false
static var _headless_set: bool = false
static var _headless: bool = false
static var _index: Dictionary = {}      # palette key -> column in the palette lookup texture (0 = unknown key, magenta)
static var _lut: ImageTexture
static var _pal_mat: ShaderMaterial     # THE material: every toon surface uses it
static var _mats: Dictionary = {}       # special materials by key
static var _ghost: Dictionary = {}      # global shader parameters this process has added
static var _shaders: Dictionary = {}
static var _stub: ShaderMaterial        # headless: a ShaderMaterial with no shader (answers set_shader_parameter, costs nothing)
static var _flat: Dictionary = {}       # WP5: flat-colour toon materials by "rrggbb|metal" (flat_material)


static func headless() -> bool:
	if not _headless_set:
		_headless = DisplayServer.get_name() == "headless"
		_headless_set = true
	return _headless


## Headless mode is detected from the display server; this overrides it (for a windowed run that wants no look).
static func set_headless(on: bool) -> void:
	_headless = on
	_headless_set = true


static func ensure() -> void:
	if not _loaded:
		load_style(DEFAULT_PATH)


## Loads and validates a style file. Returns readable messages: hard errors (the file is then NOT applied and the
## previous style stays), and lines starting with "clamped: " for values that were out of range and were clamped.
static func load_style(path: String = "res://style/style.json") -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	_loaded = true   # even when it fails: never retry in a loop
	if not FileAccess.file_exists(path):
		out.append("style file not found: " + path)
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		out.append("style file is not a JSON object: " + path)
		return out
	var d: Dictionary = parsed
	out.append_array(check(d))
	for line: String in out:
		if not line.begins_with("clamped: "):
			return out
	data = d
	style_path = path
	style_name = String(d.get("name", path.get_file().get_basename()))
	_index.clear()
	var keys: Array = (data["palette"] as Dictionary).keys()
	for i: int in keys.size():
		_index[String(keys[i])] = i + 1
	if not headless():
		_register_globals()
		_build_lut()
		if _pal_mat != null:
			_pal_mat.set_shader_parameter(&"pal_lut", _lut)
		for key: String in _mats:
			_fill_special(key, _mats[key])
	return out


## Validates (and clamps in place) a parsed style dictionary. Unknown sections and unknown `mat` keys are errors.
static func check(d: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: String in d:
		if k.begins_with("_"):
			continue
		if not SECTIONS.has(k):
			out.append("unknown section '%s' (allowed: %s)" % [k, ", ".join(SECTIONS)])
	for k: String in REQUIRED:
		if not d.has(k) or not (d[k] is Dictionary):
			out.append("missing section '%s'" % k)
	if out.size() > 0:
		return out
	var pal: Dictionary = d["palette"]
	for k: String in pal:
		if not (pal[k] is String) or not Color.html_is_valid(String(pal[k])):
			out.append("palette.%s = %s is not a colour like #rrggbb" % [k, str(pal[k])])
	if not pal.has("white"):
		out.append("palette.white is required")
	for k: String in (d["mat"] as Dictionary):
		if not pal.has(k):
			out.append("mat.%s has no palette colour of that name" % k)
		var m: Variant = d["mat"][k]
		if not (m is Dictionary):
			out.append("mat.%s must be an object" % k)
			continue
		for mk: String in (m as Dictionary):
			if not MAT_KEYS.has(mk):
				out.append("mat.%s.%s is not a material key (allowed: %s)" % [k, mk, ", ".join(MAT_KEYS)])
		if (m as Dictionary).has("class") and not CLASSES.has(String(m["class"])):
			out.append("mat.%s.class = '%s' is not one of %s" % [k, m["class"], ", ".join(CLASSES.keys())])
	for req: Array in [["sun", ["color", "energy", "elev", "azim", "shadow_max", "shadow_blur", "shadow_bias"]], ["toon", ["shade", "shade_k", "band_hi", "band_lo", "band_soft", "wrap", "amb_sky", "amb_ground", "amb_energy", "hatch", "hatch_px", "hatch_fade_near", "hatch_fade_far", "rim", "rim_k", "mottle"]],
			["env", ["tonemap", "exposure", "white", "glow", "glow_threshold", "glow_bloom"]], ["fog", ["color", "density", "sun_scatter", "height", "height_density", "aerial", "sky_affect"]]]:
		for k: String in req[1]:
			if not (d[req[0]] as Dictionary).has(k):
				out.append("%s.%s is required" % [req[0], k])
	for key: String in RANGES:
		var kv: PackedStringArray = key.split(".")
		if not d.has(kv[0]) or not (d[kv[0]] is Dictionary) or not (d[kv[0]] as Dictionary).has(kv[1]):
			continue
		var raw: Variant = d[kv[0]][kv[1]]
		if not (raw is float or raw is int):
			out.append("%s must be a number" % key)
			continue
		var v: float = float(raw)
		var c: float = clampf(v, float(RANGES[key][0]), float(RANGES[key][1]))
		if not is_equal_approx(v, c):
			out.append("clamped: %s = %s is outside %s, using %s" % [key, v, RANGES[key], c])
			d[kv[0]][kv[1]] = c
	return out


static func palette() -> PackedStringArray:
	ensure()
	return PackedStringArray((data.get("palette", {}) as Dictionary).keys())


static func has_key(key: String) -> bool:
	ensure()
	return (data.get("palette", {}) as Dictionary).has(key)


## Palette colour (sRGB) of a key; magenta for an unknown key.
static func color(key: String) -> Color:
	ensure()
	return Color(String((data.get("palette", {}) as Dictionary).get(key, "#ff00ff")))


## A number from a style section, with a default: TLStyle.num("lights", "mast", 0.0).
static func num(section: String, key: String, default: float = 0.0) -> float:
	ensure()
	return float((data.get(section, {}) as Dictionary).get(key, default))


static func index(key: String) -> int:
	ensure()
	return int(_index.get(key, 0))


static func is_toon(key: String) -> bool:
	ensure()
	if SPECIAL.has(key):
		return false
	return String(((data.get("mat", {}) as Dictionary).get(key, {}) as Dictionary).get("shader", "toon")) == "toon"


static func _shader(sname: String) -> Shader:
	if not _shaders.has(sname):
		_shaders[sname] = load(SHADER_DIR + sname + ".gdshader")
	return _shaders[sname]


## The material for a key. Every toon palette key returns the SAME ShaderMaterial (per-key values come from a lookup
## texture through a vertex channel written by TLMesh). `glass`, `water`, `holo`, `fx_add`, `fx_mix` are their own.
static func material(key: StringName) -> Material:
	ensure()
	if headless():
		if _stub == null:
			_stub = ShaderMaterial.new()
		return _stub
	var k: String = String(key)
	if is_toon(k):
		if _pal_mat == null:
			_pal_mat = ShaderMaterial.new()
			_pal_mat.shader = _shader("toon")
			_pal_mat.set_shader_parameter(&"pal_lut", _lut)
		return _pal_mat
	if not _mats.has(k):
		var m: ShaderMaterial = ShaderMaterial.new()
		_mats[k] = m
		_fill_special(k, m)
	return _mats[k]


## WP5. The toon look in one flat colour, for geometry TLMesh did not build (a BoxMesh or SphereMesh the kernel makes
## for `TLBodies.make`, `TLBall.create`, a stand-in). Same bands, ambient, hatch and ink as the palette material; no
## drawn surface detail (a primitive mesh carries no part-local coordinates). `metal` 0..1 adds the toon highlight.
## It is the toon shader with a private one-column lookup texture, so no shader or palette change is needed.
## One material per colour (8 bits per channel) and metal value; headless: the stub.
static func flat_material(c: Color, metal: float = 0.0) -> Material:
	ensure()
	if headless():
		if _stub == null:
			_stub = ShaderMaterial.new()
		return _stub
	var key: String = "%s|%.2f" % [c.to_html(false), metal]
	if _flat.has(key):
		return _flat[key]
	var lin: Color = Color(c.to_html(false)).srgb_to_linear()
	var img: Image = Image.create(1, 4, false, Image.FORMAT_RGBAF)
	img.set_pixel(0, 0, Color(lin.r, lin.g, lin.b, 0.0))    # albedo, emit
	img.set_pixel(0, 1, Color(metal, -1.0, 0.0, 1.0))       # metal, mottle (style default), class none, dscale
	img.set_pixel(0, 2, Color(1.0, 0.0, 0.0, 0.0))          # dk, no_hatch, ice, dissolve
	img.set_pixel(0, 3, Color(0.0, 0.0, 0.0, 0.0))          # sway
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader("toon")
	m.set_shader_parameter(&"pal_lut", ImageTexture.create_from_image(img))
	_flat[key] = m
	return m


## WP5. A very large flat ground in a palette colour (default: style `env.ground_key`, else "grass"), top at `y`:
## the floor of a scene whose pack built no venue. Visual only (no body, so it never changes a simulation); it takes
## the sun's shadows. Headless: an empty node.
static func ground(y: float = 0.0, key: String = "", half: float = 2000.0) -> MeshInstance3D:
	ensure()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "TLStyleGround"
	mi.position.y = y
	if headless() or data.is_empty():
		return mi
	var k: String = key
	if not has_key(k):
		k = String((data.get("env", {}) as Dictionary).get("ground_key", "grass"))
	var code: float = 1.0 + 16.0 * float(index(k))    # face axis y, grain x, palette column (see TLMesh CUSTOM0)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	var v: PackedVector3Array = PackedVector3Array([Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(half, 0, half), Vector3(-half, 0, half)])
	var cu: PackedFloat32Array = PackedFloat32Array()
	for p: Vector3 in v:
		cu.append_array([p.x, p.y, p.z, code])
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arr[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_CUSTOM0] = cu
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	mesh.surface_set_material(0, material(StringName(k)))
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A private copy of a special material (for a part that needs its own uniforms, for example a hologram rib).
static func material_instance(key: StringName) -> Material:
	ensure()
	if headless():
		return ShaderMaterial.new()
	var m: ShaderMaterial = ShaderMaterial.new()
	_fill_special(String(key), m)
	return m


static func _fill_special(k: String, m: ShaderMaterial) -> void:
	var ov: Dictionary = (data.get("mat", {}) as Dictionary).get(k, {})
	var sh: String = String(ov.get("shader", k))
	if not SPECIAL.has(sh):
		sh = "glass"
	m.shader = _shader(sh)
	if sh == "water" or sh == "holo":
		push(sh, m)
	if sh == "glass" or sh == "water":
		m.set_shader_parameter(&"albedo", color(k))
	for p: String in ov:
		if p != "shader":
			m.set_shader_parameter(p, ov[p])


## Copies data[section] onto a material: key == shader uniform name; "#rrggbb" strings become Colors.
static func push(section: String, m: ShaderMaterial) -> void:
	ensure()
	if headless() or m == null:
		return
	var s: Dictionary = data.get(section, {})
	for k: String in s:
		var v: Variant = s[k]
		if v is String and String(v).begins_with("#"):
			m.set_shader_parameter(k, Color(String(v)))
		else:
			m.set_shader_parameter(k, v)


static func _lin(hex: Variant) -> Color:
	return Color(String(hex)).srgb_to_linear()


static func _v4(c: Color, a: float) -> Vector4:
	return Vector4(c.r, c.g, c.b, a)


static func _g(gname: String, v: Variant) -> void:
	if _ghost.has(gname):
		RenderingServer.global_shader_parameter_set(gname, v)
	else:
		RenderingServer.global_shader_parameter_add(gname, RenderingServer.GLOBAL_VAR_TYPE_VEC4, v)
		_ghost[gname] = true


static func _register_globals() -> void:
	var t: Dictionary = data["toon"]
	var sun: Dictionary = data["sun"]
	_g("g_sun", _v4(_lin(sun["color"]), float(sun["energy"])))
	_g("g_shade", _v4(_lin(t["shade"]), float(t["shade_k"])))
	_g("g_bands", Vector4(t["band_hi"], t["band_lo"], t["band_soft"], t["wrap"]))
	_g("g_amb_sky", _v4(_lin(t["amb_sky"]), float(t["amb_energy"])))
	_g("g_amb_gnd", _v4(_lin(t["amb_ground"]), 1.0))
	_g("g_hatch", Vector4(t["hatch"], t["hatch_px"], t["hatch_fade_near"], t["hatch_fade_far"]))
	_g("g_rim", _v4(_lin(t["rim"]), float(t["rim_k"])))
	_g("g_mottle", Vector4(t["mottle"], 0, 0, 0))
	_g("g_shade2", _v4(_lin(t.get("shade_ground", t["shade"])), float(t.get("shade_grad", 0.0))))
	_g("g_bounce", _v4(_lin(t.get("bounce", "#000000")), float(t.get("bounce_k", 0.0))))
	var sd: Vector3 = Basis.from_euler(Vector3(deg_to_rad(-float(sun["elev"])), deg_to_rad(180.0 - float(sun["azim"])), 0.0)).z
	_g("g_sun_dir", Vector4(sd.x, sd.y, sd.z, 0.0))
	var lt: Dictionary = data.get("lights", {})
	_g("g_pool", Vector4(float(lt.get("pool_outer", 0.05)), float(lt.get("pool_inner", 0.3)), float(lt.get("pool_soft", 0.03)), float(lt.get("pool_smooth", 0.35))))
	var fg: Dictionary = data["fog"]
	_g("g_haze", _v4(_lin(fg["color"]), float(fg["density"])))
	var dt: Dictionary = data.get("detail", {})
	_g("g_detail", Vector4(float(dt.get("k", 1.0)), float(dt.get("fade_near", 45.0)), float(dt.get("fade_far", 170.0)), float(dt.get("dark", 0.5))))
	_g("g_strata", Vector4(float(dt.get("strata", 0.0)), float(dt.get("strata_m", 3.0)), float(dt.get("strata_tone", 0.2)), float(dt.get("strata_crack", 0.5))))
	_g("g_detail2", Vector4(float(dt.get("macro", 0.0)), float(dt.get("macro_near", 20.0)), float(dt.get("macro_far", 90.0)), float(dt.get("tone_end", 400.0))))


## The palette lookup texture: one column per palette key, 4 rows of per-material values (see toon.gdshader).
static func _build_lut() -> void:
	var pal: Dictionary = data["palette"]
	var keys: Array = pal.keys()
	var img: Image = Image.create(keys.size() + 1, 4, false, Image.FORMAT_RGBAF)
	img.set_pixel(0, 0, Color(1, 0, 1, 0))
	img.set_pixel(0, 1, Color(0, -1, 0, 1))
	img.set_pixel(0, 2, Color(1, 0, 0, 0))
	img.set_pixel(0, 3, Color(0, 0, 0, 0))
	for i: int in keys.size():
		var key: String = keys[i]
		var ov: Dictionary = (data["mat"] as Dictionary).get(key, {})
		var c: Color = Color(String(pal[key])).srgb_to_linear()
		img.set_pixel(i + 1, 0, Color(c.r, c.g, c.b, float(ov.get("emit", 0.0))))
		img.set_pixel(i + 1, 1, Color(float(ov.get("metal", 0.0)), float(ov.get("mottle", -1.0)), float(CLASSES.get(String(ov.get("class", "none")), 0)), float(ov.get("dscale", 1.0))))
		img.set_pixel(i + 1, 2, Color(float(ov.get("dk", 1.0)), float(ov.get("no_hatch", 0.0)), float(ov.get("ice", 0.0)), float(ov.get("dissolve", 0.0))))
		img.set_pixel(i + 1, 3, Color(float(ov.get("sway", 0.0)), 0, 0, 0))
	if _lut == null or _lut.get_width() != img.get_width():
		_lut = ImageTexture.create_from_image(img)
	else:
		_lut.update(img)


## Adds (or, when already there, re-applies) the light rig under `host`: Sun, WorldEnvironment with the painted sky,
## the ink post-process quad and the grade layer. Options: {"ink": bool, "grade": bool} (both default true).
## Idempotent: one `TLStyleRig` child per host. After `load_style(other_file)`, call it again to swap the whole look.
static func install(host: Node, opt: Dictionary = {}) -> void:
	ensure()
	if host == null:
		return
	var rig: Node3D = host.get_node_or_null(RIG_NODE)
	if rig == null:
		rig = Node3D.new()
		rig.name = RIG_NODE
		host.add_child(rig)
	if headless() or data.is_empty():
		return
	var sun: DirectionalLight3D = rig.get_node_or_null("Sun")
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "Sun"
		rig.add_child(sun)
	var we: WorldEnvironment = rig.get_node_or_null("WorldEnvironment")
	if we == null:
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		var env0: Environment = Environment.new()
		env0.background_mode = Environment.BG_SKY
		var sky: Sky = Sky.new()
		var sm0: ShaderMaterial = ShaderMaterial.new()
		sm0.shader = _shader("sky")
		sky.sky_material = sm0
		env0.sky = sky
		we.environment = env0
		rig.add_child(we)
	push("sky", we.environment.sky.sky_material)
	_apply_world(we.environment, sun)
	var post: MeshInstance3D = rig.get_node_or_null("InkPost")
	if bool(opt.get("ink", true)):
		if post == null:
			post = MeshInstance3D.new()
			post.name = "InkPost"
			var q: QuadMesh = QuadMesh.new()
			q.size = Vector2(2, 2)
			post.mesh = q
			var pm: ShaderMaterial = ShaderMaterial.new()
			pm.shader = _shader("ink_post")
			pm.render_priority = -100
			post.material_override = pm
			post.extra_cull_margin = 16384.0
			post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rig.add_child(post)
		push("ink", post.material_override)
	elif post != null:
		post.queue_free()
	var layer: CanvasLayer = rig.get_node_or_null("Grade")
	if bool(opt.get("grade", true)):
		if layer == null:
			layer = CanvasLayer.new()
			layer.layer = 1
			layer.name = "Grade"
			var rect: ColorRect = ColorRect.new()
			rect.name = "Rect"
			rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var gm: ShaderMaterial = ShaderMaterial.new()
			gm.shader = _shader("grade")
			rect.material = gm
			layer.add_child(rect)
			rig.add_child(layer)
		push("grade", (layer.get_node("Rect") as ColorRect).material)
	elif layer != null:
		layer.queue_free()


static func _apply_world(env: Environment, sun: DirectionalLight3D) -> void:
	var s: Dictionary = data["sun"]
	sun.light_color = Color(String(s["color"]))
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-float(s["elev"]), 180.0 - float(s["azim"]), 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
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
	# WP5. Every style shader is `ambient_light_disabled` or `unshaded` and brings its own ambient, so the environment's
	# ambient only reaches materials the style did not make (a pack's own StandardMaterial3D). It was black, which left
	# those lit by nothing but a sun 11.5 degrees above the horizon: near-black. Give them the toon hemisphere's mean.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var tn: Dictionary = data["toon"]
	env.ambient_light_color = Color(String(tn["amb_sky"])).lerp(Color(String(tn["amb_ground"])), 0.5)
	env.ambient_light_energy = float(e.get("plain_ambient", 1.0))
	var f: Dictionary = data["fog"]
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(String(f["color"]))
	env.fog_density = float(f["density"])
	env.fog_sun_scatter = float(f["sun_scatter"])
	env.fog_aerial_perspective = float(f["aerial"])
	env.fog_sky_affect = float(f["sky_affect"])
	env.fog_height = float(f["height"])
	env.fog_height_density = float(f["height_density"])
	env.volumetric_fog_enabled = false
