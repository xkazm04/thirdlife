extends Node
## The duel: one player against a ladder of three rivals (DUEL-PLAYBOOK 6.7: the Wall, the Duelist, the Dancer; then the
## same three at the champion tier), best of 3 rounds of 70 s, in a ring whose wall splats. Built by hand as the
## reference duel the editor copies (engine/cards/duel.json).
## Order inside a live frame: input -> the rival's mind -> (hit-stop holds: stop here) -> both fighters advance their
## counters -> both act from their buffers -> contacts (both fighters change) -> pushbox -> bodies move -> round checks.
## Helpers (no class_name): fighter.gd (state machine), contact.gd (matrix), brain.gd (AI), feel.gd (THE feel-kit
## adapter), show.gd (HUD, camera, juice), gen/arms.gd (weapons). Drills (data/drills.json) script the rival for the
## contact bots; a bot starts one by pressing its keyless action.

var ctx
var tune: Dictionary
var moves: Dictionary
var rivals: Dictionary
var drills: Dictionary = {}
var feel
var contact
var show
var brain
var lessons                            ## scripts/lessons.gd: the first minute teaches by play
var fighter_lib
var arms_lib = null
var you
var rival
var rival_pool: Dictionary = {}        ## rung -> fighter (bodies out of the tree when not fighting)
var match_rules: TLRules               ## rounds won: first to rules.score_to_win
var round_rules: TLRules               ## one round's clock
var wins: Dictionary = {"you": 0, "rival": 0}
var phase: String = "intro"            ## intro | fight | round_end | match_end
var phase_t: int = 0
var round_no: int = 1
var rung: int = 0
var crowd_level: float = 0.0
var drill: Dictionary = {}
var drill_t: int = 0
var drill_release: int = -1
var drill_wait: Array = []           ## rival actions of the drill waiting for a state that allows them
var lead: int = 0                      ## sign of the health lead (share of max): +1 you, -1 rival
var lead_changes: int = 0
var round_log: Array = []              ## [winner, reason, frames]
var match_log: Array = []
var hitstop_frames: int = 0
var fight_frames: int = 0
var first_minute: Dictionary = {}     ## the player's first 60 s of round 1: blocked, parried, punished, bashed, hit_landed, hit_taken
const SPOT_YOU := Vector3(0, 0.05, 2.5)
const SPOT_RIVAL := Vector3(0, 0.05, -2.5)


func _pack_setup(c) -> void:
	ctx = c
	tune = ctx.read_json("tuning.json")
	moves = ctx.read_json("moves.json")
	rivals = ctx.read_json("rivals.json")
	drills = ctx.read_json("drills.json")
	var built: Dictionary = TLKit.build_layout(ctx.read_json("venue.json"), ctx.root)
	if not built["ok"]:
		push_error("venue.json does not build: %s" % "; ".join(built["errors"]))
	feel = ctx.load_script("scripts/feel.gd").new()
	feel.setup(ctx)
	fighter_lib = ctx.load_script("scripts/fighter.gd")
	contact = ctx.load_script("scripts/contact.gd").new()
	contact.setup(self)
	if ctx.root.has_meta(&"duel_arms"):
		arms_lib = ctx.load_script(str(ctx.root.get_meta(&"duel_arms")))
	for a: Array in [[&"up", [KEY_W]], [&"down", [KEY_S]], [&"left", [KEY_A]], [&"right", [KEY_D]], [&"roll", [KEY_SHIFT]],
			[&"bash", [KEY_E]], [&"taunt", [KEY_Q]], [&"restart", [KEY_R]], [&"view", [KEY_V]], [&"next", [KEY_ENTER]]]:
		ctx.input.declare(a[0], a[1])
	ctx.input.declare(&"light", [KEY_J], [MOUSE_BUTTON_LEFT])
	ctx.input.declare(&"heavy", [KEY_K], [MOUSE_BUTTON_RIGHT])
	ctx.input.declare(&"block", [KEY_SPACE, KEY_L])
	for d: Dictionary in drills["drills"]:
		ctx.input.declare(StringName("drill_" + str(d["id"])), [])
	for i in range(6):
		ctx.input.declare(StringName("rung_%d" % i), [])
	var pcfg: Dictionary = tune["player"]
	you = _make_fighter("you", pcfg, SPOT_YOU, PI * 0.0)
	rung = clampi(int(tune["rival"]), 0, 5)
	rival = _rival_for(rung)
	_pair()
	feel.join(you)
	feel.join(rival)
	brain = ctx.load_script("scripts/brain.gd").new()
	match_rules = TLRules.create(tune["rules"])
	ctx.root.add_child(match_rules)
	show = ctx.load_script("scripts/show.gd").new()
	show.setup(self)
	lessons = ctx.load_script("scripts/lessons.gd").new()
	lessons.setup(self)
	feel.fade_occluders(you, rival)
	_new_brain()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for f in rival_pool.values():
			if is_instance_valid(f.body) and not f.body.is_inside_tree():
				f.body.free()


