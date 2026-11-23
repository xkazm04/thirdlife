extends Node
## Hokej: thirdjam's whole match in our engine (K3 shell, round 3; docs/design/DIRECTIONS.md). The simulation and the bots
## are thirdjam's own C++ (lane K1's RinkCore, `ctx.cores.open("rink")`, engine/cores/rink/SNAPSHOT.md): the regular cartridge,
## 5 v 5, first to 3, at the level of data/match.json. This pack keeps the keys and the drawing: thirdjam's camera (cam.gd,
## equal to thirdjam's rendered camera within 0.54 cm, round 2), thirdjam's key and mouse mapping (human_input.gd), stand-in
## figures (match_view.gd) until lane K2's pawn.
## The order inside a frame is AHokejGameMode's (StepOnce, HokejGameMode.cpp:1636-1712): the human's input is read through
## the camera of the last sim frame (ReadHumanInput cpp:937), the sim steps, the figures take the frame (ApplySimFrame), then
## the camera steps once on it (PushPresentation -> StepSimFrame, CameraFollow.cpp:1183). The engine's physics interpolation
## draws camera and figures between the 60 Hz frames (TickComponent cpp:1319-1337, ApplyRender JamPawns.cpp:824-846).
## Two proof modes, chosen by a key-less action pressed on frame 0 (a bot's): `gym` (one skater on empty ice under the
## stand-in law, rounds 1-2: the control rules' tests), `replay` (thirdjam's own logged path through our camera, round 2).

const Cam := preload("cam.gd")
const Standin := preload("skate_standin.gd")
const Human := preload("human_input.gd")
const View := preload("match_view.gd")
const HitStop := preload("hit_stop.gd")

var ctx
var cart: Dictionary
var gym: Dictionary
var match_cfg: Dictionary
var rink                 # thirdjam's core (RinkCore): set_human_input / step / snapshot / state_hash
var core                 # what this run steps: the rink, or the gym's stand-in law
var mode: String = "match"
var cam                  # thirdjam's follow camera (scripts/cam.gd)
var human                # thirdjam's key and mouse mapping (scripts/human_input.gd)
var view                 # the stand-in figures (scripts/match_view.gd)
var hit_stop             # thirdjam's hit-stop, presentation only (scripts/hit_stop.gd)
var rink_c: Dictionary   # FJamCameraRink {L, W, R}
var follow: Camera3D
var snap: Dictionary = {}
var last_raw: Dictionary = {}
var last_in: Dictionary = {}
var over: bool = false
var replay: Array = []
var replay_i: int = -1


