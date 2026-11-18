extends SceneTree
## bugfix-37 lane cam: the chase camera's regression cases (TLChaseCam with and without `avoid_space`). Headless, counted
## in physics ticks (the camera's `_physics_process` is called by hand, as walk_case.gd does). One line per case:
##   CAMCASE <name> ok|fail <figures>
## then `CAMCASE done <ok> <fail>`. Run by engine/tools/selftest.d/310-bugfix-cam.sh; args after `--` pick cases by name.
##   cam.wall_start   D5/Q5: a wall 0.2 m behind the point looked at (inside the cast sphere at its start) stops the camera
##   cam.crown_band   D5/R4: beside a pine, the point looked at swept through the band under the crown: never nearer than
##                    avoid_min, never inside the crown while the point looked at is outside it
##   cam.canopy_jump  D5/P4: a jump with his back to a trunk: the camera is inside the crown only on ticks the point looked
##                    at is inside it too, and never inside the trunk
##   cam.avoid_min    D17: setup() takes `avoid_min`
##   cam.rebase       D18: the parent re-based (as a stage does): the camera casts in the parent's frame
##   cam.snap_heading Q19: snap() after a teleport and turn stands behind the new facing at once
##   cam.reverse      Q20: use_velocity and an exact reversal of travel: the camera comes round behind the travel

const Space: GDScript = preload("res://kernel/world/terrain/world_space.gd")

var _ok: int = 0
var _fail: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _want(name: String) -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		return true
	for a: String in args:
		if name.contains(a):
			return true
	return false


func _say(name: String, ok: bool, figures: String) -> void:
	if ok:
		_ok += 1
	else:
		_fail += 1
	print("CAMCASE %s %s %s" % [name, "ok" if ok else "fail", figures])


func _flat(sp: RefCounted, r: float) -> void:
	sp.call("add_faces", PackedVector3Array([Vector3(-r, 0, -r), Vector3(r, 0, -r), Vector3(r, 0, r), Vector3(-r, 0, -r), Vector3(r, 0, r), Vector3(-r, 0, r)]))


func _inside(sp: RefCounted, at: Vector3, mask: int) -> bool:
	var q: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	q.position = at
	q.collision_mask = mask
	return not PhysicsServer3D.space_get_direct_state(sp.get("space") as RID).intersect_point(q, 1).is_empty()


func _run() -> void:
	if _want("cam.wall_start"):
		_wall_start()
	if _want("cam.crown_band"):
		_crown_band()
	if _want("cam.canopy_jump"):
		_canopy_jump()
	if _want("cam.avoid_min"):
		_avoid_min()
	if _want("cam.rebase"):
		_rebase()
	if _want("cam.snap_heading"):
		_snap_heading()
	if _want("cam.reverse"):
		_reverse()
	print("CAMCASE done %d %d" % [_ok, _fail])
	quit(0 if _fail == 0 else 1)


func _wall_start() -> void:
	var sp: RefCounted = Space.new()
	sp.call("add_box", Transform3D(Basis(), Vector3(0, 2, 5.2)), Vector3(20, 4, 10))     # z 0.2 .. 10.2
	var who: Node3D = Node3D.new()
	root.add_child(who)
	var cam: TLChaseCam = TLChaseCam.new()
	root.add_child(cam)
	cam.setup(who, {"distance": 7.0, "look_height": 1.0, "height": 1.0, "avoid_margin": 0.3, "avoid_space": sp.get("space")})
	var res: Array = []
	for z: float in [-1.0, 0.0, 0.1]:                 # the wall 1.2, 0.2, 0.1 m behind the point looked at
		who.position.z = z
		cam.snap()
		res.append([z, _inside(sp, cam.global_position, 1), cam.global_position.z])
		for i: int in 30:
			cam._physics_process(1.0 / 60.0)
		res.append([z, _inside(sp, cam.global_position, 1), cam.global_position.z])
	var bad: int = 0
	var fig: Array = []
	for r: Array in res:
		if bool(r[1]):
			bad += 1
		fig.append("%.1f:%s" % [float(r[0]) * -1.0 + 0.2, "IN" if bool(r[1]) else "out"])
	_say("cam.wall_start", bad == 0, "wall m behind the point looked at: inside the wall after snap and 30 ticks: %s (camera z %.2f with the wall at 0.2 m)" % [" ".join(fig), float((res[3] as Array)[2])])
	cam.free()
	who.free()
	sp.call("free_all")


