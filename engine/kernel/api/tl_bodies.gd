class_name TLBodies
extends RefCounted
## Bodies and triggers. Every body made here is tagged with a material and gets friction, restitution and (for a
## dynamic body) mass from the law table. Capability: `physics`.
##
##   var floor := TLBodies.make(&"box", Vector3(20, 1, 20), "concrete", {position = Vector3(0, -0.5, 0)})
##   var crate := TLBodies.make(&"box", Vector3(1, 1, 1), "wood", {dynamic = true, position = Vector3(0, 3, 0)})
##   ctx.root.add_child(floor); ctx.root.add_child(crate)

const OPTIONS: Array = ["dynamic", "mass", "position", "rotation_degrees", "color", "visual", "name", "ccd", "track",
	"layer", "mask", "group", "lock"]


## Makes a static (default) or dynamic body.
## `shape` and `dims`: &"box" Vector3 size; &"sphere" float radius; &"cylinder" or &"capsule" Vector2(radius, height).
## Options: dynamic (bool), mass (kg; default density x volume), position, rotation_degrees, color, visual (bool),
## name, ccd (bool), track (bool, dynamic bodies: attach a TLContact; default true), layer, mask, group,
## lock (dynamic bodies: world axes the body may not move along or turn about, any of "x", "y", "z", "rx", "ry", "rz").
static func make(shape: StringName, dims: Variant, material_id: String, opts: Dictionary = {}) -> PhysicsBody3D:
	TLContext.require("physics", "TLBodies")
	for k: String in opts.keys():
		if not OPTIONS.has(k):
			push_error("TLBodies.make: unknown option '%s' (options: %s)" % [k, ", ".join(PackedStringArray(OPTIONS))])
	var dynamic: bool = bool(opts.get("dynamic", false))
	var body: PhysicsBody3D = RigidBody3D.new() if dynamic else StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var mesh: Mesh = null
	match shape:
		&"box":
			var bs: BoxShape3D = BoxShape3D.new()
			bs.size = dims
			cs.shape = bs
			var bm: BoxMesh = BoxMesh.new()
			bm.size = dims
			mesh = bm
		&"sphere":
			var ss: SphereShape3D = SphereShape3D.new()
			ss.radius = float(dims)
			cs.shape = ss
			var sm: SphereMesh = SphereMesh.new()
			sm.radius = float(dims)
			sm.height = float(dims) * 2.0
			sm.radial_segments = 16
			sm.rings = 8
			mesh = sm
		&"cylinder":
			var ys: CylinderShape3D = CylinderShape3D.new()
			ys.radius = (dims as Vector2).x
			ys.height = (dims as Vector2).y
			cs.shape = ys
			var ym: CylinderMesh = CylinderMesh.new()
			ym.top_radius = (dims as Vector2).x
			ym.bottom_radius = (dims as Vector2).x
			ym.height = (dims as Vector2).y
			ym.radial_segments = 20
			mesh = ym
		&"capsule":
			var ps: CapsuleShape3D = CapsuleShape3D.new()
			ps.radius = (dims as Vector2).x
			ps.height = (dims as Vector2).y
			cs.shape = ps
			var pm: CapsuleMesh = CapsuleMesh.new()
			pm.radius = (dims as Vector2).x
			pm.height = (dims as Vector2).y
			mesh = pm
		_:
			push_error("TLBodies.make: unknown shape '%s' (box, sphere, cylinder, capsule)" % shape)
			var fs: BoxShape3D = BoxShape3D.new()
			cs.shape = fs
	body.add_child(cs)
	if bool(opts.get("visual", true)) and mesh != null:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = TLStandin.material(opts["color"], material_id) if opts.has("color") else TLStandin.material_for(material_id)
		body.add_child(mi)
	if opts.has("name"):
		body.name = str(opts["name"])
	if opts.has("position"):
		body.position = opts["position"]
	if opts.has("rotation_degrees"):
		body.rotation_degrees = opts["rotation_degrees"]
	if opts.has("layer"):
		body.collision_layer = int(opts["layer"])
	if opts.has("mask"):
		body.collision_mask = int(opts["mask"])
	if opts.has("group"):
		body.add_to_group(str(opts["group"]))
	if dynamic:
		var rb: RigidBody3D = body as RigidBody3D
		if opts.has("mass"):
			rb.mass = float(opts["mass"])
		else:
			rb.set_meta(&"tl_mass_from_density", true)
		rb.continuous_cd = bool(opts.get("ccd", false))
		_lock(rb, opts.get("lock", []))
		if bool(opts.get("track", true)):
			var c: TLContact = TLContact.new()
			c.name = "TLContact"
			rb.add_child(c)
	TLLaws.apply(body, material_id)
	return body


