class_name TLCameras
extends Node
## Cameras: fixed named capture views (what `capture --cam=<name>` renders), a chase camera and an orbit camera.
## The pack reaches it as `ctx.cameras`. Capability: `camera`.
## N1: `frame()` sizes a view on a subject, `subject_px()` measures how large a subject is on screen, `shake()` is an
## impact shake. All three are visual only: they move or offset cameras and never read or write simulation state.

var _views: Dictionary = {}       # name -> Camera3D
var _order: PackedStringArray = PackedStringArray()
var active: Camera3D = null
var _subjects: Dictionary = {}    # view name -> the subject last framed in it (for the TL_LOOK_PX measurement)
var _shake_amount: float = 0.0
var _shake_frames: int = 0
var _shake_left: int = 0
var _shake_cam: Camera3D = null
var _tick: int = 0
var _log_px: bool = false
var _log_cam: FileAccess = null


func _ready() -> void:
	_log_px = OS.get_environment("TL_LOOK_PX") != ""
	if OS.get_environment("TL_LOOK_CAM") != "":   # P3: TL_LOOK_CAM=<file>: one line per frame, the active camera's place and aim (motion review)
		_log_cam = FileAccess.open(OS.get_environment("TL_LOOK_CAM"), FileAccess.WRITE)


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
	var pack: TLContext = TLContext.of(self)
	if pack == null or pack.on_stage:
		cam.current = true
	return true


