extends RefCounted
## Possession, blade placement, release and recovery. Distances and timings come from carry and shoot tuning.

var skate
var rink_root: Node3D
var puck: TLBall
var skaters: Dictionary = {}
var teams: Dictionary = {}
var order: Array = []
var speed: float = 18.0                ## shot speed, m/s
var charge_frames: int
var charge_bonus: float
var tap_frames: int
var shot_held := false
var held_frames := 0
var cooldown_frames: int = 24
var reach: float = 1.1                 ## carry: the reach circle's radius, m
var blade_base: float
var blade_reach: float
var blade_yaw: float
var carry_reach_mult: float
var assist: float
var sweep_angle: float
var sweep_shield_frames: int
var sprint_shield_frames: int
var last_carried: Dictionary = {}      ## Last frame each skater released or lost possession.
var shield_left: int = 0
var yaw_rigs: Array[Node3D] = []
var yaw_ids: Array[String] = []
var yaw_bodies: Array[TLBiped] = []
var headless := false                  ## no stick posing without a window (set by main.gd)
var yaw_now: PackedFloat32Array = []   ## per yaw rig: the stick_yaw it is given now (rad, + = left)
var last_blade: Vector3 = Vector3.ZERO
var own_lock_frames: int = 12
var own_lock_speed: float = 4.0
var flight_take_speed: float = 7.0
var flight_take_dist: float = 0.6
var pass_speed: float = 14.0
var pass_cone_dot: float = 0.5
var pass_lead_max_frames: int = 60
var poke_reach: float = 1.7
var poke_cooldown_frames: int = 30
var poke_speed: float = 4.0
var poke_lock_frames: int = 20
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
var _poke_at: Dictionary = {}
var aim_at: Dictionary = {}             ## L5: id -> the point the human's cursor is on: a shot leaves the blade at it
var one_timer_frames: int = 0          ## L5b: a shot this soon after taking a mate's pass is a one-timer (0: none)
var one_timer_scale: float = 1.0       ## L5b: its speed factor
var from_pass: bool = false            ## L5b: the carrier took the puck from his own side's pass
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
		if key not in ["speed", "cooldown_s", "one_timer_frames", "one_timer_scale", "charge_frames", "charge_bonus", "tap_frames"]:
			push_error("tuning.json: unknown shoot.%s" % key)
	charge_frames = s["charge_frames"]
	charge_bonus = s["charge_bonus"]
	tap_frames = s["tap_frames"]
	speed = float(s["speed"])
	cooldown_frames = int(round(float(s["cooldown_s"]) * 60.0))
	one_timer_frames = int(s["one_timer_frames"])
	one_timer_scale = float(s["one_timer_scale"])
	var c: Dictionary = tune["carry"]
	reach = float(c["reach"])
	# JamSim.cpp:1478-1545,4160-4177; JamCartridge.h:159,182-189,295. Radians and frames are fixed per rink.
	blade_yaw = -deg_to_rad(float(c["blade_yaw_deg"]))
	sweep_angle = deg_to_rad(float(c["sweep_deg"]))
	sweep_shield_frames = c["sweep_shield_frames"]
	sprint_shield_frames = roundi(sweep_shield_frames * float(c["sweep_sprint_mult"]))
	blade_base = c["blade_base"]
	blade_reach = c["blade_reach"]
	carry_reach_mult = c["carry_reach_mult"]
	assist = c["assist"]
	for key: String in c:
		if key not in ["reach", "carry_min", "blade_base", "blade_reach", "blade_yaw_deg", "carry_reach_mult", "assist", "sweep_deg",
				"sweep_shield_frames", "sweep_sprint_mult", "own_lock_frames", "own_lock_speed", "flight_take_speed", "flight_take_dist",
				"pass_speed", "pass_cone_deg", "pass_lead_max_frames", "poke_reach", "poke_cooldown_frames", "poke_speed",
				"poke_lock_frames", "carry_speed_scale", "behind_net_frames", "behind_net_half_width", "ring_width"]:
			push_error("tuning.json: unknown carry.%s" % key)
	own_lock_frames = int(c["own_lock_frames"])
	own_lock_speed = float(c["own_lock_speed"])
	flight_take_speed = float(c["flight_take_speed"])
	flight_take_dist = float(c["flight_take_dist"])
	pass_speed = float(c["pass_speed"])
	pass_cone_dot = cos(deg_to_rad(float(c["pass_cone_deg"])))
	pass_lead_max_frames = int(c["pass_lead_max_frames"])
	poke_reach = float(c["poke_reach"])
	poke_cooldown_frames = int(c["poke_cooldown_frames"])
	poke_speed = float(c["poke_speed"])
	poke_lock_frames = int(c["poke_lock_frames"])
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
		_poke_at[id] = 0