func _make_fighter(fid: String, conf: Dictionary, at: Vector3, facing: float):
	var sc: float = float(conf.get("scale", 1.0))
	var body: TLBiped = TLBiped.create({"position": at, "facing": facing, "name": "Fighter_" + fid, "body_scale": sc,
		"rig_params": {"colors": conf["colors"], "prop": "none", "headgear": "none", "backpack": false, "scale": sc, "expression": "focus"}})
	body.turn_rate = 0.0
	body.accel = float(tune["move"]["accel"])
	body.get_up_frames = int(moves["getup"]["frames"])
	ctx.root.add_child(body)
	var f = fighter_lib.new()
	f.setup(ctx, fid, body, conf, moves, tune, feel)
	f.facing = facing
	if arms_lib != null and body.rig != null:
		for k: String in conf.get("arms", []):
			var arm: Node3D = arms_lib.attach(body.rig, k)
			if arm != null and f.tip == null and arm.has_node("Tip"):
				f.tip = arm.get_node("Tip")
	return f


## Rung 0..2: the three rivals at their own tier; 3..5: the same three at the champion tier.
func _rival_for(r: int):
	if rival_pool.has(r):
		var f = rival_pool[r]
		if not f.body.is_inside_tree():
			ctx.root.add_child(f.body)
		return f
	var key: String = str(rivals["ladder"][r % 3])
	var conf: Dictionary = (rivals["rivals"][key] as Dictionary).duplicate(true)
	conf["key"] = key
	conf["tier_id"] = "champion" if r >= 3 else str(conf["tier"])
	var f2 = _make_fighter("rival", conf, SPOT_RIVAL, PI)
	rival_pool[r] = f2
	return f2


func _pair() -> void:
	you.foe = rival
	rival.foe = you


func _new_brain() -> void:
	brain.setup(self, rival, you, rival.cfg, rivals["tiers"][str(rival.cfg["tier_id"])])


func rung_name() -> String:
	return "%s%s" % [rival.name, "  (CHAMPION)" if rung >= 3 else ""]


func _pack_start() -> void:
	match_rules.start()
	_start_round()


func _start_round() -> void:
	if round_rules != null:
		ctx.root.remove_child(round_rules)
		round_rules.queue_free()
	round_rules = TLRules.create({"sides": tune["rules"]["sides"], "time_limit_seconds": int(tune["rounds"]["seconds"])})
	ctx.root.add_child(round_rules)
	for f in [you, rival]:
		feel.clear(f)
		f.reset_round()
		f.body.place(SPOT_YOU if f == you else SPOT_RIVAL, 0.0 if f == you else PI)
		f.facing = 0.0 if f == you else PI
	brain.reset_round()
	if lessons != null:
		lessons.start()
	lead = 0
	phase = "intro"
	phase_t = 0
	show.snap_camera()
	show.banner("ROUND %d" % round_no if round_no > 1 or rung > 0 else "%s\n%s" % [rival.name, str(rival.cfg.get("line", ""))], int(tune["rounds"]["intro_frames"]))


