class_name TLRigSkaterLook
extends RefCounted
## The skater's surface (hockey campaign, lane K7): two looks to choose from.
##   "felt"  thirdjam's own: its nine material instances on the clay tier (felt jersey, trim and pads, clay skin,
##           helmet, gloves, skates, blade, stick), the number on the back patch, the crest on the chest
##           (TLStyleFelt, style/shaders/body_felt.gdshader). No ink line.
##   "cel"   the engine's flat cel in thirdjam's slot colours (TLStyle.flat_material), as round 1 of lane K2 had it.
## `default_variant` is the look of every skater built after it is set ("felt"); the environment variable
## TL_SKATER_LOOK (felt | cel) sets it for a run; one skater: TLRigSkaterBody.set_look.
## The numbers: thirdjam's material instances of SK_SkaterTB1_P3 as its editor reports them (engine/tools/skater/
## export_skater.py -> meta.json "materials": vector and scalar parameters with the parent's defaults filled in), and
## what its driver sets at run time (BP_SkaterVisual_TB1_P3: [SetTeam], [SetNumber] of driver-ref).

const VARIANTS: PackedStringArray = ["felt", "cel"]
const DIR: String = "res://rigs/skater/look/"
## [SetTeam]: the helmet's TeamColour = Colour x 0.75 (CallFunction_1259).
const HELMET_K: float = 0.75
## The seven slots that are not the team's: TeamColour of thirdjam's own material instance (linear).
const SLOT_LINEAR: Dictionary = {
	"Pads": Color(0.022, 0.026, 0.06),     # MI_SkaterTB1_P3_PadsFelt
	"Trim": Color(0.8, 0.7, 0.5),          # MI_SkaterTB1_P3_TrimDeco
	"Skin": Color(0.75, 0.5, 0.38),        # MI_SkaterTB1_Skin
	"Gloves": Color(0.02, 0.02, 0.025),    # MI_SkaterTB1_P3_Gloves
	"Skate": Color(0.03, 0.03, 0.035),     # MI_SkaterTB1_P3_Skate
	"Blade": Color(0.6, 0.65, 0.72),       # MI_SkaterTB1_Blade
	"Stick": Color(0.3, 0.15, 0.05),       # MI_SkaterTB1_Stick
}
## Per slot, what the material instance sets apart from its colour (keys of TLStyleFelt.KEYS). The three felt slots
## are instances of M_SkaterTB1Jersey, the six clay slots of M_Toon (clay_bump_scale = its ClayBumpMul). ClayNormalTex
## as the editor reports it per instance (look_reference.py, "slot_textures"): T_Clay_Dent_N on the helmet, the gloves
## and the skates, the master's T_Clay_Thumb_N on skin, blade and stick.
const FELT: Dictionary = {
	# MI_SkaterTB1_P3_JerseyDeco: the crest (CrestOn 1, CrestY -10, CrestZ 113, CrestSize 10 cm); the number is masked
	# off this slot (NumberBackMask -2: no normal passes), [SetNumber] still sets NumberOn 1 on it
	"Jersey": {"rim_strength": 1.2, "emissive": 2.0, "sheen_tint": Color(2.5, 2.05, 1.5), "vcol_mix": 1.0, "felt_mix": 1.0,
		"felt_tile": 4.0, "felt_bump": 3.0, "clay_bump_scale": 0.35, "felt_mottle_tile": 7.0, "felt_mottle": 0.7, "felt_darken": 0.62,
		"hem_z0": 86.0, "hem_z1": 93.5, "hem_k": 0.62, "sheen_white": 0.15, "number_back_mask": -2.0, "number_on": 0.0,
		"crest_on": 1.0, "crest_yzs": Vector3(-10.0, 113.0, 10.0)},
	# MI_SkaterTB1_P3_TrimDeco: the number on the back patch in dark ink (NumberOn 2, centre (0.5, 0.344), 0.42 x 0.7 of
	# the patch's UV, lane SK20's values)
	"Trim": {"rim_strength": 0.6, "emissive": 1.5, "sheen_tint": Color(1.5, 1.4, 1.2), "vcol_mix": 1.0, "felt_mix": 1.0,
		"felt_tile": 4.0, "felt_bump": 2.0, "clay_bump_scale": 0.5, "felt_mottle_tile": 7.0, "felt_mottle": 0.12, "felt_darken": 1.0,
		"sheen_white": 0.3, "number_on": 2.0, "number_centre": Vector2(0.5, 0.344), "number_cell": Vector2(0.42, 0.7),
		"number_back_mask": -0.3, "crest_on": 0.0},
	# MI_SkaterTB1_P3_PadsFelt
	"Pads": {"rim_strength": 0.6, "emissive": 0.6, "sheen_tint": Color(2.0, 1.64, 1.2), "vcol_mix": 1.0, "felt_mix": 1.0,
		"felt_tile": 4.0, "felt_bump": 3.0, "clay_bump_scale": 0.5, "felt_mottle_tile": 7.0, "felt_mottle": 0.6, "felt_darken": 1.0,
		"sheen_white": 0.15, "number_on": 0.0, "crest_on": 0.0},
	"Skin": {"rim_strength": 0.4, "emissive": 1.5},                                              # MI_SkaterTB1_Skin
	"Helmet": {"rim_strength": 0.6, "emissive": 1.5, "clay_tile_mul": 2.0, "clay_bump_scale": 0.6, "clay_normal": "dent"},   # MI_SkaterTB1_P3_Helmet
	"Gloves": {"rim_strength": 0.35, "emissive": 0.0, "clay_tile_mul": 2.0, "clay_bump_scale": 0.6, "clay_normal": "dent"},  # MI_SkaterTB1_P3_Gloves
	"Skate": {"rim_strength": 0.4, "emissive": 0.5, "clay_tile_mul": 2.0, "clay_bump_scale": 0.6, "clay_normal": "dent"},    # MI_SkaterTB1_P3_Skate
	"Blade": {"rim_strength": 0.8, "emissive": 1.5},                                             # MI_SkaterTB1_Blade
	"Stick": {"rim_strength": 0.6, "emissive": 2.0},                                             # MI_SkaterTB1_Stick
}

