extends RefCounted
## The rival's mind (DUEL-PLAYBOOK 6.6). It plays through the same door as the player (fighter.press / act, the walk
## intent, the block hold): no hidden advantage, so whatever it does a person could do.
##   Eyes: it sees only what a person sees (the player's animation: state, move, frame of it), `react` frames late.
##   DEFEND: once per player attack it may answer (`defend` share), in its archetype's way: block, parry (only a move it
##     has seen `parry_seen` times this round, or the 3rd hit of a string), roll, dodge, or an interrupting light.
##   PUNISH: an opening it can see (parried, rebound, guard broken, splatted, staggered, a whiff, a taunt) gets the
##     biggest attack that fits in it; after its own block or parry it counters (guard counter, riposte).
##   PRESS: a string from its repertoire, never the same one three times running; with `read` share the ender is
##     swapped for the counter to the player's commonest answer of the last 8 (block -> bash, parry -> feint into bash,
##     roll -> delayed heavy, nothing -> heavy). Every string ends in a RETURN window of `return` frames, open.
##   SPACING: circles at its threat range + 0.3 m; RESET backs off when tired or after being parried.
## Randomness: ctx.rng only (seeded).

const VULN: Array = ["PARRIED", "REBOUND", "GUARDBROKEN", "WALLSPLAT", "STAGGER", "BROKEN", "PARRY_WHIFF", "TAUNT", "TELL"]

var g
var me                                 ## the rival fighter
var you                                ## the player fighter
var cfg: Dictionary = {}
var tier: Dictionary = {}
var react: int = 30
var hist: Array = []                   ## the player's visible snapshots, newest last
var plan: Array = []                   ## steps of the string in progress
var plan_id: String = ""
var step_wait: int = -1
var last_ids: Array = []
var return_left: int = 0
var reset_left: int = 0
var press_wait: int = 40
var strafe: float = 1.0
var strafe_left: int = 0
var decided: int = -1                  ## the player's attack serial already answered
var decided_chain: int = -1            ## the player's light whose chain was read
var defence: String = ""
var act_at: int = -1                   ## frame of the defence's press
var block_until: int = -1
var release_at: int = -1
var seen_moves: Dictionary = {}        ## the player's attacks seen this round (parry_seen)
var responses: Array = []              ## the player's answers to the rival's last 8 attacks
var log_seen: int = 0
var guard_walk: bool = false
var guard_left: int = 0
var blocks_row: int = 0
var punish_left: int = 0
var counter_next: String = ""
var last_action: int = 0               ## frame the rival last started something (metrics: never idle > 2 s)
var passive_max: int = 0
var passive_note: String = ""         ## where the longest idle ended (for tuning)
var tells_min: int = 1000              ## the shortest wind-up of a dangerous rival attack (>= 12: plays-twice item 11)
var frame: int = 0
var fled_at: int = -1000
var force_string: String = ""
var phase2_on: bool = false            ## the second phase was announced (rivals.json phase2)
var attacks: int = 0
var strings_used: Dictionary = {}
var attack_frames: Array = []          ## the frames the rival started an attack (pressure waves)
var choices: Dictionary = {}           ## what the mind chose, counted (defences, reads, punishes): the bots read it


func setup(main, rival, player, conf: Dictionary, t: Dictionary) -> void:
	g = main
	me = rival
	you = player
	cfg = conf
	tier = t
	react = int(t["react"])
	reset_round()


func reset_round() -> void:
	hist = []
	plan = []
	plan_id = ""
	step_wait = -1
	return_left = 0
	reset_left = 0
	press_wait = 50
	decided = -1
	defence = ""
	act_at = -1
	block_until = -1
	release_at = -1
	seen_moves = {}
	phase2_on = false
	force_string = ""
	guard_walk = false
	guard_left = 0
	blocks_row = 0
	punish_left = 0
	counter_next = ""
	last_action = -1
	log_seen = g.contact.log.size() if g.contact != null else 0


func _rand() -> float:
	return g.ctx.rng.randf()


## The player as the rival saw him `react` frames ago.
func _seen() -> Dictionary:
	if hist.is_empty():
		return {}
	return hist[maxi(0, hist.size() - 1 - react)]


