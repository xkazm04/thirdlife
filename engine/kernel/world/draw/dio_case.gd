extends SceneTree
## Diorama day (20 Nov 2026), surfaces and nature: the headless cases of selftest block 630
## (engine/tools/selftest.d/630-dio.sh). One line per case: DIO <case> ok|failed <what was measured>.
##   tex      the six material textures load as they are (no import step), 1024 px with mipmaps; the style names how
##            much of them is used (--classic: `detail.tex` and `detail.nature` are absent, nothing is loaded)
##   nature   a kit pine, bush, rock and broadleaf drawn as felt and clay: the recipe is untouched (content_hash as
##            before), the look stays inside the recipe's reach, within a triangle budget, and is the same twice
##   mesa     a slab stack is closed around, as high as asked and no wider than its foot
const Felt: GDScript = preload("res://kits/tl_felt.gd")
const Dio: GDScript = preload("res://style/dio/style_dio.gd")
const Pictures: GDScript = preload("res://kernel/world/draw/draw_pictures.gd")


func _initialize() -> void:
	var classic: bool = OS.get_cmdline_user_args().has("--classic")
	TLStyle.set_headless(true)
	TLStyle.ensure()
	_tex(classic)
	if not classic:
		_nature()
		_mesa()
	quit(0)


func _tex(classic: bool) -> void:
	var dt: Dictionary = TLStyle.data.get("detail", {})
	var found: int = 0
	var bad: PackedStringArray = PackedStringArray()
	for n: String in Dio.TEX_NAMES:
		var path: String = Dio.TEX_DIR + n + ".res"
		var t: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
		if t == null:
			bad.append(n + ": missing")
			continue
		var img: Image = t.get_image()
		if t.get_width() != 1024 or t.get_height() != 1024 or img == null or not img.has_mipmaps():
			bad.append("%s: %dx%d mipmaps %s" % [n, t.get_width(), t.get_height(), str(img != null and img.has_mipmaps())])
			continue
		found += 1
	var ok: bool = found == Dio.TEX_NAMES.size() and bad.is_empty()
	if classic:
		ok = ok and not dt.has("tex") and not dt.has("nature") and Dio.textures(TLStyle.data) == 0.0 and (Dio._tex as Dictionary).is_empty() and not Felt.enabled()
		ok = ok and str(Pictures.style_rules()) == ""           # classic's picture key is what it was
	else:
		ok = ok and float(dt.get("tex", 0.0)) > 0.0 and float(dt.get("nature", 0.0)) > 0.0
		ok = ok and str(Pictures.style_rules()) == "|felt%d" % int(float(dt.get("nature", 0.0)))
	print("DIO tex %s style=%s textures=%d of %d tex=%s nature=%s picture_key_adds='%s' %s" % ["ok" if ok else "failed", TLStyle.style_name, found, Dio.TEX_NAMES.size(),
		str(dt.get("tex", "absent")), str(dt.get("nature", "absent")), str(Pictures.style_rules()), "; ".join(bad)])


static func _arrays(m: ArrayMesh, si: int) -> Array:
	return (m.get_meta(&"tl_arrays") as Array)[si] if m.has_meta(&"tl_arrays") else m.surface_get_arrays(si)


static func _mesh_hash(m: ArrayMesh) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	for si: int in m.get_surface_count():
		var arr: Array = _arrays(m, si)
		ctx.update((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array())
		ctx.update((arr[Mesh.ARRAY_NORMAL] as PackedVector3Array).to_byte_array())
	return ctx.finish().hex_encode()


static func _recipe(kind: String) -> TLMesh:
	match kind:
		"pine":
			return TLKitNature.pine(100, 8.5, 5, 2.1)
		"bush":
			return TLKitNature.bush(300, 1.0)
		"rock":
			return TLKitNature.rock(200, 1.2, 0.65)
	return TLKitNature.broadleaf(120, 7.5)


func _nature() -> void:
	var notes: PackedStringArray = PackedStringArray()
	var ok: bool = true
	for it: Array in [["pine", 2600], ["bush", 5400], ["rock", 5400], ["broadleaf", 8200]]:
		var kind: String = it[0]
		var mk: TLMesh = _recipe(kind)
		var before: String = mk.content_hash()
		var box: AABB = mk.aabb()
		var a: ArrayMesh = Felt.look(mk, "case_" + kind, 18, 3, true)
		var b: ArrayMesh = Felt.look(_recipe(kind), "case_" + kind, 18, 3, true)
		if a == null or b == null:
			ok = false
			notes.append(kind + ": no look")
			continue
		var tris: int = int(a.get_meta("tl_look_tris", 0))
		var lb: AABB = AABB()
		var first: bool = true
		for si: int in a.get_surface_count():
			for p: Vector3 in (_arrays(a, si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				if first:
					lb = AABB(p, Vector3.ZERO)
					first = false
				else:
					lb = lb.expand(p)
		var inside: bool = box.grow(0.22 * maxf(box.size.x, box.size.z)).encloses(lb)
		var same: bool = _mesh_hash(a) == _mesh_hash(b)
		var kept: bool = mk.content_hash() == before
		var good: bool = inside and same and kept and tris > int(mk.tri_count) and tris <= int(it[1]) and int(a.get_meta("tl_tris", 0)) == int(mk.tri_count) and str(a.get_meta("tl_hash", "")) == before
		ok = ok and good
		notes.append("%s: tris %d (recipe %d, budget %d) inside=%s same_twice=%s recipe_kept=%s" % [kind, tris, mk.tri_count, it[1], str(inside), str(same), str(kept)])
	print("DIO nature %s %s" % ["ok" if ok else "failed", "; ".join(notes)])


func _mesa() -> void:
	var unit: PackedVector2Array = PackedVector2Array()
	for v: int in 10:
		unit.append(Vector2.from_angle(TAU * float(v) / 10.0) * (0.9 + 0.2 * float(v % 2)))
	var round_: PackedVector2Array = Felt.round_outline(unit, 40)
	var mk: TLMesh = TLMesh.new(1)
	Felt.slab_stack(mk, "cliff", round_, 0.0, 60.0, 80.0, 55.0, 6, Color.WHITE, 7)
	var box: AABB = mk.aabb()
	var through: int = 0          # every corner of the polygon lies on the rounded outline
	for p: Vector2 in unit:
		for q: Vector2 in round_:
			if p.distance_to(q) < 1e-4:
				through += 1
				break
	var ok: bool = round_.size() == 40 and through == 10 and absf(box.position.y) < 0.01 and absf(box.end.y - 60.0) < 0.01 \
		and box.size.x < 2.0 * 80.0 * 1.2 and box.size.x > 2.0 * 55.0 and mk.tri_count == (6 * 4) * 40 * 2
	print("DIO mesa %s outline=%d corners_on_it=%d of 10 height=%.2f width=%.1f tris=%d" % ["ok" if ok else "failed", round_.size(), through, box.end.y, box.size.x, mk.tri_count])
