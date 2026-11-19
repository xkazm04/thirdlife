extends SceneTree
## Coyote time at the ledge, sustained wall contact, and a forced brake during a tapped step.
const Space = preload("res://kernel/world/terrain/world_space.gd")
const Walk = preload("res://kernel/world/walks/walk_case.gd")

var _filter := ""
var _n := 0
var _ok := 0


func _want(name: String) -> bool:
	return _filter.is_empty() or name.contains(_filter)


func _say(name: String, ok: bool, figures: String) -> void:
	_n += 1
	_ok += int(ok)
	print("WALKCASE %s %s %s" % [name, "ok" if ok else "fail", figures])


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_filter = args[0] if not args.is_empty() else ""
	_run.call_deferred()


func _run() -> void:
	if _want("walk.coyote_limit"):
		_coyote_limit()
	if _want("walk.wall_still"):
		_wall_still()
	if _want("walk.down_brake"):
		await _down_brake()
	print("WALKCASE done %d %d" % [_ok, _n])
	quit(2 if _n == 0 else (0 if _ok == _n else 1))


func _coyote_limit() -> void:
	var sp := Space.new()
	Walk.flat(sp, 2, -20, 20, -20, 0)
	Walk.flat(sp, 0, -20, 20, 0, 20)
	var jumps: Array[int] = []
	for delay: int in [6, 7]:
		var feet := Vector3(0, 2, -2)
		sp.place(feet)
		sp.rest()
		var left := -1
		for tick in 120:
			var tap := left >= 0 and tick == left + delay
			var r := sp.drive(feet, Vector3.BACK * 4.5, tap, false)
			feet = r.pos
			if left < 0 and r.mode == "air":
				left = tick
			if tap or r.events.has("land"):
				if tap and r.mode == "air" and not r.events.has("land"):
					jumps.append(int(r.events.has("jump")))
				break
	_say("walk.coyote_limit", jumps == [1, 0], "jumps at offsets 6/7 = %s" % [jumps])
	sp.free_all()


func _wall_still() -> void:
	var sp := Space.new()
	Walk.flat(sp, 0, -10, 10, -10, 10)
	sp.add_box(Transform3D(Basis(), Vector3(1, 1.5, 0)), Vector3(2, 3, 12))
	var feet := Vector3(-2, 0, 0)
	sp.place(feet)
	sp.rest()
	var min_x := INF
	var max_x := -INF
	var max_speed := 0.0
	var grounded := 0
	for tick in 90:
		var r := sp.drive(feet, Vector3.RIGHT * 4.5, false, false)
		feet = r.pos
		if tick >= 45:
			min_x = minf(min_x, feet.x)
			max_x = maxf(max_x, feet.x)
			max_speed = maxf(max_speed, r.vel.length())
			grounded += int(r.grounded)
	var at_wall := absf(feet.x + Space.RADIUS) < 0.01
	var contact_z := feet.z
	for tick in 45:
		feet = sp.drive(feet, Vector3(1, 0, 1).normalized() * 4.5, false, false).pos
	var along := feet.z - contact_z
	var ok := at_wall and max_x - min_x < 0.001 and max_speed < 0.01 and grounded == 45
	ok = ok and absf(feet.x + Space.RADIUS) < 0.01 and along > 1.0
	_say("walk.wall_still", ok, "45 ticks x_span=%.5f m peak_speed=%.3f m/s grounded=%d/45 along=%.2f m" % [max_x - min_x, max_speed, grounded, along])
	sp.free_all()


func _down_brake() -> void:
	var floor_body := TLBodies.ground(Vector2(20, 20), "concrete")
	root.add_child(floor_body)
	var walker := TLBiped.create({"feel": &"walker", "position": Vector3(0, 0.01, 0)})
	root.add_child(walker)
	for tick in 10:
		await physics_frame
	walker.move(Vector3.RIGHT, true)
	for tick in 3:
		await physics_frame
	var before := walker.speed()
	var last := before
	var peak := before
	var increases := 0
	walker.move(Vector3.ZERO)
	walker.down(20)
	for tick in 6:
		await physics_frame
		var speed := walker.speed()
		increases += int(speed > last + 0.0001)
		peak = maxf(peak, speed)
		last = speed
	var ok := walker.grounded and walker.is_down() and before > 1.0 and increases == 0 and last < 0.01
	_say("walk.down_brake", ok, "start=%.2f peak=%.2f end=%.2f m/s increases=%d/6" % [before, peak, last, increases])
	walker.free()
	floor_body.free()
