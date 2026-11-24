extends RefCounted
## thirdjam's hall round the rink (K6, hockey port): the barn, the stands, the crowd, the lamps, the benches, the penalty
## boxes, the scorer's table, the goal lights and the board caps of the regular cut's look tier p3_clay, as the running
## game draws them, and the surfaces of the rink itself as that tier dresses them (the ice, the boards, the kick plate,
## the board top's cap). The pieces and their places are data baked from the played game (arena.scn, arena.json; the
## tools are engine/tools/arena: export_arena.py -> arena_prep.py -> build_arena.gd); this file dresses them in the
## style's hall materials (TLStyleArena) from thirdjam's own material parameters and hands the rig's light to the style.
## Visual only: nothing here is state, nothing reads the clock (the cheer is given in frames by the caller).
##
##   var arena = ctx.cores.part("rink", "arena")                        # this script
##   arena.build(ctx.root, {"rink": cart["game"]["rink"]})
##   arena.light(ctx.root)                                              # frame 0: the rig's light and post for the style
##   var react = arena.reactions(ctx.root, rink); react.frame(snap)     # the lamps, the net, the caps, the cheer (round 3)
##
## Options of build (unknown keys are errors): `rink` (thirdjam's game.rink: with it the rink's own surfaces are drawn
## over the pack's rink, see _rink_surfaces; absent = the hall alone), `goals` (false: thirdjam's goal meshes stay
## hidden, the pack draws its own), `crowd` (true), `tone_gain` (TONE_GAIN).

const DIR: String = "res://cores/rink/arena/"
## What the rig's exposure (1 / (1.2 * 2^EV100), EV100 4.2 from the rig's post volume) is multiplied by before the film
## curve. NOT a thirdjam number and not derived: with the lights' candela, the exposure and Unreal's own film curve as
## this port reads them, the picture comes out about six times too dark in linear light; 6.0 puts the ice and the wood
## of our stills on thirdjam's game stills (docs/shifts/2026-11-24-night/lanes/K6-arena/ROUND-1.md, "the tone gain").
## What in Unreal's chain accounts for it is an open question of this lane.
const TONE_GAIN: float = 6.0
const OPTIONS: PackedStringArray = ["rink", "goals", "crowd", "tone_gain"]
const GOAL_GROUPS: PackedStringArray = ["ArenaGoalNeg", "ArenaGoalNetNeg"]
## thirdjam's measures of the boards (RinkActor.h:59-67, RinkActor.cpp:470-518).
const BOARD_H: float = 1.2
const BOARD_T: float = 0.2
const KICK_H: float = 0.25
const KICK_PROUD: float = 0.02
const TRIM_IN: float = 0.01
const TRIM_OUT: float = 0.11
const TRIM_H: float = 0.10
## Ours: how far the rink's surfaces drawn here stand off the pack's own rink (lane K3's boards and ice, which they cover).
const SKIN: float = 0.004
const ICE_LIFT: float = 0.002
## Unreal's vignette intensity against the style grade's: thirdjam's 0.35 darkens the game still's ice by about an
## eighth from the middle of the frame to its lower corners; the grade's `vignette` does that at about 0.15.
const VIGNETTE_K: float = 0.43
## Ours, not thirdjam's (which draws no contour): where the style's contour lines end in this hall (metres).
const HALL_INK: Dictionary = {"fade_near": 10.0, "fade_far": 16.0, "outer_fade_far": 34.0, "inner_near": 8.0, "inner_far": 20.0}

static var _table: Dictionary = {}
static var _tex: Dictionary = {}


## arena.json: the pieces, thirdjam's material parameters, the rig's lights, its post settings.
static func table() -> Dictionary:
	if _table.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "arena.json"))
		if d is Dictionary:
			_table = d
		else:
			push_error("rink arena: %sarena.json does not read" % DIR)
	return _table


