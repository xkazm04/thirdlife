extends Node3D
## N7 / P4. The visitor: the player as a walker between the games of a world. Kernel-owned. P4: he has a BODY: a
## kinematic capsule in a physics space that belongs to the world (terrain/world_space.gd, built by the landscape),
## so he walks on the terrain, stands on a plot's own ground inside the plot, and stops at fences, trees, rocks, walls
## and rails. He is in no pack's physics space and no pack can see him: the packs are untouched.
##
## Where the SCHEDULER thinks he is stays the world's `player_pos` (the walk script, or WASD when a person walks): a
## scripted walk gives the scheduler the scripted position and the body follows it (it cannot pass an obstacle, so it
## can fall behind; `max_dev` says how far, and a walk that is meant to pass must be adjusted); when a person walks,
## the body decides and `player_pos` is set from it each tick.
##
##   visitor.setup(at, facing)      after the node is in the tree (the camera becomes its sibling)
##   visitor.step(pos, frame)       once per world tick; `pos` is the wanted position (feet, x and z matter)
##   visitor.cam                    the chase camera (make it current while nobody is on stage)
## At the last tick of a walk one `tl.view/1` line of kind `visitor` is printed: ticks, ticks blocked, largest and final distance
## between the body and the scripted position.

var rig: Node3D = null
var cam: TLChaseCam = null
var speed: float = 0.0                  # metres per second, from the last two positions of the body
var space: RefCounted = null            # the world's space (terrain/world_space.gd), null when there is no landscape
var feet: Vector3 = Vector3.ZERO        # where the body stands
var max_dev: float = 0.0
var end_dev: float = 0.0
var ticks: int = 0
var catch_up_m: float = 0.5             # metres per tick the body may close on a scripted position it has fallen behind
var _last: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _world: Node = null
var _reported: bool = false
var _logged: int = 0
var _frame_usec: PackedInt64Array = PackedInt64Array()      # the wall time of every frame while he walks (cost line)
var _frame_last: int = 0
var _later: Array = []                  # S2: probes with a world tick `t`, run when the world reaches it
# P11: a person steers (kernel/runner/visit.gd): he faces where the camera looks, A and D sidestep, the mouse turns
# the view. A scripted walk keeps the N7 behaviour (he turns to where he moves and the camera follows his back).
var steer: bool = false
var look_yaw: float = 0.0               # where he and the camera look (radians, 0 = -z), changed only by `turn`
var look_pitch: float = 0.0             # the camera's elevation above the point it looks at (radians)
var _cam_dist: float = 8.5
var _cam_look_h: float = 1.7
# Walker-feel (18 Nov): a person's body has weight (terrain/world_space.gd `drive()`): visit.gd hands over a wish each
# tick (`wish()`), the body moves by velocity, the figure turns toward where he goes (eased), the camera follows the
# mouse only. A sidestep with the camera's facing would show the rig's forward cycle sliding sideways: the biped rig
# reads speed, not direction, so he turns to his travel and the camera keeps the view.
const FACE_EASE: float = 0.22           # share of the remaining turn of the figure toward his travel, per tick
const CAM_ANCHOR: float = 0.45          # the camera's anchor follows him by this share per tick (x, z) ...
const CAM_ANCHOR_Y: float = 0.18        # ... and this share in height (a jump, a step, a landing are eased)
var face_yaw: float = 0.0               # where the figure faces (radians, 0 = -z); the node itself keeps `look_yaw`
var face_view: bool = false             # lane walker (TL_AD_KEYS=sidestep, visit.gd): on the ground the figure faces `look_yaw`, not his travel
var mode: String = "ground"             # the body's mode: ground | air | slope | slide
signal flight_step
const Body = preload("res://kernel/world/terrain/world_body.gd")
var flying: bool:
	get:
		return mode == "fly"
var _flight_changed_at := 0
var fly_t: int:
	get:
		var elapsed := ticks - _flight_changed_at
		return elapsed if flying else -1 - elapsed
var _flight_turn := 0.0
var fly_turn: float:
	get:
		return _flight_turn
var fly_speed_k: float:
	get:
		return clampf(Vector2(vel.x, vel.z).length() / Body.FLY_CRUISE, 0, 1)
