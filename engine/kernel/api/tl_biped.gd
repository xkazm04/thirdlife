class_name TLBiped
extends CharacterBody3D
## A character on two legs: walks, runs, and skates. The controller owns the physics body and drives a rig through
## the duck-typed calls of KIT-RIG-STYLE.md; without a rig it builds the kernel's stand-in. Capability: `biped`.
##
##   var hero := TLBiped.create({position = Vector3(0, 0, 0)})        # stand-in rig, walk mode
##   ctx.root.add_child(hero)
##   func _pack_tick(frame):
##       var v := ctx.input.vector(&"left", &"right", &"forward", &"back")
##       hero.move(Vector3(v.x, 0, v.y), ctx.input.pressed(&"run"))     # intent, world space; call every frame
##
## Intent in, motion out: `move()`, `brake()`, `jump()` are the only way to steer it, for a player and for AI alike.
## Grip comes from the surface under the feet (law tables): walking on ice is slow to start and slow to stop.
## Mode &"skate": thrust along the facing, momentum, low lateral grip (it drifts), long glide on ice.

signal mode_changed(mode: StringName)
signal pushed(body: RigidBody3D, impulse: float)     ## it ran into a dynamic body and pushed it

const OPTIONS: Array = ["rig", "rig_params", "mode", "position", "facing", "name", "group", "walk_speed", "run_speed", "accel",
	"turn_rate", "skate_speed", "skate_accel", "skate_lateral_grip", "skate_turn_rate", "skate_brake", "jump_speed",
	"body_mass", "push_strength", "sole_material", "blade_material"]

var rig: Node3D
var mode: StringName = &"walk"         ## &"walk" or &"skate"
var walk_speed: float = 2.3
var run_speed: float = 6.0
var accel: float = 28.0                ## m/s2 on a surface with friction 1; scaled by the grip under the feet
var turn_rate: float = 10.0            ## rad/s, walking
var skate_speed: float = 9.5           ## top speed under thrust
var skate_accel: float = 6.5           ## m/s2 of thrust along the facing
var skate_lateral_grip: float = 2.2    ## 1/s: how quickly sideways slip dies; low = long drifts
var skate_turn_rate: float = 2.8       ## rad/s
var skate_brake: float = 9.0           ## m/s2 with `brake()`
var jump_speed: float = 4.5
var body_mass: float = 80.0            ## used when pushing dynamic bodies
var push_strength: float = 1.0
var sole_material: String = "rubber"   ## walking: pair law with the surface gives the grip
var blade_material: String = "steel"   ## skating: pair law with the surface gives the glide
var surface: String = ""               ## material id under the feet ("" = nothing tagged)
var grounded: bool = false
var _move: Vector3 = Vector3.ZERO
var _run: bool = false
var _brake: bool = false
var _jump: bool = false
var _frame: int = 0
var _metrics: Dictionary = {}


## Options: rig (a rig node; default: TLRigs when installed, else the stand-in), rig_params, mode, position,
## facing (radians about y), name, group, and any tuning variable of this class.
static func create(opts: Dictionary = {}) -> TLBiped:
	TLContext.require("biped", "TLBiped")
	var b: TLBiped = TLBiped.new()
	for k: String in opts.keys():
		if not OPTIONS.has(k):
			push_error("TLBiped.create: unknown option '%s' (options: %s)" % [k, ", ".join(PackedStringArray(OPTIONS))])
		elif not ["rig", "rig_params", "mode", "position", "facing", "name", "group"].has(k):
			b.set(k, opts[k])
	var given: Variant = opts.get("rig")
	if given is Node3D:
		var problems: PackedStringArray = TLStandin.check_rig(given as Node3D)
		if problems.is_empty():
			b.rig = given
		else:
			push_error("TLBiped: the rig cannot be used (%s); using the stand-in" % "; ".join(problems))
	if b.rig == null:
		# P12: the rig is built in the controller's mode (walk or skate) at once; built in walk and told "skate" at
		# `_ready` it rebuilt its whole skinned mesh for the helmet on the main thread (about 50 ms a skater)
		var rp: Dictionary = (opts["rig_params"] as Dictionary).duplicate() if typeof(opts.get("rig_params")) == TYPE_DICTIONARY else {}
		var md: String = str(opts.get("mode", "walk"))
		if not rp.has("mode") and (md == "walk" or md == "skate"):
			rp["mode"] = md
		b.rig = TLStandin.rig(&"biped", rp)
	b._metrics = b.rig.call("metrics")
	var h: float = float(b._metrics.get("height", 1.8))
	var r: float = float(b._metrics.get("radius", 0.3))
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = r
	cap.height = maxf(h, r * 2.0)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	b.add_child(cs)
	b.add_child(b.rig)
	b.floor_snap_length = 0.25
	if opts.has("position"):
		b.position = opts["position"]
	if opts.has("facing"):
		b.rotation.y = float(opts["facing"])
	if opts.has("name"):
		b.name = str(opts["name"])
	if opts.has("group"):
		b.add_to_group(str(opts["group"]))
	b.mode = StringName(str(opts.get("mode", "walk")))
	return b


