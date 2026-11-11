class_name TLVehicle
extends RigidBody3D
## A four-wheeled vehicle on raycast wheels. Sizes come from the rig's `metrics()`; grip comes from the surface
## under each wheel (law tables: rubber against whatever is there). The controller owns the body and drives the rig
## through the duck-typed calls of KIT-RIG-STYLE.md; without a rig it builds the kernel's stand-in.
## Capability: `vehicle`.
##
##   var car := TLVehicle.create({position = Vector3(0, 0.5, 0)})
##   ctx.root.add_child(car)
##   func _pack_tick(frame):
##       car.set_controls(ctx.input.axis(&"left", &"right"), ctx.input.strength(&"gas"), ctx.input.strength(&"brake"),
##           ctx.input.pressed(&"nitro"))
##
## Forward is -z. Wheel order everywhere: FL, FR, RL, RR.

signal nitro_started()
signal nitro_ended()

const OPTIONS: Array = ["rig", "rig_params", "position", "facing", "name", "group", "engine_force", "brake_force", "top_speed",
	"reverse_speed", "max_steer_degrees", "min_steer_degrees", "lateral_grip", "suspension_travel", "suspension_damping",
	"nitro_force", "nitro_frames", "nitro_recharge_frames", "drive", "tyre_material", "body_material", "air_drag",
	"rolling_resistance", "anti_roll"]

var rig: Node3D
var engine_force: float = 9000.0        ## N at full throttle, shared by the driven wheels
var brake_force: float = 16000.0        ## N at full brake, shared by all wheels
var top_speed: float = 42.0             ## m/s: engine force fades to zero here
var reverse_speed: float = 9.0
var max_steer_degrees: float = 30.0     ## at a standstill
var min_steer_degrees: float = 8.0      ## at top speed
var lateral_grip: float = 1.0           ## multiplies the sideways grip the surface allows
var suspension_travel: float = 0.3      ## metres
var suspension_damping: float = 0.55    ## damping ratio
var nitro_force: float = 9000.0         ## extra N while the boost burns
var nitro_frames: int = 150             ## frames of boost in a full tank
var nitro_recharge_frames: int = 900    ## frames to refill
var drive: StringName = &"rear"         ## &"rear", &"front" or &"all"
var tyre_material: String = "rubber"
var body_material: String = "steel"
var air_drag: float = 0.45              ## N per (m/s)^2
var rolling_resistance: float = 0.012   ## share of the wheel load
var anti_roll: float = 0.55             ## 0..1: how far up from the road toward the centre of mass tyre forces act

var steer: float = 0.0                  ## -1 (left) .. 1 (right), as last set
var throttle: float = 0.0               ## -1 (reverse) .. 1
var brake_input: float = 0.0            ## 0..1
var nitro_charge: float = 1.0           ## 0..1
var nitro_active: bool = false
var wheel_surface: PackedStringArray = PackedStringArray(["", "", "", ""])   ## material id under each wheel
var wheel_grounded: Array = [false, false, false, false]
var wheel_compression: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var contact: TLContact
var _nitro_wanted: bool = false
var _metrics: Dictionary = {}
var _mounts: Array = []
var _spring_k: float = 0.0
var _spring_c: float = 0.0
var _prev_len: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _wheel_spin: float = 0.0
var _frame: int = 0


