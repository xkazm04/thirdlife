extends Node3D
## The skater gym (hockey campaign, lane K2): thirdjam's skater alone on flat ice, to judge by eye. Not part of any
## pack; it counts frames, never a clock. Run windowed (it renders):
##   godot --path engine --position 0,1440 --resolution 1280x720 res://rigs/skater/gym/skater_gym.tscn -- \
##         --mode=sheet --clip=Stride --every=3 --cam=side --out=<sheet.png>
## Args after `--`:
##   --mode=sheet   one clip, a tile every `--every` keys (default 3), `--cols` tiles a row (default 10), cropped
##                  square round the figure from the full frame
##   --mode=still   one frame of `--clip` at `--key` (default 0), square, `--px` wide (default the window's height)
##   --mode=turn    the clip's key at the four cameras side | three | front | back, one row
##   --mode=shots   every shot of `--shots=<file.json>` ([{"clip", "key", "cam"}, ...], the list reference_capture.py
##                  takes) as <outdir>/<clip>_k<key>_<cam>.png, 720 px square, with what each pose measures in
##                  <outdir>/ours.json (`--outdir=<folder>`)
##   --mode=play    the clip looping (write it with --write-movie); `--frames=N` then quits
##   --clip=<name>  a clip of skater_clips.res without its AS_SkaterTB1_P3_ prefix (default Stride); `rest` = the rest pose
##   --cam=side|three|front|back   the same four cameras engine/tools/skater/reference_capture.py gives Unreal
##   --team=0|1     blue | orange
##   --style=<file> the look (default: the engine's chosen style)
## Prints `[skater_gym] ...` lines and `tl.skater.gym/1 {...}` last.

## The cameras in the figure's own frame, metres: [forward, right, up] of the eye, of the target, the field of view
## in degrees (the picture is square, so it is the same both ways). reference_capture.py holds the same numbers.
const CAMS: Dictionary = {
	"side": [[0.45, 4.6, 1.0], [0.45, 0.0, 0.8], 30.0],
	"three": [[3.6, 2.8, 1.5], [0.35, 0.0, 0.8], 30.0],
	"front": [[5.0, 0.0, 1.0], [0.0, 0.0, 0.8], 30.0],
	"back": [[-3.6, -2.4, 2.0], [0.4, 0.0, 0.8], 30.0],
}

var args: Dictionary = {}
var cam: Camera3D
var label: Label
var skater: TLRigSkater
var frame: int = 0
var report: Dictionary = {"schema": "tl.skater.gym/1", "ok": false}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("style"):
		for note: String in TLStyle.load_style(String(args["style"])):
			print("[skater_gym] style: " + note)
	TLStyle.install(self, {})
	var ice: Node3D = TLKit.build("ground_patch", {"size_x": 60.0, "size_z": 60.0, "surface": "ice", "thickness": 0.3})
	add_child(ice)
	cam = Camera3D.new()
	cam.far = 500.0
	cam.near = 0.1
	add_child(cam)
	cam.make_current()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)
	layer.add_child(label)
	skater = TLRigSkater.new()
	skater.setup({"team": int(args.get("team", "0"))})
	add_child(skater)
	report["metrics"] = skater.metrics()
	var clip: String = String(args.get("clip", "Stride"))
	if clip != "rest" and not TLRigSkater.clip_library().has_animation(clip):
		_done("no clip '%s'" % clip)
		return
	if args.has("nobody"):
		skater.mesh_instance().set_instance_shader_parameter(&"tl_body", Vector2.ZERO)
	report["clip"] = clip
	report["keys"] = TLRigSkater.clip_keys(clip) if clip != "rest" else 0
	match String(args.get("mode", "sheet")):
		"sheet": _sheet.call_deferred(clip)
		"still": _still.call_deferred(clip)
		"turn": _turn.call_deferred(clip)
		"shots": _shots.call_deferred()
		"play":
			skater.play_clip(clip, true)
			_cam_to(String(args.get("cam", "side")))
		_: _done("unknown --mode")


