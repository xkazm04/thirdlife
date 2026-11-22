extends RefCounted
## Skaters choose from a delayed view on staggered ticks. Steering and contact run on every physics frame.

const KEYS := ["speed_scale", "red_skill", "lead_frames", "yield_frames", "check_min_closing_red",
	"check_min_closing_blue", "cross_min_closing", "reaction_frames", "aim_sigma_deg", "score_noise",
	"commit_bonus", "feed_bonus", "shoot_min_xg", "pass_min_lane", "pass_weight", "poke_min_odds", "fresh_frames", "fresh_check_frames", "protect_weight", "net_zone_half", "net_round_z", "corner_z", "assist_frames", "goalie_gap"]
var cfg := {}
var base_cfg := {}
var red_over := {}
var sharpness := 0.0
var roles_now := {}
var caller := ""
var frame := 0
var rng
var sense = preload("sense.gd").new()
var roles
var carrier_play = preload("carrier.gd").new()
var braking := {}
var _goal_at := {}
var _goal_frame := -1
var plans := {}
var previous := {}
var b0_act := -100000
var b0_count := 0

func setup(ctx, _env) -> void:
	rng = ctx.rng
	base_cfg = ctx.read_json("ai.json")
	for key: String in base_cfg:
		if key not in KEYS:
			push_error("ai.json: unknown key " + key)
	override({})

func override(over: Dictionary) -> void:
	cfg = base_cfg.duplicate()
	cfg.merge(over, true)
	reset()
	roles = null
	b0_act = -100000
	b0_count = 0

func reset() -> void:
	sense.reset()
	plans.clear()
	braking.clear()
	previous.clear()
	roles_now.clear()
	caller = ""
	if roles != null:
		roles.first.clear()
		roles.sampled.clear()

func value(team: String, key: String) -> float:
	return float(red_over.get(key, cfg[key])) if team == "red" else float(cfg[key])

func reaction(team: String) -> float:
	return value(team, "reaction_frames") / 60.0

func attack(team: String) -> float:
	return 1.0 if team == "blue" else -1.0

func goal(team: String, env: Dictionary) -> Vector3:
	if _goal_frame != frame or not _goal_at.has(team):          # N3 (frame budget): once a frame, not per query
		if _goal_frame != frame:
			_goal_at.clear()
			_goal_frame = frame
		_goal_at[team] = env.api._flat(env.goals[team] + env.api.rink_root.global_position)
	return _goal_at[team]

func assisted() -> bool:
	return frame - b0_act <= int(value("blue", "assist_frames"))

func think(frame_no: int, env: Dictionary) -> void:
	frame = frame_no
	if roles == null:
		roles = preload("roles.gd").new()
		roles.setup(env, sense)
	var api = env.api
	var count: int = api.passes.b0 + api.shots.b0
	if count != b0_count and not env.autopilot:
		b0_act = frame
	b0_count = count
	braking.clear()
	var now: Dictionary = sense.record(frame, env)
	if env.frozen:
		caller = ""
		plans.clear()
		for team: String in roles.field:
			for id: String in roles.field[team]:
				if id != "b0" or env.autopilot:
					env.skate.want(id, Vector3.ZERO)
		return
	if env.autopilot or api.carrier != "b0":
		caller = ""
	var slot := 0
	for team: String in roles.field:
		var obs: Dictionary = sense.ago(int(value(team, "reaction_frames")))
		var due := {}
		for id: String in roles.field[team]:
			@warning_ignore("integer_division")
			var scheduled := (frame + slot * 15 / 6) % 15 == 0
			slot += 1
			if id == "b0" and not env.autopilot:
				roles_now.erase(id)
				plans.erase(id)
				continue
			var near: bool = obs.loose and now.pos[id].distance_squared_to(obs.puck) <= 9.0
			# A skater feels a take or loss at his own stick immediately.
			var car: String = id if now.car == id else ("" if obs.car == id else obs.car)
			var event := [car, obs.receiver == id, near, now.up[id]]
			var old: Array = previous.get(id, [])
			if scheduled or not plans.has(id) or old.is_empty() or old[0] != car or (event[1] and not old[1]) or (near and not old[2]) or old[3] != event[3]:
				due[id] = true
			previous[id] = event
		if not due.is_empty():
			roles.assign(team, obs, reaction(team))
		for id: String in roles.field[team]:
			if id == "b0" and not env.autopilot:
				continue
			var role: String = roles.assigned[id]
			if due.has(id) or roles_now.get(id, "") != role:
				plans[id] = _choose(id, team, role, now, obs, env)
			roles_now[id] = role
			var dir := Vector3.ZERO
			if now.up[id]:
				dir = _execute(id, team, role, now, obs, env)
			var scale := (value(team, "speed_scale") + sharpness) * (value(team, "red_skill") if team == "red" else 1.0)
			env.skate.want(id, dir.limit_length(1.0) * scale)