## Builds the hall under `parent` (rink x -> x, rink y -> z, up -> y) and returns its node, or null on an error.
static func build(parent: Node3D, opt: Dictionary = {}) -> Node3D:
	for k: String in opt:
		if not OPTIONS.has(k):
			push_error("rink arena: unknown option '%s' (known: %s)" % [k, ", ".join(OPTIONS)])
			return null
	var t: Dictionary = table()
	if t.is_empty():
		return null
	var packed: PackedScene = load(DIR + "arena.scn") as PackedScene
	if packed == null:
		push_error("rink arena: %sarena.scn does not load" % DIR)
		return null
	var root: Node3D = packed.instantiate() as Node3D
	parent.add_child(root)
	var gain: float = float(opt.get("tone_gain", TONE_GAIN))
	var r: Dictionary = rig(gain)
	TLStyleArena.set_rig(r["lights"], r["exposure"], r["gain"], r["gain_shadows"])
	# lane K7: the figures stand in the same rig. r["sky"] is not handed on: measured on thirdjam's own figure the sky
	# light adds 2 to 4.5 %, and TLStyleFelt's `sky` is a colour to draw, not the rig's description of its sky light
	TLStyleFelt.set_rig(r["lights"], r["exposure"], r["gain"], r["gain_shadows"])
	for mrow: Dictionary in (t["materials"] as Dictionary).values():
		if ((mrow.get("vectors", {}) as Dictionary).has("ClayIceBody")):
			TLStyleFelt.set_floor(_col(mrow["vectors"]["ClayIceBody"]))      # lane K7: the ice's own body colour, as the floor that lights them from below
			break
	var mats: Dictionary = {}
	for g: Dictionary in t["groups"]:
		var node: GeometryInstance3D = root.get_node_or_null(NodePath(str(g["name"]))) as GeometryInstance3D
		if node == null:
			push_error("rink arena: arena.scn has no '%s'" % g["name"])
			continue
		if node is MultiMeshInstance3D:
			# the instances are baked as a buffer on the node (build_arena.gd): a headless bake cannot fill a MultiMesh
			var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
			mm.instance_count = int(node.get_meta(&"tl_count", 0))
			mm.buffer = node.get_meta(&"tl_buffer", PackedFloat32Array())
		if (GOAL_GROUPS.has(str(g["name"])) and not bool(opt.get("goals", false))) or (str(g["mesh"]).begins_with("SM_Fan_") and not bool(opt.get("crowd", true))):
			node.visible = false
			continue
		var mesh: Mesh = (node as MeshInstance3D).mesh if node is MeshInstance3D else (node as MultiMeshInstance3D).multimesh.mesh
		var fan: bool = node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh.use_custom_data
		var names: Array = g["materials"]
		for s: int in mini(names.size(), mesh.get_surface_count()):
			var key: String = "%s|%s" % [names[s], fan]
			if not mats.has(key):
				mats[key] = material(str(names[s]), fan)
			mesh.surface_set_material(s, mats[key])
	if opt.has("rink"):
		var rk: Dictionary = opt["rink"]
		_rink_surfaces(root, float(rk["length_m"]), float(rk["width_m"]), float(rk["corner_radius_m"]))
	return root


## The rig's light and post for the installed style, once the hall is in the tree (the pack's frame 0): the style's sun
## becomes the rig's light from the roof (TLStyleHall) for the style's own materials and for the shadows on the ice,
## the grade and the ink are set for a hall (TLStyleArena.post). Headless: nothing.
static func light(anchor: Node, tone_gain: float = TONE_GAIN) -> void:
	TLStyleHall.apply(anchor, roof_light(tone_gain))
	TLStyleArena.post(anchor, hall_post())
	# K7 begin (round 3): the four key spots' own shadows on the ice (TLStyleHallKeys), in place of the style sun's one
	if TLStyleHallKeys.install(anchor, rig_lights()) > 0:
		for ice: Node in anchor.get_tree().root.find_children("RinkIce", "MeshInstance3D", true, false):
			TLStyleHallKeys.receive(ice as MeshInstance3D)
	# thirdjam draws no contour, and with the felt figures nothing in this hall is cel: the style's lines end at the eye
	# (HALL_INK kept them near the camera for the cel figures; they showed as a dark edge on a felt skater's skates and hands)
	if TLRigSkaterLook.chosen() == "felt":
		TLStyleArena.post(anchor, {"ink": {"fade_near": 0.0, "fade_far": 0.0, "outer_fade_far": 0.01, "inner_near": 0.0, "inner_far": 0.01}})
	# K7 end


