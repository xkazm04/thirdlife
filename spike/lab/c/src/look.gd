extends Node3D
## Lane C look-test scene (voxel). CLI (after --): --capture=<cam> [--t=s] [--fire=a,b] [--seed=n] [--style=overcast]
## [--out=name] | --stats | --movie=<name> ; experiments: --gi=none|sdfgi|ssil --vol=0|1 --ssao=0|1

var args: Dictionary = {}
var style: Style
var wb: WorldBuilder
var avatar: Avatar
var cam: Camera3D
var sun: DirectionalLight3D
var we: WorldEnvironment
var wall: Wall
var site: Site
var track: Track
var cars: Array = []
var smoke: GPUParticles3D
var hmap: PackedFloat32Array
var hm_dims: Array = []

var frames: int = 0
var phys_t: float = 0.0
var fire_phys_t: float = -1.0
var mode: String = "play"
var cam_name: String = "hero"
var yaw: float = 0.0
var pitch_deg: float = 42.0
var dist: float = 6.5
var ft: Array = []
var stat_phase: int = 0
var build_ms: int = 0
var movie_events: Array = []
var movie_len: float = 20.0
var shot_pending: bool = false

const GI_DEFAULT := "sdfgi"


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	seed(int(args.get("seed", "1")))
	if args.has("capture"):
		mode = "capture"
		cam_name = args["capture"]
	elif args.has("stats"):
		mode = "stats"
	elif args.has("movie"):
		mode = "movie"
	style = Style.new()
	style.load_file("res://data/style_overcast.json" if args.get("style", "") == "overcast" else "res://data/style.json")
	_build_world()
	_build_env()
	_build_actors()
	cam = Camera3D.new()
	cam.far = 1500.0
	cam.near = 0.08
	add_child(cam)
	cam.current = true
	if mode == "play":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		avatar.controllable = false
		_apply_cam(cam_name if mode == "capture" else "hero")
	build_ms = Time.get_ticks_msec() - t0
	print("built in %d ms; world stats %s" % [build_ms, wb.stats])
	if mode == "movie":
		movie_events = [[2.5, "site_advance"], [7.5, "nitro_pass"], [10.6, "crumble"], [15.5, "site_advance"]]


func _build_world() -> void:
	wb = WorldBuilder.new(style, self)
	wb.build_terrain()
	var f := FileAccess.open("res://assets/terrain_h.bin", FileAccess.READ)
	var nx := int(f.get_float())
	var nz := int(f.get_float())
	var x0 := f.get_float()
	var z0 := f.get_float()
	var res := f.get_float()
	hmap = f.get_buffer(nx * nz * 4).to_float32_array()
	hm_dims = [nx, nz, x0, z0, res]
	wb.build_vegetation()
	wb.build_clouds()
	var h := wb.build_house()
	smoke = h["smoke"]
	var arena := wb.build_arena()
	var s := wb.build_site()
	track = Track.new()
	track.load_from(wb.layout["track"])
	site = Site.new()
	add_child(site)
	site.setup(style, arena["ribs"], s["cranes"], arena["centre"], wb.site["bots"])
	wall = Wall.new()
	add_child(wall)
	wall.setup(style, wb.layout["wall"])


func ground_y(x: float, z: float) -> float:
	var ix := clampi(int((x - hm_dims[2]) / hm_dims[4]), 0, hm_dims[0] - 1)
	var iz := clampi(int((z - hm_dims[3]) / hm_dims[4]), 0, hm_dims[1] - 1)
	return hmap[iz * hm_dims[0] + ix]


func _build_env() -> void:
	sun = DirectionalLight3D.new()
	add_child(sun)
	style.apply_light(sun)
	we = WorldEnvironment.new()
	var gi: String = args.get("gi", GI_DEFAULT)
	we.environment = style.make_environment(gi, args.get("vol", "1") == "1", args.get("ssao", "1") == "1")
	add_child(we)
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X if args.get("msaa", "4") == "4" else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA


func _build_actors() -> void:
	avatar = Avatar.new()
	add_child(avatar)
	avatar.setup(style)
	avatar.position = Vector3(0, ground_y(0, 0) + 0.05, 0)
	var cdef: Dictionary = wb.site["cars"]
	for k: String in ["A", "B"]:
		var c := CarUnit.new()
		add_child(c)
		var d: Dictionary = cdef[k]
		c.setup(style, track, d["asset"], d["offset"], d["speed"], d["start"])
		c.step(0.0)
		cars.append(c)


# ------------------------------------------------------------------------------------------ camera
func _cam_data(name: String) -> Dictionary:
	return wb.site["cams"][name]


func _apply_cam(name: String) -> void:
	var c := _cam_data(name)
	cam.position = Vector3(c["pos"][0], c["pos"][1], c["pos"][2])
	cam.look_at(Vector3(c["look"][0], c["look"][1], c["look"][2]))
	cam.fov = c["fov"]


func _lerp_cam(a: String, b: String, u: float) -> void:
	var ca := _cam_data(a)
	var cb := _cam_data(b)
	var pa := Vector3(ca["pos"][0], ca["pos"][1], ca["pos"][2])
	var pb := Vector3(cb["pos"][0], cb["pos"][1], cb["pos"][2])
	var la := Vector3(ca["look"][0], ca["look"][1], ca["look"][2])
	var lb := Vector3(cb["look"][0], cb["look"][1], cb["look"][2])
	var w := smoothstep(0.0, 1.0, u)
	cam.position = pa.lerp(pb, w)
	cam.look_at(la.lerp(lb, w))
	cam.fov = lerpf(ca["fov"], cb["fov"], w)


