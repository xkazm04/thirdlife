extends Node
## Primitive example: vehicle controller, input actions, triggers as gates, rules with checkpoints, chase camera,
## plus the small helpers: an AI pace car steered by TLSteer.keep_lane, a HUD, a nitro flame and a finish horn.
## A box car (the stand-in rig) drives a slalom of four gates on asphalt; passing them in order completes the lap.
## Past the last gate the asphalt ends and an ice sheet begins: the same car, the same brake, far less grip, because
## each wheel takes its grip from the surface under it (law tables: rubber on asphalt 1.0, rubber on ice 0.1).

var ctx
var car: TLVehicle
var rules: TLRules
var gates: Array = []
var top_speed: float = 0.0
var nitro_starts: int = 0
var cone_hits: int = 0
var pace: TLVehicle                 # the AI car: same controller, driven through set_controls()
var pace_path: PackedVector3Array = PackedVector3Array()
var pace_length: float = 0.0
var pace_progress: float = 0.0
var pace_offset_max: float = 0.0
var hud: TLHud
var flame: Node3D
var flames_lit: int = 0


func _pack_setup(c) -> void:
	ctx = c
	var course: Dictionary = ctx.read_json("course.json")
	var ice_z: float = float(course["ice_from_z"])
	ctx.root.add_child(TLBodies.make(&"box", Vector3(60, 1, 30.0 - ice_z), "asphalt", {"position": Vector3(0, -0.5, (30.0 + ice_z) * 0.5), "name": "Asphalt"}))
	ctx.root.add_child(TLBodies.make(&"box", Vector3(60, 1, 400), "ice", {"position": Vector3(0, -0.5, ice_z - 200.0), "name": "Ice"}))
	car = TLVehicle.create({"position": Vector3(float(course["start"][0]), 0.1, float(course["start"][1])), "name": "Car"})
	ctx.root.add_child(car)
	car.nitro_started.connect(_on_nitro)
	car.contact.hit.connect(_on_car_hit)
	rules = TLRules.create(course["rules"])
	ctx.root.add_child(rules)
	var width: float = float(course["gate_width"])
	for i: int in (course["gates"] as Array).size():
		var g: Vector3 = Vector3(float(course["gates"][i][0]), 0.0, float(course["gates"][i][1]))
		gates.append(g)
		var gate: TLTrigger = TLBodies.trigger(&"box", Vector3(width, 3, 1), {"position": g + Vector3(0, 1.5, 0), "name": "Gate%d" % i})
		ctx.root.add_child(gate)
		gate.entered.connect(_on_gate.bind(i))
		for side: float in [-1.0, 1.0]:      # a cone at each end of the gate: light plastic, free to be knocked over
			ctx.root.add_child(TLBodies.make(&"cylinder", Vector2(0.18, 0.6), "plastic",
				{"dynamic": true, "mass": 2.0, "position": g + Vector3(side * width * 0.5, 0.3, 0), "group": "cones"}))
	# the pace car starts behind and follows the line through the gates, slower than the player
	pace = TLVehicle.create({"position": Vector3(0, 0.1, 24), "name": "Pace"})
	ctx.root.add_child(pace)
	pace_path.append(Vector3(0, 0, 24))
	for g: Vector3 in gates:
		pace_path.append(g)
	for i: int in pace_path.size() - 1:
		pace_length += pace_path[i].distance_to(pace_path[i + 1])
	hud = TLHud.create()
	ctx.root.add_child(hud)
	hud.add_clock(rules, &"top")
	hud.add_speed(car.speed_kmh, "km/h", &"bottom_right")
	hud.add_label(&"hint", "A/D steer, W gas, Space brake, Shift nitro", &"bottom")
	car.nitro_ended.connect(_on_nitro_end)
	rules.finished.connect(_on_finished)
	for action: Array in [[&"left", KEY_A], [&"right", KEY_D], [&"gas", KEY_W], [&"brake", KEY_SPACE], [&"reverse", KEY_S], [&"nitro", KEY_SHIFT]]:
		ctx.input.declare(action[0], [action[1]])
	ctx.cameras.chase(car, {"distance": 8.0, "height": 3.2})
	ctx.cameras.add_view(&"overview", Vector3(30, 28, -40), Vector3(0, 0, -60), 60.0)


func _on_nitro() -> void:
	nitro_starts += 1
	flame = TLVfx.attach(&"nitro_flame", car.rig.socket(&"exhaust_l"), {"direction": Vector3(0, 0, 1)})
	if flame != null:
		flames_lit += 1
	TLAudio.play(&"nitro", car.global_position)


func _on_nitro_end() -> void:
	if flame != null and is_instance_valid(flame):
		flame.stop()
	flame = null


func _on_finished(_winner: String, _reason: String) -> void:
	TLAudio.play(&"horn")


func _on_car_hit(other: Node, _impulse: float, _speed: float) -> void:
	if other.is_in_group("cones"):
		cone_hits += 1


func _on_gate(body: Node3D, index: int) -> void:
	if body == car:
		rules.pass_checkpoint("car", index)


func _pack_start() -> void:
	rules.start()


func _pack_tick(_frame: int) -> void:
	car.drive_from_input(ctx.input, {"left": &"left", "right": &"right", "gas": &"gas", "brake": &"brake", "reverse": &"reverse", "nitro": &"nitro"})
	top_speed = maxf(top_speed, car.speed())
	# AI driver: aim along the path, hold 9 m/s, brake at the end of it
	var lane: Dictionary = TLSteer.keep_lane(pace.global_position, pace.forward(), pace_path, 9.0)
	pace_progress = float(lane["progress"])
	if pace_progress > 5.0 and pace_progress < pace_length - 12.0:
		pace_offset_max = maxf(pace_offset_max, absf(float(lane["offset"])))
	if pace_progress < pace_length - 8.0:
		pace.set_controls(float(lane["steer"]), 1.0 if pace.forward_speed() < 9.0 else 0.0)
	else:
		pace.set_controls(0.0, 0.0, 1.0)


func _pack_state() -> Dictionary:
	var s: Dictionary = rules.snapshot()
	var next: int = int(rules.next_checkpoint["car"])
	var f: Vector3 = car.forward()
	s["car"] = {"x": car.global_position.x, "y": car.global_position.y, "z": car.global_position.z, "fx": f.x, "fz": f.z,
		"speed": car.speed(), "forward_speed": car.forward_speed(), "grounded_wheels": car.grounded_wheels(),
		"surface": car.wheel_surface[0], "nitro_charge": car.nitro_charge, "nitro_active": car.nitro_active}
	s["next_gate"] = [gates[next].x, gates[next].z] if not rules.is_over() else [0.0, -400.0]
	s["top_speed"] = top_speed
	s["nitro_starts"] = nitro_starts
	s["cone_hits"] = cone_hits
	s["pace"] = {"progress": pace_progress, "length": pace_length, "offset_max": pace_offset_max, "speed": pace.speed()}
	s["hud_speed"] = hud.text_of(&"speed")
	s["hud_clock"] = hud.text_of(&"clock")
	s["flames_lit"] = flames_lit
	s["horns"] = TLAudio.count(&"horn")
	return s
