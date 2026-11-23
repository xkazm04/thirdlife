extends SceneTree
## Headless checks of the skater's look (selftest block 850, engine/tools/selftest.d/850-skater-look.sh):
##   godot --headless --path engine --script res://rigs/skater/look/look_case.gd
## One line per case: `LOOK <case> ok=true|false <what was measured>`.
##   numbers    the ten skaters of a match (HokejGameMode.cpp:439-444: blue 7 13 42, orange 9 21 88, then team x 10 +
##              slot + 1) reach the jersey and the back patch as tens and ones, the crest follows the team
##   instances  every number the look carries is thirdjam's: each slot's parameters against the material instances as
##              the Unreal editor reports them (rigs/skater/source/meta.json), the helmet's colour x 0.75
##   shader     every key TLStyleFelt takes, the look collection and the rig are uniforms of body_felt.gdshader, and
##              every key the look sets is one TLStyleFelt takes
##   variants   felt and cel on one figure, each slot given a material, set_look switches, the baked mesh is untouched

const SLOTS: Array = ["Pads", "Jersey", "Trim", "Skin", "Helmet", "Gloves", "Skate", "Blade", "Stick"]
## the look's key -> thirdjam's material parameter (scalars; vectors are named in the case)
const PARAM: Dictionary = {"rim_strength": "RimStrength", "emissive": "Emissive", "vcol_mix": "VColMix", "felt_mix": "FeltMix",
	"felt_tile": "FeltTile", "felt_bump": "FeltBump", "felt_mottle_tile": "FeltMottleTile", "felt_mottle": "FeltMottle",
	"felt_darken": "FeltDarken", "hem_z0": "HemZ0", "hem_z1": "HemZ1", "hem_k": "HemK", "sheen_white": "SheenWhite",
	"number_back_mask": "NumberBackMask", "number_on": "NumberOn", "crest_on": "CrestOn", "clay_tile_mul": "ClayTileMul"}


func _init() -> void:
	_numbers()
	_instances()
	_shader()
	_variants()
	quit(0)


func _say(case: String, ok: bool, text: String) -> void:
	print("LOOK %s ok=%s %s" % [case, "true" if ok else "false", text])


func _numbers() -> void:
	var want: Array = [[7, 13, 42, 4, 5], [9, 21, 88, 14, 15]]
	var bad: Array = []
	var seen: Array = []
	for team: int in range(2):
		for slot: int in range(5):
			var n: int = int(want[team][slot])
			var j: Dictionary = TLRigSkaterLook.felt_params("Jersey", team, Color(0.1, 0.2, 0.3), n)
			var t: Dictionary = TLRigSkaterLook.felt_params("Trim", team, Color(0.1, 0.2, 0.3), n)
			var got: int = int(t["number_tens"]) * 10 + int(t["number_ones"])
			seen.append(got)
			if got != n or int(j["number_tens"]) * 10 + int(j["number_ones"]) != n:
				bad.append("number %d read %d" % [n, got])
			if float(t["number_on"]) != 2.0 or float(j["number_on"]) != 1.0 or float(j["number_back_mask"]) != -2.0:
				bad.append("number switches of %d" % n)
			if float(j["crest_team"]) != float(team) or float(j["crest_on"]) != 1.0 or float(t["crest_on"]) != 0.0:
				bad.append("crest of team %d" % team)
	if TLRigSkaterLook.digits(123) != Vector2i(9, 9) or TLRigSkaterLook.digits(-4) != Vector2i(0, 0):
		bad.append("clamp")
	_say("numbers", bad.is_empty(), "skaters=%d numbers=%s%s" % [seen.size(), str(seen), "" if bad.is_empty() else " bad=" + str(bad)])


func _near(have: Variant, want: Variant) -> bool:
	if want == null:
		return false
	if have is Color:
		return (have as Color).is_equal_approx(want as Color)
	if have is Vector2:
		return (have as Vector2).is_equal_approx(want as Vector2)
	if have is Vector3:
		return (have as Vector3).is_equal_approx(want as Vector3)
	return is_equal_approx(float(have), float(want))


func _instances() -> void:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://rigs/skater/source/meta.json"))
	var rows: Array = (meta as Dictionary).get("materials", []) if meta is Dictionary else []
	var bad: Array = []
	var compared: int = 0
	var slots: int = 0
	for row: Dictionary in rows:
		var slot: String = String(row["slot"])
		var sc: Dictionary = row["scalars"]
		var ve: Dictionary = row["vectors"]
		var look: Dictionary = TLRigSkaterLook.FELT.get(slot, {})
		slots += 1
		var jersey: bool = String(row["parent"]).ends_with("M_SkaterTB1Jersey")
		for k: String in look:
			var want: Variant = null
			match k:
				"sheen_tint": want = Color(ve["SheenTint"][0], ve["SheenTint"][1], ve["SheenTint"][2])
				"crest_yzs": want = Vector3(sc["CrestY"], sc["CrestZ"], sc["CrestSize"])
				"number_centre": want = Vector2(sc["NumberCentreU"], sc["NumberCentreV"])
				"number_cell": want = Vector2(sc["NumberWidth"], sc["NumberHeight"])
				"clay_bump_scale": want = float(sc["ClayBumpScale" if jersey else "ClayBumpMul"])
				"clay_normal": continue          # a texture: read by look_reference.py, not in meta.json
				_: want = float(sc[PARAM[k]]) if PARAM.has(k) and sc.has(PARAM[k]) else null
			compared += 1
			if not _near(look[k], want):
				bad.append("%s.%s %s != %s" % [slot, k, str(look[k]), str(want)])
		# a felt slot names every switch itself (the shader's defaults are the clay master's)
		if jersey:
			for k: String in ["felt_mix", "vcol_mix", "felt_mottle", "sheen_white", "sheen_tint", "emissive", "rim_strength", "number_on", "crest_on"]:
				if not look.has(k):
					bad.append("%s leaves %s to the default" % [slot, k])
		if slot != "Jersey" and slot != "Helmet":
			compared += 1
			var c: Color = TLRigSkaterLook.SLOT_LINEAR.get(slot, Color(-1, -1, -1))
			if not c.is_equal_approx(Color(ve["TeamColour"][0], ve["TeamColour"][1], ve["TeamColour"][2])):
				bad.append("%s colour" % slot)
	var team: Color = Color(0.2, 0.4, 0.8)
	var helmet: Color = TLRigSkaterLook.slot_colour("Helmet", team)
	if not helmet.is_equal_approx(Color(0.15, 0.3, 0.6)) or not TLRigSkaterLook.slot_colour("Jersey", team).is_equal_approx(team):
		bad.append("team colours")
	_say("instances", bad.is_empty() and slots == 9 and compared > 60, "slots=%d values=%d%s" % [slots, compared, "" if bad.is_empty() else " bad=" + str(bad)])


