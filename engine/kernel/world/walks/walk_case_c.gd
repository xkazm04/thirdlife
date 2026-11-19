extends SceneTree
## Headless regressions for a narrow V and a game floor replacing a pad. One drive per physics tick.
const Space = preload("res://kernel/world/terrain/world_space.gd")
const Walk = preload("res://kernel/world/walks/walk_case.gd")

var _filter := ""
var _n := 0
var _ok := 0


func _want(name: String) -> bool:
	return _filter.is_empty() or name.contains(_filter)


func _say(name: String, ok: bool, figures: Array) -> void:
	_n += 1
	_ok += int(ok)
	print("WALKCASE %s %s %s" % [name, "ok" if ok else "fail", " | ".join(figures)])


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_filter = args[0] if not args.is_empty() else ""
	if _want("walk.v_wedge"):
		_v_wedge()
	for name: String in ["walk.v_asymmetric", "walk.v_yaw", "walk.v_terrain"]:
		if _want(name):
			_channel_variant(name)
	if _want("walk.single_face"):
		_single_face()
	if _want("walk.step_edge"):
		_step_edge()
	if _want("walk.pad_swap"):
		_pad_swap()
	print("WALKCASE done %d %d" % [_ok, _n])
	quit(2 if _n == 0 else (0 if _ok == _n else 1))