## The rig as one value, for everything that must stand in the hall's light (the hall's own materials here; a figure's
## material elsewhere): `lights` (TLStyleArena.set_rig's shape, 18 spots), `exposure` (the rig's, times the tone gain),
## `gain` and `gain_shadows` (the post volume's colour gain), `sky` (the rig's sky light: `intensity`, `colour` linear;
## the hall's materials do not use it).
static func rig(tone_gain: float = TONE_GAIN) -> Dictionary:
	var t: Dictionary = table()
	var pp: Dictionary = (t["post"] as Dictionary).get("settings", {})
	var sk: Dictionary = t.get("sky", {})
	return {"lights": rig_lights(), "exposure": exposure() * tone_gain, "gain": _col(pp.get("color_gain", [1, 1, 1, 1])),
		"gain_shadows": _col(pp.get("color_gain_shadows", [1, 1, 1, 1])),
		"sky": {"intensity": float(sk.get("intensity", 0.0)), "colour": _srgb8(sk.get("color_srgb8", [255, 255, 255]))}}


## The rig's exposure: 1 / (1.2 * 2^EV100) of its post volume (PPV_P3_Clay: min = max brightness 4.2).
static func exposure() -> float:
	return float(table()["light_sum"]["exposure"])


## The rig's spot lights in TLStyleArena.set_rig's shape.
static func rig_lights() -> Array:
	var out: Array = []
	for l: Dictionary in table()["lights"]:
		out.append({"pos": _v3(l["pos"]), "dir": _v3(l["dir"]), "colour": _srgb8(l["color_srgb8"]), "candela": float(l["candela"]),
			"radius_m": float(l["radius_m"]), "inner_deg": float(l["inner_deg"]), "outer_deg": float(l["outer_deg"]), "shadows": bool(l["shadows"]),
			"source_radius_m": float(l.get("source_radius_m", 0.0))})      # K7: the last key (TLStyleHallKeys: the shadow's softness)
	return out


const ROOF_ALBEDO: float = 0.5
## What TLStyleHall.apply takes so that the style's own (toon) materials stand in the rig's light: what a surface of
## albedo ROOF_ALBEDO shows under the rig's mean illuminance on the ice (lux / pi, at the rig's exposure and tone gain,
## through the hall's film curve and grade), over that albedo, as a colour and an energy.
static func roof_light(tone_gain: float = TONE_GAIN) -> Dictionary:
	var e: Array = table()["light_sum"]["mean_lux_rgb"]
	var pp: Dictionary = (table()["post"] as Dictionary).get("settings", {})
	var k: float = exposure() * tone_gain / PI * ROOF_ALBEDO
	var shown: Color = TLStyleArena.tone(Color(float(e[0]) * k, float(e[1]) * k, float(e[2]) * k),
		_col(pp.get("color_gain", [1, 1, 1, 1])), _col(pp.get("color_gain_shadows", [1, 1, 1, 1])))
	var lin := Vector3(shown.r, shown.g, shown.b) / ROOF_ALBEDO
	var top: float = maxf(lin.x, maxf(lin.y, lin.z))
	var c := Color(lin.x / top, lin.y / top, lin.z / top).linear_to_srgb()
	return {"color": "#" + c.to_html(false), "energy": top, "shadows": true}


## What TLStyleArena.post takes for this hall. The grade: thirdjam's own post volume has no split toning and no wash
## (PPV_P3_Clay: saturation 0.95, contrast 0.95, vignette 0.35); the ink: thirdjam draws no contour at all, ours keeps
## the cel figures' line near the camera and lets it go before the far boards (HALL_INK).
static func hall_post() -> Dictionary:
	var pp: Dictionary = (table()["post"] as Dictionary).get("settings", {})
	var sat: Array = pp.get("color_saturation", [1.0, 1.0, 1.0, 1.0])
	var con: Array = pp.get("color_contrast", [1.0, 1.0, 1.0, 1.0])
	return {"grade": {"plum_density": 0.0, "olive_fill": 0.0, "split": 0.0, "sat": float(sat[0]), "contrast": float(con[0]),
			"vignette": float(pp.get("vignette_intensity", 0.0)) * VIGNETTE_K},
		"ink": HALL_INK}