func tick(f: int) -> void:
	frame = f
	if last_action < 0:
		last_action = f
	var s: Dictionary = you.snapshot()
	s["whiffed"] = you.whiffed
	hist.append(s)
	if hist.size() > react + 2:
		hist.pop_front()
	_read_log()
	if g.lessons != null and g.lessons.tick(f):
		return                                           # the first minute: a lesson drives him (scripts/lessons.gd)
	if me.walk.y > 0.5 and me.dist() > 2.0:
		last_action = f                                  # last frame it was closing in: pressure, not idling
	me.walk = Vector2.ZERO
	me.heavy_held = false
	if me.st == "KO" or you.st == "KO":
		me.block_held = false
		return
	if me.stunned() and me.st != "BLOCKSTUN":
		last_action = f                                  # being hit is not idling
		_on_stun()
		return
	if me.st in ["WINDUP", "ACTIVE", "RECOVERY", "ROLL", "DODGE", "TELL", "TAUNT", "PARRY_WHIFF", "PARRY_OK", "BLOCK", "BLOCKSTUN"]:
		last_action = f
	elif f - last_action > passive_max:
		passive_max = f - last_action
		passive_note = "f%d %s ret%d reset%d plan%d def%s d%.1f st%.0f" % [f, me.st, return_left, reset_left, plan.size(), defence, me.dist(), me.stamina]
	var p: Dictionary = _seen()
	if p.is_empty():
		return
	_read_chain(p)
	_defend(p)
	if _defence_running():
		return
	if me.st == "BLOCKSTUN" or me.st == "PARRY_OK":
		_queue_counter()
		return
	if _punish(p):
		return
	if str(p["state"]) == "WINDUP" and str(p["mv"]) in ["heavy", "charged"] and me.dist() < 3.2 and me.st != "WINDUP":
		me.walk = Vector2(strafe, -0.6)                   # a heavy is coming: no light into its armour; step out of it
		last_action = f
		return
	if not plan.is_empty():
		_run_plan()
		return
	if return_left > 0:
		return_left -= 1
		me.block_held = false
		if cfg.get("taunt_after", "") == plan_id and return_left == int(tier["return"]) - 6:
			_do("taunt", {})
		return
	if reset_left > 0:
		reset_left -= 1
		me.walk = Vector2(strafe * 0.4, -1.0)
		me.block_held = guard_walk
		return
	if cfg.has("phase2") and not phase2_on and me.hp < me.hp_max * float(cfg["phase2"]["below"]) and me.can_act():
		if not bool(cfg["phase2"].get("roar", true)):
			phase2_on = true                             # (the pre-round-3 behaviour: phase 2 slips in unannounced)
			return
		phase2_on = true                                 # the boss's second phase is announced, not slipped in (a roar)
		plan = []
		_do("taunt", {})
		force_string = str(cfg["phase2"]["strings"][0]["id"])   # and its signature string comes first
		me.events.append(["phase2", str(cfg["phase2"].get("cue", ""))])
		return
	if me.stamina < float(cfg.get("flee_stamina", 30)) and me.can_act() and f - fled_at > 150:
		fled_at = f
		_start_reset()
		if cfg.has("flee_stamina") and me.dist() < 3.5:
			reset_left = 18                              # she rolls out and comes back at once (a dash from range)
			_do("roll", {"dir": -me.to_foe()})
		return
	_space()


func _on_stun() -> void:
	me.block_held = false
	plan = []
	return_left = 0
	if me.st == "PARRIED":
		reset_left = 0
		counter_next = ""


## The player's answers to the rival's attacks, read from the contact log.
func _read_log() -> void:
	var lg: Array = g.contact.log
	if log_seen > lg.size():
		log_seen = 0
	for i in range(log_seen, lg.size()):
		var e: Dictionary = lg[i]
		if e["by"] == me.id:
			var k: String = str(e["type"])
			var r: String = "hit"
			if k.find("block") >= 0:
				r = "block"
			elif k.find("parried") >= 0:
				r = "parry"
				_start_reset()
			elif k == "evade":
				r = "roll"
			responses.append(r)
			if responses.size() > 8:
				responses.pop_front()
		elif e["by"] == you.id and str(e["type"]).find("block") >= 0:
			blocks_row += 1
		elif e["by"] == you.id:
			blocks_row = 0
	log_seen = lg.size()


