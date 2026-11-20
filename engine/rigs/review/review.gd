extends Node3D
## Motion review scene (P3). One rig moves across a marked floor under a tracking camera so that a clip of it
## (godot --write-movie) shows foot slide, turns and timing. Visual only; counts physics frames, never a clock.
## Args after `--`:  --what=biped|car|bot   --mode=walk|skate   --speed=m/s   --clip=<biped clip played over locomotion>
##   --turn=deg/s (yaw rate)   --view=side|three|front   --stick=1   --team=blue|red   --seconds=N (frames to run)
##   walker-feel (18 Nov): --dir=deg (travel direction against the facing: 0 forward, 90 right, 180 back; the figure keeps facing
##   one way), --dir2=deg --dir-at=frame (a second direction from that frame), --accel=frames (speed ramps up over N frames),
##   --stop-at=frame (speed 0 from there), --jump-at=frame (a jump: off the floor, `jump` / `land` clips if the rig has them),
##   --jump-v=m/s, --hold=<clip> --hold-at=frame --hold-end=frame (a held clip such as slide, ended with play("")),
##   --view=behind (the visitor's camera: 8.5 m back, 3.6 m up, fov 60) | vclose (2.6 m back) | vfront
##   --freeze-at=frame (the pose stops there, the travel goes on: a crawl meter), --style=<file>, --no-ink, --no-grade, --no-shadow, --no-body,
##   --thin=1 (fences, scaffolds, a crane and trees beside the path: the ink contour on thin members under a pan)
## `res://rigs/review/review.tscn` is run by `look.sh clip rig:...`; it is not part of any pack.

