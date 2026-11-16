extends RefCounted
## Brain for the AI skaters (and for b0 on autopilot). H1: the three roles know the carry.
##   carrier: skates at the goal, shoots inside a range when lined up, passes when an opponent closes and a mate is open.
##   our puck: chaser and support open lanes ahead; back holds the middle behind them.
##   their puck: chaser (and support when near) close on the carrier and poke; back guards the goal; support marks.
##   loose puck: chaser goes for it (support when near, back when it is in his zone); the nearest skater in reach takes it.
## H2: a closer arriving with speed checks the carrier (red from a lower closing speed than blue: red hits more).
## Yield to the human: blue mates leave a loose puck to b0 when he is as near; red does not poke b0 in his first
## `yield_frames` with the puck. Numbers in data/ai.json.

var cfg: Dictionary = {}
var base_cfg: Dictionary = {}          ## data/ai.json as read; a mode overrides some keys (H3)
var sharpness: float = 0.0             ## the rule dial (H3): added to speed_scale, both teams
var _c: Dictionary = {}
var _pos: Dictionary = {}
var _frame_no: int = 0


func setup(ctx, _env) -> void:
	base_cfg = ctx.read_json("ai.json")
	cfg = base_cfg.duplicate()


## A mode's "ai" keys over data/ai.json (validated by main.gd).
func override(over: Dictionary) -> void:
	cfg = base_cfg.duplicate()
	cfg.merge(over, true)
	_c.clear()


func _f(k: String) -> float:
	if not _c.has(k):
		_c[k] = float(cfg[k])
	return _c[k]


func think(frame: int, env: Dictionary) -> void:
	_frame_no = frame
	var skaters: Dictionary = env["skaters"]
	_pos.clear()
	for k: String in skaters:
		_pos[k] = _flat((skaters[k] as Node3D).global_position)
	for id: String in skaters:
		if id == "b0" and not env["autopilot"]:
			continue
		var sk: TLBiped = skaters[id]
		if env["frozen"]:
			sk.move(Vector3.ZERO)
			continue
		var team: String = str(env["teams"][id])
		var sc: float = (_f("speed_scale") + sharpness) * (_f("red_skill") if team == "red" else 1.0)
		var dir: Vector3 = _decide(id, team, env)
		if dir.length() > 1.0:
			dir = dir.normalized()
		sk.move(dir * sc)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _goto(me: Vector3, target: Vector3) -> Vector3:
	return TLSteer.arrive(me, target, 1.5)


func _human(env: Dictionary) -> bool:
	return not env["autopilot"]


func _decide(id: String, team: String, env: Dictionary) -> Vector3:
	var api = env["api"]
	var me: Vector3 = _pos[id]
	var pp: Vector3 = api.puck_pos()
	var opp_goal: Vector3 = _flat(env["goals"]["red" if team == "blue" else "blue"])
	var own_goal: Vector3 = _flat(env["goals"][team])
	var role: String = str(env["roles"][id])
	if role == "player":
		role = "chaser"
	var sgn: float = signf(opp_goal.x)
	var lane: float = float(env["spawns"][id].z)
	var others: Array = []
	for oid: String in _pos:
		if oid != id:
			others.append(_pos[oid])
	var car: String = api.carrier
	var hits = env["hits"]
	if not hits.can_act(id):
		return Vector3.ZERO
	var out: Vector3 = Vector3.ZERO
	if car == id:
		return _carry(id, team, env, me, opp_goal, sgn)
	var rc: Vector3 = api.receive_dir(id)
	if rc != Vector3.ZERO:
		return rc
	var d: float = me.distance_to(pp)
	if car != "" and str(env["teams"][car]) == team:
		if role == "back":
			out = _goto(me, Vector3(lerpf(own_goal.x, pp.x, 0.55), 0.0, lerpf(0.0, pp.z, 0.3)))
		else:
			var ahead: float = clampf(pp.x + sgn * _f("open_ahead"), -22.0, 22.0)
			var z: float = clampf(lane * 1.2 if absf(lane) > 1.0 else (6.0 if pp.z < 0.0 else -6.0), -12.0, 12.0)
			out = _goto(me, Vector3(ahead, 0.0, z))
	elif car != "":
		var cp: Vector3 = _pos[car]
		var dc: float = me.distance_to(cp)
		var closes: bool = role == "chaser" or (role == "support" and dc < _f("pounce_radius")) or (role == "back" and (dc < _f("back_engage") or cp.distance_to(own_goal) < _f("defend_radius")))
		if closes:
			var may: bool = not (car == "b0" and _human(env) and _frame_no - int(api.carry_since) < int(_f("yield_frames")))
			if may and hits.can_check(id) and hits.target(id, hits._f("check_reach"), hits._f("check_cone_deg")) == car and hits.closing(id, car) >= _f("check_min_closing_" + team):
				hits.try_check(id)
			elif may and api.can_poke(id):
				api.try_poke(id)
			var cv: Vector3 = _flat((env["skaters"][car] as TLBiped).velocity)
			out = (pp + cv * clampf(dc / 10.0, 0.0, 0.5) - me).normalized()
		elif role == "back":
			out = _goto(me, own_goal + Vector3(-signf(own_goal.x) * 3.0, 0, 0) + (cp - own_goal).limit_length(_f("back_radius")))
		else:
			var mark: Vector3 = own_goal.lerp(cp, 0.6)
			mark.z = lerpf(mark.z, lane, 0.5)
			out = _goto(me, mark)
	else:
		var yield_b0: bool = team == "blue" and id != "b0" and _human(env) and _pos["b0"].distance_to(pp) <= d + 2.0 and _pos["b0"].distance_to(pp) < 15.0
		var chase: bool = role == "chaser" or (role == "support" and d < _f("pounce_radius")) or (role == "back" and d < _f("back_engage"))
		if chase and not yield_b0:
			var lead: float = clampf(d / 10.0, 0.0, _f("lead_frames") / 60.0)
			out = (pp + _flat(env["puck"].linear_velocity).limit_length(25.0) * lead - me)
			out = out.normalized() if out.length() > 0.05 else Vector3.ZERO
		elif role == "back":
			out = _goto(me, own_goal + Vector3(-signf(own_goal.x) * 3.0, 0, 0) + (pp - own_goal).limit_length(_f("back_radius")))
		else:
			var between: Vector3 = own_goal.lerp(pp, 0.6)
			between.x += sgn * 4.0
			between.z = lerpf(between.z, lane, 0.5)
			out = _goto(me, between)
	out += TLSteer.separate(me, others, 1.5) * 1.2
	return out


