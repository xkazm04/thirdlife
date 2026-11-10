extends Node3D
## Scene root. Builds the world, then runs one mode:
##   (none)                 interactive: WASD + mouse orbit, B crumble, N nitro_pass, H site_advance, R reset
##   --capture=<cam>        [--t=<s>] [--fire=a,b] [--seed=n] [--out=name] [--cam=px,py,pz,lx,ly,lz,fov] -> captures/b_<cam>.png
##   --stats                15 s of the hero view -> one JSON line   (add --fire=crumble --wait=8 to measure after settling)
##   --movie=<name>         relaunches itself with --write-movie (60 fps fixed), 20 s -> captures/b_<name>.mp4
## Common: --style=<name> (data/style_<name>.json), --ink=0 (no outline pass), --nofog, --res via engine --resolution.

const MOVIE_SECONDS: float = 20.0

var args: Dictionary = {}
var world: World
var sim: Sim
var player: Player
var stage: Dictionary = {}
var cam: Camera3D
var cams: Dictionary = {}
var frame: int = 0
var mode: String = "play"
var cap_name: String = ""
var sim_time: float = 0.0
var t_target: float = 0.0
var fire_list: PackedStringArray = PackedStringArray()
var fired: bool = false
var frame_ms: PackedFloat32Array = PackedFloat32Array()
var stats_start_ms: int = 0
var stats_wait: float = 0.0
var movie_events: Array = []
var shots: Array = []
var movie_prof_ms: int = 0
var gpu_sum: float = 0.0
var cpu_sum: float = 0.0


func _ready() -> void:
	args = Style.user_args
	if args.has("movie"):
		_relaunch_movie(String(args["movie"]))
		return
	Engine.max_fps = 0
	seed(int(args.get("seed", "1")))
	var f: FileAccess = FileAccess.open("res://data/cams.json", FileAccess.READ)
	cams = JSON.parse_string(f.get_as_text())
	stage = Stage.build(self, String(args.get("ink", "1")) != "0", String(args.get("grade", "1")) != "0")
	if args.has("nofog") or args.get("capture", "") == "map":
		(stage["env"] as Environment).fog_enabled = false
	if args.has("noshadow"):
		(stage["sun"] as DirectionalLight3D).shadow_enabled = false
	world = World.new()
	world.name = "World"
	world.stage = stage
	add_child(world)
	world.load_layout(String(args.get("layout", "")))
	cams.merge(world.L.get("cams", {}), true)
	world.build()
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.far = 6000.0
	cam.near = 0.15
	add_child(cam)
	cam.current = true
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.setup(world.terrain, cam)
	player.blockers = world.blockers
	sim = Sim.new()
	sim.name = "Sim"
	add_child(sim)
	sim.setup(world)
	fire_list = String(args.get("fire", "")).split(",", false)
	player.force_anim = String(args.get("anim", ""))
	if args.has("face"):   # --face=<mood 0..1>,<blink 0..1>
		var fv: PackedStringArray = String(args["face"]).split(",")
		player.face_fixed = Vector2(float(fv[0]), float(fv[1]) if fv.size() > 1 else 0.0)
	if args.has("walk"):
		var wv: PackedStringArray = String(args["walk"]).split(",")
		player.auto_move = Vector3(float(wv[0]), 0, float(wv[1]))
	if args.has("capture"):
		mode = "capture"
		cap_name = String(args["capture"])
		t_target = float(args.get("t", "0"))
		_set_cam(cap_name)
		player.active = args.has("chase")
	elif args.has("stats"):
		mode = "stats"
		stats_wait = float(args.get("wait", "0"))
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		_set_cam("hero")
	elif args.has("play-test"):
		mode = "playtest"
		player.active = true
		player.test_mode = true
		Input.use_accumulated_input = false   # pass 4: an injected motion event must not be merged with a real one
		Engine.time_scale = 2.0
	elif args.has("movie-run"):
		mode = "movie"
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), args.has("movie-prof"))
		_setup_movie()
	else:
		mode = "play"
		player.active = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if args.has("kitstats"):
		_kitstats()
	if args.has("cam"):
		var v: PackedStringArray = String(args["cam"]).split(",")
		cam.position = Vector3(float(v[0]), float(v[1]), float(v[2]))
		cam.look_at(Vector3(float(v[3]), float(v[4]), float(v[5])), Vector3.UP)
		if v.size() > 6:
			cam.fov = float(v[6])


func _set_cam(name_: String, drift: float = 0.0) -> void:
	var c: Dictionary = cams.get(name_, cams["hero"])
	cam.fov = float(c["fov"])
	var p: Array = c["pos"]
	var l: Array = c["look"]
	var pos: Vector3 = Vector3(p[0], p[1], p[2])
	var look: Vector3 = Vector3(l[0], l[1], l[2])
	if drift != 0.0:
		var side: Vector3 = (look - pos).normalized().cross(Vector3.UP).normalized()
		pos += side * drift + (look - pos).normalized() * absf(drift) * 0.6
	cam.position = pos
	cam.look_at(look, Vector3.UP)