static var default_variant: String = ""
static var _look_mesh: Dictionary = {}      # the baked mesh's instance id -> the same mesh with the rest pose in CUSTOM0 / CUSTOM2


## The look a skater gets when it names none: TL_SKATER_LOOK, else "felt".
static func chosen() -> String:
	if default_variant == "":
		var env: String = OS.get_environment("TL_SKATER_LOOK")
		default_variant = env if VARIANTS.has(env) else "felt"
	return default_variant


## The tens and the ones of a jersey number ([SetNumber]: PendingNumber / 10 and PendingNumber % 10 of Clamp(N, 0, 99)).
static func digits(number: int) -> Vector2i:
	var n: int = clampi(number, 0, 99)
	return Vector2i(n / 10, n % 10)


## The slot's colour (linear), given the team's (linear): the jersey is the team's, the helmet the team's x 0.75.
static func slot_colour(slot: String, team_linear: Color) -> Color:
	match slot:
		"Jersey": return Color(team_linear.r, team_linear.g, team_linear.b)
		"Helmet": return Color(team_linear.r * HELMET_K, team_linear.g * HELMET_K, team_linear.b * HELMET_K)
	return SLOT_LINEAR.get(slot, Color(0.5, 0.5, 0.5)) as Color


## What TLStyleFelt.material is given for a slot: thirdjam's instance, the team, the number.
static func felt_params(slot: String, team: int, team_linear: Color, number: int) -> Dictionary:
	var p: Dictionary = (FELT.get(slot, {}) as Dictionary).duplicate()
	p["team_colour"] = slot_colour(slot, team_linear)
	if slot == "Jersey" or slot == "Trim":
		var d: Vector2i = digits(number)
		p["number_tens"] = float(d.x)       # [SetNumber]: NumberTens, NumberOnes on the jersey and on element 2 (Trim)
		p["number_ones"] = float(d.y)
	if slot == "Jersey":
		p["number_on"] = 1.0                # [SetNumber] CallFunction_1270
		p["crest_team"] = float(clampi(team, 0, 1))      # [SetTeam] CallFunction_1262
	return p


