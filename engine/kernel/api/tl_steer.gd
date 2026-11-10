class_name TLSteer
extends RefCounted
## Steering helpers for AI: pure functions on positions and velocities that answer with a direction or a steering
## value. They do not move anything: feed the answer to a controller (`TLBiped.move()`, `TLVehicle.set_controls()`).
## Everything works in the ground plane (y is ignored). Capability: `ai`.
##
##   skater.move(TLSteer.pursue(skater.global_position, skater.speed(), puck.global_position, puck.linear_velocity))
##   var lane := TLSteer.keep_lane(car.global_position, car.forward(), path, 9.0)
##   car.set_controls(lane["steer"], 1.0 if car.speed() < 20.0 else 0.0)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _need() -> void:
	TLContext.require("ai", "TLSteer")


## Unit direction from `from` to `target` (zero when they coincide).
static func seek(from: Vector3, target: Vector3) -> Vector3:
	_need()
	var d: Vector3 = _flat(target - from)
	return d.normalized() if d.length() > 0.0001 else Vector3.ZERO


## Like seek, but the length falls from 1 to 0 inside `slow_radius`, so a walker stops on the spot.
static func arrive(from: Vector3, target: Vector3, slow_radius: float = 2.0) -> Vector3:
	_need()
	var d: Vector3 = _flat(target - from)
	var dist: float = d.length()
	if dist < 0.0001:
		return Vector3.ZERO
	return d / dist * clampf(dist / maxf(0.001, slow_radius), 0.0, 1.0)


## Unit direction away from `threat`.
static func flee(from: Vector3, threat: Vector3) -> Vector3:
	return -seek(from, threat)


## The point where a mover at `speed` can meet a target that keeps its velocity (lead capped at `max_lead_frames`).
static func intercept_point(from: Vector3, speed: float, target: Vector3, target_velocity: Vector3, max_lead_frames: int = 120) -> Vector3:
	_need()
	var dist: float = _flat(target - from).length()
	var lead_s: float = minf(dist / maxf(0.1, speed), float(max_lead_frames) / 60.0)
	return target + _flat(target_velocity) * lead_s


## Unit direction to where the target will be (seek with a lead).
static func pursue(from: Vector3, speed: float, target: Vector3, target_velocity: Vector3, max_lead_frames: int = 120) -> Vector3:
	return seek(from, intercept_point(from, speed, target, target_velocity, max_lead_frames))


## Unit direction away from where a pursuer will be.
static func evade(from: Vector3, speed: float, threat: Vector3, threat_velocity: Vector3, max_lead_frames: int = 120) -> Vector3:
	return -pursue(from, speed, threat, threat_velocity, max_lead_frames)


## A sideways push away from obstacles ahead. `obstacles` is an Array of {position: Vector3, radius: float}.
## Returns a vector of length 0..1 at right angles to `heading`; add it to the direction you wanted.
static func avoid(from: Vector3, heading: Vector3, obstacles: Array, look_ahead: float = 6.0, own_radius: float = 0.5) -> Vector3:
	_need()
	var h: Vector3 = _flat(heading).normalized()
	if h.length() < 0.5:
		return Vector3.ZERO
	var right: Vector3 = h.cross(Vector3.UP)
	var best: Vector3 = Vector3.ZERO
	var best_along: float = look_ahead
	for o: Dictionary in obstacles:
		var rel: Vector3 = _flat((o["position"] as Vector3) - from)
		var along: float = rel.dot(h)
		if along < 0.0 or along > best_along:
			continue
		var side: float = rel.dot(right)
		var clear: float = float(o.get("radius", 0.5)) + own_radius
		if absf(side) < clear:
			best_along = along
			var away: float = -1.0 if side > 0.0 else 1.0
			best = right * away * clampf(1.0 - along / look_ahead + 0.2, 0.0, 1.0)
	return best


## A push away from neighbours closer than `radius` (length 0..1). `others` holds positions.
static func separate(from: Vector3, others: Array, radius: float = 1.5) -> Vector3:
	_need()
	var push: Vector3 = Vector3.ZERO
	for p: Vector3 in others:
		var d: Vector3 = _flat(from - p)
		var dist: float = d.length()
		if dist > 0.0001 and dist < radius:
			push += d / dist * (1.0 - dist / radius)
	return push.limit_length(1.0)


