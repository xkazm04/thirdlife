extends RefCounted
## Press windows and contact resolution share the same frame clock and the same two bodies.

const KEYS := ["check_gap", "check_cone_deg", "check_cooldown_frames", "whiff_cooldown_frames", "body_window",
	"bot_body_window", "lunge_speed", "cross_thrust", "behind_match", "arc_dot", "board_range",
	"board_bonus", "stability_speed", "stand_speed", "stand_brace", "side_brace", "speed_stability",
	"sprint_stability", "charge_stability", "unseen_stability", "stumble_ratio", "loose_ratio", "down_ratio",
	"full_ratio", "down_frames_min", "down_frames_max", "grace_frames", "speed_kept", "give_share",
	"restitution", "scatter_speed", "loose_back_speed", "strip_speed", "cross_gap", "cross_cone_deg",
	"cross_cooldown_frames", "cross_windup", "bot_cross_windup", "cross_live_frames", "recent_carry_frames",
	"hold_frames", "hold_speed", "hold_turn", "hold_exposed", "hold_margin", "hold_clip_frames", "cross_clip_hit", "check_windup", "check_pull", "downed_radius", "downed_push", "lying_length"]

var api
var skaters: Dictionary
var teams: Dictionary
var order: Array
var check_gap: float
var check_cone_deg: float
var check_cooldown_frames: int
var whiff_cooldown_frames: int
var body_window: int
var bot_body_window: int
var lunge_speed: float
var cross_thrust: float
var behind_match: float
var arc_dot: float
var board_range: float
var board_bonus: float
var stability_speed: float
var stand_speed: float
var stand_brace: float
var side_brace: float
var speed_stability: float
var sprint_stability: float
var charge_stability: float
var unseen_stability: float
var stumble_ratio: float
var loose_ratio: float
var down_ratio: float
var full_ratio: float
var down_frames_min: int
var down_frames_max: int
var grace_frames: int
var speed_kept: float
var give_share: float
var restitution: float
var scatter_speed: float
var loose_back_speed: float
var strip_speed: float
var cross_gap: float
var cross_cone_deg: float
var cross_cooldown_frames: int
var cross_windup: int
var bot_cross_windup: int
var cross_live_frames: int
var recent_carry_frames: int
var hold_frames: int
var hold_speed: float
var hold_turn: float
var hold_exposed: float
var hold_margin: float
var hold_clip_frames: int
var check_windup: int               ## JamCartridge.h:461 (8), here the body_check clip's hit frame 12 (RIGS.md)
var check_pull: float              ## JamCartridge.h:479 check_pull_m 1.0: the human is drawn to his man over the wind-up
var downed_radius: float             ## JamCartridge.h:416-422 DownedRadiusM: a lying man's body, for those on their feet
var lying_length: float             ## how far a fallen man lies along his facing from his feet (measured: the fall clip, 3.1 m at 2.2x)
var downed_push: float               ## the most a standing skater is moved out of it in one frame (m)
var windups: Dictionary = {}       ## id -> {"end": frame the window opens, "on": the man pressed at, "pulled": m}
var cross_clip_hit: int            ## RIGS.md "Fight clips": the cross_check clip shows its hit on this frame
var bodies: Array[TLBiped] = []
var blue_side := PackedByteArray()
var rng: RandomNumberGenerator
var enabled := true
var human := "b0"
var shield: Dictionary = {}        ## The goalies.
var immune: Dictionary = {}        ## L5 crazy: id -> true while his shield runs: no check or cross-check lands on him (he still checks)
var immune_blocks: Dictionary = {}  ## L5 crazy: shielded victim -> presses that passed him over
var _immune_target := ""           ## L5 crazy: the nearest shielded man the last target query passed over
var immune_counted: Dictionary = {} ## L5 crazy: presser id -> his current press already counted a block
var ready_at: Dictionary = {}
var cross_ready: Dictionary = {}
var body_until: Dictionary = {}
var swings: Dictionary = {}        ## id -> {target, due, end}, only during a wind-up or live window.
var hold_age := 0
var hold_spent := false
var grace_until: Dictionary = {}
var counts: Dictionary = {}
var down_frames: Dictionary = {}
var side_down: Dictionary = {}
var last_hit: Dictionary = {}
var tries: Dictionary = {}
var by_id: Dictionary = {}
var events: Array = []
var _now := 0

