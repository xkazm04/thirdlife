extends RefCounted
## Crisp cel (day of 20 Nov 2026), surfaces: what TLStyle needs for a style file that names the cel material model,
## kept beside tl_style.gd (whose size is budgeted) and out of the indexed API (a pack never calls this).
##
##   toon.model    "cel" = engine/style/shaders/toon_cel.gdshader (toon.gdshader itself is not touched).
##   water.model   "cel" = water_cel.gdshader (flat blue, drawn streaks, a foam line at the bank).
##   toon          cel_shadow (0..0.5: half width of the cut of a cast shadow; small = a line), cel_chroma (chroma the
##                 shade keeps, 0 = today's multiply), cel_deep (the band of a form turned fully away, as a factor of
##                 the shade), cel_rim (0 = smooth rim light, 1 = a cut shape), cel_top and cel_top_k (where on a lump
##                 the top light begins, of the light 0..1, and how much lighter it is; 0 = none), cel_wind (metres the
##                 top of a 10 m tree leans in the wind; it moves the keys whose `mat.<key>.sway` is negative).
##   detail        edge (a painted highlight on the edges of a sunlit box face), round (0..1: a blob or a cone side lit
##                 as the round thing it is), land_wobble (how far the edge between two land paints strays), marks_m
##                 (scale of tufts and pebbles; 1 = today's), marks_far (m: where they end; 0 = at the detail fade), patch (light patches on earth and meadow), verge_m (the
##                 dark cut of the turf beside a road), flowers (0..1: handfuls of flat dots in the meadow), land_flat (0..1: level
##                 land is lit as flatter than it is, so a rolling meadow stays one lit field), land_bias {paint: number} (a paint with a larger bias wins more
##                 ground when the land is painted by numbers).

## The land's eight paints, in the order toon_cel.gdshader reads them (0..2 grass, 3..4 earth, 5..7 rock).
const LAND: PackedStringArray = ["grass", "grass_dark", "grass_dry", "dirt", "sand", "rock", "cliff", "rock_warm"]


## The shader globals of the cel model (declared only by toon_cel.gdshader and water_cel.gdshader).
static func globals(data: Dictionary) -> Dictionary:
	var t: Dictionary = data.get("toon", {})
	var dt: Dictionary = data.get("detail", {})
	var pal: Dictionary = data.get("palette", {})
	var bias: Dictionary = dt.get("land_bias", {})
	var out: Dictionary = {
		"g_cel": Vector4(clampf(float(t.get("cel_shadow", 0.08)), 0.005, 0.5), float(t.get("cel_chroma", 0.0)), float(dt.get("edge", 0.0)), clampf(float(dt.get("round", 0.0)), 0.0, 1.0)),
		"g_cel2": Vector4(float(dt.get("land_wobble", 0.05)), float(dt.get("marks_m", 1.0)), float(dt.get("patch", 0.0)), float(dt.get("verge_m", 0.0))),
		"g_cel4": Vector4(float(t.get("cel_wind", 0.0)), clampf(float(dt.get("flowers", 0.0)), 0.0, 1.0), clampf(float(dt.get("land_flat", 0.0)), 0.0, 1.0), float(dt.get("marks_far", 0.0))),
		"g_cel3": Vector4(float(t.get("cel_deep", 1.0)), clampf(float(t.get("cel_rim", 0.0)), 0.0, 1.0), float(t.get("cel_top", 0.8)), float(t.get("cel_top_k", 0.0))),
	}
	for i: int in LAND.size():
		var c: Color = Color(String(pal.get(LAND[i], "#ff00ff"))).srgb_to_linear()
		out["g_land%d" % i] = Vector4(c.r, c.g, c.b, float(bias.get(LAND[i], 0.0)))
	return out
