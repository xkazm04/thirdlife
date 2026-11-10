extends Node3D
## Kit lab: test scenes for the kit, the rigs and the style layer. Not part of the deliverable (kits/, rigs/, style/
## never reference this directory). Driven by user args (after `--`), see tools/k.sh:
##   --sheet=parts --page=0|1        contact sheet of every kit part from defaults, labelled
##   --sheet=biped_clips             every biped clip, 6 evenly spaced frames per row, side view
##   --sheet=biped_chase             skate, shoot, pass from a chase camera (behind and above, 35 degrees)
##   --sheet=vehicle | bot | turntable
##   --layout=<name> --cam=<cam>     a layout from kits_lab/layouts/<name>.json through a named camera of the layout
##   --style=overcast                load res://style/style_overcast.json instead of the golden style
##   --out=<name>                    captures/<name>.png      --stats  print one JSON line (triangles, draw calls)
## The capture is taken after a fixed number of rendered frames, never after wall time.

var args: Dictionary = {}
var cam: Camera3D
var frames: int = 0
var wait_frames: int = 24
var out_name: String = "lab"
var layout_result: Dictionary = {}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("style"):
		var errs: PackedStringArray = TLStyle.load_style("res://style/style_%s.json" % String(args["style"]))
		for e: String in errs:
			print("[style] ", e)
	TLStyle.install(self, {"ink": String(args.get("ink", "1")) != "0", "grade": String(args.get("grade", "1")) != "0"})
	cam = Camera3D.new()
	cam.name = "LabCamera"
	cam.far = 6000.0
	add_child(cam)
	cam.make_current()
	var sheet: String = String(args.get("sheet", ""))
	out_name = String(args.get("out", sheet if sheet != "" else "lab"))
	match sheet:
		"parts": _sheet_parts(int(args.get("page", "0")))
		"biped_clips": _sheet_biped_clips()
		"biped_chase": _sheet_biped_chase()
		"vehicle": _sheet_vehicle()
		"bot": _sheet_bot()
		"turntable": _sheet_turntable()
		"fracture": _sheet_fracture()
		"biped_params": _sheet_biped_params()
		"collision": _sheet_collision()
		_:
			if args.has("layout"):
				_show_layout(String(args["layout"]), String(args.get("cam", "hero")))
			else:
				_sheet_parts(0)


func _process(_dt: float) -> void:
	frames += 1
	if args.has("swap-at") and frames == int(args["swap-at"]):   # run-time style swap: load the other file, install again
		for e: String in TLStyle.load_style("res://style/style_overcast.json"):
			print("[style] ", e)
		TLStyle.install(self)
		print("[lab] swapped to style '%s' at frame %d" % [TLStyle.style_name, frames])
	if frames == wait_frames:
		if args.has("stats"):
			var tris: int = TLKit.triangles(self)
			print(JSON.stringify({"layout": String(args.get("layout", "")), "triangles_built": tris,
				"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives_in_frame": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				"viewport": [get_viewport().size.x, get_viewport().size.y]}))
		var img: Image = get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://kits_lab/captures"))
		var path: String = "res://kits_lab/captures/%s.png" % out_name
		img.save_png(path)
		print("captured ", path, " ", img.get_width(), "x", img.get_height())
		get_tree().quit()


# ------------------------------------------------------------------ helpers
func _label(text: String, pos: Vector3, size: int = 40, parent: Node3D = null) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color(0.12, 0.08, 0.16)
	l.outline_modulate = Color(1, 1, 1, 0.9)
	l.outline_size = 10
	l.position = pos
	(parent if parent != null else self).add_child(l)
	return l


