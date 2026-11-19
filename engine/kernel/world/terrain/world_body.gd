extends RefCounted
## Walker-feel (lane M, 18 Nov 2026): the body of a person's visitor, with weight. It moves the world's kinematic
## capsule (terrain/world_space.gd, `sp`) by VELOCITY, one `drive()` per world tick (60 Hz; every number below is per
## second or counted in ticks). `world_space.gd walk()` stays for the probes and a scripted walk.
##   ground   the horizontal velocity eases toward the wish: ACCEL m/s^2 while the wish has a direction, DECEL while it
##            is let go; standing holds position unless a floor arrives through his feet.
##   air      gravity GRAVITY, falls at most FALL_MAX; a little steering (AIR_ACCEL); lands on walkable ground.
##   jump     JUMP_V up (h = JUMP_V^2 / 2g = 1.0 m, about 35 ticks in the air on flat ground); allowed COYOTE ticks
##            after walking off an edge; a press is kept BUFFER ticks after the tick it went down, so a press up to
##            BUFFER ticks before landing still jumps, on the landing tick itself.
##            From a slope (bugfix-37 D14: a pit of steep walls was a trap) he may jump too, but the jump pushes him
##            SLOPE_JUMP_PUSH m/s away from the face as well as up: hopping never climbs a too-steep bank.
##   slope    ground steeper than `max_slope_deg`: he slides down it, gaining speed along it (gravity projected on the
##            slope, SLOPE_FRICTION against it, at most SLOPE_MAX), steerable a little (SLOPE_STEER), until he stands on
##            walkable ground again. Walking UP into such ground is refused as before (a wall); walking DOWN onto it
##            starts the slide; put at rest on it (a teleport, a game left on a bank) he slides from the first tick.
##   slide    a run slide (`slide` asked while grounded and faster than SLIDE_MIN): the speed he has is kept and decays
##            by SLIDE_DECEL; a little steering; ends below SLIDE_END or after SLIDE_MAX ticks.

var _w: WeakRef = null                 # the world's space (world_space.gd), weakly: it holds this body
var sp: Variant:
	get:
		return _w.get_ref()


func _init(space_: RefCounted) -> void:
	_w = weakref(space_)

const WALK_MPS: float = 4.5
const RUN_MPS: float = 9.0
const FLY_SCALE: float = 5.0
const FLY_CRUISE := FLY_SCALE * RUN_MPS
const FLY_CEILING: float = 120.0
const TAKEOFF_TICKS := 30
const GRAVITY: float = 24.0
const JUMP_V: float = 6.93
const FALL_MAX: float = 40.0
const COYOTE: int = 6
const BUFFER: int = 8
const SLOPE_JUMP_PUSH: float = 4.5    # m/s away from a steep face (its normal, level) on a jump from a slope
const ACCEL: float = 34.0
const DECEL: float = 42.0
const AIR_ACCEL: float = 9.0
const SNAP_DOWN: float = 0.35
const SLOPE_FRICTION: float = 3.0
const SLOPE_MAX: float = 14.0
const SLOPE_STEER: float = 4.0
const SLIDE_MIN: float = 6.0
const SLIDE_DECEL: float = 7.0
const SLIDE_END: float = 2.6
const SLIDE_MAX: int = 70
const SLIDE_STEER: float = 3.0
const STEP_TICKS: int = 9            # a wish that starts from rest is kept at least this long: a tapped key is a step

var vel: Vector3 = Vector3.ZERO       # m/s
var grounded: bool = true
var mode: String = "ground"           # ground | air | slope | slide | fly
var ground_n: Vector3 = Vector3.UP
var air_ticks: int = 0                # ticks since he last stood on walkable ground
var _turn := 0.0
var fly_turn: float:
	get:
		return _turn
