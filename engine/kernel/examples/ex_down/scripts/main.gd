extends Node
## Primitive example (K2): TLBiped down / shove / stumble, and a body sized with its rig.
## - The skater (skate mode) skates on "forward"; "knock" puts him down for 90 frames, "stumble" makes him stumble for
##   30, "shove" shoves the walker sideways. The skater keeps "forward" held through all of it, as a person would.
## - Two pairs of figures whose rigs are scaled 2.2 times (as the hockey pack does) walk into each other: the left pair
##   keeps today's body (the rig's metrics at scale 1), the right pair is sized with `body_scale` 2.2. Measured: the
##   least distance between the centres of each pair.
## The camera "above" stands where the hockey camera stands (0, 52, 14), fov 55; "near" is a closer look.

const SCALE: float = 2.2
var ctx
var skater: TLBiped
var walker: TLBiped
var pairs: Array = []            # [[a, b], [a, b]]: today's body, sized body
var least: Array = [1000.0, 1000.0]
var ticks: int = 0
var downed_at: int = -1
var got_up_at: int = -1
var down_frames: int = 0
var speed_at_down: float = 0.0
var speed_gain_while_down: float = 0.0   # the largest frame-to-frame speed rise while down: 0 when move is ignored
var facing_turn_while_down: float = 0.0
var last_speed: float = 0.0
var last_facing: float = 0.0
var hud: TLHud


func _pack_setup(c) -> void:
	ctx = c
	ctx.root.add_child(TLBodies.ground(Vector2(80, 60), "ice", 0.0, Vector3.ZERO))
	skater = TLBiped.create({"position": Vector3(-8, 0.05, 6), "mode": "skate", "name": "Skater", "facing": -PI / 2.0})
	ctx.root.add_child(skater)
	walker = TLBiped.create({"position": Vector3(8, 0.05, 6), "name": "Walker"})
	ctx.root.add_child(walker)
	skater.downed.connect(_on_downed)
	skater.got_up.connect(_on_got_up)
	for i: int in 2:
		var x: float = -6.0 if i == 0 else 6.0
		var a: TLBiped = TLBiped.create({"position": Vector3(x, 0.05, -8), "name": "Pair%dA" % i, "facing": PI})
		var b: TLBiped = TLBiped.create({"position": Vector3(x, 0.05, -2), "name": "Pair%dB" % i})
		for f: TLBiped in [a, b]:
			f.rig.scale = Vector3(SCALE, SCALE, SCALE)
			if i == 1:
				f.set_body_scale(SCALE)
			ctx.root.add_child(f)
		pairs.append([a, b])
	ctx.input.declare(&"knock", [KEY_K], [MOUSE_BUTTON_LEFT])     # K2: the left button knocks him down too
	for action: Array in [[&"forward", KEY_W], [&"stumble", KEY_J], [&"shove", KEY_L]]:
		ctx.input.declare(action[0], [action[1]])
	ctx.cameras.add_view(&"above", Vector3(0, 52, 14), Vector3(0, 0, 0), 55.0)
	ctx.cameras.add_view(&"near", Vector3(0, 16, 16), Vector3(0, 0, 0), 55.0)
	hud = TLHud.create()
	ctx.root.add_child(hud)
	hud.add_bound(&"state", _hud_text, &"top_left")


func _hud_text() -> String:
	return "skater %s   frames down %d" % ["DOWN" if skater.is_down() else "up", down_frames]


func _on_downed() -> void:
	downed_at = ticks
	speed_at_down = skater.speed()


func _on_got_up() -> void:
	got_up_at = ticks


func _pack_start() -> void:
	pass


func _pack_tick(_frame: int) -> void:
	ticks += 1
	if skater.is_down():
		down_frames += 1
		speed_gain_while_down = maxf(speed_gain_while_down, skater.speed() - last_speed)
		facing_turn_while_down = maxf(facing_turn_while_down, absf(wrapf(skater.rotation.y - last_facing, -PI, PI)))
	last_speed = skater.speed()
	last_facing = skater.rotation.y
	# the skater skates toward +x while "forward" is held (his move is ignored while he is down)
	skater.move(Vector3(1, 0, 0) if ctx.input.pressed(&"forward") else Vector3.ZERO)
	if ctx.input.just_pressed(&"knock"):
		skater.down(90)
	if ctx.input.just_pressed(&"stumble"):
		skater.stumble(30)
	if ctx.input.just_pressed(&"shove"):
		walker.shove(Vector3(0, 0, -400))     # 400 N s on 80 kg: 5 m/s
	walker.move(Vector3.ZERO)
	for i: int in 2:
		var a: TLBiped = pairs[i][0]
		var b: TLBiped = pairs[i][1]
		a.move(Vector3(0, 0, 1))
		b.move(Vector3(0, 0, -1))
		var d: Vector3 = a.global_position - b.global_position
		d.y = 0.0
		least[i] = minf(float(least[i]), d.length())


func _pack_state() -> Dictionary:
	return {"ticks": ticks, "downed_at": downed_at, "got_up_at": got_up_at, "down_frames": down_frames,
		"is_down": skater.is_down(), "skater_speed": skater.speed(), "skater_x": skater.global_position.x,
		"speed_at_down": speed_at_down, "speed_gain_while_down": speed_gain_while_down,
		"facing_turn_while_down": facing_turn_while_down, "walker_down": walker.is_down(),
		"walker_z": walker.global_position.z, "walker_speed": walker.speed(),
		"least_today": float(least[0]), "least_sized": float(least[1]),
		"body_today": pairs[0][0].body_radius(), "body_sized": pairs[1][0].body_radius(), "hud": _hud_text()}