func setup(tune: Dictionary, a, sk: Dictionary, tm: Dictionary, ord: Array, source: RandomNumberGenerator) -> void:
	var cfg: Dictionary = tune["hits"]
	for key: String in cfg:
		if key not in KEYS:
			push_error("tuning.json: unknown hits.%s" % key)
	# JamCartridge.h:377-540 and JamSim.h:750-758. Cache contact tuning for live windows.
	for key: String in KEYS:
		self[key] = cfg[key]
	api = a
	skaters = sk
	teams = tm
	order = ord
	rng = source
	for id: String in order:
		bodies.append(skaters[id])
		blue_side.append(int(tm[id] == "blue"))
		by_id[id] = 0
		tries[id] = 0
		(skaters[id] as TLBiped).got_up.connect(_got_up.bind(id))
	for side: String in ["blue", "red"]:
		counts[side] = {"bump": 0, "stumble": 0, "knockdown": 0, "cross": 0}
		down_frames[side] = 0
		side_down[side] = 0

func tick(frame: int) -> void:
	_now = frame

func _got_up(id: String) -> void:
	# JamSim.cpp:2644-2655. The signal fires in the body step after the pack's tick.
	grace_until[id] = _now + grace_frames

func graced(id: String) -> bool:
	return _now <= int(grace_until.get(id, -1))

func is_down(id: String) -> bool:
	return (skaters[id] as TLBiped).is_down()

func is_stumbling(id: String) -> bool:
	return (skaters[id] as TLBiped).is_stumbling()

func can_act(id: String) -> bool:
	var sk: TLBiped = skaters[id]
	return not sk.is_down() and not sk.is_stumbling()

func _eligible(id: String) -> bool:
	return enabled and id != api.carrier and not shield.has(id) and can_act(id)

func can_check(id: String) -> bool:
	return _eligible(id) and not windups.has(id) and not swinging(id) and not is_braced(id) and _now >= int(ready_at.get(id, 0))

func can_cross(id: String) -> bool:
	return _eligible(id) and not swinging(id) and not is_braced(id) and _now >= int(cross_ready.get(id, 0))

func _vel(id: String) -> Vector3:
	var v: Vector3 = (skaters[id] as TLBiped).velocity
	return Vector3(v.x, 0, v.z)

func _dir(att: String, vic: String) -> Vector3:
	var d: Vector3 = api.pos_of(vic) - api.pos_of(att)
	return d.normalized() if not d.is_zero_approx() else api.fwd_of(att)

func closing(att: String, vic: String) -> float:
	return (_vel(att) - _vel(vic)).dot(_dir(att, vic))

func _opponent(id: String, other: String) -> bool:
	return teams[id] != teams[other] and not shield.has(other) and not is_down(other) and not immune.has(other)

func touch_distance(id: String, other: String) -> float:
	return (skaters[id] as TLBiped).body_radius() + (skaters[other] as TLBiped).body_radius()

func target(id: String, gap: float, cone_deg: float, stick := false) -> String:
	var best := ""
	var dist := INF
	var f: Vector3 = api.stick_of(id) if stick else api.fwd_of(id)
	var threshold := cos(deg_to_rad(cone_deg))
	var me: Vector3 = api.pos_of(id)
	var immune_d := INF
	_immune_target = ""
	for oid: String in order:
		if immune.has(oid) and teams[id] != teams[oid] and not is_down(oid):
			var ti: Vector3 = api.pos_of(oid) - me
			var di := ti.length()
			if di <= touch_distance(id, oid) + gap and di < immune_d and f.dot(ti) >= threshold * di:
				immune_d = di
				_immune_target = oid       # L5 crazy: counted by the press that asked, never hit
			continue
		if not _opponent(id, oid):
			continue
		var to: Vector3 = api.pos_of(oid) - me
		var d := to.length()
		if d <= touch_distance(id, oid) + gap and d < dist and f.dot(to) >= threshold * d:
			best = oid
			dist = d
	return best

func in_cross_cone(id: String, vic: String) -> bool:
	return (api.stick_of(id) as Vector3).dot(_dir(id, vic)) >= cos(deg_to_rad(cross_cone_deg))

func _clip(id: String, name: StringName) -> void:
	if api.headless:
		return                               # L4b: the figure's clips are drawing only; nothing hashed reads a pose (budget: p50)
	var rig = (skaters[id] as TLBiped).rig
	if rig == null:
		return
	if rig.has_method("clips") and (rig.clips() as PackedStringArray).has(name):
		rig.play(name)
	elif name == &"cross_check":
		rig.play(&"shoot")