var _takeoff := 0
var _walk_mask := 1
var _buffer: int = 0                  # ticks a jump press is still kept, this one included
var _jumped: bool = false             # this airtime began with a jump (no coyote jump after it)
var _slide_t: int = 0
var _step_t: int = 0
var _step_wish: Vector3 = Vector3.ZERO


## Starts the body at rest, standing (after a teleport: `put`, entering, leaving).
func rest() -> void:
	if mode == "fly":
		_fold()
	vel = Vector3.ZERO
	grounded = true
	mode = "ground"
	air_ticks = 0
	_buffer = 0
	_jumped = false
	_slide_t = 0
	_step_t = 0


func _walkable(n: Vector3) -> bool:
	return n.y >= cos(deg_to_rad(sp.max_slope_deg)) - 0.0001


## True when the ground straight under the feet (a ray from the capsule's middle, at most 1.2 m under the feet) is
## steeper than `sp.max_slope_deg`: a slope. The capsule's round foot touching an EDGE also reports a steep normal; under
## an edge the ray finds the lower ground (walkable) or nothing.
func _steep_under(pos: Vector3) -> bool:
	return _steep_n(pos) != Vector3.ZERO


## The normal of the steep ground straight under the feet (see `_steep_under`), or ZERO.
func _steep_n(pos: Vector3) -> Vector3:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 0.5, 0.0), pos + Vector3(0.0, -1.2, 0.0), 1)
	q.exclude = [sp.body]
	var h: Dictionary = PhysicsServer3D.space_get_direct_state(sp.space).intersect_ray(q)
	return h["normal"] if not h.is_empty() and not _walkable(h["normal"]) else Vector3.ZERO


## Down from `pos` by `reach`: {"hit", "dy", "n"}; only the vertical part of the engine's travel is kept (its
## depenetration push has a sideways part on a slope: that was the creep).
func _probe_down(pos: Vector3, reach: float) -> Dictionary:
	if sp._test(Transform3D(Basis(), pos), Vector3(0.0, -reach, 0.0)):
		return {"hit": true, "dy": sp._res.get_travel().y, "n": sp._res.get_collision_normal(0)}
	return {"hit": false, "dy": -reach, "n": Vector3.UP}


## Read the last down sweep. Opposing walls constrain motion to their crease.
## It can carry him if downhill gravity along that crease fits within slope friction.
func _channel_support(travel: Vector3 = Vector3.ZERO, wish_step: Vector3 = Vector3.ZERO) -> bool:
	var result: PhysicsTestMotionResult3D = sp._res
	for i in result.get_collision_count():
		var n := result.get_collision_normal(i)
		if n.y <= 0.01 or _walkable(n):
			continue
		for j in range(i + 1, result.get_collision_count()):
			var other := result.get_collision_normal(j)
			if _supports_together(n, other, travel, wish_step):
				return true
	return false


## The first normal has already been checked by the caller.
func _supports_together(n: Vector3, other: Vector3, travel: Vector3 = Vector3.ZERO, wish_step: Vector3 = Vector3.ZERO) -> bool:
	if other.y <= 0.01 or _walkable(other):
		return false
	var across := Vector2(n.x, n.z).normalized().dot(Vector2(other.x, other.z).normalized())
	var crease := n.cross(other).normalized()
	if across >= -0.5 or GRAVITY * absf(crease.y) > SLOPE_FRICTION:
		return false
	# A pocket can supply an opposing pair as well. Another face across
	# their line of travel closes the channel (the four walls of a pit).
	var contacts: PhysicsTestMotionResult3D = sp._res
	for i in contacts.get_collision_count():
		if absf(crease.dot(contacts.get_collision_normal(i))) > 0.5:
			return false
	# On landing, vertical contact recovery may mask an ongoing slide. Check
	# uncommanded downhill travel along the crease in the horizontal plane.
	var downhill := -signf(crease.y) * Vector3(crease.x, 0, crease.z)
	return absf(crease.y) < 0.0001 or travel.dot(downhill) <= maxf(0.0, wish_step.dot(downhill)) + 0.0001


