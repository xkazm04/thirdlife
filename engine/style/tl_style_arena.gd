class_name TLStyleArena
extends RefCounted
## Materials for an indoor hall and the light rig that lights them (K6, hockey port, 23-24 Nov 2026). New entries beside
## TLStyleHall; no existing shader or style file is touched. The hall of a game ported from another engine keeps that
## game's own surfaces: its wood, its crowd, its lamps, lit by its own rig by the numbers (shaders/hall_rig.gdshaderinc:
## each spot light's candela, cone and radius summed per fragment, no shadow), shown through a film curve at the rig's
## exposure. The picture is written as emission, so the installed style's sun adds nothing to it; the style's ink and
## grade passes run over it as over everything else.
##
##   TLStyleArena.set_rig(lights, exposure, gain, gain_shadows)   # once, before the materials are made
##   TLStyleArena.surface({...})                   # wood and painted pieces (hall_surface.gdshader)
##   TLStyleArena.ice({...})                       # the ice sheet (hall_ice.gdshader); it takes the style sun's shadow
##   TLStyleArena.crowd({...})                     # clay crowd and small parts (hall_crowd.gdshader)
##   TLStyleArena.bulb({...})                      # a lamp's bulb (hall_bulb.gdshader)
##   TLStyleArena.set_cheer(plus, minus, seconds)  # the crowd's cheering pose, 0..1 an end
##   TLStyleArena.post(anchor, {})                 # the installed style's grade and ink, set for a hall (hall_post.json)
##
## Colours are linear `Color`s (the numbers of the source material, not "#rrggbb"). Unknown keys are errors (the call
## returns null). Headless: one shared material with no shader (it answers set_shader_parameter), nothing else.

const MAX_LIGHTS: int = 24
const SURFACE_KEYS: Dictionary = {"dark": TYPE_COLOR, "light": TYPE_COLOR, "grain": TYPE_OBJECT, "tile_cm": TYPE_FLOAT, "grain_k": TYPE_FLOAT,
	"dent_k": TYPE_FLOAT, "vertex_colour": TYPE_BOOL, "wash_k": TYPE_FLOAT, "wash_h_cm": TYPE_FLOAT, "wash_colour": TYPE_COLOR,
	"spill_k": TYPE_FLOAT, "spill_far": TYPE_FLOAT, "spill_len_m": TYPE_FLOAT, "spill_colour": TYPE_COLOR, "spill_rink": TYPE_VECTOR4,
	"emit": TYPE_COLOR, "kick_h_cm": TYPE_FLOAT, "kick_colour": TYPE_COLOR, "rail_band_cm": TYPE_FLOAT, "rail_top_cm": TYPE_FLOAT,
	"rail_colour": TYPE_COLOR, "look_tint": TYPE_COLOR, "clay_base": TYPE_COLOR, "clay_base_mix": TYPE_FLOAT, "board": TYPE_FLOAT,
	"panel_cm": TYPE_FLOAT, "joint_cm": TYPE_FLOAT, "joint_dark": TYPE_FLOAT, "panel_var": TYPE_FLOAT, "top_cm": TYPE_FLOAT,
	"felt_rail": TYPE_FLOAT, "felt_band_cm": TYPE_FLOAT, "felt_colour": TYPE_COLOR, "wear": TYPE_BOOL, "wear_kick_top_cm": TYPE_FLOAT,
	"wear_dirt": TYPE_FLOAT, "wear_smear": TYPE_FLOAT, "wear_scuff": TYPE_FLOAT, "wear_tint": TYPE_COLOR, "clay_normal": TYPE_OBJECT,
	"clay_bump": TYPE_FLOAT, "clay_tile_cm": TYPE_FLOAT, "rim": TYPE_COLOR, "rim_power": TYPE_FLOAT, "felt_sheen": TYPE_FLOAT}
