extends Node
## seed.paddle: ball and paddle on a walled ice court. The player moves the blue paddle (actions left / right), an AI
## moves the red one, a ball behind a paddle is a point for the other side, first to five wins (data/rules.json).
##
## Where things come from:
##   data/court.json   the venue (tl.layout/1): terrain, walls, floor, ball, paddles, scenery, the two cameras
##   data/rules.json   TLRules config: sides and score_to_win
##   data/tuning.json  speeds and angles
## This script is the glue: it turns three layout props into bodies, wires two goal triggers to the rules, and
## decides what a paddle hit does to the ball. Game logic runs in _pack_tick; signal handlers only set flags.

const SIDES: Array = ["player", "rival"]

var ctx
var tune: Dictionary
var rules: TLRules
var hud: TLHud
var ball: TLBall
var paddles: Dictionary = {}          # side -> RigidBody3D, locked to slide along z only
var home: Vector3                     # where the ball is served from (its place in court.json)
var reach: float = 0.0                # how far a paddle centre may be from the middle of the court
var half_len: float = 1.0             # half the paddle length
var rally: int = 0                    # paddle hits since the serve: each one makes the ball a little faster
var serve_frame: int = 0              # frame of the next serve; -1 while the ball is in play
var serve_toward: String = ""         # side the next serve flies to
var still_frames: int = 0             # frames the ball has been nearly at rest (a dead ball is served again)
var _hit_by: String = ""              # flag from the ball's contact signal
var _conceded: String = ""            # flag from a goal trigger


func _pack_setup(c) -> void:
	ctx = c
	tune = ctx.read_json("tuning.json")
	var built: Dictionary = TLKit.build_layout(ctx.read_json("court.json"), ctx.root)
	if not built["ok"]:
		push_error("court.json does not build: %s" % "; ".join(built["errors"]))
		return
	var nodes: Dictionary = built["nodes"]

	# The kit's ball and paddles are visuals with no body (the dynamic-prop convention). The kernel makes the
	# bodies: TLBall for the ball; TLBodies.from_part for a paddle, locked so it can only slide along z.
	var ball_part: Node3D = nodes["ball"]
	home = ball_part.global_position
	ball = TLBall.create({"part": ball_part, "position": home, "planar": true, "group": "balls",
		"max_speed": float(tune["ball"]["max_speed"]), "name": "Ball"})
	ctx.root.add_child(ball)
	ball.bounced.connect(_on_ball_bounced)
	for side: String in SIDES:
		var part: Node3D = nodes["paddle_" + side]
		half_len = float(part.get_meta(&"tl_params")["length"]) * 0.5
		var paddle: RigidBody3D = TLBodies.from_part(part, {"position": part.global_position, "rotation_degrees": part.global_rotation_degrees,
			"mass": float(tune["paddle"]["mass"]), "lock": ["x", "y", "rx", "ry", "rz"], "name": "Paddle_" + side})
		ctx.root.add_child(paddle)
		paddles[side] = paddle
		# the goal: a trigger behind the paddle, as wide as the court; only bodies in the group "balls" count
		var depth: float = float(tune["court"]["goal_depth"])
		var x: float = paddle.position.x + signf(paddle.position.x) * (0.9 + depth * 0.5)
		var goal: TLTrigger = TLBodies.trigger(&"box", Vector3(depth, 2.0, float(tune["court"]["half_width"]) * 2.0),
			{"position": Vector3(x, 1.0, 0), "group_filter": "balls", "name": "Goal_" + side})
		ctx.root.add_child(goal)
		goal.entered.connect(_on_goal.bind(side))
	reach = float(tune["court"]["half_width"]) - half_len - 0.05

	rules = TLRules.create(ctx.read_json("rules.json"))
	ctx.root.add_child(rules)
	hud = TLHud.create()
	ctx.root.add_child(hud)
	hud.add_score(rules, "player", &"top_left", "YOU")
	hud.add_score(rules, "rival", &"top_right", "RIVAL")
	hud.add_label(&"hint", "A / D or the arrow keys move your paddle. First to %d." % rules.score_to_win, &"bottom")
	rules.finished.connect(func(winner: String, _reason: String) -> void: hud.set_text(&"hint", "%s wins" % winner.to_upper()))

	ctx.input.declare(&"left", [KEY_A, KEY_LEFT])
	ctx.input.declare(&"right", [KEY_D, KEY_RIGHT])
	for cam: String in built["cams"]:
		var v: Dictionary = built["cams"][cam]
		ctx.cameras.add_view(StringName(cam), v["pos"], v["look"], float(v["fov"]))


func _pack_start() -> void:
	rules.start()
	serve_toward = ctx.pick(SIDES)                 # seeded: a different --seed starts the other way
	serve_frame = ctx.frames(float(tune["ball"]["serve_delay_seconds"]))