## The hall answering the game (round 3, rink_react.gd: thirdjam's ARinkActor reactions and BP_ArenaCrowd's cheer): the
## goal lamps, the net's shake, the rocking board caps and pieces, the crowd standing. `anchor`: the node the hall was
## built under (or the hall itself); `rink`: thirdjam's game.rink. Call its frame(snap) every simulated frame.
##   var react = arena.reactions(ctx.root, cart["game"]["rink"])
static func reactions(anchor: Node, rink: Dictionary) -> RefCounted:
	return preload("rink_react.gd").new(anchor, rink, table(), not TLStyle.headless())


## The crowd's cheer for the end at +x / -x (0 seated .. 1 up), at a frame of the game (thirdjam: MPC_Crowd, written by
## BP_ArenaCrowd on a goal).
static func set_cheer(plus: float, minus: float, frame: int) -> void:
	TLStyleArena.set_cheer(plus, minus, float(frame) / 60.0)


## The style material of one thirdjam material (by its short name in arena.json), from thirdjam's parameters.
static func material(mname: String, fan: bool = false) -> Material:
	var m: Dictionary = (table()["materials"] as Dictionary).get(mname, {})
	var master: String = str(m.get("master", ""))
	var s: Dictionary = m.get("scalars", {})
	var v: Dictionary = m.get("vectors", {})
	match master:
		"M_ClayBarn", "M_ArenaWood":
			# BarnSurf, B26BarnWash, B36FloorSpill (M_ArenaWood = M_ClayBarn times the vertex colour as it is)
			return TLStyleArena.surface({"dark": _col(v["WoodDark"]), "light": _col(v["WoodLight"]), "grain": _texture("T_Clay_WoodGrain_M"),
				"tile_cm": float(s["TileCm"]), "grain_k": float(s["GrainK"]), "dent_k": float(s["DentK"]),
				"vertex_colour": master == "M_ArenaWood", "wash_k": float(s["WashK"]), "wash_h_cm": float(s["WashHeightCm"]),
				"wash_colour": _col(v["WashColour"]), "spill_k": float(s["SpillK"]), "spill_far": float(s["SpillFar"]),
				"spill_len_m": float(s["SpillLenM"]), "spill_colour": _col(v["SpillColour"]),
				"spill_rink": Vector4(v["SpillRink"][0], v["SpillRink"][1], v["SpillRink"][2], v["SpillRink"][3])})
		"M_ClayCrowd":
			return TLStyleArena.crowd({"tint": _col(v["Tint"]), "sat": float(s["Sat"]), "fill_k": float(s["FillK"]), "fill_low": float(s["FillLow"]),
				"fill_colour": _col(v["FillColour"]), "instanced": fan, "pose_k": float(s["PoseK"]), "wave_k": float(s["WaveK"]),
				"bounce_cm": float(s["BounceCm"])})
		"M_ClayBulb":
			return TLStyleArena.bulb({"colour": _col(v["BulbColour"]), "glow": float(s["Glow"]), "edge_k": float(s["EdgeK"])})
		"M_Toon":
			# the clay tier's path through M_Toon (hall_surface.gdshader lists the nodes); its light of its own is
			# ClayMixEmissiveFelt: (F * RimStrength * RimColour + Emissive * TeamColour) * the look's ClayFill + the felt sheen
			var team: Color = _col(v["TeamColour"])
			var fill: float = _look_scalar("ClayFill", 0.0)
			return TLStyleArena.surface({"dark": team, "light": team, "kick_h_cm": float(s["KickHeightCm"]), "kick_colour": _col(v["KickColour"]),
				"rail_band_cm": float(s["RailBandCm"]), "rail_top_cm": float(s["RailTopCm"]), "rail_colour": _col(v["RailColour"]),
				"look_tint": _look_vector("LookTint", Color(1, 1, 1)), "clay_base": _col(v["ClayBase"]), "clay_base_mix": float(s["ClayBaseMix"]),
				"board": float(s["B19Board"]), "panel_cm": float(s["PanelCm"]), "joint_cm": float(s["JointCm"]), "joint_dark": float(s["JointDark"]),
				"panel_var": float(s["PanelVar"]), "top_cm": float(s["BoardTopCm"]), "felt_rail": float(s["ClayFeltRail"]),
				"felt_band_cm": float(s["ClayFeltBandCm"]), "felt_colour": _col(v["ClayFeltColour"]),
				"emit": team * (float(s["Emissive"]) * fill), "rim": _col(v["RimColour"]) * (float(s["RimStrength"]) * fill),
				"rim_power": float(s["RimPower"]), "felt_sheen": _look_scalar("FeltRim", 0.0) * clampf(float(s["RimStrength"]) / 0.6, 0.0, 1.0),
				"wear": bool((m.get("switches", {}) as Dictionary).get("BoardWear", false)), "wear_kick_top_cm": float(s["WearKickTopCm"]),
				"wear_dirt": float(s["WearDirt"]), "wear_smear": float(s["WearSmear"]), "wear_scuff": float(s["WearScuff"]), "wear_tint": _col(v["WearTint"]),
				"clay_normal": _texture(str((m.get("textures", {}) as Dictionary).get("ClayNormalTex", "T_Clay_Thumb_N"))),
				"clay_bump": _look_scalar("ClayBump", 0.0) * float(s["ClayBumpMul"]), "clay_tile_cm": _look_scalar("ClayTile", 25.0) * float(s["ClayTileMul"])})
		"M_Trim":
			# B23TrimBase: a matte painted cap where ClayCap > 0; else the base tint, lit by the team colour's glow
			if float(s["ClayCap"]) >= 0.5:
				var cap: Color = _col(v["ClayCapColour"])     # its fill: the cap's own colour shown at ClayCapFill with no light on it
				return TLStyleArena.surface({"dark": cap, "light": cap, "emit": cap * float(s["ClayCapFill"])})
			var tintc: Color = _col(v["BaseTint"])
			return TLStyleArena.surface({"dark": tintc, "light": tintc, "emit": _col(v["TeamColour"]) * (float(s["Emissive"]) * float(s["ClayGlowMul"]))})
		"M_Ice":
			return TLStyleArena.ice({"scratch": _texture("T_Ice_Scratch_M"), "rink_hl": float(s["RinkHalfLength"]), "rink_hw": float(s["RinkHalfWidth"]),
				"corner_r": float(s["CornerRadiusCm"]), "goal_off": float(s["GoalLineOffsetCm"]), "blue_frac": float(s["BlueLineFrac"]),
				"scratch_tile": float(s["ScratchTileCm"]), "scratch_amt": float(s["ScratchAmt"]), "scratch_slot": float(s["ScratchSlot"]),
				"scratch_far": float(s["ScratchFar"]), "scratch_lift": float(s["ScratchLift"]), "snow_w": float(s["SnowWidthCm"]),
				"snow_amt": float(s["SnowAmt"]), "line_soft": float(s["LineSoftCm"]), "line_under": float(s["LineUnder"]),
				"body": _col(v["ClayIceBody"]), "scratch_colour": _col(v["ClayScratchColour"]), "snow_colour": _col(v["ClaySnowColour"]),
				"line_red": _col(v["ClayLineRed"]), "line_blue": _col(v["ClayLineBlue"]),
				"pool_key_x": Vector2(v["PoolKeyX"][0], v["PoolKeyX"][1]), "pool_key_z": float(s["PoolKeyZ"]),
				"pool_inner_deg": float(s["PoolInnerDeg"]), "pool_outer_deg": float(s["PoolOuterDeg"]), "pool_tint": _col(v["PoolTint"]),
				"pool_dim": float(s["PoolDim"]), "contact_cm": float(s["ContactCm"]), "contact_k": float(s["ContactK"]),
				"band_cm": float(s["BoardBandCm"]), "band_k": float(s["BoardBandK"]), "band_colour": _col(v["BoardBandColour"]),
				"lamp_a": Vector3(v["LampA"][0], v["LampA"][1], v["LampA"][2]), "lamp_b": Vector3(v["LampB"][0], v["LampB"][1], v["LampB"][2]),
				"sheen": Vector4(v["LampSheen"][0], v["LampSheen"][1], v["LampSheen"][2], v["LampSheen"][3]),
				"sheen_colour": _col(v["LampSheenColour"]), "spec": float(s["ClayIceSpec"])})
	push_warning("rink arena: no style material for '%s' (master '%s'): drawn in a plain grey" % [mname, master])
	return TLStyleArena.surface({"dark": Color(0.2, 0.2, 0.2), "light": Color(0.2, 0.2, 0.2)})


