extends Node
## game.ice_hockey_three_against, hockey_core: rink, puck, skaters, rules, HUD.
## Venue: data/venue.json (kit rink + goals). Tuning: data/tuning.json. Handlers only set flags; _pack_tick acts last.
## H1: possession (scripts/rink_api.gd): a puck in a skater's reach is his; he carries, shoots (Space), passes (Q),
## pokes (E), sprints (Shift). Drills (data/drills.json) are set starts a test calls by declared actions with no key.
## H2: body check (F; held while standing = brace) and cross-check (C) in scripts/hits.gd.
## H3: modes are data (data/modes/<id>.json, chosen by the `mode` param or a keyless action mode_<id>); the match has
## periods (TLRules), and once a period the player may open the rule dial (T: pause; A/D choose, W/S move one step).
## L1: what the player reads from the play camera is scripts/look.gd and data/tuning.json "look" and "camera": the puck's
## drawn size and rim, his ring and the carrier's, the keys' lines, GOAL, play again, the scoreboards. Drawing only.

var ctx
var base_tune: Dictionary              # data/tuning.json as read
var tune: Dictionary                   # base_tune with the mode's overrides
var ai_base: Dictionary                # data/ai.json, for validating a mode's "ai" keys
var modes: Dictionary = {}             # id -> mode file (validated)
var mode_id: String = "base"
var modes_lib                          # scripts/modes.gd
var drill_lib                          # scripts/drills.gd
var dial_lib                           # scripts/dial.gd
var look                               # scripts/look.gd (L1)
var arena: Node3D                      # the match's own nodes (goal volumes, rules, HUD): rebuilt by every _build
var venues: Dictionary = {}            # layout text -> its built rink and goals; out of the tree when not in use
var dress_node: Node3D                 # stands, masts, signs (gen/art_hook): built once at setup
var venue_key: String = "-"
var pool: Dictionary = {}              # id -> TLBiped made so far; a mode uses some, the rest wait out of the tree
var rules: TLRules
var hud: TLHud
var puck: TLBall
var api
var hits                               # scripts/hits.gd (H2)
var brain = null
var fx = null
var chase_cam = null
var skaters: Dictionary = {}           # id -> TLBiped
var order: Array = []                  # ids in roster order
var teams: Dictionary = {}
var roles: Dictionary = {}
var spawns: Dictionary = {}
var env: Dictionary = {}
var goal_pos: Dictionary = {}
var frozen: bool = false
var reset_in: int = 0                  # frames left of the pause after a goal
var result: String = ""
var _flag_goal: String = ""            # side that scored, set by a goal trigger
var _events: Array = []                # [name, pos, team] for the fx hook
var drills: Dictionary = {}
var drill_id: String = ""              # the drill running ("" = a match)
var drill_t0: int = 0
var drill_moves: Dictionary = {}       # id -> Vector3 intent for a drill's scripted skaters
var drill_script: Array = []           # [frames_after, id, act]
var drill_brace: Array = []            # ids that brace in a drill
var autopilot: bool = false            # the brain plays b0 too (a bot-only play)
var dials: Dictionary = {}             # dial name -> steps (both teams)
var dial_open: bool = false
var dial_sel: int = 0
var dial_used: Dictionary = {}         # period -> the change made in it
var dial_refused: int = 0
var rule_line: String = ""
var levels: Dictionary = {}            # H5: id -> level file (validated); "none" = no level (as before H5)
var level_id: String = "none"
var stick_heading: Vector3 = Vector3.ZERO   # H4: the human's stick, turning toward the aim at a turn rate
const DRILL_KEYS: Array = ["id", "place", "random_place", "move", "random_move", "puck", "puck_vel", "carrier", "script", "ai", "brace"]



