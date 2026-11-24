extends Node3D
## Figures in the hall, for the eye (lane K7, hockey port): thirdjam's hall as the core builds it, lit by its rig, with
## felt skaters standing where a still of the running game had them, seen by that still's own camera. Windowed:
##   godot --path engine --position 0,1440 --resolution 1280x720 res://cores/rink/arena/review/figure_view.tscn -- \
##         --shots=<file.json> --outdir=<folder> [--look=felt|cel] [--keys=0] [--ink=0] [--keyopt=blur:1,atlas:8192]
##         [--cost=N] [--film=N [--speed=6]]      or      --check=shadow [--keys=0] [--out=<png>]   (selftest block 850, look.skater.shadow)
## The file: [{"name": "f5360", "cam": [x, y, height, yaw, pitch], "figures": [{"team": 0, "number": 7,
##   "at": [x, y, yaw], "clip": "Stride", "key": 20, "down": false}, ...]}, ...] in rink metres and Unreal's degrees (lane K6's camera
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
	if String(args.get("keys", "1")) == "0":      # --keys=0: the style sun's one shadow, as before round 3 (lane K7)
		TLStyleHallKeys.clear(self)
		for ice: Node in find_children("RinkIce", "MeshInstance3D", true, false):
			((ice as MeshInstance3D).get_active_material(0) as ShaderMaterial).set_shader_parameter(&"key_shadows", 0.0)
	if String(args.get("ink", "1")) == "0":       # --ink=0: the style's ink pass hidden (review)
		var rig0: Node = get_tree().root.find_child(TLStyle.RIG_NODE, true, false)
		var inkpost: Node3D = rig0.get_node_or_null("InkPost") as Node3D if rig0 != null else null
		if inkpost != null:
			inkpost.visible = false
	if args.has("keyopt"):                        # --keyopt=atlas:16384,blur:2 (review: TLStyleHallKeys' options)
		var ko: Dictionary = {}
		for kv: String in String(args["keyopt"]).split(","):
			var pair: PackedStringArray = kv.split(":")
			ko[pair[0]] = (pair[1] == "true") if pair[0] == "soft" else (float(pair[1]) if pair[0] in ["blur", "bias", "size_k", "cone_deg"] else int(pair[1]))
		TLStyleHallKeys.install(self, Arena.rig_lights(), ko)
		for ice: Node in find_children("RinkIce", "MeshInstance3D", true, false):
			TLStyleHallKeys.receive(ice as MeshInstance3D)
	report["keys"] = TLStyleHallKeys.count(self)
	report["hall"] = hall != null
	report["rig_lights"] = TLStyleFelt.rig_size()
	if args.has("check"):
		_check.call_deferred()
		return
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
			if bool(row.get("down", false)) and sk.get(&"takes") != null:      # a lying figure: the driver's own flag for its shade
				sk.takes.set(&"bShade", true)
				sk.takes.set(&"ShadeYaw", float(at[2]))
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
	if args.has("film"):                          # --film=N: the last shot for N frames, the figures skating on; every 2nd frame a PNG
		var nf: int = int(args["film"])
		for f: TLRigSkater in figs:
			if not (f.get(&"takes") != null and bool(f.takes.get(&"bShade"))):
				f.play_clip(&"Stride", true)
		for i: int in range(nf):
			for f: TLRigSkater in figs:
				if f.get(&"takes") != null and bool(f.takes.get(&"bShade")):
					continue                          # the lying one lies
				f.tick()
				f.position += f.global_transform.basis * Vector3(0.0, 0.0, -float(args.get("speed", "6")) / 60.0)
			await RenderingServer.frame_post_draw
			if i % 2 == 0:
				get_viewport().get_texture().get_image().save_png("%s/film_%04d.png" % [outdir, i / 2])
		report["film_frames"] = nf / 2
	if args.has("cost"):                          # --cost=N: the last shot's picture for N frames, the time of a frame
		var vp: RID = get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		var n: int = int(args["cost"])
		var gpu: float = 0.0
		var cpu: float = 0.0
		var t0: int = 0
		for f: TLRigSkater in figs:                # striding, so that every shadow map is drawn again each frame
			f.play_clip(&"Stride", true)
		for i: int in range(n + 30):
			for f: TLRigSkater in figs:
				f.tick()
			await RenderingServer.frame_post_draw
			if i == 30:
				t0 = Time.get_ticks_usec()
			if i >= 30:
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		report["cost"] = {"frames": n, "figures": figs.size(), "frame_ms": snappedf(float(Time.get_ticks_usec() - t0) / 1000.0 / float(n), 0.001),
			"gpu_ms": snappedf(gpu / float(n), 0.001), "render_cpu_ms": snappedf(cpu / float(n), 0.001)}
	_done("" if saved == (list as Array).size() else "%d of %d shots saved" % [saved, (list as Array).size()])


