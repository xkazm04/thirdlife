extends Node
## Deliberately bad: the kick a player gives the crate comes from the global random generator. Nothing random happens
## while nobody presses anything, so two idle runs agree (`invariants.determinism` passes) and only two bot runs with
## one seed differ (`invariants.bot_deterministic` fails). (lint also rejects this file: randf( is outside the fence.)

var ctx
var crate: RigidBody3D
var kicks: int = 0


func _pack_setup(c) -> void:
	ctx = c
	ctx.root.add_child(TLBodies.ground(Vector2(60, 60), "concrete"))
	crate = TLBodies.make(&"box", Vector3(1, 1, 1), "wood", {"dynamic": true, "mass": 20.0, "position": Vector3(0, 0.5, 0)})
	ctx.root.add_child(crate)
	ctx.input.declare(&"kick", [KEY_SPACE])


func _pack_start() -> void:
	pass


func _pack_tick(_frame: int) -> void:
	if ctx.input.just_pressed(&"kick"):
		kicks += 1
		TLBodies.push(crate, Vector3((randf() - 0.5) * 200.0, 60.0, (randf() - 0.5) * 200.0))


func _pack_state() -> Dictionary:
	return {"kicks": kicks}