func try_check(id: String) -> String:
	if not can_check(id):
		return ""
	tries[id] += 1
	_clip(id, &"body_check")
	# JamSim.cpp:1968-1983, 2105-2177 (StepWindups, EndWindupOnContact, StepCheckPull): the press winds up check_windup frames
	# (the clip shows its hit on that frame), the window opens after it; a meeting inside the wind-up is the hit.
	immune_counted.erase(id)
	var on := target(id, check_gap + check_pull + maxf(0.0, _vel(id).length()) * float(check_windup) / 60.0, check_cone_deg)
	_count_immune(id)
	windups[id] = {"end": _now + check_windup, "on": on, "pulled": 0.0}
	ready_at[id] = _now + check_windup + whiff_cooldown_frames
	return ""

## One wind-up frame: meet the man (the hit, on the velocities before the bodies touch), draw a human toward him, or open
## the window at its end. JamSim.cpp:2105-2177.
func _step_windup(id: String) -> void:
	var w: Dictionary = windups[id]
	if not _eligible(id):
		windups.erase(id)
		return
	var on: String = w.on
	if on != "" and _opponent(id, on):
		var gap: float = api.pos_of(on).distance_to(api.pos_of(id)) - touch_distance(id, on)
		var c := closing(id, on)
		# he meets him inside this physics step: the bodies are stepped one after another, so his own speed along the line
		# can close the gap before the other man has moved (a same-way meeting too); resolved here, on the velocities before contact
		if gap - maxf(maxf(c, _vel(id).dot(_dir(id, on))), 0.0) / 60.0 <= 0.02 and in_cone(id, on, check_cone_deg):
			windups.erase(id)
			ready_at[id] = _now + check_cooldown_frames
			resolve(id, on, _dir(id, on), "body")
			return
		var left := int(w.end) - _now
		if id == human and check_pull > 0.0 and left > 0 and gap > 0.0:
			# drawn so the bodies meet as the wind-up ends; his speed is not changed (the hit stays his momentum's)
			var step := clampf((gap - maxf(c, 0.0) * float(left) / 60.0) / float(left), 0.0, check_pull - float(w.pulled))
			if step > 0.0:
				var me: TLBiped = skaters[id]
				me.global_position += _dir(id, on) * step
				w.pulled = float(w.pulled) + step
	if _now >= int(w.end):
		windups.erase(id)
		# JamSim.h:510-514. The frame the wind-up ends counts as the first frame of the window.
		body_until[id] = _now + (body_window if id == human else bot_body_window) - 1
		_body_contact(id)

func in_cone(id: String, vic: String, cone_deg: float) -> bool:
	return (api.fwd_of(id) as Vector3).dot(_dir(id, vic)) >= cos(deg_to_rad(cone_deg))

## L5 crazy: one block per press, on the first frame of its window that passed over a shielded man.
func _count_immune(id: String) -> void:
	if _immune_target != "" and not immune_counted.has(id):
		immune_blocks[_immune_target] = int(immune_blocks.get(_immune_target, 0)) + 1
		immune_counted[id] = true
	_immune_target = ""

func _body_contact(id: String) -> String:
	var vic := target(id, check_gap, check_cone_deg)
	_count_immune(id)
	if vic == "":
		return ""
	body_until.erase(id)
	ready_at[id] = _now + check_cooldown_frames
	return resolve(id, vic, _dir(id, vic), "body")

func swinging(id: String) -> bool:
	return swings.has(id)

func try_cross(id: String, aimed := "") -> bool:
	if not can_cross(id):
		return false
	tries[id] += 1
	body_until.erase(id)
	_immune_target = ""
	immune_counted.erase(id)
	if aimed == "":
		aimed = target(id, cross_gap, cross_cone_deg, true)
	_count_immune(id)
	# JamSim.cpp:1742-1768, 1819-1845; JamCartridge.h:461-470,486. Misses can meet a later opponent.
	var due := _now + (cross_windup if id == human else bot_cross_windup)
	swings[id] = {"target": aimed, "due": due, "end": due + cross_live_frames}
	cross_ready[id] = _now + cross_cooldown_frames
	# L2b's clip shows the hit on its frame cross_clip_hit (10): start it so that frame is the swing's due frame
	if due - _now > cross_clip_hit:
		swings[id]["clip"] = due - cross_clip_hit
	else:
		_clip(id, &"cross_check")
	return true

func release_hold() -> void:
	hold_age = 0
	hold_spent = false

func is_braced(id: String) -> bool:
	return hold_age > 0 and id == human and not hold_spent and hold_age >= hold_frames

