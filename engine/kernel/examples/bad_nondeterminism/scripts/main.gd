extends Node
## Deliberately bad: a body is placed with the global random generator, so two runs with one seed differ.
## (lint also rejects this file: randf( is outside the fence.)


func _pack_setup(ctx) -> void:
	ctx.root.add_child(TLBodies.ground(Vector2(30, 30), "concrete"))
	ctx.root.add_child(TLBodies.make(&"box", Vector3(1, 1, 1), "wood", {"dynamic": true, "position": Vector3(randf() * 4.0, 3.0, 0.0)}))


func _pack_start() -> void:
	pass