func _unhandled_input(ev: InputEvent) -> void:
	if mode != "play" and mode != "playtest":
		return
	for a: String in ["crumble", "nitro_pass", "site_advance", "reset"]:
		if ev.is_action_pressed(a):
			sim.fire(a)
			if a == "reset":
				player.reset()


func _process(delta: float) -> void:
	frame += 1
	if mode == "capture":
		if frame > 6:
			if not fired:
				fired = true
				sim_time = 0.0
				if t_target > 0.0:   # a timed capture shows the cars where the layout puts them, not t seconds further on
					sim.rewind_cars(t_target)
				for e: String in fire_list:
					sim.fire(e)
			sim_time += minf(delta, 0.05)
		if frame > 14 and sim_time >= t_target:
			mode = "done"
			_do_capture()
	elif mode == "stats":
		if frame > 6 and not fired:
			fired = true
			for e: String in fire_list:
				sim.fire(e)
		if frame > 40:
			sim_time += delta
			if sim_time < stats_wait:
				return
			frame_ms.append(delta * 1000.0)
			var vr: RID = get_viewport().get_viewport_rid()
			gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(vr)
			cpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(vr) + RenderingServer.get_frame_setup_time_cpu()
			if stats_start_ms == 0:
				stats_start_ms = Time.get_ticks_msec()
			elif Time.get_ticks_msec() - stats_start_ms > 15000:
				mode = "done"
				_do_stats()
	elif mode == "movie":
		_movie_step()
	elif mode == "playtest":
		_playtest(delta)


func _do_capture() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://captures/b_%s.png" % String(args.get("out", cap_name)))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	if sim.crumbled:
		print("[wall] chunks awake %d of %d at t=%.1f" % [sim.wall_awake(), sim.wall_bodies.size(), sim_time])
	print("captured ", path, " ", img.get_width(), "x", img.get_height())
	get_tree().quit()


func _do_stats() -> void:
	var s: PackedFloat32Array = frame_ms.duplicate()
	s.sort()
	var n: int = s.size()
	var sum: float = 0.0
	for v: float in s:
		sum += v
	var vp: Vector2i = get_viewport().size
	var d: Dictionary = {
		"lane": "b",
		"gpu": RenderingServer.get_video_adapter_name(),
		"res": "%dx%d" % [vp.x, vp.y],
		"fps_avg": snappedf(1000.0 / (sum / n), 0.1),
		"frame_ms_p50": snappedf(s[n / 2], 0.01),
		"frame_ms_p99": snappedf(s[int(n * 0.99)], 0.01),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"vram_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"style": Style.style_name,
		"ink": String(args.get("ink", "1")) != "0",
		"frames": n,
		"gpu_ms": snappedf(gpu_sum / n, 0.001),
		"cpu_render_ms": snappedf(cpu_sum / n, 0.001),
	}
	if sim.crumbled:
		d["wall_chunks_awake"] = sim.wall_awake()
		d["wall_bodies_left"] = sim.wall_bodies.size()
		d["rubble_baked"] = sim.rubble != null
	print(JSON.stringify(d))
	get_tree().quit()


# ------------------------------------------------------------------------------------------------ movie
func _relaunch_movie(mname: String) -> void:
	var dir: String = ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	var avi: String = dir.path_join("b_%s.avi" % mname)
	var mp4: String = dir.path_join("b_%s.mp4" % mname)
	var a: PackedStringArray = PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--position", "0,1440", "--resolution", "1920x1080",
		"--fixed-fps", "60", "--write-movie", avi, "res://look.tscn", "--", "--movie-run=" + mname])
	if args.has("style"):
		a.append("--style=" + String(args["style"]))
	var out: Array = []
	OS.execute(OS.get_executable_path(), a, out, true)
	OS.execute("ffmpeg", PackedStringArray(["-y", "-loglevel", "error", "-i", avi, "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", mp4]), out, true)
	DirAccess.remove_absolute(avi)
	print("movie ", mp4)
	get_tree().quit()


func _setup_movie() -> void:
	# [start s, cam name, drift m/s]
	shots = [[0.0, "hero", 0.25], [5.5, "site", -0.5], [11.0, "track", 0.4], [16.5, "avatar", 0.12]]
	movie_events = [[2.0, "site_advance"], [6.5, "site_advance"], [10.95, "cars_home"], [11.6, "nitro_pass"], [12.6, "crumble"]]
	player.auto_move = Vector3.ZERO