func _pack_setup(c) -> void:
	ctx = c
	base_tune = ctx.read_json("tuning.json")
	modes_lib = ctx.load_script("scripts/modes.gd").new()
	drill_lib = ctx.load_script("scripts/drills.gd").new()
	dial_lib = ctx.load_script("scripts/dial.gd").new()
	look = ctx.load_script("scripts/look.gd").new()
	look.cfg = base_tune["look"]
	ai_base = ctx.read_json("ai.json")
	drills = ctx.read_json("drills.json")
	for d: Dictionary in drills["drills"]:
		for k: String in d.keys():
			if not DRILL_KEYS.has(k):
				push_error("drills.json: drill '%s' has the unknown key '%s'" % [str(d.get("id", "?")), k])
	for mid: String in base_tune["modes"]:
		var file: String = "modes/%s.json" % mid
		var m: Variant = ctx.read_json(file)
		if not (m is Dictionary):
			push_error("data/%s: the mode file is missing or not an object" % file)
			continue
		var errs: Array = modes_lib.check(m, mid, base_tune, ai_base)
		for e: String in errs:
			push_error("data/%s: %s" % [file, e])
		if errs.is_empty():
			modes[mid] = m
	for lid: String in base_tune["levels"]:
		if lid == "none":
			continue
		var lf: String = "levels/%s.json" % lid
		var lv: Variant = ctx.read_json(lf)
		var lerrs: Array = modes_lib.check_level(lv, lid, ai_base) if lv is Dictionary else ["the level file is missing or not an object"]
		for e: String in lerrs:
			push_error("data/%s: %s" % [lf, e])
		if lerrs.is_empty():
			levels[lid] = lv
	var lvl_list: Array = base_tune["levels"]
	var lpick: String = str(lvl_list[clampi(int(base_tune["level"]), 0, lvl_list.size() - 1)])
	level_id = lpick if levels.has(lpick) else "none"
	var list: Array = base_tune["modes"]
	var pick: int = clampi(int(base_tune["mode"]), 0, list.size() - 1)
	mode_id = str(list[pick]) if modes.has(str(list[pick])) else "base"

	for a: Array in [[&"up", KEY_W], [&"down", KEY_S], [&"left", KEY_A], [&"right", KEY_D], [&"poke", KEY_E], [&"sprint", KEY_SHIFT],
			[&"dial", KEY_T], [&"restart", KEY_R]]:
		ctx.input.declare(a[0], [a[1]])
	# H7: the mouse as the jam's game had it. With the puck: left shoots, right passes; without: left cross-checks, right
	# body-checks. Each verb is one action with its key AND its button; a button is two actions, and only the verb that
	# fits his possession acts. Both actions of a button go down on the same frame, so a button held while the puck
	# changes hands is never a new press: nothing happens until it is released and pressed again (tests/bot_buttons.gd).
	ctx.input.declare(&"shoot", [KEY_SPACE], [MOUSE_BUTTON_LEFT])
	ctx.input.declare(&"cross", [KEY_C], [MOUSE_BUTTON_LEFT])
	ctx.input.declare(&"pass", [KEY_Q], [MOUSE_BUTTON_RIGHT])
	ctx.input.declare(&"check", [KEY_F], [MOUSE_BUTTON_RIGHT])
	ctx.input.declare(&"autopilot", [])
	var am: Dictionary = base_tune["aim"]
	ctx.input.declare_aim(&"aim", float(am["height"]), float(am["reach"]))
	for d: Dictionary in drills["drills"]:
		ctx.input.declare(StringName("drill_" + str(d["id"])), [])
	for mid: String in base_tune["modes"]:
		ctx.input.declare(StringName("mode_" + mid), [])
	for lid: String in base_tune["levels"]:
		ctx.input.declare(StringName("level_" + lid), [])
	if ctx.root.has_meta(&"hockey_ai"):
		brain = ctx.load_script(str(ctx.root.get_meta(&"hockey_ai"))).new()
		brain.setup(ctx, env)
	if ctx.root.has_meta(&"hockey_fx"):
		fx = ctx.load_script(str(ctx.root.get_meta(&"hockey_fx"))).new()
		fx.setup(ctx, env)
	_build(mode_id)


