extends Node
## Deliberately bad: a crate with no floor under it falls below y = -50 (V3 budget "below_ground").


func _pack_setup(ctx) -> void:
	ctx.root.add_child(TLBodies.make(&"box", Vector3(1, 1, 1), "wood", {"dynamic": true, "position": Vector3(0, 2, 0)}))


func _pack_start() -> void:
	pass
