extends RefCounted
## Contacts: the interaction matrix of DUEL-PLAYBOOK 6.5 and the results of 6.3. Every contact changes BOTH fighters:
## a hit-stop freezes both (feel.gd), then each takes its own result (the defender a stun by poise tier, a blockstun with
## pushback, a parry; the attacker its recovery, a recoil, a rebound, PARRIED). Each contact is logged with both
## fighters' states before and after it (the bots check that both changed).
##   decide(a, b): called once per live frame after both fighters advanced and acted.
## Geometry: an attack connects in its active frames when the foe's centre is within `reach` (scaled by both bodies)
## and inside `arc` degrees of the attacker's facing. A guard covers `block.arc` degrees of the defender's front.

var g                                  ## main.gd
var c: Dictionary = {}                 ## data/contacts.json
var log: Array = []                    ## the last 24 contacts: {f, type, by, a: [before, after], d: [before, after]}
var kinds: Dictionary = {}             ## contact type -> count
var failures: int = 0                  ## contacts that left a fighter's state unchanged (must stay 0)
var ring_inner: float = 8.35


func setup(main) -> void:
	g = main
	c = g.ctx.read_json("contacts.json")
	ring_inner = float(g.tune["ring"]["inner"])
	log = []
	kinds = {}
	failures = 0


func decide(a, b) -> void:
	var ha: bool = _reaches(a, b)
	var hb: bool = _reaches(b, a)
	if ha and hb:
		_trade(a, b)
	elif ha:
		_lead_clash(a, b)
	elif hb:
		_lead_clash(b, a)


## An attack in its active frames that would touch the foe this frame.
func _reaches(att, def) -> bool:
	if att.st != "ACTIVE" or att.connected:
		return false
	var m: Dictionary = att.move_data()
	var reach: float = float(m["reach"]) + (att.radius - 0.3) + (def.radius - 0.3)
	if att.dist() > reach:
		return false
	return att.forward().dot(att.to_foe()) >= cos(deg_to_rad(float(m["arc"]) * 0.5))


## Both attacks active and touching: the stronger class wins, equal classes clash.
func _trade(a, b) -> void:
	var ca: int = int(a.move_data()["class"])
	var cb: int = int(b.move_data()["class"])
	if a.mv == "bash" and b.mv == "bash":
		_land(a, b)                                     # shoulder into shoulder: the counter-bash
	elif ca == cb:
		_clash(a, b)
	elif ca > cb:
		_land(a, b)
	else:
		_land(b, a)


## One attack active; a foe a few frames from his own active frame of the same class clashes with it (two swings that
## meet, not an interruption). Otherwise the attack lands on whatever the foe is doing.
func _lead_clash(att, def) -> void:
	var lead: int = int(c["clash"]["lead"])
	if att.mv != "bash" and def.st == "WINDUP" and def.mv != "" and int(def.move_data()["class"]) == int(att.move_data()["class"]) \
			and def.windup - def.mf <= lead and _reaches_soon(def, att):
		_clash(att, def)
		return
	_land(att, def)


func _reaches_soon(att, def) -> bool:
	var m: Dictionary = att.move_data()
	return att.dist() <= float(m["reach"]) + 0.4 and att.forward().dot(att.to_foe()) >= cos(deg_to_rad(float(m["arc"]) * 0.5))


func _land(att, def) -> void:
	att.connected = true
	if def.invulnerable():
		att.connected = false                          # the blade passes through: the roll's i-frames (a whiff)
		if not att.whiffed and def.st != "KNOCKDOWN" and def.st != "KO":
			att.whiffed = true
			_log("evade", att, def, att.vis(), def.vis())
			def.events.append(["evade", ""])
		return
	if def.st == "KNOCKDOWN" or def.st == "KO":
		att.connected = false
		return
	match att.mv:
		"bash":
			_bash(att, def)
		_:
			_strike(att, def)


func _faces(def, att) -> bool:
	return def.forward().dot(def.to_foe()) >= cos(deg_to_rad(float(def.moves["block"]["arc"]) * 0.5))


func _strike(att, def) -> void:
	var m: Dictionary = att.move_data()
	var unblockable: bool = bool(m.get("unblockable", false))
	if def.st == "BLOCK" and _faces(def, att):
		if def.parry_open():
			_parry(att, def)
			return
		if def.guard_up() and not unblockable:
			_blocked(att, def)
			return
	_hit(att, def)


