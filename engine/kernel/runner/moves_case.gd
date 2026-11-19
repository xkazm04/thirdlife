extends SceneTree
## Exact, independent geometry in the visitor's private PhysicsServer space.
const Space = preload("res://kernel/world/terrain/world_space.gd")
const WALL := Vector3(0, 1.0, 0.40)
const BAR := Vector3(10, 6, 0)
const DT := 1.0 / 60
var sp := Space.new()
var feet := Vector3.ZERO
var failed := false

func _initialize() -> void:
	physics_frame.connect(_run, CONNECT_ONE_SHOT)

func _line(label: String, ok: bool, detail: String) -> void:
	print("MOVES %s %s %s" % [label, "PASS" if ok else "FAIL", detail])
	failed = failed or not ok

func _box(center: Vector3, size: Vector3) -> void:
	sp.add_box(Transform3D(Basis.IDENTITY, center), size)

func _add_bar(at: Vector3, sliced: bool) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var body := StaticBody3D.new()
	holder.add_child(body)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.06
	cylinder.height = 3
	shape.shape = cylinder
	shape.rotation.z = -PI / 2
	body.add_child(shape)
	body.set_meta(&"tl_bar", true)
	var plot := Transform3D(Basis.IDENTITY, at)
	if sliced:
		var job := sp.begin_pack(holder, plot, 10, 0, 0)
		while not sp.step_pack(job, 50):
			pass
	else:
		sp.add_pack(holder, plot, 10, 0, 0)
	holder.free()

func _start(pos: Vector3, airborne := false, vel := Vector3.ZERO) -> void:
	feet = pos
	sp.place(pos)
	sp.rest()
	if airborne:
		sp._mover.mode = "air"
		sp._mover.grounded = false
		sp._mover.vel = vel

func _tick(wish := Vector3.ZERO, jump := false, slide := false, fly := false) -> Dictionary:
	var r := sp.drive(feet, wish, jump, slide, fly)
	feet = r.pos
	return r

func _hang(height := 2.4, x := 0.0) -> bool:
	_start(Vector3(x, 3.4 - height, WALL.z), true)
	return _tick(Vector3.FORWARD).events.has("hang")

func _overlap() -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = Space.RADIUS
	shape.height = Space.HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = feet + Vector3.UP * Space.HEIGHT / 2
	query.exclude = [sp.body]
	query.collision_mask = 1
	return not PhysicsServer3D.space_get_direct_state(sp.space).intersect_shape(query, 1).is_empty()

func _ledge_reach() -> void:
	var catches := []
	for height in [1.99, 2.0, 2.01, 2.79, 2.8, 2.81]:
		catches.append(_hang(height))
	var no_room := not _hang(2.4, 2.0)
	_start(Vector3(-2, 1.0, 1.2))
	# A raised floor supports the same 2.4 m approach for all 90 grounded ticks.
	var ground_ok := true
	for t in 90:
		ground_ok = _tick(Vector3.FORWARD * 4.5).mode == "ground" and ground_ok
	_line("ledge_reach", catches == [false,true,true,true,true,false] and no_room and ground_ok,
		"height_m=[1.99,2.00,2.01,2.79,2.80,2.81] catches=%s no_room_refused=%s grounded_90=%s" % [catches,no_room,ground_ok])

