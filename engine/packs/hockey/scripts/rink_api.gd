extends RefCounted
## Possession, blade placement, release and recovery. Distances and timings come from carry and shoot tuning.

var skate
var rink_root: Node3D
var puck: TLBall
var skaters: Dictionary = {}
var teams: Dictionary = {}
var order: Array = []
var speed: float                ## shot speed, m/s
var charge_frames: int
var charge_bonus: float
var tap_frames: int
var shot_held := false
var held_frames := 0
var cooldown_frames: int
var reach: float                 ## carry: the reach circle's radius, m
var blade_base: float
var blade_reach: float
var blade_yaw: float
var carry_reach_mult: float
var carry
var poke
var puck_state := "loose"
var poke_tries := {}
var last_carried: Dictionary = {}      ## Last frame each skater released or lost possession.
var yaw_rigs: Array[Node3D] = []
var yaw_ids: Array[String] = []
var yaw_bodies: Array[TLBiped] = []
var headless := false                  ## no stick posing without a window (set by main.gd)
var yaw_now: PackedFloat32Array = []   ## per yaw rig: the stick_yaw it is given now (rad, + = left)
var pass_speed: float
var pass_cone_dot: float
var pass_lead_max_frames: int
var poke_reach: float
var rink_half: Vector2 = Vector2(30.0, 15.0)
var rink_corner: float = 5.0
var rink_margin: float = 0.35

var carrier: String = ""               ## "" = the puck is loose
var carry_since: int = 0
var behind_frames: int = 0             ## H6: frames the carrier has stayed in the zone behind his own net
var behind_limit: int = 90
var net_zone_half: float = 3.5
var own_goal_x: Dictionary = {}         ## team -> x of its own goal line
var configured_carry_min: float
var puck_radius: float
var carry_min: float = 1.0             ## H9a: the nearest the puck is carried to his centre (clear of his body)
var blade_socket: Node3D
var hold_at: Vector3 = Vector3.ZERO      ## where on him the puck is held now (the stick side, or another side at the boards)
var last_release: Dictionary = {}      ## {kind: shot|pass|poked|board, by, team, frame}; empty after a face-off
var shots: Dictionary = {}
var passes: Dictionary = {}
var pokes: Dictionary = {}
var takes: Dictionary = {}
var events: Array = []                 ## [kind, id] since main last drained it (kind: shot, pass, poke, take)
var _now: int = 0
var _ready_at: Dictionary = {}
var aim_at: Dictionary = {}             ## L5: id -> the point the human's cursor is on: a shot leaves the blade at it
var one_timer_scale: float = 1.0       ## L5b: its speed factor
var from_pass: bool = false            ## L5b: the carrier took the puck from his own side's pass
var timer_aim := Vector3.ZERO
var one_timers: Dictionary = {}        ## L5b: id -> one-timers
var goalies: Dictionary = {}            ## L5: goalie id -> team: no pass goes to him, nobody pokes the puck off him
var stick_dir: Dictionary = {}          ## H4: id -> where his stick points (the human's aim); absent = his facing
var poke_cone_dot: float = -1.0         ## H4: a poke with a stick direction reaches only inside this cone
var hits = null:                       ## scripts/hits.gd (H2): a man down or stumbling cannot take the puck
	get:                                 # hunt2 A8: held weakly (hits.gd holds this helper; main.gd holds both), so the
		return _hits_ref.get_ref() if _hits_ref != null else null   # pair is freed with the pack, never a cycle
	set(v):
		_hits_ref = weakref(v) if v != null else null
var _hits_ref: WeakRef = null