func _hit(att, def) -> void:
	var a0: String = att.st
	var d0: String = def.st
	var m: Dictionary = att.move_data()
	var mv: String = att.mv
	var counter: bool = def.open_to_counter() and not def.armoured()
	var ch: Dictionary = c["counter_hit"]
	var dmg: float = float(m["chain_damage"] if mv == "light" and att.chain > 0 else m["damage"])
	var finisher: bool = def.st == "BROKEN" and (mv == "heavy" or mv == "charged")
	if finisher:
		dmg = float(c["finisher"]["damage"])
	if counter:
		dmg *= float(ch["damage_k"])
	var star: bool = def.st == "TELL" or def.st == "TAUNT"
	def.hurt(dmg)
	g.note_hit(att, def, d0, mv, dmg)
	att._count("hits")
	def._count("hits_taken")
	var key: String = mv + "_hit"
	var hs: int = int(c[key]["hitstop"]) + (int(ch["hitstop"]) if counter else 0)
	if finisher:
		hs = int(c["finisher"]["hitstop"])
	var from_dir: Vector3 = att.pos() - def.pos()
	var tiers: Dictionary = c["tiers"]
	var excess: float = float(m["poise"]) - float(def.cfg["poise"]) - (float(tiers["armour"]) if def.armoured() else 0.0)
	var broke: bool = def.lose_posture(float(m["hit_posture"]))
	var kind: String = "hit_" + mv
	var heavy: bool = mv != "light"
	if def.hp <= 0.0 or finisher or excess > float(tiers["stagger"]):
		g.feel.impact(att, def, int(g.tune["ko"]["stop"]) if def.hp <= 0.0 else hs)   # the round-ending blow holds longest
		var ko: bool = def.hp <= 0.0
		var lie: int = int(g.tune["rounds"]["end_frames"]) - 50 if ko else int(tiers["knockdown_frames"])
		def.stun("KO" if ko else "KNOCKDOWN", 0 if ko else lie)
		g.feel.down(def, lie, from_dir)
		g.feel.slide(def, -def.to_foe(), 1.0, 16)
		kind = "ko" if ko else ("finisher" if finisher else "knockdown")
	elif excess > float(tiers["flinch"]):
		var n: int = int(tiers["stagger_frames"]) + (int(ch["stun"]) if counter else 0)
		def.stun("STAGGER", n)
		g.feel.hit(att, def, heavy, counter, {"stop": hs, "frames": n, "push": float(tiers["stagger_push"])}, c["poses"]["STAGGER"])
	elif excess > 0.0:
		var n2: int = int(tiers["flinch_frames"]) + (int(ch["stun"]) if counter else 0)
		def.stun("HITSTUN", n2)
		g.feel.hit(att, def, heavy, counter, {"stop": hs, "frames": n2, "push": float(c[key]["push"])}, c["poses"]["HITSTUN"])
	else:
		kind = "absorbed"                               # armour or poise: he takes the damage and keeps going
		g.feel.hit(att, def, heavy, counter, {"stop": hs, "frames": 0, "push": 0.0}, {})
	if broke and def.st != "KO" and def.st != "KNOCKDOWN":
		_break(def)
	if counter:
		kind += "_counter"
	if star:
		att.stars += 1
		g.crowd(att, "star")
		att.events.append(["star", ""])
	_log(kind, att, def, a0, d0)
	att.events.append(["hit", {"kind": kind, "mv": mv, "dmg": dmg, "counter": counter}])