## Axis locks from the `lock` option: a paddle that only slides along z is ["x", "y", "rx", "ry", "rz"].
static func _lock(rb: RigidBody3D, axes: Variant) -> void:
	if not (axes is Array or axes is PackedStringArray):
		push_error("TLBodies: `lock` is a list of axes (x, y, z, rx, ry, rz)")
		return
	for a: Variant in axes:
		match str(a):
			"x": rb.axis_lock_linear_x = true
			"y": rb.axis_lock_linear_y = true
			"z": rb.axis_lock_linear_z = true
			"rx": rb.axis_lock_angular_x = true
			"ry": rb.axis_lock_angular_y = true
			"rz": rb.axis_lock_angular_z = true
			_: push_error("TLBodies: unknown lock axis '%s' (x, y, z, rx, ry, rz)" % str(a))


## True when a node is a kit part the game moves (KIT-RIG-STYLE.md, dynamic props): no body of its own, metadata
## `tl_dynamic` = true and `tl_shape` (a Shape3D), optionally `tl_shape_offset`, `tl_material`, `tl_mass_hint`.
static func is_dynamic_part(part: Node) -> bool:
	return part != null and bool(part.get_meta(&"tl_dynamic", false)) and part.get_meta(&"tl_shape", null) is Shape3D


## Makes the dynamic body for a kit part the game moves (a paddle): the part becomes the visual child of a new
## RigidBody3D with the part's shape, material and mass hint. For a puck or a ball use `TLBall.create({part = ...})`.
## Options: mass, material, position, rotation_degrees, name, ccd, track, layer, mask, group, lock (as in `make`).
static func from_part(part: Node3D, opts: Dictionary = {}) -> RigidBody3D:
	TLContext.require("physics", "TLBodies")
	for k: String in opts.keys():
		if not ["mass", "material", "position", "rotation_degrees", "name", "ccd", "track", "layer", "mask", "group", "lock"].has(k):
			push_error("TLBodies.from_part: unknown option '%s'" % k)
	var rb: RigidBody3D = RigidBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var material_id: String = str(opts.get("material", "plastic"))
	if is_dynamic_part(part):
		cs.shape = part.get_meta(&"tl_shape")
		cs.position = part.get_meta(&"tl_shape_offset", Vector3.ZERO)
		if not opts.has("material") and part.has_meta(&"tl_material"):
			material_id = str(part.get_meta(&"tl_material"))
	else:
		push_error("TLBodies.from_part: the node is not a dynamic kit part (it needs metadata tl_dynamic and tl_shape); using a 0.5 m box")
		var fallback: BoxShape3D = BoxShape3D.new()
		fallback.size = Vector3.ONE * 0.5
		cs.shape = fallback
	rb.add_child(cs)
	if part != null:
		if part.get_parent() != null:
			part.get_parent().remove_child(part)
		part.transform = Transform3D.IDENTITY
		rb.add_child(part)
	if opts.has("mass"):
		rb.mass = float(opts["mass"])
	elif part != null and float(part.get_meta(&"tl_mass_hint", -1.0)) > 0.0:
		rb.mass = float(part.get_meta(&"tl_mass_hint"))
	else:
		rb.set_meta(&"tl_mass_from_density", true)
	if opts.has("name"):
		rb.name = str(opts["name"])
	if opts.has("position"):
		rb.position = opts["position"]
	if opts.has("rotation_degrees"):
		rb.rotation_degrees = opts["rotation_degrees"]
	if opts.has("layer"):
		rb.collision_layer = int(opts["layer"])
	if opts.has("mask"):
		rb.collision_mask = int(opts["mask"])
	if opts.has("group"):
		rb.add_to_group(str(opts["group"]))
	rb.continuous_cd = bool(opts.get("ccd", false))
	_lock(rb, opts.get("lock", []))
	if bool(opts.get("track", true)):
		var c: TLContact = TLContact.new()
		c.name = "TLContact"
		rb.add_child(c)
	TLLaws.apply(rb, material_id)
	return rb


