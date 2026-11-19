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
##       for `avoid_min`: over an edge it looks down at him instead of into him. When no swing up is clear (a crown
##       just over his head), it is swung DOWN instead, in 10 degree steps to the horizon at the lowest: under the crown.
##       What the sphere already touches at the point looked at is not ignored (bugfix-37 D5): the cast sphere is shrunk
##       to the room there (halved down to 2 cm, then a ray), so a wall 0.2 m behind him stops the camera in front of
##       it. A body that holds the point looked at itself (his head inside a crown) cannot be left without crossing it:
##       it is looked out of (left out of the cast), and the camera stands beyond it. The space's bodies are in the
##       coordinates of the camera's PARENT (a Node3D; otherwise global): the visitor's camera under a landscape that a
##       stage re-bases casts in the landscape's frame (D18). A tick whose move from the last place would be drawn
##       through something in the space is drawn as a cut (`reset_physics_interpolation`, Q32).

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
var _travel: Vector3 = Vector3.ZERO   ## hunt2 A4: the last travel heading (use_velocity); zero: none yet, the facing is used
var _look: Vector3 = Vector3.ZERO
var _anchor: Vector3 = Vector3.ZERO
var _free_len: float = -1.0
var _lift: float = 0.0
var _sphere: SphereShape3D = null
var _query: PhysicsShapeQueryParameters3D = null
var _point: PhysicsPointQueryParameters3D = null
var _ray: PhysicsRayQueryParameters3D = null
var _look_local: Vector3 = Vector3.ZERO   ## the point looked at in the avoid frame (the parent's coordinates)
var _cast_r: float = 0.3                  ## the radius cast this tick; under _RAY_R a ray is cast instead
const _RAY_R: float = 0.02
var _unit: float = 1.0                    ## hunt2 B11: metres per unit of the avoid frame (the parent's scale), for avoid_margin and avoid_min


func setup(target_: Node3D, opts: Dictionary = {}) -> void:
	target = target_
	fov = 58.0
	for k: String in opts.keys():
		if k in ["distance", "height", "look_height", "stiffness", "follow", "aim", "use_velocity", "fov", "anchor_follow", "anchor_follow_y",
				"avoid_space", "avoid_margin", "avoid_mask", "avoid_out", "avoid_min"]:
			set(k, opts[k])
		else:
			push_error("TLChaseCam: unknown option '%s'" % k)
	far = 2000.0
	if is_instance_valid(target) and target.is_inside_tree():
		_last_pos = target.global_position
		_heading = _target_forward()
		snap()


## Puts the camera at its wanted place at once (after a teleport, or after changing `distance` / `height`): behind the
## target's facing now (a teleport may turn him too; with `use_velocity` the travel is not known yet, the facing is used).
func snap() -> void:
	if not is_instance_valid(target) or not target.is_inside_tree() or not is_inside_tree():
		return
	_heading = _target_forward()
	_last_pos = target.global_position
	_travel = Vector3.ZERO
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
	var st: PhysicsDirectSpaceState3D = PhysicsServer3D.space_get_direct_state(avoid_space)
	if st == null:
		return
	var fr: Transform3D = _frame()
	var sc: Vector3 = fr.basis.get_scale()
	_unit = maxf((absf(sc.x) + absf(sc.y) + absf(sc.z)) / 3.0, 0.0001)   # hunt2 B11: avoid_margin and avoid_min are metres
	_look_local = fr.affine_inverse() * _look
	var d: Vector3 = fr.affine_inverse() * global_position - _look_local
	var want_len: float = d.length()
	if want_len < 0.01:
		return
	_start(st)
	var axis: Vector3 = Vector3.UP.cross(d)
	axis = axis.normalized() if axis.length() > 0.001 else Vector3.RIGHT
	if d.rotated(axis, 0.1).y < d.y:
		axis = -axis
	var elev: float = rad_to_deg(asin(clampf(d.y / want_len, -1.0, 1.0)))
	# the lowest swing up that is clear for avoid_min (or the whole wanted way when that is shorter); then down
	var need: float = minf(avoid_min / _unit, want_len)
	var want_lift: float = 0.0
	var best: float = -1.0
	for ang: float in _swings(elev):
		var fl: float = _cast(st, d.rotated(axis, deg_to_rad(ang)), want_len)
		if fl >= need - 0.01:
			want_lift = ang
			break
		if fl > best + 0.25:
			best = fl
			want_lift = ang
	if now or want_lift > _lift or (want_lift < 0.0 and want_lift < _lift):
		_lift = want_lift                                      # swung away from the wanted angle at once
	else:
		_lift = lerpf(_lift, want_lift, clampf(avoid_out, 0.01, 1.0))
		if absf(_lift - want_lift) < 0.05:
			_lift = want_lift
	var dir: Vector3 = d.rotated(axis, deg_to_rad(_lift)) if _lift != 0.0 else d
	var free_len: float = _cast(st, dir, want_len)
	if now or _free_len < 0.0 or free_len < _free_len:
		_free_len = free_len                                   # pulled in at once
	else:
		_free_len = minf(free_len, lerpf(_free_len, free_len, clampf(avoid_out, 0.01, 1.0)))
	var len: float = minf(_free_len, want_len)
	avoid_pull = (fr.basis * d).length() - (fr.basis * (dir / want_len * len)).length()   # hunt2 A10: metres, whatever the parent's scale
	avoid_lift = _lift
	global_position = fr * (_look_local + dir / want_len * len)