# ------------------------------------------------------------------------------------------------- N1: framing
## Places a view so that `subject` covers `fill` of the frame height (0.05..0.9). Default: the active view; pass a
## view name to frame another one. A chase camera keeps its angle and changes `distance` and `height`; an orbit
## camera changes `distance` (and widens its distance range to hold it); a fixed view moves along its own line of
## sight to the subject's centre and looks at that centre. The subject is remembered as the view's main actor.
## Visual only. Call it after the subject is in the tree (in `_pack_setup`, after the camera was made).
func frame(subject: Node3D, fill: float = 0.35, view_name: StringName = &"") -> void:
	TLContext.require("camera", "ctx.cameras")
	var cam: Camera3D = active if view_name == &"" else _views.get(view_name) as Camera3D
	if cam == null or not is_instance_valid(subject) or not subject.is_inside_tree():
		push_error("ctx.cameras.frame: no such view, or the subject is not in the tree yet")
		return
	for key: Variant in _views:
		if _views[key] == cam:
			_subjects[String(key)] = subject
	fill = clampf(fill, 0.05, 0.9)
	for i: int in 4:       # the covered share is close to 1 / distance; a few rounds settle look_height and perspective
		var now: float = _px(cam, subject, false)
		if now <= 0.0001:
			return
		var ratio: float = clampf(now / fill, 0.25, 4.0)
		if absf(ratio - 1.0) < 0.01:
			break
		if cam is TLChaseCam:
			(cam as TLChaseCam).distance *= ratio
			(cam as TLChaseCam).height *= ratio
			(cam as TLChaseCam).snap()
		elif cam is TLOrbitCam:
			var oc: TLOrbitCam = cam as TLOrbitCam
			var d: float = oc.distance * ratio
			oc.distance_min = minf(oc.distance_min, d)
			oc.distance_max = maxf(oc.distance_max, d)
			oc.distance = d
			oc.snap()
		else:
			var centre: Vector3 = _centre(subject)
			var up: Vector3 = Vector3.UP if absf((centre - cam.global_position).normalized().dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
			cam.look_at_from_position(centre + (cam.global_position - centre) * ratio, centre, up)


## How much of the frame height `subject` covers now in the active view: the height of the screen rectangle around
## its visible meshes, clipped to the frame, as a share of the frame height. 0 when it is off screen or behind the
## camera. 0.08 is a small actor, 0.2 a clear one, 0.35 a portrait.
func subject_px(subject: Node3D) -> float:
	return _px(active, subject, true)


## Names the main actor of a view without moving the view (a fixed view that must keep the whole court in sight).
func set_subject(view_name: StringName, subject: Node3D) -> void:
	if _views.has(view_name) and is_instance_valid(subject):
		_subjects[String(view_name)] = subject


## The main actor of a view: the subject last passed to `frame()` or `set_subject()` for it, or null.
func subject_of(view_name: StringName) -> Node3D:
	var s: Variant = _subjects.get(String(view_name))
	return s as Node3D if is_instance_valid(s) else null


## Impact shake on the active view: `amount` is the largest offset in metres at the camera (0.05 a tap, 0.3 a crash),
## fading to nothing over `frames` physics frames. It offsets the lens (`h_offset`, `v_offset`), never the camera's
## place, and its pattern is a fixed function of the frame count: no clock, no random numbers, no simulation state.
func shake(amount: float, frames: int) -> void:
	TLContext.require("camera", "ctx.cameras")
	if frames <= 0 or amount <= 0.0:
		return
	if _shake_left > 0 and _shake_amount * float(_shake_left) / float(maxi(_shake_frames, 1)) > amount:
		return               # a stronger shake is still running
	_shake_amount = amount
	_shake_frames = frames
	_shake_left = frames


func _physics_process(_delta: float) -> void:
	_tick += 1
	if _shake_cam != null and is_instance_valid(_shake_cam) and (_shake_left <= 0 or _shake_cam != active):
		_shake_cam.h_offset = 0.0
		_shake_cam.v_offset = 0.0
		_shake_cam = null
	if _shake_left > 0 and active != null:
		var k: float = _shake_amount * float(_shake_left) / float(_shake_frames)
		var t: float = float(_shake_frames - _shake_left)
		active.h_offset = k * sin(t * 2.39 + 0.7) * cos(t * 0.83)
		active.v_offset = k * sin(t * 3.17 + 1.9)
		_shake_cam = active
		_shake_left -= 1
	if _log_cam != null and active != null and active.is_inside_tree():
		var fw: Vector3 = -active.global_transform.basis.z
		_log_cam.store_line("[cam] f=%d p=%.4f,%.4f,%.4f d=%.5f,%.5f,%.5f" % [_tick, active.global_position.x, active.global_position.y, active.global_position.z, fw.x, fw.y, fw.z])
		_log_cam.flush()
	if _log_px and _tick % 30 == 0:
		for key: String in _subjects:
			var s: Node3D = subject_of(StringName(key))
			if s != null and _views.has(StringName(key)):
				var r: Vector2 = _rect(_views[StringName(key)], s, true)
				print("[look] px view=%s frame=%d h=%.4f w=%.4f" % [key, _tick, r.y, r.x])


func _px(cam: Camera3D, subject: Node3D, clip: bool) -> float:
	return _rect(cam, subject, clip).y


## Screen rectangle of the subject in `cam`, in units of the frame height: (width, height). Zero when not visible.
func _rect(cam: Camera3D, subject: Node3D, clip: bool) -> Vector2:
	if cam == null or not is_instance_valid(subject) or not subject.is_inside_tree() or not cam.is_inside_tree():
		return Vector2.ZERO
	var pts: PackedVector3Array = PackedVector3Array()
	_collect(subject, pts)
	if pts.is_empty():         # nothing drawn (a bare body): a one metre box around its origin
		for i: int in 8:
			pts.append(subject.global_position + Vector3(0.5 if i & 1 else -0.5, 1.0 if i & 2 else 0.0, 0.5 if i & 4 else -0.5))
	var vp: Vector2 = Vector2(get_viewport().get_visible_rect().size) if get_viewport() != null else Vector2(16, 9)
	var aspect: float = vp.x / maxf(vp.y, 1.0) if vp.y > 0.0 else 16.0 / 9.0
	var th: float = tan(deg_to_rad(cam.fov) * 0.5)
	var inv: Transform3D = cam.global_transform.affine_inverse()
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	var in_front: int = 0
	for p: Vector3 in pts:
		var c: Vector3 = inv * p
		if c.z < -cam.near:
			in_front += 1
		var z: float = maxf(-c.z, cam.near)
		var q: Vector2 = Vector2(c.x / (z * th * aspect), c.y / (z * th))
		lo = lo.min(q)
		hi = hi.max(q)
	if in_front == 0:
		return Vector2.ZERO
	if clip:
		lo = lo.max(Vector2(-1, -1))
		hi = hi.min(Vector2(1, 1))
	if hi.x <= lo.x or hi.y <= lo.y:
		return Vector2.ZERO
	return Vector2((hi.x - lo.x) * 0.5 * aspect, (hi.y - lo.y) * 0.5)


## The corners of every visible mesh under `n`, in world space (each mesh's own box, so a turned subject stays tight).
func _collect(n: Node, pts: PackedVector3Array) -> void:
	if n is Node3D and not (n as Node3D).visible:
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var bb: AABB = (n as MeshInstance3D).mesh.get_aabb()
		var xf: Transform3D = (n as MeshInstance3D).global_transform
		for i: int in 8:
			pts.append(xf * bb.get_endpoint(i))
	for c: Node in n.get_children():
		_collect(c, pts)


func _centre(subject: Node3D) -> Vector3:
	var pts: PackedVector3Array = PackedVector3Array()
	_collect(subject, pts)
	if pts.is_empty():
		return subject.global_position + Vector3.UP * 0.5
	var lo: Vector3 = pts[0]
	var hi: Vector3 = pts[0]
	for p: Vector3 in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return (lo + hi) * 0.5