## A long lens far away: close to an orthographic view, but the ink pass keeps its perspective depth maths.
func _frame(centre: Vector3, width: float, height: float, pitch_deg: float, yaw_deg: float, fov: float = 12.0) -> void:
	var vp: Vector2 = Vector2(get_viewport().size)
	var aspect: float = vp.x / vp.y
	var need_h: float = maxf(height, width / aspect)
	var dist: float = need_h * 0.5 / tan(deg_to_rad(fov * 0.5))
	var dir: Vector3 = Basis.from_euler(Vector3(deg_to_rad(-pitch_deg), deg_to_rad(yaw_deg), 0)) * Vector3(0, 0, -1)
	cam.fov = fov
	cam.position = centre - dir * dist
	cam.look_at(centre, Vector3.UP)


func _floor(size: Vector2, centre: Vector3, surface: String = "concrete") -> void:
	var g: Node3D = TLKit.build("ground_patch", {"size_x": size.x, "size_z": size.y, "surface": surface, "thickness": 0.3})
	g.position = centre
	add_child(g)


static func _aabb_of(n: Node, xf: Transform3D = Transform3D.IDENTITY) -> AABB:
	var bb: AABB = AABB()
	var has: bool = false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as Node3D).visible:
		bb = xf * (n as MeshInstance3D).mesh.get_aabb()
		has = true
	for c: Node in n.get_children():
		if c is Node3D and (c as Node3D).visible:
			var cb: AABB = _aabb_of(c, xf * (c as Node3D).transform)
			if cb.size != Vector3.ZERO:
				bb = cb if not has else bb.merge(cb)
				has = true
	return bb


# ------------------------------------------------------------------ sheets
func _sheet_parts(page: int) -> void:
	var kinds: PackedStringArray = TLKit.list()
	var cols: int = 5
	var rows_per_page: int = 4
	var cell: float = 11.0
	var first: int = page * cols * rows_per_page
	_floor(Vector2(cell * cols + 6.0, cell * rows_per_page + 6.0), Vector3(cell * (cols - 1) * 0.5, -0.02, cell * (rows_per_page - 1) * 0.5), "concrete")
	for i: int in range(first, mini(kinds.size(), first + cols * rows_per_page)):
		var kind: String = kinds[i]
		var part: Node3D = TLKit.build(kind, {})
		if part == null:
			continue
		var k: int = i - first
		var slot: Vector3 = Vector3(float(k % cols) * cell, 0, float(k / cols) * cell)
		var bb: AABB = _aabb_of(part)
		var big: float = maxf(bb.size.x, maxf(bb.size.y * 1.25, bb.size.z))
		var sc: float = clampf(7.5 / maxf(big, 0.001), 0.02, 12.0)
		if big > 2.5 and big < 7.5:
			sc = 1.0
		part.scale = Vector3.ONE * sc
		var c: Vector3 = bb.get_center() * sc
		part.position = slot - Vector3(c.x, bb.position.y * sc, c.z)
		add_child(part)
		var spec: Dictionary = TLKit.spec(kind)
		_label("%s%s\n%.1f x %.1f x %.1f m%s  %d tris" % [kind, " [F]" if bool(spec["fracturable"]) else "", bb.size.x, bb.size.y, bb.size.z,
			"" if is_equal_approx(sc, 1.0) else "  (x%.2f)" % sc, TLKit.triangles(part)], slot + Vector3(0, 0.5, cell * 0.43), 64)
	_frame(Vector3(cell * (cols - 1) * 0.5, 1.5, cell * (rows_per_page - 1) * 0.5 + 1.0), cell * cols + 1.0, cell * rows_per_page * 0.74 + 4.0, 42.0, 0.0)
	out_name = String(args.get("out", "tmp_parts_%d" % page))


func _make_biped(clip: String, f: int, extra: Dictionary = {}) -> Node3D:
	var hockey: bool = ["skate", "skate_stop", "shoot", "pass"].has(clip)
	var p: Dictionary = {"mode": "skate" if hockey else "walk", "stick": hockey, "backpack": not hockey}
	if hockey:
		p["colors"] = {"top": "car_blue", "trim": "car_white", "legs": "bot_dark", "boots": "black"}
	p.merge(extra, true)
	var r: Node3D = TLRigs.build("biped", p)
	r.call("play", StringName(clip), 0.0)
	for i: int in f + 1:
		r.call("tick", i + 1)
	return r