func _crown_band() -> void:
	var sc: float = 1.1
	var nearest: float = 1e9
	var bad: int = 0
	var n: int = 0
	var heights: Array[float] = []
	for k: int in 8:
		heights.append(-0.8 + 0.1 * float(k))           # -0.8 .. -0.1: the band under the crown (r1b)
	for k: int in 13:
		heights.append(-0.06 + 0.01 * float(k))         # -0.06 .. +0.06: the edge where it popped (r1)
	for h: float in heights:
		var sp: RefCounted = Space.new()
		_flat(sp, 40.0)
		sp.set("tag", "tree")
		sp.call("add_trunk", Vector3(0, -0.2, 0), 0.42 * sc)
		var who: Node3D = Node3D.new()
		root.add_child(who)
		who.position = Vector3(0.42 * sc + 0.36, h, 0)
		who.rotation.y = deg_to_rad(90.0)
		var cam: TLChaseCam = TLChaseCam.new()
		root.add_child(cam)
		cam.setup(who, {"distance": 8.5, "height": 3.6, "look_height": 1.7, "stiffness": 1.0, "follow": 1.0, "aim": 1.0,
			"anchor_follow": 0.45, "anchor_follow_y": 0.18, "avoid_space": sp.get("space"), "avoid_mask": 5})
		for i: int in 60:
			cam._physics_process(1.0 / 60.0)
		var look: Vector3 = who.global_position + Vector3.UP * 1.7
		var dist: float = cam.global_position.distance_to(look)
		nearest = minf(nearest, dist)
		if dist < 2.5 - 0.01 or (_inside(sp, cam.global_position, 5) and not _inside(sp, look, 4)):
			bad += 1
		n += 1
		cam.free()
		who.free()
		sp.call("free_all")
	_say("cam.crown_band", bad == 0, "pine 1.1, %d standing heights -0.80..+0.06 m: nearest camera %.2f m from the point looked at (avoid_min 2.5; was 0.04 m before bugfix-37), %d bad" % [n, nearest, bad])


func _canopy_jump() -> void:
	var sp: RefCounted = Space.new()
	_flat(sp, 20.0)
	sp.set("tag", "tree")
	sp.call("add_trunk", Vector3(0, 0, 1.2), 0.46)
	var who: Node3D = Node3D.new()
	root.add_child(who)
	var cam: TLChaseCam = TLChaseCam.new()
	root.add_child(cam)
	cam.setup(who, {"distance": 8.5, "height": 3.6, "look_height": 1.7, "avoid_space": sp.get("space"),
		"avoid_mask": 5, "stiffness": 1.0, "anchor_follow": 0.45, "anchor_follow_y": 0.18})
	var feet: Vector3 = Vector3.ZERO
	var cam_in: int = 0
	var look_in: int = 0
	var alone: int = 0
	var solid: int = 0
	for i: int in 90:
		var st: Dictionary = sp.call("drive", feet, Vector3.ZERO, i == 20, false)
		feet = st["pos"]
		who.position = feet
		cam._physics_process(1.0 / 60.0)
		var ci: bool = _inside(sp, cam.global_position, 4)
		var li: bool = _inside(sp, cam.get("_look") as Vector3, 4)
		cam_in += int(ci)
		look_in += int(li)
		alone += int(ci and not li)
		solid += int(_inside(sp, cam.global_position, 1))
	_say("cam.canopy_jump", alone == 0 and solid == 0 and look_in > 0, "90 ticks, jump at 20: point looked at in the crown %d ticks, camera %d (alone %d; was 10 before bugfix-37), camera inside the trunk %d" % [look_in, cam_in, alone, solid])
	cam.free()
	who.free()
	sp.call("free_all")


