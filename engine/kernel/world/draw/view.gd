extends Node
## The world in a window. Host mode `world-view` (kernel/host/host.gd; N5b patch 4), two uses:
##
## N5b, pictures of a world of packs (tools/view.sh shot / check):
##   <godot> --position 0,1440 --resolution 1920x1080 --rendering-driver d3d12 --fixed-fps 60 --path <engine>
##           res://kernel/host/host.tscn -- world-view --packs=<dir>,<dir>,... [--at=x:y:z,..] [--yaw=deg,..]
##           [--spacing=80] [--stage=0] [--cam=<view of the stage pack>|overview] [--frame=300] --out=<abs png>
##           [--mech=a|b] [--cull=auto|aabb|margin] [--standins=off|auto|all] [--far=150] [--until=end]
##           [--also=<stage>:<cam>:<abs png>;..] [--mode=bot|smoke] [--frames=36000] [--seeds=..] [--ground=on|off]
##           [--hud=on|off] [--measure=120] [--radius=40,..] [--lift=m,..] [--crane=x:y:z,x:y:z] [--settle=frames] [--band=9]
##   The packs are loaded by the world host and stay at the origin of their own physics space: `--at` is the PLOT of
##   each pack. Every pack is ticked on every frame. Output: one `tl.view/1` line per picture; with `--until=end` the
##   world then runs to its end and prints its `tl.world/1` lines.
##
## N7, one world you can walk through (tools/world.sh tour / visit):
##   ... -- world-view --walk=<walk script> --out-dir=<abs dir> [--log=<file>] [--ticks=N] [--landscape=on|off] [--live]
##   The SCHEDULED world (kernel/world/tiers.gd) in a window: the tier of each plot decides its ticks (world.gd) and
##   its drawing (here): `stage` = zero offset, its cameras, its HUD; `sideline` = drawn in full at its plot;
##   `backdrop` and `ledger` = its stand-in mesh. A tier change is applied at the tick boundary it happens on
##   (`plot_event` of the world host). The visitor (kernel/world/visitor.gd) walks the world's landscape
##   (kernel/world/landscape.gd); while he walks nobody is on stage. The walk's `shot` events become numbered pictures.
##   kernel/world/WORLD.md has the whole picture.

const WorldScript: GDScript = preload("res://kernel/world/world.gd")
const DrawScript: GDScript = preload("res://kernel/world/draw/draw.gd")
const Landscape: GDScript = preload("res://kernel/world/landscape.gd")
const VisitorScript: GDScript = preload("res://kernel/world/visitor.gd")
const PlotFile: GDScript = preload("res://kernel/world/plotfile.gd")
const VisitScript: GDScript = preload("res://kernel/runner/visit.gd")      # P11: the visitor's input, a record
const Seam: GDScript = preload("res://kernel/world/draw/view_seam.gd")    # P14: rims, colliders in slices

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
# N7: the tour
var tour: bool = false
var live: bool = false                  # a person walks (--live), or a recorded visit is replayed (--input): kernel/runner/visit.gd
var visit: Node = null
var visitor: Node3D = null
var stage: int = -1                     # the plot on stage, -1 while the visitor walks
var shots: Array = []                   # the walk's `shot` events, in order
var out_dir: String = ""
var pictures: Array = []
var land_stats: Dictionary = {}
var _shot_i: int = 0
var _busy: bool = false
var _stage_changes: int = 0
# P5: packs arrive while the world is drawn (kernel/world/jobs.gd)
var _arrived: Dictionary = {}           # plot index -> true: a built pack has stood there (a stand-in can be made of it)
var _rims: Dictionary = {}              # the rim cache: "<pack directory hash>|<radius>|<scenery>" -> rim height, or "none"
var _rims_new: int = 0
var _first_frame_ms: int = -1           # milliseconds from the start of the process to the end of the first drawn frame
var _start_ms: int = 0
var _enter_ms: int = 0                  # when `start` was called: the engine's own start is before it and is not this file's
var _frame_tick: PackedInt32Array = PackedInt32Array()    # the world tick each frame time belongs to
var _saves: Array = []                  # the tour's pictures being encoded on worker threads
var _notes: Array = []                  # P14: what ran since the last frame ("what ms"); a slow frame carries them
var _frame_notes: Dictionary = {}       # P14: frame index -> notes of that frame (only frames that have any)
var _phys_t0: int = 0                   # P14: when this physics tick began (SceneTree.physics_frame)
var _phys_usec: int = 0                 # P14: the world's ticks since the last frame, up to this node's own step
var _late: Array = []                   # P14: [plot, tick] arrived packs the draw layer adopts on the next tick
var _copies: Array = []                 # P14: colliders of arrived packs still being copied into the visitor's space


