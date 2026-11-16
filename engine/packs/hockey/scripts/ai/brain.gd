extends RefCounted
## Brain for the 5 AI skaters. Stateless per tick, so teleports are harmless.

var cfg: Dictionary = {}


func setup(ctx, _env) -> void:
	cfg = ctx.read_json("ai.json")


var _c: Dictionary = {}
var _pos: Dictionary = {}


func _f(k: String) -> float:
	if not _c.has(k):
		_c[k] = float(cfg[k])
	return _c[k]


var _frame_no: int = 0
var _anchor: Vector3 = Vector3(1e6, 0, 0)
var _anchor_frame: int = 0
var _stalled: bool = false


func think(_frame: int, env: Dictionary) -> void:
	_frame_no = _frame
	var ppk: Vector3 = _flat((env["puck"] as Node3D).global_position)
	if ppk.distance_to(_anchor) > 2.0 or _frame < _anchor_frame:
		_anchor = ppk
		_anchor_frame = _frame
	_stalled = _frame - _anchor_frame > 120
	var skaters: Dictionary = env["skaters"]
	_pos.clear()
	for k: String in skaters:
		_pos[k] = _flat((skaters[k] as Node3D).global_position)
	for id: String in skaters:
		if id == "b0":
			continue
		var sk: TLBiped = skaters[id]
		if env["frozen"]:
			sk.move(Vector3.ZERO)
			continue
		var team: String = str(env["teams"][id])
		var sc: float = _f("speed_scale") * (_f("red_skill") if team == "red" else 1.0)
		var dir: Vector3 = _decide(id, team, env)
		if dir.length() > 1.0:
			dir = dir.normalized()
		sk.move(dir * sc)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _goto(sk: TLBiped, target: Vector3) -> Vector3:
	return TLSteer.arrive(sk.global_position, target, 1.5)


func _decide(id: String, team: String, env: Dictionary) -> Vector3:
	var sk: TLBiped = env["skaters"][id]
	var puck: TLBall = env["puck"]
	var pp: Vector3 = _flat(puck.global_position)
	var me: Vector3 = _flat(sk.global_position)
	var opp_goal: Vector3 = _flat(env["goals"]["red" if team == "blue" else "blue"])
	var own_goal: Vector3 = _flat(env["goals"][team])
	var role: String = str(env["roles"][id])
	var dirg: Vector3 = (opp_goal - pp).normalized()
	var d: float = me.distance_to(pp)
	var out: Vector3 = Vector3.ZERO
	var api = env["api"]

	var others: Array = []
	var mate_chaser: Vector3 = Vector3(1e6, 0, 1e6)
	for oid: String in env["skaters"]:
		if oid == id:
			continue
		var op: Vector3 = _pos[oid]
		others.append(op)
		if env["teams"][oid] == team and env["roles"][oid] == "chaser":
			mate_chaser = op

	var yield_b0: bool = false
	if team == "blue" and _pos.has("b0"):
		var db: float = _pos["b0"].distance_to(pp)
		yield_b0 = db <= d + 2.0 and db < 15.0
	if team == "red" and role != "back" and _pos.has("b0"):
		# give the human a moment with the puck: red holds back while b0 is working it
		yield_b0 = _pos["b0"].distance_to(pp) < 4.5 and d > 3.0
	if _stalled and role == "support" and d < 9.0:
		role = "chaser"
	if yield_b0 and d > 2.0 and not _stalled:
		role = "support"
		d = 99.0
	if role == "chaser" or (role == "support" and d < _f("pounce_radius")):
		out = _attack(sk, me, pp, puck, dirg, opp_goal, api, id, d)
	elif role == "back":
		if d < 2.5:
			out = _attack(sk, me, pp, puck, dirg, opp_goal, api, id, d)
		else:
			var gl: Vector3 = own_goal + Vector3(signf(-own_goal.x) * 3.0, 0, 0)
			var t: Vector3 = gl + (pp - gl).limit_length(_f("back_radius"))
			out = _goto(sk, t)
	else:
		var lane: float = float(env["spawns"][id].z)
		var between: Vector3 = own_goal.lerp(pp, 0.6)
		between.x += signf(opp_goal.x) * 4.0
		between.z = lerpf(between.z, lane, 0.5)
		if mate_chaser.x < 1e5 and between.distance_to(mate_chaser) < _f("min_separation"):
			between += (between - mate_chaser).normalized() * _f("min_separation")
		out = _goto(sk, between)
	out += TLSteer.separate(sk.global_position, others, 1.5) * 1.2
	return out


func _attack(sk: TLBiped, me: Vector3, pp: Vector3, puck: TLBall, dirg: Vector3, opp_goal: Vector3, api, id: String, d: float) -> Vector3:
	var fwd: Vector3 = _flat(sk.forward()).normalized()
	var dgoal: float = pp.distance_to(opp_goal)
	var tol: float = minf(_f("aim_tolerance_deg"), rad_to_deg(atan2(1.4, maxf(dgoal, 1.0))))
	var face_ok: bool = fwd.dot(dirg) > cos(deg_to_rad(tol))
	var near_wall: bool = absf(pp.z) > 13.0 and dgoal > 6.0
	var ok_shot: bool = face_ok and dgoal < _f("shoot_range") + 3.0 and not near_wall
	if _stalled and fwd.dot(dirg) > 0.0:
		ok_shot = true
	if d < 1.5 and ok_shot and api.can_shoot(id):
		api.try_shoot(id)
	var to_puck: Vector3 = pp - me
	var lateral: float = to_puck.x * dirg.z - to_puck.z * dirg.x
	if to_puck.dot(dirg) > 0.0 and absf(lateral) < 1.3:
		return (pp + dirg * 3.0 - me).normalized()
	var lead: float = clampf(d / 8.0, 0.0, _f("lead_frames") / 60.0)
	var tgt: Vector3 = pp + _flat(puck.linear_velocity).limit_length(25.0) * lead
	var behind: Vector3 = tgt - dirg * 1.2
	# slow deterministic sway of the approach line so two pursuers do not lock the puck in a corner
	behind += Vector3(-dirg.z, 0, dirg.x) * sin(float(_frame_no) * 0.015 + float(id.hash() % 7)) * 1.5
	var want: Vector3 = behind - me
	if to_puck.dot(dirg) < 0.0 and d < 4.0:
		var perp: Vector3 = Vector3(-dirg.z, 0, dirg.x) * (1.0 if lateral <= 0.0 else -1.0)
		want = behind + perp * 2.5 - me
	return want.normalized()