func _blocked(att, def) -> void:
	var a0: String = att.st
	var d0: String = def.st
	var heavy: bool = att.mv != "light"
	var key: String = "heavy_block" if heavy else "light_block"
	var r: Dictionary = c[key]
	var m: Dictionary = att.move_data()
	def.block_contact = true
	def.hurt(float(m["damage"]) * float(c["chip"]), false)
	if def == g.you:
		g.note_hit(att, def, "BLOCK", "chip", float(m["damage"]) * float(c["chip"]))   # chip is a cause too (round 8)
	def.spend_stamina(float(m["block_stamina"]) * float(def.cfg.get("block_stamina_k", 1.0)))
	var broke: bool = def.lose_posture(float(m["block_posture"]))
	def._count("blocks")
	var kind: String = key
	var tune: Dictionary = {"stop": int(r["hitstop"]), "frames": int(r["blockstun"]), "push": float(r["push"]), "recoil": float(r["recoil"])}
	if heavy:
		tune["attacker_frames"] = int(r["rebound"])
		att.stun("REBOUND", int(r["rebound"]))
	else:
		att.stun("RECOVERY", maxi(att.recovery, 1))      # the light's recovery runs on, from a recoil step
	if def.exhausted or def.stamina <= 0.0:
		var n: int = int(c["exhausted_block"]["guardbroken"])
		def.stun("GUARDBROKEN", n)
		var gb: Dictionary = g.feel.guard_break(att, def, {"stop": int(r["hitstop"]), "frames": n, "push": float(r["push"]) * 1.4}, c["poses"]["GUARDBROKEN"])
		if StringName(gb.get("defender", "")) == &"wallsplat":
			def.stun("WALLSPLAT", int(gb["defender_frames"]))
		if heavy:
			var rb: Dictionary = c["poses"]["REBOUND"]
			g.feel.pose(att, StringName(rb["clip"]), rb["anim"], int(r["rebound"]), float(rb["strength"]))
		kind += "_guardbreak"
	else:
		g.feel.blocked(att, def, heavy, tune, c["poses"]["REBOUND"])
		if broke:
			_break(def)
			kind += "_posture_break"
		else:
			def.stun("BLOCKSTUN", int(r["blockstun"]))
			def.block_held = true
	_log(kind, att, def, a0, d0)
	def.events.append(["blocked", {"heavy": heavy}])


func _parry(att, def) -> void:
	var a0: String = att.st
	var d0: String = def.st
	var key: String = att.mv + "_parried"
	var r: Dictionary = c[key]
	var m: Dictionary = att.move_data()
	var frames: int = int(r["parried"])
	var heavy: bool = att.mv != "light"
	def.block_contact = true
	att.stun("PARRIED", frames)
	def.stun("PARRY_OK", int(r["defender"]))
	g.feel.parried(att, def, heavy, {"stop": int(r["hitstop"]), "attacker_frames": frames, "frames": int(r["defender"]), "recoil": float(r["recoil"])}, c["poses"]["PARRIED"])
	var broke: bool = att.lose_posture(float(m["parried_posture"]))
	def.stamina = minf(float(g.tune["stamina"]["max"]), def.stamina + float(def.moves["parry"]["good_stamina"]))
	def._count("parries")
	att._count("parried")
	if broke:
		_break(att)
	g.crowd(def, "parry")
	_log(key, att, def, a0, d0)
	def.events.append(["parry", {"mv": key}])


func _clash(a, b) -> void:
	var a0: String = a.st
	var d0: String = b.st
	var r: Dictionary = c["clash"]
	var heavy: bool = a.mv != "light"
	var frames: int = int(r["rebound_heavy"] if heavy else r["rebound"])
	a.connected = true
	b.connected = true
	a.stun("REBOUND", frames)
	b.stun("REBOUND", frames)
	g.feel.clash(a, b, heavy, heavy, {"stop": int(r["hitstop"]), "frames": frames, "push": float(r["push"])}, c["poses"]["REBOUND"])
	var ba: bool = a.lose_posture(float(r["posture"]))
	var bb: bool = b.lose_posture(float(r["posture"]))
	if ba:
		_break(a)
	if bb:
		_break(b)
	a._count("clashes")
	b._count("clashes")
	g.crowd(a, "clash")
	_log("clash", a, b, a0, d0)
	a.events.append(["clash", {"heavy": heavy}])


