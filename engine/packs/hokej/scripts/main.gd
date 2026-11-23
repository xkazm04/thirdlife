extends Node
## Hokej, stair step 1: the gym (K3 shell, campaign night 23-24 Nov 2026; docs/design/DIRECTIONS.md direction 6).
## One skater on thirdjam's empty regular rink, under thirdjam's follow camera, through thirdjam's keys and mouse. A port:
## every number and rule cites thirdjam (HEAD 8dc713c6). The order inside a frame is AHokejGameMode's: the human's input is
## read through the camera of the last sim frame (ReadHumanInput, HokejGameMode.cpp:937), the sim steps, then the camera
## steps once on the new frame (PushPresentation -> UJamFollowCamera::StepSimFrame, CameraFollow.cpp:1183). The engine's
## physics interpolation draws camera and figure between the 60 Hz frames (UJamFollowCamera::TickComponent cpp:1319-1337,
## AJamSkater::ApplySimFrame JamPawns.cpp:464 lerp with the render alpha).
## The simulation is a STAND-IN (scripts/skate_standin.gd) until lane K1's core; the figure is a STAND-IN capsule until K2's.

const Cam := preload("cam.gd")
const Controls := preload("controls.gd")
const Standin := preload("skate_standin.gd")

var ctx
var cart: Dictionary
var gym: Dictionary
var core                 # the simulation (stand-in): reset / set_human_input / step / snapshot
var cam                  # thirdjam's follow camera (scripts/cam.gd)
var controls             # thirdjam's key and mouse mapping (scripts/controls.gd)
var rink_c: Dictionary   # FJamCameraRink {L, W, R}
var net: Vector2
var body: Node3D
var stick: Node3D
var view: Camera3D
var snap: Dictionary = {}
var last_move: Vector2 = Vector2.ZERO
var last_stick: Vector2 = Vector2.ZERO
var last_axis: Vector2 = Vector2.ZERO
var aim_hit: Vector2 = Vector2.ZERO
var aim_ok: bool = false
var replay: Array = []   # thirdjam's own human path (data/tj_trace_regular_pro.json rows), when the action `replay` starts the frame-0 tick
var replay_i: int = -1


func _pack_setup(c) -> void:
	ctx = c
	cart = ctx.read_json("hockey.regular.cartridge.json")
	gym = ctx.read_json("gym.json")
	var g: Dictionary = cart["game"]
	var rink: Dictionary = g["rink"]
	var rink_gen = ctx.load_script("gen/tj_rink.gd")
	rink_gen.build(ctx.root, rink, gym.get("hall", {}))
	var parts: Array = rink_gen.standin_figure(ctx.root)
	body = parts[0]
	stick = parts[1]
	rink_c = {"L": float(rink["length_m"]), "W": float(rink["width_m"]), "R": maxf(0.0, float(rink["corner_radius_m"]))}   # FJamCameraRink::FromFrame cpp:127-134
	var sign_: float = float(gym["attack_sign"])
	net = Vector2(sign_ * (rink_c["L"] * 0.5 - float(gym["net_inset_m"])), 0.0)   # GetFarNetWorldCm (HUDFeed.cpp:8-12), metres
	core = Standin.new(ctx.read_json("standin_law.json"))
	core.set_rink({"L": float(rink["length_m"]), "W": float(rink["width_m"]), "R": float(rink["corner_radius_m"]), "goal_w": float(rink.get("goal_width_m", 4.0))})
	core.reset(Vector2(float(gym["spawn"][0]), float(gym["spawn"][1])), float(gym["spawn_yaw"]))
	cam = Cam.new(Cam.settings(g["camera"]))
	controls = Controls.new()
	# FJamBindings::Defaults (InputMapping.cpp:98-119): the gym's verbs
	ctx.input.declare(&"forward", [KEY_W, KEY_UP])
	ctx.input.declare(&"back", [KEY_S, KEY_DOWN])
	ctx.input.declare(&"left", [KEY_A, KEY_LEFT])
	ctx.input.declare(&"right", [KEY_D, KEY_RIGHT])
	ctx.input.declare(&"sprint", [KEY_SHIFT])
	ctx.input.declare(&"brake", [KEY_CTRL])
	ctx.input.declare_aim(&"aim", 0.0, 200.0)      # the cursor on the ice z = 0 (CursorAimRink, HokejGameMode.cpp:741-754)
	ctx.input.declare(&"replay", [])               # proof only, no key: pressed on frame 0, the skater follows thirdjam's own logged path
	snap = core.snapshot()
	_camera_step()                                 # PossessHuman -> PushPresentation: the camera's first frame (cpp:1003-1009)
	view = ctx.cameras.add_view(&"follow", Vector3.ZERO, Vector3(1, 0, 0), float(cam.C["FovDeg"]))
	view.keep_aspect = Camera3D.KEEP_WIDTH         # FieldOfView is horizontal in Unreal (h:36-38)
	_draw()
	ctx.cameras.add_view(&"top", Vector3(0, 70, 0.01), Vector3.ZERO, 60.0)
	ctx.cameras.activate(&"follow")
	ctx.cameras.set_subject(&"follow", body)


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	var inp = ctx.input
	if frame == 0 and inp.pressed(&"replay"):
		replay = (ctx.read_json("tj_trace_regular_pro.json") as Dictionary)["rows"]
		cam = Cam.new(cam.C)                       # thirdjam's first logged frame starts its filter
	if not replay.is_empty():
		_replay_tick()
		return
	last_axis = Controls.axis(inp.strength(&"forward"), inp.strength(&"back"), inp.strength(&"left"), inp.strength(&"right"))
	var s: Dictionary = snap["Skaters"][snap["HumanIndex"]]
	var cam_yaw: float = deg_to_rad(cam.last_yaw_out) if cam.init else float(s["Yaw"])   # ReadHumanInput's camera yaw (cpp:943-946)
	last_move = controls.move(last_axis, cam_yaw)
	aim_ok = inp.aim_valid(&"aim")
	last_stick = Vector2.ZERO
	if aim_ok:
		var a: Vector3 = inp.aim(&"aim")
		aim_hit = controls.anchor_step(inp.aim_pixel(&"aim"), Vector2(a.x, a.z), s["Pos"])   # CursorAimRink (HokejGameMode.cpp:750-752)
		last_stick = controls.stick(aim_hit, s["Pos"])
	else:
		controls.anchor_reset()       # DEVIATION: thirdjam resets only when the ray misses the ice, not when the cursor leaves the window
	core.set_human_input({"Move": last_move, "bSprint": inp.pressed(&"sprint"), "bBrake": inp.pressed(&"brake"), "Stick": last_stick})
	core.step()
	snap = core.snapshot()
	_camera_step()
	_draw()