## The carrier: at the goal, shoot inside the range when lined up, pass when pressed and a mate is open.
func _carry(id: String, team: String, env: Dictionary, me: Vector3, opp_goal: Vector3, sgn: float) -> Vector3:
	var api = env["api"]
	var fwd: Vector3 = api.fwd_of(id)
	var mouth: Vector3 = opp_goal
	var to_goal: Vector3 = mouth - me
	var dgoal: float = to_goal.length()
	var pressed: bool = false
	var threat: Vector3 = Vector3(1e6, 0, 0)
	for oid: String in _pos:
		if str(env["teams"][oid]) == team:
			continue
		var rel: Vector3 = _pos[oid] - me
		if rel.length() < _f("pressure_radius") and rel.dot(fwd) > -0.3:
			pressed = true
		if rel.dot(to_goal.normalized()) > 0.0 and rel.length() < threat.distance_to(me):
			threat = _pos[oid]
	# lined up: the puck leaves along his facing, so the facing from the puck must fall inside the goal mouth
	var from_puck: Vector3 = mouth - api.puck_pos()
	var tol: float = minf(deg_to_rad(_f("aim_tolerance_deg")), atan2(_f("mouth_half"), maxf(from_puck.length(), 1.0)))
	var lined: bool = fwd.dot(from_puck.normalized()) > cos(tol)
	var carried: int = _frame_no - int(api.carry_since)
	if dgoal < _f("shoot_range") and lined and absf(me.z) < 11.0 and carried >= int(_f("min_carry_frames")):
		api.try_shoot(id)
	elif pressed and carried >= int(_f("min_carry_frames")):
		var mid: String = api.pass_target(id)
		if mid != "" and _open(mid, team, env):
			api.try_pass(id)
	# stuck (against a net, the boards or a body): pass to anybody in the cone, else shoot it away
	var spd: float = (env["skaters"][id] as TLBiped).speed()
	if api.carrier == id and carried >= int(_f("stuck_frames")) and spd < 1.5:
		if api.pass_target(id) != "":
			api.try_pass(id)
		else:
			api.try_shoot(id)
	# skate at the goal mouth from in front of it, around the nearest opponent between
	var target: Vector3 = Vector3(opp_goal.x - sgn * 5.0, 0.0, 0.0)
	if absf(me.x - opp_goal.x) < 7.0:
		target = mouth
	var own_x: float = -opp_goal.x
	if (me.x - own_x) * sgn < 1.5:
		# at or behind his own goal line: out round the net first
		target = Vector3(own_x + sgn * 3.0, 0.0, 6.0 if me.z >= 0.0 else -6.0)
	elif (me.x - opp_goal.x) * sgn > -0.5:
		# behind their goal line: back out in front of the mouth
		target = Vector3(opp_goal.x - sgn * 4.0, 0.0, 3.0 if me.z >= 0.0 else -3.0)
	if threat.x < 1e5:
		var rel2: Vector3 = threat - me
		var g: Vector3 = (target - me).normalized()
		var lat: float = rel2.x * g.z - rel2.z * g.x
		if rel2.length() < 5.0 and absf(lat) < 2.0:
			target += Vector3(-g.z, 0, g.x) * (3.0 if lat < 0.0 else -3.0)
	return (target - me).normalized()


func _open(mid: String, team: String, env: Dictionary) -> bool:
	for oid: String in _pos:
		if str(env["teams"][oid]) != team and _pos[oid].distance_to(_pos[mid]) < _f("open_radius"):
			return false
	return true