var args: Dictionary = {}
var rig: Node3D
var cam: Camera3D
var frame: int = 0
var heading: float = 0.0       # yaw of the rig, radians, 0 = facing +X
var pos: Vector3 = Vector3.ZERO
var what: String = "biped"
var speed: float = 1.4
var turn: float = 0.0
var view: String = "side"
var clip_at: int = -1
var clip: String = ""
var cam_pos: Vector3 = Vector3.ZERO
var slip_log: Array = []
var signed_log: Array = []
var prev_feet: Array = []
var dir_deg: float = 0.0
var face: float = 0.0          # facing yaw (radians, 0 = +X); travel = facing turned by dir_deg
var vy: float = 0.0
var airborne: bool = false
var c_prev: Dictionary = {}    # contact meter: point index -> world position last frame (only while on the floor)
var c_log: Array = []
var c_frames: int = 0
var c_none: int = 0
var c_low: float = 0.0
const GRAV: float = 24.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	what = String(args.get("what", "biped"))
	speed = float(args.get("speed", "1.4"))
	turn = float(args.get("turn", "0"))
	view = String(args.get("view", "side"))
	clip = String(args.get("clip", ""))
	clip_at = int(args.get("clip-at", "90"))
	dir_deg = float(args.get("dir", "0"))
	if args.has("style"):                      # another style file (an absolute path works): the look under test
		for note: String in TLStyle.load_style(String(args["style"])):
			print("[review] style: " + note)
	TLStyle.install(self, {"ink": not args.has("no-ink"), "grade": not args.has("no-grade")})
	if args.has("sheet"):                      # diorama night: the character sheet (stills of posed figures), see _setup_sheet
		_setup_sheet()
		return
	if args.has("no-shadow"):                  # measurement only: is a crawl the sun's shadow map?
		for n: Node in find_children("*", "DirectionalLight3D", true, false):
			(n as DirectionalLight3D).shadow_enabled = false
	var skate: bool = String(args.get("mode", "walk")) == "skate"
	var floor_surface: String = "ice" if skate else "asphalt" if what == "car" else "concrete"
	var fl: Node3D = TLKit.build("ground_patch", {"size_x": 300.0, "size_z": 400.0, "surface": floor_surface, "thickness": 0.3})
	fl.position = Vector3(120, 0, 0)
	add_child(fl)
	# marker cones every 4 m on both sides: slip of a foot against the ground is visible against them
	for i: int in 60:
		for sz: float in [-3.0, 3.0]:
			var c: Node3D = TLKit.build("cone", {})
			c.position = Vector3(float(i) * 4.0 - 8.0, 0, sz)
			add_child(c)
	if args.has("thin"):
		# walker-feel: thin members at 15 to 70 m beside the path (rail and mesh fences, scaffolds, a crane, trees): what the
		# ink contour does on them while the picture pans (--turn) is the shimmer lane T measured
		for i: int in 8:
			for side: float in [-1.0, 1.0]:
				var fz: float = side * (14.0 + 9.0 * float(i % 4))
				var fe: Node3D = TLKit.build("fence", {"length": 24.0, "style": "rail" if (i + int(side)) % 2 == 0 else "mesh"})
				fe.position = Vector3(10.0 + 26.0 * float(i), 0, fz)
				add_child(fe)
				var tr: Node3D = TLKit.build("tree", {"species": "pine" if i % 2 == 0 else "broadleaf", "height": 8.0 + float(i % 3) * 3.0, "seed": 100 + i})
				tr.position = Vector3(18.0 + 26.0 * float(i), 0, fz + side * 5.0)
				add_child(tr)
		for i: int in 4:
			var sc: Node3D = TLKit.build("scaffold", {})
			sc.position = Vector3(40.0 + 45.0 * float(i), 0, -26.0 if i % 2 == 0 else 22.0)
			add_child(sc)
		var cr: Node3D = TLKit.build("crane", {})
		cr.position = Vector3(110.0, 0, -45.0)
		add_child(cr)
	if what == "fx":
		_setup_fx()
		return
	match what:
		"car":
			rig = TLRigs.build("vehicle", {})
		"bot":
			rig = TLRigs.build("bot", {})
		_:
			var p: Dictionary = {"mode": "skate" if skate else "walk", "backpack": not skate}
			if args.has("prop"):
				p["prop"] = String(args["prop"])
			if args.has("headgear"):
				p["headgear"] = String(args["headgear"])
			var team: String = String(args.get("team", "blue" if skate else ""))   # a skater is blue unless --team says red
			if team == "blue":
				p["colors"] = {"top": "car_blue", "trim": "car_white", "legs": "bot_dark", "boots": "black"}
			elif team == "red":
				p["colors"] = {"top": "car_red", "trim": "car_white", "legs": "bot_dark", "boots": "black"}
			rig = TLRigs.build("biped", p)
	add_child(rig)
	if args.has("no-body"):                    # measurement only: the rig without the body-anchored shading (toon `tl_body`)
		for n: Node in rig.find_children("*", "GeometryInstance3D", true, false):
			(n as GeometryInstance3D).set_instance_shader_parameter(&"tl_body", Vector2.ZERO)
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.far = 2000.0
	add_child(cam)
	cam.make_current()
	cam_pos = Vector3(0, 1.0, 0)
	_place_cam(true)


func _setup_fx() -> void:
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 2000.0
	add_child(cam)
	cam.make_current()
	cam.look_at_from_position(Vector3(3.6, 4.2, 8.2), Vector3(3.6, 0.7, -1.4), Vector3.UP)


var fx_names: Array = ["dust", "smoke", "sparks", "ice_spray", "debris", "nitro_flame", "confetti", "splash", "goal_flash"]


func _fx_tick() -> void:
	# every preset at its own place along X, fired at frames 20 and 120 (a second burst shows a repeat)
	if frame == 20 or frame == 130:
		for i: int in fx_names.size():
			var fxn: Node = TLStyleFx.preset(String(fx_names[i]), {"life_frames": 70})
			if fxn == null:
				continue
			(fxn as Node3D).position = Vector3(float(i % 3) * 3.4 + 0.2, 0.25, -float(i / 3) * 3.0)
			add_child(fxn)


