class_name TLChaseCam
extends Camera3D
## Follows a target from behind and above; frame-counted smoothing (no wall clock). Capability: `camera`.
## Make one with `ctx.cameras.chase(target, {distance = 7.0, height = 3.0})`.
## N1: a deliberate lens (58 degrees instead of the engine's 75), the place follows faster than the heading turns
## (`follow` against `stiffness`), so the target keeps its size at speed, and the point looked at is smoothed too.
## Walker-feel (18 Nov 2026), both opt-in, a pack's camera is unchanged without them:
##   `anchor_follow` (>= 0): the camera orbits a SMOOTHED point that follows the target by this share per frame
##       (`anchor_follow_y` for its height, default the same): the place and the point looked at both come from it, so a
##       mouse turn keeps the distance exact while a jump or a step is eased. `follow` and `aim` are then not used.
##   `avoid_space` (a physics space RID): the camera never goes inside what that space holds (mask `avoid_mask`): a
##       sphere of `avoid_margin` is cast from the point looked at to the wanted place; the camera stands where it
##       stops (pulled in at once), and eases back out by `avoid_out` of the remaining way per frame. When that leaves
##       it nearer than `avoid_min` (it would look through the back of his head), the camera is first swung UP round
##       the point looked at (10 degree steps, at most 80 degrees above the horizon) to the lowest angle that is clear
##       for `avoid_min`: over an edge it looks down at him instead of into him.

var target: Node3D
var distance: float = 7.0        ## metres behind the target
var height: float = 3.0          ## metres above the target
var look_height: float = 1.0     ## the point looked at, above the target's origin
var stiffness: float = 0.07      ## 0..1 share of the remaining heading change covered each frame
var follow: float = 0.18          ## 0..1 share of the remaining distance to the wanted place covered each frame
var aim: float = 0.3             ## 0..1 share of the remaining way to the point looked at covered each frame
var use_velocity: bool = false   ## true: stay behind the direction of travel instead of the target's facing
var anchor_follow: float = -1.0  ## >= 0: orbit a smoothed anchor (see the header); -1 off
var anchor_follow_y: float = -1.0  ## the anchor's height share per frame; -1: the same as anchor_follow
var avoid_space: RID = RID()     ## a physics space whose bodies the camera never enters; invalid: off
var avoid_margin: float = 0.3    ## metres kept between the camera and what it would enter
var avoid_mask: int = 1          ## collision layers of `avoid_space` that count
var avoid_out: float = 0.12      ## 0..1 share of the remaining way back out covered each frame
var avoid_min: float = 2.5       ## metres: a nearer camera is swung up first (see the header)
var avoid_pull: float = 0.0      ## read only: metres the camera stands nearer than wanted this frame (0 when free)
var avoid_lift: float = 0.0      ## read only: degrees the camera is swung up this frame (0 when free)
var _heading: Vector3 = Vector3.FORWARD
var _last_pos: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
var _anchor: Vector3 = Vector3.ZERO
var _free_len: float = -1.0
var _lift: float = 0.0
var _sphere: SphereShape3D = null
var _query: PhysicsShapeQueryParameters3D = null


func setup(target_: Node3D, opts: Dictionary = {}) -> void:
	target = target_
	fov = 58.0
	for k: String in opts.keys():
		if k in ["distance", "height", "look_height", "stiffness", "follow", "aim", "use_velocity", "fov", "anchor_follow", "anchor_follow_y",
				"avoid_space", "avoid_margin", "avoid_mask", "avoid_out"]:
			set(k, opts[k])
		else:
			push_error("TLChaseCam: unknown option '%s'" % k)
	far = 2000.0
	if is_instance_valid(target) and target.is_inside_tree():
		_last_pos = target.global_position
		_heading = _target_forward()
		snap()


## Puts the camera at its wanted place at once (after a teleport, or after changing `distance` / `height`).
func snap() -> void:
	if not is_instance_valid(target) or not target.is_inside_tree() or not is_inside_tree():
		return
	_anchor = target.global_position
	global_position = _wanted()
	_look = target.global_position + Vector3.UP * look_height
	_free_len = -1.0
	_lift = 0.0
	_avoid(true)
	_aim()
	reset_physics_interpolation()


