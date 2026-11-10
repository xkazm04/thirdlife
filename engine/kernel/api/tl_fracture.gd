class_name TLFracture
extends Node
## Fracture for a pre-fractured part in the kit convention (KIT-RIG-STYLE.md): a child `Intact` (visual + static
## body) and a hidden child `Pieces` (one MeshInstance3D per piece with metadata `tl_shape`, `tl_material`,
## `tl_mass_hint`). Breaking hides `Intact`, wakes the pieces as rigid bodies, and bakes them when they sleep.
## Capability: `fracture`.
##
##   var wall := TLKit.build("barrier_wall", {...})         # or TLStandin.fracturable_wall(...) without the kit
##   ctx.root.add_child(wall)
##   var fx := TLFracture.attach(wall, {hp = 100.0})
##   fx.broke.connect(func(by): ...); fx.settled.connect(func(frames): ...)
##
## It breaks by itself when impacts (see TLDamage) use up its health, or at once with `break_now()`.

signal broke(by: Node)
signal settled(frames: int)        ## every piece sleeps (or the limit passed) and the pieces are baked

const OPTIONS: Array = ["hp", "threshold", "bake", "max_awake_frames", "kick", "scatter"]

var part: Node3D
var state: StringName = &"intact"       ## &"intact" -> &"broken" -> &"settled"
var bake: StringName = &"static"        ## &"static": pieces become static bodies; &"remove": pieces are freed; &"none"
var max_awake_frames: int = 900         ## bake anyway after this many frames
var kick: float = 0.6                   ## share of the hitting body's speed given to the pieces
var scatter: float = 0.6                ## random extra speed in m/s (from ctx.rng)
var damage: TLDamage
var pieces: Array = []                  ## the RigidBody3D pieces while broken
var _broken_frames: int = 0
var _pending: Array = []


## Options: hp (default 100), threshold (N*s; default from the material's hardness), bake, max_awake_frames, kick, scatter.
static func attach(part_: Node3D, opts: Dictionary = {}) -> TLFracture:
	TLContext.require("fracture", "TLFracture")
	var f: TLFracture = TLFracture.new()
	f.name = "TLFracture"
	f.part = part_
	var dopts: Dictionary = {}
	for k: String in opts.keys():
		if k == "hp" or k == "threshold":
			dopts[k] = opts[k]
		elif OPTIONS.has(k):
			f.set(k, StringName(str(opts[k])) if k == "bake" else opts[k])
		else:
			push_error("TLFracture.attach: unknown option '%s' (options: %s)" % [k, ", ".join(PackedStringArray(OPTIONS))])
	var intact: Node = part_.get_node_or_null("Intact")
	var pieces_node: Node = part_.get_node_or_null("Pieces")
	if intact == null or pieces_node == null:
		push_error("TLFracture.attach: '%s' is not a fracturable part (it needs children named Intact and Pieces)" % part_.name)
		part_.add_child(f)
		f.set_physics_process(false)
		return f
	part_.add_child(f)
	f.damage = TLDamage.attach(intact as Node3D, dopts)
	f.damage.broken.connect(f._on_damage_broken)
	f.set_physics_process(false)
	return f


func _on_damage_broken(by: Node) -> void:
	var v: Vector3 = Vector3.ZERO
	var at: Vector3 = part.global_position
	if by is Node3D:
		at = (by as Node3D).global_position
		var c: TLContact = by.get_node_or_null("TLContact") as TLContact
		if c != null:
			v = c._prev_velocity
		elif by is RigidBody3D:
			v = (by as RigidBody3D).linear_velocity
	# this runs inside a physics callback: do the break at the start of the next physics frame
	_pending = [v * kick, at, by]
	set_physics_process(true)


## Breaks the part now. `push` is the velocity given to pieces near `at` (world); pieces further away get less.
func break_now(push: Vector3 = Vector3.ZERO, at: Variant = null, by: Node = null) -> void:
	if state != &"intact":
		return
	var intact: Node3D = part.get_node_or_null("Intact") as Node3D
	var holder: Node3D = part.get_node_or_null("Pieces") as Node3D
	if intact == null or holder == null:
		return
	state = &"broken"
	intact.visible = false
	_disable(intact)
	holder.visible = true
	var origin: Vector3 = at if at != null else part.global_position
	var rng: RandomNumberGenerator = TLContext.current.rng if TLContext.current != null else RandomNumberGenerator.new()
	for child: Node in holder.get_children():
		if not (child is MeshInstance3D) or not child.has_meta(&"tl_shape"):
			continue
		var mesh: MeshInstance3D = child
		var body: RigidBody3D = RigidBody3D.new()
		body.name = "Piece_" + String(mesh.name)
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = mesh.get_meta(&"tl_shape") as Shape3D
		body.add_child(cs)
		var xf: Transform3D = mesh.global_transform
		holder.add_child(body)
		body.global_transform = xf
		mesh.reparent(body, false)
		mesh.transform = Transform3D.IDENTITY
		body.mass = maxf(0.05, float(mesh.get_meta(&"tl_mass_hint", 10.0)))
		TLLaws.apply(body, str(mesh.get_meta(&"tl_material", "concrete")))
		var dist: float = xf.origin.distance_to(origin)
		var share: float = 1.0 / (1.0 + dist * dist * 0.5)
		body.linear_velocity = push * share + Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.0, 1.0), rng.randf_range(-1.0, 1.0)) * scatter
		body.angular_velocity = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * scatter * 2.0
		pieces.append(body)
	_broken_frames = 0
	set_physics_process(true)
	broke.emit(by)


func _disable(n: Node) -> void:
	if n is CollisionObject3D:
		(n as CollisionObject3D).collision_layer = 0
		(n as CollisionObject3D).collision_mask = 0
	for c: Node in n.get_children():
		_disable(c)


## How many pieces are still moving.
func awake_count() -> int:
	var n: int = 0
	for b: RigidBody3D in pieces:
		if is_instance_valid(b) and not b.sleeping and not b.freeze:
			n += 1
	return n


func _physics_process(_delta: float) -> void:
	if not _pending.is_empty():
		var p: Array = _pending
		_pending = []
		break_now(p[0], p[1], p[2] if is_instance_valid(p[2]) else null)
		return
	if state != &"broken":
		return
	_broken_frames += 1
	if _broken_frames < 30:
		return
	if awake_count() == 0 or _broken_frames >= max_awake_frames:
		state = &"settled"
		for b: RigidBody3D in pieces:
			if not is_instance_valid(b):
				continue
			if bake == &"static":
				b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
				b.freeze = true
			elif bake == &"remove":
				b.queue_free()
		if bake == &"remove":
			pieces.clear()
		set_physics_process(false)
		settled.emit(_broken_frames)