## A two-sided floor can intersect the capsule so deeply that a down sweep misses
## it or only partly recovers it. Locate its upper face within one step of the feet.
func _standing_floor(pos: Vector3) -> float:
	var start := pos + Vector3.UP * (float(sp.step_up) + 0.001)
	var q := PhysicsRayQueryParameters3D.create(start, pos, 1)
	q.exclude = [sp.body]
	var h: Dictionary = PhysicsServer3D.space_get_direct_state(sp.space).intersect_ray(q)
	# Ignore centre-ray roundoff when he was placed exactly on an existing bank.
	if h.is_empty() or not _walkable(h.normal) or h.position.y <= pos.y + 0.0001:
		return pos.y
	var y: float = h.position.y
	if h.normal.y < 0.99999:
		# The capsule contacts an inclined floor to one side of the centre ray.
		var pad := _probe_down(start, start.y - pos.y)
		if not pad.hit or not _walkable(pad.n):
			return pos.y
		y = maxf(y, start.y + pad.dy)
	if y - pos.y > float(sp.step_up) + 0.000001:
		return pos.y
	y = minf(y, pos.y + sp.step_up)
	# Check the destination: sweeping UP from inside a two-sided floor can hit its underside.
	var fit := PhysicsTestMotionParameters3D.new()
	fit.from = Transform3D(Basis(), Vector3(pos.x, y, pos.z))
	fit.margin = 0.001
	fit.recovery_as_collision = true
	if PhysicsServer3D.body_test_motion(sp.body, fit, sp._res) and sp._res.get_collision_depth(0) > fit.margin:
		return pos.y
	return y


## Moves by `motion` sliding along what it meets (three times at most); a hit with walkable ground while falling is a
## landing. Returns {"pos", "hit", "land", "n"}; `vel` loses its part into every surface met.
func _slide_move(pos: Vector3, motion: Vector3, descending: bool = false) -> Dictionary:
	var rest_m: Vector3 = motion
	var out: Dictionary = {"hit": false, "land": false, "n": Vector3.UP}
	for it: int in 3:
		if rest_m.length() < 0.0005:
			break
		if sp._test(Transform3D(Basis(), pos), rest_m):
			out["hit"] = true
			var n: Vector3 = sp._res.get_collision_normal(0)
			sp.last_hit = {"tag": sp._tags.get(sp._res.get_collider_rid(0), "?"), "at": sp._res.get_collision_point(0), "n": n, "from": pos}
			pos += sp._res.get_travel()
			var rem: Vector3 = sp._res.get_remainder()
			if mode == "fly":
				var rid: RID = sp._res.get_collider_rid(0)
				sp.last_hit["rid"] = rid
				var layer := PhysicsServer3D.body_get_collision_layer(rid)
				if descending and (layer & 1) and _walkable(n):
					out.land = true
					out.n = n
			elif _walkable(n) and vel.y <= 0.0:
				out["land"] = true
				out["n"] = n
				rem.y = 0.0
				vel.y = 0.0
				rest_m = rem
				continue
			if vel.dot(n) < 0.0:
				vel -= n * vel.dot(n)
			rest_m = rem - n * rem.dot(n)
		else:
			# A free sweep can still depenetrate its start. Keep that travel in flight,
			# especially on the tangent sweep immediately after a crown contact.
			pos += sp._res.get_travel() if mode == "fly" else rest_m
			rest_m = Vector3.ZERO
	out["pos"] = pos
	return out


## Read before a pack's sweep so the capsule can shorten on the very tick the slide is accepted.
func can_start_slide() -> bool:
	return mode == "ground" and Vector2(vel.x, vel.z).length() >= SLIDE_MIN