## Builds the match of a mode from nothing: venue, puck, skaters, goal volumes, rules, HUD, the helpers.
func _build(mid: String) -> void:
	# a rebuild runs inside one tick (a mode change, R): only what changed is made again, so it stays far under the
	# runner's 250 ms tick limit (the whole arena rebuilt in a tick took 254 ms of processor time)
	if arena != null:
		ctx.root.remove_child(arena)
		arena.queue_free()
	mode_id = mid
	var m: Dictionary = modes[mid]
	tune = modes_lib.merged(m, base_tune)
	arena = Node3D.new()
	arena.name = "Arena"
	ctx.root.add_child(arena)
	skaters = {}
	order = []
	teams = {}
	roles = {}
	spawns = {}
	frozen = false
	reset_in = 0
	result = ""
	_flag_goal = ""
	drill_id = ""
	dials = {}
	for n: String in tune["dial"]["names"]:
		dials[n] = 0
	dial_open = false
	dial_sel = 0
	dial_used = {}
	dial_refused = 0
	rule_line = ""                         # H7: the mode is named by the game line; this line is the dial's

	var layout: Dictionary = ctx.read_json("venue.json")
	var g: Dictionary = tune["goals"]
	var ven: Dictionary = m.get("venue", {})
	for p: Dictionary in layout["props"]:
		if str(p["id"]) == "rink":
			for k: String in ["length", "width", "corner_r", "apron"]:
				if ven.has(k):
					p["params"][k] = ven[k]
		elif str(p["id"]) == "goal_blue":
			p["p"] = [float(g["blue"][0]), 0.05, 0.0]
		elif str(p["id"]) == "goal_red":
			p["p"] = [float(g["red"][0]), 0.05, 0.0]
	# venues are kept once built (a switch back is a re-parent, not a rebuild); the dress (stands, masts) is built at
	# setup whatever the first mode, so no tick ever builds it (big ice -> base rebuilt it in a tick: 254 ms)
	var key: String = JSON.stringify(layout)
	if not venues.has(key):
		var vn: Node3D = Node3D.new()
		vn.name = "Venue%d" % venues.size()
		var built: Dictionary = TLKit.build_layout(layout, vn)
		if not built["ok"]:
			push_error("venue.json does not build: %s" % "; ".join(built["errors"]))
			return
		venues[key] = vn
	if dress_node == null and ctx.root.has_meta(&"hockey_dress"):
		dress_node = Node3D.new()
		dress_node.name = "Dress"
		var dressed: Dictionary = TLKit.build_layout(ctx.read_json(str(ctx.root.get_meta(&"hockey_dress"))), dress_node)
		if not dressed["ok"]:
			push_error("dress layout does not build: %s" % "; ".join(dressed["errors"]))
	for k: String in venues:
		var vn2: Node3D = venues[k]
		if k != key and vn2.is_inside_tree():
			ctx.root.remove_child(vn2)
	if not (venues[key] as Node3D).is_inside_tree():
		ctx.root.add_child(venues[key])
	venue_key = key
	if dress_node != null:
		var want: bool = bool(ven.get("dress", true))
		if want and not dress_node.is_inside_tree():
			ctx.root.add_child(dress_node)
		elif not want and dress_node.is_inside_tree():
			ctx.root.remove_child(dress_node)

	if puck == null:
		var pk: Dictionary = tune["puck"]
		var part: Node3D = TLKit.build("puck", {"radius": float(pk.get("radius", 0.12)), "height": float(pk.get("height", 0.08))})
		puck = TLBall.create({"part": part, "planar": true, "color": Color(0.02, 0.02, 0.03), "group": "pucks", "max_speed": float(pk["max_speed"]),
			"drag": float(pk["drag"]), "position": Vector3(0, 0.07, 0), "name": "Puck"})
		ctx.root.add_child(puck)
		look.dress_puck(self, part, puck)
		puck.bounced.connect(_on_puck_bounced)
	if puck.holder() != null:
		puck.release()
	puck.place(Vector3(0, 0.07, 0))
	for pid: String in pool:
		var old: TLBiped = pool[pid]
		if old.is_inside_tree():
			ctx.root.remove_child(old)       # every pooled skater lives directly under ctx.root

	var opts: Dictionary = (tune["skater"] as Dictionary).duplicate()
	for entry: Dictionary in tune["roster"]:
		var id: String = str(entry["id"])
		var team: String = str(entry["team"])
		var sp: Array = entry["spawn"]
		var at := Vector3(float(sp[0]), 0.1, float(sp[1]))
		var pid: String = id + ":" + team
		if not pool.has(pid):
			var o: Dictionary = opts.duplicate()
			o.merge({"mode": "skate", "position": at, "facing": _face_yaw(team), "name": "skater_" + id,
				"rig_params": {"colors": {"top": "car_blue" if team == "blue" else "car_red", "trim": "car_blue" if team == "blue" else "car_red", "legs": "car_blue" if team == "blue" else "car_red"}}})
			var made: TLBiped = TLBiped.create(o)
			if made.rig != null:
				var bs: float = float(opts["body_scale"])
				made.rig.scale = Vector3(bs, bs, bs)      # H7: the body is the figure's size too (create option body_scale)
			pool[pid] = made
		var sk: TLBiped = pool[pid]
		ctx.root.add_child(sk)
		sk.skate_accel = float(opts["skate_accel"])
		sk.skate_turn_rate = float(opts["skate_turn_rate"])
		sk.body_mass = float(opts["body_mass"])
		sk.brake(false)
		sk.place(at, _face_yaw(team))
		skaters[id] = sk
		order.append(id)
		teams[id] = team
		roles[id] = str(entry["role"])
		spawns[id] = at
	goal_pos = {"blue": _v3(g["blue"]), "red": _v3(g["red"])}

	# goal volumes just behind each line, inside the nets; the trigger decides "the whole puck crossed"
	for side: String in ["blue", "red"]:
		var gx: float = float(g[side][0])
		var trig: TLTrigger = TLBodies.trigger(&"box", Vector3(1.5, 1.0, float(g["half_width"]) * 2.0),
			{"position": Vector3(gx + signf(gx) * 0.75, 0.3, 0.0), "group_filter": "pucks", "name": "goal_trigger_" + side})
		arena.add_child(trig)
		trig.entered.connect(_on_goal.bind(side))

	api = ctx.load_script("scripts/rink_api.gd").new()
	api.setup(tune, puck, skaters, teams, order)
	hits = ctx.load_script("scripts/hits.gd").new()
	hits.setup(tune, api, skaters, teams, order)
	hits.enabled = bool(m.get("checks", true))
	api.hits = hits
	api.poke_cone_dot = cos(deg_to_rad(float(tune["aim"]["poke_cone_deg"])))
	stick_heading = Vector3.ZERO
	_new_rules()
	look.setup(self)

	var cam: Dictionary = tune["camera"]
	if ctx.cameras.has_view(&"arena"):
		var v: Camera3D = ctx.cameras.view(&"arena")
		v.global_position = _v3(cam["pos"])
		v.look_at(_v3(cam["target"]), Vector3.UP)
	else:
		ctx.cameras.add_view(&"arena", _v3(cam["pos"]), _v3(cam["target"]), float(cam["fov"]))
	ctx.cameras.set_subject(&"arena", skaters["b0"])
	var cc: Dictionary = tune["chase_camera"]
	if chase_cam == null:
		chase_cam = ctx.cameras.chase(skaters["b0"], {"distance": float(cc["distance"]), "height": float(cc["height"]), "look_height": float(cc["look_height"]), "fov": float(cc["fov"])})        # the view "chase": stills of the hand
	else:
		chase_cam.target = skaters["b0"]
	ctx.cameras.activate(&"arena")

	env.merge({"puck": puck, "skaters": skaters, "teams": teams, "roles": roles, "spawns": spawns, "goals": goal_pos,
		"frozen": false, "api": api, "hits": hits, "tuning": tune, "rules": rules, "autopilot": autopilot, "drill": false}, true)
	if brain != null:
		brain.override(m.get("ai", {}))
		brain.red_over = (levels[level_id]["ai"] as Dictionary).duplicate() if levels.has(level_id) else {}
	dial_lib.apply(self)


