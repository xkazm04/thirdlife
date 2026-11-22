extends RefCounted
## L5 (21 Nov): the goalies, one per side (data/tuning.json "goalie"; a mode turns them off with "goalies": false).
## A goalie is a TLBiped in main's lists (skaters, teams, order; role "goalie") that the brain leaves alone. He stands in
## his crease on the line from his goal's centre to the puck as he saw it reaction_frames ago, one to two metres in front of
## the line (never past z_max from the middle), moves there at `speed` m/s at most and faces the puck.
## Saves: a loose puck coming at his net whose last step passed inside his `glove` reach is his (a catch; on the move,
## faster than set_speed, his reach is moving_reach of it: a one-timer after a pass across beats him); an opponent's
## carried puck that comes inside his `poke` reach is his (a poke check). His body blocks the rest (a rebound).
## He holds a caught puck hold_frames, then passes to the most open mate (b0 preferred by prefer_human metres).
## Nobody checks or pokes him (hits.shield, api.goalies). The level ("goalie" in data/levels/<id>.json) changes the red
## goalie only, as it changes only red's skaters. Beaten by: a shot to the side he has not reached yet (after a pass
## across or a quick move, his reaction lags), a shot outside his glove, a rebound.
## Created by main.gd, no class_name; g = main.

var ids: Dictionary = {}               ## team -> the goalie's id (empty: this mode has none)
var saves: Dictionary = {}             ## team -> saves its goalie made (catches and poke checks)
var gx: Dictionary = {}                ## team -> x of its goal line
var events: Array = []                 ## [kind, id] since main drained it ("save")
var _seen: Array = []                  ## the puck's positions, newest first
var _held: int = 0                     ## frames the goalie with the puck has held it
var _cache: Dictionary = {}            ## team -> config for the level in _cache_level
var _cache_level: String = "?"
var _moving: Dictionary = {}           ## team -> his speed over the last frame (m/s): a goalie on the move reaches less
var in_drill: bool = false             ## the drill running keeps the goalies in their nets (drills.json "goalies": true)


## The roster entries of this mode's goalies (none when the mode says "goalies": false). Resets the counts.
func entries(g, m: Dictionary) -> Array:
	ids = {}
	saves = {}
	_seen = []
	_held = 0
	_cache_level = "?"
	var base: Dictionary = g.tune["goalie"]
	for key: String in base:
		if key not in ["on", "body_scale", "out", "z_max", "speed", "turn_deg", "reaction_frames", "glove", "set_speed",
				"moving_reach", "catch_speed", "poke", "hold_frames", "prefer_human", "outlet_min", "cover", "drop_speed", "slow_speed", "slow_reach"]:
			push_error("tuning.json: unknown goalie." + key)
	if not bool(m.get("goalies", base["on"])):
		return []
	var out: Array = []
	for team: String in ["blue", "red"]:
		var x: float = float(g.tune["goals"][team][0])
		var id: String = "g" + team.substr(0, 1)
		ids[team] = id
		saves[team] = 0
		gx[team] = x
		out.append({"id": id, "team": team, "role": "goalie", "spawn": [x - signf(x) * float(base["out"]), 0.0],
			"colors": {"top": "car_blue" if team == "blue" else "car_red", "trim": "car_white", "legs": "car_white"},
			"scale": float(base["body_scale"])})
	return out


## A goalie's numbers: data/tuning.json "goalie"; for red, the level's "goalie" keys over them.
func cfg(g, team: String) -> Dictionary:
	if _cache_level != g.level_id:
		_cache = {}
		_cache_level = g.level_id
	if not _cache.has(team):
		var c: Dictionary = (g.tune["goalie"] as Dictionary).duplicate()
		if team == "red" and g.levels.has(g.level_id):
			c.merge(g.levels[g.level_id].get("goalie", {}), true)
		_cache[team] = c
	return _cache[team]


## The rink's centre in the world (positions read from the bodies are global; the goals are the pack's own).
func _origin(g) -> Vector3:
	var o: Vector3 = g.ctx.root.global_position
	return Vector3(o.x, 0.0, o.z)


