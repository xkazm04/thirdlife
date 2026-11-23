extends Node3D
## The look gym (hockey campaign, lane K7): thirdjam's skater under thirdjam's hall light, to judge its SURFACE by eye
## against thirdjam's own render (docs/shifts/2026-11-24-night/lanes/K7-look/tools/look_reference.py takes the same
## shots in Unreal). Not part of any pack; it counts frames, never a clock. Run windowed (it renders):
##   godot --path engine --position 0,1440 --resolution 1280x720 res://rigs/skater/look/look_gym.tscn -- \
##         --mode=shots --shots=<file.json> --outdir=<folder> --team=0 --number=7 --look=felt
## Args after `--`:
##   --mode=shots   every shot of --shots ([{"clip", "key", "cam"}, ...]) as <outdir>/<clip>_k<key>_<cam>.png
##   --mode=ten     the ten skaters of a match (blue 7 13 42 4 5, orange 9 21 88 14 15: HokejGameMode.cpp:439-444) in
##                  two rows, from behind and from the front: <out> (a PNG), `--px` a tile (default 360)
##   --mode=check   selftest block 850 (look.skater.render): the number and the crest are in the picture. The back patch
##                  with 11 and with 88 on it (dark ink inside the patch, more of it for 88), the crest's white on the
##                  chest; prints `LOOK render ok=true|false ...`
##   --mode=cost    ten skaters before the game camera for --frames (default 300): the frame time, drawn and not
##   --look=felt|cel   the surface (TLRigSkaterLook); default: the chosen one
##   --team=0|1  --number=N   blue | orange, the jersey number (default thirdjam's first of the team: 7 | 9)
##   --at=x,y,yaw   where the figure stands on the rink (rink metres, Unreal's yaw; default the centre, facing +x)
##   --cam_abs=x,y,height,yaw,pitch   the camera of a still of the game itself, for the shot camera "abs"
##   --rig=0        the installed style's own sun instead of thirdjam's hall rig (look/gym_rig.json)
##   --style=<file> the look of the world (default: the engine's chosen style)
## Cameras: side | three | front | back (the four of skater_gym.gd, square, 30 degrees) and, in the game's frame
## (16:9, 70 degrees across: hockey.regular.cartridge.json:255), game (thirdjam's follow camera at rest: 6.75 m behind,
## 3.5 m up, pitched 17.65 degrees down), far (the same eye 40 m behind) and wide (three skaters across, from the side).
## The figure stands at the rig's centre facing rink +x, as thirdjam's stands in the reference.
## Prints `[look_gym] ...` lines and `tl.skater.look_gym/1 {...}` last.

const CAMS: Dictionary = {
	"side": [[0.45, 4.6, 1.0], [0.45, 0.0, 0.8], 30.0],
	"three": [[3.6, 2.8, 1.5], [0.35, 0.0, 0.8], 30.0],
	"front": [[5.0, 0.0, 1.0], [0.0, 0.0, 0.8], 30.0],
	"back": [[-3.6, -2.4, 2.0], [0.4, 0.0, 0.8], 30.0],
	"game": [[-6.75, 0.0, 3.5], [-6.75 + 9.5293, 0.0, 3.5 - 3.0320], 70.0],
	"far": [[-40.0, 0.0, 3.5], [-40.0 + 9.5293, 0.0, 3.5 - 3.0320], 70.0],
	"gamefront": [[6.75, 0.0, 3.5], [6.75 - 9.5293, 0.0, 3.5 - 3.0320], 70.0],
}
const WIDE: PackedStringArray = ["game", "far", "gamefront", "abs"]
const NUMBERS: Array = [[7, 13, 42, 4, 5], [9, 21, 88, 14, 15]]

