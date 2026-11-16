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
signal downed()                                      ## K2: `down()` put him on the ground
signal got_up()                                      ## K2: he stands again and takes `move` again

const OPTIONS: Array = ["rig", "rig_params", "mode", "position", "facing", "name", "group", "walk_speed", "run_speed", "accel",
	"turn_rate", "skate_speed", "skate_accel", "skate_lateral_grip", "skate_turn_rate", "skate_brake", "jump_speed",
	"body_mass", "push_strength", "sole_material", "blade_material", "get_up_frames", "body_scale"]

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
var get_up_frames: int = 24            ## K2: frames he takes to rise after `down()` (still ignoring `move`)
var _shape: CollisionShape3D = null
var _body_scale: float = 1.0
var _down_left: int = 0                # K2: frames still lying
var _rise_left: int = 0                # K2: frames still rising
var _stumble_left: int = 0
var _stumble_frames: int = 0
var _stumble_lean: float = 0.0
var _lying_by_tip: bool = false        # the rig has no fall clip (the kernel's stand-in): the rig node is tipped over
var _on_held: bool = false             # K2: the last step stood on a held ball
var _was_on_held: bool = false
var _kept_platform: Array = []         # the platform settings to give back when he steps off it


## Options: rig (a rig node; default: TLRigs when installed, else the stand-in), rig_params, mode, position,
## facing (radians about y), name, group, and any tuning variable of this class.
static func create(opts: Dictionary = {}) -> TLBiped:
	TLContext.require("biped", "TLBiped")
	var b: TLBiped = TLBiped.new()
	for k: String in opts.keys():
		if not OPTIONS.has(k):
			push_error("TLBiped.create: unknown option '%s' (options: %s)" % [k, ", ".join(PackedStringArray(OPTIONS))])
		elif not ["rig", "rig_params", "mode", "position", "facing", "name", "group", "body_scale"].has(k):
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
	b._shape = cs
	if opts.has("body_scale"):
		b.set_body_scale(float(opts["body_scale"]))
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
var _feet_query: PhysicsShapeQueryParameters3D = null


## K2, K3. True when a ball (TLBall: held, or loose and moving: a puck just shot or poked from under him) touches the
## bottom of the body. K3: with a body of 0.66 m the rounded bottom reaches a puck 0.18 m from his centre (0.12 m at 0.3 m).
func _held_under_feet() -> bool:
	if _feet_query == null:
		var s: SphereShape3D = SphereShape3D.new()
		s.radius = _body_radius() + 0.05
		_feet_query = PhysicsShapeQueryParameters3D.new()
		_feet_query.shape = s
		_feet_query.exclude = [get_rid()]
		_feet_query.collide_with_areas = false
	(_feet_query.shape as SphereShape3D).radius = _body_radius() + 0.05
	_feet_query.transform = Transform3D(Basis.IDENTITY, global_position + up_direction * _body_radius())
	# K6: the pack's own physics space (a world gives every pack its own; the viewport's space is empty there)
	for hit: Dictionary in TLContext.space_state_of(self).intersect_shape(_feet_query, 8):
		var o: Object = hit.get("collider")
		if o is TLBall:
			return true
	return false


func _body_radius() -> float:
	return body_radius()


# ---- K2: down, shove, stumble, a body sized with the rig ------------------------------------------------------------

## Puts him on the ground for `frames` physics frames, then he rises over `get_up_frames`; all that time `move`,
## `brake` and `jump` are ignored (he slides to a stop with the brake on). The rig plays its `fall` clip (it holds,
## flat on the front) and blends back to its locomotion while he rises; a rig without a fall clip (the kernel's
## stand-in) is tipped over flat and tipped back. Called while down, it keeps the longer of the two; while rising,
## he goes down again. `downed` fires when he goes down from standing, `got_up` when he stands again.
func down(frames: int) -> void:
	if frames <= 0:
		return
	var was: bool = is_down()
	var rising: bool = _rise_left > 0
	_down_left = maxi(_down_left, frames)
	_rise_left = 0
	if _stumble_left > 0:
		_stumble_left = 0
		_rig_param(&"lean", 0.0)
	if not was or rising:
		if _rig_has(&"fall"):
			rig.call("play", &"fall", 0.15)
		elif rig != null:
			_lying_by_tip = true
			rig.rotation.x = -PI * 0.5
	if not was:
		downed.emit()


## True from `down()` until he stands again (lying and rising).
func is_down() -> bool:
	return _down_left > 0 or _rise_left > 0


## Frames until he takes `move` again (0 when he stands).
func down_frames_left() -> int:
	return _down_left + (get_up_frames if _down_left > 0 else _rise_left)


## Moves him without a fall: `impulse` in N s, divided by `body_mass` and added to his velocity (also while down).
func shove(impulse: Vector3) -> void:
	velocity += impulse / maxf(body_mass, 1.0)


## A short loss of control for `frames`: a third of the intent reaches the legs, no brake, and the rig leans to the
## side (`lean`, -1 left .. 1 right, fading to 0); the TLRigs biped shows the lean, the stand-in shows nothing.
## Ignored while he is down.
func stumble(frames: int, lean: float = 0.7) -> void:
	if is_down() or frames <= 0:
		return
	_stumble_left = frames
	_stumble_frames = frames
	_stumble_lean = clampf(lean, -1.0, 1.0)
	_rig_param(&"lean", _stumble_lean)


func is_stumbling() -> bool:
	return _stumble_left > 0