func _bash(att, def) -> void:
	var a0: String = att.st
	var d0: String = def.st
	var away: Vector3 = -def.to_foe()
	var r: Dictionary = c["bash"]
	def.hurt(float(att.move_data()["damage"]), false)
	if def == g.you:
		g.note_hit(att, def, d0, "bash", float(att.move_data()["damage"]))
	att._count("bashes_landed")
	var cb: Dictionary = c["counter_bash"]
	if def.mv == "bash" and (def.st == "ACTIVE" or (def.st == "WINDUP" and def.windup - def.mf <= int(cb["window"]))):
		def.connected = true
		att.stun("REBOUND", int(cb["rebound"]))
		def.stun("REBOUND", int(cb["rebound"]))
		g.feel.clash(att, def, false, false, {"stop": int(cb["hitstop"]), "frames": int(cb["rebound"]), "push": float(cb["push"])}, c["poses"]["REBOUND"])
		_log("counter_bash", att, def, a0, d0)
		att.events.append(["clash", {"heavy": false}])
		return
	att.stun("RECOVERY", int(r["attacker"]))
	if def.stunned():
		def.t = maxi(0, def.t - 6)                    # the shove keeps him in his stun a little longer
		g.feel.guard_break(att, def, {"stop": int(c["bash_stun"]["hitstop"]), "push": float(c["bash_stun"]["push"])}, {})
		_log("bash_shove", att, def, a0, d0)
		return
	if def.exhausted:
		g.feel.impact(att, def, int(r["hitstop"]))
		def.stun("KNOCKDOWN", int(c["tiers"]["knockdown_frames"]))
		g.feel.down(def, int(c["tiers"]["knockdown_frames"]), att.pos() - def.pos())
		_log("bash_knockdown", att, def, a0, d0)
		att.events.append(["guardbreak", {}])
		return
	# the kernel's guard break finds the wall itself (a StaticBody3D within TLHit.WALL_REACH behind him): a splat 60
	var res: Dictionary = g.feel.guard_break(att, def, {"stop": int(r["hitstop"]), "frames": int(r["guardbroken"]), "push": float(r["push"])}, c["poses"]["GUARDBROKEN"])
	if StringName(res.get("defender", "")) == &"wallsplat":
		def.stun("WALLSPLAT", maxi(1, int(res["defender_frames"])))
		def._count("splats_taken")
		g.crowd(att, "splat")
		_log("bash_wallsplat", att, def, a0, d0)
		att.events.append(["splat", {}])
		return
	def.stun("GUARDBROKEN", int(r["guardbroken"]))
	_log("bash", att, def, a0, d0)
	att.events.append(["guardbreak", {}])


## A body knocked back in a stun that meets the ring wall is splatted against it (6.3, last row). The kernel's knock finds
## the wall and turns his stun into a wallsplat (its own hit-stop of 8 on him); the pack adds the same stop on the
## attacker, so both freeze, and takes the fighter into WALLSPLAT. Called every frame, before the hit-stop check.
func watch_walls(a, b) -> void:
	for f in [a, b]:
		if f.st in ["HITSTUN", "STAGGER", "GUARDBROKEN"] and g.feel.stun_of(f) == &"wallsplat":
			var a0: String = f.foe.st
			var d0: String = f.st
			g.feel.impact(f.foe, null, int(c["wall_knock"]["hitstop"]))
			f.stun("WALLSPLAT", maxi(1, g.feel.stun_left(f)))
			f._count("splats_taken")
			g.crowd(f.foe, "splat")
			_log("wall_knock", f.foe, f, a0, d0)
			f.foe.events.append(["splat", {}])


## Metres from the body's back to the ring wall along `dir` (the ring is a circle round the origin).
func wall_behind(f, dir: Vector3) -> float:
	var p := Vector2(f.pos().x, f.pos().z)
	var d := Vector2(dir.x, dir.z).normalized()
	var r: float = ring_inner - f.radius
	var b: float = p.dot(d)
	var disc: float = b * b - (p.length_squared() - r * r)
	if disc < 0.0:
		return 0.0
	return maxf(0.0, -b + sqrt(disc))


func _break(f) -> void:
	f.stun("BROKEN", int(c["broken_frames"]), c["poses"]["BROKEN"])
	f.events.append(["broken", ""])
	f._count("posture_broken")


func _log(kind: String, att, def, a0: String, d0: String) -> void:
	var a1: String = att.vis()
	var d1: String = def.vis()
	var both: bool = kind == "evade" or ((a1 != a0 or g.feel.stop_left(att) > 0) and (d1 != d0 or g.feel.stop_left(def) > 0))
	if not both:
		failures += 1
	kinds[kind] = int(kinds.get(kind, 0)) + 1
	g.first_minute_note(kind, att, def, d0)
	log.append({"f": g.ctx.frame, "type": kind, "by": att.id, "a": [a0, a1, att.st], "d": [d0, d1, def.st], "both": both})
	if log.size() > 24:
		log.pop_front()