## Options: rig (default: TLRigs when installed, else the stand-in), rig_params, position, facing (radians about y),
## name, group, and any tuning variable of this class.
static func create(opts: Dictionary = {}) -> TLVehicle:
	TLContext.require("vehicle", "TLVehicle")
	var v: TLVehicle = TLVehicle.new()
	for k: String in opts.keys():
		if not OPTIONS.has(k):
			push_error("TLVehicle.create: unknown option '%s' (options: %s)" % [k, ", ".join(PackedStringArray(OPTIONS))])
		elif not ["rig", "rig_params", "position", "facing", "name", "group"].has(k):
			v.set(k, StringName(str(opts[k])) if k == "drive" else opts[k])
	var given: Variant = opts.get("rig")
	if given is Node3D:
		var problems: PackedStringArray = TLStandin.check_rig(given as Node3D)
		if problems.is_empty():
			v.rig = given
		else:
			push_error("TLVehicle: the rig cannot be used (%s); using the stand-in" % "; ".join(problems))
	if v.rig == null:
		v.rig = TLStandin.rig(&"vehicle", opts.get("rig_params", {}))
	v._metrics = v.rig.call("metrics")
	var m: Dictionary = v._metrics
	for need: String in ["wheelbase", "track", "wheel_radius", "ride_height", "length", "width", "mass_hint"]:
		if not m.has(need):
			push_error("TLVehicle: the rig's metrics() has no '%s'" % need)
	var wr: float = float(m.get("wheel_radius", 0.34))
	var ride: float = float(m.get("ride_height", 0.45))
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(float(m.get("width", 1.8)), 0.6, float(m.get("length", 4.2)))
	cs.shape = box
	cs.position.y = ride + 0.3
	v.add_child(cs)
	v.add_child(v.rig)
	v.mass = float(m.get("mass_hint", 1100.0))
	v.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	v.center_of_mass = Vector3(0.0, ride * 0.75, 0.0)
	v.can_sleep = false
	v.angular_damp = 0.4
	var half_t: float = float(m.get("track", 1.6)) * 0.5
	var half_w: float = float(m.get("wheelbase", 2.6)) * 0.5
	var top: float = wr + v.suspension_travel * 0.5
	v._mounts = [Vector3(-half_t, top, -half_w), Vector3(half_t, top, -half_w), Vector3(-half_t, top, half_w), Vector3(half_t, top, half_w)]
	# at rest each spring carries a quarter of the weight at half travel
	v._spring_k = v.mass * 9.8 / (2.0 * v.suspension_travel)
	v._spring_c = 2.0 * v.suspension_damping * sqrt(v._spring_k * v.mass * 0.25)
	if opts.has("position"):
		v.position = opts["position"]
	if opts.has("facing"):
		v.rotation.y = float(opts["facing"])
	if opts.has("name"):
		v.name = str(opts["name"])
	if opts.has("group"):
		v.add_to_group(str(opts["group"]))
	TLLaws.apply(v, v.body_material)
	v.contact = TLContact.new()
	v.contact.name = "TLContact"
	v.add_child(v.contact)
	return v


## The driver's intent: steer -1 (left) .. 1 (right), throttle -1 (reverse) .. 1, brake 0..1, nitro held or not.
## A player and an AI driver use this same call. It holds until the next call.
func set_controls(steer_: float, throttle_: float, brake_: float = 0.0, nitro: bool = false) -> void:
	steer = clampf(steer_, -1.0, 1.0)
	throttle = clampf(throttle_, -1.0, 1.0)
	brake_input = clampf(brake_, 0.0, 1.0)
	_nitro_wanted = nitro


## Reads declared actions: map keys left, right, gas, brake, and optionally reverse and nitro.
func drive_from_input(input: TLInput, map: Dictionary) -> void:
	var t: float = input.strength(map["gas"])
	if map.has("reverse"):
		t -= input.strength(map["reverse"])
	set_controls(input.axis(map["left"], map["right"]), t, input.strength(map["brake"]),
		map.has("nitro") and input.pressed(map["nitro"]))


func forward() -> Vector3:
	return -global_transform.basis.z


## Speed along the nose in m/s (negative when rolling backwards).
func forward_speed() -> float:
	return linear_velocity.dot(forward())


func speed() -> float:
	return linear_velocity.length()


func speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func grounded_wheels() -> int:
	var n: int = 0
	for g: bool in wheel_grounded:
		if g:
			n += 1
	return n


## Puts the vehicle somewhere, at rest.
func place(at: Vector3, facing: float = 0.0) -> void:
	var xf: Transform3D = Transform3D(Basis(Vector3.UP, facing), at)
	global_transform = xf
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if is_inside_tree():
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)


var _ctx: TLContext = null


