extends Node
## N5b. The world viewer: several packs alive in one process (N2's world host), drawn in one landscape, one picture.
##
##   <godot> --position 0,1440 --resolution 1920x1080 --rendering-driver d3d12 --fixed-fps 60 --path <engine>
##           res://kernel/world/draw/view.tscn -- shot --packs=<dir>,<dir>,... [--at=x:y:z,..] [--yaw=deg,..]
##           [--spacing=80] [--stage=0] [--cam=<view of the stage pack>|overview] [--frame=300] --out=<abs png>
##           [--mech=a|b] [--cull=auto|aabb|margin] [--standins=off|auto|all] [--far=150] [--until=end]
##           [--also=<stage>:<cam>:<abs png>;..] [--mode=bot|smoke] [--frames=36000] [--seeds=..] [--ground=on|off]
##           [--hud=on|off] [--measure=120] [--radius=40,..] [--lift=m,..] [--crane=x:y:z,x:y:z] [--settle=frames] [--band=9]
##   (tools/view.sh shot does this.)
##
## The packs are loaded by N2's world host and stay at the origin of their own physics space: `--at` is the PLOT of
## each pack and is never given to the world host. The draw layer (draw.gd) puts every pack at its plot relative to
## the stage pack. Output: one `tl.view/1` JSON line per picture (draw calls, primitives, frame times, what the draw
## layer adopted); with `--until=end` the world then runs to its end and prints its own `tl.world/1` lines (one state
## hash per pack), which tools/view.sh check compares with the headless run.

const WorldScript: GDScript = preload("res://kernel/world/world.gd")
const DrawScript: GDScript = preload("res://kernel/world/draw/draw.gd")

var opts: Dictionary = {}
var world: Node
var draw: Node3D
var landscape: Node3D
var overview: Camera3D
var plots: Array = []
var radii: Array = []
var rims: Array = []
var has_ground: Array = []              # per pack: it has terrain of its own at the plot edge (a hole is cut for it)
var lifted: Array = []
var shot_frame: int = 300
var _shooting: bool = false
var _done: bool = false
var _frame_usec: PackedInt64Array = PackedInt64Array()
var _cpu_ms: PackedFloat32Array = PackedFloat32Array()
var _gpu_ms: PackedFloat32Array = PackedFloat32Array()
var _last: int = 0
var _measure: int = 120


