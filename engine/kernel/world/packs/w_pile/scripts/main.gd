extends Node
## Bench pack for tools/world.sh bench (N2), not a game. The SEED is the body count: `--seeds=300` drops 300 wooden
## boxes into a walled yard and keeps kicking them, so they stay awake (an active scene of that size). A seed of
## 10000 + N drops N boxes and leaves them alone: they settle and fall asleep (a venue between rounds).
## Every box comes from TLBodies.make, so each carries the kernel's contact tracker, like any pack body.

var ctx
var boxes: Array = []
var calm: bool = false
var kicks: int = 0


func _pack_setup(c) -> void:
	ctx = c
	calm = ctx.seed >= 10000
	var count: int = ctx.seed % 10000
	ctx.root.add_child(TLBodies.ground(Vector2(24, 24), "concrete"))
	for wall: Array in [[Vector3(24, 6, 0.5), Vector3(0, 3, 12)], [Vector3(24, 6, 0.5), Vector3(0, 3, -12)],
			[Vector3(0.5, 6, 24), Vector3(12, 3, 0)], [Vector3(0.5, 6, 24), Vector3(-12, 3, 0)]]:
		ctx.root.add_child(TLBodies.make(&"box", wall[0], "concrete", {"position": wall[1]}))
	for i: int in count:
		var layer: int = i / 100
		var cell: int = i % 100
		var at: Vector3 = Vector3(-9.0 + float(cell % 10) * 2.0 + ctx.rng.randf_range(-0.2, 0.2), 0.6 + float(layer) * 0.9,
			-9.0 + float(cell / 10) * 2.0 + ctx.rng.randf_range(-0.2, 0.2))
		var box: PhysicsBody3D = TLBodies.make(&"box", Vector3(0.5, 0.5, 0.5), "wood", {"dynamic": true, "position": at})
		ctx.root.add_child(box)
		boxes.append(box)


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	if calm or boxes.is_empty() or frame % 4 != 0:
		return
	# keep the yard busy: a few boxes are thrown toward the middle every fourth frame
	for n: int in maxi(1, boxes.size() / 25):
		var box: RigidBody3D = ctx.pick(boxes)
		var to_mid: Vector3 = Vector3(-box.position.x, 0.0, -box.position.z).normalized()
		TLBodies.push(box, (to_mid * 2.5 + Vector3(0, 3.0, 0)) * box.mass)
		kicks += 1


func _pack_state() -> Dictionary:
	var awake: int = 0
	for box: RigidBody3D in boxes:
		if not box.sleeping:
			awake += 1
	return {"boxes": boxes.size(), "awake": awake, "kicks": kicks}