const ICE_KEYS: Dictionary = {"scratch": TYPE_OBJECT, "rink_hl": TYPE_FLOAT, "rink_hw": TYPE_FLOAT, "corner_r": TYPE_FLOAT, "goal_off": TYPE_FLOAT,
	"blue_frac": TYPE_FLOAT, "layout_hl": TYPE_FLOAT, "scratch_tile": TYPE_FLOAT, "scratch_amt": TYPE_FLOAT, "scratch_slot": TYPE_FLOAT,
	"scratch_far": TYPE_FLOAT, "scratch_lift": TYPE_FLOAT, "snow_w": TYPE_FLOAT, "snow_amt": TYPE_FLOAT, "line_soft": TYPE_FLOAT,
	"line_under": TYPE_FLOAT, "body": TYPE_COLOR, "scratch_colour": TYPE_COLOR, "snow_colour": TYPE_COLOR, "line_red": TYPE_COLOR,
	"line_blue": TYPE_COLOR, "pool_key_x": TYPE_VECTOR2, "pool_key_z": TYPE_FLOAT, "pool_inner_deg": TYPE_FLOAT, "pool_outer_deg": TYPE_FLOAT,
	"pool_tint": TYPE_COLOR, "pool_dim": TYPE_FLOAT, "contact_cm": TYPE_FLOAT, "contact_k": TYPE_FLOAT, "band_cm": TYPE_FLOAT, "band_k": TYPE_FLOAT,
	"band_colour": TYPE_COLOR, "lamp_a": TYPE_VECTOR3, "lamp_b": TYPE_VECTOR3, "sheen": TYPE_VECTOR4, "sheen_colour": TYPE_COLOR, "spec": TYPE_FLOAT,
	"shadow_share": TYPE_FLOAT}
const CROWD_KEYS: Dictionary = {"tint": TYPE_COLOR, "sat": TYPE_FLOAT, "fill_k": TYPE_FLOAT, "fill_low": TYPE_FLOAT, "fill_colour": TYPE_COLOR,
	"instanced": TYPE_BOOL, "pose_k": TYPE_FLOAT, "wave_k": TYPE_FLOAT, "bounce_cm": TYPE_FLOAT}
const BULB_KEYS: Dictionary = {"colour": TYPE_COLOR, "glow": TYPE_FLOAT, "edge_k": TYPE_FLOAT}
const _RENAME: Dictionary = {"dark": "wood_dark", "light": "wood_light", "colour": "bulb_colour"}

## What `post` may set: uniforms of the installed style's grade and ink passes (shaders/grade.gdshader, ink_post.gdshader).
const POST_GRADE: PackedStringArray = ["plum_density", "olive_fill", "edge_contrast", "split", "sat", "contrast", "vignette", "lift", "gamma"]
const POST_INK: PackedStringArray = ["fade_near", "fade_far", "outer_fade_far", "inner_near", "inner_far", "thin_near", "thin_far", "thin_tone", "inner_alpha"]

static var _shaders: Dictionary = {}
static var _stub: ShaderMaterial = null
static var _made: Array = []          # weak references to every material made, so a new rig or a cheer reaches them
static var _crowds: Array = []
static var _rig: Dictionary = {}


## The rig the hall's materials are lit by. `lights`: at most 24 of {pos: Vector3 (m), dir: Vector3 (the way it looks),
## colour: Color (linear), candela: float, radius_m: float, inner_deg: float, outer_deg: float, shadows: bool} (the cone
## angles are half angles, as Unreal's; `shadows`, optional: the light casts shadows in its source: such lights are
## listed first and the ice takes their share away in the style sun's shadow). `exposure`: what a luminance is
## multiplied by before the film curve. `gain`, `gain_shadows`: the rig's colour grade before that curve (the whole
## picture; its darks).
static func set_rig(lights: Array, exposure: float, gain: Color = Color(1, 1, 1), gain_shadows: Color = Color(1, 1, 1)) -> bool:
	if lights.size() > MAX_LIGHTS:
		push_error("TLStyleArena.set_rig: %d lights, at most %d" % [lights.size(), MAX_LIGHTS])
		return false
	var pos: Array = []
	var dir: Array = []
	var col: Array = []
	var ordered: Array = lights.filter(func(l: Dictionary) -> bool: return bool(l.get("shadows", false)))
	var keys: int = ordered.size()
	ordered.append_array(lights.filter(func(l: Dictionary) -> bool: return not bool(l.get("shadows", false))))
	for l: Dictionary in ordered:
		for k: String in ["pos", "dir", "colour", "candela", "radius_m", "inner_deg", "outer_deg"]:
			if not l.has(k):
				push_error("TLStyleArena.set_rig: a light without '%s'" % k)
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
	_rig = {"rig_n": n, "rig_keys": keys, "rig_pos": pos, "rig_dir": dir, "rig_col": col, "rig_exposure": exposure,
		"rig_gain": Vector3(gain.r, gain.g, gain.b), "rig_gain_shadows": Vector3(gain_shadows.r, gain_shadows.g, gain_shadows.b)}
	for m: ShaderMaterial in _live(_made):
		_push_rig(m)
	return true