func _pack_setup(c) -> void:
	ctx = c
	cart = ctx.read_json("hockey.regular.cartridge.json")
	gym = ctx.read_json("gym.json")
	match_cfg = ctx.read_json("match.json")
	var g: Dictionary = cart["game"]
	var rk: Dictionary = g["rink"]
	var rink_gen = ctx.load_script("gen/tj_rink.gd")
	rink_gen.build(ctx.root, rk, gym.get("hall", {}))
	rink_c = {"L": float(rk["length_m"]), "W": float(rk["width_m"]), "R": maxf(0.0, float(rk["corner_radius_m"]))}   # FJamCameraRink::FromFrame cpp:127-134
	rink = ctx.cores.open("rink", "hockey.regular.cartridge.json")
	rink.set_difficulty(String(match_cfg["difficulty"]))
	rink.set_human_mode("input")
	rink.reset(ctx.seed)
	core = rink
	snap = rink.snapshot()
	view = View.new(ctx.root, rink_gen, snap, float(g["puck"]["radius_m"]))
	hit_stop = HitStop.new({"BumpRatio": 0.4, "DownRatio": 1.0, "DownFullRatio": 3.0})   # FJamContactConfig defaults (JamCartridge.h:396-399): no game.contact in the cartridge
	# JamControls::ButtonContext's numbers (InputMapping.cpp:474-486): UJamSim::CarrierReachM = max(shot.reach_m, SkaterRadius 0.4 +
	# stick.reach_m 1.2 (FJamStickConfig default)) + 0.05 (JamSim.cpp:862-869); FJamPassConfig defaults SaucerHalfFrames 8,
	# PowerFullFrames 30 (JamCartridge.h:356, 363): the regular cartridge has no game.pass
	human = Human.new({"carrier_reach": maxf(float(g["shot"]["reach_m"]), 0.4 + 1.2) + 0.05, "saucer_half": 8, "pass_power_full": 30})
	Human.declare(ctx.input)
	ctx.input.declare_aim(&"aim", 0.0, 200.0)      # the cursor on the ice z = 0 (CursorAimRink, HokejGameMode.cpp:741-754)
	ctx.input.declare(&"gym", [])                  # proof only, no key
	ctx.input.declare(&"replay", [])               # proof only, no key
	cam = Cam.new(Cam.settings(g["camera"]))
	_camera_step()                                 # PossessHuman -> PushPresentation: the camera's first frame (cpp:1003-1009)
	follow = ctx.cameras.add_view(&"follow", Vector3.ZERO, Vector3(1, 0, 0), float(cam.C["FovDeg"]))
	follow.keep_aspect = Camera3D.KEEP_WIDTH       # FieldOfView is horizontal in Unreal (h:36-38)
	_draw()
	view.reset_interpolation()                     # the first frame is drawn where it is, not slid into from the origin
	follow.reset_physics_interpolation()
	ctx.cameras.add_view(&"top", Vector3(0, 70, 0.01), Vector3.ZERO, 60.0)
	ctx.cameras.activate(&"follow")
	ctx.cameras.set_subject(&"follow", view.bodies[int(snap["HumanIndex"])])


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	var inp = ctx.input
	if frame == 0 and gym.get("hall", {}).has("light"):
		TLStyleHall.apply(ctx.root, gym["hall"]["light"])   # the style's roof light (visual only; nothing headless)
	if frame == 0 and inp.pressed(&"replay"):
		mode = "replay"
		replay = (ctx.read_json("tj_trace_regular_pro.json") as Dictionary)["rows"]
		cam = Cam.new(cam.C)                       # thirdjam's first logged frame starts its filter
		_one_skater()
	elif frame == 0 and inp.pressed(&"gym"):
		mode = "gym"
		core = Standin.new(ctx.read_json("standin_law.json"))
		var rk: Dictionary = cart["game"]["rink"]
		core.set_rink({"L": float(rk["length_m"]), "W": float(rk["width_m"]), "R": float(rk["corner_radius_m"]), "goal_w": float(rk.get("goal_width_m", 4.0))})
		core.reset(Vector2(float(gym["spawn"][0]), float(gym["spawn"][1])), float(gym["spawn_yaw"]))
		snap = core.snapshot()
		cam = Cam.new(cam.C)
		_camera_step()
		_one_skater()
	if mode == "replay":
		_replay_tick()
		return
	var s: Dictionary = snap["Skaters"][snap["HumanIndex"]]
	var cam_yaw: float = deg_to_rad(cam.last_yaw_out) if cam.init else float(s["Yaw"])   # ReadHumanInput's camera yaw (cpp:943-946)
	var aim_ok: bool = inp.aim_valid(&"aim")
	var a: Vector3 = inp.aim(&"aim")
	last_raw = Human.raw(inp, cam_yaw, aim_ok, inp.aim_pixel(&"aim"), Vector2(a.x, a.z))
	if mode == "match" and (last_raw["Pressed"] as PackedStringArray).has("R"):
		rink.reset(ctx.seed)                       # RestartMatch (HokejGameMode.cpp:800-818): DEVIATION, a new match on the same seed
		snap = rink.snapshot()
		over = false
	last_in = human.read(last_raw, snap, inp.aim_pixel(&"aim"))   # MOVES TO CORE GLUE (K1's set_raw_input)
	core.set_human_input(last_in)
	if not over:
		over = not core.step()
	snap = core.snapshot()
	if mode == "match":
		hit_stop.route(snap)                        # HitStopRoute, before the pawns apply the frame (HokejGameMode.cpp:1665)
		if hit_stop.held(int(snap["Frame"])):
			view.draw(snap, {hit_stop.victim: true, hit_stop.checker: true, -1: true})   # the two figures and the puck hold
			return                                  # the presentation frame holds: no camera step (HokejGameMode.cpp:1708)
	_camera_step()
	_draw()


## The proof mode of round 2: one row of thirdjam's JAMCAM log a tick (one StepSimFrame there, its hit-stop frames already
## absent): the human's PosM and YawDeg set from the row, then our camera steps. Nothing simulates.
func _replay_tick() -> void:
	replay_i = mini(replay_i + 1, replay.size() - 1)
	var r: Array = replay[replay_i]
	var p := Vector2(float(r[1]), float(r[2]))
	var yaw: float = deg_to_rad(float(r[3]))
	snap = {"Frame": int(r[0]), "HumanIndex": 0, "Carrier": -1, "Puck": {"Pos": Vector2(1000, 1000), "Z": 0.0, "LastTouch": -1, "PrevPos": Vector2(1000, 1000)},
		"Skaters": [{"Team": 0, "Pos": p, "Vel": Vector2.ZERO, "Yaw": yaw, "PrevPos": p, "PrevYaw": yaw, "BladePos": p + Vector2(cos(yaw), sin(yaw)) * 1.0,
		"bSprinting": false, "Stamina": 0, "bBraking": false}]}
	_camera_step()
	_draw()