func is_goalie(id: String) -> bool:
	return id.length() == 2 and id.begins_with("g") and ids.has("blue" if id == "gb" else "red") and ids["blue" if id == "gb" else "red"] == id


## Live, before possession (a catch or a poke check comes before anybody's reach).
func save(g) -> void:
	var api = g.api
	var gpp: Vector3 = api.puck_pos()
	_seen.push_front(gpp)
	if _seen.size() > 40:
		_seen.pop_back()
	var o: Vector3 = _origin(g)
	var pp: Vector3 = gpp - o                             # the pack's own coordinates (a world puts it anywhere)
	for team: String in ids:
		if absf(pp.x - float(gx[team])) > 12.0:
			continue                           # the puck far from his net: nothing to save (budget: frame p50)
		var id: String = ids[team]
		var c: Dictionary = cfg(g, team)
		var sg: float = signf(float(gx[team]))
		var front: float = (float(gx[team]) - pp.x) * sg          # metres in front of his goal line (< 0: behind it)
		if api.carrier != "" and api.carrier != id and str(g.teams[api.carrier]) == team and front > -1.5 and front < float(c["cover"]) \
				and absf(pp.z) < float(g.tune["goals"]["half_width"]) + 0.5:
			_held = 0                          # a mate's puck at his goal mouth: he covers it (an AI carrier circling his own
			g.api.give(id)                     # net swept the blade-carried puck into it: own goals with an idle b0, 21 Nov)
			_face_up(g, team, id)
			return
		if api.carrier == "":
			var pv: Vector3 = g.puck.linear_velocity
			var toward: float = pv.x * sg
			var reach: float = float(c["glove"]) * (float(c["moving_reach"]) if float(_moving.get(team, 0.0)) > float(c["set_speed"]) else 1.0)
			if front >= 0.0 and toward > float(c["catch_speed"]) and api.dist_to_puck(id) <= reach:
				_take(g, team, id)
				return
			# N3: a slow puck sliding into his mouth (a missed pass, a poke, a dump) is his within slow_reach: own goals from
			# rookie's missed back passes won matches for an idle hand (22 Nov)
			var own_pass: bool = str(api.last_release.get("kind", "")) == "pass" and str(api.last_release.get("team", "")) == team
			if (own_pass or Vector2(pv.x, pv.z).length() < float(c["slow_speed"])) and api.dist_to_puck(id) <= float(c["slow_reach"]):
				if _enters_mouth(front, pp.z, toward, pv.z, float(g.tune["goals"]["half_width"])):
					_take(g, team, id)
					return
		elif front >= 0.0 and api.carrier != id and str(g.teams[api.carrier]) != team and pp.distance_to(api.pos_of(id) - o) <= float(c["poke"]):
			_take(g, team, id)
			return


## A board rebound can cross the line wide, then slide into the scoring volume beside the post.
func _enters_mouth(front: float, z: float, toward: float, vz: float, half_width: float) -> bool:
	if front >= 0.0 and toward > 0.1 and absf(z + vz * front / toward) < half_width + 0.3:
		return true
	if absf(z) <= half_width or vz * z >= 0.0:
		return false
	var time_to_post := (signf(z) * half_width - z) / vz
	var depth := toward * time_to_post - front
	return depth >= 0.0 and depth <= 1.5    # same depth as the goal trigger and goal_by_position

func _take(g, team: String, id: String) -> void:
	var shot: bool = g.api.carrier == "" and g.puck.linear_velocity.length() >= 8.0     # a shot caught (not a poke check)
	g.api.give(id)
	_face_up(g, team, id)
	saves[team] = int(saves[team]) + 1
	if shot:
		events.append(["big_save", id])
	_held = 0
	events.append(["save", id])


## With the puck he turns up ice at once, so it rides on his blade in front of his net, never beside or behind it (a
## goalie who caught a puck facing the boards passed it into his own net from there: an idle hand's win, 21 Nov).
func _face_up(g, team: String, id: String) -> void:
	var sk: TLBiped = g.skaters[id]
	sk.place(sk.global_position, g._face_yaw(team))