## Puts the look on a skater's mesh. `o`: {"variant": "felt" | "cel" | "" (the chosen one), "team": 0 | 1,
## "colour": the team's (sRGB), "number": 0..99}. Returns the variant applied.
static func apply(mi: MeshInstance3D, o: Dictionary) -> String:
	var variant: String = String(o.get("variant", ""))
	if not VARIANTS.has(variant):
		variant = chosen()
	var colour: Color = o.get("colour", Color("1d4ed8")) as Color
	var lin: Color = colour.srgb_to_linear()
	var team: int = int(o.get("team", 0))
	var number: int = int(o.get("number", 0))
	var base: Mesh = mi.get_meta(&"tl_base_mesh") as Mesh if mi.has_meta(&"tl_base_mesh") else mi.mesh
	if variant == "felt" and not TLStyle.headless():
		if not mi.has_meta(&"tl_base_mesh"):
			mi.set_meta(&"tl_base_mesh", base)
		mi.mesh = look_mesh(base)
	elif mi.mesh != base:
		mi.mesh = base
	var numbers: Texture2D = TLStyleFelt.texture(DIR + "T_Numbers_Varsity.png") if variant == "felt" else null
	var crest0: Texture2D = TLStyleFelt.texture(DIR + "T_Crest_Blue_Comet.png") if variant == "felt" else null
	var crest1: Texture2D = TLStyleFelt.texture(DIR + "T_Crest_Orange_Fox.png") if variant == "felt" else null
	var held: Array = []
	for s: int in range(base.get_surface_count()):
		var slot: String = base.surface_get_name(s)
		if variant == "felt":
			var p: Dictionary = felt_params(slot, team, lin, number)
			if slot == "Jersey" or slot == "Trim":
				p["number_atlas"] = numbers
				p["crest0"] = crest0
				p["crest1"] = crest1
			# as thirdjam's driver keeps one dynamic instance a slot and sets parameters on it
			var have: ShaderMaterial = mi.get_surface_override_material(s) as ShaderMaterial
			if have != null and have.has_meta(&"tl_felt_slot") and String(have.get_meta(&"tl_felt_slot")) == slot:
				TLStyleFelt.set_params(have, p)
			else:
				var m: ShaderMaterial = TLStyleFelt.material(p)
				if m != null and not TLStyle.headless():
					m.set_meta(&"tl_felt_slot", slot)
				mi.set_surface_override_material(s, m)
			held.append(mi.get_surface_override_material(s))
		else:
			var c: Color = slot_colour(slot, lin).linear_to_srgb()
			mi.set_surface_override_material(s, TLStyle.flat_material(Color(c.r, c.g, c.b), 0.6 if slot == "Blade" else 0.0))
	# The node's metadata outlives its place in the renderer: a figure freed before it was ever drawn would otherwise
	# leave the renderer one update with materials that are already gone (seen: "Parameter material is null" x 36).
	mi.set_meta(&"tl_felt_materials", held)
	return variant


## The baked mesh with what thirdjam's material reads before skinning: CUSTOM0 = the vertex at rest (xyz, metres),
## CUSTOM2 = its normal at rest. The same vertices in the same order, the same surfaces and names; made once.
static func look_mesh(base: Mesh) -> Mesh:
	var id: int = base.get_instance_id()
	if _look_mesh.has(id):
		return _look_mesh[id]
	var out: ArrayMesh = ArrayMesh.new()
	for s: int in range(base.get_surface_count()):
		var arr: Array = base.surface_get_arrays(s)
		var fmt: int = (base as ArrayMesh).surface_get_format(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var rest: PackedFloat32Array = PackedFloat32Array()
		var rest_n: PackedFloat32Array = PackedFloat32Array()
		rest.resize(vs.size() * 4)
		rest_n.resize(vs.size() * 3)
		for v: int in range(vs.size()):
			rest[v * 4] = vs[v].x
			rest[v * 4 + 1] = vs[v].y
			rest[v * 4 + 2] = vs[v].z
			rest[v * 4 + 3] = 0.0
			rest_n[v * 3] = ns[v].x
			rest_n[v * 3 + 1] = ns[v].y
			rest_n[v * 3 + 2] = ns[v].z
		arr[Mesh.ARRAY_CUSTOM0] = rest
		arr[Mesh.ARRAY_CUSTOM2] = rest_n
		var flags: int = fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		flags |= ((fmt >> Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) & Mesh.ARRAY_FORMAT_CUSTOM_MASK) << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		flags |= Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		out.surface_set_name(s, base.surface_get_name(s))
	if base is ArrayMesh:
		out.custom_aabb = (base as ArrayMesh).custom_aabb
	_look_mesh[id] = out
	return out