## DEFEND: one decision per player attack, from what was seen.
func _defend(p: Dictionary) -> void:
	if defence == "parry" and act_at > frame:
		return                                           # a read parry is already timed
	if str(p["state"]) != "WINDUP" or int(p["serial"]) == decided or str(p["mv"]) == "":
		return
	decided = int(p["serial"])
	var mv: String = str(p["mv"])
	seen_moves[mv] = int(seen_moves.get(mv, 0)) + 1
	var left: int = int(p["windup"]) - int(p["mf"]) - react      # frames until his blade is live, now
	if _rand() >= float(tier["defend"]):
		return
	var reach: float = float(you.moves[mv]["reach"]) + float(you.moves[mv]["lunge"]) + 0.15
	if bool(cfg.get("punish_whiffs", false)) and me.dist() > reach and mv != "bash" and me.dist() < reach + 2.6:
		# he swings out of range: walk in and strike his recovery (a whiff read, not a reaction)
		defence = "whiff_punish"
		_note("whiff_read")
		act_at = frame + maxi(0, left + int(you.moves[mv]["active"]) + 4 - int(me.moves["light"]["windup"]))
		plan = []
		return
	var w: Dictionary = cfg["defence"]
	var opts: Array = []
	var third: bool = bool(cfg.get("parry_third", false)) and int(p["chain"]) >= 2
	if mv != "bash" and (int(seen_moves[mv]) >= int(cfg["parry_seen"]) or third) and left >= 3:
		opts.append(["parry", float(w["parry"]) * (4.0 if third else 1.0)])
	if mv != "charged" and left >= 1:
		opts.append(["block", float(w["block"]) * (0.3 if third else 1.0)])
	if left >= 2 and left <= 18:
		opts.append(["roll", float(w["roll"]) * (2.0 if mv == "heavy" and bool(cfg.get("roll_through_heavy", false)) else 1.0)])
		opts.append(["dodge", float(w["dodge"])])
	if left >= int(me.moves["light"]["windup"]) + 2 and me.dist() <= float(me.moves["light"]["reach"]) + 0.3:
		opts.append(["interrupt", float(w["interrupt"]) + (0.5 if mv == "charged" else 0.0)])
	var pick: String = _weighted(opts)
	if pick == "":
		return
	defence = pick
	_note("defend_" + pick)
	plan = []
	match pick:
		"block":
			act_at = frame
			block_until = frame + left + int(you.moves[mv]["active"]) + 6
		"parry":
			act_at = frame + maxi(0, left - 5)
			block_until = act_at + 9
		"roll", "dodge":
			act_at = frame + maxi(0, left - (6 if pick == "roll" else 4))
		"interrupt":
			act_at = frame


## A light is faster than a reaction (18 frames against 22): a chain is READ, not seen. While the player strings lights the
## rival keeps its guard up; the Duelist times a parry for the hit that would come next after the second (the third),
## so a player who stops, delays or feints makes it whiff (the Duelist's weakness, 6.7).
func _read_chain(p: Dictionary) -> void:
	if defence == "parry" or str(p["mv"]) != "light" or not (str(p["state"]) in ["WINDUP", "ACTIVE", "RECOVERY"]):
		return
	if int(p["serial"]) == decided_chain or me.dist() > 3.0:
		return
	decided_chain = int(p["serial"])
	if _rand() >= float(tier["defend"]):
		return
	var third: bool = bool(cfg.get("parry_third", false)) and int(p["chain"]) >= 1
	var lm: Dictionary = you.moves["light"]
	var to_end: int = int(p["len"]) - int(p["t"])
	if str(p["state"]) == "WINDUP":
		to_end = int(p["windup"]) - int(p["mf"]) + int(lm["active"]) + int(lm["recovery"])
	elif str(p["state"]) == "ACTIVE":
		to_end = int(lm["active"]) - int(p["t"]) + int(lm["recovery"])
	var next_active: int = to_end - 4 + int(you.moves["light"]["chain_windup"]) - react
	_note("chain_seen" if not third else "third_seen")
	if third and next_active >= 3:
		_note("read_parry")
		defence = "parry"
		act_at = frame + maxi(0, next_active - 6)
		block_until = act_at + 9
	elif float(cfg["defence"]["dodge"]) + float(cfg["defence"]["roll"]) > float(cfg["defence"]["block"]) and next_active >= 4:
		_note("read_dodge")                              # the Dancer side-steps the next hit of the chain
		defence = "dodge"
		act_at = frame + maxi(0, next_active - 5)
	elif float(cfg["defence"]["block"]) > 0.2:
		_note("read_block")
		defence = "block"
		act_at = frame
		block_until = frame + maxi(8, next_active + int(you.moves["light"]["active"]) + 4)