func _movie_step() -> void:
	var t: float = float(frame) / 60.0
	for e: Array in movie_events:
		if e.size() == 2 and t >= float(e[0]):
			sim.fire(String(e[1]))
			e.append(true)
	var cur: Array = shots[0]
	for s: Array in shots:
		if t >= float(s[0]):
			cur = s
	_set_cam(String(cur[1]), (t - float(cur[0]) - 2.5) * float(cur[2]))
	if args.has("movie-prof") and frame % 60 == 0:
		var now: int = Time.get_ticks_msec()
		var vr: RID = get_viewport().get_viewport_rid()
		print("[movie] t=%.0f s  wall %d ms per 60 frames  process %.2f ms  gpu %.2f ms  cpu_render %.2f ms" % [t, now - movie_prof_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_gpu(vr), RenderingServer.viewport_get_measured_render_time_cpu(vr) + RenderingServer.get_frame_setup_time_cpu()])
		movie_prof_ms = now
	if t >= float(args.get("secs", MOVIE_SECONDS)):
		get_tree().quit()


## --kitstats: triangle counts per generated part (for the authoring ledger), then quit.
func _kitstats() -> void:
	var rows: Dictionary = {}
	var total: int = 0
	for n: Node in find_children("*", "GeometryInstance3D", true, false):
		var tris: int = 0
		var label: String = String(n.name)
		if n is MultiMeshInstance3D:
			var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
			var per: int = 0
			for si: int in mm.mesh.get_surface_count():
				per += mm.mesh.surface_get_array_len(si) / 3
			tris = per * mm.instance_count
			label = "scatter:%s x%d (%d tris each)" % [mm.mesh.resource_name, mm.instance_count, per]
		elif n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
			var m: ArrayMesh = (n as MeshInstance3D).mesh
			for si: int in m.get_surface_count():
				tris += m.surface_get_array_len(si) / 3
			label = m.resource_name if m.resource_name != "" else String(n.name)
		else:
			continue
		rows[label] = int(rows.get(label, 0)) + tris
		total += tris
	var keys: Array = rows.keys()
	keys.sort()
	for k: String in keys:
		print("[kit] %-44s %8d" % [k, rows[k]])
	print("[kit] TOTAL %d" % total)
	get_tree().quit()


# ------------------------------------------------------------------------------------------------ play test
## Drives the game through the REAL input path (Input.action_press, Input.parse_input_event) and asserts by state.
var pt_i: int = 0
var pt_t: float = 0.0
var pt_fail: int = 0
var pt_n: int = 0
var pt: Dictionary = {}


func _pt(label: String, ok: bool, detail: String = "") -> void:
	pt_n += 1
	if not ok:
		pt_fail += 1
	print("[play_test] %s  %s  %s" % ["PASS" if ok else "FAIL", label, detail])


func _act(a: String) -> void:
	var e: InputEventAction = InputEventAction.new()
	e.action = a
	e.pressed = true
	Input.parse_input_event(e)


func _mouse(rel: Vector2) -> void:
	var e: InputEventMouseMotion = InputEventMouseMotion.new()
	e.relative = rel
	e.device = Player.TEST_DEVICE
	Input.parse_input_event(e)


func _dyn_rib() -> Dictionary:
	for r: Dictionary in world.ribs:
		if not r["static"]:
			return r
	return {}