func _target_forward() -> Vector3:
	var f: Vector3 = -target.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else _heading


func _base() -> Vector3:
	return _anchor if anchor_follow >= 0.0 else target.global_position


func _wanted() -> Vector3:
	return _base() - _heading * distance + Vector3.UP * height


func _aim() -> void:
	if global_position.distance_to(_look) > 0.01:
		look_at(_look, Vector3.UP)


## Keeps the camera out of `avoid_space` (see the header). `now`: no easing (a snap).
func _avoid(now: bool) -> void:
	avoid_pull = 0.0
	avoid_lift = 0.0
	if not avoid_space.is_valid():
		return
	var d: Vector3 = global_position - _look
	var want_len: float = d.length()
	if want_len < 0.01:
		return
	if _query == null:
		_sphere = SphereShape3D.new()
		_query = PhysicsShapeQueryParameters3D.new()
		_query.shape = _sphere
	_sphere.radius = avoid_margin
	_query.collision_mask = avoid_mask
	var st: PhysicsDirectSpaceState3D = PhysicsServer3D.space_get_direct_state(avoid_space)
	if st == null:
		return
	var axis: Vector3 = Vector3.UP.cross(d)
	axis = axis.normalized() if axis.length() > 0.001 else Vector3.RIGHT
	if d.rotated(axis, 0.1).y < d.y:
		axis = -axis
	var elev: float = rad_to_deg(asin(clampf(d.y / want_len, -1.0, 1.0)))
	# the lowest swing up that is clear for avoid_min (or the whole wanted way when that is shorter)
	var need: float = minf(avoid_min, want_len)
	var want_lift: float = 0.0
	var best: float = -1.0
	var k: int = 0
	while k <= 8:
		var ang: float = 10.0 * float(k)
		if k > 0 and elev + ang > 80.0:
			break
		var fl: float = _cast(st, d.rotated(axis, deg_to_rad(ang)), want_len)
		if fl >= need - 0.01:
			want_lift = ang
			best = -1.0
			break
		if fl > best + 0.25:
			best = fl
			want_lift = ang
		k += 1
	if now or want_lift > _lift:
		_lift = want_lift
	else:
		_lift = lerpf(_lift, want_lift, clampf(avoid_out, 0.01, 1.0))
		if absf(_lift - want_lift) < 0.05:
			_lift = want_lift
	var dir: Vector3 = d.rotated(axis, deg_to_rad(_lift)) if _lift > 0.0 else d
	var free_len: float = _cast(st, dir, want_len)
	if now or _free_len < 0.0 or free_len < _free_len:
		_free_len = free_len                                   # pulled in at once
	else:
		_free_len = minf(free_len, lerpf(_free_len, free_len, clampf(avoid_out, 0.01, 1.0)))
	var len: float = minf(_free_len, want_len)
	avoid_pull = want_len - len
	avoid_lift = _lift
	global_position = _look + dir / want_len * len


## How far a sphere of `avoid_margin` gets from the point looked at along `d` (length `want_len`).
func _cast(st: PhysicsDirectSpaceState3D, d: Vector3, want_len: float) -> float:
	_query.transform = Transform3D(Basis(), _look)
	_query.motion = d
	var r: PackedFloat32Array = st.cast_motion(_query)
	return want_len * (r[0] if r.size() > 0 else 1.0)


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
	if anchor_follow >= 0.0:
		var tp: Vector3 = target.global_position
		var ky: float = anchor_follow_y if anchor_follow_y >= 0.0 else anchor_follow
		_anchor = Vector3(lerpf(_anchor.x, tp.x, clampf(anchor_follow, 0.01, 1.0)), lerpf(_anchor.y, tp.y, clampf(ky, 0.01, 1.0)),
			lerpf(_anchor.z, tp.z, clampf(anchor_follow, 0.01, 1.0)))
		global_position = _wanted()
		_look = _anchor + Vector3.UP * look_height
	else:
		global_position = global_position.lerp(_wanted(), clampf(follow, 0.01, 1.0))
		_look = _look.lerp(target.global_position + Vector3.UP * look_height, clampf(aim, 0.01, 1.0))
	_avoid(false)
	_aim()