func _defence_running() -> bool:
	if defence == "":
		if me.st == "BLOCK" and not guard_walk and block_until < frame:
			me.block_held = false
		return false
	if frame < act_at:
		me.block_held = guard_walk and defence != "parry"
		return true
	match defence:
		"block":
			me.block_held = true
			if frame == act_at and me.st != "BLOCK":
				me.press("block")
			if frame >= block_until:
				defence = ""
				me.block_held = guard_walk
		"parry":
			if frame == act_at:
				me.block_held = true
				me.press("block")
			if frame >= block_until or me.st == "PARRY_OK":
				me.block_held = false
				defence = ""
		"roll", "dodge":
			var side: Vector3 = Vector3(-me.to_foe().z, 0.0, me.to_foe().x) * (1.0 if _rand() < 0.5 else -1.0)
			if _do(defence, {"dir": side if defence == "dodge" else (-me.to_foe() + side).normalized()}) or frame > act_at + 8:
				defence = ""
		"whiff_punish":
			if _do("light", {"dash": maxf(0.0, me.dist() - float(me.moves["light"]["reach"]) - float(me.moves["light"]["lunge"]) + 0.3)}) or frame > act_at + 6:
				defence = ""
		"interrupt":
			if _do("light", {}) or frame > act_at + 4:
				defence = ""
	return defence != ""


## After its own block or parry: the guard counter / riposte, pressed as the stun ends.
func _queue_counter() -> void:
	if counter_next != "":
		return
	if me.st == "PARRY_OK":
		counter_next = str(cfg.get("riposte", "light"))
	elif cfg.has("guard_counter") and you.st in ["REBOUND", "RECOVERY"]:
		counter_next = str(cfg["guard_counter"])
	if counter_next != "":
		me.press(counter_next)
		attacks += 1
		last_action = frame
		counter_next = ""


## PUNISH an opening it can see: the biggest attack that lands before it closes.
func _punish(p: Dictionary) -> bool:
	if not me.can_act():
		return false
	var st: String = str(p["state"])
	var open: bool = st in VULN or (st == "RECOVERY" and bool(p.get("whiffed", false))) or (st == "GETUP" and int(p["t"]) > 18)
	if not open:
		if bool(cfg.get("guard_counter", "") != "") and blocks_row >= int(cfg.get("taunt_after_blocks", 99)):
			blocks_row = 0
			_do("taunt", {})
			return true
		return false
	var left: int = int(p["len"]) - int(p["t"]) - react
	if st == "RECOVERY":
		left = int(p["len"]) - int(p["t"]) - react
	var reach: float = float(me.moves["light"]["reach"]) + float(me.moves["light"]["lunge"])
	if me.dist() > reach + 1.2:
		return false
	if me.dist() > reach:
		me.walk = Vector2(0.0, 1.0)
		return true
	var hw: int = int(me.moves["heavy"]["windup"])
	var lw: int = int(me.moves["light"]["windup"])
	if st == "BROKEN" or left >= hw + 2:
		_do("heavy", {})
	elif left >= lw - 2:
		_do("light", {})
	else:
		return false
	plan = []
	return_left = 0
	return true


func _start_reset() -> void:
	reset_left = 24 + int(_rand() * 24.0)
	plan = []


## SPACING and PRESS.
func _space() -> void:
	var d: float = me.dist()
	var want: float = float(cfg["space"])
	strafe_left -= 1
	if strafe_left <= 0:
		strafe = -strafe if _rand() < 0.6 else strafe
		strafe_left = 40 + int(_rand() * 50.0)
	guard_left -= 1
	if guard_left <= 0:
		guard_walk = _rand() < float(cfg.get("guard_up", 0.0))
		guard_left = 50 + int(_rand() * 60.0)
	me.block_held = guard_walk
	if guard_walk and me.st != "BLOCK" and me.can_act():
		me.press("block")
	var fwd: float = clampf((d - want) * 1.5, -1.0, 1.0)
	me.walk = Vector2(strafe * 0.7, fwd)
	press_wait -= 1
	if press_wait <= 0 and d <= want + 2.5 and me.can_act():          # a string closes in by itself (_run_plan)
		_pick_string()