func _note(what: String, t0: int) -> void:
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	if ms >= 1.0:
		_notes.append("%s %.1f" % [what, ms])


func _ready() -> void:
	if get_parent() != get_tree().root:
		return                                    # started by the host: `start(options)` follows
	var verb: String = ""
	var o: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var eq: int = a.find("=")
			if eq < 0:
				o[a.substr(2)] = "true"
			else:
				o[a.substr(2, eq - 2)] = a.substr(eq + 1)
		elif verb.is_empty():
			verb = a
	start(o)


func start(options: Dictionary) -> void:
	opts = options
	_enter_ms = Time.get_ticks_msec()
	print("[view] start")
	tour = opts.has("walk")
	if not tour and (not opts.has("packs") or not opts.has("out")):
		print("[view] usage: world-view --packs=<a>,<b>,.. --out=<abs png> [--at=x:y:z,..] [--stage=i] [--cam=<name>|overview] [--frame=n]  |  world-view --walk=<walk script> --out-dir=<abs dir>")
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
	world.set("quit_on_end", false)            # this node ends the process (N5b patch 3)
	add_child(world)
	world.connect("ended", _on_world_ended)
	var wopts: Dictionary = {}
	if tour:
		live = opts.has("live") or opts.has("input")
		out_dir = str(opts.get("out-dir", "")).replace("\\", "/").trim_suffix("/")
		wopts["walk"] = opts["walk"]
		for k: String in ["log", "tiers", "cost", "ticks", "scenery", "mode", "load", "trip", "dead"]:
			if opts.has(k):
				wopts[k] = opts[k]          # P11: load, trip and dead are listed options of the host (PATCHES-P5 entry 1)
		if live and not opts.has("ticks"):
			wopts["ticks"] = str(1 << 40)
	else:
		wopts = {"packs": opts["packs"], "mode": str(opts.get("mode", "bot")), "frames": str(opts.get("frames", "36000")),
			"stage": str(opts.get("stage", "0"))}
		for k: String in ["seeds", "scenery"]:
			if opts.has(k):
				wopts[k] = opts[k]
	world.call("start", wopts)                 # no "at": every pack is simulated at its own origin
	if not str(world.get("refused")).is_empty():
		return                                 # the world host said why and ends the process with exit code 2
	var holders: Array = world.get("packs")
	var errs: Array = world.get("errors")
	if holders.is_empty() or not errs.is_empty():
		print("[view] the world did not load: %s" % str(errs))
		for h: Node in holders:
			print("[view]   %s: %s" % [h.name, str(h.get("load_errors"))])
		get_tree().quit(1)
		return
	var walk: Dictionary = world.get("walk")
	var rads: PackedStringArray = str(opts.get("radius", "40")).split(",", false)
	if tour:
		# plots and radii come from the walk script (a plot's `radius`, else the footprint's shorter side)
		var defs: Array = world.get("plot_defs")
		var sp: Array = (world.get("sched") as RefCounted).get("plots")
		var src: Array = walk.get("plots", [])
		rads = PackedStringArray()
		for i: int in defs.size():
			var d: Dictionary = defs[i]
			var o: Vector3 = d.get("origin", Vector3.ZERO)
			var pads: Array = (walk.get("landscape", {}) as Dictionary).get("pad_h", []) if typeof(walk.get("landscape")) == TYPE_DICTIONARY else []
			if i < pads.size():
				o.y = float(pads[i])           # PATCHES-P4 entry 1: a walk states a pad's height once
			plots.append(Transform3D(Basis(Vector3.UP, deg_to_rad(float(d.get("yaw", 0.0)))), o))
			var size: Vector2 = (sp[i] as Dictionary)["size"]
			rads.append(str(float((src[i] as Dictionary).get("radius", minf(size.x, size.y) * 0.5))))
	else:
		_make_plots(holders.size())
	# every pack is cut to its plot (metres; 0 = not cut) and lifted so that the rim of its own ground meets the
	# world's ground (--lift overrides the measured value)
	var lifts: PackedStringArray = str(opts.get("lift", "")).split(",", false)
	for i: int in holders.size():
		var r: float = float(rads[mini(i, rads.size() - 1)]) if not rads.is_empty() else 0.0
		radii.append(r)
		var rim: float = -float(lifts[i]) if i < lifts.size() else Seam.rim_of(self, i, r)
		if bool((holders[i] as Node).get("loaded")):
			_arrived[i] = true
		has_ground.append(not is_nan(rim))
		if is_nan(rim):
			rim = 0.0
		var lift: float = -rim
		rims.append(rim)
		var p: Transform3D = plots[i]
		p.origin.y += lift
		plots[i] = p
		lifted.append(snappedf(lift, 0.01))
	Seam.save_rims(self)
	# the landscape between the plots: drawn once (the sky and the sun are the style's rig, installed once by the world host)
	landscape = Node3D.new()
	landscape.name = "TLLandscape"
	add_child(landscape)
	if tour and str(opts.get("landscape", "on")) != "off":
		var lcfg: Dictionary = (walk.get("landscape", {}) as Dictionary).duplicate() if typeof(walk.get("landscape")) == TYPE_DICTIONARY else {}     # P13: a copy
		if not lcfg.has("road") and walk.has("road"):
			lcfg["road"] = walk["road"]
		lcfg["events"] = walk.get("events", [])               # P13: trees give way to the walk's crane shots
		land_stats = Landscape.call("build", landscape, plots, radii, has_ground, lcfg)
		land_stats["haze"] = float(lcfg.get("haze", 0.4))
		Landscape.call("tone_haze", world, float(land_stats["haze"]))
	elif str(opts.get("ground", "on")) != "off":
		Landscape.call("ground", landscape, plots, radii, has_ground, str(opts.get("ground-key", "")))
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
	draw.set("rim_band", float(opts.get("band", str(walk.get("rim_band", 9.0)))))
	draw.set("force_picture", str(opts.get("picture", "")))     # P11 (PATCHES-P6 entry 2): still | mid | far, every far game
	add_child(draw)
	if tour:
		draw.call("setup", world, plots, radii, rims, -1)
		_start_tour(walk)
	else:
		var st: int = clampi(int(opts.get("stage", "0")), 0, holders.size() - 1)
		draw.call("setup", world, plots, radii, rims, st)
		_apply_stage(st, str(opts.get("cam", "overview")))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_last = Time.get_ticks_usec()
	_start_ms = Time.get_ticks_msec()
	RenderingServer.frame_post_draw.connect(func() -> void: _first_frame_ms = Time.get_ticks_msec(), CONNECT_ONE_SHOT)
	get_tree().physics_frame.connect(func() -> void: _phys_t0 = Time.get_ticks_usec())


