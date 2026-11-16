extends Node
## game.ice_hockey_three_against, hockey_core: rink, puck, six skaters, rules, HUD. First to 3 goals.
## Venue: data/venue.json (kit rink + goals). Tuning: data/tuning.json. Handlers only set flags; _pack_tick acts last.

var ctx
var tune: Dictionary
var rules: TLRules
var hud: TLHud
var puck: TLBall
var api
var brain = null
var fx = null
var skaters: Dictionary = {}          # id -> TLBiped
var order: Array = []                 # ids in roster order
var teams: Dictionary = {}
var roles: Dictionary = {}
var spawns: Dictionary = {}
var env: Dictionary = {}
var goal_pos: Dictionary = {}
var frozen: bool = false
var reset_in: int = 0                 # frames left of the pause after a goal
var result: String = ""
var _flag_goal: String = ""           # side that scored, set by a goal trigger
var _events: Array = []               # [name, pos, team] for the fx hook


func _pack_setup(c) -> void:
	ctx = c
	tune = ctx.read_json("tuning.json")
	var built: Dictionary = TLKit.build_layout(ctx.read_json("venue.json"), ctx.root)
	if not built["ok"]:
		push_error("venue.json does not build: %s" % "; ".join(built["errors"]))
		return
	if ctx.root.has_meta(&"hockey_dress"):
		var dressed: Dictionary = TLKit.build_layout(ctx.read_json(str(ctx.root.get_meta(&"hockey_dress"))), ctx.root)
		if not dressed["ok"]:
			push_error("dress layout does not build: %s" % "; ".join(dressed["errors"]))

	var pk: Dictionary = tune["puck"]
	puck = TLBall.create({"part": TLKit.build("puck", {"radius": float(pk.get("radius", 0.12)), "height": float(pk.get("height", 0.08))}), "planar": true, "color": Color(0.02, 0.02, 0.03), "group": "pucks", "max_speed": float(pk["max_speed"]),
		"drag": float(pk["drag"]), "position": Vector3(0, 0.07, 0), "name": "Puck"})
	ctx.root.add_child(puck)
	puck.bounced.connect(_on_puck_bounced)

	var opts: Dictionary = (tune["skater"] as Dictionary).duplicate()
	for entry: Dictionary in tune["roster"]:
		var id: String = str(entry["id"])
		var team: String = str(entry["team"])
		var sp: Array = entry["spawn"]
		var at := Vector3(float(sp[0]), 0.1, float(sp[1]))
		var o: Dictionary = opts.duplicate()
		o.merge({"mode": "skate", "position": at, "facing": _face_yaw(team), "name": "skater_" + id,
			"rig_params": {"colors": {"top": "car_blue" if team == "blue" else "car_red", "trim": "car_blue" if team == "blue" else "car_red", "legs": "car_blue" if team == "blue" else "car_red"}}})
		var sk: TLBiped = TLBiped.create(o)
		ctx.root.add_child(sk)
		if sk.rig != null:
			sk.rig.scale = Vector3(2.2, 2.2, 2.2)
		skaters[id] = sk
		order.append(id)
		teams[id] = team
		roles[id] = str(entry["role"])
		spawns[id] = at
	var g: Dictionary = tune["goals"]
	goal_pos = {"blue": _v3(g["blue"]), "red": _v3(g["red"])}

	# goal volumes just behind each line, inside the nets; the trigger decides "the whole puck crossed"
	for side: String in ["blue", "red"]:
		var sgn: float = -1.0 if side == "blue" else 1.0
		var trig: TLTrigger = TLBodies.trigger(&"box", Vector3(1.5, 1.0, float(g["half_width"]) * 2.0),
			{"position": Vector3(sgn * 26.75, 0.3, 0.0), "group_filter": "pucks", "name": "goal_trigger_" + side})
		ctx.root.add_child(trig)
		trig.entered.connect(_on_goal.bind(side))

	api = ctx.load_script("scripts/rink_api.gd").new()
	api.setup(tune, puck, skaters)

	_new_rules()
	for a: Array in [[&"up", KEY_W], [&"down", KEY_S], [&"left", KEY_A], [&"right", KEY_D], [&"shoot", KEY_SPACE], [&"restart", KEY_R]]:
		ctx.input.declare(a[0], [a[1]])
	var cam: Dictionary = tune["camera"]
	ctx.cameras.add_view(&"arena", _v3(cam["pos"]), _v3(cam["target"]), float(cam["fov"]))
	ctx.cameras.set_subject(&"arena", skaters["b0"])

	env = {"puck": puck, "skaters": skaters, "teams": teams, "roles": roles, "spawns": spawns, "goals": goal_pos,
		"frozen": false, "api": api, "tuning": tune, "rules": rules}
	if ctx.root.has_meta(&"hockey_ai"):
		brain = ctx.load_script(str(ctx.root.get_meta(&"hockey_ai"))).new()
		brain.setup(ctx, env)
	if ctx.root.has_meta(&"hockey_fx"):
		fx = ctx.load_script(str(ctx.root.get_meta(&"hockey_fx"))).new()
		fx.setup(ctx, env)