func _avoid_min() -> void:
	var who: Node3D = Node3D.new()
	root.add_child(who)
	var cam: TLChaseCam = TLChaseCam.new()
	root.add_child(cam)
	cam.setup(who, {"avoid_min": 4.0})
	_say("cam.avoid_min", is_equal_approx(cam.avoid_min, 4.0), "setup {avoid_min = 4.0}: %.1f m" % cam.avoid_min)
	cam.free()
	who.free()


func _rebase() -> void:
	var sp: RefCounted = Space.new()
	_flat(sp, 200.0)
	var land: Node3D = Node3D.new()
	root.add_child(land)
	var who: Node3D = Node3D.new()
	land.add_child(who)
	var cam: TLChaseCam = TLChaseCam.new()
	land.add_child(cam)
	cam.setup(who, {"distance": 8.5, "height": 3.6, "look_height": 1.7, "stiffness": 1.0, "follow": 1.0, "aim": 1.0,
		"anchor_follow": 0.45, "anchor_follow_y": 0.18, "avoid_space": sp.get("space"), "avoid_mask": 5})
	for i: int in 30:
		cam._physics_process(1.0 / 60.0)
	var plot: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(30.0)), Vector3(40, 3, 0))
	land.transform = plot.affine_inverse()            # view.gd _set_stage(i)
	cam.snap()                                        # view.gd _set_stage(i) snaps the visitor camera on entering
	var first: float = cam.global_position.distance_to(who.global_position + Vector3.UP * 1.7)
	for i: int in 120:
		cam._physics_process(1.0 / 60.0)
	var lk: Vector3 = who.global_position + Vector3.UP * 1.7
	var d: float = cam.global_position.distance_to(lk)
	var ok: bool = absf(d - 8.71) < 0.02 and absf(first - 8.71) < 0.02 and cam.avoid_pull < 0.01
	_say("cam.rebase", ok, "parent re-based on (40, 3, 0) yaw 30: camera %.2f m from the point looked at on the snap, %.2f m after 120 ticks (wanted 8.71; was 4.58 before bugfix-37), avoid_pull %.2f" % [first, d, cam.avoid_pull])
	land.free()
	sp.call("free_all")


func _snap_heading() -> void:
	var who: Node3D = Node3D.new()
	root.add_child(who)
	var cam: TLChaseCam = TLChaseCam.new()
	root.add_child(cam)
	cam.setup(who, {"distance": 8.0, "stiffness": 1.0})
	who.position = Vector3(15, 0, 10)
	who.rotation.y = PI / 2
	cam.snap()
	var back: float = (cam.global_position - who.global_position).dot(who.global_basis.z)
	_say("cam.snap_heading", absf(back - 8.0) < 0.01, "teleport and quarter turn, then snap(): %.2f m behind the new facing (wanted 8.00)" % back)
	cam.free()
	who.free()


func _reverse() -> void:
	var who: Node3D = Node3D.new()
	root.add_child(who)
	var cam: TLChaseCam = TLChaseCam.new()
	root.add_child(cam)
	cam.setup(who, {"use_velocity": true, "distance": 7.0, "follow": 1.0})
	for tick: int in 360:
		who.position += (Vector3.FORWARD if tick < 60 else Vector3.BACK) * 0.1
		cam._physics_process(1.0 / 60.0)
	var behind: float = -(cam.global_position - who.global_position).dot(Vector3.BACK)
	_say("cam.reverse", absf(behind - 7.0) < 0.05, "use_velocity, travel reversed for 300 ticks: camera %.2f m behind the travel (wanted 7.00)" % behind)
	cam.free()
	who.free()
