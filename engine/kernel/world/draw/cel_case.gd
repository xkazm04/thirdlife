extends SceneTree
## Crisp cel (day of 20 Nov 2026), surfaces: the headless cases of selftest block 610 (engine/tools/selftest.d/610-celsurf.sh).
## One line per case: CEL <case> ok|failed <what was measured>.
##   classic_files  toon.gdshader, water.gdshader and style.json are, byte for byte, the files of the day's base
##                  (--toon=, --water=, --style= sha256 of each, line ends as LF): the look of TL_STYLE=classic cannot
##                  have moved through them; the cel model lives in files of its own
##   model          TL_STYLE=crisp: the cel model and cel water are named, and the style file has no errors;
##                  TL_STYLE=classic (--classic): no key of the cel model is present
##   pic_key        the picture cache key carries the paints a kit terrain bakes into vertex colours when they are not
##                  today's: nothing under TL_STYLE=classic (today's key byte-equal), the paints under TL_STYLE=crisp
##   palette        style_crisp.json has the palette keys of style.json, same names, same order (kit hashes and the
##                  lookup texture depend on the columns)
##   globals        every shader global the cel shaders declare is one TLStyle registers, and the eight land paints
##                  are palette keys
##   rails          terrain/road_rails.gd on a small landscape: a row on both sides of the road, in pieces that are not
##                  drawn where a rail would be thinner than three quarters of a pixel, no collision
##                  object, a gap on the spur's side at the spur's mouth and none across the road from it; nothing at all
##                  without the key (offset 0); the key is named by style_crisp.json and not by style.json
##   paint          the land painted by numbers, on the CPU as the shader does it: along the blend from grass to road the
##                  paint goes from a grass to an earth and is never a rock on level ground; on a steep face rock wins

const CEL_TOON: PackedStringArray = ["cel_shadow", "cel_chroma", "cel_deep", "cel_rim", "cel_top", "cel_top_k", "cel_wind", "cel_rock_shade", "cel_cloud"]
const CEL_DETAIL: PackedStringArray = ["edge", "land_wobble", "marks_m", "patch", "verge_m", "land_bias", "flowers", "land_flat", "marks_far", "pine_teeth", "land_dead", "strata_cream", "road_rails", "tree_shade"]
const _Cel: GDScript = preload("res://style/cel/cel_surfaces.gd")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var want: Dictionary = {}
	for a: String in args:
		for k: String in ["toon", "water", "style"]:
			if a.begins_with("--%s=" % k):
				want[k] = a.trim_prefix("--%s=" % k)
	TLStyle.set_headless(true)
	_classic_files(want)
	_model(args.has("--classic"))
	_pic_key(args.has("--classic"))
	_palette()
	_globals()
	_paint()
	_rails()
	quit(0)


func _sha(path: String) -> String:
	return FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()


func _classic_files(want: Dictionary) -> void:
	var got: Dictionary = {"toon": _sha("res://style/shaders/toon.gdshader"), "water": _sha("res://style/shaders/water.gdshader"), "style": _sha("res://style/style.json")}
	var moved: PackedStringArray = PackedStringArray()
	for k: String in got:
		if String(want.get(k, "")) != String(got[k]):
			moved.append("%s sha256=%s want=%s" % [k, got[k], want.get(k, "")])
	print("CEL classic_files %s %s" % ["ok" if moved.is_empty() else "failed", "toon.gdshader, water.gdshader, style.json as on the base" if moved.is_empty() else "; ".join(moved)])


func _model(classic: bool) -> void:
	var hard: int = 0
	var clamped: int = 0
	for p: String in TLStyle.load_style(TLStyle._chosen_path()):
		if p.begins_with("clamped: "):
			clamped += 1          # a value outside its looked-at range: the file says one thing and the picture shows another
		else:
			hard += 1
	var toon: Dictionary = TLStyle.data.get("toon", {})
	var detail: Dictionary = TLStyle.data.get("detail", {})
	var model: String = String(toon.get("model", ""))
	var water: String = String((TLStyle.data.get("water", {}) as Dictionary).get("model", ""))
	var cel_keys: int = 0
	for k: String in CEL_TOON:
		cel_keys += int(toon.has(k))
	for k: String in CEL_DETAIL:
		cel_keys += int(detail.has(k))
	var ok: bool = hard == 0 and clamped == 0
	if classic:
		ok = ok and model == "" and water == "" and cel_keys == 0
	else:
		ok = ok and model == "cel" and water == "cel" and cel_keys > 0
	print("CEL model %s style=%s file=%s model='%s' water='%s' cel_keys=%d errors=%d clamped=%d" % ["ok" if ok else "failed", TLStyle.style_name,
		TLStyle.style_path.get_file(), model, water, cel_keys, hard, clamped])