var args: Dictionary = {}
var cam: Camera3D
var skater: TLRigSkater
var report: Dictionary = {"schema": "tl.skater.look_gym/1", "ok": false}
var _cost_left: int = -1
var _cost_usec: Array = []
var _cost_t: int = 0
var _gpu_ms: float = 0.0
var _cpu_ms: float = 0.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("style"):
		for note: String in TLStyle.load_style(String(args["style"])):
			print("[look_gym] style: " + note)
	TLStyle.install(self, {})
	var use_rig: bool = String(args.get("rig", "1")) != "0"
	if use_rig:
		_hall()
	var ice: Node3D = TLKit.build("ground_patch", {"size_x": 120.0, "size_z": 60.0, "surface": "ice", "thickness": 0.3})
	add_child(ice)
	cam = Camera3D.new()
	cam.far = 500.0
	cam.near = 0.1
	add_child(cam)
	cam.make_current()
	if args.has("look"):
		TLRigSkaterLook.default_variant = String(args["look"])
	report["look"] = TLRigSkaterLook.chosen()
	report["rig_lights"] = TLStyleFelt.rig_size()
	var team: int = int(args.get("team", "0"))
	skater = _skater(team, int(args.get("number", str(NUMBERS[clampi(team, 0, 1)][0]))))
	match String(args.get("mode", "shots")):
		"shots": _shots.call_deferred()
		"ten": _ten.call_deferred()
		"cost": _cost.call_deferred()
		"check": _check.call_deferred()
		_: _done("unknown --mode")


## thirdjam's rig in the felt materials, and a roof light for the style's own materials (the ice of this gym).
func _hall() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://rigs/skater/look/gym_rig.json")) as Dictionary
	var lights: Array = []
	for l: Dictionary in d["lights"] as Array:
		var c: Array = l["color_srgb8"]
		var p: Array = l["pos"]
		var w: Array = l["dir"]
		lights.append({"pos": Vector3(p[0], p[1], p[2]), "dir": Vector3(w[0], w[1], w[2]),
			"colour": Color(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0).srgb_to_linear(), "candela": float(l["candela"]),
			"radius_m": float(l["radius_m"]), "inner_deg": float(l["inner_deg"]), "outer_deg": float(l["outer_deg"])})
	var gain: float = float(args.get("gain", "6.0"))             # lane K6's tone gain (rink_arena.gd TONE_GAIN)
	var exposure: float = float(d["light_sum"]["exposure"]) * gain
	var pp: Dictionary = d["post"]["settings"]
	var cg: Array = pp["color_gain"]
	var cs: Array = pp["color_gain_shadows"]
	var sky: Color = Color(0, 0, 0)
	if args.has("sky"):
		var s: PackedStringArray = String(args["sky"]).split(",")
		sky = Color(float(s[0]), float(s[1]), float(s[2]))
	TLStyleFelt.set_rig(lights, exposure, Color(cg[0], cg[1], cg[2]), Color(cs[0], cs[1], cs[2]), sky)
	# for the style's own materials (the ice of this gym): a plain roof light, and the style's grade set for a hall as
	# lane K6 sets it (rink_arena.gd hall_post: no plum, no olive, no split; the rig's saturation and contrast)
	TLStyleHall.apply(self, {"color": "#fff1e2", "energy": 0.9})
	var rig: Node = get_tree().root.find_child(TLStyle.RIG_NODE, true, false)
	var grade: CanvasItem = rig.get_node_or_null("Grade/Rect") as CanvasItem if rig != null else null
	if grade != null and grade.material is ShaderMaterial:
		var gm: ShaderMaterial = grade.material as ShaderMaterial
		for k: String in ["plum_density", "olive_fill", "split"]:
			gm.set_shader_parameter(k, 0.0)
		gm.set_shader_parameter(&"sat", float((pp["color_saturation"] as Array)[0]))
		gm.set_shader_parameter(&"contrast", float((pp["color_contrast"] as Array)[0]))
		gm.set_shader_parameter(&"vignette", float(pp["vignette_intensity"]) * 0.43)


func _skater(team: int, number: int) -> TLRigSkater:
	var sk: TLRigSkater = TLRigSkater.new()
	sk.setup({"team": team})
	sk.SetNumber(number)
	sk.rotation.y = -PI * 0.5            # faces rink +x, as thirdjam's figure stands in the reference
	if args.has("at"):                   # --at=x,y,yaw: a place on the rink (rink metres, Unreal's yaw in degrees)
		var v: PackedStringArray = String(args["at"]).split(",")
		sk.position = Vector3(float(v[0]), 0.0, float(v[1]))
		sk.rotation.y = -PI * 0.5 - deg_to_rad(float(v[2]) if v.size() > 2 else 0.0)
	add_child(sk)
	return sk


