extends SceneTree
## Hash the exact float positions at every tick, including jumps, slides and direction changes.
const FRAMES := 600

func _initialize() -> void:
	physics_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1000, 2, 1000)
	shape.shape = box
	shape.position.y = -1
	floor_body.add_child(shape)
	root.add_child(floor_body)
	var walker := TLBiped.create({"feel": "walker"})
	root.add_child(walker)
	walker.set_physics_process(false)
	await physics_frame
	var positions := PackedVector3Array()
	for tick in FRAMES:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, (tick / 120) * PI / 2)
		walker.move(dir, tick % 110 < 88)
		if tick % 151 == 35:
			walker.jump()
		if tick % 151 == 100:
			walker.slide()
		walker._physics_process(1.0 / 60.0)
		positions.append(walker.global_position)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(positions.to_byte_array())
	var hash_text := digest.finish().hex_encode()
	walker.place(Vector3.ZERO)
	var run := _travel(walker)
	if not walker.has_method("fly"):
		print("FLIGHT biped FAIL frames=%d sha256=%s run=%.3f fly=missing" % [positions.size(), hash_text, run])
		quit(1)
		return
	walker.place(Vector3.ZERO)
	walker.call("fly", true)
	for tick in 90:
		walker.move(Vector3.ZERO)
		walker.call("climb", 1.0)
		walker._physics_process(1.0 / 60.0)
	var raised := walker.position.y
	var cruise := _travel(walker)
	var ratio := cruise / run
	var ok: bool = hash_text == "896a9c9dfce48bd87e10a7dd393e3a8d6c7bcc5f6dd4f1fbd85bde3dd29ff214" and raised > 10 and walker.call("is_flying") and absf(ratio - 5) <= 0.1
	var mapping := _mapped_controls()
	ok = ok and mapping
	print("FLIGHT biped %s frames=%d sha256=%s run=%.3f cruise=%.3f ratio=%.3f climb_m=%.3f mapped_controls=%s" % ["PASS" if ok else "FAIL", positions.size(), hash_text, run, cruise, ratio, raised, mapping])
	quit(0 if ok else 1)

func _mapped_controls() -> bool:
	var walker := TLBiped.create({"feel": "walker", "fly_scale": 2.0})
	root.add_child(walker)
	var input := TLInput.new()
	var actions := {}
	for key: String in ["forward", "back", "left", "right", "fly", "climb", "descend"]:
		actions[key] = StringName(key)
		input.declare(actions[key], [])
	input.tap(&"fly")
	input.press(&"climb")
	input.press(&"forward")
	var ok := true
	for tick in 480:
		if tick == 160:
			ok = walker.walker_motion() == &"fly" and is_equal_approx(walker.speed(), 18) and walker.velocity.y > 8.9
			input.release_all()
			input.press(&"left")
			input.press(&"descend")
		if tick == 180:
			ok = ok and walker.velocity.y < 0
			input.release(&"descend")
		if tick == 320:
			ok = ok and is_equal_approx(walker.speed(), 9) and walker.velocity.x < -8.9
			input.release_all()
			input.press(&"back")
		input._sample()
		walker.drive_from_input(input, actions)
		walker._physics_process(1.0 / 60.0)
	ok = ok and walker.velocity.z > 8.9 and walker.velocity.y == 0
	input.tap(&"fly")
	input._sample()
	walker.drive_from_input(input, actions)
	walker._physics_process(1.0 / 60.0)
	ok = ok and walker.walker_motion() == &"air"
	input.free()
	walker.free()
	return ok

func _travel(walker: TLBiped) -> float:
	var start := Vector3.ZERO
	for tick in 240:
		if tick == 180:
			start = walker.position
		walker.move(Vector3.FORWARD, true)
		walker._physics_process(1.0 / 60.0)
	return start.z - walker.position.z