func _chase_cam(delta: float) -> void:
	var tgt: Vector3 = avatar.global_position + Vector3(0, 1.45, 0)
	var p := deg_to_rad(pitch_deg)
	var off := Vector3(sin(yaw) * cos(p), sin(p), cos(yaw) * cos(p)) * dist
	var want := tgt + off
	cam.global_position = cam.global_position.lerp(want, clampf(delta * 14.0, 0, 1)) if frames > 2 else want
	cam.look_at(tgt)
	cam.fov = 62.0
	avatar.cam_yaw = yaw


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and mode == "play" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := e as InputEventMouseMotion
		yaw -= m.relative.x * 0.0035
		pitch_deg = clampf(pitch_deg + m.relative.y * 0.15, 30.0, 60.0)
	if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().quit()
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and mode == "play":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if e.is_action_pressed("crumble"):
		fire("crumble")
	if e.is_action_pressed("nitro_pass"):
		fire("nitro_pass")
	if e.is_action_pressed("site_advance"):
		fire("site_advance")
	if e.is_action_pressed("reset"):
		fire("reset")


func fire(ev: String) -> void:
	match ev:
		"crumble":
			wall.crumble()
		"nitro_pass":
			cars[1].fire_nitro()
		"site_advance":
			site.advance()
		"reset":
			wall.reset()
			site.reset_all()
			for i in cars.size():
				var d: Dictionary = wb.site["cars"]["AB"[i]]
				cars[i].station = d["start"]
				cars[i].nitro_t = -1.0
				cars[i].speed = cars[i].base_speed
				for f: GPUParticles3D in cars[i].flames:
					f.emitting = false
				cars[i].trail.emitting = false
			avatar.position = Vector3(0, ground_y(0, 0) + 0.05, 0)
			avatar.velocity = Vector3.ZERO


# ------------------------------------------------------------------------------------------ loop
func _physics_process(delta: float) -> void:
	phys_t += delta
	for c: CarUnit in cars:
		c.step(delta)


func _process(delta: float) -> void:
	frames += 1
	if mode == "play":
		_chase_cam(delta)
	elif mode == "capture":
		_capture_step()
	elif mode == "stats":
		_stats_step(delta)
	elif mode == "movie":
		_movie_step(delta)


func _capture_step() -> void:
	var c := _cam_data(cam_name)
	if frames == 30:
		fire_phys_t = phys_t
		var evs: Array = []
		for e: String in c.get("fire", []):
			evs.append(e)
		if args.has("fire"):
			for e: String in String(args["fire"]).split(","):
				evs.append(e)
		for e: String in evs:
			fire(e)
	if frames > 30 and not shot_pending:
		var wait := float(args["t"]) if args.has("t") else float(c.get("wait", 0.5))
		if phys_t - fire_phys_t >= wait and frames >= 150:
			shot_pending = true
			_take_shot()


func _take_shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var name: String = args.get("out", "%s%s" % [cam_name, "_overcast" if args.get("style", "") == "overcast" else ""])
	var path := ProjectSettings.globalize_path("res://captures/c_%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	var w := wall.sleeping_count()
	print("captured %s (%dx%d) debris bodies=%d asleep=%d" % [path, img.get_width(), img.get_height(), w.y, w.x])
	get_tree().quit()


func _stats_step(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if stat_phase == 0:
		fire_phys_t = t
		stat_phase = 1
	var el := t - fire_phys_t
	if el > 3.0 and el <= 15.0:
		ft.append(delta * 1000.0)
	if el > 15.0:
		ft.sort()
		var sum := 0.0
		for v: float in ft:
			sum += v
		var n := ft.size()
		var rd := RenderingServer
		var out := {
			"lane": "C", "gpu": rd.get_video_adapter_name(), "res": "%dx%d" % [get_viewport().size.x, get_viewport().size.y],
			"fps_avg": snappedf(1000.0 * n / sum, 0.1), "frame_ms_p50": snappedf(ft[n / 2], 0.01), "frame_ms_p99": snappedf(ft[int(n * 0.99)], 0.01),
			"draw_calls": rd.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": rd.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			"vram_mb": snappedf(rd.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 1.0),
			"gi": args.get("gi", GI_DEFAULT), "vol": args.get("vol", "1"), "ssao": args.get("ssao", "1"), "frames": n,
			"build_ms": build_ms, "style": args.get("style", "golden")}
		print(JSON.stringify(out))
		get_tree().quit()


func _movie_step(delta: float) -> void:
	var t := float(frames) / 60.0
	for e: Array in movie_events:
		if e[0] >= 0.0 and t >= e[0]:
			fire(e[1])
			e[0] = -1.0
	var seq := [[0.0, "hero"], [5.0, "site"], [8.0, "track"], [13.5, "avatar"], [20.0, "hero"]]
	for i in seq.size() - 1:
		var a: Array = seq[i]
		var b: Array = seq[i + 1]
		if t >= a[0] and t < b[0]:
			var u: float = (t - a[0]) / (b[0] - a[0])
			var hold := 0.35
			_lerp_cam(a[1], b[1], clampf((u - hold) / (1.0 - hold), 0.0, 1.0))
			break
	if t >= movie_len:
		get_tree().quit()