func _ready() -> void:
	var verb: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var eq: int = a.find("=")
			if eq < 0:
				opts[a.substr(2)] = "true"
			else:
				opts[a.substr(2, eq - 2)] = a.substr(eq + 1)
		elif verb.is_empty():
			verb = a
	print("[view] start")
	if verb != "shot" or not opts.has("packs") or not opts.has("out"):
		print("[view] usage: shot --packs=<a>,<b>,.. --out=<abs png> [--at=x:y:z,..] [--stage=i] [--cam=<name>|overview] [--frame=n]")
		get_tree().quit(2)
		return
	if DisplayServer.get_name() == "headless":
		print("[view] a picture needs a window (started headless)")
		get_tree().quit(2)
		return
	shot_frame = int(opts.get("frame", "300"))
	_measure = int(opts.get("measure", "120"))
	process_physics_priority = 100000          # after the world host and after every pack node of this tick
	world = WorldScript.new()
	world.name = "World"
	add_child(world)
	var wopts: Dictionary = {"packs": opts["packs"], "mode": str(opts.get("mode", "bot")), "frames": str(opts.get("frames", "36000"))}
	if opts.has("seeds"):
		wopts["seeds"] = opts["seeds"]
	world.call("start", wopts)                 # no "at": every pack is simulated at its own origin
	var holders: Array = world.get("packs")
	var errs: Array = world.get("errors")
	if holders.is_empty() or not errs.is_empty():
		print("[view] the world did not load: %s" % str(errs))
		for h: Node in holders:
			print("[view]   %s: %s" % [h.name, str(h.get("load_errors"))])
		get_tree().quit(1)
		return
	_make_plots(holders.size())
	# every pack is cut to its plot (--radius, metres; 0 = not cut) and lifted so that the rim of its own ground meets
	# the world's ground (--lift overrides the measured value)
	var rads: PackedStringArray = str(opts.get("radius", "40")).split(",", false)
	var lifts: PackedStringArray = str(opts.get("lift", "")).split(",", false)
	for i: int in holders.size():
		var r: float = float(rads[mini(i, rads.size() - 1)]) if not rads.is_empty() else 0.0
		radii.append(r)
		var rim: float = -float(lifts[i]) if i < lifts.size() else float(DrawScript.call("edge_height", holders[i], r))
		has_ground.append(not is_nan(rim))
		if is_nan(rim):
			rim = 0.0
		var lift: float = -rim
		rims.append(rim)
		var p: Transform3D = plots[i]
		p.origin.y += lift
		plots[i] = p
		lifted.append(snappedf(lift, 0.01))
	var stage: int = clampi(int(opts.get("stage", "0")), 0, holders.size() - 1)
	# the landscape between the plots: one ground under all of them, drawn once (the sky and the sun are the style's rig,
	# installed once by the world host)
	landscape = Node3D.new()
	landscape.name = "TLLandscape"
	add_child(landscape)
	if str(opts.get("ground", "on")) != "off":
		var ground: MeshInstance3D = TLStyle.ground(-0.06, str(opts.get("ground-key", "")), 3000.0)
		landscape.add_child(ground)
		# the plots are cut out of the world's ground (toon.gdshader `tl_holes`): its own material, same shader and palette
		var pal: ShaderMaterial = TLStyle.material(&"white") as ShaderMaterial
		if pal != null and pal.shader != null:
			var gm: ShaderMaterial = ShaderMaterial.new()
			gm.shader = pal.shader
			gm.set_shader_parameter(&"pal_lut", pal.get_shader_parameter(&"pal_lut"))
			var holes: Array = []
			for i: int in plots.size():
				if float(radii[i]) > 0.0 and bool(has_ground[i]) and holes.size() < 32:
					holes.append(Vector4((plots[i] as Transform3D).origin.x, (plots[i] as Transform3D).origin.z, float(radii[i]) + 2.5, 0.0))
			var n: int = holes.size()
			while holes.size() < 32:
				holes.append(Vector4.ZERO)
			gm.set_shader_parameter(&"tl_holes", holes)
			gm.set_shader_parameter(&"tl_hole_n", n)
			ground.material_override = gm
	overview = Camera3D.new()
	overview.name = "Overview"
	overview.fov = 50.0
	overview.far = 4000.0
	landscape.add_child(overview)              # a child of the landscape: it is re-based with it
	var lo: Vector3 = (plots[0] as Transform3D).origin
	var hi: Vector3 = lo
	for p: Transform3D in plots:
		lo = lo.min(p.origin)
		hi = hi.max(p.origin)
	var centre: Vector3 = (lo + hi) * 0.5
	var radius: float = maxf(60.0, (hi - lo).length() * 0.5 + 45.0)
	var from: Vector3 = centre + Vector3(-radius * 0.55, radius * 0.75, radius * 1.25)
	if opts.has("crane"):                      # --crane=x:y:z,x:y:z  (from, to) in world coordinates
		var ft: PackedStringArray = str(opts["crane"]).split(",")
		if ft.size() == 2:
			from = _v3(ft[0])
			centre = _v3(ft[1])
	overview.look_at_from_position(from, centre, Vector3.UP)
	draw = DrawScript.new()
	draw.name = "TLDraw"
	draw.set("mech", str(opts.get("mech", "a")))
	draw.set("cull", str(opts.get("cull", "auto")))
	draw.set("far_mode", str(opts.get("standins", "off")))
	draw.set("far_dist", float(opts.get("far", "150")))
	draw.set("rim_band", float(opts.get("band", "9")))
	add_child(draw)
	draw.call("setup", world, plots, radii, rims, stage)
	_apply_stage(stage, str(opts.get("cam", "overview")))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_last = Time.get_ticks_usec()


func _v3(text: String) -> Vector3:
	var f: PackedStringArray = text.split(":")
	return Vector3(float(f[0]), float(f[1]), float(f[2])) if f.size() == 3 else Vector3.ZERO


