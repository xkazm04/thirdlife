extends SceneTree
## Our side of the reactions' side-by-side (K6 round 3): the pack's rink (lane K3's gen/tj_rink.gd with thirdjam's own goals
## from the hall, as main.gd builds it) inside the core's hall, its reactions fed an event of thirdjam's own match, one
## PNG a moment from a given camera pose (thirdjam's, read from its JAMCAM log, or a close-up of our choosing).
##   godot --path engine --resolution 1280x720 -s res://tools/arena/react_shots.gd -- --moments=<json> --out=<folder>
## --moments: [{"name", "pos_m": [x, y, h], "pitch", "yaw", "hfov", "events": [[frame, name, kind, x, y, strength], ...],
##              "at": frame}, ...] in thirdjam's rink axes and Unreal's angles: the reactions are put at rest, the events
##              fed on their frames, every frame advanced up to `at`, then the picture is taken (nothing moves while it
##              settles: the reactions are only advanced by frame()).
## Needs a window (a picture). Prints `tl.arena.react_shots/1 {...}` last.

const WARM: int = 40
const SETTLE: int = 12

var moments: Array = []
var out_dir := ""
var cam: Camera3D
var world: Node3D
var react: RefCounted
var arena: GDScript
var i := -1
var wait := 0
var frame := 0
var rep := {"shots": []}


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--moments="):
			moments = JSON.parse_string(FileAccess.get_file_as_string(a.substr(10)))
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = Node3D.new()
	world.name = "World"
	get_root().add_child(world)
	TLStyle.install(world)
	var cart: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://packs/hokej/data/hockey.regular.cartridge.json"))
	var rk: Dictionary = cart["game"]["rink"]
	arena = load("res://cores/rink/arena/rink_arena.gd")
	# main.gd's _arena_marks: the Markings colours of the hall, and the hall's own goals
	var t: Dictionary = arena.table()
	var mats: Array = ((t.get("rink_surfaces", {}) as Dictionary).get("Markings", {}) as Dictionary).get("materials", [])
	var marks: Dictionary = {"arena_goals": true}
	for k: Array in [["red", 2], ["pale", 3]]:
		var c: Array = (((t["materials"] as Dictionary).get(String(mats[k[1]]), {}) as Dictionary).get("vectors", {}) as Dictionary).get("Color", [])
		marks[k[0]] = Color(float(c[0]), float(c[1]), float(c[2]))
	(load("res://packs/hokej/gen/tj_rink.gd") as GDScript).build(world, rk, {}, marks)
	arena.build(world, {"rink": rk, "goals": true})
	react = arena.reactions(world, rk)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 0.1
	cam.far = 400.0
	world.add_child(cam)
	cam.make_current()


func _place(s: Dictionary) -> void:
	var p: Array = s["pos_m"]
	var pitch: float = deg_to_rad(float(s["pitch"]))
	var yaw: float = deg_to_rad(float(s["yaw"]))
	var eye := Vector3(float(p[0]), float(p[2]), float(p[1]))
	var fwd := Vector3(cos(pitch) * cos(yaw), sin(pitch), cos(pitch) * sin(yaw))
	cam.fov = float(s.get("hfov", 70.0))
	cam.look_at_from_position(eye, eye + fwd, Vector3.UP)
	cam.reset_physics_interpolation()


func _stage(s: Dictionary) -> void:
	react.reset()
	var evs: Array = s.get("events", [])
	var from: int = int(s["at"])
	for e: Array in evs:
		from = mini(from, int(e[0]))
	react.frame({"Frame": -1, "Events": []})                       # a frame before: a restart puts everything at rest
	for f: int in range(from, int(s["at"]) + 1):
		var list: Array = []
		for e: Array in evs:
			if int(e[0]) == f:
				list.append({"Name": e[1], "Kind": e[2], "Where": Vector2(float(e[3]), float(e[4])), "Strength": float(e[5])})
		react.frame({"Frame": f, "Events": list})


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		arena.light(world)
	if frame < WARM:
		return false
	if wait > 0:
		wait -= 1
		if wait == 0:
			var s: Dictionary = moments[i]
			var img: Image = get_root().get_texture().get_image()
			var path: String = out_dir.path_join(str(s["name"]) + ".png")
			img.save_png(path)
			(rep["shots"] as Array).append({"name": s["name"], "file": path, "lamps": react.lamp_now.duplicate(), "net": [react.net_scale[0], react.net_scale[1]],
				"caps_off_rest": react.cap_now.size(), "cheer": [react.cheer_now.x, react.cheer_now.y]})
		return false
	i += 1
	if i >= moments.size():
		print("tl.arena.react_shots/1 " + JSON.stringify(rep))
		quit(0)
		return true
	_place(moments[i])
	_stage(moments[i])
	wait = SETTLE
	return false
