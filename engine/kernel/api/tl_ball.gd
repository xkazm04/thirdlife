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
var _pos_now: Vector3 = Vector3.ZERO       # for swept trigger tests (TLTrigger): where it was at the last two ticks
var _pos_before: Vector3 = Vector3.ZERO
var _pos_stamp: int = -1
var _hold_offset: Vector3 = Vector3.ZERO


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
	b.add_to_group(&"tl_ball")
	TLLaws.apply(b, b.material_id)
	b.contact = TLContact.new()
	b.contact.name = "TLContact"
	b.add_child(b.contact)
	b.contact.hit.connect(b._on_hit)
	return b


func _on_hit(other: Node, _impulse: float, hit_speed: float) -> void:
	bounced.emit(other, hit_speed)


## Hits the ball: an impulse in N*s (mass x change of velocity).
func shoot(impulse: Vector3) -> void:
	sleeping = false
	apply_central_impulse(impulse)


## Sends the ball toward a world point at `speed_` m/s, whatever it was doing.
func shoot_at(target: Vector3, speed_: float) -> void:
	var d: Vector3 = target - global_position
	if d.length() < 0.001:
		return
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
	_pos_stamp = -1          # a teleport is not a path: it must not count as passing through a trigger


## Carries the ball with a node (a stick blade, a hand socket): it stays at `offset` in the holder's space and takes
## no part in physics until `release()`. Possession for hockey, handball, a pickup.
func hold(holder: Node3D, offset: Vector3 = Vector3.ZERO) -> void:
	_holder = holder
	_hold_offset = offset
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	held.emit(holder)


## Lets go of a held ball with a velocity in m/s (a pass, a shot). Does nothing when it is not held.
func release(velocity: Vector3 = Vector3.ZERO) -> void:
	if _holder == null:
		return
	var was: Node3D = _holder
	_holder = null
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
	if _holder != null:
		if is_instance_valid(_holder) and _holder.is_inside_tree():
			global_position = _holder.global_transform * _hold_offset
		else:
			release()
		return
	if max_speed > 0.0 and linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
	var moving: bool = is_moving()
	if _was_moving and not moving:
		stopped.emit()
	_was_moving = moving
