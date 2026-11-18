extends SceneTree
## Lane M, 18 Nov: the BEFORE figures of the old walk() (no velocity): idle on a bank, a ledge. Headless, one line each.
##   <godot> --headless --path engine --script res://kernel/world/walks/walk_before.gd

const Space: GDScript = preload("res://kernel/world/terrain/world_space.gd")


func _plane(sp: RefCounted, deg: float) -> void:
	# a plane through the origin rising toward -z at `deg`, 60 m square
	var t: float = tan(deg_to_rad(deg))
	var a: Vector3 = Vector3(-30, -30.0 * t * -1.0, 30)
	var f: PackedVector3Array = PackedVector3Array()
	var p: Array = [Vector3(-30, -30.0 * t, 30), Vector3(30, -30.0 * t, 30), Vector3(30, 30.0 * t, -30), Vector3(-30, 30.0 * t, -30)]
	f.append_array(PackedVector3Array([p[0], p[1], p[2], p[0], p[2], p[3]]))
	sp.call("add_faces", f)


func _initialize() -> void:
	for deg: float in [20.0, 35.0, 50.0]:
		var sp: RefCounted = Space.new()
		_plane(sp, deg)
		var g: float = sp.call("ground_at", 0.0, 0.0, 50.0)
		var feet: Vector3 = Vector3(0.0, g, 0.0)
		sp.call("place", feet)
		var start: Vector3 = feet
		for i: int in 600:
			feet = (sp.call("walk", feet, Vector3.ZERO) as Dictionary)["pos"]
		print("BEFORE idle bank %d deg: drift %.4f m (start %s end %s)" % [int(deg), feet.distance_to(start), start, feet])
		sp.call("free_all")
	# a ledge: flat at y 3 for z < 0, flat at y 0 for z > 0
	var s2: RefCounted = Space.new()
	var f2: PackedVector3Array = PackedVector3Array([Vector3(-20, 3, -20), Vector3(20, 3, -20), Vector3(20, 3, 0), Vector3(-20, 3, -20), Vector3(20, 3, 0), Vector3(-20, 3, 0),
		Vector3(-20, 0, 0), Vector3(20, 0, 0), Vector3(20, 0, 20), Vector3(-20, 0, 0), Vector3(20, 0, 20), Vector3(-20, 0, 20),
		Vector3(-20, 3, 0), Vector3(20, 3, 0), Vector3(20, 0, 0), Vector3(-20, 3, 0), Vector3(20, 0, 0), Vector3(-20, 0, 0)])
	s2.call("add_faces", f2)
	var p: Vector3 = Vector3(0, 3, -1.0)
	s2.call("place", p)
	var ys: Array = []
	for i: int in 30:
		p = (s2.call("walk", p, Vector3(0, 0, 4.5 / 60.0)) as Dictionary)["pos"]
		ys.append(snappedf(p.y, 0.01))
	print("BEFORE ledge 3 m, walking off at 4.5 m/s, feet y per tick: %s" % [ys])
	s2.call("free_all")
	quit(0)