func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Heading (radians about y) that makes a skater face the opponent's goal: blue +x, red -x.
func _face_yaw(team: String) -> float:
	return -PI * 0.5 if team == "blue" else PI * 0.5


func _new_rules() -> void:
	rules = TLRules.create(tune["rules"])
	arena.add_child(rules)
	hud = TLHud.create()
	arena.add_child(hud)
	hud.add_score(rules, "blue", &"top_left", "BLUE")
	hud.add_score(rules, "red", &"top_right", "RED")
	hud.add_clock(rules, &"top")
	look.hud_lines(self)
	hud.add_bound(&"rule", func() -> String: return rule_line, &"top")
	hud.add_bound(&"game", _game_line, &"bottom_left")
	hud.add_bound(&"dial", func() -> String: return dial_lib.text(self), &"right")


## H6: which game this is, on screen from the first frame: the level and the mode in one line.
func _game_line() -> String:
	var lv: String = str(levels[level_id]["label"]) if levels.has(level_id) else str(base_tune["look"]["level_none"])
	return "Level: %s | Mode: %s" % [lv, str(modes[mode_id].get("label", mode_id))]


func _pack_start() -> void:
	_start_match()


func _start_match() -> void:
	rules.start()
	var j: float = float(tune["faceoff_jitter"])
	puck.place(Vector3(ctx.rng.randf_range(-j, j), 0.07, ctx.rng.randf_range(-j, j)))
	_event("faceoff", Vector3.ZERO, "")