func _pick_string() -> void:
	var pool: Array = cfg["strings"]
	if phase2_on:
		pool = pool + cfg["phase2"]["strings"]
	var opts: Array = []
	for s: Dictionary in pool:
		var id: String = str(s["id"])
		if last_ids.size() >= 2 and last_ids[-1] == id and last_ids[-2] == id:
			continue                                     # never the same string three times running
		opts.append([id, float(s["weight"])])
	var pick: String = _weighted(opts)
	if force_string != "":
		pick = force_string
		force_string = ""
	for s: Dictionary in pool:
		if str(s["id"]) == pick:
			plan = (s["steps"] as Array).duplicate(true)
	plan_id = pick
	last_ids.append(pick)
	if last_ids.size() > 4:
		last_ids.pop_front()
	strings_used[pick] = int(strings_used.get(pick, 0)) + 1
	if plan.size() >= 1 and _rand() < float(tier["read"]):
		_swap_ender()
	step_wait = int(plan[0].get("delay", 0))
	me.block_held = false


## The read: the last step becomes the counter to what the player answered most of the last 8 times.
func _swap_ender() -> void:
	if responses.size() < 3:
		return
	var n: Dictionary = {}
	for r: String in responses:
		n[r] = int(n.get(r, 0)) + 1
	var top: String = ""
	for k: String in n:
		if top == "" or int(n[k]) > int(n[top]):
			top = k
	var ender: Array = []
	match top:
		"block":
			ender = [{"m": "bash"}]
		"parry":
			ender = [{"m": "heavy", "feint": 14}, {"m": "bash"}]
		"roll":
			ender = [{"m": "heavy", "hold": 18}]
		_:
			ender = [{"m": "heavy"}]
	plan.pop_back()
	plan.append_array(ender)
	plan_id += "+read_" + top


func _run_plan() -> void:
	if step_wait > 0:
		step_wait -= 1
		return
	var step: Dictionary = plan[0]
	var m: String = str(step["m"])
	if m in ["light", "heavy", "charged", "bash"] and me.dist() > float(me.moves[m]["reach"]) + float(me.moves[m]["lunge"]) + float(step.get("dash", 0.0)) + 0.4:
		me.walk = Vector2(0.0, 1.0)                         # close in first; the string waits
		last_action = frame                                 # closing in to strike is pressure, not idling
		if me.st == "IDLE" and me.dist() > 6.0:
			plan = []
		return
	var opts: Dictionary = {}
	for k: String in ["hold", "dash", "feint", "frames"]:
		if step.has(k):
			opts[k] = step[k]
	if m == "roll":
		opts["dir"] = (me.to_foe() + Vector3(-me.to_foe().z, 0.0, me.to_foe().x) * strafe).normalized()
	if _do(m, opts):
		plan.pop_front()
		if plan.is_empty():
			return_left = int(tier["return"])
			press_wait = int(tier["pace"][0]) + int(_rand() * float(int(tier["pace"][1]) - int(tier["pace"][0])))
		else:
			step_wait = int(plan[0].get("delay", 0))


func _do(m: String, opts: Dictionary) -> bool:
	if not me.can_act() and not (m == "light" and me.st == "RECOVERY"):
		return false
	if me.st == "BLOCK":
		me.block_held = false
	var ok: bool = me.act(m, opts)
	if ok:
		last_action = frame
		if m in ["light", "heavy", "charged", "bash"]:
			attacks += 1
			attack_frames.append(frame)
			var w: int = me.windup
			if m != "bash" or true:
				tells_min = mini(tells_min, w)
	return ok


func _weighted(opts: Array) -> String:
	var total: float = 0.0
	for o: Array in opts:
		total += maxf(0.0, float(o[1]))
	if total <= 0.0:
		return ""
	var r: float = _rand() * total
	for o: Array in opts:
		r -= maxf(0.0, float(o[1]))
		if r <= 0.0:
			return str(o[0])
	return str(opts[-1][0])


func _note(k: String) -> void:
	choices[k] = int(choices.get(k, 0)) + 1