func _make_plots(count: int) -> void:
	var ats: PackedStringArray = str(opts.get("at", "")).split(",", false)
	var yaws: PackedStringArray = str(opts.get("yaw", "")).split(",", false)
	var spacing: float = float(opts.get("spacing", "80"))
	var cols: int = int(ceil(sqrt(float(count))))
	for i: int in count:
		var at: Vector3 = Vector3(spacing * float(i % cols), 0.0, spacing * float(i / cols))
		if i < ats.size():
			at = _v3(ats[i])
		var yaw: float = deg_to_rad(float(yaws[i])) if i < yaws.size() else 0.0
		plots.append(Transform3D(Basis(Vector3.UP, yaw), at))


## The stage pack keeps its own cameras and its HUD; everything else is drawn relative to it.
func _apply_stage(stage: int, cam_name: String) -> void:
	draw.call("set_stage", stage)
	landscape.transform = (plots[stage] as Transform3D).affine_inverse()
	var holders: Array = world.get("packs")
	var ctx: TLContext = (holders[stage] as Node).get("ctx")
	if str(opts.get("hud", "on")) == "off":
		TLHud.hide_all(ctx)
	if cam_name == "overview" or ctx == null or ctx.cameras == null:
		overview.make_current()
	elif ctx.cameras.has_view(StringName(cam_name)):
		ctx.cameras.activate(StringName(cam_name))
	else:
		print("[view] the stage pack has no view '%s' (it has: %s); using the overview" % [cam_name, ", ".join(ctx.cameras.views())])
		overview.make_current()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	_frame_usec.append(now - _last)
	_last = now
	var vp: RID = get_viewport().get_viewport_rid()
	_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
	_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	# a HUD a pack makes after loading: only the stage pack's is shown
	if draw != null and world != null and not _done:
		var holders: Array = world.get("packs")
		var stage: int = int(draw.get("stage"))
		for i: int in holders.size():
			if i == stage or not is_instance_valid(holders[i]):
				continue
			var ctx: TLContext = (holders[i] as Node).get("ctx")
			if ctx != null:
				for h: Variant in ctx.huds:
					if is_instance_valid(h) and (h as CanvasLayer).visible:
						(h as CanvasLayer).visible = false


func _physics_process(_delta: float) -> void:
	if _shooting or _done or world == null:
		return
	if int(world.get("tick")) >= shot_frame:
		_shooting = true
		_shoot()


func _p50(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var s: Array = values.duplicate()
	s.sort()
	return float(s[s.size() / 2])


func _take(out: String, stage: int, cam_name: String) -> void:
	for i: int in 3:
		await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(out)
	var n: int = mini(_measure, _frame_usec.size())
	var line: Dictionary = {"schema": "tl.view/1", "out": out, "saved": err == OK, "stage": stage, "cam": cam_name,
		"world_tick": int(world.get("tick")), "packs": (world.get("packs") as Array).size(),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"frame_ms_p50": snappedf(_p50(Array(_frame_usec.slice(_frame_usec.size() - n))) / 1000.0, 0.001),
		"render_cpu_ms_p50": snappedf(_p50(Array(_cpu_ms.slice(_cpu_ms.size() - n))), 0.001),
		"render_gpu_ms_p50": snappedf(_p50(Array(_gpu_ms.slice(_gpu_ms.size() - n))), 0.001),
		"measured_frames": n, "radius": radii, "lift": lifted, "draw": draw.call("report")}
	print(JSON.stringify(line, "", false))


func _shoot() -> void:
	await _take(str(opts["out"]), int(draw.get("stage")), str(opts.get("cam", "overview")))
	for part: String in str(opts.get("also", "")).split(";", false):
		var f: PackedStringArray = part.split(":", true, 2)        # <stage>:<cam>:<abs png>; the path may hold a colon
		if f.size() == 3:
			_apply_stage(int(f[0]), f[1])
			for i: int in int(opts.get("settle", "0")):       # frames between pictures, so each has its own timings
				await get_tree().process_frame
			await _take(f[2], int(f[0]), f[1])
	_done = true
	if str(opts.get("until", "")) == "end":
		return                       # the world runs on, drawn, to its own end and prints one state hash per pack
	_shutdown()


func _shutdown() -> void:
	draw.call("clear")
	world.call("_end")              # prints the world's lines (no final hashes: the packs were cut short), frees, quits