func _on_puck_bounced(other: Node, speed: float) -> void:
	if speed >= 6.0 and not (other is TLBiped):
		_event("board", puck.global_position, "")


## H11: the side that scores when the puck's centre lies in a goal volume (the trigger's box: 1.5 m deep behind the line,
## the goal's width), else "".
func _goal_by_position() -> String:
	var p: Vector3 = puck.global_position
	var g: Dictionary = tune["goals"]
	for side: String in ["blue", "red"]:
		var gx: float = float(g[side][0])
		if absf(p.x - (gx + signf(gx) * 0.75)) <= 0.75 and absf(p.z) <= float(g["half_width"]):
			return "red" if side == "blue" else "blue"
	return ""


func _on_goal(body: Node3D, side: String) -> void:
	if body == puck and puck.holder() == null and _flag_goal == "" and reset_in <= 0 and not frozen and rules.is_running():
		_flag_goal = "red" if side == "blue" else "blue"


func _event(name: String, pos: Vector3, team: String) -> void:
	_events.append([name, pos, team])


func _pack_tick(frame: int) -> void:
	for mid: String in modes:
		if ctx.input.just_pressed(StringName("mode_" + mid)):
			_build(mid)
			_start_match()
			_flush_events(frame)
			return
	for lid: String in base_tune["levels"]:
		if ctx.input.just_pressed(StringName("level_" + lid)):
			level_id = lid if levels.has(lid) else "none"
			if brain != null:
				brain.red_over = (levels[level_id]["ai"] as Dictionary).duplicate() if levels.has(level_id) else {}
	api.tick(frame)
	hits.tick(frame)
	if not autopilot and ctx.input.pressed(&"check"):
		hits.braced["b0"] = true      # holding F braces him (standing still: he holds a hit from the side)
	if ctx.input.just_pressed(&"autopilot"):
		autopilot = not autopilot
	for d: Dictionary in drills["drills"]:
		if ctx.input.just_pressed(StringName("drill_" + str(d["id"]))):
			drill_lib.start(self, d, frame)
	env["autopilot"] = autopilot
	env["drill"] = drill_id != ""
	env["rules"] = rules
	if rules.is_over():
		if result == "":
			# H9a: a match that ends at full time (or by the time limit) has a result too: the HUD said nothing before
			result = "WIN" if rules.winner == "blue" else ("LOSE" if rules.winner != "" else "DRAW")
			_event("win" if result == "WIN" else "lose", Vector3.ZERO, str(rules.winner))
		frozen = true
		env["frozen"] = true
		_hold_all()
		if ctx.input.just_pressed(&"restart"):
			_restart()
		_flush_events(frame)
		return
	if dial_lib.tick(self):
		env["frozen"] = true
		_hold_all()
		_flush_events(frame)
		return
	var stopped: bool = frozen or not rules.is_running()     # after a goal, between periods
	env["frozen"] = stopped

	var player: TLBiped = skaters["b0"]
	if not stopped:
		api.update_possession()
	if drill_id != "":
		drill_lib.tick(self, frame)
	elif brain != null:
		brain.think(frame, env)
	elif not stopped:
		for id: String in order:
			if id != "b0":
				skaters[id].move(Vector3.ZERO)
	if stopped:
		_hold_all()
	elif not autopilot:
		var v := Vector3(ctx.input.axis(&"left", &"right"), 0.0, ctx.input.axis(&"up", &"down"))
		if v.length() > 1.0:
			v = v.normalized()
		player.brake(false)
		player.move(v)
		_aim_stick()
		api.sprinting["b0"] = ctx.input.pressed(&"sprint")
		if ctx.input.just_pressed(&"shoot"):
			api.try_shoot("b0")
		if ctx.input.just_pressed(&"pass"):
			api.try_pass("b0")
		if ctx.input.just_pressed(&"poke"):
			api.try_poke("b0")
		if ctx.input.just_pressed(&"check"):
			hits.try_check("b0")
		if ctx.input.just_pressed(&"cross"):
			hits.try_cross("b0")
	if not stopped:
		hits.enforce()
		for id: String in order:
			if drill_id == "" and (id != "b0" or autopilot):
				(skaters[id] as TLBiped).brake(hits.is_down(id))
	api.apply_speeds()
	for e: Array in api.events:
		if str(e[0]) == "shot":
			_event("shot", (skaters[str(e[1])] as Node3D).global_position, str(teams[str(e[1])]))
	api.events.clear()
	for e: Array in hits.events:
		_event("hit_" + str(e[0]), (skaters[str(e[2])] as Node3D).global_position, str(teams[str(e[1])]))
	hits.events.clear()

	# the pause after a goal, then the face-off
	if reset_in > 0:
		reset_in -= 1
		if reset_in == 0:
			_faceoff()
	# H11: a puck inside a goal volume counts however it got there (carried in on the blade, released there, lying
	# loose; into his own net it is an own goal): its position is read each live tick, not only the trigger's enter event
	if _flag_goal == "" and reset_in <= 0 and not frozen and rules.is_running():
		_flag_goal = _goal_by_position()
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
	_flush_events(frame)


