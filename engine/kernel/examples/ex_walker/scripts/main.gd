extends Node
## Primitive example: biped controller, input actions, triggers, rules, orbit camera.
## A walker crosses a concrete room through two checkpoints (pushing a crate out of the way); the rules end the
## "game" when the lap is complete. Beside the room a skater on an ice lane shows the skate mode: thrust, then a
## long glide when the input is released.

var ctx
var walker: TLBiped
var skater: TLBiped
var crate: RigidBody3D
var rules: TLRules
var cam: TLOrbitCam
var crate_pushes: int = 0
var walker_top_speed: float = 0.0
var skater_top_speed: float = 0.0


func _pack_setup(c) -> void:
	ctx = c
	# the room: concrete floor and four walls
	ctx.root.add_child(TLBodies.ground(Vector2(12, 32), "concrete", 0.0, Vector3(0, 0, 4)))
	for wall: Array in [[Vector3(12, 3, 0.4), Vector3(0, 1.5, 20)], [Vector3(12, 3, 0.4), Vector3(0, 1.5, -12)],
			[Vector3(0.4, 3, 32), Vector3(6, 1.5, 4)], [Vector3(0.4, 3, 32), Vector3(-6, 1.5, 4)]]:
		ctx.root.add_child(TLBodies.make(&"box", wall[0], "concrete", {"position": wall[1]}))
	# the ice lane beside it
	ctx.root.add_child(TLBodies.ground(Vector2(6, 80), "ice", 0.0, Vector3(12, 0, -20)))
	walker = TLBiped.create({"position": Vector3(0, 0.05, 10), "name": "Walker"})
	skater = TLBiped.create({"position": Vector3(12, 0.05, 10), "mode": "skate", "name": "Skater"})
	ctx.root.add_child(walker)
	ctx.root.add_child(skater)
	# an empty crate: without "mass" a solid wooden block of this size would weigh 333 kg (density x volume)
	crate = TLBodies.make(&"box", Vector3(0.8, 0.8, 0.8), "wood", {"dynamic": true, "mass": 15.0, "position": Vector3(0, 0.4, 4), "name": "Crate"})
	ctx.root.add_child(crate)
	walker.pushed.connect(_on_pushed)
	rules = TLRules.create(ctx.read_json("rules.json"))
	ctx.root.add_child(rules)
	var gates: Array = [Vector3(0, 1, 0), Vector3(0, 1, -9)]
	for i: int in gates.size():
		var gate: TLTrigger = TLBodies.trigger(&"box", Vector3(11, 2, 0.5), {"position": gates[i], "name": "Gate%d" % i})
		ctx.root.add_child(gate)
		gate.entered.connect(_on_gate.bind(i))
	for action: Array in [[&"forward", KEY_W], [&"back", KEY_S], [&"left", KEY_A], [&"right", KEY_D], [&"run", KEY_SHIFT],
			[&"skate", KEY_UP], [&"look_left", KEY_Q], [&"look_right", KEY_E]]:
		ctx.input.declare(action[0], [action[1]])
	cam = ctx.cameras.orbit(walker, {"distance": 7.0, "pitch": 40.0})
	cam.bind_actions(ctx.input, {"yaw_left": &"look_left", "yaw_right": &"look_right"})
	ctx.cameras.add_view(&"top", Vector3(4, 30, 0), Vector3(4, 0, -1), 60.0)


func _on_pushed(_body: RigidBody3D, _impulse: float) -> void:
	crate_pushes += 1


func _on_gate(body: Node3D, index: int) -> void:
	if body == walker:
		rules.pass_checkpoint("walker", index)


func _pack_start() -> void:
	rules.start()


func _pack_tick(_frame: int) -> void:
	walker.drive_from_input(ctx.input, {"left": &"left", "right": &"right", "forward": &"forward", "back": &"back", "run": &"run"},
		cam.yaw_basis())
	skater.move(Vector3(0, 0, -1) * ctx.input.strength(&"skate"))
	walker_top_speed = maxf(walker_top_speed, walker.speed())
	skater_top_speed = maxf(skater_top_speed, skater.speed())


func _pack_state() -> Dictionary:
	var s: Dictionary = rules.snapshot()
	s["walker_z"] = walker.global_position.z
	s["walker_speed"] = walker.speed()
	s["walker_top_speed"] = walker_top_speed
	s["walker_surface"] = walker.surface
	s["skater_z"] = skater.global_position.z
	s["skater_speed"] = skater.speed()
	s["skater_top_speed"] = skater_top_speed
	s["skater_surface"] = skater.surface
	s["crate_pushes"] = crate_pushes
	s["camera_pitch"] = cam.pitch
	return s