func setup(tune: Dictionary, p: TLBall, sk: Dictionary, tm: Dictionary, ord: Array, root: Node3D) -> void:
	rink_root = root
	var s: Dictionary = tune["shoot"]
	# JamSim.cpp:2786-2809,2850-2854; JamCartridge.h:320-321,340.
	for key: String in s:
		if key not in ["speed", "cooldown_s", "one_timer_before", "one_timer_after", "one_timer_release", "one_timer_scale", "charge_frames", "charge_bonus", "tap_frames"]:
			push_error("tuning.json: unknown shoot.%s" % key)
	charge_frames = s["charge_frames"]
	charge_bonus = s["charge_bonus"]
	tap_frames = s["tap_frames"]
	speed = float(s["speed"])
	cooldown_frames = int(round(float(s["cooldown_s"]) * 60.0))
	one_timer_scale = float(s["one_timer_scale"])
	var c: Dictionary = tune["carry"]
	reach = float(c["reach"])
	# JamSim.cpp:1478-1545,4160-4177; JamCartridge.h:159,182-189,295. Radians and frames are fixed per rink.
	blade_yaw = -deg_to_rad(float(c["blade_yaw_deg"]))
	carry.setup(c, s)
	blade_base = c["blade_base"]
	blade_reach = c["blade_reach"]
	carry_reach_mult = c["carry_reach_mult"]
	pass_speed = float(c["pass_speed"])
	pass_cone_dot = cos(deg_to_rad(float(c["pass_cone_deg"])))
	pass_lead_max_frames = int(c["pass_lead_max_frames"])
	poke_reach = float(c["poke_reach"])
	configured_carry_min = float(c["carry_min"])
	puck_radius = tune["puck"]["radius"]
	behind_limit = int(c["behind_net_frames"])
	net_zone_half = float(c["behind_net_half_width"])
	own_goal_x = {"blue": float(tune["goals"]["blue"][0]), "red": float(tune["goals"]["red"][0])}
	var r: Dictionary = tune["rink"]
	rink_half = Vector2(float(r["half_length"]), float(r["half_width"]))
	rink_corner = float(r["corner_r"])
	rink_margin = float(r["margin"])
	puck = p
	skaters = sk
	teams = tm
	order = ord
	for id: String in order:
		var rig = (skaters[id] as TLBiped).rig
		# L2's fight clips came with the rig param stick_yaw (engine/rigs/RIGS.md "stick_yaw"): a rig that has them turns its stick
		if rig != null and rig.clips().has("cross_check") and rig.socket(&"stick_blade") != null:
			yaw_rigs.append(rig)
			yaw_ids.append(id)
			yaw_bodies.append(sk[id])
			yaw_now.append(0.0)
		shots[id] = 0
		passes[id] = 0
		pokes[id] = 0
		takes[id] = 0
		_ready_at[id] = 0
		poke_tries[id] = 0

func tick(frame: int) -> void:
	_now = frame

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

## Pack-authored changes set the reference for the next physics step.
func set_puck_velocity(v: Vector3) -> void:
	puck.linear_velocity = v
	carry.set_speed_ref(v)

func place_puck(at: Vector3) -> void:
	puck.place(at)
	carry.set_speed_ref(Vector3.ZERO)

func pos_of(id: String) -> Vector3:
	return _flat((skaters[id] as Node3D).global_position)

func fwd_of(id: String) -> Vector3:
	return _flat((skaters[id] as TLBiped).forward()).normalized()

## H4: where a skater's stick points: the aim's heading when the human has one, else the way he faces (as before H4).
func stick_of(id: String) -> Vector3:
	if stick_dir.has(id):
		return stick_dir[id]
	return fwd_of(id)

func puck_pos() -> Vector3:
	return _flat(puck.global_position)

## Distance from a skater to the puck's path of the last physics step (a fast puck cannot jump his circle).
func dist_to_puck(id: String) -> float:
	var step: Array = puck.last_step()
	return _path_distance(pos_of(id), _flat(step[0]), _flat(step[1]) - _flat(step[0]))

func _path_distance(p: Vector3, a: Vector3, ab: Vector3) -> float:
	var length_sq := ab.length_squared()
	var t := 0.0 if length_sq < 1e-8 else clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func in_reach(id: String) -> bool:
	return carrier == "" and dist_to_puck(id) <= reach

