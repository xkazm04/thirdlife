extends SceneTree
## Lane flight (19 Nov 2026): the wings' own case (selftest block 530). Headless, counted in ticks.
##   godot --headless --path engine --script res://kernel/world/flight_wings_case.gd
## Prints one line `WINGSCASE ok=<bool> ...` with: the asset's parts and triangles, the ticks the unfold and the fold
## take, the largest per-tick move of a wing tip while unfolding (no pop), the folded bundle's box in the rig's space
## (behind his back, inside his width) and the spread span, and whether two runs pose the same.

const Wings: GDScript = preload("res://kernel/world/flight_wings.gd")


func _tip(w: RefCounted, s: String) -> Vector3:
	var fore: Node3D = ((w.get("_parts") as Dictionary)[s] as Dictionary)["fore"]
	var m: float = 1.0 if s == "r" else -1.0
	return fore.global_transform * Vector3(0.80 * m, -0.08, 0.02)


## The box of every wing mesh vertex in the rig's space.
func _box(w: RefCounted, rig: Node3D) -> AABB:
	var inv: Transform3D = rig.global_transform.affine_inverse()
	var box: AABB = AABB()
	var first: bool = true
	for mi: Node in (w.get("root") as Node3D).find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		var xf: Transform3D = inv * (mi as MeshInstance3D).global_transform
		for si: int in mesh.get_surface_count():
			var vs: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in vs:
				var p: Vector3 = xf * v
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
	return box


func _run(log: Array) -> Dictionary:
	var rig: Node3D = TLRigs.build("biped", {})
	root.add_child(rig)
	rig.call("tick", 1)
	var w: RefCounted = Wings.attach(rig)
	if w == null:
		return {"error": "no wings"}
	var r: Dictionary = {"parts": ((w.get("root") as Node3D).get_meta(&"tl_parts", []) as PackedStringArray).size(),
		"tris": int((w.get("root") as Node3D).get_meta(&"tl_tris", 0))}
	r["folded"] = _box(w, rig)
	var unfold: int = -1
	var step: float = 0.0
	var last: Vector3 = _tip(w, "r")
	for t: int in range(1, 61):
		w.call("tick", true, 0.0, 0.0, t)
		var p: Vector3 = _tip(w, "r")
		step = maxf(step, p.distance_to(last))
		last = p
		log.append(p)
		if unfold < 0 and float(w.get("k")) >= 1.0:
			unfold = t
	r["unfold"] = unfold
	r["step"] = step
	w.set("flap_t", 0.0)
	w.call("_pose", 0.0, 1.0)
	var sp: AABB = _box(w, rig)
	r["span"] = sp.size.x
	var fold: int = -1
	for t: int in range(1, 61):
		w.call("tick", false, 0.0, 0.0, 100 + t)
		log.append(_tip(w, "r"))
		if fold < 0 and float(w.get("k")) <= 0.0:
			fold = t
	r["fold"] = fold
	rig.queue_free()
	return r


var _frames: int = 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_case()
	return false


func _case() -> void:
	var a: Array = []
	var b: Array = []
	var r: Dictionary = _run(a)
	var r2: Dictionary = _run(b)
	if r.has("error"):
		print("WINGSCASE ok=false error=%s" % r["error"])
		quit(1)
		return
	var same: bool = a == b
	var fb: AABB = r["folded"]
	# folded: behind the back (the rig faces -Z: behind is +Z; the backpack's back face is about z = 0.34), no wider
	# than his shoulders, from the hips up to below the top of his head (2.0 m)
	var tidy: bool = fb.position.z >= 0.30 and absf(fb.position.x) <= 0.55 and fb.end.x <= 0.55 and fb.position.y >= 0.55 and fb.end.y <= 1.95
	var ok: bool = int(r["parts"]) == 17 and int(r["tris"]) <= 2000 and int(r["unfold"]) == 30 and int(r["fold"]) == 36 \
		and float(r["step"]) <= 0.20 and float(r["span"]) >= 3.5 and tidy and same
	print("WINGSCASE ok=%s parts=%d tris=%d unfold_ticks=%d fold_ticks=%d tip_step_max_m=%.3f span_m=%.2f folded_box=[%.2f,%.2f,%.2f]..[%.2f,%.2f,%.2f] tidy=%s same=%s" % [
		ok, int(r["parts"]), int(r["tris"]), int(r["unfold"]), int(r["fold"]), float(r["step"]), float(r["span"]),
		fb.position.x, fb.position.y, fb.position.z, fb.end.x, fb.end.y, fb.end.z, tidy, same])
	quit(0 if ok else 1)