## The proof modes have one skater: the others and the puck are put away.
func _one_skater() -> void:
	for i: int in range(1, view.bodies.size()):
		(view.bodies[i] as Node3D).visible = false
		(view.sticks[i] as Node3D).visible = false
	view.puck.visible = false


func _camera_step() -> void:
	cam.C["KeepAspect"] = ctx.cameras.aspect()   # StepSimFrame reads the viewport's size every frame (CameraFollow.cpp:1226-1230)
	var s: Dictionary = snap["Skaters"][snap["HumanIndex"]]
	# GetFarNetWorldCm (HUDFeed.cpp:8-12) with F.AttackSign = human team 0 ? +1 : -1 and NetInsetM 4 (HokejGameMode.cpp:1616-1617)
	var sign_: float = 1.0 if int(s.get("Team", 0)) == 0 else -1.0
	var net := Vector2(sign_ * (float(rink_c["L"]) * 0.5 - 4.0), 0.0)
	cam.step({"pos": s["Pos"], "yaw": rad_to_deg(float(s["Yaw"])), "rink": rink_c, "net": net})


func _draw() -> void:
	if mode == "match":
		view.draw(snap)
	else:
		view.draw_skater(0, snap["Skaters"][0])
	var pose: Dictionary = cam.pose
	var cp: Vector2 = pose["pos"]
	var pr: float = deg_to_rad(float(pose["pitch"]))
	var yr: float = deg_to_rad(float(pose["yaw"]))
	var eye := Vector3(cp.x, float(pose["height"]), cp.y)
	var fwd := Vector3(cos(pr) * cos(yr), sin(pr), cos(pr) * sin(yr))   # FRotator(pitch, yaw, 0)'s forward, z up -> y up
	ctx.cameras.add_view(&"follow", eye, eye + fwd, float(cam.C["FovDeg"]))


func _pack_state() -> Dictionary:
	var me: int = int(snap["HumanIndex"])
	var s: Dictionary = snap["Skaters"][me]
	var p: Vector2 = s["Pos"]
	var v: Vector2 = s["Vel"]
	var pose: Dictionary = cam.pose
	var cp: Vector2 = pose["pos"]
	var ctl = human.controls
	var mv: Vector2 = last_in.get("Move", Vector2.ZERO)
	var st: Vector2 = last_in.get("Stick", Vector2.ZERO)
	var ax: Vector2 = last_raw.get("Axis", Vector2.ZERO)
	var out: Dictionary = {"mode": mode, "frame": int(snap["Frame"]), "replay_i": replay_i, "human": me,
		"x": p.x, "y": p.y, "vx": v.x, "vy": v.y, "speed": v.length(), "yaw_deg": rad_to_deg(float(s["Yaw"])),
		"sprinting": bool(s["bSprinting"]), "stamina": int(s["Stamina"]),
		"cam_x": cp.x, "cam_y": cp.y, "cam_h": float(pose["height"]), "cam_pitch": float(pose["pitch"]), "cam_yaw": float(pose["yaw"]),
		"cam_boards_w": cam.last_boards_weight,
		"axis_x": ax.x, "axis_y": ax.y, "move_x": mv.x, "move_y": mv.y,
		"back_held": ctl.back_held, "back_yaw_deg": rad_to_deg(ctl.back_yaw),
		"anchored": ctl.anchored, "aiming": ctl.aiming, "stick_x": st.x, "stick_y": st.y,
		"in": _in_state(last_in)}
	if mode == "match":
		var pk: Dictionary = snap["Puck"]
		out["rink"] = ctx.cores.state()["rink"]     # the core's own hash, frame and score: the run's state_hash covers the match
		out["phase"] = int(snap["Phase"])
		out["over"] = over
		out["carrier"] = int(snap["Carrier"])
		out["puck_x"] = (pk["Pos"] as Vector2).x
		out["puck_y"] = (pk["Pos"] as Vector2).y
		out["puck_z"] = float(pk["Z"])
		out["team"] = int(s["Team"])
		out["faceoff"] = int(snap["FaceoffCountdown"])
	return out


## The FJamInput the human's skater got this frame, as plain values (bools as 0 / 1, vectors as integers x EXACT).
const EXACT: float = 1125899906842624.0   # 2^50
static func _in_state(i: Dictionary) -> Dictionary:
	var o: Dictionary = {}
	for k: String in i:
		var v: Variant = i[k]
		if v is Vector2:
			o[k] = [int((v as Vector2).x * EXACT), int((v as Vector2).y * EXACT)]   # x 2^50: the single-precision value exactly (a report rounds floats)
		elif v is bool:
			o[k] = 1 if v else 0
		else:
			o[k] = v
	return o
