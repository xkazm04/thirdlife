extends SceneTree
## Run the same two approaches with each controller. Hash the raw Vector3 bytes of all 600 steps.
const BASELINE := "1c2a24d2e3af1bdff8f2a852a4b2b1c917230fd52a8416a46a9ae08c6d2ecf1d"

func _initialize() -> void:
	physics_frame.connect(_run, CONNECT_ONE_SHOT)

func _static(shape: Shape3D, at: Vector3, basis := Basis.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(basis, at)
	body.add_child(cs)
	root.add_child(body)
	return body

func _course(moves: Array) -> Dictionary:
	var options := {"feel": &"walker"}
	if not moves.is_empty():
		options["moves"] = moves
	var walker := TLBiped.create(options)
	root.add_child(walker)
	walker.set_physics_process(false)
	var positions := PackedVector3Array()
	var hang := false
	var bar := false
	for tick in 600:
		if tick == 0 or tick == 300:
			walker.place(Vector3(0 if tick == 0 else 10, 0.01, 1.0))
		var phase := tick % 300
		if phase == 8:
			walker.jump()
		walker.move(Vector3.FORWARD if phase < 45 else Vector3.ZERO)
		walker._physics_process(1.0 / 60.0)
		hang = hang or walker.walker_motion() == &"hang"
		bar = bar or walker.walker_motion() == &"bar"
		positions.append(walker.position)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(positions.to_byte_array())
	walker.free()
	return {"hash": digest.finish().hex_encode(), "hang": hang, "bar": bar, "frames": positions.size()}

func _run() -> void:
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(100, 2, 100)
	_static(floor_shape, Vector3.DOWN)
	var wall := BoxShape3D.new()
	wall.size = Vector3(4, 3, 3)
	_static(wall, Vector3(0, 1.5, -1.5))
	var cylinder := CylinderShape3D.new()
	cylinder.height = 3
	cylinder.radius = 0.06
	var rail := _static(cylinder, Vector3(10, 3.02, -0.25), Basis(Vector3.BACK, PI / 2))
	var api: Script = load("res://kernel/api/tl_biped.gd")
	if api.has_method("mark_bar"):
		api.call("mark_bar", rail)
	else:
		rail.set_meta(&"tl_bar", true)  # same marked course when measuring the 1.9 baseline
	await physics_frame
	var off := _course([])
	var on := _course([&"ledge", &"bar"])
	var ledge := _course([&"ledge"])
	var bar := _course([&"bar"])
	var independent: bool = ledge.hang and not ledge.bar and bar.bar and not bar.hang
	var ok: bool = independent and api.has_method("mark_bar") and off.frames == 600 and off.hash == BASELINE and not off.hang and not off.bar and on.hang and on.bar
	print("MOVES optin %s frames=%d sha256=%s off_hang/bar=%s/%s on_hang/bar=%s/%s independent=%s" % [
		"PASS" if ok else "FAIL", off.frames, off.hash, off.hang, off.bar, on.hang, on.bar, independent])
	quit(0 if ok else 1)