func _choose(id: String, team: String, role: String, now: Dictionary, obs: Dictionary, env: Dictionary) -> Dictionary:
	var me: Vector3 = now.pos[id]
	var api = env.api
	if caller == id:
		caller = ""
	if now.car == id:
		return carrier_play.choose(self, id, team, obs, me, env, plans.get(id, {}).get("action", ""))
	var opp: String = roles.other(team)
	var own := goal(team, env)
	var net := goal(opp, env)
	var sg := attack(team)
	var cp: Vector3 = obs.pos.get(obs.car, obs.puck)
	var d := me.distance_to(obs.puck)
	var yield_b0: bool = team == "blue" and not env.autopilot and obs.pos.b0.distance_to(obs.puck) <= d + 2.0 and obs.pos.b0.distance_to(obs.puck) < 15.0
	var target := Vector3.ZERO
	var action := "position"
	if obs.receiver == id:
		action = "receive"
	elif obs.car == roles.keeper[opp] and obs.car != "":
		target = cp + (own - cp).normalized() * value(team, "goalie_gap")
		target.z = own.z + clampf(env.spawns[id].z * 1.2, -11.0, 11.0)
	elif obs.car == "" and role.ends_with("1") and not yield_b0:
		action = "contest"
	elif role == "F1" and obs.car == roles.keeper[team] and obs.car != "":
		# Become the short outlet while the goalie holds. F2 offers the longer lane.
		var board_side := 1.0 if me.z >= own.z else -1.0
		target = own + Vector3(sg * 10.0, 0, board_side * 5.0)
	elif role == "F2" or (role == "F1" and yield_b0):
		target = roles.support(id, team, frame, obs, env, net, sg, reaction(opp))
		if role == "F2" and team == "blue" and not env.autopilot and obs.car == "b0" and api.carrier == "b0" and now.up[id]:
			var lead: Vector3 = api.projected_lead(obs.puck, me, now.vel[id])
			var safe: float = sense.lane(obs.puck, lead, api.pass_speed_at(d), roles.roster[opp], obs, reaction(opp))
			if safe * sense.open(me, roles.roster[opp], obs) > 0.6:
				caller = id
	elif role.begins_with("F"):
		target = roles.safety(team, obs, env, own, sg, reaction(opp))
	elif role == "D1" and obs.car != "":
		action = "pressure"
	elif role == "D2":
		target = roles.block(team, obs, env, reaction(team))
	else:
		target = roles.guard(obs, own, sg)
	return {"action": action, "target": target}