func _v3(text: String) -> Vector3:
	var f: PackedStringArray = text.split(":")
	return Vector3(float(f[0]), float(f[1]), float(f[2])) if f.size() == 3 else Vector3.ZERO


func _a3(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


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


## N5b: the stage pack keeps its own cameras and its HUD; everything else is drawn relative to it.
func _apply_stage(st: int, cam_name: String) -> void:
	stage = st
	draw.call("set_stage", st)
	landscape.transform = (plots[st] as Transform3D).affine_inverse()
	var holders: Array = world.get("packs")
	var ctx: TLContext = (holders[st] as Node).get("ctx")
	if str(opts.get("hud", "on")) == "off":
		TLHud.hide_all(ctx)
	if cam_name == "overview" or ctx == null or ctx.cameras == null:
		overview.make_current()
	elif ctx.cameras.has_view(StringName(cam_name)):
		ctx.cameras.activate(StringName(cam_name))
	else:
		print("[view] the stage pack has no view '%s' (it has: %s); using the overview" % [cam_name, ", ".join(ctx.cameras.views())])
		overview.make_current()


# ------------------------------------------------------------------------------------------------ N7: the tour
func _start_tour(walk: Dictionary) -> void:
	draw.call("set_stage", -1)                 # nobody is on stage: every pack at its plot, every HUD hidden
	landscape.transform = Transform3D.IDENTITY
	world.connect("plot_event", _on_plot_event)
	for ev: Variant in walk.get("events", []):
		if typeof(ev) == TYPE_DICTIONARY and str((ev as Dictionary).get("e", "")) == "shot":
			shots.append(ev)
	shots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("t", 0)) < int(b.get("t", 0)))
	var script: Array = world.get("player_script")
	var at: Vector3 = _a3((script[0] as Array)[1]) if not script.is_empty() else Vector3.ZERO
	var facing: Vector3 = Vector3.FORWARD
	for k: int in range(1, script.size()):
		var d: Vector3 = _a3((script[k] as Array)[1]) - at
		if d.length() > 0.5:
			facing = d
			break
	visitor = VisitorScript.new()
	landscape.add_child(visitor)               # a child of the landscape: re-based with it when a game takes the stage
	visitor.call("setup", at, facing, walk.get("visitor_cam", {}) if typeof(walk.get("visitor_cam")) == TYPE_DICTIONARY else {})
	(visitor.get("cam") as Camera3D).make_current()
	if live:
		world.set("player_live", true)
		world.set("player_pos", at)
		# PATCHES-P9 3b: a person's walk runs none of the walk's scripted visits (tiers.gd keeps them in `_visits`)
		(world.get("sched") as RefCounted).set("_visits", [])
		visit = VisitScript.new()
		add_child(visit)
		var why: String = visit.call("setup", self, opts)
		if not why.is_empty():
			print("[view] the visit cannot start: " + why)
			world.call("_end")
			return
		visitor.call("steer_on")
		shots = visit.get("shots") if not out_dir.is_empty() else []
	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(out_dir)
	else:
		shots = []                                 # PATCHES-P9 3a: no folder, no pictures (not `/01_<name>.png`)