## Called once a tick before anybody acts: the carried puck stays on the ice, a loose one becomes the nearest
## eligible skater's whose reach it is inside.
func update_possession() -> void:
	if carrier != "":
		# H6: a carrier who stays behind his own net longer than behind_net_frames loses the puck's protection there:
		# an opponent whose reach it is in takes it (else a match could stall there until the time limit)
		var gx: float = float(own_goal_x[str(teams[carrier])])
		var pp: Vector3 = puck_pos()
		if (puck.position.x - gx) * signf(gx) > 0.0 and absf(puck.position.z) < net_zone_half:
			behind_frames += 1
		else:
			behind_frames = 0
		if behind_frames > behind_limit:
			var best_o: String = ""
			var best_od: float = reach
			for oid: String in order:
				if str(teams[oid]) == str(teams[carrier]) or (hits != null and not hits.can_act(oid)):
					continue
				var od: float = pos_of(oid).distance_to(pp)
				if od <= best_od:
					best_o = oid
					best_od = od
			if best_o != "":
				behind_frames = 0
				give(best_o)
				return
			if behind_frames > behind_limit * 2:
				# Nobody can reach him behind the net:
				# place it in front in pack coordinates, with the lock of a hit.
				var by: String = carrier
				behind_frames = 0
				_release("hit", by, Vector3.ZERO)
				var spot := Vector3(gx - signf(gx) * 2.0, 0.07, clampf(puck.position.z, -3.0, 3.0))
				place_puck(rink_root.to_global(spot))
				return
		return
	carry.pickup(self)

## JamSim.cpp:1478-1500. The un-aimed blade rests on the rig's right side.
func blade_dir(id: String) -> Vector3:
	if goalies.has(id):
		# L4 (21 Nov): a goalie holds the puck on the ice side of his body, never toward his own net: his outlet pass left
		# from a blade 1.1 m behind him, inside the net, and an idle hand won a rookie match by it (ladder seed 6)
		return Vector3(-signf(float(own_goal_x[str(teams[id])])), 0.0, 0.0)
	if stick_dir.has(id):
		return stick_of(id)
	return fwd_of(id).rotated(Vector3.UP, blade_yaw)

func pose_sticks() -> void:
	if headless:
		return                               # drawing only (the rig's stick pose; nothing hashed reads it), as fun.gd's bursts
	for i in yaw_rigs.size():
		if yaw_bodies[i].is_down():
			continue
		var id := yaw_ids[i]
		var rig: Node3D = yaw_rigs[i]
		# RIGS.md stick_yaw: + = left, relative to where the blade rests, which moves with the pose: steer it in a loop on the
		# drawn blade's bearing (the socket, read after the rig's last tick) toward the puck's blade bearing, half the gap a frame
		var at: Vector3 = rig.global_transform.affine_inverse() * (rig.socket(&"stick_blade") as Node3D).global_position
		var target := blade_dir(id) if id != carrier else _flat(yaw_bodies[i].global_basis * hold_at)
		var gap: float = angle_difference(atan2(-at.x, -at.z), fwd_of(id).signed_angle_to(target, Vector3.UP))
		yaw_now[i] = clampf(yaw_now[i] + 0.5 * gap, -1.2, 2.0)
		rig.set_param(&"stick_yaw", yaw_now[i])

func _follow_blade() -> void:
	carry.follow(self)

func _board_point(body: TLBiped, blade: Vector3) -> Vector3:
	var cm := carry_min
	for p: Vector3 in [_flat(blade).normalized() * cm, Vector3(-blade.x, 0, blade.z),
			Vector3.FORWARD * cm, Vector3.LEFT * cm, Vector3.RIGHT * cm, Vector3.BACK * cm]:
		p.y = blade.y
		if _inside(body.transform * p):
			return p
	var inward := body.transform.basis.inverse() * -_flat(body.position).normalized() * cm
	inward.y = blade.y
	return inward

