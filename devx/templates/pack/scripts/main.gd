extends Node
## {{title}}: a starting point. Balls roll down a ramp; "nudge" (Space) pushes them toward the finish line.
## Replace the ramp with your game. Where things come from:
##   data/tuning.json   every number a designer would turn
## Habits to keep (engine/seeds/README.md): time is `frame`, randomness is ctx.rng, signal handlers set flags and
## _pack_tick acts on them, bodies come from TLBodies (never RigidBody3D.new()).

var ctx
var balls: Array = []
var nudges: int = 0
var finish_x: float = 12.0


func _pack_setup(c) -> void:
	ctx = c
	var tuning: Dictionary = ctx.read_json("tuning.json")
	finish_x = float(tuning["finish_x"])
	ctx.root.add_child(TLBodies.ground(Vector2(40, 20), "concrete"))
	# kerbs keep every body on the floor (a body below y = -50 fails the budget check)
	for wall: Array in [[Vector3(40, 2, 0.5), Vector3(0, 1, 10)], [Vector3(40, 2, 0.5), Vector3(0, 1, -10)],
			[Vector3(0.5, 2, 20), Vector3(20, 1, 0)], [Vector3(0.5, 2, 20), Vector3(-20, 1, 0)]]:
		ctx.root.add_child(TLBodies.make(&"box", wall[0], "concrete", {"position": wall[1]}))
	ctx.root.add_child(TLBodies.make(&"box", Vector3(8, 0.3, 6), str(tuning["ramp_material"]),
		{"position": Vector3(-4, 1.2, 0), "rotation_degrees": Vector3(0, 0, -float(tuning["ramp_angle_degrees"])), "name": "Ramp"}))
	for p: Array in tuning["balls"]:
		var ball: PhysicsBody3D = TLBodies.make(&"sphere", float(tuning["ball_radius"]), str(tuning["ball_material"]),
			{"dynamic": true, "position": Vector3(float(p[0]), float(p[1]), float(p[2]))})
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


## Everything a bot needs to play blind. It is hashed: same seed, same state.
func _pack_state() -> Dictionary:
	var lead: float = -INF
	var past: int = 0
	for ball: RigidBody3D in balls:
		lead = maxf(lead, ball.global_position.x)
		if ball.global_position.x > finish_x:
			past += 1
	return {"nudges": nudges, "past_finish": past, "lead_x": lead}