var _cam_flight := 0.0
# Lane flight: the mechanical wings on the rig's `back` socket (kernel/world/flight_wings.gd, assets/engine/wings.glb) and
# the figure's lean into the flight (degrees forward, about his middle) and bank (degrees, + = rolled left, into a left turn)
const FlightWings: GDScript = preload("res://kernel/world/flight_wings.gd")
const LEAN_HOVER: float = 12.0
const LEAN_CRUISE: float = 62.0
const BANK_MAX: float = 28.0
var wings: RefCounted = null
var lean: float = 0.0
var bank: float = 0.0
var _wish_fly := false
var _wish_climb := 0.0
var vel: Vector3 = Vector3.ZERO         # the body's velocity, m/s
var _wish: Vector3 = Vector3.ZERO
var _wish_jump: bool = false
var _wish_slide: bool = false
var trace_frames: int = 0               # drawn frames still to trace (a device script's `trace`, kernel/runner/visit.gd)


func setup(at: Vector3, facing: Vector3 = Vector3.FORWARD, cam_opts: Dictionary = {}) -> void:
	name = "TLVisitor"
	var land: Node = get_parent()
	if land != null and land.has_meta(&"tl_space"):
		space = land.get_meta(&"tl_space")
	var view: Node = land.get_parent() if land != null else null
	_world = view.get("world") if view != null else null
	if space != null:
		var g: float = space.call("ground_at", at.x, at.z, at.y + 80.0)
		if not is_nan(g):
			at.y = g
		space.call("place", at)
	feet = at
	position = at
	_last = at
	if space != null and _world != null:
		var walk: Dictionary = _world.get("walk")
		if typeof(walk.get("visitor_probe")) == TYPE_ARRAY:
			_run_probes(walk["visitor_probe"], land.get_meta(&"tl_probe", {}), at)
	if facing.length() > 0.001:
		_yaw = atan2(-facing.x, -facing.z)
	rotation.y = _yaw
	rig = TLRigs.build("biped", {})
	if rig != null:
		add_child(rig)
		wings = FlightWings.attach(rig)
	var chase := preload("res://kernel/world/terrain/crown_camera.gd").new()
	if space != null and space.get("drawn_crowns") is Dictionary:
		chase.crowns = space.get("drawn_crowns")
	cam = chase
	cam.name = "VisitorCam"
	get_parent().add_child(cam)
	var o: Dictionary = {"distance": 8.5, "height": 3.6, "look_height": 1.7, "stiffness": 0.05, "fov": 60.0}
	o.merge(cam_opts, true)
	if space != null:
		o["avoid_space"] = space.get("space")
		o["avoid_mask"] = 1 | 4                 # the ground and solid things, and the trees' crowns (world_space CANOPY)
		cam.near = 0.05
	cam.setup(self, o)
	_cam_dist = Vector2(float(o["distance"]), float(o["height"]) - float(o["look_height"])).length()
	_cam_look_h = float(o["look_height"])
	look_pitch = atan2(float(o["height"]) - float(o["look_height"]), float(o["distance"]))
	look_yaw = _yaw
	face_yaw = _yaw
	if space != null:
		space.call("rest")
	reset_physics_interpolation()


## P11. A person's controls: from now on he faces `look_yaw` and the camera sits behind him at `look_pitch`, at once
## (no smoothing: the view follows the mouse tick by tick).
func steer_on() -> void:
	steer = true
	cam.stiffness = 1.0
	cam.follow = 1.0
	cam.aim = 1.0
	cam.anchor_follow = CAM_ANCHOR
	cam.anchor_follow_y = CAM_ANCHOR_Y
	_place_cam()
	cam.snap()


## Walker-feel. A person's wish for this tick (kernel/runner/visit.gd, below its sampling line): `v` the horizontal
## velocity he asks for (m/s, world axes), `jump` / `slide`: the key went down this tick.
func wish(v: Vector3, jump: bool, slide: bool, toggle_fly: bool = false, climb: float = 0.0) -> void:
	_wish_fly = toggle_fly
	_wish_climb = climb
	_wish = v
	_wish_jump = _wish_jump or jump
	_wish_slide = _wish_slide or slide


