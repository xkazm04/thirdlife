extends SceneTree
## Diorama night (20 Nov 2026), surfaces: the headless cases of selftest block 580 (engine/tools/selftest.d/580-surf.sh).
## One line per case: SURF <case> ok|failed <what was measured>.
##   classic_source  toon.gdshader with every TL_DIORAMA branch taken out is, byte for byte, the shader of diorama-base
##                   (--sha=<sha256 of that file>): the look of TL_STYLE=classic cannot have moved through this file
##   model           TL_STYLE unset: the diorama model and resin water are named; TL_STYLE=classic (--classic): no key of the
##                   diorama model is present, so TLStyle hands out the shader file as it is
##   edges           a TLMesh box writes the place on each face into UV2 (whole part = the face size in cm, fraction =
##                   the place), the side of a cylinder its round normal (both numbers under 1), its flat ends nothing; content_hash is what it was before UV2 existed (--box=<hash taken on diorama-base>)
##   keys            the new material keys are accepted, an unknown one is still an error

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var classic: bool = args.has("--classic")
	var want_sha: String = ""
	var want_box: String = ""
	for a: String in args:
		if a.begins_with("--sha="):
			want_sha = a.trim_prefix("--sha=")
		if a.begins_with("--box="):
			want_box = a.trim_prefix("--box=")
	_classic_source(want_sha)
	_model(classic)
	_edges(want_box)
	_keys()
	quit(0)