## The hall shaders' film curve and grade (shaders/hall_rig.gdshaderinc `hall_tone`, the same arithmetic) for one linear
## colour that is already exposed: what the style's own materials are told the rig's light is (TLStyleHall) comes from
## here, so that both kinds of surface stand in one light.
static func tone(c: Color, gain: Color = Color(1, 1, 1), gain_shadows: Color = Color(1, 1, 1)) -> Color:
	var luma := Vector3(0.2126, 0.7152, 0.0722)
	var x := Vector3(maxf(c.r, 0.0) * gain.r, maxf(c.g, 0.0) * gain.g, maxf(c.b, 0.0) * gain.b)
	var k: float = smoothstep(0.0, 0.09, x.dot(luma))
	x *= Vector3(lerpf(gain_shadows.r, 1.0, k), lerpf(gain_shadows.g, 1.0, k), lerpf(gain_shadows.b, 1.0, k))
	x = Vector3.ONE * (x.dot(luma) * 0.04) + x * 0.96
	var out := Vector3.ZERO
	for i: int in 3:
		var lc: float = log(maxf(x[i], 1e-10)) * 0.4342944819
		var straight: float = 0.88 * (lc + 0.901647)
		var toe: float = (2.0 * 0.45) / (1.0 + exp((-2.0 * 0.88 / 0.45) * (lc + 0.390283)))
		var shoulder: float = 1.04 - (2.0 * 0.78) / (1.0 + exp((2.0 * 0.88 / 0.78) * (lc + 0.606192)))
		if lc >= -0.390283:
			toe = straight
		if lc <= -0.606192:
			shoulder = straight
		var t: float = 1.0 - clampf((lc + 0.390283) / (-0.606192 + 0.390283), 0.0, 1.0)
		t = (3.0 - 2.0 * t) * t * t
		out[i] = lerpf(toe, shoulder, t)
	out = Vector3.ONE * (out.dot(luma) * 0.07) + out * 0.93
	return Color(clampf(out.x, 0.0, 1.0), clampf(out.y, 0.0, 1.0), clampf(out.z, 0.0, 1.0))


## The exposure alone (a fade, a tone gain looked at in a still).
static func set_exposure(exposure: float) -> void:
	_rig["rig_exposure"] = exposure
	for m: ShaderMaterial in _live(_made):
		m.set_shader_parameter(&"rig_exposure", exposure)


## The crowd's cheer: `plus` / `minus` 0..1 for the end at +x / -x (0 = seated), `seconds` = game time (frames / 60).
static func set_cheer(plus: float, minus: float, seconds: float) -> void:
	for m: ShaderMaterial in _live(_crowds):
		m.set_shader_parameter(&"cheer_plus", plus)
		m.set_shader_parameter(&"cheer_minus", minus)
		m.set_shader_parameter(&"cheer_time", seconds)


## The hall look's own file (style/hall_post.json): the values `post` applies, {"grade": {...}, "ink": {...}}.
const POST_FILE: String = "res://style/hall_post.json"
static func post_file() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(POST_FILE))
	if not (d is Dictionary):
		push_error("TLStyleArena: %s does not read" % POST_FILE)
		return {}
	var out: Dictionary = {}
	for k: String in d:
		if k == "grade" or k == "ink":
			out[k] = d[k]
		elif k != "note":
			push_error("TLStyleArena: unknown key '%s' in %s" % [k, POST_FILE])
	return out


