class_name TLBall
extends RigidBody3D
## A ball or a puck: slides, rolls and bounces by the material laws (surface rules included, first touch included).
## Capability: `ball`.
##
##   var ball := TLBall.create({kind = &"ball", radius = 0.11, material = "rubber", position = Vector3(0, 1, 0)})
##   ctx.root.add_child(ball)
##   ball.shoot(Vector3(4, 2, 0) * ball.mass)        # an impulse in N*s
##   ball.bounced.connect(func(other, speed): ...)

signal bounced(other: Node, speed: float)   ## hit something at `speed` m/s (closing speed)
signal stopped()                             ## came to rest after moving
signal held(holder: Node3D)                  ## picked up with hold()
signal released(holder: Node3D)              ## let go with release()

const OPTIONS: Array = ["part", "kind", "radius", "height", "material", "mass", "position", "planar", "max_speed", "color", "name", "group", "drag"]

var kind: StringName = &"ball"     ## &"ball" (sphere) or &"puck" (flat cylinder)
var radius: float = 0.11
var height: float = 0.025          ## puck only
var material_id: String = "rubber"
var max_speed: float = 0.0         ## m/s; 0 = no limit
var contact: TLContact
var _was_moving: bool = false
var _holder: Node3D = null
var _held: bool = false   # hunt2 A6: possession apart from the node, which compares equal to null once freed
var _pos_now: Vector3 = Vector3.ZERO       # for swept trigger tests (TLTrigger): where it was at the last two ticks
var _pos_before: Vector3 = Vector3.ZERO
var _pos_stamp: int = -1
var _hold_offset: Vector3 = Vector3.ZERO
var _shape_node: CollisionShape3D = null   # K8: what set_radius resizes
var _visual: Node3D = null
var _gain: float = 0.0                     # H1: largest planar speed gain per frame from contacts (0 = off)
var _gain_floor: float = 0.0
var _speed_ref: float = 0.0                # H1: the planar speed the next frame is measured against
var _trust: int = 0                        # H1: frames in which a declared velocity is taken as it is


## Options: kind, radius, height (puck), material, mass (default density x volume), position, planar (bool: a puck
## that stays flat), max_speed, color, name, group, drag (linear damping per second), and
## part: a kit part in the dynamic-prop convention of KIT-RIG-STYLE.md (`TLKit.build("puck", {...})`: a visual node
## with metadata tl_dynamic, tl_shape, tl_shape_offset, tl_material, tl_mass_hint and no body). The ball then takes
## its shape, material and mass from the part and wears it; `material` and `mass` still override.
static func create(opts: Dictionary = {}) -> TLBall:
	TLContext.require("ball", "TLBall")
	var b: TLBall = TLBall.new()
	for k: String in opts.keys():
		if not OPTIONS.has(k):
			push_error("TLBall.create: unknown option '%s' (options: %s)" % [k, ", ".join(PackedStringArray(OPTIONS))])
	b.kind = StringName(str(opts.get("kind", "ball")))
	b.radius = float(opts.get("radius", 0.038 if b.kind == &"puck" else 0.11))
	b.height = float(opts.get("height", 0.025))
	b.material_id = str(opts.get("material", "rubber"))
	b.max_speed = float(opts.get("max_speed", 0.0))
	var cs: CollisionShape3D = CollisionShape3D.new()
	var mi: Node3D = MeshInstance3D.new()
	var part: Node3D = opts.get("part") as Node3D
	var part_mass: float = -1.0
	if opts.has("part") and not TLBodies.is_dynamic_part(part):
		push_error("TLBall.create: `part` is not a dynamic kit part (it needs metadata tl_dynamic and tl_shape); using the ball's own shape")
		part = null
	if part != null:
		var shape: Shape3D = part.get_meta(&"tl_shape")
		cs.shape = shape
		cs.position = part.get_meta(&"tl_shape_offset", Vector3.ZERO)
		if shape is CylinderShape3D:
			b.kind = &"puck"
			b.radius = (shape as CylinderShape3D).radius
			b.height = (shape as CylinderShape3D).height
		elif shape is SphereShape3D:
			b.kind = &"ball"
			b.radius = (shape as SphereShape3D).radius
		if not opts.has("material") and part.has_meta(&"tl_material"):
			b.material_id = str(part.get_meta(&"tl_material"))
		part_mass = float(part.get_meta(&"tl_mass_hint", -1.0))
		mi.free()
		if part.get_parent() != null:
			part.get_parent().remove_child(part)
		part.transform = Transform3D.IDENTITY
		mi = part
	elif b.kind == &"puck":
		var cyl: CylinderShape3D = CylinderShape3D.new()
		cyl.radius = b.radius
		cyl.height = b.height
		cs.shape = cyl
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = b.radius
		cm.bottom_radius = b.radius
		cm.height = b.height
		cm.radial_segments = 20
		(mi as MeshInstance3D).mesh = cm
	else:
		var sp: SphereShape3D = SphereShape3D.new()
		sp.radius = b.radius
		cs.shape = sp
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = b.radius
		sm.height = b.radius * 2.0
		sm.radial_segments = 16
		sm.rings = 8
		(mi as MeshInstance3D).mesh = sm
	if part == null:
		(mi as MeshInstance3D).material_override = TLStandin.material(opts["color"], b.material_id) if opts.has("color") else TLStandin.material_for(b.material_id)
	b.add_child(cs)
	b.add_child(mi)
	b._shape_node = cs
	b._visual = mi
	b.continuous_cd = true
	if bool(opts.get("planar", false)):
		b.axis_lock_angular_x = true
		b.axis_lock_angular_z = true
	if opts.has("mass"):
		b.mass = float(opts["mass"])
	elif part_mass > 0.0:
		b.mass = part_mass
	else:
		b.set_meta(&"tl_mass_from_density", true)
	if opts.has("drag"):
		b.linear_damp = float(opts["drag"])
	if opts.has("position"):
		b.position = opts["position"]
	if opts.has("name"):
		b.name = str(opts["name"])
	if opts.has("group"):
		b.add_to_group(str(opts["group"]))
	b.add_to_group(TLContext.current.ball_group if TLContext.current != null else &"tl_ball")   # N2: per pack
	TLLaws.apply(b, b.material_id)
	b.contact = TLContact.new()
	b.contact.name = "TLContact"
	b.add_child(b.contact)
	b.contact.hit.connect(b._on_hit)
	return b


