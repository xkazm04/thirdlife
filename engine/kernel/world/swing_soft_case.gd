extends SceneTree
## Lane flight round 3 (19 Nov 2026): the soft end of a hard swing (selftest block 534). Headless, ticks only. The
## visitor in a world space of its own with a bar 2.8 m up. Prints `SWINGSOFT ok=<bool> ...`:
##   pump   from a dead hang, pumping with the swing for 60 s: the swing peaks near walker_grips SOFT_AMP (85 deg) and
##          stays under 90 deg, never reaches the 100 deg guard (no tick ends at it), and no tick changes the angular
##          speed by more than 1.2 rad/s (the dead stop changed it by its whole value, up to 7 rad/s, in one tick);
##   entry  a run at 9 m/s and a jump into the bar: the fast entry is bled off the same way (under 90 deg, no guard);
## The swing below SOFT_AMP is untouched: moves.bar_swing (block 523) still measures the plain pendulum's period.

const Space = preload("res://kernel/world/terrain/world_space.gd")
const Visitor = preload("res://kernel/world/visitor.gd")
const BAR_Y: float = 2.8

var _frames: int = 0
var _keep: Array = []


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var pump: Dictionary = _swing("pump")
		var entry: Dictionary = _swing("entry")
		var ok: bool = bool(pump["caught"]) and float(pump["max"]) < 90.0 and float(pump["max"]) > 70.0 and int(pump["guard"]) == 0 \
			and float(pump["dw"]) <= 1.2 and bool(entry["caught"]) and float(entry["max"]) < 90.0 and int(entry["guard"]) == 0 \
			and float(entry["dw"]) <= 1.2
		print("SWINGSOFT ok=%s pump: max_theta_deg=%.2f guard_ticks=%d max_domega=%.3f | entry 9 m/s: entry_omega=%.2f max_theta_deg=%.2f guard_ticks=%d max_domega=%.3f" % [
			ok, pump["max"], pump["guard"], pump["dw"], entry["w0"], entry["max"], entry["guard"], entry["dw"]])
		quit(0 if ok else 1)
	return false


func _swing(kind: String) -> Dictionary:
	var land: Node3D = Node3D.new()
	root.add_child(land)
	var sp: RefCounted = Space.new()
	sp.add_box(Transform3D(Basis(), Vector3(0, -0.5, 0)), Vector3(120, 1, 120))
	var bar: CylinderShape3D = CylinderShape3D.new()
	bar.radius = 0.05
	bar.height = 6.0
	_keep.append(bar)
	sp.call("_copy_solid", bar, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0, BAR_Y, 0)), true)
	sp.call("finish")
	land.set_meta(&"tl_space", sp)
	var v: Node3D = Visitor.new()
	land.add_child(v)
	v.setup(Vector3(0, 0, 0.25 if kind == "pump" else 20.0), Vector3.FORWARD)
	v.steer_on()
	var max_t: float = 0.0
	var guard: int = 0
	var dw: float = 0.0
	var w0: float = 0.0
	var caught: bool = false
	var last_w: float = 0.0
	var was_bar: bool = false
	for t: int in 3900:
		var w: Vector3 = Vector3.ZERO
		var jump: bool = false
		if v.mode == "bar":
			var face: Vector3 = Vector3(-sin(v.face_yaw), 0.0, -cos(v.face_yaw))
			var tangent: Vector3 = (v.get("bar_axis") as Vector3).cross(Vector3.DOWN)
			var sgn: float = 1.0 if tangent.dot(face) >= 0.0 else -1.0
			if kind == "pump":
				w = face * (4.5 if float(v.get("bar_omega")) * sgn >= 0.0 else -4.5)
		elif kind == "pump":
			jump = t == 3
		else:
			# a run at 9 m/s toward the bar, a jump about 2.6 m before it: the hands meet the bar on the way up
			w = Vector3(0, 0, -9.0)
			jump = v.mode == "ground" and v.feet.z < 2.7 and v.feet.z > 2.0
		v.wish(w, jump, false)
		v.step(v.feet, t + 1)
		if v.mode == "bar":
			var om: float = float(v.get("bar_omega"))
			if not was_bar:
				w0 = om
				last_w = om
			caught = true
			max_t = maxf(max_t, absf(rad_to_deg(float(v.get("bar_theta")))))
			if absf(rad_to_deg(float(v.get("bar_theta")))) >= 99.99:
				guard += 1
			dw = maxf(dw, absf(om - last_w))
			last_w = om
		was_bar = v.mode == "bar"
		if kind == "entry" and caught and v.mode != "bar":
			break
	land.queue_free()
	return {"max": max_t, "guard": guard, "dw": dw, "w0": w0, "caught": caught}
