extends SceneTree
## bugfix-37 lane cam, Q32: a quarter turn in one tick swings the camera (stiffness 1, anchor_follow 1) across a box; with
## physics interpolation on, the frames drawn between the two ticks would show it inside the box. The camera now draws a
## move whose chord passes through something in `avoid_space` as a cut. Run with `--fixed-fps 120` (two frames a tick).
## Prints `CAMCASE cam.cut_wall ok|fail <figures>`.

const Space: GDScript = preload("res://kernel/world/terrain/world_space.gd")

var tick: int = 0
var sp: RefCounted = Space.new()
var who: Node3D = Node3D.new()
var cam: TLChaseCam = TLChaseCam.new()
var inside_drawn: int = 0
var inside_physics: int = 0
var drawn: int = 0
var started: bool = false


func _initialize() -> void:
	_setup.call_deferred()


func _setup() -> void:
	root.add_child(who)
	root.add_child(cam)
	sp.call("add_box", Transform3D(Basis(), Vector3(4, 1, 4)), Vector3(2, 2, 2))
	cam.setup(who, {"distance": 8.0, "height": 1.0, "look_height": 1.0, "stiffness": 1.0, "anchor_follow": 1.0,
		"avoid_space": sp.get("space")})
	cam.make_current()
	started = true


func _physics_process(_delta: float) -> bool:
	if started:
		tick += 1
		if tick == 8:
			who.rotation.y = PI / 2
	return false


func _inside(pos: Vector3) -> bool:
	var q: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	q.position = pos
	q.collision_mask = 1
	return not PhysicsServer3D.space_get_direct_state(sp.get("space") as RID).intersect_point(q).is_empty()


func _process(_delta: float) -> bool:
	if started:
		drawn += 1
		if _inside(cam.global_position):
			inside_physics += 1
		if _inside(cam.get_global_transform_interpolated().origin):
			inside_drawn += 1
		if tick >= 16:
			var ok: bool = inside_drawn == 0 and inside_physics == 0 and drawn >= 16
			print("CAMCASE cam.cut_wall %s quarter turn in one tick past a box, %d frames drawn over 16 ticks: physics poses inside %d, drawn frames inside %d (was 1 before bugfix-37)" % [
				"ok" if ok else "fail", drawn, inside_physics, inside_drawn])
			cam.free()
			who.free()
			sp.call("free_all")
			quit(0 if ok else 1)
	return false