func _cam_to(which: String, about: Node3D) -> void:
	if which == "abs":
		# --cam_abs=x,y,height,yaw,pitch: a camera of the game itself (rink metres, Unreal's yaw and pitch in degrees)
		var v: PackedStringArray = String(args.get("cam_abs", "0,0,3.5,0,-17.65")).split(",")
		var yaw: float = deg_to_rad(float(v[3]))
		var pitch: float = deg_to_rad(float(v[4]))
		var eye: Vector3 = Vector3(float(v[0]), float(v[2]), float(v[1]))
		cam.fov = 70.0
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.look_at_from_position(eye, eye + Vector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch)), Vector3.UP)
		return
	var c: Array = CAMS.get(which, CAMS["side"])
	cam.fov = float(c[2])
	cam.keep_aspect = Camera3D.KEEP_WIDTH if WIDE.has(which) else Camera3D.KEEP_HEIGHT
	cam.look_at_from_position(_at(about, c[0]), _at(about, c[1]), Vector3.UP)


## [forward, right, up] in the figure's frame to the scene: the figure faces -Z with its right on +X.
func _at(about: Node3D, fru: Array) -> Vector3:
	return about.global_transform * Vector3(float(fru[1]), float(fru[2]), -float(fru[0]))


func _pose(sk: TLRigSkater, clip: String, key: int) -> void:
	if clip == "rest":
		sk.pose_rest()
	else:
		sk.pose_at(clip, float(key))


## The frame; square (the centre) for the four close cameras, whole for the game's.
func _grab(which: String) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if WIDE.has(which):
		return img
	var h: int = img.get_height()
	return img.get_region(Rect2i((img.get_width() - h) / 2, 0, h, h))


func _shots() -> void:
	var list: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(args.get("shots", ""))))
	var outdir: String = String(args.get("outdir", "")).trim_suffix("/")
	if not (list is Array) or outdir == "":
		_done("--shots=<file.json> and --outdir=<folder> are needed")
		return
	DirAccess.make_dir_recursive_absolute(outdir)
	var saved: int = 0
	for shot: Dictionary in list as Array:
		var clip: String = String(shot["clip"])
		var key: int = int(shot["key"])
		if clip != "rest" and not TLRigSkater.clip_library().has_animation(clip):
			continue
		_cam_to(String(shot["cam"]), skater)
		_pose(skater, clip, key)
		var img: Image = await _grab(String(shot["cam"]))
		if not WIDE.has(String(shot["cam"])):
			img.resize(720, 720, Image.INTERPOLATE_LANCZOS)
		if img.save_png("%s/%s_k%03d_%s.png" % [outdir, clip, key, shot["cam"]]) == OK:
			saved += 1
	report["shots_asked"] = (list as Array).size()
	report["shots_saved"] = saved
	_done("" if saved == (list as Array).size() else "%d of %d shots saved" % [saved, (list as Array).size()])


## The ten skaters of a match, one tile each: the top row from behind (the number), the bottom row from the front
## (the crest), blue then orange.
func _ten() -> void:
	var px: int = int(args.get("px", "360"))
	var clip: String = String(args.get("clip", "Glide"))
	var sheet: Image = Image.create(10 * px, 2 * px, false, Image.FORMAT_RGB8)
	var asked: Array = []
	for team: int in range(2):
		for slot: int in range(5):
			var n: int = int(NUMBERS[team][slot])
			skater.queue_free()
			skater = _skater(team, n)
			_pose(skater, clip, int(args.get("key", "0")))
			asked.append(n)
			var views: Array = ["back", "front"]
			for row: int in range(2):
				_cam_to(String(views[row]), skater)
				var img: Image = await _grab(String(views[row]))
				img.resize(px, px, Image.INTERPOLATE_LANCZOS)
				sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i((team * 5 + slot) * px, row * px))
	var out: String = String(args.get("out", "user://look_ten.png"))
	report["saved"] = sheet.save_png(out) == OK
	report["numbers"] = asked
	_done("" if bool(report["saved"]) else "sheet not saved")


## The share of pixels of `box` (in the 720 px square frame) for which `test` holds.
func _share(img: Image, box: Rect2i, test: Callable) -> float:
	var k: float = float(img.get_height()) / 720.0
	var n: int = 0
	var all: int = 0
	for y: int in range(int(box.position.y * k), int(box.end.y * k)):
		for x: int in range(int(box.position.x * k), int(box.end.x * k)):
			all += 1
			if bool(test.call(img.get_pixel(x, y))):
				n += 1
	return float(n) / float(maxi(all, 1))


