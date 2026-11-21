extends Node
## Hit lab (K7, falls lane L3, 21 Nov 2026): the one scripted run every falls arm is judged on. It plays itself; the
## bot only waits for the end. Nothing here depends on how an arm draws a hit: it calls `TLHit.react` / `TLHit.down` and
## measures what the figure did through the rig's public sockets.
## - Station "lab" (concrete): an attacker with a stick hits a standing victim from the FRONT, then the SIDE (the
##   victim's right), then from BEHIND; each side: a tap (0.3, react), a solid hit (0.7, react), a big hit (1.2, down
##   for 40 frames), then the get-up. The victim turns between the sides; the attacker always stands on the left, so
##   every fall away from the blow goes to the right of the picture.
## - Station "check" (ice): the hockey body check as engine/packs/hockey/scripts/hits.gd does it (lunge 1.5 m/s, the
##   victim pushed along the line at 0.6 x the closing speed, down for 30 + 12 x (closing - 7.8) frames, 30..60), at
##   scale 1, both skaters with sticks; the hitter comes in at 8.6 m/s, shoulder to shoulder from the victim's right
##   (40 m to the side of the lab station, so neither camera sees the other station).
## Measures (per hit, through `rig.socket(&"head")` relative to the body, from the frame before the hit): how far the
## head went away from / toward the blow, its lowest height, where it lies; `pose_digest` hashes five sockets of both
## victims every frame (the same run twice must give the same digest, whatever the arm's way of drawing it).

const LIE: int = 40                     # frames a big lab hit floors him
const SETS: Array = [["front", PI * 0.5, 40], ["side", PI, 210], ["behind", -PI * 0.5, 380]]
const STRENGTHS: Array = [[0.3, 0, "tap"], [0.7, 40, "solid"], [1.2, 80, "big"]]
const CHECK_AT: int = 560
const END: int = 750
const A_POS: Vector3 = Vector3(-1.15, 0.05, 0.0)
const V_POS: Vector3 = Vector3(0.0, 0.05, 0.0)
const H_POS: Vector3 = Vector3(32.0, 0.05, 0.5)
const K_POS: Vector3 = Vector3(40.0, 0.05, 0.0)
const SOCKETS: Array = [&"head", &"hand_r", &"hand_l", &"foot_r", &"foot_l"]

var ctx
var attacker: TLBiped
var victim: TLBiped
var hitter: TLBiped
var skater: TLBiped
var hud: TLHud
var ticks: int = 0
var hits: Array = []                    # one Dictionary per hit: what it was and what the figure did
var current: Dictionary = {}            # the hit being measured
var check: Dictionary = {}
var downed: int = 0
var got_up: int = 0
var digest: int = 0
var label: String = "ready"


func _pack_setup(c) -> void:
	ctx = c
	ctx.root.add_child(TLBodies.ground(Vector2(18, 12), "concrete", 0.0, Vector3(0, 0, 0)))
	ctx.root.add_child(TLBodies.ground(Vector2(40, 12), "ice", 0.0, Vector3(40, 0, 0)))
	attacker = TLBiped.create({"position": A_POS, "facing": -PI * 0.5, "name": "Attacker",
		"rig_params": {"prop": "stick", "backpack": false, "colors": {"top": "car_red", "trim": "car_white", "legs": "bot_dark", "boots": "black"}}})
	victim = TLBiped.create({"position": V_POS, "facing": PI * 0.5, "name": "Victim",
		"rig_params": {"backpack": false, "colors": {"top": "car_blue", "trim": "car_white", "legs": "bot_dark", "boots": "black"}}})
	hitter = TLBiped.create({"position": H_POS, "facing": -PI * 0.5, "name": "Hitter", "mode": "skate",
		"rig_params": {"colors": {"top": "car_red", "trim": "car_white", "legs": "bot_dark", "boots": "black"}}})
	skater = TLBiped.create({"position": K_POS, "facing": PI, "name": "Skater", "mode": "skate",
		"rig_params": {"colors": {"top": "car_blue", "trim": "car_white", "legs": "bot_dark", "boots": "black"}}})
	for b: TLBiped in [attacker, victim, hitter, skater]:
		ctx.root.add_child(b)
	for b: TLBiped in [victim, skater]:
		b.downed.connect(func() -> void: downed += 1)
		b.got_up.connect(func() -> void: got_up += 1)
	ctx.cameras.add_view(&"lab", Vector3(1.0, 1.8, 5.4), Vector3(0.5, 0.85, 0.0), 45.0)
	ctx.cameras.add_view(&"check", Vector3(39.8, 2.3, 6.4), Vector3(39.6, 0.8, 0.0), 50.0)
	ctx.cameras.set_subject(&"lab", victim)
	ctx.cameras.set_subject(&"check", skater)
	hud = TLHud.create()
	ctx.root.add_child(hud)
	hud.add_bound(&"beat", func() -> String: return label, &"top_left")


