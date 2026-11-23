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
const HIGH_M := 12.0
const RING_MIN := 9.0       # H2 sheet line 2: the support ring round the carrier, metres
const RING_MAX := 18.0
const CROWD_M := 5.0
const RESAMPLE := 10        # H2 sheet line 17: the support spot is re-chosen every 10 frames (30 before)
const BLOCK_MIN_M := 5.0    # H2 sheet line 1

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
	var high: float = obs.puck.x * attack - HIGH_M      # sheet line 2 (H2): the high man 12 m behind the puck (8 before)
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
	return goal + Vector3(attack * depth, 0, clampf((obs.puck.z - goal.z) * 0.5, -3.5, 3.5))   # sheet line 17: the post follows the puck

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
	# sheet line 1 (H2): the lane-blocker stands in the lane but never inside BLOCK_MIN_M of the carrier (he was the pile's
	# second body); the hunter, not he, goes at the carrier
	var spot: Vector3 = cp.lerp(target, 0.4)
	if spot.distance_to(cp) < BLOCK_MIN_M and target.distance_to(cp) > 0.1:
		spot = cp + (target - cp).normalized() * minf(BLOCK_MIN_M, target.distance_to(cp))
	return spot

func support(id: String, team: String, frame: int, obs: Dictionary, env: Dictionary, goal: Vector3, attack: float, reaction: float) -> Vector3:
	if frame < int(sampled.get(team, -30)) + RESAMPLE:
		return spot[team]
	var opp := other(team)
	var anchor: Vector3 = obs.pos.get(obs.car, obs.puck)
	var best := -INF
	var target := anchor
	# A rink-fixed grid remains stable while the carrier moves across it.
	var origin: Vector3 = env.api._flat(env.api.rink_root.global_position)
	# sheet line 2 (H2): the ring is RING_MIN-RING_MAX m from the carrier (it was 6-14), ideal 12-15, on a 2 m grid, and a
	# spot within CROWD_M of a mate (the chaser among them) is marked crowded
	var base := origin + (anchor - origin).snapped(Vector3(2.0, 1, 2.0))
	for ix in range(-9, 10):
		for iz in range(-9, 10):
			var p := base + Vector3(ix * 2.0, 0, iz * 2.0)
			var d := p.distance_to(anchor)
			if d < RING_MIN or d > RING_MAX or not inside(p, env).is_equal_approx(p):
				continue
			var safe: float = sense.lane(obs.puck, p, env.api.pass_speed_at(obs.puck.distance_to(p)), roster[opp], obs, reaction)
			var xg: float = sense.xg(p, goal, attack, roster[opp], keeper[opp], obs)
			var ideal := (d - RING_MIN) / 3.0 if d < 12.0 else (1.0 if d <= 15.0 else (RING_MAX - d) / 3.0)
			var crowded := 0.0
			for mate: String in field[team]:
				if mate != id and p.distance_squared_to(obs.pos[mate]) < CROWD_M * CROWD_M:
					crowded = 1.0
			var score := 0.35 * safe + 0.30 * xg + 0.20 * ideal - 0.30 * crowded
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
