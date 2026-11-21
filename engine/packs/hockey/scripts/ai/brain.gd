extends RefCounted
## Chasers press the puck, support opens a lane, and backs guard the goal. The carrier can skate, pass or shoot.
## Modes override data/ai.json. Level overrides apply to red only.

var cfg: Dictionary = {}
var base_cfg: Dictionary = {}          ## data/ai.json as read; a mode overrides some keys (H3)
var sharpness: float = 0.0             ## the rule dial (H3): added to speed_scale, both teams
var _c: Dictionary = {}
var _pos: Dictionary = {}
var _all: Array = []
var _frame_no: int = 0
var red_over: Dictionary = {}          ## H5: the level's ai keys, for red's decisions only
var _team: String = ""                 ## the team of the skater being decided (for red_over)
var _seen: Array = []                  ## the puck's last positions, newest first (red's reaction)
var _ctx = null
var _b0_act: int = -100000             ## L5: the frame b0 last passed or shot (his own press, never a puck that just came to him)
var _b0_count: int = 0

func setup(ctx, _env) -> void:
	_ctx = ctx
	base_cfg = ctx.read_json("ai.json")
	cfg = base_cfg.duplicate()

## A mode's "ai" keys over data/ai.json (validated by main.gd).
func override(over: Dictionary) -> void:
	cfg = base_cfg.duplicate()
	cfg.merge(over, true)
	_c.clear()

func _f(k: String) -> float:
	if _team == "red" and red_over.has(k):
		return float(red_over[k])
	if not _c.has(k):
		_c[k] = float(cfg[k])
	return _c[k]

func think(frame: int, env: Dictionary) -> void:
	_frame_no = frame
	var n0: int = int(env["api"].passes.get("b0", 0)) + int(env["api"].shots.get("b0", 0))
	if n0 != _b0_count:
		_b0_count = n0
		_b0_act = frame
	_seen.push_front((env["api"]).puck_pos())
	if _seen.size() > 40:
		_seen.pop_back()
	var skaters: Dictionary = env["skaters"]
	_pos.clear()
	for k: String in skaters:
		_pos[k] = _flat((skaters[k] as Node3D).global_position)
	_all = _pos.values()                   # L4b: one list for every skater's separation (TLSteer.separate skips his own point)
	for id: String in skaters:
		if (id == "b0" and not env["autopilot"]) or str(env["roles"][id]) == "goalie":
			continue                       # L5: the goalies are scripts/keeper.gd's
		if env["frozen"]:
			env["skate"].want(id, Vector3.ZERO)
			continue
		var team: String = str(env["teams"][id])
		_team = team
		var sc: float = (_f("speed_scale") + sharpness) * (_f("red_skill") if team == "red" else 1.0)
		var dir: Vector3 = _decide(id, team, env)
		if dir.length() > 1.0:
			dir = dir.normalized()
		env["skate"].want(id, dir * sc)
	_team = ""

## H6: the x of the goal line a point is behind (inside the net's width), or 0.0.
func _behind_net(p: Vector3, env: Dictionary) -> float:
	for side: String in ["blue", "red"]:
		var gx: float = float(env["goals"][side].x)
		if (p.x - gx) * signf(gx) > -0.2 and absf(p.z) < _f("net_zone_half"):
			return gx
	return 0.0

## H6: a target behind a net is reached round the frame, not through it: from in front, go first to the post on the
## near side (side = 1.0) or the far side (side = -1.0, the second man); once level with the goal line, go straight.
func _around_net(me: Vector3, target: Vector3, env: Dictionary, side: float) -> Vector3:
	var gx: float = _behind_net(target, env)
	if gx == 0.0:
		return target
	if (me.x - gx) * signf(gx) > -0.5:
		return target
	var zs: float = signf(me.z) if absf(me.z) > 0.3 else (signf(target.z) if absf(target.z) > 0.1 else 1.0)
	return Vector3(gx + signf(gx) * 0.8, 0.0, zs * side * _f("net_round_z"))

## Where this skater sees the puck: now, or (red under a level) reaction_frames ago.
func _puck_seen() -> Vector3:
	var lag: int = int(_f("reaction_frames"))
	if lag <= 0 or _seen.is_empty():
		return _seen[0] if not _seen.is_empty() else Vector3.ZERO
	return _seen[mini(lag, _seen.size() - 1)]

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func _goto(me: Vector3, target: Vector3) -> Vector3:
	return TLSteer.arrive(me, target, 1.5)

func _human(env: Dictionary) -> bool:
	return not env["autopilot"]

