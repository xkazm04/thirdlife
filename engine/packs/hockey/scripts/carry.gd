extends RefCounted
## Flight, reception and the carrier's spring, sampled once per live physics step.

const KEYS := ["reach", "carry_min", "blade_base", "blade_reach", "blade_yaw_deg", "carry_reach_mult",
	"spring_k", "dangle_max", "turn_norm", "turn_min_speed", "turn_ema", "loss_ratio", "loss_frames",
	"loss_out_speed", "loss_lock_frames", "own_lock_frames", "clean_speed", "bobble_speed", "bobble_keep",
	"bobble_frames", "recv_bobble_speed", "recv_extra", "recv_cone_deg", "magnet_dist", "magnet_frames",
	"magnet_turn", "pass_loose_speed", "pass_flight_frames", "shot_loose_speed", "shot_flight_frames",
	"pass_speed", "pass_hard_speed", "pass_hard_dist", "pass_cone_deg", "pass_lead_max_frames", "poke_reach",
	"poke_cooldown_frames", "poke_speed", "poke_carry_share", "poke_frames", "poke_first", "poke_last",
	"poke_chance", "poke_front_deg", "poke_back_deg", "poke_front", "poke_side", "poke_back", "poke_cut_deg",
	"poke_cut_frames", "poke_cut_mult", "whiff_frames", "whiff_turn_mult", "steal_dist", "steal_lock",
	"poke_immune", "pinch_floor", "pinch_gain", "carry_speed_scale", "behind_net_frames", "behind_net_half_width", "ring_width"]

var c: Dictionary
var shot: Dictionary
var spring_velocity := Vector3.ZERO
var headings: Array[Vector3] = []
var turn_rate := 0.0
var dangle := 0.0
var over_line := 0
var cut := false
var contact := false
var _loose_speed := 0.0                ## N3: the loose puck's speed last frame (the pinch guard)
var flight_dir := Vector3.ZERO
var last_owner := ""
var take_after := {}
var steal_after := {}
var immune_until := 0
var armed := ""
var pending_receiver := ""
var press_frame := 0

func set_speed_ref(v: Vector3) -> void:
	_loose_speed = Vector2(v.x, v.z).length()

func setup(cfg: Dictionary, shooting: Dictionary) -> void:
	c = cfg
	shot = shooting
	for key: String in c:
		if key not in KEYS:
			push_error("tuning.json: unknown carry.%s" % key)

func reset() -> void:
	last_owner = ""
	take_after.clear()
	steal_after.clear()
	immune_until = 0
	armed = ""
	pending_receiver = ""
	contact = false

func take(a, id: String) -> void:
	armed = id if pending_receiver == id and a.from_pass and a._now - press_frame <= int(shot.one_timer_before) else ""
	pending_receiver = ""
	immune_until = 0
	if last_owner != "" and a.teams[last_owner] != a.teams[id] and not a.goalies.has(id):
		immune_until = a._now + int(c.poke_immune)
		for other: String in a.order:
			if a.teams[other] != a.teams[id] and (other == last_owner or a.pos_of(id).distance_to(a.pos_of(other)) <= float(c.steal_dist)):
				steal_after[other] = a._now + int(c.steal_lock)
	last_owner = id
	headings.clear()
	spring_velocity = Vector3.ZERO
	turn_rate = 0.0
	dangle = 0.0
	cut = false
	over_line = 0

func released(a, kind: String, id: String, v: Vector3) -> void:
	armed = ""
	pending_receiver = ""
	contact = false
	flight_dir = v.normalized()
	var lock: int = c.own_lock_frames
	match kind:
		"poked": lock = c.steal_lock
		"lost", "hit": lock = c.loss_lock_frames
	take_after[id] = maxi(take_after.get(id, 0), a._now + lock)

func velocity(a, id: String) -> Vector3:
	return a._flat(a.skaters[id].velocity)

func anchor(a, id: String) -> Vector3:
	var frac := 1.0 if a.stick_dir.has(id) else 0.5
	var length: float = a.blade_base + frac * a.blade_reach
	if not a.skate.is_sprinting(id):
		length *= a.carry_reach_mult
	return a.blade_dir(id) * maxf(length, maxf(a.configured_carry_min, a.skaters[id].body_radius() + a.puck_radius))

func follow(a) -> void:
	var id: String = a.carrier
	if id == "":
		return
	var body: TLBiped = a.skaters[id]
	var vel := velocity(a, id)
	var heading := vel.normalized() if vel.length() > float(c.turn_min_speed) else Vector3.ZERO
	var rate := 0.0
	cut = false
	if heading != Vector3.ZERO and not headings.is_empty() and headings.back() != Vector3.ZERO:
		rate = headings.back().signed_angle_to(heading, Vector3.UP) * 60.0
		for past in headings:
			if past != Vector3.ZERO and past.angle_to(heading) > deg_to_rad(c.poke_cut_deg):
				cut = true
				break
	if headings.size() >= int(c.poke_cut_frames):
		headings.pop_front()
	headings.append(heading)
	turn_rate = lerpf(turn_rate, rate, c.turn_ema)
	var top: float = a.skate.base_speed * a.skate.carry_sprint_scale
	dangle = clampf(vel.length() / top * absf(turn_rate) / float(c.turn_norm), 0, 1) * float(c.dangle_max)
	var outward: Vector3 = a.fwd_of(id).cross(Vector3.UP) * signf(turn_rate)
	over_line = over_line + 1 if a.skate.is_sprinting(id) and dangle > float(c.loss_ratio) * float(c.dangle_max) else 0
	if over_line >= int(c.loss_frames):
		a._release("lost", id, vel + outward * float(c.loss_out_speed))
		a.events.append(["lost", id])
		return
	var blade: Vector3 = body.global_basis.inverse() * (anchor(a, id) + outward * dangle)
	blade.y = 0.07
	var k: float = c.spring_k
	spring_velocity += ((blade - a.hold_at) * k - spring_velocity * (2.0 * sqrt(k))) / 60.0
	var point: Vector3 = a.hold_at + spring_velocity / 60.0
	if not a._inside(body.transform * point):
		point = a._board_point(body, blade)
		spring_velocity = Vector3.ZERO
	a.hold_at = point
	a.blade_socket.position = point

