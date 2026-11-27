extends RefCounted
## Time of day (lane DN, day of 27 Nov 2026): the style's look moved through dawn, day, dusk and night. The style file's
## own values ARE noon: a style with a `day` section names only how dawn, dusk and night differ from them, so the look
## at noon (t = 0.5) is the file's, value for value, and a style without the section has no time of day at all.
## Not pack API (TLStyle's public surface is unchanged): the kernel's Home preloads this file and calls `has_day()`,
## `day_look(t)` and `apply_day(anchor, look)`. No state, no reference outside the style. Values only: no shader change,
## no new global.
##
## `day` section (style_crisp.json): {"dawn": {...}, "dusk": {...}, "night": {...}}; each names a few keys of the sections
## below, as in the style itself ("sun": {"color": "#9db4ff", "elev": 38.0}), plus "lamps" (how strongly the kit's lamps
## burn, 0 = off; noon is 0). Unknown keys are errors; an absent key is noon's value.
##
## The clock t is the fraction of a day (0 = midnight, 0.25 dawn, 0.5 noon, 0.75 dusk). The colours stay the night's
## from 0.80 to 0.20 and noon's from 0.375 to 0.625. At the two blue hours (0.225, 0.775) the light is flat (the lit band
## takes the shade's colour), and there the light turns from the sun to the moon or back, so the swap is never seen.

const PHASES: PackedStringArray = ["dawn", "dusk", "night"]


static var _cached_for: Dictionary = {}   # the style data the phases below were made from (same object)
static var _phases: Dictionary = {}       # phase name -> look (noon, dawn, dusk, night, blue_dawn, blue_dusk)


## A phase of `d`, made once per style data (a look is about 60 values; the clock asks every few frames).
static func cached(d: Dictionary, ph: String) -> Dictionary:
	if not is_same(d, _cached_for):
		_cached_for = d
		_phases = {}
	if not _phases.has(ph):
		_phases[ph] = phase(d, ph)
	return _phases[ph]


## The loaded style has a day section.
static func has_day() -> bool:
	TLStyle.ensure()
	return TLStyle.data.get("day") is Dictionary and not (TLStyle.data["day"] as Dictionary).is_empty()


## The loaded style's look at clock t (0..1 of a day; 0.5 = its own values, exactly).
static func day_look(t: float) -> Dictionary:
	TLStyle.ensure()
	return look(TLStyle.data, t)


## Writes a look onto the rig TLStyle.install made (the one in `anchor`'s tree) and the shader globals. Headless, with no
## rig or no look: nothing, 0; else the number of values written. `TLStyle.install(host)` again gives the style back.
static func apply_day(anchor: Node, lk: Dictionary) -> int:
	if TLStyle.headless() or anchor == null or not anchor.is_inside_tree() or lk.is_empty():
		return 0
	var rig: Node = anchor.get_tree().root.find_child(TLStyle.RIG_NODE, true, false)
	return 0 if rig == null else apply(rig, TLStyle.data, lk)
## the keys a phase may name, by section; each is a colour ("#rrggbb") or a number
const KEYS: Dictionary = {
	"sun": ["color", "energy", "elev", "azim"],
	"toon": ["shade", "shade_k", "shade_ground", "amb_sky", "amb_ground", "amb_energy", "bounce", "bounce_k", "rim2", "rim2_k"],
	"fog": ["color", "density", "height_density"],
	"sky": ["zenith", "upper", "mid", "horizon", "ground", "glow", "glow_k", "disc", "disc_r", "cloud", "cloud_shade", "cloud_ink", "sun_draw_elev",
		"sun_draw_yaw", "stars", "moon"],
	"water": ["deep", "shallow", "sky", "stripe", "foam"],
	"grade": ["shadows", "highlights", "sat", "split", "contrast", "lift", "plum_density", "olive_fill"],
	"env": ["exposure"],
}
## where a key's noon value comes from when the style leaves it out (the same defaults TLStyle._register_globals uses)
const FALLBACK: Dictionary = {"toon.shade_ground": "toon.shade", "toon.rim2": "#000000", "toon.rim2_k": 0.0,
	"toon.bounce": "#000000", "toon.bounce_k": 0.0, "fog.height_density": 0.0, "grade.sat": 1.0,
	"grade.contrast": 1.0}
const RANGE: Dictionary = {"sun.energy": [0.0, 2.0], "sun.elev": [4.0, 80.0], "sun.azim": [-360.0, 720.0], "lamps": [0.0, 3.0],
	"toon.amb_energy": [0.0, 1.2], "toon.shade_k": [0.2, 0.95], "fog.density": [0.0, 0.004], "env.exposure": [0.6, 1.6]}
