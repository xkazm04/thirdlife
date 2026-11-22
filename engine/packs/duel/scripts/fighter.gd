extends RefCounted
## One fighter: the state machine of DUEL-PLAYBOOK 6.4, counted in physics frames.
##   IDLE (walking) -> WINDUP -> ACTIVE -> RECOVERY -> IDLE, plus BLOCK (its first frames are the parry window), PARRY_WHIFF,
##   PARRY_OK, ROLL, DODGE, TAUNT, TELL, and the stuns HITSTUN, BLOCKSTUN, PARRIED, GUARDBROKEN, REBOUND, STAGGER,
##   WALLSPLAT, BROKEN, KNOCKDOWN -> GETUP, KO. HITSTOP is the frozen sub-state (feel.gd); EXHAUSTED is a flag.
## The player and the rival use the same door: press(action) into an 8-frame buffer, hold flags for block and heavy, a
## walk intent in the lock-on frame. Actions start only from IDLE, the last 4 frames of RECOVERY, BLOCK, and the end of a
## stun or get-up (the buffer fires on the frame the state ends). Contacts are decided in contact.gd.

const ATTACKS: Array = ["light", "heavy", "charged", "bash"]
const STUNS: Array = ["HITSTUN", "BLOCKSTUN", "PARRIED", "GUARDBROKEN", "REBOUND", "STAGGER", "WALLSPLAT", "BROKEN", "KNOCKDOWN", "GETUP", "KO"]

var id: String = ""
var name: String = ""
var body: TLBiped
var rig = null
var tip: Node3D = null                 ## the weapon's tip (gen/arms.gd): the swing trail follows it
var foe = null
var feel = null
var moves: Dictionary = {}             ## data/moves.json with this fighter's changes
var cfg: Dictionary = {}               ## hp, poise, walk, scale, block_stamina_k, parry_window, roll ...
var tune: Dictionary = {}              ## data/tuning.json
var radius: float = 0.3
var events: Array = []                 ## [name, data] for the show this frame (main drains it)

var st: String = "IDLE"
var t: int = 0
var length: int = 0
var mv: String = ""                    ## the attack in progress
var mf: int = 0                        ## frame of the attack (windup + active + recovery)
var windup: int = 0
var active: int = 0
var recovery: int = 0
var chain: int = 0                     ## lights in the current chain (0 = the first)
var serial: int = 0                    ## counts attacks started (the rival's eyes key on it)
var connected: bool = false
var whiffed: bool = false
var hold_extra: int = 0                ## a delayed heavy: frames held at the coil
var dash_m: float = 0.0
var feint_at: int = -1
var feint_into: String = ""
var flash_done: bool = false

var hp: float = 100.0
var hp_max: float = 100.0
var stamina: float = 100.0
var posture: float = 0.0
var exhausted: bool = false
var regen_wait: int = 0
var posture_wait: int = 0
var parry_from: int = 2
var parry_to: int = 13
var parry_shrink: int = 0
var last_block_press: int = -1000
var block_contact: bool = false
var frozen: bool = false

var buffer: String = ""
var buffer_age: int = 99
var walk: Vector2 = Vector2.ZERO       ## x right, y forward, in the lock-on frame (length 0..1)
var block_held: bool = false
var heavy_held: bool = false
var roll_dir: Vector3 = Vector3.ZERO
var facing: float = 0.0

var slide_dir: Vector3 = Vector3.ZERO
var slide_m: float = 0.0
var slide_n: int = 0
var slide_i: int = 0
var anim_clip: StringName = &""
var anim_map: Array = []
var anim_len: int = 0
var anim_t: int = 0

var stars: int = 0
var counts: Dictionary = {}            ## what this fighter did: attacks, hits, blocks, parries, whiffs, rolls ...
var frame_no: int = 0


