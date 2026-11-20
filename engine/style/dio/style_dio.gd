extends RefCounted
## Diorama night (20 Nov 2026), surfaces: what TLStyle needs for a style file that names a material model, kept
## beside tl_style.gd (whose size is budgeted) and out of the indexed API (a pack never calls this). A style file without these keys never reaches the code paths below
## that differ from today: it gets the shader files as they are and the same lookup texture.
##
##   toon.model   absent = today's banded toon (toon.gdshader as it is). "diorama" = the same file compiled with
##                TL_DIORAMA defined: clay, felt, painted wood and plastic (smooth light, marks anchored in the
##                object, gloss, fuzz, chips, soft box edges).
##   water.model  absent = water.gdshader. "resin" = water_resin.gdshader; with `water.shore` > 0 compiled with
##                TL_SHORE (the resin reads the depth of its bed: shallows, a meniscus at the bank).
##   mat.<key>    gloss (0 matte .. 1 wet), fuzz (felt sheen), chip (worn paint); classes clay and felt.
##   detail       bump, bump_near, bump_far (the marks as relief, and where they fade), chip, bevel (m: the soft
##                edge of a box face, 0 = cut), round (0..1: a blob or a cylinder side lit as the round thing it is).
##   toon         gloss (of a key that names none), sheen, sky_refl, spec, chip_color, wax (warm light along the
##                turn from sun to shade).

const SHADER_DIR: String = "res://style/shaders/"


## `file`.gdshader, or compiled with `#define <define>` in front when `define` is not empty. `cache` is TLStyle's.
static func variant(file: String, define: String, cache: Dictionary) -> Shader:
	var key: String = file if define.is_empty() else file + "#" + define
	if not cache.has(key):
		var base: Shader = load(SHADER_DIR + file + ".gdshader")
		if define.is_empty():
			cache[key] = base
		else:
			var sh: Shader = Shader.new()
			sh.code = "#define %s\n%s" % [define, base.code]
			cache[key] = sh
	return cache[key]


static func model(data: Dictionary) -> String:
	return String((data.get("toon", {}) as Dictionary).get("model", ""))


## The toon shader of a style: the file itself, or its variant for the style's material model.
static func toon(data: Dictionary, cache: Dictionary) -> Shader:
	var m: String = model(data)
	return variant("toon", "" if m.is_empty() else "TL_" + m.to_upper(), cache)


## The water shader of a style.
static func water(data: Dictionary, cache: Dictionary) -> Shader:
	var w: Dictionary = data.get("water", {})
	var m: String = String(w.get("model", ""))
	if m.is_empty():
		return variant("water", "", cache)
	return variant("water_" + m, "TL_SHORE" if float(w.get("shore", 0.0)) > 0.0 else "", cache)


## Diorama day: a flat-colour material is worn by primitives the kernel makes for bodies (BoxMesh, SphereMesh). Under
## a material model they say so, and the shader gives them the part's space and the soft edges a TLMesh part has.
## A style without a model sets nothing: its materials are as they were.
static func prim(m: ShaderMaterial, data: Dictionary) -> void:
	if not model(data).is_empty():
		m.set_shader_parameter(&"tl_prim", true)


## The shader globals of the diorama model (read only by the TL_DIORAMA variant; today's shader never declares them).
static func globals(data: Dictionary) -> Dictionary:
	var t: Dictionary = data.get("toon", {})
	var dt: Dictionary = data.get("detail", {})
	var chip: Color = Color(String(t.get("chip_color", "#e8dcc8"))).srgb_to_linear()
	var grass: Color = Color(String((data.get("palette", {}) as Dictionary).get("grass", "#86b944"))).srgb_to_linear()
	return {
		"g_dio": Vector4(float(dt.get("bump", 1.0)), float(dt.get("bump_near", 14.0)), float(dt.get("bump_far", 60.0)), float(dt.get("chip", 1.0))),
		"g_dio2": Vector4(float(t.get("gloss", 0.12)), float(t.get("sheen", 1.0)), float(t.get("sky_refl", 0.5)), float(t.get("spec", 1.0))),
		"g_dio3": Vector4(chip.r, chip.g, chip.b, float(dt.get("bevel", 0.0))),
		"g_dio5": Vector4(float(t.get("wax", 0.0)), 1.0 if (float(dt.get("pebbles", 0.0)) > 0.0 and float(dt.get("nature", 0.0)) > 0.0) else 0.0, 0.0, 0.0),
		"g_dio4": Vector4(grass.r, grass.g, grass.b, clampf(float(dt.get("round", 0.0)), 0.0, 1.0)),
		"g_dio6": Vector4(textures(data), float(dt.get("tex_felt_m", 2.4)), float(dt.get("tex_clay_m", 2.0)), float(dt.get("tex_relief", 0.8))),
	}