func give(id: String) -> void:
	if carrier != "":
		_drop()
	from_pass = puck_state == "pass" and not last_release.is_empty() and str(last_release["kind"]) == "pass" and str(last_release["team"]) == str(teams[id]) \
		and str(last_release["by"]) != id
	carry.take(self, id)
	carrier = id
	puck_state = "carried"
	carry_min = maxf(configured_carry_min, (skaters[id] as TLBiped).body_radius() + puck_radius)
	carry_since = _now
	behind_frames = 0
	takes[id] = int(takes[id]) + 1
	var local: Vector3 = (skaters[id] as Node3D).global_transform.affine_inverse() * puck.global_position
	local.y = 0.07
	hold_at = local
	var body: TLBiped = skaters[id]
	blade_socket = body.get_node_or_null("PuckSocket")
	if blade_socket == null:
		blade_socket = Node3D.new()
		blade_socket.name = "PuckSocket"
		body.add_child(blade_socket)
	blade_socket.position = local
	puck.hold(blade_socket)
	events.append(["take", id])

func _drop() -> void:
	cancel_charge()
	last_carried[carrier] = _now
	carrier = ""
	puck_state = "loose"
	carry.armed = ""
	puck.release(Vector3.ZERO)
	carry.set_speed_ref(Vector3.ZERO)

## A face-off or a drill: nobody has it, no lock.
func reset() -> void:
	if carrier != "":
		_drop()
	puck_state = "loose"
	carry.reset()
	poke.reset()
	last_release = {}
	last_carried.clear()

func _release(kind: String, by: String, vel: Vector3) -> void:
	cancel_charge()
	last_carried[by] = _now
	carrier = ""
	puck_state = kind if kind in ["pass", "shot"] else "loose"
	carry.released(self, kind, by, vel)
	puck.release(vel)
	carry.set_speed_ref(vel)
	last_release = {"kind": kind, "by": by, "team": str(teams[by]), "frame": _now}

## Sets each skater's top speed for this frame: carrying is slower, sprinting faster (numbers in data).
func apply_speeds() -> void:
	skate.tick()

func can_shoot(id: String) -> bool:
	return carrier == id and _now >= int(_ready_at[id])

func cancel_charge() -> void:
	shot_held = false
	held_frames = 0

## JamSim.cpp:2786-2809, JamCartridge.h:73. Only a fresh carrier press arms a release.
func charge_input(pressed: bool, first: bool, released: bool) -> void:
	if first:
		if try_one_timer("b0"):
			cancel_charge()
			return
		shot_held = carrier == "b0"
	if pressed:
		if shot_held and can_shoot("b0"):
			held_frames = mini(held_frames + 1, charge_frames)
		return
	if released and shot_held and held_frames > 0:
		try_shoot("b0", held_frames)
	cancel_charge()

func try_shoot(id: String, frames := 0) -> bool:
	if not can_shoot(id):
		return false
	var sp := speed
	if frames > tap_frames:
		sp += charge_bonus * mini(frames, charge_frames) / charge_frames
	var direction := shot_dir(id)
	if carry.armed == id and from_pass:
		if _now - carry_since < int(carry.shot.one_timer_release):
			return false
		if timer_aim != Vector3.ZERO:
			direction = timer_aim
		sp = maxf(sp, speed * one_timer_scale)                # L5b: a one-timer: shot straight off a mate's pass, harder
		one_timers[id] = int(one_timers.get(id, 0)) + 1
		events.append(["one_timer", id])
	_release("shot", id, direction * sp)
	_clip(id, &"shoot")
	_ready_at[id] = _now + cooldown_frames
	shots[id] = int(shots[id]) + 1
	events.append(["shot", id])
	return true

## L5: where a shot goes: from the blade at the cursor's point when he has one at least 4 m away and in front of the
## stick (before, it left parallel to the stick from the blade, 1.24 m to the right of the cursor), else along the stick.
func shot_dir(id: String) -> Vector3:
	var st: Vector3 = stick_of(id)
	if aim_at.has(id):
		var to: Vector3 = _flat(aim_at[id]) - puck_pos()
		if to.length() >= 4.0 and to.normalized().dot(st) > 0.5:
			return to.normalized()
	return st