## A tier change, at the tick boundary it was decided on: the same event that changes a plot's ticks changes how it
## is drawn. A pack rebuilt from its seed (next round, back from the ledger) is adopted again.
func _on_plot_event(i: int, what: String, ev: Dictionary) -> void:
	if draw == null or _done:
		return
	match what:
		"before_tier":
			if str(ev.get("to", "")) == "ledger" and _arrived.has(i):
				draw.call("set_tier", i, "ledger")           # its stand-in is built while its nodes are still there
		"tier":
			var to: String = str(ev.get("to", ""))
			if stage == i and to != "stage":
				_set_stage(-1)
			if to == "ledger":
				draw.call("forget_nodes", i)
			if _arrived.has(i) or (to != "backdrop" and to != "ledger"):
				var tt: int = Time.get_ticks_usec()
				draw.call("set_tier", i, to)                 # P5: a plot whose pack has not arrived has nothing to make a stand-in of
				_note("tier p%d %s" % [i, to], tt)
			if to == "stage":
				_set_stage(i)
		"rebuilt":
			if not _arrived.has(i) and landscape != null and landscape.has_meta(&"tl_space") and float(radii[i]) > 0.0:
				# P5: the first pack to stand on this plot arrived after the landscape was built: its static colliders
				# are copied into the visitor's space now (landscape.gd does it at the start for the packs that are there)
				var ws: Object = landscape.get_meta(&"tl_space")
				var lc: Variant = (world.get("walk") as Dictionary).get("landscape", {})
				ws.set("tag", "pack %d" % i)
				var tc: int = Time.get_ticks_usec()
				# P14: listed now, copied in slices of 2 ms a frame (nearest plot first), and at once when he is near
				_copies.append({"i": i, "job": ws.call("begin_pack", (world.get("packs") as Array)[i], plots[i], float(radii[i]),
					float(rims[i]), float((lc as Dictionary).get("rim_band", 9.0)) if typeof(lc) == TYPE_DICTIONARY else 9.0)})
				_note("colliders_list p%d" % i, tc)
			_arrived[i] = true
			if i == stage or not tour:
				_adopt(i)
			else:
				# P14: the draw layer adopts the new holder on the next tick, not in the arrival's own frame (5 to 10 ms
				# of a seed); until then the holder is hidden, so it is never seen at its simulated place
				((world.get("packs") as Array)[i] as Node3D).visible = false
				_late.append([i, Engine.get_physics_frames()])