func setup(c, fid: String, b: TLBiped, conf: Dictionary, base_moves: Dictionary, t_: Dictionary, f_) -> void:
	id = fid
	body = b
	rig = b.rig
	cfg = conf
	tune = t_
	feel = f_
	name = str(conf.get("name", fid.to_upper()))
	moves = base_moves.duplicate(true)
	var over: Dictionary = conf.get("moves", {})
	for k: String in over:
		for kk: String in (over[k] as Dictionary):
			moves[k][kk] = over[k][kk]
	if conf.has("roll"):
		for kk: String in (conf["roll"] as Dictionary):
			moves["roll"][kk] = conf["roll"][kk]
	if conf.has("dodge_stamina"):
		moves["dodge"]["stamina"] = conf["dodge_stamina"]
	var pw: Array = conf.get("parry_window", [moves["parry"]["from"], moves["parry"]["to"]])
	parry_from = int(pw[0])
	parry_to = int(pw[1])
	radius = 0.3 * float(conf.get("scale", 1.0))
	hp_max = float(conf["hp"])
	reset_round()
	var _c = c


func reset_round() -> void:
	hp = hp_max
	stamina = float(tune["stamina"]["max"])
	posture = 0.0
	exhausted = false
	regen_wait = 0
	posture_wait = 0
	buffer = ""
	buffer_age = 99
	block_held = false
	heavy_held = false
	slide_n = 0
	chain = 0
	mv = ""
	frozen = false
	_enter("IDLE", 0)
	if rig != null:
		rig.play(&"", 0.05)
	anim_clip = &""


## --- the door both sides use ---------------------------------------------------------------------------------------
func press(action: String) -> void:
	buffer = action
	buffer_age = 0
	if action == "block":
		_parry_press()


func vis() -> String:
	return "HITSTOP" if feel.stop_left(self) > 0 else st


func stunned() -> bool:
	return st in STUNS


func attacking() -> bool:
	return st in ["WINDUP", "ACTIVE"]


func can_act() -> bool:
	return st == "IDLE" or st == "BLOCK" or (st == "RECOVERY" and t >= length - 4)


func blocking() -> bool:
	return st == "BLOCK"


func parry_open() -> bool:
	return st == "BLOCK" and t >= parry_from and t <= parry_to - parry_shrink and not exhausted


func guard_up() -> bool:
	return st == "BLOCK" and (t >= int(moves["block"]["up"]) or parry_open())


func invulnerable() -> bool:
	if st == "ROLL":
		var r: Array = moves["roll"]["iframes"]
		return t >= int(r[0]) and t <= int(r[1])
	if st == "DODGE":
		var d: Array = moves["dodge"]["iframes"]
		return t >= int(d[0]) and t <= int(d[1])
	if st == "GETUP":
		var g: Array = moves["getup"]["iframes"]
		return t >= int(g[0]) and t <= int(g[1])
	return st == "KNOCKDOWN" or st == "KO"


## Counter-hit windows: a wind-up, the end of a roll or dodge, a tell, a taunt (the opening the rules punish).
func open_to_counter() -> bool:
	return st in ["WINDUP", "TELL", "TAUNT", "PARRY_WHIFF"] or ((st == "ROLL" or st == "DODGE") and not invulnerable())


func armoured() -> bool:
	if st != "WINDUP" and st != "ACTIVE":
		return false
	var a: Array = moves[mv].get("armour", [])
	return a.size() == 2 and mf >= int(a[0]) and mf <= int(a[1]) + hold_extra


func move_data() -> Dictionary:
	return moves[mv] if mv != "" else {}


func pos() -> Vector3:
	return body.position


func forward() -> Vector3:
	return Vector3(-sin(facing), 0.0, -cos(facing))


func to_foe() -> Vector3:
	var d: Vector3 = foe.pos() - pos()
	d.y = 0.0
	return d.normalized() if d.length() > 0.001 else forward()


func dist() -> float:
	var d: Vector3 = foe.pos() - pos()
	return Vector2(d.x, d.z).length()


