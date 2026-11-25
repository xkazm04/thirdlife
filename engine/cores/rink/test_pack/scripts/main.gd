extends Node
## Rink core probe (engine/cores/rink, lane K1): thirdjam's regular 5 v 5 run by the native core through the kernel's one
## door, ctx.cores.open. The human's skater takes ctx.input (raw keys to thirdjam's FJamInput); the other nine are
## thirdjam's bots. Nothing is drawn: this pack exists so the runner's determinism laws (same seed and input, same hash;
## a replay; a window) are checked on the core. _pack_state is ctx.cores.state(): the core's hash, frame and score.

var ctx
var rink: Object = null


func _pack_setup(c) -> void:
	ctx = c
	rink = ctx.cores.open("rink", "hockey.regular.cartridge.json")
	if rink == null:
		return
	rink.set_difficulty("pro")
	rink.set_human_mode("input")
	rink.reset(ctx.seed)
	ctx.input.declare(&"left", [KEY_A])
	ctx.input.declare(&"right", [KEY_D])
	ctx.input.declare(&"up", [KEY_W])
	ctx.input.declare(&"down", [KEY_S])
	ctx.input.declare(&"sprint", [KEY_SHIFT])
	ctx.input.declare(&"shoot", [KEY_SPACE])
	ctx.input.declare(&"pass", [KEY_E])
	ctx.input.declare(&"check", [KEY_Q])


func _pack_start() -> void:
	pass


func _pack_tick(_frame: int) -> void:
	if rink == null:
		return
	var m: Vector2 = ctx.input.vector(&"left", &"right", &"down", &"up")
	rink.set_human_input({"Move": m, "bSprint": ctx.input.pressed(&"sprint"), "bShootHeld": ctx.input.pressed(&"shoot"),
		"bPass": ctx.input.just_pressed(&"pass"), "bCheck": ctx.input.just_pressed(&"check")})
	rink.step()
	if _frame % 600 == 599:
		ctx.info("RINKPROBE frame=%d core=%s" % [int(rink.get_frame()), str(rink.state_hash_hex())])


func _pack_state() -> Dictionary:
	return ctx.cores.state()