static func _clip_frames(rig: Node3D, clip: String, n: int) -> Array:
	var c: Dictionary = rig.get("_clips")[clip]
	var total: int = int(round(float(c["dur"]) * 60.0))
	var out: Array = []
	for i: int in n:
		out.append(int(round(float(total) * float(i) / float(n if bool(c["loop"]) else n - 1))))
	return out


## Rows stacked in Y, frames along Z, seen from +X: a true side view (the rigs face -Z = screen left).
func _strip(family: String, clip_names: Array, blocks: int, col_w: float, row_h: float, maker: Callable) -> void:
	var probe: Node3D = TLRigs.build(family, {})
	var per_block: int = int(ceil(float(clip_names.size()) / float(blocks)))
	var block_w: float = col_w * 6.0 + col_w * 1.6
	for ci: int in clip_names.size():
		var clip: String = clip_names[ci]
		var b: int = ci / per_block
		var row: int = ci % per_block
		var y: float = float(per_block - 1 - row) * row_h
		var z0: float = -float(b) * block_w
		var fr: Array = _clip_frames(probe, clip, 6)
		var slab: Node3D = TLKit.build("ground_patch", {"size_x": 1.6, "size_z": col_w * 6.0 + 0.4, "surface": "ice" if ["skate", "skate_stop", "shoot", "pass"].has(clip) else "concrete", "thickness": 0.12})
		slab.position = Vector3(0, y, z0 - col_w * 2.5)
		add_child(slab)
		for i: int in 6:
			var r: Node3D = maker.call(clip, int(fr[i]))
			r.position = Vector3(0, y, z0 - float(i) * col_w)
			add_child(r)
			_label("f%d" % int(fr[i]), Vector3(0.9, y - 0.32, z0 - float(i) * col_w), 26)
		_label(clip, Vector3(0.9, y + row_h * 0.62, z0 + col_w * 0.75), 44)
	probe.free()
	var h: float = float(per_block) * row_h
	var w: float = float(blocks) * block_w
	_frame(Vector3(0, h * 0.5 - 0.35, -w * 0.5 + col_w * 1.1), w + 0.6, h + 0.5, 0.0, 90.0)


func _sheet_biped_clips() -> void:
	var names: Array = ["idle", "walk", "run", "skate", "skate_stop", "shoot", "pass", "cheer", "fall", "carry", "work"]
	_strip("biped", names, 2, 2.3, 2.75, _make_biped)


func _sheet_bot() -> void:
	var maker: Callable = func(clip: String, f: int) -> Node3D:
		var r: Node3D = TLRigs.build("bot", {"scale": 1.4, "colors": {"body": "bot_body" if clip != "weld" else "bot_body2", "hat": "hat_a"}})
		r.call("play", StringName(clip), 0.0)
		for i: int in f + 1:
			r.call("tick", i + 1)
		return r
	_strip("bot", ["idle", "walk", "work", "carry", "weld"], 1, 2.3, 2.6, maker)


func _sheet_biped_chase() -> void:
	var names: Array = ["skate", "shoot", "pass", "skate_stop", "cheer"]
	var probe: Node3D = TLRigs.build("biped", {})
	_floor(Vector2(24, 24), Vector3(5.6, 0.0, -8.0), "ice")
	for ri: int in names.size():
		var fr: Array = _clip_frames(probe, names[ri], 6)
		for i: int in 6:
			var r: Node3D = _make_biped(names[ri], int(fr[i]), {"mode": "skate", "stick": true, "backpack": false, "colors": {"top": "car_blue", "trim": "car_white", "legs": "bot_dark", "boots": "black"}})
			r.position = Vector3(float(i) * 2.5, 0.05, -float(ri) * 4.0)
			add_child(r)
			var puck: Node3D = TLKit.build("puck", {"radius": 0.06, "height": 0.04})
			puck.position = r.position + Vector3(0.25, 0.0, -1.05)
			add_child(puck)
		_label(String(names[ri]), Vector3(-2.4, 1.2, -float(ri) * 4.0), 56)
	probe.free()
	_frame(Vector3(5.4, 0.9, -8.0), 19.5, 15.0, 35.0, 0.0)