## Live, after the brain: each goalie to his spot, or (with the puck) a hold and then the outlet pass.
func move(g) -> void:
	var api = g.api
	for team: String in ids:
		var id: String = ids[team]
		var sk: TLBiped = g.skaters[id]
		var c: Dictionary = cfg(g, team)
		sk.brake(true)
		sk.move(Vector3.ZERO)
		if sk.is_physics_processing() and g.ctx.frame > 2:
			sk.set_physics_process(false)      # placed by this script every frame: the biped's own step (a floor ray, a
			                                   # slide, the rig) is not needed after his first frames (budget: frame p50)
		_moving[team] = 0.0
		if api.carrier == id:
			_held += 1
			if _held >= int(c["hold_frames"]):
				_outlet(g, team, id, c)
			continue
		var x: float = float(gx[team])
		var sg: float = signf(x)
		var lag: int = mini(int(c["reaction_frames"]), _seen.size() - 1)
		var o: Vector3 = _origin(g)
		var p: Vector3 = (_seen[lag] if lag >= 0 else api.puck_pos()) - o
		var zmax: float = float(c["z_max"])
		var goal: Vector3 = Vector3(x, 0.0, 0.0)
		var depth := lerpf(1.0, 2.0, clampf((goal.distance_to(p) - 6.0) / 14.0, 0.0, 1.0))
		var front := (x - p.x) * sg
		var z := p.z * depth / front if front > depth else p.z
		var want := Vector3(x - sg * depth, 0.0, clampf(z, -zmax, zmax))
		var at: Vector3 = api.pos_of(id) - o
		var nxt: Vector3 = at.move_toward(want, minf(float(c["speed"]), 4.0) / 60.0)
		_moving[team] = at.distance_to(nxt) * 60.0
		var face: Vector3 = p - nxt
		var yaw: float = sk.rotation.y
		if face.length() > 0.3:
			yaw = rotate_toward(yaw, atan2(-face.x, -face.z), deg_to_rad(float(c["turn_deg"])))
		if nxt.distance_squared_to(at) > 1e-8 or absf(yaw - sk.rotation.y) > 1e-5:
			sk.place(Vector3(nxt.x + o.x, sk.global_position.y, nxt.z + o.z), yaw)     # only when he moves (budget)


## The pass out of his zone: to the mate with the most room (b0 counts prefer_human metres more), along the stick.
func _outlet(g, team: String, id: String, c: Dictionary) -> void:
	var api = g.api
	var best: String = ""
	var best_room: float = -1e9
	for mid: String in g.order:
		if mid == id or str(g.teams[mid]) != team or is_goalie(mid) or not g.hits.can_act(mid):
			continue
		if (api.pos_of(mid).x - _origin(g).x - float(gx[team])) * -signf(float(gx[team])) < float(c["outlet_min"]):
			continue                           # never to a mate at his own net (one took it into it: an own goal, 21 Nov)
		var room: float = 1e9
		for oid: String in g.order:
			if str(g.teams[oid]) != team and not is_goalie(oid):
				room = minf(room, api.pos_of(oid).distance_to(api.pos_of(mid)))
		if mid == "b0" and not g.autopilot:
			room += float(c["prefer_human"])
		if room > best_room:
			best_room = room
			best = mid
	# the pass goes to the mate chosen here (a pass picked by the stick's cone once went to a mate lying on the ice and slid
	# 50 m into the far net: an idle hand's win, 21 Nov); with nobody up ice he holds on, then drops it softly up the middle
	var to: Vector3 = Vector3(-signf(float(gx[team])), 0.0, 0.0)
	var spd: float = float(c["drop_speed"])
	if best != "":
		var lead: Vector3 = api.lead_point(best) - api.puck_pos()
		if lead.length() > 0.2:
			to = lead.normalized()
			spd = api.pass_speed_to(best)
	elif _held < int(c["hold_frames"]) * 3:
		return
	api._release("pass", id, to * spd)
	if best != "":
		api.last_release["to"] = best
	api.passes[id] = int(api.passes[id]) + 1
	api.events.append(["pass", id])
	api._clip(id, &"pass")
	_held = 0