func hold_input(pressed: bool, carrying: bool, first_frame: bool) -> void:
	if not pressed or carrying:
		release_hold()
		return
	if first_frame and _eligible(human):
		hold_age = 1
	if hold_age == 0 or hold_spent:
		return
	if not _eligible(human):
		hold_spent = true
		swings.erase(human)
		return
	# JamSim.cpp:1946-1965; JamSim.h:750-758. A committed hold spends its swing on body contact only.
	if first_frame:
		return
	hold_age += 1
	if is_braced(human):
		swings.erase(human)
		if (hold_age - hold_frames) % hold_clip_frames == 0:
			_clip(human, &"cross_check")
		_held_contact()

func _held_contact() -> void:
	var me: TLBiped = skaters[human]
	for vic: String in order:
		if not _opponent(human, vic):
			continue
		var reach := touch_distance(human, vic) + hold_margin
		if me.global_position.distance_squared_to(skaters[vic].global_position) <= reach * reach:
			resolve(human, vic, _dir(human, vic), "cross")
			hold_spent = true
			return

func step_actions() -> void:
	if not windups.is_empty():
		for id: String in windups.keys():
			_step_windup(id)
	if not body_until.is_empty():
		for id: String in body_until.keys():
			if _now > int(body_until[id]) or not _eligible(id):
				body_until.erase(id)
			else:
				_body_contact(id)
	if not swings.is_empty():
		for id: String in swings.keys():
			_step_swing(id)

func _step_swing(id: String) -> void:
	var s: Dictionary = swings[id]
	if s.has("clip") and _now >= int(s.clip):
		s.erase("clip")
		_clip(id, &"cross_check")
	if not _eligible(id) or _now > int(s.end):
		swings.erase(id)
		return
	if _now < int(s.due) or (id == human and hold_age > 0):
		return
	var vic: String = s.target
	if vic == "" or not _opponent(id, vic) or api.pos_of(vic).distance_to(api.pos_of(id)) > touch_distance(id, vic) + cross_gap or not in_cross_cone(id, vic):
		if _now == int(s.due):
			return
		vic = target(id, cross_gap, cross_cone_deg, true)
	if vic != "":
		resolve(id, vic, _dir(id, vic), "cross")
		swings.erase(id)

## JamSim.cpp:2559-2570; JamCartridge.h:526. Brace also supplies effective mass in the collision.
func brace(id: String, dir: Vector3, kind: String) -> float:
	var along: float = dir.dot(api.fwd_of(id))
	var arc := arc_dot
	if _vel(id).length() >= stand_speed or along > arc or (kind == "cross" and along < -arc):
		return 1.0
	var front := stand_brace
	if kind == "body" and along > -arc and id != api.carrier:
		return lerpf(side_brace, front, clampf(-along / arc, 0, 1))
	return front

## JamSim.cpp:2534-2556. A fully wound shot exposes its carrier.
func charge_factor(id: String) -> float:
	return charge_stability if api.carrier == id and api.shot_held and api.held_frames == api.charge_frames else 1.0

func stability(id: String, dir: Vector3, standing_brace: float) -> float:
	var sk: TLBiped = skaters[id]
	var speed := _vel(id).length()
	var stand := stand_speed
	var factor := standing_brace
	if speed >= stand:
		factor = lerpf(1.0, speed_stability, clampf((speed - stand) / maxf(0.000001, api.skate.top_speed(id) - stand), 0, 1))
	if api.skate.is_sprinting(id) and not is_braced(id):
		factor *= sprint_stability
	factor *= charge_factor(id)
	if dir.dot(api.fwd_of(id)) > arc_dot:
		factor *= unseen_stability
	return sk.body_mass * stability_speed * factor

## JamSim.cpp:2573-2581. Signed distance (negative inside) and outward normal of the rounded rink.
func board_distance(p: Vector3) -> Vector3:
	var half_size: Vector2 = api.rink_half
	var r: float = api.rink_corner
	var q := Vector2(absf(p.x), absf(p.z)) - half_size + Vector2.ONE * r
	var corner := q.max(Vector2.ZERO)
	var normal := corner.normalized()
	if corner == Vector2.ZERO:
		normal = Vector2.RIGHT if q.x > q.y else Vector2.DOWN
	return Vector3(normal.x * signf(p.x), corner.length() + minf(maxf(q.x, q.y), 0.0) - r, normal.y * signf(p.z))