func _sheet_vehicle() -> void:
	_floor(Vector2(34, 22), Vector3(9.0, 0.0, 3.0), "asphalt")
	var cases: Array = [
		["steer left (+1)", {"steer": 1.0}, 180.0], ["steer right (-1)", {"steer": -1.0, "colors": {"body": "car_blue", "stripe": "car_white"}}, 180.0],
		["suspension: front compressed 0.14 m, rear extended 0.10 m", {"suspension": [0.14, 0.14, -0.1, -0.1]}, 180.0],
		["rest (reference)", {}, 180.0],
		["nitro 1.0 (rear view)", {"nitro": 1.0, "throttle": 1.0}, 0.0], ["nitro 0.4 + brake lights (rear view)", {"nitro": 0.4, "brake": 1.0, "colors": {"body": "car_blue", "stripe": "car_white"}}, 0.0],
		["suspension: left side compressed (rear view)", {"suspension": [0.14, -0.08, 0.14, -0.08]}, 0.0], ["no spoiler, steer left (rear view)", {"spoiler": false, "steer": 1.0, "colors": {"body": "yellow", "stripe": "black"}}, 0.0],
	]
	for i: int in cases.size():
		var c: Array = cases[i]
		var r: Node3D = TLRigs.build("vehicle", c[1])
		for f: int in 30:
			r.call("tick", f + 1)
		r.position = Vector3(float(i % 4) * 6.2, 0.0, float(i / 4) * 7.5)
		r.rotation_degrees.y = float(c[2]) - 28.0
		add_child(r)
		_label(String(c[0]), r.position + Vector3(0, 2.1 + 0.5 * float(i % 2), 0), 30)
	_frame(Vector3(9.3, 0.6, 3.6), 25.5, 12.5, 24.0, 0.0)


func _sheet_turntable() -> void:
	var rows: Array = [["biped", {"mode": "skate", "stick": true, "backpack": false}, 2.9, 1.0], ["biped", {}, 2.9, 1.0], ["bot", {"scale": 1.4}, 2.7, 1.0], ["vehicle", {}, 2.4, 0.42]]
	var y: float = 0.0
	for ri: int in range(rows.size() - 1, -1, -1):
		var row: Array = rows[ri]
		var slab: Node3D = TLKit.build("ground_patch", {"size_x": 2.4, "size_z": 8.0 * 2.6 + 0.4, "surface": "concrete", "thickness": 0.12})
		slab.position = Vector3(0, y, -3.5 * 2.6)
		add_child(slab)
		for i: int in 8:
			var r: Node3D = TLRigs.build(String(row[0]), row[1])
			for f: int in 20:
				r.call("tick", f + 1)
			r.scale *= float(row[3])
			r.position = Vector3(0, y, -float(i) * 2.6)
			r.rotation_degrees.y = float(i) * 45.0
			add_child(r)
		y += float(row[2])
	_frame(Vector3(0, y * 0.5 - 0.3, -3.5 * 2.6), 8.0 * 2.6 + 0.6, y + 0.4, 4.0, 90.0)


