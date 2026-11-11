extends Node
## P2 profiling pack, not a game: `w_pile` with a MODE in the seed so one command shows where the time of a pile goes.
## seed = MODE * 100000 + (10000 if calm) + N boxes.
##   mode 0: as w_pile (every box carries the kernel's contact tracker)
##   mode 1: boxes made with track=false (no TLContact at all): Jolt + the scene tree + the pack's own pushes
##   mode 3: as mode 1, and the pack does not push (everything falls asleep): the floor of the scene tree
##   mode 4: boxes tracked, the pack tracker (TLTracker under TLPack) switched off after setup: what contact monitoring and the
##           once-made law cost without the per-tick pass
## Every box is placed by the same seeded generator in every mode, so the piles are the same piles.

var ctx
var boxes: Array = []
var calm: bool = false
var mode: int = 0
var kicks: int = 0


func _pack_setup(c) -> void:
	ctx = c
	mode = ctx.seed / 100000
	var s: int = ctx.seed % 100000
	calm = s >= 10000 or mode == 3
	var count: int = s % 10000
	ctx.root.add_child(TLBodies.ground(Vector2(24, 24), "concrete"))
	for wall: Array in [[Vector3(24, 6, 0.5), Vector3(0, 3, 12)], [Vector3(24, 6, 0.5), Vector3(0, 3, -12)],
			[Vector3(0.5, 6, 24), Vector3(12, 3, 0)], [Vector3(0.5, 6, 24), Vector3(-12, 3, 0)]]:
		ctx.root.add_child(TLBodies.make(&"box", wall[0], "concrete", {"position": wall[1]}))
	for i: int in count:
		var layer: int = i / 100
		var cell: int = i % 100
		var at: Vector3 = Vector3(-9.0 + float(cell % 10) * 2.0 + ctx.rng.randf_range(-0.2, 0.2), 0.6 + float(layer) * 0.9,
			-9.0 + float(cell / 10) * 2.0 + ctx.rng.randf_range(-0.2, 0.2))
		var opts: Dictionary = {"dynamic": true, "position": at}
		if mode == 1 or mode == 3:
			opts["track"] = false
		var box: PhysicsBody3D = TLBodies.make(&"box", Vector3(0.5, 0.5, 0.5), "wood", opts)
		ctx.root.add_child(box)
		boxes.append(box)
	if mode == 4:
		(ctx.root.get_parent().get_node("TLTracker") as Node).set_physics_process(false)


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	if calm or boxes.is_empty() or frame % 4 != 0:
		return
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