## The draw layer takes the holder of plot `i` (it arrived): placed, and drawn as its tier says.
func _adopt(i: int) -> void:
	var tr: int = Time.get_ticks_usec()
	draw.call("replace_holder", i, (world.get("packs") as Array)[i])
	_note("replace p%d" % i, tr)
	tr = Time.get_ticks_usec()
	draw.call("set_tier", i, str((((world.get("sched") as RefCounted).get("plots") as Array)[i] as Dictionary)["tier"]))
	_note("set_tier p%d" % i, tr)
	if i == stage:
		_set_stage(i)


## Puts plot `i` on stage (its own camera, its HUD; the world is re-based on it) or, with -1, hands the picture back
## to the visitor.
func _set_stage(i: int) -> void:
	var holders: Array = world.get("packs")
	if visit != null:
		visit.call("stage", stage, i, holders, plots, radii)   # bot off, the game's input, after Q: at the plot's gate
	stage = i
	_stage_changes += 1
	draw.call("set_stage", i)
	landscape.transform = (plots[i] as Transform3D).affine_inverse() if i >= 0 else Transform3D.IDENTITY
	var vcam: Camera3D = visitor.get("cam")
	if i < 0:
		visitor.visible = true
		visitor.call("snap")
		vcam.make_current()
		return
	visitor.visible = false
	var ctx: TLContext = (holders[i] as Node).get("ctx")
	if ctx != null and ctx.cameras != null and ctx.cameras.active != null:
		ctx.cameras.active.make_current()
	else:
		vcam.make_current()                              # a game with no view of its own is watched from where he stands


func _tiers_now() -> Dictionary:
	var out: Dictionary = {}
	var sched: RefCounted = world.get("sched")
	if sched != null:
		for p: Dictionary in sched.get("plots"):
			out[str(p["id"])] = str(p["tier"])
	return out


func _tour_shot(sh: Dictionary, number: int) -> void:
	var file: String = "%s/%02d_%s.png" % [out_dir, number, str(sh.get("name", "shot"))]
	var kind: String = str(sh.get("cam", ""))
	var prev: Camera3D = get_viewport().get_camera_3d()
	if kind == "crane" and sh.has("from") and sh.has("to"):
		var from: Vector3 = _a3(sh["from"])
		overview.transform = Transform3D(Basis.looking_at(_a3(sh["to"]) - from, Vector3.UP), from)     # local: world coordinates
		overview.make_current()
	await _take(file, stage, kind if not kind.is_empty() else ("stage" if stage >= 0 else "visitor"), sh)
	if kind == "crane" and is_instance_valid(prev) and not _done:
		prev.make_current()
	_busy = false