func _pic_key(classic: bool) -> void:
	var salt: String = preload("res://kernel/world/draw/pic_salt.gd").salt()
	var ok: bool = salt.is_empty() if classic else salt.begins_with("|paints:#")
	print("CEL pic_key %s style=%s salt='%s'" % ["ok" if ok else "failed", TLStyle.style_path.get_file(), salt.left(40)])


func _palette() -> void:
	var a: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://style/style.json"))
	var b: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://style/style_crisp.json"))
	var ka: Array = (a["palette"] as Dictionary).keys()
	var kb: Array = (b["palette"] as Dictionary).keys()
	var changed: int = 0
	for k: String in ka:
		if kb.has(k) and String(a["palette"][k]) != String(b["palette"][k]):
			changed += 1
	var ok: bool = ka == kb
	print("CEL palette %s keys=%d crisp_keys=%d same_names_and_order=%s colours_changed=%d" % ["ok" if ok else "failed", ka.size(), kb.size(), str(ka == kb), changed])


func _declared(file: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(file).split("\n"):
		var t: String = line.strip_edges()
		if t.begins_with("global uniform"):
			out.append(t.get_slice(";", 0).split(" ")[-1])
	return out


func _globals() -> void:
	TLStyle.load_style("res://style/style_crisp.json")
	var cel: Dictionary = _Cel.globals(TLStyle.data)
	# what TLStyle registers: its own list (read from the source: the names are literals there), the diorama's, the cel's
	var known: Dictionary = {}
	var src: String = FileAccess.get_file_as_string("res://style/tl_style.gd") + FileAccess.get_file_as_string("res://style/dio/style_dio.gd")
	var rx: RegEx = RegEx.new()
	rx.compile("\"(g_[a-z0-9_]+)\"")
	for m: RegExMatch in rx.search_all(src):
		known[m.get_string(1)] = true
	for k: String in cel:
		known[k] = true
	var missing: PackedStringArray = PackedStringArray()
	var declared: int = 0
	for f: String in ["res://style/shaders/toon_cel.gdshader", "res://style/shaders/water_cel.gdshader"]:
		for g: String in _declared(f):
			declared += 1
			if not known.has(g):
				missing.append(g)
	var paints: int = 0
	for k: String in _Cel.LAND:
		paints += int(TLStyle.has_key(k))
	var ok: bool = missing.is_empty() and declared > 20 and paints == 8 and cel.size() == 15
	print("CEL globals %s declared=%d not_registered=%s cel_globals=%d land_paints_in_palette=%d of 8" % ["ok" if ok else "failed", declared, str(missing), cel.size(), paints])


## toon_cel.gdshader's choice of a paint for a pigment, without the wobble: the index into _Cel.LAND.
func _nearest(pig: Color, ny: float, g: Dictionary) -> int:
	var level: float = 0.16 * smoothstep(0.72, 0.86, ny)
	var face: float = 0.18 * (1.0 - smoothstep(0.72, 0.90, ny))
	var best: int = 0
	var bd: float = 1e9
	for i: int in 8:
		var v: Vector4 = g["g_land%d" % i]
		var d: float = Vector3(pig.r, pig.g, pig.b).distance_to(Vector3(v.x, v.y, v.z)) - v.w + (level if i >= 5 else (face if i >= 3 else 0.0))
		if d < bd:
			bd = d
			best = i
	return best


func _paint() -> void:
	TLStyle.load_style("res://style/style_crisp.json")
	var g: Dictionary = _Cel.globals(TLStyle.data)
	var c: Dictionary = {}
	for k: String in _Cel.LAND:
		c[k] = TLStyle.color(k)
	# the village's own blend (village_terrain.gd _col): meadow grass into a worn road, on level ground
	var grass: Color = (c["grass_dark"] as Color).lerp(c["grass"], 0.75)
	var road: Color = (c["dirt"] as Color).lerp(c["sand"], 0.17)
	var seq: PackedInt32Array = PackedInt32Array()
	var rock_on_level: int = 0
	var back: int = 0
	for k: int in 41:
		var t: float = float(k) / 40.0
		var p: int = _nearest(grass.lerp(road, t * 0.9).srgb_to_linear(), 1.0, g)
		if p >= 5:
			rock_on_level += 1
		if seq.size() > 0 and p < 3 and seq[seq.size() - 1] >= 3:
			back += 1
		if seq.is_empty() or seq[seq.size() - 1] != p:
			seq.append(p)
	var rock: Color = (c["rock"] as Color).lerp(c["cliff"], 0.5)
	var steep: int = _nearest(grass.lerp(rock, 0.8).srgb_to_linear(), 0.6, g)
	var names: PackedStringArray = PackedStringArray()
	for p: int in seq:
		names.append(_Cel.LAND[p])
	var ok: bool = rock_on_level == 0 and back == 0 and seq[0] < 3 and (seq[seq.size() - 1] == 3 or seq[seq.size() - 1] == 4) and steep >= 5
	print("CEL paint %s grass_to_road=%s rock_on_level=%d back_to_grass=%d steep_face=%s" % ["ok" if ok else "failed", ">".join(names), rock_on_level, back, _Cel.LAND[steep]])


func _rails() -> void:
	var terr: RefCounted = (preload("res://kernel/world/terrain/village_terrain.gd") as GDScript).new(7, Rect2(-150, -100, 300, 200), 3.0)
	var road: TLKitPath = TLKitPath.new([Vector2(-140, 0), Vector2(0, 6), Vector2(140, 0)], false, 2.0)
	var ys: PackedFloat32Array = PackedFloat32Array()
	ys.resize(road.pts.size())
	terr.set("roads", [{"pts": road.pts, "ys": ys, "half": 3.0}])
	terr.call("build_grid")
	var mid: Vector2 = road.pts[road.pts.size() / 2]
	var spur: TLKitPath = TLKitPath.new([Vector2(mid.x, mid.y - 40.0), mid], false, 2.0)
	var rails: GDScript = preload("res://kernel/world/terrain/road_rails.gd")
	var host: Node3D = Node3D.new()
	var metres: float = rails.call("build", host, terr, road, 3.0, [[0, spur, PackedFloat32Array()]], -1, -1, [Vector2(mid.x, mid.y - 60.0)], [18.0], 1.3)
	var meshes: int = 0
	var bodies: int = 0
	var at_mouth: int = 0
	var across: int = 0
	var thin: int = 0      # pieces that would still be drawn where a rail is thinner than a pixel (0.15 m at 1080 lines, a 75 degree lens)
	for n: Node in host.get_children():
		bodies += int(n is CollisionObject3D)
		if n is MeshInstance3D:
			meshes += 1
			var seen: float = (n as MeshInstance3D).visibility_range_end
			var reach: float = seen + (n as MeshInstance3D).visibility_range_end_margin + (n as MeshInstance3D).get_aabb().size.length() * 0.5
			thin += int(seen <= 0.0 or 0.15 / (2.0 * reach * tan(deg_to_rad(37.5)) / 1080.0) < 0.75)
			for v: Vector3 in ((n as MeshInstance3D).mesh as ArrayMesh).get_faces():
				if absf(v.x - mid.x) < 3.0:
					at_mouth += int(v.z < mid.y)
					across += int(v.z > mid.y)
	var bare: Node3D = Node3D.new()
	var none: float = rails.call("build", bare, terr, road, 3.0, [], -1, -1, [], [], 0.0)
	var crisp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://style/style_crisp.json"))
	var classic: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://style/style.json"))
	var keyed: bool = (crisp["detail"] as Dictionary).has("road_rails") and not (classic["detail"] as Dictionary).has("road_rails")
	var ok: bool = metres > 300.0 and meshes >= 2 and thin == 0 and bodies == 0 and at_mouth == 0 and across > 0 and none == 0.0 and bare.get_child_count() == 0 and keyed
	print("CEL rails %s rail_m=%.1f pieces=%d drawn_under_0.75_px=%d collision_objects=%d vertices_in_the_spur_mouth=%d across_from_it=%d without_key_m=%.1f nodes=%d key_in_crisp_only=%s" % [
		"ok" if ok else "failed", metres, meshes, thin, bodies, at_mouth, across, none, bare.get_child_count(), str(keyed)])
	host.free()
	bare.free()