## Turns the view: `dx` radians to the right (the mouse moved right), `dy` radians down; the pitch stays in its limits.
func turn(dx: float, dy: float, pitch_min: float, pitch_max: float) -> void:
	look_yaw = wrapf(look_yaw - dx, -PI, PI)
	look_pitch = clampf(look_pitch + dy, pitch_min, pitch_max)
	_place_cam()


func _place_cam() -> void:
	var pitch := look_pitch - deg_to_rad(6.0) * _cam_flight
	var arm := _cam_dist * (1.0 + 0.8 * _cam_flight)
	cam.distance = arm * cos(pitch)
	cam.height = _cam_look_h + arm * sin(pitch)
	cam.look_height = _cam_look_h


## P11. Puts him at `at` (feet, x and z; the ground decides y) facing `yaw`, the camera behind him, the figure back
## in its locomotion (no held clip).
func put(at: Vector3, yaw: float) -> void:
	if space != null:
		var g: float = space.call("ground_at", at.x, at.z, 200.0)
		at.y = g if not is_nan(g) else feet.y
		space.call("place", at)
	feet = at
	_last = at
	position = at
	_yaw = yaw
	look_yaw = yaw
	face_yaw = yaw
	rotation.y = yaw
	if space != null:
		space.call("rest")
	if flying:
		_flight_changed_at = ticks
	_flight_turn = 0.0
	_wish_fly = false
	_wish_climb = 0.0
	_cam_flight = 0.0
	vel = Vector3.ZERO
	mode = "ground"
	if steer:
		_flight_camera()
	lean = 0.0
	bank = 0.0
	if rig != null:
		rig.transform = Transform3D.IDENTITY
		rig.rotation.y = 0.0
		_clip(&"")                              # a teleport ends any held clip: he stands where he is put (D7)
	reset_physics_interpolation()
	snap()


func step(pos: Vector3, frame: int) -> void:
	ticks += 1
	if not _later.is_empty() and space != null and _world != null and int(_world.get("tick")) >= int((_later[0] as Dictionary)["t"]):
		_run_probes([_later.pop_front()], {}, Vector3.INF)
		space.call("place", feet)
	if space != null and steer:
		_drive_step(pos, frame)
		return
	if space != null:
		var want: Vector3 = Vector3(pos.x - feet.x, 0.0, pos.z - feet.z)
		var dist: float = want.length()
		if dist > catch_up_m:
			want = want / dist * catch_up_m
		var res: Dictionary = space.call("walk", feet, want)
		feet = res["pos"]
		if bool(res["blocked"]) and _logged < 6 and (ticks % 30 == 1 or _logged < 2):
			_logged += 1
			var lh: Dictionary = space.get("last_hit")
			print(JSON.stringify({"schema": "tl.view/1", "kind": "visitor_blocked", "world_tick": int(_world.get("tick")) if _world != null else -1,
				"feet": [snappedf(feet.x, 0.01), snappedf(feet.y, 0.01), snappedf(feet.z, 0.01)], "want": [snappedf(pos.x, 0.01), snappedf(pos.z, 0.01)],
				"hit": str(lh.get("tag", "none")), "at": str(lh.get("at", "")), "normal": str(lh.get("n", ""))}, "", false))
		var dev: float = Vector2(pos.x - feet.x, pos.z - feet.z).length()
		max_dev = maxf(max_dev, dev)
		end_dev = dev
		if _world != null and bool(_world.get("player_live")):
			_world.set("player_pos", Vector3(feet.x, pos.y, feet.z))        # a person walks: the body decides
		_report_at_end()
	else:
		feet = pos
	var d: Vector3 = feet - _last
	d.y = 0.0
	speed = d.length() * 60.0
	var local_v: Vector3 = Vector3(0.0, 0.0, -speed)
	if steer:
		_yaw = look_yaw
		local_v = (d * 60.0).rotated(Vector3.UP, -_yaw)
	elif speed > 0.2:
		_yaw = lerp_angle(_yaw, atan2(-d.x, -d.z), 0.18)
	position = feet
	rotation.y = _yaw
	_last = feet
	if rig != null and visible:
		rig.call("set_locomotion", local_v, true)
		rig.call("tick", frame)