func _physics_process(_dt: float) -> void:
	frame += 1
	if args.has("sheet"):
		_sheet_tick()
		return
	if what == "fx":
		_fx_tick()
		return
	var dt: float = 1.0 / 60.0
	var v: float = speed
	if what == "biped" and frame < 30:
		v = 0.0                                      # stand for half a second, then go
	elif what == "biped" and args.has("accel"):
		v = speed * clampf(float(frame - 30) / maxf(1.0, float(args["accel"])), 0.0, 1.0)
	if what == "biped" and args.has("stop-at") and frame >= int(args["stop-at"]):
		v = 0.0
	if what == "car":
		v = speed * smoothstep(0.0, 120.0, float(frame))
	if args.has("dir2") and frame >= int(args.get("dir-at", "150")):
		dir_deg = float(args["dir2"])
	heading += deg_to_rad(turn) * dt * (1.0 if frame > 30 else 0.0)
	face = heading
	var fwd: Vector3 = Vector3(cos(face), 0, sin(face))
	var right: Vector3 = Vector3(-sin(face), 0, cos(face))
	var da: float = deg_to_rad(dir_deg)
	var dir: Vector3 = fwd * cos(da) + right * sin(da)
	pos += dir * v * dt
	# a jump: ballistic, off the floor until it comes back
	if what == "biped" and args.has("jump-at") and frame == int(args["jump-at"]):
		vy = float(args.get("jump-v", "8.0"))
		airborne = true
		if (rig.call("clips") as PackedStringArray).has("jump"):
			rig.call("play", &"jump")
	var landed: bool = false
	var land_v: float = 0.0
	if airborne:
		vy -= GRAV * dt
		pos.y += vy * dt
		if pos.y <= 0.0:
			pos.y = 0.0
			airborne = false
			landed = true
			land_v = vy
			vy = 0.0
	rig.position = pos
	# rigs face -Z; rotation about Y by -(heading + 90 deg) points -Z along the facing
	rig.rotation.y = -(face + PI * 0.5)
	if what == "car":
		var yaw_rate: float = deg_to_rad(turn)
		var steer: float = clampf(yaw_rate * 2.7 / maxf(v, 1.0) / deg_to_rad(32.0), -1.0, 1.0)
		rig.call("set_param", &"steer", steer)
		rig.call("set_param", &"wheel_spin", v / 0.34)
		rig.call("set_param", &"throttle", 0.6 if frame < 200 else 0.0)
		rig.call("set_param", &"brake", 0.0 if frame < 200 else 0.8)
		var bump: float = 0.03 * sin(float(frame) * 0.35)
		rig.call("set_param", &"suspension", [bump, -bump, -bump, bump])
		rig.call("set_param", &"nitro", 1.0 if (frame > 150 and frame < 190) else 0.0)
	else:
		rig.call("set_locomotion", Vector3(sin(da) * v, land_v if landed else vy, -cos(da) * v), not airborne)
		if landed and (rig.call("clips") as PackedStringArray).has("land"):
			rig.call("play", &"land")
		if clip != "" and frame == clip_at:
			rig.call("play", StringName(clip))
		if args.has("hold") and (rig.call("clips") as PackedStringArray).has(String(args["hold"])):
			if frame == int(args.get("hold-at", "120")):
				rig.call("play", StringName(String(args["hold"])))
			if frame == int(args.get("hold-end", "200")):
				rig.call("play", &"")
	if not (args.has("freeze-at") and frame >= int(args["freeze-at"])):
		rig.call("tick", frame)       # --freeze-at: the pose stops, the travel goes on: what still changes on him is the shading
	if what == "biped" and frame == 1 and args.has("k"):
		rig.set("stride_k", float(args["k"]))
	if what == "biped" and frame == 1 and args.has("a"):
		rig.set("amp_override", float(args["a"]))
	if what == "biped" and args.has("hip") and frame > 200 and frame <= 200 + int(args["hip"]):
		var fts: Array = (rig.get("_gait") as Object).get("feet")
		var lp: Dictionary = rig.get("_last")
		print("[hip] f=%d y=%.3f L st=%s pos=%s R st=%s pos=%s" % [frame, (lp["h"] as Vector3).y, str(fts[0]["st"]), str((fts[0]["pos"] as Vector3).snapped(Vector3.ONE * 0.01)), str(fts[1]["st"]), str((fts[1]["pos"] as Vector3).snapped(Vector3.ONE * 0.01))])
	if what == "biped":
		_log_feet(dir, v)
		_log_contact(v)
	_place_cam(false)