## Runtime params and blending, the way a controller drives the rig: set_locomotion every frame, play() for events.
func _sheet_biped_params() -> void:
	_floor(Vector2(30, 22), Vector3(8.75, 0.0, -5.0), "ice")
	var hockey: Dictionary = {"mode": "skate", "stick": true, "backpack": false, "colors": {"top": "car_blue", "trim": "car_white", "legs": "bot_dark", "boots": "black"}}
	# row 1 (far): skating at 6 m/s, shoot played at frame 30: legs keep striding, upper body shoots, then blends back
	var shots: Array = [28, 40, 50, 58, 66, 84, 100, 120]
	for i: int in shots.size():
		var r: Node3D = TLRigs.build("biped", hockey)
		for f: int in int(shots[i]):
			r.call("set_locomotion", Vector3(0, 0, -6.0), true)
			if f == 30:
				r.call("play", &"shoot", 0.12)
			r.call("tick", f + 1)
		r.position = Vector3(float(i) * 2.5, 0.05, -10.0)
		r.rotation_degrees.y = -35.0
		add_child(r)
		_label("f%d%s" % [int(shots[i]), " shoot" if String(r.get("clip")) == "shoot" else ""], r.position + Vector3(0, -0.2, 1.6), 30)
	_label("skating at 6 m/s, play(shoot) at f30: upper body only, legs keep striding, blend back", Vector3(8.75, 0.0, -13.5), 36)
	# row 2 (near): speed ramp in walk mode (idle -> walk -> run), lean, look_at, expressions
	var cases: Array = [["0 m/s", 0.0, {}], ["1.2 m/s", 1.2, {}], ["3.4 m/s (walk/run mix)", 3.4, {}], ["6 m/s, lean +1", 6.0, {"lean": 1.0}],
		["look_at left", 0.0, {"look_at": Vector3(-30, 1.5, -8)}], ["focus", 0.0, {"expression": &"focus"}], ["blink", 0.0, {"expression": &"blink"}], ["skate mode 0 m/s", 0.0, {"mode": &"skate", "stick": true}]]
	for i: int in cases.size():
		var c: Array = cases[i]
		var r2: Node3D = TLRigs.build("biped", {"scale": 1.8 if i >= 4 and i <= 6 else 1.0})
		r2.position = Vector3(float(i) * 2.5, 0.0, 0.0)
		r2.rotation_degrees.y = 180.0 - 25.0   # facing the camera, turned a little
		add_child(r2)
		for pk: Variant in (c[2] as Dictionary):
			r2.call("set_param", StringName(str(pk)), c[2][pk])
		for f: int in 73:
			r2.call("set_locomotion", Vector3(0, 0, -float(c[1])), true)
			r2.call("tick", f + 1)
		_label(String(c[0]), r2.position + Vector3(0, -0.2, 1.7), 28)
	_frame(Vector3(8.75, 0.8, -5.0), 22.5, 12.0, 33.0, 0.0)


## Fracturable parts three ways: Intact, Pieces shown in place (must look like Intact), Pieces pushed apart.
func _sheet_fracture() -> void:
	_floor(Vector2(40, 16), Vector3(13, 0, 3), "concrete")
	var row: int = 0
	for spec: Array in [["barrier_wall", {"blocks": 3}], ["crate", {"size": 2.0}]]:
		for mode: int in 3:
			var part: Node3D = TLKit.build(String(spec[0]), spec[1])
			part.position = Vector3(float(mode) * 10.5, 0, float(row) * 7.0)
			add_child(part)
			if mode > 0:
				(part.get_node("Intact") as Node3D).visible = false
				(part.get_node("Pieces") as Node3D).visible = true
			if mode == 2:
				for pc: Node3D in part.get_node("Pieces").get_children():
					pc.position += Vector3(pc.position.x * 0.25, 0.25 * float(pc.get_index() % 3), pc.position.z * 0.9 + 0.3 * float(pc.get_index() % 2))
			_label("%s: %s" % [String(spec[0]), ["Intact", "Pieces in place (%d pieces)" % part.get_node("Pieces").get_child_count(), "Pieces pushed apart"][mode]], part.position + Vector3(0, 3.2, 0), 34)
		row += 1
	_frame(Vector3(10.5, 1.0, 3.5), 32.0, 15.0, 30.0, 0.0)


