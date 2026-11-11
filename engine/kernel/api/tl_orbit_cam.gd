class_name TLOrbitCam
extends Camera3D
## Orbits a target: yaw is free, pitch is held to 30..60 degrees looking down, distance to a range.
## Capability: `camera`. Make one with `ctx.cameras.orbit(target, {distance = 6.5})`.
## Drive it with `orbit_by()` / `zoom_by()`, or bind input actions with `bind_actions()`.
## N1: a deliberate lens (50 degrees instead of the engine's 75) and smoothing: the camera eases toward the place
## that `yaw`, `pitch`, `distance` and the target ask for (`smooth` share per frame). `yaw`, `pitch`, `distance` and
## `yaw_basis()` themselves are never smoothed, so camera-relative movement reads exactly what it read before.

const PITCH_MIN: float = 30.0
const PITCH_MAX: float = 60.0

var target: Node3D
var yaw: float = 0.0             ## degrees
var pitch: float = 35.0          ## degrees looking down, clamped to 30..60
var distance: float = 6.5
var distance_min: float = 4.0
var distance_max: float = 12.0
var look_height: float = 1.2
var yaw_rate: float = 2.0        ## degrees per frame at full action strength
var pitch_rate: float = 1.0
var zoom_rate: float = 0.1       ## metres per frame
var smooth: float = 0.25         ## 0..1 share of the remaining way covered each frame (1 = rigid, as before N1)
var _focus: Vector3 = Vector3.ZERO     # what is drawn: eased copies of the target point, yaw, pitch and distance
var _yaw_s: float = 0.0
var _pitch_s: float = 35.0
var _dist_s: float = 6.5
var _input: TLInput
var _bind: Dictionary = {}
var _door: TLInput               # the pack's ctx.input (the pointer's actions), found on the first frame


func setup(target_: Node3D, opts: Dictionary = {}) -> void:
	target = target_
	fov = 50.0
	for k: String in opts.keys():
		if k in ["yaw", "pitch", "distance", "distance_min", "distance_max", "look_height", "yaw_rate", "pitch_rate", "zoom_rate", "fov", "smooth"]:
			set(k, opts[k])
		else:
			push_error("TLOrbitCam: unknown option '%s'" % k)
	far = 2000.0
	pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
	distance = clampf(distance, distance_min, distance_max)
	snap()


## Puts the camera where `yaw`, `pitch`, `distance` and the target ask at once (after a teleport or a cut).
func snap() -> void:
	_yaw_s = yaw
	_pitch_s = pitch
	_dist_s = distance
	if is_instance_valid(target) and target.is_inside_tree():
		_focus = target.global_position + Vector3.UP * look_height
	_place()


## Turns the camera: degrees of yaw and pitch. Pitch never leaves 30..60.
func orbit_by(yaw_degrees: float, pitch_degrees: float) -> void:
	yaw = wrapf(yaw + yaw_degrees, -180.0, 180.0)
	pitch = clampf(pitch + pitch_degrees, PITCH_MIN, PITCH_MAX)


func zoom_by(metres: float) -> void:
	distance = clampf(distance + metres, distance_min, distance_max)


## Binds declared input actions: keys `yaw_left`, `yaw_right`, `pitch_up`, `pitch_down`, `zoom_in`, `zoom_out`
## (each optional) to action names. The camera then reads them every frame through `ctx.input`.
func bind_actions(input: TLInput, actions: Dictionary) -> void:
	_input = input
	_bind = actions


## The yaw basis: use it to make movement camera-relative (`cam.yaw_basis() * Vector3(x, 0, z)`).
func yaw_basis() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw))


func _strength(key: String) -> float:
	return _input.strength(_bind[key]) if _bind.has(key) else 0.0


func _place() -> void:
	if not is_instance_valid(target) or not target.is_inside_tree() or not is_inside_tree():
		return
	var at: Vector3 = _focus
	var pr: float = deg_to_rad(_pitch_s)
	var yr: float = deg_to_rad(_yaw_s)
	global_position = at + Vector3(sin(yr) * cos(pr), sin(pr), cos(yr) * cos(pr)) * _dist_s
	look_at(at, Vector3.UP)


func _physics_process(_delta: float) -> void:
	# P7: the mouse comes through ctx.input like every device (TLInput.LOOK_X, LOOK_Y, ZOOM: latched once per frame and
	# part of the input record). The camera on screen turns 0.2 degrees per pixel of a right-button drag (0.15 of
	# pitch) and moves 0.4 m per wheel notch, as it did when it read the mouse itself.
	if _door == null:
		var ctx: TLContext = TLContext.of(self)
		_door = ctx.input if ctx != null else null
	if _door != null and current:
		var look: Vector2 = Vector2(_door.strength(TLInput.LOOK_X), _door.strength(TLInput.LOOK_Y))
		var wheel: float = _door.strength(TLInput.ZOOM)
		if look != Vector2.ZERO:
			orbit_by(-look.x * 0.2, look.y * 0.15)
		if wheel != 0.0:
			zoom_by(0.4 * wheel)
	if _input != null:
		orbit_by((_strength("yaw_right") - _strength("yaw_left")) * yaw_rate,
			(_strength("pitch_up") - _strength("pitch_down")) * pitch_rate)
		zoom_by((_strength("zoom_out") - _strength("zoom_in")) * zoom_rate)
	if is_instance_valid(target) and target.is_inside_tree():
		var s: float = clampf(smooth, 0.01, 1.0)
		_focus = _focus.lerp(target.global_position + Vector3.UP * look_height, s)
		_yaw_s = rad_to_deg(lerp_angle(deg_to_rad(_yaw_s), deg_to_rad(yaw), s))
		_pitch_s = lerpf(_pitch_s, pitch, s)
		_dist_s = lerpf(_dist_s, distance, s)
	_place()