func resolve(att: String, vic: String, dir: Vector3, kind: String) -> String:
	var hitter: TLBiped = skaters[att]
	var victim: TLBiped = skaters[vic]
	var va := _vel(att)
	var vv := _vel(vic)
	var c := (va - vv).dot(dir)
	var back: bool = dir.dot(api.fwd_of(vic)) > arc_dot
	var cross := kind == "cross"
	var held := is_braced(att)
	var push := cross_thrust if cross else lunge_speed
	# JamSim.cpp:2583-2601,2612-2632. Only the victim's impulse includes the board bonus.
	if cross and back:
		push *= clampf(c / behind_match, 0, 1)
	var free := hitter.body_mass * maxf(0, c + push)
	var board := board_distance(victim.position)
	var bonus := 0.0
	if -board.y <= board_range:
		var local_dir: Vector3 = api.rink_root.global_basis.inverse() * dir
		bonus = board_bonus * clampf(2.0 * (local_dir.x * board.x + local_dir.z * board.z), 0, 1)
	var weight := brace(vic, dir, kind)
	var sv := stability(vic, dir, weight)
	if is_braced(vic) and va.dot(dir) > vv.dot(-dir):
		sv *= hold_exposed
	var sa := stability(att, -dir, brace(att, -dir, "body"))
	var ratio := free * (1.0 + bonus) / sv
	var outcome := "knockdown" if ratio >= down_ratio else ("stumble" if ratio >= stumble_ratio else "bump")
	# JamSim.cpp:1779-1817. Only a human tap gets the special stumble and strip from behind.
	var recent: bool = api.carrier == vic or (api.last_carried.has(vic) and _now - int(api.last_carried[vic]) <= recent_carry_frames)
	var back_strip := att == human and not held and recent
	if cross and back and not held:
		outcome = "stumble" if back_strip else "bump"
	if graced(vic) or (outcome == "stumble" and victim.is_stumbling()):
		outcome = "bump"
	var recoil := outcome != "knockdown" and sa < sv and free >= sa
	if is_braced(vic) and outcome != "bump":
		hold_spent = true
	var down_time := 0
	match outcome:
		"bump":
			# A capped bump still reports its physical ratio but must not re-stumble the figure.
			TLHit.react(victim, -dir, minf(ratio, 0.399999))
		"stumble":
			victim.shove(-vv * (1.0 - speed_kept) * victim.body_mass)
			TLHit.react(victim, -dir, clampf(ratio, 0.4, 0.99))
		"knockdown":
			var t := clampf((ratio - down_ratio) / (full_ratio - down_ratio), 0, 1)
			down_time = roundi(lerpf(down_frames_min, down_frames_max, t))
			TLHit.down(victim, down_time, -dir)
	if api.carrier == vic:
		var strip: bool = cross and not held and (not back or back_strip)
		if strip and api.shield_left == 0:
			api.knock_loose(vic, va * speed_kept - dir * strip_speed)
		elif outcome == "knockdown" or (outcome == "stumble" and ratio >= loose_ratio):
			# JamSim.cpp:2700-2705,2777-2784. The stumble has already halved his speed.
			var scatter := Vector3.RIGHT.rotated(Vector3.UP, rng.randf_range(0, TAU))
			api.knock_loose(vic, _vel(vic) * speed_kept + scatter * scatter_speed - dir * loose_back_speed)
	# JamSim.cpp:2684-2694,2742-2763. Exchange the lunge, pay recoil, then bounce the bodies.
	if outcome != "bump":
		var give := give_share * (maxf(0, c + push) if cross else push)
		var impulse := dir * give * hitter.body_mass
		victim.shove(impulse)
		hitter.shove(-impulse)
	if recoil:
		hitter.shove(-_vel(att) * (1.0 - speed_kept) * hitter.body_mass)
		TLHit.react(hitter, dir, clampf(free / sa, 0.4, 0.99))
	if not cross:
		# JamCartridge.h:533-537. Effective mass changes the velocity split, not the body's shove API.
		var effective := victim.body_mass * (1.0 if outcome == "knockdown" else weight)
		var exchange := (1.0 + restitution) * maxf(0, (_vel(att) - _vel(vic)).dot(dir)) / (1.0 / hitter.body_mass + 1.0 / effective)
		hitter.shove(-dir * exchange)
		victim.shove(dir * exchange * victim.body_mass / effective)
	var side: String = teams[att]
	counts[side][outcome] += 1
	if cross:
		counts[side]["cross"] += 1
	by_id[att] += 1
	last_hit = {"by": att, "on": vic, "kind": kind, "class": outcome, "ratio": ratio, "closing": snappedf(c, 0.001),
		"frame": _now, "recoil": recoil, "braced": weight > 1.0}
	if held:
		last_hit["held"] = true
	if bonus > 0:
		last_hit["board"] = true
	if down_time > 0:
		last_hit["down_frames"] = down_time
		last_hit["down_with_rise"] = victim.down_frames_left()
	events.append([outcome, att, vic, last_hit])
	return outcome