## The rink's own surfaces as the clay tier dresses them, drawn over the pack's rink (lane K3's gen/tj_rink.gd builds
## the same shapes in the style's palette): thirdjam's ARinkActor wears /JamAssets/Look materials on them
## (arena.json "rink_surfaces"), and a place is its surfaces. Shapes from RinkActor.cpp:444-518 round ARinkActor::Outline:
##   Ice         the sheet inside the outline, ICE_LIFT over the pack's ice and under its markings (0.6 cm);
##   Boards      the inner face above the kick plate, the top and the outer face, SKIN proud of the pack's boards;
##   KickPlate   the 25 cm band 2 cm proud of the inner face, and its top lip;
##   Trim        the 10 cm strip on the board top's inner edge (1 cm to 11 cm outward of the outline).
static func _rink_surfaces(root: Node3D, L: float, W: float, R: float) -> void:
	var rs: Dictionary = table().get("rink_surfaces", {})
	var line: Array = outline(L, W, R, 12)
	var ice := SurfaceTool.new()
	var boards := SurfaceTool.new()
	var kick := SurfaceTool.new()
	var trim := SurfaceTool.new()
	for st: SurfaceTool in [ice, boards, kick, trim]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in line.size():
		var p0: Vector2 = line[i]
		var p1: Vector2 = line[(i + 1) % line.size()]
		var dirv: Vector2 = (p1 - p0).normalized()
		var out := Vector2(dirv.y, -dirv.x)                       # outward of a counter-clockwise outline (RinkActor.cpp:479)
		var n_in := Vector3(-out.x, 0, -out.y)
		var n_out := Vector3(out.x, 0, out.y)
		_tri(ice, Vector3(0, ICE_LIFT, 0), _g(p0, ICE_LIFT), _g(p1, ICE_LIFT), Vector3.UP)
		var a0: Vector2 = p0 - out * SKIN
		var a1: Vector2 = p1 - out * SKIN
		var b0: Vector2 = p0 + out * (BOARD_T + SKIN)
		var b1: Vector2 = p1 + out * (BOARD_T + SKIN)
		_quad(boards, _g(a0, KICK_H), _g(a1, KICK_H), _g(a1, BOARD_H), _g(a0, BOARD_H), n_in)
		_quad(boards, _g(a0, BOARD_H + SKIN), _g(a1, BOARD_H + SKIN), _g(b1, BOARD_H + SKIN), _g(b0, BOARD_H + SKIN), Vector3.UP)
		_quad(boards, _g(b0, 0.0), _g(b1, 0.0), _g(b1, BOARD_H), _g(b0, BOARD_H), n_out)
		var k0: Vector2 = p0 - out * (KICK_PROUD + SKIN)
		var k1: Vector2 = p1 - out * (KICK_PROUD + SKIN)
		_quad(kick, _g(k0, 0.0), _g(k1, 0.0), _g(k1, KICK_H), _g(k0, KICK_H), n_in)
		_quad(kick, _g(k0, KICK_H + SKIN), _g(k1, KICK_H + SKIN), _g(a1, KICK_H + SKIN), _g(a0, KICK_H + SKIN), Vector3.UP)
		var i0: Vector2 = p0 + out * TRIM_IN
		var i1: Vector2 = p1 + out * TRIM_IN
		var o0: Vector2 = p0 + out * TRIM_OUT
		var o1: Vector2 = p1 + out * TRIM_OUT
		var h0: float = BOARD_H + SKIN
		var h1: float = BOARD_H + TRIM_H
		_quad(trim, _g(i0, h1), _g(i1, h1), _g(o1, h1), _g(o0, h1), Vector3.UP)
		_quad(trim, _g(i0, h0), _g(i1, h0), _g(i1, h1), _g(i0, h1), n_in)
		_quad(trim, _g(o0, h0), _g(o1, h0), _g(o1, h1), _g(o0, h1), n_out)
	for row: Array in [["Ice", ice, "MID_MI_Ice_Night_0"], ["Boards", boards, "MI_Toon_Board"], ["KickPlate", kick, "MI_Toon_KickPlate"],
			["Trim", trim, "MID_MI_Trim_Blue_0"]]:
		var mname: String = str(row[2])
		var listed: Array = (rs.get(row[0], {}) as Dictionary).get("materials", [])
		if not listed.is_empty():
			mname = str(listed[0])
		var mesh := ArrayMesh.new()
		(row[1] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(0, material(mname))
		var mi := MeshInstance3D.new()
		mi.name = "Rink" + str(row[0])
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


## ARinkActor::Outline (RinkActor.cpp:416-432): counter-clockwise in rink (x, y), corner arcs of `segs` segments.
static func outline(L: float, W: float, R: float, segs: int) -> Array:
	var out: Array = []
	var hx: float = L * 0.5
	var hy: float = W * 0.5
	var rc: float = clampf(R, 0.0, minf(hx, hy))
	var centres: Array = [Vector2(hx - rc, hy - rc), Vector2(-(hx - rc), hy - rc), Vector2(-(hx - rc), -(hy - rc)), Vector2(hx - rc, -(hy - rc))]
	for c: int in 4:
		var start: float = float(c) * PI * 0.5
		var n: int = segs if rc > 0.0 else 1
		for i: int in n + 1:
			var a: float = start + (PI * 0.5) * float(i) / float(n)
			out.append((centres[c] as Vector2) + Vector2(cos(a), sin(a)) * rc)
	return out


static func _g(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x, h, p.y)


## A triangle and a quad given by their corners and the way they face; Godot's front face winds clockwise.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	var pts: Array = [a, c, b] if (b - a).cross(c - a).dot(n) > 0.0 else [a, b, c]
	for p: Vector3 in pts:
		st.set_normal(n)
		st.add_vertex(p)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)