func _decide(id: String, team: String, env: Dictionary) -> Vector3:
	var api = env["api"]
	var me: Vector3 = _pos[id]
	var pp: Vector3 = _puck_seen()
	var opp_goal: Vector3 = _flat(env["goals"]["red" if team == "blue" else "blue"])
	var own_goal: Vector3 = _flat(env["goals"][team])
	var role: String = str(env["roles"][id])
	if role == "player":
		role = "chaser"
	var sgn: float = signf(opp_goal.x)
	var lane: float = float(env["spawns"][id].z)
	var others: Array = _all
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
		if str(env["roles"][car]) == "goalie":
			# L5b: their goalie has it covered: nobody checks or pokes him, so nobody swarms him (the clips showed five
			# figures round a goalie holding the puck); they wait goalie_gap metres out, each in his lane
			var wait: Vector3 = cp + (own_goal - cp).normalized() * _f("goalie_gap")
			wait.z = clampf(lane * 1.2, -11.0, 11.0)
			out = _goto(me, wait)
		elif closes:
			var may: bool = not (car == "b0" and _human(env) and _frame_no - int(api.carry_since) < int(_f("yield_frames")))
			var gap: float = dc - hits.touch_distance(id, car)
			# L4b: the press winds up hits.check_windup frames: press when he will be in reach as it ends (thirdjam's bots time it too)
			var lead: float = hits.check_gap + maxf(hits.closing(id, car), 0.0) * float(hits.check_windup) / 60.0
			if may and gap <= lead and not hits.graced(car) and hits.can_check(id) and hits.target(id, lead, hits.check_cone_deg) == car and hits.closing(id, car) >= _f("check_min_closing_" + team):
				hits.try_check(id)
			elif may and role == "chaser" and gap <= hits.cross_gap and not hits.graced(car) and hits.can_cross(id) and hits.closing(id, car) > _f("cross_min_closing") and hits.in_cross_cone(id, car):
				hits.try_cross(id, car)
			elif may and not hits.swinging(id) and api.can_poke(id):
				api.try_poke(id)
			var cv: Vector3 = _flat((env["skaters"][car] as TLBiped).velocity)
			out = (_around_net(me, pp + cv * clampf(dc / 10.0, 0.0, 0.5), env, 1.0) - me).normalized()
		elif _behind_net(cp, env) != 0.0:
			# H6: their carrier behind a net: the second man covers the far side of the frame
			out = _goto(me, _around_net(me, cp, env, -1.0))
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
			out = (_around_net(me, pp + _flat(env["puck"].linear_velocity).limit_length(25.0) * lead, env, 1.0) - me)
			out = out.normalized() if out.length() > 0.05 else Vector3.ZERO
		elif role == "back":
			out = _goto(me, own_goal + Vector3(-signf(own_goal.x) * 3.0, 0, 0) + (pp - own_goal).limit_length(_f("back_radius")))
		else:
			var between: Vector3 = own_goal.lerp(pp, 0.6)
			between.x += sgn * 4.0
			between.z = lerpf(between.z, lane, 0.5)
			out = _goto(me, between)
	out += TLSteer.separate(me, others, 2.0) * 1.2
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
	# L5: the human's mates set him up. They shoot only within assist_frames of his own pass or shot (a give-and-go, a
	# rebound of his shot); otherwise they pass to him. A match he does not play is not won for him (idle: 0 wins).
	var feed: bool = team == "blue" and _human(env) and _frame_no - _b0_act > int(_f("assist_frames"))
	if feed and carried >= int(_f("min_carry_frames")) and _pos["b0"].distance_to(me) > 4.0 and hits_ok(env, "b0"):
		var to: Vector3 = api.lead_point("b0") - api.puck_pos()
		if to.length() > 0.5 and (dgoal >= _f("shoot_range") or pressed or carried >= int(_f("feed_frames"))):
			api.stick_dir[id] = to.normalized()
			api.try_pass(id)
			api.stick_dir.erase(id)
			api.last_release["to"] = "b0"
			return Vector3.ZERO
	if not feed and dgoal < _f("shoot_range") and lined and absf(me.z) < 11.0 and carried >= int(_f("min_carry_frames")):
		var err: float = _f("aim_error_deg")
		var aim: Vector3 = _corner(team, env, opp_goal, api.puck_pos(), fwd)
		if err > 0.0 and api.can_shoot(id):
			aim = aim.rotated(Vector3.UP, deg_to_rad(_ctx.rng.randf_range(-err, err)))
		api.stick_dir[id] = aim
		api.try_shoot(id)
		api.stick_dir.erase(id)
	elif pressed and carried >= int(_f("min_carry_frames")):
		var mid: String = api.pass_target(id)
		if mid != "" and _open(mid, team, env):
			api.try_pass(id)
	# stuck (against a net, the boards or a body): pass to anybody in the cone, else shoot it away
	var spd: float = (env["skaters"][id] as TLBiped).speed()
	if api.carrier == id and carried >= int(_f("stuck_frames")) and spd < 1.5:
		if api.pass_target(id) != "":
			api.try_pass(id)
		elif not feed:
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

## L5: where a shot goes: at the far side of the goal from their goalie (corner_z from the middle), along the facing
## when they have none.
func _corner(team: String, env: Dictionary, opp_goal: Vector3, from: Vector3, fwd: Vector3) -> Vector3:
	for oid: String in _pos:
		if str(env["roles"][oid]) == "goalie" and str(env["teams"][oid]) != team:
			var gz: float = (_pos[oid] as Vector3).z
			var side: float = -signf(gz) if absf(gz) > 0.1 else (1.0 if from.z < 0.0 else -1.0)
			var to: Vector3 = Vector3(opp_goal.x, 0.0, side * _f("corner_z")) - from
			return to.normalized() if to.length() > 0.5 else fwd
	return fwd

## May he take a pass now (not down, not stumbling)?
func hits_ok(env: Dictionary, id: String) -> bool:
	return env["hits"].can_act(id)

func _open(mid: String, team: String, env: Dictionary) -> bool:
	for oid: String in _pos:
		if str(env["teams"][oid]) != team and _pos[oid].distance_to(_pos[mid]) < _f("open_radius"):
			return false
	return true