func _on_ball_bounced(other: Node, _speed: float) -> void:
	for side: String in SIDES:
		if other == paddles[side]:
			_hit_by = side


func _on_goal(_ball: Node3D, side: String) -> void:
	_conceded = side


func _pack_tick(frame: int) -> void:
	if rules.is_over():
		for side: String in SIDES:
			TLBodies.drive(paddles[side], Vector3.ZERO)
		return
	# 1. paddles. The player: one axis from two actions. The rival: TLSteer says where the ball will be when it
	#    arrives and how hard to go there; it returns to the middle while the ball flies away from it.
	_drive("player", ctx.input.axis(&"left", &"right") * float(tune["paddle"]["speed"]))
	var rival: RigidBody3D = paddles["rival"]
	var target_z: float = 0.0
	if ball.linear_velocity.x > 0.0:
		target_z = TLSteer.intercept_point(rival.global_position, ball.speed(), ball.global_position, ball.linear_velocity).z
	var want: Vector3 = TLSteer.arrive(rival.global_position, Vector3(rival.global_position.x, 0, target_z), float(tune["rival"]["slow_radius"]))
	_drive("rival", want.z * float(tune["rival"]["speed"]))

	# 2. a goal: the other side scores, the ball goes back to the middle and is served to the side that conceded
	if _conceded != "":
		if serve_frame < 0:
			rules.add_score("rival" if _conceded == "player" else "player")
			_next_serve(_conceded, frame)
		_conceded = ""
	# 3. a paddle hit: send the ball back; where it met the paddle sets the angle (the edge gives the steepest)
	if _hit_by != "":
		if serve_frame < 0:
			_return_ball(paddles[_hit_by])
		_hit_by = ""
	# 4. the serve
	if serve_frame >= 0 and frame >= serve_frame and not rules.is_over():
		var spread: float = deg_to_rad(ctx.rng.randf_range(-1.0, 1.0) * float(tune["ball"]["serve_spread"]))
		var dir_x: float = -1.0 if serve_toward == "player" else 1.0
		ball.shoot_at(ball.global_position + Vector3(dir_x * cos(spread), 0, sin(spread)), float(tune["ball"]["serve_speed"]))
		serve_frame = -1
		rally = 0
	# 5. a dead ball (stuck in a corner, or stopped): serve again, no point
	still_frames = still_frames + 1 if serve_frame < 0 and ball.speed() < float(tune["ball"]["dead_ball_speed"]) else 0
	if still_frames > ctx.frames(float(tune["ball"]["dead_ball_seconds"])):
		_next_serve(serve_toward, frame)


## Moves a paddle along z at `speed`, and not past the side walls.
func _drive(side: String, speed: float) -> void:
	var paddle: RigidBody3D = paddles[side]
	if absf(paddle.position.z) >= reach and signf(speed) == signf(paddle.position.z):
		speed = 0.0
	TLBodies.drive(paddle, Vector3(0, 0, speed), float(tune["paddle"]["accel"]))


func _return_ball(paddle: RigidBody3D) -> void:
	var away: float = -signf(paddle.position.x)                       # toward the other end
	if (ball.global_position.x - paddle.position.x) * away < 0.0:
		return                                                         # it touched the back of the paddle: no return
	var offset: float = clampf((ball.global_position.z - paddle.position.z) / half_len, -1.0, 1.0)
	var angle: float = deg_to_rad(offset * float(tune["ball"]["max_angle"]))
	rally += 1
	var speed: float = minf(float(tune["ball"]["serve_speed"]) + rally * float(tune["ball"]["speed_step"]), float(tune["ball"]["max_speed"]))
	ball.shoot_at(ball.global_position + Vector3(away * cos(angle), 0, sin(angle)), speed)


func _next_serve(toward: String, frame: int) -> void:
	ball.place(home)
	serve_toward = toward
	serve_frame = frame + ctx.frames(float(tune["ball"]["serve_delay_seconds"]))
	still_frames = 0


## What a bot (and the state hash) sees: the rules snapshot plus where the ball and the paddles are.
func _pack_state() -> Dictionary:
	var s: Dictionary = rules.snapshot()
	s["ball"] = {"x": ball.global_position.x, "z": ball.global_position.z, "vx": ball.linear_velocity.x, "vz": ball.linear_velocity.z}
	s["player_z"] = paddles["player"].position.z
	s["player_x"] = paddles["player"].position.x
	s["rival_z"] = paddles["rival"].position.z
	s["rally"] = rally
	s["in_play"] = serve_frame < 0
	s["court"] = {"half_width": float(tune["court"]["half_width"]), "ball_radius": ball.radius, "paddle_half": half_len}
	s["hud"] = {"player": hud.text_of(&"score_player"), "hint": hud.text_of(&"hint")}
	return s