## --- every live frame ----------------------------------------------------------------------------------------------
func advance(frame: int) -> void:
	frame_no = frame
	t += 1
	buffer_age += 1
	if buffer_age > int(tune["buffer"]):
		buffer = ""
	match st:
		"WINDUP":
			mf += 1
			_windup_frame()
		"ACTIVE":
			mf += 1
			if t >= active:
				if not connected:
					whiffed = true
					_count("whiffs")
					events.append(["whiff", mv])
					regen_wait = maxi(regen_wait, int(tune["stamina"]["wait_attack"]))
				_enter("RECOVERY", recovery)
		"RECOVERY":
			mf += 1
			if t >= length:
				chain = 0
				_enter("IDLE", 0)
		"BLOCK":
			# a tap keeps the parry window to its end (Sekiro's deflect); a tap that met nothing is a whiffed parry
			if not block_held and (t > parry_to - parry_shrink or block_contact):
				if t <= parry_to + 1 and not block_contact:
					stamina = maxf(0.0, stamina - float(moves["parry"]["whiff_stamina"]))
					_count("parry_whiffs")
					_enter("PARRY_WHIFF", int(moves["parry"]["whiff"]))
				else:
					_enter("IDLE", 0)
				rig.play(&"", 0.1)
				anim_clip = &""
		"KNOCKDOWN":
			if t >= length:
				_enter("GETUP", int(moves["getup"]["frames"]))
		"KO":
			pass
		"BROKEN":
			if t >= length:
				posture = 0.0
				_enter("IDLE", 0)
		_:
			if length > 0 and t >= length:
				_enter("IDLE", 0)
	_regen()


func _windup_frame() -> void:
	var m: Dictionary = moves[mv]
	if mv == "heavy" and feint_at >= 0 and mf >= feint_at:
		_feint(feint_into)
		return
	if mv == "heavy" and heavy_held and mf == int(m["charge_at"]) and id == "you":
		_become_charged()
		return
	if mv == "charged" and not flash_done and mf >= int(moves["heavy"]["charge_at"]):
		flash_done = true
		events.append(["charged_flash", mv])
	if mf >= windup:
		_enter("ACTIVE", active)
		connected = false


func _become_charged() -> void:
	var k: float = float(tune["stamina"]["windup_k"]) if exhausted else 1.0
	mv = "charged"
	windup = roundi(float(moves["charged"]["windup"]) * k)
	active = int(moves["charged"]["active"])
	recovery = int(moves["charged"]["recovery"])
	stamina = maxf(0.0, stamina - (float(moves["charged"]["stamina"]) - float(moves["heavy"]["stamina"])))
	flash_done = true
	events.append(["charged_flash", mv])
	feel.pose(self, StringName(moves["charged"]["clip"]), _scaled_anim(moves["charged"]["anim"], k), 0)
	anim_t = mf


func _feint(into: String) -> void:
	stamina = maxf(0.0, stamina - float(moves["heavy"]["feint_stamina"]))
	_count("feints")
	events.append(["feint", into])
	mv = ""
	feint_at = -1
	if into == "bash":
		_start_attack("bash")
	else:
		_enter("IDLE", 0)
		rig.play(&"", 0.08)


## The buffer turns into an action when the state allows one.
func try_act() -> void:
	if st == "WINDUP" and mv == "heavy" and mf <= int(moves["heavy"]["feint_until"]) and buffer_age == 0 and id == "you":
		if buffer == "block" or buffer == "bash":          # the player's feint: block cancels, bash feints into a bash
			var into: String = buffer
			buffer = ""
			_feint("bash" if into == "bash" else "")
			return
	if buffer != "" and can_act():
		var b: String = buffer
		var dir: Vector3 = roll_dir
		buffer = ""
		match b:
			"light", "heavy", "bash":
				_start_attack(b)
			"roll":
				_start_roll(dir)
			"taunt":
				_start_simple("TAUNT", int(moves["taunt"]["frames"]), &"taunt")
			"block":
				_start_block()
			"tell":
				_start_simple("TELL", int(cfg.get("tell_frames", 24)), StringName(moves["tell"]["clip"]))
				anim_map = moves["tell"]["anim"]
				events.append(["tell", ""])
		return
	if block_held and (st == "IDLE" or (st == "RECOVERY" and t >= length - 4)):
		_start_block(false)