## The rig hears from the controller only once both are in the scene tree (a skeleton posed outside the tree
## stops updating): the mode is sent here, `tick` and `set_locomotion` only from `_physics_process`.
func _ready() -> void:
	if rig != null:
		rig.call("set_param", &"mode", mode)


## The intent for this frame: a world-space direction (y ignored), length 0..1. Call it every frame; zero = stop.
func move(direction: Vector3, run: bool = false) -> void:
	_move = Vector3(direction.x, 0.0, direction.z).limit_length(1.0)
	_run = run


func brake(on: bool = true) -> void:
	_brake = on


## Jumps on the next frame if it stands on something.
func jump() -> void:
	_jump = true


func set_mode(mode_: StringName) -> void:
	if mode_ != mode:
		mode = mode_
		if rig != null and is_inside_tree():
			rig.call("set_param", &"mode", mode)
		mode_changed.emit(mode)


## Reads four (or more) declared actions and moves: map keys left, right, forward, back, and optionally run, brake,
## jump. `view` turns the stick into world space (pass an orbit camera's `yaw_basis()` for camera-relative control).
func drive_from_input(input: TLInput, map: Dictionary, view: Basis = Basis.IDENTITY) -> void:
	var v: Vector2 = input.vector(map["left"], map["right"], map["forward"], map["back"])
	move(view * Vector3(v.x, 0.0, v.y), map.has("run") and input.pressed(map["run"]))
	if map.has("brake"):
		brake(input.pressed(map["brake"]))
	if map.has("jump") and input.just_pressed(map["jump"]):
		jump()


## Unit vector the body faces (its -z).
func forward() -> Vector3:
	return -global_transform.basis.z


func speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Puts the character somewhere, at rest.
func place(at: Vector3, facing: float = 0.0) -> void:
	global_position = at
	rotation.y = facing
	velocity = Vector3.ZERO


var _ctx: TLContext = null


func _physics_process(delta: float) -> void:
	_frame += 1
	grounded = is_on_floor()
	var under: Dictionary = TLLaws.surface_under(self, global_position + Vector3.UP * 0.2, 0.6, [get_rid()])
	surface = str(under.get("material", "")) if under.get("hit", false) else ""
	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if mode == &"skate":
		var glide_mu: float = float(TLLaws.pair(blade_material, surface)["friction"]) if not surface.is_empty() else 0.3
		var fwd: Vector3 = forward()
		fwd.y = 0.0
		fwd = fwd.normalized()
		if _move.length() > 0.05:
			var want: float = atan2(-_move.x, -_move.z)
			rotation.y = rotate_toward(rotation.y, want, skate_turn_rate * delta)
			fwd = -global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
		if grounded:
			var along: float = flat.dot(fwd)
			var side: Vector3 = flat - fwd * along
			if _move.length() > 0.05 and not _brake and along < skate_speed:
				along = minf(skate_speed, along + skate_accel * _move.length() * delta)
			var drag: float = glide_mu * 9.8 + (skate_brake if _brake else 0.0)
			along = move_toward(along, 0.0, drag * delta)
			var side_kill: float = skate_lateral_grip + (skate_brake * 0.5 if _brake else 0.0)
			side = side * maxf(0.0, 1.0 - side_kill * delta)
			flat = fwd * along + side
	else:
		var grip: float = 1.0
		if not surface.is_empty():
			grip = clampf(float(TLLaws.pair(sole_material, surface)["friction"]), 0.03, 1.0)
		var target: Vector3 = Vector3.ZERO if _brake else _move * (run_speed if _run else walk_speed)
		if grounded:
			flat = flat.move_toward(target, accel * grip * delta)
		else:
			flat = flat.move_toward(target, accel * 0.1 * delta)
		if _move.length() > 0.05:
			rotation.y = rotate_toward(rotation.y, atan2(-_move.x, -_move.z), turn_rate * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if grounded:
		if _jump:
			velocity.y = jump_speed
	else:
		velocity.y -= 9.8 * delta
	_jump = false
	var before: Vector3 = velocity
	move_and_slide()
	for i: int in get_slide_collision_count():
		var col: KinematicCollision3D = get_slide_collision(i)
		var other: Object = col.get_collider()
		if other is RigidBody3D:
			var rb: RigidBody3D = other
			var closing: float = (before - rb.linear_velocity).dot(-col.get_normal())
			if closing > 0.05:
				var impulse: float = closing * minf(body_mass, rb.mass) * push_strength
				rb.apply_impulse(-col.get_normal() * impulse, col.get_position() - rb.global_position)
				pushed.emit(rb, impulse)
				TLDamage.report(rb, impulse, self)
	if rig != null:
		rig.call("set_locomotion", global_transform.basis.inverse() * velocity, is_on_floor())
		if _ctx == null:
			_ctx = TLContext.of(self)        # N2: the pack this biped belongs to, not "the pack of the process"
		rig.call("tick", _ctx.frame if _ctx != null else _frame)