func _playtest(delta: float) -> void:
	if frame < 20:
		return
	pt_t += delta
	var car_b: Dictionary = sim.cars[1]
	match pt_i:
		0:
			pt["p0"] = player.position
			Input.action_press("move_forward")
			pt_i = 1; pt_t = 0.0
		1:
			if pt_t >= 13.0:
				Input.action_release("move_forward")
				var p: Vector3 = player.position
				var moved: float = Vector2(p.x, p.z).distance_to(Vector2((pt["p0"] as Vector3).x, (pt["p0"] as Vector3).z))
				_pt("walk: avatar moved off the ridge", moved > 20.0, "moved %.1f m" % moved)
				_pt("walk: avatar is on the ground", absf(p.y - world.terrain.h(p.x, p.z)) < 0.15, "y %.2f ground %.2f" % [p.y, world.terrain.h(p.x, p.z)])
				_pt("walk: avatar reached the valley", p.y < -8.0, "y %.2f" % p.y)
				_mouse(Vector2(0, 4000))
				pt_i = 2; pt_t = 0.0
		2:
			if pt_t >= 0.2:
				_pt("orbit: pitch clamps at 60", is_equal_approx(player.pitch, 60.0), "pitch %.1f" % player.pitch)
				_mouse(Vector2(150, -8000))
				pt_i = 3; pt_t = 0.0
		3:
			if pt_t >= 0.2:
				_pt("orbit: pitch clamps at 30", is_equal_approx(player.pitch, 30.0), "pitch %.1f" % player.pitch)
				_pt("orbit: yaw is free", absf(player.yaw + 30.0) < 0.5, "yaw %.1f" % player.yaw)
				pt["rib"] = _dyn_rib()
				_act("site_advance")
				pt_i = 4; pt_t = 0.0
		4:
			if pt_t >= 5.4:
				var r: Dictionary = pt["rib"]
				if r.is_empty():   # layout C edit: a layout may have no roof at all
					_pt("site_advance: nothing to build in this layout (no hologram rib), no error", sim.active_rib < 0)
				else:
					_pt("site_advance: next hologram rib is built", is_equal_approx(float(r["build"]), 1.0) and not (r["holo"] as Node3D).visible and (r["built"] as Node3D).visible, "build %.2f" % float(r["build"]))
				_act("nitro_pass")
				pt_i = 5; pt_t = 0.0
		5:
			if pt_t >= 1.0:
				_pt("nitro_pass: car B is boosting", float(car_b["v"]) > Sim.CRUISE + 5.0 and ((car_b["node"] as Node3D).get_node("Nitro") as Node3D).visible, "v %.1f m/s" % float(car_b["v"]))
				_act("crumble")
				pt_i = 6; pt_t = 0.0
		6:
			if pt_t >= 0.5:
				_pt("crumble: wall chunks are awake rigid bodies", sim.wall_bodies.size() > 0 and sim.wall_awake() > 0, "%d bodies, %d awake" % [sim.wall_bodies.size(), sim.wall_awake()])
				pt_i = 7; pt_t = 0.0
		7:
			if pt_t >= 8.0:
				_pt("crumble: rubble settled and baked to one mesh", sim.rubble != null and sim.wall_bodies.size() == 0, "bodies left %d" % sim.wall_bodies.size())
				_act("reset")
				pt_i = 8; pt_t = 0.0
		8:
			if pt_t >= 0.2:
				var r2: Dictionary = pt["rib"]
				var p2: Vector3 = player.position
				_pt("reset: rib is a hologram again", r2.is_empty() or (is_equal_approx(float(r2["build"]), 0.0) and (r2["holo"] as Node3D).visible and not (r2["built"] as Node3D).visible))
				var intact: bool = true
				for blk: Dictionary in sim.wall_blocks:
					intact = intact and (blk["node"] as Node3D).visible
				_pt("reset: wall is intact, no rubble, no bodies", intact and not sim.crumbled and sim.rubble == null and sim.wall_bodies.size() == 0)
				_pt("reset: car B back at its start, no nitro", absf(float(car_b["s"]) - float(car_b["s0"])) < 8.0 and float(car_b["nitro"]) <= 0.0 and float(car_b["v"]) <= Sim.CRUISE + 0.01, "ds %.1f m" % (float(car_b["s"]) - float(car_b["s0"])))
				_pt("reset: avatar back at the start, on the ground", Vector2(p2.x, p2.z).length() < 0.1 and absf(p2.y - world.terrain.h(0, 0)) < 0.2, "pos %s" % p2)
				_pt("reset: camera back to its initial pitch and yaw", is_equal_approx(player.pitch, Player.PITCH0) and is_equal_approx(player.yaw, 0.0), "pitch %.1f yaw %.1f" % [player.pitch, player.yaw])
				# collision: aim the camera at a boulder with real mouse motion and walk into it
				var rk: Array = world.L["hero_rocks"][1]
				var dir: Vector2 = Vector2(rk[0], rk[1]).normalized()
				var yaw_deg: float = rad_to_deg(atan2(-dir.x, -dir.y))
				_mouse(Vector2(-yaw_deg / 0.2, 0))
				pt["rock"] = Vector2(rk[0], rk[1])
				pt["rock_r"] = float(rk[2]) * 0.85
				pt["min_d"] = 1e9
				Input.action_press("move_forward")
				pt_i = 9; pt_t = 0.0
		9:
			var d: float = Vector2(player.position.x, player.position.z).distance_to(pt["rock"])
			pt["min_d"] = minf(float(pt["min_d"]), d)
			if pt_t >= 5.0:
				Input.action_release("move_forward")
				_pt("collision: avatar reached the boulder but never entered it", float(pt["min_d"]) >= float(pt["rock_r"]) + 0.3 and float(pt["min_d"]) < float(pt["rock_r"]) + 0.6, "closest %.2f m, radius %.2f m" % [float(pt["min_d"]), float(pt["rock_r"])])
				print("[play_test] RESULT %s  %d of %d assertions passed" % ["PASS" if pt_fail == 0 else "FAIL", pt_n - pt_fail, pt_n])
				pt_i = 10
				get_tree().quit(0 if pt_fail == 0 else 1)
