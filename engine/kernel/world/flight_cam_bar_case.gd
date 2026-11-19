extends SceneTree
## Lane flight round 3 (19 Nov 2026): the visitor's camera and a bar (selftest block 533). Headless, ticks only. A
## visitor in a small world space of its own with a floor and a bar 2.8 m up (a copied, marked bar, as a pack's bar is
## in the village). Two runs of the same script, with the camera leaving bars out (the default) and, as a control, with
## the old behaviour (`ignore_bars = false`):
##   walk   he walks under the bar and on, the camera's arm sweeping through it;
##   swing  he jumps to the bar and pumps a hard swing for 8 s with the camera behind him.
## Prints `CAMBAR ok=<bool> ...`: with bars left out, the camera's lift and pull from avoidance stay 0 on every tick and
## (under 0.01 deg and 1 mm: rounding) and its largest move in one tick stays under 0.6 m (no pop); the control must lift or pull (so the case can see it).

const Space = preload("res://kernel/world/terrain/world_space.gd")
const Visitor = preload("res://kernel/world/visitor.gd")
const BAR_Y: float = 2.8
const BAR_Z: float = 0.0

var _frames: int = 0
var _keep: Array = []


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var on: Dictionary = _run(true)
		var off: Dictionary = _run(false)
		var ok: bool = bool(on["caught"]) and float(on["lift"]) < 0.01 and float(on["pull"]) < 0.001 and float(on["step"]) < 0.6
		ok = ok and (float(off["lift"]) > 0.0 or float(off["pull"]) > 0.0)
		print("CAMBAR ok=%s ignore: walk+swing max_lift_deg=%.6f max_pull_m=%.6f max_cam_step_m=%.3f caught=%s max_theta_deg=%.1f | control (old): max_lift_deg=%.3f max_pull_m=%.3f max_cam_step_m=%.3f" % [
			ok, on.lift, on.pull, on.step, on.caught, on.theta, off.lift, off.pull, off.step])
		quit(0 if ok else 1)
	return false


func _run(ignore: bool) -> Dictionary:
	var land: Node3D = Node3D.new()
	root.add_child(land)
	var sp: RefCounted = Space.new()
	sp.add_box(Transform3D(Basis(), Vector3(0, -0.5, 0)), Vector3(80, 1, 80))
	var bar: CylinderShape3D = CylinderShape3D.new()
	bar.radius = 0.05
	bar.height = 6.0
	_keep.append(bar)
	sp.call("_copy_solid", bar, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0, BAR_Y, BAR_Z)), true)
	sp.call("finish")
	land.set_meta(&"tl_space", sp)
	var v: Node3D = Visitor.new()
	land.add_child(v)
	v.setup(Vector3(0, 0, BAR_Z + 10.0), Vector3.FORWARD)
	v.steer_on()
	var cam: Node3D = v.get("cam")
	cam.set("ignore_bars", ignore)
	var lift: float = 0.0
	var pull: float = 0.0
	var step: float = 0.0
	var theta: float = 0.0
	var caught: bool = false
	var last: Vector3 = cam.global_position
	var t: int = 0
	# walk: under the bar and 8 m on (the arm sweeps through the bar as he passes 4 to 6 m beyond it)
	for i: int in 300:
		t += 1
		v.wish(Vector3(0, 0, -4.5) if v.feet.z > BAR_Z - 8.0 else Vector3.ZERO, false, false)
		v.step(v.feet, t)
		cam.call("_physics_process", 1.0 / 60.0)
		lift = maxf(lift, absf(float(cam.get("avoid_lift"))))
		pull = maxf(pull, float(cam.get("avoid_pull")))
		step = maxf(step, cam.global_position.distance_to(last))
		last = cam.global_position
	# swing: back under the bar, jump, pump hard with the camera behind him (it looks along his facing, across the bar)
	v.put(Vector3(0, 0, BAR_Z + 0.25), 0.0)            # beside the bar: put() finds the ground from above
	cam.call("snap")
	last = cam.global_position
	for i: int in 540:
		t += 1
		var face: Vector3 = Vector3(-sin(v.face_yaw), 0.0, -cos(v.face_yaw))
		var tangent: Vector3 = (v.get("bar_axis") as Vector3).cross(Vector3.DOWN)
		var sgn: float = 1.0 if tangent.dot(face) >= 0.0 else -1.0
		var w: Vector3 = face * (4.5 if float(v.get("bar_omega")) * sgn >= 0.0 else -4.5) if v.mode == "bar" else Vector3.ZERO
		v.wish(w, i == 3, false)
		v.step(v.feet, t)
		cam.call("_physics_process", 1.0 / 60.0)
		if v.mode == "bar":
			caught = true
			theta = maxf(theta, absf(rad_to_deg(float(v.get("bar_theta")))))
		lift = maxf(lift, absf(float(cam.get("avoid_lift"))))
		pull = maxf(pull, float(cam.get("avoid_pull")))
		step = maxf(step, cam.global_position.distance_to(last))
		last = cam.global_position
	land.queue_free()
	return {"lift": lift, "pull": pull, "step": step, "caught": caught, "theta": theta}