## One tick of a person's body. `wish`: the horizontal velocity he asks for (m/s, world axes); `jump`, `slide`: the
## key went down this tick. A brake cancels even a tapped step. Returns {"pos", "grounded", "mode", "vel", "events": ["jump" | "land" | "slide" |
## "slope" | "end_slide"], "blocked"}.
func drive(from: Vector3, wish: Vector3, jump: bool, slide: bool, brake: bool = false, toggle_fly: bool = false, climb: float = 0.0, cruise: float = FLY_CRUISE) -> Dictionary:
	var dt: float = 1.0 / 60.0
	var pos: Vector3 = from
	var ev: Array = []
	var hit: bool = false
	wish.y = 0.0
	sp.last_hit = {}
	if toggle_fly:
		if mode == "fly":
			_fold()
			mode = "air"
			_jumped = true
			ev.append("fly_end")
		else:
			_takeoff = TAKEOFF_TICKS if grounded else 0
			_walk_mask = PhysicsServer3D.body_get_collision_mask(sp.body)
			PhysicsServer3D.body_set_collision_mask(sp.body, _walk_mask | 4)
			grounded = false
			mode = "fly"
			_buffer = 0
			_step_t = 0
			_slide_t = 0
			ev.append("fly_start")
	if mode == "fly":
		return _fly(pos, Vector3.ZERO if brake else wish, climb, cruise, ev)
	# a tapped key is a step: a wish that starts from rest is kept STEP_TICKS ticks
	var hv: Vector3 = Vector3(vel.x, 0.0, vel.z)
	if brake:
		_step_t = 0
		wish = Vector3.ZERO
	elif wish.length() > 0.01 and hv.length() < 0.3 and _step_t <= 0 and mode == "ground":
		_step_t = STEP_TICKS
		_step_wish = wish
	if _step_t > 0:
		_step_t -= 1
		if wish.length() < 0.01:
			wish = _step_wish
	if jump:
		_buffer = BUFFER + 1                     # the press tick and BUFFER ticks after it
	elif _buffer > 0:
		_buffer -= 1
	# air_ticks counts completed air ticks, before the current press.
	var can_jump: bool = mode == "ground" or mode == "slide" or mode == "slope" or (mode == "air" and not _jumped and air_ticks < COYOTE)
	if _buffer > 0 and can_jump:
		_take_jump(ev)
	if slide and can_start_slide():
		mode = "slide"
		_slide_t = 0
		ev.append("slide")
	match mode:
		"ground", "slide":
			if mode == "ground":
				var rate: float = ACCEL if wish.length() > 0.01 and wish.dot(hv) >= -0.01 else DECEL
				hv = hv.move_toward(wish, rate * dt)
			else:
				_slide_t += 1
				var spd: float = maxf(0.0, hv.length() - SLIDE_DECEL * dt)
				var dir: Vector3 = hv.normalized() if hv.length() > 0.01 else Vector3.ZERO
				if wish.length() > 0.01 and dir != Vector3.ZERO:
					dir = (dir + wish.normalized() * SLIDE_STEER * dt / maxf(spd, 1.0)).normalized()
				hv = dir * spd
				if spd < SLIDE_END or _slide_t >= SLIDE_MAX:
					mode = "ground"
					ev.append("end_slide")
			vel = Vector3(hv.x, 0.0, hv.z)
			if hv.length() < 0.0005:
				# A scaffold can disappear, or the floor of an arriving game can replace a lower pad.
				vel = Vector3.ZERO
				var pd: Dictionary = _probe_down(pos, 0.05)
				if not pd.hit or (pd.dy > 0.0 and _walkable(pd.n)):
					var floor_y := _standing_floor(pos)
					if floor_y > pos.y:
						pos.y = floor_y
						pd = _probe_down(pos, 0.05)
				if not bool(pd["hit"]):
					mode = "air"
					grounded = false
					_jumped = false
					air_ticks = 0
				elif mode == "ground" and not _walkable(pd["n"]) and not _channel_support() and _steep_under(pos):
					# put at rest on ground steeper than the limit (D6): not a place to stand, the slope slide begins
					mode = "slope"
					grounded = false
					ground_n = pd["n"]
					ev.append("slope")
				return {"pos": pos, "grounded": grounded, "mode": mode, "vel": vel, "events": ev, "blocked": false}
			var r: Dictionary = _ground_move(pos, hv * dt)
			pos = r["pos"]
			hit = bool(r["blocked"])
			if hit:
				var n: Vector3 = (sp.last_hit.get("n", Vector3.ZERO) as Vector3)
				n.y = 0.0
				if n.length() > 0.001:
					n = n.normalized()
					if vel.dot(n) < 0.0:
						vel -= n * vel.dot(n)
				else:
					vel = Vector3.ZERO                 # refused by a steep slope ahead: he stops there
			if str(r["state"]) == "air":
				mode = "air"
				grounded = false
				_jumped = false
				air_ticks = 0
				if ev.has("slide") or _slide_t > 0:
					ev.append("end_slide")
			elif str(r["state"]) == "slope":
				mode = "slope"
				grounded = false
				ev.append("slope")
			else:
				grounded = true
				air_ticks = 0
		"air":
			air_ticks += 1
			vel.y = maxf(vel.y - GRAVITY * dt, -FALL_MAX)
			if wish.length() > 0.01:
				var ah: Vector3 = Vector3(vel.x, 0.0, vel.z)
				var target: Vector3 = wish
				if target.length() < ah.length():
					target = target.normalized() * ah.length()     # steering in the air never brakes him
				ah = ah.move_toward(target, AIR_ACCEL * dt)
				vel.x = ah.x
				vel.z = ah.z
			var falling := vel.y <= 0.0
			var m: Dictionary = _slide_move(pos, vel * dt)
			pos = m["pos"]
			hit = bool(m["hit"])
			if not m.land and vel.y <= 0.0:
				var pd2: Dictionary = _probe_down(pos, 0.06)
				if pd2.hit and not _walkable(pd2.n):
					if falling and hit and pos.y >= from.y - 0.001 and _channel_support(pos - from, wish * dt):
						m.land = true
						m.n = Vector3.UP
						vel.y = 0.0
					elif _steep_under(pos):
						mode = "slope"
						ground_n = pd2.n
						ev.append("land")
						ev.append("slope")
			if bool(m["land"]):
				mode = "ground"
				grounded = true
				_jumped = false
				air_ticks = 0
				ground_n = m["n"]
				ev.append("land")
				if _buffer > 0:
					_take_jump(ev)                       # a buffered press jumps on the landing tick (D20)
		"slope":
			var n2: Vector3 = ground_n
			var g: Vector3 = Vector3(0.0, -GRAVITY, 0.0)
			var along: Vector3 = g - n2 * g.dot(n2)                # gravity along the slope
			vel += along * dt
			vel -= vel.normalized() * minf(vel.length(), SLOPE_FRICTION * dt) if vel.length() > 0.0 else Vector3.ZERO
			if wish.length() > 0.01:
				var side: Vector3 = wish.normalized() - n2 * wish.normalized().dot(n2)
				var down: Vector3 = along.normalized() if along.length() > 0.001 else Vector3.ZERO
				side -= down * side.dot(down)                        # steering across the slope, never up it
				vel += side * SLOPE_STEER * dt
			vel = vel - n2 * vel.dot(n2)
			if vel.length() > SLOPE_MAX:
				vel = vel.normalized() * SLOPE_MAX
			var m2: Dictionary = _slide_move(pos, vel * dt)
			pos = m2["pos"]
			var pd3: Dictionary = _probe_down(pos, SNAP_DOWN)
			if bool(pd3["hit"]):
				pos.y += float(pd3["dy"])
				ground_n = pd3["n"]
				if pos.y >= from.y - 0.001 and absf(pd3.dy) <= 0.06 and _channel_support(pos - from, wish * dt):
					ground_n = Vector3.UP
				if _walkable(ground_n):
					mode = "ground"
					grounded = true
					air_ticks = 0
					_jumped = false
					vel.y = 0.0
					ev.append("end_slide")
			else:
				mode = "air"
				_jumped = true                       # no coyote jump off a slide
				air_ticks = 0
				ev.append("end_slide")
	if hit:
		sp.blocked_ticks += 1
	return {"pos": pos, "grounded": grounded, "mode": mode, "vel": vel, "events": ev, "blocked": hit}