func _start_attack(m: String, opts: Dictionary = {}) -> void:
	var data: Dictionary = moves[m]
	var chained: bool = m == "light" and mv == "light" and st == "RECOVERY" and chain + 1 < int(data["chain_max"])
	chain = chain + 1 if chained else 0
	var k: float = float(tune["stamina"]["windup_k"]) if exhausted else 1.0
	mv = m
	windup = roundi(float(data["chain_windup"] if chained else data["windup"]) * k)
	hold_extra = int(opts.get("hold", 0))
	windup += hold_extra
	active = int(data["active"])
	recovery = int(data["recovery"])
	dash_m = float(opts.get("dash", 0.0))
	feint_at = int(opts.get("feint", -1))
	feint_into = "bash" if feint_at >= 0 else ""
	flash_done = false
	whiffed = false
	connected = false
	mf = 0
	serial += 1
	var cost: float = float(data["chain_stamina"] if chained else data["stamina"])
	stamina = maxf(0.0, stamina - cost)
	regen_wait = maxi(regen_wait, int(tune["stamina"]["wait_attack"]) + windup + active)
	_count("attacks")
	_count(m)
	_enter("WINDUP", 0)
	var anim: Array = data["chain_anim"] if chained else data["anim"]
	feel.pose(self, StringName(data["clip"]), _scaled_anim(_held_anim(anim, hold_extra), k), 0)
	events.append(["windup", m])


## Rival strings call this to start a step with its options (delay, hold, dash, feint) when the state allows.
func act(m: String, opts: Dictionary = {}) -> bool:
	if not can_act():
		return false
	if m in ATTACKS:
		_start_attack(m, opts)
	elif m == "roll" or m == "dodge":
		_start_roll(opts.get("dir", -forward()), m == "dodge")
	elif m == "taunt":
		_start_simple("TAUNT", int(moves["taunt"]["frames"]), &"taunt")
	elif m == "tell":
		_start_simple("TELL", int(opts.get("frames", 24)), StringName(moves["tell"]["clip"]))
		anim_map = moves["tell"]["anim"]
		events.append(["tell", ""])
	return true


func _held_anim(anim: Array, extra: int) -> Array:
	if extra <= 0:
		return anim
	var out: Array = []
	var coil: float = float(anim[1][0])       # the coil peak: hold there
	for p: Array in anim:
		if float(p[0]) < coil:
			out.append(p)
		elif float(p[0]) == coil:
			out.append(p)
			out.append([coil + extra, p[1]])
		else:
			out.append([float(p[0]) + extra, p[1]])
	return out


static func _scaled_anim(anim: Array, k: float) -> Array:
	if k == 1.0:
		return anim
	var out: Array = []
	for p: Array in anim:
		out.append([float(p[0]) * k, p[1]])
	return out


func _start_roll(dir: Vector3, force_dodge: bool = false) -> void:
	var local := body.basis.inverse() * dir
	var side: bool = force_dodge or absf(local.x) > absf(local.z) * 1.2
	var key: String = "dodge" if side else "roll"
	var data: Dictionary = moves[key]
	stamina = maxf(0.0, stamina - float(data["stamina"]))
	regen_wait = maxi(regen_wait, int(tune["stamina"]["wait_dodge"]) + int(data["frames"]))
	var frames: int = int(data["frames"]) + (int(moves["roll"]["exhausted_extra"]) if exhausted and key == "roll" else 0)
	_count(key + "s")
	roll_dir = Vector3(dir.x, 0.0, dir.z).normalized() if dir.length() > 0.01 else -forward()
	_enter(key.to_upper(), frames)
	if key == "roll":
		facing = atan2(-roll_dir.x, -roll_dir.z)
		body.rotation.y = facing
	else:
		rig.set_param(&"dodge_side", 1 if local.x > 0.0 else -1)
	feel.pose(self, StringName(data["clip"]), data["anim"], frames)
	events.append([key, ""])


