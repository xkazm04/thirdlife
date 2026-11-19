extends SceneTree
## Lane flight round 3 (19 Nov 2026): a ledge whose standing-room test meets float noise (selftest block 536). The parkour
## lane's Skyline: a kit ground slab 3.8 x 3.4 x 1.0 m with its top at y = 10.13, 3.05 m over the floor, at x = -22.79;
## the standing-room test of the top found a contact 2.4e-7 m deep (float noise at those coordinates) and refused the
## catch (3.00 m worked). A TLBiped walker (moves ledge) runs at the face and jumps, at five heights. Prints
## `LEDGEFIT ok=<bool> ...`: every ledge from 2.90 to 3.10 m in 0.05 steps is caught and mantled onto. Before the fix
## (walker_grips FIT_TOL) none of the five was caught here: the slab's top read a contact of float-noise depth.

var _frames: int = 0


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		_run()
	return false


func _static(shape: Shape3D, at: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)
	body.global_position = at
	return body


func _try(h: float) -> Dictionary:
	var top_y: float = 10.13
	var floor_y: float = top_y - h
	var made: Array = []
	var fl: BoxShape3D = BoxShape3D.new()
	fl.size = Vector3(40, 1, 40)
	made.append(_static(fl, Vector3(-22.78585, floor_y - 0.5, 10.0)))
	var slab: BoxShape3D = BoxShape3D.new()
	slab.size = Vector3(3.8, 3.4, 1.0)
	made.append(_static(slab, Vector3(-22.78585, top_y - 1.7, 3.900004)))     # its face at z = 4.400004, top at 10.13
	var w: TLBiped = TLBiped.create({"feel": &"walker", "moves": [&"ledge"]})
	root.add_child(w)
	await physics_frame
	w.set_physics_process(false)
	w.place(Vector3(-23.5385, floor_y + 0.01, 6.0))
	var hang: bool = false
	var on_top: bool = false
	var hang_n: int = 0
	for f: int in 240:
		if f == 10:
			w.jump()
		var m: StringName = w.walker_motion()
		if m == &"hang":
			hang = true
			hang_n += 1
			if hang_n == 20:
				w.jump()
		w.move(Vector3.FORWARD if f < 40 and not hang else Vector3.ZERO)
		w._physics_process(1.0 / 60.0)
	on_top = w.walker_motion() == &"ground" and absf(w.global_position.y - top_y) < 0.05
	w.free()
	for n: Node in made:
		n.free()
	return {"hang": hang, "top": on_top}


func _run() -> void:
	await physics_frame
	var res: Array = []
	var ok: bool = true
	for i: int in 5:
		var h: float = 2.90 + 0.05 * float(i)
		var r: Dictionary = await _try(h)
		res.append("%.2f:%s/%s" % [h, "hang" if r["hang"] else "-", "top" if r["top"] else "-"])
		ok = ok and bool(r["hang"]) and bool(r["top"])
	print("LEDGEFIT ok=%s ledges=[%s]" % [ok, ", ".join(res)])
	quit(0 if ok else 1)
