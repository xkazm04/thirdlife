extends Node
## Contact is at the same beat in every 110-frame take. The lead-in is timed from
## the rig's Hit column, independently for each hand in the mixed clash.
const TAKES := ["Light hit", "Heavy hit", "Heavy counter-hit", "Light blocked", "Heavy blocked",
	"Light parried", "Heavy parried", "Light clash", "Heavy clash", "Heavy vs light",
	"Open bash", "Bash near wall", "Heavy into wall"]
const PERIOD := 110
const CONTACT := 32
const WALL_X := 2.4
const LEADS := {&"strike": 5, &"strike_heavy": 13, &"body_check": 12, &"block": 4}
const SOCKETS := [&"head", &"hand_r", &"hand_l", &"foot_r", &"foot_l"]

var ctx
var attacker: TLBiped
var defender: TLBiped
var cases: Array = []
var take: Dictionary
var last_ground: Array[Vector2] = []
var before_clip: Array = []
var label := ""
var pose_digest := 0
var done := false


func _pack_setup(c) -> void:
	ctx = c
	ctx.root.add_child(TLBodies.ground(Vector2(14, 10), "concrete"))
	ctx.root.add_child(TLBodies.make(&"box", Vector3(0.4, 2.55, 1.55), "concrete",
		{"position": Vector3(WALL_X + 0.2, 1.275, 0), "name": "Wall"}))
	attacker = _fighter("Attacker", "car_red", -1.1, -PI / 2)
	defender = _fighter("Defender", "car_blue", 0.2, PI / 2)
	ctx.cameras.add_view(&"play", Vector3(0.10, 1.50, 5.0), Vector3(0.10, 1.03, 0), 34.0)
	ctx.cameras.set_subject(&"play", defender)
	var hud := TLHud.create()
	ctx.root.add_child(hud)
	hud.add_bound(&"contact", func() -> String: return label, &"top_left")


func _fighter(body_name: String, color: String, x: float, facing: float) -> TLBiped:
	var b := TLBiped.create({"name": body_name, "mode": "walk", "position": Vector3(x, 0.01, 0),
		"facing": facing, "rig_params": {
		"backpack": false, "colors": {"top": color, "legs": "bot_dark", "boots": "black"}}})
	ctx.root.add_child(b)
	TLHit.pushbox(b)
	return b


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	if done:
		return
	var i := floori(float(frame) / PERIOD)
	var beat := frame % PERIOD
	if beat == 0:
		if not cases.is_empty():
			_measure(frame)
		if i == TAKES.size():
			done = true
			return
		_reset(i)
	var heavy := i in [1, 2, 4, 6, 8, 9, 12]
	var swing := &"strike_heavy" if heavy else &"strike"
	if i in [10, 11]:
		swing = &"body_check"
	# Close the initial 1.3 m gap before the wind-up. Movement after the
	# contact is measured independently, from the two bodies' actual positions.
	attacker.move(Vector3.RIGHT if beat < 10 else Vector3.ZERO)
	defender.move(Vector3.ZERO)
	_play_on_beat(attacker, swing, beat)
	if i in [3, 4, 5, 6]:
		_play_on_beat(defender, &"block", beat)
	elif i in [7, 8, 9]:
		_play_on_beat(defender, &"strike_heavy" if i == 8 else &"strike", beat)
	elif i == 2 and beat == CONTACT - 3:
		defender.rig.play(&"strike_heavy")
	if beat == CONTACT:
		before_clip = [attacker.rig.clip, defender.rig.clip]
		last_ground = [_ground(attacker), _ground(defender)]
		take = {"name": TAKES[i], "frame": frame, "result": _contact(i, heavy),
			"max_busy": [0, 0], "travel": [0.0, 0.0], "clip_changed": [false, false],
			"min_centres": last_ground[0].distance_to(last_ground[1]), "splat": {}}
		take["call"] = [_state(attacker), _state(defender)]
		# Playbook 6.3 gives equal-class clashes one row with two weight trials.
		if i != 8:
			cases.append({"name": "Same-class clash" if i == 7 else TAKES[i], "contacts": []})
		cases.back().contacts.append(take)
	if beat >= CONTACT:
		_measure(frame)
	_digest()


func _reset(i: int) -> void:
	var x := 0.20
	if i == 11:
		x = WALL_X - 1.0
	elif i == 12:
		x = WALL_X - defender.body_radius() - 0.32
	for b: TLBiped in [attacker, defender]:
		TLHit.clear(b)
		b.rig.play(&"")
	attacker.place(Vector3(x - 1.3, 0.01, 0), -PI / 2)
	defender.place(Vector3(x, 0.01, 0), PI / 2)
	label = TAKES[i]


func _play_on_beat(b: TLBiped, clip: StringName, beat: int) -> void:
	if beat == CONTACT - int(LEADS[clip]):
		b.rig.play(clip)


func _contact(i: int, heavy: bool) -> Dictionary:
	match i:
		3, 4: return TLHit.blocked(attacker, defender, heavy)
		5, 6: return TLHit.parried(attacker, defender, heavy)
		7, 8, 9: return TLHit.clash(attacker, defender, heavy, i == 8)
		10, 11: return TLHit.guard_break(attacker, defender)
	return TLHit.hit(attacker, defender, heavy, i == 2)


func _ground(b: TLBiped) -> Vector2:
	return Vector2(b.global_position.x, b.global_position.z)


func _state(b: TLBiped) -> Dictionary:
	return {"stop": TLHit.stop_left(b), "stun": TLHit.stun_of(b), "left": TLHit.stun_left(b)}


func _measure(frame: int) -> void:
	if frame == int(take.frame) + 1:
		take["next"] = [_state(attacker), _state(defender)]
	var bodies := [attacker, defender]
	for n in bodies.size():
		var b: TLBiped = bodies[n]
		var here := _ground(b)
		take.travel[n] += here.distance_to(last_ground[n])
		last_ground[n] = here
		take.max_busy[n] = maxi(take.max_busy[n], TLHit.busy_left(b))
		take.clip_changed[n] = take.clip_changed[n] or before_clip[n] != b.rig.clip
	take.min_centres = minf(take.min_centres, last_ground[0].distance_to(last_ground[1]))
	if TLHit.stun_of(defender) == &"wallsplat" and take.splat.is_empty():
		take.splat = {"frame": frame, "stop": TLHit.stop_left(defender), "left": TLHit.stun_left(defender),
			"wall_gap": WALL_X - defender.global_position.x - defender.body_radius()}


func _digest() -> void:
	var parts := PackedStringArray()
	for b: TLBiped in [attacker, defender]:
		for s: StringName in SOCKETS:
			var socket: Node3D = b.rig.socket(s)
			parts.append(str(socket.global_position.snapped(Vector3.ONE * 0.001)))
	pose_digest = hash(str(pose_digest) + ",".join(parts))


func _pack_state() -> Dictionary:
	return {"done": done, "cases": cases, "pose_digest": pose_digest,
		"radii_sum": attacker.body_radius() + defender.body_radius() + 0.04}