func _pack_start() -> void:
	pass


func _pack_tick(_frame: int) -> void:
	ticks += 1
	for b: TLBiped in [attacker, victim, hitter, skater]:
		b.move(Vector3.ZERO)
	for s: Array in SETS:
		var at: int = int(s[2])
		if ticks == at - 12:
			victim.place(V_POS, float(s[1]))
			attacker.place(A_POS, -PI * 0.5)
		for st: Array in STRENGTHS:
			var hf: int = at + int(st[1])
			var lead: Array = _lead(float(st[0]))
			if ticks == hf - int(lead[1]) and lead[0] != &"":
				var ar = attacker.rig
				ar.play(lead[0])
			if ticks == hf - 4:
				attacker.shove(Vector3(1.2, 0, 0) * attacker.body_mass)
			if ticks == hf:
				_hit(String(s[0]), float(st[0]), String(st[2]))
	_measure()
	_check_tick()
	if ticks == CHECK_AT - 20:
		ctx.cameras.activate(&"check")
		label = "HOCKEY  body check, shoulder to shoulder from his right"
	_digest()


## The attacker's swing: the clip and how many frames before contact it is played (L2's strike clips when the rig has them).
func _lead(strength: float) -> Array:
	var ar = attacker.rig
	var have: PackedStringArray = ar.clips() if ar.has_method("clips") else PackedStringArray()
	if strength >= 1.0:
		return [&"strike_heavy", 11] if have.has("strike_heavy") else ([&"shoot", 25] if have.has("shoot") else [&"", 0])
	return [&"strike", 4] if have.has("strike") else ([&"pass", 18] if have.has("pass") else [&"", 0])


func _hit(side: String, strength: float, kind: String) -> void:
	var from_dir: Vector3 = attacker.global_position - victim.global_position
	from_dir.y = 0.0
	var away: Vector3 = -from_dir.normalized()
	victim.shove(away * strength * 1.8 * victim.body_mass)
	if strength >= 1.0:
		TLHit.down(victim, LIE, from_dir)
	else:
		TLHit.react(victim, from_dir, strength)
	label = "%s   %.1f %s   %s" % [side.to_upper(), strength, kind, "down" if strength >= 1.0 else "react"]
	_start(victim, side, strength, away, 70 if strength >= 1.0 else 34)


func _start(who: TLBiped, side: String, strength: float, away: Vector3, window: int) -> void:
	if not current.is_empty():
		hits.append(current)
	current = {"side": side, "strength": strength, "frame": ticks, "who": who, "away": away, "until": ticks + window,
		"base": _head_rel(who), "away_max": 0.0, "toward_max": 0.0, "move_max": 0.0, "head_y_min": 99.0,
		"lie_away": 0.0, "lie_y": 0.0, "down": who.is_down()}


func _head_rel(who: TLBiped) -> Vector3:
	var r = who.rig
	var h: Node3D = r.socket(&"head") if r != null and r.has_method("socket") else null
	return (h.global_position - who.global_position) if h != null else Vector3.ZERO