func intended(a, id: String) -> bool:
	return a.puck_state == "pass" and a.last_release.get("to", "") == id

func window(a, id: String, offset: Vector3) -> float:
	if intended(a, id) and a.fwd_of(id).dot(offset.normalized()) >= cos(deg_to_rad(c.recv_cone_deg)):
		return a.reach + float(c.recv_extra)
	return a.reach

func deflection(a) -> void:
	# The contact signal follows the rigid-body step. Publish a redirected pass immediately.
	contact = true
	if not flight_dir.is_equal_approx(a._flat(a.puck.linear_velocity).normalized()):
		a.puck_state = "loose"
		armed = ""
		pending_receiver = ""
		contact = false

func flight(a) -> void:
	var kind: String = a.puck_state
	if kind != "shot" and kind != "pass":
		return
	var vel: Vector3 = a._flat(a.puck.linear_velocity)
	var speed := vel.length()
	var age: int = a._now - int(a.last_release.frame)
	var turned := contact and not flight_dir.is_equal_approx(vel.normalized())
	contact = false
	if speed < float(c[kind + "_loose_speed"]) or age >= int(c[kind + "_flight_frames"]) or (kind == "pass" and turned):
		a.puck_state = "loose"
		armed = ""
		pending_receiver = ""
		return
	var id: String = a.last_release.get("to", "")
	if kind == "pass" and id != "":
		var to: Vector3 = a.pos_of(id) + anchor(a, id) - a.puck_pos()
		if to.length() <= float(c.magnet_dist) and to.length() * 60.0 <= speed * float(c.magnet_frames) and not to.is_zero_approx():
			var delta := vel.signed_angle_to(to, Vector3.UP)
			vel = vel.rotated(Vector3.UP, delta * float(c.magnet_turn))
			a.set_puck_velocity(Vector3(vel.x, a.puck.linear_velocity.y, vel.z))
	flight_dir = vel.normalized()

## N3: a loose puck squeezed between bodies can leave at 27 m/s with nobody's release (rookie seed 1: a face-off puck
## launched into red's net). Without a release this frame, a loose puck never gains more than pinch_gain m/s in a frame
## above max(its last speed, pinch_floor); a stick's release (shot, pass, poke) is never limited.
func _pinch(a) -> void:
	var v: Vector3 = a._flat(a.puck.linear_velocity)
	var spd := v.length()
	var released_now: bool = not a.last_release.is_empty() and int(a.last_release.get("frame", -1)) == a._now
	var cap := maxf(_loose_speed, float(c.pinch_floor)) + float(c.pinch_gain)
	if a.carrier == "" and not released_now and spd > cap:
		var w: Vector3 = v * (cap / spd)
		a.puck.linear_velocity = Vector3(w.x, a.puck.linear_velocity.y, w.z)
		spd = cap
	_loose_speed = spd if a.carrier == "" else 0.0

func pickup(a) -> void:
	_pinch(a)
	flight(a)
	var best := ""
	var best_d := INF
	var bobble := false
	var step: Array = a.puck.last_step()
	var start: Vector3 = a._flat(step[0])
	var end: Vector3 = a._flat(step[1])
	var vel: Vector3 = a._flat(a.puck.linear_velocity)
	for id: String in a.order:
		if a.goalies.has(id) or a._now < int(take_after.get(id, 0)) or not a.hits.can_act(id):
			continue
		if a._now < int(steal_after.get(id, 0)) and a.last_release.get("team", "") != a.teams[id]:
			continue
		var me: Vector3 = a.pos_of(id)
		var closest := start if start == end else Geometry3D.get_closest_point_to_segment(me, start, end)
		var offset := closest - me
		var dist := offset.length()
		if dist >= best_d or dist > window(a, id, offset):
			continue
		var r := (vel - velocity(a, id)).length()
		var recv := intended(a, id)
		if not recv and r >= float(c.bobble_speed):
			continue
		best = id
		best_d = dist
		bobble = r >= float(c.recv_bobble_speed if recv else c.clean_speed)
	if best == "":
		return
	if bobble:
		a.set_puck_velocity(vel * float(c.bobble_keep))   # N3 tuning: the research's "velocity -60 %" (world frame): a bobble no longer carries the puck along with him (red bobbled pucks into their own net)
		take_after[best] = a._now + int(c.bobble_frames)
		a.puck_state = "loose"
		a.last_release = {"kind": "bobble", "by": best, "team": a.teams[best], "frame": a._now}
		a.events.append(["bobble", best])
		armed = ""
		pending_receiver = ""
	else:
		a.give(best)

func arm(a, id: String) -> bool:
	if a._now < int(a._ready_at[id]):
		return false
	if a.carrier == id:
		if not a.from_pass or a._now - a.carry_since > int(shot.one_timer_after):
			return false
		armed = id
		return true
	if intended(a, id):
		# Judge the press against the actual take. The receiver and the magnet can both
		# change the arrival after the press, including on the last step into the ring.
		pending_receiver = id
		press_frame = a._now
		return true
	return false
