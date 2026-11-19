extends TLChaseCam
## The visitor can look from a point with less than a camera sphere's clearance. The
## regular chase cast shrinks in that case. Only repair a placement that grazes a
## drawn crown, or a line that enters leaves from their padding. Walls keep their
## normal close cast. A crown actually containing the look point is still looked out of.
## All pulls and up/down swings behind the visitor take precedence. If raw leaves
## and solid walls block every such placement, the last resort is a sideways swing.
## The owner may revisit that choice: TL_CROWN_SWING=behind (lane walker, 19 Nov round 3) never swings sideways; the
## camera then keeps the nearest placement behind him (it may stand in leaves). Absent or `sideways`: as described.
## An ordinary close wall keeps the head-on pull.
const CANOPY := 4
var crowns: Dictionary = {}
var repair := preload("res://kernel/world/terrain/crown_clearance.gd").new()
var clearance := PhysicsShapeQueryParameters3D.new()
var sphere := SphereShape3D.new()
var nearby: Array = []  # [prototype, inverse transform] for padded starts outside actual foliage
var yaws: Array = [0.0] if OS.get_environment("TL_CROWN_SWING") == "behind" else [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0, 150.0, -150.0, 180.0]
var side_ticks: int = 0                  ## read only: ticks the camera stood swung sideways (yaw != 0)
## Lane flight round 3: the world space's copied bars (world_space `copied_bars`, body RID -> true), left out of the
## avoidance like a pack's marked bars (TLChaseCam `_bar_rids`). `ignore_bars = false` only for the control in
## flight_cam_bar_case.gd (the old behaviour: the camera lifts over a bar).
var bars: Dictionary = {}
var ignore_bars: bool = true
var max_side: float = 0.0                ## read only: the largest sideways swing so far (degrees)


func _init() -> void:
	clearance.shape = sphere
	clearance.collision_mask = CANOPY


func _avoid(now: bool) -> void:
	var wanted := position
	super(now)
	if not avoid_space.is_valid() or crowns.is_empty() or _query == null:
		return
	var st := PhysicsServer3D.space_get_direct_state(avoid_space)
	sphere.radius = maxf(0.01, avoid_margin - 0.015)  # leave contact tolerance on a full-radius cast
	clearance.transform.origin = _look_local
	clearance.exclude = []
	# A full-size cast from a clear start swept the complete arm against every padded part.
	if _cast_r >= avoid_margin and _query.exclude.is_empty():
		return
	nearby.clear()
	var ignore: Array[RID] = []
	var starting: Array[RID] = []
	for hit: Dictionary in st.intersect_shape(clearance):
		var rid: RID = hit.rid
		if rid in starting or not crowns.has(rid):
			continue
		starting.append(rid)
		var tree: Array = crowns[rid]
		if tree[0].contains(tree[1] * _look_local):
			ignore.append(rid)
		else:
			nearby.append(tree)
	clearance.exclude = ignore
	if _clear(st, position):
		return

	var arm := wanted - _look_local
	var length := arm.length()
	if length < 0.01:
		return
	var elev := rad_to_deg(asin(clampf(arm.y / length, -1.0, 1.0)))
	var level := Vector3(arm.x, 0.0, arm.z).normalized()
	repair.prepare(st, crowns, _look_local, length)
	# Geometry and foliage have different start-overlap rules. Keep the existing wall
	# cast (including its shrinking sphere) and bound it separately by the raw leaves.
	var mask := avoid_mask
	avoid_mask &= ~CANOPY
	_start(st)
	avoid_mask = mask
	var swings := _swings(elev)
	for yaw: float in yaws:
		var horizontal := level.rotated(Vector3.UP, deg_to_rad(yaw))
		for angle in swings:
			var pitch := deg_to_rad(elev + angle)
			var dir := horizontal * cos(pitch) + Vector3.UP * sin(pitch)
			var reach := repair.reach(dir, _cast(st, dir * length, length))
			if reach >= 0.0:
				position = _look_local + dir * reach
				_free_len = reach
				_lift = angle
				avoid_lift = angle
				avoid_pull = length - reach
				if yaw != 0.0:
					side_ticks += 1
					max_side = maxf(max_side, absf(yaw))
				_ray.collision_mask = mask
				return
	_ray.collision_mask = mask


func _bar_rids() -> Array[RID]:
	if not ignore_bars:
		return [] as Array[RID]
	var out: Array[RID] = super()
	for rid: Variant in bars.keys():
		out.append(rid as RID)
	return out


func _limit_lift(previous: float, wanted: float, now: bool) -> float:
	if not now and target.get("flying") == true:
		return move_toward(previous, wanted, 2.0)
	return wanted


func _clear(st: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	clearance.transform.origin = at
	if not st.intersect_shape(clearance, 1).is_empty():
		return false
	for tree: Array in nearby:
		var inv: Transform3D = tree[1]
		if tree[0].crosses(inv * _look_local, inv * at):
			return false
	return true


## Endpoints can both be safe while interpolation draws a chord through a crown.
func _cut_if_blocked(was: Vector3) -> void:
	super(was)
	if not avoid_space.is_valid() or crowns.is_empty():
		return
	var start := _frame().affine_inverse() * was
	var motion := position - start
	if motion.length_squared() < 0.000001:
		return
	var st := PhysicsServer3D.space_get_direct_state(avoid_space)
	clearance.transform.origin = start
	clearance.motion = motion
	var hit := st.cast_motion(clearance)
	clearance.motion = Vector3.ZERO
	if hit[0] < 1.0 or not st.intersect_shape(clearance, 1).is_empty():
		reset_physics_interpolation()