func _on_hit(other: Node, _impulse: float, hit_speed: float) -> void:
	bounced.emit(other, hit_speed)


## K8 (feel kit, 22 Nov 2026): a new radius in metres, now (the hockey big puck). The collision shape and the drawn
## ball or puck grow or shrink with it (a kit part's visual is scaled: x and z for a puck, all three for a ball); the
## puck's height, the mass, the material and the motion are kept. Deterministic; it moves the state hash only from the
## frame it is called (the shape is part of the physics, not of the hashed bytes).
func set_radius(r: float) -> void:
	if not (r > 0.0) or not is_finite(r):
		push_error("TLBall.set_radius: the radius must be a positive number (got %s)" % r)
		return
	var k: float = r / radius if radius > 0.0 else 1.0
	radius = r
	if _shape_node != null and _shape_node.shape != null:
		var sh: Shape3D = _shape_node.shape.duplicate() as Shape3D   # a kit part's shape is shared: never resize it in place
		if sh is CylinderShape3D:
			(sh as CylinderShape3D).radius = r
		elif sh is SphereShape3D:
			(sh as SphereShape3D).radius = r
		_shape_node.shape = sh
	if _visual is MeshInstance3D and ((_visual as MeshInstance3D).mesh is CylinderMesh or (_visual as MeshInstance3D).mesh is SphereMesh):
		var m: Mesh = (_visual as MeshInstance3D).mesh.duplicate() as Mesh
		if m is CylinderMesh:
			(m as CylinderMesh).top_radius = r
			(m as CylinderMesh).bottom_radius = r
		else:
			(m as SphereMesh).radius = r
			(m as SphereMesh).height = r * 2.0
		(_visual as MeshInstance3D).mesh = m
	elif _visual != null:
		_visual.scale = Vector3(_visual.scale.x * k, _visual.scale.y if kind == &"puck" else _visual.scale.y * k, _visual.scale.z * k)
	sleeping = false


