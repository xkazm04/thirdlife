extends SceneTree
## Our side of the arena's side-by-side: lane K3's rink (engine/packs/hokej/gen/tj_rink.gd, the regular cartridge) with
## the core's hall round it, seen from given camera poses (thirdjam's own, read from its camera log), one PNG a pose.
##   godot --path engine --resolution 1280x720 -s res://tools/arena/shots.gd -- --shots=<json> --out=<folder>
##        [--arena=0] [--hall=1] [--cost=1] [--gain=<tone gain>] [--post=0] [--marks=0]
## --shots: [{"name": "centre", "pos_m": [x, y, h], "pitch": deg, "yaw": deg, "hfov": deg}, ...] in thirdjam's rink
##          axes and Unreal's angles (the same file export_arena.py takes). --arena=0: the rink alone. --hall=1: lane K3's
##          plain dark box in place of the arena (what stood before). --cost=1: per pose, the measured render time of
##          the viewport (CPU and GPU, mean of 90 frames) with the hall, with the hall without its fans, without it.
##          --marks=0: lane K3's rink mesh (boards, markings, goals) hidden, to see the hall's own surfaces alone.
## Needs a window (a picture). Prints `tl.arena.shots/1 {...}` last.

const WARM: int = 40
const SETTLE: int = 30
const COST_FRAMES: int = 90

var shots: Array = []
var out_dir := ""
var cam: Camera3D
var world: Node3D
var arena_node: Node3D
var i := -1
var wait := 0
var frame := 0
var want_cost := false
var cost_phase := 0
var cost_acc := Vector2.ZERO
var cost_n := 0
var rep := {"shots": [], "cost": []}
var arena_on := true
var hall_box := false
var gain := -1.0
var lit := false
var no_post := false
var marks: Node3D = null
var show_marks := true


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = JSON.parse_string(FileAccess.get_file_as_string(a.substr(8)))
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a == "--arena=0":
			arena_on = false
		elif a == "--hall=1":
			hall_box = true
		elif a == "--marks=0":
			show_marks = false
		elif a == "--post=0":
			no_post = true
		elif a == "--cost=1":
			want_cost = true
		elif a.begins_with("--gain="):
			gain = float(a.substr(7))
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = Node3D.new()
	world.name = "World"
	get_root().add_child(world)
	TLStyle.install(world)
	var cart: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://packs/hokej/data/hockey.regular.cartridge.json"))
	var gym: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://packs/hokej/data/gym.json"))
	var rk: Dictionary = cart["game"]["rink"]
	var rink_gen: GDScript = load("res://packs/hokej/gen/tj_rink.gd")
	var rink_node: Node3D = rink_gen.build(world, rk, gym.get("hall", {}) if hall_box else {})
	marks = rink_node.get_node_or_null("TjRink")
	if arena_on and not hall_box:
		var arena: GDScript = load("res://cores/rink/arena/rink_arena.gd")
		var opt := {"rink": rk}
		if gain > 0.0:
			opt["tone_gain"] = gain
		arena_node = arena.build(world, opt)
		rep["roof_light"] = arena.roof_light(gain if gain > 0.0 else arena.TONE_GAIN)
	else:
		rep["roof_light"] = gym["hall"]["light"]
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 0.1
	cam.far = 400.0
	world.add_child(cam)
	cam.make_current()
	RenderingServer.viewport_set_measure_render_time(get_root().get_viewport_rid(), true)


func _place(s: Dictionary) -> void:
	var p: Array = s["pos_m"]
	var pitch: float = deg_to_rad(float(s["pitch"]))
	var yaw: float = deg_to_rad(float(s["yaw"]))
	var eye := Vector3(float(p[0]), float(p[2]), float(p[1]))
	var fwd := Vector3(cos(pitch) * cos(yaw), sin(pitch), cos(pitch) * sin(yaw))
	cam.fov = float(s.get("hfov", 70.0))
	cam.look_at_from_position(eye, eye + fwd, Vector3.UP)
	cam.reset_physics_interpolation()      # a new pose is a cut, not a move


func _process(_dt: float) -> bool:
	frame += 1
	if not lit and frame >= 2:
		TLStyleHall.apply(world, rep["roof_light"])
		if arena_node != null and not no_post:
			TLStyleArena.post(world, load("res://cores/rink/arena/rink_arena.gd").hall_post())
		lit = true
	if marks != null and frame == 2:
		marks.visible = show_marks
	if frame < WARM:
		if frame == 3 and not shots.is_empty():
			_place(shots[0])
		return false
	if wait > 0:
		wait -= 1
		if cost_phase > 0 and wait < COST_FRAMES:
			var vp: RID = get_root().get_viewport_rid()
			cost_acc += Vector2(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(), RenderingServer.viewport_get_measured_render_time_gpu(vp))
			cost_n += 1
		if wait == 0:
			_step()
		return false
	i += 1
	if i >= shots.size():
		print("tl.arena.shots/1 " + JSON.stringify(rep))
		quit(0)
		return true
	_place(shots[i])
	cost_phase = 0
	wait = SETTLE
	return false


func _step() -> void:
	var s: Dictionary = shots[i]
	if cost_phase == 0:
		var img: Image = get_root().get_texture().get_image()
		var path: String = out_dir.path_join(str(s["name"]) + ".png")
		img.save_png(path)
		(rep["shots"] as Array).append({"name": s["name"], "file": path, "size": [img.get_width(), img.get_height()],
			"eye": [cam.global_position.x, cam.global_position.y, cam.global_position.z], "looks": [-cam.global_basis.z.x, -cam.global_basis.z.y, -cam.global_basis.z.z]})
		if want_cost and arena_node != null:
			(rep["cost"] as Array).append({"name": s["name"]})
			_cost_next(1)
		return
	# 1 = the whole hall, 2 = the hall without its fans, 3 = no hall (lane K3's rink alone)
	var row: Dictionary = (rep["cost"] as Array)[-1]
	var key: String = ["", "hall", "no_fans", "no_hall"][cost_phase]
	row[key + "_cpu_ms"] = cost_acc.x / cost_n
	row[key + "_gpu_ms"] = cost_acc.y / cost_n
	if cost_phase == 1:
		_fans(false)
		_cost_next(2)
	elif cost_phase == 2:
		_fans(true)
		arena_node.visible = false
		_cost_next(3)
	else:
		arena_node.visible = true
		cost_phase = 0


func _cost_next(phase: int) -> void:
	cost_phase = phase
	cost_acc = Vector2.ZERO
	cost_n = 0
	wait = COST_FRAMES + SETTLE


func _fans(on: bool) -> void:
	for n: Node in arena_node.get_children():
		if str(n.name).begins_with("Fan_"):
			(n as Node3D).visible = on