static func _show_shapes(n: Node, col: Color) -> void:
	for c: Node in n.get_children():
		_show_shapes(c, col)
		if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = (c as CollisionShape3D).shape.get_debug_mesh()
			var m: StandardMaterial3D = StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = col
			m.no_depth_test = true
			mi.material_override = m
			c.add_child(mi)


## Collision shapes drawn over the parts (wireframe, colour = material tag) to check that bodies sit on the visuals.
func _sheet_collision() -> void:
	var cols: Dictionary = {"ice": Color(0.2, 0.9, 1.0), "concrete": Color(1, 1, 1), "steel": Color(1, 0.3, 1), "wood": Color(1, 0.6, 0.1), "plastic": Color(0.1, 1, 0.2),
		"glass": Color(0.3, 0.5, 1), "stone": Color(1, 1, 0.2), "fabric": Color(1, 0.2, 0.2), "rubber": Color(0.2, 0.2, 0.2), "asphalt": Color(0.9, 0.9, 0.5), "grass": Color(0.5, 1, 0.5)}
	var items: Array = [["rink", {"length": 30, "width": 16, "corner_r": 5}, 0.5], ["goal", {}, 4.0], ["stands", {"length": 16, "rows": 6}, 0.7], ["scaffold", {}, 1.6],
		["house", {}, 1.0], ["bridge", {}, 0.5], ["arch_rib", {}, 0.4], ["road_spline", {}, 0.2], ["barrier_wall", {}, 1.0], ["timber_frame", {}, 1.2], ["entrance", {}, 1.0], ["tree", {}, 1.0]]
	_floor(Vector2(80, 60), Vector3(27, -0.02, 18), "grass")
	for i: int in items.size():
		var it: Array = items[i]
		var part: Node3D = TLKit.build(String(it[0]), it[1])
		part.scale = Vector3.ONE * float(it[2])
		part.position = Vector3(float(i % 4) * 18.0, 0.3 if String(it[0]) == "rink" else 0.0, float(i / 4) * 18.0)
		add_child(part)
		for b: Node in part.find_children("*", "StaticBody3D", true, false):
			_show_shapes(b, cols.get(String(b.get_meta("tl_material", "")), Color.RED))
		_label(String(it[0]), part.position + Vector3(0, 0.5, 8.0), 60)
	_frame(Vector3(27, 2, 18), 76.0, 38.0, 40.0, 0.0)


# ------------------------------------------------------------------ layouts
func _show_layout(lname: String, cam_name: String) -> void:
	var path: String = lname if lname.ends_with(".json") else "res://kits_lab/layouts/%s.json" % lname
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		print("[lab] cannot read layout ", path)
		get_tree().quit(1)
		return
	layout_result = TLKit.build_layout(parsed, self)
	for e: String in layout_result.get("errors", []):
		print("[layout] ", e)
	print("[lab] layout '%s' ok=%s nodes=%d" % [lname, str(layout_result.get("ok", false)), (layout_result.get("nodes", {}) as Dictionary).size()])
	var cams: Dictionary = layout_result.get("cams", {})
	if cams.has(cam_name):
		var c: Dictionary = cams[cam_name]
		cam.position = c["pos"]
		cam.look_at(c["look"], Vector3.UP)
		cam.fov = float(c["fov"])
	else:
		print("[lab] no camera '%s' in the layout (cameras: %s)" % [cam_name, ", ".join(cams.keys())])
		cam.position = Vector3(0, 60, 120)
		cam.look_at(Vector3(0, 0, 0), Vector3.UP)
	if args.has("avatar") and layout_result.get("ok", false):
		var av: Node3D = TLRigs.build("biped", {})
		var sp: Vector3 = layout_result.get("spawn", Vector3.ZERO)
		av.position = sp
		add_child(av)
	wait_frames = 40
	out_name = String(args.get("out", "layout_%s_%s" % [lname.get_file().get_basename(), cam_name]))
