extends SceneTree
## E6 (day of 22 Nov; selftest 760-e6-world-alone.sh, cases e6.space_order and e6.space_contact). "A game in a world
## plays as it does alone": a world's pack holder (kernel/world/pack.gd) moves every body of its pack from the
## viewport's default space into the pack's own space (`adopt`); the lone worker leaves it in the default space. The
## same small scene is built twice: ALONE under a plain node (default space), WORLD under a real pack holder with its
## own space, every node handed to its `adopt()` as world.gd does. 40 static boxes and a bin (slope, floor, walls,
## posts) are placed after they enter the tree (as kit parts are); four movers (CharacterBody3D, move_and_slide as
## TLBiped) skate down the slope into the bin, where each slides along walls, posts and the floor at once (the r2a
## case: a skater against the net frame and the boards). Frame 3: the whole-space query order of both spaces;
## frame 360: the movers' transforms, bit for bit. Counts frames, never the clock. Prints two lines:
## `E6SPACE order ok|fail ...` and `E6SPACE contact ok|fail ...`.

const PackScript: GDScript = preload("res://kernel/world/pack.gd")
const ORDER_AT: int = 3
const END_AT: int = 360
const SLIDERS: int = 4

var _alone: Node3D
var _world: Node3D
var _space: RID
var _ticks: int = 0
var _order_same: bool = false
var _order_n: Array = [0, 0]


func _initialize() -> void:
	_space = PhysicsServer3D.space_create()
	PhysicsServer3D.area_set_param(_space, PhysicsServer3D.AREA_PARAM_GRAVITY, ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	PhysicsServer3D.area_set_param(_space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, ProjectSettings.get_setting("physics/3d/default_gravity_vector", Vector3.DOWN))
	PhysicsServer3D.area_set_param(_space, PhysicsServer3D.AREA_PARAM_LINEAR_DAMP, ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1))
	PhysicsServer3D.area_set_param(_space, PhysicsServer3D.AREA_PARAM_ANGULAR_DAMP, ProjectSettings.get_setting("physics/3d/default_angular_damp", 0.1))
	PhysicsServer3D.space_set_active(_space, true)
	_alone = Node3D.new()
	_alone.name = "Alone"
	root.add_child(_alone)
	_world = PackScript.new()
	_world.name = "World"
	_world.set("space", _space)
	root.add_child(_world)
	node_added.connect(_on_node_added)
	_build(_alone)
	_build(_world)
	physics_frame.connect(_on_tick)


func _on_node_added(n: Node) -> void:
	if n is CollisionObject3D and _world.is_ancestor_of(n):
		_world.call("adopt", n)


func _box(parent: Node3D, nm: String, size: Vector3, at: Transform3D, dynamic: bool) -> void:
	var b: CollisionObject3D = CharacterBody3D.new() if dynamic else StaticBody3D.new()
	b.name = nm
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	parent.add_child(b)
	b.transform = at           # placed after entering the tree, as kit parts and layouts are


func _build(parent: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 40:
		var size: Vector3 = Vector3(rng.randf_range(0.2, 3.0), rng.randf_range(0.2, 3.0), rng.randf_range(0.2, 3.0))
		_box(parent, "s%02d" % i, size, Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-30, 30), rng.randf_range(0, 3), rng.randf_range(-30, 30))), false)
	# a bin: a slope into a floor ringed by walls and two posts; twelve boxes pile up in it, each touching several
	# static shapes (and each other) at once
	_box(parent, "slope", Vector3(4, 0.2, 8), Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(50, 1.4, 0)), false)
	_box(parent, "floor", Vector3(4, 0.2, 4), Transform3D(Basis.IDENTITY, Vector3(50, -0.1, 5)), false)
	_box(parent, "wall_e", Vector3(0.2, 2, 4), Transform3D(Basis.IDENTITY, Vector3(52.1, 1, 5)), false)
	_box(parent, "wall_w", Vector3(0.2, 2, 4), Transform3D(Basis.IDENTITY, Vector3(47.9, 1, 5)), false)
	_box(parent, "wall_s", Vector3(4, 2, 0.2), Transform3D(Basis.IDENTITY, Vector3(50, 1, 7.1)), false)
	_box(parent, "post_a", Vector3(0.3, 2, 0.3), Transform3D(Basis(Vector3.UP, 0.6), Vector3(50.9, 1, 6.2)), false)
	_box(parent, "post_b", Vector3(0.3, 2, 0.3), Transform3D(Basis(Vector3.UP, 0.2), Vector3(49.2, 1, 5.6)), false)
	for k: int in SLIDERS:
		_box(parent, "slider%02d" % k, Vector3(0.7, 1.6, 0.7), Transform3D(Basis(Vector3.UP, 0.3 * k), _start(k)), true)


