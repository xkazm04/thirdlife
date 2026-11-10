extends Node
## Minimal pack: a few rubber balls dropped on a wooden ramp roll onto a concrete floor. No game, just the lifecycle:
## data from data/, randomness from ctx.rng, bodies from the kernel, one input action, one capture view, one bot.

var ctx
var balls: Array = []
var nudges: int = 0
var finish_x: float = 6.0


func _pack_setup(c) -> void:
	ctx = c
	var tuning: Dictionary = ctx.read_json("tuning.json")
	finish_x = float(tuning["finish_x"])
	ctx.root.add_child(TLBodies.ground(Vector2(40, 20), "concrete"))
	# kerbs keep every ball on the floor (the V3 budget fails a pack whose bodies fall below y = -50)
	for wall: Array in [[Vector3(40, 2, 0.5), Vector3(0, 1, 10)], [Vector3(40, 2, 0.5), Vector3(0, 1, -10)],
			[Vector3(0.5, 2, 20), Vector3(20, 1, 0)], [Vector3(0.5, 2, 20), Vector3(-20, 1, 0)]]:
		ctx.root.add_child(TLBodies.make(&"box", wall[0], "concrete", {"position": wall[1]}))
	ctx.root.add_child(TLBodies.make(&"box", Vector3(8, 0.3, 6), str(tuning["ramp_material"]),
		{"position": Vector3(-4, 1.2, 0), "rotation_degrees": Vector3(0, 0, -float(tuning["ramp_angle_degrees"])), "name": "Ramp"}))
	for start: Vector3 in ctx.root.get_meta("ball_starts"):
		var ball: PhysicsBody3D = TLBodies.make(&"sphere", float(tuning["ball_radius"]), str(tuning["ball_material"]),
			{"dynamic": true, "position": start})
		ctx.root.add_child(ball)
		balls.append(ball)
	ctx.input.declare(&"nudge", [KEY_SPACE])
	ctx.cameras.add_view(&"hero", Vector3(4, 5, 12), Vector3(0, 1, 0), 55.0)


func _pack_start() -> void:
	ctx.info("%d balls released" % balls.size())


func _pack_tick(_frame: int) -> void:
	if ctx.input.just_pressed(&"nudge"):
		nudges += 1
		for ball: RigidBody3D in balls:
			TLBodies.push(ball, Vector3(ball.mass * 2.0, 0, 0))


func _pack_state() -> Dictionary:
	return {"nudges": nudges, "past_finish": past_finish(), "lead_x": lead_x()}


func past_finish() -> int:
	var n: int = 0
	for ball: RigidBody3D in balls:
		if ball.global_position.x > finish_x:
			n += 1
	return n


func lead_x() -> float:
	var best: float = -INF
	for ball: RigidBody3D in balls:
		best = maxf(best, ball.global_position.x)
	return best