## The frame `avoid_space` is in: the parent's (see the header).
func _frame() -> Transform3D:
	var p: Node3D = get_parent() as Node3D
	return p.global_transform if p != null else Transform3D.IDENTITY


## The swings tried, in order (degrees, + is up): 0, then up in 10 degree steps to 80 above the horizon, then down in
## 10 degree steps and last the horizon itself (never below it).
func _swings(elev: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array([0.0])
	for k: int in range(1, 9):
		if elev + 10.0 * float(k) > 80.0:
			break
		out.append(10.0 * float(k))
	var ang: float = -10.0
	while elev + ang > 0.0:
		out.append(ang)
		ang -= 10.0
	if elev > 0.0:
		out.append(-elev)
	return out


## Before casting: bodies holding the point looked at are left out (they cannot be left without crossing them), and
## the cast sphere is shrunk to the room at the point looked at, since a cast ignores what it overlaps at its start.
func _start(st: PhysicsDirectSpaceState3D) -> void:
	if _query == null:
		_sphere = SphereShape3D.new()
		_query = PhysicsShapeQueryParameters3D.new()
		_query.shape = _sphere
		_point = PhysicsPointQueryParameters3D.new()
		_ray = PhysicsRayQueryParameters3D.new()
	_point.collision_mask = avoid_mask
	_point.position = _look_local
	var ex: Array[RID] = []
	for h: Dictionary in st.intersect_point(_point, 8):
		ex.append(h["rid"] as RID)
	_query.collision_mask = avoid_mask
	_query.exclude = ex
	_query.motion = Vector3.ZERO
	_query.transform = Transform3D(Basis(), _look_local)
	_ray.collision_mask = avoid_mask
	_ray.exclude = ex
	_ray.hit_from_inside = false
	_cast_r = maxf(avoid_margin / _unit, _RAY_R)
	while _cast_r >= _RAY_R:
		_sphere.radius = _cast_r
		if st.intersect_shape(_query, 1).is_empty():
			break
		_cast_r *= 0.5


## How far the camera gets from the point looked at along `d` (length `want_len`): a sphere of the radius `_start`
## found, or a ray (stopping _RAY_R short) when the point looked at has less room than _RAY_R.
func _cast(st: PhysicsDirectSpaceState3D, d: Vector3, want_len: float) -> float:
	if _cast_r < _RAY_R:
		_ray.from = _look_local
		_ray.to = _look_local + d
		var hit: Dictionary = st.intersect_ray(_ray)
		if hit.is_empty():
			return want_len
		return maxf(0.0, _look_local.distance_to(hit["position"] as Vector3) - _RAY_R)
	_query.transform = Transform3D(Basis(), _look_local)
	_query.motion = d
	var r: PackedFloat32Array = st.cast_motion(_query)
	return want_len * (r[0] if r.size() > 0 else 1.0)


## Q32: a move from `was` that passes through something in the space would be drawn (interpolated) inside it: a cut.
func _cut_if_blocked(was: Vector3) -> void:
	if not avoid_space.is_valid() or _ray == null:
		return
	var st: PhysicsDirectSpaceState3D = PhysicsServer3D.space_get_direct_state(avoid_space)
	if st == null:
		return
	var inv: Transform3D = _frame().affine_inverse()
	_ray.from = inv * was
	_ray.to = inv * global_position
	_ray.exclude = []
	if _ray.from.distance_to(_ray.to) > 0.001 and not st.intersect_ray(_ray).is_empty():
		reset_physics_interpolation()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	var want_heading: Vector3 = _target_forward()
	if use_velocity:
		var step: Vector3 = target.global_position - _last_pos
		step.y = 0.0
		# hunt2 A4: travel is measured over as many ticks as it takes to cover 2 cm (slow travel too), and its heading is
		# kept between samples and at rest, never swapped for the facing
		if step.length() > 0.02:
			_travel = step.normalized()
			_last_pos = target.global_position
		if _travel != Vector3.ZERO:
			want_heading = _travel
	else:
		_last_pos = target.global_position
	if _heading.dot(want_heading) < -0.999:
		# Q20: an exact reversal lerps along the line and normalises back to the old heading: turn round the up axis
		_heading = _heading.rotated(Vector3.UP, PI * clampf(stiffness, 0.0, 1.0))
	else:
		var h: Vector3 = _heading.lerp(want_heading, stiffness)
		_heading = h.normalized() if h.length() > 0.001 else want_heading
	var was: Vector3 = global_position
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
	_cut_if_blocked(was)
	_aim()
