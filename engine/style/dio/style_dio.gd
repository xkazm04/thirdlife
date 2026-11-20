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
		"g_dio5": Vector4(float(t.get("wax", 0.0)), 0.0, 0.0, 0.0),
		"g_dio4": Vector4(grass.r, grass.g, grass.b, clampf(float(dt.get("round", 0.0)), 0.0, 1.0)),
	}