func _pack_tick(frame: int) -> void:
	_meta_input()
	phase_t += 1
	match phase:
		"intro":
			_idle_bodies()
			if phase_t >= int(tune["rounds"]["intro_frames"]):
				phase = "fight"
				phase_t = 0
				round_rules.start()
				show.banner("FIGHT!", 30)
		"fight":
			_fight(frame)
		"round_end":
			if not feel.holding(you, rival):
				_idle_bodies(true)
			if phase_t >= int(tune["rounds"]["end_frames"]):
				_after_round()
		"match_end":
			_idle_bodies(true)
	show.tick()


func _meta_input() -> void:
	var inp = ctx.input
	if inp.just_pressed(&"view"):
		show.next_view()
	if inp.just_pressed(&"restart") or (phase == "match_end" and inp.just_pressed(&"next")):
		var advance: bool = phase == "match_end" and match_rules.winner == "you" and inp.just_pressed(&"next")
		_restart_match(mini(rung + 1, 5) if advance else rung)
	for i in range(6):
		if inp.just_pressed(StringName("rung_%d" % i)):
			_restart_match(i)
	for d: Dictionary in drills["drills"]:
		if inp.just_pressed(StringName("drill_" + str(d["id"]))):
			_start_drill(d)


func _restart_match(r: int) -> void:
	if r != rung:
		feel.clear(rival)
		feel.leave(rival)
		if rival.body.is_inside_tree():
			ctx.root.remove_child(rival.body)
		rung = r
		rival = _rival_for(r)
		_pair()
		feel.join(rival)
		feel.fade_occluders(you, rival)
		_new_brain()
	wins = {"you": 0, "rival": 0}
	ctx.root.remove_child(match_rules)
	match_rules.queue_free()
	match_rules = TLRules.create(tune["rules"])
	ctx.root.add_child(match_rules)
	match_rules.start()
	round_no = 1
	round_log = []
	first_minute = {}
	lead_changes = 0
	drill = {}
	_start_round()


## A drill: both fighters placed, the rival's mind off, its moves from the drill's script (the contact bots).
func _start_drill(d: Dictionary) -> void:
	if d.has("rung") and int(d["rung"]) != rung:
		_restart_match(int(d["rung"]))
	_start_round()
	drill = d
	lessons.stop()
	drill_wait = []
	show.banner("", 1)
	if d.has("view"):
		show.view_i = maxi(0, show.views.find(StringName(d["view"])))
		ctx.cameras.activate(show.views[show.view_i])
	drill_t = 0
	drill_release = -1
	phase = "fight"
	round_rules.start()
	for side: String in ["you", "rival"]:
		var f = you if side == "you" else rival
		var p: Array = d[side]
		f.body.place(Vector3(float(p[0]), 0.05, float(p[1])), float(p[2]))
		f.facing = float(p[2])
	var rs: Dictionary = d.get("rival_set", {})
	for k: String in rs:
		match k:
			"stamina":
				rival.stamina = float(rs[k])
			"posture":
				rival.posture = float(rs[k])
			"exhausted":
				rival.exhausted = bool(rs[k])
			_:
				push_error("drills.json: drill %s has the unknown rival_set key %s" % [d["id"], k])