## A texture of the core (tex/<name>.png) with mipmaps, read as data (no colour space change); null headless.
static func _texture(tname: String) -> Texture2D:
	if TLStyle.headless():
		return null
	if not _tex.has(tname):
		var path: String = DIR + "tex/" + tname + ".png"
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			path = "res://style/felt/" + tname + ".png"      # the look's clay normal maps live once, in style (lane K7)
		var img: Image = null
		if ResourceLoader.exists(path):
			var t: Texture2D = load(path) as Texture2D
			img = t.get_image() if t != null else null
		if img == null:
			img = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			push_error("rink arena: %s does not load" % path)
			return null
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		_tex[tname] = ImageTexture.create_from_image(img)
	return _tex[tname]


static func _look() -> Dictionary:
	return (table()["collections"] as Dictionary).get("/JamAssets/Look/MPC_Look", {})


## thirdjam's look collection (MPC_Look) as the clay rig had set it in the running game.
static func _look_scalar(pname: String, fallback: float) -> float:
	var row: Dictionary = (_look().get("scalars", {}) as Dictionary).get(pname, {})
	return float(row.get("now", fallback))


static func _look_vector(pname: String, fallback: Color) -> Color:
	var row: Dictionary = (_look().get("vectors", {}) as Dictionary).get(pname, {})
	return _col(row["now"]) if row.has("now") else fallback


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _col(a: Array) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]))


static func _srgb8(a: Array) -> Color:
	return Color(float(a[0]) / 255.0, float(a[1]) / 255.0, float(a[2]) / 255.0).srgb_to_linear()