func _fold() -> void:
	PhysicsServer3D.body_set_collision_mask(sp.body, _walk_mask)
	_takeoff = 0
	_turn = 0.0


func _fly(pos: Vector3, wish: Vector3, climb: float, cruise: float, events: Array) -> Dictionary:
	var horizontal := Vector3(vel.x, 0, vel.z)
	var speed := horizontal.length()
	var goal := wish.length()
	var heading := horizontal.normalized() if speed > 0.001 else wish.normalized()
	_turn = 0.0
	if goal > 0.001 and speed > 0.001:
		var rate := deg_to_rad(lerpf(300.0, 140.0, clampf(speed / maxf(0.01, cruise), 0, 1)))
		var angle := heading.signed_angle_to(wish.normalized(), Vector3.UP)
		_turn = clampf(angle * 60, -rate, rate)
		heading = heading.rotated(Vector3.UP, _turn / 60)
	# Cap initial thrust, then taper it as cruise approaches. Drag tails off to a stop.
	var dv := absf(goal - speed) * (0.051 if goal > speed else 0.042)
	horizontal = heading * move_toward(speed, goal, clampf(dv, 0.12, 1.5))
	vel.x = horizontal.x
	vel.z = horizontal.z
	if _takeoff > 0 and is_zero_approx(climb):
		var t := TAKEOFF_TICKS - _takeoff
		# Integrated half cosine: zero endpoint speeds, exactly 2.5 m over 30 sweeps.
		vel.y = 75.0 * (cos(PI * t / TAKEOFF_TICKS) - cos(PI * (t + 1) / TAKEOFF_TICKS))
		_takeoff -= 1
	else:
		_takeoff = 0
		vel.y = move_toward(vel.y, clampf(climb, -1, 1) * RUN_MPS, RUN_MPS / 18.0)
	var floor_y: float = sp.ground_at(pos.x + vel.x / 60, pos.z + vel.z / 60, pos.y + 0.05)
	if is_finite(floor_y):
		var room := floor_y + FLY_CEILING - pos.y
		vel.y = minf(vel.y, room * (60.0 if room < 0.0 else 4.0))
	var motion := _slide_move(pos, vel / 60, climb < 0 or vel.y < -0.5)
	if motion.land:
		_fold()
		mode = "ground"
		grounded = true
		ground_n = motion.n
		air_ticks = 0
		vel.y = 0
		events.append("fly_land")
	if motion.hit:
		sp.blocked_ticks += 1
	return {"pos": motion.pos, "grounded": grounded, "mode": mode, "vel": vel, "events": events, "blocked": motion.hit, "fly_turn": _turn}