## 4 m walls, a 10 cm strip of floor and open ends at x = +/-10 m.
static func channel(sp: RefCounted, deg: float, grade: float = 0.0, other_deg: float = 0.0, yaw: float = 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
	for side: int in [-1, 1]:
		var angle := other_deg if side > 0 and other_deg > 0.0 else deg
		var width := 4.0 / tan(deg_to_rad(angle))
		var base := side * 0.05
		var rim := side * (width + 0.05)
		var a := Vector3(-10, 10 * grade, base)
		var b := Vector3(10, -10 * grade, base)
		var c := Vector3(10, 4 - 10 * grade, rim)
		var d := Vector3(-10, 4 + 10 * grade, rim)
		sp.add_faces(xf * PackedVector3Array([a, b, c, a, c, d]))
	var a := Vector3(-10, 10 * grade, -0.05)
	var b := Vector3(10, -10 * grade, -0.05)
	var c := Vector3(10, -10 * grade, 0.05)
	var d := Vector3(-10, 10 * grade, 0.05)
	sp.add_faces(xf * PackedVector3Array([a, b, c, a, c, d]))
	a = Vector3(10, -10 * grade, -5)
	b = Vector3(30, -10 * grade, -5)
	c = Vector3(30, -10 * grade, 5)
	d = Vector3(10, -10 * grade, 5)
	sp.add_faces(xf * PackedVector3Array([a, b, c, a, c, d]))


## Observe the actual facet bearings at the foot, independently of the controller's verdict.
func _skew_contacts(sp: RefCounted, feet: Vector3) -> bool:
	if not sp._test(Transform3D(Basis(), feet), Vector3.DOWN * 0.06):
		return false
	var res: PhysicsTestMotionResult3D = sp._res
	for i in res.get_collision_count():
		var n := res.get_collision_normal(i)
		for j in range(i + 1, res.get_collision_count()):
			var other := res.get_collision_normal(j)
			var dot_xz := Vector2(n.x, n.z).normalized().dot(Vector2(other.x, other.z).normalized())
			if dot_xz >= -0.9999 and dot_xz < -0.5:
				return true
	return false


func _channel_trial(sp: RefCounted, axis: Vector3, faceted: bool = false) -> Dictionary:
	var feet := Vector3(0, 2, 0)
	sp.place(feet)
	sp.rest()
	var lands := 0
	var mode := ""
	for tick in 180:
		var r: Dictionary = sp.drive(feet, Vector3.ZERO, false, false)
		feet = r.pos
		mode = r.mode
		lands += int(r.events.has("land"))
	var settled := mode
	var changes := 0
	var ground_ticks := 0
	var skew_ticks := 0
	for tick in 120:
		var r: Dictionary = sp.drive(feet, axis * 4.5, false, false)
		feet = r.pos
		changes += int(r.mode != mode)
		mode = r.mode
		ground_ticks += int(r.grounded and mode == "ground")
		if faceted and _skew_contacts(sp, feet):
			skew_ticks += 1
		lands += int(r.events.has("land"))
	var walk_x := feet.dot(axis)
	var takeoff := feet.y
	var peak := takeoff
	var jumped := false
	for tick in 90:
		var r: Dictionary = sp.drive(feet, axis * 4.5, tick == 0, false)
		feet = r.pos
		mode = r.mode
		peak = maxf(peak, feet.y)
		jumped = jumped or r.events.has("jump")
	var escaped := feet.dot(axis) > 12 and absf(feet.y) < 0.04 and mode == "ground"
	var ok := settled == "ground" and lands == 1 and changes == 0 and ground_ticks == 120 and walk_x > 8 and jumped and peak > takeoff + 0.8 and escaped
	var figures := "settled=%s lands=%d walk_ground=%d/120 changes=%d x=%.2f jump=%s rise=%.2f exit=%s" % [settled, lands, ground_ticks, changes, walk_x, jumped, peak - takeoff, escaped]
	if faceted:
		ok = ok and skew_ticks > 0
		figures += " skew_contacts=%d/120" % skew_ticks
	sp.free_all()
	return {"ok": ok, "figures": figures}


func _v_wedge() -> void:
	var ok := true
	var figures := []
	for deg: float in [62.0, 75.0]:
		var sp := Space.new()
		channel(sp, deg)
		var trial := _channel_trial(sp, Vector3.RIGHT)
		ok = ok and trial.ok
		figures.append("%ddeg %s" % [deg, trial.figures])
	# Two steep walls also meet in a draining crease. Gravity alone must still carry him down it.
	for grade: float in [0.15, 0.05]:
		var crease := Space.new()
		channel(crease, 62, grade)
		var feet := Vector3(0, 2, 0)
		crease.place(feet)
		crease.rest()
		var grounded_inside := 0
		for tick in 300:
			var r := crease.drive(feet, Vector3.ZERO, false, false)
			feet = r.pos
			grounded_inside += int(feet.x < 9.5 and r.grounded)
		ok = ok and grounded_inside == 0 and feet.x > 10
		figures.append("%d%% grade ground_inside=%d exit_x=%.2f" % [roundi(100 * grade), grounded_inside, feet.x])
		crease.free_all()
	_say("walk.v_wedge", ok, figures)


## One concave mesh with shared vertices. The floor strip tapers to a shared edge
## at x=-1..1, then opens again. The wall pitch and bearing change across triangles.
func _terrain_channel(sp: RefCounted) -> void:
	var faces := PackedVector3Array()
	var previous := PackedVector3Array()
	for x in range(-10, 11):
		var mid := 0.025 * sin(x * 0.8)
		var half := 0.0 if absi(x) <= 1 else 0.035 + 0.025 * cos(x * 0.9)
		var row := PackedVector3Array([
			Vector3(x, 4.0 + 0.12 * sin(x), mid - 2.0), Vector3(x, 0, mid - half),
			Vector3(x, 0, mid + half), Vector3(x, 4.0 + 0.12 * cos(x), mid + 2.0)])
		if not previous.is_empty():
			for k in 3:
				if row[k] != row[k + 1]:
					faces.append_array(PackedVector3Array([previous[k], row[k], row[k + 1]]))
				if previous[k] != previous[k + 1]:
					faces.append_array(PackedVector3Array([previous[k], row[k + 1], previous[k + 1]]))
		previous = row
	sp.add_faces(faces)
	Walk.flat(sp, 0, 10, 30, -5, 5)


func _channel_variant(name: String) -> void:
	var sp := Space.new()
	var yaw := 0.0
	match name:
		"walk.v_asymmetric":
			channel(sp, 62, 0, 75)
		"walk.v_yaw":
			yaw = deg_to_rad(30)
			channel(sp, 62, 0, 62, yaw)
		"walk.v_terrain":
			_terrain_channel(sp)
	var trial := _channel_trial(sp, Vector3.RIGHT.rotated(Vector3.UP, yaw), name == "walk.v_terrain")
	_say(name, trial.ok, [trial.figures])


func _single_face() -> void:
	var sp := Space.new()
	Walk.bank(sp, 62)
	var feet := Vector3(0, 2, 0)
	sp.place(feet)
	sp.rest()
	var slope_ticks := 0
	var ground_ticks := 0
	for tick in 90:
		var r := sp.drive(feet, Vector3.ZERO, false, false)
		feet = r.pos
		slope_ticks += int(r.mode == "slope")
		ground_ticks += int(r.grounded)
	var ok := slope_ticks > 45 and ground_ticks == 0 and feet.z > 2 and feet.y < -4
	_say("walk.single_face", ok, ["62deg slope=%d ground=%d downhill=%.2f y=%.2f" % [slope_ticks, ground_ticks, feet.z, feet.y]])
	sp.free_all()


func _step_edge() -> void:
	var sp := Space.new()
	sp.add_box(Transform3D(Basis(), Vector3(0, 0.3, -5)), Vector3(10, 0.6, 10))
	Walk.flat(sp, 0, -5, 5, -10, 10)
	var feet := Vector3(0, 0.6, -1)
	sp.place(feet)
	sp.rest()
	var air := 0
	var lands := 0
	var slopes := 0
	var biggest_drop := 0.0
	var mode := ""
	for tick in 60:
		var r := sp.drive(feet, Vector3.BACK * 4.5, false, false)
		biggest_drop = maxf(biggest_drop, feet.y - r.pos.y)
		feet = r.pos
		mode = r.mode
		air += int(mode == "air")
		lands += int(r.events.has("land"))
		slopes += int(mode == "slope")
	var ok := air >= 4 and lands == 1 and slopes == 0 and biggest_drop < 0.2 and feet.z > 2 and absf(feet.y) < 0.03 and mode == "ground"
	_say("walk.step_edge", ok, ["0.60m air=%d lands=%d slope=%d max_drop=%.3f end=%s y=%.3f" % [air, lands, slopes, biggest_drop, mode, feet.y]])
	sp.free_all()


## A walkable pitched floor meets the round foot off centre. With a low roof the raised capsule cannot fit.
func _pitched_pad(roof: bool) -> float:
	var sp := Space.new()
	sp.tag = "pad 0"
	Walk.flat(sp, 0, -5, 5, -5, 5)
	sp.place(Vector3.ZERO)
	sp.rest()
	var before := sp.drive(Vector3.ZERO, Vector3.ZERO, false, false)
	sp.tag = "game"
	var a := Vector3(-5, -2.3, -5)
	var b := Vector3(5, 2.7, -5)
	var c := Vector3(5, 2.7, 5)
	var d := Vector3(-5, -2.3, 5)
	sp.add_faces(PackedVector3Array([a, b, c, a, c, d]))
	if roof:
		sp.add_box(Transform3D(Basis(), Vector3(0, 2.0, 0)), Vector3(8, 0.2, 8))
	sp.remove_tag("pad 0")
	var r := sp.drive(before.pos, Vector3.ZERO, false, false)
	sp.free_all()
	return r.pos.y


func _pad_swap() -> void:
	var ok := true
	var figures := []
	for shape: String in ["faces", "box"]:
		for top: float in [0.2, 0.4, 0.55, 0.65]:
			var sp := Space.new()
			sp.tag = "pad 0"
			Walk.flat(sp, 0, -10, 10, -10, 10)
			var feet := Vector3.ZERO
			sp.place(feet)
			sp.rest()
			var before := sp.drive(feet, Vector3.ZERO, false, false)
			feet = before.pos
			sp.tag = "game"
			if shape == "faces":
				Walk.flat(sp, top, -10, 10, -10, 10)
			else:
				sp.add_box(Transform3D(Basis(), Vector3(0, top - 1, 0)), Vector3(20, 2, 20))
			var removed := sp.remove_tag("pad 0")
			ok = ok and removed == 1 and before.grounded and absf(feet.y) < 0.001
			var low := top <= sp.step_up
			var idle_overlap := 0
			var first_y := 0.0
			var last_idle := 0.0
			for tick in 90:
				var wish := Vector3.ZERO if tick < 60 else Vector3.RIGHT * 4.5
				var r := sp.drive(feet, wish, false, false)
				feet = r.pos
				# Both fixtures cover the whole path. Their exact vertical intersection with the capsule
				# is known independently of the motion solver (strict penetration, not mere contact).
				var bottom := top if shape == "faces" else top - 2.0
				var overlap := feet.y < top - 0.00001 and feet.y + sp.HEIGHT > bottom + 0.00001
				print("PAD %s +%.2f tick=%d feet_y=%.5f overlap=%s mode=%s" % [shape, top, tick + 1, feet.y, overlap, r.mode])
				if tick == 0:
					first_y = feet.y
				if tick < 60:
					last_idle = feet.y
					idle_overlap += int(overlap)
				if low:
					ok = ok and not overlap and absf(feet.y - top) <= 0.03 and r.grounded
				elif tick < 60:
					ok = ok and feet.y <= 0.001
			ok = ok and (not low or feet.x > 1.5)
			figures.append("%s+%.2f first=%.3f idle60=%.3f overlaps=%d/60 walk90=%.3f" % [shape, top, first_y, last_idle, idle_overlap, feet.y])
			sp.free_all()
	var pitched := _pitched_pad(false)
	var roof := _pitched_pad(true)
	var tangent_y := 0.2 + Space.RADIUS * (sqrt(1.25) - 1.0)
	ok = ok and pitched >= tangent_y - 0.001 and pitched < tangent_y + 0.03 and is_zero_approx(roof)
	figures.append("pitched=%.3f roof=%.3f" % [pitched, roof])
	_say("walk.pad_swap", ok, figures)
