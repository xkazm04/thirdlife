extends RefCounted
## Fixed-tick ledge and bar contacts shared by both walker controllers.
const HANDS_H := 1.6
const LEDGE_MIN := 0.4
const LEDGE_MAX := 1.2
const HANG_DROP := HANDS_H
const MANTLE_TICKS := 28
const REGRAB_TICKS := 20
const BAR_HANDS_H := 2.2
const BAR_REACH := 0.35
const BAR_L := 1.1
const BAR_HOP := 2.0
const DAMPING := 0.23105  # 2 ln(2) / 6 per second
const PUMP := 5.0         # maximum angular acceleration from input (rad/s²)
const LIMIT := 100.0 * PI / 180.0
const CLEARANCE := 0.004

var ledges := false
var bars := false
var ledge_top := Vector3.ZERO
var wall_normal := Vector3.ZERO
var bar_point := Vector3.ZERO
var bar_axis := Vector3.ZERO
var theta := 0.0
var omega := 0.0
var mantle_tick := 0
var _hang := Vector3.ZERO
var _stand := Vector3.ZERO
var _crest := Vector3.ZERO
var _grip_key: Array
var _standing_normal := Vector3.UP
var _tick := 0
var _cooldowns := {}
var _reach := SphereShape3D.new()

func _init() -> void:
	_reach.radius = BAR_REACH

func reset() -> void:
	_cooldowns.clear()
	_tick = 0
	_grip_key = []
	mantle_tick = 0
	theta = 0
	omega = 0

func _ray(sp: Variant, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, PhysicsServer3D.body_get_collision_mask(sp.body))
	q.exclude = [sp.body]
	return PhysicsServer3D.space_get_direct_state(sp.space).intersect_ray(q)

func _fits(sp: Variant, pos: Vector3) -> bool:
	var fit := PhysicsTestMotionParameters3D.new()
	fit.from.origin = pos
	fit.margin = 0.001
	fit.recovery_as_collision = true
	return not PhysicsServer3D.body_test_motion(sp.body, fit)

func _clear(sp: Variant, pos: Vector3, to: Vector3) -> bool:
	return _fits(sp, to) and not sp._test(Transform3D(Basis.IDENTITY, pos), to - pos, 0.001)

func _ledge(body: Variant, pos: Vector3, direction: Vector3) -> bool:
	var sp: Variant = body.sp
	var hand := pos + Vector3.UP * HANDS_H
	var radius: float = sp.walker_radius
	var face := _ray(sp, hand, hand + direction * (radius + 0.23))
	if face.is_empty() or body._walkable(face.normal) or direction.dot(face.normal) >= -0.05:
		return false
	var normal := Vector3(face.normal.x, 0, face.normal.z).normalized()
	# Follow the steep face up to the lip, including battered or overhanging faces.
	var face_rise := Vector3.UP - normal * (float(face.normal.y) / Vector2(face.normal.x, face.normal.z).length())
	var edge: Vector3 = face.position - normal * 0.02
	var top := _ray(sp, edge + face_rise * (LEDGE_MAX + 0.01), edge + face_rise * (LEDGE_MIN - 0.01))
	if top.is_empty() or not body._walkable(top.normal):
		return false
	# Intersect the top plane with the face at the hand's station along the edge.
	var height: float = (top.position - face.position).dot(top.normal) / face_rise.dot(top.normal)
	if height < LEDGE_MIN - 0.00001 or height > LEDGE_MAX + 0.00001:
		return false
	var key := [face.rid, face.shape, normal.snapped(Vector3.ONE * 0.01)]
	if _cooldowns.has(key):
		return false
	var lip: Vector3 = face.position + face_rise * height
	var sphere_y: float = radius if face.normal.y >= 0 else sp.walker_height - radius
	var offset: float = (radius + CLEARANCE - (sphere_y - HANG_DROP) * face.normal.y) / normal.dot(face.normal)
	var hang := lip + normal * offset - Vector3.UP * HANG_DROP
	var landing := lip - normal * (radius + 0.015)
	var rise := radius * tan(deg_to_rad(sp.max_slope_deg)) + 0.1
	var floor_hit := _ray(sp, landing + Vector3.UP * rise, landing - Vector3.UP * rise)
	if floor_hit.is_empty() or not body._walkable(floor_hit.normal):
		return false
	# On an incline the round foot is tangent to the plane off the centre ray.
	var stand: Vector3 = floor_hit.position + Vector3.UP * (radius * (1.0 / floor_hit.normal.y - 1.0) + 0.001)
	if not _fits(sp, stand) or not _clear(sp, pos, hang):
		return false
	ledge_top = lip
	wall_normal = face.normal
	_standing_normal = floor_hit.normal
	_hang = hang
	_stand = stand
	_crest = Vector3(hang.x, maxf(lip.y, stand.y) + CLEARANCE, hang.z)
	_grip_key = key
	mantle_tick = 0
	return true