## The mate nearest his facing inside the pass cone, or "".
func pass_target(id: String) -> String:
	var me: Vector3 = pos_of(id)
	var f: Vector3 = stick_of(id)
	var best: String = ""
	var best_dot: float = pass_cone_dot
	for mid: String in order:
		if mid == id or str(teams[mid]) != str(teams[id]) or goalies.has(mid):
			continue
		var to: Vector3 = pos_of(mid) - me
		if to.length() < 1.5:
			continue
		var dt: float = f.dot(to.normalized())
		if dt >= best_dot:
			best_dot = dt
			best = mid
	return best

## Where a pass to `mid` should go: where he will be when it arrives (two refinements, lead bounded in data).
func pass_speed_to(mid: String) -> float:
	return pass_speed_at(puck_pos().distance_to(pos_of(mid))) if mid != "" else pass_speed

func pass_speed_at(distance: float) -> float:
	if distance > float(carry.c.pass_hard_dist):
		return carry.c.pass_hard_speed
	return pass_speed

func lead_point(mid: String) -> Vector3:
	var from: Vector3 = puck_pos()
	var mp: Vector3 = pos_of(mid)
	var mv: Vector3 = _flat((skaters[mid] as TLBiped).velocity)
	return projected_lead(from, mp, mv)

func projected_lead(from: Vector3, mp: Vector3, mv: Vector3) -> Vector3:
	var tgt: Vector3 = mp
	var launch_speed := pass_speed_at(from.distance_to(mp))
	for i: int in 2:
		var t: float = minf(from.distance_to(tgt) / launch_speed, float(pass_lead_max_frames) / 60.0)
		tgt = mp + mv * t
	return tgt

func try_pass(id: String, receiver := "") -> bool:
	if carrier != id or carry.armed == id:
		return false
	var mid: String = pass_target(id) if receiver.is_empty() else receiver
	var dir: Vector3 = stick_of(id)
	if mid != "" and (receiver.is_empty() or not stick_dir.has(id)):
		var to: Vector3 = lead_point(mid) - puck_pos()
		if to.length() > 0.1:
			dir = to.normalized()
	_release("pass", id, dir * pass_speed_to(mid))
	_clip(id, &"pass")
	if mid != "":
		last_release["to"] = mid
	passes[id] = int(passes[id]) + 1
	events.append(["pass", id])
	return true

func try_dump(id: String, dir: Vector3) -> bool:
	if carrier != id or carry.armed == id or dir.is_zero_approx():
		return false
	_release("dump", id, dir.normalized() * pass_speed)
	_clip(id, &"pass")
	return true

## The mate a pass is meant for skates to meet it while it is loose and moving: towards the nearest point of its
## path ahead of the puck. Vector3.ZERO when he is not receiving.
func receive_dir(id: String, observation: Dictionary = {}) -> Vector3:
	var pp: Vector3
	var v: Vector3
	if observation.is_empty():
		if not carry.intended(self, id):
			return Vector3.ZERO
		pp = puck_pos()
		v = _flat(puck.linear_velocity)
	else:
		if observation.receiver != id:
			return Vector3.ZERO
		pp = observation.puck
		v = observation.motion
	var me := pos_of(id)
	if v.length() < 1.0:
		return Vector3.ZERO
	var u: Vector3 = v.normalized()
	var along: float = maxf((me - pp).dot(u), 0.0)
	var meet: Vector3 = pp + u * along
	var to: Vector3 = meet - me
	return to.normalized() if to.length() > 0.2 else Vector3.ZERO

## A hit takes the puck off him: loose, with a velocity (H2).
func knock_loose(victim: String, vel: Vector3) -> void:
	if carrier != victim:
		return
	_release("hit", victim, vel)

func can_strip(id: String, victim: String) -> bool:
	return _now >= int(carry.steal_after.get(id, 0)) and (victim != carrier or _now >= carry.immune_until)

func whiff_turn(id: String) -> float:
	return carry.c.whiff_turn_mult if _now < int(poke.whiff_until.get(id, 0)) else 1.0

func can_poke(id: String) -> bool:
	return _now >= int(poke.ready.get(id, 0)) and poke.eligible(self, id) and poke.in_cone(self, id)

func try_poke(id: String) -> bool:
	return poke.start(self, id)