func _place_cam(snap: bool) -> void:
	var target: Vector3 = pos + Vector3(0, 0.9 if what != "car" else 0.5, 0)
	if view == "face":
		target = pos + Vector3(0, 1.74, 0)
	cam_pos = target if snap else cam_pos.lerp(target, 0.25)
	if view == "behind" or view == "vclose" or view == "vfront":
		# the visitor's camera (kernel/world/visitor.gd): behind the facing, looking at 1.7 m; rigid, as with steer on
		var f: Vector3 = Vector3(cos(face), 0, sin(face))
		var back: float = 8.5 if view == "behind" else 2.6 if view == "vclose" else -4.2
		var up: float = 3.6 if view == "behind" else 2.0
		cam.fov = 60.0 if view == "behind" else 45.0
		cam.position = Vector3(pos.x, 0.0, pos.z) - f * back + Vector3(0, up, 0)
		cam.look_at(Vector3(pos.x, 1.7 if view == "behind" else 1.25, pos.z), Vector3.UP)
		return
	var off: Vector3
	match view:
		"three": off = Vector3(-4.2, 2.2, 5.8)
		"front": off = Vector3(5.5, 1.6, 1.8)
		"high": off = Vector3(-6.0, 5.5, 6.5)
		"close": off = Vector3(-1.9, 0.8, 3.0)
		"face": off = Vector3(1.7, 0.05, 0.75)
		"top": off = Vector3(0.0, 11.0, 0.9)
		_: off = Vector3(0, 0.9, 7.0)
	if what == "car":
		off *= 1.8
	cam.position = cam_pos + off
	cam.look_at(cam_pos, Vector3.UP)


## Foot slide: at every frame at least one foot is on the floor; the grounded foot with the lowest ground speed should stand
## still on the floor (relative to it). `along` is that foot's speed along the travel direction in m/s: 0 = planted,
## +v = the foot rides along with the body (a skate's glide counts as a pass for a skater, since blades slide).
func _log_feet(dir: Vector3, v: float) -> void:
	if not rig.has_method("socket"):
		return
	var fl: Node3D = rig.call("socket", &"foot_l")
	var fr: Node3D = rig.call("socket", &"foot_r")
	if fl == null or fr == null:
		return
	var feet: Array = [fl.global_position, fr.global_position]
	if prev_feet.size() == 2 and v > 0.05 and frame > 40:
		# stance = a foot on the floor that is moving backwards relative to the body; its ground speed should be 0
		var best_s: float = 1e9
		var best_signed: float = 0.0
		for k: int in 2:
			if (feet[k] as Vector3).y < 0.03:
				var d: Vector3 = (feet[k] as Vector3) - (prev_feet[k] as Vector3)
				d.y = 0
				var gs: float = d.dot(dir) * 60.0
				if gs - v < -0.25 * v and absf(gs) < best_s:
					best_s = absf(gs)
					best_signed = gs
		if best_s < 1e8:
			slip_log.append([best_s, v])
			signed_log.append(best_signed)
	prev_feet = feet
	if frame == int(args.get("frames", "300")) and args.has("slip"):
		_print_contact()
		var sum: float = 0.0
		var worst: float = 0.0
		for e: Array in slip_log:
			var s: float = absf(float(e[0]))
			sum += s
			worst = maxf(worst, s)
		var ss: float = 0.0
		for x: float in signed_log:
			ss += x
		print("[review] slip speed=%.2f k=%s planted_samples=%d mean_ms=%.3f max_ms=%.3f signed_mean=%.3f (foot on the floor: ground speed along travel, m/s)" % [speed, str(args.get("k", "1")), slip_log.size(), sum / maxf(1.0, float(slip_log.size())), worst, ss / maxf(1.0, float(signed_log.size()))])


