extends Node
## Three parallel runs. Sample the completed physics step before issuing new
## intents. Row C switches to walking ten ticks into its 120-tick stun.
const RUN := 240
const STUN_AT := 230
const END := 400

var pairs: Array = []
var stats: Array = []
var stun_origin := Vector2.ZERO
var stunned_last_tick := false
var done := false


func _pack_setup(ctx) -> void:
	ctx.root.add_child(TLBodies.ground(Vector2(44, 22), "concrete"))
	for row in 3:
		var pair: Array[TLBiped] = []
		for side in 2:
			var b := TLBiped.create({"name": "%s%d" % [["A", "B", "C"][row], side],
				"position": Vector3(-4 + 8 * side, 0.01, (row - 1) * 6),
				"facing": -PI / 2 if side == 0 else PI / 2, "mode": "walk",
				"rig_params": {"backpack": false, "colors": {"top": "car_red" if side == 0 else "car_blue"}}})
			ctx.root.add_child(b)
			if row > 0:
				TLHit.pushbox(b)
			pair.append(b)
		pairs.append(pair)
		var capsule_sum := pair[0].body_radius() + pair[1].body_radius()
		stats.append({"row": ["A", "B", "C"][row], "min_centres": 8.0, "capsule_sum": capsule_sum,
			"radii_sum": capsule_sum + (0.04 if row > 0 else 0.0)})
	ctx.cameras.add_view(&"play", Vector3(6, 15, 9), Vector3.ZERO, 55.0)


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	if done:
		return
	for row in 3:
		var a: TLBiped = pairs[row][0]
		var b: TLBiped = pairs[row][1]
		var pos_a := Vector2(a.position.x, a.position.z)
		var pos_b := Vector2(b.position.x, b.position.z)
		var s: Dictionary = stats[row]
		s.min_centres = minf(s.min_centres, pos_a.distance_to(pos_b))
		if row == 2:
			if frame == STUN_AT:
				s["contact"] = TLHit.guard_break(a, b, {"push": 0.0, "frames": 120})
				stun_origin = pos_b
				s["stunned_travel"] = 0.0
				s["stunned_ticks"] = 0
			# Read the completed step only if the body entered it stunned and unfrozen.
			if stunned_last_tick:
				s.stunned_travel = pos_b.x - stun_origin.x
				s.stunned_ticks += 1
			stunned_last_tick = TLHit.stun_of(b) == &"guardbroken" and TLHit.stop_left(b) == 0
		a.move(Vector3.RIGHT, frame < RUN)
		b.move(Vector3.LEFT, frame < RUN)
	done = frame >= END


func _pack_state() -> Dictionary:
	return {"done": done, "pairs": stats}