func _execute(id: String, team: String, role: String, now: Dictionary, obs: Dictionary, env: Dictionary) -> Vector3:
	var api = env.api
	var plan: Dictionary = plans[id]
	var action: String = plan.action
	var me: Vector3 = now.pos[id]
	var target: Vector3 = plan.target
	if api.carrier == id:
		var their: Vector3 = goal(roles.other(team), env)
		if team == "blue" and not env.autopilot and id != "b0" and not assisted() and api.puck_pos().distance_to(their) < 5.0:
			return (me - their).normalized()   # N3: the human's mate never takes it into their net himself (pro idle seeds 1, 20)
		if action == "shoot" or action.begins_with("pass_"):
			var timer: bool = action == "shoot" and api.from_pass and frame - api.carry_since <= int(api.carry.shot.one_timer_after)
			if action == "shoot" and (not api.can_shoot(id) or (team == "blue" and not env.autopilot and not assisted())):
				return Vector3.ZERO
			if api.carry.armed == id:
				return Vector3.ZERO
			if action.begins_with("pass_"):
				var mid := action.trim_prefix("pass_")
				if not obs.up[mid]:
					return Vector3.ZERO
				target = api.projected_lead(api.puck_pos(), obs.pos[mid], obs.vel[mid])
			if carrier_play.risky(self, team, api.puck_pos(), target, env):
				return (carrier_play._carry_target(me, goal(roles.other(team), env), goal(team, env), attack(team), roles.roster[roles.other(team)], obs) - me).normalized()
			var dir: Vector3 = (target - api.puck_pos()).normalized()
			# If the puck is on the trailing blade, turn it to the release side first.
			# An immediate backwards feed can strike the passer's own skate.
			var body_offset: Vector3 = me - api.puck_pos()
			var clearance: float = env.skaters[id].body_radius() + api.puck_radius
			if not timer and body_offset.dot(dir) > 0.0 and body_offset.cross(dir).length() < clearance:
				return dir
			api.stick_dir[id] = dir.rotated(Vector3.UP, deg_to_rad(rng.randfn(0, value(team, "aim_sigma_deg"))))
			if action == "shoot":
				if not api.try_one_timer(id):
					api.try_shoot(id)
			else:
				api.try_pass(id, action.trim_prefix("pass_"))
			api.stick_dir.erase(id)
			return Vector3.ZERO
		if action == "dump" and not carrier_play.risky(self, team, api.puck_pos(), target, env):
			api.try_dump(id, target - api.puck_pos())
			return Vector3.ZERO
		var skate_to := (target - me).normalized()
		if action == "protect":
			if now.vel[id].length() > 0.4 * env.skate.top_speed(id):
				braking[id] = true
			return skate_to * 0.4
		return skate_to
	var car: String = obs.car
	if car != "" and car == api.carrier and env.teams[car] != team and not api.goalies.has(car):
		if role.begins_with("D"):
			_contact(id, team, car, role, env)
	if action == "receive":
		# Estimate arrival from the observed flight and relative velocity. The observation
		# is already several frames old when the receiver chooses whether to coast.
		var rel: Vector3 = obs.pos[id] - obs.puck
		var closing: float = (obs.motion - now.vel[id]).dot(rel.normalized())
		var eta := rel.length() * 60.0 / maxf(0.01, closing) - (frame - int(obs.frame))
		if eta <= 10.0:
			return Vector3.ZERO
		return api.receive_dir(id, obs)
	var distance := me.distance_to(obs.puck)
	if action == "contest":
		target = obs.puck + obs.motion.limit_length(25.0) * clampf(distance / 10.0, 0.0, value(team, "lead_frames") / 60.0)
	elif action == "pressure" and car != "":
		var lead: Vector3 = obs.pos[car] + obs.vel[car] * clampf(distance / 10.0, 0.0, 0.5)
		# Contain from a stick's length on the inside. Matching this point lets D1
		# poke and time a hit without skating through a stationary carrier.
		target = lead + (goal(team, env) - lead).normalized() * api.poke_reach
	target = _around_net(me, target, env, team)
	var out := TLSteer.arrive(me, target, 1.5)
	if action == "contest":
		return (target - me).normalized()
	var mates := []
	for mid: String in roles.roster[team]:
		if mid != id:
			mates.append(obs.pos[mid])
	out += TLSteer.separate(me, mates, 4.0) * 1.2
	out += (roles.inside(me, env) - me).limit_length(1.0)
	if action == "position" or action == "pressure":
		# arrive() scales thrust. On ice the skater also needs to brake before the spot.
		var remaining := target - me
		var closing: float = maxf(0.0, now.vel[id].dot(remaining.normalized()))
		var brake_decel: float = env.skaters[id].skate_brake
		if remaining.length() <= closing * closing / (2.0 * brake_decel) + 0.25 and now.vel[id].length() > 0.3:
			braking[id] = true
	return out

## The decision to wind up is tested every frame using the actual contact geometry.
func _contact(id: String, team: String, car: String, role: String, env: Dictionary) -> void:
	var api = env.api
	var hits = env.hits
	var dc: float = api.pos_of(id).distance_to(api.pos_of(car))
	if role != "D1" and dc > 5.0:
		return
	var may: bool = not (car == "b0" and not env.autopilot and frame - int(api.carry_since) < int(value(team, "yield_frames")))
	var age: int = frame - int(api.carry_since)
	var stick_ok: bool = may and age >= int(value(team, "fresh_frames"))         # N3: a fresh carrier gets his first look (no stick on him)
	may = may and age >= int(value(team, "fresh_check_frames"))                  # ...and a shorter one before a body check (the owner: keep the hit rate)
	var gap: float = dc - hits.touch_distance(id, car)
	var lead: float = hits.check_gap + maxf(hits.closing(id, car), 0.0) * float(hits.check_windup) / 60.0
	if may and gap <= lead and not hits.graced(car) and hits.can_check(id) and hits.target(id, lead, hits.check_cone_deg) == car and hits.closing(id, car) >= value(team, "check_min_closing_" + team):
		hits.try_check(id)
	elif stick_ok and role == "D1" and gap <= hits.cross_gap and not hits.graced(car) and hits.can_cross(id) and hits.closing(id, car) > value(team, "cross_min_closing") and hits.in_cross_cone(id, car):
		hits.try_cross(id, car)
	elif stick_ok and role == "D1" and not hits.swinging(id) and api.can_poke(id) and api.poke_odds(id) >= value(team, "poke_min_odds"):
		api.try_poke(id)

func _around_net(me: Vector3, target: Vector3, env: Dictionary, team: String) -> Vector3:
	for side: String in ["blue", "red"]:
		var net := goal(side, env)
		var sg := -attack(side)
		if (target.x - net.x) * sg <= -0.2 or absf(target.z - net.z) >= value(team, "net_zone_half"):
			continue
		if (me.x - net.x) * sg > -0.5:
			return target
		var zs := signf(me.z - net.z) if absf(me.z - net.z) > 0.3 else (1.0 if target.z >= net.z else -1.0)
		return net + Vector3(sg * 0.8, 0, zs * value(team, "net_round_z"))
	return target
