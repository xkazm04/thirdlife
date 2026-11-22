extends RefCounted
## Roles are shared by the three field skaters. The human occupies a slot in the same arrival ordering.
var field := {"blue": [], "red": []}
var roster := {"blue": [], "red": []}
var keeper := {"blue": "", "red": ""}
var first := {}
var assigned := {}
var spot := {}
var sampled := {}
var sense

func setup(env: Dictionary, perception) -> void:
	sense = perception
	for id: String in env.skaters:
		var team: String = env.teams[id]
		roster[team].append(id)
		if env.roles[id] == "goalie":
			keeper[team] = id
		else:
			field[team].append(id)

func other(team: String) -> String:
	return "red" if team == "blue" else "blue"

func assign(team: String, obs: Dictionary, reaction: float) -> void:
	var order: Array = field[team].duplicate()
	var arrival := {}
	for id: String in order:
		arrival[id] = obs.puck.distance_to(obs.pos[id]) / float(obs.speed[id]) + reaction
	order.sort_custom(func(a, b): return arrival[a] < arrival[b])
	var leader: String = order[0]
	var old: String = first.get(team, leader)
	if obs.car in order:
		leader = obs.car
	elif obs.receiver in order:
		# A directed flight already has a first man. Keep the passer and third man available.
		leader = obs.receiver
	elif arrival[old] - arrival[leader] < 0.3:
		leader = old
	first[team] = leader
	order.erase(leader)
	order.push_front(leader)
	var attack: bool = obs.last_team == team
	for i in order.size():
		assigned[order[i]] = ("%s%d" % ["F" if attack else "D", i + 1])

func inside(p: Vector3, env: Dictionary) -> Vector3:
	var api = env.api
	var center: Vector3 = api._flat(api.rink_root.global_position)
	var local := p - center
	var half: Vector2 = api.rink_half
	var r: float = api.rink_corner
	var core := Vector3(clampf(local.x, -half.x + r, half.x - r), 0, clampf(local.z, -half.y + r, half.y - r))
	return center + core + (local - core).limit_length(r - 1.5)

func safety(team: String, obs: Dictionary, env: Dictionary, goal: Vector3, attack: float, reaction: float) -> Vector3:
	var high: float = obs.puck.x * attack - 8.0
	for oid: String in field[other(team)]:
		high = minf(high, obs.pos[oid].x * attack - 0.5)
	# Keep the high man's depth, then choose the open side for a return pass.
	var center_z: float = lerpf(goal.z, obs.puck.z, 0.45)
	var best := -INF
	var target := Vector3.ZERO
	var enemies: Array = roster[other(team)]
	for offset: float in [0.0, -4.5, 4.5, -9.0, 9.0]:
		var p := inside(Vector3(high * attack, 0, center_z + offset), env)
		if absf(p.x - goal.x) < 4.0 and absf(p.z - goal.z) < 4.0:
			continue
		var speed: float = env.api.pass_speed_at(obs.puck.distance_to(p))
		var quality: float = sense.lane(obs.puck, p, speed, enemies, obs, reaction) * sense.open(p, enemies, obs)
		if quality > best:
			best = quality
			target = p
	return target

func guard(obs: Dictionary, goal: Vector3, attack: float) -> Vector3:
	var depth := clampf(absf(obs.puck.x - goal.x) * 0.35, 4.0, 7.0)
	return goal + Vector3(attack * depth, 0, clampf((obs.puck.z - goal.z) * 0.30, -2.5, 2.5))

func block(team: String, obs: Dictionary, env: Dictionary, reaction: float) -> Vector3:
	var opp := other(team)
	var passer: String = obs.car if obs.car in field[opp] else sense.nearest(obs.puck, field[opp], obs)
	var cp: Vector3 = obs.pos[passer]
	var target := cp
	var best := -1.0
	for id: String in field[opp]:
		if id == passer or not obs.up[id]:
			continue
		var p: Vector3 = obs.pos[id]
		var to: Vector3 = env.api.projected_lead(obs.puck, p, obs.vel[id])
		var safe: float = sense.lane(obs.puck, to, env.api.pass_speed_at(obs.puck.distance_to(p)), roster[team], obs, reaction)
		var score: float = safe * sense.open(p, roster[team], obs)
		if score > best:
			best = score
			target = p
	return cp.lerp(target, 0.4)

func support(id: String, team: String, frame: int, obs: Dictionary, env: Dictionary, goal: Vector3, attack: float, reaction: float) -> Vector3:
	if frame < int(sampled.get(team, -30)) + 30:
		return spot[team]
	var opp := other(team)
	var anchor: Vector3 = obs.pos.get(obs.car, obs.puck)
	var best := -INF
	var target := anchor
	# A rink-fixed grid remains stable while the carrier moves across it.
	var origin: Vector3 = env.api._flat(env.api.rink_root.global_position)
	var base := origin + (anchor - origin).snapped(Vector3(1.5, 1, 1.5))
	for ix in range(-10, 11):
		for iz in range(-10, 11):
			var p := base + Vector3(ix * 1.5, 0, iz * 1.5)
			var d := p.distance_to(anchor)
			if d < 6 or d > 14 or not inside(p, env).is_equal_approx(p):
				continue
			var safe: float = sense.lane(obs.puck, p, env.api.pass_speed_at(obs.puck.distance_to(p)), roster[opp], obs, reaction)
			var xg: float = sense.xg(p, goal, attack, roster[opp], keeper[opp], obs)
			var ideal := (d - 6.0) / 3.0 if d < 9.0 else (14.0 - d) / 5.0
			var crowded := 0.0
			for mate: String in field[team]:
				if mate != id and p.distance_squared_to(obs.pos[mate]) < 16.0:
					crowded = 1.0
			var score := 0.35 * safe + 0.30 * xg + 0.20 * ideal - 0.15 * crowded
			if score > best or (is_equal_approx(score, best) and p.distance_squared_to(obs.pos[id]) < target.distance_squared_to(obs.pos[id])):
				best = score
				target = p
	if (anchor.x - origin.x) * attack >= 10.0:
		var far := goal + Vector3(-attack * 3.0, 0, -1.5 if obs.puck.z > goal.z else 1.5)
		if sense.xg(far, goal, attack, roster[opp], keeper[opp], obs) > sense.xg(target, goal, attack, roster[opp], keeper[opp], obs):
			target = far
	sampled[team] = frame
	spot[team] = target
	return target
