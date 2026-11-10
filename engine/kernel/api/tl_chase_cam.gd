class_name TLChaseCam
extends Camera3D
## Follows a target from behind and above; frame-counted smoothing (no wall clock). Capability: `camera`.
## Make one with `ctx.cameras.chase(target, {distance = 7.0, height = 3.0})`.

var target: Node3D
var distance: float = 7.0        ## metres behind the target
var height: float = 3.0          ## metres above the target
var look_height: float = 1.0     ## the point looked at, above the target's origin
var stiffness: float = 0.12      ## 0..1 share of the remaining distance covered each frame
var use_velocity: bool = false   ## true: stay behind the direction of travel instead of the target's facing
var _heading: Vector3 = Vector3.FORWARD
var _last_pos: Vector3 = Vector3.ZERO


func setup(target_: Node3D, opts: Dictionary = {}) -> void:
	target = target_
	for k: String in opts.keys():
		if k in ["distance", "height", "look_height", "stiffness", "use_velocity", "fov"]:
			set(k, opts[k])
		else:
			push_error("TLChaseCam: unknown option '%s'" % k)
	far = 2000.0
	if is_instance_valid(target) and target.is_inside_tree():
		_last_pos = target.global_position
		_heading = _target_forward()
		global_position = _wanted()
		_aim()


func _target_forward() -> Vector3:
	var f: Vector3 = -target.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else _heading


func _wanted() -> Vector3:
	return target.global_position - _heading * distance + Vector3.UP * height


func _aim() -> void:
	var at: Vector3 = target.global_position + Vector3.UP * look_height
	if global_position.distance_to(at) > 0.01:
		look_at(at, Vector3.UP)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	var want_heading: Vector3 = _target_forward()
	if use_velocity:
		var step: Vector3 = target.global_position - _last_pos
		step.y = 0.0
		if step.length() > 0.02:
			want_heading = step.normalized()
	_last_pos = target.global_position
	_heading = _heading.lerp(want_heading, stiffness).normalized() if _heading.lerp(want_heading, stiffness).length() > 0.001 else want_heading
	global_position = global_position.lerp(_wanted(), stiffness)
	_aim()