## Walker-feel: one tick of a person's body (steer on, a space): the wish moves the body by velocity; the figure turns
## toward his travel; the rig is told the velocity in its own axes, whether he stands, and the one-shot clips.
func _drive_step(pos: Vector3, frame: int) -> void:
	if not visible:
		# a game is on stage: the walker stands where he entered it (as before: nothing moved him then); a held slide
		# or slope clip ends with the slide the rest just ended, or he comes back on his hip (bugfix-37 D7)
		space.call("rest")
		if rig != null and (mode == "slide" or mode == "slope"):
			_clip(&"")
		if flying:
			_flight_changed_at = ticks
		_flight_turn = 0.0
		_wish_fly = false
		_wish_climb = 0.0
		vel = Vector3.ZERO
		mode = "ground"
		_wish_jump = false
		_wish_slide = false
		return
	var res: Dictionary = space.call("drive", feet, _wish, _wish_jump, _wish_slide, _wish_fly, _wish_climb)
	_wish_fly = false
	_wish_climb = 0.0
	_wish_jump = false
	_wish_slide = false
	var was: String = mode
	if bool(res["blocked"]) and _logged < 6 and (ticks % 30 == 1 or _logged < 2):
		_logged += 1
		var lh: Dictionary = space.get("last_hit")
		print(JSON.stringify({"schema": "tl.view/1", "kind": "visitor_blocked", "world_tick": int(_world.get("tick")) if _world != null else -1,
			"feet": [snappedf(feet.x, 0.01), snappedf(feet.y, 0.01), snappedf(feet.z, 0.01)], "mode": str(res["mode"]),
			"hit": str(lh.get("tag", "none")), "at": str(lh.get("at", "")), "normal": str(lh.get("n", ""))}, "", false))
	feet = res["pos"]
	vel = res["vel"]
	mode = str(res["mode"])
	_flight_turn = float(res.get("fly_turn", 0))
	if flying != (was == "fly"):
		_flight_changed_at = ticks
	if flying or was == "fly" or _cam_flight > 0.0:
		_cam_flight = lerpf(_cam_flight, fly_speed_k if flying else 0.0, 1.0 - exp(-1.0 / 30.0))
		if _cam_flight < 0.00001:
			_cam_flight = 0.0
		_flight_camera()
	if _world != null and bool(_world.get("player_live")):
		_world.set("player_pos", Vector3(feet.x, pos.y, feet.z))        # a person walks: the body decides
	var d: Vector3 = feet - _last
	d.y = 0.0
	speed = d.length() * 60.0
	var hv: Vector3 = Vector3(vel.x, 0.0, vel.z)
	if face_view and (mode == "ground" or mode == "air"):
		face_yaw = lerp_angle(face_yaw, look_yaw, FACE_EASE)          # a sidestep or a backward walk: the gait reads the direction
	elif hv.length() > 0.5 and mode != "slope":
		face_yaw = lerp_angle(face_yaw, atan2(-hv.x, -hv.z), FACE_EASE)
	elif mode == "slope" and hv.length() > 0.5:
		face_yaw = lerp_angle(face_yaw, atan2(-hv.x, -hv.z), FACE_EASE * 0.5)
	_yaw = look_yaw
	position = feet
	rotation.y = look_yaw
	_last = feet
	if rig != null and visible:
		_lean_and_bank(wrapf(face_yaw - look_yaw, -PI, PI))
		var local_v: Vector3 = vel.rotated(Vector3.UP, -face_yaw)
		rig.call("set_locomotion", local_v, mode == "ground" or mode == "slide")
		for e: Variant in res["events"]:
			match str(e):
				"jump":
					_clip(&"jump")
				"land":
					if mode != "slope":
						_clip(&"land")
				"slide":
					_clip(&"slide")
				"slope":
					_clip(&"slope_slide")
				"end_slide":
					# a slide started this very tick ends here too (pressed on the edge tick, D19)
					if was == "slide" or was == "slope" or (res["events"] as Array).has("slide"):
						_clip(&"")
				"fly_start":
					_clip(&"fly")
				"fly_land", "fly_end":
					_clip(&"")
		rig.call("tick", frame)
		if wings != null:
			wings.call("tick", flying, fly_speed_k, _flight_turn, frame)


	if flying or res.events.has("fly_land"):
		flight_step.emit()