func _mantle() -> void:
	var caught := _hang()
	var start := feet
	var ended := -1
	var overlaps := int(_overlap())
	var states := caught
	for t in 28:
		var row := _tick(Vector3.ZERO, t == 0)
		if row.events.has("end_mantle"):
			ended = t + 1
		if t == 0:
			states = states and row.events.has("mantle")
		states = states and row.mode == ("ground" if t == 27 else "mantle")
		overlaps += int(_overlap())
	var gain := feet.y - start.y
	var end_mode: String = sp._mover.mode
	var landed: bool = feet.z < 0 and absf(feet.y - 3.4) < 0.01 and _tick().grounded
	# Add an obstacle after the catch. A blocked step must stay at its previous safe feet.
	var interrupted := false
	if _hang():
		_tick(Vector3.ZERO, true)
		sp.tag = "obstruction"
		_box(Vector3(0, start.y + 2.25, WALL.z), Vector3(1, 0.2, 0.6))
		for t in 27:
			var last := feet
			var row := _tick()
			if row.blocked:
				interrupted = row.mode == "air" and feet == last and not _overlap() and row.events.has("end_mantle")
				break
		sp.remove_tag("obstruction")
		sp.tag = ""
	_line("mantle", states and ended == 28 and overlaps == 0 and landed and absf(gain - 1.6) < 0.01 and interrupted,
		"ticks=%d gain_m=%.6f overlaps=%d end=%s blocked_safe=%s" % [ended,gain,overlaps,end_mode,interrupted])

func _drop() -> void:
	var ok := _hang()
	var hung_y := feet.y
	var row := _tick(Vector3.ZERO, false, true)
	ok = ok and row.events.has("drop") and row.mode == "air" and absf(row.vel.z - 1.0) < 0.00001
	var landed := -1
	for t in 90:
		if _tick().mode == "ground":
			landed = t + 1
			break
	var below := feet.y < hung_y - 0.5
	# A second release challenges the cooldown at a catchable height on every tick.
	var regrab := -1
	if _hang():
		_tick(Vector3.BACK)
		for t in 21:
			feet = WALL
			if _tick(Vector3.FORWARD).events.has("hang"):
				regrab = t + 1
				break
	_line("drop", ok and landed > 0 and below and regrab == 21,
		"push_mps=%.3f landed_tick=%d below=%s first_regrab_tick=%d" % [row.vel.z,landed,below,regrab])

func _catch_bar(speed := 0.0) -> bool:
	_start(BAR - Vector3.UP * 2.2, true, Vector3.FORWARD * speed)
	return _tick().events.has("bar")

func _bar_catch() -> void:
	# The low rail matches the upward hands height after the first jump tick.
	var hits := []
	for offset in [0.35, 0.36]:
		_start(Vector3(20, 0, offset))
		var jumped: bool = _tick(Vector3.ZERO, true).events.has("jump")
		hits.append(jumped and _tick().events.has("bar"))
	_start(Vector3(20, 0, 1))
	var ground_ok := true
	for t in 35:
		ground_ok = _tick(Vector3.FORWARD * 4.5).mode == "ground" and ground_ok
	_start(BAR + Vector3.RIGHT * 2 - Vector3.UP * 2.2, true)
	var finite: bool = _tick().mode == "air"
	_line("bar_catch", hits == [true,false] and ground_ok and finite,
		"jump_0.35/0.36=%s grounded_walk=%s outside_end_refused=%s" % [hits,ground_ok,finite])

func _bar_swing() -> void:
	var caught := _catch_bar(0.22)
	var expected := TAU * sqrt(1.1 / 24)
	var previous := 0.0
	var crossings := []
	var ratio := 0.0
	var stuck := false
	if caught:
		for t in range(1, 361):
			stuck = _tick().blocked or stuck
			var angle: float = sp._mover.bar_theta
			if previous <= 0 and angle > 0:
				crossings.append((t - 1 + absf(previous) / (angle - previous)) * DT)
			previous = angle
		var amplitude_v := Vector2(sp._mover.bar_omega, sqrt(24 / 1.1) * previous).length()
		ratio = amplitude_v / (0.22 / 1.1)
	var period := 0.0
	if crossings.size() >= 3:
		period = (crossings.back() - crossings.front()) / (crossings.size() - 1)
	var pump_tick := -1
	if _catch_bar():
		for t in 240:
			var direction := Vector3.FORWARD if sp._mover.bar_omega >= 0 else Vector3.BACK
			_tick(direction * 4.5)
			if absf(sp._mover.bar_theta) >= PI / 6:
				pump_tick = t + 1
				break
	# A side wall blocks the vertical capsule as it starts to swing forward.
	var stopped := false
	if _catch_bar(2.5):
		sp.tag = "swing wall"
		_box(feet + Vector3(0, 1, -0.63), Vector3(3, 2, 0.2))
		for t in 30:
			var last := feet
			if _tick().blocked:
				stopped = feet == last and sp._mover.bar_omega == 0 and not _overlap()
				break
		sp.remove_tag("swing wall")
		sp.tag = ""
	_line("bar_swing", stopped and not stuck and absf(period / expected - 1) <= 0.02 and absf(ratio - 0.5) < 0.02 and pump_tick > 0,
		"period_s=%.6f theoretical_s=%.6f crossings=%d amplitude_after_360=%.5f pump_30deg_tick=%d wall_stopped=%s" % [period,expected,crossings.size(),ratio,pump_tick,stopped])

