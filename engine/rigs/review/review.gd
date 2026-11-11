extends Node3D
## Motion review scene (P3). One rig moves across a marked floor under a tracking camera so that a clip of it
## (godot --write-movie) shows foot slide, turns and timing. Visual only; counts physics frames, never a clock.
## Args after `--`:  --what=biped|car|bot   --mode=walk|skate   --speed=m/s   --clip=<biped clip played over locomotion>
##   --turn=deg/s (yaw rate)   --view=side|three|front   --stick=1   --team=blue|red   --seconds=N (frames to run)
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
	TLStyle.install(self, {"ink": true, "grade": true})
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
			if String(args.get("team", "")) == "blue" or skate:
				p["colors"] = {"top": "car_blue", "trim": "car_white", "legs": "bot_dark", "boots": "black"}
			elif String(args.get("team", "")) == "red":
				p["colors"] = {"top": "car_red", "trim": "car_white", "legs": "bot_dark", "boots": "black"}
			rig = TLRigs.build("biped", p)
	add_child(rig)
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
	if what == "fx":
		_fx_tick()
		return
	var dt: float = 1.0 / 60.0
	var v: float = speed
	if what == "biped" and frame < 30:
		v = 0.0                                      # stand for half a second, then go
	if what == "car":
		v = speed * smoothstep(0.0, 120.0, float(frame))
	heading += deg_to_rad(turn) * dt * (1.0 if frame > 30 else 0.0)
	var dir: Vector3 = Vector3(cos(heading), 0, sin(heading))
	pos += dir * v * dt
	rig.position = pos
	rig.rotation.y = -heading + (0.0 if what == "car" else 0.0) - PI * 0.5 + PI * 0.5
	# rigs face -Z; rotation about Y by -(heading + 90 deg) points -Z along `dir`
	rig.rotation.y = -(heading + PI * 0.5)
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
		rig.call("set_locomotion", Vector3(0, 0, -v), true)
		if clip != "" and frame == clip_at:
			rig.call("play", StringName(clip))
	rig.call("tick", frame)
	if what == "biped" and frame == 1 and args.has("k"):
		rig.set("stride_k", float(args["k"]))
	if what == "biped" and frame == 1 and args.has("a"):
		rig.set("amp_override", float(args["a"]))
	if what == "biped":
		_log_feet(dir, v)
	_place_cam(false)


func _place_cam(snap: bool) -> void:
	var target: Vector3 = pos + Vector3(0, 0.9 if what != "car" else 0.5, 0)
	if view == "face":
		target = pos + Vector3(0, 1.74, 0)
	cam_pos = target if snap else cam_pos.lerp(target, 0.25)
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