const TEX_DIR: String = "res://style/dio/tex/"
const TEX_NAMES: PackedStringArray = ["felt", "clay", "wood", "cast", "soil", "wool"]
static var _tex: Dictionary = {}     # name -> Texture2D, kept alive here (the renderer holds only the RID)


## Diorama day: the material textures (make_tex.py, bake_tex.gd) as the global samplers g_dio_<name> of the diorama
## model. Returns `detail.tex` (how much of them the shader uses), or 0 when the style names no model or a texture is
## missing: the shader then draws last night's marks. A style without a material model never gets here.
static func textures(data: Dictionary) -> float:
	if model(data).is_empty():
		return 0.0
	var whole: bool = true
	for n: String in TEX_NAMES:
		if _tex.has(n):
			whole = whole and not (_tex[n] is ImageTexture)
			continue
		var path: String = TEX_DIR + n + ".res"
		var t: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
		if t == null:
			push_warning("style: %s is missing; the diorama model draws its marks without textures" % path)
			var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
			img.fill(Color(0.5, 0.5, 0.5, 0.5))
			t = ImageTexture.create_from_image(img)
			whole = false
		_tex[n] = t
		RenderingServer.global_shader_parameter_add("g_dio_" + n, RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, t.get_rid())
	return clampf(float((data.get("detail", {}) as Dictionary).get("tex", 0.0)), 0.0, 1.5) if whole else 0.0


## Combine of 20 Nov (moved from tl_style.gd to keep it inside its size budget; behaviour unchanged).
## N1. Far blur for every camera that has no attributes of its own: `env.dof_far` = metres where it starts (0 = off).
static func far_dof(e0: Dictionary) -> CameraAttributesPractical:
	if float(e0.get("dof_far", 0.0)) <= 0.0:
		return null
	var ca: CameraAttributesPractical = CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_distance = float(e0["dof_far"])
	ca.dof_blur_far_transition = float(e0.get("dof_far_transition", 150.0))
	ca.dof_blur_amount = clampf(float(e0.get("dof_amount", 0.05)), 0.0, 0.3)
	return ca


static var _shadow_filter_set: bool = false


class HorizonCompositor extends Compositor:
	func _init() -> void:
		compositor_effects = [preload("res://style/dio/horizon_resolve.gd").new()]


static func horizon_aa(we: WorldEnvironment, env: Dictionary) -> void:
	# An explicit AA comparison gets exactly the requested hardware/temporal modes.
	var on: bool = env.get("horizon_aa", false) and OS.get_environment("TL_EXE_AA").is_empty()
	if on and RenderingServer.get_current_rendering_method() == "forward_plus":
		if we.compositor == null:
			we.compositor = HorizonCompositor.new()
	elif we.compositor is HorizonCompositor:
		we.compositor = null


## The felt is viewed at grazing angles. Save the caller's sampling level on each
## viewport so a live style change also restores custom camera or preview settings.
static func apply_anisotropy(vp: Viewport, env: Dictionary) -> void:
	const SAVED := &"_tl_pre_diorama_anisotropy"
	if env.get("anisotropy_16x", false):
		if not vp.has_meta(SAVED):
			vp.set_meta(SAVED, vp.anisotropic_filtering_level)
		vp.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
	elif vp.has_meta(SAVED):
		vp.anisotropic_filtering_level = vp.get_meta(SAVED)
		vp.remove_meta(SAVED)


## The PCSS filter is renderer-wide. A live return to classic restores the project's sampling quality. A fresh
## classic run never changes the filter (`sun.filter_quality` absent).
static func shadow_filter(s: Dictionary) -> void:
	if s.has("filter_quality") or _shadow_filter_set:
		var default_quality: int = ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")
		RenderingServer.directional_soft_shadow_filter_set_quality(clampi(int(s.get("filter_quality", default_quality)), 0, RenderingServer.SHADOW_QUALITY_SOFT_ULTRA))
		_shadow_filter_set = s.has("filter_quality")
