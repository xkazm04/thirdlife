extends RefCounted
## Utilities are evaluated together against one observation. A pass to a different mate is a different choice.
var feed_roll := {}   # sheet line 5: carrier id -> [carry_since, whether he feeds the open human this carry]

func choose(b, id: String, team: String, obs: Dictionary, me: Vector3, env: Dictionary, prior: String) -> Dictionary:
	var api = env.api
	var opp: String = b.roles.other(team)
	var opponents: Array = b.roles.roster[opp]
	var goalie: String = b.roles.keeper[opp]
	var goal: Vector3 = b.goal(opp, env)
	var own_net: Vector3 = b.goal(team, env)
	var attack: float = b.attack(team)
	var fwd: Vector3 = api.fwd_of(id)
	var puck: Vector3 = api.puck_pos()   # on this skater's own blade
	var nearest: String = b.sense.nearest(me, opponents, obs)
	var rel: Vector3 = obs.pos[nearest] - me
	var pressure := clampf((5.0 - rel.length()) / 3.5, 0.0, 1.0)
	if rel.dot(fwd) < 0:
		pressure *= 0.5
	var quality: float = b.sense.xg(me, goal, attack, opponents, goalie, obs)
	var feed: bool = team == "blue" and not env.autopilot and id != "b0"
	var scores := {}
	var targets := {}
	var corner := _corner(goal, puck, goalie, obs, b.value(team, "corner_z"))
	var shot := corner - puck
	if quality >= b.value(team, "shoot_min_xg") and shot.angle_to(fwd) <= deg_to_rad(100.0):   # sheet line 3: the human's mates shoot too
		var timer: bool = api.from_pass and b.frame - api.carry_since <= int(api.carry.shot.one_timer_after)
		scores["shoot"] = b.value(team, "shoot_weight") * quality + (0.2 if timer else 0.0) - 0.3 * pressure * (1.0 - quality)   # sheet line 7 (H2): the weight by level (1.6 for all before)
		targets["shoot"] = corner
	var max_lane := 0.0
	for mid: String in b.roles.field[team]:
		if mid == id or not obs.up[mid]:
			continue
		var mate: Vector3 = obs.pos[mid]
		var lead: Vector3 = api.projected_lead(puck, mate, obs.vel[mid])
		if _near_own_net(puck, lead, own_net, attack, api.rink_half.y):
			continue                         # N3: no pass across our own goal mouth (red's own goals won rookie for an idle hand)
		var safe: float = b.sense.lane(puck, lead, api.pass_speed_at(puck.distance_to(mate)), opponents, obs, b.reaction(opp))
		max_lane = maxf(max_lane, safe)
		if safe < b.value(team, "pass_min_lane"):
			continue
		var gain: float = b.sense.xg(mate, goal, attack, opponents, goalie, obs) - quality + 0.45 * clampf((mate.x - me.x) * attack / 15.0, -1, 1)   # sheet line 9 (H2): a pass up ice is worth more (0.3 before)
		var key := "pass_" + mid
		scores[key] = b.value(team, "pass_weight") * safe * b.sense.open(mate, opponents, obs) * (0.5 + clampf(gain, 0.0, 1.0)) + 0.25 * pressure
		targets[key] = lead
	var age := clampf((b.frame - api.carry_since) / 300.0, 0.0, 1.0)
	var boards_x: float = api.rink_root.global_position.x + api.rink_half.x * attack
	scores["carry"] = 0.9 * b.sense.space_ahead(me, attack, opponents, obs, boards_x, api.reach) * (1.0 - pressure) + 0.15 - 0.2 * age
	scores["protect"] = b.value(team, "protect_weight") * pressure * (1.0 - max_lane)
	var center: Vector3 = api._flat(api.rink_root.global_position)
	var own_half := 1.0 if (me.x - center.x) * attack < 0 else 0.0
	scores["dump"] = 0.5 * own_half * pressure * (1.0 - max_lane)
	if _near_own_net(puck, corner, own_net, attack, api.rink_half.y):
		scores.erase("shoot")               # N3: never a shot or a dump that starts behind our own net
		scores.erase("dump")
	var best := -INF
	var chosen := ""
	var noise: float = b.value(team, "score_noise")
	for action: String in scores:
		var score: float = scores[action] + b.rng.randf_range(-noise, noise)
		if action == prior:
			score += b.value(team, "commit_bonus")
		if score > best:
			best = score
			chosen = action
	# sheet line 5 (thirdjam JamAICore.cpp:1686-1733): when the human is open ahead (his lane passed the threshold above),
	# his mate feeds him in feed_share of his carries by the level (0.6 / 0.4 / 0.2), rolled once a carry
	if feed and scores.has("pass_b0") and (obs.pos.b0.x - me.x) * attack > 0.0:
		var roll: Array = feed_roll.get(id, [])
		if roll.is_empty() or int(roll[0]) != int(api.carry_since):
			roll = [int(api.carry_since), b.roll([id, "feed", int(api.carry_since)]) < b.level_value("feed_share")]
			feed_roll[id] = roll
		if bool(roll[1]):
			chosen = "pass_b0"
	var target: Vector3 = targets.get(chosen, goal)
	match chosen:
		"carry":
			target = _carry_target(me, goal, b.goal(team, env), attack, opponents, obs)   # sheet line 4: a mate carries it in too
		"protect":
			var away := -rel.normalized()
			if absf(me.z - center.z) > env.api.rink_half.y - 3.0:
				away = Vector3(signf(away.x) if absf(away.x) > 0.1 else attack, 0, 0)
			target = b.roles.inside(me + away * 4.0, env)
		"dump":
			target = goal + Vector3(attack, 0, (env.api.rink_half.y - 2.0) * (1 if me.z >= center.z else -1))
	return {"action": chosen, "target": target}