func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Heading (radians about y) that makes a skater face the opponent's goal: blue +x, red -x.
func _face_yaw(team: String) -> float:
	return -PI * 0.5 if team == "blue" else PI * 0.5


func _new_rules() -> void:
	rules = TLRules.create(tune["rules"])
	ctx.root.add_child(rules)
	hud = TLHud.create()
	ctx.root.add_child(hud)
	hud.add_score(rules, "blue", &"top_left", "BLUE")
	hud.add_score(rules, "red", &"top_right", "RED")
	hud.add_bound(&"result", func() -> String: return result, &"center")


func _pack_start() -> void:
	rules.start()
	_event("faceoff", Vector3.ZERO, "")


func _on_puck_bounced(other: Node, speed: float) -> void:
	if speed >= 6.0 and not (other is TLBiped):
		_event("board", puck.global_position, "")


func _on_goal(body: Node3D, side: String) -> void:
	if body == puck and _flag_goal == "" and reset_in <= 0 and not frozen:
		_flag_goal = "red" if side == "blue" else "blue"


func _event(name: String, pos: Vector3, team: String) -> void:
	_events.append([name, pos, team])


func _pack_tick(frame: int) -> void:
	api.tick(frame)
	env["frozen"] = frozen
	env["rules"] = rules
	if rules.is_over():
		frozen = true
		env["frozen"] = true
		_hold_all()
		if ctx.input.just_pressed(&"restart"):
			_restart()
		_flush_events(frame)
		return

	var player: TLBiped = skaters["b0"]
	if brain != null:
		brain.think(frame, env)
	elif not frozen:
		for id: String in order:
			if id != "b0":
				skaters[id].move(Vector3.ZERO)
	if frozen:
		_hold_all()
	else:
		var v := Vector3(ctx.input.axis(&"left", &"right"), 0.0, ctx.input.axis(&"up", &"down"))
		if v.length() > 1.0:
			v = v.normalized()
		player.move(v)
		if ctx.input.just_pressed(&"shoot"):
			api.try_shoot("b0")
	for sid: String in api.events:
		_event("shot", (skaters[sid] as Node3D).global_position, str(teams[sid]))
	api.events.clear()

	# the pause after a goal, then the face-off
	if reset_in > 0:
		reset_in -= 1
		if reset_in == 0:
			_faceoff()
	# a goal: acted on last
	if _flag_goal != "":
		var side: String = _flag_goal
		_flag_goal = ""
		rules.add_score(side)
		_event("goal", puck.global_position, side)
		frozen = true
		_hold_all()
		if rules.is_over():
			result = "WIN" if rules.winner == "blue" else "LOSE"
			_event("win" if result == "WIN" else "lose", Vector3.ZERO, str(rules.winner))
		else:
			reset_in = int(round(float(tune["pause_s"]) * 60.0))
	env["frozen"] = frozen
	_flush_events(frame)


func _hold_all() -> void:
	for id: String in order:
		skaters[id].move(Vector3.ZERO)
		skaters[id].brake(true)


func _faceoff() -> void:
	puck.place(Vector3(0, 0.07, 0))
	for id: String in order:
		var sk: TLBiped = skaters[id]
		sk.brake(false)
		sk.place(spawns[id], _face_yaw(str(teams[id])))
	frozen = false
	_event("faceoff", Vector3.ZERO, "")


func _restart() -> void:
	rules.queue_free()
	hud.queue_free()
	_new_rules()
	result = ""
	reset_in = 0
	_flag_goal = ""
	for id: String in order:
		api.shots[id] = 0
	_faceoff()
	rules.start()
	env["rules"] = rules


func _flush_events(_frame: int) -> void:
	if fx != null:
		for e: Array in _events:
			fx.on_event(str(e[0]), e[1], str(e[2]))
		fx.tick(_frame, env)
	_events.clear()


func _r3(x: float) -> float:
	return snappedf(x, 0.001)


func _p2(v: Vector3) -> Array:
	return [_r3(v.x), _r3(v.z)]


func _pack_state() -> Dictionary:
	var s: Dictionary = rules.snapshot()
	s["player"] = "b0"
	s["puck"] = {"pos": _p2(puck.global_position), "vel": _p2(puck.linear_velocity)}
	var list: Array = []
	for id: String in order:
		var sk: TLBiped = skaters[id]
		var f: Vector3 = sk.forward()
		list.append({"id": id, "team": teams[id], "role": roles[id], "pos": _p2(sk.global_position), "vel": _p2(sk.velocity), "facing": _p2(f)})
	s["skaters"] = list
	s["shots"] = api.shots.duplicate()
	s["frozen"] = frozen
	s["shoot_ready"] = api.can_shoot("b0")
	s["goals"] = {"blue": [-26.0, 0.0], "red": [26.0, 0.0], "half_width": float(tune["goals"]["half_width"])}
	s["result"] = result
	return s