## The text of a shader with the TL_DIORAMA branches removed: what the preprocessor leaves when the name is not defined.
static func without_diorama(text: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	var stack: Array = []      # per open #if: [is the diorama test, are we in its #else part, was the outside kept]
	var keep: bool = true
	for line: String in text.split("\n"):
		var t: String = line.strip_edges()
		if t.begins_with("#ifdef") or t.begins_with("#ifndef") or t.begins_with("#if "):
			var dio: bool = t == "#ifdef TL_DIORAMA"
			stack.append([dio, false, keep])
			if dio:
				keep = false
				continue
		elif t == "#else" and not stack.is_empty():
			var top: Array = stack.back()
			if top[0]:
				top[1] = true
				keep = top[2]
				continue
		elif t == "#endif" and not stack.is_empty():
			var top2: Array = stack.pop_back()
			if top2[0]:
				keep = top2[2]
				continue
		if keep:
			out.append(line)
	return "\n".join(out)


func _classic_source(want: String) -> void:
	var text: String = FileAccess.get_file_as_string("res://style/shaders/toon.gdshader").replace("\r\n", "\n")
	var classic: String = without_diorama(text)
	var sha: String = classic.sha256_text()
	var ok: bool = sha == want and not classic.contains("TL_DIORAMA") and not classic.contains("g_dio")
	print("SURF classic_source %s sha256=%s want=%s lines=%d diorama_lines=%d" % ["ok" if ok else "failed", sha, want,
		classic.count("\n"), text.count("\n") - classic.count("\n")])


func _model(classic: bool) -> void:
	TLStyle.set_headless(true)
	var hard: int = 0
	for p: String in TLStyle.load_style(TLStyle._chosen_path()):
		if not p.begins_with("clamped: "):
			hard += 1
	var model: String = String((TLStyle.data.get("toon", {}) as Dictionary).get("model", ""))
	var water: String = String((TLStyle.data.get("water", {}) as Dictionary).get("model", ""))
	var dio_keys: int = 0
	for k: String in (TLStyle.data.get("mat", {}) as Dictionary):
		for mk: String in ["gloss", "fuzz", "chip"]:
			if (TLStyle.data["mat"][k] as Dictionary).has(mk):
				dio_keys += 1
		if String((TLStyle.data["mat"][k] as Dictionary).get("class", "")) in ["clay", "felt"]:
			dio_keys += 1
	var ok: bool = hard == 0
	if classic:
		ok = ok and model == "" and water == "" and dio_keys == 0 and not (TLStyle.data.get("detail", {}) as Dictionary).has("bevel")
	else:
		ok = ok and model == "diorama" and water == "resin" and dio_keys > 0
	print("SURF model %s style=%s model='%s' water='%s' diorama_mat_keys=%d errors=%d" % ["ok" if ok else "failed",
		TLStyle.style_name, model, water, dio_keys, hard])


func _edges(want: String) -> void:
	TLStyle.set_headless(true)
	var mk: TLMesh = TLMesh.new(1)
	mk.box(Vector3(2.0, 1.0, 0.5), "wood")
	mk.push_at(Vector3(3.0, 0.0, 0.0), Vector3(0.0, 30.0, 0.0))
	mk.box(Vector3(0.3, 0.3, 4.0), "steel", Color.WHITE, 0.0, Vector3(0.0, 1.0, 0.0))
	mk.pop()
	mk.cyl(0.4, 1.0, 8, "wood")
	var s: TLMesh.Surf = mk.surfs["wood"]
	var st: TLMesh.Surf = mk.surfs["steel"]
	var sizes: Dictionary = {}
	var bad: int = 0
	var marked: int = 0
	var round_n: int = 0
	var round_off: int = 0
	for k: int in s.uv2.size():
		var e: Vector2 = s.uv2[k]
		if e == Vector2.ZERO:
			continue
		if e.x < 1.0 and e.y < 1.0:
			# the side of the cylinder: the unit normal lies in the ground plane and points away from the axis
			round_n += 1
			var n2: Vector2 = (e - Vector2(0.5, 0.5)) / 0.45
			var away: Vector2 = Vector2(s.v[k].x, s.v[k].z).normalized()
			if absf(n2.length() - 1.0) > 0.01 or n2.dot(away) < 0.99:
				round_off += 1
			continue
		marked += 1
		sizes[int(floor(e.x))] = true
		sizes[int(floor(e.y))] = true
		var fx: float = e.x - floor(e.x)
		var fy: float = e.y - floor(e.y)
		# a corner of a face: both fractions are at an end
		if not ((absf(fx - 0.002) < 0.0005 or absf(fx - 0.998) < 0.0005) and (absf(fy - 0.002) < 0.0005 or absf(fy - 0.998) < 0.0005)):
			bad += 1
	var keys: Array = sizes.keys()
	keys.sort()
	var steel_sizes: Dictionary = {}
	for e2: Vector2 in st.uv2:
		steel_sizes[int(floor(e2.x))] = true
		steel_sizes[int(floor(e2.y))] = true
	var sk: Array = steel_sizes.keys()
	sk.sort()
	var hash_now: String = mk.content_hash()
	var ok: bool = marked == 36 and bad == 0 and keys == [50, 100, 200] and sk == [30, 400] and s.uv2.size() <= s.v.size() \
		and round_n == 48 and round_off == 0 and (want.is_empty() or hash_now == want)
	print("SURF edges %s box_corners=%d off_corner=%d face_cm=%s rotated_bar_cm=%s cylinder_side=%d not_radial=%d uv2=%d of %d vertices content_hash=%s want=%s" % [
		"ok" if ok else "failed", marked, bad, str(keys), str(sk), round_n, round_off, s.uv2.size(), s.v.size(), hash_now, want])


func _keys() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://style/style_diorama.json"))
	var clean: int = 0
	for p: String in TLStyle.check(d.duplicate(true)):
		if not p.begins_with("clamped: "):
			clean += 1
	var d2: Dictionary = d.duplicate(true)
	d2["mat"]["wood"]["glos"] = 0.5
	var caught: int = 0
	for p: String in TLStyle.check(d2):
		if p.contains("mat.wood.glos"):
			caught += 1
	var d3: Dictionary = d.duplicate(true)
	d3["mat"]["wood"]["class"] = "velvet"
	for p: String in TLStyle.check(d3):
		if p.contains("mat.wood.class"):
			caught += 1
	var ok: bool = clean == 0 and caught == 2
	print("SURF keys %s diorama_file_errors=%d unknown_key_and_class_caught=%d of 2" % ["ok" if ok else "failed", clean, caught])
