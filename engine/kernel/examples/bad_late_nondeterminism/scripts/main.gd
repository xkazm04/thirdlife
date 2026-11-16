extends Node
## Deliberately bad, late: the two runs `invariants` compares agree for 437 frames, then differ. At frame 437 the crate
## is sent off with the global random generator (its velocity is set inside _pack_tick, so frame 437 itself already
## differs, before the physics step). A press of `flip` adds randi() to the state and leaves every body alone. The
## selftest's diverge.* cases check that the report names the frame and the part: `body World/Crate`, `_pack_state.flips`.
## (lint also rejects this file: randf( and randi( are outside the fence.)

const PUSH_AT: int = 437

var ctx
var crate: RigidBody3D
var flips: int = 0


func _pack_setup(c) -> void:
	ctx = c
	ctx.root.add_child(TLBodies.ground(Vector2(60, 60), "concrete"))
	crate = TLBodies.make(&"box", Vector3(1, 1, 1), "wood", {"dynamic": true, "name": "Crate", "position": Vector3(0, 0.5, 0)})
	ctx.root.add_child(crate)
	ctx.input.declare(&"flip", [KEY_F])


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	if frame == PUSH_AT:
		crate.linear_velocity = Vector3(1.0 + randf() * 4.0, 2.0 + randf() * 4.0, 0.0)
	if ctx.input.just_pressed(&"flip"):
		flips += 1 + randi() % 1000


func _pack_state() -> Dictionary:
	return {"flips": flips}