func _drill_rival() -> void:
	drill_t += 1
	rival.walk = Vector2.ZERO
	if drill_t == drill_release:
		rival.block_held = false
	for s: Array in drill.get("script", []):
		if int(s[0]) == drill_t:
			drill_wait.append(s)
	for i in range(drill_wait.size() - 1, -1, -1):
		var s: Array = drill_wait[i]
		if drill_t - int(s[0]) > 40:
			drill_wait.remove_at(i)
			continue
		var act: String = str(s[1])
		var opts: Dictionary = (s[2] as Dictionary).duplicate() if s.size() > 2 else {}
		if act == "hold_block":
			rival.block_held = true
			rival.press("block")
		elif act == "release":
			rival.block_held = false
		elif act == "block_tap":
			rival.block_held = true
			rival.press("block")
			drill_release = drill_t + 9
		elif act == "dodge_side":
			if not rival.act("dodge", {"dir": Vector3(-rival.to_foe().z, 0, rival.to_foe().x)}):
				continue
		elif not rival.act(act, opts):
			continue
		drill_wait.remove_at(i)


func _read_player() -> void:
	var inp = ctx.input
	you.walk = Vector2(inp.axis(&"left", &"right"), inp.axis(&"down", &"up"))
	you.block_held = inp.pressed(&"block")
	you.heavy_held = inp.pressed(&"heavy")
	if inp.just_pressed(&"block"):
		you.press("block")
	for a: StringName in [&"light", &"heavy", &"bash", &"taunt"]:
		if inp.just_pressed(a):
			you.press(String(a))
	if inp.just_pressed(&"roll"):
		var fwd: Vector3 = you.to_foe()
		var right := Vector3(-fwd.z, 0.0, fwd.x)
		var dir: Vector3 = right * you.walk.x + fwd * you.walk.y
		you.roll_dir = dir.normalized() if dir.length() > 0.2 else -fwd
		you.press("roll")


func _fight(frame: int) -> void:
	_read_player()
	contact.watch_walls(you, rival)
	if feel.holding(you, rival):        # the hit-stop holds every counter of ours too: wind-ups, buffers, the rival's mind
		hitstop_frames += 1
		return
	if drill.is_empty():
		brain.tick(frame)
	else:
		_drill_rival()
	fight_frames += 1
	you.advance(frame)
	rival.advance(frame)
	you.try_act()
	rival.try_act()
	contact.decide(you, rival)
	feel.pushbox(you, rival)
	you.drive()
	rival.drive()
	_drain_events()
	_track_lead()
	_round_checks()


func _drain_events() -> void:
	for f in [you, rival]:
		for e: Array in f.events:
			show.on_event(f, e)
		f.events = []


## What the player did in the first 60 s of the match (round 1): the learning curve a person meets (plays-twice 5, 10).
func first_minute_note(kind: String, att, def, d0: String) -> void:
	if round_no != 1 or round_rules == null or round_rules.total_frames > 3600 or not drill.is_empty():
		return
	var k: String = ""
	if def == you and kind.find("block") >= 0:
		k = "blocked"
	elif def == you and kind.find("parried") >= 0:
		k = "parried"
	elif att == you and d0 in ["REBOUND", "PARRIED", "GUARDBROKEN", "WALLSPLAT", "STAGGER", "BROKEN", "TAUNT", "TELL"]:
		k = "punished"
	elif att == you and kind.begins_with("bash"):
		k = "bashed"
	elif def == you and (kind.begins_with("hit") or kind == "ko" or kind == "knockdown"):
		k = "hit_taken"
	elif att == you and (kind.begins_with("hit") or kind == "ko"):
		k = "hit_landed"
	if k != "":
		first_minute[k] = int(first_minute.get(k, 0)) + 1


func crowd(_f, why: String) -> void:
	crowd_level = minf(12.0, crowd_level + float(tune["crowd"].get(why, 1)))


func _track_lead() -> void:
	var d: float = you.hp / you.hp_max - rival.hp / rival.hp_max
	var s: int = 1 if d > 0.04 else (-1 if d < -0.04 else 0)
	if s != 0 and lead != 0 and s != lead:
		lead_changes += 1
	if s != 0:
		lead = s
	crowd_level = maxf(0.0, crowd_level - 0.004)