func _physics_process(_dt: float) -> void:
	if String(args.get("mode", "sheet")) != "play" or skater == null:
		return
	frame += 1
	skater.tick()
	label.text = "%s  key %d" % [skater.clip, roundi(skater.clip_key())]
	if args.has("frames") and frame >= int(args["frames"]):
		report["frames"] = frame
		_done("")


func _cam_to(which: String) -> void:
	var c: Array = CAMS.get(which, CAMS["side"])
	cam.fov = float(c[2])
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.look_at_from_position(_at(c[0]), _at(c[1]), Vector3.UP)


## [forward, right, up] in the figure's frame to the scene: the figure faces -Z with its right on +X.
func _at(fru: Array) -> Vector3:
	return skater.global_transform * Vector3(float(fru[1]), float(fru[2]), -float(fru[0]))


func _show(clip: String, key: int) -> void:
	if clip == "rest":
		skater.pose_rest()
	else:
		skater.pose_at(clip, float(key))


## The centre square of the frame (the cameras are square: the field of view is the frame's height).
func _grab() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var h: int = img.get_height()
	return img.get_region(Rect2i((img.get_width() - h) / 2, 0, h, h))


func _place_label(text: String) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	label.position = Vector2((vp.x - vp.y) * 0.5 + 6.0, 4.0)
	label.text = text


func _sheet(clip: String) -> void:
	var which: String = String(args.get("cam", "side"))
	var every: int = maxi(1, int(args.get("every", "3")))
	var cols: int = maxi(1, int(args.get("cols", "10")))
	var px: int = int(args.get("px", "360"))
	var keys: Array = []
	var n: int = maxi(1, TLRigSkater.clip_keys(clip)) if clip != "rest" else 1
	for k: int in range(0, n, every):
		keys.append(k)
	var rows: int = int(ceil(float(keys.size()) / float(cols)))
	var sheet: Image = Image.create(mini(cols, keys.size()) * px, rows * px, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.12))
	_cam_to(which)
	for i: int in range(keys.size()):
		_show(clip, int(keys[i]))
		_place_label("%s  key %d" % [clip, int(keys[i])])
		var img: Image = await _grab()
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i((i % cols) * px, (i / cols) * px))
	var out: String = String(args.get("out", "user://skater_sheet.png"))
	report["saved"] = sheet.save_png(out) == OK
	report["out"] = out
	report["tiles"] = keys.size()
	report["cam"] = which
	_done("" if bool(report["saved"]) else "sheet not saved")


func _still(clip: String) -> void:
	var which: String = String(args.get("cam", "side"))
	var key: int = int(args.get("key", "0"))
	_cam_to(which)
	_show(clip, key)
	_place_label("ours  %s  key %d  %s" % [clip, key, which])
	if args.has("nolabel"):
		label.text = ""
	var img: Image = await _grab()
	if args.has("px"):
		img.resize(int(args["px"]), int(args["px"]), Image.INTERPOLATE_LANCZOS)
	var out: String = String(args.get("out", "user://skater_still.png"))
	report["saved"] = img.save_png(out) == OK
	report["out"] = out
	report["cam"] = which
	report["key"] = key
	_measure()
	_done("" if bool(report["saved"]) else "still not saved")


func _turn(clip: String) -> void:
	var key: int = int(args.get("key", "0"))
	var px: int = int(args.get("px", "540"))
	var names: Array = ["side", "three", "front", "back"]
	var sheet: Image = Image.create(names.size() * px, px, false, Image.FORMAT_RGB8)
	_show(clip, key)
	for i: int in range(names.size()):
		_cam_to(String(names[i]))
		_place_label("ours  %s  key %d  %s" % [clip, key, names[i]])
		var img: Image = await _grab()
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(i * px, 0))
	var out: String = String(args.get("out", "user://skater_turn.png"))
	report["saved"] = sheet.save_png(out) == OK
	report["out"] = out
	_measure()
	_done("" if bool(report["saved"]) else "sheet not saved")