## How far apart the dark and the light of `box` are: the 95th less the 5th percentile of its luminance.
func _spread(img: Image, box: Rect2i) -> float:
	var k: float = float(img.get_height()) / 720.0
	var lum: Array = []
	for y: int in range(int(box.position.y * k), int(box.end.y * k)):
		for x: int in range(int(box.position.x * k), int(box.end.x * k)):
			lum.append(img.get_pixel(x, y).get_luminance())
	lum.sort()
	return float(lum[lum.size() * 95 / 100]) - float(lum[lum.size() * 5 / 100])


func _check() -> void:
	const PATCH: Rect2i = Rect2i(378, 282, 68, 50)        # inside the patch's stitching, back camera, Stride key 0
	const CREST: Rect2i = Rect2i(378, 330, 28, 26)        # the crest on the chest, front camera
	var dark: Callable = func(c: Color) -> bool: return c.get_luminance() < 0.12
	var ink: Dictionary = {}
	_pose(skater, "Stride", 0)
	for n: int in [11, 88]:
		skater.SetNumber(n)
		_cam_to("back", skater)
		var back: Image = await _grab("back")
		ink[n] = _share(back, PATCH, dark)
	_cam_to("front", skater)
	var front: Image = await _grab("front")
	if args.has("out"):
		front.save_png(String(args["out"]))
	var crest: float = _spread(front, CREST)
	var felt: bool = TLRigSkaterLook.chosen() == "felt"
	var ok: bool = (float(ink[11]) > 0.04 and float(ink[88]) > float(ink[11]) * 1.3 and crest > 0.08) if felt else (float(ink[88]) < 0.02 and crest < 0.04)
	print("LOOK render ok=%s look=%s ink11=%.3f ink88=%.3f crest_spread=%.3f rig_lights=%d" % ["true" if ok else "false", TLRigSkaterLook.chosen(), float(ink[11]), float(ink[88]), crest, TLStyleFelt.rig_size()])
	_done("" if ok else "the number or the crest is not in the picture")


## Ten skaters before the game camera, animated (the Stride clip, plain playback): the time of a frame.
func _cost() -> void:
	skater.queue_free()
	var crowd: Array = []
	for team: int in range(2):
		for slot: int in range(5):
			var sk: TLRigSkater = _skater(team, int(NUMBERS[team][slot]))
			sk.position = Vector3(2.0 + 2.2 * float(slot), 0.0, -3.0 + 6.0 * float(team) + 0.8 * float(slot % 2))
			sk.play_clip(&"Stride", true)
			sk.visible = not args.has("hidden")
			crowd.append(sk)
	var anchor: Node3D = Node3D.new()
	anchor.rotation.y = -PI * 0.5
	add_child(anchor)
	_cam_to("game", anchor)
	report["skaters"] = crowd.size()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	report["hidden"] = args.has("hidden")
	set_meta(&"crowd", crowd)
	_cost_left = int(args.get("frames", "300")) + 60


func _process(_dt: float) -> void:
	if _cost_left < 0:
		return
	for sk: TLRigSkater in get_meta(&"crowd") as Array:
		sk.tick()
	var now: int = Time.get_ticks_usec()
	if _cost_left <= int(args.get("frames", "300")) and _cost_t > 0:
		_cost_usec.append(now - _cost_t)
		_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
	_cost_t = now
	_cost_left -= 1
	if _cost_left == 0:
		_cost_left = -1
		_cost_usec.sort()
		var sum: int = 0
		for u: int in _cost_usec:
			sum += u
		report["frames"] = _cost_usec.size()
		report["frame_ms_mean"] = snappedf(float(sum) / float(_cost_usec.size()) / 1000.0, 0.001)
		report["frame_ms_median"] = snappedf(float(_cost_usec[_cost_usec.size() / 2]) / 1000.0, 0.001)
		report["gpu_ms_mean"] = snappedf(_gpu_ms / float(_cost_usec.size()), 0.001)
		report["render_cpu_ms_mean"] = snappedf(_cpu_ms / float(_cost_usec.size()), 0.001)
		if args.has("out"):
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png(String(args["out"]))
		_done("")


func _done(err: String) -> void:
	report["ok"] = err == ""
	if err != "":
		report["error"] = err
	print("%s look gym" % ("PASS" if err == "" else "FAIL"))
	print("tl.skater.look_gym/1 " + JSON.stringify(report))
	get_tree().quit(0 if err == "" else 1)