func _round_checks() -> void:
	var winner: String = ""
	var reason: String = ""
	if rival.st == "KO":
		winner = "you"
		reason = "ko"
	elif you.st == "KO":
		winner = "rival"
		reason = "ko"
	elif round_rules.is_over():
		var d: float = you.hp / you.hp_max - rival.hp / rival.hp_max
		winner = "you" if d > 0.0 else ("rival" if d < 0.0 else "")
		reason = "time"
	if reason == "":
		return
	round_rules.finish(winner, reason)
	round_log.append([winner, reason, round_rules.total_frames, snappedf(you.hp, 0.1), snappedf(rival.hp, 0.1)])
	if winner != "":
		wins[winner] = int(wins[winner]) + 1
		match_rules.add_score(winner)
	phase = "round_end"
	phase_t = 0
	if reason == "time":
		show.banner("TIME - %s" % ("ROUND TO YOU" if winner == "you" else ("ROUND TO %s" % rival.name if winner != "" else "DRAW")), 120)
	elif winner == "you":
		show.banner("K.O.  ROUND TO YOU", 120)
	else:
		show.banner("K.O.  ROUND TO %s" % rival.name, 120)
	TLAudio.play(&"cheer" if winner == "you" else &"horn")
	if not drill.is_empty():
		drill = {}


func _after_round() -> void:
	if match_rules.is_over() or round_no >= int(tune["rounds"]["max_rounds"]):
		phase = "match_end"
		phase_t = 0
		if not match_rules.is_over():
			match_rules.finish(match_rules.leader(), "rounds")
		match_log.append([rung, match_rules.winner, wins.duplicate(), round_log.duplicate()])
		var won: bool = match_rules.winner == "you"
		show.banner(("YOU BEAT %s" % rival.name if won else "%s WINS" % rival.name) + "\n%s   R: again" % ("ENTER: next rival" if won and rung < 5 else ""), 100000)
		return
	round_no += 1
	_start_round()


## Outside a live fight the bodies stand (or lie) still, and nobody's counters run.
func _idle_bodies(winner_cheers: bool = false) -> void:
	for f in [you, rival]:
		f.walk = Vector2.ZERO
		f.block_held = false
		if winner_cheers and f.slide_i < f.slide_n:
			f.drive()                       # a knockout's slide and fall play out
			continue
		f.body.move(Vector3.ZERO)
		f.body.velocity.x = 0.0
		f.body.velocity.z = 0.0
		if winner_cheers and phase_t == 30 and f.st != "KO" and f.rig != null and round_log.size() > 0 and str(round_log[-1][0]) == f.id:
			f.rig.play(&"taunt" if f.id == "rival" else &"cheer")
			f.anim_clip = &""


func _pack_state() -> Dictionary:
	return {"phase": phase, "phase_t": phase_t, "round": round_no, "rung": rung, "rival_key": str(rival.cfg.get("key", "")),
		"wins": wins.duplicate(), "match": match_rules.snapshot(), "winner": match_rules.winner, "you": you.snapshot(), "rival": rival.snapshot(),
		"clock": round_rules.clock_text() if round_rules != null else "", "round_frames": round_rules.total_frames if round_rules != null else 0,
		"kinds": contact.kinds.duplicate(), "failures": contact.failures, "log": contact.log.duplicate(true),
		"drill": str(drill.get("id", "")), "stops": feel.stops, "lead_changes": lead_changes, "crowd": snappedf(crowd_level, 0.01),
		"rounds": round_log.duplicate(true), "matches": match_log.size(), "rival_passive_max": brain.passive_max, "rival_passive_note": brain.passive_note,
		"rival_tells_min": brain.tells_min, "rival_attacks": brain.attacks, "rival_strings": brain.strings_used.duplicate(), "rival_mind": brain.choices.duplicate(),
		"you_counts": you.counts.duplicate(), "rival_counts": rival.counts.duplicate(), "pushbox_gap": snappedf(feel.pushbox_gap(you, rival), 0.001), "first_minute": first_minute.duplicate(), "lessons": lessons.snapshot() if lessons != null else {}}
