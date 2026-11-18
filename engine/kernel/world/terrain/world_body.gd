extends RefCounted
## Walker-feel (lane M, 18 Nov 2026): the body of a person's visitor, with weight. It moves the world's kinematic
## capsule (terrain/world_space.gd, `sp`) by VELOCITY, one `drive()` per world tick (60 Hz; every number below is per
## second or counted in ticks). `world_space.gd walk()` stays for the probes and a scripted walk.
##   ground   the horizontal velocity eases toward the wish: ACCEL m/s^2 while the wish has a direction, DECEL while it
##            is let go; standing still on walkable ground is not a move at all (no test, no creep).
##   air      gravity GRAVITY, falls at most FALL_MAX; a little steering (AIR_ACCEL); lands on walkable ground.
##   jump     JUMP_V up (h = JUMP_V^2 / 2g = 1.0 m, about 35 ticks in the air on flat ground); allowed COYOTE ticks
##            after walking off an edge; a press is kept BUFFER ticks, so a press just before landing still jumps.
##   slope    ground steeper than `max_slope_deg`: he slides down it, gaining speed along it (gravity projected on the
##            slope, SLOPE_FRICTION against it, at most SLOPE_MAX), steerable a little (SLOPE_STEER), until he stands on
##            walkable ground again. Walking UP into such ground is refused as before (a wall); walking DOWN onto it
##            starts the slide.
##   slide    a run slide (`slide` asked while grounded and faster than SLIDE_MIN): the speed he has is kept and decays
##            by SLIDE_DECEL; a little steering; ends below SLIDE_END or after SLIDE_MAX ticks.

var _w: WeakRef = null                 # the world's space (world_space.gd), weakly: it holds this body
var sp: Variant:
	get:
		return _w.get_ref()


func _init(space_: RefCounted) -> void:
	_w = weakref(space_)

const GRAVITY: float = 24.0
const JUMP_V: float = 6.93
const FALL_MAX: float = 40.0
const COYOTE: int = 6
const BUFFER: int = 8
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
var mode: String = "ground"           # ground | air | slope | slide
var ground_n: Vector3 = Vector3.UP
var air_ticks: int = 0                # ticks since he last stood on walkable ground
var _buffer: int = 0
var _jumped: bool = false             # this airtime began with a jump (no coyote jump after it)
var _slide_t: int = 0
var _step_t: int = 0
var _step_wish: Vector3 = Vector3.ZERO


## Starts the body at rest, standing (after a teleport: `put`, entering, leaving).
func rest() -> void:
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
	var h: Dictionary = PhysicsServer3D.space_get_direct_state(sp.space).intersect_ray(q)
	return h["normal"] if not h.is_empty() and not _walkable(h["normal"]) else Vector3.ZERO


## Down from `pos` by `reach`: {"hit", "dy", "n"}; only the vertical part of the engine's travel is kept (its
## depenetration push has a sideways part on a slope: that was the creep).
func _probe_down(pos: Vector3, reach: float) -> Dictionary:
	if sp._test(Transform3D(Basis(), pos), Vector3(0.0, -reach, 0.0)):
		return {"hit": true, "dy": sp._res.get_travel().y, "n": sp._res.get_collision_normal(0)}
	return {"hit": false, "dy": -reach, "n": Vector3.UP}


## Moves by `motion` sliding along what it meets (three times at most); a hit with walkable ground while falling is a
## landing. Returns {"pos", "hit", "land", "n"}; `vel` loses its part into every surface met.
func _slide_move(pos: Vector3, motion: Vector3) -> Dictionary:
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
			if _walkable(n) and vel.y <= 0.0:
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
			pos += rest_m
			rest_m = Vector3.ZERO
	out["pos"] = pos
	return out


## One tick of a person's body. `wish`: the horizontal velocity he asks for (m/s, world axes); `jump`, `slide`: the
## key went down this tick. Returns {"pos", "grounded", "mode", "vel", "events": ["jump" | "land" | "slide" |
## "slope" | "end_slide"], "blocked"}.
func drive(from: Vector3, wish: Vector3, jump: bool, slide: bool) -> Dictionary:
	var dt: float = 1.0 / 60.0
	var pos: Vector3 = from
	var ev: Array = []
	var hit: bool = false
	wish.y = 0.0
	sp.last_hit = {}
	# a tapped key is a step: a wish that starts from rest is kept STEP_TICKS ticks
	var hv: Vector3 = Vector3(vel.x, 0.0, vel.z)
	if wish.length() > 0.01 and hv.length() < 0.3 and _step_t <= 0 and mode == "ground":
		_step_t = STEP_TICKS
		_step_wish = wish
	if _step_t > 0:
		_step_t -= 1
		if wish.length() < 0.01:
			wish = _step_wish
	if jump:
		_buffer = BUFFER
	elif _buffer > 0:
		_buffer -= 1
	var can_jump: bool = mode == "ground" or mode == "slide" or (mode == "air" and not _jumped and air_ticks <= COYOTE)
	if _buffer > 0 and can_jump:
		if mode == "slide":
			ev.append("end_slide")
		_buffer = 0
		_jumped = true
		vel.y = JUMP_V
		mode = "air"
		grounded = false
		ev.append("jump")
	if slide and mode == "ground" and hv.length() >= SLIDE_MIN:
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
				# standing: not a move; only check that the ground is still there (a site's scaffold can go)
				vel = Vector3.ZERO
				var pd: Dictionary = _probe_down(pos, 0.05)
				if not bool(pd["hit"]):
					mode = "air"
					grounded = false
					_jumped = false
					air_ticks = 0
				sp.place(pos)
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
			var m: Dictionary = _slide_move(pos, vel * dt)
			pos = m["pos"]
			hit = bool(m["hit"])
			if bool(m["land"]):
				mode = "ground"
				grounded = true
				_jumped = false
				air_ticks = 0
				ground_n = m["n"]
				ev.append("land")
			elif vel.y <= 0.0:
				# on steep ground without falling free: a slope slide
				var pd2: Dictionary = _probe_down(pos, 0.06)
				if bool(pd2["hit"]) and not _walkable(pd2["n"]) and _steep_under(pos):
					mode = "slope"
					ground_n = pd2["n"]
					ev.append("land")
					ev.append("slope")
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
	sp.place(pos)
	return {"pos": pos, "grounded": grounded, "mode": mode, "vel": vel, "events": ev, "blocked": hit}


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
		if sp._test(Transform3D(Basis(), pos), rest_m):
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


