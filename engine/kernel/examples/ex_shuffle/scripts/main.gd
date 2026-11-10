extends Node
## Primitive example: the puck kind of TLBall on an ice lane with steel rails.
##   fast puck:    shot at 30 m/s at a thin end rail; it must bounce back, stay flat and stay on the lane, and a
##                 trigger gate across the lane must see it pass both ways (a small fast body against thin things).
##   carried puck: held by a moving pusher (hold), then released at 3 m/s; it slides by the surface rule
##                 rubber on ice (0.10): 3*3 / (2 * 0.10 * 9.8) = 4.59 m.

var ctx
var fast: TLBall
var carried: TLBall
var pusher: Node3D
var paddle: RigidBody3D
var gate: TLTrigger
var fast_min_z: float = INF
var fast_max_y: float = -INF
var fast_min_y: float = INF
var fast_min_up: float = 1.0
var fast_bounces: int = 0
var release_z: float = 0.0
var held_frames: int = 0


func _pack_setup(c) -> void:
	ctx = c
	ctx.root.add_child(TLBodies.ground(Vector2(8, 44), "ice"))
	for rail: Array in [[Vector3(8, 0.3, 0.2), Vector3(0, 0.15, -20.1)], [Vector3(8, 0.3, 0.2), Vector3(0, 0.15, 20.1)],
			[Vector3(0.2, 0.3, 44), Vector3(4.1, 0.15, 0)], [Vector3(0.2, 0.3, 44), Vector3(-4.1, 0.15, 0)]]:
		ctx.root.add_child(TLBodies.make(&"box", rail[0], "steel", {"position": rail[1]}))
	fast = TLBall.create({"kind": &"puck", "radius": 0.06, "height": 0.03, "material": "rubber", "planar": true,
		"position": Vector3(-2, 0.016, 15), "name": "FastPuck", "group": "pucks"})
	# the carried puck wears a part in the kit's dynamic-prop convention (the stand-in here; TLKit.build("puck") later):
	# the ball takes shape, material and mass from the part's metadata. The paddle is a plain body from a part.
	carried = TLBall.create({"part": TLStandin.dynamic_part(&"puck", 0.06, 0.03, "rubber", 0.17), "planar": true,
		"position": Vector3(2, 0.016, 15), "name": "CarriedPuck", "group": "pucks"})
	paddle = TLBodies.from_part(TLStandin.dynamic_part(&"box", 0.2, 0.1, "wood", 1.5), {"position": Vector3(3.2, 0.06, 0), "name": "Paddle"})
	ctx.root.add_child(paddle)
	ctx.root.add_child(fast)
	ctx.root.add_child(carried)
	fast.bounced.connect(_on_fast_bounced)
	pusher = Node3D.new()
	pusher.name = "Pusher"
	pusher.position = Vector3(2, 0.016, 15.5)
	ctx.root.add_child(pusher)
	gate = TLBodies.trigger(&"box", Vector3(3.5, 0.5, 0.3), {"position": Vector3(-2, 0.25, -5), "group_filter": "pucks", "name": "Gate"})
	ctx.root.add_child(gate)
	ctx.cameras.add_view(&"lane", Vector3(7, 6, 22), Vector3(0, 0, 0), 50.0)


func _on_fast_bounced(_other: Node, _speed: float) -> void:
	fast_bounces += 1


func _pack_start() -> void:
	carried.hold(pusher, Vector3(0, 0, -0.5))


func _pack_tick(frame: int) -> void:
	if frame == 30:
		fast.shoot_at(Vector3(-2, 0.016, -20), 30.0)
	if frame < 60:
		pusher.position.z -= 0.05                    # the pusher carries its puck 3 m down the lane
		if carried.holder() == pusher:
			held_frames += 1
	elif frame == 60:
		release_z = carried.global_position.z
		carried.release(Vector3(0, 0, -3.0))
	if frame > 30:
		fast_min_z = minf(fast_min_z, fast.global_position.z)
		fast_max_y = maxf(fast_max_y, fast.global_position.y)
		fast_min_y = minf(fast_min_y, fast.global_position.y)
		fast_min_up = minf(fast_min_up, fast.global_transform.basis.y.dot(Vector3.UP))


func _pack_state() -> Dictionary:
	return {"fast_min_z": fast_min_z, "fast_min_y": fast_min_y, "fast_max_y": fast_max_y, "fast_min_up": fast_min_up,
		"fast_bounces": fast_bounces, "fast_speed": fast.speed(), "gate_passes": gate.enter_count,
		"held_frames": held_frames, "carried_slide": release_z - carried.global_position.z, "carried_speed": carried.speed(),
		"carried_surface": carried.surface(), "carried_mass": carried.mass, "carried_kind": String(carried.kind),
		"carried_material": carried.material_id, "paddle_mass": paddle.mass, "paddle_material": TLLaws.material_of(paddle),
		"paddle_y": paddle.global_position.y, "law_friction": float(TLLaws.pair("rubber", "ice")["friction"])}