func poke_odds(id: String) -> float:
	return poke.odds(self, id)

func try_one_timer(id: String) -> bool:
	if carry.armed == id:
		return true
	if not carry.arm(self, id):
		return false
	# The AI supplies an aim only for the call. A human can still aim the stick through release.
	timer_aim = stick_of(id) if id != hits.human and stick_dir.has(id) else Vector3.ZERO
	return true

func step_sticks() -> void:
	poke.tick(self)
	if carrier != "" and carry.armed == carrier and _now - carry_since >= int(carry.shot.one_timer_release):
		try_shoot(carrier)

func _clip(id: String, clip: StringName) -> void:
	var r = (skaters[id] as TLBiped).rig
	if r != null and not headless:          # L4b: drawing only (no hashed value reads a pose)
		r.play(clip)

func _inside(p: Vector3) -> bool:
	var hx: float = rink_half.x - rink_margin
	var hz: float = rink_half.y - rink_margin
	if absf(p.x) > hx or absf(p.z) > hz:
		return false
	var r: float = rink_corner - rink_margin
	var dx: float = maxf(absf(p.x) - (hx - r), 0.0)
	var dz: float = maxf(absf(p.z) - (hz - r), 0.0)
	return Vector2(dx, dz).length() <= r

## Possession for _pack_state(): absent values are omitted.
func state() -> Dictionary:
	var s: Dictionary = {"takes": takes.duplicate(), "passes": passes.duplicate(), "pokes": pokes.duplicate()}
	if not one_timers.is_empty():
		s["one_timers"] = one_timers.duplicate()     # L5b
	if carrier != "":
		s["carrier"] = carrier
		s["team"] = str(teams[carrier])
		s["since"] = carry_since
	if shot_held:
		s["charge_frames"] = held_frames
	s["puck_state"] = puck_state
	s["poke_tries"] = poke_tries.duplicate()
	if carrier != "":
		s["dangle"] = carry.dangle
		if carry.cut:
			s["cut"] = true
		if _now < carry.immune_until:
			s["poke_immune"] = carry.immune_until - _now
	if not last_release.is_empty():
		s["last"] = last_release.duplicate()
	return s

var _goal_prev: Vector3 = Vector3(1e9, 0, 0)   ## N3: the puck's position at the last goal check
var _goal_bad: Dictionary = {}                 ## N3: side -> the puck in that net came in from behind the line
const GOAL_TOP := 1.55   ## the crossbar: data/venue.json's goals stand at y 0.05 and are 1.5 m high

## H11 (moved from main.gd in H13, its 600-line limit): the side that scores when the puck's centre lies in a goal volume (the trigger's box: 1.5 m deep behind the line,
## the goal's width, under the goal's crossbar), else "". hunt2 A7: a puck flying over the net is no goal.
func goal_by_position(g: Dictionary) -> String:
	if goalies.has(carrier):
		return ""                         # L5: a puck a goalie holds is covered, never a goal (his blade can reach into his net)
	var p: Vector3 = puck.position   # the pack's own coordinates (the goals' too), wherever a world puts the pack
	var prev: Vector3 = _goal_prev
	_goal_prev = p
	for side: String in ["blue", "red"]:
		var gx: float = float(g[side][0])
		if absf(p.x - (gx + signf(gx) * 0.75)) <= 0.75 and absf(p.z) <= float(g["half_width"]) and p.y <= GOAL_TOP:
			# N3: only through the mouth: a puck that came in from behind the goal line (round the back or past a post: a
			# 47 m zero-friction rebound won a rookie match for an idle hand) is no goal until it has left the net again
			if not _goal_bad.has(side):
				_goal_bad[side] = prev.x < 1e8 and prev.distance_to(p) < 3.0 and (prev.x - gx) * signf(gx) > 0.05 					and not (absf(prev.x - (gx + signf(gx) * 0.75)) <= 0.75 and absf(prev.z) <= float(g["half_width"]))
			if not bool(_goal_bad[side]):
				return "red" if side == "blue" else "blue"
		else:
			_goal_bad.erase(side)
	return ""