## Contact slide (walker-feel): what the eye sees. Six points of the soles (heel, ball, toe tip of each boot); a point that is on
## the floor (under 15 mm) this frame and the last should not have moved: its horizontal speed over the floor is the slide.
## Per frame the worst point counts. Also: the frames with no point on the floor (flight or floating) and the lowest point
## seen (below 0 = through the floor).
const SOLE: Array = [["LeftFoot", Vector3(-0.11, 0.0, 0.115)], ["LeftFoot", Vector3(-0.11, 0.0, -0.08)], ["LeftToes", Vector3(-0.11, 0.0, -0.225)],
	["RightFoot", Vector3(0.11, 0.0, 0.115)], ["RightFoot", Vector3(0.11, 0.0, -0.08)], ["RightToes", Vector3(0.11, 0.0, -0.225)]]


func _log_contact(v: float) -> void:
	var sk: Skeleton3D = rig.get_node_or_null("Model/Skeleton3D")
	if sk == null:
		return
	var now: Dictionary = {}
	var worst: float = -1.0
	var lowest: float = 1e9
	for i: int in SOLE.size():
		var bi: int = sk.find_bone(String(SOLE[i][0]))
		var p: Vector3 = sk.global_transform * (sk.get_bone_global_pose(bi) * (sk.get_bone_global_rest(bi).affine_inverse() * (SOLE[i][1] as Vector3)))
		lowest = minf(lowest, p.y - rig.position.y)
		if p.y - rig.position.y < 0.015 and not airborne:
			now[i] = p
			if c_prev.has(i):
				var d: Vector3 = p - (c_prev[i] as Vector3)
				d.y = 0.0
				worst = maxf(worst, d.length() * 60.0)
	c_prev = now
	if v > 0.05 and frame > 60 and not airborne:
		c_frames += 1
		c_low = minf(c_low, lowest)
		if worst >= 0.0:
			c_log.append(worst)
		elif now.is_empty():
			c_none += 1


func _print_contact() -> void:
	var sum: float = 0.0
	var mx: float = 0.0
	for x: float in c_log:
		sum += x
		mx = maxf(mx, x)
	print("[review] contact speed=%.2f dir=%.0f frames=%d on_floor=%d mean_ms=%.3f max_ms=%.3f none_on_floor=%d lowest_m=%.3f (sole points on the floor two frames running: speed over the floor, m/s)" % [speed, dir_deg, c_frames, c_log.size(), sum / maxf(1.0, float(c_log.size())), mx, c_none, c_low])


# ------------------------------------------------------------------ the character sheet (diorama night, 20 Nov)
## `--sheet=<abs path .png|.jpg>` writes one still of posed figures and quits. `--sheet-set=`:
##   line   (default) ten figures in two rows: the village walker from the front, three-quarter, side and back, at a run, with
##          the backpack, cheering (arms up beside the head), a blue and a red skater, a slide
##   back   one walker seen from behind and a little above, as on the target board (idle)
##   front  one walker from the front, close
##   run    one walker at a run from behind, close
## Each figure is ticked to its pose by frame count; nothing here reads a clock.
var _sheet_rigs: Array = []     # [rig, {"v": speed, "clip": name, "at": frame the clip starts, "air": bool}]


func _sheet_fig(p: Dictionary, at: Vector3, yaw_deg: float, drive: Dictionary) -> void:
	var r: Node3D = TLRigs.build("biped", p)
	r.position = at
	r.rotation.y = deg_to_rad(yaw_deg)       # 0 = faces -Z (away from a camera on +Z)
	add_child(r)
	_sheet_rigs.append([r, drive])


