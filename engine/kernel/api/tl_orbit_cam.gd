class_name TLOrbitCam
extends Camera3D
## Orbits a target: yaw is free, pitch is held to 30..60 degrees looking down, distance to a range.
## Capability: `camera`. Make one with `ctx.cameras.orbit(target, {distance = 6.5})`.
## Drive it with `orbit_by()` / `zoom_by()`, or bind input actions with `bind_actions()`.

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
var _input: TLInput
var _bind: Dictionary = {}


func setup(target_: Node3D, opts: Dictionary = {}) -> void:
	target = target_
	for k: String in opts.keys():
		if k in ["yaw", "pitch", "distance", "distance_min", "distance_max", "look_height", "yaw_rate", "pitch_rate", "zoom_rate", "fov"]:
			set(k, opts[k])
		else:
			push_error("TLOrbitCam: unknown option '%s'" % k)
	far = 2000.0
	pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
	distance = clampf(distance, distance_min, distance_max)
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


## Interactive play only: drag with the right mouse button to orbit, wheel to zoom. Verify runs never get here.
func _unhandled_input(event: InputEvent) -> void:
	var ctx: TLContext = TLContext.current
	if ctx == null or ctx.input == null or not ctx.input.accept_devices or not current:
		return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_RIGHT:
		orbit_by(-(event as InputEventMouseMotion).relative.x * 0.2, (event as InputEventMouseMotion).relative.y * 0.15)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(-0.4)
		elif (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(0.4)


func _strength(key: String) -> float:
	return _input.strength(_bind[key]) if _bind.has(key) else 0.0


func _place() -> void:
	if not is_instance_valid(target) or not target.is_inside_tree() or not is_inside_tree():
		return
	var at: Vector3 = target.global_position + Vector3.UP * look_height
	var pr: float = deg_to_rad(pitch)
	var yr: float = deg_to_rad(yaw)
	global_position = at + Vector3(sin(yr) * cos(pr), sin(pr), cos(yr) * cos(pr)) * distance
	look_at(at, Vector3.UP)


func _physics_process(_delta: float) -> void:
	if _input != null:
		orbit_by((_strength("yaw_right") - _strength("yaw_left")) * yaw_rate,
			(_strength("pitch_up") - _strength("pitch_down")) * pitch_rate)
		zoom_by((_strength("zoom_out") - _strength("zoom_in")) * zoom_rate)
	_place()