const BLUE_DAWN := 0.225
const BLUE_DUSK := 0.775
## the colour timeline: [t, phase]; "blue_dawn" / "blue_dusk" are made (the night and the day half and half, flat light)
const TIMELINE: Array = [[0.0, "night"], [0.20, "night"], [BLUE_DAWN, "blue_dawn"], [0.25, "dawn"], [0.375, "noon"],
	[0.625, "noon"], [0.75, "dusk"], [BLUE_DUSK, "blue_dusk"], [0.80, "night"], [1.0, "night"]]


static func check(d: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if not d.has("day"):
		return out
	if not (d["day"] is Dictionary):
		out.append("day must be an object")
		return out
	for ph: String in d["day"]:
		if not PHASES.has(ph):
			out.append("day.%s is not a phase (allowed: %s)" % [ph, ", ".join(PHASES)])
			continue
		var p: Variant = d["day"][ph]
		if not (p is Dictionary):
			out.append("day.%s must be an object" % ph)
			continue
		for sec: String in p:
			if sec == "lamps":
				if not (p[sec] is float or p[sec] is int):
					out.append("day.%s.lamps must be a number" % ph)
				continue
			if not KEYS.has(sec) or not (p[sec] is Dictionary):
				out.append("day.%s.%s is not a section of the day (allowed: %s, lamps)" % [ph, sec, ", ".join(PackedStringArray(KEYS.keys()))])
				continue
			for k: String in p[sec]:
				if not (KEYS[sec] as Array).has(k):
					out.append("day.%s.%s.%s is not a key of the day (allowed: %s)" % [ph, sec, k, ", ".join(PackedStringArray(KEYS[sec]))])
					continue
				var v: Variant = p[sec][k]
				var want_colour: bool = _noon_value(d, sec, k) is Color
				if want_colour and not (v is String and Color.html_is_valid(String(v))):
					out.append("day.%s.%s.%s = %s is not a colour like #rrggbb" % [ph, sec, k, str(v)])
				elif not want_colour and not (v is float or v is int):
					out.append("day.%s.%s.%s must be a number" % [ph, sec, k])
	return out


## The noon look: every key of KEYS from the style itself, colours as Color, numbers as float; lamps 0.
static func noon(d: Dictionary) -> Dictionary:
	var out := {"lamps": 0.0}
	for sec: String in KEYS:
		for k: String in KEYS[sec]:
			out[sec + "." + k] = _noon_value(d, sec, k)
	return out


static func _noon_value(d: Dictionary, sec: String, k: String) -> Variant:
	var s: Dictionary = d.get(sec, {}) if d.get(sec, {}) is Dictionary else {}
	var v: Variant = s.get(k)
	if v == null:
		var fb: Variant = FALLBACK.get(sec + "." + k)
		if fb is String and String(fb).contains("."):
			v = (d.get(String(fb).get_slice(".", 0), {}) as Dictionary).get(String(fb).get_slice(".", 1))
		else:
			v = fb
	if v is String:
		return Color(String(v))
	return float(v) if (v is float or v is int) else 0.0


## A phase's look: noon with the phase's keys on top.
static func phase(d: Dictionary, ph: String) -> Dictionary:
	var out := noon(d)
	if ph == "noon":
		return out
	if ph == "blue_dawn" or ph == "blue_dusk":
		var b := mix(phase(d, "night"), phase(d, "dawn" if ph == "blue_dawn" else "dusk"), 0.5)
		b["sun.color"] = b["toon.shade"]        # flat: the lit band is the shade's colour (see the file's head)
		b["sun.energy"] = 1.0
		return b
	var p: Dictionary = (d.get("day", {}) as Dictionary).get(ph, {})
	for sec: String in p:
		if sec == "lamps":
			out["lamps"] = _clamp("lamps", float(p[sec]))
			continue
		for k: String in p[sec]:
			var v: Variant = p[sec][k]
			out[sec + "." + k] = Color(String(v)) if v is String else _clamp(sec + "." + k, float(v))
	return out


static func _clamp(key: String, v: float) -> float:
	if RANGE.has(key):
		return clampf(v, float(RANGE[key][0]), float(RANGE[key][1]))
	return v


## a and b mixed by w (0 = a, exactly; 1 = b, exactly). Angles of azimuth take the short way round.
static func mix(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	if w <= 0.0:
		return a.duplicate()
	if w >= 1.0:
		return b.duplicate()
	var out := {}
	for k: String in a:
		var va: Variant = a[k]
		var vb: Variant = b.get(k, va)
		if va is Color:
			out[k] = (va as Color).lerp(vb as Color, w)
		elif k == "sun.azim" or k == "sky.sun_draw_yaw":
			out[k] = float(va) + wrapf(float(vb) - float(va), -180.0, 180.0) * w
		else:
			out[k] = lerpf(float(va), float(vb), w)
	return out


## The look at clock t (0..1, fraction of a day). At t = 0.5 it is `noon(d)` exactly.
static func look(d: Dictionary, t: float) -> Dictionary:
	t = fposmod(t, 1.0)
	var out: Dictionary = {}
	for i: int in TIMELINE.size() - 1:
		var t0: float = TIMELINE[i][0]
		var t1: float = TIMELINE[i + 1][0]
		if t >= t0 and t < t1:
			var w := smoothstep(0.0, 1.0, (t - t0) / (t1 - t0))
			out = mix(cached(d, TIMELINE[i][1]), cached(d, TIMELINE[i + 1][1]), w)
			break
	if out.is_empty():
		out = cached(d, "night").duplicate()
	var dir := light_dir(d, t)
	out["sun.elev"] = dir.x
	out["sun.azim"] = dir.y
	out["moon"] = dir.z
	return out


## Where the light comes from at clock t: Vector3(elev, azim, 1 if it is the moon). Between the blue hours the sun's arc
## (dawn's elevation and azimuth, noon's, dusk's: the sun keeps moving all day, it is at the style's own sun at 0.5);
## the rest of the day the moon's, highest at midnight. Elevation never below 4 degrees (a lower light draws no shadow
## worth having and the cel bands go to the deep one).
static func light_dir(d: Dictionary, t: float) -> Vector3:
	t = fposmod(t, 1.0)
	var n: Dictionary = cached(d, "noon")
	var dawn: Dictionary = cached(d, "dawn")
	var dusk: Dictionary = cached(d, "dusk")
	var night: Dictionary = cached(d, "night")
	var e0: float = n["sun.elev"]
	var a0: float = n["sun.azim"]
	if t >= BLUE_DAWN and t < BLUE_DUSK:
		if t < 0.25:
			var u := (t - BLUE_DAWN) / (0.25 - BLUE_DAWN)
			return Vector3(lerpf(4.0, dawn["sun.elev"], u), float(dawn["sun.azim"]) - 6.0 * (1.0 - u), 0.0)
		if t < 0.5:
			var u2 := (t - 0.25) / 0.25
			return Vector3(lerpf(dawn["sun.elev"], e0, sin(u2 * PI * 0.5)), lerpf(dawn["sun.azim"], a0, u2), 0.0)
		if t == 0.5:
			return Vector3(e0, a0, 0.0)
		if t < 0.75:
			var u3 := (t - 0.5) / 0.25
			return Vector3(lerpf(e0, dusk["sun.elev"], 1.0 - cos(u3 * PI * 0.5)), lerpf(a0, dusk["sun.azim"], u3), 0.0)
		var u4 := (t - 0.75) / (BLUE_DUSK - 0.75)
		return Vector3(lerpf(dusk["sun.elev"], 4.0, u4), float(dusk["sun.azim"]) + 6.0 * u4, 0.0)
	# the moon: s = 0 at the dusk's blue hour, 0.5 at midnight, 1 at the dawn's
	var s := fposmod(t - BLUE_DUSK, 1.0) / (1.0 - (BLUE_DUSK - BLUE_DAWN))
	var me: float = night["sun.elev"]
	return Vector3(lerpf(12.0, me, sqrt(sin(clampf(s, 0.0, 1.0) * PI))), float(night["sun.azim"]) + (s - 0.5) * 50.0, 1.0)


## The shader globals of look `lk`, as TLStyle._register_globals computes them from the style (same formulas, same kind
## of values: a Color parsed from the same "#rrggbb", the same floats), so at noon they are the values install wrote.
static func globals(d: Dictionary, lk: Dictionary) -> Dictionary:
	var t: Dictionary = d.get("toon", {})
	var elev: float = lk["sun.elev"]
	var azim: float = lk["sun.azim"]
	var sd: Vector3 = Basis.from_euler(Vector3(deg_to_rad(-elev), deg_to_rad(180.0 - azim), 0.0)).z
	return {
		"g_sun": TLStyle._v4((lk["sun.color"] as Color).srgb_to_linear(), float(lk["sun.energy"])),
		"g_shade": TLStyle._v4((lk["toon.shade"] as Color).srgb_to_linear(), float(lk["toon.shade_k"])),
		"g_amb_sky": TLStyle._v4((lk["toon.amb_sky"] as Color).srgb_to_linear(), float(lk["toon.amb_energy"])),
		"g_amb_gnd": TLStyle._v4((lk["toon.amb_ground"] as Color).srgb_to_linear(), 1.0),
		"g_shade2": TLStyle._v4((lk["toon.shade_ground"] as Color).srgb_to_linear(), float(t.get("shade_grad", 0.0))),
		"g_rim2": TLStyle._v4((lk["toon.rim2"] as Color).srgb_to_linear(), float(lk["toon.rim2_k"])),
		"g_bounce": TLStyle._v4((lk["toon.bounce"] as Color).srgb_to_linear(), float(lk["toon.bounce_k"])),
		"g_sun_dir": Vector4(sd.x, sd.y, sd.z, 0.0),
		"g_haze": TLStyle._v4((lk["fog.color"] as Color).srgb_to_linear(), float(lk["fog.density"])),
	}


## Writes look `lk` onto the installed rig `rig` (TLStyle.install's TLStyleRig) and the shader globals. `d` is the style.
## The same writes TLStyle.install and _register_globals make for these keys, from the same kind of values, so the look
## at noon writes what install wrote. Returns the number of values written.
static func apply(rig: Node, d: Dictionary, lk: Dictionary) -> int:
	var n := 0
	var g := globals(d, lk)
	for gk: String in g:
		TLStyle._g(gk, g[gk])
		n += 1
	var sun_c: Color = lk["sun.color"]
	var energy: float = lk["sun.energy"]
	var elev: float = lk["sun.elev"]
	var azim: float = lk["sun.azim"]
	if rig == null:
		return n
	var sun: DirectionalLight3D = rig.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = sun_c
		var e_noon: float = float((d.get("sun", {}) as Dictionary).get("energy", 1.0))
		sun.light_energy = 1.0 if is_equal_approx(energy, e_noon) else energy / maxf(e_noon, 0.001)
		sun.rotation_degrees = Vector3(-elev, 180.0 - azim, 0.0)
		var key: Node = sun.get_node_or_null("OverheadKey")
		if key != null:
			key.set("normal_pitch", -deg_to_rad(elev))
			# the overhead board keeps its offset from the sun (cel: 39 against 40), so at noon it is the style's own
			var s0: Dictionary = d.get("sun", {})
			var over: float = float(s0.get("overhead_elev", s0.get("elev", elev))) - float(s0.get("elev", elev))
			key.set("overhead_pitch", -deg_to_rad(clampf(elev + over, 4.0, 85.0)))
			key.call("_process", 0.0)
		n += 3
	var we: WorldEnvironment = rig.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		var env: Environment = we.environment
		env.fog_light_color = lk["fog.color"]
		env.fog_density = float(lk["fog.density"])
		env.fog_height_density = float(lk["fog.height_density"])
		env.ambient_light_color = (lk["toon.amb_sky"] as Color).lerp(lk["toon.amb_ground"] as Color, 0.5)
		env.tonemap_exposure = float(lk["env.exposure"])
		n += 5
		var sm: ShaderMaterial = env.sky.sky_material as ShaderMaterial if env.sky != null else null
		if sm != null:
			n += _write(sm, d, "sky", lk)
	var water: Variant = TLStyle._mats.get("water")
	if water is ShaderMaterial:
		n += _write(water as ShaderMaterial, d, "water", lk)
	var grade: Node = rig.get_node_or_null("Grade/Rect")
	if grade is CanvasItem and (grade as CanvasItem).material is ShaderMaterial:
		n += _write((grade as CanvasItem).material as ShaderMaterial, d, "grade", lk)
	return n


## A section's keys onto a material. A key the style names is written as the look has it; a key it leaves out is written
## only while it differs from noon's, and at noon its override is cleared (null: the shader's own default again), so
## what install left (nothing set) is what noon leaves (stars, moon, a grade knob the file does not name).
static func _write(m: ShaderMaterial, d: Dictionary, sec: String, lk: Dictionary) -> int:
	var n := 0
	var named: Dictionary = d.get(sec, {}) if d.get(sec, {}) is Dictionary else {}
	for k: String in KEYS[sec]:
		var v: Variant = lk[sec + "." + k]
		if named.has(k) or v != _noon_value(d, sec, k):
			m.set_shader_parameter(k, v)
		else:
			m.set_shader_parameter(k, null)
		n += 1
	return n