## Selftest block 850 (look.skater.shadow): one skater 10 m from the first key light's foot, seen from above. The ice
## where that key's shadow of his chest must fall (S = P + (P - K) x h / (H - h), h 1.0 m, H the key's height) against
## the ice as far on his other side: the shadowed point is darker. With --keys=0 it is not (the style sun's one
## shadow lies under him), which is the case shown red.
func _check() -> void:
	const P: Vector2 = Vector2(-27.8, -8.2)          # rink metres
	const H_BODY: float = 1.0
	var key: Dictionary = {}
	for l: Dictionary in Arena.rig_lights():
		if bool(l["shadows"]) and (key.is_empty() or Vector2((l["pos"] as Vector3).x, (l["pos"] as Vector3).z).distance_to(P) < Vector2((key["pos"] as Vector3).x, (key["pos"] as Vector3).z).distance_to(P)):
			key = l
	var kp: Vector3 = key["pos"]
	var off: Vector2 = (P - Vector2(kp.x, kp.z)) * H_BODY / (kp.y - H_BODY)
	var sk: TLRigSkater = TLRigSkater.new()
	sk.setup({"team": 0})
	sk.position = Vector3(P.x, 0.0, P.y)
	add_child(sk)
	sk.pose_rest()
	var cam: Camera3D = Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.make_current()
	cam.look_at_from_position(Vector3(P.x, 9.0, P.y), Vector3(P.x, 0.0, P.y), Vector3(1, 0, 0))
	for _i: int in range(6):
		await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if args.has("out"):
		img.save_png(String(args["out"]))
	var lum: Array = []
	for q: Vector2 in [P + off, P - off]:
		var px: Vector2 = cam.unproject_position(Vector3(q.x, 0.0, q.y)) * (Vector2(img.get_size()) / get_viewport().get_visible_rect().size)
		var sum: float = 0.0
		for dy: int in range(-3, 4):
			for dx: int in range(-3, 4):
				sum += img.get_pixel(clampi(int(px.x) + dx, 0, img.get_width() - 1), clampi(int(px.y) + dy, 0, img.get_height() - 1)).get_luminance()
		lum.append(sum / 49.0)
	var ratio: float = float(lum[0]) / maxf(float(lum[1]), 0.0001)
	var ok: bool = TLStyleHallKeys.count(self) > 0 and ratio < 0.88 and float(lum[1]) > 0.2
	print("LOOK shadow ok=%s keys=%d shadowed=%.3f open=%.3f ratio=%.3f key_at=(%.2f, %.2f) offset_m=%.2f" % ["true" if ok else "false",
		TLStyleHallKeys.count(self), float(lum[0]), float(lum[1]), ratio, kp.x, kp.z, off.length()])
	_done("" if ok else "the key light's shadow is not on the ice where it must fall")


func _done(err: String) -> void:
	report["ok"] = err == ""
	if err != "":
		report["error"] = err
	print("%s figure view" % ("PASS" if err == "" else "FAIL"))
	print("tl.rink.figure_view/1 " + JSON.stringify(report))
	get_tree().quit(0 if err == "" else 1)