## A jump now, from ground, a slide, a slope or the coyote air (`can_jump`). From a slope he is pushed away from the
## face as well (SLOPE_JUMP_PUSH along its level normal): out of a pit, never up a bank by hopping.
func _take_jump(ev: Array) -> void:
	if mode == "slide" or mode == "slope":
		ev.append("end_slide")
	if mode == "slope":
		var away: Vector3 = Vector3(ground_n.x, 0.0, ground_n.z)
		if away.length() > 0.001:
			vel += away.normalized() * SLOPE_JUMP_PUSH
	_buffer = 0
	_jumped = true
	vel.y = JUMP_V
	mode = "air"
	grounded = false
	ev.append("jump")


## The ground part of drive(): lift by the step, move `delta` (horizontal) sliding along what it meets, then put him
## down by at most step + SNAP_DOWN. Returns {"pos", "blocked", "state": "ground" | "air" | "slope"}. Only the
## vertical part of the drop's travel is kept.
func _ground_move(from: Vector3, delta: Vector3) -> Dictionary:
	var pos: Vector3 = from
	var rest_m: Vector3 = Vector3(delta.x, 0.0, delta.z)
	var hit: bool = false
	var up: Vector3 = Vector3(0.0, sp.step_up, 0.0)
	if sp._test(Transform3D(Basis(), pos), up):
		up = sp._res.get_travel()
		up.x = 0.0
		up.z = 0.0
	pos += up
	for it: int in 3:
		if rest_m.length() < 0.0005:
			break
		# Sweep with 1 mm of clearance here. With the 3 cm ground-probe margin,
		# recovery can shift the sweep so far back that a short push misses the wall.
		if sp._test(Transform3D(Basis(), pos), rest_m, 0.001):
			hit = true
			sp.last_hit = {"tag": sp._tags.get(sp._res.get_collider_rid(0), "?"), "at": sp._res.get_collision_point(0), "n": sp._res.get_collision_normal(0), "from": pos}
			var travel: Vector3 = sp._res.get_travel()
			travel.y = 0.0
			pos += travel
			var rem: Vector3 = sp._res.get_remainder()
			var nrm: Vector3 = sp._res.get_collision_normal(0)
			nrm.y = 0.0
			rest_m = rem - nrm.normalized() * rem.dot(nrm.normalized()) if nrm.length() > 0.001 else Vector3.ZERO
			rest_m.y = 0.0
		else:
			pos += rest_m
			rest_m = Vector3.ZERO
	var pd: Dictionary = _probe_down(pos, up.y + SNAP_DOWN)
	if not bool(pd["hit"]):
		pos.y -= up.y                                # nothing within a step: he walked off an edge and falls from here
		return {"pos": pos, "blocked": hit, "state": "air"}
	var n: Vector3 = pd["n"]
	if _walkable(n):
		pos.y += float(pd["dy"])
		ground_n = n
		return {"pos": pos, "blocked": hit, "state": "ground"}
	var landed: Vector3 = pos + Vector3(0.0, float(pd["dy"]), 0.0)
	if n.y > 0.01 and absf(landed.y - from.y) <= SNAP_DOWN:
		if _channel_support():
			ground_n = Vector3.UP
			return {"pos": landed, "blocked": hit, "state": "ground"}
		# The step-down sweep can touch one side of a bending channel first.
		# Let the foot settle along that face only if the other wall actually catches it.
		var settle := Vector3.DOWN.slide(n).normalized() * 0.06
		if sp._test(Transform3D(Basis(), landed), settle):
			for i in sp._res.get_collision_count():
				if _supports_together(n, sp._res.get_collision_normal(i)):
					ground_n = Vector3.UP
					return {"pos": landed + sp._res.get_travel(), "blocked": hit, "state": "ground"}
	var sn: Vector3 = _steep_n(landed)
	if sn == Vector3.ZERO:
		pos.y -= up.y                                # the round foot met an edge, not a slope: he walks off it and falls
		return {"pos": pos, "blocked": hit, "state": "air"}
	var downhill: Vector3 = Vector3(sn.x, 0.0, sn.z)
	if landed.y < from.y - 0.02 or (downhill.length() > 0.001 and delta.dot(downhill) > 0.0):
		ground_n = sn                                # down onto steep ground: the slope slide begins
		return {"pos": landed, "blocked": hit, "state": "slope"}
	# up onto steep ground: refused, he stays where he was (a wall, as before)
	sp.last_hit = {"tag": "slope", "at": landed, "n": Vector3.ZERO, "from": from}
	return {"pos": from, "blocked": true, "state": "ground"}