## Lane flight: the figure leans into the flight (LEAN_HOVER hovering, LEAN_CRUISE at cruise, eased) about a point at
## his middle and banks into a turn (from the heading's turn rate); on the ground both are 0 and the rig is turned only
## about y, exactly as before.
func _lean_and_bank(yaw_rel: float) -> void:
	var lean_want: float = lerpf(LEAN_HOVER, LEAN_CRUISE, fly_speed_k) if flying else 0.0
	var bank_want: float = clampf(rad_to_deg(_flight_turn) * 0.2, -BANK_MAX, BANK_MAX) if flying else 0.0
	if flying:
		lean = lerpf(lean, lean_want, 0.08)
		bank = lerpf(bank, bank_want, 0.1)
	else:
		# landed or fallen out of flight: he straightens up in at most 30 ticks and lands exactly on 0 (flight.pose)
		lean = move_toward(lean, 0.0, clampf(absf(lean) * 0.12, 1.0, 5.0))
		bank = move_toward(bank, 0.0, clampf(absf(bank) * 0.12, 1.0, 5.0))
	if lean == 0.0 and bank == 0.0:
		rig.transform = Transform3D.IDENTITY
		rig.rotation.y = yaw_rel
		return
	var b: Basis = Basis(Vector3.UP, yaw_rel) * Basis.from_euler(Vector3(deg_to_rad(-lean), 0.0, deg_to_rad(bank)))
	var mid: Vector3 = Vector3(0.0, 1.0, 0.0)
	rig.transform = Transform3D(b, mid - b * mid)


func _flight_camera() -> void:
	# Anchor the cast inside the flying capsule, including when braking against a wall.
	cam.anchor_follow = 1.0 if flying else CAM_ANCHOR
	cam.anchor_follow_y = 1.0 if flying else CAM_ANCHOR_Y
	_place_cam()


## Plays a clip of the wire only if the rig has it (lane L adds them); &"" is always allowed (back to locomotion).
func _clip(c: StringName) -> void:
	if String(c) == "" or (rig.call("clips") as PackedStringArray).has(String(c)):
		rig.call("play", c)


