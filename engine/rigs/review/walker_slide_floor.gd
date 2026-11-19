extends SceneTree
## Lane walker (night of 19 Nov 2026): the held run slide keeps every drawn vertex of the biped at or above the floor
## (the rig's root stands on y = 0). Before: the folded left leg sank 0.151 m into the floor (bugfix-37 new finding).
## Prints `RIGCASE slide_floor ok|fail <lowest> <bone>` for the held pose (frames 30..120, every 6th). The entry blend
## (the first ~12 frames) is not judged: a crossfade from the run is reported in the lane report, not here.
## Run: godot --headless --path engine --script res://rigs/review/walker_slide_floor.gd

const FLOOR_TOL: float = 0.02       # metres a vertex may sit under the floor (the idle foot sits at -0.011)


func _initialize() -> void:
	_run.call_deferred()


func _lowest(sk: Skeleton3D, geometry: TLMesh) -> Array:
	var lo: float = INF
	var at: String = ""
	for surface: Variant in geometry.surfs.values():
		for i: int in surface.v.size():
			var b: int = surface.b[4 * i]
			var skin: Transform3D = sk.get_bone_global_pose(b) * sk.get_bone_global_rest(b).affine_inverse()
			var y: float = (skin * Vector3(surface.v[i])).y
			if y < lo:
				lo = y
				at = sk.get_bone_name(b)
	return [lo, at]


func _run() -> void:
	var rig: Node = TLRigs.build("biped")
	root.add_child(rig)
	rig.call("play", &"slide")
	var worst: float = INF
	var worst_at: String = ""
	for f: int in range(1, 121):
		rig.call("tick", f)
		if f < 30 or f % 6 != 0:
			continue
		var sk: Skeleton3D = rig.get_node("Model/Skeleton3D")
		var lo: Array = _lowest(sk, TLRigBipedMesh.build_mesh(sk, TLRigBipedMesh.LOOK, true, false))
		if float(lo[0]) < worst:
			worst = float(lo[0])
			worst_at = "%s@f%d" % [lo[1], f]
	var ok: bool = worst >= -FLOOR_TOL
	print("RIGCASE slide_floor %s lowest=%.3f m at %s (tolerance -%.2f)" % ["ok" if ok else "fail", worst, worst_at, FLOOR_TOL])
	rig.free()
	quit()
