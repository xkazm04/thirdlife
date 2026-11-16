extends Node
## Deliberately bad, three ways a world used to report other than the runner alone (kernel/runner/pack_life.gd):
## a crate with no floor falls below y = -50, a node gets this script after add_child (its _physics_process never
## runs), and the bot's _bot_result has no summary (tests/bot.gd). Also the probe pack of runner/life_case.gd: each
## tick draws from the seeded generator, so the state hash moves every frame.

var ticks: int = 0
var drawn: int = 0
var _ctx


func _pack_setup(ctx) -> void:
	_ctx = ctx
	ctx.root.add_child(TLBodies.make(&"box", Vector3(1, 1, 1), "wood", {"dynamic": true, "position": Vector3(0, 2, 0)}))
	var late: Node = Node.new()
	late.name = "Late"
	ctx.root.add_child(late)
	late.set_script(get_script())


func _pack_start() -> void:
	pass


func _pack_tick(_frame: int) -> void:
	ticks += 1
	drawn = _ctx.rng.randi_range(0, 999)


func _physics_process(_delta: float) -> void:
	pass


func _pack_state() -> Dictionary:
	return {"ticks": ticks, "drawn": drawn}