func tick(frame: int) -> void:
	_now = frame

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

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

## Whether the loose puck may become his now (the locks after a release, the rule for a puck in flight).
func may_take(id: String, d: float) -> bool:
	if last_release.is_empty():
		return true
	var age: int = _now - int(last_release["frame"])
	var kind: String = str(last_release["kind"])
	var by: String = str(last_release["by"])
	var spd: float = _flat(puck.linear_velocity).length()
	if kind == "poked":
		return id != by or age >= poke_lock_frames
	if kind == "hit":
		return id != by or age >= poke_lock_frames
	if id == by:
		return age >= own_lock_frames or spd < own_lock_speed
	if kind == "pass" and str(teams[id]) == str(last_release["team"]):
		return true
	return spd < flight_take_speed or d < flight_take_dist

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
				puck.place(rink_root.to_global(spot))
				return
		return
	var best: String = ""
	var best_d: float = 1e9
	var step := puck.last_step()
	var a := _flat(step[0])
	var ab := _flat(step[1]) - a
	var contacts = hits
	for id: String in order:
		if contacts != null and not contacts.can_act(id):
			continue
		var d := _path_distance(pos_of(id), a, ab)
		if d <= reach and d < best_d and may_take(id, d):
			best = id
			best_d = d
	if best != "":
		give(best)

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
		var gap: float = angle_difference(atan2(-at.x, -at.z), fwd_of(id).signed_angle_to(blade_dir(id), Vector3.UP))
		yaw_now[i] = clampf(yaw_now[i] + 0.5 * gap, -1.2, 2.0)
		rig.set_param(&"stick_yaw", yaw_now[i])

func _follow_blade() -> void:
	if carrier == "":
		return
	var body: TLBiped = skaters[carrier]
	var dir := blade_dir(carrier)
	var sprint: bool = skate.is_sprinting(carrier)
	# JamSim.cpp:1500-1545, JamCartridge.h:182-189. A new sweep renews the shield.
	var duration := sprint_shield_frames if sprint else sweep_shield_frames
	shield_left = clampi(shield_left - 1, 0, duration)
	if hits.can_act(carrier) and last_blade.angle_to(dir) > sweep_angle:
		shield_left = duration
	last_blade = dir

	# JamSim.h:494, JamCartridge.h:159,187, JamSim.cpp:1484-1499. Aim extends the blade.
	var frac := 1.0 if stick_dir.has(carrier) else 0.5
	var dist := blade_base + frac * blade_reach
	if not sprint:
		dist *= carry_reach_mult
	var blade := body.global_transform.basis.inverse() * (dir * maxf(carry_min, dist))
	blade.y = 0.07
	# JamSim.cpp:4160-4177, JamCartridge.h:295. Keep the puck moving with its holder
	# and close a fraction of the remaining local gap, including on a take.
	var point := hold_at.lerp(blade, assist)
	if not _inside(body.transform * point):
		point = _board_point(body, blade)
	if point != hold_at:
		hold_at = point
		blade_socket.position = point

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
	from_pass = not last_release.is_empty() and str(last_release["kind"]) == "pass" and str(last_release["team"]) == str(teams[id]) \
		and str(last_release["by"]) != id
	carrier = id
	carry_min = maxf(configured_carry_min, (skaters[id] as TLBiped).body_radius() + puck_radius)
	carry_since = _now
	behind_frames = 0
	takes[id] = int(takes[id]) + 1
	var local: Vector3 = (skaters[id] as Node3D).global_transform.affine_inverse() * puck.global_position
	local.y = 0.07
	hold_at = local
	last_blade = blade_dir(id)
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
	shield_left = 0
	puck.release(Vector3.ZERO)

## A face-off or a drill: nobody has it, no lock.
func reset() -> void:
	if carrier != "":
		_drop()
	last_release = {}
	last_carried.clear()

