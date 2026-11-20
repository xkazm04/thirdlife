extends Node
## L4b fixture (selftest 640 dungeon.watchdog): a floor and a ball, then at frame 60 one step that never returns. The
## dungeon's watchdog (kernel/dungeon/watch.gd) must end it to a card with Leave. Never a game.

var ctx
var spins: int = 0


func _pack_setup(c) -> void:
	ctx = c
	ctx.root.add_child(TLBodies.ground(Vector2(20, 20), "concrete"))
	ctx.root.add_child(TLBodies.make(&"sphere", 0.5, "rubber", {"dynamic": true, "position": Vector3(0, 3, 0)}))
	ctx.cameras.add_view(&"hero", Vector3(0, 4, 9), Vector3(0, 0.5, 0), 55.0)


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	if frame == 60:
		while true:
			spins += 1