## A flat static floor: `size` metres in x and z, its top at height `top_y`.
static func ground(size: Vector2, material_id: String, top_y: float = 0.0, center: Vector3 = Vector3.ZERO) -> StaticBody3D:
	return make(&"box", Vector3(size.x, 1.0, size.y), material_id, {"position": Vector3(center.x, top_y - 0.5, center.z)}) as StaticBody3D


## A trigger volume (no collision response). See TLTrigger. Options: position, rotation_degrees, name, group_filter.
static func trigger(shape: StringName, dims: Variant, opts: Dictionary = {}) -> TLTrigger:
	TLContext.require("physics", "TLBodies")
	var t: TLTrigger = TLTrigger.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	match shape:
		&"box":
			var bs: BoxShape3D = BoxShape3D.new()
			bs.size = dims
			cs.shape = bs
			t._half = (dims as Vector3) * 0.5
		&"sphere":
			var ss: SphereShape3D = SphereShape3D.new()
			ss.radius = float(dims)
			cs.shape = ss
			t._half = Vector3.ONE * float(dims)
			t._round = true
		&"cylinder":
			var ys: CylinderShape3D = CylinderShape3D.new()
			ys.radius = (dims as Vector2).x
			ys.height = (dims as Vector2).y
			cs.shape = ys
			t._half = Vector3((dims as Vector2).x, (dims as Vector2).y * 0.5, (dims as Vector2).x)
		_:
			push_error("TLBodies.trigger: unknown shape '%s' (box, sphere, cylinder)" % shape)
	t.add_child(cs)
	for k: String in opts.keys():
		match k:
			"position":
				t.position = opts[k]
			"rotation_degrees":
				t.rotation_degrees = opts[k]
			"name":
				t.name = str(opts[k])
			"group_filter":
				t.group_filter = StringName(str(opts[k]))
			_:
				push_error("TLBodies.trigger: unknown option '%s'" % k)
	return t


## The kernel's door for a one-off push on a dynamic body: an impulse in N*s at the centre, or at a world point.
static func push(body: RigidBody3D, impulse: Vector3, at_world: Variant = null) -> void:
	if body == null:
		return
	body.sleeping = false
	if at_world == null:
		body.apply_central_impulse(impulse)
	else:
		body.apply_impulse(impulse, (at_world as Vector3) - body.global_position)


## The kernel's door for a body a player or an AI moves under control (a paddle, a bat, a platform): steers its
## velocity toward `velocity` (m/s) with at most `max_accel` (m/s2). Call it every frame; zero velocity holds it still.
## Use it with the `lock` option, so the body keeps to its rail whatever hits it.
static func drive(body: RigidBody3D, velocity: Vector3, max_accel: float = 80.0) -> void:
	if body == null:
		return
	body.sleeping = false
	var dv: Vector3 = (velocity - body.linear_velocity).limit_length(max_accel / 60.0)
	body.apply_central_impulse(dv * body.mass)


## The contact tracker of a dynamic body (attached on demand): `TLBodies.contact(body).hit.connect(...)`.
static func contact(body: RigidBody3D) -> TLContact:
	var c: TLContact = body.get_node_or_null("TLContact") as TLContact
	if c == null:
		c = TLContact.new()
		c.name = "TLContact"
		body.add_child(c)
	return c