func _start(k: int) -> Vector3:
	return Vector3(48.6 + 0.9 * float(k), 3.4, -2.5 + 0.3 * float(k % 2))


## Each mover skates down the slope into the bin and on into its corners (move_and_slide, as TLBiped does), so it
## slides along walls, posts and the floor at once; its pushes swing every 40 frames.
func _drive(parent: Node3D) -> void:
	for k: int in SLIDERS:
		var c: CharacterBody3D = parent.get_node("slider%02d" % k)
		var side: float = 1.0 if (_ticks / 40 + k) % 2 == 0 else -1.0
		var v: Vector3 = Vector3(side * (2.0 + 0.5 * float(k)), c.velocity.y - 9.8 / 60.0, 3.5)
		if c.is_on_floor():
			v.y = 0.0
		c.velocity = v
		c.move_and_slide()


func _order(st: PhysicsDirectSpaceState3D, base: Node) -> PackedStringArray:
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var big: BoxShape3D = BoxShape3D.new()
	big.size = Vector3(1000, 1000, 1000)
	q.shape = big
	var names: PackedStringArray = []
	for h: Dictionary in st.intersect_shape(q, 1024):
		var c: Object = h.get("collider")
		names.append(String((c as Node).name) if c is Node and base.is_ancestor_of(c as Node) else "<outside>")
	return names


func _on_tick() -> void:
	_ticks += 1
	_drive(_alone)
	_drive(_world)
	if _ticks == ORDER_AT:
		var a: PackedStringArray = _order(_alone.get_world_3d().direct_space_state, _alone)
		var w: PackedStringArray = _order(PhysicsServer3D.space_get_direct_state(_space), _world)
		_order_n = [a.size(), w.size()]
		_order_same = a == w and a.size() == 47 + SLIDERS
		if OS.has_environment("E6_DEBUG"):
			print("A ", ",".join(a))
			print("W ", ",".join(w))
	if _ticks == END_AT:
		var moved: int = 0
		var differ: PackedStringArray = []
		for k: int in SLIDERS:
			var ta: Transform3D = (_alone.get_node("slider%02d" % k) as Node3D).global_transform
			var tw: Transform3D = (_world.get_node("slider%02d" % k) as Node3D).global_transform
			if ta.origin.z > 3.0:          # reached the bin
				moved += 1
			if ta != tw:
				differ.append("slider%02d %.6f m" % [k, ta.origin.distance_to(tw.origin)])
		print("E6SPACE order %s %s: %d colliders alone, %d in the moved space, frame %d" % [
			"ok" if _order_same else "fail", "same" if _order_same else "DIFFERS", _order_n[0], _order_n[1], ORDER_AT])
		var ok: bool = differ.is_empty() and moved == SLIDERS
		print("E6SPACE contact %s: movers in the bin %d/%d, differ %s, frame %d" % [
			"ok" if ok else "fail", moved, SLIDERS, "none" if differ.is_empty() else ", ".join(differ), _ticks])
		_alone.free()
		_world.free()
		PhysicsServer3D.free_rid(_space)
		quit(0 if ok and _order_same else 1)