## N3: whether a release from `from` toward `to` risks our own net (the brain asks again at the release itself).
func risky(b, team: String, from: Vector3, to: Vector3, env: Dictionary) -> bool:
	return _near_own_net(from, to, b.goal(team, env), b.attack(team), env.api.rink_half.y)

## N3: a pass whose path runs within 3.5 m of our own goal centre, or whose target lies behind our goal line, is never
## made: a bobble, a deflection or a stick on the way puts it in our own net.
func _near_own_net(from: Vector3, to: Vector3, net: Vector3, attack: float, _half_w: float = 15.0) -> bool:
	if (to.x - net.x) * attack < 1.0 or ((from.x - net.x) * attack < 0.5 and absf(from.z - net.z) < 3.5):
		return true                      # a target behind our line, or a release from behind our own net (it crosses the goal box)
	var seg := to - from
	var t := clampf((net - from).dot(seg) / maxf(seg.length_squared(), 1e-6), 0.0, 1.0)
	if (from + seg * t).distance_to(net) < 3.5:
		return true
	# sheet line 10 (H2, 23 Nov): the back-pass and corner-carom guards (an idle hand's win, rookie seed 7) are gone; a pass
	# back toward our own end is hockey. The guard on a pass across our own mouth stays.
	return false

func _corner(goal: Vector3, puck: Vector3, goalie: String, obs: Dictionary, corner_z: float) -> Vector3:
	var side := 0.0
	if goalie != "":
		var gz: float = obs.pos[goalie].z - goal.z
		side = -signf(gz) if absf(gz) > 0.1 else (1.0 if puck.z < goal.z else -1.0)
	return goal + Vector3(0, 0, side * corner_z)

func _carry_target(me: Vector3, goal: Vector3, own: Vector3, attack: float, opponents: Array, obs: Dictionary) -> Vector3:
	var target := goal - Vector3(attack * 4.0, 0, 0)
	if (me.x - own.x) * attack < 1.5:
		return own + Vector3(attack * 3.0, 0, 6 if me.z >= own.z else -6)
	if (me.x - goal.x) * attack > -0.5:
		return goal + Vector3(-attack * 4.0, 0, 3 if me.z >= goal.z else -3)
	var heading := (target - me).normalized()
	var nearest := 5.0
	var detour := Vector3.ZERO
	for oid: String in opponents:
		var rel: Vector3 = obs.pos[oid] - me
		var lateral := heading.cross(rel).y
		if rel.dot(heading) > 0.0 and rel.length() < nearest and absf(lateral) < 2.0:
			nearest = rel.length()
			detour = Vector3(-heading.z, 0, heading.x) * (3.0 if lateral >= 0 else -3.0)
	return me + heading * nearest + detour if detour != Vector3.ZERO else target