## Sizes the collision body with the rig: the capsule is the rig's metrics (radius, height at rig scale 1) times
## `scale_`. Call it with the scale you give the rig (`rig.scale = Vector3(2.2, 2.2, 2.2)`; `set_body_scale(2.2)`).
## 1.0 = the body a biped always had. Also the create option `body_scale`.
func set_body_scale(scale_: float) -> void:
	_body_scale = clampf(scale_, 0.1, 10.0)
	if _shape == null:
		return
	var h: float = float(_metrics.get("height", 1.8)) * _body_scale
	var r: float = float(_metrics.get("radius", 0.3)) * _body_scale
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = r
	cap.height = maxf(h, r * 2.0)
	_shape.shape = cap
	_shape.position.y = cap.height * 0.5


## The radius of the collision body in metres (the rig's radius times the body scale).
func body_radius() -> float:
	if _shape != null and _shape.shape is CapsuleShape3D:
		return (_shape.shape as CapsuleShape3D).radius
	return 0.3


## Kernel side: the state of down and stumble, for the state hash ("" while he stands and does not stumble).
func _down_text() -> String:
	if _down_left <= 0 and _rise_left <= 0 and _stumble_left <= 0:
		return ""
	return "%d,%d,%d" % [_down_left, _rise_left, _stumble_left]


func _rig_has(clip: StringName) -> bool:
	if rig == null or rig is TLStandinRig or not rig.has_method("clips"):
		return false
	return (rig.call("clips") as PackedStringArray).has(String(clip))


func _rig_param(p: StringName, v: Variant) -> void:
	if rig != null and rig.has_method("set_param"):
		rig.call("set_param", p, v)


## One frame of down / rise / stumble, after the step.
func _step_down() -> void:
	if _down_left > 0:
		_down_left -= 1
		if _down_left == 0:
			_rise_left = maxi(get_up_frames, 1)
			if _rig_has(&"fall"):
				rig.call("play", &"", float(_rise_left) / 60.0)    # the rig blends from lying back to its locomotion
	elif _rise_left > 0:
		_rise_left -= 1
		if _lying_by_tip and rig != null:
			rig.rotation.x = -PI * 0.5 * float(_rise_left) / float(maxi(get_up_frames, 1))
		if _rise_left == 0:
			_lying_by_tip = false
			got_up.emit()
	if _stumble_left > 0:
		_stumble_left -= 1
		_rig_param(&"lean", _stumble_lean * float(_stumble_left) / float(maxi(_stumble_frames, 1)))


func _physics_process(delta: float) -> void:
	# K2: down (lying or rising): no intent, the brake on; stumbling: a third of the intent, no brake
	var mv: Vector3 = Vector3.ZERO if is_down() else (_move * 0.3 if _stumble_left > 0 else _move)
	var brk: bool = true if is_down() else (false if _stumble_left > 0 else _brake)
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
		if mv.length() > 0.05:
			var want: float = atan2(-mv.x, -mv.z)
			rotation.y = rotate_toward(rotation.y, want, skate_turn_rate * delta)
			fwd = -global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
		if grounded:
			var along: float = flat.dot(fwd)
			var side: Vector3 = flat - fwd * along
			if mv.length() > 0.05 and not brk and along < skate_speed:
				along = minf(skate_speed, along + skate_accel * mv.length() * delta)
			var drag: float = glide_mu * 9.8 + (skate_brake if brk else 0.0)
			along = move_toward(along, 0.0, drag * delta)
			var side_kill: float = skate_lateral_grip + (skate_brake * 0.5 if brk else 0.0)
			side = side * maxf(0.0, 1.0 - side_kill * delta)
			flat = fwd * along + side
	else:
		var grip: float = 1.0
		if not surface.is_empty():
			grip = clampf(float(TLLaws.pair(sole_material, surface)["friction"]), 0.03, 1.0)
		var target: Vector3 = Vector3.ZERO if brk else mv * (run_speed if _run else walk_speed)
		if grounded:
			flat = flat.move_toward(target, accel * grip * delta)
		else:
			flat = flat.move_toward(target, accel * 0.1 * delta)
		if mv.length() > 0.05:
			rotation.y = rotate_toward(rotation.y, atan2(-mv.x, -mv.z), turn_rate * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if grounded:
		if _jump and not is_down():
			velocity.y = jump_speed
	else:
		velocity.y -= 9.8 * delta
	_jump = false
	var before: Vector3 = velocity
	# K2, K3: a ball (TLBall) is never a moving floor: held (kinematic, moved by its holder every frame) or loose (a puck
	# released, shot or poked from under him, spinning: its contact velocity reached 88 m/s in the hockey pack). While he stood
	# on one at the last step, its motion is not followed and leaving it adds nothing; the pack's own platform settings
	# come back when he stands on anything else.
	if _on_held != _was_on_held:
		if _on_held:
			_kept_platform = [platform_floor_layers, platform_on_leave]
			platform_floor_layers = 0
			platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
		else:
			platform_floor_layers = int(_kept_platform[0])
			platform_on_leave = int(_kept_platform[1]) as CharacterBody3D.PlatformOnLeave
		_was_on_held = _on_held
	move_and_slide()
	# a moving floor under him (or one already left out): is it a ball? (the floor found by snapping is in no
	# slide collision, so the feet are asked directly; a still floor costs nothing)
	_on_held = (get_platform_velocity().length_squared() > 0.000001 or _was_on_held) and is_on_floor() and _held_under_feet()
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
	if _down_left > 0 or _rise_left > 0 or _stumble_left > 0:
		_step_down()
	if rig != null:
		rig.call("set_locomotion", global_transform.basis.inverse() * velocity, is_on_floor())
		if _ctx == null:
			_ctx = TLContext.of(self)        # N2: the pack this biped belongs to, not "the pack of the process"
		rig.call("tick", _ctx.frame if _ctx != null else _frame)