func _release_run(jump: bool) -> Dictionary:
	var trace := PackedVector3Array()
	if not _catch_bar(2.5):
		return {"trace": trace.to_byte_array(), "err": INF, "regrab": -1}
	for t in 18:
		_tick(Vector3.FORWARD * 4.5)
		trace.append(feet)
	var angle: float = sp._mover.bar_theta
	var rate: float = sp._mover.bar_omega
	var axis: Vector3 = sp._mover.bar_axis
	var tangent := axis.cross(Vector3.DOWN.rotated(axis, angle)).normalized()
	var want := tangent * (rate * 1.1) + Vector3.UP * (2 if jump else 0)
	var release := _tick(Vector3.ZERO, jump, not jump)
	var err: float = release.vel.distance_to(want) if release.mode == "air" and release.events.has("release" if jump else "drop") else INF
	for t in 60:
		_tick()
		trace.append(feet)
	var regrab := -1
	if _catch_bar():
		_tick(Vector3.ZERO, jump, not jump)
		for t in 21:
			feet = BAR - Vector3.UP * 2.2
			if _tick().mode == "bar":
				regrab = t + 1
				break
	return {"trace": trace.to_byte_array(), "err": err, "regrab": regrab}

func _bar_release() -> void:
	var first := _release_run(true)
	var again := _release_run(true)
	var drop := _release_run(false)
	var same: bool = first.trace.size() == 78 * 12 and first.trace == again.trace
	_line("bar_release", same and first.err <= 1e-6 and drop.err <= 1e-6 and first.regrab == 21 and drop.regrab == 21,
		"hop_error_mps=%.9f drop_error_mps=%.9f identical_bytes=%d first_regrab_tick=%d" % [first.err,drop.err,first.trace.size() if same else 0,first.regrab])

func _flight() -> void:
	_start(WALL, true)
	var wall: bool = _tick(Vector3.FORWARD, false, false, true).mode == "fly"
	_start(BAR - Vector3.UP * 2.2, true)
	var rail: bool = _tick(Vector3.ZERO, false, false, true).mode == "fly"
	_line("flight_unchanged", wall and rail and _catch_bar() and _hang(), "in_range_fly_wall/bar=%s/%s" % [wall,rail])

func _run() -> void:
	_box(Vector3(0,-1,0),Vector3(100,2,100))
	_box(Vector3(-2,0.5,1.5),Vector3(1.5,1,3))
	_box(Vector3(0,1.7,-1.5),Vector3(6,3.4,3))
	_box(Vector3(2,4.6,-1),Vector3(1.2,0.15,2))
	_add_bar(BAR, false)
	_add_bar(Vector3(20,2.2 + (6.93 - 24 * DT) * DT,0), true)
	sp.finish()
	_ledge_reach()
	_mantle()
	_drop()
	_bar_catch()
	_bar_swing()
	_bar_release()
	_flight()
	sp.free_all()
	quit(1 if failed else 0)