func _physics_process(delta: float) -> void:
	_frame += 1
	var wr: float = float(_metrics.get("wheel_radius", 0.34))
	var xf: Transform3D = global_transform
	var up: Vector3 = xf.basis.y.normalized()
	var fspeed: float = forward_speed()
	# nitro
	var burning: bool = _nitro_wanted and nitro_charge > 0.0 and throttle > 0.0
	if burning:
		nitro_charge = maxf(0.0, nitro_charge - 1.0 / float(maxi(1, nitro_frames)))
	elif not _nitro_wanted:
		nitro_charge = minf(1.0, nitro_charge + 1.0 / float(maxi(1, nitro_recharge_frames)))
	if burning != nitro_active:
		nitro_active = burning
		if burning:
			nitro_started.emit()
		else:
			nitro_ended.emit()
	var speed_share: float = clampf(absf(fspeed) / maxf(1.0, top_speed), 0.0, 1.0)
	var steer_angle: float = -steer * deg_to_rad(lerpf(max_steer_degrees, min_steer_degrees, speed_share))
	var driven: Array = [drive != &"rear", drive != &"rear", drive != &"front", drive != &"front"]
	var n_driven: float = 4.0 if drive == &"all" else 2.0
	if _ctx == null:
		_ctx = TLContext.of(self)            # N2: the pack this vehicle belongs to
	var space: PhysicsDirectSpaceState3D = TLContext.space_state_of(self, _ctx)   # N2: the pack's own space
	var ray_len: float = suspension_travel + wr
	var com_world: Vector3 = xf * center_of_mass
	for i: int in 4:
		var from: Vector3 = xf * (_mounts[i] as Vector3)
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - up * ray_len)
		q.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			wheel_grounded[i] = false
			wheel_surface[i] = ""
			wheel_compression[i] = 0.0
			_prev_len[i] = suspension_travel
			continue
		wheel_grounded[i] = true
		var hp: Vector3 = hit["position"]
		var n: Vector3 = hit["normal"]
		var mat: String = TLLaws.material_of(hit["collider"])
		wheel_surface[i] = mat
		var mu: float = float(TLLaws.pair(tyre_material, mat)["friction"]) if not mat.is_empty() else 0.9
		var length: float = clampf(from.distance_to(hp) - wr, 0.0, suspension_travel)
		var comp: float = suspension_travel - length
		wheel_compression[i] = comp
		var rate: float = (float(_prev_len[i]) - length) / delta
		_prev_len[i] = length
		var wheel_load: float = maxf(0.0, _spring_k * comp + _spring_c * rate)
		wheel_load = minf(wheel_load, mass * 9.8 * 2.5)
		var r: Vector3 = hp - global_position
		apply_force(n * wheel_load, r)
		# tyre forces in the ground plane
		var wheel_fwd: Vector3 = -xf.basis.z
		if i < 2:
			wheel_fwd = wheel_fwd.rotated(up, steer_angle)
		wheel_fwd = (wheel_fwd - n * wheel_fwd.dot(n)).normalized()
		var wheel_side: Vector3 = wheel_fwd.cross(n).normalized()
		var vp: Vector3 = linear_velocity + angular_velocity.cross(hp - com_world)
		var v_f: float = vp.dot(wheel_fwd)
		var v_s: float = vp.dot(wheel_side)
		var quarter: float = mass * 0.25
		var f_long: float = 0.0
		if driven[i]:
			if throttle > 0.0 and fspeed < top_speed:
				f_long += throttle * engine_force / n_driven * (1.0 - clampf(fspeed / top_speed, 0.0, 1.0) * 0.85)
			elif throttle < 0.0 and fspeed > -reverse_speed:
				f_long += throttle * engine_force * 0.6 / n_driven
			if nitro_active:
				f_long += nitro_force / n_driven
		if brake_input > 0.0:
			f_long -= signf(v_f) * minf(brake_input * brake_force * 0.25, absf(v_f) * quarter / delta)
		f_long -= signf(v_f) * minf(rolling_resistance * wheel_load, absf(v_f) * quarter / delta)
		var f_lat: float = -v_s * quarter / delta * 0.45
		var limit: float = mu * wheel_load
		var lat_limit: float = limit * lateral_grip
		f_lat = clampf(f_lat, -lat_limit, lat_limit)
		var total: float = sqrt(f_long * f_long + f_lat * f_lat)
		if total > limit and total > 0.0:
			var scale_: float = limit / total
			f_long *= scale_
			f_lat *= scale_
		var act: Vector3 = r + up * (com_world - hp).dot(up) * anti_roll
		apply_force(wheel_fwd * f_long + wheel_side * f_lat, act)
	var v: Vector3 = linear_velocity
	if v.length() > 0.1:
		apply_central_force(-v.normalized() * air_drag * v.length_squared())
	_wheel_spin = fspeed / maxf(0.05, wr)
	if rig != null:
		rig.call("set_param", &"steer", -steer)      # the rig contract counts + as left (RIGS.md); the controller + as right
		rig.call("set_param", &"throttle", maxf(0.0, throttle))
		rig.call("set_param", &"brake", brake_input)
		rig.call("set_param", &"wheel_spin", _wheel_spin)
		rig.call("set_param", &"suspension", [wheel_compression[0] - suspension_travel * 0.5, wheel_compression[1] - suspension_travel * 0.5,
			wheel_compression[2] - suspension_travel * 0.5, wheel_compression[3] - suspension_travel * 0.5])
		rig.call("set_param", &"nitro", 1.0 if nitro_active else 0.0)
		rig.call("tick", _ctx.frame if _ctx != null else _frame)
