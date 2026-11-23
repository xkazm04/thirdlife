class_name TLStyleFelt
extends RefCounted
## Felt and clay for a figure (K7, hockey port, 23-24 Nov 2026): thirdjam's skater materials on its clay look tier, as a
## new entry beside the palette material. No existing shader or style file is touched (shaders/body_felt.gdshader is
## new). A figure ported from another engine keeps that game's own surface: its felt (mottle, fibre, sheen), its clay
## (thumb dents), the number and the crest on its jersey, lit by the hall's own rig by the numbers when one is given
## (`set_rig`, the shape of TLStyleArena.set_rig) and by the installed style's sun and sky when none is.
## The material draws no ink: it is drawn after the style's ink pass (thirdjam's clay tier has no outline).
##
##   TLStyleFelt.set_rig(lights, exposure)      # optional: the hall's spot lights, before or after the materials are made
##   TLStyleFelt.material({"team_colour": Color(0.02, 0.1, 0.55), "felt_mix": 1.0, "number_ones": 7.0, ...})
##
## Keys are the uniforms of body_felt.gdshader (thirdjam's material parameters in snake case; its header names each).
## Colours are linear `Color`s (the numbers of the source material, not "#rrggbb"). `clay_normal` is "thumb" or "dent"
## (thirdjam's two clay normal maps); `number_atlas`, `crest0`, `crest1` are textures the caller owns (`texture()` loads
## one with mipmaps). Unknown keys are errors (the call returns null). Headless: one shared material with no shader
## (it answers set_shader_parameter), nothing else.

const SHADER_PATH: String = "res://style/shaders/body_felt.gdshader"
const DIR: String = "res://style/felt/"
## The style's ink pass is drawn at render priority -100 (TLStyle.install); this is after it and before everything else.
const RENDER_PRIORITY: int = -90
const MAX_LIGHTS: int = 24
const KEYS: Dictionary = {"team_colour": TYPE_COLOR, "rim_colour": TYPE_COLOR, "sheen_tint": TYPE_COLOR, "rim_power": TYPE_FLOAT,
	"rim_strength": TYPE_FLOAT, "emissive": TYPE_FLOAT, "vcol_mix": TYPE_FLOAT, "vcol_jitter": TYPE_FLOAT, "felt_mix": TYPE_FLOAT,
	"felt_tile": TYPE_FLOAT, "felt_bump": TYPE_FLOAT, "clay_bump_scale": TYPE_FLOAT, "clay_tile_mul": TYPE_FLOAT,
	"felt_mottle_tile": TYPE_FLOAT, "felt_mottle": TYPE_FLOAT, "felt_darken": TYPE_FLOAT, "hem_z0": TYPE_FLOAT, "hem_z1": TYPE_FLOAT,
	"hem_k": TYPE_FLOAT, "sheen_white": TYPE_FLOAT, "deco_glow": TYPE_FLOAT, "number_tens": TYPE_FLOAT, "number_ones": TYPE_FLOAT,
	"number_on": TYPE_FLOAT, "number_centre": TYPE_VECTOR2, "number_cell": TYPE_VECTOR2, "number_pitch": TYPE_FLOAT,
	"number_back_mask": TYPE_FLOAT, "crest_team": TYPE_FLOAT, "crest_yzs": TYPE_VECTOR3, "crest_on": TYPE_FLOAT,
	"number_atlas": TYPE_OBJECT, "crest0": TYPE_OBJECT, "crest1": TYPE_OBJECT, "clay_normal": TYPE_STRING}
## thirdjam's look collection on the clay tier (/JamAssets/Look/MPC_Look as the running game holds it, read by lane K6's
## export: engine/cores/rink/arena/arena.json "collections"): Clay 1, ClayBump 2.0, FeltRim 1.4, ClayFill 0.15,
## ClayTile 25, ClayRough 0.85, LookTint (1, 0.94, 0.84).
const LOOK: Dictionary = {"look_tint": Vector3(1.0, 0.94, 0.84), "clay_tile": 25.0, "clay_bump": 2.0, "clay_fill": 0.15, "felt_rim": 1.4}
const CLAY_NORMALS: Dictionary = {"thumb": "T_Clay_Thumb_N", "dent": "T_Clay_Dent_N"}

static var _shader: Shader
static var _stub: ShaderMaterial
static var _tex: Dictionary = {}          # path -> Texture2D (with mipmaps)
static var _made: Array = []              # WeakRef of every material made (the rig is pushed to them)
static var _rig: Dictionary = {}          # rig_* uniforms, empty = none (the style's sun stands in)


## One material of a figure's slot. `params`: KEYS (absent = the shader's default, which is the source master's).
static func material(params: Dictionary = {}) -> ShaderMaterial:
	for k: String in params:
		if not KEYS.has(k):
			push_error("TLStyleFelt.material: unknown key '%s'" % k)
			return null
	if TLStyle.headless():
		if _stub == null:
			_stub = ShaderMaterial.new()
		return _stub
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader
	m.render_priority = RENDER_PRIORITY
	for k: String in LOOK:
		m.set_shader_parameter(k, LOOK[k])
	m.set_shader_parameter(&"felt_fibre", texture(DIR + "T_Felt_Fibre.png"))
	m.set_shader_parameter(&"clay_normal", texture(DIR + "%s.png" % CLAY_NORMALS["thumb"]))
	set_params(m, params)
	if not _rig.is_empty():
		_push_rig(m)
	_made.append(weakref(m))
	return m