## H4: the stick follows the aim. Valid aim off the figure: the stick heading turns toward it at most
## stick_turn_deg_per_frame; on the figure (TLInput.AIM_DEAD): held; invalid: none, and every stick action uses his
## facing exactly as before H4. The rig has no upper-body or stick yaw (only the head's look_at): the head looks at
## the aim, the body keeps skating where W A S D send it.
func _aim_stick() -> void:
	var player: TLBiped = skaters["b0"]
	var at: Vector3 = player.global_position
	if not ctx.input.aim_valid(&"aim"):
		stick_heading = Vector3.ZERO
		api.stick_dir.erase("b0")
		if player.rig != null:
			player.rig.set_param(&"look_at", null)
		return
	var fwd: Vector3 = api.fwd_of("b0")
	if stick_heading == Vector3.ZERO:
		stick_heading = fwd
	var want: Vector3 = ctx.input.aim_direction(&"aim", at, Vector3.ZERO)
	if want != Vector3.ZERO:
		var turn: float = deg_to_rad(float(tune["aim"]["stick_turn_deg_per_frame"]))
		var ang: float = stick_heading.signed_angle_to(want, Vector3.UP)
		stick_heading = stick_heading.rotated(Vector3.UP, clampf(ang, -turn, turn)).normalized()
	api.stick_dir["b0"] = stick_heading
	if player.rig != null:
		player.rig.set_param(&"look_at", ctx.input.aim(&"aim") + Vector3(0, 1.0, 0))