## -1 (turn left) .. 1 (turn right) to bring `heading` round to `wanted`. For vehicles: the steer value.
static func steer_toward(heading: Vector3, wanted: Vector3, gain: float = 2.0) -> float:
	_need()
	var h: Vector3 = _flat(heading).normalized()
	var w: Vector3 = _flat(wanted).normalized()
	if h.length() < 0.5 or w.length() < 0.5:
		return 0.0
	var turn: float = h.x * w.z - h.z * w.x
	if h.dot(w) < 0.0:        # the target is behind: turn hard toward its side
		turn = 1.0 if turn >= 0.0 else -1.0
	return clampf(turn * gain, -1.0, 1.0)


## Follows a path (a polyline of points). Returns {target: Vector3 (the point to aim at, `look_ahead` metres along
## the path from the nearest point), direction: Vector3 (unit, toward it), steer: float (-1..1 for a vehicle),
## offset: float (metres off the path, + = right of it), index: int (segment), progress: float (metres along)}.
## `closed` joins the last point to the first (a circuit).
static func keep_lane(from: Vector3, heading: Vector3, path: PackedVector3Array, look_ahead: float = 6.0, closed: bool = false) -> Dictionary:
	_need()
	var n: int = path.size()
	if n < 2:
		return {"target": from, "direction": Vector3.ZERO, "steer": 0.0, "offset": 0.0, "index": 0, "progress": 0.0}
	var segs: int = n if closed else n - 1
	var best_i: int = 0
	var best_t: float = 0.0
	var best_d: float = INF
	var lengths: PackedFloat32Array = PackedFloat32Array()
	for i: int in segs:
		var a: Vector3 = _flat(path[i])
		var b: Vector3 = _flat(path[(i + 1) % n])
		var ab: Vector3 = b - a
		var len2: float = ab.length_squared()
		lengths.append(sqrt(len2))
		var t: float = clampf(_flat(from - a).dot(ab) / len2, 0.0, 1.0) if len2 > 0.000001 else 0.0
		var d: float = _flat(from).distance_to(a + ab * t)
		if d < best_d:
			best_d = d
			best_i = i
			best_t = t
	var progress: float = float(lengths[best_i]) * best_t
	for i: int in best_i:
		progress += float(lengths[i])
	# walk look_ahead metres along the path from the nearest point
	var remain: float = look_ahead
	var i2: int = best_i
	var t2: float = best_t
	var target: Vector3 = path[best_i]
	var guard: int = 0
	while guard < segs * 2 + 2:
		guard += 1
		var a2: Vector3 = path[i2 % n]
		var b2: Vector3 = path[(i2 + 1) % n]
		var seg_left: float = float(lengths[i2 % segs]) * (1.0 - t2)
		if remain <= seg_left or (not closed and i2 >= segs - 1):
			var seg_len: float = maxf(0.0001, float(lengths[i2 % segs]))
			target = a2.lerp(b2, clampf(t2 + remain / seg_len, 0.0, 1.0))
			break
		remain -= seg_left
		i2 += 1
		t2 = 0.0
	var seg_a: Vector3 = _flat(path[best_i])
	var seg_dir: Vector3 = (_flat(path[(best_i + 1) % n]) - seg_a).normalized()
	var offset: float = _flat(from - seg_a).dot(seg_dir.cross(Vector3.UP))
	var direction: Vector3 = seek(from, target)
	return {"target": target, "direction": direction, "steer": steer_toward(heading, direction), "offset": offset,
		"index": best_i, "progress": progress}


## A slowly changing random direction for idle movement. Keep `memory` (a Dictionary) between calls; uses `rng`.
static func wander(rng: RandomNumberGenerator, memory: Dictionary, jitter: float = 0.3) -> Vector3:
	_need()
	var angle: float = float(memory.get("angle", rng.randf_range(-PI, PI)))
	angle += rng.randf_range(-jitter, jitter)
	memory["angle"] = angle
	return Vector3(sin(angle), 0.0, cos(angle))