## Sets the installed style's grade and ink passes for a hall, from the hall look's file (`opt`: values on top of it,
## {} = the file as it is). (the "TLStyleRig" TLStyle.install made): a closed, lamp-lit
## room is not graded as open country is (the cel style prints a plum wash into low-chroma half tones: wood and a
## crowd in lamp light turn violet), and its far side carries no contour (a stand of 600 seated figures at 60 m is
## ink dots). Values only, no shader change: `TLStyleHall.clear` (TLStyle.install again) gives the style's own back.
## Like TLStyleHall it acts on the whole process: meant for a game alone. Headless: nothing.
static func post(anchor: Node, opt: Dictionary) -> bool:
	var over: Dictionary = opt
	for k: String in over:
		if k != "grade" and k != "ink":
			push_error("TLStyleArena.post: unknown section '%s' (known: grade, ink)" % k)
			return false
	var vals_all: Dictionary = post_file()
	for sec: String in over:
		var merged: Dictionary = (vals_all.get(sec, {}) as Dictionary).duplicate()
		merged.merge(over[sec] as Dictionary, true)
		vals_all[sec] = merged
	if TLStyle.headless() or anchor == null or not anchor.is_inside_tree():
		return false
	var rig: Node = anchor.get_tree().root.find_child(TLStyle.RIG_NODE, true, false)
	if rig == null:
		push_error("TLStyleArena.post: no installed style rig (TLStyle.install)")
		return false
	for sec: Array in [["grade", "Grade/Rect", POST_GRADE], ["ink", "InkPost", POST_INK]]:
		var vals: Dictionary = vals_all.get(sec[0], {})
		if vals.is_empty():
			continue
		for k: String in vals:
			if not (sec[2] as PackedStringArray).has(k):
				push_error("TLStyleArena.post: unknown %s key '%s' (known: %s)" % [sec[0], k, ", ".join(sec[2] as PackedStringArray)])
				return false
		var node: Node = rig.get_node_or_null(NodePath(str(sec[1])))
		var m: ShaderMaterial = null
		if node is CanvasItem:
			m = (node as CanvasItem).material as ShaderMaterial
		elif node is GeometryInstance3D:
			m = (node as GeometryInstance3D).material_override as ShaderMaterial
			if m == null and node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
				m = (node as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
		if m == null:
			continue                      # the pass is not installed (install's "ink": false / "grade": false)
		for k: String in vals:
			m.set_shader_parameter(k, vals[k])
	return true


static func surface(p: Dictionary = {}) -> Material:
	var m: ShaderMaterial = _make("hall_surface", p, SURFACE_KEYS, "surface")
	if m != null and m != _stub:
		m.set_shader_parameter(&"grain_on", 1.0 if p.get("grain") != null else 0.0)
	return m


static func ice(p: Dictionary = {}) -> Material:
	var m: ShaderMaterial = _make("hall_ice", p, ICE_KEYS, "ice")
	if m != null and m != _stub:
		m.set_shader_parameter(&"scratch_on", 1.0 if p.get("scratch") != null else 0.0)
	return m


static func crowd(p: Dictionary = {}) -> Material:
	var m: ShaderMaterial = _make("hall_crowd", p, CROWD_KEYS, "crowd")
	if m != null and m != _stub:
		_crowds.append(weakref(m))
	return m


static func bulb(p: Dictionary = {}) -> Material:
	return _make("hall_bulb", p, BULB_KEYS, "bulb")


static func _make(sname: String, p: Dictionary, keys: Dictionary, what: String) -> ShaderMaterial:
	for k: String in p:
		if not keys.has(k):
			push_error("TLStyleArena.%s: unknown key '%s' (known: %s)" % [what, k, ", ".join(PackedStringArray(keys.keys()))])
			return null
	if TLStyle.headless():
		if _stub == null:
			_stub = ShaderMaterial.new()
		return _stub
	if not _shaders.has(sname):
		_shaders[sname] = load("res://style/shaders/%s.gdshader" % sname)
	var m := ShaderMaterial.new()
	m.shader = _shaders[sname]
	for k: String in p:
		var v: Variant = p[k]
		var uname: String = String(_RENAME.get(k, k))
		match int(keys[k]):
			TYPE_COLOR:
				var c: Color = v
				m.set_shader_parameter(uname, Vector3(c.r, c.g, c.b))
			TYPE_BOOL:
				m.set_shader_parameter(uname, 1.0 if bool(v) else 0.0)
			TYPE_OBJECT:
				if v != null:
					m.set_shader_parameter(uname, v)
			_:
				m.set_shader_parameter(uname, v)
	_push_rig(m)
	_made.append(weakref(m))
	return m


static func _push_rig(m: ShaderMaterial) -> void:
	for k: String in _rig:
		m.set_shader_parameter(k, _rig[k])


static func _live(list: Array) -> Array:
	var out: Array = []
	var keep: Array = []
	for w: WeakRef in list:
		var m: Object = w.get_ref()
		if m != null:
			out.append(m)
			keep.append(w)
	list.assign(keep)
	return out