func _release(kind: String, by: String, vel: Vector3) -> void:
	cancel_charge()
	last_carried[by] = _now
	carrier = ""
	shield_left = 0
	puck.release(vel)
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
	if from_pass and one_timer_frames > 0 and _now - carry_since <= one_timer_frames:
		sp = maxf(sp, speed * one_timer_scale)                # L5b: a one-timer: shot straight off a mate's pass, harder
		one_timers[id] = int(one_timers.get(id, 0)) + 1
		events.append(["one_timer", id])
	_release("shot", id, shot_dir(id) * sp)
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
func lead_point(mid: String) -> Vector3:
	var from: Vector3 = puck_pos()
	var mp: Vector3 = pos_of(mid)
	var mv: Vector3 = _flat((skaters[mid] as TLBiped).velocity)
	var tgt: Vector3 = mp
	for i: int in 2:
		var t: float = minf(from.distance_to(tgt) / pass_speed, float(pass_lead_max_frames) / 60.0)
		tgt = mp + mv * t
	return tgt

func try_pass(id: String) -> bool:
	if carrier != id:
		return false
	var mid: String = pass_target(id)
	var dir: Vector3 = stick_of(id)
	if mid != "":
		var to: Vector3 = lead_point(mid) - puck_pos()
		if to.length() > 0.1:
			dir = to.normalized()
	_release("pass", id, dir * pass_speed)
	_clip(id, &"pass")
	if mid != "":
		last_release["to"] = mid
	passes[id] = int(passes[id]) + 1
	events.append(["pass", id])
	return true

## The mate a pass is meant for skates to meet it while it is loose and moving: towards the nearest point of its
## path ahead of the puck. Vector3.ZERO when he is not receiving.
func receive_dir(id: String) -> Vector3:
	if carrier != "" or last_release.is_empty() or str(last_release["kind"]) != "pass" or str(last_release.get("to", "")) != id:
		return Vector3.ZERO
	if _now - int(last_release["frame"]) > pass_lead_max_frames * 2:
		return Vector3.ZERO
	var v: Vector3 = _flat(puck.linear_velocity)
	if v.length() < 1.0:
		return Vector3.ZERO
	var me: Vector3 = pos_of(id)
	var pp: Vector3 = puck_pos()
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

func can_poke(id: String) -> bool:
	return carrier != "" and carrier != id and not goalies.has(carrier) and str(teams[carrier]) != str(teams[id]) and _now >= int(_poke_at[id]) \
		and pos_of(id).distance_to(puck_pos()) <= poke_reach

## A stick poke at an opponent's carried puck: it comes loose towards the poker. A miss costs the cooldown too.
func try_poke(id: String) -> bool:
	if _now < int(_poke_at[id]) or carrier == "" or carrier == id or goalies.has(carrier) or str(teams[carrier]) == str(teams[id]):
		return false
	_poke_at[id] = _now + poke_cooldown_frames
	if shield_left > 0 or pos_of(id).distance_to(puck_pos()) > poke_reach:
		return false
	if stick_dir.has(id) and pos_of(id).distance_to(puck_pos()) > 0.05 and (stick_dir[id] as Vector3).dot((puck_pos() - pos_of(id)).normalized()) < poke_cone_dot:
		return false
	var victim: String = carrier
	var dir: Vector3 = pos_of(id) - puck_pos()
	dir = dir.normalized() if dir.length() > 0.05 else -fwd_of(victim)
	_release("poked", victim, dir * poke_speed)
	_poke_at[victim] = maxi(int(_poke_at[victim]), _now + poke_lock_frames)     # no poke straight back
	pokes[id] = int(pokes[id]) + 1
	events.append(["poke", id])
	return true

func _clip(id: String, clip: StringName) -> void:
	var r = (skaters[id] as TLBiped).rig
	if r != null:
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
	if shield_left > 0:
		s["shield_left"] = shield_left
	if not last_release.is_empty():
		s["last"] = last_release.duplicate()
	return s

const GOAL_TOP := 1.55   ## the crossbar: data/venue.json's goals stand at y 0.05 and are 1.5 m high

## H11 (moved from main.gd in H13, its 600-line limit): the side that scores when the puck's centre lies in a goal volume (the trigger's box: 1.5 m deep behind the line,
## the goal's width, under the goal's crossbar), else "". hunt2 A7: a puck flying over the net is no goal.
func goal_by_position(g: Dictionary) -> String:
	if goalies.has(carrier):
		return ""                         # L5: a puck a goalie holds is covered, never a goal (his blade can reach into his net)
	var p: Vector3 = puck.position   # the pack's own coordinates (the goals' too), wherever a world puts the pack
	for side: String in ["blue", "red"]:
		var gx: float = float(g[side][0])
		if absf(p.x - (gx + signf(gx) * 0.75)) <= 0.75 and absf(p.z) <= float(g["half_width"]) and p.y <= GOAL_TOP:
			return "red" if side == "blue" else "blue"
	return ""
