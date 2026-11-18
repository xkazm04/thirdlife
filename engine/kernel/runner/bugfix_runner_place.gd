extends SceneTree
## Bugfix-37 D15 (selftest 340-bugfix-runner.sh, case runner.place_no_glide). Physics interpolation is on project-wide,
## so a kernel teleport that does not reset it is DRAWN as a glide from the old place for one tick. TLBall.place,
## TLBiped.place and TLVehicle.place are called inside a physics tick, 30 m from where the body stood; every frame
## drawn before the next tick must show the body at its new place (get_global_transform_interpolated within 5 cm).
## A twin ball teleported by hand without the reset is the control: it must glide (the check can bite).
## The verdict counts frames, not time: at least one drawn frame per kind is required, and no kernel frame may glide.
## Prints one line: `BUGFIXRUNNER place ok|fail ...`.

const PLACES: int = 24             # placements per body, alternating x 0 / x 30, one every other tick
const FAR_M: float = 30.0
const NEAR_M: float = 0.05         # one tick of gravity is 3 mm; a glide is metres
const GLIDE_M: float = 0.5

var _bodies: Array = []            # [name, Node3D, z]
var _twin: RigidBody3D = null
var _ticks: int = 0
var _placed_tick: int = -1
var _target_x: float = 0.0
var _done: int = 0


func _initialize() -> void:
	var ball: TLBall = TLBall.create({"kind": &"puck", "radius": 0.1, "position": Vector3(0, 0.07, 0), "planar": true})
	ball.gravity_scale = 0.0
	var biped: TLBiped = TLBiped.create({"position": Vector3(0, 0.0, 6.0)})
	var car: TLVehicle = TLVehicle.create({"position": Vector3(0, 0.5, 12.0)})
	car.gravity_scale = 0.0
	_twin = TLBall.create({"kind": &"puck", "radius": 0.1, "position": Vector3(0, 0.07, 18.0), "planar": true})
	_twin.gravity_scale = 0.0
	_bodies = [["ball", ball, 0.0], ["biped", biped, 6.0], ["vehicle", car, 12.0]]
	for b: Array in _bodies:
		root.add_child(b[1])
	root.add_child(_twin)
	physics_frame.connect(_on_tick)
	_run()


func _run() -> void:
	var seen: Dictionary = {"ball": 0, "biped": 0, "vehicle": 0, "twin": 0}
	var glide: Dictionary = {"ball": 0, "biped": 0, "vehicle": 0, "twin": 0}
	var worst: Dictionary = {"ball": 0.0, "biped": 0.0, "vehicle": 0.0}
	var twin_judged: int = 0          # control frames whose fraction leaves room for a visible glide
	var guard: int = 0
	while _done < PLACES and guard < 20000:
		await process_frame
		guard += 1
		if _placed_tick < 0 or _ticks != _placed_tick:
			continue                      # only the frames drawn after a place and before the next tick
		for b: Array in _bodies:
			var d: float = absf((b[1] as Node3D).get_global_transform_interpolated().origin.x - _target_x)
			seen[b[0]] += 1
			worst[b[0]] = maxf(float(worst[b[0]]), d)
			if d > NEAR_M:
				glide[b[0]] += 1
		var td: float = absf(_twin.get_global_transform_interpolated().origin.x - _target_x)
		seen["twin"] += 1
		if Engine.get_physics_interpolation_fraction() < 0.9:
			twin_judged += 1
			if td > GLIDE_M:
				glide["twin"] += 1
	var why: PackedStringArray = PackedStringArray()
	for k: String in ["ball", "biped", "vehicle"]:
		if int(seen[k]) == 0:
			why.append("%s: no frame drawn between a place and the next tick" % k)
		elif int(glide[k]) > 0:
			why.append("%s glides on %d/%d frames (worst %.2f m)" % [k, glide[k], seen[k], worst[k]])
	if twin_judged > 0 and int(glide["twin"]) == 0:
		why.append("control: the hand-moved twin never glided on %d judged frames (the check cannot bite)" % twin_judged)
	print("BUGFIXRUNNER place %s %s placements=%d frames ball=%d biped=%d vehicle=%d worst_m ball=%.3f biped=%.3f vehicle=%.3f control_glides=%d/%d" % [
		"ok" if why.is_empty() else "fail", "; ".join(why) if not why.is_empty() else "-", _done, seen["ball"], seen["biped"], seen["vehicle"],
		worst["ball"], worst["biped"], worst["vehicle"], glide["twin"], twin_judged])
	quit(0 if why.is_empty() else 1)


func _on_tick() -> void:
	_ticks += 1
	if _ticks < 10 or _ticks % 2 != 0 or _done >= PLACES:
		return
	_target_x = FAR_M if _done % 2 == 0 else 0.0
	for b: Array in _bodies:
		var at: Vector3 = Vector3(_target_x, (b[1] as Node3D).global_position.y, float(b[2]))
		if b[0] == "ball":
			(b[1] as TLBall).place(at)
		elif b[0] == "biped":
			(b[1] as TLBiped).place(at)
		else:
			(b[1] as TLVehicle).place(at)
	# the control: the same teleport by hand, without resetting the interpolation
	var tw: Vector3 = Vector3(_target_x, _twin.global_position.y, 18.0)
	_twin.global_position = tw
	PhysicsServer3D.body_set_state(_twin.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(_twin.global_transform.basis, tw))
	_placed_tick = _ticks
	_done += 1