func _start_simple(state: String, frames: int, clip: StringName) -> void:
	_count(state.to_lower())
	_enter(state, frames)
	feel.pose(self, clip, [], frames)


## A fresh press opens the parry window (its first frames); a guard held on from a stun or a move does not: no parry,
## and no whiffed parry when it is let go.
func _start_block(fresh: bool = true) -> void:
	_enter("BLOCK", 0)
	if not fresh:
		t = parry_to + 2
	block_contact = false
	_count("blocks_raised")
	feel.pose(self, &"block", [], 0)


func _parry_press() -> void:
	if frame_no - last_block_press <= int(moves["parry"]["retap_frames"]):
		parry_shrink = mini(parry_shrink + int(moves["parry"]["retap_shrink"]), parry_to)
	else:
		parry_shrink = 0
	last_block_press = frame_no


func _enter(state: String, frames: int) -> void:
	st = state
	t = 0
	length = frames


func _count(k: String) -> void:
	counts[k] = int(counts.get(k, 0)) + 1


## Stuns and contact results land here (contact.gd). The state's pose comes from data/contacts.json "poses".
func stun(state: String, frames: int, ps: Dictionary = {}) -> void:
	mv = "" if state != "RECOVERY" else mv
	chain = 0
	block_held = block_held and state == "BLOCKSTUN"
	_enter(state, frames)
	if not ps.is_empty():
		feel.pose(self, StringName(ps["clip"]), ps["anim"], frames, float(ps["strength"]))


func lose_posture(amount: float) -> bool:
	posture = minf(float(tune["posture"]["max"]), posture + amount)
	posture_wait = int(tune["posture"]["wait"])
	return posture >= float(tune["posture"]["max"])


func spend_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	regen_wait = maxi(regen_wait, int(tune["stamina"]["wait_blocked"]))


func hurt(amount: float, can_kill: bool = true) -> void:
	hp = maxf(0.0 if can_kill else minf(hp, 1.0), hp - amount)


func _regen() -> void:
	var s: Dictionary = tune["stamina"]
	if stamina <= 0.0 and not exhausted:
		exhausted = true
		events.append(["exhausted", ""])
	if exhausted and stamina >= float(s["exhausted_until"]):
		exhausted = false
	if regen_wait > 0:
		regen_wait -= 1
	elif st == "BLOCK":
		stamina = minf(float(s["max"]), stamina + float(moves["block"]["stamina_regen"]))
	elif not attacking() and st != "ROLL" and st != "DODGE":
		var k: float = float(tune["rally"]["stamina_k"]) if rally() else 1.0
		stamina = minf(float(s["max"]), stamina + float(s["regen"]) * k)
	var p: Dictionary = tune["posture"]
	if posture_wait > 0:
		posture_wait -= 1
	elif st != "BROKEN" and posture > 0.0:
		posture = maxf(0.0, posture - float(p["regen"]) * (float(p["low_hp_k"]) if hp < hp_max * 0.5 else 1.0))


## The comeback rule, visible on the HUD: under 35 % of health a fighter's stamina comes back half as fast again.
func rally() -> bool:
	return hp > 0.0 and hp < hp_max * float(tune["rally"]["below"])