func enforce() -> void:
	var blue := 0
	var red := 0
	for i in bodies.size():
		if bodies[i].is_down():
			if blue_side[i]:
				blue += 1
			else:
				red += 1
	if blue > 0:
		down_frames["blue"] += blue
		side_down["blue"] += 1
	if red > 0:
		down_frames["red"] += red
		side_down["red"] += 1
	if blue + red > 0 and downed_radius > 0.0:
		_keep_off_downed()

## JamCartridge.h:416-422, JamSim.cpp:2467-2487 (PushOutOfDowned): nobody stands in a man who is down. His lying body is the
## segment from his feet lying_length along his facing (TLHit.down v1 falls forward; when the falls experiment lands, follow
## its direction here), downed_radius thick; a skater on his feet alone gives way (at most downed_push a frame) and the speed
## he had into it turns along it. Read from the body, never the rig's pose: the pose is drawing only (clips skip headless).
func _lying(i: int) -> Array:
	var down: TLBiped = bodies[i]
	var a := Vector3(down.global_position.x, 0.0, down.global_position.z)
	return [a, a + (api.fwd_of(order[i]) as Vector3) * lying_length]

func _keep_off_downed() -> void:
	for i in bodies.size():
		var down: TLBiped = bodies[i]
		if not down.is_down():
			continue
		var seg := _lying(i)
		var a: Vector3 = seg[0]
		var ab: Vector3 = seg[1] - a
		for j in bodies.size():
			var up: TLBiped = bodies[j]
			if j == i or up.is_down() or shield.has(order[j]):
				continue
			var p := Vector3(up.global_position.x, 0.0, up.global_position.z)
			var t := 0.0 if ab.length_squared() < 1e-6 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var q := a + ab * t
			var d := p.distance_to(q)
			var keep := up.body_radius() + downed_radius
			if d >= keep:
				continue
			var side := Vector3(-ab.z, 0.0, ab.x).normalized() if ab.length_squared() > 1e-6 else Vector3.RIGHT
			var n := (p - q) / d if d >= 1e-4 else side      # on his centre line (he fell onto the hitter): out to one side
			up.global_position += n * minf(keep - d + maxf(-Vector3(up.velocity.x, 0.0, up.velocity.z).dot(n), 0.0) / 60.0, downed_push)   # and this frame's step into him
			var into := Vector3(up.velocity.x, 0.0, up.velocity.z).dot(n)
			if into < 0.0:
				up.shove(-n * into * up.body_mass)

func reset() -> void:
	windups.clear()
	body_until.clear()
	swings.clear()
	grace_until.clear()
	ready_at.clear()
	cross_ready.clear()
	release_hold()

func state() -> Dictionary:
	var s := {"given": counts.duplicate(true), "by": by_id.duplicate(), "tries": tries.duplicate(), "down_frames": down_frames.duplicate(), "side_down": side_down.duplicate()}
	for id: String in order:
		var sk: TLBiped = skaters[id]
		if sk.is_down():
			s.get_or_add("down", {})[id] = sk.down_frames_left()
		elif sk.is_stumbling():
			s.get_or_add("stumbling", {})[id] = 1
		if graced(id):
			s.get_or_add("grace", {})[id] = mini(grace_frames, int(grace_until[id]) - _now + 1)
	if hold_age > 0:
		s["hold_frames"] = hold_age
		s["braced"] = is_braced(human)
		s["spent"] = hold_spent
	if not swings.is_empty():
		s["swings"] = swings.duplicate(true)
	if not last_hit.is_empty():
		s["last"] = last_hit.duplicate()
	if not windups.is_empty():
		s["windups"] = windups.duplicate(true)
	for i in bodies.size():
		if (bodies[i] as TLBiped).is_down():
			var seg := _lying(i)
			s.get_or_add("lying", {})[order[i]] = [snappedf(seg[0].x, 0.001), snappedf(seg[0].z, 0.001), snappedf(seg[1].x, 0.001), snappedf(seg[1].z, 0.001)]
	return s