func _shader() -> void:
	var text: String = FileAccess.get_file_as_string(TLStyleFelt.SHADER_PATH)
	var missing: Array = []
	var names: Array = TLStyleFelt.KEYS.keys()
	names.append_array(TLStyleFelt.LOOK.keys())
	names.append_array(["rig_n", "rig_pos", "rig_dir", "rig_col", "rig_exposure", "rig_gain", "rig_gain_shadows", "sky_fill", "felt_fibre"])
	var rx: RegEx = RegEx.new()
	for n: String in names:
		rx.compile("(?m)^uniform\\s+\\w+\\s+%s\\b" % n)
		if rx.search(text) == null:
			missing.append(n)
	var foreign: Array = []
	for slot: String in TLRigSkaterLook.FELT:
		for k: String in TLRigSkaterLook.FELT[slot] as Dictionary:
			if not TLStyleFelt.KEYS.has(k):
				foreign.append("%s.%s" % [slot, k])
	for k: String in TLRigSkaterLook.felt_params("Jersey", 1, Color(1, 1, 1), 42):
		if not TLStyleFelt.KEYS.has(k):
			foreign.append("Jersey." + k)
	var ok: bool = text != "" and missing.is_empty() and foreign.is_empty()
	_say("shader", ok, "uniforms=%d%s%s" % [names.size(), "" if missing.is_empty() else " missing=" + str(missing), "" if foreign.is_empty() else " not_keys=" + str(foreign)])


func _variants() -> void:
	var bad: Array = []
	var sk: TLRigSkater = TLRigSkater.new()
	sk.setup({"team": 1})
	sk.SetNumber(21)
	var mi: MeshInstance3D = sk.mesh_instance()
	var base: Mesh = mi.mesh
	var names: Array = []
	for s: int in range(base.get_surface_count()):
		names.append(base.surface_get_name(s))
	if names != SLOTS:
		bad.append("slots %s" % str(names))
	for v: String in ["felt", "cel", "felt"]:
		sk.set_look(v)
		if String(sk.get("_look")) != v:
			bad.append("look %s is %s" % [v, str(sk.get("_look"))])
		for s: int in range(base.get_surface_count()):
			if mi.get_surface_override_material(s) == null:
				bad.append("%s: slot %s has no material" % [v, names[s]])
		if mi.mesh.get_surface_count() != 9:
			bad.append("%s: %d surfaces" % [v, mi.mesh.get_surface_count()])
	# the baked mesh keeps no rest pose of its own (the look adds it to a copy when it draws); the copy keeps the vertices
	var copy: Mesh = TLRigSkaterLook.look_mesh(base)
	var same: int = 0
	var verts: int = 0
	for s: int in range(base.get_surface_count()):
		var a: Array = base.surface_get_arrays(s)
		var b: Array = copy.surface_get_arrays(s)
		verts += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var eq: bool = a[Mesh.ARRAY_VERTEX] == b[Mesh.ARRAY_VERTEX] and a[Mesh.ARRAY_INDEX] == b[Mesh.ARRAY_INDEX]
		eq = eq and a[Mesh.ARRAY_BONES] == b[Mesh.ARRAY_BONES] and a[Mesh.ARRAY_WEIGHTS] == b[Mesh.ARRAY_WEIGHTS]
		eq = eq and a[Mesh.ARRAY_TEX_UV] == b[Mesh.ARRAY_TEX_UV] and a[Mesh.ARRAY_CUSTOM1] == b[Mesh.ARRAY_CUSTOM1]
		eq = eq and b[Mesh.ARRAY_CUSTOM0] != null and b[Mesh.ARRAY_CUSTOM2] != null and a[Mesh.ARRAY_CUSTOM0] == null
		eq = eq and copy.surface_get_name(s) == base.surface_get_name(s)
		if eq:
			same += 1
	if same != 9:
		bad.append("copy: %d of 9 surfaces equal" % same)
	if mi.mesh != base:
		bad.append("headless: the figure's mesh was swapped")
	if not TLRigSkaterLook.VARIANTS.has(TLRigSkaterLook.chosen()):
		bad.append("chosen")
	sk.free()
	_say("variants", bad.is_empty(), "looks=felt,cel slots=%d vertices=%d copy_equal=%d%s" % [names.size(), verts, same, "" if bad.is_empty() else " bad=" + str(bad)])