## --- moving the body (after contacts) ------------------------------------------------------------------------------
func drive() -> void:
	var m: Dictionary = tune["move"]
	var want: Vector3 = Vector3.ZERO
	var walk_speed: float = float(cfg["walk"])
	var fwd: Vector3 = to_foe()
	var right: Vector3 = Vector3(-fwd.z, 0.0, fwd.x)
	var intent: Vector3 = right * walk.x + fwd * walk.y
	var turn: float = float(m["turn"])
	match st:
		"IDLE":
			want = intent * walk_speed
		"BLOCK":
			want = intent * walk_speed * float(moves["block"]["walk_k"])
		"WINDUP":
			want = intent * walk_speed * float(m["windup_walk_k"]) + _lunge()
			turn = float(moves[mv]["tracking"])
		"ACTIVE":
			want = _lunge()
			turn = float(m["turn_active"])
		"RECOVERY":
			want = intent * walk_speed * float(m["recovery_walk_k"])
			turn = float(m["turn_recovery"])
		"ROLL", "DODGE":
			var data: Dictionary = moves[st.to_lower()]
			var n: float = float(data["anim"][1][0])
			if t <= n:
				want = roll_dir * float(data["distance"]) / (n / 60.0) * 2.0 * (1.0 - float(t) / n)
			turn = 0.0 if st == "ROLL" and t < int(data["anim"][1][0]) else (30.0 if st == "ROLL" else turn)   # out of a roll: square up at once
		"TAUNT", "TELL", "PARRY_OK", "PARRY_WHIFF":
			turn = 4.0
		_:
			turn = 0.0 if st in ["KNOCKDOWN", "KO", "GETUP"] else 2.0
	if slide_i < slide_n:
		var k: float = 2.0 * (1.0 - (float(slide_i) + 0.5) / float(slide_n)) / float(slide_n)
		want += slide_dir * slide_m * k * 60.0
		slide_i += 1
	if st in ["KNOCKDOWN", "KO"]:
		want = want * 0.5
	var target: float = atan2(-fwd.x, -fwd.z)
	facing = rotate_toward(facing, target, turn / 60.0)
	if st == "IDLE" and rig != null and (rig.clip == &"" or rig.clip == &"block_stun"):
		feel.stance(self)
	if feel.owns_body(self):                         # a kernel stun, push or fall moves him: no intent, no facing
		facing = body.rotation.y
		body.move(Vector3.ZERO)
		feel.run_pose(self)
		return
	if st != "KNOCKDOWN" and st != "KO" and st != "GETUP":
		body.rotation.y = facing
	else:
		facing = body.rotation.y
	body.walk_speed = maxf(want.length(), 0.01)
	body.move(want.normalized() if want.length() > 0.001 else Vector3.ZERO)
	body.velocity.x = want.x
	body.velocity.z = want.z
	feel.run_pose(self)


## The attack's lunge: its metres spread over the last 8 wind-up frames and the active frames; it stops at the foe.
func _lunge() -> Vector3:
	var m: Dictionary = moves[mv]
	var n: float = 8.0 + float(active)
	var start: int = windup - 8
	if mf < start or mf > windup + active:
		return Vector3.ZERO
	if dist() < (radius + foe.radius) * 2.25:           # stops at blade's length (1.35 m at scale 1): duellists, not wrestlers
		return Vector3.ZERO
	return forward() * (float(m["lunge"]) + dash_m) / (n / 60.0)


## What a person can see of this fighter (the rival's eyes, the HUD, the bots).
func snapshot() -> Dictionary:
	return {"st": vis(), "state": st, "t": t, "len": length, "mv": mv, "mf": mf, "windup": windup, "chain": chain,
		"serial": serial, "hp": snappedf(hp, 0.01), "hp_max": hp_max, "stamina": snappedf(stamina, 0.01),
		"posture": snappedf(posture, 0.01), "exhausted": exhausted, "rally": rally(), "armour": armoured(),
		"x": snappedf(pos().x, 0.001), "z": snappedf(pos().z, 0.001), "facing": snappedf(facing, 0.001), "stars": stars}