func _hold_all() -> void:
	for id: String in order:
		skaters[id].move(Vector3.ZERO)
		skaters[id].brake(true)


func _faceoff() -> void:
	api.reset()
	hits.reset()
	var j: float = float(tune["faceoff_jitter"])
	puck.place(Vector3(ctx.rng.randf_range(-j, j), 0.07, ctx.rng.randf_range(-j, j)))
	for id: String in order:
		var sk: TLBiped = skaters[id]
		sk.brake(false)
		sk.place(spawns[id], _face_yaw(str(teams[id])))
	frozen = false
	_event("faceoff", Vector3.ZERO, "")


func _restart() -> void:
	_build(mode_id)
	_start_match()


func _flush_events(_frame: int) -> void:
	if fx != null:
		for e: Array in _events:
			fx.on_event(str(e[0]), e[1], str(e[2]))
		fx.tick(_frame, env)
	_events.clear()
	look.tick(self)


func _r3(x: float) -> float:
	return snappedf(x, 0.001)


func _p2(v: Vector3) -> Array:
	return [_r3(v.x), _r3(v.z)]


func _pack_state() -> Dictionary:
	var s: Dictionary = rules.snapshot()
	s["mode"] = mode_id
	s["body_radius"] = snappedf((skaters["b0"] as TLBiped).body_radius(), 0.001)
	s["game_line"] = _game_line()
	if level_id != "none":
		s["level"] = level_id
	s["periods"] = rules.periods
	s["player"] = "b0"
	s["puck"] = {"pos": _p2(puck.global_position), "vel": _p2(puck.linear_velocity)}
	if api.carrier != "":
		s["puck"]["holder"] = api.carrier
	s["possession"] = api.state()
	s["hits"] = hits.state()
	s["reach"] = api.reach
	s["poke_reach"] = api.poke_reach
	s["autopilot"] = autopilot
	if drill_id != "":
		s["drill"] = drill_id
	var dl: Dictionary = {"values": dials.duplicate(), "open": dial_open, "refused": dial_refused}
	var used: Dictionary = {}
	for p: int in dial_used:
		used[str(p)] = dial_used[p]
	if not used.is_empty():
		dl["used"] = used
	if dial_open:
		dl["selected"] = str(tune["dial"]["names"][dial_sel])
	s["dial"] = dl
	if rule_line != "":
		s["rule_line"] = rule_line
	var list: Array = []
	for id: String in order:
		var sk: TLBiped = skaters[id]
		var f: Vector3 = sk.forward()
		list.append({"id": id, "team": teams[id], "role": roles[id], "pos": _p2(sk.global_position), "vel": _p2(sk.velocity), "facing": _p2(f), "speed": _r3(sk.speed())})
	s["skaters"] = list
	s["shots"] = api.shots.duplicate()
	s["frozen"] = frozen
	s["shoot_ready"] = api.can_shoot("b0")
	s["pass_ready"] = api.carrier == "b0"
	s["poke_ready"] = api.can_poke("b0")
	s["check_ready"] = hits.can_check("b0")
	var g: Dictionary = tune["goals"]
	s["goals"] = {"blue": [float(g["blue"][0]), float(g["blue"][2])], "red": [float(g["red"][0]), float(g["red"][2])], "half_width": float(g["half_width"])}
	s["rink"] = {"half_length": float(tune["rink"]["half_length"]), "half_width": float(tune["rink"]["half_width"])}
	s["result"] = result
	if api.stick_dir.has("b0"):
		s["stick"] = _p2(api.stick_dir["b0"])       # H4: only while the aim is valid (absent: as before H4)
	return s