## The proof mode: one row of thirdjam's JAMCAM log a tick (one StepSimFrame there, its hit-stop frames already absent):
## the human's PosM and YawDeg set from the row, then our camera steps. Nothing simulates; the stand-in law is idle.
func _replay_tick() -> void:
	replay_i = mini(replay_i + 1, replay.size() - 1)
	var r: Array = replay[replay_i]
	var p := Vector2(float(r[1]), float(r[2]))
	var yaw: float = deg_to_rad(float(r[3]))
	snap = {"Frame": int(r[0]), "HumanIndex": 0, "Skaters": [{"Pos": p, "Vel": Vector2.ZERO, "Yaw": yaw, "PrevPos": p, "PrevYaw": yaw,
		"bSprinting": false, "Stamina": 0, "bBraking": false, "Stick": Vector2.ZERO}]}
	_camera_step()
	_draw()


func _camera_step() -> void:
	cam.C["KeepAspect"] = ctx.cameras.aspect()   # StepSimFrame reads the viewport's size every frame (CameraFollow.cpp:1226-1230)
	var s: Dictionary = snap["Skaters"][snap["HumanIndex"]]
	cam.step({"pos": s["Pos"], "yaw": rad_to_deg(float(s["Yaw"])), "rink": rink_c, "net": net})


func _draw() -> void:
	var s: Dictionary = snap["Skaters"][snap["HumanIndex"]]
	var p: Vector2 = s["Pos"]
	body.position = Vector3(p.x, 0.0, p.y)          # rink (x, y) -> Godot (x, z): Unreal's top view without a mirror
	body.rotation = Vector3(0.0, -float(s["Yaw"]), 0.0)
	# the stand-in stick: from the body's edge along FJamInput::Stick (size 0.5..1 of the reach 1.2 m, FJamStickConfig::ReachM);
	# no aim: the blade held ahead at half size. The sim's own blade (BladePos) is K1's.
	var d: Vector2 = s["Stick"]
	var yaw_s: float = float(s["Yaw"]) if d == Vector2.ZERO else atan2(d.y, d.x)
	var size: float = 0.5 if d == Vector2.ZERO else d.length()
	stick.position = Vector3(p.x + cos(yaw_s) * 0.25, 0.0, p.y + sin(yaw_s) * 0.25)
	stick.rotation = Vector3(0.0, -yaw_s, 0.0)
	stick.scale = Vector3(size * 1.2, 1.0, 1.0)
	var pose: Dictionary = cam.pose
	var cp: Vector2 = pose["pos"]
	var pr: float = deg_to_rad(float(pose["pitch"]))
	var yr: float = deg_to_rad(float(pose["yaw"]))
	var eye := Vector3(cp.x, float(pose["height"]), cp.y)
	var fwd := Vector3(cos(pr) * cos(yr), sin(pr), cos(pr) * sin(yr))   # FRotator(pitch, yaw, 0)'s forward, z up -> y up
	ctx.cameras.add_view(&"follow", eye, eye + fwd, float(cam.C["FovDeg"]))


func _pack_state() -> Dictionary:
	var s: Dictionary = snap["Skaters"][snap["HumanIndex"]]
	var p: Vector2 = s["Pos"]
	var v: Vector2 = s["Vel"]
	var pose: Dictionary = cam.pose
	var cp: Vector2 = pose["pos"]
	return {"frame": int(snap["Frame"]), "replay_i": replay_i, "x": p.x, "y": p.y, "vx": v.x, "vy": v.y, "speed": v.length(), "yaw_deg": rad_to_deg(float(s["Yaw"])),
		"sprinting": bool(s["bSprinting"]), "stamina": int(s["Stamina"]),
		"cam_x": cp.x, "cam_y": cp.y, "cam_h": float(pose["height"]), "cam_pitch": float(pose["pitch"]), "cam_yaw": float(pose["yaw"]),
		"cam_boards_w": cam.last_boards_weight,
		"axis_x": last_axis.x, "axis_y": last_axis.y, "move_x": last_move.x, "move_y": last_move.y,
		"back_held": controls.back_held, "back_yaw_deg": rad_to_deg(controls.back_yaw),
		"aim_ok": aim_ok, "anchored": controls.anchored, "aim_x": aim_hit.x, "aim_y": aim_hit.y, "aiming": controls.aiming, "stick_x": last_stick.x, "stick_y": last_stick.y}