func _on_world_ended(_bad: bool) -> void:
	_done = true
	if visit != null:
		visit.call("finish")                             # P11: the visit's records
	if draw != null:
		draw.call("clear")
	var code: int = int(world.get("exit_code"))
	if tour:
		for s: Array in _saves:
			WorkerThreadPool.wait_for_task_completion(int(s[0]))
		_saves.clear()
		for pic: String in pictures:
			if not FileAccess.file_exists(pic):
				print("[view] the picture %s was not written" % pic)
				code = maxi(code, 1)
		var n: int = mini(600, _frame_usec.size())
		# PATCHES-P1 entry 1, the frame tail. The first two frame times are the start itself (the build of the world and
		# the first drawn frame): they are reported apart, as the time to the first frame.
		var sorted_us: Array = Array(_frame_usec.slice(2))
		sorted_us.sort()
		var p99_us: float = float(sorted_us[clampi(int(ceil(0.99 * float(sorted_us.size()))) - 1, 0, sorted_us.size() - 1)]) if not sorted_us.is_empty() else 0.0
		var max_us: float = float(sorted_us[sorted_us.size() - 1]) if not sorted_us.is_empty() else 0.0
		var over: int = 0
		var slow: Array = []                 # the frames over 16.7 ms: [world tick, ms], at most 40
		for k: int in range(2, _frame_usec.size()):
			if _frame_usec[k] > 16700:
				over += 1
				if slow.size() < 40:
					slow.append([_frame_tick[k], snappedf(float(_frame_usec[k]) / 1000.0, 0.1), _frame_notes.get(k, []), snappedf(_cpu_ms[k], 0.1)])
		var line: Dictionary = {"schema": "tl.view/1", "kind": "tour", "pictures": pictures.size(), "shots_asked": shots.size(),
			"world_ticks": int(world.get("tick")), "stage_changes": _stage_changes, "landscape": land_stats,
			"frame_ms_p50": snappedf(_p50(Array(_frame_usec.slice(_frame_usec.size() - n))) / 1000.0, 0.001),
			"frame_ms_p50_all": snappedf(_p50(Array(_frame_usec)) / 1000.0, 0.001),
			"frame_ms_p99_all": snappedf(p99_us / 1000.0, 0.001), "frame_ms_max_all": snappedf(max_us / 1000.0, 0.001),
			"frames": _frame_usec.size(), "frames_over_16_7_ms": over, "first_frame_ms": _first_frame_ms, "view_ready_ms": _start_ms, "world_to_first_frame_ms": _first_frame_ms - _enter_ms,
			"first_two_frames_ms": [snappedf(float(_frame_usec[0]) / 1000.0, 0.01) if _frame_usec.size() > 0 else 0.0, snappedf(float(_frame_usec[1]) / 1000.0, 0.01) if _frame_usec.size() > 1 else 0.0],
			"rims_measured": _rims_new, "slow_frames": slow,
			"render_cpu_ms_p50": snappedf(_p50(Array(_cpu_ms)), 0.001), "render_gpu_ms_p50": snappedf(_p50(Array(_gpu_ms)), 0.001),
			"draw": draw.call("report") if draw != null else {}}
		print(JSON.stringify(line, "", false))
		if pictures.size() < shots.size():
			print("[view] %d of %d pictures were taken (a shot must lie at least 10 ticks before the end of the walk)" % [pictures.size(), shots.size()])
			code = maxi(code, 1)
	get_tree().quit(code)


# ------------------------------------------------------------------------------------------------ every frame
func _process(_delta: float) -> void:
	if landscape != null and landscape.has_meta(&"tl_land_rest"):     # P13: the landscape's parts made on a worker
		var ta: int = Time.get_ticks_usec()
		Landscape.call("arrive", landscape)                           # P13
		_note("land_arrive", ta)
	var now: int = Time.get_ticks_usec()
	_frame_usec.append(now - _last)
	_frame_tick.append(int(world.get("tick")) if world != null else -1)
	_last = now
	if draw != null:
		_notes.append_array(draw.get("notes"))
		(draw.get("notes") as Array).clear()
	if _phys_usec >= 4000:
		_notes.append("tick %.1f" % (float(_phys_usec) / 1000.0))     # the world's ticks of this frame, arrivals included
	_phys_usec = 0
	if not _notes.is_empty():
		_frame_notes[_frame_usec.size() - 1] = _notes
		_notes = []
	var vp: RID = get_viewport().get_viewport_rid()
	_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
	_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))