## Probes (a walk's `visitor_probe`): the body is put at `from`, told to walk to `to`, and the line says where it ended.
## `{"name", "from": [x, z], "to": [x, z], "expect": "stop" | "pass"}`; the element "auto" adds a tree, a rock and the
## bridge's rail from the landscape (the first of each on gentle ground). `stop`: the body must end more than 0.5 m
## short of `to`, `pass`: within 0.3 m. Results are printed as `tl.view/1` lines of kind `visitor_probe`; the body is put back.
func _run_probes(list: Array, auto: Dictionary, back_to: Vector3) -> void:
	var probes: Array = []
	for p: Variant in list:
		if typeof(p) == TYPE_STRING and str(p) == "auto":
			if auto.has("tree"):
				var t: Array = auto["tree"]
				probes.append({"name": "tree", "from": [float(t[0]) - 6.0, float(t[1])], "to": [float(t[0]) + 6.0, float(t[1])], "expect": "stop"})
			if auto.has("rock"):
				var r: Array = auto["rock"]
				probes.append({"name": "rock", "from": [float(r[0]) - 6.0, float(r[1])], "to": [float(r[0]) + 6.0, float(r[1])], "expect": "stop"})
			if auto.has("rail"):
				var b: Array = auto["rail"]
				probes.append({"name": "bridge_rail", "from": [float(b[0]), float(b[1])], "to": [float(b[0]) + float(b[2]) * 8.0, float(b[1]) + float(b[3]) * 8.0], "expect": "stop"})
		elif typeof(p) == TYPE_DICTIONARY and (p as Dictionary).has("t") and int((p as Dictionary)["t"]) > 0 and back_to != Vector3.INF:
			_later.append(p)                        # S2: at its world tick (a site's scaffold before and after its game arrives)
		elif typeof(p) == TYPE_DICTIONARY:
			probes.append(p)
	for pr: Dictionary in probes:
		var f: Array = pr["from"]
		var to: Array = pr["to"]
		var g: float = space.call("ground_at", float(f[0]), float(f[1]), 120.0)
		var pos: Vector3 = Vector3(float(f[0]), 0.0 if is_nan(g) else g, float(f[1]))
		space.call("place", pos)
		var settle: Dictionary = space.call("walk", pos, Vector3.ZERO)
		pos = settle["pos"]
		var target: Vector2 = Vector2(float(to[0]), float(to[1]))
		var still: int = 0
		var steps: int = 0
		var hit: String = "none"
		while steps < 900:
			steps += 1
			var want: Vector2 = target - Vector2(pos.x, pos.z)
			if want.length() < 0.05:
				break
			if want.length() > 0.12:
				want = want.normalized() * 0.12
			var res: Dictionary = space.call("walk", pos, Vector3(want.x, 0.0, want.y))
			var np: Vector3 = res["pos"]
			if Vector2(np.x - pos.x, np.z - pos.z).length() < 0.01:
				still += 1
			else:
				still = 0
			if bool(res["blocked"]):
				hit = str((space.get("last_hit") as Dictionary).get("tag", "slope"))
			pos = np
			if still > 20:
				break
		var short: float = Vector2(pos.x, pos.z).distance_to(target)
		var expect: String = str(pr.get("expect", "stop"))
		var ok: bool = short > 0.5 if expect == "stop" else short < 0.3
		print(JSON.stringify({"schema": "tl.view/1", "kind": "visitor_probe", "name": str(pr.get("name", "")), "expect": expect, "ok": ok, "from": f, "to": to,
			"end": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)], "short_of_target_m": snappedf(short, 0.01), "stopped_by": hit, "ticks": steps}, "", false))
	space.set("blocked_ticks", 0)
	if back_to != Vector3.INF:
		space.call("place", back_to)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if trace_frames > 0:
		trace_frames -= 1
		var f: Vector3 = get_global_transform_interpolated().origin
		var c: Vector3 = cam.get_global_transform_interpolated().origin if cam != null else Vector3.ZERO
		print(JSON.stringify({"schema": "tl.view/1", "kind": "visitor_frame", "tick": int(_world.get("tick")) if _world != null else -1,
			"physics_frames": Engine.get_physics_frames(), "usec": now, "fraction": snappedf(Engine.get_physics_interpolation_fraction(), 0.001),
			"figure": [snappedf(f.x, 0.0001), snappedf(f.y, 0.0001), snappedf(f.z, 0.0001)], "cam": [snappedf(c.x, 0.0001), snappedf(c.y, 0.0001), snappedf(c.z, 0.0001)]}, "", false))
	if _frame_last > 0:
		_frame_usec.append(now - _frame_last)
	_frame_last = now


func _frame_ms(p: float) -> float:
	if _frame_usec.is_empty():
		return 0.0
	var sorted: PackedInt64Array = _frame_usec.duplicate()
	sorted.sort()
	return snappedf(float(sorted[clampi(int(ceil(p * float(sorted.size()))) - 1, 0, sorted.size() - 1)]) / 1000.0, 0.001)


func _report_at_end() -> void:
	if _reported or _world == null or bool(_world.get("player_live")):
		return
	if int(_world.get("tick")) >= int(_world.get("walk_ticks")) - 2:
		_reported = true
		var s: Dictionary = space.get("stats")
		print(JSON.stringify({"schema": "tl.view/1", "kind": "visitor", "ticks": ticks, "blocked_ticks": int(space.get("blocked_ticks")), "max_dev_m": snappedf(max_dev, 0.01),
			"end_dev_m": snappedf(end_dev, 0.01), "frame_ms_p50": _frame_ms(0.5), "frame_ms_p99": _frame_ms(0.99), "frame_ms_max": _frame_ms(1.0), "end": [snappedf(feet.x, 0.01), snappedf(feet.y, 0.01), snappedf(feet.z, 0.01)],
			"space": s}, "", false))


## Lane walker round 3: how often the camera swung sideways round him near crowns (crown_camera.gd, TL_CROWN_SWING).
func _exit_tree() -> void:
	if cam != null and cam.get("side_ticks") != null:
		print(JSON.stringify({"schema": "tl.view/1", "kind": "visitor_cam", "crown_swing": OS.get_environment("TL_CROWN_SWING"),
			"side_ticks": int(cam.get("side_ticks")), "max_side_deg": float(cam.get("max_side"))}, "", false))


func snap() -> void:
	if cam != null:
		cam.snap()
