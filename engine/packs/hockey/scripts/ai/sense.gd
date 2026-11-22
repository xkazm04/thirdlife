extends RefCounted
## A history of observable play. Geometry below takes an explicit observation and never looks up a live opponent.

const DEPTH := 24
var frames: Array[Dictionary] = []
var cursor := -1

func reset() -> void:
	frames.clear()
	cursor = -1

func record(frame: int, env: Dictionary) -> Dictionary:
	# N3 (frame budget): the ring's snapshots are reused in place once it is full (no new dictionaries each frame)
	var api = env.api
	cursor = (cursor + 1) % DEPTH
	var snap: Dictionary
	if frames.size() < DEPTH:
		snap = {"pos": {}, "vel": {}, "up": {}, "speed": {}}
		frames.append(snap)
	else:
		snap = frames[cursor]
	var pos: Dictionary = snap.pos
	var vel: Dictionary = snap.vel
	var upright: Dictionary = snap.up
	var speed: Dictionary = snap.speed
	var hits = env.hits
	for id: String in env.skaters:
		var sk: TLBiped = env.skaters[id]
		var gp: Vector3 = sk.global_position
		pos[id] = Vector3(gp.x, 0.0, gp.z)
		var v: Vector3 = sk.velocity
		vel[id] = Vector3(v.x, 0.0, v.z)
		upright[id] = hits.can_act(id)
		speed[id] = maxf(0.1, sk.skate_speed)
	snap.frame = frame
	snap.puck = api.puck_pos()
	snap.motion = api._flat(env.puck.linear_velocity)
	snap.car = api.carrier
	snap.receiver = api.last_release.get("to", "") if api.puck_state == "pass" else ""
	snap.loose = api.puck_state == "loose"
	snap.last_team = env.teams.get(api.carry.last_owner, "")
	return snap

func ago(lag: int) -> Dictionary:
	var cutoff: int = frames[cursor].frame - lag
	var index := cursor
	for age in range(1, frames.size()):
		if frames[index].frame <= cutoff:
			break
		index = posmod(cursor - age, DEPTH)
	return frames[index]

func nearest(p: Vector3, opponents: Array, obs: Dictionary) -> String:
	var best := ""
	var dist := INF
	for id: String in opponents:
		var d := p.distance_squared_to(obs.pos[id])
		if d < dist:
			dist = d
			best = id
	return best

func open(p: Vector3, opponents: Array, obs: Dictionary) -> float:
	var id := nearest(p, opponents, obs)
	return 1.0 if id.is_empty() else clampf((p.distance_to(obs.pos[id]) - 1.5) / 4.0, 0.0, 1.0)

func lane(from: Vector3, target: Vector3, speed: float, opponents: Array, obs: Dictionary, reaction: float) -> float:
	var segment := target - from
	var length := segment.length()
	if length < 0.01:
		return 0.0
	var path := segment / length
	var margin := INF
	for id: String in opponents:
		var p: Vector3 = obs.pos[id]
		var along := clampf((p - from).dot(path), 0.0, length)
		var reach_time := (p.distance_to(from + path * along) - 1.45) / 9.0 + reaction
		margin = minf(margin, reach_time - along / speed)
	return clampf((margin + 0.1) / 0.5, 0.0, 1.0)

func xg(p: Vector3, goal: Vector3, attack: float, opponents: Array, goalie: String, obs: Dictionary) -> float:
	var shot := goal - p
	var length := shot.length()
	var axis := Vector3(attack, 0, 0)
	var path := shot.normalized() if length > 0.001 else axis
	var score := clampf((22.0 - length) / 18.0, 0.0, 1.0) * clampf(1.0 - rad_to_deg(path.angle_to(axis)) / 70.0, 0.0, 1.0)
	for id: String in opponents:
		if id == goalie:
			continue
		var rel: Vector3 = obs.pos[id] - p
		if (rel - path * clampf(rel.dot(path), 0, length)).length_squared() <= 0.81:
			score *= 0.3
			break
	if goalie != "":
		var rel: Vector3 = obs.pos[goalie] - p
		score += 0.15 * minf(1.0, rel.cross(path).length())
	return clampf(score, 0.0, 1.0)

func space_ahead(p: Vector3, attack: float, opponents: Array, obs: Dictionary, boards_x: float, reach: float) -> float:
	var free := clampf((boards_x - p.x) * attack, 0, 10)
	var edge := Vector2(cos(PI / 6.0), sin(PI / 6.0))
	for id: String in opponents:
		var delta: Vector3 = obs.pos[id] - p
		var rel := Vector2(delta.x * attack, absf(delta.z))
		if rel.x < -reach:
			continue
		var off := edge.cross(rel)
		if off <= 0.0:
			free = minf(free, maxf(0, rel.length() - reach))
		elif off < reach and rel.dot(edge) >= 0.0:
			# Even just outside the cone a stick can cut into the open ice.
			free = minf(free, maxf(0, rel.dot(edge) - sqrt(reach * reach - off * off)))
	return free / 10.0