func _shots() -> void:
	var list: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(args.get("shots", ""))))
	var outdir: String = String(args.get("outdir", "")).trim_suffix("/")
	if not (list is Array) or outdir == "":
		_done("--shots=<file.json> and --outdir=<folder> are needed")
		return
	DirAccess.make_dir_recursive_absolute(outdir)
	var rows: Array = []
	var saved: int = 0
	label.text = ""
	for shot: Dictionary in list as Array:
		var clip: String = String(shot["clip"])
		var key: int = int(shot["key"])
		if clip != "rest" and not TLRigSkater.clip_library().has_animation(clip):
			rows.append({"clip": clip, "key": key, "cam": shot["cam"], "error": "no such clip"})
			continue
		_cam_to(String(shot["cam"]))
		_show(clip, key)
		var img: Image = await _grab()
		img.resize(720, 720, Image.INTERPOLATE_LANCZOS)
		var file: String = "%s_k%03d_%s.png" % [clip, key, shot["cam"]]
		if img.save_png(outdir + "/" + file) == OK:
			saved += 1
		_measure()
		var row: Dictionary = {"clip": clip, "key": key, "cam": shot["cam"], "file": file}
		for bone: String in ["pelvis", "head", "hand_l", "hand_r", "foot_l", "foot_r", "stick_socket", "head_socket"]:
			row[bone] = _fru(skater.bone_transform(bone).origin)
		row["puck_socket"] = _fru(skater.socket_transform(&"puck_socket").origin)
		row["top_m"] = report["top_m"]
		row["lowest_by_slot_m"] = report["lowest_by_slot_m"]
		rows.append(row)
	var f: FileAccess = FileAccess.open(outdir + "/ours.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": "tl.skater.gym.shots/1", "units": "metres, [forward, right, up] in the figure's frame", "shots": rows}, " ") + "
")
	f.close()
	report.erase("top_m")
	report.erase("lowest_by_slot_m")
	report.erase("puck_socket")
	report.erase("head_socket")
	report["shots_asked"] = (list as Array).size()
	report["shots_saved"] = saved
	_done("" if saved == (list as Array).size() else "%d of %d shots saved" % [saved, (list as Array).size()])


## A point of the figure's own space as [forward, right, up] metres (the figure faces -Z, its right is +X).
func _fru(v: Vector3) -> Array:
	return [snappedf(-v.z, 0.0001), snappedf(v.x, 0.0001), snappedf(v.y, 0.0001)]


## What the pose measures, in metres above the ice (y = 0): the highest and lowest skinned vertex, the blade's lowest
## vertex (slot Stick), the lowest of the skate blades (slot Blade), the puck socket.
func _measure() -> void:
	var sk: Skeleton3D = skater.skeleton()
	var mesh: Mesh = skater.mesh_instance().mesh
	var skin: Skin = skater.mesh_instance().skin
	var pal: Array = []
	for b: int in range(skin.get_bind_count()):
		var bi: int = skin.get_bind_bone(b)
		if bi < 0:
			bi = sk.find_bone(skin.get_bind_name(b))
		pal.append(sk.get_bone_global_pose(bi) * skin.get_bind_pose(b))
	var root: Transform3D = sk.global_transform
	var top: float = -INF
	var low: Dictionary = {}
	for s: int in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / vs.size()
		var lo: float = INF
		for v: int in range(vs.size()):
			var p: Vector3 = Vector3.ZERO
			for j: int in range(per):
				var w: float = ws[v * per + j]
				if w > 0.0:
					p += (pal[bones[v * per + j]] as Transform3D * vs[v]) * w
			p = root * p
			top = maxf(top, p.y)
			lo = minf(lo, p.y)
		low[mesh.surface_get_name(s)] = snappedf(lo, 0.0001)
	report["top_m"] = snappedf(top, 0.0001)
	report["lowest_by_slot_m"] = low
	report["puck_socket"] = _v(skater.global_transform * skater.socket_transform(&"puck_socket").origin)
	report["head_socket"] = _v(skater.global_transform * skater.socket_transform(&"head_socket").origin)


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]


func _done(err: String) -> void:
	report["ok"] = err == ""
	if err != "":
		report["error"] = err
	print("%s skater gym" % ("PASS" if err == "" else "FAIL"))
	print("tl.skater.gym/1 " + JSON.stringify(report))
	get_tree().quit(0 if err == "" else 1)