## Sets `params` (KEYS) on a material made here: a number, a team colour, a crest that change after the figure was built.
static func set_params(m: ShaderMaterial, params: Dictionary) -> bool:
	if m == null or TLStyle.headless():
		return m != null
	for k: String in params:
		if not KEYS.has(k):
			push_error("TLStyleFelt.set_params: unknown key '%s'" % k)
			return false
		var v: Variant = params[k]
		match k:
			"clay_normal":
				if not CLAY_NORMALS.has(String(v)):
					push_error("TLStyleFelt: clay_normal '%s' (known: thumb, dent)" % String(v))
					return false
				m.set_shader_parameter(&"clay_normal", texture(DIR + "%s.png" % CLAY_NORMALS[String(v)]))
			_:
				if v is Color:
					m.set_shader_parameter(k, Vector3((v as Color).r, (v as Color).g, (v as Color).b))
				else:
					m.set_shader_parameter(k, v)
	return true


## The hall's light rig: `lights` = [{pos, dir, colour (linear Color), candela, radius_m, inner_deg, outer_deg}, ...] in
## pack space (the shape TLStyleArena.set_rig takes), `exposure` = what a luminance is multiplied by before the film
## curve, `gain` and `gain_shadows` = the rig's colour grade before the curve (its post volume's ColorGain and
## ColorGainShadows), `sky` = the rig's sky light on a face that looks up (lux / PI, linear). An empty list gives the
## style's sun back.
static func set_rig(lights: Array, exposure: float, gain: Color = Color(1, 1, 1), gain_shadows: Color = Color(1, 1, 1),
		sky: Color = Color(0, 0, 0)) -> bool:
	if lights.size() > MAX_LIGHTS:
		push_error("TLStyleFelt.set_rig: %d lights, at most %d" % [lights.size(), MAX_LIGHTS])
		return false
	var pos: Array = []
	var dir: Array = []
	var col: Array = []
	for l: Dictionary in lights:
		for k: String in ["pos", "dir", "colour", "candela", "radius_m", "inner_deg", "outer_deg"]:
			if not l.has(k):
				push_error("TLStyleFelt.set_rig: a light without '%s'" % k)
				return false
		var p: Vector3 = l["pos"]
		var d: Vector3 = (l["dir"] as Vector3).normalized()
		var c: Color = l["colour"]
		var cd: float = float(l["candela"])
		pos.append(Vector4(p.x, p.y, p.z, float(l["radius_m"])))
		dir.append(Vector4(d.x, d.y, d.z, cos(deg_to_rad(float(l["outer_deg"])))))
		col.append(Vector4(c.r * cd, c.g * cd, c.b * cd, cos(deg_to_rad(float(l["inner_deg"])))))
	var n: int = pos.size()
	while pos.size() < MAX_LIGHTS:
		pos.append(Vector4(0, 0, 0, 0))
		dir.append(Vector4(0, -1, 0, 0))
		col.append(Vector4(0, 0, 0, 1))
	_rig = {"rig_n": n, "rig_pos": pos, "rig_dir": dir, "rig_col": col, "rig_exposure": exposure,
		"rig_gain": Vector3(gain.r, gain.g, gain.b), "rig_gain_shadows": Vector3(gain_shadows.r, gain_shadows.g, gain_shadows.b),
		"sky_fill": Vector3(sky.r, sky.g, sky.b)}
	for m: ShaderMaterial in _live():
		_push_rig(m)
	return true


## How many lights the materials are lit by (0 = the installed style's sun).
static func rig_size() -> int:
	return int(_rig.get("rig_n", 0))


## A texture with mipmaps from a PNG of the project (the import keeps none); null headless or when it cannot be read.
static func texture(path: String) -> Texture2D:
	if TLStyle.headless():
		return null
	if not _tex.has(path):
		var img: Image = null
		if ResourceLoader.exists(path):
			var t: Texture2D = load(path) as Texture2D
			img = t.get_image() if t != null else null
		if img == null:
			img = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			push_error("TLStyleFelt.texture: cannot read " + path)
			_tex[path] = null
		else:
			if img.is_compressed():
				img.decompress()
			img.generate_mipmaps()
			_tex[path] = ImageTexture.create_from_image(img)
	return _tex[path]


static func _push_rig(m: ShaderMaterial) -> void:
	for k: String in _rig:
		m.set_shader_parameter(k, _rig[k])


static func _live() -> Array:
	var out: Array = []
	var keep: Array = []
	for w: WeakRef in _made:
		var m: ShaderMaterial = w.get_ref() as ShaderMaterial
		if m != null:
			out.append(m)
			keep.append(w)
	_made = keep
	return out