func _physics_process(_delta: float) -> void:
	if _done or world == null or draw == null:
		return
	if _phys_t0 > 0:
		_phys_usec += Time.get_ticks_usec() - _phys_t0              # P14: the world host and every pack ran before this node
	if tour:
		var t: int = int(world.get("tick"))
		if visit != null:
			visit.call("sample", t)                      # the sampling line: no device is read below it
			visit.call("steer", t)
			if _done:
				return
		while not _late.is_empty() and int((_late[0] as Array)[1]) < Engine.get_physics_frames():
			var li: int = int((_late.pop_front() as Array)[0])
			if is_instance_valid((world.get("packs") as Array)[li]):
				_adopt(li)
		if not _copies.is_empty():                      # P14: colliders of arrived packs, in slices (view_seam.gd)
			var cu: int = Seam.copy_colliders(_copies, landscape.get_meta(&"tl_space"), plots, radii, world.get("player_pos"))
			if cu >= 1000:
				_notes.append("colliders %.1f" % (float(cu) / 1000.0))
		visitor.call("step", world.get("player_pos"), t)
		if not _busy and _shot_i < shots.size() and t > int((shots[_shot_i] as Dictionary).get("t", 0)):
			_busy = true
			_shot_i += 1
			_tour_shot(shots[_shot_i - 1], _shot_i)
		return
	if _shooting:
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


func _take(out: String, st: int, cam_name: String, shot: Dictionary = {}) -> void:
	for i: int in 3:
		await RenderingServer.frame_post_draw
	if _done:
		return
	var tg: int = Time.get_ticks_usec()
	var img: Image = get_viewport().get_texture().get_image()
	_note("shot_read", tg)
	var err: Error = OK
	if tour:
		# P5: a 1920x1080 PNG takes 0.7 s to encode: off the main thread (it was the tour's worst frame). The end waits.
		_saves.append([WorkerThreadPool.add_task(img.save_png.bind(out)), img])     # the image must outlive the task: a Callable holds no reference
	else:
		err = img.save_png(out)
	var n: int = mini(_measure, _frame_usec.size())
	var line: Dictionary = {"schema": "tl.view/1", "out": out, "saved": err == OK, "stage": st, "cam": cam_name,
		"world_tick": int(world.get("tick")), "packs": (world.get("packs") as Array).size(),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"frame_ms_p50": snappedf(_p50(Array(_frame_usec.slice(_frame_usec.size() - n))) / 1000.0, 0.001),
		"render_cpu_ms_p50": snappedf(_p50(Array(_cpu_ms.slice(_cpu_ms.size() - n))), 0.001),
		"render_gpu_ms_p50": snappedf(_p50(Array(_gpu_ms.slice(_gpu_ms.size() - n))), 0.001),
		"measured_frames": n, "radius": radii, "lift": lifted, "draw": draw.call("report")}
	if tour:
		var pos: Vector3 = world.get("player_pos")
		line["kind"] = "picture"
		line["name"] = str(shot.get("name", ""))
		line["asked_tick"] = int(shot.get("t", 0))
		line["stage_plot"] = str(((world.get("plot_defs") as Array)[st] as Dictionary)["id"]) if st >= 0 else ""
		line["visitor"] = [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)]
		line["tiers"] = _tiers_now()
		pictures.append(out)
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
	if str(opts.get("until", "")) == "end":
		_shooting = true                 # the world runs on, drawn, to its own end and prints one state hash per pack
		return
	world.call("_end")                   # prints the world's lines (no final hashes: the packs were cut short); `ended` ends the process
