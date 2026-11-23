extends RefCounted
## The game state for _pack_state() (moved out of main.gd on 21 Nov, its 600-line limit). g = main. Absent values are
## omitted. L5 (21 Nov): the goalies' saves and the fun layer's stop and replay counters are in it too.


func _r3(x: float) -> float:
	return snappedf(x, 0.001)


func _p2(v: Vector3) -> Array:
	return [_r3(v.x), _r3(v.z)]


func state(g) -> Dictionary:
	var s: Dictionary = g.rules.snapshot()
	s["mode"] = g.mode_id
	if g.menu_lib.open:
		s["menu"] = {"level": str(g.menu_lib.LEVELS[g.menu_lib.lv]), "mode": str(g.base_tune["modes"][g.menu_lib.md]), "idle": g.menu_lib.idle}
	s["body_radius"] = snappedf((g.skaters["b0"] as TLBiped).body_radius(), 0.001)
	s["game_line"] = g._game_line()
	if g.level_id != "none":
		s["level"] = g.level_id
	s["periods"] = g.rules.periods
	s["player"] = "b0"
	s["puck"] = {"pos": _p2(g.puck.global_position), "vel": _p2(g.puck.linear_velocity)}
	if g.api.carrier != "":
		s["puck"]["holder"] = g.api.carrier
	s["possession"] = g.api.state()
	var skating: Dictionary = g.skate.state()
	if not skating.is_empty():
		s["skate"] = skating
	s["hits"] = g.hits.state()
	var ct: Dictionary = g.hits.contact.state()
	if not ct.is_empty():
		s["contact"] = ct              # H1 build: the cross-check's strips at the press, the bounces
	s["reach"] = g.api.reach
	s["poke_reach"] = g.api.poke_reach
	s["autopilot"] = g.autopilot
	if g.brain != null and (g.drill_id == "" or g.drill_lib.ai) and not g.intro.active:
		s["roles_now"] = g.brain.roles_now.duplicate()
		if not g.autopilot and not g.frozen and g.api.carrier == "b0" and g.brain.caller != "":
			s["call"] = g.brain.caller
	if g.drill_id != "":
		s["drill"] = g.drill_id
	var dl: Dictionary = {"values": g.dials.duplicate(), "open": g.dial_open, "refused": g.dial_refused}
	var used: Dictionary = {}
	for p: int in g.dial_used:
		used[str(p)] = g.dial_used[p]
	if not used.is_empty():
		dl["used"] = used
	if g.dial_open:
		dl["selected"] = str(g.tune["dial"]["names"][g.dial_sel])
	s["dial"] = dl
	if g.rule_line != "":
		s["rule_line"] = g.rule_line
	var list: Array = []
	for id: String in g.order:
		var sk: TLBiped = g.skaters[id]
		var f: Vector3 = sk.forward()
		list.append({"id": id, "team": g.teams[id], "role": g.roles[id], "pos": _p2(sk.global_position), "vel": _p2(sk.velocity), "facing": _p2(f), "speed": _r3(sk.speed()), "turn_rate": _r3(sk.skate_turn_rate)})
	s["skaters"] = list
	s["shots"] = g.api.shots.duplicate()
	s["frozen"] = g.frozen
	s["shoot_ready"] = g.api.can_shoot("b0") and not g.api.shot_held
	s["pass_ready"] = g.api.carrier == "b0"
	s["poke_ready"] = g.api.can_poke("b0")
	s["check_ready"] = g.hits.can_check("b0")
	var gl: Dictionary = g.tune["goals"]
	s["goals"] = {"blue": [float(gl["blue"][0]), float(gl["blue"][2])], "red": [float(gl["red"][0]), float(gl["red"][2])], "half_width": float(gl["half_width"])}
	s["rink"] = {"half_length": float(g.tune["rink"]["half_length"]), "half_width": float(g.tune["rink"]["half_width"])}
	s["result"] = g.result
	if g.api.stick_dir.has("b0"):
		s["stick"] = _p2(g.api.stick_dir["b0"])       # H4: only while the aim is valid (absent: as before H4)
	if not g.keeper.ids.is_empty():
		s["saves"] = g.keeper.saves.duplicate()      # L5: the goalies' saves by the side that made them
	if g.crazy != null and g.crazy.on:
		s["crazy"] = g.crazy.state()                 # L5 crazy: only in a mode with pickups or abilities
	var fs: Dictionary = g.fun.state()
	if not fs.is_empty():
		s["fun"] = fs
	if g.intro.active:
		s["intro"] = {"step": g.intro.step, "ring": g.tune["intro"]["ring"], "steps": g.intro.steps}
	elif g.intro.ran:
		s["intro_end"] = "goal" if g.intro.netted else "skip"
	return s
