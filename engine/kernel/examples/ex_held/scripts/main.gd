extends Node
## Primitive example (K2): a held ball is never a moving floor. A carrier node holds a big ball (TLBall.hold) and
## shakes it from side to side, fast, as a carried puck is moved every frame; a skater stands on the ball and, on the
## action "go", skates off it. Measured: the skater's top speed after he left the ball. A held ball that acted as a
## platform would hand him its own velocity when he leaves (the hockey pack saw 47 m/s).

const RADIUS: float = 0.6
var ctx
var carrier: Node3D
var ball: TLBall
var rider: TLBiped
var ticks: int = 0
var on_ball_frames: int = 0
var left_at: int = -1
var top_speed_after: float = 0.0
var top_speed_on: float = 0.0
var ball_peak: float = 0.0           # the held ball's own speed, from its positions: what a platform would hand on
var ball_last: Vector3 = Vector3.ZERO


func _pack_setup(c) -> void:
	ctx = c
	ctx.root.add_child(TLBodies.ground(Vector2(80, 80), "ice", 0.0, Vector3.ZERO))
	carrier = Node3D.new()
	carrier.name = "Carrier"
	carrier.position = Vector3(0, RADIUS, 0)
	ctx.root.add_child(carrier)
	ball = TLBall.create({"kind": &"ball", "radius": RADIUS, "material": "rubber", "mass": 20.0, "position": Vector3(0, RADIUS, 0), "name": "Ball"})
	ctx.root.add_child(ball)
	ball.hold(carrier)
	rider = TLBiped.create({"position": Vector3(0, RADIUS * 2.0 + 0.02, 0), "mode": "skate", "name": "Rider"})
	ctx.root.add_child(rider)
	ctx.input.declare(&"go", [KEY_W])
	ctx.cameras.add_view(&"side", Vector3(0, 4, 14), Vector3(0, 1, 0), 55.0)


func _pack_start() -> void:
	pass


func _pack_tick(_frame: int) -> void:
	ticks += 1
	# the carrier shakes the ball: 1.2 m either side, a period of 24 frames (peak 19 m/s), as a stick moves a puck
	carrier.position = Vector3(1.2 * sin(float(ticks) * TAU / 24.0), RADIUS, 0.0)
	if ticks > 1:
		ball_peak = maxf(ball_peak, (carrier.position - ball_last).length() * 60.0)
	ball_last = carrier.position
	rider.move(Vector3(0, 0, -1) if ctx.input.pressed(&"go") else Vector3.ZERO)
	var flat: Vector3 = rider.global_position - ball.global_position
	flat.y = 0.0
	var on: bool = rider.global_position.y > RADIUS * 1.5 and flat.length() < RADIUS + 0.35
	if on:
		on_ball_frames += 1
		top_speed_on = maxf(top_speed_on, rider.speed())
	elif left_at < 0 and on_ball_frames > 0:
		left_at = ticks
	if left_at >= 0:
		top_speed_after = maxf(top_speed_after, rider.speed())


func _pack_state() -> Dictionary:
	return {"ticks": ticks, "on_ball_frames": on_ball_frames, "left_at": left_at, "top_speed_after": top_speed_after,
		"top_speed_on": top_speed_on, "ball_peak": ball_peak, "rider_x": rider.global_position.x, "rider_y": rider.global_position.y,
		"rider_z": rider.global_position.z, "rider_speed": rider.speed(), "skate_speed": rider.skate_speed}