## H1 (1.16, hockey): a contact (a puck squeezed between two skaters, a body run into it) may raise the planar speed
## by at most `per_frame` m/s a frame over max(the speed a frame ago, `floor_speed`); a faster gain is cut back at the start of
## the next frame. A velocity the game sets is never cut: shoot, shoot_at, release, place and set_velocity declare it
## (writing `linear_velocity` yourself does not: use set_velocity). Held: nothing. 0 = off (the default: no hash moves).
func set_max_gain(per_frame: float, floor_speed: float = 0.0) -> void:
	_gain = maxf(0.0, per_frame)
	_gain_floor = maxf(0.0, floor_speed)
	_declare()


## H1 (1.16): sets the velocity (m/s) as the game's own: max_gain does not cut it.
func set_velocity(v: Vector3) -> void:
	sleeping = false
	linear_velocity = v
	_declare()


func _declare() -> void:
	_trust = 2                               # this frame, and the physics step after an impulse


## Hits the ball: an impulse in N*s (mass x change of velocity).
func shoot(impulse: Vector3) -> void:
	_declare()
	sleeping = false
	apply_central_impulse(impulse)


## Sends the ball toward a world point at `speed_` m/s, whatever it was doing.
func shoot_at(target: Vector3, speed_: float) -> void:
	var d: Vector3 = target - global_position
	if d.length() < 0.001:
		return
	_declare()
	sleeping = false
	linear_velocity = d.normalized() * speed_


## Puts the ball somewhere, at rest (a face-off, a reset after a goal).
func place(at: Vector3) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = at
	if is_inside_tree():
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(global_transform.basis, at))
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	sleeping = false
	_was_moving = false
	_declare()
	_pos_stamp = -1          # a teleport is not a path: it must not count as passing through a trigger
	if is_inside_tree():
		reset_physics_interpolation()   # D15: drawn at the new place at once, never a glide from the old one (draw only)


## Carries the ball with a node (a stick blade, a hand socket): it stays at `offset` in the holder's space and takes
## no part in physics until `release()`. Possession for hockey, handball, a pickup.
func hold(holder: Node3D, offset: Vector3 = Vector3.ZERO) -> void:
	_holder = holder
	_held = true
	_hold_offset = offset
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	held.emit(holder)


## Lets go of a held ball with a velocity in m/s (a pass, a shot). Does nothing when it is not held.
func release(velocity: Vector3 = Vector3.ZERO) -> void:
	if not _held:
		return
	var was: Node3D = _holder if is_instance_valid(_holder) else null
	_holder = null
	_held = false
	_declare()
	freeze = false
	sleeping = false
	linear_velocity = velocity
	angular_velocity = Vector3.ZERO
	released.emit(was)


## The node that holds the ball, or null.
func holder() -> Node3D:
	return _holder if is_instance_valid(_holder) else null


func speed() -> float:
	return linear_velocity.length()


func is_moving() -> bool:
	return linear_velocity.length() > 0.05


## Material id of the surface the ball is on or about to touch ("" when nothing tagged is near).
func surface() -> String:
	return contact.surface if contact != null else ""


## The straight path of the last physics step, as [from, to] (used by TLTrigger so a fast ball cannot skip a gate).
func last_step() -> Array:
	if _pos_stamp == Engine.get_physics_frames():
		return [_pos_before, _pos_now]
	return [_pos_now, global_position] if _pos_stamp >= 0 else [global_position, global_position]


func _physics_process(_delta: float) -> void:
	_pos_before = _pos_now if _pos_stamp >= 0 else global_position
	_pos_now = global_position
	_pos_stamp = Engine.get_physics_frames()
	if _held:
		if is_instance_valid(_holder) and _holder.is_inside_tree():
			global_position = _holder.global_transform * _hold_offset
		else:
			release()
		return
	if max_speed > 0.0 and linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
	if _gain > 0.0:
		_limit_gain()
	var moving: bool = is_moving()
	if _was_moving and not moving:
		stopped.emit()
	_was_moving = moving


## H1: cut a planar speed gain the game did not declare (see set_max_gain).
func _limit_gain() -> void:
	var flat := Vector2(linear_velocity.x, linear_velocity.z)
	var spd := flat.length()
	if _trust > 0:
		_trust -= 1
	else:
		var cap := maxf(_speed_ref, _gain_floor) + _gain
		if spd > cap:
			var k := cap / spd
			linear_velocity = Vector3(linear_velocity.x * k, linear_velocity.y, linear_velocity.z * k)
			spd = cap
	_speed_ref = spd
