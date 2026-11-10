class_name TLCameras
extends Node
## Cameras: fixed named capture views (what `capture --cam=<name>` renders), a chase camera and an orbit camera.
## The pack reaches it as `ctx.cameras`. Capability: `camera`.

var _views: Dictionary = {}       # name -> Camera3D
var _order: PackedStringArray = PackedStringArray()
var active: Camera3D = null


## A fixed named view. List the name in pack.json `cameras` so the verifier knows it exists.
func add_view(view: StringName, position: Vector3, target: Vector3, fov: float = 60.0) -> Camera3D:
	TLContext.require("camera", "ctx.cameras")
	var cam: Camera3D = _views.get(view) as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "View_" + String(view)
		add_child(cam)
		_register(view, cam)
	cam.fov = fov
	cam.far = 2000.0
	var up: Vector3 = Vector3.UP if absf((target - position).normalized().dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
	cam.look_at_from_position(position, target, up)
	return cam


## A camera that follows `target` from behind (see TLChaseCam for the options). Registered as view `view`.
func chase(target: Node3D, opts: Dictionary = {}, view: StringName = &"chase") -> TLChaseCam:
	TLContext.require("camera", "ctx.cameras")
	var cam: TLChaseCam = TLChaseCam.new()
	cam.name = "Chase_" + String(view)
	add_child(cam)
	cam.setup(target, opts)
	_register(view, cam)
	return cam


## A camera that orbits `target`: free yaw, pitch held to 30..60 degrees (see TLOrbitCam). Registered as view `view`.
func orbit(target: Node3D, opts: Dictionary = {}, view: StringName = &"orbit") -> TLOrbitCam:
	TLContext.require("camera", "ctx.cameras")
	var cam: TLOrbitCam = TLOrbitCam.new()
	cam.name = "Orbit_" + String(view)
	add_child(cam)
	cam.setup(target, opts)
	_register(view, cam)
	return cam


func _register(view: StringName, cam: Camera3D) -> void:
	if not _views.has(view):
		_order.append(String(view))
	_views[view] = cam
	if active == null:
		activate(view)


## Names of every registered view, in registration order.
func views() -> PackedStringArray:
	return _order


func has_view(view: StringName) -> bool:
	return _views.has(view)


func view(view_name: StringName) -> Camera3D:
	return _views.get(view_name) as Camera3D


## Makes a view the one the player (and a capture) sees. Returns false for an unknown name.
func activate(view_name: StringName) -> bool:
	var cam: Camera3D = _views.get(view_name) as Camera3D
	if cam == null:
		push_error("ctx.cameras.activate('%s'): no such view (registered: %s)" % [view_name, ", ".join(_order)])
		return false
	active = cam
	cam.current = true
	return true