func _measure() -> void:
	if current.is_empty() or ticks > int(current["until"]):
		return
	var who: TLBiped = current["who"]
	var d: Vector3 = _head_rel(who) - (current["base"] as Vector3)
	var away: Vector3 = current["away"]
	var flat: Vector3 = Vector3(d.x, 0.0, d.z)
	current["away_max"] = maxf(float(current["away_max"]), flat.dot(away))
	current["toward_max"] = maxf(float(current["toward_max"]), -flat.dot(away))
	current["move_max"] = maxf(float(current["move_max"]), d.length())
	var hy: float = _head_rel(who).y
	current["head_y_min"] = minf(float(current["head_y_min"]), hy)
	if ticks == int(current["frame"]) + 30:              # lying (a big hit) or the end of a reaction
		current["lie_away"] = flat.dot(away)
		current["lie_y"] = hy


func _check_tick() -> void:
	if ticks == CHECK_AT:
		hitter.shove(Vector3(8.6, 0, 0) * hitter.body_mass)
	if ticks < CHECK_AT or ticks > END:
		return
	if check.is_empty():
		hitter.move(Vector3(1, 0, 0))
		var n: Vector3 = skater.global_position - hitter.global_position
		n.y = 0.0
		if n.length() < 0.95:
			n = n.normalized()
			var c: float = (hitter.velocity - skater.velocity).dot(n)
			hitter.shove(n * 1.5 * hitter.body_mass)
			var hr = hitter.rig
			var r: PackedStringArray = hr.clips() if hr.has_method("clips") else PackedStringArray()
			if r.has("body_check"):
				hr.play(&"body_check")
			var lying: int = 0
			if c >= 7.8:
				skater.shove(n * c * 0.6 * skater.body_mass)
				lying = int(clampf(30.0 + 12.0 * (c - 7.8), 30.0, 60.0))
				TLHit.down(skater, lying, -n)
			elif c >= 3.0:
				skater.shove(n * c * 0.6 * skater.body_mass)
				TLHit.react(skater, -n, 0.7)
			check = {"frame": ticks, "closing": snappedf(c, 0.001), "down_frames": lying}
			label = "HOCKEY  body check at %.1f m/s: %s" % [c, ("down %d f" % lying) if lying > 0 else "stumble"]
			_start(skater, "check", 1.2 if lying > 0 else 0.7, n, 80)
	else:
		hitter.brake(true)


func _digest() -> void:
	var parts: PackedStringArray = []
	for who: TLBiped in [victim, skater]:
		for s: StringName in SOCKETS:
			var wr = who.rig
			var n: Node3D = wr.socket(s) if wr.has_method("socket") else null
			if n != null:
				parts.append(str(n.global_position.snapped(Vector3.ONE * 0.001)))
	digest = hash(str(digest) + ",".join(parts))


func _hits_out() -> Array:
	var all: Array = hits.duplicate()
	if not current.is_empty():
		all.append(current)
	var out: Array = []
	for h: Dictionary in all:
		out.append({"side": h["side"], "strength": h["strength"], "frame": h["frame"],
			"away_max": snappedf(float(h["away_max"]), 0.001), "toward_max": snappedf(float(h["toward_max"]), 0.001),
			"move_max": snappedf(float(h["move_max"]), 0.001), "head_y_min": snappedf(float(h["head_y_min"]), 0.001),
			"lie_away": snappedf(float(h["lie_away"]), 0.001), "lie_y": snappedf(float(h["lie_y"]), 0.001)})
	return out


func _pack_state() -> Dictionary:
	return {"ticks": ticks, "done": ticks >= END, "hits": _hits_out(), "check": check, "downed": downed, "got_up": got_up,
		"victim_down": victim.is_down(), "skater_down": skater.is_down(), "pose_digest": digest,
		"victim": victim.global_position.snapped(Vector3.ONE * 0.0001), "skater": skater.global_position.snapped(Vector3.ONE * 0.0001),
		"hitter": hitter.global_position.snapped(Vector3.ONE * 0.0001), "label": label}