func _bar(body: Variant, pos: Vector3) -> bool:
	var sp: Variant = body.sp
	var hands := pos + Vector3.UP * BAR_HANDS_H
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _reach
	query.transform.origin = hands
	query.exclude = [sp.body]
	query.collision_mask = PhysicsServer3D.body_get_collision_mask(sp.body)
	var nearest := INF
	for hit in PhysicsServer3D.space_get_direct_state(sp.space).intersect_shape(query):
		var rid: RID = hit.rid
		if not sp.copied_bars.has(rid) and not (hit.collider is StaticBody3D and hit.collider.get_meta(&"tl_bar", false)):
			continue
		if _cooldowns.has([rid, hit.shape]):
			continue
		var shape := PhysicsServer3D.body_get_shape(rid, hit.shape)
		var kind := PhysicsServer3D.shape_get_type(shape)
		if kind != PhysicsServer3D.SHAPE_CYLINDER and kind != PhysicsServer3D.SHAPE_CAPSULE:
			continue
		var xf: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM) * PhysicsServer3D.body_get_shape_transform(rid, hit.shape)
		var axis := xf.basis.y.normalized()
		var data: Dictionary = PhysicsServer3D.shape_get_data(shape)
		var half_len: float = data.height * xf.basis.y.length() * 0.5
		var point := xf.origin + axis * clampf((hands - xf.origin).dot(axis), -half_len, half_len)
		var dist := hands.distance_squared_to(point)
		if dist > BAR_REACH * BAR_REACH + 0.0000001 or dist >= nearest:
			continue
		if not _clear(sp, pos, point - Vector3.UP * BAR_HANDS_H):
			continue
		bar_point = point
		bar_axis = axis
		_grip_key = [rid, hit.shape]
		nearest = dist
	if not is_finite(nearest):
		return false
	theta = 0
	omega = body.vel.dot(_tangent()) / BAR_L
	return true

func _tangent() -> Vector3:
	return bar_axis.cross(Vector3.DOWN).rotated(bar_axis, theta).normalized()

func _released(body: Variant) -> void:
	_cooldowns[_grip_key] = _tick + REGRAB_TICKS
	body.mode = "air"
	body._jumped = true
	body.air_ticks = 0

func _result(body: Variant, pos: Vector3, events: Array, blocked := false) -> Dictionary:
	if blocked:
		body.sp.blocked_ticks += 1
	return {"pos": pos, "vel": body.vel, "mode": body.mode, "grounded": body.grounded, "events": events, "blocked": blocked}

func advance_clock() -> void:
	_tick += 1
	for key: Array in _cooldowns.keys():
		if _tick > _cooldowns[key]:
			_cooldowns.erase(key)

## Empty result delegates to the ordinary walker for this tick.
func drive(body: Variant, pos: Vector3, wish: Vector3, jump: bool, slide: bool, events: Array) -> Dictionary:
	match body.mode:
		"air":
			if body.sp.crouched:
				return {}
			var entry: String
			if bars and _bar(body, pos):
				entry = "bar"
				pos = bar_point - Vector3.UP * BAR_HANDS_H
			elif ledges:
				var drift := Vector3(body.vel.x, 0, body.vel.z).normalized()
				var dir := wish.normalized()
				if (dir != Vector3.ZERO and _ledge(body, pos, dir)) or (drift != Vector3.ZERO and not drift.is_equal_approx(dir) and _ledge(body, pos, drift)):
					entry = "hang"
					pos = _hang
			if entry.is_empty():
				return {}
			body.mode = entry
			body.vel = Vector3.ZERO
			body._buffer = 0
			body._step_t = 0
			events.append(entry)
		"hang":
			if slide or wish.dot(wall_normal) > 0.1:
				body.vel = Vector3(wall_normal.x, 0, wall_normal.z).normalized()
				_released(body)
				events.append("drop")
			elif jump or wish.dot(wall_normal) < -0.1:
				body.mode = "mantle"
				events.append("mantle")
			else:
				return _result(body, pos, events)
		"bar":
			if slide or jump:
				body.vel = _tangent() * (omega * BAR_L)
				if jump and not slide:
					body.vel += Vector3.UP * BAR_HOP
				_released(body)
				events.append("release" if jump and not slide else "drop")
			else:
				var side := bar_axis.cross(Vector3.DOWN)
				var pump := clampf(wish.dot(side) / body.WALK_MPS, -1, 1)
				omega += (PUMP * pump - body.GRAVITY / BAR_L * sin(theta) * side.length() - DAMPING * omega) / 60.0
				var angle := clampf(theta + omega / 60.0, -LIMIT, LIMIT)
				var next := bar_point + Vector3.DOWN.rotated(bar_axis, angle) * BAR_HANDS_H
				if not _clear(body.sp, pos, next):
					omega = 0
					return _result(body, pos, events, true)
				pos = next
				theta = angle
				if absf(theta) == LIMIT:
					omega = 0
		"mantle":
			pass
		_:
			return {}
	if body.mode == "mantle":
		mantle_tick += 1
		var t := float(mantle_tick) / MANTLE_TICKS
		var next := _hang.lerp(_crest, smoothstep(0, 0.5, t)) if t <= 0.5 else _crest.lerp(_stand, smoothstep(0.5, 1, t))
		if not _clear(body.sp, pos, next):
			_released(body)
			events.append("end_mantle")
			return _result(body, pos, events, true)
		pos = next
		if mantle_tick == MANTLE_TICKS:
			# A copied plot or pack platform can disappear after the initial standing-room test.
			if not body.sp._test(Transform3D(Basis.IDENTITY, pos), Vector3.DOWN * 0.025, 0.001) or not body._walkable(body.sp._res.get_collision_normal(0)):
				_released(body)
				events.append("end_mantle")
				return _result(body, pos, events)
			body.mode = "ground"
			body.grounded = true
			body.ground_n = _standing_normal
			body.air_ticks = 0
			body._jumped = false
			events.append("end_mantle")
	return _result(body, pos, events)
