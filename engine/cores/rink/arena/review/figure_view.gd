extends Node3D
## Figures in the hall, for the eye (lane K7, hockey port): thirdjam's hall as the core builds it, lit by its rig, with
## felt skaters standing where a still of the running game had them, seen by that still's own camera. Windowed:
##   godot --path engine --position 0,1440 --resolution 1280x720 res://cores/rink/arena/review/figure_view.tscn -- \
##         --shots=<file.json> --outdir=<folder> [--look=felt|cel]
## The file: [{"name": "f5360", "cam": [x, y, height, yaw, pitch], "figures": [{"team": 0, "number": 7,
##   "at": [x, y, yaw], "clip": "Stride", "key": 20}, ...]}, ...] in rink metres and Unreal's degrees (lane K6's camera
## log of the game). One PNG a shot (<name>.png, the window's frame). Prints `tl.rink.figure_view/1 {...}` last.

const Arena := preload("res://cores/rink/arena/rink_arena.gd")

var args: Dictionary = {}
var report: Dictionary = {"schema": "tl.rink.figure_view/1", "ok": false}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("look"):
		TLRigSkaterLook.default_variant = String(args["look"])
	TLStyle.install(self, {})
	var hall: Node3D = Arena.build(self, {"rink": {"length_m": 90.0, "width_m": 45.0, "corner_radius_m": 3.75}})
	Arena.light(self)
	report["hall"] = hall != null
	report["rig_lights"] = TLStyleFelt.rig_size()
	_shots.call_deferred()


func _shots() -> void:
	var list: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(args.get("shots", ""))))
	var outdir: String = String(args.get("outdir", "")).trim_suffix("/")
	if not (list is Array) or outdir == "":
		_done("--shots=<file.json> and --outdir=<folder> are needed")
		return
	DirAccess.make_dir_recursive_absolute(outdir)
	var cam: Camera3D = Camera3D.new()
	cam.far = 500.0
	cam.near = 0.1
	cam.fov = 70.0
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(cam)
	cam.make_current()
	var saved: int = 0
	var figs: Array = []
	for shot: Dictionary in list as Array:
		for f: Node in figs:
			f.queue_free()
		figs.clear()
		for row: Dictionary in shot["figures"] as Array:
			var sk: TLRigSkater = TLRigSkater.new()
			sk.setup({"team": int(row["team"])})
			sk.SetNumber(int(row["number"]))
			var at: Array = row["at"]
			sk.position = Vector3(float(at[0]), 0.0, float(at[1]))
			sk.rotation.y = -PI * 0.5 - deg_to_rad(float(at[2]))
			add_child(sk)
			sk.pose_at(String(row.get("clip", "Stride")), float(row.get("key", 0)))
			figs.append(sk)
		var c: Array = shot["cam"]
		var yaw: float = deg_to_rad(float(c[3]))
		var pitch: float = deg_to_rad(float(c[4]))
		var eye: Vector3 = Vector3(float(c[0]), float(c[2]), float(c[1]))
		cam.look_at_from_position(eye, eye + Vector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch)), Vector3.UP)
		for _i: int in range(4):
			await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		if img.save_png("%s/%s.png" % [outdir, String(shot["name"])]) == OK:
			saved += 1
	report["shots"] = saved
	_done("" if saved == (list as Array).size() else "%d of %d shots saved" % [saved, (list as Array).size()])


func _done(err: String) -> void:
	report["ok"] = err == ""
	if err != "":
		report["error"] = err
	print("%s figure view" % ("PASS" if err == "" else "FAIL"))
	print("tl.rink.figure_view/1 " + JSON.stringify(report))
	get_tree().quit(0 if err == "" else 1)
