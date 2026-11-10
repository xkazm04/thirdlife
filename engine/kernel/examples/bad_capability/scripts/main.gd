extends Node
## Deliberately bad: uses TLBodies (capability "physics") while pack.json declares only "input".


func _pack_setup(ctx) -> void:
	ctx.root.add_child(TLBodies.ground(Vector2(30, 30), "concrete"))


func _pack_start() -> void:
	pass