func _setup_sheet() -> void:
	var fl: Node3D = TLKit.build("ground_patch", {"size_x": 120.0, "size_z": 120.0, "surface": String(args.get("floor", "dirt")), "thickness": 0.3})
	add_child(fl)
	cam = Camera3D.new()
	cam.far = 500.0
	add_child(cam)
	cam.make_current()
	var blue: Dictionary = {"top": "car_blue", "trim": "car_white", "legs": "bot_dark", "boots": "black"}
	var red: Dictionary = {"top": "car_red", "trim": "car_white", "legs": "bot_dark", "boots": "black"}
	match String(args.get("sheet-set", "line")):
		"back":
			_sheet_fig({"backpack": false}, Vector3.ZERO, float(args.get("yaw", "0")), {"v": 0.0})
			cam.fov = 30.0
			cam.look_at_from_position(Vector3(0.0, 2.3, 5.6), Vector3(0, 1.0, 0), Vector3.UP)
		"front":
			_sheet_fig({"backpack": false}, Vector3.ZERO, float(args.get("yaw", "160")), {"v": 0.0})
			cam.fov = 30.0
			cam.look_at_from_position(Vector3(0.0, 1.5, 5.0), Vector3(0, 1.05, 0), Vector3.UP)
		"run":
			_sheet_fig({"backpack": false}, Vector3.ZERO, float(args.get("yaw", "20")), {"v": 5.0})
			cam.fov = 30.0
			cam.look_at_from_position(Vector3(0.0, 2.3, 5.6), Vector3(0, 1.0, 0), Vector3.UP)
		_:
			var x0: float = -3.7
			var dx: float = 1.85
			var back_z: float = -7.0
			_sheet_fig({"backpack": false}, Vector3(x0, 0, 0), 180.0, {"v": 0.0})
			_sheet_fig({"backpack": false}, Vector3(x0 + dx, 0, 0), 140.0, {"v": 0.0})
			_sheet_fig({"backpack": false}, Vector3(x0 + 2 * dx, 0, 0), 90.0, {"v": 1.4})
			_sheet_fig({"backpack": false}, Vector3(x0 + 3 * dx, 0, 0), 0.0, {"v": 0.0})
			_sheet_fig({"backpack": false}, Vector3(x0 + 4 * dx, 0, 0), 30.0, {"v": 5.0})
			_sheet_fig({}, Vector3(x0, 0, back_z), -40.0, {"v": 0.0})
			_sheet_fig({"backpack": false}, Vector3(x0 + dx, 0, back_z), 170.0, {"v": 0.0, "clip": "cheer", "at": 4})
			_sheet_fig({"mode": "skate", "backpack": false, "colors": blue}, Vector3(x0 + 2 * dx, 0, back_z), 130.0, {"v": 5.0})
			_sheet_fig({"mode": "skate", "backpack": false, "colors": red}, Vector3(x0 + 3 * dx, 0, back_z), 20.0, {"v": 5.0})
			_sheet_fig({"backpack": false}, Vector3(x0 + 4 * dx, 0, back_z), 110.0, {"v": 0.0, "clip": "hang", "at": 4})
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 5.1
			cam.look_at_from_position(Vector3(0.0, 7.2, 16.5), Vector3(0, 1.22, -3.5), Vector3.UP)
	if args.has("cam"):                        # --cam=x,y,z,tx,ty,tz,fov : the camera of a single-figure set, by hand
		var c: PackedStringArray = String(args["cam"]).split(",")
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = float(c[6]) if c.size() > 6 else 30.0
		cam.look_at_from_position(Vector3(float(c[0]), float(c[1]), float(c[2])), Vector3(float(c[3]), float(c[4]), float(c[5])), Vector3.UP)


func _sheet_tick() -> void:
	var n: int = int(args.get("frames", "46"))
	for e: Array in _sheet_rigs:
		var r: Node3D = e[0]
		var d: Dictionary = e[1]
		r.call("set_locomotion", Vector3(0, 0, -float(d.get("v", 0.0))), true)
		if d.has("clip") and frame == int(d.get("at", 4)):
			r.call("play", StringName(String(d["clip"])))
		r.call("tick", frame)
	if frame == n + 3:
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = String(args["sheet"])
		if path.ends_with(".jpg"):
			img.save_jpg(path, 0.92)
		else:
			img.save_png(path)
		print("[review] sheet %s" % path)
		get_tree().quit()
